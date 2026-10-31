# Sonda raporu: script motoru seçimi (`rad.script` 1. aşama)

Tarih: 2026-11-01. Karar: **TMS Scripter 8.1** (DWScript kullanıcı kararıyla elendi,
FastScript ölçüm öncesi kaynak incelemesiyle elendi). Kod: `src/test/scratch/rad_script_spike/`
(`SpikeCore.dpr`, `SpikeVcl.dpr`, `spikeform.dfm`). Hiçbir kalıcı birim yazılmadı.

## Neden TMS Scripter

| İhtiyaç | TMS Scripter 8.1 (Haz 2026) | FastScript (FR 2026.2.1) | Wolvox'un PascalScript 1.31'i |
|---|---|---|---|
| Önce/sonra olay kesme | `EventBroker.SetEvent(epTopCall/epBottomCall)` + `UnsetEvent` | yalnız değiştirir | RTTI `SetMethodProp` ile elle üretilen sarmalayıcı |
| Sınıfları açma | `DefineClassByRTTI`: public+published, sarmalayıcısız | yalnız published özellik, metotlar elle | RTTI + ~1.100 sınıflık elle beyaz liste |
| Script'ten form | DFM'den script formu + çalışma zamanı tasarımcısı/inspector/editör/debugger | yok | yeni form DFM'den, LMD inspector |
| UI'siz (KP) | çekirdek VCL'siz derleniyor, Win64 var | thread beyanı yok | yalnız e-belge thread'i |
| Delphi 13 | `packages\d13`, Win32/Win64 DCU hazır | var | eski taban |

## Ölçümler (Delphi 13, Win32 + Win64)

### Çekirdek (`SpikeCore`, 10/10 her iki platform)

| Ölçüm | Sonuç |
|---|---|
| C1 küçük script derleme | 0 ms |
| C2 501 satır (100 prosedür) derleme | 9 ms (Win64 10 ms) |
| C3 10.000 `ExecuteSubroutine` çağrısı | 101 ms (~10 µs/çağrı) |
| C4 script içinden 10.000 Delphi metot çağrısı (RTTI kayıtlı sınıf) | 12 ms |
| C4 `DefineClassByRTTI(TProbe)` | 0 ms |
| C5 RTTI kapsamı | public metot/özellik kayıtlı; **overload'da son bildirilen kazanır** (belge "ilki" diyor), diğeri hiç yok; **varsayılan parametre zorunlu olur** (`Greet('Ali')` → "Expected 2 parameters"); `array of Integer` ve `TArray<string>` döndüren metotlar listede görünüyor (çağrı denenmedi) |
| C6 p-code kaydet/yükle | 3.809 bayt (Win64 4.233); kaynaksız yeni scripter'da çalıştı |
| C7 4 thread, her birinin kendi scripter'ı | 4/4 doğru |
| C8 çalışma zamanı hatası | `EatScripterRuntime: RUNTIME ERROR / Division by zero`, satır/sütun var |
| C9 `OnExecHook` içinden `Halt` | döngü 2 ms'de bitti ama **komut ortasında kesildiği için AV** (`Read of address 19 … PushInteger`), Win64'te "INTERNAL ERROR"; `Halted=False` |
| C10 başka thread'den `Halt` | **güvenilmez**: Win32'de 312 ms'de durdu, Win64'te 5 s beklemedi; ardından `Free` "Cannot clear script while script is running" ile patladı, süreç asılı kaldı |
| C10' hook içinden **istisna** (`raise ERadScriptTimeout`) | 300 ms sınırda 301 ms'de temiz çıkış, `EatScripterRuntime` olarak yakalanır, VM sağlam |

### VCL (`SpikeVcl`, 11/11 Win32)

| Ölçüm | Sonuç |
|---|---|
| V1 8 sınıf `DefineClassByRTTI` | 2 ms; `TcxButton` 27 metot/99 özellik, `TcxDBTextEdit` 98/107, `TcxGrid` 68/87, `TcxGridDBTableView` 86/164, `TdxLayoutControl` 75/131, `TRadQuery` 170/135 |
| V1 script'ten bileşen özelliği yazma | `btnKaydet.Caption`, `edtAd.Text`, `qryKasa.SQL.Text` yazıldı |
| V2 `epTopCall` / `epBottomCall` | sıra doğru: `script-before,delphi-exec`; `delphi-click,script-after`; `UnsetEvent` orijinali geri koydu |
| V2 `epTopCall` + script'te istisna | orijinal çalışmadı ama **hata olarak** yayıldı (`EatScripterRuntime`); temiz iptal yok |
| V3 kendi RTTI sarmalayıcımız (`TRadNotifyHook`) | `own-before,delphi-exec,own-after`; `Before` `False` dönünce orijinal **çalışmadı** (temiz iptal); `Detach` geri koydu |
| V3 10.000 kancalı `Action.Execute` (önce+sonra script) | 250 ms (25 µs/çağrı); kancasız 0 ms |
| V4 DevExpress `TcxEditValidateEvent` (var parametreli) adaptörü | elle yazılan `TatEventDispatcher` ile `delphi-validate:abc,script-validate:abc`; var parametreler script'e **değerle** gider, geri yazılmaz |
| V5 DFM'den script formu (`{$FORM TfmSpike, spikeform.dfm}`, `TcxButton`/`TcxTextEdit` içeren) | yaratıldı, DFM özellikleri okundu; `f.Show` XE7 dönemi `ap_Forms` import'unda yok ("Unknown member identifier") |
| V6 `TIDEEngine`, `TIDEDialog`, `TScrMemo` + Pascal styler | yaratıldı, linklendi |

## Tasarım kararları (ölçümlerden)

1. **Olay kesme kendi sarmalayıcımızla** (Wolvox kalıbı + iptal): `TNotifyEvent` için
   `TRadNotifyHook` (`Before(Sender): Boolean` iptal eder, `After(Sender)`), geri alma `Detach`.
   Tipli DevExpress olayları için TMS `DefineEventAdapter` üretici (Import Tool ya da kendi
   üretecimiz); var parametreler script'e kopya gider, "geri yazma" gerekirse olaya özel köprü.
2. **Zaman aşımı/iptal**: yalnız script'in kendi thread'inde `OnExecHook` + istisna. `Halt` komut
   ortasında VM'yi bozuyor; başka thread'den `Halt` yasak.
3. **Thread**: scripter nesnesi thread başına; paylaşılan tek scripter yok. KP'de görev başına
   scripter + `CallExecHookEvent` ile süre sınırı.
4. **Facade API'de overload ve varsayılan parametre yok** (RTTI kaydında kayboluyor); tek ad, tüm
   parametreler açık. Yapay zeka için üretilecek referans `Scripter.Classes` listesinden çıkar.
5. **Form sınıfları**: XE7 import'larına güvenme; `TForm`/`TScriptForm`'u kendi
   `DefineClassByRTTI` kaydımızla aç (Show/Close dahil).
6. **Derleme hızı sorun değil** (500 satır 9 ms); p-code saklama mümkün ama kaynak gizleme sayılmaz.
7. `Vcl.ScripterInit` birimi **şart** (`DefaultMachineClass`); olmadan `EatInternalError`. KP de
   VCL'li olduğu için sorun değil.

## Sonraki aşamalar (TODO RAD-15)

2. Paket modeli + DB tabloları + yükleyici + dışa/içe aktarma.
3. Kanca katmanı (`rad.script.hooks`): action/click/dataset/form olayları, KP adlandırılmış
   olaylar + zamanlayıcı, `rad.eventbus` üstünden.
4. Facade API + sınıf kaydı + `rad-script` skill'i.
5. Tasarımcı: mevcut form (`TcxRTTIInspector` + düzen), yeni form (TMS tasarımcısı).
6. IDE formları.
