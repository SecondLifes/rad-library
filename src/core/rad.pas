unit rad;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes
  ,System.TypInfo,System.Rtti

  ,mormot.core.base,mormot.core.os,mormot.core.variants,mormot.core.text,mormot.core.rtti
  ,mormot.core.json,mormot.core.buffers

  , JclBase, JclSysInfo
  , rad.core , rad.cache, rad.config
  , Dext.Types.UUID
  ;


const
 Cache  : function :ISmartCache = rad.cache.Cache;
 //Config : function :ISmartCache = rad.cache.Config;
type
  TFileVersion1 = class(mormot.core.os.TFileVersion);
  TUUID = Dext.Types.UUID.TUUID;

  TFoldersSystem = record
   const
    WindowsFolder: function : string =JclSysInfo.GetWindowsFolder;  // C:\Windows
    WindowsSystemFolder: function : string =JclSysInfo.GetWindowsSystemFolder;  // C:\Windows\system32
    WindowsTempFolder: function : string =JclSysInfo.GetWindowsTempFolder; // C:\Users\SECOND~1\AppData\Local\Temp
    ProgramFilesFolder: function : string =JclSysInfo.GetProgramFilesFolder;  // C:\Program Files
    DesktopFolder: function : string =JclSysInfo.GetDesktopFolder; // C:\Users\SecondLife\Desktop
    ProgramsFolder: function : string =JclSysInfo.GetProgramsFolder;   // C:\Users\SecondLife\AppData\Roaming\Microsoft\Windows\Start Menu\Programs
    DesktopDirectoryFolder: function : string =JclSysInfo.GetDesktopDirectoryFolder;  // C:\Users\SecondLife\Desktop
    CommonDocumentsFolder: function : string =JclSysInfo.GetCommonDocumentsFolder;  // C:\Users\Public\Documents
    ProfileFolder: function : string =JclSysInfo.GetProfileFolder;  // C:\Users\SecondLife
    CommonProgramsFolder: function : string =JclSysInfo.GetCommonProgramsFolder; // C:\ProgramData\Microsoft\Windows\Start Menu\Programs
    CommonDesktopdirectoryFolder: function : string =JclSysInfo.GetCommonDesktopdirectoryFolder; // C:\Users\Public\Desktop
    CommonAppdataFolder: function : string =JclSysInfo.GetCommonAppdataFolder;  // C:\ProgramData
    AppdataFolder: function : string =JclSysInfo.GetAppdataFolder;          // C:\Users\SecondLife\AppData\Roaming
    LocalAppData: function : string =JclSysInfo.GetLocalAppData;            // C:\Users\SecondLife\AppData\Local
    CommonFilesFolder: function : string =JclSysInfo.GetCommonFilesFolder; // C:\Program Files\Common Files
  end;


  TFileVersion = class(mormot.core.os.TFileVersion)
  public
    Name      : string;      // urun adi (ProductName)
    Company   : string;
    Copyright : string;
    Web       : string;
    Email     : string;
    Tel       : string;
   function AppInfo :string;
  end;

  TFolders = record
  private
    FApp  : string;
    function GetStr(const Index: Integer): string;
  public
  sistem:TFoldersSystem;

  property App: string index 0 read GetStr;

  end;




  TRadApp  = class
   class var Folders : TFolders;
   private
    class var FDefaultApp : TRadApp;
   public
    Info:TFileVersion;
    constructor Create(const aAppName:string='');
    destructor Destroy; override;

    //function Config:ISmartCache;

  end;


// GenerateFluentCode / GenerateFluentUnit buradan KALDIRILDI — tek kaynak artik
// rad.utils.pas. Iki birebir kopya vardi; ayni projede iki unit birlikte uses
// edildiginde uses sirasina gore biri digerini golgeliyordu.

/// 1/10 ms toleranslı TDateTime karşılaştırma (float yuvarlama hatalarına karşı)
/// Kaynak: vendor\gabr42\GpDelphiUnits\src\GpTimezone.pas (DateEQ/DateLT/.../DateGE)
function DateEQ(const ADate1, ADate2: TDateTime): Boolean;
function DateLT(const ADate1, ADate2: TDateTime): Boolean;
function DateLE(const ADate1, ADate2: TDateTime): Boolean;
function DateGT(const ADate1, ADate2: TDateTime): Boolean;
function DateGE(const ADate1, ADate2: TDateTime): Boolean;

/// float yuvarlama hatalarını düzeltir (Trunc/Frac öncesi çağrılır)
/// ör. FixDT(36463.99999999999) = 36464
function FixDT(const ADate: TDateTime): TDateTime;

/// "ayın N'inci X günü" tarihini hesaplar (ör. DayOfMonth2Date(2026,12,5,1) = Aralık'ın son Pazarı)
/// AWeekInMonth: 1-4 (o ayın kaçıncı haftası) veya 5 (son hafta); ADayInWeek: 1=Pazar..7=Cumartesi
function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;


function RadApp: TRadApp;

function Config :IRadConfig;

implementation
uses
System.Generics.Collections, System.DateUtils, System.IOUtils
,mormot.core.datetime
//, JclSynch

;

function Config :IRadConfig;
begin
  if TRadConfig.Config = nil then
    TRadConfig.Config :=rad.config.TRadConfig.Create;
  Result :=TRadConfig.Config;
end;

function RadApp: TRadApp;
 begin
  if TRadApp.FDefaultApp = nil then
   TRadApp.FDefaultApp := TRadApp.Create();
  Result:=TRadApp.FDefaultApp;
 end;

const
  CDateTolerance: Double = 1.157407407407407E-9; // ~0.1 ms, TDateTime gün biriminde

function DateEQ(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := Abs(ADate1 - ADate2) < CDateTolerance;
end;

function DateLT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := (ADate2 - ADate1) >= CDateTolerance;
end;

function DateLE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := not DateGT(ADate1, ADate2);
end;

function DateGT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := (ADate1 - ADate2) >= CDateTolerance;
end;

function DateGE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := not DateLT(ADate1, ADate2);
end;

function FixDT(const ADate: TDateTime): TDateTime;
begin
  Result := Round(ADate * MSecsPerDay) / MSecsPerDay;
end;

function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;
var
  LFirstOfMonth, LLastOfMonth, LResult: TDateTime;
  LFirstDow: Word;
  LOffset: Integer;
begin
  LFirstOfMonth := EncodeDate(AYear, AMonth, 1);
  LFirstDow := DayOfWeek(LFirstOfMonth); // 1=Pazar..7=Cumartesi
  LOffset := ADayInWeek - LFirstDow;
  if LOffset < 0 then
    Inc(LOffset, 7);
  LResult := LFirstOfMonth + LOffset; // ayın ilk ADayInWeek günü

  if AWeekInMonth = 5 then
  begin
    LLastOfMonth := EncodeDate(AYear, AMonth, DaysInAMonth(AYear, AMonth));
    while LResult + 7 <= LLastOfMonth do
      LResult := LResult + 7;
  end
  else
    LResult := LResult + 7 * (AWeekInMonth - 1);

  Result := LResult;
end;





{ TFolders }

function TFolders.GetStr(const Index: Integer): string;
begin
  case Index of
   0 : begin
        if FApp.IsEmpty then
         FApp:=IncludeTrailingPathDelimiter(TPath.GetFullPath(ParamStr(0)));
       end;
  end;
end;


constructor TRadApp.Create(const aAppName: string);
begin
 Info := TFileVersion.Create(ParamStr(0));
 Info.Name    := Info.ProductName; //GetFileNameWithoutExtOrPath(Info.fFileName)
 //Info.AppName :=ExtractFileName(Info.fFileName);
 if not Assigned(TRadApp.FDefaultApp) then
  TRadApp.FDefaultApp:=Self;

end;

destructor TRadApp.Destroy;
begin
  Info.Free;
  inherited;
end;



procedure wInit;
begin
  //DocDict(StringFromFile(pmcFileName));
end;

{ TFileVersion }

function TFileVersion.AppInfo: string;
begin
  if self = nil then
    FastAssignNew(result)
  else
    result := _fmt('%s - v%s (%s-%s)', [Name, DetailedOrVoid, OS_TEXT,CPU_ARCH_TEXT]);

end;

Initialization
 wInit;

finalization


end.








