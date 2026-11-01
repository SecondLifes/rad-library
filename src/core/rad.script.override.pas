unit rad.script.override;

(* Script sistemi 5. aşama: mevcut formu kod yazmadan özelleştirme. Adlı bileşenlerin yayımlanmış
   özelliklerinin anlık görüntüsü, iki görüntü arasındaki fark, `<Sınıf>.duzen.json` ve uygulama.
   VCL'siz (TComponent + TypInfo); tasarımcı (rad.script.design) ve binder (rad.script.hooks) kullanır.
   Bkz. docs/specs/rad.script.designer.md *)

interface

uses
  System.SysUtils, System.Classes, System.TypInfo, System.Generics.Collections,
  mormot.core.base, mormot.core.variants;

type
  TRadOverrideWarning = reference to procedure(const AKey, AMessage: string);

  /// Özellik yolu → metin değer. Anahtar: `Form.Caption`, `btn.Caption`, `edt.Properties.ReadOnly`.
  /// Değer DFM metnine yakın: sayı, True/False, enum adı, [küme], ham metin, bileşen başvurusu = adı.
  TRadPropSnapshot = class
  public const
    FORM_KEY = 'Form';
    MAX_DEPTH = 4;
    FORMAT_VERSION = 1;
  private
    FValues: TDictionary<string, string>;
    FKeys: TList<string>;
    procedure CaptureObject(AObj: TObject; const APrefix: string; ADepth: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    /// Kök (Form.) + adlı bileşenler; adsız bileşen, olay, salt okunur ve Variant özellikler atlanır.
    class function Capture(ARoot: TComponent): TRadPropSnapshot; static;
    /// ANew'de AOld'dan farklı değer taşıyan anahtarlar (yalnız ikisinde de olanlar).
    class function Diff(AOld, ANew: TRadPropSnapshot): TRadPropSnapshot; static;
    procedure SetValue(const AKey, AValue: string);
    function TryGetValue(const AKey: string; out AValue: string): Boolean;
    procedure Remove(const AKey: string);
    /// AOther kazanır; yeni anahtarlar sona eklenir.
    procedure Merge(AOther: TRadPropSnapshot);
    function ToJson(const AFormClass: string): RawUtf8;
    /// Kaynak (script_kaynak) içeriği için UTF-8 baytlar.
    function ToJsonBytes(const AFormClass: string): TBytes;
    /// Biçim hatası → ERadOverrideFormat.
    class function FromJson(const AJson: RawUtf8; out AFormClass: string): TRadPropSnapshot; static;
    class function FromJsonBytes(const ABytes: TBytes; out AFormClass: string): TRadPropSnapshot; static;
    /// Uygular; bulunamayan bileşen/özellik ya da uyumsuz değer durdurmaz: AWarn (nil olabilir), kalan devam.
    /// Sonuç: uygulanan anahtar sayısı.
    function Apply(ARoot: TComponent; const AWarn: TRadOverrideWarning): Integer;
    function Count: Integer;
    property Keys: TList<string> read FKeys;
    property Values: TDictionary<string, string> read FValues;
  end;

  ERadOverrideFormat = class(Exception);

  /// Tek özellik: yol çözümleme, metin okuma/yazma (TypInfo).
  TRadPropText = class
  public
    /// `btn.Font.Size` → nesne (btn.Font) + özellik (Size). Kök `Form`. Bulunamazsa False.
    class function Resolve(ARoot: TComponent; const AKey: string; out AObj: TObject; out AProp: PPropInfo): Boolean; static;
    /// Yazılabilir ve saklanabilir türde mi (olay, Variant, pointer, arayüz, dizi hariç).
    class function IsStorable(AProp: PPropInfo): Boolean; static;
    class function ReadProp(AObj: TObject; AProp: PPropInfo): string; static;
    /// Bileşen başvurusu ARoot.FindComponent ile; '' → nil. Uyumsuz metin → EConvertError.
    class procedure WriteProp(ARoot: TComponent; AObj: TObject; AProp: PPropInfo; const AValue: string); static;
  end;

implementation

uses
  mormot.core.text, mormot.core.unicode;

const
  STORABLE_KINDS = [tkInteger, tkChar, tkEnumeration, tkFloat, tkString, tkSet, tkWChar, tkLString, tkWString,
    tkInt64, tkUString, tkClass];
  SKIP_PROPS: array[0..1] of string = ('Name', 'Tag');

resourcestring
  SWarnNotFound = 'Bileşen ya da özellik bulunamadı.';
  SWarnBadValue = 'Değer uygulanamadı: %s';
  SErrJsonFormat = 'Düzen dosyası okunamadı: %s';
  SErrJsonVersion = 'Düzen dosyası biçimi %d desteklenmiyor (en çok %d).';

{ TRadPropText }

class function TRadPropText.IsStorable(AProp: PPropInfo): Boolean;
var
  LName: string;
begin
  // Alt nesne (Font, Properties) genelde salt okunur bir sınıf özelliğidir: içine inilir, kendisi yazılmaz.
  Result := (AProp^.PropType^.Kind in STORABLE_KINDS) and (AProp^.GetProc <> nil) and
    ((AProp^.SetProc <> nil) or (AProp^.PropType^.Kind = tkClass));
  if not Result then Exit;
  for LName in SKIP_PROPS do
    if SameText(string(AProp^.NameFld.ToString), LName) then Exit(False);
end;

class function TRadPropText.Resolve(ARoot: TComponent; const AKey: string; out AObj: TObject;
  out AProp: PPropInfo): Boolean;
var
  LParts: TArray<string>;
  i: Integer;
  LInfo: PPropInfo;
begin
  Result := False;
  AObj := nil;
  AProp := nil;
  LParts := AKey.Split(['.']);
  if Length(LParts) < 2 then Exit;
  if SameText(LParts[0], TRadPropSnapshot.FORM_KEY) then AObj := ARoot
  else AObj := ARoot.FindComponent(LParts[0]);
  if AObj = nil then Exit;
  for i := 1 to High(LParts) - 1 do
  begin
    LInfo := GetPropInfo(AObj, LParts[i]);
    if (LInfo = nil) or (LInfo^.PropType^.Kind <> tkClass) then Exit;
    AObj := GetObjectProp(AObj, LInfo);
    if AObj = nil then Exit;
  end;
  AProp := GetPropInfo(AObj, LParts[High(LParts)]);
  Result := AProp <> nil;
end;

class function TRadPropText.ReadProp(AObj: TObject; AProp: PPropInfo): string;
var
  LObj: TObject;
begin
  case AProp^.PropType^.Kind of
    tkInteger: Result := IntToStr(GetOrdProp(AObj, AProp));
    tkChar, tkWChar: Result := '#' + IntToStr(GetOrdProp(AObj, AProp));
    tkEnumeration: Result := GetEnumName(AProp^.PropType^, GetOrdProp(AObj, AProp));
    tkSet: Result := SetToString(AProp, GetOrdProp(AObj, AProp), True);
    tkFloat: Result := FloatToStr(GetFloatProp(AObj, AProp), TFormatSettings.Invariant);
    tkInt64: Result := IntToStr(GetInt64Prop(AObj, AProp));
    tkString, tkLString, tkWString, tkUString: Result := GetStrProp(AObj, AProp);
    tkClass:
      begin
        LObj := GetObjectProp(AObj, AProp);
        if LObj is TComponent then Result := TComponent(LObj).Name else Result := '';
      end;
  else
    Result := '';
  end;
end;

class procedure TRadPropText.WriteProp(ARoot: TComponent; AObj: TObject; AProp: PPropInfo; const AValue: string);
var
  LOrd: Integer;
  LRef: TComponent;
begin
  case AProp^.PropType^.Kind of
    tkInteger: SetOrdProp(AObj, AProp, StrToInt(AValue));
    tkChar, tkWChar:
      if (AValue <> '') and (AValue[1] = '#') then SetOrdProp(AObj, AProp, StrToInt(Copy(AValue, 2, MaxInt)))
      else if AValue <> '' then SetOrdProp(AObj, AProp, Ord(AValue[1]))
      else raise EConvertError.Create(AValue);
    tkEnumeration:
      begin
        LOrd := GetEnumValue(AProp^.PropType^, AValue);
        if LOrd < 0 then raise EConvertError.Create(AValue);
        SetOrdProp(AObj, AProp, LOrd);
      end;
    tkSet: SetOrdProp(AObj, AProp, StringToSet(AProp, AValue));
    tkFloat: SetFloatProp(AObj, AProp, StrToFloat(AValue, TFormatSettings.Invariant));
    tkInt64: SetInt64Prop(AObj, AProp, StrToInt64(AValue));
    tkString, tkLString, tkWString, tkUString: SetStrProp(AObj, AProp, AValue);
    tkClass:
      begin
        if AProp^.SetProc = nil then raise EConvertError.Create(AValue);
        if AValue = '' then LRef := nil
        else
        begin
          LRef := ARoot.FindComponent(AValue);
          if LRef = nil then raise EConvertError.Create(AValue);
        end;
        SetObjectProp(AObj, AProp, LRef);
      end;
  else
    raise EConvertError.Create(AValue);
  end;
end;

{ TRadPropSnapshot }

constructor TRadPropSnapshot.Create;
begin
  inherited Create;
  FValues := TDictionary<string, string>.Create;
  FKeys := TList<string>.Create;
end;

destructor TRadPropSnapshot.Destroy;
begin
  FKeys.Free;
  FValues.Free;
  inherited;
end;

function TRadPropSnapshot.Count: Integer;
begin
  Result := FKeys.Count;
end;

procedure TRadPropSnapshot.SetValue(const AKey, AValue: string);
begin
  if not FValues.ContainsKey(AKey) then FKeys.Add(AKey);
  FValues.AddOrSetValue(AKey, AValue);
end;

function TRadPropSnapshot.TryGetValue(const AKey: string; out AValue: string): Boolean;
begin
  Result := FValues.TryGetValue(AKey, AValue);
end;

procedure TRadPropSnapshot.Remove(const AKey: string);
begin
  if FValues.ContainsKey(AKey) then
  begin
    FValues.Remove(AKey);
    FKeys.Remove(AKey);
  end;
end;

procedure TRadPropSnapshot.CaptureObject(AObj: TObject; const APrefix: string; ADepth: Integer);
var
  LList: PPropList;
  LCount, i: Integer;
  LProp: PPropInfo;
  LSub: TObject;
  LName: string;
begin
  LCount := GetPropList(AObj, LList);
  if LCount = 0 then Exit;
  try
    for i := 0 to LCount - 1 do
    begin
      LProp := LList^[i];
      if not TRadPropText.IsStorable(LProp) then Continue;
      LName := string(LProp^.NameFld.ToString);
      if LProp^.PropType^.Kind = tkClass then
      begin
        LSub := GetObjectProp(AObj, LProp);
        if (LSub = nil) or (LSub is TComponent) then
        begin
          if LProp^.SetProc <> nil then SetValue(APrefix + LName, TRadPropText.ReadProp(AObj, LProp));
        end
        else if ADepth < MAX_DEPTH then
          CaptureObject(LSub, APrefix + LName + '.', ADepth + 1);
        // TStrings/TCollection gibi alt nesnelerin yayımlanmış özelliği yoktur; içerikleri kapsam dışı.
      end
      else
        SetValue(APrefix + LName, TRadPropText.ReadProp(AObj, LProp));
    end;
  finally
    FreeMem(LList);
  end;
end;

class function TRadPropSnapshot.Capture(ARoot: TComponent): TRadPropSnapshot;
var
  i: Integer;
  C: TComponent;
begin
  Result := TRadPropSnapshot.Create;
  try
    Result.CaptureObject(ARoot, FORM_KEY + '.', 1);
    for i := 0 to ARoot.ComponentCount - 1 do
    begin
      C := ARoot.Components[i];
      if C.Name <> '' then Result.CaptureObject(C, C.Name + '.', 1);
    end;
  except
    Result.Free;
    raise;
  end;
end;

class function TRadPropSnapshot.Diff(AOld, ANew: TRadPropSnapshot): TRadPropSnapshot;
var
  LKey, LOldVal, LNewVal: string;
begin
  Result := TRadPropSnapshot.Create;
  for LKey in ANew.FKeys do
    if AOld.FValues.TryGetValue(LKey, LOldVal) then
    begin
      LNewVal := ANew.FValues[LKey];
      if LOldVal <> LNewVal then Result.SetValue(LKey, LNewVal);
    end;
end;

procedure TRadPropSnapshot.Merge(AOther: TRadPropSnapshot);
var
  LKey: string;
begin
  for LKey in AOther.FKeys do
    SetValue(LKey, AOther.FValues[LKey]);
end;

function TRadPropSnapshot.ToJson(const AFormClass: string): RawUtf8;
var
  LDoc, LProps: TDocVariantData;
  LKey: string;
begin
  LProps.InitObject([], JSON_FAST);
  for LKey in FKeys do
    LProps.AddValue(StringToUtf8(LKey), RawUtf8ToVariant(StringToUtf8(FValues[LKey])));
  LDoc.InitObject(['format', FORMAT_VERSION, 'form', StringToUtf8(AFormClass)], JSON_FAST);
  LDoc.AddValue('props', Variant(LProps));
  Result := LDoc.ToJson('', '', jsonHumanReadable);
end;

class function TRadPropSnapshot.FromJson(const AJson: RawUtf8; out AFormClass: string): TRadPropSnapshot;
var
  LDoc: TDocVariantData;
  LProps: PDocVariantData;
  LVer, i: Integer;
begin
  AFormClass := '';
  if not LDoc.InitJson(AJson, JSON_FAST) or not LDoc.IsObject then
    raise ERadOverrideFormat.CreateFmt(SErrJsonFormat, ['JSON nesnesi değil']);
  LVer := LDoc.GetValueOrDefault('format', 0);
  if (LVer < 1) or (LVer > FORMAT_VERSION) then
    raise ERadOverrideFormat.CreateFmt(SErrJsonVersion, [LVer, FORMAT_VERSION]);
  AFormClass := Utf8ToString(VariantToUtf8(LDoc.GetValueOrDefault('form', '')));
  Result := TRadPropSnapshot.Create;
  try
    if LDoc.GetAsDocVariant('props', LProps) and LProps^.IsObject then
      for i := 0 to LProps^.Count - 1 do
        Result.SetValue(Utf8ToString(LProps^.Names[i]), Utf8ToString(VariantToUtf8(LProps^.Values[i])));
  except
    Result.Free;
    raise;
  end;
end;

function TRadPropSnapshot.ToJsonBytes(const AFormClass: string): TBytes;
var
  LJson: RawUtf8;
begin
  LJson := ToJson(AFormClass);
  SetLength(Result, Length(LJson));
  if Length(LJson) > 0 then Move(Pointer(LJson)^, Result[0], Length(LJson));
end;

class function TRadPropSnapshot.FromJsonBytes(const ABytes: TBytes; out AFormClass: string): TRadPropSnapshot;
var
  LJson: RawUtf8;
begin
  SetString(LJson, PAnsiChar(Pointer(ABytes)), Length(ABytes));
  Result := FromJson(LJson, AFormClass);
end;

function TRadPropSnapshot.Apply(ARoot: TComponent; const AWarn: TRadOverrideWarning): Integer;
var
  LKey: string;
  LObj: TObject;
  LProp: PPropInfo;
begin
  Result := 0;
  for LKey in FKeys do
  begin
    if not TRadPropText.Resolve(ARoot, LKey, LObj, LProp) or not TRadPropText.IsStorable(LProp) then
    begin
      if Assigned(AWarn) then AWarn(LKey, SWarnNotFound);
      Continue;
    end;
    try
      TRadPropText.WriteProp(ARoot, LObj, LProp, FValues[LKey]);
      Inc(Result);
    except
      on E: Exception do
        if Assigned(AWarn) then AWarn(LKey, Format(SWarnBadValue, [E.Message]));
    end;
  end;
end;

end.
