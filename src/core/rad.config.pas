unit rad.config;

interface

uses
  System.SysUtils,
  System.Classes, System.Rtti,
  mormot.core.base,mormot.core.variants, mormot.core.json, mormot.core.fmt

  ,mormot.core.rtti
  ,rad.core;

type

  /// <summary>Yapilandirma katmani hatalari. Ortak ata: rad.core'daki ERadCore.</summary>
  ERadConfig = class(ERadCore);

  TRadOptions = class(TSynAutoCreateFields)
  end;


  TRadConfig = class(TSynAutoCreateFields)//class(TAbstractLockable,IRadConfig)
  class var Config :TRadConfig;
  strict private
    FJson   : IDocDict;
    FSafe   : TRadLock;
  private
    fSectionName: RawUtf8;
    fFileName: TFileName;
    fSettingsOptions: TSynJsonFileSettingsOptions;
    fCurrentHash: cardinal;
    // could be overriden to validate the content coherency and/or clean fields



   function GetFileName: TFileName;
   procedure SetFileName(const Value: TFileName);
   function AfterLoad(const aText: RawUtf8): boolean;

    function LoadFromYamlText(const aYaml: RawUtf8): boolean;
    function LoadFromIniText(const aIni, aSectionName: RawUtf8): boolean;
    function LoadFromJsonText(const aJson: RawUtf8): boolean;
    function LoadFromText(const aContent: RawUtf8; const aSectionName: RawUtf8 = 'Main'): boolean;
  public
   //constructor Create(const AThreadSafe: Boolean = True); reintroduce; virtual;
   constructor Create; override;
   destructor Destroy; override;

   function LoadFromFile(const aFileName: TFileName; const aSectionName: string='Main'): boolean;  overload;
   /// <summary>Anlik goruntu: uzerine yazilan degisiklik KAYBOLUR; yazmak icin SetV/SetValue,
   /// kayit icin RecordSave. Veri bu kopyada "Root" altindadir; anahtar ust duzeyde aranmaz.</summary>
   function Json: IDocDict;
   /// <summary>AKey altindaki nesneyi ARec'e okur (kilitli). Anahtar yoksa False, ARec degismez.</summary>
   function RecordLoad<T>(const AKey: string; var ARec: T): Boolean;
   /// <summary>ARec'i AKey altina yazar (kilitli). Dosyaya yazmak icin ardindan SaveIfNeeded.</summary>
   function RecordSave<T>(const AKey: string; var ARec: T): Boolean;


   function FolderName: TFileName;
   function SaveIfNeeded: boolean;
   //function SaveIfNeeded: boolean; virtual;
   property FileName: TFileName read GetFileName write SetFileName;


   function GetValue(const aKey:string; const aDefault:Variant):Variant; overload;
   function Get(const aKey:string; const aDefault:string):string; overload;
   function Get(const aKey:string; const aDefault:Integer):Integer; overload;
   function Get(const aKey:string; const aDefault:Int64):Int64; overload;
   function Get(const aKey:string; const aDefault:Boolean):Boolean; overload;
   function Get(const aKey:string; const aDefault:Double):Double; overload;
   function GetDateTime(const aKey:string; const aDefault:TDateTime):TDateTime;




   function SetJson(const aKey:string; const v:string):TRadConfig;
   function SetValue(const aKey:string; const v:Variant):TRadConfig; overload;
   function SetV(const aKey:string; const v:string):TRadConfig; overload;
   function SetV(const aKey:string; const v:Int64):TRadConfig; overload;
   function SetV(const aKey:string; const v:Double):TRadConfig; overload;
   function SetV(const aKey:string; const v:TDateTime):TRadConfig; overload;
   function SetV(const aKey:string; const v:TObject):TRadConfig; overload;

  published
   property Root: IDocDict read FJson write FJson;
  end;

//function NewConfig(const AFileName: string = ''; const ADefaults: string = '{}'): IRadConfig;

implementation

uses
  System.IOUtils,
  help.mormot,
  System.Variants,       // VarIsEmpty / VarIsNull / VarToStr
  mormot.core.os,
  mormot.core.unicode,
  mormot.core.text,
  mormot.core.datetime,
  mormot.core.buffers,
  mormot.core.data;   // StringToUtf8 / Utf8ToString




{ TRadConfig }

function TRadConfig.AfterLoad(const aText: RawUtf8): boolean;
begin
  fCurrentHash := DefaultHashTrim(aText);
  result := true; // success

end;

constructor TRadConfig.Create;
begin
  inherited;
  FSafe.Init(True);
  FJson    := DocDict('{}');
  SetFileName(ChangeFileExt(ParamStr(0),'.setting.json'));
end;

destructor TRadConfig.Destroy;
begin
  //SaveIfNeeded;
  FJson :=nil;
  inherited;
end;

function TRadConfig.FolderName: TFileName;
begin
  if self = nil then
    result := ''
  else
    result := ExtractFilePath(fFileName);
end;

function TRadConfig.Get(const aKey: string; const aDefault: Double): Double;
begin
 try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.Get(const aKey: string; const aDefault: Integer): Integer;
begin
 try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.Get(const aKey: string; const aDefault: Boolean): Boolean;
begin
 try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.Get(const aKey: string; const aDefault: Int64): Int64;
begin
 try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.Get(const aKey, aDefault: string): string;
begin
 try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.GetDateTime(const aKey: string; const aDefault: TDateTime): TDateTime;
begin
  try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.GetValue(const aKey: string; const aDefault: Variant): Variant;
begin
  FSafe.ReadLock;
  try
   try
   Result :=FJson.GetDef(StringToUtf8(aKey),aDefault);
   if VarIsEmpty(Result) or VarIsNull(Result) then
    Result := aDefault;
   except
    Result :=aDefault;
   end;
  finally
   FSafe.ReadUnlock;
  end;
end;


function TRadConfig.GetFileName: TFileName;
begin
 Result:=fFileName;
end;


function TRadConfig.Json: IDocDict;
begin
  FSafe.ReadLock;
  try
    Result :=DocDict(ObjectToJson(self));
    //Result.Merge(FJson);
  finally
   FSafe.ReadUnlock;
  end;


end;




function TRadConfig.LoadFromFile(const aFileName: TFileName; const aSectionName: string): boolean;
var
 text: RawUtf8;
begin

  fCurrentHash := 0;
  fFileName := aFileName;
  text := RawUtf8FromFile(aFileName); // may detect BOM
  if text = '' then
    Exit(False);
 FSafe.WriteLock;
 try
   //Result := LoadFromFile(aFileName,StringToUtf8(aSectionName));

    case SameExt(aFileName,
        ['yaml', 'yml', 'ini', 'json', 'jsonc', 'json5', 'hjson'], true) of
      0, 1: result := LoadFromYamlText(text);
      { StringToUtf8 ACIKCA: ortulu string -> UTF8String donusumu ANSI kod
        sayfasindan gecer ve Turkce bolum adinda karakter kaybettirir (W1057). }
      2   : result := LoadFromIniText(text, StringToUtf8(aSectionName));
      3..6: result := LoadFromJsonText(text); // JsonSettingsToObject supports those
    else
      result := LoadFromText(text, StringToUtf8(aSectionName)); // detect JSON or INI
    end;

 finally
  FSafe.WriteUnlock;
 end;

end;


function TRadConfig.LoadFromIniText(const aIni, aSectionName: RawUtf8): boolean;
begin
  fSectionName := aSectionName; // to be used when writing
  result := IniToObject(aIni, self, aSectionName, @JSON_[mFastFloat], 0, [ifClassSection, ifClassValue, ifMultiLineSections, ifArraySection, ifMultiLineJsonArray, ifClearValues]);
  if not result then
    exit;
  include(fSettingsOptions, fsoWriteIni); // save back as INI
  result := AfterLoad(aIni);
end;

function TRadConfig.LoadFromJsonText(const aJson: RawUtf8): boolean;
begin
  result := JsonSettingsToObject(aJson, self) and AfterLoad(aJson);
end;

function TRadConfig.LoadFromText(const aContent, aSectionName: RawUtf8): boolean;
begin
  if fsoReadIni in fSettingsOptions then
  begin
    result := LoadFromIniText(aContent, aSectionName); // only INI
    include(fSettingsOptions, fsoWriteIni); // save back as INI
  end
  else
    result := LoadFromJsonText(aContent) or
              LoadFromIniText(aContent, aSectionName); // fallback to INI
end;

function TRadConfig.LoadFromYamlText(const aYaml: RawUtf8): boolean;
var
  json: RawUtf8;
begin
  result := TryYamlToJson(aYaml, json) and
            JsonSettingsToObject(json, self);
  if not result then
    exit;
  include(fSettingsOptions, fsoWriteYaml); // save back as YAML
  result := AfterLoad(aYaml);

end;



function TRadConfig.SaveIfNeeded: boolean;
var
  saved: RawUtf8;
  opt: TTextWriterWriteObjectOptions;
  LHash:Cardinal;
begin
  result := false;
  if (self = nil) or (fFileName = '') or (fsoDisableSaveIfNeeded in fSettingsOptions) then
    exit;
  FSafe.WriteLock;
  try

  opt := SETTINGS_WRITEOPTIONS;
  if fSettingsOptions * [fsoNoEnumsComment, fsoWriteYaml, fsoWriteIni] <> [] then
    exclude(opt, woHumanReadableEnumSetAsComment);
  if fsoWriteIni in fSettingsOptions then
    saved := ObjectToIni(self, fSectionName, opt, 0,
    [ifClassSection, ifClassValue, ifMultiLineSections, ifArraySection, ifMultiLineJsonArray, ifClearValues])
  else
  begin

    //Json.Merge(DocDict(ObjectToJson(self, opt)));

    saved:=ObjectToJson(self,opt);

    if fsoWriteYaml in fSettingsOptions then
      saved := JsonToYaml(saved)
    else if fsoWriteHjson in fSettingsOptions then
      saved := JsonReformat(saved, jsonH); // very human friendly
  end;
   LHash :=DefaultHashTrim(saved);
  if fCurrentHash = LHash then
    exit; // don't rewrite the same content on disk
  result := FileFromString(saved, fFileName);
  if not result then
    exit;

  fCurrentHash := LHash;

  finally
   FSafe.WriteUnlock;
  end;
end;

procedure TRadConfig.SetFileName(const Value: TFileName);
begin
fFileName := Value;
if FileExists(Value) and (TFile.GetSize(Value) > 0) and not LoadFromFile(Value) then
begin
  { Destroy kaydetmesin: bozuk dosyanin uzerine varsayilanlar yazilirdi. }
  include(fSettingsOptions, fsoDisableSaveIfNeeded);
  raise ERadConfig.CreateFmt('Ayar dosyasi okunamadi: %s', [Value]);
end;
end;

function TRadConfig.RecordLoad<T>(const AKey: string; var ARec: T): Boolean;
begin
  FSafe.ReadLock;
  try
    Result := FJson.Value._RecordLoad<T>(AKey, ARec);
  finally
    FSafe.ReadUnlock;
  end;
end;

function TRadConfig.RecordSave<T>(const AKey: string; var ARec: T): Boolean;
begin
  FSafe.WriteLock;
  try
    Result := FJson.Value._RecordSave<T>(AKey, ARec);
  finally
    FSafe.WriteUnlock;
  end;
end;

function TRadConfig.SetJson(const aKey, v: string): TRadConfig;
begin
 Result := Self;
 FSafe.WriteLock;
 try
  FJson.O[StringToUtf8(aKey)]:=DocDict(StringToUtf8(v));
 finally
  FSafe.WriteUnlock;
 end;
end;

function TRadConfig.SetV(const aKey: string; const v: Double): TRadConfig;
begin
  Result := SetValue(aKey,v);
end;

function TRadConfig.SetV(const aKey: string; const v: Int64): TRadConfig;
begin
 Result := SetValue(aKey,v);
end;

function TRadConfig.SetV(const aKey, v: string): TRadConfig;
begin
 Result := SetValue(aKey,v);
end;

function TRadConfig.SetValue(const aKey: string; const v: Variant): TRadConfig;
begin
 Result := Self;
 FSafe.WriteLock;
 try
  FJson.Item[StringToUtf8(aKey)]:=v;
  //FJson.Merge(StringToUtf8(aKey),v);
 finally
  FSafe.WriteUnlock;
 end;
end;

function TRadConfig.SetV(const aKey: string; const v: TDateTime): TRadConfig;
begin
  Result := SetValue(aKey,v);
end;

function TRadConfig.SetV(const aKey: string; const v: TObject): TRadConfig;
begin
  Result := SetValue(aKey,ObjectToVariant(v,True));

end;


initialization
finalization
  FreeAndNil(TRadConfig.Config);

end.
