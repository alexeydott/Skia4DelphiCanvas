type
  TInputValidationLargeStream = class(TMemoryStream)
  protected
    function GetSize:Int64; override;
  end;
  TInputValidationFault = class
    procedure Change(Sender:TObject);
  end;
function TInputValidationLargeStream.GetSize:Int64;
begin
  Result:=Int64(High(Integer))+1;
end;

procedure TInputValidationFault.Change(Sender:TObject);
begin
  raise EAbort.Create('Injected resource observer failure');
end;

{ Shared Delphi/FPC/Windows/Linux input-validation regressions. }
procedure TestInputRopAlpha;
var Canvas,Source:TSkiaBitmapCanvas;Image:ISkImage;Pixels:TArray<TAlphaColor>;I,Bad,Changed:Integer;
begin
  Canvas:=TSkiaBitmapCanvas.Create(16,16);Source:=TSkiaBitmapCanvas.Create(16,16);
  try
    Canvas.SkCanvas.Clear($800000FF);
    Canvas.DrawFocusRect(Rect(2,2,14,14));Image:=Canvas.Snapshot;SetLength(Pixels,256);
    Check(Image.ReadPixels(TSkImageInfo.Create(16,16,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),64),
      'Input validation: destination-only ROP pixels readable');
    Bad:=0;Changed:=0;
    for I:=0 to High(Pixels) do
    begin
      if Abs(Integer(Pixels[I] shr 24)-128)>1 then Inc(Bad);
      if Pixels[I] and $FFFFFF<>$0000FF then Inc(Changed);
    end;
    Check((Bad=0) and (Changed>0),'Input validation: focus inversion changes RGB while preserving destination alpha');
    Canvas.SkCanvas.Clear(0);Canvas.Brush.Color:=clRed;Canvas.Brush.Alpha:=64;
    Source.Brush.Color:=clWhite;Source.FillRect(Rect(0,0,16,16));
    Canvas.CopyMode:=$00F00021;Canvas.BitBlt(0,0,16,16,Source,0,0);
    Image:=Canvas.Snapshot;
    Image.ReadPixels(TSkImageInfo.Create(16,16,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),64);
    Check(Abs(Integer(Pixels[8*16+8] shr 24)-64)<=1,'Input validation: PATCOPY preserves pattern opacity');
  finally Source.Free;Canvas.Free;end;
end;

procedure TestTiledRasterOperations;
const Rops:array[0..6] of Byte=($55,$F0,$0F,$CC,$66,$5A,$FB);
var Canvas,Reference,Source:TSkiaBitmapCanvas;Pattern:TBitmap;
  LeftImage,RightImage:ISkImage;LeftPixels,RightPixels:TArray<TAlphaColor>;
  M:TMatrix;TransformIndex,PatternIndex,ClipIndex,RopIndex,Rop,I:Integer;Same:Boolean;
  procedure Render(Target:TSkiaBitmapCanvas; FullFrame:Boolean);
  begin
    Target.ResetClip;Target.ResetWorldTransform;Target.SkCanvas.Clear($A04070C0);
    Target.Brush.Alpha:=192;Target.Brush.Color:=clLime;Target.Brush.Pattern:=nil;
    if PatternIndex=0 then Target.Brush.Style:=bsDiagCross
    else begin Target.Brush.Style:=bsSolid;Target.Brush.Pattern:=Pattern;end;
    if ClipIndex<>0 then
    begin Target.SetClipRect(Rect(8,8,55,40));Target.ExcludeClipRect(Rect(30,20,33,24));end;
    Target.SetWorldTransform(M);Target.CopyMode:=TCopyMode(Cardinal(Rop) shl 16);
    if FullFrame then
      Target.PlgBlt([Point(13,17),Point(21,17),Point(13,25)],Source,0,0,8,8)
    else
      Target.BitBlt(13,17,8,8,Source,0,0);
  end;
begin
  Canvas:=TSkiaBitmapCanvas.Create(64,48);Reference:=TSkiaBitmapCanvas.Create(64,48);
  Source:=TSkiaBitmapCanvas.Create(8,8);Pattern:=TBitmap.Create;
  try
    Source.SkCanvas.Clear($FFFF0000);Source.Brush.Color:=clBlue;Source.FillRect(Rect(0,0,4,8));
    Pattern.PixelFormat:=pf24bit;Pattern.SetSize(8,8);
    Pattern.Canvas.Brush.Color:=clWhite;Pattern.Canvas.FillRect(Rect(0,0,8,8));
    Pattern.Canvas.Brush.Color:=clRed;Pattern.Canvas.FillRect(Rect(0,0,4,4));
    SetLength(LeftPixels,64*48);SetLength(RightPixels,64*48);
    for TransformIndex:=0 to 5 do
    for PatternIndex:=0 to 1 do
    for ClipIndex:=0 to 1 do
    begin
      if (TransformIndex=0) and ((PatternIndex<>0) or (ClipIndex<>0)) then Continue;
      M:=TMatrix.Identity;
      case TransformIndex of
        1:begin M.M31:=9;M.M32:=4;end;
        2:begin M.M11:=0.75;M.M12:=0.5;M.M21:=-0.5;M.M22:=0.75;M.M31:=26;M.M32:=-2;end;
        3:begin M.M11:=-1;M.M31:=58;end;
        4:begin M.M11:=1.5;M.M22:=0.75;M.M31:=2;M.M32:=1;end;
        5:begin M.M12:=0.25;M.M21:=0.5;M.M31:=3;M.M32:=2;end;
      end;
      for RopIndex:=0 to 255 do
      begin
        if TransformIndex=0 then Rop:=RopIndex
        else begin if RopIndex>High(Rops) then Break;Rop:=Rops[RopIndex];end;
        Render(Canvas,False);Render(Reference,True);
        LeftImage:=Canvas.Snapshot;RightImage:=Reference.Snapshot;
        Same:=LeftImage.ReadPixels(TSkImageInfo.Create(64,48,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(LeftPixels),64*4) and
          RightImage.ReadPixels(TSkImageInfo.Create(64,48,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(RightPixels),64*4);
        for I:=0 to High(LeftPixels) do if LeftPixels[I]<>RightPixels[I] then begin Same:=False;Break;end;
        Check(Same,Format('Input validation: tiled/full ROP %x transform %d pattern %d clip %d',[Rop,TransformIndex,PatternIndex,ClipIndex]));
        LeftImage:=nil;RightImage:=nil;
      end;
    end;
  finally Pattern.Free;Source.Free;Reference.Free;Canvas.Free;end;
end;

{$IFDEF MSWINDOWS}
function TestWorkExtPen(Style,Width:Cardinal;Brush:Pointer;Count:Cardinal;Entries:Pointer):HPEN;stdcall;external 'gdi32.dll' name 'ExtCreatePen';
function TestWorkTransform(DC:HDC;Transform:Pointer):BOOL;stdcall;external 'gdi32.dll' name 'SetWorldTransform';
procedure TestNativeReplayWork;
var DC:HDC;Player:TMetafileRecordPlayer;Pen,Old:HPEN;Brush:TLogBrush;
  Data:array[0..21] of Integer;XF:TXForm;Rejected:Boolean;Pass:Integer;
  procedure Verify(ShouldReject:Boolean;const Name:string);
  begin
    Rejected:=False;
    try Player.ValidateWork(DC,PEnhMetaRecord(@Data[0]));
    except on E:EReadError do Rejected:=True;end;
    Check(Rejected=ShouldReject,'Native replay work: '+Name);
  end;
begin
  DC:=CreateCompatibleDC(0);Player:=TMetafileRecordPlayer.Create;
  try
    Brush.lbStyle:=BS_SOLID;Brush.lbColor:=0;Brush.lbHatch:=0;
    SetGraphicsMode(DC,GM_ADVANCED);
    Pen:=TestWorkExtPen(PS_GEOMETRIC or PS_DASH,4,@Brush,0,nil);
    Check(Pen<>0,'Native replay work: geometric dashed pen created');
    Old:=SelectObject(DC,Pen);
    try
      Data[0]:=54;Data[1]:=16;Data[2]:=9700000;Data[3]:=128;
      MoveToEx(DC,0,128,nil);
      Verify(True,'large dashed segment rejected before GDI');
      FillChar(XF,SizeOf(XF),0);XF.eM11:=0.00001;XF.eM22:=0.00001;
      TestWorkTransform(DC,@XF);
      Verify(False,'large logical coordinates accepted after downscaling');
      XF.eM11:=-0.00001;XF.eM12:=0.00001;XF.eM21:=0.00002;
      TestWorkTransform(DC,@XF);
      Verify(False,'mapped reflected and sheared segment accepted');
    finally SelectObject(DC,Old);DeleteObject(Pen);end;
    FillChar(XF,SizeOf(XF),0);XF.eM11:=1;XF.eM22:=1;TestWorkTransform(DC,@XF);
    FillChar(Data,SizeOf(Data),0);Data[0]:=55;Data[1]:=40;
    Data[4]:=50;Data[5]:=50;Data[6]:=90;Data[7]:=90;
    Verify(False,'ARCTO uses rectangle geometry, not a point count');
    FillChar(Data,SizeOf(Data),0);Data[0]:=84;Data[1]:=SizeOf(Data);
    Data[11]:=2;Data[18]:=80;Data[20]:=67108874;Data[21]:=12;
    Verify(True,'large text advance rejected before native allocation');
    Data[18]:=1;Verify(True,'text advance offset inside header rejected');
    Data[18]:=80;Data[20]:=12;Verify(False,'ordinary text advances accepted');
    Data[20]:=67108874;XF.eM11:=0.00001;XF.eM22:=0.00001;TestWorkTransform(DC,@XF);
    Verify(False,'large logical text advance accepted after downscaling');
    Pen:=TestWorkExtPen(PS_GEOMETRIC or PS_SOLID,$40000000,@Brush,0,nil);
    Check(Pen<>0,'Native replay work: boundary pen created');
    Old:=SelectObject(DC,Pen);
    try
      FillChar(XF,SizeOf(XF),0);XF.eM11:=1;XF.eM22:=1;
      TestWorkTransform(DC,@XF);
      Data[0]:=42;Data[1]:=24;Data[2]:=10;Data[3]:=10;Data[4]:=50;Data[5]:=50;
      Verify(True,'excessive native pen rejected');
      Data[0]:=64;Data[1]:=24;
      Verify(True,'excessive native pen rejected before StrokePath');
      XF.eM11:=0.000001;XF.eM22:=0.000001;TestWorkTransform(DC,@XF);
      Verify(False,'large logical pen accepted after downscaling');
      for Pass:=0 to 2 do begin
        case Pass of
          0:begin XF.eM11:=0;XF.eM12:=0.000001;XF.eM21:=-0.000001;XF.eM22:=0;end;
          1:begin XF.eM11:=-0.000001;XF.eM12:=0;XF.eM21:=0;XF.eM22:=0.000001;end;
          2:begin XF.eM11:=0.000002;XF.eM12:=0.000001;XF.eM21:=0;XF.eM22:=0.000001;end;
        end;
        TestWorkTransform(DC,@XF);
        Verify(False,'mapped rotated/reflected/nonuniform pen '+IntToStr(Pass));
      end;
    finally SelectObject(DC,Old);DeleteObject(Pen);end;
  finally Player.Free;DeleteDC(DC);end;
end;
{$ENDIF}

procedure TestInputValidation;
var Canvas,Huge:TSkiaBitmapCanvas; Bitmap:TBitmap; Manager:TSkiaFontManager;
  Stream:TMemoryStream; Rejected:Boolean; OriginalFormat:TPixelFormat;
  I:Integer; Value:Single; NativeBrush:TBrush; Surface:ISkSurface; Wrapper:TSkiaCanvas; Clip:TRect; Fault:TInputValidationFault; Handler:TNotifyEvent; SaveIndex,NativeDepth:Integer; Pixel:TAlphaColor; LargeStream:TInputValidationLargeStream; Pixmap:ISkPixmap; BatchImage:ISkImage; BatchPixels:array[0..63] of TAlphaColor; X,Y:Integer; DIB:TBytes;
begin
  {$IFDEF MSWINDOWS}TestNativeReplayWork;{$ENDIF}
  TestInputRopAlpha;
  TestTiledRasterOperations;
  Canvas:=TSkiaBitmapCanvas.Create(32,32);Bitmap:=TBitmap.Create;
  Manager:=TSkiaFontManager.Create;Stream:=TMemoryStream.Create;
  try
    Fault:=TInputValidationFault.Create;
    try
      Canvas.Pen.Color:=clRed;NativeDepth:=Canvas.SkCanvas.GetSaveCount;
      SaveIndex:=Canvas.SaveState;Canvas.Pen.Color:=clBlue;
      Handler:=Canvas.Pen.OnChange;Canvas.Pen.OnChange:=Fault.Change;
      try
        Rejected:=False;try Canvas.RestoreState(SaveIndex);except on E:EAbort do Rejected:=True;end;
        Check(Rejected,'Input validation: restore observer failure is propagated');
        Check(Canvas.SkCanvas.GetSaveCount=NativeDepth+1,'Input validation: failed restore retains native checkpoint');
        Check(Canvas.Pen.Color=clBlue,'Input validation: failed restore rolls back wrapper resources');
      finally Canvas.Pen.OnChange:=Handler;end;
      Canvas.RestoreState(SaveIndex);
      Check((Canvas.Pen.Color=clRed) and (Canvas.SkCanvas.GetSaveCount=NativeDepth),
        'Input validation: restore can be retried after observer failure');
    finally Fault.Free;end;
    Surface:=TSkSurface.MakeRaster(64,64);
    Surface.GetCanvas.ClipRect(RectF(10,12,30,40));
    Wrapper:=TSkiaCanvas.Create(Surface.GetCanvas);
    try
      Clip:=Wrapper.ClipRect;
      Check((Clip.Left=10) and (Clip.Top=12) and (Clip.Right=30) and (Clip.Bottom=40),
        'Input validation: wrapper preserves non-origin native clip bounds');
      Wrapper.Brush.Color:=clRed;Wrapper.FillRect(Rect(22,20,28,25));
      Surface.ReadPixels(TSkImageInfo.Create(1,1,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),@Pixel,4,25,22);
      Check(Pixel=$FFFF0000,'Input validation: non-origin wrapper retains absolute device coordinates');
    finally Wrapper.Free;Surface:=nil;end;
    Huge:=nil;Rejected:=False;
    try Huge:=TSkiaBitmapCanvas.Create(High(Integer),2);except on E:ESkiaCanvasError do Rejected:=True;end;
    Huge.Free;Check(Rejected,'Input validation: oversized bitmap rejected before allocation');
    Rejected:=False;
    try Manager.LoadTypefaceFromStream(Stream,-1);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Input validation: negative font collection index rejected');
    LargeStream:=TInputValidationLargeStream.Create;
    try
      Rejected:=False;
      try Manager.LoadTypefaceFromStream(LargeStream);except on E:ESkiaCanvasError do Rejected:=True;end;
      Check(Rejected,'Input validation: oversized font stream rejected before reading');
    finally LargeStream.Free;end;
    Pixel:=$FFFFFFFF;
    Pixmap:=TSkPixmap.Create(TSkImageInfo.Create(1,1,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),@Pixel,4);
    Rejected:=False;
    try Canvas.DrawPixmap(High(Integer),0,Pixmap);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Input validation: overflowing pixmap destination rejected');
    Pixmap:=nil;
    for I:=0 to 2 do
    begin
      case I of 0:Value:=NaN;1:Value:=Infinity;else Value:=-1;end;
      Rejected:=False;
      try Canvas.Pen.MiterLimit:=Value;except on E:ESkiaCanvasError do Rejected:=True;end;
      Check(Rejected,'Input validation: invalid miter '+IntToStr(I));
      Rejected:=False;
      try Canvas.Pen.DashPattern:=TArray<Single>.Create(Value,2);except on E:ESkiaCanvasError do Rejected:=True;end;
      Check(Rejected,'Input validation: invalid dash '+IntToStr(I));
    end;
    Bitmap.PixelFormat:=pf24bit;Bitmap.SetSize(8,8);
    Bitmap.Canvas.Brush.Color:=clRed;Bitmap.Canvas.FillRect(Rect(0,0,8,8));
    OriginalFormat:=Bitmap.PixelFormat;
    Canvas.Draw(0,0,Bitmap);
    Check(Bitmap.PixelFormat=OriginalFormat,'Input validation: Draw preserves source bitmap format');
    Check(Bitmap.Canvas.Pixels[2,2]=clRed,'Input validation: Draw preserves source bitmap pixels');
    Check(Canvas.Pixels[2,2]=clRed,'Input validation: Draw transfers source bitmap pixels');
    Rejected:=False;
    try Canvas.StretchBlt(0,0,1,1,Bitmap.Canvas,0,0,Low(Integer),1);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Input validation: native blit rejects Low(Integer) width');
    Rejected:=False;
    try Canvas.StretchBlt(0,0,1,1,Bitmap.Canvas,Low(Integer),0,-4,1);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Input validation: native blit rejects overflowing mirrored source coordinates');
    NativeDepth:=Canvas.SkCanvas.GetSaveCount;
    Canvas.SetClipRect(Rect(5,5,20,20));Canvas.ExcludeClipRect(Rect(5,5,9,20));Clip:=Canvas.ClipRect;
    Check((Clip.Left=9) and (Clip.Top=5) and (Clip.Right=20) and (Clip.Bottom=20),
      'Input validation: clip bounds use native region geometry');
    Check(Canvas.SkCanvas.GetSaveCount=NativeDepth,'Input validation: clip query preserves native save depth');
    Canvas.ResetClip;
    NativeBrush:=TBrush.Create;
    try
      NativeBrush.Bitmap:=Bitmap;Canvas.Brush.Assign(NativeBrush);
      Check(Canvas.Brush.Pattern<>nil,'Input validation: native pattern brush imports bitmap');
      Canvas.FillRect(Rect(8,8,16,16));
      Check(Canvas.Pixels[10,10]=clRed,'Input validation: imported pattern brush retains pixels');
      Canvas.Brush.Assign(Canvas.Brush);
      Check(Canvas.Brush.Pattern<>nil,'Input validation: brush self-assignment preserves pattern');
      Canvas.Brush.Pattern.Canvas.Brush.Color:=clBlue;
      Canvas.Brush.Pattern.Canvas.FillRect(Rect(0,0,8,8));
      Canvas.FillRect(Rect(8,8,16,16));
      Check(Canvas.Pixels[10,10]=clBlue,'Input validation: mutating pattern pixels invalidates cached paint');
    finally NativeBrush.Free;end;
{$IFDEF MSWINDOWS}
    NativeBrush:=TBrush.Create;
    try
      NativeBrush.Handle:=CreatePatternBrush(Bitmap.Handle);
      Canvas.Brush.Assign(NativeBrush);
      Check(Canvas.Brush.Pattern<>nil,'Input validation: raw GDI pattern brush imports bitmap');
      Canvas.FillRect(Rect(8,8,16,16));
      Check(Canvas.Pixels[10,10]=clRed,'Input validation: raw GDI pattern brush retains pixels');
      SetLength(DIB,40+8*8*4);
      PBitmapInfoHeader(@DIB[0]).biSize:=40;PBitmapInfoHeader(@DIB[0]).biWidth:=8;
      PBitmapInfoHeader(@DIB[0]).biHeight:=-8;PBitmapInfoHeader(@DIB[0]).biPlanes:=1;
      PBitmapInfoHeader(@DIB[0]).biBitCount:=32;
      NativeBrush.Handle:=CreateDIBPatternBrushPt(@DIB[0],DIB_RGB_COLORS);
      Rejected:=False;
      try Canvas.Brush.Assign(NativeBrush);except on E:ESkiaCanvasError do Rejected:=True;end;
      Check(Rejected,'Input validation: unavailable raw DIB brush data reports unsupported import');
      Check(Canvas.Brush.Pattern<>nil,'Input validation: unsupported native brush preserves previous pattern');
    finally NativeBrush.Free;end;
{$ENDIF}
    Canvas.TranslateTransform(4,5);
    Check(Canvas.Pixels[-2,-3]=clRed,'Input validation: single pixel read respects world transform');
    Check(Canvas.Pixels[1000,1000]=clBlack,'Input validation: out-of-bounds pixel read');
    for Y:=0 to 7 do for X:=0 to 7 do Canvas.Pixels[X,Y]:=clLime;
    BatchImage:=Canvas.Snapshot;
    Check(BatchImage.ReadPixels(TSkImageInfo.Create(8,8,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),@BatchPixels[0],32,4,5),
      'Input validation: direct pixel batch readable');
    Rejected:=False;for I:=0 to High(BatchPixels) do if BatchPixels[I]<>$FF00FF00 then Rejected:=True;
    Check(not Rejected,'Input validation: direct pixel batch respects the transform');
    BatchImage:=nil;
  finally Stream.Free;Manager.Free;Bitmap.Free;Canvas.Free;end;
end;

