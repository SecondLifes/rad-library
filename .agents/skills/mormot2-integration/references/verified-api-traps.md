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
