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



  IRadConfig = interface (ILockable)
    ['{7B2E4A61-9C3D-4F58-8A17-6D0B5E9C4A22}']

    function LoadFromFile(const aFileName: TFileName; const aSectionName: string): boolean;
    function Json: IDocObject;
    function FolderName: TFileName;
    function SaveIfNeeded: boolean;
    function GetFileName: TFileName;
    procedure SetFileName(const Value: TFileName);



    function GetValue(const aKey:string; const aDefault:Variant):Variant; overload;
    function Get(const aKey:string; const aDefault:string =''):string; overload;
    function Get(const aKey:string; const aDefault:Int64 =0):Int64; overload;
    function Get(const aKey:string; const aDefault:Double =0):Double; overload;
    function Get(const aKey:string; const aDefault:TDateTime =0):TDateTime; overload;




    function SetJson(const aKey:string; const v:string):IRadConfig;
    function SetValue(const aKey:string; const v:Variant):IRadConfig; overload;
    function SetV(const aKey:string; const v:string):IRadConfig; overload;
    function SetV(const aKey:string; const v:Int64):IRadConfig; overload;
    function SetV(const aKey:string; const v:Double):IRadConfig; overload;
    function SetV(const aKey:string; const v:TDateTime):IRadConfig; overload;
    function SetV(const aKey:string; const v:TObject):IRadConfig; overload;



  end;

  TRadConfig = class(TAbstractLockable,IRadConfig)
  class var Config :IRadConfig;
  private
    fCurrentContent, fSectionName: RawUtf8;
    fFileName: TFileName;
    fSettingsOptions: TSynJsonFileSettingsOptions;
    fCurrentHash: cardinal;
    // could be overriden to validate the content coherency and/or clean fields

   FJson    : IDocDict;


   function GetFileName: TFileName;
   procedure SetFileName(const Value: TFileName);
   function AfterLoad(const aText: RawUtf8): boolean; virtual;

    function LoadFromYamlText(const aYaml: RawUtf8): boolean;
    function LoadFromIniText(const aIni, aSectionName: RawUtf8): boolean;
    function LoadFromJsonText(const aJson: RawUtf8): boolean;
    function LoadFromText(const aContent: RawUtf8; const aSectionName: RawUtf8 = 'Main'): boolean;
  public
   //constructor Create(const AThreadSafe: Boolean = True); reintroduce; virtual;
   constructor Create; override;
   destructor Destroy; override;

   function LoadFromFile(const aFileName: TFileName; const aSectionName: string='Main'): boolean;  overload;
   function Json: IDocDict;

   function FolderName: TFileName;
   function SaveIfNeeded: boolean;
   //function SaveIfNeeded: boolean; virtual;
   property FileName: TFileName read GetFileName write SetFileName;


   function GetValue(const aKey:string; const aDefault:Variant):Variant; overload;
   function Get(const aKey:string; const aDefault:string =''):string; overload;
   function Get(const aKey:string; const aDefault:Int64 =0):Int64; overload;
   function Get(const aKey:string; const aDefault:Double =0):Double; overload;
   function Get(const aKey:string; const aDefault:TDateTime =0):TDateTime; overload;




   function SetJson(const aKey:string; const v:string):IRadConfig;
   function SetValue(const aKey:string; const v:Variant):IRadConfig; overload;
   function SetV(const aKey:string; const v:string):IRadConfig; overload;
   function SetV(const aKey:string; const v:Int64):IRadConfig; overload;
   function SetV(const aKey:string; const v:Double):IRadConfig; overload;
   function SetV(const aKey:string; const v:TDateTime):IRadConfig; overload;
   function SetV(const aKey:string; const v:TObject):IRadConfig; overload;

  published
   //property Root: IDocDict read Json;
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
  fCurrentContent := aText;
  fCurrentHash := DefaultHashTrim(aText);
  result := true; // success

end;

constructor TRadConfig.Create;
begin
  inherited;
  FSafe.Init(True);
  FJson    := DocDict('{}');

  AutoCreateFields(Self);
  SetFileName(ChangeFileExt(ParamStr(0),'.json'));
end;

destructor TRadConfig.Destroy;
begin
  SaveIfNeeded;
  AutoDestroyFields(Self);
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

function TRadConfig.Get(const aKey: string; const aDefault: Int64): Int64;
begin
 try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.Get(const aKey, aDefault: string): string;
begin
 try Result:=GetValue(aKey,aDefault); except Result :=aDefault end;
end;

function TRadConfig.Get(const aKey: string; const aDefault: TDateTime): TDateTime;
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
 Result := FJson;
end;

function TRadConfig.LoadFromFile(const aFileName: TFileName; const aSectionName: string): boolean;
var
 text: RawUtf8;
begin
   fCurrentContent := ''; // ignore file neither valid JSON nor INI/YAML
  fCurrentHash := 0;
  fFileName := aFileName;
  text := RawUtf8FromFile(aFileName); // may detect BOM
  if text = '' then
    Exit(False);
 WriteLock;
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
  WriteUnlock;
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
  FJson :=DocDict(aJson);
end;

function TRadConfig.LoadFromText(const aContent,
  aSectionName: RawUtf8): boolean;
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
begin
  result := false;
  if (self = nil) or (fFileName = '') or (fsoDisableSaveIfNeeded in fSettingsOptions) then
    exit;
  ReadLock;
  try

  opt := SETTINGS_WRITEOPTIONS;
  if fSettingsOptions * [fsoNoEnumsComment, fsoWriteYaml, fsoWriteIni] <> [] then
    exclude(opt, woHumanReadableEnumSetAsComment);
  if fsoWriteIni in fSettingsOptions then
    saved := ObjectToIni(self, fSectionName, opt, 0,
    [ifClassSection, ifClassValue, ifMultiLineSections, ifArraySection, ifMultiLineJsonArray, ifClearValues])
  else
  begin

    //saved := ObjectToJson(self, opt);

    Json.Merge(DocDict(ObjectToJson(self, opt)));
    saved:=Json.Json;

    if fsoWriteYaml in fSettingsOptions then
      saved := JsonToYaml(saved)
    else if fsoWriteHjson in fSettingsOptions then
      saved := JsonReformat(saved, jsonH); // very human friendly
  end;
  if saved = fCurrentContent then
    exit; // don't rewrite the same content on disk
  result := FileFromString(saved, fFileName);
  if not result then
    exit;
  fCurrentContent := saved;
  fCurrentHash := DefaultHashTrim(saved);

  finally
   ReadUnlock;
  end;
end;

procedure TRadConfig.SetFileName(const Value: TFileName);
begin
fFileName := Value;
if FileExists(Value) then
  LoadFromFile(fFileName);
end;

function TRadConfig.SetJson(const aKey, v: string): IRadConfig;
begin
 WriteLock;
 try
  FJson.O[StringToUtf8(aKey)]:=DocDict(StringToUtf8(v));
 finally
  WriteUnlock;
 end;
end;

function TRadConfig.SetV(const aKey: string; const v: Double): IRadConfig;
begin
  Result := SetValue(aKey,v);
end;

function TRadConfig.SetV(const aKey: string; const v: Int64): IRadConfig;
begin
 Result := SetValue(aKey,v);
end;

function TRadConfig.SetV(const aKey, v: string): IRadConfig;
begin
 Result := SetValue(aKey,v);
end;

function TRadConfig.SetValue(const aKey: string; const v: Variant): IRadConfig;
begin
 Result := Self;
 WriteLock;
 try
  FJson.Item[StringToUtf8(aKey)]:=v;
  //FJson.Merge(StringToUtf8(aKey),v);
 finally
  WriteUnlock;
 end;
end;

function TRadConfig.SetV(const aKey: string; const v: TDateTime): IRadConfig;
begin
  Result := SetValue(aKey,v);
end;

function TRadConfig.SetV(const aKey: string; const v: TObject): IRadConfig;
begin
  Result := SetValue(aKey,ObjectToVariant(v,True));

end;


end.
