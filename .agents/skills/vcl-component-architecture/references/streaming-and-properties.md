# Streaming & Published Properties — DFM Compatibility

## Published property design

The `published` section is the component's public *design-time* contract:
everything there appears in the Object Inspector and is streamed to the
DFM. Keep it small and deliberate.

Rules:

- Ordinal/enum/set properties: give a `default` directive AND assign the
  same value in the constructor — the two must agree, or the DFM will
  either bloat (value always streamed) or silently lose the value
  (streamed skipped but constructor sets something else).
- String/float/int64 properties have no `default` directive support for
  skipping — use `stored` functions when streaming should be conditional.
- Boolean feature switches default to the safe/off value.
- Never publish a property whose setter has side effects that are unsafe
  at design time without a `csDesigning` guard (see lifecycle doc).

```pascal
published
  property Interval: Integer read FInterval write SetInterval default 1000;
  property Active: Boolean read FActive write SetActive default False;
  //Koşullu streaming: yalnızca varsayılan dosya adından farklıysa yaz
  property FileName: string read FFileName write FFileName stored IsFileNameStored;
```

## TPersistent sub-properties

A structured property (margins, font-like settings, options group) is a
`TPersistent` descendant exposed as an object property. Contract:

```pascal
TWatcherOptions = class(TPersistent)
private
  FRecursive: Boolean;
  FPattern: string;
public
  procedure Assign(Source: TPersistent); override;   //ZORUNLU
published
  property Recursive: Boolean read FRecursive write FRecursive default False;
  property Pattern: string read FPattern write FPattern;
end;

//Bileşen tarafı: setter HER ZAMAN Assign çağırır, referans ataması yapmaz
procedure TFolderWatcher.SetOptions(const AValue: TWatcherOptions);
begin
  FOptions.Assign(AValue);
end;
```

- Create the sub-object in the component constructor, free in destructor.
- `Assign` copies every field; forgetting a newly added field in `Assign`
  is a classic regression — update `Assign` in the same commit that adds
  the field.
- If changes must repaint/re-configure the owner, give the sub-object an
  `OnChange: TNotifyEvent` (or `TPersistent.DefineProperties`-style owner
  backlink) rather than letting the owner poll.

## Collections

Use `TOwnedCollection` so collection items get the component as owner
path (correct DFM nesting and Object Inspector behavior):

```pascal
TColumnItem = class(TCollectionItem)
published
  property Caption: string read FCaption write SetCaption;
end;

TColumns = class(TOwnedCollection)
  //ItemClass = TColumnItem; ekleme/silme API'si burada
end;
```

## Events

- Event properties are published method-pointer properties named `On*`.
- Fire through a protected virtual `DoXxx` method — descendants override
  behavior without re-implementing the trigger logic:

```pascal
protected
  procedure DoFileChanged(const AFileName: string); virtual;
published
  property OnFileChanged: TFileChangedEvent read FOnFileChanged write FOnFileChanged;

procedure TFolderWatcher.DoFileChanged(const AFileName: string);
begin
  if Assigned(FOnFileChanged) then
    FOnFileChanged(Self, AFileName);
end;
```

## DefineProperties — data outside the published contract

For binary blobs or legacy property names, override `DefineProperties`:

```pascal
procedure TMyComponent.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  //Eski DFM'lerdeki kaldırılmış özelliği oku-ve-yok-say (geriye uyumluluk)
  Filer.DefineProperty('LegacyMode', ReadLegacyMode, nil, False);
end;
```

## DFM backward compatibility — the versioning contract

A published property is a serialization format. Across library versions:

- **Adding** a property with a correct `default` is safe (old DFMs simply
  don't mention it).
- **Removing or renaming** a published property breaks every existing DFM
  ("Property does not exist" at load). Removal requires a deprecation
  cycle: keep accepting the old name via `DefineProperty` read-and-discard
  (or read-and-map) for at least one major version, and document it in
  the CHANGELOG as a breaking-risk change.
- **Changing a type or enum member order** breaks streamed values —
  enum values stream by name, but removing a name breaks old DFMs the
  same way.

## Checklist — streaming review

- [ ] `default` directive ↔ constructor value agreement for every ordinal property?
- [ ] `TPersistent` props: setter uses `Assign`; `Assign` covers ALL fields?
- [ ] Collections descend from `TOwnedCollection`?
- [ ] Events fired via protected virtual `DoXxx`?
- [ ] No published property removed/renamed without a `DefineProperty` compatibility shim + CHANGELOG entry?
