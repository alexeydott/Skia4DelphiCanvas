{ Boolean raster operations are checked against independent truth tables. }
procedure T_CompatPenModes;
var C: TSkiaBitmapCanvas; Mode: TPenMode; Expected,D,S,Actual: Cardinal;
begin
  C:=TSkiaBitmapCanvas.Create(20,20);
  try
    for Mode:=Low(TPenMode) to High(TPenMode) do begin
      D:=$005A3CA5; S:=$00A5C35A;
      case Mode of
        pmBlack:Expected:=0; pmWhite:Expected:=$FFFFFF;
        pmNop:Expected:=D; pmNot:Expected:=not D;
        pmCopy:Expected:=S; pmNotCopy:Expected:=not S;
        pmMergePenNot:Expected:=S or not D; pmMaskPenNot:Expected:=S and not D;
        pmMergeNotPen:Expected:=not S or D; pmMaskNotPen:Expected:=not S and D;
        pmMerge:Expected:=S or D; pmNotMerge:Expected:=not(S or D);
        pmMask:Expected:=S and D; pmNotMask:Expected:=not(S and D);
        pmXor:Expected:=S xor D; pmNotXor:Expected:=not(S xor D);
      else
        raise Exception.Create('Unsupported pen mode in truth-table test');
      end;
      Expected:=Expected and $FFFFFF;
      C.Brush.Color:=TColor(D); C.FillRect(Rect(0,0,20,20));
      C.Pen.Color:=TColor(S); C.Pen.Width:=4; C.Pen.Mode:=Mode;
      C.MoveTo(2,10); C.LineTo(18,10); C.Pen.Mode:=pmCopy;
      Actual:=Cardinal(ColorToRGB(C.Pixels[10,10])) and $FFFFFF;
      Check(Actual=Expected,'ROP2 pen mode '+IntToStr(Ord(Mode)));
    end;
  finally C.Free; end;
end;
procedure T_CompatCopyRops;
var C,S: TSkiaBitmapCanvas; Table,Bit,I: Integer; P,D,Source,Expected: Cardinal;
begin
  C:=TSkiaBitmapCanvas.Create(8,8); S:=TSkiaBitmapCanvas.Create(8,8);
  try
    Source:=$00A55AC3; D:=$0033CC5A; P:=$00F00FA5;
    S.Brush.Color:=TColor(Source); S.FillRect(Rect(0,0,8,8));
    for Table:=0 to 255 do begin
      Expected:=0;
      for Bit:=0 to 23 do begin
        I:=Integer(((P shr Bit) and 1)*4+((Source shr Bit) and 1)*2+((D shr Bit) and 1));
        if (Table and (1 shl I))<>0 then Expected:=Expected or (Cardinal(1) shl Bit);
      end;
      C.CopyMode:=cmSrcCopy; C.Brush.Color:=TColor(D); C.FillRect(Rect(0,0,8,8));
      C.Brush.Color:=TColor(P); C.CopyMode:=TCopyMode(Cardinal(Table) shl 16);
      C.BitBlt(0,0,8,8,S,0,0);
      Check((Cardinal(ColorToRGB(C.Pixels[4,4])) and $FFFFFF)=Expected,'ROP3 truth table '+IntToStr(Table));
    end;
  finally S.Free; C.Free; end;
end;
procedure T_CompatTransparencyAndMirroring;
var C,S: TSkiaBitmapCanvas; B: TBitmap;
begin
  C:=TSkiaBitmapCanvas.Create(40,30); S:=TSkiaBitmapCanvas.Create(10,10); B:=TBitmap.Create;
  try
    S.Brush.Color:=clRed; S.FillRect(Rect(0,0,5,10)); S.Brush.Color:=clBlue; S.FillRect(Rect(5,0,10,10)); S.Flush(B);
    C.Brush.Color:=clGreen; C.FillRect(Rect(0,0,40,30));
    C.BrushCopy(Rect(0,0,10,10),B,Rect(0,0,10,10),clRed);
    Check(C.Pixels[2,2]=clGreen,'BrushCopy: keyed red preserves destination');
    Check(C.Pixels[7,2]=clBlue,'BrushCopy: non-keyed source copied');
    C.StretchBlt(30,0,-20,20,S,0,0,10,10);
    Check(C.Pixels[12,5]=clBlue,'StretchBlt: negative width mirrors right half');
    Check(C.Pixels[27,5]=clRed,'StretchBlt: negative width mirrors left half');
    C.DrawFocusRect(Rect(2,22,35,29)); C.DrawFocusRect(Rect(2,22,35,29));
    Check(C.Pixels[5,22]=clGreen,'Focus rectangle: drawing twice restores destination');
  finally B.Free; S.Free; C.Free; end;
end;
procedure T_CompatVectorRasterOps;
var MC: TSkiaMetafileCanvas; S,D: TSkiaBitmapCanvas; Mask: TBitmap; I,J: Integer; Pic: ISkPicture;
begin
  MC:=TSkiaMetafileCanvas.Create(40,40); S:=TSkiaBitmapCanvas.Create(10,10);
  D:=TSkiaBitmapCanvas.Create(40,40); Mask:=TBitmap.Create;
  try
    S.Brush.Color:=clRed; S.FillRect(Rect(0,0,10,10));
    Mask.SetSize(10,10); for J:=0 to 9 do for I:=0 to 9 do Mask.Canvas.Pixels[I,J]:=clWhite;
    MC.Brush.Color:=clWhite; MC.FillRect(Rect(0,0,40,40));
    MC.SetClipRect(Rect(12,12,18,18)); MC.TranslateTransform(10,10);
    try
      MC.MaskBlt(0,0,10,10,S,0,0,Mask,0,0);
      Check(True,'MaskBlt: metafile target accepted');
    except on E: ESkiaNotSupportedError do Check(False,'MaskBlt: metafile target accepted'); end;
    MC.ResetClip; MC.ResetWorldTransform;
    try MC.Brush.Color:=clBlue; MC.FloodFill(30,30,clWhite,fsSurface);
      Check(True,'FloodFill: metafile target accepted');
    except on E: ESkiaNotSupportedError do Check(False,'FloodFill: metafile target accepted'); end;
    Pic:=MC.FinishRecording; Pic.Playback(D.SkCanvas);
    Check(D.Pixels[14,14]=clRed,'Vector mask: transform / clip respected');
    Check(D.Pixels[11,11]=clBlue,'Vector flood: unmasked region filled');
  finally Mask.Free; D.Free; S.Free; MC.Free; end;
end;
procedure T_CompatTextLayout;
var C: TSkiaBitmapCanvas; R: TRect; S: string;
Ref: TBitmap; RR: TRect; RS: string;
begin
  C:=TSkiaBitmapCanvas.Create(200,120);
  try
    C.Font.Name:='Arial'; C.Font.Height:=-20; C.Font.Color:=clWhite;
    C.Brush.Style:=bsClear; C.TextToCurves:=True;
    R:=Rect(0,0,100,110); S:='Alpha beta gamma delta epsilon';
    
    {$IFDEF MSWINDOWS}
    Ref:=TBitmap.Create;
    try
      Ref.SetSize(200,120); Ref.Canvas.Font.Assign(C.Font); Ref.Canvas.Brush.Style:=bsClear;
      Ref.Canvas.TextOut(0,0,''); RR:=R; RS:=S;
      Ref.Canvas.TextRect(RR,RS,[tfWordBreak,tfCalcRect]);
      C.TextRect(R,S,[tfWordBreak,tfCalcRect]);
      Check((R.Width=RR.Width) and (R.Height=RR.Height),'TextRect: wrapped CalcRect matches native VCL');
      R:=Rect(0,0,70,30); RR:=R; S:='Very long file name.txt'; RS:=S;
      Ref.Canvas.TextRect(RR,RS,[tfSingleLine,tfEndEllipsis,tfModifyString]);
      C.TextRect(R,S,[tfSingleLine,tfEndEllipsis,tfModifyString]);
      Check(S=RS,'TextRect: ellipsis / ModifyString matches native VCL');
    finally Ref.Free; end;
    
    {$ELSE}
    C.TextRect(R,S,[tfWordBreak,tfCalcRect]);
    Check(R.Height>C.TextHeight('A'),'TextRect word wrapping increases calculated height');
    R:=Rect(0,0,70,30); S:='Very long file name.txt';
    C.TextRect(R,S,[tfSingleLine,tfEndEllipsis,tfModifyString]);
    Check((S<>'Very long file name.txt') and (C.TextWidth(S)<=70),'TextRect ellipsis fits available width');
    {$ENDIF}
    R:=Rect(0,0,180,100); S:='Bottom';
    C.TextRect(R,S,[tfSingleLine,tfBottom]);
    Check(C.Pixels[5,5]=clBlack,'TextRect bottom: top stays empty');
    try C.TextRect(R,S,[tfSingleLine,tfCenter,tfVerticalCenter,tfComposited]);
      Check(True,'TextRect composited: supported');
    except Check(False,'TextRect composited: supported'); end;
  finally C.Free; end;
end;
procedure T_CompatClipStackAndFlood;
var C: TSkiaBitmapCanvas; A,B: Integer;
begin
  C:=TSkiaBitmapCanvas.Create(60,60);
  try
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,60,60));
    C.SetClipRect(Rect(0,0,30,30)); A:=C.SaveState;
    C.SetClipRect(Rect(30,30,60,60)); B:=C.SaveState;
    C.ExcludeClipRect(Rect(35,35,55,55)); C.RestoreState(B);
    C.Brush.Color:=clRed; C.FillRect(Rect(0,0,60,60)); C.RestoreState(A);
    C.Brush.Color:=clBlue; C.FloodFill(5,5,clWhite,fsSurface);
    Check(C.Pixels[10,10]=clBlue,'FloodFill: restored clip interior filled');
    Check(C.Pixels[40,10]=clWhite,'FloodFill: stops at active clip');
    Check(C.Pixels[40,40]=clRed,'Clip snapshots: replaced clip restored without losing its hole state');
    C.ResetClip;
    C.Brush.Color:=clGreen; C.FloodFill(45,5,clRed,fsSurface);
    Check(C.Pixels[45,5]=clWhite,'FloodFill surface: mismatched seed color is a no-op');
  finally C.Free; end;
end;
procedure T_CompatInsideFrame;
var C: TSkiaBitmapCanvas;
begin
  C:=TSkiaBitmapCanvas.Create(50,50);
  try
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,50,50)); C.Brush.Style:=bsClear;
    C.Pen.Color:=clRed; C.Pen.Width:=8; C.Pen.Style:=psInsideFrame; C.Rectangle(10,10,40,40);
    Check(C.Pixels[7,25]=clWhite,'InsideFrame: thick stroke remains inside bounds');
    Check(C.Pixels[12,25]=clRed,'InsideFrame: stroke is visible inside bounds');
  finally C.Free; end;
end;
function CompatHasInk(C: TSkiaBitmapCanvas): Boolean;
var Pixels: TArray<TAlphaColor>; I: Integer; Image: ISkImage;
begin
  Image:=C.Snapshot;
  
  SetLength(Pixels,C.Width*C.Height);
  Image.ReadPixels(TSkImageInfo.Create(C.Width,C.Height,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),C.Width*4);
  
  Result:=False;
  for I:=0 to High(Pixels) do if Pixels[I] and $FFFFFF<>0 then Exit(True);
end;
procedure T_CompatPrefixAndCustomCurves;

var C: TSkiaBitmapCanvas; R: TRect; S: string; Custom: ISkTypeface; LF: TLogFontW;

begin
  
  C:=TSkiaBitmapCanvas.Create(240,80);
  try
    C.Brush.Style:=bsClear; C.Font.Color:=clWhite; C.Font.Height:=-24;
    R:=Rect(0,0,200,60); S:='A&B'; C.TextRect(R,S,[tfSingleLine,tfPrefixOnly]);
    Check(CompatHasInk(C),'TextRect PrefixOnly: visible accelerator underline');
    Custom:=TSkTypeface.MakeFromName('Courier New',TSkFontStyle.Normal);
    C.FontManager.RegisterTypeface('NativeAlias',Custom); C.Font.Name:='NativeAlias'; C.TextToCurves:=True;
    C.FontManager.GetLogFont(C.Font,LF);
    Check(SameText(string(LF.lfFaceName),Custom.GetFamilyName),'Custom curves: GDI family resolves registered alias');
    Check(Abs(C.TextExtent('iiii').cx-Ceil(C.AcquireFont.MeasureText('iiii')))<=1,'Custom curves: measured width matches registered typeface');
    C.TextOut(0,20,'iiii'); Check(CompatHasInk(C),'Custom curves: registered typeface draws');
  finally C.Free; end;
  
end;
{$IFDEF MSWINDOWS}
procedure T_CompatNativeGraphics;

var C: TSkiaBitmapCanvas; Meta: TMetafile; Writer: TMetafileCanvas;
  PNG: TPngImage; Ref: TBitmap; X,Y: Integer; Color: Cardinal;

begin
  
  C:=TSkiaBitmapCanvas.Create(40,40); Meta:=TMetafile.Create; PNG:=TPngImage.CreateBlank(COLOR_RGBALPHA,8,12,12);
  try
    Meta.Width:=12; Meta.Height:=12; Writer:=TMetafileCanvas.Create(Meta,0);
    try Writer.Brush.Color:=clGreen; Writer.FillRect(Rect(0,0,12,12)); finally Writer.Free; end;
    C.Draw(0,0,Meta); Check(C.Pixels[5,5]=clGreen,'Draw: parsed VCL metafile playback');
    Ref:=TBitmap.Create;
    try
      Ref.SetSize(40,40); Ref.Canvas.Brush.Color:=clBlack; Ref.Canvas.FillRect(Rect(0,0,40,40));
      Ref.Canvas.StretchDraw(Rect(15,0,39,24),Meta);
      C.StretchDraw(Rect(15,0,39,24),Meta);
      Check(C.Pixels[30,10]=Ref.Canvas.Pixels[30,10],'StretchDraw: metafile conversion matches native VCL');
      Check((Ref.Canvas.Pixels[20,5]=clGreen) and (C.Pixels[20,5]=clGreen),'StretchDraw: metafile interior visible');

    finally Ref.Free; end;
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,25,20,40));
    PNG.Canvas.Brush.Color:=clRed; PNG.Canvas.FillRect(Rect(0,0,12,12));
    for Y:=0 to 11 do for X:=0 to 11 do if X<6 then PNG.AlphaScanline[Y][X]:=128 else PNG.AlphaScanline[Y][X]:=0;
    C.Draw(0,25,PNG); Color:=Cardinal(ColorToRGB(C.Pixels[2,28]));
    Check(((Color and 255)=255) and (Abs(Integer((Color shr 8) and 255)-127)<=2),'Draw: PNG partial alpha reconstructed');
    Check(C.Pixels[9,28]=clWhite,'Draw: PNG transparent pixels preserved');
  finally PNG.Free; Meta.Free; C.Free; end;
  
end;
{$ENDIF}

procedure T_CompatSourceCoordinates;
var S,D: TSkiaBitmapCanvas;
begin
  S:=TSkiaBitmapCanvas.Create(40,40); D:=TSkiaBitmapCanvas.Create(40,40);
  try
    S.TranslateTransform(10,12); S.Brush.Color:=clRed; S.FillRect(Rect(0,0,10,10));
    S.Pixels[1,1]:=clBlue;
    Check(S.Pixels[1,1]=clBlue,'Pixels: reads and writes use logical coordinates');
    D.BitBlt(0,0,10,10,S,0,0);
    Check(D.Pixels[5,5]=clRed,'BitBlt: transformed source uses logical source rectangle');
    Check(D.Pixels[1,1]=clBlue,'BitBlt: source coordinate origin is preserved');
    D.StretchBlt(10,10,20,20,S,0,0,10,10);
    Check(D.Pixels[20,20]=clRed,'StretchBlt: transformed source scales correctly');
    S.ResetWorldTransform; S.TranslateTransform(20,20); S.Brush.Color:=clGreen;
    S.FillRect(Rect(-15,-15,-5,-5));
    D.CopyRect(Rect(0,25,10,35),S,Rect(-15,-15,-5,-5));
    Check(D.Pixels[5,30]=clGreen,'CopyRect: negative logical source coordinates supported');
  finally D.Free; S.Free; end;
end;
procedure T_CompatPrepaintedSurface;
var Surface: ISkSurface; C: TSkiaCanvas;
begin
  Surface:=TSkSurface.MakeRaster(20,20); Surface.GetCanvas.Clear(ColorToAlphaColor(clRed));
  C:=TSkiaCanvas.Create(Surface);
  try
    C.Pen.Color:=clBlue; C.Pen.Width:=4; C.Pen.Mode:=pmXor; C.MoveTo(2,10); C.LineTo(18,10);
    Check(C.Pixels[10,10]=clFuchsia,'Surface constructor: XOR reads existing destination');
  finally C.Free; end;
end;
procedure T_CompatBrushKeyAndFrame;
var C: TSkiaBitmapCanvas; B: TBitmap; S: TSkiaBitmapCanvas;
begin
  C:=TSkiaBitmapCanvas.Create(40,40); S:=TSkiaBitmapCanvas.Create(4,4); B:=TBitmap.Create;
  try
    S.Brush.Color:=clRed; S.FillRect(Rect(0,0,4,4)); S.Flush(B);
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,40,40));
    C.Brush.Color:=clGreen; C.BrushCopy(Rect(0,0,10,10),B,Rect(0,0,4,4),clRed);
    Check(C.Pixels[5,5]=clGreen,'BrushCopy: keyed pixels use current solid brush');
    C.Brush.Style:=bsClear; C.BrushCopy(Rect(12,0,22,10),B,Rect(0,0,4,4),clRed);
    Check(C.Pixels[15,5]=clWhite,'BrushCopy: bsClear keyed pixels are transparent');
    C.Brush.Style:=bsVertical; C.Brush.Color:=clBlue; C.FrameRect(Rect(0,20,32,35));
    Check(C.Pixels[4,20]=clBlue,'FrameRect: hatch brush paints active pattern pixel');
    Check(C.Pixels[0,20]=clWhite,'FrameRect: hatch gaps preserve destination');
  finally B.Free; S.Free; C.Free; end;
end;
procedure T_CompatNonRectangularClip;
var C: TSkiaBitmapCanvas; Path: ISkiaPathBuilder;
begin
  C:=TSkiaBitmapCanvas.Create(40,40);
  try
    Path:=TSkiaPathBuilder.Create; Path.AddOval(RectF(5,5,35,35));
    C.SetClipPath(Path.Snapshot); C.Brush.Color:=clRed; C.FillRect(Rect(0,0,40,40));
    Check(C.Pixels[20,20]=clRed,'ClipPath: ellipse interior filled');
    Check(C.Pixels[6,6]=clBlack,'ClipPath: ellipse corner excluded');
    C.ResetClip;
  finally C.Free; end;
end;
type TCompatChangeObserver = class
  Count: Integer;
  procedure Changed(Sender: TObject);
end;
procedure TCompatChangeObserver.Changed(Sender: TObject);
begin Inc(Count); end;
procedure T_CompatFontChangeObserver;
var RM: TSkiaResourceManager; F: TFont; Before,After: ISkFont; TF: ISkTypeface; Observer: TCompatChangeObserver;
begin
  RM:=TSkiaResourceManager.Create; F:=TFont.Create; Observer:=TCompatChangeObserver.Create;
  try
    RM.FontManager.OnChange:=Observer.Changed; F.Name:='CallbackAlias'; Before:=RM.AcquireFont(F);
    TF:=TSkTypeface.MakeFromName('Courier New',TSkFontStyle.Normal);
    RM.FontManager.RegisterTypeface(F.Name,TF); After:=RM.AcquireFont(F);
    Check(Observer.Count=1,'FontManager: user OnChange is notified');
    Check(Before<>After,'FontManager: user OnChange does not disconnect internal cache invalidation');
    Check(After.GetTypeface.GetFamilyName=TF.GetFamilyName,'FontManager: cache sees registered font after callback');
  finally Observer.Free; F.Free; RM.Free; end;
end;
procedure T_CompatExternalTypeface;

var C: TSkiaBitmapCanvas; MC: TSkiaMetafileCanvas; TF: ISkTypeface; Pic: ISkPicture;
  Stream: TMemoryStream; SVG: ISkCanvas; XML: UTF8String; FileName,S: string; R: TRect;

begin
  
  FileName:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..'+PathDelim+'..'+PathDelim+'fixtures'+PathDelim+'SkiaFixture.ttf');
  if not FileExists(FileName) then FileName:=ExpandFileName('fixtures'+PathDelim+'SkiaFixture.ttf');
  TF:=TSkTypeface.MakeFromFile(FileName);
  Check(TF<>nil,'Custom fixture: external typeface loaded'); if TF=nil then Exit;
  C:=TSkiaBitmapCanvas.Create(150,90); MC:=TSkiaMetafileCanvas.Create(150,90); Stream:=TMemoryStream.Create;
  try
    C.FontManager.RegisterTypeface('ExternalFixture',TF); C.Font.Name:='ExternalFixture'; C.Font.Height:=-30;
    C.Font.Color:=clWhite; C.Brush.Style:=bsClear; C.TextToCurves:=True;
    Check(C.TextExtent('AV').cx=32,'Uninstalled custom font: HarfBuzz kerning matches fixture units');
    Check(C.TextExtent('AV ').cx=41,'Uninstalled custom font: trailing space contributes advance');
    C.TextOut(5,5,'AV'); Check(CompatHasInk(C),'Uninstalled custom font: outlines visible');
    R:=Rect(0,0,35,90); S:='AV AV AV'; C.TextRect(R,S,[tfWordBreak,tfCalcRect]);
    Check(R.Height>=60,'Uninstalled custom font: formatted layout wraps');
    C.SkCanvas.Clear(0); R:=Rect(0,0,150,70); S:='&AV';
    C.TextRect(R,S,[tfSingleLine,tfPrefixOnly,tfRtlReading]);
    Check(CompatHasInk(C),'Uninstalled custom font: accelerator-only RTL layout paints underline');
    MC.FontManager.RegisterTypeface('ExternalFixture',TF); MC.Font.Name:='ExternalFixture'; MC.Font.Height:=-30;
    MC.Font.Color:=clBlue; MC.Brush.Style:=bsClear; MC.TextToCurves:=True; MC.TextOut(5,5,'AV'); Pic:=MC.FinishRecording;
    SVG:=TSkSVGCanvas.Make(RectF(0,0,150,90),Stream); Pic.Playback(SVG); SVG:=nil;
    SetLength(XML,Stream.Size); Stream.Position:=0; Stream.ReadBuffer(XML[1],Length(XML));
    Check((Pos(AnsiString('<path'),XML)>0) and (Pos(AnsiString('<text'),XML)=0),'Uninstalled custom font: SVG contains curves, no font dependency');
  finally SVG:=nil; Stream.Free; MC.Free; C.Free; end;
  
end;

{$IFDEF MSWINDOWS}
procedure T_CompatPatternRopReference;

var C,S: TSkiaBitmapCanvas; B,Src: TBitmap; Style: TBrushStyle; I,X,Y: Integer; Same: Boolean;

begin
  
  C:=TSkiaBitmapCanvas.Create(16,16); S:=TSkiaBitmapCanvas.Create(16,16);
  B:=TBitmap.Create; Src:=TBitmap.Create;
  try
    B.SetSize(16,16); Src.SetSize(16,16); Src.Canvas.Brush.Color:=clBlue; Src.Canvas.FillRect(Rect(0,0,16,16));
    S.Brush.Color:=clBlue; S.FillRect(Rect(0,0,16,16));
    for I:=1 to 7 do begin
      Style:=TBrushStyle(I);
      B.Canvas.Brush.Style:=bsSolid; B.Canvas.Brush.Color:=clGreen; B.Canvas.FillRect(Rect(0,0,16,16));
      B.Canvas.Brush.Style:=Style; B.Canvas.Brush.Color:=clRed;
      SetBkMode(B.Canvas.Handle,TRANSPARENT);
      BitBlt(B.Canvas.Handle,0,0,16,16,Src.Canvas.Handle,0,0,PATCOPY);
      C.Brush.Style:=bsSolid; C.Brush.Color:=clGreen; C.FillRect(Rect(0,0,16,16));
      C.Brush.Style:=Style; C.Brush.Color:=clRed; C.CopyMode:=TCopyMode(PATCOPY); C.BitBlt(0,0,16,16,S,0,0);
      Same:=True;
      for Y:=0 to 15 do for X:=0 to 15 do if C.Pixels[X,Y]<>B.Canvas.Pixels[X,Y] then Same:=False;
      Check(Same,'PATCOPY native reference: brush '+IntToStr(Ord(Style)));
    end;
  finally Src.Free; B.Free; S.Free; C.Free; end;
  
end;

{$ENDIF}

procedure T_CompatFontOrientation;
var C: TSkiaBitmapCanvas; X,Y,NAbove,NRight: Integer;
begin
  
  C:=TSkiaBitmapCanvas.Create(100,100);
  try
    C.Font.Name:='Arial'; C.Font.Height:=-20; C.Font.Color:=clWhite; C.Font.Orientation:=900;
    C.Brush.Style:=bsClear; C.TextOut(40,80,'TEST'); NAbove:=0; NRight:=0;
    for Y:=0 to 99 do for X:=0 to 99 do if C.Pixels[X,Y]<>clBlack then begin
      if (Y<80) and (X>=40) then Inc(NAbove); if (Y>=80) and (X>40) then Inc(NRight);
    end;
    Check((NAbove>20) and (NRight=0),'Font orientation rotates text around its logical origin');
  finally C.Free; end;
  
end;

procedure T_CompatInsideFrameClosedShapes;
var C: TSkiaBitmapCanvas; I: Integer;
begin
  
  C:=TSkiaBitmapCanvas.Create(60,60);
  try
    for I:=0 to 3 do begin
      C.Brush.Style:=bsSolid; C.Brush.Color:=clBlack; C.FillRect(Rect(0,0,60,60));
      C.Brush.Style:=bsClear; C.Pen.Style:=psInsideFrame; C.Pen.Width:=12; C.Pen.Color:=clWhite;
      case I of
        0: C.Ellipse(10,10,45,45);
        1: C.RoundRect(10,10,45,45,12,12);
        2: C.Chord(10,10,45,45,45,27,10,27);
        3: C.Pie(10,10,45,45,45,27,10,27);
      end;
      Check(CompatHasInk(C),'psInsideFrame closed shape '+IntToStr(I)+': stroke is visible');
      Check((C.Pixels[8,27]=clBlack) and (C.Pixels[47,27]=clBlack) and (C.Pixels[27,8]=clBlack),
        'psInsideFrame closed shape '+IntToStr(I)+': stroke stays within bounds');
    end;
  finally C.Free; end;
  
end;

procedure T_CompatPortableTextFormatting;

begin
  
end;
