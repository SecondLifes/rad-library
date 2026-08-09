unit Help.vcl;

interface
uses
  Winapi.Windows, Winapi.Messages, System.ObjAuto ,System.SysUtils, System.Classes, UITypes,
  System.Generics.Collections, System.Actions, Vcl.Controls,
  Vcl.ActnList, System.Rtti, vcl.Forms, Vcl.Menus, Vcl.Dialogs,System.Threading
  //,JvBrowseFolder
  ,mormot.core.base
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

 IEventHandler1 = interface
   ['{CCBD8574-8432-4CC7-80CA-BE9A31C81983}']
   procedure DoEvent (const AControl: TWinControl; const AEvent: Integer);
   procedure RegisterEvent(AEvent:TGlobalFormEvent);
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
    function _ValueSetPath(const APath, AValue: Variant): Boolean;
    function _ValueGetPathText(const APath: RawUtf8): RawUtf8;
    function _ValueSetPathText(const APath, AValue: RawUtf8): Boolean;

  end;


  TWinControlHelper = class helper for TWinControl
  private
  public
    function _ScaleToCurrentMonitor(const AValue: Integer): Integer;
    function _PositionEx(const ARect: TRect; AHorz: THorzAlign; AVert: TVertAlign; AOffset: Integer = 0): TWinControl; overload;
    //function _PositionEx(const ARect: TRect; AHorz: THorzAlign; AVert: TVertAlign; AOffset: Integer = 0): TForm; overload;
    function _Position(const aRect: TRect; const aPosition: TWinPosition): TWinControl; overload;
    function _Position(const aPosition: TWinPosition; const aForm: TCustomForm = nil): TWinControl; overload;
  end;

  TFrameHelper = class helper for TCustomFrame
  public

  end;

  TFormHelper = class helper for TCustomForm
  private

  public
   class function _New(const AFormStyle: TFormStyle=fsNormal; AOwner: TComponent = nil):TForm; overload;

   class function _Modal(const AOnCreate:TProc<TCustomForm>=nil; const AOnBeforeFree:TProc<TCustomForm>=nil):TModalResult; overload;
   class procedure _ModalAsync(const ALoadData: TFunc<TObject>; const AOnDataReady: TProc<TObject, TCustomForm>);


   function DefClientProc: TFarProc;
   function _ArgClas<T:class>(AProc:TProc<T>=nil):TArray<T>;
   function _AnimateShow(AFadeDuration: Integer = 200):TCustomForm;

   function  _SetWindowsState(const AWindowState:TWindowState):TCustomForm;
   function  _SetStateNormal:TCustomForm;
   function  _SetStateMinimized:TCustomForm;
   function  _SetStateMaximized:TCustomForm;

   // TCoreForm formları için
   function  _SetAutoFree(const aAutoFree:Boolean):TCustomForm;

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
    function _Add(const ACaption:string;const AAction:TAction; const AImgIndex:Integer=-1):TMenuItem;
    class function _Create(const ACaption:string;const AAction:TAction; const AImgIndex:Integer=-1):TMenuItem;
    function _Caption:string;
    function _TreeCaption(const ASplitter:string='\'):string;
  end;

  TChildFormHelper1 = class helper for TApplication
    //procedure OpenChildForm(aForm: TForm);
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
  Core.Form,
  //Help.Str,
  mormot.core.rtti,
  cxGeometry,cxControls; //,JvJVCLUtils;

 type

  TRttiPropHelper = record helper for TRttiProp
  public
   function _ValueGet(Instance: TObject):Variant;
  end;

function ScreenWorkArea: TRect;
begin
  if Assigned(Screen.ActiveCustomForm) then
    Result := Screen.MonitorFromWindow(Screen.ActiveCustomForm.Handle).WorkareaRect
  else
  {$IFDEF MSWINDOWS}
  if not SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0) then
  {$ENDIF MSWINDOWS}
    Result := Bounds(0, 0, Screen.Width, Screen.Height);
end;

{ TFormHelper }


function TFormHelper.DefClientProc: TFarProc;
begin
 Result := Pointer(GetWindowLong(self.Handle, GWL_WNDPROC));//Self.FDefClientProc;
end;

function TFormHelper._AnimateShow(AFadeDuration: Integer):TCustomForm;
begin
// Önce alpha channel'ı hazırla
  Self.AlphaBlendValue := 0;
  Self.AlphaBlend := True;
  Self.Show;

  // Basit bir döngü veya TTimer/TThread ile opacity artırılır
  TThread.CreateAnonymousThread(procedure
  var
    i: Integer;
  begin
    for i := 0 to 25 do
    begin
      TThread.Synchronize(nil, procedure
      begin
        try
          if (Self <> nil) and not (csDestroying in Self.ComponentState) then
             Self.AlphaBlendValue := i * 10;
        except
          // Form o sırada yok edildiyse hatayı yut, uygulamayı patlatma
        end;
      end);
      Sleep(AFadeDuration div 25);
    end;
  end).Start;
end;

function TFormHelper._ArgClas<T>(AProc: TProc<T>): TArray<T>;
var
 i:Integer;
begin
   for i := 0 to ComponentCount -1 do
     begin
       if Components[i].ClassType = T then
       begin
         if Assigned(AProc) then AProc(Components[i] as T);

         SetLength(Result,length(Result)+1);
         Result[length(Result)-1]:=Components[i] as T;
       end;

     end;

end;

function TFormHelper._EnsureInWorkArea: TCustomForm;
var
  R: TRect;
  NewLeft, NewTop: Integer;
begin
  Result := Self;
  R := ScreenWorkArea;

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
  R := ScreenWorkArea;

  // 1. Mevcut genişlik ve yükseklik ekrana sığıyor mu?
  if (Width <= R.Width) and (Height <= R.Height) then
    Exit(Self._EnsureInWorkArea);  // Sığıyorsa ölçekleme yapma, sadece ekrana sok (önceki mantık)

  // 2. Eğer küçültmeye izin verilmediyse (parametre ile), normal davran
  if not AAllowShrink then  Exit(Self._EnsureInWorkArea);

  // --- ÖLÇEKLEME MANTIĞI ---

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
    Self.ScaleBy(Round(Ratio * 100), 100);

    // Not: ScaleBy bazen formun BoundsRect'ini anında güncellemeyebilir,
    // manuel olarak boyutları da set etmek garantidir.
    NewW := Round(Width * Ratio);
    NewH := Round(Height * Ratio);
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
Result := Self;
  if fsModal in Self.FormState then
    Self.ModalResult := mrCancel
  else
    Self.Hide;
end;

function TFormHelper._MakeMDIChild: TCustomForm;
begin
Result := Self;
  // Sadece Main form MDI container ise ve kendisi zaten child değilse
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsMDIForm) and
     (Self.FormStyle <> fsMDIChild) then
  begin
    Self.Hide; // Görsel titremeyi önlemek için önce gizle
    //Self.BorderStyle := bsNone; // MDI Child için genelde tercih edilir
    Self.FormStyle := fsMDIChild;
    // Window handle recreate edildikten sonra tekrar gösterilmesi gerekebilir
    // Ancak MDI child'lar genelde otomatik görünür.
  end;
end;


class function TFormHelper._Modal(const AOnCreate, AOnBeforeFree: TProc<TCustomForm>): TModalResult;
var
  LForm: TCustomForm;
begin
  // Form instance'ını oluştur
  LForm := TFormClass(Self).Create(nil); // Owner nil, çünkü manuel free edeceğiz
  try
    if Assigned(AOnCreate) then AOnCreate(LForm);
    Result := LForm.ShowModal;

    // Form kapandıktan sonra ama yok edilmeden önce son bir işlem (örn: veri okuma)
    if Assigned(AOnBeforeFree) then AOnBeforeFree(LForm);

  finally
    LForm.Free;
  end;
end;

class procedure TFormHelper._ModalAsync(const ALoadData: TFunc<TObject>; const AOnDataReady: TProc<TObject, TCustomForm>);
begin
var LForm := Self.Create(nil);

  // Form hemen açılır, kullanıcı bekletilmez
  LForm.Show;

  TTask.Run(procedure
  var
    LData: TObject;
  begin
    // Ağır iş burada (DB sorgusu vs.)
    LData := ALoadData();

    TThread.Queue(nil, procedure
    begin
      //LData nesnesini OnDataReady içinde Free etmeyi unutmayın
      if Assigned(AOnDataReady) then
        AOnDataReady(LData, LForm);

    end);
  end);
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
 if Self is TCoreForm then TCoreForm(Self).AutoFree:=aAutoFree;

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
begin

   while not Active do
   Application.ProcessMessages;
end;

{ TWinControlHelper }

function TWinControlHelper._Position(const aRect: TRect; const aPosition: TWinPosition): TWinControl;
begin
      case aPosition of
        wpTopLeft:    Result := _PositionEx(aRect, haInsideLeft,  vaInsideTop);
        wpTopRight:   Result := _PositionEx(aRect, haInsideRight, vaInsideTop);
        wpBottomLeft: Result := _PositionEx(aRect, haInsideLeft,  vaInsideBottom);
        wpBottomRight:Result := _PositionEx(aRect, haInsideRight, vaInsideBottom);
        wpCenter:     Result := _PositionEx(aRect, haCenter,      vaCenter);
        wpCustom:     Result := Self as TForm;
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
    Result:=_Position(ScreenWorkArea,aPosition)
  else
    Result:=_Position(AForm.BoundsRect,aPosition)
end;



function TWinControlHelper._PositionEx(const ARect: TRect; AHorz: THorzAlign; AVert: TVertAlign; AOffset: Integer): TWinControl;
var
  NewLeft, NewTop: Integer;
begin
  Result := Self;

  {
   MdiChil Formlar iin olabilir
   if Application.MainForm <> nil then  LockWindowUpdate(Application.MainForm.ClientHandle);
   LockWindowUpdate(0);

  }
    // Not: Eğer parent değişecekse Parent.Handle kullanılabilir.
    //SendMessage(Self.Handle, WM_SETREDRAW, WParam(False), 0);
    //Self.Perform(WM_SETREDRAW, 0, 0); // Çizimi durdur
    Self.LockDrawing;
    try
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

 if AForm is TCoreForm then
  AForm._SetAutoFree(aAutoFree)
 else
  begin
    inherited Create(AForm);
    AutoFree := aAutoFree;
    if AForm = nil then Exit;

    FOldClose := AForm.OnClose;
    AForm.OnClose := HookClose;

  end;


end;



procedure TFormEventBridge.HookClose(Sender: TObject; var Action: TCloseAction);
begin
  //if (FOwnerForm.FormStyle = fsMDIChild) or FAutoFree then
  if FAutoFree then  Action := caFree;
  //if FOwnerFactory <> nil then FOwnerFactory.DoFormEvent(FOwnerForm,fetClose);
  if Assigned(FOldClose) then FOldClose(Sender, Action);
end;


 procedure TFormEventBridge.DoWndProc(var Message: TMessage);
var
 s:string;
begin
   //if Assigned(FOldProc) then
  FOldProc(Message);
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
var
 frm:TCustomForm;
begin
  for frm in FForms.Values do
   TForm(frm).Free;
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
begin
  if FForms = nil then Exit;

  for LKey in FForms.Keys do
  begin
    if FForms[LKey] = AForm then
    begin
      FForms.Remove(LKey);
      Break;
    end;
  end;
end;

function TFormFactory.New<T>(const AFormStyle: TFormStyle; AOwner: TComponent): T;
var
  LBridge: TFormEventBridge;
  LNeedStyleChange: Boolean;
begin
  if AOwner = nil then AOwner := Application;

  // 1. Formu oluştur
  Result := TFormClass(T)._New() as T;  //T.Create(AOwner);
  //TForm(T).VisualManager:=Self as IFormVisualManager;
  
  // 2. Bridge Tak (AutoFree = True: Form kapandığında otomatik Free olur)
  LBridge := TFormEventBridge.CreateBridge(Result, True);

  // 3. Create Eventini Manuel Tetikle
  //DoFormEvent(Result,fetCreate);

  // 4. MDI ve Stil Ayarları
  LNeedStyleChange := (Result.FormStyle <> AFormStyle);
  if (AFormStyle = fsMDIChild) and LNeedStyleChange then
  begin
    if (Application.MainForm = nil) or (Application.MainForm.FormStyle <> fsMDIForm) then
      LNeedStyleChange := False; // Ana MDI Form yoksa zorlama
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
 obj:TObject;
begin
  Result := '';
  obj:=TObject(self);
 if GetInstanceByPath(TObject(Self), APath, P, '.') then
  begin
   Result:=P^.GetValueText(TObject(Self));
   //P^.GetValueJson(TObject(Self),Result);
  end;

end;

function TObjectHelper._ValueSetPathText(const APath, AValue: RawUtf8): Boolean;
var
 P: PRttiCustomProp;
 obj:TObject;
begin
  Result := False;
  obj:=TObject(self);
 if GetInstanceByPath( TObject(Self), APath, P, '.') then
   Result:= P^.SetValueText(TObject(Self),AValue);

end;

function TObjectHelper._AsIX<T>: T;
var
  LGuid: TGUID;
begin
  PPointer(@Result)^ := nil;
  if Self = nil then Exit;
  LGuid := GetTypeData(TypeInfo(T)).Guid; // 2. T'nin GUID bilgisini al

  // Bu fonksiyon hem QueryInterface kontrolü yapar hem de nesne IInterface'den türememişse (düz TObject ise) çökmesini engeller.
  if not Supports(Self, LGuid, Result) then
    PPointer(@Result)^ := nil;
end;

function TObjectHelper._AsObj<T>: T;
begin
  Result:= Self as T;
end;



function TObjectHelper._SetEvent(const AEventName: string; const AMethod: TMethod): TObject;
begin
 Result:=Self;
 if IsPublishedProp(Self, AEventName) then
  SetMethodProp(Self, AEventName, AMethod);
 end;

function TObjectHelper._To<T>: T;
var
  LTypeInfo: PTypeInfo;
begin
  LTypeInfo := TypeInfo(T);   // 1. Adım: T'nin Tip Bilgisini Al

  if (LTypeInfo <> nil) and (LTypeInfo.Kind = tkInterface) then     // 2. Adım: Eğer hedef bir Interface ise (Örn: _To<IMyInterface>)
  begin
    if not Supports(Self, GetTypeData(LTypeInfo).Guid, Result) then // Nesnenin bu interface'i destekleyip desteklemediğini kontrol et ve güvenli cast yap
      PPointer(@Result)^ := nil; // Desteklemiyorsa nil döndür
  end
  else
  begin
    // 3. Adım: Eğer hedef bir Sınıf veya Pointer ise (Hard Cast)
    // En hızlı yöntem: Bellek adresini direkt kopyala
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
 obj:TObject;
begin
  Result := Null;
  obj:=TObject(self);
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

function TObjectHelper._ValueSetPath(const APath, AValue: Variant): Boolean;
var
 P: PRttiCustomProp;
 obj:TObject;
begin
  Result := False;
  obj:=TObject(self);
 if GetInstanceByPath( TObject(Self), APath, P, '.') then
   Result:= P^.Prop.SetValue(Self,AValue);

end;

{ TMenuItemHelp }

function TMenuItemHelp._Caption: string;
begin
 Result:=StripHotkey(Self.Caption);
end;

class function TMenuItemHelp._Create(const ACaption: string; const AAction: TAction;
  const AImgIndex: Integer): TMenuItem;
begin
  Result := TMenuItem.Create(nil);
  with Result do
  begin

    Caption := ACaption;
    if AAction<>nil then Action:=AAction;
    if AImgIndex>-1 then ImageIndex:=AImgIndex;
    //ShortCut := AShortCut;
    //OnClick := AOnClick;
    //HelpContext := hCtx;
    //Checked := AChecked;
    //Enabled := AEnabled;
    //Name := AName;
  end;
end;



function TMenuItemHelp._TreeCaption(const ASplitter: string): string;
var
 itm:TMenuItem;
begin
 itm:=Self;
 Result:=itm._Caption;
 itm:=itm.Parent;
 while itm<>nil do
 begin
   Result:=itm._Caption+ASplitter+Result;
   itm:=itm.Parent;
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
  begin
   // if Length(arg) = ActionCount then
   try
        for var i := 0 to High(arg)-1 do
         Actions[i].ShortCut:=arg[i];

    except
        Exception.Create('TActionListHelp._DefaultSet');
   end;

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
      Result:=Owner.ClassName+'.'+Self.Name;
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
  if Owner.FindComponent(act.Name) =nil then Name:=act.Name;

end;

function TActionHelp._Execute: Boolean;
begin
 if Enabled and Visible then Result:=Execute;

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


        for Result in Items do
        begin
          OutputDebugString(pChar(Result.Caption+'--'+ACaption));
         if AnsiSameCaption(Result.Caption, ACaption) then Exit;
        end;
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
  prn:=self;
  Result := GetNamePath;

 while (TPersistentHack(prn).GetOwner <>nil) and (TPersistentHack(prn).GetOwner.ClassType<>TApplication) do
  begin
    prn:=TPersistentHack(prn).GetOwner;
    var asd :=prn.ClassName;
  end;
       if prn is TCustomForm then
      s:=prn.ClassName
      else
     S := prn.GetNamePath;
    if S <> '' then
      Result := S + '.' + Result;

  exit;
  while TPersistentHack(prn).GetOwner <>nil do
    begin
     if prn is TCustomForm then
      s:=prn.ClassName
      else
     S := prn.GetNamePath;
    if S <> '' then
      Result := S + '.' + Result;
     prn:=TPersistentHack(prn).GetOwner;
    end;

end;


{ TRttiPropHelper }

function TRttiPropHelper._ValueGet(Instance: TObject): Variant;
var
  k: TRttiKind;
  v: TSynVarData;
begin
  result := '';
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

initialization
//GlobalFormFactory:=TFormFactory.Create;

finalization
 if Assigned(GlobalFormFactory) then FreeAndNil(GlobalFormFactory);

end.

