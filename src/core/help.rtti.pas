unit Help.Rtti;

interface

uses
  System.SysUtils,
  System.Variants,
  mormot.core.base,
  mormot.core.rtti,
  mormot.core.text,
  mormot.core.variants,
  mormot.core.json;

type
  /// mORMot RTTI tabanlı güvenli ve hızlı yardımcı sınıf
  TRtti = record
  public
    // ============================================================================
    // PROPERTY (PATH'SIZ)
    // ============================================================================

    /// Property veya Field var mı kontrol eder
    class function PropertyExists(const AInstance: TObject; const AName: RawUtf8): Boolean; static;

    /// Property değerini text (RawUtf8) olarak okur
    class function ReadPropertyText(const AInstance: TObject; const AName: RawUtf8): RawUtf8; static;

    /// Property değerini text (RawUtf8) olarak yazar
    class function WritePropertyText(const AInstance: TObject; const AName, AValue: RawUtf8): Boolean; static;

    /// Property değerini Variant olarak okur
    class function ReadPropertyVariant(const AInstance: TObject; const AName: RawUtf8): Variant; static;

    /// Property değerini Variant olarak yazar
    class function WritePropertyVariant(const AInstance: TObject; const AName: RawUtf8; const AValue: Variant): Boolean; static;

    // ============================================================================
    // PROPERTY (PATH'LI) -> Font.Style, Button1.Font.Name vb.
    // ============================================================================

    /// Path var mı kontrol eder (örn: "Font.Style")
    class function PathExists(const AInstance: TObject; const APath: RawUtf8): Boolean; static;

    /// Path'li property değerini text olarak okur
    class function ReadPathText(const AInstance; const APath: RawUtf8): RawUtf8; static;

    /// Path'li property değerini text olarak yazar
    class function WritePathText(const AInstance; const APath, AValue: RawUtf8): Boolean; static;

    // ============================================================================
    // TOPLU İŞLEMLER & JSON
    // ============================================================================

    /// Nesneyi JSON formatına dönüştürür
    class function ToJson(const AInstance: TObject): RawUtf8; static;

    /// JSON verisini nesneye yükler
    class function FromJson(var AInstance: TObject; const AJson: RawUtf8): Boolean; static;

    /// Bir nesnenin propertylerini diğerine kopyalar
    class function CopyProperties(var ASource, ATarget: TObject): Boolean; static;

    /// Tüm property isimlerini dizi olarak döndürür
    class function GetPropertyNames(const AInstance: TObject): TRawUtf8DynArray; static;
  end;

implementation

{ TRtti }

class function TRtti.PropertyExists(const AInstance: TObject; const AName: RawUtf8): Boolean;
var
  RC: TRttiCustom;
begin
  if (AInstance = nil) or (AName = '') then Exit(False);
  RC := Rtti.RegisterClass(AInstance.ClassType);
  Result := RC.Props.Find(AName) <> nil;
end;

class function TRtti.ReadPropertyText(const AInstance: TObject; const AName: RawUtf8): RawUtf8;
var
  RC: TRttiCustom;
  P: PRttiCustomProp;
begin
  Result := '';
  if (AInstance = nil) or (AName = '') then Exit;
  RC := Rtti.RegisterClass(AInstance.ClassType);
  P := RC.Props.Find(AName);
  if P <> nil then
    Result := P^.GetValueText(AInstance);
end;

class function TRtti.WritePropertyText(const AInstance: TObject; const AName, AValue: RawUtf8): Boolean;
var
  RC: TRttiCustom;
  P: PRttiCustomProp;
begin
  Result := False;
  if (AInstance = nil) or (AName = '') then Exit;
  RC := Rtti.RegisterClass(AInstance.ClassType);
  P := RC.Props.Find(AName);
  if P <> nil then
    Result := P^.SetValueText(AInstance, AValue);
end;

class function TRtti.ReadPropertyVariant(const AInstance: TObject; const AName: RawUtf8): Variant;
var
  Text: RawUtf8;
begin
  VarClear(Result);
  Text := ReadPropertyText(AInstance, AName);
  if Text <> '' then
    VariantLoadJSON(Result, Text, @JSON_[mFast]);

end;

class function TRtti.WritePropertyVariant(const AInstance: TObject; const AName: RawUtf8; const AValue: Variant): Boolean;
var
  Text: RawUtf8;
begin
  Text := VariantSaveJSON(AValue);
  Result := WritePropertyText(AInstance, AName, Text);
end;

class function TRtti.PathExists(const AInstance: TObject; const APath: RawUtf8): Boolean;
var
  RC: TRttiCustom;
  Data: Pointer;
begin
  if (AInstance = nil) or (APath = '') then Exit(False);
  RC := Rtti.RegisterClass(AInstance.ClassType);
  Data := Pointer(AInstance);
  Result := RC.PropFindByPath(Data, PUtf8Char(APath)) <> nil;
end;

class function TRtti.ReadPathText(const AInstance; const APath: RawUtf8): RawUtf8;
var
 P: PRttiCustomProp;
 obj:TObject;
begin
  Result := '';
  obj:=TObject(AInstance);
 if GetInstanceByPath( obj, APath, P, '.') then
  begin
   Result:=P^.GetValueText(obj);
  end;
end;

class function TRtti.WritePathText(const AInstance; const APath, AValue: RawUtf8): Boolean;
var
 P: PRttiCustomProp;
 obj:TObject;
begin
  Result := False;
  obj:=TObject(AInstance);
 if GetInstanceByPath( obj, APath, P, '.') then
   Result:= P^.SetValueText(obj,AValue);
end;

class function TRtti.ToJson(const AInstance: TObject): RawUtf8;
begin
  if AInstance = nil then Exit('');
  Result := ObjectToJSON(AInstance, [woDontStoreDefault]);
end;

class function TRtti.FromJson(var AInstance: TObject; const AJson: RawUtf8): Boolean;
begin
  Result := False;
  if (AInstance = nil) or (AJson = '') then Exit;
  Result := JSONToObject(AInstance, PUtf8Char(AJson), Result) <> nil;
end;

class function TRtti.CopyProperties(var ASource, ATarget: TObject): Boolean;
var
  Json: RawUtf8;
begin
  Result := False;
  if (ASource = nil) or (ATarget = nil) then Exit;

  // Kaynak nesneyi JSON'a çevir
  Json := ObjectToJSON(ASource, [woDontStoreDefault]);

  // JSON'dan hedef nesneye yükle

  Result := JSONToObject(ATarget, PUtf8Char(Json), Result) <> nil;
end;

class function TRtti.GetPropertyNames(const AInstance: TObject): TRawUtf8DynArray;
var
  RC: TRttiCustom;
  i: Integer;
begin
  if AInstance = nil then Exit(nil);
  RC := Rtti.RegisterClass(AInstance.ClassType);

  SetLength(Result, RC.Props.Count);
  for i := 0 to RC.Props.Count - 1 do
    Result[i] := RC.Props.List[i].Name;
end;

end.
