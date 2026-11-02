unit rad.reports.Tests;

{ rad.reports — veritabanı gerektirmeyen parçaların DUnitX testleri: dosya adı şablonu, yerel eşitleme, sabitler.
  Veritabanı/FastReport gerektirenler rad.reports.db.Tests'tedir. }

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.IOUtils, System.Variants, System.DateUtils, Data.DB, Data.FMTBcd,
  rad.reports;

type
  [TestFixture]
  TRadReportFileNameTests = class
  public
    [Test] procedure Clean_ReplacesForbidden;
    [Test] procedure Clean_TrimsEdges;
    [Test] procedure ValueText_CurrencyTwoDecimals;
    [Test] procedure ValueText_DoubleTwoDecimals;
    [Test] procedure ValueText_Date;
    [Test] procedure ValueText_DateTime;
    [Test] procedure ValueText_NullAndEmpty;
    [Test] procedure ValueText_Boolean;
    [Test] procedure ValueText_FmtBcd;
    [Test] procedure Resolve_PlaceholdersAndUnknown;
    [Test] procedure Resolve_CleansValues;
    [Test] procedure Resolve_UnclosedBraceKept;
    [Test] procedure Unique_AppendsCounter;
    [Test] procedure Unique_ShortensLongName;
    [Test] procedure Unique_EmptyNameBecomesReport;
  end;

  [TestFixture]
  TRadReportLocalTests = class
  strict private
    FRoot: string;
    FLocal: TRadReportLocal;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Sha256_Known;
    [Test] procedure Sha256_Empty;
    [Test] procedure Write_ThenUnchanged;
    [Test] procedure FileEdit_Detected;
    [Test] procedure SideFile_DottedKeysRead;
    [Test] procedure NoSideFile_CountsAsChanged;
    [Test] procedure NoFile_NotChanged;
    [Test] procedure Backup_Writes;
    [Test] procedure Paths_CleanKeyAndDesign;
  end;

  [TestFixture]
  TRadReportConstTests = class
  public
    [Test] procedure FormatExtAndNamesFilled;
  end;

implementation

function Bytes(const S: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(S);
end;

function TempDir(const APrefix: string): string;
begin
  Result := TPath.Combine(TPath.GetTempPath, APrefix + TGUID.NewGuid.ToString.Substring(1, 8));
end;

{ TRadReportFileNameTests }

procedure TRadReportFileNameTests.Clean_ReplacesForbidden;
begin
  Assert.AreEqual('a_b_c_d_e_f_g_h_i', TRadReportFileName.Clean('a\b/c:d*e?f"g<h>i'));
  Assert.AreEqual('a_b', TRadReportFileName.Clean('a|b'));
end;

procedure TRadReportFileNameTests.Clean_TrimsEdges;
begin
  Assert.AreEqual('ad', TRadReportFileName.Clean('  ad. '));
  Assert.AreEqual('', TRadReportFileName.Clean(' . '));
end;

procedure TRadReportFileNameTests.ValueText_CurrencyTwoDecimals;
begin
  Assert.AreEqual('1234.50', TRadReportFileName.ValueText(Currency(1234.5)));
  Assert.AreEqual('0.00', TRadReportFileName.ValueText(Currency(0)));
  Assert.AreEqual('-12.35', TRadReportFileName.ValueText(Currency(-12.346)));
end;

procedure TRadReportFileNameTests.ValueText_DoubleTwoDecimals;
begin
  Assert.AreEqual('1234.50', TRadReportFileName.ValueText(Double(1234.5)));
end;

procedure TRadReportFileNameTests.ValueText_Date;
begin
  Assert.AreEqual('2026-11-01', TRadReportFileName.ValueText(EncodeDate(2026, 11, 1)));
end;

procedure TRadReportFileNameTests.ValueText_DateTime;
begin
  Assert.AreEqual('2026-11-01_1405', TRadReportFileName.ValueText(EncodeDateTime(2026, 11, 1, 14, 5, 0, 0)));
end;

procedure TRadReportFileNameTests.ValueText_NullAndEmpty;
begin
  Assert.AreEqual('', TRadReportFileName.ValueText(Null));
  Assert.AreEqual('', TRadReportFileName.ValueText(Unassigned));
end;

procedure TRadReportFileNameTests.ValueText_Boolean;
begin
  Assert.AreEqual('evet', TRadReportFileName.ValueText(True));
  Assert.AreEqual('hayir', TRadReportFileName.ValueText(False));
end;

procedure TRadReportFileNameTests.ValueText_FmtBcd;
begin
  Assert.AreEqual('1234.50', TRadReportFileName.ValueText(VarFMTBcdCreate(StrToBcd('1234.50', TFormatSettings.Invariant))));
end;

procedure TRadReportFileNameTests.Resolve_PlaceholdersAndUnknown;
var
  S: string;
begin
  S := TRadReportFileName.Resolve('fis-{Kasalar|musteri}-{tarih}-{yok}',
    function(const A: string): Variant
    begin
      if A = 'Kasalar|musteri' then
        Result := 'Ali'
      else if A = 'tarih' then
        Result := EncodeDate(2026, 1, 5)
      else
        Result := Null;
    end);
  Assert.AreEqual('fis-Ali-2026-01-05-', S);
end;

procedure TRadReportFileNameTests.Resolve_CleansValues;
begin
  Assert.AreEqual('Ali_Veli', TRadReportFileName.Resolve('{m}',
    function(const A: string): Variant begin Result := 'Ali/Veli'; end));
end;

procedure TRadReportFileNameTests.Resolve_UnclosedBraceKept;
begin
  Assert.AreEqual('fis-{x', TRadReportFileName.Resolve('fis-{x', nil));
end;

procedure TRadReportFileNameTests.Unique_AppendsCounter;
var
  D: string;
begin
  D := TempDir('radreports_fn_');
  TDirectory.CreateDirectory(D);
  try
    Assert.AreEqual('a.pdf', ExtractFileName(TRadReportFileName.Unique(D, 'a', 'pdf')));
    TFile.WriteAllText(TPath.Combine(D, 'a.pdf'), 'x');
    Assert.AreEqual('a-2.pdf', ExtractFileName(TRadReportFileName.Unique(D, 'a', 'pdf')));
    TFile.WriteAllText(TPath.Combine(D, 'a-2.pdf'), 'x');
    Assert.AreEqual('a-3.pdf', ExtractFileName(TRadReportFileName.Unique(D, 'a', 'pdf')));
  finally
    TDirectory.Delete(D, True);
  end;
end;

procedure TRadReportFileNameTests.Unique_ShortensLongName;
var
  P: string;
begin
  P := TRadReportFileName.Unique(TPath.GetTempPath, StringOfChar('x', 400), 'pdf', 240);
  Assert.IsTrue(Length(P) <= 240, 'yol uzunluğu ' + IntToStr(Length(P)));
  Assert.IsTrue(P.EndsWith('.pdf'));
end;

procedure TRadReportFileNameTests.Unique_EmptyNameBecomesReport;
begin
  Assert.AreEqual('report.pdf', ExtractFileName(TRadReportFileName.Unique(TempDir('radreports_none_'), '  ', 'pdf')));
end;

{ TRadReportLocalTests }

procedure TRadReportLocalTests.Setup;
begin
  FRoot := TempDir('radreports_local_');
  FLocal := TRadReportLocal.Create(FRoot);
end;

procedure TRadReportLocalTests.TearDown;
begin
  FLocal.Free;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TRadReportLocalTests.Sha256_Known;
begin
  Assert.AreEqual('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', TRadReportLocal.Sha256(Bytes('abc')));
end;

procedure TRadReportLocalTests.Sha256_Empty;
begin
  Assert.AreEqual('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', TRadReportLocal.Sha256(nil));
end;

procedure TRadReportLocalTests.Write_ThenUnchanged;
var
  I: TRadReportLocalInfo;
  C: TBytes;
begin
  C := Bytes('merhaba');
  I.ReportId := 'id1';
  I.Version := 3;
  I.Sha := TRadReportLocal.Sha256(C);
  FLocal.Write('kasa.liste', 'Varsayılan', I, C);
  Assert.IsTrue(TFile.Exists(FLocal.FilePath('kasa.liste', 'Varsayılan')));
  Assert.IsFalse(FLocal.Changed('kasa.liste', 'Varsayılan'));
  Assert.AreEqual(I.Sha, FLocal.FileSha('kasa.liste', 'Varsayılan'));
end;

procedure TRadReportLocalTests.FileEdit_Detected;
var
  I: TRadReportLocalInfo;
begin
  I.ReportId := 'id1';
  I.Version := 1;
  I.Sha := TRadReportLocal.Sha256(Bytes('a'));
  FLocal.Write('k', 'd', I, Bytes('a'));
  TFile.WriteAllBytes(FLocal.FilePath('k', 'd'), Bytes('b'));
  Assert.IsTrue(FLocal.Changed('k', 'd'));
end;

procedure TRadReportLocalTests.SideFile_DottedKeysRead;
var
  I, O: TRadReportLocalInfo;
begin
  I.ReportId := 'abc-123';
  I.Version := 7;
  I.Sha := 'ff';
  FLocal.Write('a.b.c', 'Özet', I, Bytes('x'));
  Assert.IsTrue(FLocal.Read('a.b.c', 'Özet', O));
  Assert.AreEqual('abc-123', O.ReportId);
  Assert.AreEqual(7, O.Version);
  Assert.AreEqual('ff', O.Sha);
end;

procedure TRadReportLocalTests.NoSideFile_CountsAsChanged;
begin
  TDirectory.CreateDirectory(ExtractFileDir(FLocal.FilePath('x', 'y')));
  TFile.WriteAllText(FLocal.FilePath('x', 'y'), 'icerik');
  Assert.IsTrue(FLocal.Changed('x', 'y'), 'kaynağı bilinmeyen dosya değişmiş sayılır');
end;

procedure TRadReportLocalTests.NoFile_NotChanged;
begin
  Assert.IsFalse(FLocal.Changed('yok', 'yok'));
  Assert.AreEqual('', FLocal.FileSha('yok', 'yok'));
end;

procedure TRadReportLocalTests.Backup_Writes;
var
  P: string;
begin
  P := FLocal.Backup('kasa.liste', 'Özet', 4, Bytes('yedek'));
  Assert.IsTrue(TFile.Exists(P));
  Assert.IsTrue(ExtractFileName(P).StartsWith('kasa.liste@Özet_v4_'));
  Assert.AreEqual('yedek', TFile.ReadAllText(P, TEncoding.UTF8));
end;

procedure TRadReportLocalTests.Paths_CleanKeyAndDesign;
begin
  Assert.AreEqual(TPath.Combine(TPath.Combine(FRoot, 'a_b'), 'c_d.fr3'), FLocal.FilePath('a/b', 'c:d'));
end;

{ TRadReportConstTests }

procedure TRadReportConstTests.FormatExtAndNamesFilled;
var
  F: TRadReportFormat;
begin
  for F := Low(TRadReportFormat) to High(TRadReportFormat) do
  begin
    Assert.IsTrue(RadReportFormatExt[F] <> '', 'uzantı boş: ' + IntToStr(Ord(F)));
    Assert.IsTrue(RadReportFormatName[F] <> '', 'ad boş: ' + IntToStr(Ord(F)));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadReportFileNameTests);
  TDUnitX.RegisterTestFixture(TRadReportLocalTests);
  TDUnitX.RegisterTestFixture(TRadReportConstTests);

end.
