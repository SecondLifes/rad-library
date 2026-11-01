program OverrideTest;

(* rad.script.override: anlik goruntu, fark, JSON, uygulama. VCL'siz -> Win32 + Win64.
   Spec: docs/specs/rad.script.designer.md, "Override" kabul olcutleri. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.Diagnostics,
  mormot.core.base,
  rad.script.override;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure Kontrol(const AAd: string; ABasarili: Boolean; const ADetay: string = '');
begin
  if ABasarili then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
end;

type
  TKind = (kA, kB, kC);
  TFlag = (fA, fB, fC);
  TFlags = set of TFlag;

  TDeep = class(TPersistent)
  private
    FLevel: Integer;
    FNext: TDeep;
  public
    destructor Destroy; override;
  published
    property Level: Integer read FLevel write FLevel;
    property Next: TDeep read FNext;
  end;

  TSub = class(TPersistent)
  private
    FSize: Integer;
    FBold: Boolean;
    FText: string;
  published
    property Size: Integer read FSize write FSize;
    property Bold: Boolean read FBold write FBold;
    property Text: string read FText write FText;
  end;

  TItem = class(TComponent)
  private
    FCaption: string;
    FVisible: Boolean;
    FKind: TKind;
    FFlags: TFlags;
    FWidth: Integer;
    FRatio: Double;
    FBig: Int64;
    FSub: TSub;
    FDeep: TDeep;
    FLink: TComponent;
    FValue: Variant;
    FOnClick: TNotifyEvent;
    FReadOnlyProp: Integer;
    FCh: Char;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Caption: string read FCaption write FCaption;
    property Visible: Boolean read FVisible write FVisible;
    property Kind: TKind read FKind write FKind;
    property Flags: TFlags read FFlags write FFlags;
    property Width: Integer read FWidth write FWidth;
    property Ratio: Double read FRatio write FRatio;
    property Big: Int64 read FBig write FBig;
    property Ch: Char read FCh write FCh;
    property Sub: TSub read FSub;
    property Deep: TDeep read FDeep;
    property Link: TComponent read FLink write FLink;
    property Value: Variant read FValue write FValue;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property ReadOnlyProp: Integer read FReadOnlyProp;
  end;

  TRoot = class(TComponent)
  private
    FCaption: string;
  published
    property Caption: string read FCaption write FCaption;
  end;

destructor TDeep.Destroy;
begin
  FNext.Free;
  inherited;
end;

constructor TItem.Create(AOwner: TComponent);
var
  D: TDeep;
  i: Integer;
begin
  inherited Create(AOwner);
  FSub := TSub.Create;
  FSub.Size := 10;
  FDeep := TDeep.Create;
  D := FDeep;
  for i := 1 to 6 do   // Deep.Next.Next.Next... derinlik siniri icin
  begin
    D.FLevel := i;
    D.FNext := TDeep.Create;
    D := D.FNext;
  end;
  FVisible := True;
  FRatio := 1.5;
  FCh := 'A';
  FValue := 42;
end;

destructor TItem.Destroy;
begin
  FDeep.Free;
  FSub.Free;
  inherited;
end;

function Agac: TRoot;
var
  B, E, U: TItem;
begin
  Result := TRoot.Create(nil);
  Result.Caption := 'Kasa';
  B := TItem.Create(Result);
  B.Name := 'btnKaydet';
  B.Caption := 'Kaydet';
  E := TItem.Create(Result);
  E.Name := 'edtAd';
  E.Caption := 'Ad';
  B.Link := E;
  U := TItem.Create(Result);   // adsiz: goruntuye girmez
  U.Caption := 'adsiz';
end;

procedure Testler;
var
  R, R2: TRoot;
  S0, S1, D, D2, M: TRadPropSnapshot;
  V, LCls: string;
  LJson: RawUtf8;
  LWarns: TList<string>;
  LSw: TStopwatch;
  i, N: Integer;
begin
  LWarns := TList<string>.Create;
  R := Agac;
  try
    S0 := TRadPropSnapshot.Capture(R);
    try
      Kontrol('O01a Form.Caption', S0.TryGetValue('Form.Caption', V) and (V = 'Kasa'));
      Kontrol('O01b alt nesne', S0.TryGetValue('btnKaydet.Sub.Size', V) and (V = '10'));
      Kontrol('O01c baslangic degerleri', S0.TryGetValue('btnKaydet.Visible', V) and (V = 'True') and
        S0.TryGetValue('btnKaydet.Kind', V) and (V = 'kA') and S0.TryGetValue('btnKaydet.Flags', V) and (V = '[]') and
        S0.TryGetValue('btnKaydet.Ratio', V) and (V = '1.5') and S0.TryGetValue('btnKaydet.Ch', V) and (V = '#65'));
      Kontrol('O01d bilesen basvurusu = ad', S0.TryGetValue('btnKaydet.Link', V) and (V = 'edtAd') and
        S0.TryGetValue('edtAd.Link', V) and (V = ''));
      Kontrol('O01e adsiz/olay/salt okunur/Variant/Name/Tag yok', not S0.Values.ContainsKey('btnKaydet.OnClick') and
        not S0.Values.ContainsKey('btnKaydet.ReadOnlyProp') and not S0.Values.ContainsKey('btnKaydet.Value') and
        not S0.Values.ContainsKey('btnKaydet.Name') and not S0.Values.ContainsKey('btnKaydet.Tag'));
      N := 0;
      for V in S0.Keys do if V.StartsWith('btnKaydet.Deep') then Inc(N);
      Kontrol('O01f derinlik siniri 4', S0.Values.ContainsKey('btnKaydet.Deep.Next.Next.Level') and
        not S0.Values.ContainsKey('btnKaydet.Deep.Next.Next.Next.Level'), IntToStr(N));
      for V in S0.Keys do
        if V.Contains('adsiz') then Kontrol('O01g adsiz bilesen', False, V);

      (R.FindComponent('btnKaydet') as TItem).Caption := 'Kaydet*';
      (R.FindComponent('btnKaydet') as TItem).Sub.Bold := True;
      (R.FindComponent('btnKaydet') as TItem).Flags := [fA, fC];
      (R.FindComponent('edtAd') as TItem).Link := R.FindComponent('btnKaydet');
      (R.FindComponent('edtAd') as TItem).Visible := False;
      (R.FindComponent('edtAd') as TItem).Visible := True;   // geri alindi: farkta olmamali
      R.Caption := 'Kasa (sube)';
      S1 := TRadPropSnapshot.Capture(R);
      try
        D := TRadPropSnapshot.Diff(S0, S1);
        try
          Kontrol('O02 fark tam 5 anahtar', D.Count = 5, IntToStr(D.Count));
          Kontrol('O02b fark degerleri', D.TryGetValue('btnKaydet.Caption', V) and (V = 'Kaydet*') and
            D.TryGetValue('btnKaydet.Sub.Bold', V) and (V = 'True') and D.TryGetValue('btnKaydet.Flags', V) and (V = '[fA,fC]') and
            D.TryGetValue('edtAd.Link', V) and (V = 'btnKaydet') and D.TryGetValue('Form.Caption', V) and (V = 'Kasa (sube)'));
          Kontrol('O03 geri alinan farkta yok', not D.Values.ContainsKey('edtAd.Visible'));

          LJson := D.ToJson('Tkasa_k');
          D2 := TRadPropSnapshot.FromJson(LJson, LCls);
          try
            Kontrol('O04 JSON gidis-donus', (LCls = 'Tkasa_k') and (D2.Count = 5) and D2.TryGetValue('btnKaydet.Caption', V) and
              (V = 'Kaydet*') and (D2.Keys[0] = D.Keys[0]), string(LJson));
            Kontrol('O04b Turkce karakter', (D2.TryGetValue('Form.Caption', V)) and (V = 'Kasa (sube)'));
            // Turkce metinle ayri deneme
            D2.SetValue('edtAd.Caption', 'Şube ğüİ');
            LJson := D2.ToJson('Tkasa_k');
          finally
            D2.Free;
          end;
          D2 := TRadPropSnapshot.FromJson(LJson, LCls);
          try
            Kontrol('O04c Turkce gidis-donus', D2.TryGetValue('edtAd.Caption', V) and (V = 'Şube ğüİ'));
            R2 := Agac;
            try
              N := D2.Apply(R2, procedure(const AKey, AMsg: string) begin LWarns.Add(AKey + ': ' + AMsg); end);
              Kontrol('O05 Apply', (N = 6) and (LWarns.Count = 0) and ((R2.FindComponent('btnKaydet') as TItem).Caption = 'Kaydet*') and
                (R2.FindComponent('btnKaydet') as TItem).Sub.Bold and ((R2.FindComponent('btnKaydet') as TItem).Flags = [fA, fC]) and
                ((R2.FindComponent('edtAd') as TItem).Link = R2.FindComponent('btnKaydet')) and (R2.Caption = 'Kasa (sube)') and
                ((R2.FindComponent('edtAd') as TItem).Caption = 'Şube ğüİ'), IntToStr(N) + ' ' + string.Join(';', LWarns.ToArray));
              // bulunamayan bilesen, ozellik, uyumsuz deger, bilinmeyen basvuru
              LWarns.Clear;
              D2.SetValue('yok.Caption', 'x');
              D2.SetValue('btnKaydet.Yok', 'x');
              D2.SetValue('btnKaydet.Width', 'abc');
              D2.SetValue('btnKaydet.Kind', 'kZ');
              D2.SetValue('btnKaydet.Link', 'yokBilesen');
              D2.SetValue('btnKaydet.OnClick', 'x');
              D2.SetValue('btnKaydet.Ratio', '2.25');
              N := D2.Apply(R2, procedure(const AKey, AMsg: string) begin LWarns.Add(AKey); end);
              Kontrol('O06 uyari + devam', (N = 7) and (LWarns.Count = 6) and (LWarns.IndexOf('yok.Caption') >= 0) and
                (LWarns.IndexOf('btnKaydet.Yok') >= 0) and (LWarns.IndexOf('btnKaydet.Width') >= 0) and
                (LWarns.IndexOf('btnKaydet.Kind') >= 0) and (LWarns.IndexOf('btnKaydet.Link') >= 0) and
                (LWarns.IndexOf('btnKaydet.OnClick') >= 0) and ((R2.FindComponent('btnKaydet') as TItem).Ratio = 2.25),
                IntToStr(N) + ' ' + string.Join(';', LWarns.ToArray));
              Kontrol('O06b uyari nil kabul', D2.Apply(R2, nil) = 7);
            finally
              R2.Free;
            end;
          finally
            D2.Free;
          end;

          M := TRadPropSnapshot.Create;
          try
            M.SetValue('btnKaydet.Caption', 'Eski');
            M.SetValue('edtAd.Width', '7');
            M.Merge(D);
            Kontrol('O07 Merge: diger kazanir, yeni sona', (M.Count = 6) and M.TryGetValue('btnKaydet.Caption', V) and (V = 'Kaydet*') and
              (M.Keys[0] = 'btnKaydet.Caption') and (M.Keys[1] = 'edtAd.Width'));
            M.Remove('edtAd.Width');
            Kontrol('O07b Remove', (M.Count = 5) and not M.Values.ContainsKey('edtAd.Width'));
          finally
            M.Free;
          end;
        finally
          D.Free;
        end;
      finally
        S1.Free;
      end;
    finally
      S0.Free;
    end;
  finally
    R.Free;
  end;

  // bicim hatalari
  try
    TRadPropSnapshot.FromJson('[1,2]', LCls).Free;
    Kontrol('O08 dizi JSON hata', False);
  except
    on E: ERadOverrideFormat do Kontrol('O08 dizi JSON hata', True);
  end;
  try
    TRadPropSnapshot.FromJson('{"format":9,"props":{}}', LCls).Free;
    Kontrol('O08b surum hatasi', False);
  except
    on E: ERadOverrideFormat do Kontrol('O08b surum hatasi', True);
  end;
  D := TRadPropSnapshot.FromJson('{"format":1,"form":"T"}', LCls);
  try
    Kontrol('O08c props yok = bos', D.Count = 0);
  finally
    D.Free;
  end;

  // olcum: 200 adli bilesen
  R := TRoot.Create(nil);
  try
    for i := 1 to 200 do TItem.Create(R).Name := 'c' + IntToStr(i);
    LSw := TStopwatch.StartNew;
    S0 := TRadPropSnapshot.Capture(R);
    LSw.Stop;
    Writeln(Format('  olcum: 200 bilesen, %d anahtar, Capture %d ms', [S0.Count, LSw.ElapsedMilliseconds]));
    Kontrol('O09 Capture < 50 ms', LSw.ElapsedMilliseconds < 50, IntToStr(LSw.ElapsedMilliseconds));
    S0.Free;
  finally
    R.Free;
  end;
  LWarns.Free;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Testler;
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('[ISTISNA] ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then ExitCode := 1;
end.
