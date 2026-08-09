unit rad.thread.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  System.Rtti,
  Winapi.Windows,
  rad.thread;

type
  [TestFixture]
  TRadTaskTestleri = class
  private
    function YeniOlay: TEvent;
    // BittiOlay'i beklerken CheckSynchronize'i de pompalar; aksi halde
    // TRadTask'ın Synchronize/ForceQueue ile ana thread'e kuyrukladığı
    // OnSuccess/OnError/OnCancel/OnFinally callback'leri hiç çalışmaz.
    function GorevBekle(AOlay: TEvent; AZamanAsimiMs: Integer): Boolean;
  public
    [Test]
    procedure OnGeciktirmeSuresiUygulanir;

    [Test]
    procedure SonGeciktirmeSuresiUygulanir;

    [Test]
    procedure TekrarTamSayidaCalisir;

    [Test]
    procedure HataliGorevYenidenDenenirVeHataVerir;

    [Test]
    [Category('İptal')]
    procedure OnGeciktirmeSirasindaIptalEdilebilir;

    [Test]
    [Category('İptal')]
    procedure YenidenDenemeGeciktirmesindeIptalEdilebilir;

    [Test]
    [Category('İptal')]
    procedure HariciTokenIleIptalEdilebilir;

    [Test]
    [Category('İptal')]
    procedure TekrarGeciktirmesindeIptalEdilebilir;

    [Test]
    procedure TumGorevleriBeklerVeTamamlar;

    [Test]
    procedure AdimlarArasiSonucTasinir;

    [Test]
    [Category('Zaman Aşımı')]
    procedure ZamanAsimindaOnTimeoutTetiklenir;

    [Test]
    [Category('Zaman Aşımı')]
    procedure YenidenDenemeSirasindaZamanAsiminaUgrayanGorevTekrarlanmaz;

    [Test]
    procedure IkinciBaslatmaCagrisiIstisnaFirlatir;

    [Test]
    [Category('İptal')]
    procedure AcikIptalIstisnasiHataDegilIptalSayilir;

    [Test]
    [Category('Eşzamanlılık')]
    procedure EszamanliCokGorevBasariylaTamamlanir;

    [Test]
    procedure IlerlemeBildirimiKisitlanir;

    [Test]
    procedure BeklemeCagrisiEsZamanliCalisir;

    [Test]
    procedure CallbackHatasiYutulurVeZincirDevamEder;

    [Test]
    [Category('İptal')]
    procedure BeklemeSirasindaIptalOnFinallyTamamlanmasiniGarantiEder;

    [Test]
    procedure CalismaVeTamamlanmaDurumuDogruYansir;

    [Test]
    procedure BasariliGorevdeSadeceOnSuccessTetiklenir;

    [Test]
    [Category('İptal')]
    procedure BaslamadanOnceIptalEdilenGorevCalismaz;

    [Test]
    [Category('İptal')]
    procedure CheckCancelledYanlisPozitifVermez;

    [Test]
    [Category('Zaman Aşımı')]
    procedure TimeoutAyarlanmamisGorevZamanAsimayaUgramaz;

    [Test]
    procedure WhenAllBasarisizAltGorevIleTamamlanir;

    [Test]
    procedure WhenAllBosDiziIleAnindaTamamlanir;

    [Test]
    [Category('İptal')]
    procedure AdimZincirindeIptalKalanAdimlariAtlar;

    [Test]
    procedure IkinciWaitCagrisiDaIstisnaFirlatir;

    [Test]
    procedure OncekiOnFinallyEzilmezZincirlenir;

    [Test]
    [Category('İptal')]
    procedure HariciTokenThrowIfCancelledOnCancelTetikler;

    [Test]
    [Category('Zaman Aşımı')]
    procedure CheckTimedOutBaslamadanOnceYanlisPozitifVermez;

    [Test]
    procedure NilProcIleOlusturmaIstisnaFirlatir;

    [Test]
    procedure IlerlemeYuzdesiAralikDisindaKirpilir;

    [Test]
    procedure IlerlemeUseQueueFalseSenkronCalisir;

    [Test]
    [Category('Eşzamanlılık')]
    procedure EsZamanliSetDataGetDataHataVermez;

    [Test]
    procedure ArkaPlanThreadindenWaitCokmez;

    [Test]
    procedure ElapsedMsBaslamadanOnceSifirDoner;
  end;

implementation

function TRadTaskTestleri.YeniOlay: TEvent;
begin
  Result := TEvent.Create(nil, True, False, '');
end;

function TRadTaskTestleri.GorevBekle(AOlay: TEvent; AZamanAsimiMs: Integer): Boolean;
var
  BaslangicTick: UInt64;
begin
  BaslangicTick := GetTickCount64;
  repeat
    if AOlay.WaitFor(5) = wrSignaled then Exit(True);
    CheckSynchronize(5);
  until GetTickCount64 - BaslangicTick >= UInt64(AZamanAsimiMs);
  Result := AOlay.WaitFor(0) = wrSignaled;
end;

{ ── Ön/son gecikme, tekrar, hata+yeniden deneme ────────────────────────── }

procedure TRadTaskTestleri.OnGeciktirmeSuresiUygulanir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var BaslangicZamani := Now;
    var CalismaZamani: TDateTime;
    TRadTask.Create(procedure(t: TRadTask) begin CalismaZamani := Now; end)
      .Named('OnGeciktirmeTesti')
      .SetPreDelay(300)
      .OnSuccess(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'PreDelay görevi tamamlanmadı');
    Assert.IsTrue(MilliSecondsBetween(CalismaZamani, BaslangicZamani) >= 280, 'PreDelay uygulanmadı (>=300ms bekleniyordu)');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.SonGeciktirmeSuresiUygulanir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var BasariZamani, BitisZamani: TDateTime;
    TRadTask.Create(procedure(t: TRadTask) begin end)
      .Named('SonGeciktirmeTesti')
      .SetPostDelay(300)
      .OnSuccess(procedure(t: TRadTask) begin BasariZamani := Now; end)
      .OnFinally(procedure(t: TRadTask) begin
        BitisZamani := Now;
        BittiOlay.SetEvent;
      end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'PostDelay görevi tamamlanmadı');
    Assert.IsTrue(MilliSecondsBetween(BitisZamani, BasariZamani) >= 280, 'PostDelay uygulanmadı (>=300ms bekleniyordu)');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.TekrarTamSayidaCalisir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var TekrarSayisi := 0;
    TRadTask.Create(procedure(t: TRadTask) begin TInterlocked.Increment(TekrarSayisi); end)
      .Named('TekrarTesti')
      .SetRepeat(5, 20)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Repeat görevi tamamlanmadı');
    Assert.AreEqual(5, TekrarSayisi, 'Görev tam 5 kez tekrarlanmadı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.HataliGorevYenidenDenenirVeHataVerir;
var
  BittiOlay: TEvent;
begin
  // Her denemede hata fırlatılırsa (ilk deneme + N retry) kadar denenmeli,
  // sonunda OnError tetiklenmeli ve ErrorMsg dolu olmalı.
  BittiOlay := YeniOlay;
  try
    var DenemeSayisi := 0;
    var HataMesaji: string;
    var Basarili, Iptal: Boolean;
    TRadTask.Create(procedure(t: TRadTask) begin
        TInterlocked.Increment(DenemeSayisi);
        raise Exception.Create('Beklenen test hatası');
      end)
      .Named('YenidenDenemeTesti')
      .Retry(2, 20)
      .OnError(procedure(t: TRadTask) begin
        HataMesaji := t.ErrorMsg;
        Basarili   := t.Success;
        Iptal      := t.Cancelled;
        BittiOlay.SetEvent;
      end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Hatalı görev OnError tetiklemedi');
    Assert.AreEqual(3, DenemeSayisi, 'İlk deneme + 2 yeniden deneme = 3 deneme olmalıydı');
    Assert.IsTrue(HataMesaji.Contains('Beklenen test hatası'), 'ErrorMsg beklenen mesajı içermiyor');
    Assert.IsFalse(Basarili, 'Hatalı görev Success=True olmamalıydı');
    Assert.IsFalse(Iptal, 'Hatalı görev Cancelled=True olmamalıydı');
  finally
    BittiOlay.Free;
  end;
end;

{ ── İptal senaryoları ──────────────────────────────────────────────────── }

procedure TRadTaskTestleri.OnGeciktirmeSirasindaIptalEdilebilir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var CalismaSayisi := 0;
    var IptalTetiklendi := False;
    var Gorev := TRadTask.Create(procedure(t: TRadTask) begin TInterlocked.Increment(CalismaSayisi); end)
      .Named('OnGeciktirmeSirasindaIptal')
      .SetPreDelay(1000)
      .OnCancel(procedure(t: TRadTask) begin
        IptalTetiklendi := True;
        BittiOlay.SetEvent;
      end);
    Gorev.Start;
    Sleep(150);
    Gorev.Cancel;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'PreDelay sırasında iptal edilen görev OnCancel tetiklemedi');
    Assert.IsTrue(IptalTetiklendi, 'OnCancel çalışmadı');
    Assert.AreEqual(0, CalismaSayisi, 'PreDelay sırasında iptal edilen görev çalıştırılmamalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.YenidenDenemeGeciktirmesindeIptalEdilebilir;
var
  BittiOlay: TEvent;
begin
  // Regresyon testi: Cancel() yeniden-deneme geciktirmesi sırasında tetiklenirse
  // ek deneme yapılmamalı.
  BittiOlay := YeniOlay;
  try
    var DenemeSayisi   := 0;
    var IptalTetiklendi := False;
    var HataTetiklendi  := False;
    var Gorev := TRadTask.Create(procedure(t: TRadTask) begin
        TInterlocked.Increment(DenemeSayisi);
        raise Exception.Create('Yeniden deneme sırasında hata');
      end)
      .Named('YenidenDenemeSirasindaIptal')
      .Retry(5, 1000)
      .OnError(procedure(t: TRadTask) begin HataTetiklendi := True; end)
      .OnCancel(procedure(t: TRadTask) begin
        IptalTetiklendi := True;
        BittiOlay.SetEvent;
      end);
    Gorev.Start;
    Sleep(200); // ilk deneme başarısız olup 1000ms'lik geciktirmeye girmiş olmalı
    Gorev.Cancel;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Yeniden deneme geciktirmesinde iptal edilen görev OnCancel tetiklemedi');
    Assert.IsTrue(IptalTetiklendi, 'OnCancel çalışmadı');
    Assert.IsFalse(HataTetiklendi, 'İptal edilen görevde OnError da tetiklenmemeliydi');
    Assert.AreEqual(1, DenemeSayisi, 'İptal sonrası ekstra deneme yapılmamalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.HariciTokenIleIptalEdilebilir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var DonguSayisi := 0;
    var IptalTetiklendi := False;
    var Kaynak := NewCancellationSource;
    var Gorev := TRadTask.Create(procedure(t: TRadTask) begin
        while not t.CheckCancelled do
        begin
          TInterlocked.Increment(DonguSayisi);
          Sleep(20);
        end;
      end)
      .Named('HariciTokenIleIptal')
      .WithCancel(Kaynak.Token)
      .OnCancel(procedure(t: TRadTask) begin
        IptalTetiklendi := True;
        BittiOlay.SetEvent;
      end);
    Gorev.Start;
    Sleep(150);
    Kaynak.Cancel;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Harici token ile iptal edilen görev OnCancel tetiklemedi');
    Assert.IsTrue(IptalTetiklendi, 'OnCancel çalışmadı');
    Assert.IsTrue(DonguSayisi > 0, 'Görev iptalden önce hiç çalışmamış olmalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.TekrarGeciktirmesindeIptalEdilebilir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var CalismaSayisi := 0;
    var IptalTetiklendi := False;
    var Gorev := TRadTask.Create(procedure(t: TRadTask) begin TInterlocked.Increment(CalismaSayisi); end)
      .Named('TekrarGeciktirmesindeIptal')
      .SetRepeat(10, 500) // 10 tekrar, aralarda 500ms bekleme
      .OnCancel(procedure(t: TRadTask) begin
        IptalTetiklendi := True;
        BittiOlay.SetEvent;
      end);
    Gorev.Start;
    Sleep(150); // ilk çalışma bitmiş, tekrar geciktirmesi (500ms) içinde olmalı
    Gorev.Cancel;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Tekrar geciktirmesinde iptal edilen görev OnCancel tetiklemedi');
    Assert.IsTrue(IptalTetiklendi, 'OnCancel çalışmadı');
    Assert.AreEqual(1, CalismaSayisi, 'İptal sonrası ekstra tekrar çalıştırılmamalıydı');
  finally
    BittiOlay.Free;
  end;
end;

{ ── WhenAll / ThenBy+StepResult / WithTimeout ──────────────────────────── }

procedure TRadTaskTestleri.TumGorevleriBeklerVeTamamlar;
var
  BittiOlay: TEvent;
begin
  // WhenAll: tüm alt görevler bitmeden aggregate görev bitmemeli
  // (busy-wait yerine event tabanlı bekleme).
  BittiOlay := YeniOlay;
  try
    var Sayac := 0;
    var G1 := TRadTask.Create(procedure(t: TRadTask) begin TInterlocked.Increment(Sayac); end).Named('G1');
    var G2 := TRadTask.Create(procedure(t: TRadTask) begin Sleep(50);  TInterlocked.Increment(Sayac); end).Named('G2');
    var G3 := TRadTask.Create(procedure(t: TRadTask) begin Sleep(100); TInterlocked.Increment(Sayac); end).Named('G3');

    TRadTask.WhenAll([G1, G2, G3])
      .Named('TumGorevleriBekle')
      .OnSuccess(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'WhenAll tamamlanmadı');
    Assert.AreEqual(3, Sayac, 'WhenAll tüm alt görevlerin bitmesini beklemeden döndü');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.AdimlarArasiSonucTasinir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var SonucDegeri: string;
    TRadTask.Create(procedure(t: TRadTask) begin t.StepResult := TValue.From<Integer>(10); end)
      .Named('AdimZinciriTesti')
      .ThenBy(procedure(t: TRadTask) begin
        var v := t.StepResult.AsType<Integer>;
        t.StepResult := TValue.From<Integer>(v * 2);
      end)
      .ThenBy(procedure(t: TRadTask) begin
        var v := t.StepResult.AsType<Integer>;
        t.StepResult := TValue.From<string>('Sonuc=' + IntToStr(v));
      end)
      .OnSuccess(procedure(t: TRadTask) begin
        SonucDegeri := t.StepResult.AsType<string>;
        BittiOlay.SetEvent;
      end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'ThenBy zinciri tamamlanmadı');
    Assert.AreEqual('Sonuc=20', SonucDegeri, 'ThenBy adımları arasında StepResult doğru taşınmadı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.ZamanAsimindaOnTimeoutTetiklenir;
var
  BittiOlay: TEvent;
begin
  // rad.thread.pas'ta timeout artık cooperative CheckTimedOut ile kontrol
  // edilir (watchdog thread YOK) ve OnCancel DEĞİL, ayrı OnTimeout tetiklenir.
  BittiOlay := YeniOlay;
  try
    var DonguKirildi := False;
    var GecenSure: Int64;
    var TimeoutTetiklendi, IptalTetiklendi, TimedOutOzelligi: Boolean;
    var Gorev := TRadTask.Create(procedure(t: TRadTask) begin
        while not (t.CheckCancelled or t.CheckTimedOut) do
          Sleep(20);
        DonguKirildi := True;
      end)
      .Named('ZamanAsimiTesti')
      .WithTimeout(200)
      .OnTimeout(procedure(t: TRadTask) begin
        GecenSure         := t.ElapsedMs;
        TimeoutTetiklendi := True;
        TimedOutOzelligi  := t.TimedOut;
        BittiOlay.SetEvent;
      end)
      .OnCancel(procedure(t: TRadTask) begin IptalTetiklendi := True; end);
    Gorev.Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Zaman aşımı sonrası OnTimeout tetiklenmedi');
    Assert.IsTrue(DonguKirildi, 'CheckTimedOut döngüyü kırmadı');
    Assert.IsTrue(TimeoutTetiklendi, 'OnTimeout çalışmadı');
    Assert.IsTrue(TimedOutOzelligi, 'TimedOut özelliği True olmalıydı');
    Assert.IsFalse(IptalTetiklendi, 'Zaman aşımında OnCancel TETİKLENMEMELİ (OnTimeout''dan ayrı yol)');
    Assert.IsTrue(GecenSure >= 180, 'Zaman aşımı süresinden belirgin şekilde önce tetiklendi');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.YenidenDenemeSirasindaZamanAsiminaUgrayanGorevTekrarlanmaz;
var
  BittiOlay: TEvent;
begin
  // Regresyon testi: retry-bekleme sırasında timeout dolarsa, dış repeat
  // döngüsü de kırılmalı — FProc fazladan repeat turunda tekrar çalışmamalı.
  BittiOlay := YeniOlay;
  try
    var CagriSayisi := 0;
    var TimeoutTetiklendi := False;
    TRadTask.Create(procedure(t: TRadTask) begin
        TInterlocked.Increment(CagriSayisi);
        raise Exception.Create('Zaman aşımı sırasında kasıtlı hata');
      end)
      .Named('ZamanAsimindaYenidenDenemeTesti')
      .SetRetry(5, 300)
      .SetRepeat(3, 0)
      .WithTimeout(100)
      .OnTimeout(procedure(t: TRadTask) begin
        TimeoutTetiklendi := True;
        BittiOlay.SetEvent;
      end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Zaman aşımında OnTimeout tetiklenmedi');
    Assert.IsTrue(TimeoutTetiklendi, 'OnTimeout çalışmadı');
    Assert.IsTrue(CagriSayisi <= 2, Format('Zaman aşımı sonrası FProc fazladan repeat turunda çağrılmamalıydı (%d kez çağrıldı)', [CagriSayisi]));
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.IkinciBaslatmaCagrisiIstisnaFirlatir;
var
  BittiOlay: TEvent;
begin
  // Çift-başlatma koruması: aynı TRadTask'ı ikinci kez Start/Wait etmek artık
  // ERadTaskAlreadyStarted fırlatır; ilk (geçerli) çalışma bozulmadan sürer.
  BittiOlay := YeniOlay;
  try
    var IstisnaFirladi := False;
    var Gorev := TRadTask.Create(procedure(t: TRadTask) begin Sleep(150); end)
      .Named('CiftBaslatmaTesti')
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end);

    Gorev.Start;
    try
      Gorev.Start;
    except
      on E: ERadTaskAlreadyStarted do
        IstisnaFirladi := True;
    end;

    Assert.IsTrue(IstisnaFirladi, 'İkinci Start çağrısı ERadTaskAlreadyStarted fırlatmadı');
    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'İlk (geçerli) çalışma tamamlanmadı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.AcikIptalIstisnasiHataDegilIptalSayilir;
var
  BittiOlay: TEvent;
begin
  // FProc içinden t.CheckCancelled(True) çağrılırsa ERadTaskCancelled fırlatılır
  // ve bu, generic Exception handler'dan ÖNCE yakalanıp OnCancel'a yönlendirilir
  // — OnError/retry mantığı TETİKLENMEMELİ.
  BittiOlay := YeniOlay;
  try
    var IptalTetiklendi, HataTetiklendi: Boolean;
    TRadTask.Create(procedure(t: TRadTask) begin
        t.Cancel;
        t.CheckCancelled(True);
      end)
      .Named('AcikIptalIstisnasiTesti')
      .SetRetry(3, 20)
      .OnCancel(procedure(t: TRadTask) begin
        IptalTetiklendi := True;
        BittiOlay.SetEvent;
      end)
      .OnError(procedure(t: TRadTask) begin HataTetiklendi := True; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Açık CheckCancelled(True) sonrası OnCancel tetiklenmedi');
    Assert.IsTrue(IptalTetiklendi, 'OnCancel çalışmadı');
    Assert.IsFalse(HataTetiklendi, 'ERadTaskCancelled, OnError''a değil OnCancel''a yönlendirilmeliydi (retry de tetiklenmemeliydi)');
  finally
    BittiOlay.Free;
  end;
end;

{ ── Eşzamanlı çoklu görev (stres) ───────────────────────────────────────── }

procedure TRadTaskTestleri.EszamanliCokGorevBasariylaTamamlanir;
const
  GorevSayisi = 25;
var
  BittiOlay: TEvent;
  Kalan: Integer;
  BasariSayisi: Integer;
begin
  BittiOlay := YeniOlay;
  try
    Kalan        := GorevSayisi;
    BasariSayisi := 0;

    for var i := 1 to GorevSayisi do
    begin
      var Sira := i; // her closure kendi kopyasını yakalasın (loop değişkeni paylaşılmasın)
      TRadTask.Create(procedure(t: TRadTask) begin
          Sleep(5 + Random(30));
          t.SetData('sira', Sira);
        end)
        .Named('Stres' + IntToStr(Sira))
        .OnSuccess(procedure(t: TRadTask) begin
          TInterlocked.Increment(BasariSayisi);
        end)
        .OnFinally(procedure(t: TRadTask) begin
          if TInterlocked.Decrement(Kalan) = 0 then
            BittiOlay.SetEvent;
        end)
        .Start;
    end;

    Assert.IsTrue(GorevBekle(BittiOlay, 8000), 'Eşzamanlı görevler zamanında tamamlanmadı');
    Assert.AreEqual(GorevSayisi, BasariSayisi, 'Bazı görevler başarısız oldu veya hiç tamamlanmadı');
    Assert.AreEqual(0, Kalan, 'Bekleyen görev sayısı sıfıra inmedi');
  finally
    BittiOlay.Free;
  end;
end;

{ ── İlerleme bildirimi + throttle ──────────────────────────────────────── }

procedure TRadTaskTestleri.IlerlemeBildirimiKisitlanir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var BildirimSayisi := 0;
    var SonIlerleme     := -1;
    var SonMesaj: string;

    TRadTask.Create(procedure(t: TRadTask) begin
        for var i := 1 to 10 do
        begin
          t.ReportProgress(i * 10, 'Adim ' + IntToStr(i));
          Sleep(15); // throttle(80ms)'den kısa aralıklarla çağır -> çoğu atlanmalı
        end;
      end)
      .Named('KisitlanmaTesti')
      .SetThrottle(80)
      .OnProgress(procedure(t: TRadTask) begin
        TInterlocked.Increment(BildirimSayisi);
        SonIlerleme := t.Progress;
        SonMesaj    := t.ProgressMsg;
      end)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Kısıtlama testi tamamlanmadı');
    Assert.IsTrue(BildirimSayisi >= 1, 'En az bir ilerleme bildirimi gelmeliydi');
    Assert.IsTrue(BildirimSayisi < 10, Format('Kısıtlama, çoğu ilerleme çağrısını süzmeliydi (%d geldi)', [BildirimSayisi]));
    Assert.AreEqual(100, SonIlerleme, 'Son ilerleme (%100, kısıtlamadan muaf) tetiklenmemiş');
    Assert.AreEqual('Adim 10', SonMesaj, 'Son ilerleme mesajı beklenenden farklı');
  finally
    BittiOlay.Free;
  end;
end;

{ ── Wait() — bloklayan çağrı ───────────────────────────────────────────── }

procedure TRadTaskTestleri.BeklemeCagrisiEsZamanliCalisir;
var
  BaslangicZamani, CalismaZamani: TDateTime;
begin
  BaslangicZamani := Now;

  TRadTask.Create(procedure(t: TRadTask) begin
      Sleep(200);
      CalismaZamani := Now;
    end)
    .Named('BeklemeTesti')
    .Wait;

  // Wait çağrısı, arka plan işi (Sleep 200) bitmeden dönmemeli.
  Assert.IsTrue(MilliSecondsBetween(CalismaZamani, BaslangicZamani) >= 180, 'İş, Wait dönmeden önce tamamlanmadı');
  Assert.IsTrue(MilliSecondsBetween(Now, BaslangicZamani) >= 180, 'Wait, arka plan işi bitmeden erken döndü');
end;

{ ── Callback'in kendisi exception fırlatırsa ───────────────────────────── }
// Not: Bu test kasıtlı olarak exception fırlatır. IDE debugger'da "Stop on
// Delphi Exceptions" açıksa debugger bu satırda durur (crash değildir) —
// testi Ctrl+Shift+F9 (Run Without Debugging) ile veya exe'den çalıştır.

procedure TRadTaskTestleri.CallbackHatasiYutulurVeZincirDevamEder;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var OnFinallyTetiklendi := False;
    TRadTask.Create(procedure(t: TRadTask) begin end)
      .Named('CallbackHatasiTesti')
      .OnSuccess(procedure(t: TRadTask) begin
        raise Exception.Create('OnSuccess içinde kasıtlı hata');
      end)
      .OnFinally(procedure(t: TRadTask) begin
        OnFinallyTetiklendi := True;
        BittiOlay.SetEvent;
      end)
      .Start;

    // OnSuccess içindeki exception FireCallback.SafeInvoke tarafından yutulmalı
    // (log'lanmalı) ve OnFinally normal şekilde tetiklenmeye devam etmeli.
    Assert.IsTrue(GorevBekle(BittiOlay, 5000),
      'OnSuccess içinde fırlatılan hata zinciri bozdu — OnFinally hiç tetiklenmedi');
    Assert.IsTrue(OnFinallyTetiklendi, 'OnFinally çalışmadı');
  finally
    BittiOlay.Free;
  end;
end;

{ ── Kök bug regresyon testleri (FCancelEvent/FCompletedEvent ayrımı, TInterlocked durum) ── }

procedure TRadTaskTestleri.BeklemeSirasindaIptalOnFinallyTamamlanmasiniGarantiEder;
var
  Yardimci: TThread;
begin
  // Kök bug regresyonu: Cancel() Wait() sırasında tetiklenirse, Wait() ancak
  // OnFinally GERÇEKTEN tamamlandıktan sonra dönmeli — FCancelEvent/
  // FCompletedEvent ayrılmadan önce erken Free riski vardı.
  var OnFinallyTamamlandi := False;
  var IptalTetiklendi := False;
  var Gorev := TRadTask.Create(procedure(t: TRadTask)
      var i: Integer;
      begin
        for i := 1 to 50 do
        begin
          if t.CheckCancelled then Exit;
          Sleep(10);
        end;
      end)
    .Named('BeklemeIptalYarisTesti')
    .OnCancel(procedure(t: TRadTask) begin IptalTetiklendi := True; end)
    .OnFinally(procedure(t: TRadTask) begin
      Sleep(30); // OnFinally'nin gerçekten tamamlanması için kasıtlı gecikme
      OnFinallyTamamlandi := True;
    end);

  Yardimci := TThread.CreateAnonymousThread(procedure begin
    Sleep(100);
    Gorev.Cancel;
  end);
  Yardimci.FreeOnTerminate := False;
  Yardimci.Start;

  Gorev.Wait; // Wait dönmeden ÖNCE OnFinally KESİN bitmiş olmalı

  Assert.IsTrue(OnFinallyTamamlandi, 'Wait(), OnFinally tamamlanmadan döndü — erken serbest bırakma riski');
  Assert.IsTrue(IptalTetiklendi, 'OnCancel çalışmadı');
  Yardimci.WaitFor;
  Yardimci.Free;
end;

procedure TRadTaskTestleri.CalismaVeTamamlanmaDurumuDogruYansir;
var
  BittiOlay: TEvent;
begin
  // Bug #3 regresyonu: IsRunning/IsDone artık TInterlocked ile okunuyor.
  BittiOlay := YeniOlay;
  try
    var IsRunningOnFinallyIcinde, IsDoneOnFinallyIcinde: Boolean;
    var Gorev := TRadTask.Create(procedure(t: TRadTask) begin Sleep(150); end)
      .Named('DurumTesti')
      .OnFinally(procedure(t: TRadTask) begin
        IsRunningOnFinallyIcinde := t.IsRunning;
        IsDoneOnFinallyIcinde    := t.IsDone;
        BittiOlay.SetEvent;
      end);

    Gorev.Start;
    Assert.IsTrue(Gorev.IsRunning, 'Start hemen sonrası IsRunning True olmalıydı');
    Assert.IsFalse(Gorev.IsDone, 'Start hemen sonrası IsDone False olmalıydı');

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev tamamlanmadı');
    Assert.IsFalse(IsRunningOnFinallyIcinde, 'OnFinally içinde IsRunning False olmalıydı');
    Assert.IsTrue(IsDoneOnFinallyIcinde, 'OnFinally içinde IsDone True olmalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.BasariliGorevdeSadeceOnSuccessTetiklenir;
var
  BittiOlay: TEvent;
begin
  // Karşılıklı dışlama: OnSuccess/OnError/OnCancel/OnTimeout'tan tam olarak
  // biri tetiklenmeli.
  BittiOlay := YeniOlay;
  try
    var BasariSayisi, HataSayisi, IptalSayisi, TimeoutSayisi: Integer;
    TRadTask.Create(procedure(t: TRadTask) begin end)
      .Named('TekCallbackTesti')
      .OnSuccess(procedure(t: TRadTask) begin TInterlocked.Increment(BasariSayisi); end)
      .OnError(procedure(t: TRadTask) begin TInterlocked.Increment(HataSayisi); end)
      .OnCancel(procedure(t: TRadTask) begin TInterlocked.Increment(IptalSayisi); end)
      .OnTimeout(procedure(t: TRadTask) begin TInterlocked.Increment(TimeoutSayisi); end)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev tamamlanmadı');
    Assert.AreEqual(1, BasariSayisi, 'OnSuccess tam olarak bir kez tetiklenmeliydi');
    Assert.AreEqual(0, HataSayisi, 'OnError tetiklenmemeliydi');
    Assert.AreEqual(0, IptalSayisi, 'OnCancel tetiklenmemeliydi');
    Assert.AreEqual(0, TimeoutSayisi, 'OnTimeout tetiklenmemeliydi');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.BaslamadanOnceIptalEdilenGorevCalismaz;
begin
  var CalistiMi := False;
  var Gorev := TRadTask.Create(procedure(t: TRadTask) begin CalistiMi := True; end)
    .Named('BaslamadanOnceIptalTesti');
  Gorev.Cancel; // Start/Wait çağrılmadan önce iptal
  Gorev.Wait;   // InternalExecute'un ilk checkpoint'i hemen True dönmeli, FProc hiç çalışmamalı

  Assert.IsFalse(CalistiMi, 'Başlamadan önce iptal edilen görev FProc''u çalıştırmamalıydı');
end;

procedure TRadTaskTestleri.CheckCancelledYanlisPozitifVermez;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var IstisnaFirladi := False;
    var BasariTetiklendi := False;
    TRadTask.Create(procedure(t: TRadTask) begin
        try
          t.CheckCancelled(True); // iptal edilmedi -> raise ETMEMELİ
        except
          on E: ERadTaskCancelled do
            IstisnaFirladi := True;
        end;
      end)
      .Named('YanlisPozitifTesti')
      .OnSuccess(procedure(t: TRadTask) begin BasariTetiklendi := True; end)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev tamamlanmadı');
    Assert.IsFalse(IstisnaFirladi, 'CheckCancelled(True) iptal edilmemişken istisna fırlatmamalıydı');
    Assert.IsTrue(BasariTetiklendi, 'Görev normal şekilde başarıyla tamamlanmalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.TimeoutAyarlanmamisGorevZamanAsimayaUgramaz;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var TimeoutTetiklendi := False;
    var BasariTetiklendi := False;
    TRadTask.Create(procedure(t: TRadTask) begin
        Sleep(150); // WithTimeout çağrılmadı (FTimeout=0) -> hiçbir süre sınırı yok
      end)
      .Named('TimeoutYokTesti')
      .OnTimeout(procedure(t: TRadTask) begin TimeoutTetiklendi := True; end)
      .OnSuccess(procedure(t: TRadTask) begin BasariTetiklendi := True; end)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev tamamlanmadı');
    Assert.IsFalse(TimeoutTetiklendi, 'WithTimeout çağrılmadıysa OnTimeout asla tetiklenmemeliydi');
    Assert.IsTrue(BasariTetiklendi, 'Görev normal şekilde tamamlanmalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.WhenAllBasarisizAltGorevIleTamamlanir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var TamamlandiMi := False;
    var G1 := TRadTask.Create(procedure(t: TRadTask) begin end).Named('BasariliAlt');
    var G2 := TRadTask.Create(procedure(t: TRadTask) begin raise Exception.Create('kasıtlı alt görev hatası'); end).Named('BasarisizAlt');

    TRadTask.WhenAll([G1, G2])
      .Named('BasarisizAltIleWhenAll')
      .OnFinally(procedure(t: TRadTask) begin
        TamamlandiMi := True;
        BittiOlay.SetEvent;
      end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'WhenAll (başarısız alt görevle) tamamlanmadı');
    Assert.IsTrue(TamamlandiMi, 'WhenAll bir alt görev başarısız olsa bile tamamlanmalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.WhenAllBosDiziIleAnindaTamamlanir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var TamamlandiMi := False;
    TRadTask.WhenAll([])
      .Named('BosDiziTesti')
      .OnFinally(procedure(t: TRadTask) begin
        TamamlandiMi := True;
        BittiOlay.SetEvent;
      end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 2000), 'Boş dizi ile WhenAll zamanında tamamlanmadı');
    Assert.IsTrue(TamamlandiMi, 'Boş dizi ile WhenAll tamamlanmalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.AdimZincirindeIptalKalanAdimlariAtlar;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var Adim1Calisti, Adim2Calisti, Adim3Calisti: Boolean;
    TRadTask.Create(procedure(t: TRadTask) begin Adim1Calisti := True; end)
      .Named('AdimIptalTesti')
      .ThenBy(procedure(t: TRadTask) begin
        Adim2Calisti := True;
        t.Cancel; // ikinci adımdan sonra iptal
      end)
      .ThenBy(procedure(t: TRadTask) begin Adim3Calisti := True; end)
      .OnCancel(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev iptal edilmedi');
    Assert.IsTrue(Adim1Calisti, 'İlk adım (FProc) çalışmalıydı');
    Assert.IsTrue(Adim2Calisti, 'İkinci ThenBy adımı çalışmalıydı (iptal orada tetiklendi)');
    Assert.IsFalse(Adim3Calisti, 'Üçüncü ThenBy adımı, iptalden sonra ÇALIŞMAMALIYDI');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.IkinciWaitCagrisiDaIstisnaFirlatir;
begin
  var IstisnaFirladi := False;
  var Gorev := TRadTask.Create(procedure(t: TRadTask) begin Sleep(150); end)
    .Named('IkinciWaitTesti');

  Gorev.Start; // fire & forget başlat

  try
    Gorev.Wait; // aynı örnek üzerinde ikinci bir çalıştırma çağrısı
  except
    on E: ERadTaskAlreadyStarted do
      IstisnaFirladi := True;
  end;

  Assert.IsTrue(IstisnaFirladi, 'Zaten çalışan bir görev üzerinde Wait çağrısı ERadTaskAlreadyStarted fırlatmadı');
  Sleep(300); // ilk (geçerli) çalışmanın auto-free ile bitmesini bekle
end;

{ ── 2026-07-09: "1.md"/"2.md" incelemesinden doğrulanan 10 ek bug (bkz. rad.thread.md) ── }

procedure TRadTaskTestleri.OncekiOnFinallyEzilmezZincirlenir;
var
  BittiOlay: TEvent;
begin
  // WhenAll, alt görevin önceden tanımlanmış OnFinally'sini artık EZMEZ —
  // MakeChainedFinally ile zincirlenir (bkz. project_delphi_compiler_quirks.md #7).
  BittiOlay := YeniOlay;
  try
    var OncekiCalisti := False;
    var G1 := TRadTask.Create(procedure(t: TRadTask) begin end).Named('WhenAllZincirG1');
    G1.OnFinally(procedure(t: TRadTask) begin OncekiCalisti := True; end);
    var G2 := TRadTask.Create(procedure(t: TRadTask) begin end).Named('WhenAllZincirG2');

    TRadTask.WhenAll([G1, G2])
      .Named('WhenAllZincirlemeTesti')
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'WhenAll tamamlanmadı');
    Assert.IsTrue(OncekiCalisti, 'Alt görevin önceden tanımlı OnFinally''si WhenAll tarafından EZİLDİ');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.HariciTokenThrowIfCancelledOnCancelTetikler;
var
  BittiOlay: TEvent;
begin
  // ThrowIfCancelled artık ERadTaskCancelled fırlatır (RTL'in EOperationCancelled'ı
  // DEĞİL) — bu yüzden OnError/retry değil OnCancel tetiklenir.
  BittiOlay := YeniOlay;
  try
    var Kaynak := NewCancellationSource;
    Kaynak.Cancel;
    var IptalTetiklendi, HataTetiklendi: Boolean;
    TRadTask.Create(procedure(t: TRadTask) begin
        Kaynak.Token.ThrowIfCancelled; // WithCancel KULLANILMIYOR - sadece bu satır test ediliyor
      end)
      .Named('ThrowIfCancelledTesti')
      .OnCancel(procedure(t: TRadTask) begin IptalTetiklendi := True; end)
      .OnError(procedure(t: TRadTask) begin HataTetiklendi := True; end)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev tamamlanmadı');
    Assert.IsTrue(IptalTetiklendi, 'ThrowIfCancelled sonrası OnCancel tetiklenmedi');
    Assert.IsFalse(HataTetiklendi, 'ThrowIfCancelled, OnError''a değil OnCancel''a yönlendirilmeliydi');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.CheckTimedOutBaslamadanOnceYanlisPozitifVermez;
var
  Gorev: TRadTask;
begin
  // FRunStartTick=0 (görev hiç Start/Wait edilmedi) iken CheckTimedOut, sistem
  // çalışma süresini (uptime) süre aşımı sanıp yanlış-pozitif VERMEMELİ.
  Gorev := TRadTask.Create(procedure(t: TRadTask) begin end).WithTimeout(100);
  try
    Assert.IsFalse(Gorev.CheckTimedOut, 'CheckTimedOut, görev hiç başlamadan True dönmemeliydi');
  finally
    Gorev.Free;
  end;
end;

procedure TRadTaskTestleri.NilProcIleOlusturmaIstisnaFirlatir;
begin
  Assert.WillRaise(
    procedure begin TRadTask.Create(nil); end,
    ERadTaskInvalidArgument);
end;

procedure TRadTaskTestleri.IlerlemeYuzdesiAralikDisindaKirpilir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var SonIlerleme: Integer;
    TRadTask.Create(procedure(t: TRadTask) begin
        t.ReportProgress(-50, '', False);
        t.ReportProgress(500, '', False);
      end)
      .Named('IlerlemeKirpilirTesti')
      .SetThrottle(0)
      .OnProgress(procedure(t: TRadTask) begin SonIlerleme := t.Progress; end)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev tamamlanmadı');
    Assert.AreEqual(100, SonIlerleme, 'İlerleme 0-100 aralığına kırpılmadı (üst sınır)');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.IlerlemeUseQueueFalseSenkronCalisir;
var
  BittiOlay: TEvent;
begin
  BittiOlay := YeniOlay;
  try
    var CallbackOnceCalistiMi := False; // ReportProgress dönmeden ÖNCE callback çalıştı mı
    var CallbackHicCalismadi := True;
    TRadTask.Create(procedure(t: TRadTask) begin
        t.ReportProgress(50, '', False); // UseQueue=False -> senkron (Synchronize)
        CallbackOnceCalistiMi := not CallbackHicCalismadi;
      end)
      .Named('UseQueueTesti')
      .SetThrottle(0)
      .OnProgress(procedure(t: TRadTask) begin CallbackHicCalismadi := False; end)
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end)
      .Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'Görev tamamlanmadı');
    Assert.IsTrue(CallbackOnceCalistiMi, 'UseQueue=False iken OnProgress, ReportProgress dönmeden ÖNCE (senkron) çalışmalıydı');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.EsZamanliSetDataGetDataHataVermez;
const
  YardimciSayisi = 4;
var
  BittiOlay: TEvent;
  Yardimcilar: array[0..YardimciSayisi - 1] of TThread;
  HataOldu: Boolean;
  i: Integer;
begin
  // FData artık FDataLock ile korunuyor — eşzamanlı SetData/GetData sırasında
  // AV/hata OLMAMALI (bkz. project_no_more_tdynarrayhashed.md'deki benzer geçmiş).
  BittiOlay := YeniOlay;
  HataOldu := False;
  try
    var Gorev := TRadTask.Create(procedure(t: TRadTask)
        var k: Integer;
        begin
          for k := 1 to 200 do
          begin
            t.SetData('k' + IntToStr(k mod 10), k);
            t.GetData('k' + IntToStr(k mod 10), 0);
          end;
        end)
      .Named('DataEsZamanliTesti')
      .OnFinally(procedure(t: TRadTask) begin BittiOlay.SetEvent; end);

    for i := 0 to YardimciSayisi - 1 do
    begin
      Yardimcilar[i] := TThread.CreateAnonymousThread(procedure
        var j: Integer;
        begin
          try
            for j := 1 to 500 do
            begin
              Gorev.SetData('x' + IntToStr(j mod 5), j);
              Gorev.GetData('x' + IntToStr(j mod 5), 0);
            end;
          except
            HataOldu := True;
          end;
        end);
      Yardimcilar[i].FreeOnTerminate := False;
      Yardimcilar[i].Start;
    end;

    Gorev.Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 8000), 'Görev zamanında tamamlanmadı');
    for i := 0 to YardimciSayisi - 1 do
    begin
      Yardimcilar[i].WaitFor;
      Yardimcilar[i].Free;
    end;
    Assert.IsFalse(HataOldu, 'Eşzamanlı SetData/GetData sırasında hata/AV oluştu');
  finally
    BittiOlay.Free;
  end;
end;

procedure TRadTaskTestleri.ArkaPlanThreadindenWaitCokmez;
var
  TamamlandiMi, HataOldu: Boolean;
  Yardimci: TThread;
begin
  // Wait(), main thread dışından çağrılırsa artık Application.ProcessMessages
  // KULLANMAZ (VCL'de güvensiz) — doğrudan bloklayarak bekler.
  TamamlandiMi := False;
  HataOldu := False;
  Yardimci := TThread.CreateAnonymousThread(procedure
    begin
      try
        TRadTask.Create(procedure(t: TRadTask) begin Sleep(50); end)
          .Named('ArkaPlanWaitTesti')
          .Wait;
        TamamlandiMi := True;
      except
        HataOldu := True;
      end;
    end);
  Yardimci.FreeOnTerminate := False;
  Yardimci.Start;
  Yardimci.WaitFor;
  Yardimci.Free;

  Assert.IsTrue(TamamlandiMi and not HataOldu, 'Arka plan thread''den Wait çökmeden tamamlanmalıydı');
end;

procedure TRadTaskTestleri.ElapsedMsBaslamadanOnceSifirDoner;
var
  Gorev: TRadTask;
begin
  Gorev := TRadTask.Create(procedure(t: TRadTask) begin end);
  try
    Assert.AreEqual(Int64(0), Gorev.ElapsedMs, 'ElapsedMs, görev başlamadan 0 dönmeliydi');
  finally
    Gorev.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadTaskTestleri);

end.
