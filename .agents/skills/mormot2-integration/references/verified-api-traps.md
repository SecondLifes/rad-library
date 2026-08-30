# Verified mORMot2 API traps

Each entry below was found by compiling and running a probe against the
installed mORMot2 source, not by reading documentation. Every one of them
compiles cleanly and fails silently at runtime — that is why they are here.

## `AesPkcs7` does not authenticate, even with `mGcm`

`AesPkcs7(src, encrypt, key, keyBits, mGcm, nil)` looks like authenticated
encryption. It is not. The GCM authentication tag is never stored, so
tampering is not detected.

Measured (Delphi 37.0, Win32): a 54-byte plaintext produced 80 bytes of
ciphertext — 54 padded to 64 by PKCS7, plus a 16-byte IV. There is no room
for a 16-byte tag, and there is none. Flipping one bit in the middle of the
ciphertext returned a *successfully decrypted, silently corrupted* plaintext.

Do not be reassured by a wrong key being rejected: that is PKCS7 padding
validation failing by luck, not authentication.

**Use `TAesGcm.MacAndCrypt` instead.**

```pascal
LAes := TAesGcm.Create(AKey, 256);
try
  // IVAtBeginning=True -> random IV prepended AND the GCM tag appended
  LCipher := LAes.MacAndCrypt(APlain, {Encrypt=}True, {IVAtBeginning=}True);
finally
  LAes.Free;
end;
```

Same plaintext through `MacAndCrypt`: 96 bytes = 64 padded + 16 IV + 16 MAC.
All 96 bytes were flipped one at a time; 92 were rejected. The 4 that were
not are bytes 13-16, the tail of the 16-byte IV field: GCM uses a 96-bit
nonce plus a 32-bit counter that it re-initialises itself, so those 4 bytes
are dead space and flipping them still decrypts to the *correct* plaintext.
No modification that can alter the plaintext goes undetected.

`MacAndCrypt` returns `''` on failure rather than raising — check for it.

## `AesPkcs7`'s password overload reuses the IV

```pascal
AesPkcs7(src, encrypt, password, salt, rounds, aesMode)
```

Reading the implementation: PBKDF2's lower 128 bits become the key and the
**upper 128 bits become the IV**. A fixed password with a fixed salt
therefore encrypts with the same key *and the same IV* every time. With the
default `mCtr` this is keystream reuse: `C1 xor C2 = P1 xor P2`.

That is fatal for anything saved repeatedly — a config file evolves slightly
between saves and is highly structured, so two versions leak most of the
content. Derive the key yourself with a random per-file salt, or use the
key-buffer overload, which generates a random IV per call.

## `TAesGcm` instances carry state

Counter and MAC accumulation live in the instance, so a shared `TAesGcm` is
not thread-safe. Either create one per operation (fine when encryption only
happens on file save/load) or serialise access with a lock.

## Static object files are required for `mormot.crypt.core`

Compiling `mormot.crypt.core` fails with
`E1026 File not found: '..\..\static\delphi\sha512-x86.obj'` unless the
static binaries are present. They are not in the git repository — download
`https://synopse.info/files/mormot2static.7z` and extract into the
repository's own `static/` folder. Checksums are in `static/dev.sha256`.
The framework has pure-pascal fallbacks, but the x86 SHA-512 path is on by
default for Delphi.

## `DocDict` / `DocList` accept invalid JSON silently

`DocDict('{broken json')` does **not** raise. It returns an **empty `dvObject`**,
so `Kind` checks pass and `Count` is 0 — indistinguishable from "the file was
empty". Measured in this kit: `TSmartCache.FileLoad` returned `True` after
loading nothing, three separate ways (malformed text, a UTF-8 BOM the parser
choked on, and `XmlToJson` returning empty).

An independent benchmark reaches the same conclusion from the other side:
`hydrobyte/TestJSON` records mORMot2 accepting 8 of 23 deliberately-malformed
inputs.

Validate before parsing, and check the kind afterwards:

```pascal
if not IsValidJson(LJson) then raise ...;
LDoc.InitJson(LJson, JSON_FAST_FLOAT);   // NOT DocDict() - see next trap
if LDoc.Kind <> dvObject then raise ...;
```

## `DocDict()` erases the real `Kind`

`DocDict('[1,2,3]')` turns an **array** into an empty object, so a
`Kind <> dvObject` guard never fires. `TDocVariantData.InitJson` preserves the
actual kind. Prefer it whenever the kind is part of the contract — it also
avoids an interface allocation.

## `FlattenFromNestedObjects` does not add the promised counter

The documentation says "any name collision will append a counter to make it
unique". Measured: it does not. `{"a":{"b":1},"a.b":2}` flattens to
`{"a.b":1,"a.b":2}` — a **duplicate-key** document. No value is lost, but the
document becomes ambiguous: `Exists` returns True with no way to say which one
was read, and writing it to a keyed table collides. Detect duplicates yourself
after flattening.

Also: the call flattens **one level per invocation**. Loop it
(`while Doc.FlattenFromNestedObjects(...) do`) and cap the loop — termination
is not guaranteed by the documentation. An empty nested object is left as-is
and does not loop forever (measured).

## `AddOrUpdateObject(..., RecursiveUpdate := True)` corrupts the target

Measured with base `{"db":{"host":"eski","port":1}}` merged with
`{"db":{"host":"yeni"}}`:

| Call | Result |
|---|---|
| `MergeObject` | `{"db":{"host":"yeni","port":1}}` — deep, correct |
| `AddOrUpdateObject` | `{"db":{"host":"yeni"}}` — shallow, `port` dropped |
| `AddOrUpdateObject(.., RecursiveUpdate := True)` | `{"db":{"host":null}}` — **`port` dropped AND `host` nulled** |

Use `MergeObject` for a deep merge and plain `AddOrUpdateObject` for a
whole-value replace. Do not use `RecursiveUpdate`.

## `TDocVariantData` is not thread-safe, and `IDocDict` cannot be subclassed

mORMot ships `ILockedDocVariant` (`mormot.core.threads.pas`) precisely because
`TDocVariantData` has no internal locking. That wrapper's own documentation
warns that its `Data: PDocVariantData` accessor "is not thread-safe" — handing
out a pointer to the inner document defeats the lock, so a safe facade must
return copies or scalars.

Subclassing is not an option either: `TDocDict` is declared in the
**implementation** section of `mormot.core.variants.pas` (line ~12048, after
`implementation` at ~3924), so it is invisible outside that unit.
`TDocVariantData` is a `record`, so it cannot be inherited from, and a record
helper cannot add fields (no room for a lock) and would be hidden if mORMot
ever ships its own helper for the type. **Wrapping is the only available
strategy** — this is why `rad.json`'s `TMormot2Json` wraps `IDocDict` rather
than descending from it. (The wrapper lived in its own unit,
`src/vendor/rad.json.mormot2.pas`, until 2026-08-23; it is now the
implementation section of `src/core/rad.json.pas` — same code, same reason, one
less unit for a caller to remember to include.)

**Moving the class to the interface section would not rescue subclassing
either** — measured, not assumed. `TDocDict` declares **zero** `virtual`
methods, so none of `IDocDict`'s 56 methods can be overridden; and node
construction is hardcoded, not dispatched — `TDocDict.GetD` literally does
`result := TDocDict.CreateByRef(...)`, one of 32 such fixed-class constructions
in the unit. A descendant would therefore never be produced for any nested
node. Making the methods virtual on top of that is a fork of a 13,881-line unit
whose modified file stays MPL (`LICENCE.md`: disjunctive MPL 1.1 / GPL 2.0 /
LGPL 2.1), and would still leave `TDocAny.Value: PDocVariantData` handing out
the raw record — the same hole mORMot admits for `ILockedDocVariant.Data`.

## A nested `IDocDict` dangles after **one** insertion into its parent

`GetD`/`GetL` return a node **by reference** into the parent's storage
(`TDocDict.CreateByRef`), and that storage is a dynamic array that reallocates
as it grows. Measured on Delphi 37.0 / Win32, starting from
`{"alt":{"x":7},"z":0}`:

```
child address before : 0001DDF708
after ONE d.I['k1'] := 1
child address after  : 0001DBB5F8      <-- moved on the FIRST insertion
old child reads      : EDocDict "I['x'] key not found"
```

So a held child is valid only until the next structural change to its parent.
mORMot's strict accessors raise `EDocDict`; the lenient
`Get(key, var value): boolean` overloads — the ones a wrapper is otherwise
right to prefer — return `false`, so the same corrupted read arrives disguised
as a legitimate "key not found", and the caller sees `0` or `''`.

Which operations move nodes, measured by comparing `Value^.Values` (storage
base) and `Value^.Count` before and after:

| Operation on the parent | Storage base | Count | Children |
|---|---|---|---|
| add a new key | changes | changes | **invalid** |
| overwrite an existing key's scalar | same | same | still valid |
| delete a key | same | changes | **invalid** |

`Values` and `Count` are public (`property Values: TVariantDynArray read
VValue`); the underlying `VValue`/`VCount` fields are private, so this pair is
the only observable signal — and it is exact. `rad.json` uses it: every node
records its parent's storage base and count at birth and re-checks them, up the
whole ancestor chain, on every access (`IJsonNode.IsStale`, `EJsonStale`).
That converts a silent use-after-free into a deterministic error. Regression:
`rad_jsoncontract` 55–76.

## `mormot.core.base` shadows RTL `LowerCase`, `Pos` and `Trim`

Any unit that `uses mormot.core.base` — directly or through
`mormot.core.variants`, `mormot.core.json`, and most of the rest of mORMot —
picks up `RawUtf8` overloads of routines the RTL already provides. Unqualified
calls on `string` arguments then resolve to the mORMot overload, and the
compiler inserts a UTF-8 round trip on every call:

```
k.setting.pas(459) Warning: W1057 Implicit string cast from 'string' to 'UTF8String'
k.setting.pas(1128) Warning: W1057 Implicit string cast from 'UTF8String' to 'string'
```

Measured while building `k.setting.pas`: seven of these appeared across
`LowerCase`, `Pos` and `Trim` in a unit that never mentions `RawUtf8`. Every
one is a real encode + decode per call, and a search box calls them once per
row per keystroke.

It is only a **warning**, so a build configured to hide W1057 — or a reviewer
skimming past it — ships the round trip silently. Nothing is functionally
wrong, which is exactly why it survives.

Qualify explicitly in any unit that mixes RTL strings with mORMot:

```pascal
System.SysUtils.LowerCase(S)
System.SysUtils.Trim(S)
System.Pos(ASub, S)
```

Same class of problem, different symptom: a bare `'{}'` literal passed to
`DocDict()` also casts implicitly. Write `DocDict(RawUtf8('{}'))`.

Do not "fix" this by declaring local wrappers named `LowerCase`/`Trim` — that
reproduces the shadowing one level down. Qualify at the call site so the next
reader can see which unit's routine actually runs.

## `IDocDict.PathDelim` defaults to `#0` — nested paths do nothing until it is set

`IDocDict` supports dotted-path access, but **not by default**. mORMot's own
declaration (`mormot.core.variants.pas`) says `PathDelim` "equals #0 by
default, meaning only root object keys are located", and that with `'.'` set,
`dict.U['child2.name']` matches `dict.D['child2'].U['name']` — creating the
sub-object hierarchy on write if it is missing.

Measured both ways:

```pascal
LDoc := DocDict('{}');
LDoc.I['a.b.c'] := 7;
// PathDelim not set  ->  {"a.b.c":7}          one flat key, no tree
// LDoc.PathDelim := '.'  ->  {"a":{"b":{"c":7}}}
```

The flat form is not an error and raises nothing. Code that writes settings by
dotted key and later expects to read a subtree — or hands the JSON to something
that walks it — gets an empty walk and no diagnostic. If a document is meant to
be a tree, set `PathDelim` at construction, next to the `DocDict()` call, and
say why in a comment.

Note that `rad.config`'s `TRadConfig` does **not** set it, so its keys are flat
today. That is a separate question from this trap; do not "fix" it without
checking what already reads those files.
