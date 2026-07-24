# HTTP Consumption Patterns — Reference

Companion to `../SKILL.md`. Everything here presumes the golden rules
(timeouts, try..finally, status-first, no main-thread blocking).

## POST / PUT with a JSON body (THTTPClient)

```pascal
uses System.Net.HttpClient, System.Classes, System.JSON, System.NetConsts;

function TCustomerApiClient.CreateCustomer(const AName, ACpf: string): Integer;
var
  LClient: THTTPClient;
  LBody: TStringStream;
  LJson: TJSONObject;
  LResponse: IHTTPResponse;
  LParsed: TJSONValue;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('name', AName);
    LJson.AddPair('cpf', ACpf);
    LBody := TStringStream.Create(LJson.ToJSON, TEncoding.UTF8);
  finally
    LJson.Free;
  end;

  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 5000;
    LClient.ResponseTimeout := 10000;
    LClient.ContentType := 'application/json';

    LResponse := LClient.Post(FConfig.BaseUrl + '/customers', LBody);
    if LResponse.StatusCode <> 201 then
      raise EApiClientException.CreateFmt('POST failed: %d %s',
        [LResponse.StatusCode, LResponse.StatusText]);

    LParsed := TJSONObject.ParseJSONValue(LResponse.ContentAsString(TEncoding.UTF8));
    if LParsed = nil then
      raise EApiClientException.Create('Response is not valid JSON');
    try
      Result := LParsed.GetValue<Integer>('id');
    finally
      LParsed.Free;
    end;
  finally
    LBody.Free;
    LClient.Free;
  end;
end;
```

Notes:
- The request body stream is **yours to free** — the client doesn't own it.
- `PUT` is identical with `LClient.Put(...)`; `DELETE` typically has no
  body: `LClient.Delete(LUrl)`.

## The TRESTClient trio (JSON-heavy APIs)

```pascal
uses REST.Client, REST.Types, REST.Json;

var
  LClient: TRESTClient;
  LRequest: TRESTRequest;
  LResponse: TRESTResponse;
begin
  LClient := TRESTClient.Create(FConfig.BaseUrl);
  LRequest := TRESTRequest.Create(nil);
  LResponse := TRESTResponse.Create(nil);
  try
    LRequest.Client := LClient;
    LRequest.Response := LResponse;

    LRequest.Resource := 'customers/{id}';
    LRequest.AddParameter('id', '42', pkURLSEGMENT);       // encodes for you
    LRequest.AddParameter('expand', 'orders', pkQUERY);
    LRequest.Method := rmGET;
    LRequest.Timeout := 10000;

    LRequest.Execute;
    if LResponse.StatusCode <> 200 then
      raise EApiClientException.CreateFmt('%d %s',
        [LResponse.StatusCode, LResponse.StatusText]);

    // Direct JSON access — no manual parse/free:
    ShowName(LResponse.JSONValue.GetValue<string>('name'));
  finally
    LResponse.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;
```

- Auth: attach a `TRESTHttpBasicAuthenticator` (or OAuth1/OAuth2
  authenticator component) to `LClient.Authenticator`, or add an
  `Authorization` header parameter with `poDoNotEncode`.
- Object mapping: `TJson.JsonToObject<TCustomerDto>(LResponse.Content)`
  (from `REST.Json`) — remember the returned object is yours to free.

## RESTRequest4Delphi — fluent third-party alternative

[RESTRequest4Delphi](https://github.com/viniciussanchez/RESTRequest4Delphi)
(MIT) wraps the whole request in one fluent chain, with the HTTP engine
swappable underneath (default RESTClient on Delphi; `RR4D_INDY`,
`RR4D_SYNAPSE`, `RR4D_ICS`, `RR4D_NETHTTP` conditional defines switch it;
fphttpclient on Lazarus):

```pascal
uses RESTRequest4D;

var
  LResponse: IResponse;
begin
  LResponse := TRequest.New
    .BaseURL(FConfig.BaseUrl)
    .Resource('customers')
    .AddParam('expand', 'orders')
    .TokenBearer(FConfig.ApiToken)      // or BasicAuthentication(user, pass)
    .Accept('application/json')
    .Get;

  if LResponse.StatusCode <> 200 then
    raise EApiClientException.CreateFmt('%d %s',
      [LResponse.StatusCode, LResponse.StatusText]);
  ProcessJson(LResponse.JSONValue);
end;
```

The golden rules still apply unchanged — status-first, no main-thread
blocking, secrets from configuration. `IResponse` is interface-counted;
no manual Free for the chain.

## Async — keep the UI alive

```pascal
uses System.Threading;

procedure TCustomerForm.LoadCustomerAsync(AId: Integer);
begin
  TTask.Run(
    procedure
    var
      LName: string;
    begin
      LName := FApiClient.FetchCustomerName(AId);   // blocking call, worker thread
      TThread.Queue(nil,
        procedure
        begin
          lblName.Caption := LName;                 // UI update, main thread
        end);
    end);
end;
```

- Exceptions inside the task are silent unless handled — wrap the worker
  body in `try..except`, marshal the error message back with `Queue` too.
- Lifecycle: the queued closure may outlive the form — apply the
  `threading` skill's captured-object-lifetime warning verbatim.

## Retry with backoff (transient failures only)

```pascal
function TApiClientBase.ExecuteWithRetry(const ACall: TFunc<IHTTPResponse>): IHTTPResponse;
const
  MAX_ATTEMPTS = 3;
  BASE_DELAY_MS = 500;
var
  LAttempt: Integer;
begin
  for LAttempt := 1 to MAX_ATTEMPTS do
  begin
    try
      Result := ACall();
      // Retry only transient statuses; 4xx are the caller's bug, don't retry
      if not (Result.StatusCode in [429, 502, 503, 504]) then
        Exit;
    except
      on E: ENetHTTPClientException do
        if LAttempt = MAX_ATTEMPTS then
          raise;
    end;
    Sleep(BASE_DELAY_MS * LAttempt * LAttempt);  // 0.5s, 2s, 4.5s — worker thread only!
  end;
end;
```

Never `Sleep` on the main thread — this helper belongs inside the
`TTask.Run` worker path.

## File download / upload

```pascal
// Download straight into a stream — no giant in-memory strings
LFile := TFileStream.Create(ATargetPath, fmCreate);
try
  LResponse := LClient.Get(AUrl, LFile);   // writes body into LFile
  if LResponse.StatusCode <> 200 then
    raise EApiClientException.Create('Download failed: ' + LResponse.StatusText);
finally
  LFile.Free;
end;

// Multipart upload
LForm := TMultipartFormData.Create;        // System.Net.Mime
try
  LForm.AddFile('file', ASourcePath);
  LForm.AddField('description', ADescription);
  LResponse := LClient.Post(AUrl, LForm);
finally
  LForm.Free;
end;
```

## Pitfalls

- **Encoding:** `ContentAsString` defaults to the charset the server
  declared; pass `TEncoding.UTF8` explicitly when the server lies or
  omits it.
- **Redirects:** followed automatically up to `MaxRedirects` — set it
  (and check `LResponse.StatusCode`) when calling APIs that answer 3xx
  meaningfully.
- **TLS:** modern TLS is negotiated by the platform (SChannel on
  Windows) — don't ship custom certificate-validation bypasses
  (`OnValidateServerCertificate` that always accepts) to "fix" cert
  errors; fix the certificate instead.
- **One client per unit of work is fine** — THTTPClient is cheap to
  create; sharing one instance across threads is NOT safe by default.
  Give each worker its own client.
- **4xx vs 5xx:** 4xx means fix the request (don't retry); 5xx/429 may
  be retried with backoff. Collapsing both into one "error" path hides
  caller bugs.
