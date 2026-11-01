unit rad.script;

(* Script/eklenti sistemi, 2. aşama: paket modeli, tanım tabloları DDL ve .radpaket
   dosya biçimi. Motor (TMS Scripter) ve kanca katmanı burada değil; bkz.
   docs/specs/rad.script.md. Veri erişimi Help.uni.pas (TRadUniScriptStore). *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  mormot.core.base, mormot.core.text, mormot.core.buffers, mormot.core.variants,
  rad.sqlfilter, rad.date;

type
  ERadScript = class(Exception);
  ERadScriptFormat = class(ERadScript);

  /// Derleme/çalışma/zaman aşımı hatası: hangi script, hangi konum.
  ERadScriptExec = class(ERadScript)
  private
    FScriptCode: string;
    FLine: Integer;
    FCol: Integer;
  public
    constructor Create(const AScriptCode: string; ALine, ACol: Integer; const AMsg: string);
    property ScriptCode: string read FScriptCode;
    property Line: Integer read FLine;
    property Col: Integer read FCol;
  end;
  ERadScriptCompile = class(ERadScriptExec);
  ERadScriptRuntime = class(ERadScriptExec);
  ERadScriptTimeout = class(ERadScriptExec);

  /// tur kodu: form, olay, zaman, komut, kutuphane, pencere
  TRadScriptKind = (skForm, skEvent, skSchedule, skCommand, skLibrary, skWindow);

  TRadScript = class
  private
    FId: Integer;
    FPackageId: Integer;
    FCode: string;
    FName: string;
    FKind: TRadScriptKind;
    FTarget: string;
    FOrder: Integer;
    FActive: Boolean;
    FSource: string;
    FModified: TDateTime;
  public
    constructor Create;
    class function KindCodeOf(AKind: TRadScriptKind): string; static;
    class function KindOfCode(const ACode: string; out AKind: TRadScriptKind): Boolean; static;
    /// Pascal tanımlayıcısı: harf/_ ile başlar, harf/rakam/_ devam eder, en çok 50.
    class function IsValidIdentifier(const AText: string): Boolean; static;
    function KindCode: string;
    /// pencere script'inin DFM kaynağının adı: <kod>.dfm
    function DfmFileName: string;
    /// '' = geçerli; aksi halde ilk hata.
    function Validate: string;
    procedure Assign(ASource: TRadScript);
    property Id: Integer read FId write FId;
    property PackageId: Integer read FPackageId write FPackageId;
    property Code: string read FCode write FCode;
    property Name: string read FName write FName;
    property Kind: TRadScriptKind read FKind write FKind;
    /// form/komut: sınıf adı; olay: kanal adı; zaman: TDtSchedule maskesi; kutuphane/pencere: boş.
    property Target: string read FTarget write FTarget;
    property Order: Integer read FOrder write FOrder;
    property Active: Boolean read FActive write FActive;
    property Source: string read FSource write FSource;
    property Modified: TDateTime read FModified write FModified;
  end;
  TRadScripts = TObjectList<TRadScript>;

  TRadScriptParam = class
  private
    FId: Integer;
    FName: string;
    FValue: string;
    FDescription: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
    property Description: string read FDescription write FDescription;
  end;

  TRadScriptDbStep = class
  private
    FId: Integer;
    FOrder: Integer;
    FDescription: string;
    FSql: string;
    FApplied: Boolean;
    FAppliedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property Order: Integer read FOrder write FOrder;
    property Description: string read FDescription write FDescription;
    property Sql: string read FSql write FSql;
    property Applied: Boolean read FApplied write FApplied;
    property AppliedAt: TDateTime read FAppliedAt write FAppliedAt;
  end;

  TRadScriptResource = class
  private
    FId: Integer;
    FPackageId: Integer;
    FFileName: string;
    FContent: TBytes;
  public
    property Id: Integer read FId write FId;
    /// ResourcesNamed doldurur; paket içinden okunanda 0 kalabilir.
    property PackageId: Integer read FPackageId write FPackageId;
    property FileName: string read FFileName write FFileName;
    property Content: TBytes read FContent write FContent;
  end;

  TRadScriptPackage = class
  private
    FId: Integer;
    FCode: string;
    FName: string;
    FDescription: string;
    FVersion: string;
    FAuthor: string;
    FActive: Boolean;
    FProtected: Boolean;
    FOrder: Integer;
    FCreated: TDateTime;
    FModified: TDateTime;
    FScripts: TRadScripts;
    FParams: TObjectList<TRadScriptParam>;
    FDbSteps: TObjectList<TRadScriptDbStep>;
    FResources: TObjectList<TRadScriptResource>;
  public
    constructor Create;
    destructor Destroy; override;
    /// küçük harf/rakam ile başlar, sonra küçük harf/rakam/./-, 2-50 karakter; dosya adı olur.
    class function IsValidCode(const ACode: string): Boolean; static;
    /// '' = geçerli; aksi halde ilk hata.
    function Validate: string;
    function ScriptByCode(const ACode: string): TRadScript;
    function ParamByName(const AName: string): TRadScriptParam;
    function ParamValue(const AName, ADefault: string): string;
    function ResourceByName(const AFileName: string): TRadScriptResource;
    function AddScript(const ACode: string; AKind: TRadScriptKind; const ATarget, ASource: string): TRadScript;
    function AddParam(const AName, AValue: string): TRadScriptParam;
    function AddDbStep(AOrder: Integer; const ASql: string): TRadScriptDbStep;
    function AddResource(const AFileName: string; const AContent: TBytes): TRadScriptResource;
    property Id: Integer read FId write FId;
    property Code: string read FCode write FCode;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Version: string read FVersion write FVersion;
    property Author: string read FAuthor write FAuthor;
    property Active: Boolean read FActive write FActive;
    /// tasarımcı kaynağı gizler; güvenlik değil (dosyada kaynak okunur).
    property IsProtected: Boolean read FProtected write FProtected;
    property Order: Integer read FOrder write FOrder;
    property Created: TDateTime read FCreated write FCreated;
    property Modified: TDateTime read FModified write FModified;
    property Scripts: TRadScripts read FScripts;
    property Params: TObjectList<TRadScriptParam> read FParams;
    property DbSteps: TObjectList<TRadScriptDbStep> read FDbSteps;
    property Resources: TObjectList<TRadScriptResource> read FResources;
  end;
  TRadScriptPackages = TObjectList<TRadScriptPackage>;

  IRadScriptStore = interface
    ['{3B6E0F7A-2C19-4D58-9A41-7E5D0C2B8F13}']
    function Dialect: TRadSqlDialect;
    /// 5 tanım tablosu yoksa yaratır. İdempotent.
    procedure EnsureDefinitionTables;
    /// Tam graf (script/parametre/db/kaynak). Sahiplik çağırana geçer.
    function LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;
    /// nil = yok.
    function LoadPackage(const ACode: string): TRadScriptPackage;
    /// Kod'a göre insert/update; listede olmayan alt kayıt silinir; tek transaction. Id'ler dolar.
    procedure SavePackage(APkg: TRadScriptPackage);
    /// Aynı kod varsa mevcut parametre değerlerini korur, sonra SavePackage.
    procedure ImportPackage(APkg: TRadScriptPackage);
    /// Cascade; script_db ile yaratılan kullanıcı tablolarına dokunmaz.
    procedure DeletePackage(const ACode: string);
    /// Yalnız aktif paket + aktif script; sıra: paket.sira, script.sira. Hedef büyük/küçük harf duyarsız.
    function ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
    /// Uygulanmamış adımlar sırayla; hata olursa durur ve yükseltir, uygulananlar işaretli kalır.
    procedure ApplyPendingDbSteps(APkg: TRadScriptPackage);
    function LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
    /// Aktif paketlerin bu addaki kaynakları, paket.sira sırasıyla; PackageId dolu. Sahiplik çağırana.
    function ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>;
    /// Verilen paketlerin aktif `kutuphane` ve `pencere` script'leri (paket, sıra). Boş liste → boş.
    function LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
    /// Verilen paketlerin parametreleri (facade Param için). Sahiplik çağırana.
    function ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>;
  end;

  /// Saf DDL metni; bağlantı yok, birim test edilir.
  TRadScriptDdl = class
  public const
    PackageTable = 'script_paket';
    ScriptTable = 'script';
    ParamTable = 'script_parametre';
    DbTable = 'script_db';
    ResourceTable = 'script_kaynak';
  public
    /// Yaratma sırasında (FK'ler için).
    class function TableNames: TArray<string>; static;
    class function CreateDefinitionTables(ADialect: TRadSqlDialect): TArray<string>; static;
  end;

  /// Tek dosya .radpaket = JSON; kaynaklar base64.
  TRadScriptPackageFile = class
  public const
    FormatVersion = 1;
    FileExt = '.radpaket';
  public
    class function ExportPackage(APkg: TRadScriptPackage): RawUtf8; static;
    /// Id'ler 0, Applied=False. Biçim/doğrulama hatası: ERadScriptFormat.
    class function ImportPackage(const AJson: RawUtf8): TRadScriptPackage; static;
    class procedure SaveToFile(APkg: TRadScriptPackage; const AFileName: string); static;
    class function LoadFromFile(const AFileName: string): TRadScriptPackage; static;
  end;

implementation

uses
  System.Character, System.Variants, mormot.core.unicode;

const
  KIND_CODES: array[TRadScriptKind] of string = ('form', 'olay', 'zaman', 'komut', 'kutuphane', 'pencere');
  WINDOW_DIRECTIVE = '{$FORM';   // TMS: {$FORM TAdForm, ad.dfm}
  MAX_CODE_LEN = 50;
  MAX_NAME_LEN = 100;
  MAX_FILE_LEN = 100;

resourcestring
  SErrScriptCode = 'Script kodu geçersiz: "%s" (tanımlayıcı, en çok 50 karakter).';
  SErrScriptName = 'Script adı boş olamaz.';
  SErrScriptSource = 'Script kaynağı boş olamaz.';
  SErrTargetClass = 'Hedef sınıf adı geçersiz: "%s".';
  SErrTargetEvent = 'Olay adı boş olamaz.';
  SErrTargetSchedule = 'Zaman maskesi geçersiz: "%s".';
  SErrTargetLibrary = 'Kütüphane script''inin hedefi boş olmalı.';
  SErrTargetWindow = 'Pencere script''inin hedefi boş olmalı.';
  SErrWindowDirective = 'Pencere script''i {$FORM TAdForm, %s} yönergesi içermeli: "%s".';
  SErrWindowDfm = 'Pencere script''i "%s" için pakette "%s" kaynağı yok.';
  SErrPackageCode = 'Paket kodu geçersiz: "%s".';
  SErrPackageName = 'Paket adı boş olamaz.';
  SErrPackageVersion = 'Paket sürümü boş olamaz.';
  SErrDupScript = 'Script kodu tekrar ediyor: "%s".';
  SErrDupParam = 'Parametre adı tekrar ediyor: "%s".';
  SErrDupStep = 'DB adımı sırası tekrar ediyor: %d.';
  SErrDupResource = 'Kaynak dosya adı tekrar ediyor: "%s".';
  SErrParamName = 'Parametre adı geçersiz: "%s".';
  SErrStepSql = 'DB adımı %d: SQL boş.';
  SErrResourceName = 'Kaynak dosya adı geçersiz: "%s".';
  SErrFormat = 'Paket dosyası okunamadı: %s';
  SErrFormatVersion = 'Paket dosyası biçimi %d desteklenmiyor (en çok %d).';
  SErrFormatKind = 'Bilinmeyen script türü: "%s".';

{ ERadScriptExec }

constructor ERadScriptExec.Create(const AScriptCode: string; ALine, ACol: Integer; const AMsg: string);
begin
  FScriptCode := AScriptCode;
  FLine := ALine;
  FCol := ACol;
  if AScriptCode = '' then inherited Create(AMsg)
  else if ALine > 0 then inherited CreateFmt('%s [%s %d:%d]', [AMsg, AScriptCode, ALine, ACol])
  else inherited CreateFmt('%s [%s]', [AMsg, AScriptCode]);
end;

{ TRadScript }

constructor TRadScript.Create;
begin
  inherited Create;
  FActive := True;
end;

class function TRadScript.KindCodeOf(AKind: TRadScriptKind): string;
begin
  Result := KIND_CODES[AKind];
end;

class function TRadScript.KindOfCode(const ACode: string; out AKind: TRadScriptKind): Boolean;
var
  K: TRadScriptKind;
begin
  for K := Low(TRadScriptKind) to High(TRadScriptKind) do
    if SameText(KIND_CODES[K], ACode) then
    begin
      AKind := K;
      Exit(True);
    end;
  Result := False;
end;

class function TRadScript.IsValidIdentifier(const AText: string): Boolean;
var
  i: Integer;
begin
  Result := (AText <> '') and (Length(AText) <= MAX_CODE_LEN) and
    (AText[1].IsLetter or (AText[1] = '_')) and (Ord(AText[1]) < 128);
  if not Result then Exit;
  for i := 2 to Length(AText) do
    if not ((AText[i].IsLetterOrDigit or (AText[i] = '_')) and (Ord(AText[i]) < 128)) then
      Exit(False);
end;

function TRadScript.KindCode: string;
begin
  Result := KIND_CODES[FKind];
end;

function TRadScript.Validate: string;
var
  LSched: TDtSchedule;
begin
  if not IsValidIdentifier(FCode) then Exit(Format(SErrScriptCode, [FCode]));
  if System.SysUtils.Trim(FName) = '' then Exit(SErrScriptName);
  if System.SysUtils.Trim(FSource) = '' then Exit(SErrScriptSource);
  case FKind of
    skForm, skCommand:
      if not IsValidIdentifier(FTarget) then Exit(Format(SErrTargetClass, [FTarget]));
    skEvent:
      if System.SysUtils.Trim(FTarget) = '' then Exit(SErrTargetEvent);
    skSchedule:
      try
        LSched.SetAsString(FTarget);
      except
        on E: Exception do Exit(Format(SErrTargetSchedule, [FTarget]));
      end;
    skLibrary:
      if System.SysUtils.Trim(FTarget) <> '' then Exit(SErrTargetLibrary);
    skWindow:
      begin
        if System.SysUtils.Trim(FTarget) <> '' then Exit(SErrTargetWindow);
        if System.Pos(WINDOW_DIRECTIVE, System.SysUtils.UpperCase(FSource)) = 0 then Exit(Format(SErrWindowDirective, [DfmFileName, FCode]));
      end;
  end;
  Result := '';
end;

function TRadScript.DfmFileName: string;
begin
  Result := FCode + '.dfm';
end;

procedure TRadScript.Assign(ASource: TRadScript);
begin
  FId := ASource.FId;
  FPackageId := ASource.FPackageId;
  FCode := ASource.FCode;
  FName := ASource.FName;
  FKind := ASource.FKind;
  FTarget := ASource.FTarget;
  FOrder := ASource.FOrder;
  FActive := ASource.FActive;
  FSource := ASource.FSource;
  FModified := ASource.FModified;
end;

{ TRadScriptPackage }

constructor TRadScriptPackage.Create;
begin
  inherited Create;
  FActive := True;
  FVersion := '1.0.0';
  FScripts := TRadScripts.Create(True);
  FParams := TObjectList<TRadScriptParam>.Create(True);
  FDbSteps := TObjectList<TRadScriptDbStep>.Create(True);
  FResources := TObjectList<TRadScriptResource>.Create(True);
end;

destructor TRadScriptPackage.Destroy;
begin
  FResources.Free;
  FDbSteps.Free;
  FParams.Free;
  FScripts.Free;
  inherited;
end;

class function TRadScriptPackage.IsValidCode(const ACode: string): Boolean;
var
  i: Integer;
  C: Char;
begin
  Result := (Length(ACode) >= 2) and (Length(ACode) <= MAX_CODE_LEN);
  if not Result then Exit;
  for i := 1 to Length(ACode) do
  begin
    C := ACode[i];
    if not (CharInSet(C, ['a'..'z', '0'..'9']) or ((i > 1) and CharInSet(C, ['.', '-']))) then
      Exit(False);
  end;
end;

function TRadScriptPackage.Validate: string;
var
  i, j: Integer;
  LErr: string;
begin
  if not IsValidCode(FCode) then Exit(Format(SErrPackageCode, [FCode]));
  if System.SysUtils.Trim(FName) = '' then Exit(SErrPackageName);
  if System.SysUtils.Trim(FVersion) = '' then Exit(SErrPackageVersion);
  for i := 0 to FScripts.Count - 1 do
  begin
    LErr := FScripts[i].Validate;
    if LErr <> '' then Exit(LErr);
    if (FScripts[i].Kind = skWindow) and (ResourceByName(FScripts[i].DfmFileName) = nil) then
      Exit(Format(SErrWindowDfm, [FScripts[i].Code, FScripts[i].DfmFileName]));
    for j := 0 to i - 1 do
      if SameText(FScripts[j].Code, FScripts[i].Code) then Exit(Format(SErrDupScript, [FScripts[i].Code]));
  end;
  for i := 0 to FParams.Count - 1 do
  begin
    if not TRadScript.IsValidIdentifier(FParams[i].Name) then Exit(Format(SErrParamName, [FParams[i].Name]));
    for j := 0 to i - 1 do
      if SameText(FParams[j].Name, FParams[i].Name) then Exit(Format(SErrDupParam, [FParams[i].Name]));
  end;
  for i := 0 to FDbSteps.Count - 1 do
  begin
    if System.SysUtils.Trim(FDbSteps[i].Sql) = '' then Exit(Format(SErrStepSql, [FDbSteps[i].Order]));
    for j := 0 to i - 1 do
      if FDbSteps[j].Order = FDbSteps[i].Order then Exit(Format(SErrDupStep, [FDbSteps[i].Order]));
  end;
  for i := 0 to FResources.Count - 1 do
  begin
    if (System.SysUtils.Trim(FResources[i].FileName) = '') or (Length(FResources[i].FileName) > MAX_FILE_LEN) or
       (FResources[i].FileName <> ExtractFileName(FResources[i].FileName)) then
      Exit(Format(SErrResourceName, [FResources[i].FileName]));
    for j := 0 to i - 1 do
      if SameText(FResources[j].FileName, FResources[i].FileName) then
        Exit(Format(SErrDupResource, [FResources[i].FileName]));
  end;
  Result := '';
end;

function TRadScriptPackage.ScriptByCode(const ACode: string): TRadScript;
var
  S: TRadScript;
begin
  for S in FScripts do
    if SameText(S.Code, ACode) then Exit(S);
  Result := nil;
end;

function TRadScriptPackage.ParamByName(const AName: string): TRadScriptParam;
var
  P: TRadScriptParam;
begin
  for P in FParams do
    if SameText(P.Name, AName) then Exit(P);
  Result := nil;
end;

function TRadScriptPackage.ParamValue(const AName, ADefault: string): string;
var
  P: TRadScriptParam;
begin
  P := ParamByName(AName);
  if P = nil then Result := ADefault else Result := P.Value;
end;

function TRadScriptPackage.ResourceByName(const AFileName: string): TRadScriptResource;
var
  R: TRadScriptResource;
begin
  for R in FResources do
    if SameText(R.FileName, AFileName) then Exit(R);
  Result := nil;
end;

function TRadScriptPackage.AddScript(const ACode: string; AKind: TRadScriptKind;
  const ATarget, ASource: string): TRadScript;
begin
  Result := TRadScript.Create;
  Result.Code := ACode;
  Result.Name := ACode;
  Result.Kind := AKind;
  Result.Target := ATarget;
  Result.Source := ASource;
  Result.Order := FScripts.Count;
  FScripts.Add(Result);
end;

function TRadScriptPackage.AddParam(const AName, AValue: string): TRadScriptParam;
begin
  Result := TRadScriptParam.Create;
  Result.Name := AName;
  Result.Value := AValue;
  FParams.Add(Result);
end;

function TRadScriptPackage.AddDbStep(AOrder: Integer; const ASql: string): TRadScriptDbStep;
begin
  Result := TRadScriptDbStep.Create;
  Result.Order := AOrder;
  Result.Sql := ASql;
  FDbSteps.Add(Result);
end;

function TRadScriptPackage.AddResource(const AFileName: string; const AContent: TBytes): TRadScriptResource;
begin
  Result := TRadScriptResource.Create;
  Result.FileName := AFileName;
  Result.Content := AContent;
  FResources.Add(Result);
end;

{ TRadScriptDdl }

class function TRadScriptDdl.TableNames: TArray<string>;
begin
  Result := [PackageTable, ScriptTable, ParamTable, DbTable, ResourceTable];
end;

class function TRadScriptDdl.CreateDefinitionTables(ADialect: TRadSqlDialect): TArray<string>;
const
  ID_: array[TRadSqlDialect] of string = (
    'integer generated by default as identity primary key',
    'int identity(1,1) primary key',
    'int auto_increment primary key',
    'integer generated by default as identity primary key');
  VC_: array[TRadSqlDialect] of string = ('varchar', 'nvarchar', 'varchar', 'varchar');
  MEMO_: array[TRadSqlDialect] of string = ('text', 'nvarchar(max)', 'text', 'blob sub_type text');
  BOOL_: array[TRadSqlDialect] of string = ('boolean', 'bit', 'tinyint(1)', 'boolean');
  TS_: array[TRadSqlDialect] of string = ('timestamp', 'datetime2', 'datetime', 'timestamp');
  BLOB_: array[TRadSqlDialect] of string = ('bytea', 'varbinary(max)', 'longblob', 'blob');
  TRUE_: array[TRadSqlDialect] of string = ('true', '1', '1', 'true');
  FALSE_: array[TRadSqlDialect] of string = ('false', '0', '0', 'false');
var
  V, B, T, F, FK: string;
begin
  V := VC_[ADialect];
  B := BOOL_[ADialect];
  T := TRUE_[ADialect];
  F := FALSE_[ADialect];
  FK := 'paket_id integer not null, ';
  Result := [
    Format('create table %0:s (id %1:s, kod %2:s(50) not null, adi %2:s(100) not null, aciklama %2:s(500), ' +
      'surum %2:s(20) not null, yazar %2:s(100), aktif_mi %3:s default %4:s not null, ' +
      'korumali_mi %3:s default %5:s not null, sira integer default 0 not null, ' +
      'olusturma_zamani %6:s, degisim_zamani %6:s, constraint uq_%0:s unique (kod))',
      [PackageTable, ID_[ADialect], V, B, T, F, TS_[ADialect]]),
    Format('create table %0:s (id %1:s, %2:skod %3:s(50) not null, adi %3:s(100) not null, ' +
      'tur %3:s(10) not null, hedef %3:s(200) not null, sira integer default 0 not null, ' +
      'aktif_mi %4:s default %5:s not null, kaynak %6:s not null, degisim_zamani %7:s, ' +
      'constraint uq_%0:s unique (paket_id, kod), ' +
      'constraint fk_%0:s_paket foreign key (paket_id) references %8:s (id) on delete cascade)',
      [ScriptTable, ID_[ADialect], FK, V, B, T, MEMO_[ADialect], TS_[ADialect], PackageTable]),
    Format('create table %0:s (id %1:s, %2:sadi %3:s(50) not null, deger %3:s(1000), aciklama %3:s(200), ' +
      'constraint uq_%0:s unique (paket_id, adi), ' +
      'constraint fk_%0:s_paket foreign key (paket_id) references %4:s (id) on delete cascade)',
      [ParamTable, ID_[ADialect], FK, V, PackageTable]),
    Format('create table %0:s (id %1:s, %2:ssira integer not null, aciklama %3:s(200), sql_metni %4:s not null, ' +
      'uygulandi_mi %5:s default %6:s not null, uygulama_zamani %7:s, ' +
      'constraint uq_%0:s unique (paket_id, sira), ' +
      'constraint fk_%0:s_paket foreign key (paket_id) references %8:s (id) on delete cascade)',
      [DbTable, ID_[ADialect], FK, V, MEMO_[ADialect], B, F, TS_[ADialect], PackageTable]),
    Format('create table %0:s (id %1:s, %2:sdosya_adi %3:s(100) not null, icerik %4:s, ' +
      'constraint uq_%0:s unique (paket_id, dosya_adi), ' +
      'constraint fk_%0:s_paket foreign key (paket_id) references %5:s (id) on delete cascade)',
      [ResourceTable, ID_[ADialect], FK, V, BLOB_[ADialect], PackageTable])];
end;

{ TRadScriptPackageFile }

class function TRadScriptPackageFile.ExportPackage(APkg: TRadScriptPackage): RawUtf8;
var
  LDoc, LItem, LPkg: IDocDict;
  LList: IDocList;
  S: TRadScript;
  P: TRadScriptParam;
  D: TRadScriptDbStep;
  R: TRadScriptResource;
begin
  LDoc := DocDict;
  LDoc.I['format'] := FormatVersion;
  LPkg := DocDict;
  LPkg.S['kod'] := APkg.Code;
  LPkg.S['adi'] := APkg.Name;
  LPkg.S['aciklama'] := APkg.Description;
  LPkg.S['surum'] := APkg.Version;
  LPkg.S['yazar'] := APkg.Author;
  LPkg.B['aktif_mi'] := APkg.Active;
  LPkg.B['korumali_mi'] := APkg.IsProtected;
  LPkg.I['sira'] := APkg.Order;
  LDoc.D['paket'] := LPkg;
  LList := DocList;
  for S in APkg.Scripts do
  begin
    LItem := DocDict;
    LItem.S['kod'] := S.Code;
    LItem.S['adi'] := S.Name;
    LItem.S['tur'] := S.KindCode;
    LItem.S['hedef'] := S.Target;
    LItem.I['sira'] := S.Order;
    LItem.B['aktif_mi'] := S.Active;
    LItem.S['kaynak'] := S.Source;
    LList.AppendDoc(LItem);
  end;
  LDoc.L['scriptler'] := LList;
  LList := DocList;
  for P in APkg.Params do
  begin
    LItem := DocDict;
    LItem.S['adi'] := P.Name;
    LItem.S['deger'] := P.Value;
    LItem.S['aciklama'] := P.Description;
    LList.AppendDoc(LItem);
  end;
  LDoc.L['parametreler'] := LList;
  LList := DocList;
  for D in APkg.DbSteps do
  begin
    LItem := DocDict;
    LItem.I['sira'] := D.Order;
    LItem.S['aciklama'] := D.Description;
    LItem.S['sql'] := D.Sql;
    LList.AppendDoc(LItem);
  end;
  LDoc.L['db'] := LList;
  LList := DocList;
  for R in APkg.Resources do
  begin
    LItem := DocDict;
    LItem.S['dosya_adi'] := R.FileName;
    LItem.U['icerik'] := BinToBase64(PAnsiChar(Pointer(R.Content)), Length(R.Content));
    LList.AppendDoc(LItem);
  end;
  LDoc.L['kaynaklar'] := LList;
  Result := LDoc.ToJson(jsonHumanReadable);
end;

// Eksik anahtar hata değil, varsayılan: dosya elle yazılabilir.
function DefS(const D: IDocDict; const K: RawUtf8): string;
begin
  Result := VarToStr(D.GetDef(K, ''));
end;

function DefU(const D: IDocDict; const K: RawUtf8): RawUtf8;
begin
  Result := StringToUtf8(DefS(D, K));
end;

function DefI(const D: IDocDict; const K: RawUtf8): Integer;
begin
  Result := D.GetDef(K, 0);
end;

function DefB(const D: IDocDict; const K: RawUtf8; ADefault: Boolean): Boolean;
begin
  Result := D.GetDef(K, ADefault);
end;

class function TRadScriptPackageFile.ImportPackage(const AJson: RawUtf8): TRadScriptPackage;
var
  LDoc, LItem, LPkg: IDocDict;
  LList: IDocList;
  i: Integer;
  LKind: TRadScriptKind;
  LScript: TRadScript;
  LRaw: RawByteString;
  LBytes: TBytes;
  LErr, LKindCode: string;
begin
  try
    LDoc := DocDict(AJson);
  except
    on E: Exception do raise ERadScriptFormat.CreateFmt(SErrFormat, [E.Message]);
  end;
  if (LDoc.Kind <> dvObject) or not LDoc.Exists('format') or not LDoc.Exists('paket') then
    raise ERadScriptFormat.CreateFmt(SErrFormat, ['format/paket yok']);
  if LDoc.I['format'] > FormatVersion then
    raise ERadScriptFormat.CreateFmt(SErrFormatVersion, [LDoc.I['format'], FormatVersion]);
  Result := TRadScriptPackage.Create;
  try
    LPkg := LDoc.D['paket'];
    Result.Code := DefS(LPkg, 'kod');
    Result.Name := DefS(LPkg, 'adi');
    Result.Description := DefS(LPkg, 'aciklama');
    Result.Version := DefS(LPkg, 'surum');
    Result.Author := DefS(LPkg, 'yazar');
    Result.Active := DefB(LPkg, 'aktif_mi', True);
    Result.IsProtected := DefB(LPkg, 'korumali_mi', False);
    Result.Order := DefI(LPkg, 'sira');
    if LDoc.Get('scriptler', LList) then
      for i := 0 to LList.Len - 1 do
      begin
        LItem := LList.D[i];
        LKindCode := DefS(LItem, 'tur');
        if not TRadScript.KindOfCode(LKindCode, LKind) then
          raise ERadScriptFormat.CreateFmt(SErrFormatKind, [LKindCode]);
        LScript := Result.AddScript(DefS(LItem, 'kod'), LKind, DefS(LItem, 'hedef'), DefS(LItem, 'kaynak'));
        LScript.Name := DefS(LItem, 'adi');
        LScript.Order := DefI(LItem, 'sira');
        LScript.Active := DefB(LItem, 'aktif_mi', True);
      end;
    if LDoc.Get('parametreler', LList) then
      for i := 0 to LList.Len - 1 do
      begin
        LItem := LList.D[i];
        Result.AddParam(DefS(LItem, 'adi'), DefS(LItem, 'deger')).Description := DefS(LItem, 'aciklama');
      end;
    if LDoc.Get('db', LList) then
      for i := 0 to LList.Len - 1 do
      begin
        LItem := LList.D[i];
        Result.AddDbStep(DefI(LItem, 'sira'), DefS(LItem, 'sql')).Description := DefS(LItem, 'aciklama');
      end;
    if LDoc.Get('kaynaklar', LList) then
      for i := 0 to LList.Len - 1 do
      begin
        LItem := LList.D[i];
        LRaw := '';
        if (DefU(LItem, 'icerik') <> '') and
           not Base64ToBin(PAnsiChar(Pointer(DefU(LItem, 'icerik'))), Length(DefU(LItem, 'icerik')), LRaw) then
          raise ERadScriptFormat.CreateFmt(SErrFormat, ['base64: ' + DefS(LItem, 'dosya_adi')]);
        SetLength(LBytes, Length(LRaw));
        if LRaw <> '' then Move(Pointer(LRaw)^, LBytes[0], Length(LRaw));
        Result.AddResource(DefS(LItem, 'dosya_adi'), LBytes);
      end;
    LErr := Result.Validate;
    if LErr <> '' then
      raise ERadScriptFormat.Create(LErr);
  except
    on E: Exception do
    begin
      Result.Free;
      if E is EDocVariant then
        raise ERadScriptFormat.CreateFmt(SErrFormat, [E.Message]);
      raise;
    end;
  end;
end;

class procedure TRadScriptPackageFile.SaveToFile(APkg: TRadScriptPackage; const AFileName: string);
var
  LJson: RawUtf8;
  LStream: TFileStream;
begin
  LJson := ExportPackage(APkg);
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if LJson <> '' then LStream.WriteBuffer(Pointer(LJson)^, Length(LJson));
  finally
    LStream.Free;
  end;
end;

class function TRadScriptPackageFile.LoadFromFile(const AFileName: string): TRadScriptPackage;
var
  LJson: RawUtf8;
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LJson, LStream.Size);
    if LJson <> '' then LStream.ReadBuffer(Pointer(LJson)^, Length(LJson));
  finally
    LStream.Free;
  end;
  Result := ImportPackage(LJson);
end;

end.
