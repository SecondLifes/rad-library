unit rad.search;

{ Kullanım: uses rad.search; TRadSearch.Kur(LKurulum); TRadSearch.Bagla(edtSearch, Images, Self);
  Menü/komut araması ve takılabilir kaynaklar (cari, stok...) tek kutuda; ayrıntı docs/specs/rad.search.md. }

interface

uses
  System.Classes,
  Vcl.ImgList,
  cxTextEdit,
  rad.desktop.commands,
  rad.search.match,
  rad.search.core,
  rad.search.popup;

type
  TRadSearchKey = rad.search.match.TRadSearchKey;
  TRadSearchMatch = rad.search.match.TRadSearchMatch;
  TRadSearchHit = rad.search.core.TRadSearchHit;
  TRadSearchHits = rad.search.core.TRadSearchHits;
  TRadSearchUsageItem = rad.search.core.TRadSearchUsageItem;
  TRadSearchUsageItems = rad.search.core.TRadSearchUsageItems;
  IRadSearchProvider = rad.search.core.IRadSearchProvider;
  TRadSearchUsage = rad.search.core.TRadSearchUsage;
  TRadSearchCommandProvider = rad.search.core.TRadSearchCommandProvider;
  TRadSearchEngine = rad.search.core.TRadSearchEngine;
  TRadSearchBox = rad.search.popup.TRadSearchBox;

  TRadSearchSetup = record
    /// <summary>Komut kataloğu (menü, eylemler); nil ise komut kaynağı eklenmez. Sahiplenilmez.</summary>
    Commands: TRadDeskCommands;
    /// <summary>Komut sonuçlarının grup başlığı.</summary>
    CommandsCaption: string;
    /// <summary>Kayıtlı kullanım sayaçları.</summary>
    Usage: TRadSearchUsageItems;
    /// <summary>Sayaç değişince çağrılır; uygulama burada saklar.</summary>
    OnUsageChange: TNotifyEvent;
    /// <summary>True: uygulama her çalıştırmayı kendisi sayar (Application.OnActionExecute);
    /// arama kutusu ayrıca saymaz.</summary>
    AppCounts: Boolean;
  end;

  TRadSearch = class abstract
  private
    class var FEngine: TRadSearchEngine;
  public
    /// <summary>Tekrar çağrılabilir: kaynakları ve sayaçları baştan kurar, motor aynı kalır.</summary>
    class procedure Kur(const ASetup: TRadSearchSetup); static;
    /// <summary>Motoru bırakır. Bağlı kutular önce yok edilmiş olmalıdır.</summary>
    class procedure Kapat; static;
    /// <summary>Kaynak eklemek (cari, stok...) ve sayaç işlemleri için. Kur'dan önce nil.</summary>
    class function Motor: TRadSearchEngine; static;
    /// <summary>Bir metin kutusunu arama kutusuna çevirir; denetleyicinin sahibi AOwner'dır.</summary>
    class function Bagla(AEdit: TcxCustomTextEdit; AImages: TCustomImageList;
      AOwner: TComponent): TRadSearchBox; static;
  end;

implementation

uses
  System.SysUtils;

class procedure TRadSearch.Kur(const ASetup: TRadSearchSetup);
begin
  if FEngine = nil then
    FEngine := TRadSearchEngine.Create;
  FEngine.Clear;
  FEngine.Usage.OnChange := nil;
  FEngine.Usage.Assign(ASetup.Usage);
  FEngine.Usage.OnChange := ASetup.OnUsageChange;
  FEngine.CountOnExecute := not ASetup.AppCounts;
  if Assigned(ASetup.Commands) then
    FEngine.Add(TRadSearchCommandProvider.Create(ASetup.Commands, 'cmd', ASetup.CommandsCaption));
end;

class procedure TRadSearch.Kapat;
begin
  FreeAndNil(FEngine);
end;

class function TRadSearch.Motor: TRadSearchEngine;
begin
  Result := FEngine;
end;

class function TRadSearch.Bagla(AEdit: TcxCustomTextEdit; AImages: TCustomImageList;
  AOwner: TComponent): TRadSearchBox;
begin
  if FEngine = nil then
    raise EInvalidOpException.Create('TRadSearch.Kur çağrılmadan Bagla çağrıldı');
  Result := TRadSearchBox.Create(AOwner);
  Result.Bagla(AEdit, FEngine, AImages);
end;

end.
