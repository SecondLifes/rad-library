# Specification: `rad.sqlfilter` — akıcı SQL filtre üretici

## Bağlam

Liste ekranlarında WHERE ve ORDER BY parçaları elle birleştiriliyor; değerler
metne gömülüyor, boş alan için `if` zinciri yazılıyor, `LIKE` jokerleri
kaçırılmıyor. Beş açık kaynak Delphi ORM/builder incelendi (dext, Trysil,
mORMot2, CQLBr, DelphiMVCFramework); hiçbiri "boş değer → koşul yok"
davranışını vermiyor, çoğu `IN ()` üretiyor ve `LIKE` kaçışı yapmıyor.
`src/core/rad.filtre.pas` ekran modeli olarak kalıyor; bu birim ondan
bağımsız, kod odaklı bir builder.

## İşlevsel gereksinimler

### Kullanım

```pascal
LF := TRadSqlFilter.New(sdPostgreSQL)            // varsayılan: sdPostgreSQL, rfmSkipEmpty
  .Wildcards('*', '?')                          // filtre geneli joker karakterleri
  .CaseSensitive(False)                         // filtre geneli duyarsız (VARSAYILAN düz işleçtir)
  .Equal('tip', cmbTip.EditValue)               // boşsa koşul yok
  .Like('telefon', '*5595')                     // kaçış açık
  .Like('telefon', '%5595', False)              // kaçış kapalı, desen olduğu gibi
  .Contains('kod', edtKod.Text, rcSensitive)    // bu çağrıda harf duyarlı
  .Between('tarih', D1, D2)
  .InList('sube', ['01', '02'])
  .BeginOr.Equal('a', 1).Equal('b', 2).EndOr
  .AddOrderBy('adi', True).AddOrderBy('soyad');

LQuery.SQL.Text := 'select * from cari ' + LF.GetWhere + ' ' + LF.GetOrderBy;
LQuery._ApplyFilter(LF);                          // Help.uni: parametreleri yazar
```

Her koşul yöntemi `IRadSqlFilter` döndürür. Nesne `TInterfacedObject`;
`try..finally` yok, sınıf değişkeniyle tutulmaz.

### API

| Grup | Üye | Not |
|---|---|---|
| Ayar | `Dialect(sd)`, `Mode(rfm)`, `Wildcards(AMany, AOne)`, `CaseMode(rc)`, `CaseSensitive(Boolean)`, `ParamPrefix(s)`, `WholeDay(Boolean)` | ayarlar `Clear` ile silinmez |
| Koşul | `Equal`, `NotEqual`, `Greater`, `GreaterEqual`, `Less`, `LessEqual` | `(AField, AValue[, ACase])`; `ACase` yalnız `Equal`/`NotEqual` metin değerde |
| Koşul | `Like`, `NotLike` | `(AField, APattern, AEscape = True, ACase = rcDefault)` |
| Koşul | `Contains`, `NotContains`, `StartsWith`, `EndsWith` | `(AField, AText, ACase = rcDefault)`; metin her zaman düz |
| Koşul | `InList`, `NotInList` | `(AField, array of Variant)`; Null öğeler atılır |
| Koşul | `Between`, `NotBetween` | `(AField, AFrom, ATo)`; tek taraf boşsa `>=` / `<=` (`NotBetween`: `<` / `>`) |
| Koşul | `IsNull`, `IsNotNull` | her modda yazılır |
| Koşul | `Raw(ASql, array of Variant)` | güvenilen SQL parçası; `?` → `:pN` |
| Grup | `BeginOr` … `EndOr` | tek seviye; iç içe → hata |
| Sıra | `AddOrderBy(AField, ADesc = False)` | eklenir; alan adı `^[A-Za-z_][A-Za-z0-9_.]*$` değilse hata |
| Çıktı | `GetWhere` | `WHERE …` ya da `''` |
| Çıktı | `GetConditions` | `WHERE` öneksiz |
| Çıktı | `GetOrderBy` | `ORDER BY adi DESC, soyad ASC` ya da `''` |
| Çıktı | `GetSql` | `GetWhere + ' ' + GetOrderBy`, kırpılmış |
| Çıktı | `GetDebugSql` | değerler metne gömülü; yalnız log/hata ayıklama, çalıştırılmaz |
| Çıktı | `Params`, `ParamCount`, `IsEmpty` | `TArray<TRadSqlParam>` (`Name`, `Value`), ad `:`'siz |
| Temizlik | `Clear`, `ClearConditions`, `ClearOrderBy` | sayaç sıfırlanır, ayarlar kalır |

Tipler: `TRadSqlDialect = (sdPostgreSQL, sdMSSQL, sdMySQL, sdFirebird)`,
`TRadFilterMode = (rfmSkipEmpty, rfmStrict)`,
`TRadCase = (rcDefault, rcDatabase, rcSensitive, rcInsensitive)`,
**Varsayılan harf modu `rcDatabase`** (düz işleç, `lower/UPPER/ILIKE` yok; indeks kullanılır).
Duyarsızlık yalnız `CaseSensitive(False)`/`CaseMode(rcInsensitive)` ya da çağrı başına `rcInsensitive` ile açılır.
`ERadSqlFilter = class(Exception)`.

### Kabul ölçütleri (EARS)

1. **WHEN** herhangi bir koşul değer alır **THE SYSTEM SHALL** değeri
   `:p1`, `:p2` … adlı parametre olarak saklar; SQL metnine hiçbir değer
   yazılmaz. Sayaç filtre genelinde ortaktır, `ParamPrefix` ile değişir.
2. **WHEN** mod `rfmSkipEmpty` ve değer boş (`Null`, `Unassigned`, boş
   metin, boş dizi, yalnız çok-karakter jokerinden oluşan desen) **THE
   SYSTEM SHALL** koşulu üretmez. `0`, `False` boş değildir.
3. **WHEN** mod `rfmStrict` ve `Eq`/`Like`/`Contains`/`Between` boş değer
   alır **THE SYSTEM SHALL** `ERadSqlFilter` fırlatır; boş `InList` →
   `1=0`, boş `NotInList` → `1=1`.
4. **WHEN** `Like` `AEscape=True` **THE SYSTEM SHALL** kullanıcı
   jokerlerini `%`/`_`'ye çevirir, desendeki diğer `%`, `_`, `!` (MSSQL'de
   `[` dahil) karakterlerini `!` ile kaçırır ve `ESCAPE '!'` ekler.
   Joker karakter iki kez yazılmışsa düz karakterdir.
5. **WHEN** `Like` `AEscape=False` **THE SYSTEM SHALL** yalnız joker
   çevirisi yapar; `ESCAPE` yazmaz, çift yazım kuralı uygulanmaz.
6. **WHEN** `Contains`/`StartsWith`/`EndsWith` **THE SYSTEM SHALL** metni
   tamamen kaçırır ve uygun `%` ekler.
7. **WHEN** etkin harf modu `rcInsensitive` **THE SYSTEM SHALL**
   PostgreSQL'de `ILIKE` / `lower(f) = lower(:p)`, diğer üç lehçede
   `UPPER(f) LIKE UPPER(:p)` / `UPPER(f) = UPPER(:p)` üretir.
   `rcSensitive` ve `rcDatabase` düz işleç üretir (MSSQL/MySQL'de harf
   duyarlılığı collation'a kalır; belgelenir).
   **Hiçbir mod verilmezse** (`rcDefault` ve filtre ayarı da varsayılan) etkin mod `rcDatabase`'dir:
   düz işleç. (2026-10-31 öncesi varsayılan `rcInsensitive` idi; `uuid` gibi metin değerlere de
   `lower()` sarıp indeksi devre dışı bıraktığı için kaldırıldı.)
8. **WHEN** `BeginOr`…`EndOr` arasında ≥2 koşul kalır **THE SYSTEM SHALL**
   `(a OR b)` üretir; 1 kalırsa tek koşul, 0 kalırsa hiçbir şey. Her koşul
   kendi parantezinde.
9. **WHEN** `GetWhere` çağrılır ve koşul yoksa **THE SYSTEM SHALL** boş
   metin döndürür.
10. **WHEN** `AddOrderBy` birden çok kez çağrılır **THE SYSTEM SHALL**
    sırayı korur ve virgülle birleştirir.
11. **WHEN** `Clear` **THE SYSTEM SHALL** koşulları, parametreleri, sırayı
    ve açık OR grubunu siler; `Dialect`, `Mode`, `Wildcards`, `CaseMode`,
    `ParamPrefix` korunur.
12. **WHEN** `Raw` içindeki `?` sayısı dizi uzunluğuna eşit değil **THE
    SYSTEM SHALL** hata fırlatır.
13. **WHEN** `WholeDay` açık (varsayılan) ve değer saatsiz tarih (`varDate`,
    kesir 0) **THE SYSTEM SHALL** günü yarı açık aralık sayar:
    `Equal` → `f >= gün AND f < gün+1`, `NotEqual` → tersi, `Greater` →
    `f >= gün+1`, `LessEqual` → `f < gün+1`, `GreaterEqual`/`Less` değişmez,
    `Between(a, b)` → `f >= a AND f < b+1`. Saatli değer, `InList` ve `Raw`
    etkilenmez. (23:59:59 yerine yarı açık aralık: salise/`datetime2`
    hassasiyetinden bağımsız.)

## İşlevsel olmayan gereksinimler

- **Bağımlılık:** çekirdek yalnız RTL (`System.SysUtils`, `Classes`,
  `Variants`, `Generics.Collections`). UniDAC uygulaması `Help.uni.pas`'ta
  (`TUniQuery._ApplyFilter`, `TUniConnection._SqlDialect`).
- **Platform:** Delphi 13, Win32 + Win64.
- **Doğrulama:** çekirdek testleri bağlantısız; canlı testler PostgreSQL 18
  (`testdb`), SQL Server (`rad_filter_test`, `Turkish_CI_AS`), Firebird 5
  (`C:\Users\Public\rad-test\rad_filter_test.fdb`). MySQL kurulu değil →
  lehçe belgeye göre yazılır, "doğrulanmadı" diye işaretlenir.

## İş kuralları

1. Alan adı/ifadesi (`AField`) koddan gelir, doğrulanmaz; yalnız boş olamaz.
2. `AddOrderBy` alan adı deseni dışındaysa hata: ORDER BY parametre alamaz.
3. `Eq(f, Null)` `IS NULL`'a çevrilmez; `IsNull` açıkça çağrılır.
4. `InList` harf modundan etkilenmez (tam eşleşme).
5. Kaçış karakteri `!`: PostgreSQL `standard_conforming_strings`'e,
   MySQL ters bölü kaçışına bağımlı olmamak için. (PostgreSQL 9.7.1,
   MSSQL `LIKE` belgesi `ESCAPE '!'` örneği, Firebird `BoolNodes.cpp`:
   `ESCAPE` yalnız `LIKE`/`SIMILAR`.)

## Ölçümler (canlı, 2026-10-31)

| Durum | PostgreSQL 18 (`testdb`) | SQL Server 2025 (`Turkish_CI_AS`) | Firebird 5.0.4 (UTF8) |
|---|---|---|---|
| Canlı doğrulamalar | 42/42 (Win32+Win64) | 40/40 (Win32+Win64) | 42/42 (Win32) |
| Çekirdek (`SqlFilterTest`, bağlantısız) | 138/138 Win32+Win64 (varsayılan `rcDatabase`) | | |
| `rcSensitive` `Eq('ad','ELA')` ('Ela' satırı) | 0 (duyarlı) | 1 (collation CI, düz işleç) | 0 (duyarlı) |
| `Contains('ad','şenay')` duyarsız, 'ŞENAY' | 1 | 1 | 1 |
| `Contains('ad','ismail')` duyarsız, 'İsmail' | **0** (`lower('İ')` ≠ `'i'`) | 1 | **0** (`UPPER('i')` ≠ `'İ'`) |
| `StartsWith('ad','ı')` | 0 | 0 | 0 |

Firebird Win64: makinede 64-bit `fbclient.dll` yok, çalıştırılmadı. MySQL: kurulu değil.

## Kapsam dışı

- Sayfalama (`LIMIT`/`OFFSET`/`FETCH`): lehçe farkı büyük, sonra.
- İç içe OR/AND grupları, `NOT` grubu.
- `rad.filtre.pas`'ın bu çekirdeğe yönlendirilmesi: ayrı iş (TODO).
- `= ANY(:dizi)` ile büyük `IN` listesi.
