unit Core.Form;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,rtti, System.Actions, Vcl.ActnList
  ,Help.vcl
  ;


type

  TCoreForm = class(TRadFormBase)
  protected
    procedure ClientWndProc(var Message: TMessage); override;
  public
  end;


implementation
{$R *.dfm}

{ TB_Form }




const
  { MDICLIENT'in kendini kurarken ve yerlesimini yeniden hesaplarken
    gonderdigi IC yapilandirma mesaji. Windows SDK'da BELGELENMEMISTIR ve
    Winapi.Messages de onu tanimlamaz - o yuzden kendi adimizla tutuluyor.
    Cikplak $3F yazmak, ileride bu satiri okuyanin neye baktigini
    bilememesi demekti. }
  WM_MDICLIENT_FRAMECALC = $3F;

{ MDI istemci alaninin cukur cercevesini kaldirir.

  Bir MDI ana formunun ic bolgesi formun kendi penceresi DEGILDIR: Windows'un
  "MDICLIENT" sistem pencere sinifidir, VCL onu ClientHandle olarak tutar ve
  varsayilan olarak WS_EX_CLIENTEDGE ile - ice gomuk 3B kenarlikla - yaratir.
  ClientWndProc iste O pencereye giden mesajlari gorur. }
procedure TCoreForm.ClientWndProc(var Message: TMessage);
var
  { NativeInt, DWORD DEGIL: Get/SetWindowLongPtr Win64'te LONG_PTR (64 bit)
    kullanir. DWORD'e almak sessiz bir daralmadir - GWL_EXSTYLE degeri 32
    bite sigdigi icin pratikte calisiyordu, ama tip yanlisti ve derleyici
    bunun icin uyari uretmiyor. }
  ExStyle: NativeInt;
begin
  if (FormStyle = fsMDIForm) and (Message.Msg = WM_MDICLIENT_FRAMECALC) then
  begin
    { ClientHandle 0 olabilir (pencere henuz yaratilmamis ya da yok
      edilmis). Korumasiz GetWindowLongPtr(0, ...) anlamsiz deger dondurur
      ve ardindaki SetWindowPos gecersiz tutamaca yazmaya calisir. }
    if ClientHandle <> 0 then
    begin
      ExStyle := GetWindowLongPtr(ClientHandle, GWL_EXSTYLE);

      { Yalnizca stil GERCEKTEN varsa dokun. Kosulsuz yazmak her yerlesim
        hesabinda bir SetWindowPos tetikliyordu; SWP_FRAMECHANGED cerceveyi
        yeniden cizdirdigi icin bu gorunur titremeye yol acar. }
      if (ExStyle and WS_EX_CLIENTEDGE) <> 0 then
      begin
        SetWindowLongPtr(ClientHandle, GWL_EXSTYLE, ExStyle and not WS_EX_CLIENTEDGE);

        { SWP_FRAMECHANGED sart: stil degisikligi ancak bu bayrakla pencereye
          uygulanir. Digerleri "konumu/boyutu/z-sirasini degistirme" demek. }
        SetWindowPos(ClientHandle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or
          SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER);
      end;
    end;

    { $3F BURADA TUKETILIR - inherited'a GITMEZ, ve bu bilincli bir karardir.

      "Her yolda inherited cagrilmali" diye degistirmeyi denedik; sonuc
      OLCULDU: 30 saniyede 796.240 ClientWndProc cagrisi, %100 CPU, kilitli
      surec. Sebep geri besleme dongusu - inherited MDICLIENT'in kendi
      yordamina gider, o da WS_EX_CLIENTEDGE'i GERI KOYAR; biz tekrar
      sileriz, SWP_FRAMECHANGED yeni bir $3F dogurur, bastan baslar.
      Stili "zaten temizse dokunma" korumasi bunu engellemez, cunku her
      turda inherited onu yeniden setler.

      Yani bu Exit bir ihmal degil, donguyu kiran seyin ta kendisi.
      Kaldirmadan once rad_coreform testini calistirin: 08 numarali iddia
      tam bu firtinayi yakalar. }
    Exit;
  end;

  inherited;
end;






end.
