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
 Cache  : function :ISmartCache = TSmartCache.Global;
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

  public
    class function Instance: TRadApp; static;
    class function Config :TRadConfig; static;
  end;


// GenerateFluentCode / GenerateFluentUnit buradan KALDIRILDI — tek kaynak artik
// rad.utils.pas. Iki birebir kopya vardi; ayni projede iki unit birlikte uses
// edildiginde uses sirasina gore biri digerini golgeliyordu.

function DateEQ(const ADate1, ADate2: TDateTime): Boolean; deprecated 'Use TRadDate.EQ in rad.utils';
function DateLT(const ADate1, ADate2: TDateTime): Boolean; deprecated 'Use TRadDate.LT in rad.utils';
function DateLE(const ADate1, ADate2: TDateTime): Boolean; deprecated 'Use TRadDate.LE in rad.utils';
function DateGT(const ADate1, ADate2: TDateTime): Boolean; deprecated 'Use TRadDate.GT in rad.utils';
function DateGE(const ADate1, ADate2: TDateTime): Boolean; deprecated 'Use TRadDate.GE in rad.utils';
function FixDT(const ADate: TDateTime): TDateTime; deprecated 'Use TRadDate.Fix in rad.utils';
function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime; deprecated 'Use TRadDate.DayOfMonth in rad.utils';

function RadApp: TRadApp; deprecated 'Use TRadApp.Instance';
function Config :TRadConfig; deprecated 'Use TRadApp.Config';

implementation
uses
System.Generics.Collections, System.DateUtils, System.IOUtils
,rad.utils
,mormot.core.datetime
//, JclSynch

;

class function TRadApp.Config :TRadConfig;
begin
  if TRadConfig.Config = nil then
    TRadConfig.Config :=rad.config.TRadConfig.Create;
  Result :=TRadConfig.Config;
end;


class function TRadApp.Instance: TRadApp;
 begin
  if TRadApp.FDefaultApp = nil then
   TRadApp.FDefaultApp := TRadApp.Create();
  Result:=TRadApp.FDefaultApp;
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

{ Deprecated names }

function RadApp: TRadApp;
begin
  Result := TRadApp.Instance;
end;

function Config :TRadConfig;
begin
  Result := TRadApp.Config;
end;

function DateEQ(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := TRadDate.EQ(ADate1, ADate2);
end;

function DateLT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := TRadDate.LT(ADate1, ADate2);
end;

function DateLE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := TRadDate.LE(ADate1, ADate2);
end;

function DateGT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := TRadDate.GT(ADate1, ADate2);
end;

function DateGE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := TRadDate.GE(ADate1, ADate2);
end;

function FixDT(const ADate: TDateTime): TDateTime;
begin
  Result := TRadDate.Fix(ADate);
end;

function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;
begin
  Result := TRadDate.DayOfMonth(AYear, AMonth, AWeekInMonth, ADayInWeek);
end;

Initialization
 wInit;

finalization


end.

