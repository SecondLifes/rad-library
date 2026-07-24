# Numeric conversion and the locale decimal separator

`StrToFloat`, `StrToCurr`, `StrToFloatDef`, `StrToCurrDef` (and the
`Try...` variants) use the **system locale's decimal separator** by
default. In Turkish locale the decimal separator is a **comma** (`,`)
and the thousands separator is a dot (`.`) — the exact opposite of the
invariant/English format.

## The silent bug

```pascal
//❌ YANLIŞ — Türkçe locale'de sessizce sıfır döner
LText := Edit1.Text.Replace(',', '.');   // "37,55" -> "37.55"
Result := StrToCurrDef(LText, 0);        // '.' BINLIK ayracı sanılır
                                          // -> dönüşüm başarısız -> 0 (default)
```

The default value (0) masks the failure: no exception, the value just
"disappears". Typical symptom: a "value required" validation firing even
though the field is filled.

## The correct pattern

Parse the string **in the format it actually has**, with an explicit
`TFormatSettings` — never depend on the machine's regional settings:

```pascal
var
  LFormat: TFormatSettings;
begin
  LFormat := TFormatSettings.Create;
  LFormat.DecimalSeparator  := ',';   { UI'da gösterilen Türkçe format }
  LFormat.ThousandSeparator := '.';
  Result := StrToCurrDef(Edit1.Text, 0, LFormat);
end;
```

Rule: the `TFormatSettings` must describe the **input string's** format,
not the desired output. If the UI shows `37,55`, parse with decimal `,`.

## Machine-facing formats: use Invariant

For JSON, SQL literals, config files, CSV interchange — anything a
program (not a human) will read — always format and parse with
`TFormatSettings.Invariant` (dot decimal, no thousands separator):

```pascal
LJsonValue := FloatToStr(LAmount, TFormatSettings.Invariant);  // "37.55"
LAmount := StrToFloat(LJsonText, TFormatSettings.Invariant);
```

The reverse direction (`FloatToStr`/`FormatFloat` for UI display) equally
takes an explicit `TFormatSettings` — otherwise output changes per
machine locale.

`TFormatSettings` lives in `System.SysUtils`; the overloads accepting it
exist since Delphi XE.

> Kaynak: `adrianosantostreina/delphi-dev` (MIT) bilgi tabanından
> uyarlanmıştır (örnekler Türkçe locale'e çevrildi) — bkz.
> ACKNOWLEDGMENTS.
