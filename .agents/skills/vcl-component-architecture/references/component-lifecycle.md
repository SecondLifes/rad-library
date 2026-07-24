# Component Lifecycle — Ownership, Notification, State

## Ownership model

`TComponent.Create(AOwner)` registers the new component in `AOwner`'s
`Components` list; the Owner frees every owned component in its own
destructor. Consequences:

- A component dropped on a form at design time is owned by the form —
  never call `Free` on it manually.
- A component created at runtime with `Create(Self)` (form as owner) is
  freed with the form; with `Create(nil)` YOU own it and must
  `try..finally Free` it like any object.
- Internal sub-**components** (e.g. an inner timer) are created with
  `Self` as owner **and** marked `SetSubComponent(True)` if they should be
  visible to the Object Inspector as part of the parent; otherwise create
  them with `nil` owner and free them in the destructor explicitly —
  pick one strategy per sub-object, never both.

```pascal
constructor TFolderWatcher.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  //Sahibi biziz: destructor'da serbest bırakılacak (Owner=nil)
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.OnTimer := HandleTimer;
end;

destructor TFolderWatcher.Destroy;
begin
  FTimer.Free;
  inherited Destroy;   //inherited HER ZAMAN en son
end;
```

Rules:

- Constructor: call `inherited Create(AOwner)` FIRST, then initialize —
  and set every field that backs a `default`-directive property to that
  same default value.
- Destructor: free own resources FIRST, call `inherited Destroy` LAST.
- Never raise out of a destructor.

## Cross-component references — Notification / FreeNotification

Any field referencing a component you don't own (a linked `TDataSource`,
an attached label, a partner component) becomes a dangling pointer when
that component is freed elsewhere. The VCL contract for this:

```pascal
procedure TMyComponent.SetDataSource(const AValue: TDataSource);
begin
  if FDataSource = AValue then
    Exit;
  if Assigned(FDataSource) then
    FDataSource.RemoveFreeNotification(Self);
  FDataSource := AValue;
  if Assigned(FDataSource) then
    FDataSource.FreeNotification(Self);   //haber ver: silinirsen bileyim
end;

procedure TMyComponent.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FDataSource) then
    FDataSource := nil;                   //asılı pointer'ı temizle
end;
```

Checklist: **every** component-typed field/property needs this pair.
Omitting it works fine until the user deletes the linked component at
design time and the IDE crashes on a stale pointer — the classic
hard-to-reproduce component bug.

## ComponentState guards

| Flag | True when | Typical guard |
|---|---|---|
| `csDesigning` | Instance lives in the IDE designer | Skip real work (timers, connections, threads): `if csDesigning in ComponentState then Exit;` |
| `csLoading` | DFM streaming in progress | Defer side effects of property setters until `Loaded` |
| `csDestroying` | Owner destruction started | Skip notifications/UI updates during teardown |

`Loaded` override — the correct place for work that needs *all* streamed
properties present:

```pascal
procedure TMyComponent.Loaded;
begin
  inherited Loaded;
  //Tüm DFM özellikleri artık yüklü — bağımlı başlatma burada yapılır
  if FActive then
    OpenConnection;
end;
```

A property setter that immediately acts (`SetActive` → connect) must
distinguish streaming from user action:

```pascal
procedure TMyComponent.SetActive(AValue: Boolean);
begin
  if FActive = AValue then
    Exit;
  FActive := AValue;
  if csLoading in ComponentState then
    Exit;              //Loaded devreye girecek
  if csDesigning in ComponentState then
    Exit;              //tasarım zamanında gerçek bağlantı açılmaz
  if FActive then
    OpenConnection
  else
    CloseConnection;
end;
```

## Threading inside components

- The component's public API is main-thread-only unless documented
  otherwise.
- A component running background work owns its thread(s): create in
  `Create`/on demand, signal-and-wait terminate in `Destroy` **before**
  `inherited`.
- Every event fired from a worker thread goes through `TThread.Queue`
  (preferred) or `TThread.Synchronize`; document which one and why.
- Never fire events during `csDestroying`.

## Checklist — lifecycle review

- [ ] `inherited Create` first / `inherited Destroy` last?
- [ ] Every owned sub-object freed exactly once (Owner OR destructor, not both)?
- [ ] Every component-typed field: `FreeNotification` + `Notification` nil-out?
- [ ] `csDesigning` guard on every real-world side effect?
- [ ] `csLoading` deferred via `Loaded`?
- [ ] Worker threads terminated in destructor before `inherited`?
