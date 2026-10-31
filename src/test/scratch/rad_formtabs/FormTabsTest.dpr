program FormTabsTest;

{$APPTYPE CONSOLE}

{
  TRadFormTabs sondasi (rad.formtabs.tms).

  Olculen sozlesme: MDI olmayan formlarin sekme olmasi, sekme/form senkronu
  (secim, baslik, gizleme, yok olma), sekme kapatma dugmesinin formu kapatmasi
  (OnCloseQuery'e saygi), HideInactive, AutoAttach ilkesi ve zincirleme,
  yonetici/sekme cubugu/form omur sirasi, MDI cocuk aktivasyonu.
}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  AdvOfficeTabSet,
  rad.core         in '..\..\..\core\rad.core.pas',
  Help.vcl         in '..\..\..\core\Help.vcl.pas',
  rad.tms.formtabs in '..\..\..\component\rad.tms.formtabs.pas',
  FormTabsDfmNormal in 'FormTabsDfmNormal.pas' {DfmNormal},
  FormTabsDfmMdi    in 'FormTabsDfmMdi.pas' {DfmMdi};

type
  TTestForm = class(TForm)
  strict private
    FGone: PBoolean;
  public
    CanCloseNow: Boolean;
    CloseAs: TCloseAction;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function CloseQuery: Boolean; override;
    procedure DoClose(var Action: TCloseAction); override;
    procedure WatchGone(AFlag: PBoolean);
  end;

  { Korunmus CanCloseTab'i sekme dugmesi tiklamasi gibi cagirir. }
  TTabsHack = class(TRadFormTabs)
  public
    function ClickClose(AIndex: Integer): Boolean;
  end;

  TRadTestForm = class(TRadFormBase)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { Korunmus DoEvent'i etkinlesme olmadan tetikler. }
  TFactoryHack = class(TFormFactory)
  public
    procedure Fire(AForm: TForm; AEvent: TFormEventType);
  end;

  TProbe = class
  public
    Calls: Integer;
    procedure Prev(Sender: TObject);
    procedure Accept(Sender: TObject; AForm: TForm; var AAccept: Boolean);
  end;

var
  GOk, GFail: Integer;
  { Screen.OnActiveFormChange zincirine girdigi icin PROGRAM BOYUNCA yasar:
    hub onu onceki dinleyici olarak saklar, olu nesneye cagri giderdi. }
  GProbe: TProbe;

constructor TTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  CanCloseNow := True;
  CloseAs := caHide;
end;

destructor TTestForm.Destroy;
begin
  if FGone <> nil then
    FGone^ := True;
  inherited;
end;

function TTestForm.CloseQuery: Boolean;
begin
  Result := CanCloseNow and inherited CloseQuery;
end;

procedure TTestForm.DoClose(var Action: TCloseAction);
begin
  inherited DoClose(Action);
  Action := CloseAs;
end;

procedure TTestForm.WatchGone(AFlag: PBoolean);
begin
  FGone := AFlag;
end;

procedure TFactoryHack.Fire(AForm: TForm; AEvent: TFormEventType);
begin
  DoEvent(AForm, AEvent);
end;

function TTabsHack.ClickClose(AIndex: Integer): Boolean;
var
  LAction: TCloseAction;
begin
  LAction := caFree;
  Result := CanCloseTab(AIndex, LAction);
end;

constructor TRadTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
end;

procedure TProbe.Prev(Sender: TObject);
begin
  Inc(Calls);
end;

procedure TProbe.Accept(Sender: TObject; AForm: TForm; var AAccept: Boolean);
begin
  if AForm.Tag = 7 then AAccept := False;     // varsayilan kabul edecekti -> reddet
  if AForm.Tag = 8 then AAccept := True;      // varsayilan reddedecekti -> kabul et
end;

procedure Chk(ADogru: Boolean; const AMesaj: string);
begin
  if ADogru then
  begin
    Inc(GOk);
    Writeln('  [GECTI] ', AMesaj);
  end
  else
  begin
    Inc(GFail);
    Writeln('  [KALDI] ', AMesaj);
  end;
  Flush(Output);
end;

procedure Bekle(AMs: Cardinal);
var
  LSon: UInt64;
begin
  LSon := GetTickCount64 + AMs;
  while GetTickCount64 < LSon do
  begin
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  end;
end;

function YeniForm(const ACaption: string): TTestForm;
begin
  Result := TTestForm.Create(nil);
  Result.Caption := ACaption;
  Result.SetBounds(100, 100, 300, 200);
  Result.Show;
end;

function YeniHost(out ATabs: TAdvOfficeTabSet; out AMgr: TRadFormTabs): TForm;
begin
  Result := TForm.CreateNew(nil);
  Result.SetBounds(50, 50, 800, 400);
  AMgr := TTabsHack.Create(Result);
  AMgr.Parent := Result;
  AMgr.Align := alTop;
  ATabs := AMgr;
  Result.Show;
  Bekle(100);
end;

{ ------------------------------------------------------------------ }

procedure Temel;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1, F2: TTestForm;
  LItem: TOfficeTabCollectionItem;
begin
  Writeln;
  Writeln('=== Attach / eslesme ===');
  LHost := YeniHost(LTabs, LMgr);
  F1 := YeniForm('Birinci');
  F2 := YeniForm('Ikinci');
  try
    LItem := LMgr.Attach(F1);
    Chk((LItem <> nil) and (LTabs.AdvOfficeTabs.Count = 1), '01 MDI olmayan form sekme oldu');
    Chk(LItem.Caption = 'Birinci', '02 sekme basligi form basligi');
    Chk((LMgr.TabOf(F1) = LItem) and (LMgr.FormOf(0) = F1), '03 TabOf / FormOf eslesiyor');
    Chk(LMgr.Attach(F1) = LItem, '04 ikinci Attach ayni sekmeyi dondurur');
    Chk(LTabs.AdvOfficeTabs.Count = 1, '05 sekme cogalmadi');
    Chk(LMgr.Attach(LHost) = nil, '06 sekme cubugunun kendi formu sekme olmaz');
    Chk(LMgr.Attach(nil) = nil, '07 nil sessizce reddedilir');

    LMgr.Attach(F2);
    Chk(LTabs.AdvOfficeTabs.Count = 2, '08 ikinci form da sekme');

    F1.Caption := 'Yeni Baslik';
    Chk(LMgr.TabOf(F1).Caption = 'Yeni Baslik', '09 form basligi degisince sekme guncellendi');
  finally
    F2.Free;
    F1.Free;
    LHost.Free;
  end;
end;

procedure Secim;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1, F2: TTestForm;
begin
  Writeln;
  Writeln('=== Sekme secimi formu one getirir ===');
  LHost := YeniHost(LTabs, LMgr);
  F1 := YeniForm('A');
  F2 := YeniForm('B');
  try
    LMgr.Attach(F1);
    LMgr.Attach(F2);
    LTabs.ActiveTabIndex := 1;
    F1.WindowState := wsMinimized;
    LTabs.ActiveTabIndex := 0;
    Chk(F1.WindowState = wsNormal, '10 simge durumundaki form sekme secilince geri yuklendi');
    Chk(LTabs.ActiveTabIndex = 0, '11 secim korundu (geri besleme dongusu yok)');

    F1.Hide;     // kullanici/kod gizledi (HideInactive kapali)
    Chk(LMgr.TabOf(F1) = nil, '12 gizlenen formun sekmesi kalkti');
    Chk(LTabs.AdvOfficeTabs.Count = 1, '13 digeri yerinde');
    F1.Show;
    LMgr.Attach(F1);
    Chk(LTabs.AdvOfficeTabs.Count = 2, '14 yeniden gosterilip Attach edilince geri geldi');
  finally
    F2.Free;
    F1.Free;
    LHost.Free;
  end;
end;

procedure YokOlma;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1, F2: TTestForm;
begin
  Writeln;
  Writeln('=== Form yok olunca sekme gider ===');
  LHost := YeniHost(LTabs, LMgr);
  F1 := YeniForm('A');
  F2 := YeniForm('B');
  try
    LMgr.Attach(F1);
    LMgr.Attach(F2);
    F2.Free;
    F2 := nil;
    Chk(LTabs.AdvOfficeTabs.Count = 1, '15 form Free edilince sekme silindi');
    Chk(LMgr.FormOf(0) = F1, '16 kalan sekme dogru formda');
    F1.Free;
    F1 := nil;
    Chk(LTabs.AdvOfficeTabs.Count = 0, '17 son form da gidince sekme kalmadi');
  finally
    F2.Free;
    F1.Free;
    LHost.Free;
  end;
end;

procedure Kapatma;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1, F2, F3: TTestForm;
  LGone1, LGone3: Boolean;
  LAllow: Boolean;
begin
  Writeln;
  Writeln('=== Sekme kapatma dugmesi formu kapatir ===');
  LHost := YeniHost(LTabs, LMgr);
  F1 := YeniForm('A');
  F2 := YeniForm('B');
  F3 := YeniForm('C');
  LGone1 := False;
  LGone3 := False;
  F1.WatchGone(@LGone1);
  F3.WatchGone(@LGone3);
  try
    LMgr.Attach(F1);
    LMgr.Attach(F2);
    LMgr.Attach(F3);

    { caFree: form yok olur, sekme gider }
    F1.CloseAs := caFree;
    LAllow := TTabsHack(LMgr).ClickClose(0);
    Chk(not LAllow, '18 TMS sekmeyi kendisi silmesin (Allow=False)');
    Chk(LTabs.AdvOfficeTabs.Count = 3, '19 kapatma ERTELENDI: sekme tiklama bitmeden silinmedi');
    Bekle(100);
    Chk(LGone1, '20 caFree formu yok edildi');
    Chk(LTabs.AdvOfficeTabs.Count = 2, '21 sekmesi kalkti');

    { OnCloseQuery veto: form acik kalir, sekme kalir }
    F2.CanCloseNow := False;
    LAllow := TTabsHack(LMgr).ClickClose(LMgr.TabOf(F2).Index);
    Bekle(100);
    Chk(F2.Visible and (LMgr.TabOf(F2) <> nil), '22 CloseQuery reddedince form ve sekme yerinde');

    { caHide: form gizlenir, sekme gider }
    F3.CloseAs := caHide;
    LAllow := TTabsHack(LMgr).ClickClose(LMgr.TabOf(F3).Index);
    Bekle(100);
    Chk((not LGone3) and (not F3.Visible), '23 caHide formu gizledi');
    Chk(LMgr.TabOf(F3) = nil, '24 gizlenen formun sekmesi gitti');
  finally
    F3.Free;
    F2.Free;
    if not LGone1 then F1.Free;
    LHost.Free;
  end;
end;

procedure TekPencere;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1, F2, F3: TTestForm;
begin
  Writeln;
  Writeln('=== HideInactive (tek pencere hissi) ===');
  LHost := YeniHost(LTabs, LMgr);
  F1 := YeniForm('A');
  F2 := YeniForm('B');
  F3 := YeniForm('C');
  try
    LMgr.HideInactive := True;
    LMgr.Attach(F1);
    LMgr.Attach(F2);
    LMgr.Attach(F3);
    LMgr.ActivateForm(F2);
    Chk(F2.Visible and not F1.Visible and not F3.Visible, '25 yalniz etkin formun penceresi gorunur');
    Chk(LTabs.AdvOfficeTabs.Count = 3, '26 gizlenenlerin sekmeleri KALDI');
    LTabs.ActiveTabIndex := 0;
    Chk(F1.Visible and not F2.Visible, '27 gizli forma ait sekme secilince gosterildi');
    Chk(LTabs.AdvOfficeTabs.Count = 3, '28 sekme sayisi degismedi');
    LMgr.HideInactive := False;
    LMgr.ActivateForm(F2);
    Chk(F1.Visible and F2.Visible, '29 ayar kapaliyken diger formlar GIZLENMEZ (F1 gorunur kaldi)');
    Chk(F2.Visible, '30 ama etkin form gosterildi');
  finally
    F3.Free;
    F2.Free;
    F1.Free;
    LHost.Free;
  end;
end;

procedure Ilke;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1, F2, F3, F4: TTestForm;
begin
  Writeln;
  Writeln('=== AutoAttach ilkesi ve zincirleme ===');
  GProbe.Calls := 0;
  LHost := YeniHost(LTabs, LMgr);
  F1 := YeniForm('Normal');
  F2 := YeniForm('Dialog');
  F2.BorderStyle := bsDialog;
  F3 := YeniForm('Reddedilecek');
  F3.Tag := 7;
  F4 := YeniForm('Zorla kabul');
  F4.BorderStyle := bsDialog;
  F4.Tag := 8;
  try
    LMgr.AutoAttachForm(F1);
    Chk(LTabs.AdvOfficeTabs.Count = 0, '31 AutoAttach kapaliyken baglanmaz');

    Screen.OnActiveFormChange := GProbe.Prev;     // hub'dan ONCE: zincirlenmeli
    LMgr.AutoAttach := True;
    LMgr.AutoAttachForm(F1);
    Chk(LMgr.TabOf(F1) <> nil, '32 uygun form baglandi');
    LMgr.AutoAttachForm(F2);
    Chk(LMgr.TabOf(F2) = nil, '33 dialog stili form baglanmaz');
    LMgr.AutoAttachForm(LHost);
    Chk(LMgr.TabOf(LHost) = nil, '34 sekme cubugunun formu baglanmaz');

    LMgr.OnAcceptForm := GProbe.Accept;
    LMgr.AutoAttachForm(F3);
    LMgr.AutoAttachForm(F4);
    Chk(LMgr.TabOf(F3) = nil, '35 OnAcceptForm varsayilani reddedebilir');
    Chk(LMgr.TabOf(F4) <> nil, '36 OnAcceptForm varsayilani kabule cevirebilir');

    Screen.OnActiveFormChange(Screen);
    Chk(GProbe.Calls = 1, '37 onceki Screen.OnActiveFormChange zincirleniyor');
    LMgr.AutoAttach := False;
    Chk(LMgr.TabOf(F1) <> nil, '38 AutoAttach kapatmak mevcut sekmeleri silmez');
  finally
    F4.Free;
    F3.Free;
    F2.Free;
    F1.Free;
    LHost.Free;
  end;
end;

procedure OmurSirasi;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1: TTestForm;
begin
  Writeln;
  Writeln('=== Sekme cubugu formlardan once yok olur ===');
  LHost := YeniHost(LTabs, LMgr);
  F1 := YeniForm('A');
  try
    LMgr.Attach(F1);
    LHost.Free;
    Chk(True, '39 formlar varken sekme cubugu yok edilebildi');
    F1.Caption := 'Sonra';     // WindowProc geri verildiyse sorunsuz
    Chk(F1.Caption = 'Sonra', '40 cubuk gittikten sonra form saglam');
    F1.Free;
    F1 := nil;
    Chk(True, '41 sonra form da yok edilebildi');
  finally
    F1.Free;
  end;
end;

procedure RadFormBaseEntegrasyon;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  F1, F2, F3: TRadTestForm;
begin
  Writeln;
  Writeln('=== TRadFormBase entegrasyonu (ShowInTabs, fetShow) ===');
  GlobalFormFactory := TFormFactory.Create;
  LHost := YeniHost(LTabs, LMgr);
  F1 := TRadTestForm.Create(nil);
  F2 := TRadTestForm.Create(nil);
  F3 := TRadTestForm.Create(nil);
  try
    LMgr.AutoAttach := True;
    Chk(F1.ShowInTabs, '42 ShowInTabs varsayilan True');
    F1.Caption := 'R1';
    F1.Show;
    F2.Caption := 'R2';
    F2.ShowInTabs := False;
    F2.Show;
    Bekle(200);     // fetShow, WM_CMD ile gecikmeli gelir
    Chk(LMgr.TabOf(F1) <> nil, '43 TRadFormBase fetShow ile sekme oldu');
    Chk(LMgr.TabOf(F2) = nil, '44 ShowInTabs=False sekme olmaz');
    Chk(LMgr.TabOf(F1).Caption = 'R1', '45 sekme basligi form basligi');

    LMgr.Detach(F1);
    Chk(LMgr.TabOf(F1) = nil, '46 Detach sekmeyi kaldirdi');
    TFactoryHack(GlobalFormFactory).Fire(F1, fetShow);
    Chk(LMgr.TabOf(F1) <> nil, '47 fabrika fetShow olayi etkinlesme olmadan sekme acar');

    LMgr.AutoAttach := False;
    F3.Caption := 'R3';
    F3.Show;
    Bekle(200);
    TFactoryHack(GlobalFormFactory).Fire(F3, fetShow);
    Chk(LMgr.TabOf(F3) = nil, '48 AutoAttach kapaninca fabrika dinleyicisi ayrildi');
  finally
    F3.Free;
    F2.Free;
    F1.Free;
    LHost.Free;
    FreeAndNil(GlobalFormFactory);
  end;
end;

procedure DfmFormlar;
var
  LHost, LMdiHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  N: TDfmNormal;
  M: TDfmMdi;
begin
  Writeln;
  Writeln('=== DFM ile yuklenen TRadFormBase (CreateNew cagrilmaz) ===');
  GlobalFormFactory := TFormFactory.Create;
  LHost := YeniHost(LTabs, LMgr);
  N := TDfmNormal.Create(nil);
  try
    LMgr.AutoAttach := True;
    Chk(N.ShowInTabs, '51 DFM formunda ShowInTabs varsayilan True');
    N.Show;
    Bekle(200);
    Chk(LMgr.TabOf(N) <> nil, '52 DFM normal form sekme oldu');
    LMgr.Detach(N);
    N.ShowInTabs := False;
    TFactoryHack(GlobalFormFactory).Fire(N, fetShow);
    Chk(LMgr.TabOf(N) = nil, '53 DFM formunda ShowInTabs=False sekme olmaz');
  finally
    N.Free;
    LHost.Free;
  end;

  Application.CreateForm(TTestForm, LMdiHost);
  LMdiHost.FormStyle := fsMDIForm;
  LMdiHost.SetBounds(50, 50, 800, 500);
  LMgr := TTabsHack.Create(LMdiHost);
  LMgr.Parent := LMdiHost;
  LMgr.Align := alTop;
  LMgr.AutoAttach := True;
  LMdiHost.Show;
  Bekle(100);
  try
    M := TDfmMdi.Create(LMdiHost);
    Chk(M.ShowInTabs, '54 DFM MDI cocukta ShowInTabs varsayilan True');
    M.Show;
    Bekle(200);
    Chk(LMgr.TabOf(M) <> nil, '55 DFM MDI cocuk sekme oldu');
  finally
    LMdiHost.Free;
    FreeAndNil(GlobalFormFactory);
  end;
end;

procedure MdiCocuk;
var
  LHost: TForm;
  LTabs: TAdvOfficeTabSet;
  LMgr : TRadFormTabs;
  C1, C2: TTestForm;
begin
  Writeln;
  Writeln('=== MDI cocuk aktivasyonu ===');
  Application.CreateForm(TTestForm, LHost);
  LHost.FormStyle := fsMDIForm;
  LHost.SetBounds(50, 50, 800, 500);
  LMgr := TTabsHack.Create(LHost);
  LMgr.Parent := LHost;
  LMgr.Align := alTop;
  LTabs := LMgr;
  LHost.Show;
  Bekle(100);
  try
    C1 := TTestForm.Create(LHost);
    C1.FormStyle := fsMDIChild;
    C1.Caption := 'C1';
    C1.Show;
    C2 := TTestForm.Create(LHost);
    C2.FormStyle := fsMDIChild;
    C2.Caption := 'C2';
    C2.Show;
    LMgr.Attach(C1);
    LMgr.Attach(C2);
    Bekle(100);
    LTabs.ActiveTabIndex := 1;
    Bekle(50);
    LTabs.ActiveTabIndex := 0;
    Bekle(100);
    Chk(LHost.ActiveMDIChild = C1, '49 sekme secilince MDI cocuk etkinlesti (C1)');
    LTabs.ActiveTabIndex := 1;
    Bekle(100);
    Chk(LHost.ActiveMDIChild = C2, '50 diger sekme -> diger MDI cocuk (C2)');
  finally
    LHost.Free;
  end;
end;

begin
  GOk := 0;
  GFail := 0;
  GProbe := TProbe.Create;
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(60000);
      Writeln('  [BEKCI] 60 sn doldu - takilma var.');
      Flush(Output);
      Halt(3);
    end).Start;

  Application.Initialize;
  try
    Temel;
    Secim;
    YokOlma;
    Kapatma;
    TekPencere;
    Ilke;
    OmurSirasi;
    RadFormBaseEntegrasyon;
    MdiCocuk;
    DfmFormlar;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;

  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  { GProbe BILEREK serbest birakilmaz: hub finalization'da dinleyiciyi geri verirken
    hala ona basvurur; surec zaten bitiyor. }
  if GFail > 0 then
    ExitCode := 1;
end.
