unit rad.cmd;

interface

uses
  System.Classes, System.Variants, System.SysUtils, System.Threading,
  System.SyncObjs, System.Rtti, System.Generics.Collections,
  rad.utils,
  mormot.core.os; // TRWLock için

type
  TCmd = reference to function(Sender: TObject; const Args: TArray<TValue>): TValue;

  ICmds = interface
    ['{38103B57-33D7-400A-AEA6-B97453481263}']
    procedure RegisterCommand(const Name: string; const Func: TCmd);
    procedure UnregisterCommand(const Name: string);
    function Exists(const Name: string): Boolean;
    function CommandCount: Integer;

    function Execute(const Name: string; Sender: TObject = nil; const Args: TArray<TValue> = nil): TValue;
    function TryExecute(const Name: string; Sender: TObject; const Args: TArray<TValue>; out Res: TValue): Boolean; overload;
    function TryExecute(const Name: string; out Res: TValue; Sender: TObject = nil): Boolean; overload;

    procedure ExecuteAsync(const Name: string; Sender: TObject; const Args: TArray<TValue>; OnDone: TProc<TValue>; OnError: TProc<Exception> = nil);
  end;

function CreateCmds: ICmds;

implementation

uses
  mormot.core.base, // TRWLock inline expansion + sllWarning/sllError
  mormot.core.log;  // TSynLog — TryExecute/ExecuteAsync hata loglaması için

type
  TCmds = class(TInterfacedObject, ICmds)
  strict private
    FLock    : TRWLock;
    FCommands: TDictionary<string, TCmd>;

    procedure BeginRead;  inline;
    procedure EndRead;    inline;
    procedure BeginWrite; inline;
    procedure EndWrite;   inline;
    class function NormalizeName(const Name: string): string; static;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterCommand(const Name: string; const Func: TCmd);
    procedure UnregisterCommand(const Name: string);
    function Exists(const Name: string): Boolean;
    function CommandCount: Integer;

    function Execute(const Name: string; Sender: TObject = nil; const Args: TArray<TValue> = nil): TValue;
    function TryExecute(const Name: string; Sender: TObject; const Args: TArray<TValue>; out Res: TValue): Boolean; overload;
    function TryExecute(const Name: string; out Res: TValue; Sender: TObject = nil): Boolean; overload;

    procedure ExecuteAsync(const Name: string; Sender: TObject; const Args: TArray<TValue>; OnDone: TProc<TValue>; OnError: TProc<Exception> = nil);
  end;

function CreateCmds: ICmds;
begin
  Result := TCmds.Create;
end;

{ TCmds }

constructor TCmds.Create;
begin
  inherited Create;
  FCommands := TDictionary<string, TCmd>.Create;
end;

destructor TCmds.Destroy;
begin
  FCommands.Free;
  inherited Destroy;
end;

procedure TCmds.BeginRead;
begin
  FLock.ReadOnlyLock;
end;

procedure TCmds.EndRead;
begin
  FLock.ReadOnlyUnLock;
end;

procedure TCmds.BeginWrite;
begin
  FLock.WriteLock;
end;

procedure TCmds.EndWrite;
begin
  FLock.WriteUnlock;
end;

class function TCmds.NormalizeName(const Name: string): string;
begin
  // rad.eventbus.pas'taki kanal adı normalizasyonuyla tutarlı (Trim.ToLowerInvariant):
  // bas/son bosluk farkinin farkli komut sayilmasini onler.
  Result := Name.Trim.ToLowerInvariant;
end;

procedure TCmds.RegisterCommand(const Name: string; const Func: TCmd);
var
  LName: string;
begin
  LName := NormalizeName(Name);
  if LName = '' then
    raise EArgumentException.Create('TCmds.RegisterCommand: Name cannot be empty');
  if not Assigned(Func) then
    raise EArgumentException.CreateFmt('TCmds.RegisterCommand: Func cannot be nil (Name=%s)', [Name]);
  BeginWrite;
  try
    FCommands.AddOrSetValue(LName, Func);
  finally
    EndWrite;
  end;
end;

procedure TCmds.UnregisterCommand(const Name: string);
begin
  BeginWrite;
  try
    FCommands.Remove(NormalizeName(Name));
  finally
    EndWrite;
  end;
end;

function TCmds.Execute(const Name: string; Sender: TObject; const Args: TArray<TValue>): TValue;
var
  LFunc: TCmd;
begin
  BeginRead;
  try
    if not FCommands.TryGetValue(NormalizeName(Name), LFunc) then
      raise Exception.CreateFmt('Command not found: %s', [Name]);
  finally
    EndRead;
  end;
  Result := LFunc(Sender, Args);
end;

function TCmds.TryExecute(const Name: string; Sender: TObject; const Args: TArray<TValue>; out Res: TValue): Boolean;
begin
  try
    Res    := Execute(Name, Sender, Args);
    Result := True;
  except
    on E: Exception do
    begin
      // 2026-07-09 incelemesi #5: hata bilgisi Boolean'a indirgenirken kaybolmasin
      // diye TSynLog'a yazilir (caller yine sadece True/False gorur - tasarim
      // korunuyor, ama hata izlenebilir).
      TSynLog.Add.Log(sllWarning, 'TCmds.TryExecute [%]: %', [Name, E.Message]);
      Res    := TValue.Empty;
      Result := False;
    end;
  end;
end;

function TCmds.TryExecute(const Name: string; out Res: TValue; Sender: TObject): Boolean;
begin
  Result := TryExecute(Name, Sender, [], Res);
end;

procedure TCmds.ExecuteAsync(const Name: string; Sender: TObject; const Args: TArray<TValue>; OnDone: TProc<TValue>; OnError: TProc<Exception>);
var
  LKeepAlive: ICmds;
begin
  // 2026-07-09 incelemesi #2: closure Self'i (Execute cagrisi uzerinden) dogrudan
  // yakalardi - interface refcount'a katilmayan ham nesne referansi. Dis kod
  // ICmds referansini erken birakirsa (ör. CreateCmds.ExecuteAsync(...)) task
  // calisirken nesne Free edilebilirdi. LKeepAlive, task bitene kadar nesneyi
  // interface refcount ile hayatta tutar.
  LKeepAlive := Self;

  TTask.Run(procedure
  var
    LRes: TValue;
    LAcquiredEx: Exception;
  begin
    try
      LRes := LKeepAlive.Execute(Name, Sender, Args);
      if Assigned(OnDone) then
        TThread.ForceQueue(nil, procedure
          begin
            try
              OnDone(LRes);
            except
              // 2026-07-09 incelemesi #6: OnDone callback'inin KENDISI exception
              // atarsa artik sarmalanmadan yayilmiyor, loglanip yutuluyor.
              on E: Exception do
                TSynLog.Add.Log(sllError, 'TCmds.ExecuteAsync [%] OnDone callback failed: %', [Name, E.Message]);
            end;
          end);
    except
      on E: Exception do
      begin
        if Assigned(OnError) then
        begin
          // 2026-07-09 incelemesi #1: except blogundan cikildiginda RTL E'yi
          // otomatik Free eder; ForceQueue ise OnError'i DAHA SONRA ana thread'de
          // calistirir - bu yuzden E dogrudan kapatilirsa use-after-free olusur.
          // AcquireExceptionObject ile sahiplik RTL'den alinip callback bitince
          // manuel Free edilir.
          LAcquiredEx := Exception(AcquireExceptionObject);
          TThread.ForceQueue(nil, procedure
            begin
              try
                try
                  OnError(LAcquiredEx);
                except
                  // 2026-07-09 incelemesi #6: OnError callback'inin KENDISI de
                  // exception atarsa loglanip yutuluyor.
                  on E2: Exception do
                    TSynLog.Add.Log(sllError, 'TCmds.ExecuteAsync [%] OnError callback failed: %', [Name, E2.Message]);
                end;
              finally
                LAcquiredEx.Free;
              end;
            end);
        end;
      end;
    end;
  end);
end;

function TCmds.Exists(const Name: string): Boolean;
begin
  BeginRead;
  try
    Result := FCommands.ContainsKey(NormalizeName(Name));
  finally
    EndRead;
  end;
end;

function TCmds.CommandCount: Integer;
begin
  BeginRead;
  try
    Result := FCommands.Count;
  finally
    EndRead;
  end;
end;

end.
