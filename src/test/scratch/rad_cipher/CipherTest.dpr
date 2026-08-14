program CipherTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  mormot.core.base,
  mormot.core.text,
  mormot.crypt.core,
  rad.core   in '..\..\..\core\rad.core.pas',
  rad.cipher in '..\..\..\core\rad.cipher.pas';

var
  GOk, GFail: Integer;

procedure C(B: Boolean; const S: string);
begin
  if B then begin Inc(GOk); Writeln('  [GECTI] ', S) end
  else begin Inc(GFail); Writeln('  [KALDI] ', S) end;
end;

function Anahtar(AByte: Byte): THash256;
begin
  FillCharFast(Result, SizeOf(Result), AByte);
end;

const
  CDuz = '{"Logging":{"Path":"D:\\loglar"},"Db":{"Pwd":"cok-gizli-parola"}}';

{ ---------------------------------------------------------------- }

procedure GidisDonus;
var
  K: THash256;
  LC: IRadCipher;
  c1, c2: RawByteString;
begin
  Writeln;
  Writeln('=== Gidis-donus ===');
  K := Anahtar(7);
  LC := TRadAesGcmCipher.Create(K, 256);

  c1 := LC.Encrypt(CDuz);
  C(c1 <> '', '01 sifreleme bos donmedi');
  C(Pos(RawByteString('gizli'), c1) = 0, '02 duz metin sifrelide GORUNMUYOR');
  C(LC.Decrypt(c1) = CDuz, '03 gidis-donus dogru');

  c2 := LC.Encrypt(CDuz);
  C(c1 <> c2, '04 ayni girdi FARKLI cikti (rastgele IV)');
  C(LC.Decrypt(c2) = CDuz, '05 ikinci sifreleme de dogru cozuluyor');

  C(LC.AlgorithmId = 'aes-gcm-256', '06 AlgorithmId = ' + Utf8ToString(LC.AlgorithmId));
end;

procedure Kurcalama;
var
  K: THash256;
  LC: IRadCipher;
  LSif, bozuk: RawByteString;
  i, yakalandi, kacan, kacanAmaDogru: Integer;
begin
  Writeln;
  Writeln('=== Kurcalama: HER bayt tek tek cevriliyor ===');
  K := Anahtar(7);
  LC := TRadAesGcmCipher.Create(K, 256);
  LSif := LC.Encrypt(CDuz);

  yakalandi := 0; kacan := 0; kacanAmaDogru := 0;
  for i := 1 to Length(LSif) do
  begin
    bozuk := LSif;
    bozuk[i] := AnsiChar(Byte(bozuk[i]) xor 1);
    try
      if LC.Decrypt(bozuk) = CDuz then
        Inc(kacanAmaDogru)      // olu alan: duz metin bozulmadi
      else
        Inc(kacan);             // GERCEK kacak: bozuk metin dondu
    except
      on E: ERadCipherData do Inc(yakalandi);
    end;
  end;

  Writeln(Format('  %d bayt denendi: %d reddedildi, %d olu alan, %d GERCEK KACAK',
    [Length(LSif), yakalandi, kacanAmaDogru, kacan]));
  C(kacan = 0, '07 duz metni bozan HICBIR mudahale kacmadi');
  C(yakalandi >= Length(LSif) - 4, '08 olu alan en fazla 4 bayt (IV sayac kuyrugu)');
end;

procedure YanlisAnahtar;
var
  K1, K2: THash256;
  LC1, LC2: IRadCipher;
  LSif, LAtilan: RawByteString;
begin
  Writeln;
  Writeln('=== Yanlis anahtar ===');
  K1 := Anahtar(7);
  K2 := Anahtar(9);
  LC1 := TRadAesGcmCipher.Create(K1, 256);
  LC2 := TRadAesGcmCipher.Create(K2, 256);
  LSif := LC1.Encrypt(CDuz);

  try
    LAtilan := LC2.Decrypt(LSif);
    C(False, '09 yanlis anahtar -> ERadCipherData');
  except
    on E: ERadCipherData do C(True, '09 yanlis anahtar -> ERadCipherData');
  end;

  // Tek bit farkli anahtar da reddedilmeli
  K2 := Anahtar(7);
  K2[0] := K2[0] xor 1;
  LC2 := TRadAesGcmCipher.Create(K2, 256);
  try
    LAtilan := LC2.Decrypt(LSif);
    C(False, '10 TEK BIT farkli anahtar -> ERadCipherData');
  except
    on E: ERadCipherData do C(True, '10 TEK BIT farkli anahtar -> ERadCipherData');
  end;
end;

procedure SinirDurumlar;
var
  K: THash256;
  LC: IRadCipher;
  buyuk, LAtilan: RawByteString;
  i: Integer;
begin
  Writeln;
  Writeln('=== Sinir durumlar ===');
  K := Anahtar(7);
  LC := TRadAesGcmCipher.Create(K, 256);

  C(LC.Encrypt('') = '', '11 bos girdi -> bos cikti');

  try
    LAtilan := LC.Decrypt('');
    C(False, '12 bos veriyi cozmek -> ERadCipherData');
  except
    on E: ERadCipherData do C(True, '12 bos veriyi cozmek -> ERadCipherData');
  end;

  try
    LAtilan := LC.Decrypt('bu gecerli bir sifreli metin degil');
    C(False, '13 cop veri -> ERadCipherData');
  except
    on E: ERadCipherData do C(True, '13 cop veri -> ERadCipherData');
  end;

  C(LC.Decrypt(LC.Encrypt('x')) = 'x', '14 tek karakter');

  SetLength(buyuk, 1024 * 1024);
  for i := 1 to Length(buyuk) do
    buyuk[i] := AnsiChar(Byte(i));
  C(LC.Decrypt(LC.Encrypt(buyuk)) = buyuk, '15 1 MB veri');
end;

procedure AnahtarBoyutlari;
var
  K: THash256;
  LC, LAtilanC: IRadCipher;
begin
  Writeln;
  Writeln('=== Anahtar boyutlari ===');
  K := Anahtar(7);

  LC := TRadAesGcmCipher.Create(K, 128);
  C(LC.Decrypt(LC.Encrypt(CDuz)) = CDuz, '16 AES-128 calisiyor');
  C(LC.AlgorithmId = 'aes-gcm-128', '17 AlgorithmId 128 yansitiyor');

  LC := TRadAesGcmCipher.Create(K, 192);
  C(LC.Decrypt(LC.Encrypt(CDuz)) = CDuz, '18 AES-192 calisiyor');

  try
    LAtilanC := TRadAesGcmCipher.Create(K, 64);
    C(False, '19 gecersiz boyut -> ERadCipherKey');
  except
    on E: ERadCipherKey do C(True, '19 gecersiz boyut -> ERadCipherKey');
  end;

  try
    LAtilanC := TRadAesGcmCipher.Create(K, 255);
    C(False, '20 255 bit -> ERadCipherKey');
  except
    on E: ERadCipherKey do C(True, '20 255 bit -> ERadCipherKey');
  end;
end;

procedure FarkliBoyutlarUyusmaz;
var
  K: THash256;
  L128, L256: IRadCipher;
  LSif, LAtilan: RawByteString;
begin
  Writeln;
  Writeln('=== Ayni anahtar, farkli boyut ===');
  K := Anahtar(7);
  L128 := TRadAesGcmCipher.Create(K, 128);
  L256 := TRadAesGcmCipher.Create(K, 256);
  LSif := L256.Encrypt(CDuz);
  try
    LAtilan := L128.Decrypt(LSif);
    C(False, '21 128 ile 256 verisi cozulemez');
  except
    on E: ERadCipherData do C(True, '21 128 ile 256 verisi cozulemez');
  end;
end;

procedure CokThread;
const
  N = 8;
  DONGU = 200;
var
  K: THash256;
  LC: IRadCipher;
  t: array of ITask;
  i, hata: Integer;
begin
  Writeln;
  Writeln('=== Cok thread: ', N, ' thread x ', DONGU, ' ===');
  K := Anahtar(7);
  LC := TRadAesGcmCipher.Create(K, 256);
  hata := 0;

  SetLength(t, N);
  for i := 0 to N - 1 do
    t[i] := TTask.Run(
      procedure
      var
        j: Integer;
        LSif: RawByteString;
      begin
        for j := 1 to DONGU do
        begin
          LSif := LC.Encrypt(CDuz);
          if LC.Decrypt(LSif) <> CDuz then
            TInterlocked.Increment(hata);
        end;
      end);
  TTask.WaitForAll(t);

  C(hata = 0, Format('22 %d es zamanli gidis-donus, hata: %d', [N * DONGU, hata]));
end;

begin
  GOk := 0; GFail := 0;
  try
    GidisDonus;
    Kurcalama;
    YanlisAnahtar;
    SinirDurumlar;
    AnahtarBoyutlari;
    FarkliBoyutlarUyusmaz;
    CokThread;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;

  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  if GFail > 0 then ExitCode := 1;
end.
