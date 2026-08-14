program CoreLockTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  mormot.core.base,
  mormot.core.os,
  rad.core in '..\..\..\core\rad.core.pas';

type
  // Kalitim agaci uygun OLMAYAN bir sinif: TAbstractLockable'dan turemiyor,
  // kilidi ALAN olarak tasiyor. Record tasariminin asil gerekcesi bu.
  TAyarBenzeri = class(TObject)
  public
    Kilit: TRadLock;      // Init cagrilmadi: sifirlanmis bellek = ETKIN
    Sayac: Integer;
  end;

var
  GOk, GFail: Integer;

procedure C(B: Boolean; const S: string);
begin
  if B then begin Inc(GOk); Writeln('  [GECTI] ', S) end
  else begin Inc(GFail); Writeln('  [KALDI] ', S) end;
end;

{ ---------------------------------------------------------------- }

procedure TemelDavranis;
var
  L: TRadLock;
  LAyar: TAyarBenzeri;
begin
  Writeln;
  Writeln('=== Temel davranis ===');

  L.Init;
  C(L.Enabled, '01 Init varsayilani etkin');
  C(not L.IsLocked, '02 baslangicta kilitli degil');

  L.ReadLock;
  C(L.IsLocked, '03 ReadLock sonrasi kilitli');
  L.ReadUnlock;
  C(not L.IsLocked, '04 ReadUnlock sonrasi serbest');

  L.WriteLock;
  C(L.IsLocked, '05 WriteLock sonrasi kilitli');
  L.WriteUnlock;
  C(not L.IsLocked, '06 WriteUnlock sonrasi serbest');

  L.UpdateLock;
  C(L.IsLocked, '07 UpdateLock sonrasi kilitli');
  L.UpdateUnlock;
  C(not L.IsLocked, '08 UpdateUnlock sonrasi serbest');

  // Sifirlanmis bellek = etkin. Init cagrilmadi.
  LAyar := TAyarBenzeri.Create;
  try
    C(LAyar.Kilit.Enabled, '09 Init CAGRILMADAN sinif alani etkin geliyor');
    LAyar.Kilit.ReadLock;
    C(LAyar.Kilit.IsLocked, '10 Init'#39'siz alan gercekten kilitliyor');
    LAyar.Kilit.ReadUnlock;
  finally
    LAyar.Free;
  end;
end;

procedure DevreDisi;
var
  L: TRadLock;
begin
  Writeln;
  Writeln('=== Devre disi (tek thread) ===');

  L.Init(False);
  C(not L.Enabled, '11 Init(False) devre disi');

  L.ReadLock;
  C(not L.IsLocked, '12 devre disiyken ReadLock islemsiz');
  L.ReadUnlock;

  L.WriteLock;
  C(not L.IsLocked, '13 devre disiyken WriteLock islemsiz');
  L.WriteUnlock;

  // Asil kazanc: asimetri artik ZARARSIZ, cunku bayrak degismiyor.
  L.AssertUnlocked;
  C(True, '14 devre disi kilit AssertUnlocked'#39'tan temiz gecti');
end;

procedure GuvenliYuvalama;
var
  L: TRadLock;
begin
  Writeln;
  Writeln('=== Guvenli yuvalamalar (yanlissa BU NOKTADA ASILIR) ===');

  L.Init;

  L.ReadLock;
  L.ReadLock;                 // ic ice okuma
  L.ReadUnlock;
  L.ReadUnlock;
  C(not L.IsLocked, '15 ReadLock ic ice ReadLock');

  L.WriteLock;
  L.WriteLock;                // ayni thread, yeniden girisli
  L.WriteUnlock;
  L.WriteUnlock;
  C(not L.IsLocked, '16 WriteLock ic ice WriteLock (yeniden girisli)');

  L.UpdateLock;
  L.ReadLock;                 // guncelleme niyeti icinde okuma
  L.ReadUnlock;
  L.UpdateUnlock;
  C(not L.IsLocked, '17 UpdateLock ic ice ReadLock');

  L.UpdateLock;
  L.WriteLock;                // YUKSELTME yolu
  L.WriteUnlock;
  L.UpdateUnlock;
  C(not L.IsLocked, '18 UpdateLock ic ice WriteLock (yukseltme)');
end;

procedure ParantezYardimcilari;
var
  L: TRadLock;
  LGirdi: Boolean;
begin
  Writeln;
  Writeln('=== Parantez yardimcilari ===');

  L.Init;

  LGirdi := False;
  L.LockedRead(procedure begin LGirdi := L.IsLocked end);
  C(LGirdi, '19 LockedRead govdesi kilit altinda calisti');
  C(not L.IsLocked, '20 LockedRead sonrasi serbest');

  LGirdi := False;
  L.LockedWrite(procedure begin LGirdi := L.IsLocked end);
  C(LGirdi and not L.IsLocked, '21 LockedWrite alip birakti');

  // "Oku, karar ver, yaz" — cevap 3'un deseni
  LGirdi := False;
  L.LockedUpdate(procedure
    begin
      if not LGirdi then
      begin
        L.WriteLock;
        try
          LGirdi := True;
        finally
          L.WriteUnlock;
        end;
      end;
    end);
  C(LGirdi and not L.IsLocked, '22 LockedUpdate icinde yukseltme');

  // Govde istisna atsa bile kilit BIRAKILMALI
  try
    L.LockedWrite(procedure begin raise Exception.Create('kasitli') end);
  except
    on E: Exception do ;
  end;
  C(not L.IsLocked, '23 govde istisna atsa da kilit birakildi');
end;

procedure AssertVeIstisna;
var
  L: TRadLock;
begin
  Writeln;
  Writeln('=== AssertUnlocked ===');

  L.Init;
  L.AssertUnlocked;
  C(True, '24 serbestken AssertUnlocked sessiz');

  L.ReadLock;
  try
    L.AssertUnlocked;
    C(False, '25 tutulurken AssertUnlocked -> ERadLock');
  except
    on E: ERadLock do C(True, '25 tutulurken AssertUnlocked -> ERadLock');
  end;
  L.ReadUnlock;
end;

procedure ArayuzUzerinden;
var
  LNesne: TAbstractLockable;
  LArayuz: ILockable;
begin
  Writeln;
  Writeln('=== TAbstractLockable / ILockable ===');

  LArayuz := TAbstractLockable.Create;
  C(LArayuz.IsThreadSafe, '26 varsayilan thread-safe');
  LArayuz.ReadLock;
  LArayuz.ReadUnlock;
  LArayuz.UpdateLock;
  LArayuz.WriteLock;
  LArayuz.WriteUnlock;
  LArayuz.UpdateUnlock;
  C(True, '27 arayuz uzerinden tum seviyeler');

  LArayuz := TAbstractLockable.Create(False);
  C(not LArayuz.IsThreadSafe, '28 Create(False) -> IsThreadSafe False');
  LArayuz := nil;

  LNesne := TAbstractLockable.Create;
  try
    // Lock ISARETCI dondurur: uzerinde kilitlemek GERCEK alani etkiler
    LNesne.Lock.ReadLock;
    C(LNesne.Lock.IsLocked, '29 Lock isaretcisi gercek kilidi veriyor');
    LNesne.Lock.ReadUnlock;
    C(not LNesne.Lock.IsLocked, '30 isaretci uzerinden birakma da gercek');
  finally
    LNesne.Free;
  end;
end;

{ ---------------------------------------------------------------- }

procedure CokThread;
const
  CYazar   = 4;
  COkur    = 8;
  CDongu   = 5000;
var
  LAyar: TAyarBenzeri;
  LGorevler: array of ITask;
  I: Integer;
  LOkumaHatasi: Integer;
begin
  Writeln;
  Writeln('=== Cok thread: ', CYazar, ' yazar x ', CDongu, ' + ', COkur, ' okur ===');

  LAyar := TAyarBenzeri.Create;
  try
    LOkumaHatasi := 0;
    SetLength(LGorevler, CYazar + COkur);

    for I := 0 to CYazar - 1 do
      LGorevler[I] := TTask.Run(
        procedure
        var K: Integer;
        begin
          for K := 1 to CDongu do
            LAyar.Kilit.LockedWrite(procedure begin Inc(LAyar.Sayac) end);
        end);

    for I := CYazar to CYazar + COkur - 1 do
      LGorevler[I] := TTask.Run(
        procedure
        var K, LDeger: Integer;
        begin
          for K := 1 to CDongu do
            LAyar.Kilit.LockedRead(
              procedure
              begin
                LDeger := LAyar.Sayac;
                // Sayac hicbir zaman gerilememeli, sinirlari asmamali
                if (LDeger < 0) or (LDeger > CYazar * CDongu) then
                  TInterlocked.Increment(LOkumaHatasi);
              end);
        end);

    TTask.WaitForAll(LGorevler);

    C(LAyar.Sayac = CYazar * CDongu,
      Format('31 sayac dogru: %d (beklenen %d)', [LAyar.Sayac, CYazar * CDongu]));
    C(LOkumaHatasi = 0, '32 okurlar hicbir zaman tutarsiz deger gormedi');
    C(not LAyar.Kilit.IsLocked, '33 tum isler bitince kilit notr');
  finally
    LAyar.Free;
  end;
end;

procedure OkurlarUpdateIleParalel;
var
  L: TRadLock;
  LOkudu: Boolean;
  LGorev: ITask;
begin
  Writeln;
  Writeln('=== UpdateLock okurlari ENGELLEMIYOR mu ===');

  L.Init;
  LOkudu := False;

  L.UpdateLock;               // ana thread guncelleme niyeti tutuyor
  try
    LGorev := TTask.Run(
      procedure
      begin
        L.ReadLock;               // engellenmemeli
        try
          LOkudu := True;
        finally
          L.ReadUnlock;
        end;
      end);
    // Engellenirse bu bekleme dolar ve iddia kalir
    LGorev.Wait(3000);
  finally
    L.UpdateUnlock;
  end;

  C(LOkudu, '34 baska thread UpdateLock altinda okuyabildi');
end;

{ ---------------------------------------------------------------- }
{ TRadOSLock                                                        }

type
  // Kilidini ALAN olarak tasiyan sinif — TRadLock'la BIREBIR ayni sablon,
  // tek fark alan tipi ve destructor'daki Done.
  TOSAyarBenzeri = class(TObject)
  public
    Kilit: TRadOSLock;   // Init cagrilmadi: ilk kilitlemede kendi kurulur
    Sayac: Integer;
    destructor Destroy; override;
  end;

destructor TOSAyarBenzeri.Destroy;
begin
  Kilit.Done;            // TRadLock'tan TEK yapisal fark
  inherited;
end;

procedure OSTemel;
var
  L: TRadOSLock;
  LAyar: TOSAyarBenzeri;
begin
  Writeln;
  Writeln('=== TRadOSLock temel ===');

  L.Init;
  try
    C(L.Enabled, '35 Init varsayilani etkin');
    C(not L.IsLocked, '36 baslangicta kilitli degil');

    L.ReadLock;
    C(L.IsLocked, '37 ReadLock sonrasi kilitli');
    L.ReadUnlock;
    C(not L.IsLocked, '38 ReadUnlock sonrasi serbest');

    L.WriteLock;  C(L.IsLocked, '39 WriteLock');   L.WriteUnlock;
    L.UpdateLock; C(L.IsLocked, '40 UpdateLock');  L.UpdateUnlock;
    C(not L.IsLocked, '41 hepsi birakildi');
  finally
    L.Done;
  end;

  // Init CAGRILMADAN: LockAndInitIfNeeded devreye girmeli
  LAyar := TOSAyarBenzeri.Create;
  try
    C(LAyar.Kilit.Enabled, '42 Init CAGRILMADAN etkin geliyor');
    LAyar.Kilit.ReadLock;
    C(LAyar.Kilit.IsLocked, '43 Init'#39'siz alan gercekten kilitliyor');
    LAyar.Kilit.ReadUnlock;
  finally
    LAyar.Free;          // destructor Done cagiriyor
  end;
  C(True, '44 Done destructor'#39'dan cagrildi, patlamadi');
end;

procedure OSDevreDisiVeDone;
var
  L: TRadOSLock;
begin
  Writeln;
  Writeln('=== TRadOSLock devre disi / Done ===');

  L.Init(False);
  C(not L.Enabled, '45 Init(False) devre disi');
  L.ReadLock;
  C(not L.IsLocked, '46 devre disiyken islemsiz');
  L.ReadUnlock;
  L.Done;
  C(True, '47 devre disi kilitte Done guvenli');

  L.Init;
  L.Done;
  L.Done;                // idempotent olmali
  C(True, '48 Done iki kez cagrilabildi');
end;

procedure OSHerYuvalamaGuvenli;
var
  L: TRadOSLock;
begin
  Writeln;
  Writeln('=== TRadOSLock: TRadLock'#39'ta KILITLENEN yuvalamalar ===');

  L.Init;
  try
    // TRadLock'ta bu iki desen SESSIZCE ASILIR. Burada gecmeli.
    L.ReadLock;
    L.WriteLock;          // TRadLock'ta kilitlenir
    L.WriteUnlock;
    L.ReadUnlock;
    C(not L.IsLocked, '49 ReadLock ic ice WriteLock (TRadLock'#39'ta kilitlenir)');

    L.WriteLock;
    L.ReadLock;           // TRadLock'ta kilitlenir
    L.ReadUnlock;
    L.WriteUnlock;
    C(not L.IsLocked, '50 WriteLock ic ice ReadLock (TRadLock'#39'ta kilitlenir)');

    // Derin ozyineleme
    L.UpdateLock; L.ReadLock; L.WriteLock; L.UpdateLock;
    C(L.IsLocked, '51 dort kat ozyineleme tutuluyor');
    L.UpdateUnlock; L.WriteUnlock; L.ReadUnlock; L.UpdateUnlock;
    C(not L.IsLocked, '52 dort kat geri sarildi');
  finally
    L.Done;
  end;
end;

procedure OSCokThread;
const
  CYazar = 8;
  CDongu = 20000;
var
  LAyar: TOSAyarBenzeri;
  LGorevler: array of ITask;
  I: Integer;
begin
  Writeln;
  Writeln('=== TRadOSLock cok thread: ', CYazar, ' yazar x ', CDongu, ' ===');

  LAyar := TOSAyarBenzeri.Create;
  try
    SetLength(LGorevler, CYazar);
    for I := 0 to CYazar - 1 do
      LGorevler[I] := TTask.Run(
        procedure
        var K: Integer;
        begin
          for K := 1 to CDongu do
            LAyar.Kilit.LockedWrite(procedure begin Inc(LAyar.Sayac) end);
        end);
    TTask.WaitForAll(LGorevler);

    C(LAyar.Sayac = CYazar * CDongu,
      Format('53 sayac dogru: %d (beklenen %d)', [LAyar.Sayac, CYazar * CDongu]));
    C(not LAyar.Kilit.IsLocked, '54 bitince kilit notr');
  finally
    LAyar.Free;
  end;
end;

begin
  GOk := 0; GFail := 0;
  try
    TemelDavranis;
    DevreDisi;
    GuvenliYuvalama;
    ParantezYardimcilari;
    AssertVeIstisna;
    ArayuzUzerinden;
    CokThread;
    OkurlarUpdateIleParalel;
    OSTemel;
    OSDevreDisiVeDone;
    OSHerYuvalamaGuvenli;
    OSCokThread;
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
