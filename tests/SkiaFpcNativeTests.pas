{ Integration tests using real LCL/GDI resources and the native Skia DLL. }
program SkiaFpcNativeTests;
{$mode delphiunicode}{$codepage utf8}

uses Interfaces, Classes, SysUtils, Windows, Types, Math, System.UITypes,
  Vcl.Graphics, System.Skia, Vcl.Graphics.Skia, Vcl.GraphUtil.MetafileParser, SkiaPublicTypesTests;
var Passed,Failed:Integer;
function RectF(L,T,R,B:Single):TRectF;
begin Result.Left:=L;Result.Top:=T;Result.Right:=R;Result.Bottom:=B;end;
procedure Check(Value:Boolean;const Name:string);
begin
  if Value then begin Inc(Passed);Writeln('PASS: ',Name);end
  else begin Inc(Failed);Writeln('FAIL: ',Name);end;
end;
function HasInk(Canvas:TSkiaBitmapCanvas):Boolean;
var Pixels:TArray<TAlphaColor>;Image:ISkImage;I:Integer;
begin
  Image:=Canvas.Snapshot;SetLength(Pixels,Image.Width*Image.Height);
  if not Image.ReadPixels(TSkImageInfo.Create(Image.Width,Image.Height,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),Image.Width*4) then raise Exception.Create('Cannot read native pixels');
  Result:=False;for I:=0 to High(Pixels) do if Pixels[I] and $FFFFFF<>0 then Exit(True);
end;
procedure TestRops;
const Tables:array[TPenMode] of Byte=(0,15,10,5,12,3,13,4,11,2,14,1,8,7,6,9);
var Canvas,Source:TSkiaBitmapCanvas;Mode:TPenMode;Table,Bit,I:Integer;P,D,S,Expected:Cardinal;
begin
  Canvas:=TSkiaBitmapCanvas.Create(20,20);Source:=TSkiaBitmapCanvas.Create(20,20);
  try
    D:=$0033CC5A;S:=$00A55AC3;P:=$00F00FA5;
    Source.Brush.Color:=TColor(S);Source.FillRect(Rect(0,0,20,20));
    for Mode:=Low(TPenMode) to High(TPenMode) do begin
      Expected:=0;
      for Bit:=0 to 23 do begin I:=Integer(((S shr Bit) and 1)*2+((D shr Bit) and 1));
        if Tables[Mode] and (1 shl I)<>0 then Expected:=Expected or (Cardinal(1) shl Bit);end;
      Canvas.Brush.Color:=TColor(D);Canvas.FillRect(Rect(0,0,20,20));
      Canvas.Pen.Color:=TColor(S);Canvas.Pen.Width:=4;Canvas.Pen.Mode:=Mode;
      Canvas.MoveTo(2,10);Canvas.LineTo(18,10);Canvas.Pen.Mode:=pmCopy;
      Check(Cardinal(ColorToRGB(Canvas.Pixels[10,10]))=Expected,'native ROP2 '+IntToStr(Ord(Mode)));
    end;
    for Table:=0 to 255 do begin
      Expected:=0;
      for Bit:=0 to 23 do begin I:=Integer(((P shr Bit) and 1)*4+((S shr Bit) and 1)*2+((D shr Bit) and 1));
        if Table and (1 shl I)<>0 then Expected:=Expected or (Cardinal(1) shl Bit);end;
      Canvas.CopyMode:=cmSrcCopy;Canvas.Brush.Color:=TColor(D);Canvas.FillRect(Rect(0,0,20,20));
      Canvas.Brush.Color:=TColor(P);Canvas.CopyMode:=TCopyMode(Cardinal(Table) shl 16);
      Canvas.BitBlt(0,0,20,20,Source,0,0);
      Check(Cardinal(ColorToRGB(Canvas.Pixels[10,10]))=Expected,'native ROP3 '+IntToStr(Table));
    end;
  finally Source.Free;Canvas.Free;end;
end;
procedure TestNativePathsAndState;
var Canvas:TSkiaBitmapCanvas;Path:ISkPathBuilder;State:Integer;Origin:TPoint;
begin
  Canvas:=TSkiaBitmapCanvas.Create(80,80);
  try
    Path:=TSkPathBuilder.Create;Path.AddOval(RectF(10,10,70,70));
    State:=Canvas.SaveState;
    try
      Canvas.SetClipPath(Path.Snapshot);Canvas.Brush.Color:=clRed;Canvas.FillRect(Rect(0,0,80,80));
      Check(Canvas.Pixels[40,40]=clRed,'native curved clip interior');
      Check(Canvas.Pixels[11,11]=clBlack,'native curved clip excludes bbox corner');
      Canvas.TranslateTransform(15,20);Canvas.Brush.Alpha:=77;
    finally Canvas.RestoreState(State);end;
    Origin:=Canvas.LPToDP(Point(0,0));
    Check((Origin.X=0) and (Origin.Y=0) and (Canvas.Brush.Alpha=255),'native state restoration');
    Canvas.Brush.Color:=clBlack;Canvas.FillRect(Rect(0,0,80,80));Canvas.Brush.Style:=bsClear;
    Canvas.Pen.Color:=clWhite;Canvas.Pen.Width:=5;Canvas.PolyBezier([Point(5,60),Point(10,5),Point(60,5),Point(75,60)]);
    Check(HasInk(Canvas),'native cubic path stroke has visible pixels');
    Canvas.Brush.Style:=bsSolid;Canvas.Brush.Color:=clBlack;Canvas.FillRect(Rect(0,0,80,80));
    Canvas.Pen.Color:=clWhite;Canvas.Arc(5,5,75,75,75,40,5,40);
    Check(HasInk(Canvas),'native arc stroke has visible pixels');
  finally Canvas.Free;end;
end;
procedure TestNativeText;
var Canvas:TSkiaBitmapCanvas;LF:TLogFontW;Glyphs:TArray<TGdiShapedGlyph>;Key:string;R:TRect;Text:string;Face:ISkTypeface;
begin
  Canvas:=TSkiaBitmapCanvas.Create(300,150);
  try
    Canvas.Font.Name:='Times New Roman';Canvas.Font.Height:=-30;Canvas.Font.Color:=clWhite;
    Canvas.Brush.Style:=bsClear;Canvas.TextToCurves:=True;
    Check(Canvas.TextWidth('AV')<Canvas.TextWidth('A')+Canvas.TextWidth('V'),'native kerning');
    Canvas.Font.Name:='Arial';Canvas.FontManager.GetLogFont(Canvas.Font,LF);Key:=Canvas.FontManager.FontKey(Canvas.Font);
    Canvas.GlyphCache.ShapeText(LF,Key,Canvas.GlyphCache.GetEmSquare(LF,Key),#$0644#$0627,Glyphs);
    Check((Length(Glyphs)>0) and (Length(Glyphs)<2),'native Arabic lam-alef shaping');
    Canvas.TextOut(10,10,'AVATAR '+#$0633#$0644#$0627#$0645);
    Check(HasInk(Canvas),'native shaped text has visible outlines');
    R:=Rect(0,0,100,150);Text:='A paragraph with word wrapping';Canvas.TextRect(R,Text,[tfWordBreak,tfCalcRect]);
    Check(R.Height>Canvas.TextHeight('A'),'native formatted text wraps');
    Face:=Canvas.FontManager.LoadTypefaceFromFile(ParamStr(1));Canvas.FontManager.RegisterTypeface('PrivateFixture',Face);
    Canvas.Font.Name:='PrivateFixture';Canvas.Font.Height:=-30;
    Check(Canvas.TextWidth('AV')=32,'native private font kerning uses fixture design units');
  finally Canvas.Free;end;
end;
procedure TestNativeRecordingAndBitmap;
var Recorder:TSkiaMetafileCanvas;Picture:ISkPicture;Canvas:TSkiaBitmapCanvas;Bitmap:TBitmap;
  Stream:TMemoryStream;SVG:ISkCanvas;Bytes:AnsiString;OutputDir:string;
begin
  OutputDir:=ExtractFilePath(ParamStr(0));Recorder:=TSkiaMetafileCanvas.Create(80,80);
  try Recorder.Brush.Color:=clBlue;Recorder.Ellipse(10,10,70,70);Picture:=Recorder.FinishRecording;finally Recorder.Free;end;
  Canvas:=TSkiaBitmapCanvas.Create(80,80);Bitmap:=TBitmap.Create;Stream:=TMemoryStream.Create;
  try
    Picture.Playback(Canvas.SkCanvas);Check(Canvas.Pixels[40,40]=clBlue,'native picture playback');
    Canvas.Flush(Bitmap);Bitmap.SaveToFile(OutputDir+'native-test.bmp');
    Check(Bitmap.Canvas.Pixels[40,40]=clBlue,'native BMP contains blue center');
    Picture.SerializeToStream(Stream);SetLength(Bytes,8);Stream.Position:=0;Stream.ReadBuffer(Bytes[1],8);
    Check(Bytes='skiapict','native SKP signature');Stream.Clear;
    SVG:=TSkSVGCanvas.Make(RectF(0,0,80,80),Stream);Picture.Playback(SVG);SVG:=nil;
    SetLength(Bytes,Stream.Size);Stream.Position:=0;Stream.ReadBuffer(Bytes[1],Length(Bytes));
    Check((Pos('<svg',Bytes)>0) and ((Pos('<ellipse',Bytes)>0) or (Pos('<path',Bytes)>0)),'native SVG geometry');
  finally SVG:=nil;Stream.Free;Bitmap.Free;Canvas.Free;end;
end;
{$I SkiaBltTests.inc}
{$I SkiaTextPathTests.inc}
{$I SkiaUnicodeTests.inc}
{$I SkiaThreadTests.inc}
{$I SkiaMetafileTests.inc}
{$I SkiaImageCodecTests.inc}
begin
  Writeln('Native Skia4Delphi ',TSkVersion.ToString);
  TestNativePngDecoding;
  Check(TestPublicGraphicsTypes,'public VCL/Skia aliases compile and render without extra graphics units');
  TestEmfPlayback;
  TestTextOnPath;
  TestThreadSafety;
  TestUnicodeTextHelpers;
  TestCanvasApiGuards;
  T_BltNativeSources;
  TestRops;
  TestNativePathsAndState;
  TestNativeText;
  TestNativeRecordingAndBitmap;
  Writeln('Native FPC/Skia: ',Passed,' passed; ',Failed,' failed');
  if Failed<>0 then Halt(1);
end.





