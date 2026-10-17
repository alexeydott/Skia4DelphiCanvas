program SkiaLinuxTests;
{$mode delphiunicode}{$codepage utf8}
uses cthreads, Interfaces, Classes, SysUtils, Types, Math, LCLType, SyncObjs,
  Vcl.Graphics, System.Skia, Vcl.Graphics.Skia, IntfGraphics, FPImage, GraphType;
const fsSurface=Vcl.Graphics.fsSurface; fsBorder=Vcl.Graphics.fsBorder;
var Passed,Failed: Integer;
procedure Check(Value:Boolean;const Name:string);
begin
  if Value then begin Inc(Passed); Writeln('PASS: ',Name); end
  else begin Inc(Failed); Writeln('FAIL: ',Name); end;
end;
function HasInk(C:TSkiaBitmapCanvas):Boolean;
var Image:ISkImage; Pixels:TArray<TAlphaColor>; Value:TAlphaColor;
begin
  Image:=C.Snapshot; SetLength(Pixels,C.Width*C.Height);
  Image.ReadPixels(TSkImageInfo.Create(C.Width,C.Height,TSkColorType.BGRA8888,
    TSkAlphaType.Unpremul),Pointer(Pixels),C.Width*4);
  for Value in Pixels do if (Value and $FFFFFF)<>0 then Exit(True);
  Result:=False;
end;
{$I SkiaBasicCanvasTests.inc}
{$I SkiaCompatibilityTests.inc}
{$I SkiaAdvancedTests.inc}
{$I SkiaAtlasTests.inc}
{$I SkiaImageCodecTests.inc}
{$I SkiaInputValidationTests.inc}
{$I SkiaThreadTests.inc}
{$I SkiaBltTests.inc}
{$I SkiaBindingsTests.inc}
{$I SkiaRasterOptionsTests.inc}
{$I SkiaAffineRasterTests.inc}
{$I SkiaAffineTextPathTests.inc}
{$I SkiaTextPathTests.inc}

procedure TestGenericGraphic;
var C:TSkiaBitmapCanvas; Image:TLazIntfImage; PNG:TPortableNetworkGraphic;
    Color:TFPColor; Value:Cardinal; Y:Integer;
begin
  C:=TSkiaBitmapCanvas.Create(8,4); PNG:=TPortableNetworkGraphic.Create;
  Image:=TLazIntfImage.Create(4,2,[riqfRGB,riqfAlpha]);
  try
    Color.Red:=65535; Color.Green:=0; Color.Blue:=0; Color.Alpha:=32896; Image.FillPixels(Color);
    Color.Alpha:=0; for Y:=0 to 1 do Image.Colors[3,Y]:=Color;
    PNG.LoadFromIntfImage(Image);
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,8,4)); C.Draw(0,0,PNG);
    Value:=ColorToRGB(C.Pixels[1,0]);
    Check(((Value and 255)=255) and (Abs(Integer((Value shr 8) and 255)-127)<=2),'Draw generic PNG reconstructs partial alpha and RGB');
    Check(C.Pixels[3,0]=clWhite,'Draw generic PNG preserves transparent pixels');
    C.FillRect(Rect(0,0,8,4)); C.Draw(0,0,PNG,128); Value:=ColorToRGB(C.Pixels[1,0]);
    Check(Abs(Integer((Value shr 8) and 255)-191)<=2,'Draw generic PNG with opacity');
    C.FillRect(Rect(0,0,8,4)); C.StretchDraw(Rect(0,0,8,4),PNG); Value:=ColorToRGB(C.Pixels[2,1]);
    Check(((Value and 255)=255) and (Abs(Integer((Value shr 8) and 255)-127)<=2),'StretchDraw generic PNG channels and alpha');
  finally Image.Free; PNG.Free; C.Free; end;
end;

procedure TestGradientShapeExport;
var C:TSkiaMetafileCanvas; Picture:ISkPicture; Stream:TMemoryStream; SVG:ISkCanvas;
    XML:UTF8String; I,Images,Gradients:Integer;
begin
  C:=TSkiaMetafileCanvas.Create(100,80); Stream:=TMemoryStream.Create;
  try
    C.Brush.Gradient:=gkHorizontal; C.Brush.GradientStartColor:=clRed; C.Brush.GradientEndColor:=clBlue;
    C.RoundRect(0,0,45,35,8,8); C.Ellipse(50,0,95,35);
    C.Polygon([Point(0,40),Point(40,40),Point(20,75)]);
    C.Pie(50,40,95,75,95,55,70,75);
    Picture:=C.FinishRecording; SVG:=TSkSVGCanvas.Make(RectF(0,0,100,80),Stream);
    Picture.Playback(SVG); SVG:=nil;
    SetLength(XML,Stream.Size); Stream.Position:=0; Stream.ReadBuffer(XML[1],Length(XML));
    Images:=0; for I:=1 to Length(XML)-5 do if Copy(XML,I,6)='<image' then Inc(Images);
    Gradients:=0; for I:=1 to Length(XML)-14 do
      if Copy(XML,I,15)='<linearGradient' then Inc(Gradients);
    Check(Images=0,'Linux SVG gradient shapes have no raster patches');
    Check(Gradients=4,'Linux SVG retains four vector gradient shape fills');
    Check(Pos('fill="url(#',XML)>0,'Linux SVG shapes reference gradient paint servers');
  finally SVG:=nil; Stream.Free; C.Free; end;
end;

procedure TestNativeGlyphCache;
var C:TSkiaBitmapCanvas; LF:TLogFontW; G:TArray<TGdiShapedGlyph>; Key:string;
    Em,I:Integer; A,V,AV:Single; Advance:Single; Path:ISkPath;
  function Width(const S:UnicodeString):Single;
  var Glyph:TGdiShapedGlyph;
  begin
    Result:=0;
    Check(C.GlyphCache.ShapeText(LF,Key,Em,S,G,True),'native HarfBuzz cache shapes '+string(S));
    for Glyph in G do Result:=Result+Glyph.AdvanceX;
  end;
begin
  C:=TSkiaBitmapCanvas.Create(20,20);
  try
    C.Font.Name:='DejaVu Sans'; C.Font.Height:=-30;
    C.FontManager.GetLogFont(C.Font,LF); Key:=C.FontManager.FontKey(C.Font);
    Em:=C.GlyphCache.GetEmSquare(LF,Key);
    A:=Width('A'); V:=Width('V'); AV:=Width('AV');
    Check(AV<A+V,'native glyph cache applies pair kerning');
    AV:=Width(#$644#$627); Check(Length(G)=1,'native cache lam-alef ligature');
    Check(C.GlyphCache.LastShapeUsedOpenType,'native cache reports actual shaping backend');
    if Length(G)>0 then begin
      Path:=C.GlyphCache.GetGlyphPathByIndex(G[0].GlyphIndex,Advance);
      Check(Path<>nil,'native glyph cache returns outline after shaping');
    end;
    Check(C.GlyphCache.ShapeText(LF,Key,Em,'',G,True) and (Length(G)=0),'native cache empty layout');
    Check(not C.GlyphCache.ShapeText(LF,Key,Em,WideChar($D800),G,True),'native cache rejects malformed UTF-16');
  finally C.Free; end;
end;

procedure TestCopyRect;
var Bitmap:TBitmap; Canvas:TCanvas; Dst:TSkiaBitmapCanvas;
begin
  Bitmap:=TBitmap.Create; Dst:=TSkiaBitmapCanvas.Create(24,24);
  try
    Bitmap.SetSize(8,8);
    Bitmap.Canvas.Brush.Color:=clBlue; Bitmap.Canvas.FillRect(Rect(0,0,4,8));
    Bitmap.Canvas.Brush.Color:=clRed; Bitmap.Canvas.FillRect(Rect(4,0,8,8));
    Canvas:=Bitmap.Canvas;
    Dst.CopyRect(Rect(0,0,16,8),Canvas,Rect(8,0,0,8));
    Check((Dst.Pixels[2,3]=clRed) and (Dst.Pixels[13,3]=clBlue),'CopyRect TCanvas scaling and reflection');
    Dst.CopyRect(Rect(0,8,8,16),Dst,Rect(0,0,8,8));
    Check(Dst.Pixels[2,11]=clRed,'CopyRect Skia self copy');
    Dst.CopyRect(Rect(0,0,8,8),TCanvas(nil),Rect(0,0,8,8));
  finally Dst.Free; Bitmap.Free; end;
end;

procedure TestNativeOutput;
var Canvas:TSkiaBitmapCanvas; Bitmap:TBitmap; Stream:TFileStream;
    SVG:ISkCanvas; Doc:ISkDocument; OutDir:string; X,Y,Ink:Integer;
begin
  OutDir:=IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Canvas:=TSkiaBitmapCanvas.Create(96,64); Bitmap:=TBitmap.Create;
  try
    Canvas.Brush.Color:=clWhite; Canvas.FillRect(Rect(0,0,96,64));
    Canvas.Brush.Color:=clBlue; Canvas.FillRect(Rect(4,4,28,28));
    Canvas.Font.Name:='DejaVu Sans'; Canvas.Font.Color:=clBlack; Canvas.Font.Size:=12;
    Check(Canvas.TextWidth('Linux')>0,'native Linux font metrics');
    Canvas.TextOut(4,32,'Linux');
    Ink:=0;
    for Y:=32 to 63 do for X:=0 to 95 do
      if Canvas.Pixels[X,Y]<>clWhite then Inc(Ink);
    Check(Ink>20,'native Linux shaped text has visible pixels');
    Canvas.Flush(Bitmap); Bitmap.SaveToFile(OutDir+'linux-canvas.bmp');
    Check(Bitmap.Canvas.Pixels[10,10]=clBlue,'Linux bitmap export pixels');
    Canvas.Snapshot.EncodeToFile(OutDir+'linux-canvas.png');
    Stream:=TFileStream.Create(OutDir+'linux-canvas.svg',fmCreate);
    try
      SVG:=TSkSVGCanvas.Make(RectF(0,0,96,64),Stream);
      SVG.DrawImage(Canvas.Snapshot,0,0); SVG:=nil;
      Check(Stream.Size>0,'native Linux SVG output');
    finally SVG:=nil; Stream.Free; end;
    Stream:=TFileStream.Create(OutDir+'linux-canvas.pdf',fmCreate);
    try
      Doc:=TSkDocument.MakePDF(Stream);
      Doc.BeginPage(96,64).DrawImage(Canvas.Snapshot,0,0);
      Doc.EndPage; Doc.Close; Doc:=nil;
      Check(Stream.Size>0,'native Linux PDF output');
    finally Doc:=nil; Stream.Free; end;
  finally Bitmap.Free; Canvas.Free; end;
end;

procedure TestBitmapChannels;
var Bitmap:TBitmap; Image:TLazIntfImage; C:TFPColor;
    Dst:TSkiaBitmapCanvas; Pixels:TArray<TAlphaColor>;
begin
  Bitmap:=TBitmap.Create; Image:=TLazIntfImage.Create(3,2,[riqfRGB,riqfAlpha]);
  Dst:=TSkiaBitmapCanvas.Create(3,2);
  try
    C.Red:=65535; C.Green:=0; C.Blue:=0; C.Alpha:=32896;
    Image.FillPixels(C);
    C.Red:=0; C.Blue:=65535; C.Alpha:=65535; Image.Colors[0,1]:=C;
    Bitmap.LoadFromIntfImage(Image); Bitmap.AlphaFormat:=afDefined; Bitmap.Transparent:=False;
    Dst.BitBlt(0,0,3,2,Bitmap,0,0);
    SetLength(Pixels,6);
    Check(Dst.Snapshot.ReadPixels(TSkImageInfo.Create(3,2,TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul),Pointer(Pixels),12),'read Linux bitmap transfer alpha');
    begin
      Check((Pixels[0] shr 24=128) and ((Pixels[0] and $FFFFFF)=$FF0000),
        'Linux bitmap RGBA channels and alpha');
      Check(Pixels[3]=$FF0000FF,'Linux bitmap top/bottom row order');
    end;
    C.Red:=32896; C.Green:=0; C.Blue:=0; C.Alpha:=32896; Image.FillPixels(C);
    Bitmap.LoadFromIntfImage(Image); Bitmap.AlphaFormat:=afPremultiplied; Bitmap.Masked:=False;
    Dst.Brush.Color:=clBlack; Dst.FillRect(Rect(0,0,3,2));
    Dst.BitBlt(0,0,3,2,Bitmap,0,0);
    Check((ColorToRGB(Dst.Pixels[1,0]) and 255) in [127,128],
      'Linux premultiplied bitmap is unpremultiplied before composition');
    C.Red:=0; C.Blue:=65535; C.Alpha:=65535; Image.Colors[0,1]:=C;
    Bitmap.LoadFromIntfImage(Image); Bitmap.AlphaFormat:=afDefined;
    Bitmap.TransparentColor:=clBlue; Bitmap.Masked:=True;
    Dst.Brush.Color:=clWhite; Dst.FillRect(Rect(0,0,3,2));
    Dst.StretchBlt(0,0,3,2,Bitmap,0,0,3,2);
    Check(Dst.Pixels[0,1]=clWhite,'Linux bitmap color key preserves destination');
  finally Dst.Free; Image.Free; Bitmap.Free; end;
end;

begin
  if SysUtils.GetEnvironmentVariable('SKIA_TEST_GROUP') = 'review-compat' then
  begin
    T_CompatPenModes;
    T_CompatCopyRops;
    T_CompatTransparencyAndMirroring;
    T_CompatVectorRasterOps;
    T_CompatClipStackAndFlood;
    T_CompatSourceCoordinates;
    T_CompatPrepaintedSurface;
    T_CompatBrushKeyAndFrame;
    T_CompatNonRectangularClip;
    T_CompatInsideFrameClosedShapes;
    T_BltNativeSources;
    TestInputValidation;
  end
  else
  if SysUtils.GetEnvironmentVariable('SKIA_TEST_GROUP') = 'review' then
    TestInputValidation
  else
  if SysUtils.GetEnvironmentVariable('SKIA_TEST_GROUP') = 'textpath-affine' then
  begin
    Writeln('Test group: textpath-affine');
    TestTextOnPath;
    TestAffineTextOnPathOptions;
  end
  else
  begin
  TestInputValidation;
  Writeln('Native Linux / FPC / Skia ',TSkVersion.ToString);
  TestUpdatedSkiaBindings;
  TestCanvasRasterSettingsAndPixmap;
  TestAffineRasterOptions;
  TestAffineTextOnPathOptions;
  T_BltNativeSources;
  TestNativeGlyphCache;
  TestCopyRect;
  TestBitmapChannels;
  TestNativeOutput;
  TestGenericGraphic;
  TestGradientShapeExport;
  T_BrushAssignFromProps;
  T_PenAssignFromProps;
  T_BrushPatternFromBitmap;
  T_ResourceManagerCache;
  T_FontAlpha;
  T_FontManagerCache;
  T_FontManagerCustom;
  T_FontManagerInvalidatesResourceCache;
  T_PenDashEffect;
  T_FillRectPixel;
  T_StrokeRectPixel;
  T_EllipsePixel;
  T_GradientPixel;
  T_HatchPixel;
  T_DrawImagePixel;
  T_DrawWithOpacity;
  T_FlushToBitmap;
  T_FloodFill;
  T_ClipRect;
  T_RotateTransform;
  T_RotateDrawRect;
  T_TranslateTransform;
  T_SaveRestoreState;
  T_TextOutLog;
  T_TextExtent;
  T_ArcAngles;
  T_MetafileRecordPlayback;
  T_MetafileDrawAfterFinish;
  T_FloodFillBorder;
  T_TextUnderline;
  T_TextToCurves;
  T_TextToCurvesOff;
  T_TextOpaqueBackground;
  T_TextTransparentBackground;
  T_MetafileSerialize;
  T_PdfExport;
  T_SvgExport;
  T_SvgTransform;
  T_TextRectNoSaveLeak;
  T_TextRectCalcRect;
  T_CompatPenModes;
  T_CompatCopyRops;
  T_CompatTransparencyAndMirroring;
  T_CompatVectorRasterOps;
  T_CompatTextLayout;
  T_CompatClipStackAndFlood;
  T_CompatInsideFrame;
  T_CompatPrefixAndCustomCurves;
  T_CompatSourceCoordinates;
  T_CompatPrepaintedSurface;
  T_CompatBrushKeyAndFrame;
  T_CompatNonRectangularClip;
  T_CompatFontChangeObserver;
  T_CompatExternalTypeface;
  T_CompatFontOrientation;
  T_CompatInsideFrameClosedShapes;

  T_AdvancedKerning;
  T_AdvancedEmptyAndInvalid;
  T_AdvancedComplexShaping;
  T_AdvancedNestedState;
  T_AdvancedOutlineExport;
  T_AdvancedAlpha;
  T_AtlasClipResetMatrix;
  T_AtlasMaskSelfCopy;
  T_AtlasTransfers;
  T_AtlasClipShapes;
  T_AtlasStateModes;
  T_AtlasBrushPenCatalog;
  TestNativePngDecoding;
  TestTextOnPath;
  TestThreadSafety;
  end;
  Writeln('Linux: ',Passed,' passed; ',Failed,' failed');
  if Failed<>0 then Halt(1);
end.
