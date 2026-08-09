unit rad.utils;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes
  ,System.TypInfo
  ,mormot.core.base
  ;



type

  { TResult<T>: Operasyon sonu�lar�n� y�netmek i�in optimize edilmi� record.
    Bellek ay�rma (allocation) maliyeti yoktur, stack �zerinde �al���r. }
  TResult<T> = record
  private
    FValue: T;
    FErrorMsg: string;
    FSuccess: Boolean;
    function GetValue: T;
  public
    { Ba�ar� durumunda sonu� �retir }
    class function Success(const AValue: T): TResult<T>; static;
    { Hata durumunda mesajla sonu� �retir }
    class function Failure(const AErrorMsg: string): TResult<T>; static;
    { Exception durumunda otomatik hata sonucu �retir }
    class function FromException(const E: Exception): TResult<T>; static;

    { G�venli veri okuma pattern'� }
    function TryGetValue(out AValue: T): Boolean;

    { �zellikler }
    property Value: T read GetValue;
    property ErrorMsg: string read FErrorMsg;
    property IsSuccess: Boolean read FSuccess;

  end;


  TUtils = class
    //const
     //Hash32      : function (const Text: RawByteString): cardinal = mormot.core.base.Hash32;
     //Join        : function (const Args: array of RawByteString): RawUtf8 = mormot.core.base.Join;
    private
    public
    class procedure InUI(AProc: TProc); static;
  end;




/// Verilen bir class'ı RTTI ile inceleyip, onu fluent/interface tabanlı bir sisteme
/// çevirecek HAZIR PASCAL KAYNAK KODUNU (string olarak) üretir. Üretilen kod
/// ÇALIŞTIRILMAZ/derlenmez — yalnızca metindir; gözden geçirip projeye elle eklemen gerekir.
///
/// Kurallar:
///   - Interface adı: class adı 'T' ile başlıyorsa 'I' + (T'siz hali), değilse 'I' + ad.
///   - İmplementasyon class adı: class adı + 'Fluent'.
///   - Her zaman bir "AsInstance: <ClassName>" eklenir — sarmalanan ham örneğe kaçış kapısı.
///   - Class'ta DOĞRUDAN tanımlı (kalıtılmamış), public/published her BASİT property için:
///       function Set<Prop>(const a<Prop>: <Tip>): I<Isim>;  (fluent, zincire devam eder)
///       function Get<Prop>: <Tip>;
///     Event property'ler (TNotifyEvent gibi method-type) de aynı kurala tabidir.
///   - İNDEKSLİ (array) property'ler (ör. property Items[Index: Integer]: T) için:
///       function Set<Prop>(<index parametreleri>; const aValue: <Tip>): I<Isim>;
///       function Get<Prop>(<index parametreleri>): <Tip>;
///   - DOĞRUDAN tanımlı her public method (property accessor'ları hariç, onlar zaten
///     private/protected olduğu için otomatik elenir) AYNI isim ve imzayla pass-through
///     olarak eklenir (fluent DEĞİLDİR, orijinal dönüş tipini korur). Aynı isimde birden
///     fazla (overload) metod varsa üretilen kodda 'overload;' otomatik eklenir.
///   - Constructor'a AAutoFree: Boolean = False parametresi eklenir; True verilirse
///     wrapper'ın destructor'ı FInstance.Free çağırır (varsayılan False — sarmalanan
///     örneğin ömrü hâlâ çağıranın sorumluluğundadır).
///
/// DİKKAT — Parametre/dönüş tipi adları: RTTI (TRttiType.Name) tabanlıdır ve TEST EDİLDİ
/// (bkz. rad.utils.Tests.pas → GenerikArrayParametreliMetodDaUretilir): ör. TArray<TValue>
/// gibi generic bir tip TAM NİTELİKLİ olarak üretilir (TArray<System.Rtti.TValue>) — bu
/// hâlâ geçerli/derlenebilir Pascal'dır, sadece kısaltılmamıştır.
///
/// DİKKAT — Class helper sızıntısı (RTTI seviyesinde DÜZELTİLEMEZ): AClass'ın DECLARE
/// EDİLDİĞİ unit'te o an AKTİF olan bir class helper (ör. "TObjectHelper = class helper
/// for TObject") varsa, derleyici o helper'ın metodlarını AClass'ın RTTI'sine SANKİ
/// DOĞRUDAN TANIMLIYMIŞ GİBİ gömer — Meth.Parent bile AClass'ı gösterir, ayırt edilemez
/// (gerçek derleme/testte doğrulandı: DUnitX.Utils.TObjectHelper.Log/Status/WriteLn,
/// TDenemeSinifi hiç tanımlamadığı hâlde üretilen koda karıştı). Bu, üretici fonksiyonun
/// bir kusuru değil, Delphi'nin derleme zamanında RTTI'ye "o anki görünür" tüm üyeleri
/// gömmesinin doğal sonucu — çalışma zamanı RTTI'sinden ayıklanamaz. ÜRETİLEN KODU HER
/// ZAMAN GÖZDEN GEÇİR; beklenmeyen fazladan metod görürsen elle çıkar.
///
/// NOT: Record desteği (GenerateFluentCode(ATypeInfo: PTypeInfo)) denendi ve KALDIRILDI —
/// gerçek derleme/testte (bkz. rad.utils.Tests.pas geçmişi) Delphi 13.1 Athens'in
/// System.Rtti'sinde record property'lerinin TRttiProperty olarak HİÇ yansıtılmadığı
/// (GetDeclaredProperties boş döndüğü) tespit edildi — en geniş {$RTTI} direktifiyle bile
/// değişmedi. Yalnızca class destekleniyor.
function GenerateFluentCode(AClass: TClass): string;

/// 1/10 ms toleranslı TDateTime karşılaştırma (float yuvarlama hatalarına karşı)
/// Kaynak: vendor\gabr42\GpDelphiUnits\src\GpTimezone.pas (DateEQ/DateLT/.../DateGE)
function DateEQ(const ADate1, ADate2: TDateTime): Boolean;
function DateLT(const ADate1, ADate2: TDateTime): Boolean;
function DateLE(const ADate1, ADate2: TDateTime): Boolean;
function DateGT(const ADate1, ADate2: TDateTime): Boolean;
function DateGE(const ADate1, ADate2: TDateTime): Boolean;

/// float yuvarlama hatalarını düzeltir (Trunc/Frac öncesi çağrılır)
/// ör. FixDT(36463.99999999999) = 36464
function FixDT(const ADate: TDateTime): TDateTime;

/// "ayın N'inci X günü" tarihini hesaplar (ör. DayOfMonth2Date(2026,12,5,1) = Aralık'ın son Pazarı)
/// AWeekInMonth: 1-4 (o ayın kaçıncı haftası) veya 5 (son hafta); ADayInWeek: 1=Pazar..7=Cumartesi
function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;


implementation
uses
mormot.core.datetime, System.Rtti, System.Generics.Collections,
System.DateUtils;

{ GenerateFluentCode }

function GenerateFluentCode(AClass: TClass): string;
var
  Ctx: TRttiContext;
  RttiType: TRttiInstanceType;
  InstanceTypeName, InterfaceName, ImplName: string;
  MemberDecls, DeclBody, ImplBody: TStringBuilder;
  MethodOverloadCount: TDictionary<string, Integer>;
  Prop: TRttiProperty;
  IdxProp: TRttiIndexedProperty;
  Meth: TRttiMethod;

  function InterfaceNameFor(const ATypeName: string): string;
  begin
    if (Length(ATypeName) > 1) and (ATypeName[1] = 'T') then
      Result := 'I' + Copy(ATypeName, 2, MaxInt)
    else
      Result := 'I' + ATypeName;
  end;

  function ParamListFor(const AParams: TArray<TRttiParameter>): string;
  var
    P: TRttiParameter;
    LPrefix: string;
  begin
    Result := '';
    for P in AParams do
    begin
      if pfConst in P.Flags then LPrefix := 'const '
      else if pfVar in P.Flags then LPrefix := 'var '
      else if pfOut in P.Flags then LPrefix := 'out '
      else LPrefix := '';
      if Result <> '' then Result := Result + '; ';
      Result := Result + LPrefix + P.Name + ': ' + P.ParamType.Name;
    end;
  end;

  function ArgListFor(const AParams: TArray<TRttiParameter>): string;
  var
    P: TRttiParameter;
  begin
    Result := '';
    for P in AParams do
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + P.Name;
    end;
  end;

  // İndeksli property'nin index parametrelerini (value HARİÇ) ReadMethod/WriteMethod'dan çıkarır.
  function IndexParamsOf(const AIdxProp: TRttiIndexedProperty): TArray<TRttiParameter>;
  begin
    if Assigned(AIdxProp.ReadMethod) then
      Result := AIdxProp.ReadMethod.GetParameters
    else if Assigned(AIdxProp.WriteMethod) then
    begin
      Result := AIdxProp.WriteMethod.GetParameters;
      SetLength(Result, Length(Result) - 1); // son parametre value'dur, index değil
    end
    else
      SetLength(Result, 0);
  end;

  function MethodSignature(const AMeth: TRttiMethod; AOverload: Boolean): string;
  var
    LParams: string;
  begin
    LParams := ParamListFor(AMeth.GetParameters);
    if LParams <> '' then LParams := '(' + LParams + ')';
    if AMeth.MethodKind = mkFunction then
      Result := 'function ' + AMeth.Name + LParams + ': ' + AMeth.ReturnType.Name + ';'
    else
      Result := 'procedure ' + AMeth.Name + LParams + ';';
    if AOverload then
      Result := Result + ' overload;';
  end;

  function IsOverloaded(const AMethodName: string): Boolean;
  var
    LCount: Integer;
  begin
    Result := MethodOverloadCount.TryGetValue(AMethodName, LCount) and (LCount > 1);
  end;

begin
  if AClass = nil then
    raise Exception.Create('GenerateFluentCode: AClass nil olamaz.');

  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(AClass) as TRttiInstanceType;
    InstanceTypeName := RttiType.Name;
    InterfaceName := InterfaceNameFor(InstanceTypeName);
    ImplName := InstanceTypeName + 'Fluent';

    // Aynı isimde birden fazla (overload) public metod var mı — 'overload;' kararı için.
    MethodOverloadCount := TDictionary<string, Integer>.Create;
    try
      for Meth in RttiType.GetDeclaredMethods do
      begin
        if Meth.Parent <> RttiType then Continue; // class helper metodlarını dışarıda bırak
        if Meth.Visibility < mvPublic then Continue;
        if Meth.MethodKind in [mkConstructor, mkDestructor, mkClassProcedure, mkClassFunction] then Continue;
        var LCount: Integer;
        if MethodOverloadCount.TryGetValue(Meth.Name, LCount) then
          MethodOverloadCount[Meth.Name] := LCount + 1
        else
          MethodOverloadCount.Add(Meth.Name, 1);
      end;

      MemberDecls := TStringBuilder.Create;
      DeclBody := TStringBuilder.Create;
      ImplBody := TStringBuilder.Create;
      try
        // ================= Ortak üye (property/indeksli/method) İMZA listesi =================
        // Bu blok, interface VE impl class tanımında AYNEN tekrar kullanılır — iki taraf
        // asla birbirinden sapmasın diye TEK bir kaynaktan üretilir.
        MemberDecls.AppendLine('    function AsInstance: ' + InstanceTypeName + ';');
        MemberDecls.AppendLine('');

        for Prop in RttiType.GetDeclaredProperties do
        begin
          if Prop.Parent <> RttiType then Continue; // class helper property'lerini dışarıda bırak
          if Prop.Visibility < mvPublic then Continue;
          if Prop.IsWritable then
            MemberDecls.AppendLine('    function Set' + Prop.Name + '(const a' + Prop.Name + ': ' +
              Prop.PropertyType.Name + '): ' + InterfaceName + ';');
          if Prop.IsReadable then
            MemberDecls.AppendLine('    function Get' + Prop.Name + ': ' + Prop.PropertyType.Name + ';');
        end;

        for IdxProp in RttiType.GetIndexedProperties do
        begin
          if IdxProp.Parent <> RttiType then Continue; // yalnızca doğrudan tanımlı
          if IdxProp.Visibility < mvPublic then Continue;

          var LIdxParamText := ParamListFor(IndexParamsOf(IdxProp));
          if IdxProp.IsWritable then
          begin
            var LSetParams: string;
            if LIdxParamText <> '' then
              LSetParams := LIdxParamText + '; const aValue: ' + IdxProp.PropertyType.Name
            else
              LSetParams := 'const aValue: ' + IdxProp.PropertyType.Name;
            MemberDecls.AppendLine('    function Set' + IdxProp.Name + '(' + LSetParams + '): ' +
              InterfaceName + ';');
          end;
          if IdxProp.IsReadable then
          begin
            var LGetParams: string;
            if LIdxParamText <> '' then LGetParams := '(' + LIdxParamText + ')' else LGetParams := '';
            MemberDecls.AppendLine('    function Get' + IdxProp.Name + LGetParams + ': ' +
              IdxProp.PropertyType.Name + ';');
          end;
        end;

        MemberDecls.AppendLine('');
        for Meth in RttiType.GetDeclaredMethods do
        begin
          if Meth.Parent <> RttiType then Continue; // class helper metodlarını dışarıda bırak
          if Meth.Visibility < mvPublic then Continue;
          if Meth.MethodKind in [mkConstructor, mkDestructor, mkClassProcedure, mkClassFunction] then Continue;
          MemberDecls.AppendLine('    ' + MethodSignature(Meth, IsOverloaded(Meth.Name)));
        end;

        // ================= INTERFACE =================
        DeclBody.AppendLine('  ' + InterfaceName + ' = interface');
        DeclBody.Append(MemberDecls.ToString);
        DeclBody.AppendLine('  end;');
        DeclBody.AppendLine('');

        // ================= İMPLEMENTASYON CLASS TANIMI =================
        DeclBody.AppendLine('  ' + ImplName + ' = class(TInterfacedObject, ' + InterfaceName + ')');
        DeclBody.AppendLine('  strict private');
        DeclBody.AppendLine('    FInstance: ' + InstanceTypeName + ';');
        DeclBody.AppendLine('    FAutoFree: Boolean;');
        DeclBody.AppendLine('  public');
        DeclBody.AppendLine('    constructor Create(AInstance: ' + InstanceTypeName + '; AAutoFree: Boolean = False);');
        DeclBody.AppendLine('    destructor Destroy; override;');
        DeclBody.Append(MemberDecls.ToString);
        DeclBody.AppendLine('  end;');

        // ================= İMPLEMENTASYON GÖVDELERİ =================
        ImplBody.AppendLine('constructor ' + ImplName + '.Create(AInstance: ' + InstanceTypeName +
          '; AAutoFree: Boolean = False);');
        ImplBody.AppendLine('begin');
        ImplBody.AppendLine('  inherited Create;');
        ImplBody.AppendLine('  FInstance := AInstance;');
        ImplBody.AppendLine('  FAutoFree := AAutoFree;');
        ImplBody.AppendLine('end;');
        ImplBody.AppendLine('');
        ImplBody.AppendLine('destructor ' + ImplName + '.Destroy;');
        ImplBody.AppendLine('begin');
        ImplBody.AppendLine('  if FAutoFree then');
        ImplBody.AppendLine('    FInstance.Free;');
        ImplBody.AppendLine('  inherited;');
        ImplBody.AppendLine('end;');
        ImplBody.AppendLine('');

        ImplBody.AppendLine('function ' + ImplName + '.AsInstance: ' + InstanceTypeName + ';');
        ImplBody.AppendLine('begin');
        ImplBody.AppendLine('  Result := FInstance;');
        ImplBody.AppendLine('end;');
        ImplBody.AppendLine('');

        for Prop in RttiType.GetDeclaredProperties do
        begin
          if Prop.Parent <> RttiType then Continue; // class helper property'lerini dışarıda bırak
          if Prop.Visibility < mvPublic then Continue;
          if Prop.IsWritable then
          begin
            ImplBody.AppendLine('function ' + ImplName + '.Set' + Prop.Name + '(const a' + Prop.Name + ': ' +
              Prop.PropertyType.Name + '): ' + InterfaceName + ';');
            ImplBody.AppendLine('begin');
            ImplBody.AppendLine('  FInstance.' + Prop.Name + ' := a' + Prop.Name + ';');
            ImplBody.AppendLine('  Result := Self;');
            ImplBody.AppendLine('end;');
            ImplBody.AppendLine('');
          end;
          if Prop.IsReadable then
          begin
            ImplBody.AppendLine('function ' + ImplName + '.Get' + Prop.Name + ': ' + Prop.PropertyType.Name + ';');
            ImplBody.AppendLine('begin');
            ImplBody.AppendLine('  Result := FInstance.' + Prop.Name + ';');
            ImplBody.AppendLine('end;');
            ImplBody.AppendLine('');
          end;
        end;

        for IdxProp in RttiType.GetIndexedProperties do
        begin
          if IdxProp.Parent <> RttiType then Continue;
          if IdxProp.Visibility < mvPublic then Continue;

          var LIdxParamsArr := IndexParamsOf(IdxProp);
          var LIdxParamText := ParamListFor(LIdxParamsArr);
          var LIdxArgText := ArgListFor(LIdxParamsArr);

          if IdxProp.IsWritable then
          begin
            var LSetParams: string;
            if LIdxParamText <> '' then
              LSetParams := LIdxParamText + '; const aValue: ' + IdxProp.PropertyType.Name
            else
              LSetParams := 'const aValue: ' + IdxProp.PropertyType.Name;
            ImplBody.AppendLine('function ' + ImplName + '.Set' + IdxProp.Name + '(' + LSetParams + '): ' +
              InterfaceName + ';');
            ImplBody.AppendLine('begin');
            ImplBody.AppendLine('  FInstance.' + IdxProp.Name + '[' + LIdxArgText + '] := aValue;');
            ImplBody.AppendLine('  Result := Self;');
            ImplBody.AppendLine('end;');
            ImplBody.AppendLine('');
          end;
          if IdxProp.IsReadable then
          begin
            var LGetParams: string;
            if LIdxParamText <> '' then LGetParams := '(' + LIdxParamText + ')' else LGetParams := '';
            ImplBody.AppendLine('function ' + ImplName + '.Get' + IdxProp.Name + LGetParams + ': ' +
              IdxProp.PropertyType.Name + ';');
            ImplBody.AppendLine('begin');
            ImplBody.AppendLine('  Result := FInstance.' + IdxProp.Name + '[' + LIdxArgText + '];');
            ImplBody.AppendLine('end;');
            ImplBody.AppendLine('');
          end;
        end;

        for Meth in RttiType.GetDeclaredMethods do
        begin
          if Meth.Parent <> RttiType then Continue; // class helper metodlarını dışarıda bırak
          if Meth.Visibility < mvPublic then Continue;
          if Meth.MethodKind in [mkConstructor, mkDestructor, mkClassProcedure, mkClassFunction] then Continue;

          var LParams := ParamListFor(Meth.GetParameters);
          if LParams <> '' then LParams := '(' + LParams + ')';
          var LArgs := ArgListFor(Meth.GetParameters);
          if LArgs <> '' then LArgs := '(' + LArgs + ')';

          if Meth.MethodKind = mkFunction then
            ImplBody.AppendLine('function ' + ImplName + '.' + Meth.Name + LParams + ': ' +
              Meth.ReturnType.Name + ';')
          else
            ImplBody.AppendLine('procedure ' + ImplName + '.' + Meth.Name + LParams + ';');
          ImplBody.AppendLine('begin');
          if Meth.MethodKind = mkFunction then
            ImplBody.AppendLine('  Result := FInstance.' + Meth.Name + LArgs + ';')
          else
            ImplBody.AppendLine('  FInstance.' + Meth.Name + LArgs + ';');
          ImplBody.AppendLine('end;');
          ImplBody.AppendLine('');
        end;

        Result := DeclBody.ToString + sLineBreak +
          '// ---------------------------------------------------------------------------' + sLineBreak +
          '// Implementasyon gövdeleri (unit''in implementation bölümüne eklenecek)' + sLineBreak +
          '// ---------------------------------------------------------------------------' + sLineBreak +
          ImplBody.ToString;
      finally
        MemberDecls.Free;
        DeclBody.Free;
        ImplBody.Free;
      end;
    finally
      MethodOverloadCount.Free;
    end;
  finally
    Ctx.Free;
  end;
end;

{ TResult<T> }

class function TResult<T>.Success(const AValue: T): TResult<T>;
begin
  Result.FValue := AValue;
  Result.FSuccess := True;
  Result.FErrorMsg := '';
end;

class function TResult<T>.Failure(const AErrorMsg: string): TResult<T>;
begin
  Result.FSuccess := False;
  Result.FErrorMsg := AErrorMsg;
  // FValue default(T) olarak kal�r (Managed record de�ilse manuel s�f�rlanabilir)
end;

class function TResult<T>.FromException(const E: Exception): TResult<T>;
begin
  Result := TResult<T>.Failure(E.Message);
end;

function TResult<T>.GetValue: T;
begin
  if not FSuccess then
    raise EInvalidOpException.Create('Hatal� bir sonucun degeri okunamaz. Hata: ' + FErrorMsg);
  Result := FValue;
end;

function TResult<T>.TryGetValue(out AValue: T): Boolean;
begin
  Result := FSuccess;
  if Result then
    AValue := FValue;
end;

const
  CDateTolerance: Double = 1.157407407407407E-9; // ~0.1 ms, TDateTime gün biriminde

function DateEQ(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := Abs(ADate1 - ADate2) < CDateTolerance;
end;

function DateLT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := (ADate2 - ADate1) >= CDateTolerance;
end;

function DateLE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := not DateGT(ADate1, ADate2);
end;

function DateGT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := (ADate1 - ADate2) >= CDateTolerance;
end;

function DateGE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := not DateLT(ADate1, ADate2);
end;

function FixDT(const ADate: TDateTime): TDateTime;
begin
  Result := Round(ADate * MSecsPerDay) / MSecsPerDay;
end;

function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;
var
  LFirstOfMonth, LLastOfMonth, LResult: TDateTime;
  LFirstDow: Word;
  LOffset: Integer;
begin
  LFirstOfMonth := EncodeDate(AYear, AMonth, 1);
  LFirstDow := DayOfWeek(LFirstOfMonth); // 1=Pazar..7=Cumartesi
  LOffset := ADayInWeek - LFirstDow;
  if LOffset < 0 then
    Inc(LOffset, 7);
  LResult := LFirstOfMonth + LOffset; // ayın ilk ADayInWeek günü

  if AWeekInMonth = 5 then
  begin
    LLastOfMonth := EncodeDate(AYear, AMonth, DaysInAMonth(AYear, AMonth));
    while LResult + 7 <= LLastOfMonth do
      LResult := LResult + 7;
  end
  else
    LResult := LResult + 7 * (AWeekInMonth - 1);

  Result := LResult;
end;


{ TUtils }

class procedure TUtils.InUI(AProc: TProc);
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    AProc()
  else
    TThread.ForceQueue(nil, procedure begin AProc() end);
end;

Initialization


finalization


end.







