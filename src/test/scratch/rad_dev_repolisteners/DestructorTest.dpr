program DestructorTest;

(*
  RADDEV-001 regresyonu: RepositoryItem, BAGLI TUKETICILERI VARKEN silinince?

  DOGRULANMIS ZINCIR (kaynaktan okundu, tahmin degil):
    TRadEditRepositoryItem.Destroy
      -> FConsumers.Free              { alan DANGLING kalir, nil olmaz }
      -> inherited Destroy
         -> TcxEditRepositoryItem.Destroy
            -> RemoveNotification      (cxEdit.pas:6745-6755)
               -> RemoveListener(...)  SANAL (cxEdit.pas:260)
                  -> TRadEditRepositoryItem.RemoveListener
                     -> FConsumers.Remove(...)  <-- SERBEST BIRAKILMIS LISTE

  ! COKME DETERMINISTIK DEGILDIR. Delphi'nin varsayilan bellek yoneticisi
    serbest blogu silmez, dolayisiyla hatali kod cogu zaman SESSIZCE
    "calisir". Bu yuzden bu sondanin kirmizisi cokmeye bakmaz; olctugu sey
    CAGRI SIRASIDIR:

      yikim sirasinda RemoveListener cagrisi > 0

    Bu sayi sifirdan buyukse, FConsumers'i ondan ONCE serbest birakmak
    tanim geregi use-after-free'dir - bellek yoneticisinin o an ne yaptigina
    bagli olmadan.

  Sayac, Destroy'un ICINDE inherited'dan SONRA global'e yaziliyor: nesnenin
  bellegi destructor donene kadar gecerlidir, dolayisiyla bu okuma yasaldir
  ve sayiyi yikimdan sonra gorebilmemizi saglar.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls,
  cxEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit, cxDBLookupComboBox,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  cxGrid, cxGridLevel, cxGridTableView, cxGridCustomTableView,
  Rad.Dev;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  { TSondaItem.Destroy sonunda doldurulur. }
  GYikimdaRemove: Integer = -1;
  GYikimSonuTuketici: Integer = -1;

procedure Kontrol(const AAd: string; ABasarili: Boolean; const ADetay: string = '');
begin
  if ABasarili then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd);
  end;
  if ADetay <> '' then
    Writeln('         ', ADetay);
end;

type
  { Yalnizca GOZLER - sinifin davranisini degistirmez. }
  TSondaItem = class(TRadLookupComboBoxRepository)
  private
    FYikimda: Boolean;
  public
    RemoveCagrisi: Integer;
    RemoveYikimSirasinda: Integer;
    destructor Destroy; override;
    procedure RemoveListener(AListener: IcxEditRepositoryItemListener); override;
  end;

destructor TSondaItem.Destroy;
begin
  FYikimda := True;
  inherited Destroy;
  { Nesne bellegi destructor donene kadar gecerli - bu okuma yasal. }
  GYikimdaRemove := RemoveYikimSirasinda;
  GYikimSonuTuketici := ConsumerCount;
end;

procedure TSondaItem.RemoveListener(AListener: IcxEditRepositoryItemListener);
begin
  Inc(RemoveCagrisi);
  if FYikimda then
    Inc(RemoveYikimSirasinda);
  inherited RemoveListener(AListener);
end;

var
  LForm: TForm;
  LItem: TSondaItem;
  LEd1, LEd2: TRadLookupComboBox;
  LGrid: TcxGrid;
  LLevel: TcxGridLevel;
  LView: TcxGridTableView;
  LCol: TcxGridColumn;
  LOnce: Integer;
  LHata: string;

function YeniEditor(const AAd: string): TRadLookupComboBox;
begin
  Result := TRadLookupComboBox.Create(LForm);
  Result.Name := AAd;
  Result.Parent := LForm;
end;

begin
  try
    LForm := TForm.CreateNew(nil);
    try
      LEd1 := YeniEditor('Ed1');
      LEd2 := YeniEditor('Ed2');
      LGrid := TcxGrid.Create(LForm);
      LGrid.Name := 'Izgara';
      LGrid.Parent := LForm;
      LLevel := LGrid.Levels.Add;
      LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
      LLevel.GridView := LView;
      LCol := LView.CreateColumn;

      Writeln('=== T01) Normal kopma yikim DISI sayiliyor mu? ===');
      LItem := TSondaItem.Create(LForm);
      LItem.Name := 'Sonda1';
      LEd1.RepositoryItem := LItem;
      LOnce := LItem.RemoveCagrisi;
      LEd1.RepositoryItem := nil;
      Kontrol('normal kopmada RemoveListener cagriliyor',
        LItem.RemoveCagrisi > LOnce,
        Format('%d -> %d', [LOnce, LItem.RemoveCagrisi]));
      Kontrol('normal kopma yikim sayacina girmiyor',
        LItem.RemoveYikimSirasinda = 0,
        Format('RemoveYikimSirasinda = %d', [LItem.RemoveYikimSirasinda]));
      LItem.Free;

      Writeln;
      Writeln('=== T02) ASIL OLCUM: bagli tuketiciler varken yikim ===');
      GYikimdaRemove := -1;
      GYikimSonuTuketici := -1;
      LItem := TSondaItem.Create(LForm);
      LItem.Name := 'Sonda2';
      LEd1.RepositoryItem := LItem;
      LEd2.RepositoryItem := LItem;
      LCol.RepositoryItem := LItem;
      Kontrol('uc tuketici bagli',
        LItem.ConsumerCount = 3,
        Format('ConsumerCount = %d (3 bekleniyor)', [LItem.ConsumerCount]));

      LHata := '';
      try
        LItem.Free;
      except
        on E: Exception do
          LHata := E.ClassName + ': ' + E.Message;
      end;

      Kontrol('yikim istisnasiz tamamlandi',
        LHata = '', 'atilan: ' + LHata);
      Writeln('         yikim sirasinda RemoveListener cagrisi : ',
        GYikimdaRemove, '  (3 bekleniyor)');
      Writeln('         yikim sonunda ConsumerCount            : ',
        GYikimSonuTuketici, '  (0 bekleniyor)');

      (* KIRMIZI KOSULU: cagri yikim sirasinda gerceklesiyorsa, FConsumers'in
         ondan ONCE serbest birakilmis olmasi use-after-free demektir. Bu
         iddia duzeltmeden ONCE de dogrudur; duzeltmeden SONRA ise sayac ayni
         kalir ama liste artik canlidir - bu yuzden ikinci bir iddia var:
         yikim sonunda ConsumerCount 0 olmali (liste gercekten bosaltilmis). *)
      (* OLCULDU: uc tuketici icin sayac 6 cikiyor, 3 degil - cunku
         RemoveNotification tuketici basina IKI kez tetikliyor:
           AListener.ItemRemoved(Self)  -> tuketici RepositoryItem := nil
                                           yapar, bu da RemoveListener''i cagirir
           RemoveListener(AListener)    -> dongunun kendi acik cagrisi
         (cxEdit.pas:6749-6754). Kesin sayi DevExpress''in ic isi; bizim icin
         onemli olan SIFIRDAN BUYUK olmasi - zinciri kuran sey bu. *)
      Kontrol('RemoveListener yikim sirasinda gercekten cagriliyor',
        GYikimdaRemove >= 3,
        Format('sayac = %d (tuketici basina iki cagri; sifir olsaydi zincir ' +
               'kurulmazdi ve bulgu gecersiz olurdu)', [GYikimdaRemove]));
      Kontrol('yikim sonunda tuketici listesi bosaltilmis (liste CANLI idi)',
        GYikimSonuTuketici = 0,
        Format('ConsumerCount = %d; serbest birakilmis listede bu sayi ' +
               'guvenilmezdir', [GYikimSonuTuketici]));
    finally
      LForm.Free;
    end;

    Writeln;
    Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
    if GHata > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
