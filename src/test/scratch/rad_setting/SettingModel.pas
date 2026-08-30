unit SettingModel;

(* Ayar panelinin test modeli. Siniflar .dpr icinde DEGIL ayri bir birimde
   duruyor: TRttiType.QualifiedName, bir birimin interface bolumunde
   TANIMLANMAMIS turler icin ENonPublicType firlatiyor (kitin
   delphi-conventions kuralinda olculmus). Panel bugun QualifiedName
   cagirmiyor ama testin bu tuzakla ugrasmasinin bir anlami yok. *)

interface

uses
  k.setting;

type
  /// Alt kategori: fatura.alis.*
  TAlisAyar = class(TRadSetting)
  published
    property IskontoOrani : Double  index 0 read GetF write SetF;
    property OtomatikOnay : Boolean index 1 read GetB write SetB default False;
  end;

  /// Alt kategori: fatura.satis.*
  TSatisAyar = class(TRadSetting)
  published
    property Vade          : Integer index 0 read GetI write SetI default 30;
    property KdvDahil      : Boolean index 1 read GetB write SetB default False;
    property Depo          : string  index 2 read GetS write SetS;
    property VadeAsimUyar  : Boolean index 3 read GetB write SetB default True;
  end;

  /// Ust kategori; ic ice published alanlar TSynAutoCreateFields tarafindan
  /// otomatik yaratilir ve panel bunlari alt kategori satiri yapar.
  TFaturaAyar = class(TRadSetting)
  private
    FAlis  : TAlisAyar;
    FSatis : TSatisAyar;
  published
    property Alis  : TAlisAyar  read FAlis;
    property Satis : TSatisAyar read FSatis;
  end;

  /// Duz kategori, ic ice yok.
  TGenelAyar = class(TRadSetting)
  published
    property SirketAdi   : string  index 0 read GetS write SetS;
    property OndalikBasamak : Integer index 1 read GetI write SetI default 2;
  end;

  // ---- kasitli hatali siniflar (savunma testleri icin) --------------------

  /// Iki property ayni index'i paylasiyor -> Register ERadSetting firlatmali.
  TCakisanAyar = class(TRadSetting)
  published
    property Bir : Integer index 0 read GetI write SetI;
    property Iki : Integer index 0 read GetI write SetI;
  end;

  /// index direktifi yok -> Register ERadSetting firlatmali.
  /// Alan destekli yazildi: GetI/SetI bir parametre aldigi icin index
  /// direktifi OLMADAN read/write belirteci yapilamaz - derleyici reddeder.
  /// Yani "index'siz ortak erisimci" zaten YAZILAMAZ; asil yakalanmasi
  /// gereken durum, birinin alan destekli bir property'yi ayar sanmasidir.
  TIndeksizAyar = class(TRadSetting)
  private
    FBir: Integer;
  published
    property Bir : Integer read FBir write FBir;
  end;

implementation

end.
