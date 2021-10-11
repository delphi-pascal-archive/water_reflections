//  Unit Reflets (like Lake applet) - Don't forget Jpeg unit
//  Jean Yves Quéinec 28/10/2000 - j.y.q@wanadoo.fr
unit Ureflets;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, Buttons, jpeg, ExtDlgs;
type
  TForm1 = class(TForm)
    Panel1: TPanel;
    Btopen: TButton;
    Panel2: TPanel;
    PaintBox1: TPaintBox;
    Timer1: TTimer;
    Edit1: TEdit;
    UpDown1: TUpDown;
    Label1: TLabel;
    RadioGroup1: TRadioGroup;
    Button1: TButton;
    Label2: TLabel;
    Label3: TLabel;
    CheckBox1: TCheckBox;
    Edit2: TEdit;
    Label5: TLabel;
    UpDown2: TUpDown;
    OpenPictureDialog1: TOpenPictureDialog;
    Image1: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtQuitterClick(Sender: TObject);
    procedure BtopenClick(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure UpDown1Click(Sender: TObject; Button: TUDBtnType);
    procedure FormResize(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RadioGroup1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure UpDown2Click(Sender: TObject; Button: TUDBtnType);
  private
    procedure Initmirror;
    procedure mirror(ph : integer);
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}

type
  TRGBArray = ARRAY[0..0] OF TRGBTriple;   // bitmap pixel (API windows)
  pRGBArray = ^TRGBArray;     // pointer to 3 bytes pixel(24 bits)

Var
  limitebmp2 : integer;   // adjustable mirror position
  savebmp2H  : integer;   // Bmp2 height for clic

  //   bitmap loaded (bmp1)
  //   +---------------+        bmp2             lake bmp3
  //   |               |    +-----------+       +---------+
  //   |               |    |   top     |       |  bottom |
  //   |               |===>|           | ===>  |         |
  //   |               |    |           |       +---------+
  //   |               |    |           |           ||
  //   |               |    |   bottom  |           ||
  //   |               |    +-----------+           ||
  //   |               |    \  mirror   \  Bmp4 <===//
  //   +---------------+    /           /
  //                        +-----------+
  bmp1 : Tbitmap;   // bitmap read
  bmp2 : Tbitmap;   // Bitmap loaded (on top of  paintbox1)
  bmp3 : Tbitmap;   // Bitmap (vertical mirror)
  bmp4 : Tbitmap;   // bitmap lake (paintbox bottom)
  // scanlines arrays for optimisation
  Tscan3 : array[0..1024] of pRGBArray;
  Tscan4 : array[0..1024] of PRGBArray;
  // Frames : numer of lake sector   Phase = current frame
  Frames : integer;
  Phase  : integer;
  stop : boolean;
  // calculated sinus (degrees)
  zsin : array[0..360] of single;

procedure TForm1.FormCreate(Sender: TObject);
var
  i : integer;
  a : single;
begin
  timer1.enabled := false;
  phase  := 0;
  for i := 0 to 360 do
  begin
    a := (i * 180) / pi;
    zsin[i] := sin(i*180);
  end;
  bmp1 := tbitmap.create; bmp1.width  := 8;  Bmp1.height := 8;
  bmp2 := Tbitmap.create; bmp2.width  := 8;  Bmp2.height := 8;
  bmp3 := tbitmap.create; bmp3.width  := 8;  Bmp3.height := 8;
  bmp4 := Tbitmap.create; bmp4.width  := 8;  Bmp4.height := 8;
end;

procedure TForm1.FormActivate(Sender: TObject);
begin
  btopenclick(sender);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  bmp1.free;
  bmp2.free;
  bmp3.free;
  bmp4.free;
end;

procedure TForm1.BtQuitterClick(Sender: TObject);
begin

end;

//---------  Buttons
procedure TForm1.BtopenClick(Sender: TObject);
begin
  stop := true;
  button1.caption := 'Start';
  timer1.enabled := false;
  If openpictureDialog1.execute then
  begin
    image1.Picture.LoadFromFile(OpenPictureDialog1.FileName);
    bmp1.width := image1.picture.graphic.width;
    bmp1.height := image1.picture.graphic.height;
    bmp1.pixelformat := pf24bit;
    bmp1.canvas.draw(0,0,image1.picture.graphic);
    limitebmp2 := 0;
    initmirror;
    stop := false;
    button1.caption := 'Stop';
    timer1.enabled := true;
  end;
end;

procedure Tform1.Initmirror;
var
  i : integer;
  h : integer;            // Max Form height
  k1, k2 : integer;       // lake parameters
begin
  frames := updown2.position;
  case radiogroup1.itemindex of
  0 : begin k1 := 1; k2 := 3; end;
  1 : begin k1 := 1; k2 := 2; end;
  2 : begin k1 := 2; k2 := 3; end;
  3 : begin k1 := 4; k2 := 5; end;
  end;
  //  Bmp2 must fit in client form area
  bmp2.free;
  bmp2 := tbitmap.create;
  h := panel2.height - 16;
  If (bmp1.height*(k1+k2)) div k2 > h then
  begin
    bmp2.height := (bmp1.height * h) div ((bmp1.height*(k1+k2)) div k2);
    bmp2.width  := (bmp1.width  * h) div ((bmp1.height*(k1+k2)) div k2);
  end
  else
  begin
    bmp2.width := bmp1.width;
    bmp2.height := bmp1.height;
  end;
  If limitebmp2 = 0 then limitebmp2 := bmp2.height  // 0 => height initialize
  else
    limitebmp2 := (limitebmp2*bmp2.height) div savebmp2H;
  savebmp2H := bmp2.height;      // clic limits
  bmp2.canvas.stretchdraw(rect(0,0,bmp2.width, bmp2.height), bmp1);
  bmp2.height := limitebmp2;
  bmp3.free;
  Bmp3 := Tbitmap.create;
  bmp3.width  := Bmp2.width;
  // decrease height to simulate point of view
  bmp3.height := (Bmp2.height *k1) div k2;
  Bmp3.pixelformat := pf24bit;       // 24 bits per pixel
  // vertical mirror
  Bmp3.Canvas.stretchDraw(Rect(0, Bmp2.height-1,Bmp2.width,-1), bmp2);
  bmp4.free;
  Bmp4 := Tbitmap.create;
  bmp4.width  := bmp3.width;
  bmp4.height := bmp3.height;
  Bmp4.pixelformat := pf24bit;
  bmp4.canvas.draw(0,0,bmp3);

  paintbox1.width  := bmp3.width;
  paintbox1.height := limitebmp2+ (bmp2.height*k1) div k2;
  Paintbox1.left := (panel2.width - paintbox1.width) div 2;
  Paintbox1.top  := (panel2.height - paintbox1.height) div 2;
  Paintbox1.canvas.draw(0,0,bmp2);
  Paintbox1.canvas.draw(0, limitebmp2, bmp4);
  //  scanline pointers optimization
  For i := 0 to bmp3.height-1 do
  begin
    Tscan3[i] := bmp3.scanline[i];
    Tscan4[i] := bmp4.scanline[i];
  end;
end;

procedure Tform1.mirror(ph : integer);
var
  h : single;          // bitmap height
  a : single;          // angle in radians
  dy :  single;        // compute with reals
  y3 :  integer;       // pixel source
  x4, y4 :  integer;   // pixel destination
  f : single;          // frames
  p : single;          // phase
  k0 : single;
  k1 : single;
  k2 : single;
  za : integer;
begin
  // phase (0..Frames-1) in radians for sinus variation
  p := ph;                  // phase
  h := bmp4.height;         // height into real
  f := frames;              // frames into real
  a := (2*pi*p) / f;
  k0 := 16;
  k1 := h/k0;
  k2 := k0*1.5;
  for y4 := 0 to bmp4.height -1 do   // from destination image
  begin
    dy := y4;  // en réel
    y3 := trunc( k1*(dy+k2) * sin((h/k1*(h-dy))/(dy+1)+a)/h );
    y3 := y3+y4;
    IF checkbox1.checked then   // blur option
    begin
      for x4 := 0 to bmp4.width-1 do
      begin
       // check bitmap limits
        if (y3 > 0) and (y3 < Bmp3.height) and ((x4+y4) mod 2 = 0) then
        Tscan4[y4,x4] := Tscan3[y3, x4]  else Tscan4[y4,x4] := Tscan3[y4, x4];
      end;
    end
    else
    begin
      for x4 := 0 to bmp4.width-1 do
      begin
        if (y3 > 0) and (y3 < Bmp3.height) then
        Tscan4[y4,x4] := Tscan3[y3, x4] else Tscan4[y4,x4] := Tscan3[y4, x4];
      end;
    end;
  end;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
begin
  with paintbox1.canvas do
  begin
    draw(0,0,bmp2);
    draw(0, bmp2.height-1, bmp4);
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  inc(phase);
  if phase >= frames then phase := 0;
  mirror(phase);
  paintbox1.canvas.draw(0, limitebmp2,bmp4);
end;

procedure TForm1.UpDown1Click(Sender: TObject; Button: TUDBtnType);
begin
  timer1.interval := updown1.position;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  timer1.enabled := false;
  limitebmp2 := 0;
  initmirror;
  IF not stop then timer1.enabled := true;
end;

procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  timer1.enabled := false;
  if y > savebmp2h then limitebmp2 := 0 else limitebmp2 := y;
  initmirror;
  IF not stop then timer1.enabled := true;
end;

procedure TForm1.RadioGroup1Click(Sender: TObject);
begin
  timer1.enabled := false;
  initmirror;
  IF not stop then timer1.enabled := true;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  If Stop then
  begin
    stop := false;
    button1.caption := 'Stop';
    timer1.enabled := true;
  end
  else
  begin
    stop := true;
    button1.caption := 'Start';
    timer1.enabled := false;
  end;
end;

procedure TForm1.UpDown2Click(Sender: TObject; Button: TUDBtnType);
begin
  timer1.enabled := false;
  initmirror;
  IF not stop then timer1.enabled := true;
end;

end.
