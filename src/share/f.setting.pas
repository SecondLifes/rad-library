unit f.setting;

{ Ayar formunun tabanı. Pages (TcxPageControl) içindeki her sayfa bir ayar
  kategorisidir; NavBar bağlantıları sayfalardan üretilir.

  - Sıralama: TcxTabSheet.Tag. 1,2,3... artan sırada önce, Tag=0 olanlar en sonda
    (kendi aralarında sayfa sırasına göre).
  - Arama: sayfalardaki TdxLayoutControl'lerin öğelerinin başlık (CaptionOptions.Text)
    metinlerinde aranır; eşleşmeyen öğeler gizlenir, eşleşen öğesi olmayan sayfanın
    NavBar bağlantısı da gizlenir, eşleşen sayfanın bağlantısında eşleşen ayar sayısı
    görünür, eşleşen başlık parçası kalın yazılır ([B]..[/B], DevExpress biçimli metin).
    Sayfa başlığı eşleşirse sayfanın tamamı görünür. Yazarken 250 ms beklenir.
  - Klavye: Ctrl+F aramaya gider, Esc aramayı siler, Enter ilk ayara geçer.
  - Kapatma: dsAyar'ın veri kümesi düzenleme durumundaysa onay sorulur. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxContainer, cxEdit, dxCoreGraphics,
  dxLayoutcxEditAdapters, dxLayoutContainer, dxLayoutControlAdapters, cxClasses,
  Vcl.ExtCtrls, Vcl.WinXPanels, dxNavBar, cxTextEdit, cxMaskEdit, cxButtonEdit,
  dxLayoutControl, dxBarBuiltInMenu, cxPC,help.vcl, Data.DB, DBAccess,
  Uni, System.Generics.Collections, System.Generics.Defaults,
  dxNavBarCollns, dxNavBarBase, cxLabel, System.UITypes;

type
  TF_Setting = class(TRadFormBase)
    lytSetting: TdxLayoutControl;
    edtSearch: TcxButtonEdit;
    dxNavBar: TdxNavBar;
    lytSettingGroup_Root: TdxLayoutGroup;
    grpArama: TdxLayoutGroup;
    grpGrup: TdxLayoutGroup;
    grpData: TdxLayoutGroup;
    dxLayoutItem1: TdxLayoutItem;
    dxLayoutAutoCreatedGroup1: TdxLayoutAutoCreatedGroup;
    dxLayoutItem6: TdxLayoutItem;
    Pages: TcxPageControl;
    dxLayoutItem2: TdxLayoutItem;
    dsAyar: TUniDataSource;
  private
    FSayfalar: TList<TcxTabSheet>;
    FOrijinal: TDictionary<TdxCustomLayoutItem, Boolean>;
    FMetin: TDictionary<TdxCustomLayoutItem, string>;
    FZamanlayici: TTimer;
    FSonucYok: TcxLabel;
    procedure NavBarKur;
    procedure NavLinkClick(Sender: TObject);
    procedure SayfaSec(AIndex: Integer);
    procedure AramaDegisti(Sender: TObject);
    procedure AramaTemizle(Sender: TObject; AButtonIndex: Integer);
    procedure AramaTusu(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ZamanlayiciDoldu(Sender: TObject);
    procedure FormKisayol(var Msg: TWMKey; var Handled: Boolean);
    procedure AramaUygula;
    procedure IlkAyaraGit;
    function DegisiklikVarMi: Boolean;
    function OrijinalMetin(AOge: TdxCustomLayoutItem): string;
    procedure LayoutleriTopla(AAta: TWinControl; AListe: TList<TdxLayoutControl>);
    function LayoutFiltrele(ALayout: TdxLayoutControl; const AAranan: string;
      ATumu: Boolean; var AAyarSayisi: Integer): Integer;
    procedure LayoutGeriYukle(ALayout: TdxLayoutControl);
    function GrupGorunurlukUygula(AGrup: TdxCustomLayoutGroup): Boolean;
    function SayfaFiltrele(ASayfa: TcxTabSheet; const AAranan: string;
      out AAyarSayisi: Integer): Boolean;
    procedure SayfaGeriYukle(ASayfa: TcxTabSheet);
  protected
    procedure DoCreate; override;
  public
    destructor Destroy; override;
    function CloseQuery: Boolean; override;
  end;



implementation

{$R *.dfm}

resourcestring
  SNavGrupBasligi = 'Ayarlar';
  SSonucYok = 'Eşleşen ayar bulunamadı';
  SAramaIpucu = 'Ayar ara (Ctrl+F)';
  SKaydedilmemis = 'Kaydedilmemiş değişiklikler var. Yine de kapatılsın mı?';

const
  ARAMA_BEKLEME_MS = 250;

type
  { FindNextControl korumalı; sayfa içinde gezinmek için erişim sınıfı. }
  TWinControlErisim = class(TWinControl);

{ Aramada büyük/küçük harf ve Türkçe harf ayrımı yapılmaz: "Doviz" = "DÖVİZ".
  Harfler kodla yazıldı: kaynak dosya kodlamasından bağımsız çalışsın.
  Dönüşüm karakter-karakter olduğu için uzunluk değişmez; bulunan konum özgün
  metinde de aynı yerdir (vurgulama bunu kullanır). }
function Katla(const AMetin: string): string;
var
  I: Integer;
begin
  Result := AMetin;
  for I := 1 to Length(Result) do
    case Result[I] of
      #$0130, #$0131, 'I': Result[I] := 'i';
      #$00C7, #$00E7: Result[I] := 'c';
      #$011E, #$011F: Result[I] := 'g';
      #$00D6, #$00F6: Result[I] := 'o';
      #$015E, #$015F: Result[I] := 's';
      #$00DC, #$00FC: Result[I] := 'u';
    end;
  Result := LowerCase(Result);
end;

function OgeBasligiOku(AOge: TdxCustomLayoutItem): string;
begin
  if AOge is TdxLayoutItem then
    Result := TdxLayoutItem(AOge).CaptionOptions.Text
  else if AOge is TdxLayoutLabeledItem then
    Result := TdxLayoutLabeledItem(AOge).CaptionOptions.Text
  else
    Result := '';
end;

procedure OgeBasligiYaz(AOge: TdxCustomLayoutItem; const AMetin: string);
begin
  if AOge is TdxLayoutItem then
    TdxLayoutItem(AOge).CaptionOptions.Text := AMetin
  else if AOge is TdxLayoutLabeledItem then
    TdxLayoutLabeledItem(AOge).CaptionOptions.Text := AMetin;
end;

function AramaOgesiMi(AOge: TdxCustomLayoutItem): Boolean;
begin
  Result := (AOge is TdxLayoutItem) or (AOge is TdxLayoutLabeledItem);
end;

{ Eşleşen parçayı kalın yapar. Başlıkta zaten '[' varsa biçim karışmasın diye
  dokunulmaz. }
function Vurgula(const AMetin, AAranan: string): string;
var
  LKonum: Integer;
begin
  Result := AMetin;
  if (AAranan = '') or (Pos('[', AMetin) > 0) then
    Exit;
  LKonum := Pos(AAranan, Katla(AMetin));
  if LKonum > 0 then
    Result := Copy(AMetin, 1, LKonum - 1) + '[B]' + Copy(AMetin, LKonum, Length(AAranan))
      + '[/B]' + Copy(AMetin, LKonum + Length(AAranan), MaxInt);
end;

{ Tag > 0 artan sırada önce, Tag = 0 sona; eşitlikte sayfa sırası. }
function SayfaKarsilastir(const ASol, ASag: TcxTabSheet): Integer;
begin
  if (ASol.Tag = 0) <> (ASag.Tag = 0) then
  begin
    if ASol.Tag = 0 then
      Result := 1
    else
      Result := -1;
    Exit;
  end;
  Result := ASol.Tag - ASag.Tag;
  if Result = 0 then
    Result := ASol.PageIndex - ASag.PageIndex;
end;

procedure TF_Setting.DoCreate;
begin
  inherited;
  FSayfalar := TList<TcxTabSheet>.Create;
  FOrijinal := TDictionary<TdxCustomLayoutItem, Boolean>.Create;
  FMetin := TDictionary<TdxCustomLayoutItem, string>.Create;

  FZamanlayici := TTimer.Create(Self);
  FZamanlayici.Enabled := False;
  FZamanlayici.Interval := ARAMA_BEKLEME_MS;
  FZamanlayici.OnTimer := ZamanlayiciDoldu;

  // Gezinme NavBar'dan; sekme şeridi ikinci bir gezinme olmasın.
  Pages.Properties.HideTabs := True;

  FSonucYok := TcxLabel.Create(Self);
  FSonucYok.Parent := Pages;
  FSonucYok.Align := alClient;
  FSonucYok.AutoSize := False;
  FSonucYok.Transparent := True;
  FSonucYok.Properties.Alignment.Horz := taCenter;
  FSonucYok.Properties.Alignment.Vert := taVCenter;
  FSonucYok.Caption := SSonucYok;
  FSonucYok.Visible := False;

  edtSearch.TextHint := SAramaIpucu;
  edtSearch.Properties.OnChange := AramaDegisti;
  edtSearch.Properties.OnButtonClick := AramaTemizle;
  edtSearch.OnKeyDown := AramaTusu;
  OnShortCut := FormKisayol;
  NavBarKur;
end;

destructor TF_Setting.Destroy;
begin
  FMetin.Free;
  FOrijinal.Free;
  FSayfalar.Free;
  inherited;
end;

function TF_Setting.DegisiklikVarMi: Boolean;
begin
  Result := Assigned(dsAyar.DataSet) and dsAyar.DataSet.Active
    and (dsAyar.DataSet.State in dsEditModes);
end;

function TF_Setting.CloseQuery: Boolean;
begin
  Result := inherited CloseQuery;
  if Result and DegisiklikVarMi then
  begin
    Result := MessageDlg(SKaydedilmemis, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
    if Result then
      dsAyar.DataSet.Cancel;
  end;
end;

procedure TF_Setting.NavBarKur;
var
  I: Integer;
  LGrup: TdxNavBarGroup;
  LOge: TdxNavBarItem;
begin
  FSayfalar.Clear;
  for I := 0 to Pages.PageCount - 1 do
    if Pages.Pages[I].TabVisible then
      FSayfalar.Add(Pages.Pages[I]);
  FSayfalar.Sort(TComparer<TcxTabSheet>.Construct(SayfaKarsilastir));

  dxNavBar.BeginUpdate;
  try
    dxNavBar.Groups.Clear;
    dxNavBar.Items.Clear;
    LGrup := dxNavBar.Groups.Add;
    LGrup.Caption := SNavGrupBasligi;
    LGrup.Expanded := True;
    for I := 0 to FSayfalar.Count - 1 do
    begin
      LOge := dxNavBar.Items.Add;
      LOge.Caption := FSayfalar[I].Caption;
      LOge.Tag := I;
      LOge.OnClick := NavLinkClick;
      LGrup.CreateLink(LOge);
    end;
  finally
    dxNavBar.EndUpdate;
  end;
  if FSayfalar.Count > 0 then
    SayfaSec(0);
end;

procedure TF_Setting.NavLinkClick(Sender: TObject);
begin
  SayfaSec(TdxNavBarItem(Sender).Tag);
end;

procedure TF_Setting.SayfaSec(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FSayfalar.Count) then
    Exit;
  Pages.ActivePage := FSayfalar[AIndex];
end;

procedure TF_Setting.AramaDegisti(Sender: TObject);
begin
  // Her tuşta değil, yazma durunca ara.
  FZamanlayici.Enabled := False;
  FZamanlayici.Enabled := True;
end;

procedure TF_Setting.ZamanlayiciDoldu(Sender: TObject);
begin
  FZamanlayici.Enabled := False;
  AramaUygula;
end;

procedure TF_Setting.AramaTemizle(Sender: TObject; AButtonIndex: Integer);
begin
  edtSearch.Text := '';
  FZamanlayici.Enabled := False;
  AramaUygula;
end;

procedure TF_Setting.AramaTusu(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE:
      if edtSearch.Text <> '' then
      begin
        AramaTemizle(Sender, 0);
        Key := 0;
      end;
    VK_RETURN:
      begin
        FZamanlayici.Enabled := False;
        AramaUygula;
        IlkAyaraGit;
        Key := 0;
      end;
  end;
end;

procedure TF_Setting.FormKisayol(var Msg: TWMKey; var Handled: Boolean);
begin
  if (Msg.CharCode = Ord('F')) and (GetKeyState(VK_CONTROL) < 0) then
  begin
    edtSearch.SetFocus;
    edtSearch.SelectAll;
    Handled := True;
  end;
end;

procedure TF_Setting.IlkAyaraGit;
var
  LKontrol: TWinControl;
begin
  if Pages.ActivePage = nil then
    Exit;
  LKontrol := TWinControlErisim(Pages.ActivePage).FindNextControl(nil, True, True, False);
  if (LKontrol <> nil) and LKontrol.CanFocus then
    LKontrol.SetFocus;
end;

procedure TF_Setting.LayoutleriTopla(AAta: TWinControl; AListe: TList<TdxLayoutControl>);
var
  I: Integer;
begin
  for I := 0 to AAta.ControlCount - 1 do
    if AAta.Controls[I] is TdxLayoutControl then
      AListe.Add(TdxLayoutControl(AAta.Controls[I]))
    else if AAta.Controls[I] is TWinControl then
      LayoutleriTopla(TWinControl(AAta.Controls[I]), AListe);
end;

{ Başlık metni ilk görüldüğünde saklanır; arama ve geri yükleme hep özgün metne
  bakar (vurgu etiketleri aramayı bozmasın). }
function TF_Setting.OrijinalMetin(AOge: TdxCustomLayoutItem): string;
begin
  if not FMetin.TryGetValue(AOge, Result) then
  begin
    Result := OgeBasligiOku(AOge);
    FMetin.Add(AOge, Result);
  end;
end;

{ Altında görünen öğe kalmayan grupları gizler (boş çerçeve kalmasın). Kök grup
  bu fonksiyona çocukları üzerinden girer, kendisine dokunulmaz. }
function TF_Setting.GrupGorunurlukUygula(AGrup: TdxCustomLayoutGroup): Boolean;
var
  I: Integer;
  LCocuk: TdxCustomLayoutItem;
  LGorunur, LOrijinal: Boolean;
begin
  Result := False;
  for I := 0 to AGrup.Count - 1 do
  begin
    LCocuk := AGrup.Items[I];
    if LCocuk is TdxCustomLayoutGroup then
    begin
      LGorunur := GrupGorunurlukUygula(TdxCustomLayoutGroup(LCocuk));
      if not FOrijinal.TryGetValue(LCocuk, LOrijinal) then
        LOrijinal := True;
      LCocuk.Visible := LGorunur and LOrijinal;
    end
    else
      LGorunur := LCocuk.Visible;
    Result := Result or LGorunur;
  end;
end;

{ Dönen değer: görünür kalan arama öğesi (editör + açıklama) sayısı.
  AAyarSayisi: bunlardan editör (TdxLayoutItem) olanların sayısına eklenir. }
function TF_Setting.LayoutFiltrele(ALayout: TdxLayoutControl; const AAranan: string;
  ATumu: Boolean; var AAyarSayisi: Integer): Integer;
var
  I: Integer;
  LOge: TdxCustomLayoutItem;
  LEslesen: Boolean;
  LMetin: string;
begin
  Result := 0;
  ALayout.BeginUpdate;
  try
    // İlk filtrede tasarımdaki görünürlük ve başlık saklanır; arama silinince dönülür.
    for I := 0 to ALayout.Container.AbsoluteItemCount - 1 do
    begin
      LOge := ALayout.Container.AbsoluteItems[I];
      if not FOrijinal.ContainsKey(LOge) then
        FOrijinal.Add(LOge, LOge.Visible);
      if AramaOgesiMi(LOge) then
        OrijinalMetin(LOge);
    end;
    for I := 0 to ALayout.Container.AbsoluteItemCount - 1 do
    begin
      LOge := ALayout.Container.AbsoluteItems[I];
      if LOge is TdxCustomLayoutGroup then
        Continue;
      LEslesen := False;
      if AramaOgesiMi(LOge) then
      begin
        LMetin := OrijinalMetin(LOge);
        LEslesen := Pos(AAranan, Katla(LMetin)) > 0;
        // Başlık eşleştiyse parçayı kalın yaz, değilse özgün metne dön.
        OgeBasligiYaz(LOge, Vurgula(LMetin, AAranan));
      end;
      LOge.Visible := FOrijinal[LOge] and (ATumu or LEslesen) and AramaOgesiMi(LOge);
      if LOge.Visible then
      begin
        Inc(Result);
        if LOge is TdxLayoutItem then
          Inc(AAyarSayisi);
      end;
    end;
    GrupGorunurlukUygula(ALayout.Items);
  finally
    ALayout.EndUpdate;
  end;
end;

procedure TF_Setting.LayoutGeriYukle(ALayout: TdxLayoutControl);
var
  I: Integer;
  LOge: TdxCustomLayoutItem;
  LOrijinal: Boolean;
  LMetin: string;
begin
  ALayout.BeginUpdate;
  try
    for I := 0 to ALayout.Container.AbsoluteItemCount - 1 do
    begin
      LOge := ALayout.Container.AbsoluteItems[I];
      if FOrijinal.TryGetValue(LOge, LOrijinal) then
        LOge.Visible := LOrijinal;
      if FMetin.TryGetValue(LOge, LMetin) then
        OgeBasligiYaz(LOge, LMetin);
    end;
  finally
    ALayout.EndUpdate;
  end;
end;

function TF_Setting.SayfaFiltrele(ASayfa: TcxTabSheet; const AAranan: string;
  out AAyarSayisi: Integer): Boolean;
var
  LListe: TList<TdxLayoutControl>;
  LLayout: TdxLayoutControl;
  LTumu: Boolean;
  LSayi: Integer;
begin
  LSayi := 0;
  AAyarSayisi := 0;
  LTumu := Pos(AAranan, Katla(ASayfa.Caption)) > 0;
  LListe := TList<TdxLayoutControl>.Create;
  try
    LayoutleriTopla(ASayfa, LListe);
    for LLayout in LListe do
      Inc(LSayi, LayoutFiltrele(LLayout, AAranan, LTumu, AAyarSayisi));
  finally
    LListe.Free;
  end;
  Result := LTumu or (LSayi > 0);
end;

procedure TF_Setting.SayfaGeriYukle(ASayfa: TcxTabSheet);
var
  LListe: TList<TdxLayoutControl>;
  LLayout: TdxLayoutControl;
begin
  LListe := TList<TdxLayoutControl>.Create;
  try
    LayoutleriTopla(ASayfa, LListe);
    for LLayout in LListe do
      LayoutGeriYukle(LLayout);
  finally
    LListe.Free;
  end;
end;

procedure TF_Setting.AramaUygula;
var
  I, LIlk, LAktif, LAyarSayisi: Integer;
  LAranan: string;
  LEslesti: Boolean;
begin
  LAranan := Katla(Trim(edtSearch.Text));
  LIlk := -1;
  for I := 0 to FSayfalar.Count - 1 do
  begin
    LAyarSayisi := 0;
    if LAranan = '' then
    begin
      SayfaGeriYukle(FSayfalar[I]);
      LEslesti := True;
    end
    else
      LEslesti := SayfaFiltrele(FSayfalar[I], LAranan, LAyarSayisi);
    dxNavBar.Items[I].Visible := LEslesti;
    if LEslesti and (LAyarSayisi > 0) then
      dxNavBar.Items[I].Caption := Format('%s (%d)', [FSayfalar[I].Caption, LAyarSayisi])
    else
      dxNavBar.Items[I].Caption := FSayfalar[I].Caption;
    if LEslesti and (LIlk < 0) then
      LIlk := I;
  end;
  if LAranan = '' then
  begin
    FOrijinal.Clear;
    FMetin.Clear;
    FSonucYok.Visible := False;
    Exit;
  end;
  FSonucYok.Visible := LIlk < 0;
  if FSonucYok.Visible then
    FSonucYok.BringToFront;
  // Açık sayfada eşleşme yoksa ilk eşleşen sayfaya geç.
  LAktif := FSayfalar.IndexOf(Pages.ActivePage);
  if (LIlk >= 0) and ((LAktif < 0) or not dxNavBar.Items[LAktif].Visible) then
    SayfaSec(LIlk);
end;

end.
