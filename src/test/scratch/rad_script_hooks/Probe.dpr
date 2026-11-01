program Probe;

(* Sonda: P1 TForm.Caption DefineClassByRTTI ile gorunuyor mu; P2 Routines listesi; P3 thread: biri calisirken digeri derler. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Diagnostics, System.SyncObjs, System.Threading, System.Rtti,
  Vcl.Forms, Vcl.StdCtrls,
  atScript, atPascal, ap_Classes, Vcl.ScripterInit;

type
  TMyForm = class(TForm)
  end;

procedure P1;
var
  S: TatPascalScripter;
  F: TMyForm;
  C: TatClass;
  i: Integer;
  LNames: string;
begin
  S := TatPascalScripter.Create(nil);
  F := TMyForm.CreateNew(nil);
  try
    S.AddLibrary(TatClassesLibrary);
    S.DefineClassByRTTI(TForm);
    S.DefineClassByRTTI(TMyForm);
    C := S.Classes.ClassByName('TForm');
    if C = nil then Writeln('P1 TForm sinifi YOK') else
    begin
      LNames := '';
      for i := 0 to C.Properties.Count - 1 do
        if Pos('Cap', C.Properties[i].Name) > 0 then LNames := LNames + C.Properties[i].Name + ' ';
      Writeln('P1 TForm props=', C.Properties.Count, ' methods=', C.Methods.Count, ' Cap*: ', LNames);
    end;
    C := S.Classes.ClassByName('TMyForm');
    if C = nil then Writeln('P1 TMyForm YOK') else
    begin
      if C.Ancestor = nil then Writeln('P1 TMyForm props=', C.Properties.Count, ' ancestor=NIL')
      else Writeln('P1 TMyForm props=', C.Properties.Count, ' ancestor=', C.Ancestor.Name, ' ancestorname=', C.AncestorName);
      C.Ancestor := S.Classes.ClassByName('TForm');
      C.AncestorName := 'TForm';
    end;
    S.AddObject('Form', F);
    S.SourceCode.Text := 'begin Form.Caption := ''x''; end.';
    try
      S.Compile;
      S.Execute;
      Writeln('P1 Form.Caption OK -> ', F.Caption);
    except
      on E: Exception do Writeln('P1 HATA: ', E.Message);
    end;
    S.SourceCode.Text := 'begin Form.Width := 123; end.';
    try
      S.Compile;
      S.Execute;
      Writeln('P1b Form.Width OK -> ', F.Width);
    except
      on E: Exception do Writeln('P1b HATA: ', E.Message);
    end;
  finally
    F.Free;
    S.Free;
  end;
  // P1c: form sinifi hic tanimlanmazsa (yalniz TForm)
  S := TatPascalScripter.Create(nil);
  F := TMyForm.CreateNew(nil);
  try
    S.AddLibrary(TatClassesLibrary);
    S.DefineClassByRTTI(TForm);
    S.AddObject('Form', F);
    S.SourceCode.Text := 'begin Form.Caption := ''y''; end.';
    try
      S.Compile;
      S.Execute;
      Writeln('P1c tanimsiz TMyForm: Caption OK -> ', F.Caption);
    except
      on E: Exception do Writeln('P1c HATA: ', E.Message);
    end;
  finally
    F.Free;
    S.Free;
  end;
  // P1d: once TForm, sonra TMyForm Recursive=True
  S := TatPascalScripter.Create(nil);
  F := TMyForm.CreateNew(nil);
  try
    S.AddLibrary(TatClassesLibrary);
    S.DefineClassByRTTI(TForm);
    S.DefineClassByRTTI(TMyForm, roNone, True);
    S.AddObject('Form', F);
    S.SourceCode.Text := 'begin Form.Caption := ''z''; end.';
    try
      S.Compile;
      S.Execute;
      Writeln('P1d recursive: Caption OK -> ', F.Caption);
    except
      on E: Exception do Writeln('P1d HATA: ', E.Message);
    end;
  finally
    F.Free;
    S.Free;
  end;
end;

procedure P2;
var
  S: TatPascalScripter;
  i: Integer;
begin
  S := TatPascalScripter.Create(nil);
  try
    S.AddLibrary(TatClassesLibrary);
    S.SourceCode.Text := 'procedure Sonsuz; var i: Integer; begin i := 0; while true do i := i + 1; end;'#13#10 +
      'function Topla(a, b: Integer): Integer; begin Result := a + b; end;';
    S.Compile;
    for i := 0 to S.Scripts[0].ScriptInfo.Routines.Count - 1 do
      Writeln('P2 routine[', i, '] = "', S.Scripts[0].ScriptInfo.Routines[i].Name, '" internal=',
        S.Scripts[0].ScriptInfo.Routines[i].Internal);
  finally
    S.Free;
  end;
end;

var
  GLock: TCriticalSection;
  GUseLock: Boolean;

function Compile1(const ATag: string): string;
var
  S: TatPascalScripter;
begin
  S := TatPascalScripter.Create(nil);
  try
    try
      if GUseLock then GLock.Enter;
      try
        S.AddLibrary(TatClassesLibrary);
        S.SourceCode.Text := 'function Topla(a, b: Integer): Integer; begin Result := a + b; end;';
        S.Compile;
      finally
        if GUseLock then GLock.Leave;
      end;
      Result := ATag + ':ok=' + VarToStr(S.ExecuteSubroutineAsVariant('Topla', [1, 2]));
    except
      on E: Exception do Result := ATag + ':' + E.ClassName + ':' + E.Message;
    end;
  finally
    S.Free;
  end;
end;

procedure P3(AUseLock: Boolean);
var
  LBusy: TatPascalScripter;
  LTask: ITask;
  LRes: string;
  LRes2: string;
begin
  GUseLock := AUseLock;
  // Thread A: 1.5 s donen script
  LBusy := TatPascalScripter.Create(nil);
  try
    LBusy.AddLibrary(TatClassesLibrary);
    LBusy.SourceCode.Text := 'var i: Integer; begin i := 0; while i < 3000000 do i := i + 1; end.';
    LBusy.Compile;
    LTask := TTask.Run(procedure begin LBusy.Execute; end);
    Sleep(50);
    // Thread B (TTask): derle + calistir
    LRes := '';
    TTask.Run(procedure begin LRes := Compile1('task'); end).Wait;
    // Thread C: kendi TThread'i
    LRes2 := '';
    TThread.CreateAnonymousThread(procedure begin LRes2 := Compile1('thread'); end).Start;
    LTask.Wait;
    Sleep(300);
    Writeln('P3 lock=', AUseLock, ' ', LRes, ' | ', LRes2);
  finally
    LBusy.Free;
  end;
end;

begin
  GLock := TCriticalSection.Create;
  try
    P1;
    P2;
    P3(False);
    P3(True);
  finally
    GLock.Free;
  end;
end.
