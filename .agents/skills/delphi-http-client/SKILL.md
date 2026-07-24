---
name: delphi-http-client
description: Consuming HTTP/REST APIs from Delphi — THTTPClient (System.Net.HttpClient), TNetHTTPClient, and the TRESTClient stack (REST.Client), with JSON handling, timeouts, authentication, async patterns and error handling. Use whenever Delphi code CALLS an external API — this kit is client-side only; exposing/serving APIs is out of its scope.
---

# Delphi HTTP Client — Consuming REST APIs

This skill covers **calling** external HTTP/REST APIs from Delphi code —
the client side of REST/JSON integration. Serving HTTP is out of this
kit's scope.

## Usage

| You say | What happens |
|---|---|
| "Call this REST API from Delphi" / "bu API'yi Delphi'den tüket" | Client choice (table below), then a timeout-safe, try..finally-correct implementation with parsed JSON. |
| "Add authentication to the API call" | CustomHeaders bearer/token pattern, or TRESTClient authenticator classes. |
| "The API call freezes my UI" | Moves the call off the main thread (TTask + TThread.Queue — see the `threading` skill), never a synchronous call in an event handler. |
| A `.pas` file consuming an API is reviewed | Checklist at the bottom applied: timeouts set, response freed, status checked, JSON parsed safely, no main-thread blocking. |

## Choosing the client — three options, one decision table

| | `THTTPClient` | `TNetHTTPClient` | `TRESTClient` stack |
|---|---|---|---|
| Unit | `System.Net.HttpClient` | `System.Net.HttpClientComponent` | `REST.Client` |
| Style | Code-first class | Drop-on-form component wrapper of THTTPClient (design-time props, events) | Component trio: `TRESTClient` + `TRESTRequest` + `TRESTResponse` |
| Best for | Services/infrastructure code, console, anything non-visual | Quick form-based apps wanting design-time config | JSON REST APIs — built-in param handling, serialization helpers, authenticators |
| JSON | Manual (`System.JSON`) | Manual (`System.JSON`) | `Response.JSONValue`, `TJson` helpers |
| Auth | `CustomHeaders` yourself | `CustomHeaders` yourself | `TRESTHttpBasicAuthenticator`, OAuth authenticator components |

Default recommendation: **`THTTPClient` in infrastructure/service
classes** (fits this kit's layering — the HTTP call belongs behind an
interface in Infrastructure, never in a form event); **`TRESTClient`
stack when the API is JSON-heavy** and you want request/response
plumbing handled for you.

**Third-party option — [RESTRequest4Delphi](https://github.com/viniciussanchez/RESTRequest4Delphi)**
(MIT, 600+ stars, actively maintained): a fluent one-liner API over
pluggable engines (RESTClient default on Delphi; Indy/Synapse/ICS/
NetHTTP via `RR4D_*` conditional defines; fphttpclient on Lazarus).
Worth reaching for when the project already uses it, needs Lazarus/FPC
compatibility, or wants engine portability — see
`references/consumption-patterns.md` for the pattern. RTL-only projects
should still default to the first-party clients above (no extra
dependency).

## Golden rules

1. **Always set timeouts.** `ConnectionTimeout` and `ResponseTimeout`
   (milliseconds) — the defaults can block far too long on a dead
   endpoint. No production call ships without both.
2. **The client is an object like any other** — `try..finally Free`,
   per this kit's memory rules. `IHTTPResponse` is interface-counted
   (no Free), but the client and any request streams you create are not.
3. **Check `StatusCode` before touching the body.** A 404's body parses
   as JSON just fine and then poisons your logic. Branch on status
   first; raise a typed exception (`EApiClientException`) for non-2xx.
4. **Never build or parse JSON by string concatenation** — `System.JSON`
   (`TJSONObject.ParseJSONValue`, `TJSONValue.GetValue<T>`) or
   `REST.Json`'s `TJson.JsonToObject<T>`.
5. **Never call synchronously on the main thread.** Wrap in `TTask.Run`
   and marshal results back with `TThread.Queue` — the `threading`
   skill's rules apply verbatim here.
6. **Encode what goes into URLs** — `TNetEncoding.URL.Encode` for query
   values (or `TRESTRequest.AddParameter`, which encodes for you).
7. **Secrets stay out of code** — tokens/API keys come from
   configuration (`IConfiguration` injection), never hardcoded literals.

## Minimal correct example (GET + JSON)

```pascal
uses
  System.Net.HttpClient, System.Net.URLClient, System.JSON, System.SysUtils;

function TCustomerApiClient.FetchCustomerName(AId: Integer): string;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LJson: TJSONValue;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 5000;   // ms — never ship without these
    LClient.ResponseTimeout := 10000;
    LClient.CustomHeaders['Authorization'] := 'Bearer ' + FConfig.ApiToken;

    LResponse := LClient.Get(Format('%s/customers/%d', [FConfig.BaseUrl, AId]));
    if LResponse.StatusCode <> 200 then
      raise EApiClientException.CreateFmt('GET customer %d failed: %d %s',
        [AId, LResponse.StatusCode, LResponse.StatusText]);

    LJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString(TEncoding.UTF8));
    if LJson = nil then
      raise EApiClientException.Create('Response is not valid JSON');
    try
      Result := LJson.GetValue<string>('name');
    finally
      LJson.Free;
    end;
  finally
    LClient.Free;
  end;
end;
```

## Review checklist

- [ ] `ConnectionTimeout` + `ResponseTimeout` explicitly set?
- [ ] Client (and any request streams) freed in `finally`?
- [ ] `StatusCode` checked before parsing the body?
- [ ] JSON parsed via `System.JSON`/`REST.Json`, parse result nil-checked and freed?
- [ ] Call kept off the main thread (TTask + Queue) in UI apps?
- [ ] Query/path values URL-encoded?
- [ ] Token/base-URL injected from configuration, not hardcoded?
- [ ] Non-2xx mapped to a typed exception, not silently ignored?

Deeper patterns — POST/PUT with JSON bodies, the TRESTClient trio,
retry/backoff, file download/upload, async wrappers, common pitfalls:
`references/consumption-patterns.md`.

> API surface (units, member names, timeout semantics) verified against
> Embarcadero DocWiki (System.Net.HttpClient.THTTPClient,
> TNetHTTPClient.ResponseTimeout/CustomHeaders, "Using an HTTP Client")
> at authoring time. Examples follow the documented API; compile-verify
> in a real RAD Studio project before shipping derived code.
