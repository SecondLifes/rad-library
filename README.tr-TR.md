# RAD Library AI Spec-Kit

Küçük, kararlı ve hızlı bir Delphi library/component seti geliştirmek için AI
specification kit. Delphi 13+ (tercihen güncel kararlı sürüm), Win32/Win64,
VCL ve FMX hedeflenir.

[English](README.md)

## Sözleşme

- Çekirdek harici bağımlılık içermez; vendor entegrasyonları ayrıdır.
- Helper unit adları `help.*`, public helper fonksiyon/metotları `_` ile başlar.
- Component class adları `TRAD` ile başlar; runtime/design-time paketleri ayrıdır.
- Projeyle ilgili tüm yollar `src/`, testler `src/test/`, vendor adaptörleri
  `src/vendor/` altındadır.
- Test dosya adı kaynak dosya adına `.test` eklenerek oluşturulur.
- Public metotlar başarı, sınır ve hata yolu DUnitX testleri gerektirir.
- Performans iddiaları kayıtlı Release Win32/Win64 benchmark gerektirir.
- Örnekler yalnızca yapıyı gösterir; AI API veya davranış uyduramaz.

UniDAC, DevExpress, TMS, FastReport, JEDI JCL/JVCL ve mORMot2 isteğe bağlıdır.
JEDI ve mORMot2, kullanıcının sürümleri Delphi 13+ ile derlenene kadar
koşullu kabul edilir.

## Başlangıç

Önce `AGENTS.md`, sonra konuya uygun `.agents/rules/` kuralı ve
`.agents/skills/` skill'i okunur. `src/README.md` gerçek proje yapısını
tanımlar — `src/` artık sadece yer tutucu değil, gerçek **Rad Core**
kütüphanesini içeriyor (aşağıya bakın).

## Köken

Bu kit'te iki ayrı soyağacı buluşuyor:

- **AI talimat sistemi**, `rad-template-builder` Derivation Mode v2 ile
  **Delphi Library AI Spec-Kit** (`delphi-library-expert`)
  `b9795465c997ea841a8b319a9931256a7f35bd5c` commit'inden türetildi. Bkz.
  `derivation.json`. MIT lisansı korunmuştur.
- **`src/` altındaki kütüphane kodu**, ayrı bir yerde bakımı sürdürülen
  **Rad Core | Enterprise Delphi Framework** projesinden aktarıldı — bu
  kit'in kendi kurallarının (`help.*` adlandırma, `TRAD` component'leri,
  vendor izolasyonu) aslında modellendiği gerçek proje. Bkz.
  `ACKNOWLEDGMENTS.md`.
