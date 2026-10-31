program HostDfmProbe;

(* Sonda: TRadCustomFieldsFrame host formun DFM'inden (inline) yaratilinca
   CreateLayout'ta AV var mi? ERPPlus kasa.k.pas'ta bildirilen hata.
   1) duz forma birakilmis, 2) host'un TdxLayoutControl item'ina birakilmis. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, Vcl.Forms, Vcl.Controls,
  rad.dev.customfields,
  HostDfm in 'HostDfm.pas' {frmHost},
  HostDfm2 in 'HostDfm2.pas' {frmHost2};

var
  GHata: Integer = 0;

procedure Dene(const AAd: string; AProc: TProc);
begin
  Writeln('--- ', AAd);
  try
    AProc;
    Writeln('  OK');
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

var
  F: TfrmHost;
  F2: TfrmHost2;
begin
  Dene('1 duz form, inline frame', procedure
    begin
      F := TfrmHost.Create(nil);
      try
        Writeln('  Create sonrasi Layout=', F.FOzel.Layout <> nil, ' (Loaded yolu)');
        F.HandleNeeded;
        F.FOzel.HandleNeeded;
        Writeln('  CreateWnd sonrasi Layout=', F.FOzel.Layout <> nil);
        F.FOzel.Rebuild;
        Writeln('  Rebuild sonrasi Layout=', F.FOzel.Layout <> nil);
      finally
        F.Free;
      end;
    end);
  Dene('2 host TdxLayoutControl item icinde inline frame', procedure
    begin
      F2 := TfrmHost2.Create(nil);
      try
        Writeln('  Create sonrasi Layout=', F2.FOzel.Layout <> nil, ' Parent=', F2.FOzel.Parent.ClassName);
        F2.HandleNeeded;
        F2.FOzel.HandleNeeded;
        Writeln('  CreateWnd sonrasi Layout=', F2.FOzel.Layout <> nil);
        F2.FOzel.Rebuild;
        Writeln('  Rebuild sonrasi Layout=', F2.FOzel.Layout <> nil);
      finally
        F2.Free;
      end;
    end);
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [2 - GHata, GHata]));
  if GHata > 0 then Halt(1);
end.
