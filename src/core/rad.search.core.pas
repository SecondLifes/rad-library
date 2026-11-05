unit rad.search.core;

{ Arama motoru: kaynaklar (IRadSearchProvider), kullanım sayaçları ve sıralama.
  Yalnız RTL (+ rad.desktop.commands, komut kaynağı için). Arayüz rad.search.popup'tadır. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  rad.search.match,
  rad.desktop.commands;

type
  TRadSearchHit = record
    /// <summary>Sonucu üreten kaynağın anahtarı.</summary>
    Provider: string;
    /// <summary>Kaynak içindeki kimlik; kaynak Execute'ta bunu bekler.</summary>
    Id: string;
    Caption: string;
    /// <summary>Gösterilecek yol ('Finans Yönetimi → Tanımlar').</summary>
    Path: string;
    ImageIndex: Integer;
    Score: Integer;
    UseCount: Integer;
    /// <summary>Kullanım sayacının anahtarı: kaynak + '|' + kimlik.</summary>
    function UsageKey: string;
  end;

  TRadSearchHits = TArray<TRadSearchHit>;

  TRadSearchUsageItem = record
    Id: string;
    Count: Integer;
  end;

  TRadSearchUsageItems = TArray<TRadSearchUsageItem>;

  /// <summary>Bir arama kaynağı: menü komutları, cari, stok... Kaynak kendi yetki filtresini uygular.</summary>
  IRadSearchProvider = interface
    ['{4C1E8B27-6F3A-4D59-B2E0-8A7D1C5F3E94}']
    /// <summary>Tekil anahtar ('menu', 'cari').</summary>
    function Key: string;
    /// <summary>Sonuç listesindeki grup başlığı.</summary>
    function Caption: string;
    /// <summary>AQuery katlanmıştır (TRadSearchMatch.Fold). En çok AMax sonuç ekler, Score dolu.</summary>
    procedure Search(const AQuery: string; AMax: Integer; AHits: TList<TRadSearchHit>);
    /// <summary>Sık kullanılanlar için tek kaydı çözer; yetkisi kalkmış ya da silinmiş kayıtta False.</summary>
    function Find(const AId: string; out AHit: TRadSearchHit): Boolean;
    function Execute(const AId: string): Boolean;
    /// <summary>Önbelleği bırakır; menü, yetki ya da şirket değişince çağrılır.</summary>
    procedure Invalidate;
  end;

  /// <summary>Kullanıcının komut başına çalıştırma sayıları. Saklama çağırana aittir (OnChange).</summary>
  TRadSearchUsage = class
  private
    FCounts: TDictionary<string, Integer>;
    FOnChange: TNotifyEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AKey: string);
    function Count(const AKey: string): Integer;
    /// <summary>En çok kullanılan anahtarlar, çoktan aza.</summary>
    function Top(AMax: Integer): TArray<string>;
    function Items: TRadSearchUsageItems;
    procedure Assign(const AItems: TRadSearchUsageItems);
    procedure Clear;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  /// <summary>TRadDeskCommands üzerinden komut kaynağı (menü ve eylemler). Dizin ilk aramada bir kez kurulur.</summary>
  TRadSearchCommandProvider = class(TInterfacedObject, IRadSearchProvider)
  private
    type
      TEntry = record
        Info: TRadDeskCommandInfo;
        Key: TRadSearchKey;
      end;
  private
    FCommands: TRadDeskCommands;
    FKey: string;
    FCaption: string;
    FEntries: TArray<TEntry>;
    FBuilt: Boolean;
    procedure Build;
    function HitOf(const AInfo: TRadDeskCommandInfo; AScore: Integer): TRadSearchHit;
  public
    /// <summary>ACommands sahiplenilmez; kaynaktan önce yaşamalıdır.</summary>
    constructor Create(ACommands: TRadDeskCommands; const AKey, ACaption: string);
    function Key: string;
    function Caption: string;
    procedure Search(const AQuery: string; AMax: Integer; AHits: TList<TRadSearchHit>);
    function Find(const AId: string; out AHit: TRadSearchHit): Boolean;
    function Execute(const AId: string): Boolean;
    procedure Invalidate;
  end;

  TRadSearchEngine = class
  private
    FProviders: TList<IRadSearchProvider>;
    FUsage: TRadSearchUsage;
    FMaxPerProvider: Integer;
    FCountOnExecute: Boolean;
    function ProviderOf(const AKey: string): IRadSearchProvider;
    function ProviderIndex(const AKey: string): Integer;
    procedure Sort(AHits: TList<TRadSearchHit>);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Aynı anahtarlı kaynağın yerine geçer. Sonuçlar eklenme sırasındaki gruplarla gelir.</summary>
    procedure Add(const AProvider: IRadSearchProvider);
    procedure Remove(const AKey: string);
    procedure Clear;
    /// <summary>Kaynak sırasına, sonra puana, kullanım sayısına ve başlık uzunluğuna göre sıralı sonuçlar.</summary>
    function Search(const AText: string): TRadSearchHits;
    /// <summary>En çok kullanılan, hâlâ çözülebilen kayıtlar.</summary>
    function Frequent(AMax: Integer): TRadSearchHits;
    /// <summary>Kaynağa çalıştırtır ve başarılıysa kullanım sayacını artırır.</summary>
    function Execute(const AHit: TRadSearchHit): Boolean;
    procedure Invalidate;
    /// <summary>Kaynağın grup başlığı; kaynak yoksa boş.</summary>
    function CaptionOf(const AProviderKey: string): string;
    property Usage: TRadSearchUsage read FUsage;
    property MaxPerProvider: Integer read FMaxPerProvider write FMaxPerProvider;
    /// <summary>False: sayacı uygulama kendisi artırır (ör. Application.OnActionExecute ile her yoldan
    /// çalıştırmayı sayar); o zaman aramadan çalıştırma iki kez sayılmaz.</summary>
    property CountOnExecute: Boolean read FCountOnExecute write FCountOnExecute;
  end;

const
  /// <summary>Yol parçaları arasındaki ayırıcı.</summary>
  RAD_SEARCH_PATH_SEPARATOR = ' → ';

implementation

uses
  System.Generics.Defaults;

const
  // rad.desktop.sources'ın menü yolu ayırıcısı (' › '); burada okunur bir oka çevrilir.
  DESK_PATH_SEPARATOR = ' ' + #$203A + ' ';

{ TRadSearchHit }

function TRadSearchHit.UsageKey: string;
begin
  Result := Provider + '|' + Id;
end;

{ TRadSearchUsage }

constructor TRadSearchUsage.Create;
begin
  inherited Create;
  FCounts := TDictionary<string, Integer>.Create;
end;

destructor TRadSearchUsage.Destroy;
begin
  FCounts.Free;
  inherited Destroy;
end;

procedure TRadSearchUsage.Add(const AKey: string);
begin
  FCounts.AddOrSetValue(AKey, Count(AKey) + 1);
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

function TRadSearchUsage.Count(const AKey: string): Integer;
begin
  if not FCounts.TryGetValue(AKey, Result) then
    Result := 0;
end;

function TRadSearchUsage.Items: TRadSearchUsageItems;
var
  LPair: TPair<string, Integer>;
  LItem: TRadSearchUsageItem;
begin
  Result := nil;
  for LPair in FCounts do
  begin
    LItem.Id := LPair.Key;
    LItem.Count := LPair.Value;
    Result := Result + [LItem];
  end;
  TArray.Sort<TRadSearchUsageItem>(Result, TComparer<TRadSearchUsageItem>.Construct(
    function(const A, B: TRadSearchUsageItem): Integer
    begin
      Result := B.Count - A.Count;
      if Result = 0 then
        Result := CompareStr(A.Id, B.Id);
    end));
end;

function TRadSearchUsage.Top(AMax: Integer): TArray<string>;
var
  LItems: TRadSearchUsageItems;
  I: Integer;
begin
  LItems := Items;
  Result := nil;
  for I := 0 to High(LItems) do
  begin
    if Length(Result) >= AMax then
      Break;
    Result := Result + [LItems[I].Id];
  end;
end;

procedure TRadSearchUsage.Assign(const AItems: TRadSearchUsageItems);
var
  LItem: TRadSearchUsageItem;
begin
  FCounts.Clear;
  for LItem in AItems do
    if (LItem.Id <> '') and (LItem.Count > 0) then
      FCounts.AddOrSetValue(LItem.Id, LItem.Count);
end;

procedure TRadSearchUsage.Clear;
begin
  FCounts.Clear;
end;

{ TRadSearchCommandProvider }

constructor TRadSearchCommandProvider.Create(ACommands: TRadDeskCommands; const AKey, ACaption: string);
begin
  inherited Create;
  if not Assigned(ACommands) then
    raise EArgumentNilException.Create('ACommands');
  FCommands := ACommands;
  FKey := AKey;
  FCaption := ACaption;
end;

function TRadSearchCommandProvider.Key: string;
begin
  Result := FKey;
end;

function TRadSearchCommandProvider.Caption: string;
begin
  Result := FCaption;
end;

procedure TRadSearchCommandProvider.Build;
var
  LInfos: TRadDeskCommandInfos;
  I: Integer;
begin
  // All yalnız görünür ve izinli komutları verir; yetki burada uygulanmış olur.
  LInfos := FCommands.All;
  SetLength(FEntries, Length(LInfos));
  for I := 0 to High(LInfos) do
  begin
    FEntries[I].Info := LInfos[I];
    FEntries[I].Info.Category := FEntries[I].Info.Category.Replace(DESK_PATH_SEPARATOR, RAD_SEARCH_PATH_SEPARATOR);
    FEntries[I].Key := TRadSearchMatch.Key(LInfos[I].Caption, LInfos[I].Category);
  end;
  FBuilt := True;
end;

function TRadSearchCommandProvider.HitOf(const AInfo: TRadDeskCommandInfo; AScore: Integer): TRadSearchHit;
begin
  Result := Default(TRadSearchHit);
  Result.Provider := FKey;
  Result.Id := AInfo.Id;
  Result.Caption := AInfo.Caption;
  Result.Path := AInfo.Category;
  Result.ImageIndex := AInfo.ImageIndex;
  Result.Score := AScore;
end;

procedure TRadSearchCommandProvider.Search(const AQuery: string; AMax: Integer; AHits: TList<TRadSearchHit>);
var
  LEntry: TEntry;
  LScore: Integer;
begin
  if not FBuilt then
    Build;
  for LEntry in FEntries do
    if LEntry.Info.Enabled then
    begin
      LScore := TRadSearchMatch.Score(AQuery, LEntry.Key);
      if LScore > TRadSearchMatch.ScoreNone then
        AHits.Add(HitOf(LEntry.Info, LScore));
    end;
end;

function TRadSearchCommandProvider.Find(const AId: string; out AHit: TRadSearchHit): Boolean;
var
  LInfo: TRadDeskCommandInfo;
begin
  Result := (FCommands.Resolve(AId, LInfo) = crOk) and LInfo.Enabled;
  if Result then
  begin
    LInfo.Category := LInfo.Category.Replace(DESK_PATH_SEPARATOR, RAD_SEARCH_PATH_SEPARATOR);
    AHit := HitOf(LInfo, TRadSearchMatch.ScoreNone);
  end;
end;

function TRadSearchCommandProvider.Execute(const AId: string): Boolean;
begin
  Result := FCommands.Execute(AId);
end;

procedure TRadSearchCommandProvider.Invalidate;
begin
  FEntries := nil;
  FBuilt := False;
end;

{ TRadSearchEngine }

constructor TRadSearchEngine.Create;
begin
  inherited Create;
  FProviders := TList<IRadSearchProvider>.Create;
  FUsage := TRadSearchUsage.Create;
  FMaxPerProvider := 8;
  FCountOnExecute := True;
end;

destructor TRadSearchEngine.Destroy;
begin
  FUsage.Free;
  FProviders.Free;
  inherited Destroy;
end;

function TRadSearchEngine.ProviderIndex(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FProviders.Count - 1 do
    if SameText(FProviders[I].Key, AKey) then
      Exit(I);
  Result := -1;
end;

function TRadSearchEngine.ProviderOf(const AKey: string): IRadSearchProvider;
var
  LIndex: Integer;
begin
  LIndex := ProviderIndex(AKey);
  if LIndex >= 0 then
    Result := FProviders[LIndex]
  else
    Result := nil;
end;

procedure TRadSearchEngine.Add(const AProvider: IRadSearchProvider);
begin
  if not Assigned(AProvider) then
    raise EArgumentNilException.Create('AProvider');
  Remove(AProvider.Key);
  FProviders.Add(AProvider);
end;

procedure TRadSearchEngine.Remove(const AKey: string);
var
  LIndex: Integer;
begin
  LIndex := ProviderIndex(AKey);
  if LIndex >= 0 then
    FProviders.Delete(LIndex);
end;

procedure TRadSearchEngine.Clear;
begin
  FProviders.Clear;
end;

procedure TRadSearchEngine.Sort(AHits: TList<TRadSearchHit>);
begin
  AHits.Sort(TComparer<TRadSearchHit>.Construct(
    function(const A, B: TRadSearchHit): Integer
    begin
      Result := B.Score - A.Score;
      if Result = 0 then
        Result := B.UseCount - A.UseCount;
      if Result = 0 then
        Result := Length(A.Caption) - Length(B.Caption);
      if Result = 0 then
        Result := CompareText(A.Caption, B.Caption);
    end));
end;

function TRadSearchEngine.Search(const AText: string): TRadSearchHits;
var
  LQuery: string;
  LProvider: IRadSearchProvider;
  LHits: TList<TRadSearchHit>;
  LHit: TRadSearchHit;
  I: Integer;
begin
  Result := nil;
  LQuery := TRadSearchMatch.Fold(AText).Trim;
  if LQuery = '' then
    Exit;
  LHits := TList<TRadSearchHit>.Create;
  try
    for LProvider in FProviders do
    begin
      LHits.Clear;
      LProvider.Search(LQuery, FMaxPerProvider, LHits);
      for I := 0 to LHits.Count - 1 do
      begin
        LHit := LHits[I];
        LHit.UseCount := FUsage.Count(LHit.UsageKey);
        LHits[I] := LHit;
      end;
      Sort(LHits);
      for I := 0 to LHits.Count - 1 do
        if I < FMaxPerProvider then
          Result := Result + [LHits[I]];
    end;
  finally
    LHits.Free;
  end;
end;

function TRadSearchEngine.Frequent(AMax: Integer): TRadSearchHits;
var
  LKey: string;
  LPos: Integer;
  LProvider: IRadSearchProvider;
  LHit: TRadSearchHit;
begin
  Result := nil;
  // Çözülemeyen (silinmiş, yetkisi kalkmış) kayıtlar atlanır; bu yüzden fazlası istenir.
  for LKey in FUsage.Top(AMax * 2) do
  begin
    if Length(Result) >= AMax then
      Break;
    LPos := LKey.IndexOf('|');
    if LPos <= 0 then
      Continue;
    LProvider := ProviderOf(LKey.Substring(0, LPos));
    if Assigned(LProvider) and LProvider.Find(LKey.Substring(LPos + 1), LHit) then
    begin
      LHit.UseCount := FUsage.Count(LKey);
      Result := Result + [LHit];
    end;
  end;
end;

function TRadSearchEngine.Execute(const AHit: TRadSearchHit): Boolean;
var
  LProvider: IRadSearchProvider;
begin
  LProvider := ProviderOf(AHit.Provider);
  Result := Assigned(LProvider) and LProvider.Execute(AHit.Id);
  if Result and FCountOnExecute then
    FUsage.Add(AHit.UsageKey);
end;

function TRadSearchEngine.CaptionOf(const AProviderKey: string): string;
var
  LProvider: IRadSearchProvider;
begin
  LProvider := ProviderOf(AProviderKey);
  if Assigned(LProvider) then
    Result := LProvider.Caption
  else
    Result := '';
end;

procedure TRadSearchEngine.Invalidate;
var
  LProvider: IRadSearchProvider;
begin
  for LProvider in FProviders do
    LProvider.Invalidate;
end;

end.
