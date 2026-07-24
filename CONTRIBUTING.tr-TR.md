# RAD Library AI Spec-Kit'e Katkıda Bulunma

Öncelikle katkıda bulunmayı düşündüğünüz için teşekkürler! Bu kiti herkes için daha iyi hale getirenler sizin gibi insanlar.

Bu projeye katılarak [Davranış Kuralları](CODE_OF_CONDUCT.md)'na uymayı kabul etmiş olursunuz.

## Nasıl Katkıda Bulunabilirim?

### Hata Bildirme

* Hatanın daha önce bildirilip bildirilmediğini görmek için [issue tracker](https://github.com/SecondLife/rad-library/issues)'a bakın.
* Bildirilmemişse yeni bir issue açın. Sorunu net şekilde tanımlayın ve tekrar üretme adımlarını ekleyin.

### İyileştirme Önerme

* `enhancement` etiketiyle bir issue açın.
* Bunun kitin çoğu kullanıcısı için neden faydalı olacağını açıklayın.

### Pull Request'ler

1. Depoyu fork'layın.
2. Özelliğiniz veya hata düzeltmeniz için yeni bir branch oluşturun.
3. Değişikliklerinizi uygulayın.
4. `AGENTS.md` ve `.agents/rules/*.md`'deki kurallara uyun (projenin geri kalanıyla tutarlı olacak şekilde).
5. Değişikliğinizi gerçekten derleyip çalıştırarak doğrulayın — bir unit, sadece okuyarak değil, derlenip davranışı kontrol edilerek doğru sayılır (bkz. `AGENTS.md`'nin Identity bölümü).
6. `main` branch'ini hedefleyen bir Pull Request gönderin.

## Teknik Standartlar

Bu kitin kendi kuralları katkılar için teknik standarttır — aynı kuralların
iki kopyası arasında sapma olmaması için burada tekrarlanmıyor.
Delphi'nin isimlendirme, hata yönetimi ve mimari kuralları için
`AGENTS.md`'nin "Naming Conventions", "SOLID principles", "Clean Code" ve
"Memory Management" bölümlerine bakın.

Var olan bir şeyi düzeltmek yerine yeni bir yetenek eklemek için:

1. **Kural** → `.agents/rules/konunuz.md`, ardından `.claude/rules/` ve `.cursor/rules/`'u yeniden üretmek için `pwsh tools/generate-ai-configs.ps1` çalıştırın — bu iki klasörü doğrudan elle düzenlemeyin, değişikliğiniz bir sonraki çalıştırmada üzerine yazılır.
2. **Skill** → `.agents/skills/framework-adiniz/SKILL.md` (tek kopya, her destekli araç tarafından doğrudan okunur — çoğaltılacak içerik yok, ama Claude Code'un eşleşen `/framework-adiniz` komut sarmalayıcısını da alması için sonrasında `pwsh tools/generate-ai-configs.ps1` çalıştırın).
3. **Referans** → `AGENTS.md`'de (framework/veritabanına özgüyse mevcut girdilerle tutarlı şekilde `.gemini/rules/project-rules.md`'de de) ve `docs/proje-haritasi.md`'de bahsedin.

### Test Etme

* Bu kitin kendine ait otomatik bir test paketi yok — doğrulama, bir kural/skill'in ürettiği Object Pascal kodunu gerçek bir RAD Studio/Delphi kurulumunda fiilen derleyip çalıştırmak anlamına gelir; sadece okuyarak doğru ilan etmek değil.

## İletişim

* Hata, soru ve öneriler için [issue tracker](https://github.com/SecondLife/rad-library/issues)'ı kullanın.
* Tüm katkıda bulunanlara ve yöneticilere saygı gösterin — bkz. [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Köken

Bu kit [delphicleancode/delphi-spec-kit](https://github.com/delphicleancode/delphi-spec-kit)'in bir fork'u olarak başladı ve o zamandan beri bağımsız olarak genişletildi. Orijinal projenin MIT lisansını ve telif hakkı bildirimini koruyor (bkz. [LICENSE](LICENSE)) — bir katkıda önce tartışmadan lisansı veya telif hakkı sahibini değiştirmeyin.
