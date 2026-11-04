---
name: rad-script
description: Writing ERP behaviour scripts for the rad-library script system (TMS Scripter, Pascal syntax) — form hooks (`<Comp>_Before/_After`), control-panel event/schedule scripts, module commands, the facade objects (Db, Msg, Kullanici, Sirket, Param, Log, Mail) and the generated API reference. Use whenever a user or an AI needs to add or change ERP behaviour without recompiling, or asks how a script should be written, bound or packaged.
---

# rad-script — ERP davranışını script ile değiştirme

Bu kit'in script sistemi (`src/core/rad.script.pas`, `src/vendor/tms/rad.script.*.pas`) TMS Scripter 8.1
üstünde Pascal sözdizimiyle çalışır. Script yazan kişi programı derlemez; paketi şirket DB'sine kaydeder,
form açılınca ya da KP tetikleyince çalışır. Bu skill **ne yazılır, nereye bağlanır, hangi adlar**
sorularını cevaplar; tasarım gerekçeleri `docs/specs/rad.script*.md`'de.

## Kaynak sırası (önce oku)

1. `docs/script-api.md` — **üretilen** API referansı (global nesneler, sınıf üyeleri, imzalar). Elle
   yazılmış kopyası yoktur; `FacadeTest` her koşuda yeniler. Bir üye orada yoksa script'ten erişilemez.
2. `docs/specs/rad.script.hooks.md` — kanca adı kuralları ve zincir semantiği.
3. `docs/specs/rad.script.facade.md` — facade, `komut`, tipli olaylar.

## Script türleri ve bağlanma anahtarı

| tur | hedef | giriş noktası |
|---|---|---|
| `form` | form sınıf adı (`Tkasa_k`; atalar da eşleşir, ata önce çalışır) | `<Bileşen>_Before(Sender): Boolean`, `<Bileşen>_After(Sender)`, `<Bileşen>_<Olay>_Before/_After`, `Form_AfterCreate(Sender)` |
| `olay` | `rad.eventbus` kanal adı (`efatura.gelen`) | `procedure Calistir(Olay: TRadScriptEvent)` — `Olay.Channel`, `Olay.Json` |
| `zaman` | Quartz maskesi `sn dk saat gün ay haftagünü` (`0 0 8 * * ?`) | `procedure Calistir(Olay: TRadScriptEvent)` |
| `komut` | modül sınıf adı (`Tkasa_modul`) | `procedure <Kod>_Execute(Sender: TObject)` — menüye komut olur |
| `kutuphane` | boş | aynı paketin diğer script'leri `uses <Kod>;` ile kullanır |
| `pencere` | boş | script'in kendi formu: kaynak `{$FORM T<Kod>Form, <kod>.dfm}` ile başlar, DFM pakette `<kod>.dfm` kaynağı; başka script `uses <Kod>;` + `T<Kod>Form.Create(Form)`, `ShowModal`, `Release`; olaylar DFM'de (`OnClick = btnTamamClick` ya da `SaveEvents`) ve script'te `procedure btnTamamClick(Sender: TObject)` |

Kurallar:
- Bileşen **adıyla** bulunur; adsız bileşen görünmez. `Form` sözcüğü formun kendisidir.
- `_Before` yalnız **açık `False`** dönerse olayı iptal eder; `procedure` ya da `Null` geçer. İstisna da
  iptal sayılır ve kullanıcıya gösterilir.
- Aynı olaya birden çok paket bağlıysa sıra `paket.sira`: `B1, B2, orijinal, A2, A1`; herhangi bir
  `Before` `False` derse kalan `Before`'lar ve tüm `After`'lar atlanır.
- `_After` içindeki hata gösterilir, **kayıt geri alınmaz**; transaction isteyen iş `_Before`'a yazılır.
- Dataset olayları (`qry_BeforePost_Before`) orijinal olay işleyicisini keser, `Post`'un kendisini
  durdurmaz; kaydı durdurmak için `Before`'da hata fırlat.
- Var parametreli olaylar yalnız kayıtlı tipler için: `Form_OnCloseQuery_Before(Sender; CanClose): Boolean`
  (`False` → `CanClose := False`), `edt_OnValidate_Before(Sender; DisplayValue; ErrorText): Boolean`
  (`False` → `Error := True`, `ErrorText := Msg.HataMetni(...)` ile konan metin). DevExpress editörlerinde
  olay `Properties` altındadır; adlandırma yine `edt_OnValidate_...`.

## Facade (her script'te hazır)

```pascal
Db.Sorgu('select ad from cari where id = :id').Param('id', 5).Deger     // tek değer
Db.Sorgu('update ... where id = :id').Param('id', 5).Calistir
D := Db.Sorgu('select ...').Ac;  while not D.Eof do begin ... D.Next; end;   // Kapat şart değil
Db.Sayi('select count(*) from ...'); Db.Deger('select ...'); Db.Calistir('...');
Db.BaslaIslem; ... Db.Onayla / Db.GeriAl;      // iç içe yok
Msg.Bilgi / Uyari / Hata(metin); if Msg.Soru('Devam?') then ...   // KP'de Soru hep False
Param.Deger('MailAdresi'); Param.DegerVarsayilan('Esik', '10')     // paketin script_parametre'si
Kullanici.Id / Ad / Kod; Sirket.Kod / Ad
Log.Yaz(metin); Log.Hata(metin); Mail.Gonder(kime, konu, govde)
```

Standart kütüphane: `IntToStr`, `FormatDateTime`, `Now`, `Pos`, `Copy`, `Trim`, `StrToIntDef`...
(TMS `ap_SysUtils/StrUtils/DateUtils/Math/Variants`). `BoolToStr` **yok**; `if` kullan. Script rutinlerinde `const`
parametre **yok** (`Syntax error`): `function Ek(S: string): string`.

## Yapılmaz

- Overload ve varsayılan parametre tanımlama/çağırma yok (RTTI kaydında kayboluyor).
- Nesne yaratma/yıkma yok: `Create`, `Free`, `Destroy` script'e kapalı; `Db.Sorgu` nesneleri motor
  serbest bırakır.
- `Halt`, `Sleep`-benzeri bekleme döngüsü, sonsuz döngü yok: KP script'leri süre sınırıyla kesilir
  (`ERadScriptTimeout`), form script'inde UI donar.
- Formun **kendi** metotları çağrılamaz (form `TForm` olarak görünür); bileşenler adlarıyla açık. VCL metotlarından
  yalnız `Show/Hide/BringToFront/Refresh` (kontrol), `SetFocus`, `Close/Release/ShowModal` (form) vardır; `Click`,
  `SetBounds` gibi diğerleri yok (VCL metot RTTI'si üretmez).
- Pencere script'inde `Form` ERP formu değildir; pencerenin kendisi `Self`. Pencere kancalanmaz (`_Before/_After` yok).
- Bağlantı dizesi/parola/lisans bilgisi facade'da yoktur; `TUniConnection.Password` derleme hatasıdır.
- UI (`Msg`, bileşen değiştirme) yalnız form script'inde; KP script'i `Log`/`Mail`/`Db` kullanır.

## Örnekler

```pascal
// 1. Kaydetmeden önce kontrol (form: Tkasa_k)
function btnKaydet_Before(Sender: TObject): Boolean;
begin
  Result := True;
  if qry.FieldByName('ozel_1').AsString = '' then begin
    Msg.Uyari('Şube kodu zorunlu.');
    Result := False;
  end;
end;

// 2. Kayıttan sonra log
procedure btnKaydet_After(Sender: TObject);
begin
  Db.Sorgu('insert into kasa_log (kasa_id, kullanici) values (:id, :k)')
    .Param('id', qry.FieldByName('id').AsString).Param('k', Kullanici.Kod).Calistir;
end;

// 3. Form açılırken
procedure Form_AfterCreate(Sender: TObject);
begin
  Form.Caption := Form.Caption + ' [script]';
  btnKaydet.Caption := 'Kaydet*';
end;

// 4. KP: her sabah 08:00 (tur=zaman, hedef='0 0 8 * * ?')
procedure Calistir(Olay: TRadScriptEvent);
begin
  if Db.Sayi('select count(*) from fatura where durum = 0') > 0 then
    Mail.Gonder(Param.Deger('MailAdresi'), 'Onay bekleyen fatura var', '');
end;

// 5. Modül komutu (tur=komut, kod=KurGuncelle, hedef='Tkasa_modul')
procedure KurGuncelle_Execute(Sender: TObject);
begin
  Log.Yaz('kur güncellendi: ' + Kullanici.Kod);
end;

// 6. Pencere (tur=pencere, kod=CariOzet; pakette CariOzet.dfm) ve onu açan form script'i
{$FORM TCariOzetForm, CariOzet.dfm}
procedure btnTamamClick(Sender: TObject);
begin
  Close;
end;
// --- Tkasa_k script'inde:
uses CariOzet;
procedure btnOzet_After(Sender: TObject);
var F: TCariOzetForm;
begin
  F := TCariOzetForm.Create(Form);
  F.edtKod.Text := qry.FieldByName('kod').AsString;
  F.ShowModal;
  F.Release;
end;
```

## Düzen (kod yazmadan özelleştirme)

Tasarım kipi (`TRadScriptDesigner.Start(Form, PaketKodu)`) adlı bileşenlerin özelliklerini değiştirir ve farkı pakete
`<FormSınıfı>.duzen.json` (`{"format":1,"form":"Tkasa_k","props":{"btnKaydet.Caption":"Kaydet*",
"edt.Properties.ReadOnly":"True","lytItemNot.Visible":"False"}}`) ve `<FormSınıfı>.<Yerleşim>.layout` kaynağı olarak
yazar; `Attach` bunları **script'ten önce** uygular (`Form_AfterCreate` üstüne yazabilir), paket sırasında sonraki
kazanır. Elle de yazılabilir: anahtar `Bileşen.Özellik[.Alt]`, kök `Form.`, değer DFM metni (`True`, `clRed`,
`[fsBold]`, bileşen başvurusu = adı). Bulunamayan anahtar uyarı verir, kalan uygulanır. Pencere tasarımı:
`TRadScriptDesigner.StartWindow(Paket, Kod)`.

## IDE ve paket yöneticisi (ERP içinden)

Sistem → Script paketleri (`TRadScriptPackagesForm`): paket/script/parametre/DB adımı/kaynak; `.radpaket` içe/dışa
aktarma; **IDE'de aç** TMS IDE'yi paketin üstünde açar (script = dosya, kayıt DB'ye; `Deneme` menüsü: deneme olayı
kanal/JSON + `Calistir(Olay)`; `olay/zaman/kutuphane/pencere` çalıştırılır, kesme noktası/watch IDE'nin Run'ında;
`form/komut` yalnız derlenir — `Form`/bileşenler orada çözülmez, hata ERP formu açılınca gelir). Deneme çalıştırması
**şirket veritabanında** çalışır (onay sorulur). **Tasarla**: pencere script'i (DFM) ya da host açıyorsa form.

## Masaüstü widget'ı (`rad.desktop.script`)

Bir `kutuphane` script'indeki `<Kod>_Yenile(W: TRadDeskWidgetData)` yordamı, ERP masaüstünde
`script:<Kod>` widget'ı olur. Script çizim yapmaz, yalnız `W`'yi doldurur. Çizimi masaüstü yapar.

```pascal
procedure Ciro_Yenile(W: TRadDeskWidgetData);
begin
  W.Title := 'Günlük ciro';
  W.Value := '₺ 1,28 M';           // büyük yazı; sığmazsa otomatik küçülür
  W.SubText := 'Dün: ₺ 1,12 M';
  W.Trend := dtUp;                 // dtNone / dtUp / dtDown
  W.AddPoint(42); W.AddPoint(47);  // mini grafik
  W.AddLine('SP-1042 Akdeniz'#9'₺ 84.300');  // TAB'dan sonrası sağa yaslanır
  // W.Settings: kutucuğun kendi ayar JSON'u
end;
```

- Süre sınırı 3 saniyedir. Aşılırsa ya da script hata verirse hata yalnız o kutucukta gösterilir.
- Hata atmak için `Raise('mesaj')` kullanılır. TMS'de `raise Exception.Create(...)` derlenmez.
- Yenileme aralığı 60 saniyedir. Uzak masaüstünde en az 5 saniyedir.
## Paketleme

Script'ler `script_paket` altında toplanır (`kod` = `firma.kasa-kontrol` biçimi), tek dosya
`<kod>.radpaket` (JSON) ile taşınır; `script_parametre` kurulum ayarlarıdır (içe aktarmada mevcut
değer korunur), `script_db` paketin kendi tablolarının migrasyon adımlarıdır (bir kez koşar).
Ayrıntı: `docs/specs/rad.script.md`.

## Host tarafı (script yazarı değil, ERP geliştiricisi için)

Tek giriş birimi (share/rules/single-entry-facade.md): ERP yalnız `uses rad.scripting;`, KP yalnız
`uses rad.scripting.kp;` — alt `rad.script.*` birimleri host'ta geçmez.

```pascal
// ERP: bağlantı kurulunca bir kez (dm.erp)
LSetup := Default(TRadScriptingSetup);
LSetup.Connection := cnSirketDB; LSetup.UserName := Oturum.UserName;
LSetup.CompanyCode := Oturum.SirketKod; LSetup.CompanyName := Oturum.SirketUnvan;
TRadScripting.Kur(LSetup);                 // store, tablolar, facade, sınıf kayıtları
// taban form (TBaseForm.DoCreate, inherited'dan sonra): her form için tek satır
TRadScripting.Bagla(Self);
// modül başlangıcı
TRadScripting.KomutlariBagla(Self, procedure(const ACode, ACaption: string; AOnExecute: TNotifyEvent)
  begin Komut(ACode, ACaption, 'Script', '', -1, AOnExecute, False); end);
// menü: Sistem → Script paketleri
TRadScripting.PaketYoneticisi(Application).OnOpenFormForDesign := ...;
// KP
TRadScriptingKp.Kur(LKpSetup, Bus, Workers);   // olay/zaman görevleri başlar; paketler değişince Yenile
```

Kodla yaratılan düğme/editörlere `Name` ver; adsız bileşen kancalanamaz ve tasarımcıda görünmez.
`RadScriptTmsDesign.bpl` yalnız ERP'de (tasarımcı + IDE); KP `RadScriptTms` ile yetinir.
