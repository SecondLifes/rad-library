unit Help.vcl;

interface
uses
  Winapi.Windows, Winapi.Messages, System.ObjAuto ,System.SysUtils, System.Classes, UITypes,
  System.Generics.Collections, System.Actions, Vcl.Controls,
  Vcl.ActnList, System.Rtti, vcl.Forms, Vcl.Menus, Vcl.Dialogs,System.Threading
  ,mormot.core.base
  ,rad.core
  ;

type

  TWinPosition = (wpTopLeft, wpTopRight, wpBottomLeft, wpBottomRight, wpCenter, wpCustom);
  THorzAlign = (haInsideLeft, haCenter, haInsideRight, haOutsideLeft, haOutsideRight);
  TVertAlign = (vaInsideTop, vaCenter, vaInsideBottom, vaOutsideTop, vaOutsideBottom);


{
 Form Yaşam Döngüsü
 OnCreate -> OnShow -> OnActivate -> OnPaint -> OnResize -> OnPaint ...
 OnCloseQuery -> OnClose -> OnDeactivate -> OnHide -> OnDestroy
}

 TFormEventType = (fetCreate, fetShow, fetActivate, fetClose, fetDeactivate, fetHide, fetFree, fetCaptionChange);
 TGlobalFormEvent = procedure(const AControl: TForm; const AEvent: TFormEventType) of object;

  { KOPRU (TFormEventBridge) BU SINIFA TAKILMAZ - bilerek.

    Kopru bir TELAFI mekanizmasidir: duz TForm'un yasam dongusu kancasi
    olmadigi icin pencere yordamini ele gecirip mesajlardan olay uretir.
    TRadFormBase'in o kancalarinin hepsi ZATEN var ve daha fazlasini kapsar:

      Kopru                          TRadFormBase
      -----------------------------  --------------------------------
      HookClose -> caFree            DoClose (FAutoFree ile ayni is)
      CM_ACTIVATE   -> fetActivate   Activate
      CM_DEACTIVATE -> fetDeactivate Deactivate
      WM_CLOSE      -> fetClose      DoClose
      WM_DESTROY    -> fetFree       DoDestroy
      CM_TEXTCHANGED-> fetCaption... CMTextChanged (asagida eklendi)
      (yok)                          DoCreate / DoShow / DoHide

    Ikisini birden takmak CIFT TETIKLEME uretirdi: Activate hem kendi
    olayini hem koprunun CM_ACTIVATE dalini calistirirdi. }
  TRadFormBase = class(TForm)
  private
    FAutoFree   : Boolean;
    FIsShow     : Boolean;
    { Yasam dongusu kancalarinin CAGIRDIGI tek nokta. DoEvent'i dogrudan
      cagirmiyorlar: DoEvent turev icin uzanti noktasidir ve `inherited`
      cagirmayan bir override, global fabrika baglantisini sessizce
      koparirdi. Buradan ikisi de garanti calisir. }
    procedure NotifyEvent(const AEvent: TFormEventType);
    procedure CMTextChanged(var Msg: TMessage); message CM_TEXTCHANGED;
  protected
    procedure ClientWndProc(var Message: TMessage); override;
    procedure WmCMD(var Msg: TMessage); message WM_CMD;
    //function  CmdSys(const AID:SmallInt):variant;
    procedure DoCreate; override;
    procedure DoShow; override;
    procedure Activate; override;
    procedure DoClose(var Action: TCloseAction); override;
    procedure Deactivate; override;
    procedure DoHide; override;
    procedure DoDestroy; override;
    procedure DoEvent(const AEvent: TFormEventType); virtual;

  public
    function _IsShowing:Boolean;
    function _ShowWait: TForm;
    property _AutoFree: Boolean read FAutoFree write FAutoFree;
  {
    function _ShowMDIChild: TForm;
    begin

     if FormStyle<>fsMDIChild then
      begin
       PostMessage(Self.Handle, WM_CMD,99, WM_EVENT_CREATE);
      end else Show;

    end;
   }
  end;

  TPersistentHack = class(TPersistent)
  public
     function _GetNamePath: string;
  end;

  TWinControlHook = class(TComponent)
  private
    FControl: TWinControl;
    FOldProc: TWndMethod;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoWndProc(var Msg: TMessage); virtual;
  public
    constructor Create(AControl: TWinControl); reintroduce;
    destructor Destroy; override;
    property Control: TWinControl read FControl;
  end;

{
 Form Yaşam Döngüsü
 OnCreate -> OnShow -> OnActivate -> OnPaint -> OnResize -> OnPaint ...
 OnCloseQuery -> OnClose -> OnDeactivate -> OnHide -> OnDestroy
}

  TFormEventBridge = class(TWinControlHook)
  private
    FAutoFree: Boolean; // Form kapatılınca Free edilsin mi?
    FOldClose: TCloseEvent;
    procedure HookClose(Sender: TObject; var Action: TCloseAction);
  protected
    procedure DoWndProc(var Message: TMessage); override;
  public
    constructor CreateBridge(const AForm: TForm; const aAutoFree: Boolean); reintroduce;
    /// Form yok edilirken fabrikanin sozlugunden de dusurur.
    destructor Destroy; override;
    property AutoFree: Boolean read FAutoFree write FAutoFree;
  end;


  TFormFactory = class//(TComponent, IEventHandler) //IFormVisualManager
  private
    FOnEvent: TGlobalFormEvent; // Global Event Handler
    FForms: TDictionary<string, TCustomForm>;
  protected
    procedure DoEvent(const AForm: TForm; const AEvent: TFormEventType);
  public

    procedure RegisterEvent(AEvent: TGlobalFormEvent);
    procedure UnregisterForm(const AForm: TCustomForm);

    function Get<T: TForm>(const AUniqueName: string = ''; const AFormStyle: TFormStyle = fsNormal; AOwner: TComponent = nil): T;
    function New<T: TForm>(const AFormStyle: TFormStyle; AOwner: TComponent = nil): T;

    constructor Create;
    destructor Destroy; override;
    //property OnEvent: TGlobalFormEvent read FOnEvent write FOnEvent;
  end;


  TObjectHelper = class helper for TObject
  private
  public
    function _SetEvent(const AEventName: string; const AMethod: TMethod):TObject;
    function _To<T>:T; overload;
    function _AsObj<T:class>:T;
    function _AsIX<T:IInterface>:T;


    //Rtti Fonksiyonları
    function _ValueGet(const AProp: RawUtf8): Variant;
    function _ValueSet(const AProp: RawUtf8; const v:Variant): Boolean;
    function _ValueGetPath(const APath: RawUtf8): Variant;
    { APath RawUtf8: yol her zaman metindir. Variant olarak bildirilmesi
      GetInstanceByPath cagrisinda ortuk donusume ve W1057 uyarisina yol
      aciyordu. AValue Variant kalir - yazilan DEGER gercekten her tip
      olabilir. }
    function _ValueSetPath(const APath: RawUtf8; const AValue: Variant): Boolean;
    function _ValueGetPathText(const APath: RawUtf8): RawUtf8;
    function _ValueSetPathText(const APath, AValue: RawUtf8): Boolean;

  end;


  TWinControlHelper = class helper for TWinControl
  private
  public
    function _ScaleToCurrentMonitor(const AValue: Integer): Integer;
    function _PositionEx(const ARect: TRect; AHorz: THorzAlign; AVert: TVertAlign; AOffset: Integer = 0): TWinControl; overload;
    function _Position(const aRect: TRect; const aPosition: TWinPosition): TWinControl; overload;
    function _Position(const aPosition: TWinPosition; const aForm: TCustomForm = nil): TWinControl; overload;
  end;

  { TFrameHelper ve TChildFormHelper1 KALDIRILDI: ikisi de tamamen bostu.
    Bos bir helper zararsiz gorunur ama zararlidir - Delphi'de bir tip icin
    yalnizca EN YAKIN helper gorunur, bos bir helper ileride ara katmandaki
    baska bir helper'i gizleyebilir. }

  TFormHelper = class helper for TCustomForm
  private

  public
   class function _New(const AFormStyle: TFormStyle=fsNormal; AOwner: TComponent = nil):TForm; overload;

   class function _Modal(const APosition:TPosition = TPosition.poScreenCenter; const AOnCreate:TProc<TCustomForm>=nil; const AOnBeforeFree:TProc<TCustomForm>=nil):TModalResult; overload;
   /// <summary>
   ///   Formu MODAL acar, ALoadData'yi arka planda calistirir, veri hazir
   ///   olunca AOnDataReady'yi ANA THREAD'de cagirir.
   /// </summary>
   /// <remarks>
   ///   SOZLESME:
   ///   * Form bu metoda aittir: yaratir, modal gosterir, free eder.
   ///   * LData da bu metoda aittir: AOnDataReady dondukten HEMEN SONRA
   ///     free edilir. Geri cagirim ihtiyaci olani KOPYALAMALIDIR.
   ///   * ALoadData istisna atarsa AOnError cagrilir (verilmemisse
   ///     Application.ShowException) ve modal mrAbort ile kapanir.
   ///   * Kullanici formu veri gelmeden kapatirsa AOnDataReady HIC
   ///     cagrilmaz - sarkan isaretciye erisilmez.
   /// </remarks>
   class function _ModalAsync(const ALoadData: TFunc<TObject>;
     const AOnDataReady: TProc<TObject, TCustomForm>;
     const AOnError: TProc<Exception> = nil): TModalResult;


   { DefClientProc KALDIRILDI. Tek cagiran Core.Form.ClientWndProc idi ve o
     artik `inherited` kullaniyor. Kaldirilma sebebi cagrisiz kalmasi degil,
     BOZUK olmasiydi: GetWindowLong(Self.Handle, GWL_WNDPROC) formun
     yordamini, ustelik VCL alt siniklamayi yaptiktan SONRA donduruyordu.
     VCL'in gercek karsiligi FDefClientProc'tur ve ISTEMCI penceresinin
     yordamini alt siniklamadan ONCE yakalar (Vcl.Forms.pas:7889). Alan
     private oldugu icin taklit edilemez; dogru cozum ona ihtiyac
     duymamaktir. Ayrinti: Core.Form.ClientWndProc'un basligi.

     function TFormHelper.DefClientProc: TFarProc;
    begin
     Result := Pointer(GetWindowLong(self.Handle, GWL_WNDPROC));//Self.FDefClientProc;
    end;
     }
   function _ArgClas<T:class>(AProc:TProc<T>=nil):TArray<T>;
   function _AnimateShow(AFadeDuration: Integer = 200):TCustomForm;

   function  _SetPosition(const APosition:TPosition):TCustomForm;
   function  _SetWindowsState(const AWindowState:TWindowState):TCustomForm;
   function  _SetStateNormal:TCustomForm;
   function  _SetStateMinimized:TCustomForm;
   function  _SetStateMaximized:TCustomForm;

   // TCoreForm formları için
   function  _SetAutoFree(const aAutoFree:Boolean):TCustomForm;

   //function _Modal(const AOnClose:TProc<TCustomForm>=nil):TModalResult; overload;
   function _Show: TCustomForm;
   function _ShowWait: TCustomForm;
   function _Hide: TCustomForm;
   function _EnsureInWorkArea: TCustomForm;
   function _FitToScreen(const AAllowShrink: Boolean = True): TCustomForm;
   // Güvenli MDI Dönüşümü
   function _MakeMDIChild: TCustomForm;
  end;




  TMenuItemHelp = class helper for TMenuItem
    function _AddOrGetPath(const ACaption:string):TMenuItem;
    function _AddOrGet(const ACaption:string):TMenuItem;
    function _Add(const ACaption:string; const AAction:TAction = nil; const AImgIndex:Integer=-1):TMenuItem;
    class function _Create(const ACaption:string;const AAction:TAction = nil; const AImgIndex:Integer=-1):TMenuItem;
    function _Caption:string;
    function _TreeCaption(const ASplitter:string='\'):string;
    function _SetHint(const aHint:string):TMenuItem;
    function _SetTag(const aTag:Integer):TMenuItem;
    function _SetClick(const aClick:TNotifyEvent):TMenuItem;
    function _ClearSubMenu:TMenuItem;
  end;

  TMainMenuHelp = class helper for TMenu
    procedure _ForEach(const AProc:TProc<TMenuItem>);
    function _FindTag(const ATag:Integer):TMenuItem;
    function _FindCaption(const ACaption:string):TMenuItem;
    function _Add(const ACaption:string; const ATag:Integer=-1; const AImage:Integer=-1):TMenuItem;
  end;

  TActionHelp = class helper for TAction
    procedure _Clone(const act:TCustomAction);
    procedure _Visible(const AVisible:Boolean); overload;
    function  _Execute:Boolean;
    class procedure _Visible(const arg:TArray<TAction>; const AVisible:Boolean=False;const AEnable:Boolean=False);overload;
  end;

  TActionListHelp = class helper for TCustomActionList
  public
   procedure _For(AProc:TProc<TAction>);
    function _UniqName:string;
    function _FindName(const AName:string):TAction;
    function  _DefaultKeyGet : TArray<TShortCut>;
    procedure _DefaultKeySet( const arg:TArray<TShortCut>);
  end;



      {$REGION 'FileDialog'}

   TOpenDialogHelp = class helper for TOpenDialog
      function _Exec(const AFilter:string; const AFilterIndex:Integer;const AFolder:string=''):Boolean;overload;
      function _Exec(out AFile:string):Boolean; overload;
      function _Exec:string; overload;
      function _Options(const AOptions:TOpenOptions):TOpenDialog;
      function _Title(const ATitle:string):TOpenDialog;
      function _OpenDir(const AOpenDir:string):TOpenDialog;
      function _Filter(const AFilter:string):TOpenDialog;

     end;

     TSaveDialogHelp = class helper for TSaveDialog
       function _Title(const ATitle:string):TSaveDialog;
       function _OptionsEx(const AOptionsEx:TOpenOptionsEx):TSaveDialog;
       function _Options(const AOptions:TOpenOptions):TSaveDialog;
       function _InitialDir(const AInitialDir:string):TSaveDialog;
       function _FilterIndex(const AFilterIndex:Integer):TSaveDialog;
       function _Filter(const AFilter:string):TSaveDialog;
       function _FileName(const AFileName:string):TSaveDialog;
       function _DefaultExt(const ADefaultExt:string):TSaveDialog;
     end;



    {$ENDREGION}

  var
   GlobalFormFactory:TFormFactory =nil;
  
implementation
uses
  System.TypInfo,
  //Help.Str,
  mormot.core.rtti,
  cxGeometry,cxControls; //,JvJVCLUtils;

 type

  TRttiPropHelper = record helper for TRttiProp
  public
   function _ValueGet(Instance: TObject):Variant;
  end;

  { _ModalAsync'in "form hala yasiyor mu" bayragi.

    ARAYUZ olmasi sart: closure onu yakalayinca refcount artar, yani metot
    donse bile nesne yasar. Duz bir Boolean yerel degisken olsaydi metot
    dondugunde yigindan silinirdi ve closure serbest bellege bakardi -
    duzeltmeye calistigimiz hatanin ta kendisi.

    Yalnizca ANA THREAD'den okunup yazilir (Queue ve ShowModal'in finally'si
    ikisi de ana thread'de), o yuzden ek bir kilide gerek yok. }
  IRadAsyncCtx = interface
    ['{2D9A4F17-6C83-4E5B-9A71-0F3E8B25C4D6}']
    function Gecerli: Boolean;
    procedure Iptal;
  end;

  TRadAsyncCtx = class(TInterfacedObject, IRadAsyncCtx)
  private
    FGecerli: Boolean;
  public
    constructor Create;
    function Gecerli: Boolean;
    procedure Iptal;
  end;

constructor TRadAsyncCtx.Create;
begin
  inherited Create;
  FGecerli := True;
end;

function TRadAsyncCtx.Gecerli: Boolean;
begin
  Result := FGecerli;
end;

procedure TRadAsyncCtx.Iptal;
begin
  FGecerli := False;
end;

function ScreenWorkArea(AControl: TWinControl = nil): TRect;
var
  LMon: TMonitor;
begin
  { AControl verilirse ONUN monitorunun calisma alani doner.

    Eski hâl her zaman AKTIF formun monitorunu kullaniyordu. Cok monitorlu
    bir kurulumda 2. ekrandaki bir formu _EnsureInWorkArea ile hizalamak,
    aktif form 1. ekrandaysa formu 1. ekrana ITIYORDU - kullanicinin
    baktigi yerden kaybolan bir pencere.

    HandleAllocated kontrolu de onemli: .Handle okumak pencere tanitici-
    sini ZORLA yarattirir. Henuz gosterilmemis bir kontrol icin bu istenmez;
    o durumda birincil calisma alanina duseriz. }
  LMon := nil;

  if Assigned(AControl) and AControl.HandleAllocated then
    LMon := Screen.MonitorFromWindow(AControl.Handle)
  else if Assigned(Screen.ActiveCustomForm) and
          Screen.ActiveCustomForm.HandleAllocated then
    LMon := Screen.MonitorFromWindow(Screen.ActiveCustomForm.Handle);

  if Assigned(LMon) then
    Exit(LMon.WorkareaRect);

  {$IFDEF MSWINDOWS}
  if SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0) then
    Exit;
  {$ENDIF MSWINDOWS}
  Result := Bounds(0, 0, Screen.Width, Screen.Height);
end;

{ TFormHelper }


function TFormHelper._AnimateShow(AFadeDuration: Integer):TCustomForm;
const
  CAdim = 25;
var
  LForm: TCustomForm;
  LAdimMs: Integer;
begin
  { Eski hâlin uc sorunu vardi:

    1) Result HIC atanmiyordu (W1035) -> cagirana cop isaretci donuyordu.

    2) Anonim thread `Self`i yakaliyordu. Metot donduktan sonra form FREE
       edilirse `Self` sarkan bir isaretcidir; `Self.ComponentState`
       okumak SERBEST BIRAKILMIS BELLEGI okumaktir. Bu her zaman istisna
       atmaz — cogu zaman cop deger okur ve kontrol gecer, sonra
       AlphaBlendValue yazilir. Bos `except` de bunu gizliyordu.
       Cozum: Screen.CustomForms uzerinden formun HALA VAR oldugunu
       dogruluyoruz; serbest birakilmis bir form o listeden cikarilmis
       olur, yani sarkan isaretciyi guvenle eleriz.

    3) Sleep(AFadeDuration div 25): AFadeDuration < 25 ise bolum 0 verir ve
       dongu bosa doner. Alt sinir koyuldu.

    Bos `except` de kaldirildi: kitin kurali (delphi-conventions.md) genel
    yakalamayi yasakliyor, ve burada yuttugu sey gercek bir bellek hatasiydi. }
  Result := Self;
  LForm := Self;
  LAdimMs := AFadeDuration div CAdim;
  if LAdimMs < 1 then
    LAdimMs := 1;

  Self.AlphaBlendValue := 0;
  Self.AlphaBlend := True;
  Self.Show;

  TThread.CreateAnonymousThread(procedure
  var
    i: Integer;
  begin
    for i := 0 to CAdim do
    begin
      TThread.Synchronize(nil, procedure
      var
        j: Integer;
        LHalaVar: Boolean;
      begin
        LHalaVar := False;
        for j := 0 to Screen.CustomFormCount - 1 do
          if Screen.CustomForms[j] = LForm then
          begin
            LHalaVar := True;
            Break;
          end;
        if LHalaVar and not (csDestroying in LForm.ComponentState) then
          LForm.AlphaBlendValue := i * 10;
      end);
      Sleep(LAdimMs);
    end;
  end).Start;
end;

function TFormHelper._ArgClas<T>(AProc: TProc<T>): TArray<T>;
var
  i, LSayi: Integer;
begin
  { `ClassType = T` TAM ESLESMEYDI: alt siniflari eliyordu. _ArgClas<TButton>
    bir TBitBtn'i dondurmuyordu - oysa TBitBtn bir TButton'dur ve cagiran
    bunu bekler. `is` ile miras zinciri de kapsaniyor.

    Ayrica dizi her eslesmede birer buyutuluyordu (O(n^2) yeniden ayirma);
    once sayilip TEK SEFERDE ayriliyor. }
  LSayi := 0;
  for i := 0 to ComponentCount - 1 do
    if Components[i] is T then
      Inc(LSayi);

  SetLength(Result, LSayi);
  if LSayi = 0 then
    Exit;

  LSayi := 0;
  for i := 0 to ComponentCount - 1 do
    if Components[i] is T then
    begin
      if Assigned(AProc) then
        AProc(T(Components[i]));
      Result[LSayi] := T(Components[i]);
      Inc(LSayi);
    end;
end;

function TFormHelper._EnsureInWorkArea: TCustomForm;
var
  R: TRect;
  NewLeft, NewTop: Integer;
begin
  Result := Self;
  R := ScreenWorkArea(Self);   // A-03: KENDI monitorumuz

  NewLeft := Self.Left;
  NewTop := Self.Top;

  // 1. Adım: Önce Sağ ve Alt taşmalarını düzeltmeye çalış (İçeri it)
  if (NewLeft + Width) > R.Right then   NewLeft := R.Right - Width;
  if (NewTop + Height) > R.Bottom then  NewTop := R.Bottom - Height;

  // 2. Adım: KRİTİK NOKTA!
  // Sol ve Üst kontrolünü SONRA yapıyoruz.
  // Böylece form ekrandan büyükse bile, 1. adımda yapılan ötelemeyi ezer
  // ve Başlık Çubuğunu (Top-Left) mutlaka ekran içinde tutar.
  if NewLeft < R.Left then NewLeft := R.Left;
  if NewTop < R.Top then NewTop := R.Top;

  // 3. Adım: Eğer bir değişiklik varsa uygula
  // Left ve Top'u ayrı ayrı set etmek yerine SetBounds kullanmak
  // işletim sistemine tek mesaj gönderir, daha performanslıdır.
  if (NewLeft <> Self.Left) or (NewTop <> Self.Top) then
    Self.SetBounds(NewLeft, NewTop, Width, Height);
end;

function TFormHelper._FitToScreen(const AAllowShrink: Boolean): TCustomForm;
var
  R: TRect;
  Ratio, RatioW, RatioH: Double;
  NewW, NewH: Integer;
begin
  Result := Self;
  R := ScreenWorkArea(Self);   // A-03: KENDI monitorumuz

  // 1. Mevcut genişlik ve yükseklik ekrana sığıyor mu?
  if (Width <= R.Width) and (Height <= R.Height) then
    Exit(Self._EnsureInWorkArea);  // Sığıyorsa ölçekleme yapma, sadece ekrana sok (önceki mantık)

  // 2. Eğer küçültmeye izin verilmediyse (parametre ile), normal davran
  if not AAllowShrink then  Exit(Self._EnsureInWorkArea);

  // --- ÖLÇEKLEME MANTIĞI ---

  { NOT - burada sifira bolme korumasi YOK, cunku GEREKMIYOR.
    Bu noktaya ancak yukaridaki ilk kontrol basarisiz olunca gelinir, yani
    Width > R.Width olmak zorundadir - dolayisiyla Width > 0'dir. Onceki bir
    duzeltme turunda buraya bir (Width <= 0) korumasi eklenmisti; olculdu,
    ULASILAMAZ oldugu gorulup kaldirildi. Sifir boyutlu form zaten ilk
    kontrolden _EnsureInWorkArea'ya cikiyor. }

  // 3. Oranları Hesapla (Genişlik ve Yükseklik için ne kadar küçülmeli?)
  RatioW := R.Width / Width;
  RatioH := R.Height / Height;

  // 4. En kısıtlı oranı seç (En boy oranını (Aspect Ratio) bozmamak için)
  // Hangisi daha küçükse onu baz alacağız ki form tamamen sığsın.
  if RatioW < RatioH then
    Ratio := RatioW
  else
    Ratio := RatioH;

  // Biraz kenar boşluğu bırakalım (Tam yapışmasın, %95'i kadar olsun)
  Ratio := Ratio * 0.95;

  // 5. VCL ScaleBy Metodu ile Formu Küçült
  // ScaleBy(Pay, Payda) mantığıyla çalışır.
  // Örn: Ratio 0.8 ise -> ScaleBy(80, 100) demektir.
  if Ratio < 1.0 then
  begin
    { DIKKAT — hedef boyutlar ScaleBy'DAN ONCE hesaplanmali.

      Eski hâlde once ScaleBy cagriliyor, sonra `NewW := Round(Width * Ratio)`
      yaziliyordu. Ama ScaleBy Width'i ZATEN kucultmustu; ikinci carpim ayni
      orani bir kez daha uyguluyor ve form iki kat kuculuyordu.
      Ornek: 1000 genislik, Ratio 0.8 -> ScaleBy sonrasi 800, sonra
      800*0.8 = 640. Beklenen 800 idi. }
    NewW := Round(Width * Ratio);
    NewH := Round(Height * Ratio);

    Self.ScaleBy(Round(Ratio * 100), 100);

    // SetBounds ile hem boyutlandır hem ortala
    Self.SetBounds(
      R.Left + ((R.Width - NewW) div 2),
      R.Top + ((R.Height - NewH) div 2),
      NewW,
      NewH
    );
  end;

end;

function TFormHelper._Hide: TCustomForm;
begin
  { DIKKAT - MODAL formda bu metot formu KAPATIR, gizlemez.
    Modal bir formun kendi mesaj dongusu vardir; Hide onu gizlemez, yalnizca
    ModalResult atamak dongudan cikarir. Yani ad "hide" olsa da modal
    baglamda etkisi iptaldir. Adi degistirmek cagiranlari kirardi; davranis
    korunuyor, sozlesme burada yaziliyor. }
Result := Self;
  if fsModal in Self.FormState then
    Self.ModalResult := mrCancel
  else
    Self.Hide;
end;

function TFormHelper._MakeMDIChild: TCustomForm;
var
  LGorunurdu: Boolean;
begin
Result := Self;
  // Sadece Main form MDI container ise ve kendisi zaten child değilse
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsMDIForm) and
     (Self.FormStyle <> fsMDIChild) then
  begin
    { ONCEKI GORUNURLUK GERI VERILIYOR.

      Eski hâl Hide cagirip FormStyle degistiriyor ve orada biriyordu; yorum
      da "MDI child'lar genelde otomatik gorunur" diyordu - bu bir TAHMINDI.
      FormStyle degisimi pencere tanitiсisini yeniden yaratir ama Visible'i
      True yapmaz; Hide zaten False yapmisti. Yani form GIZLI kaliyordu ve
      cagiran bunu goremiyordu.
      Bu metodun isi stili degistirmek; gorunurluk kararini degistirmek
      degil. Girerken ne ise cikarken de o. }
    LGorunurdu := Self.Visible;
    Self.Hide;   // stil degisimindeki gorsel titremeyi onler
    Self.FormStyle := fsMDIChild;
    Self.Visible := LGorunurdu;
  end;
end;


class function TFormHelper._Modal(const APosition:TPosition; const AOnCreate, AOnBeforeFree: TProc<TCustomForm>): TModalResult;
var
  LForm: TCustomForm;
begin
  // Form instance'ını oluştur
  LForm := TFormClass(Self).Create(nil); // Owner nil, çünkü manuel free edeceğiz
  try
    if Assigned(AOnCreate) then AOnCreate(LForm);
    LForm.Position:=APosition;
    Result := LForm.ShowModal;

    // Form kapandıktan sonra ama yok edilmeden önce son bir işlem (örn: veri okuma)
    if Assigned(AOnBeforeFree) then AOnBeforeFree(LForm);

  finally
    LForm.Free;
  end;
end;

class function TFormHelper._ModalAsync(const ALoadData: TFunc<TObject>;
  const AOnDataReady: TProc<TObject, TCustomForm>;
  const AOnError: TProc<Exception>): TModalResult;
var
  LForm: TCustomForm;
  LGecerli: IRadAsyncCtx;
begin
  { ESKI HALIN BES AYRI SORUNU VARDI - hepsi sessizdi:

    1) Adi "Modal" ama Show cagiriyordu; metot hemen donuyordu.
    2) Form Create(nil) ile SAHIPSIZ yaratiliyor ve hicbir yerde free
       edilmiyordu -> her cagrida bir form siziyordu.
    3) LData'yi "AOnDataReady icinde free edin" diyordu, ama AOnDataReady
       nil ise kimse etmiyordu -> sizinti.
    4) ALoadData istisna atarsa TTask onu yutuyordu: form bos kaliyor,
       kullanici hicbir sey gormuyor, hata kayboluyordu.
    5) EN AGIRI: kullanici formu veri gelmeden kapatirsa LForm SARKAN
       ISARETCI oluyordu ve geri cagirim olu nesneye erisiyordu.

    Cozumun cekirdegi MODAL olmasi: ShowModal kendi mesaj dongusunu
    calistirdigi icin TThread.Queue o dongu ayaktayken tetiklenir, yani
    form yasarken doldurulur. Yine de kullanici veri gelmeden kapatabilir;
    onun icin sayilan bir baglam nesnesi tutuyoruz. Closure onu tutar
    (refcount canli kalir), metot form olmeden once Iptal isaretler.
    Queue tetiklendiginde baglam iptal ise HICBIR SEYE dokunmaz. }

  LGecerli := TRadAsyncCtx.Create;
  LForm := TFormClass(Self).Create(nil);
  try
    TTask.Run(
      procedure
      var
        LData: TObject;
        LHata: TObject;
      begin
        LData := nil;
        LHata := nil;
        try
          LData := ALoadData();
        except
          // Istisnayi TASIYORUZ: ana thread'de bildirilecek. Eski hâlde
          // TTask onu sessizce yutuyordu.
          LHata := AcquireExceptionObject;
        end;

        TThread.Queue(nil,
          procedure
          begin
            if not LGecerli.Gecerli then
            begin
              // Form kapandi: forma da geri cagirima da DOKUNMA, sadece temizle.
              LData.Free;
              LHata.Free;
              Exit;
            end;

            try
              if LHata <> nil then
              begin
                if Assigned(AOnError) then
                  AOnError(Exception(LHata))
                else
                  Application.ShowException(Exception(LHata));
                LForm.ModalResult := mrAbort;
                Exit;
              end;

              if Assigned(AOnDataReady) then
                AOnDataReady(LData, LForm);
            finally
              { LData BU METODA aittir ve geri cagirim dondukten hemen sonra
                silinir. Geri cagirim ihtiyaci olani kopyalamalidir. Eski
                "siz free edin" kurali, AOnDataReady nil oldugunda sizinti
                birakiyordu. }
              LData.Free;
              LHata.Free;
            end;
          end);
      end);

    Result := LForm.ShowModal;
  finally
    { ONCE iptal, SONRA free. Sirasi onemli: bu iki satirin arasinda
      Queue tetiklenirse baglam zaten iptal oldugu icin forma dokunmaz. }
    LGecerli.Iptal;
    LForm.Free;
  end;
end;




class function TFormHelper._New(const AFormStyle: TFormStyle; AOwner: TComponent): TForm;
var
  LNeedStyleChange: Boolean;
begin
  if AOwner = nil then AOwner := Application;
  Result := TFormClass(Self).Create(AOwner);
  LNeedStyleChange := (Result.FormStyle <> AFormStyle);
  if (AFormStyle = fsMDIChild) and LNeedStyleChange then
  begin
    if (Application.MainForm = nil) or (Application.MainForm.FormStyle <> fsMDIForm) then
      LNeedStyleChange := False;
  end;

  if LNeedStyleChange then
  begin
    if Result.Visible then Result.Hide;
    Result.FormStyle := AFormStyle;
    if AFormStyle = fsMDIChild then
    begin
      Result.Visible := True;
      Result.BringToFront;
    end;
  end;

end;

function TFormHelper._SetAutoFree(const aAutoFree: Boolean): TCustomForm;
begin
 Result:=self;
 if Self is TRadFormBase then TRadFormBase(Self)._AutoFree:=aAutoFree;

end;

function TFormHelper._SetPosition(const APosition: TPosition): TCustomForm;
begin
 result:=Self;
 TForm(Self).Position:=APosition;
end;

function TFormHelper._SetStateMaximized: TCustomForm;
begin
 Result:=_SetWindowsState(TWindowState.wsMaximized);
end;

function TFormHelper._SetStateMinimized: TCustomForm;
begin
  Result:=_SetWindowsState(TWindowState.wsMinimized);
end;

function TFormHelper._SetStateNormal: TCustomForm;
begin
   Result:=_SetWindowsState(TWindowState.wsNormal);
end;

function TFormHelper._SetWindowsState(const AWindowState: TWindowState): TCustomForm;
begin
Result := Self;

  // Gereksiz titremeyi önlemek için kontrol
  if Self.WindowState = AWindowState then Exit;

  // MDI Child formlar bazen doğrudan atamalarda garip davranabilir,
  // ama %99 durumda standart atama yeterlidir.
  Self.WindowState := AWindowState;

  // Eğer MDI Child ise ve görsel güncelleme gerekirse:
  if (Self.FormStyle = fsMDIChild) and (AWindowState = wsMinimized) then
     Application.ProcessMessages; // Bazen ikonun yerine oturması için gerekir (nadiren)

 {
  case AWindowState of
    TWindowState.wsNormal: Self.WindowState := TWindowState.wsNormal;
    TWindowState.wsMinimized: begin
                               if IsIconic(Self.Handle) then Exit; // Zaten minimize ise işlem yapma

                                // VCL'in standart metodunu veya Windows API'sini kullan
                                if Self.FormStyle = fsMDIChild then
                                  SendMessage(Self.Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0)
                                else
                                  Self.WindowState := wsMinimized;
                              end;
    TWindowState.wsMaximized: begin
                               if IsZoomed(Self.Handle) then
                                  SendMessage(Self.Handle, WM_SYSCOMMAND, SC_RESTORE, 0)
                                else
                                  SendMessage(Self.Handle, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
                              end;
  end;
 }
end;

function TFormHelper._Show: TCustomForm;
begin
Result := Self;

  if IsIconic(Handle) then
  begin
    // Form minimize ise, animasyonlu şekilde eski haline getir
    SendMessage(Handle, WM_SYSCOMMAND, SC_RESTORE, 0);
  end
  else
  begin

    Self.Show;
    Self.BringToFront;
  end;
end;

function TFormHelper._ShowWait: TCustomForm;
const
  CZamanAsimiMs = 5000;   // form hic aktiflesmezse burada takilip kalmayalim
var
  LBitis: UInt64;
begin
  { Eski hâli `while not Active do Application.ProcessMessages;` idi. Iki
    ayri sorun:
      * Result HIC atanmiyordu (W1035) -> cagirana COP ISARETCI donuyordu.
      * Form hicbir zaman Active olmazsa (gizliyse, baska uygulama odagi
        aldiysa, modal bir pencere ustteyse) dongu SONSUZA kadar donuyor ve
        cekirdegi %100 mesgul ediyordu. Cikis kosulu yoktu.
    Simdi hem Result atanir hem de zaman asimi var. }
  Result := Self;
  if not Showing then
    Self.Show;
  LBitis := GetTickCount64 + CZamanAsimiMs;
  while (not Active) and (GetTickCount64 < LBitis) do
  begin
    Application.ProcessMessages;
    Sleep(1);   // bosa donmeyi engeller
  end;
end;

{ TWinControlHelper }

function TWinControlHelper._Position(const aRect: TRect; const aPosition: TWinPosition): TWinControl;
begin
  { Result ONCE atanir. Case'in else dali yok; atanmadan birakilirsa
    fonksiyon COP BIR ISARETCI dondurur (W1035) ve cagiran onu TWinControl
    sanip uzerinde metot cagirirsa erisim ihlali olur. TWinPosition'a
    ileride bir uye eklendiginde bu sessizce olurdu. }
  Result := Self;

  case aPosition of
    wpTopLeft:    Result := _PositionEx(aRect, haInsideLeft,  vaInsideTop);
    wpTopRight:   Result := _PositionEx(aRect, haInsideRight, vaInsideTop);
    wpBottomLeft: Result := _PositionEx(aRect, haInsideLeft,  vaInsideBottom);
    wpBottomRight:Result := _PositionEx(aRect, haInsideRight, vaInsideBottom);
    wpCenter:     Result := _PositionEx(aRect, haCenter,      vaCenter);
    { wpCustom: konumu CAGIRAN belirler, burada dokunmuyoruz.
      Eskiden `Result := Self as TForm` yaziyordu; bunun iki sorunu vardi:
      hicbir sey konumlandirmiyordu (yani `as` tamamen bosunaydi), ve Self
      bir TForm degilse EInvalidCast FIRLATIYORDU — bir TPanel'i wpCustom
      ile cagirmak patliyordu. Result zaten yukarida Self. }
    wpCustom:     ;
  end;
end;


function TWinControlHelper._ScaleToCurrentMonitor(const AValue: Integer): Integer;
begin
  // Delphi 10.3 Rio ve sonrası için Per-Monitor v2 desteği
{$IF CompilerVersion >= 33.0}
  Result := MulDiv(AValue, Self.CurrentPPI, 96);
{$ELSE}
  Result := AValue; // Eski sürümlerde standart kalır
{$IFEND}


// Kullanımı:
// NewLeft := ARect.Left + ScaleToCurrentMonitor(AOffset);
end;




function TWinControlHelper._Position(const aPosition: TWinPosition; const aForm: TCustomForm): TWinControl;
begin
  if AForm=nil then
    Result:=_Position(ScreenWorkArea(Self),aPosition)   // A-03
  else
    Result:=_Position(AForm.BoundsRect,aPosition)
end;



function TWinControlHelper._PositionEx(const ARect: TRect; AHorz: THorzAlign; AVert: TVertAlign; AOffset: Integer): TWinControl;
var
  NewLeft, NewTop: Integer;
begin
  Result := Self;

  { Bos referans dikdortgeni: hesap yapma, kontrolu YERINDE birak.

    ARect iki kaynaktan gelir: ScreenWorkArea, ya da baska bir formun
    BoundsRect'i (_Position'in aForm'lu asiri yuklemesi). O form henuz
    gosterilmemisse BoundsRect (0,0,0,0) olabilir; o zaman

      NewLeft := ARect.Right  - Width   ->  0 - 400 = -400
      NewTop  := ARect.Bottom - Height  ->  0 - 300 = -300

    cikar ve kontrol EKRAN DISINA tasinir. Kullanici hicbir sey gormez,
    hata da almaz. Yerinde birakmak en kotu ihtimalle yanlis konum verir,
    ama gorunur birakir.

    IsEmpty, IsRectEmpty uzerinden calisir (System.Types:1676): sifir
    alanli dikdortgenlerin yani sira TERS CEVRILMIS olanlari da yakalar.

    Bu kontrol en basta: bail-out edeceksek asagidaki Position degisikligi
    dahil hicbir yan etki birakmamaliyiz. }
  if ARect.IsEmpty then
    Exit;

  {
   MdiChil Formlar iin olabilir
   if Application.MainForm <> nil then  LockWindowUpdate(Application.MainForm.ClientHandle);
   LockWindowUpdate(0);

  }
    // Not: Eğer parent değişecekse Parent.Handle kullanılabilir.
    //SendMessage(Self.Handle, WM_SETREDRAW, WParam(False), 0);
    //Self.Perform(WM_SETREDRAW, 0, 0); // Çizimi durdur
    { VCL, form konumunu bizden SONRA ezer — sessizce, hata vermeden:

        * poDefaultPosOnly VARSAYILANDIR (Vcl.Forms.pas:5440) ve pencere
          yaratilirken konumu CW_USEDEFAULT yapar (a.g.e. 7737), yani
          Windows nereye isterse koyar.
        * poScreenCenter / poDesktopCenter / poMainFormCenter /
          poOwnerFormCenter ise CMShowingChanged icinde, OnShow'dan SONRA
          formu yeniden konumlandirir (a.g.e. 9448).

      Ikisi de sessiz: konum tutmaz ama istisna da alinmaz. Bu yuzden
      poDesigned'a cekiyoruz — cagiran zaten "formu buraya koy" diyor,
      bu VCL'e "sen karar verme" demenin ta kendisi.

      YAN ETKI: bu fonksiyon bir forma uygulandiginda Position ozelligini
      DEGISTIRIR. Bilerek sessiz; istisna firlatmak cagirani her seferinde
      elle poDesigned yazmaya zorlardi, kazanci olmazdi.

      Test TForm, TCustomForm DEGIL: Position, TCustomForm'da protected
      (a.g.e. 1044); disaridan erisilebilir hale gelmesi TForm'un onu
      yeniden yayimlamasiyla olur (a.g.e. 1315). TCustomForm ile test edip
      TForm'a cast etmek, TForm olmayan bir form soyu icin denetimsiz bir
      cast olurdu — su an alan yerlesimi ayni oldugu icin calisir, ama
      tesadufen. }
    if Self is TForm then
      if TForm(Self).Position <> poDesigned then
        TForm(Self).Position := poDesigned;

    Self.LockDrawing;

    try
      //if self is TCustomForm then
      // TForm(self).Position := poDesigned;

      // --- Yatay Hesaplama ---
      case AHorz of
        haInsideLeft:   NewLeft := ARect.Left + AOffset;
        haCenter:       NewLeft := ARect.Left + ((ARect.Right - ARect.Left) - Width) div 2;
        haInsideRight:  NewLeft := ARect.Right - Width - AOffset;
        haOutsideLeft:  NewLeft := ARect.Left - Width - AOffset;
        haOutsideRight: NewLeft := ARect.Right + AOffset;
        else NewLeft := self.Left;
      end;

      // --- Dikey Hesaplama ---
      case AVert of
        vaInsideTop:    NewTop := ARect.Top + AOffset;
        vaCenter:       NewTop := ARect.Top + ((ARect.Bottom - ARect.Top) - Height) div 2;
        vaInsideBottom: NewTop := ARect.Bottom - Height - AOffset;
        vaOutsideTop:   NewTop := ARect.Top - Height - AOffset;
        vaOutsideBottom:NewTop := ARect.Bottom + AOffset;
        else NewTop := self.Top;
      end;

      SetBounds(NewLeft, NewTop, Width, Height);
    finally
      // Çizimi tekrar aç ve invalidate et (tekrar boyat)
      //SendMessage(Self.Handle, WM_SETREDRAW, WParam(True), 0);
      //Self.Perform(WM_SETREDRAW, 1, 0); // Çizimi aç
      Self.UnlockDrawing(True);
      //RedrawWindow(Self.Handle, nil, 0, RDW_ERASE or RDW_FRAME or RDW_INVALIDATE or RDW_ALLCHILDREN);
      //RedrawWindow(Self.Handle, nil, 0, RDW_ERASE or RDW_FRAME or RDW_INVALIDATE or RDW_UPDATENOW or RDW_ALLCHILDREN);


    end;

end;


{ ============================================================================ }
{ TFormEventBridge }
{ ============================================================================ }

constructor TFormEventBridge.CreateBridge(const AForm: TForm; const aAutoFree: Boolean);
begin
  { Eski hâlde AForm bir TCoreForm ise `inherited Create` HIC CAGRILMIYORDU.
    Sonucu: TComponent kurucusu calismadigi icin nesnenin sahibi yoktu -
    kimse Free etmiyordu, yani her TCoreForm icin bir bridge SIZIYORDU.
    Ustelik FControl/FOldProc nil kaliyor, nesne yari kurulmus donuyordu.

    Simdi inherited HER DURUMDA cagriliyor (nesne gecerli ve forma ait
    olsun diye). TCoreForm'a ozel olan tek sey OnClose kancasinin
    takilmamasi: TCoreForm AutoFree'yi kendi yonetiyor, iki mekanizma ust
    uste binmemeli. }
  if AForm = nil then
    raise Exception.Create('TFormEventBridge: AForm nil olamaz');

  inherited Create(AForm);
  AutoFree := aAutoFree;

  if AForm is TRadFormBase then
  begin
    // TCoreForm kapanis davranisini kendi yonetir; OnClose'u ele gecirmiyoruz.
    AForm._SetAutoFree(aAutoFree);
    Exit;
  end;

  FOldClose := AForm.OnClose;
  AForm.OnClose := HookClose;
end;



destructor TFormEventBridge.Destroy;
begin
  { SARKAN ISARETCI DUZELTMESI.

    TFormFactory.Get<T> formu FForms sozlugune ekliyordu, ama sozlukten
    DUSUREN kimse yoktu - UnregisterForm yazilmisti ve hicbir yerden
    cagrilmiyordu. Bridge AutoFree=True ile formu kapanista yok ettigi
    icin sozlukte serbest birakilmis bir nesnenin adresi kaliyordu; ayni
    anahtarla ikinci Get<T> o olu isaretciyi donduruyordu.

    Bridge forma ait oldugu icin form yok edilirken bu destructor da
    calisir - dusurmek icin dogru yer burasi. }
  if Assigned(GlobalFormFactory) and Assigned(FControl) and
     (FControl is TCustomForm) then
    GlobalFormFactory.UnregisterForm(TCustomForm(FControl));
  inherited Destroy;
end;

procedure TFormEventBridge.HookClose(Sender: TObject; var Action: TCloseAction);
begin
  //if (FOwnerForm.FormStyle = fsMDIChild) or FAutoFree then
  if FAutoFree then  Action := caFree;
  //if FOwnerFactory <> nil then FOwnerFactory.DoFormEvent(FOwnerForm,fetClose);
  if Assigned(FOldClose) then FOldClose(Sender, Action);
end;


 procedure TFormEventBridge.DoWndProc(var Message: TMessage);
begin
  { FOldProc kontrolu ACIK olmali: Assigned testi yorumda birakilmisti ve
    hook takilamadigi her durumda burada nil cagrilirdi. }
  if Assigned(FOldProc) then
    FOldProc(Message);

  { GlobalFormFactory initialization'da YARATILMIYOR (asagida yorumda) ve
    hicbir yerde otomatik kurulmuyor. Nil kontrolu olmadan her mesajda
    erisim ihlali olurdu. Kontrolu buraya koyuyoruz, otomatik yaratmiyoruz:
    yasam dongusunu kimin yonettigi cagiranin karari. }
  if not Assigned(GlobalFormFactory) then
    Exit;
  if not Assigned(FControl) then
    Exit;   // Notification opRemove'da nil'lenmis olabilir

   case Message.Msg of
    CM_ACTIVATE: GlobalFormFactory.DoEvent(TForm(FControl),TFormEventType.fetActivate);
    CM_DEACTIVATE:GlobalFormFactory.DoEvent(TForm(FControl),TFormEventType.fetDeactivate);
    CM_TEXTCHANGED:GlobalFormFactory.DoEvent(TForm(FControl),TFormEventType.fetCaptionChange);
    WM_CLOSE:GlobalFormFactory.DoEvent(TForm(FControl),TFormEventType.fetClose);
    WM_DESTROY:GlobalFormFactory.DoEvent(TForm(FControl),TFormEventType.fetFree);
   end;
end;



{ ============================================================================ }
{ TFormFactory Implementation }
{ ============================================================================ }


constructor TFormFactory.Create;
begin
  //inherited;
  FForms := TDictionary<string, TCustomForm>.Create;
end;


destructor TFormFactory.Destroy;
begin
  { FABRIKA FORMLARI FREE ETMEZ - iki sebeple:

    1) CIFT SERBEST BIRAKMA. New<T> formu bir Owner ile yaratir (verilmezse
       Application). Sahip zaten yok edecek; fabrika da ederse ayni nesne
       iki kez serbest birakilir.

    2) SOZLUK DEGISIRKEN UZERINDE DONULUYORDU. `for frm in FForms.Values`
       icinde Free cagrilinca bridge'in destructor'i UnregisterForm'u
       tetikler, o da FForms.Remove yapar - numaralandirici gecersizlesir.

    Fabrika yalnizca KAYIT tutar, SAHIPLIK iddia etmez. }
  FForms.Free;
  inherited;
end;



procedure TFormFactory.DoEvent(const AForm: TForm; const AEvent: TFormEventType);
begin
  if Assigned(FOnEvent) then FOnEvent(AForm,AEvent);
end;


procedure TFormFactory.UnregisterForm(const AForm: TCustomForm);
var
  LKey: string;
  LBulunan: string;
  LVar: Boolean;
begin
  if FForms = nil then Exit;

  { Eski hâl numaralandirma SIRASINDA Remove cagiriyordu. Hemen ardindaki
    Break sayesinde pratikte patlamiyordu (bir sonraki MoveNext hic
    calismiyor) - yani KAZARA guvenliydi, tasarim geregi degil. Delphi'nin
    TDictionary numaralandiricisinda .NET'teki degisiklik korumasi yok, bu
    yuzden hata da vermezdi. Anahtari once bul, dongunun DISINDA sil. }
  LVar := False;
  LBulunan := '';
  for LKey in FForms.Keys do
    if FForms[LKey] = AForm then
    begin
      LBulunan := LKey;
      LVar := True;
      Break;
    end;

  if LVar then
    FForms.Remove(LBulunan);
end;

function TFormFactory.New<T>(const AFormStyle: TFormStyle; AOwner: TComponent): T;
begin
  if AOwner = nil then AOwner := Application;

  { _New() PARAMETRESIZ cagriliyordu; yani hem AOwner hem AFormStyle sessizce
    yok sayiliyor, form her zaman varsayilan sahiple (Application) ve
    fsNormal ile yaratiliyordu. Cagiranin verdigi Owner hicbir zaman
    kullanilmiyordu (H2077 bunu gosteriyordu). Artik ikisi de geciriliyor;
    asagidaki stil duzeltmesi de boylece cogu durumda hic gerekmiyor. }
  Result := TFormClass(T)._New(AFormStyle, AOwner) as T;
  //TForm(T).VisualManager:=Self as IFormVisualManager;
  
  { IKI AILE, AYNI SOZLESME - ama farkli yoldan.

    TRadFormBase kendi yasam dongusu kancalarina sahiptir (DoClose zaten
    FAutoFree'yi uygular, DoDestroy kaydi dusurur, NotifyEvent global
    dinleyiciyi besler), dolayisiyla ona kopru TAKILMAZ; yalnizca bayrak
    verilir. Kopru takmak cift tetikleme uretirdi - ayrinti icin
    TRadFormBase'in tip bildirimindeki tablo.

    Eski hâlde bu dal SESSIZCE ATLANIYORDU: `if not (Result is TRadFormBase)`
    kosulu yalnizca kopruyu degil AutoFree niyetini de es geciyordu, yani
    ayni Get<T> cagrisi duz forma "kapaninca yok et", TRadFormBase'e
    "yasamaya devam et" diyordu. Olculdu: rad_formfactory testi 03/04. }
  if Result is TRadFormBase then
    TRadFormBase(Result)._AutoFree := True
  else
    { Kopru formun kendisine sahiplenir (inherited Create(AForm)), o yuzden
      donen referansi tutmuyoruz - form ile birlikte yok edilir. }
    TFormEventBridge.CreateBridge(Result, True);

  { STIL BLOGU KALDIRILDI. _New(AFormStyle, AOwner) cagrisi ayni islemi
    zaten yapiyor (bkz. TFormHelper._New) - buradaki kopya birebir aynisiydi
    ve kosulu (`Result.FormStyle <> AFormStyle`) _New donduktan sonra her
    zaman False oluyordu. Olu kod. }
end;

procedure TFormFactory.RegisterEvent(AEvent: TGlobalFormEvent);
begin
 FOnEvent:=AEvent;
end;

function TFormFactory.Get<T>(const AUniqueName: string; const AFormStyle: TFormStyle; AOwner: TComponent): T;
var
  LKey: string;
  LExisting: TCustomForm;
begin
  // Container (Key) İsmi Belirleme
  if AUniqueName.Trim = '' then
    LKey := T.ClassName // Singleton Modu (Sınıf Adı Key olur)
  else
    LKey := AUniqueName; // Multi-Instance Modu (Verilen Ad Key olur)

  // 1. Listede Var mı?
  if FForms.TryGetValue(LKey, LExisting) then
  begin
    { DENETIMLI cast. Eski hâl `T(LExisting)` yaziyordu - denetimsiz. Ayni
      anahtari iki farkli form sinifiyla kullanmak (ki AUniqueName verildiginde
      cok kolay) bir formu baska bir sinif sanip donduruyordu; her alan
      erisimi yanlis ofsete gidiyordu. Sessiz tip bozulmasi yerine acik hata. }
    if not (LExisting is T) then
      raise Exception.CreateFmt(
        'TFormFactory.Get<%s>: "%s" anahtari zaten bir %s tutuyor.',
        [T.ClassName, LKey, LExisting.ClassName]);

    Result := T(LExisting);
    // Mevcut formu öne getir ve küçültülmüşse normal hale getir
    if Result.WindowState = wsMinimized then
      Result.WindowState := wsNormal;
    Result.BringToFront;
  end
  else
  begin
    // 2. Yoksa Yarat (New metodunu kullanıyoruz)
    Result := New<T>(AFormStyle, AOwner);

    // Dictionary'ye kaydet
    FForms.Add(LKey, Result);
  end;
end;




{ TWinControlHook }

constructor TWinControlHook.Create(AControl: TWinControl);
begin
 if not Assigned(AControl) then
    raise Exception.Create('TWinControlHook: AControl cannot be nil');
  inherited Create(AControl);
  FControl := AControl;
  FOldProc := FControl.WindowProc;
  FControl.WindowProc := DoWndProc;
  FControl.FreeNotification(Self);
end;

destructor TWinControlHook.Destroy;
begin
  if Assigned(FControl) then
  begin
    FControl.WindowProc := FOldProc;
    FControl.RemoveFreeNotification(Self);
  end;
  inherited;
end;

procedure TWinControlHook.DoWndProc(var Msg: TMessage);
begin
  { Destroy sirasinda WindowProc geri verilmeden bir mesaj gelirse, ya da
    hook hic takilamadiysa FOldProc nil olur. }
  if Assigned(FOldProc) then
    FOldProc(Msg);
end;

procedure TWinControlHook.Notification(AComponent: TComponent; Operation: TOperation);
begin
inherited;
  if (Operation = opRemove) and (AComponent = FControl) then
  begin
    // Control free ediliyor, artık ona dokunma
    FControl := nil;
  end;

end;

{ TObjectHelper }


function TObjectHelper._ValueGetPathText(const APath: RawUtf8): RawUtf8;
var
 P: PRttiCustomProp;
begin
  Result := '';
 if GetInstanceByPath(TObject(Self), APath, P, '.') then
  begin
   Result:=P^.GetValueText(TObject(Self));
   //P^.GetValueJson(TObject(Self),Result);
  end;

end;

function TObjectHelper._ValueSetPathText(const APath, AValue: RawUtf8): Boolean;
var
 P: PRttiCustomProp;
begin
  Result := False;
 if GetInstanceByPath( TObject(Self), APath, P, '.') then
   Result:= P^.SetValueText(TObject(Self),AValue);

end;

function TObjectHelper._AsIX<T>: T;
var
  LGuid: TGUID;
  LInfo: PTypeInfo;   // TypeInfo(T) dogrudan ifade olarak .Name cozumlemiyor (E2671)
begin
  { Result yonetilen bir tiptir ve giriste ZATEN nil'dir; eski hâldeki iki
    `PPointer(@Result)^ := nil` yazimi gereksizdi. Ustelik PPointer ile nil
    yazmak sayim yapmaz - Result canli bir referans tutuyor olsaydi sizinti
    olurdu. Supports zaten basarisizlikta Result'i nil birakir. }
  if Self = nil then
    Exit;

  LInfo := TypeInfo(T);
  LGuid := GetTypeData(LInfo).Guid;

  (* GUID'SIZ ARAYUZ KONTROLU. Bir arayuz kendi bildiriminde koseli parantez
     icinde tirnakli bir GUID tasimiyorsa GetTypeData sifir GUID doner;
     Supports o GUID'le sorgulayinca nesne arayuzu GERCEKTEN uygulasa bile
     False doner. Yani sessizce "desteklenmiyor" denirdi. Simdi acikca hata
     veriyor - cunku duzeltmesi cagiranin arayuzune GUID eklemektir,
     sessizce nil almak degil.

     NOT: bu yorum yildiz-parantez bicimindedir, suslu parantez degil.
     Sebebi kitin kendi kurali (delphi-conventions.md): suslu yorum ilk
     kapanis susu gordugu yerde biter, dolayisiyla GUID sozdizimini ornek
     olarak yazmak yorumu erken kapatir. Bu duzeltme turunda tam olarak o
     yasandi - E2052 "Unterminated string". *)
  if LGuid = TGUID.Empty then
    raise Exception.CreateFmt(
      '_AsIX<%s>: arayuz GUID tasimiyor. Bildirimine koseli parantez ' +
      'icinde tirnakli bir GUID ekleyin.',
      [string(LInfo^.Name)]);

  Supports(Self, LGuid, Result);
end;

function TObjectHelper._AsObj<T>: T;
begin
  { KARDESINDEN FARKI BILINCLI: _AsObj bir CAST'tir, _AsIX bir SORGUDUR.
    Uymayan tipte bu metot istisna atar (Delphi'nin `as` deyimi), _AsIX ise
    nil doner. Ikisini ayni davranisa cekmedik: "bu nesne su tiptir" demek
    ile "su tipi destekliyor mu" diye sormak farkli sorulardir. Sessizce nil
    donmek birinci soruda hatayi gizlerdi. }
  Result := Self as T;
end;



function TObjectHelper._SetEvent(const AEventName: string; const AMethod: TMethod): TObject;
begin
  { Property yoksa SESSIZCE hicbir sey yapar ve yine Self doner - akici
    zincirleme icin bilincli. Basarinin dogrulanmasi gerekiyorsa cagiran
    IsPublishedProp'u kendisi kontrol etmelidir. }
 Result:=Self;
 if IsPublishedProp(Self, AEventName) then
  SetMethodProp(Self, AEventName, AMethod);
 end;

function TObjectHelper._To<T>: T;
var
  LTypeInfo: PTypeInfo;
begin
  LTypeInfo := TypeInfo(T);   // 1. Adım: T'nin Tip Bilgisini Al

  if LTypeInfo = nil then
    raise Exception.Create('_To<T>: T icin tip bilgisi yok.');

  if LTypeInfo.Kind = tkInterface then     // 2. Adım: Eğer hedef bir Interface ise (Örn: _To<IMyInterface>)
  begin
    if not Supports(Self, GetTypeData(LTypeInfo).Guid, Result) then // Nesnenin bu interface'i destekleyip desteklemediğini kontrol et ve güvenli cast yap
      PPointer(@Result)^ := nil; // Desteklemiyorsa nil döndür
  end
  else
  begin
    { T SINIF ya da ISARETCI OLMAK ZORUNDA.

      Eski hâl bu dalda hicbir kontrol yapmadan nesne isaretcisini Result'in
      bellegine yaziyordu. T uzerinde kisit da yok - yani `X._To<string>`
      DERLENIYORDU. Bir nesne isaretcisini string degiskenine yazmak, o
      degisken kapsamdan cikinca sayim azaltmasini NESNE BELLEGINDE
      calistirir: yigin bozulmasi. Ayni sey Integer, Double ve record icin de
      gecerli. Derleyici tek kelime etmiyordu.

      Delphi'de "sinif ya da arayuz" tek bir kisitla ifade edilemedigi icin
      kontrol calisma zamaninda: desteklenmeyen tip sessiz bozulma yerine
      acik bir hata alir. }
    if not (LTypeInfo.Kind in [tkClass, tkPointer]) then
      raise Exception.CreateFmt(
        '_To<%s>: yalnizca sinif, arayuz veya isaretci tipleri desteklenir. ' +
        'Deger tipleri bellegi bozardi.', [string(LTypeInfo.Name)]);

    PPointer(@Result)^ := Pointer(Self);
  end;
 //PPointer(@Result)^ := Pointer(Self);
 //Result := TValue.From<TObject>(Self).AsType<T>;
end;




function TObjectHelper._ValueGet(const AProp: RawUtf8): Variant;
begin
  var P:= ClassFieldProp(Self.ClassType,AProp);
  if p = nil then
   Result:=Null
  else
   Result:= P^._ValueGet(Self);
   //P.GetVariantProp(Self,Result,False);
  //Result:= GetPropValue(Self,AProp);
end;

function TObjectHelper._ValueGetPath(const APath: RawUtf8): Variant;
 var
 P: PRttiCustomProp;
begin
  Result := Null;
 if GetInstanceByPath(TObject(Self), APath, P, '.') then
  Result:=P^.Prop._ValueGet(Self);

end;

function TObjectHelper._ValueSet(const AProp: RawUtf8; const v:Variant): Boolean;
begin
    var P:= ClassFieldProp(Self.ClassType,AProp);
  if p = nil then
   Result:=False
  else
   Result:= P.SetValue(Self,v);
  //Result:= GetPropValue(Self,AProp);
end;

function TObjectHelper._ValueSetPath(const APath: RawUtf8; const AValue: Variant): Boolean;
var
 P: PRttiCustomProp;
begin
  Result := False;
 if GetInstanceByPath( TObject(Self), APath, P, '.') then
   Result:= P^.Prop.SetValue(Self,AValue);

end;

{ TMenuItemHelp }

function TMenuItemHelp._Caption: string;
begin
 Result:=StripHotkey(Self.Caption);
end;

function TMenuItemHelp._ClearSubMenu: TMenuItem;
var
 i:Integer;
begin
 Result :=Self;
 for i := Self.Count-1 downto 0 do
   Items[i].Free;
end;

class function TMenuItemHelp._Create(const ACaption: string; const AAction: TAction;  const AImgIndex: Integer): TMenuItem;
begin
  { `with` kaldirildi: kitin delphi-conventions.md kurali bunu acikca
    yasakliyor - baglami gizler, ayni adli alan/degisken oldugunda hangisine
    yazdigin belirsizlesir. }
  Result := TMenuItem.Create(nil);
  Result.Caption := ACaption;
  if AAction <> nil then Result.Action := AAction;
  if AImgIndex > -1 then Result.ImageIndex := AImgIndex;
  begin
    //ShortCut := AShortCut;
    //OnClick := AOnClick;
    //HelpContext := hCtx;
    //Checked := AChecked;
    //Enabled := AEnabled;
    //Name := AName;
  end;
end;



function TMenuItemHelp._SetClick(const aClick: TNotifyEvent): TMenuItem;
begin
 Result:=Self;
 Self.OnClick:=aClick;
end;

function TMenuItemHelp._SetHint(const aHint: string): TMenuItem;
begin
 Result:=Self;
 Self.Hint:=aHint;
end;

function TMenuItemHelp._SetTag(const aTag: Integer): TMenuItem;
begin
 Result:=Self;
 Self.Tag:=aTag;
end;

function TMenuItemHelp._TreeCaption(const ASplitter: string): string;
var
 itm:TMenuItem;
 LBaslik: string;
begin
  { BOS BASLIKLI atalar atlanir.

    TMainMenu.Items'in kendisi de bir TMenuItem'dir ve basligi BOSTUR.
    Eski hâl onu da zincire katiyor, sonuca bas tarafta bos bir segment ve
    fazladan bir ayrac ekliyordu:

      beklenen : Dosya\Yeni\Proje\Bos
      donen    : \Dosya\Yeni\Proje\Bos

    Ayni sey basligi verilmemis her ara oge icin de gecerliydi. }
  itm := Self;
  Result := itm._Caption;
  itm := itm.Parent;
  while itm <> nil do
  begin
    LBaslik := itm._Caption;
    if LBaslik <> '' then
      Result := LBaslik + ASplitter + Result;
    itm := itm.Parent;
  end;
end;

function TMenuItemHelp._Add(const ACaption: string; const AAction: TAction;
  const AImgIndex: Integer): TMenuItem;
begin
 Result:=TMenuItem._Create(ACaption,AAction,AImgIndex);
 Add(Result);
end;

function TMenuItemHelp._AddOrGet(const ACaption: string): TMenuItem;
begin
   Result:=Self.Find(ACaption);
   if Result <> nil then Exit;
    Result := TMenuItem.Create(nil);
    Result.Caption := ACaption;
    Add(Result);
end;



function TMenuItemHelp._AddOrGetPath(const ACaption: string): TMenuItem;
 var
 arg:TArray<string>;
 i:Integer;
begin
   arg:=ACaption.Split(['\','/','.']);
   Result:=Self;
   for i := Low(arg) to High(arg) do
      Result:=Result._AddOrGet(arg[i]);

end;



{ TActionListHelp }
  {$REGION 'TActionListHelp'}

  procedure TActionListHelp._DefaultKeySet(const arg:TArray<TShortCut>);
  var
    LSon: Integer;
  begin
    { Eski hâlin uc hatasi vardi:

      * `to High(arg)-1` SON ELEMANI ATLIYORDU. Dizideki son kisayol hicbir
        zaman uygulanmiyordu.
      * `arg` ActionCount'tan uzunsa Actions[i] siniri asiyordu.
      * except blogu `Exception.Create(...)` yaziyordu — bu bir istisna
        FIRLATMAZ, sadece bir nesne yaratip ortada birakir: hem gercek hata
        yutuluyor hem de bellek siziyor. Kitin kurali (delphi-conventions.md)
        genel yakalamayi ve yutmayi zaten yasakliyor.

      Simdi sinir acikca hesaplaniyor, istisna yakalama yok — bir hata varsa
      cagirana ulassin. }
    LSon := High(arg);
    if LSon > ActionCount - 1 then
      LSon := ActionCount - 1;
    for var i := 0 to LSon do
      Actions[i].ShortCut := arg[i];
  end;


function TActionListHelp._DefaultKeyGet: TArray<TShortCut>;
    var
     i:Integer;
    begin
         SetLength(Result,ActionCount);
         for i := 0 to ActionCount-1 do
           Result[i]:=Actions[i].ShortCut;
    end;

function TActionListHelp._FindName(const AName: string): TAction;
  var
   i:Integer;

  begin
    Result:=nil;

    for i := 0 to ActionCount -1 do
      begin
        if AnsiSameText(Actions[i].Name,AName) then
        begin
          Result:=TAction(Actions[i]);
          Exit;
        end;
      end;


  end;

  procedure TActionListHelp._For(AProc: TProc<TAction>);
  var
   i:Integer;
  begin
      if not Assigned(AProc) then exit;
    for i := 0 to ActionCount -1 do
      begin
        //if not Devam then exit;
        AProc(TAction(Actions[i]));
      end;


  end;


  function TActionListHelp._UniqName: string;
  begin
      { Owner nil olabilir (kod icinde yaratilmis, sahipsiz bir ActionList).
        Eski hâl bu durumda erisim ihlali veriyordu. }
      if Owner = nil then
        Result := Self.Name
      else
        Result := Owner.ClassName + '.' + Self.Name;
  end;




{$ENDREGION}

{ TActionHelp }

procedure TActionHelp._Clone(const act: TCustomAction);
begin
   AutoCheck:=act.AutoCheck;
   Caption:=act.Caption;
   Category:=act.Category;
   Enabled:=act.Enabled;
   GroupIndex:=act.GroupIndex;
   HelpContext:=act.HelpContext;
   HelpKeyword:=act.HelpKeyword;
   HelpType:=act.HelpType;
   Hint:=act.Hint;
   ImageIndex:=act.ImageIndex;
   ShortCut:=act.ShortCut;
   Tag:=act.Tag;
   Visible:=act.Visible;
  { Owner nil olabilir; eski hâl bu durumda erisim ihlali veriyordu.
    Sahipsizsek ad catismasi kontrolu de yapilamaz, adi degistirmiyoruz. }
  if (Owner <> nil) and (Owner.FindComponent(act.Name) = nil) then
    Name := act.Name;

end;

function TActionHelp._Execute: Boolean;
begin
  { Result once False: aksiyon pasif/gizliyse eski hâl atama YAPMIYORDU ve
    cagirana rastgele bir Boolean donuyordu (W1035). }
  Result := False;
  if Enabled and Visible then
    Result := Execute;
end;

class procedure TActionHelp._Visible(const arg: TArray<TAction>; const AVisible, AEnable: Boolean);
var
 act:TAction;
begin
  for Act in arg do
   begin
     act.Enabled:=AEnable;
     act.Visible:=AVisible
   end;

end;

{ TOpenDialogHelp }
 {$REGION 'TOpenDialogHelp'}

function TOpenDialogHelp._Exec(const AFilter: string; const AFilterIndex: Integer; const AFolder: string): Boolean;
begin
  FileName:='';

  if not AFilter.IsEmpty then
   begin
     Filter:=AFilter;
     FilterIndex:=AFilterIndex;
   end;
  if not AFolder.IsEmpty then InitialDir:=AFolder;

  Result:=Execute;

end;



function TOpenDialogHelp._Exec: string;
begin
 if Execute then Result:=FileName else Result:='';

end;

function TOpenDialogHelp._Exec(out AFile: string): Boolean;
begin
  Result:=Execute;
 if Result then AFile:=FileName;

end;

function TOpenDialogHelp._Filter(const AFilter: string): TOpenDialog;
begin
   Filter:=AFilter;
   Result:=Self;
end;

function TOpenDialogHelp._OpenDir(const AOpenDir: string): TOpenDialog;
begin
 InitialDir:=AOpenDir;
 Result:=Self;
end;

function TOpenDialogHelp._Options(const AOptions: TOpenOptions): TOpenDialog;
begin
 Options:=AOptions;
 Result:=Self;
end;

function TOpenDialogHelp._Title(const ATitle: string): TOpenDialog;
begin
 Title:=ATitle;
 Result:=Self;
end;



procedure TActionHelp._Visible(const AVisible: Boolean);
begin
  Self.Enabled:=AVisible;
  Self.Visible:=AVisible;
end;

{ TSaveDialogHelp }

  function TSaveDialogHelp._DefaultExt( const ADefaultExt: string): TSaveDialog;
begin
  DefaultExt:=ADefaultExt;
  Result:=self;

end;

function TSaveDialogHelp._FileName( const AFileName: string): TSaveDialog;
begin
  FileName:=AFileName;
  Result:=self;
end;

function TSaveDialogHelp._Filter( const AFilter: string): TSaveDialog;
begin
  Filter:=AFilter;
  Result:=self;
end;

function TSaveDialogHelp._FilterIndex(const AFilterIndex: Integer): TSaveDialog;
begin
  FilterIndex:=AFilterIndex;
  Result:=self;
end;

function TSaveDialogHelp._InitialDir(  const AInitialDir: string): TSaveDialog;
begin
  InitialDir:=AInitialDir;
  Result:=self;
end;

function TSaveDialogHelp._Options( const AOptions: TOpenOptions): TSaveDialog;
begin
  Options:=AOptions;
  Result:=self;
end;

function TSaveDialogHelp._OptionsEx(  const AOptionsEx: TOpenOptionsEx): TSaveDialog;
begin
  OptionsEx:=AOptionsEx;
  Result:=self;
end;


function TSaveDialogHelp._Title(const ATitle: string): TSaveDialog;
  begin
  Title:=ATitle;
  Result:=self;
  end;



{ TMainMenuHelp }

  procedure TMainMenuHelp._ForEach(const AProc: TProc<TMenuItem>);
  var
   itm:TMenuItem;
  begin
     { TActionListHelp._For ayni kontrolu yapiyordu, burada eksikti: nil
       gecilirse erisim ihlali olurdu. }
     if not Assigned(AProc) then Exit;
     for itm in Items do AProc(itm);
  end;

 function TMainMenuHelp._Add(const ACaption: string; const ATag, AImage: Integer): TMenuItem;
begin
    Result:=TMenuItem.Create(Self);
    Result.Caption:=ACaption;
    Result.Tag:=ATag;
    Result.ImageIndex:=AImage;
    Items.Add(Result);
end;

function TMainMenuHelp._FindCaption(const ACaption: string): TMenuItem;
  begin


        { OutputDebugString kaldirildi: her cagrida hata ayiklama ciktisi
          uretiyordu - uretim kodunda kalmis bir kalinti. }
        for Result in Items do
         if AnsiSameCaption(Result.Caption, ACaption) then Exit;
      Result:=nil;
  end;

function TMainMenuHelp._FindTag(const ATag: Integer): TMenuItem;
  begin
     for Result in Items do
         if Result.Tag=ATag then Exit;
      Result:=nil;
  end;


 {$ENDREGION}





{ TPersistentHack }

function TPersistentHack._GetNamePath: string;
var
  S: string;
  prn:TPersistent;
begin
  prn := Self;
  Result := GetNamePath;

  { En ustteki sahibe kadar yuruyoruz (TApplication haric). }
  while (TPersistentHack(prn).GetOwner <> nil) and
        (TPersistentHack(prn).GetOwner.ClassType <> TApplication) do
    prn := TPersistentHack(prn).GetOwner;

  { prn HALA Self ise sahip yok demektir - onek eklenmez.
    Eski hâl bu durumda S := prn.GetNamePath diyordu, yani Result ile AYNI
    degeri aliyor ve sonucu ikiye katliyordu: "Edit1" -> "Edit1.Edit1". }
  if prn = Self then
    Exit;

  if prn is TCustomForm then
    S := prn.ClassName
  else
    S := prn.GetNamePath;

  if S <> '' then
    Result := S + '.' + Result;
end;


{ TRttiPropHelper }

function TRttiPropHelper._ValueGet(Instance: TObject): Variant;
var
  k: TRttiKind;
  v: TSynVarData;
begin
  { Null, '' DEGIL. TObjectHelper._ValueGet "deger yok" icin Null kullaniyor;
    ayni birimde iki farkli "yok" gosterimi olmasi cagirani yaniltir. Ele
    alinmayan tip turleri (rkClass, rkSet, rkArray...) de artik Null doner. }
  Result := Null;
  if (@self = nil) or
     (Instance = nil) then
    exit;
  k := TypeInfo^.Kind;
  if k in rkOrdinalTypes then
    Result:=GetInt64Value(Instance)
  else if k in rkStringTypes then
    Result:= GetAsString(Instance)
  else if k = rkFloat then
    Result:=GetFloatProp(Instance)
  else if k = rkVariant then
  begin
    v.VType := 0;
    GetVariantProp(Instance, variant(v), {byref=}true);
    Result:=variant(v);
    if (v.VType and VTYPE_STATIC) <> 0 then
      VarClearProc(v.Data);
  end;

end;

{ TRadFormBase }

procedure TRadFormBase.NotifyEvent(const AEvent: TFormEventType);
begin
  DoEvent(AEvent);                                // turev icin uzanti noktasi
  if Assigned(GlobalFormFactory) then
    GlobalFormFactory.DoEvent(Self, AEvent);      // global dinleyici
end;

procedure TRadFormBase.ClientWndProc(var Message: TMessage);
const
  { MDICLIENT'in kendini kurarken ve yerlesimini yeniden hesaplarken
    gonderdigi IC yapilandirma mesaji. Windows SDK'da BELGELENMEMISTIR ve
    Winapi.Messages de onu tanimlamaz - o yuzden kendi adimizla tutuluyor.
    Cikplak $3F yazmak, ileride bu satiri okuyanin neye baktigini
    bilememesi demekti. }
  WM_MDICLIENT_FRAMECALC = $3F;
var
  { NativeInt, DWORD DEGIL: Get/SetWindowLongPtr Win64'te LONG_PTR (64 bit)
    kullanir. DWORD'e almak sessiz bir daralmadir - GWL_EXSTYLE degeri 32
    bite sigdigi icin pratikte calisiyordu, ama tip yanlisti ve derleyici
    bunun icin uyari uretmiyor. }
  ExStyle: NativeInt;
begin
  if (FormStyle = fsMDIForm) and (Message.Msg = WM_MDICLIENT_FRAMECALC) then
  begin
    { ClientHandle 0 olabilir (pencere henuz yaratilmamis ya da yok
      edilmis). Korumasiz GetWindowLongPtr(0, ...) anlamsiz deger dondurur
      ve ardindaki SetWindowPos gecersiz tutamaca yazmaya calisir. }
    if ClientHandle <> 0 then
    begin
      ExStyle := GetWindowLongPtr(ClientHandle, GWL_EXSTYLE);

      { Yalnizca stil GERCEKTEN varsa dokun. Kosulsuz yazmak her yerlesim
        hesabinda bir SetWindowPos tetikliyordu; SWP_FRAMECHANGED cerceveyi
        yeniden cizdirdigi icin bu gorunur titremeye yol acar. }
      if (ExStyle and WS_EX_CLIENTEDGE) <> 0 then
      begin
        SetWindowLongPtr(ClientHandle, GWL_EXSTYLE, ExStyle and not WS_EX_CLIENTEDGE);

        { SWP_FRAMECHANGED sart: stil degisikligi ancak bu bayrakla pencereye
          uygulanir. Digerleri "konumu/boyutu/z-sirasini degistirme" demek. }
        SetWindowPos(ClientHandle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or
          SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER);
      end;
    end;

    { $3F BURADA TUKETILIR - inherited'a GITMEZ, ve bu bilincli bir karardir.

      "Her yolda inherited cagrilmali" diye degistirmeyi denedik; sonuc
      OLCULDU: 30 saniyede 796.240 ClientWndProc cagrisi, %100 CPU, kilitli
      surec. Sebep geri besleme dongusu - inherited MDICLIENT'in kendi
      yordamina gider, o da WS_EX_CLIENTEDGE'i GERI KOYAR; biz tekrar
      sileriz, SWP_FRAMECHANGED yeni bir $3F dogurur, bastan baslar.
      Stili "zaten temizse dokunma" korumasi bunu engellemez, cunku her
      turda inherited onu yeniden setler.

      Yani bu Exit bir ihmal degil, donguyu kiran seyin ta kendisi.
      Kaldirmadan once rad_coreform testini calistirin: 08 numarali iddia
      tam bu firtinayi yakalar. }
    Exit;
  end;

  inherited;

end;

procedure TRadFormBase.CMTextChanged(var Msg: TMessage);
begin
  inherited;
  { Koprunun kapsayip bu sinifin kapsamadigi TEK olay buydu. Caption
    degisimi ne DoCreate/DoShow gibi bir sanal kanca ne de bir olay
    uretir; yalnizca bu mesaj gelir. }
  NotifyEvent(fetCaptionChange);
end;

procedure TRadFormBase.Activate;
begin
  inherited;
  { FIsShow'a DOKUNULMAZ. Eski hâlde Activate True, Deactivate False
    yaziyordu - yani alan "gosteriliyor mu" degil "odakta mi" demekti ve
    _IsShowing adi yalan soyluyordu. Somut sonucu _ShowWait'te sonsuz
    dongu idi: baska bir pencere odak alinca FIsShow False oluyor, form
    HALA gorunur oldugu icin Show kisa devre yapiyor, DoShow calismiyor,
    AFTERSHOW postalanmiyor, donguden cikis kosulu hic olusmuyordu.
    Artik FIsShow yalnizca AFTERSHOW'da True, DoHide'da False olur. }
  NotifyEvent(fetActivate);
end;


procedure TRadFormBase.Deactivate;
begin
  inherited;
  NotifyEvent(fetDeactivate);
end;

procedure TRadFormBase.DoClose(var Action: TCloseAction);
begin
  if FAutoFree then
   Action:=TCloseAction.caFree;
  NotifyEvent(fetClose);
  inherited;

end;

procedure TRadFormBase.DoCreate;
begin
  inherited DoCreate;
  NotifyEvent(fetCreate);
end;

procedure TRadFormBase.DoDestroy;
begin
  inherited;
  NotifyEvent(fetFree);

  { SOZLUK KAYDINI DUSUR. TFormFactory.Get<T> her formu FForms'a ekler ama
    UnregisterForm'un tek cagirani TFormEventBridge.Destroy idi - ve bu
    sinifa kopru takilmaz (bkz. tip bildirimindeki gerekce). Sonuc: sozlukte
    serbest birakilmis nesnenin adresi kaliyordu ve ayni anahtarla ikinci
    Get<T> o olu isaretciyi donduruyordu (olculdu: rad_formfactory testi 11).
    Kopru takmak yerine dogru cozum bu: sinif kendi kaydini kendi dusurur. }
  if Assigned(GlobalFormFactory) then
    GlobalFormFactory.UnregisterForm(Self);
end;

procedure TRadFormBase.DoEvent(const AEvent: TFormEventType);
begin
  { Bilerek bos: turevlerin uzanti noktasi. Global dinleyiciye ulasan yol
    NotifyEvent'tir, bu metot degil - boylece `inherited` cagirmayan bir
    override fabrika baglantisini koparamaz. }
end;

procedure TRadFormBase.DoHide;
begin
  inherited;
  FIsShow :=False;
  NotifyEvent(fetHide);
end;

procedure TRadFormBase.DoShow;
begin
  inherited;
  PostMessage(Self.Handle, WM_CMD,99, WM_EVENT_AFTERSHOW);
end;

procedure TRadFormBase.WmCMD(var Msg: TMessage);
begin
 if  Msg.WParam =99 then
 begin
  //CmdSys(Msg.LParam);
     case Msg.LParam of  //Sistem Mesajları Eksi ile başlar
      // WM_EVENT_CREATE:DoFormEvent(oCreate);
       WM_EVENT_AFTERSHOW: begin FIsShow :=True; NotifyEvent(fetShow); end;
       //WM_EVENT_LOAD  *-1:;
       //0:Result:=(FIsShow and Self.Showing);
      //-1:begin Close; end; //F_Main.MDITab.RemoveTab(Self);
      //-2:Self.WindowState:=TWindowState.wsMinimized;
      //-3:Self.WindowState:=TWindowState.wsMaximized;

    end;
 end;

end;




function TRadFormBase._IsShowing: Boolean;
begin
  Result :=FIsShow;
end;

{ TFormHelper._ShowWait'i BILEREK golgeler. Delphi'de gercek metot helper'i
  yener, yani TRadFormBase ornekleri icin daima BU calisir. Dogrusu da bu:
  helper surumu VCL'in `Active` bayragini bekler (form gorunur ama odaksiz
  ise hic gerceklesmez), bu surum sinifin kendi AFTERSHOW sinyalini bekler.
  Iki surumun ayni cikis korumalarini tasimasi sart - asagidaki zaman asimi
  o yuzden helper'daki ile aynidir. }
function TRadFormBase._ShowWait: TForm;
const
  CZamanAsimiMs = 5000;
var
  LBitis: UInt64;
begin
  Result := Self;
  if FIsShow then Exit;

  { `FIsShow := False` KALDIRILDI. Zaten False oldugu tek durumda gereksiz,
    True oldugu durumda ise yukaridaki Exit'ten sonra hic ulasilmiyor -
    ama daha kotusu, durumu sifirlayip Show'un kisa devre yapmasi hâlinde
    geri yazacak kimse kalmiyordu. }
  Show;

  LBitis := GetTickCount64 + CZamanAsimiMs;
  while (not FIsShow) and (not Application.Terminated) and
        (GetTickCount64 < LBitis) do
  begin
    Application.ProcessMessages;
    Sleep(1);   { bosa donup cekirdegi %100 mesgul etmemek icin }
  end;
end;

initialization
  { GlobalFormFactory BILEREK YARATILMIYOR. Yasam dongusunu uygulama
    belirler; burada yaratmak, kimsenin istemedigi bir fabrikayi her
    projeye zorlamak olurdu. Kullanacak uygulama kendisi kurar:

      GlobalFormFactory := TFormFactory.Create;

    Kurulmadigi surece TFormEventBridge.DoWndProc onu nil kontrolüyle
    atlar - bkz. o metodun basi. Finalization yine de temizler ki
    uygulama kurduysa sizinti kalmasin. }

finalization
 if Assigned(GlobalFormFactory) then FreeAndNil(GlobalFormFactory);

end.

