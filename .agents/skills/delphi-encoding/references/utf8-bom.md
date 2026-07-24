# UTF-8 BOM — verification, repair, pitfalls

## Verify: list all `.pas` files missing the BOM

```powershell
$root = "C:\path\to\project"
$excludeDirs = @("\bin\","\dcu\","\Win32\","\Win64\","\__history\","\__recovery\")
Get-ChildItem -Path $root -Recurse -Filter "*.pas" -File | Where-Object {
  $path = $_.FullName + "\"
  $skip = $false
  foreach ($d in $excludeDirs) { if ($path -like "*$d*") { $skip = $true; break } }
  -not $skip
} | ForEach-Object {
  $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
  if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    $_.FullName
  }
}
```

## Repair — mass BOM prepend (validate first!)

⚠️ Adding a BOM to a file that is actually ANSI (Windows-1254 for Turkish)
corrupts its accents. First classify each file:

```powershell
$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
foreach ($f in $files) {
  $bytes = [System.IO.File]::ReadAllBytes($f)
  try { [void]$utf8Strict.GetString($bytes); "$f`tUTF8" }
  catch { "$f`tANSI — önce dönüştür!" }
}
```

Only for files confirmed UTF-8, prepend the BOM:

```powershell
$bom = [byte[]](0xEF, 0xBB, 0xBF)
foreach ($f in $files) {
  $bytes = [System.IO.File]::ReadAllBytes($f)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { continue }
  $newBytes = New-Object byte[] ($bytes.Length + 3)
  [Array]::Copy($bom, 0, $newBytes, 0, 3)
  [Array]::Copy($bytes, 0, $newBytes, 3, $bytes.Length)
  [System.IO.File]::WriteAllBytes($f, $newBytes)
}
```

> ⚠️ `Set-Content -Encoding UTF8` is a trap: PowerShell 5.1 writes WITH
> BOM, PowerShell 7+ writes WITHOUT (breaking change). For portability
> always use `[System.IO.File]::WriteAllBytes` with a manual BOM.

## The AI-write-tool caveat

Observed failure mode: an AI file-write tool creates a new `.pas` as
UTF-8 **without** BOM on Windows — content bytes are correct (`C3 A7`
for `ç`) but the missing `EF BB BF` makes dcc read the file as ANSI →
mojibake at runtime. Two rules:

1. **After creating any new `.pas`/`.dpr`/`.dpk` containing non-ASCII
   text, verify the first 3 bytes** and prepend the BOM if missing
   (script above). Edited files keep their original BOM; only newly
   created ones need the check.
2. If accents arrive as `?` (0x3F) or `�` (U+FFFD `EF BF BD`), the
   characters were destroyed *before* the write — prepending a BOM won't
   help. Rewrite the file composing each special character from its
   Unicode codepoint and writing bytes explicitly:

```powershell
$path = 'path\Unit1.pas'
$g = [char]0x011F  # ğ
$c = [char]0x00E7  # ç
$lines = @(
  'unit Unit1;',
  '...',
  "    LMsg := 'Ge${c}ersiz de${g}er';",
  '...'
)
$text = ($lines -join "`r`n") + "`r`n"

$utf8 = New-Object System.Text.UTF8Encoding($false)   # BOM'suz encoder; BOM'u elle ekliyoruz
$contentBytes = $utf8.GetBytes($text)
$bom = [byte[]](0xEF, 0xBB, 0xBF)
$all = New-Object byte[] ($bom.Length + $contentBytes.Length)
[Array]::Copy($bom, 0, $all, 0, 3)
[Array]::Copy($contentBytes, 0, $all, 3, $contentBytes.Length)
[System.IO.File]::WriteAllBytes($path, $all)
```

Verify after writing: the file must start `239 187 191` (BOM) and line
breaks must be `13 10` (CRLF):

```powershell
Get-Content 'path\Unit1.pas' -Raw | Format-Hex | Select-Object -First 4
```

## Turkish character codepoints

| Char | Codepoint | UTF-8 bytes | | Char | Codepoint | UTF-8 bytes |
|---|---|---|---|---|---|---|
| ç | `0x00E7` | `C3 A7` | | Ç | `0x00C7` | `C3 87` |
| ğ | `0x011F` | `C4 9F` | | Ğ | `0x011E` | `C4 9E` |
| ı | `0x0131` | `C4 B1` | | İ | `0x0130` | `C4 B0` |
| ö | `0x00F6` | `C3 B6` | | Ö | `0x00D6` | `C3 96` |
| ş | `0x015F` | `C5 9F` | | Ş | `0x015E` | `C5 9E` |
| ü | `0x00FC` | `C3 BC` | | Ü | `0x00DC` | `C3 9C` |

## Known pitfalls

- **`__history/` / `__recovery/`:** the IDE can resurrect old (BOM-less)
  versions over your fixed ones on an Object Inspector roundtrip. Keep
  both folders in `.gitignore` and close/reopen the project after a mass
  conversion.
- **`.dfm`:** current Delphi streams text DFMs as UTF-16 LE with BOM —
  do not convert to UTF-8.
- **`.dproj`:** UTF-8 *without* BOM is the MSBuild default — leave it.
- **`W1057 Implicit string cast`** warnings appearing suddenly often
  indicate a file being read as AnsiString source — check its BOM.

> Kaynak: `adrianosantostreina/delphi-dev` (MIT) bilgi tabanındaki
> encoding rehberinden uyarlanmıştır (karakter tablosu Türkçe'ye
> çevrildi) — bkz. ACKNOWLEDGMENTS.
