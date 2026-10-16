{ Drawing examples for the public canvas API. }
unit SkiaAtlasScenes;
{$IFDEF FPC}{$MODE DELPHIUNICODE}{$CODEPAGE UTF8}{$ENDIF}
interface
uses Classes, SysUtils, Types, Math,
  System.UITypes, {$IFNDEF FPC}System.Math.Vectors,{$ENDIF}
  {$IFDEF MSWINDOWS}{$IFDEF FPC}Windows,{$ELSE}Winapi.Windows,{$ENDIF}{$ELSE}LCLType,{$ENDIF} Vcl.Graphics, System.Skia, Vcl.Graphics.Skia, SkiaDemoScenes, SkiaUsageExamples;
const AtlasPageCount = 12;
  TextPathCyrillicCaption = 'Текст по кривой';
  TextPathMixedCaption = 'AB سَلامُ 12';
function AtlasPageName(Index: Integer): string;
{ Draw individual examples on a ShowcaseWidth x ShowcaseHeight canvas.
  Panel and Note add the page layout and captions. These procedures change
  canvas state; when embedding them in another scene, use SaveState with
  try..finally and RestoreState around the call. }
procedure DrawPrimitives(C: TSkiaCanvas);
procedure DrawBrushes(C: TSkiaCanvas);
procedure DrawPens(C: TSkiaCanvas);
procedure DrawTransfers(C: TSkiaCanvas);
procedure DrawClipsTransforms(C: TSkiaCanvas);
procedure DrawTextFonts(C: TSkiaCanvas);
procedure DrawRasterResources(C: TSkiaCanvas);
procedure DrawRopsAndFormatting(C: TSkiaCanvas);
procedure DrawAtlasPage(C: TSkiaCanvas; Index: Integer);
implementation
type
  TAtlasChangeCounter = class
    Count: Integer;
    procedure Changed(Sender: TObject);
  end;
procedure TAtlasChangeCounter.Changed(Sender: TObject);
begin Inc(Count); end;
const Ink = TColor($512514); Muted = TColor($78665E);
function AtlasPageName(Index: Integer): string;
begin
  case Index of
    0: Result:='01-typography'; 1: Result:='02-primitives';
    2: Result:='03-brushes'; 3: Result:='04-pens';
    4: Result:='05-transfers'; 5: Result:='06-clips-transforms';
    6: Result:='07-text-fonts'; 7: Result:='08-raster-resources'; 8: Result:='09-rop-formatting';
    9: Result:='10-unicode-fonts';10: Result:='11-unicode-rtl';11: Result:='12-text-on-path';
  else raise ESkiaCanvasError.Create('Unknown atlas page'); end;
end;
function AtlasRectF(L,T,R,B: Single): TRectF;
begin Result.Left:=L; Result.Top:=T; Result.Right:=R; Result.Bottom:=B; end;
procedure Clean(C: TSkiaCanvas);
begin
  C.ResetClip; C.ResetWorldTransform;
  C.Brush.Pattern:=nil; C.Brush.Gradient:=gkNone;
  C.Brush.Style:=bsSolid; C.Brush.Color:=clWhite; C.Brush.Alpha:=255;
  C.Pen.Style:=psSolid; C.Pen.Color:=Ink; C.Pen.Alpha:=255; C.Pen.Width:=2;
  C.Pen.Mode:=pmCopy; C.Pen.DashPattern:=nil;
  C.Pen.StrokeCap:=TSkStrokeCap.Butt; C.Pen.StrokeJoin:=TSkStrokeJoin.Miter;
  C.Pen.MiterLimit:=4; C.Font.Style:=[]; C.Font.Alpha:=255;
  C.TextToCurves:=True; C.CopyMode:=cmSrcCopy;
end;
procedure Panel(C: TSkiaCanvas; Column,Row: Integer; const Title,Subtitle: string;
  out X,Y: Integer);
begin
  Clean(C); X:=24+488*Column; Y:=148+360*Row;
  Card(C,X,Y,Title,Subtitle);
  C.Brush.Style:=bsClear; C.Pen.Color:=Ink; C.Pen.Width:=2;
end;
procedure Note(C: TSkiaCanvas; X,Y: Integer; const S: string);
begin LabelText(C,X+20,Y+290,13,UnicodeString(S),Muted); end;
procedure Backdrop(C: TSkiaCanvas; X,Y,W,H: Integer);
begin
  C.Brush.Style:=bsSolid; C.Brush.Color:=TColor($F8EEDF);
  C.FillRect(Types.Rect(X,Y,X+W,Y+H)); C.Brush.Style:=bsClear;
end;
procedure BeginPage(C: TSkiaCanvas; Index: Integer; const Title,Subtitle: string);
begin
  Clean(C); C.Brush.Color:=TColor($F7F5F1);
  C.FillRect(Types.Rect(0,0,ShowcaseWidth,ShowcaseHeight));
  C.Brush.Gradient:=gkHorizontal;
  C.Brush.GradientStartColor:=TColor($512514); C.Brush.GradientEndColor:=TColor($805D21);
  C.FillRect(Types.Rect(0,0,ShowcaseWidth,124)); C.Brush.Gradient:=gkNone;
  LabelText(C,28,24,32,UnicodeString(Title),clWhite);
  LabelText(C,30,76,15,UnicodeString(Subtitle),clWhite);
  LabelText(C,28,1232,14,UnicodeString(Format('Page %d / %d   |   %s',[Index+1,AtlasPageCount,AtlasPageName(Index)])));
end;
procedure DrawPrimitives(C: TSkiaCanvas);
var X,Y: Integer;
begin
  Panel(C,0,0,'Lines + polygonal paths','MoveTo / LineTo / PenPos / Polyline / Polygon',X,Y);
  C.MoveTo(X+30,Y+100); C.LineTo(X+210,Y+130); C.LineTo(X+70,Y+170);
  C.PenPos:=Types.Point(X+260,Y+100); C.LineTo(X+420,Y+170);
  C.Polyline([Types.Point(X+30,Y+220),Types.Point(X+120,Y+180),Types.Point(X+200,Y+250)]);
  C.Brush.Style:=bsSolid; C.Brush.Color:=TColor($EAD183);
  C.Polygon([Types.Point(X+270,Y+210),Types.Point(X+340,Y+170),Types.Point(X+420,Y+230),Types.Point(X+360,Y+260)]);
  Note(C,X,Y,Format('PenPos = (%d, %d)',[C.PenPos.X,C.PenPos.Y]));
  Panel(C,1,0,'Closed shapes + fill / stroke','Rectangle / RoundRect / Ellipse / FillRect',X,Y);
  C.Brush.Style:=bsSolid; C.Brush.Color:=TColor($F2D6B3);
  C.Rectangle(X+24,Y+100,X+210,Y+175);
  C.RoundRect(X+240,Y+100,X+430,Y+175,30,30);
  C.Brush.Color:=TColor($E4E2A4); C.Ellipse(X+24,Y+195,X+210,Y+265);
  C.FillRect(Types.Rect(X+240,Y+195,X+430,Y+265));
  Note(C,X,Y,'Stroke + fill are independent; bsClear removes fill.');
  Panel(C,0,1,'Arcs + current position','Arc / ArcTo / AngleArc (VCL angle convention)',X,Y);
  C.Pen.Width:=4;
  C.Arc(X+25,Y+95,X+155,Y+225,X+155,Y+160,X+90,Y+225);
  C.MoveTo(X+190,Y+240);
  C.ArcTo(X+175,Y+95,X+305,Y+225,X+305,Y+160,X+240,Y+225);
  C.AngleArc(X+380,Y+165,55,20,250);
  Note(C,X,Y,'ArcTo connects from PenPos; AngleArc uses degrees.');
  Panel(C,1,1,'Arc closures','Chord / Pie / overlapping translucent interiors',X,Y);
  C.Brush.Style:=bsSolid; C.Brush.Color:=clBlue; C.Brush.Alpha:=110;
  C.Chord(X+25,Y+105,X+210,Y+255,X+210,Y+180,X+115,Y+255);
  C.Brush.Color:=clRed;
  C.Pie(X+240,Y+105,X+430,Y+255,X+430,Y+180,X+335,Y+255);
  Note(C,X,Y,'Chord closes endpoints; Pie connects through center.');
  Panel(C,0,2,'Cubic curves','PolyBezier / PolyBezierTo',X,Y);
  C.Pen.Width:=4; C.Pen.Color:=clBlue;
  C.PolyBezier([Types.Point(X+25,Y+220),Types.Point(X+100,Y+50),Types.Point(X+160,Y+300),Types.Point(X+235,Y+160)]);
  C.Pen.Color:=clRed;
  C.PolyBezierTo([Types.Point(X+285,Y+50),Types.Point(X+360,Y+280),Types.Point(X+430,Y+120)]);
  Note(C,X,Y,'BezierTo begins at the current PenPos.');
  Panel(C,1,2,'Frames + focus + refresh','FrameRect / DrawFocusRect / Refresh',X,Y);
  C.Brush.Style:=bsSolid; C.Brush.Color:=clBlue;
  C.FrameRect(Types.Rect(X+35,Y+110,X+210,Y+245));
  C.DrawFocusRect(Types.Rect(X+245,Y+110,X+430,Y+245)); C.Refresh;
  Note(C,X,Y,'Refresh is a no-op: drawing is immediate.');
end;
function PatternBitmap: TBitmap;
var X,Y: Integer;
begin
  Result:=TBitmap.Create; Result.PixelFormat:=pf32bit; Result.SetSize(16,16);
  for Y:=0 to 15 do for X:=0 to 15 do
    if ((X div 4)+(Y div 4)) mod 2=0 then Result.Canvas.Pixels[X,Y]:=clNavy
    else Result.Canvas.Pixels[X,Y]:=TColor($EAD183);
end;
procedure DrawBrushes(C: TSkiaCanvas);
const Names: array[0..7] of string=('bsSolid','bsClear','bsHorizontal','bsVertical',
  'bsFDiagonal','bsBDiagonal','bsCross','bsDiagCross');
var X,Y,I,XX,YY: Integer; Bmp: TBitmap; B: TSkiaBrush; Src: TBrush;
begin
  Panel(C,0,0,'All eight brush styles','TBrushStyle / identical background and foreground',X,Y);
  for I:=0 to 7 do begin
    XX:=X+20+(I mod 4)*108; YY:=Y+95+(I div 4)*85;
    Backdrop(C,XX,YY,96,48); C.Brush.Style:=TBrushStyle(I); C.Brush.Color:=Ink;
    C.FillRect(Types.Rect(XX,YY,XX+96,YY+48));
    LabelText(C,XX,YY+54,10,UnicodeString(Names[I]));
  end;
  Note(C,X,Y,'bsClear leaves the destination unchanged.');
  Panel(C,1,0,'Horizontal + vertical gradients','GradientStartColor / GradientEndColor',X,Y);
  C.Brush.Style:=bsSolid; C.Brush.GradientStartColor:=clRed; C.Brush.GradientEndColor:=clBlue;
  C.Brush.Gradient:=gkHorizontal; C.FillRect(Types.Rect(X+25,Y+105,X+435,Y+165));
  C.Brush.Gradient:=gkVertical; C.FillRect(Types.Rect(X+25,Y+190,X+435,Y+255));
  C.Brush.Gradient:=gkNone;
  Note(C,X,Y,'Gradient coordinates follow each shape bounds.');
  Panel(C,0,1,'Bitmap patterns','Pattern property / Assign(TBitmap) / ownership copy',X,Y);
  Bmp:=PatternBitmap;
  try
    C.Brush.Pattern:=Bmp; C.Brush.Style:=bsSolid;
    C.FillRect(Types.Rect(X+25,Y+105,X+210,Y+255));
    C.Brush.Assign(Bmp); C.FillRect(Types.Rect(X+240,Y+105,X+435,Y+255));
  finally Bmp.Free; end;
  C.Brush.Pattern:=nil;
  Note(C,X,Y,'Original bitmap can be freed after assigning the brush.');
  Panel(C,1,1,'Alpha ramp','Solid / gradient / bitmap pattern opacity',X,Y);
  Bmp:=PatternBitmap;
  try
    for I:=0 to 3 do begin
      XX:=X+25+I*103;
      Backdrop(C,XX,Y+105,90,150);
      C.Brush.Style:=bsSolid; C.Brush.Color:=clRed; C.Brush.Alpha:=64+I*63;
      C.FillRect(Types.Rect(XX,Y+105,XX+90,Y+145));
      C.Brush.Gradient:=gkVertical; C.Brush.GradientStartColor:=clRed; C.Brush.GradientEndColor:=clBlue;
      C.FillRect(Types.Rect(XX,Y+155,XX+90,Y+195)); C.Brush.Gradient:=gkNone;
      C.Brush.Pattern:=Bmp; C.FillRect(Types.Rect(XX,Y+205,XX+90,Y+255)); C.Brush.Pattern:=nil;
    end;
  finally Bmp.Free; end;
  C.Brush.Alpha:=255; Note(C,X,Y,'Columns: alpha = 64, 127, 190, 253.');
  Panel(C,0,2,'Assign + visibility','VCL TBrush / TSkiaBrush / IsVisible',X,Y);
  B:=TSkiaBrush.Create; Src:=TBrush.Create;
  try
    Src.Color:=clBlue; Src.Style:=bsCross;
    if Src.Handle=0 then raise ESkiaCanvasError.Create('Brush handle unavailable');
    B.Assign(Src); C.Brush.Assign(B);
    C.FillRect(Types.Rect(X+25,Y+100,X+210,Y+250));
    B.Alpha:=100; C.Brush.Assign(B); C.FillRect(Types.Rect(X+240,Y+100,X+435,Y+250));
    Note(C,X,Y,'Assigned brush is visible: '+BoolToStr(B.IsVisible,True));
  finally Src.Free; B.Free; end;
  Panel(C,1,2,'Resource cache + invalidation','AcquireFillPaint / InvalidateBrush / InvalidateAll',X,Y);
  LabelText(C,X+25,Y+105,24,'Same key -> same paint');
  LabelText(C,X+25,Y+157,20,'Color / alpha / bounds -> new paint');
  LabelText(C,X+25,Y+209,20,'OnChange invalidates canvas resources');
  Note(C,X,Y,'Cache identity is also checked in runtime diagnostics.');
end;
procedure DrawPens(C: TSkiaCanvas);
const StyleNames: array[0..6] of string=('psSolid','psDash','psDot','psDashDot','psDashDotDot','psClear','psInsideFrame');
  ModeNames: array[0..15] of string=('pmBlack','pmWhite','pmNop','pmNot','pmCopy','pmNotCopy','pmMergePenNot',
  'pmMaskPenNot','pmMergeNotPen','pmMaskNotPen','pmMerge','pmNotMerge','pmMask','pmNotMask','pmXor','pmNotXor');
var X,Y,I,J,XX,YY: Integer; P: TSkiaPen; Src: TPen;
begin
  Panel(C,0,0,'All seven pen styles','Pen.Style / Width = 2',X,Y);
  for I:=0 to 6 do begin
    YY:=Y+96+I*24; LabelText(C,X+22,YY,12,UnicodeString(StyleNames[I]));
    C.Pen.Style:=TPenStyle(I); C.Pen.Width:=2; C.MoveTo(X+145,YY+8); C.LineTo(X+435,YY+8);
  end;
  Note(C,X,Y,'psInsideFrame keeps the stroke inside closed shape bounds.');
  Panel(C,1,0,'Width / alpha / custom dashes','Widths 1, 5, 9, 13; user dash [12,4,2,4]',X,Y);
  for I:=0 to 3 do begin
    C.Pen.Width:=1+I*4; C.Pen.Alpha:=70+I*60; C.Pen.Color:=clBlue;
    C.MoveTo(X+25,Y+105+I*38); C.LineTo(X+435,Y+105+I*38);
  end;
  C.Pen.Alpha:=255; C.Pen.Width:=3; C.Pen.DashPattern:=TArray<Single>.Create(12,4,2,4);
  C.MoveTo(X+25,Y+265); C.LineTo(X+435,Y+265); C.Pen.DashPattern:=nil;
  Note(C,X,Y,'Alpha, stroke width and user dash are independent.');
  Panel(C,0,1,'Stroke caps','Butt / Round / Square; vertical guides show endpoints',X,Y);
  for I:=0 to 2 do begin
    C.Pen.Width:=1; C.Pen.Color:=clRed;
    C.MoveTo(X+90,Y+110+I*60); C.LineTo(X+90,Y+145+I*60);
    C.MoveTo(X+370,Y+110+I*60); C.LineTo(X+370,Y+145+I*60);
    C.Pen.Width:=18; C.Pen.Color:=Ink; C.Pen.StrokeCap:=TSkStrokeCap(I);
    C.MoveTo(X+90,Y+128+I*60); C.LineTo(X+370,Y+128+I*60);
  end;
  Note(C,X,Y,'Caps extend beyond / stop at the geometric endpoints.');
  Panel(C,1,1,'Stroke joins + miter limit','Miter / Round / Bevel / clipped miter',X,Y);
  for I:=0 to 3 do begin
    XX:=X+28+I*105; C.Pen.Width:=12; C.Pen.StrokeJoin:=TSkStrokeJoin(Math.Min(I,2));
    if I=3 then begin C.Pen.StrokeJoin:=TSkStrokeJoin.Miter; C.Pen.MiterLimit:=1; end;
    C.Polyline([Types.Point(XX,Y+240),Types.Point(XX+40,Y+110),Types.Point(XX+80,Y+240)]);
  end;
  P:=TSkiaPen.Create; Src:=TPen.Create;
  try Src.Style:=psDash; Src.Color:=clBlue;
    if Src.Handle=0 then raise ESkiaCanvasError.Create('Pen handle unavailable');
    P.Assign(Src); C.Pen.Assign(P); finally Src.Free; P.Free; end;
  Note(C,X,Y,'Pen.Assign(VCL) / IsVisible = '+BoolToStr(C.Pen.IsVisible,True));
  for J:=0 to 1 do begin
    Panel(C,J,2,'Pen.Mode: '+IntToStr(J*8)+'..'+IntToStr(J*8+7),'All 16 Boolean combinations of source and destination',X,Y);
    for I:=0 to 7 do begin
      XX:=X+20+(I mod 4)*108; YY:=Y+94+(I div 4)*90;
      Backdrop(C,XX,YY,96,56); C.Pen.Mode:=TPenMode(I+J*8); C.Pen.Width:=8;
      C.Pen.Color:=clBlue; C.MoveTo(XX+12,YY+28); C.LineTo(XX+84,YY+28);
      C.Pen.Mode:=pmCopy;
      LabelText(C,XX,YY+62,9,UnicodeString(ModeNames[I+J*8]));
    end;
    Note(C,X,Y,'Each mode changes the same blue stroke over the backdrop.');
  end;
end;
procedure MakeSource(S: TSkiaBitmapCanvas);
begin
  S.Brush.Color:=TColor($EAD183); S.FillRect(Types.Rect(0,0,S.Width,S.Height));
  S.Brush.Color:=clBlue; S.FillRect(Types.Rect(0,0,60,40));
  S.Brush.Color:=clRed; S.FillRect(Types.Rect(60,40,120,80));
  S.Pen.Color:=clWhite; S.Pen.Width:=3;
  S.MoveTo(12,65); S.LineTo(95,16); S.LineTo(88,42);
  S.MoveTo(95,16); S.LineTo(65,16);
end;
function MaskBitmap: TBitmap;
var X,Y: Integer;
begin
  Result:=TBitmap.Create; Result.PixelFormat:=pf32bit; Result.SetSize(120,80);
  for Y:=0 to 79 do for X:=0 to 119 do
    if Sqr((X-60)/50)+Sqr((Y-40)/30)<1 then Result.Canvas.Pixels[X,Y]:=clWhite
    else Result.Canvas.Pixels[X,Y]:=clBlack;
end;
procedure DrawTransfers(C: TSkiaCanvas);
var X,Y: Integer; S: TSkiaBitmapCanvas; Bmp,Mask: TBitmap;
begin
  S:=TSkiaBitmapCanvas.Create(120,80); Bmp:=TBitmap.Create;
  Mask:=MaskBitmap;
  try
    MakeSource(S); S.Flush(Bmp);
    Panel(C,0,0,'Source / Draw / opacity','Asymmetric source makes cropping and flipping visible',X,Y);
    C.Draw(X+25,Y+110,Bmp); C.Draw(X+190,Y+110,Bmp,110);
    C.StretchDraw(Types.Rect(X+325,Y+110,X+435,Y+245),Bmp);
    Note(C,X,Y,'Draw(TBitmap) / Draw(...,Opacity) / StretchDraw.');
    Panel(C,1,0,'BitBlt + CopyRect','Full copy and cropped source rectangle',X,Y);
    C.BitBlt(X+25,Y+120,120,80,S,0,0);
    C.CopyRect(Types.Rect(X+225,Y+110,X+425,Y+255),S,Types.Rect(30,10,110,70));
    Note(C,X,Y,'CopyMode controls the Boolean source/destination operation.');
    Panel(C,0,1,'StretchBlt','Expansion / compression / nonuniform scale',X,Y);
    C.StretchBlt(X+25,Y+105,260,150,S,0,0,120,80);
    C.StretchBlt(X+315,Y+105,60,40,S,0,0,120,80);
    C.StretchBlt(X+425,Y+170,-110,85,S,0,0,120,80);
    Note(C,X,Y,'Signed dimensions also support horizontal / vertical mirroring.');
    Panel(C,1,1,'PlgBlt','Three points define the affine destination parallelogram',X,Y);
    C.PlgBlt([Types.Point(X+50,Y+140),Types.Point(X+330,Y+95),Types.Point(X+120,Y+260)],S,0,0,120,80);
    C.Pen.Style:=psDot; C.Polygon([Types.Point(X+50,Y+140),Types.Point(X+330,Y+95),Types.Point(X+400,Y+215),Types.Point(X+120,Y+260)]);
    Note(C,X,Y,'Source origin + two basis vectors determine the warp.');
    Panel(C,0,2,'MaskBlt','White mask copies source; black keeps destination',X,Y);
    C.Draw(X+25,Y+110,Mask);
    DrawMaskedTransfer(C, S, Mask, Types.Rect(0,0,120,80), Types.Point(X+225,Y+115), 1.6);
    Note(C,X,Y,'MaskBlt works on all targets, with clipping and transforms.');
    Panel(C,1,2,'BrushCopy + SRCINVERT','Blue key becomes brush color; right sample uses XOR',X,Y);
    C.Brush.Color:=clGreen; C.Brush.Style:=bsSolid; C.FillRect(Types.Rect(X+25,Y+110,X+210,Y+245));
    DrawKeyedBitmap(C, Bmp, Types.Rect(0,0,120,80), Types.Rect(X+25,Y+110,X+210,Y+245), clBlue, clGreen);
    DrawXorCopy(C, S, Types.Rect(0,0,120,80), Types.Rect(X+240,Y+110,X+435,Y+245));
    Note(C,X,Y,'Color-key substitution and destination-dependent ROP are active.');
  finally Mask.Free; Bmp.Free; S.Free; end;
end;
procedure DrawClipsTransforms(C: TSkiaCanvas);
var
  X, Y, I, SavedState, InnerState: Integer;
  Bounds: TRect;
  World: TMatrix;
  DevicePoint, LogicalPoint: TPoint;
  ClipBuilder: ISkiaPathBuilder;
begin
  Panel(C,0,0,'Set / intersect / exclude clip',
    'SetClipRect / IntersectClipRect / ExcludeClipRect',X,Y);
  Backdrop(C,X+20,Y+95,424,170);
  Bounds := DrawClippedFill(C,
    Types.Rect(X+40,Y+105,X+420,Y+250), Types.Rect(X+110,Y+95,X+370,Y+265),
    Types.Rect(X+185,Y+140,X+285,Y+210), Types.Rect(X+20,Y+95,X+444,Y+265), TColor($E4D883));
  Note(C,X,Y,Format('Automatic difference-clip fallback; bounds %dx%d',
    [Bounds.Width,Bounds.Height]));

  Panel(C,1,0,'Region clip + ResetClip',
    'SetClipRegion(TRect) / reset / draw outside old clip',X,Y);
  SavedState := C.SaveState;
  try
    C.SetClipRegion(Types.Rect(X+35,Y+110,X+230,Y+245));
    { Use a path for curved clip boundaries. SetClipPath replaces the current clip. }
    ClipBuilder := TSkiaPathBuilder.Create;
    ClipBuilder.AddOval(AtlasRectF(X+50,Y+115,X+225,Y+240));
    C.SetClipPath(ClipBuilder.Snapshot);
    C.Brush.Style := bsSolid;
    C.Brush.Color := TColor($E4D883);
    C.FillRect(Types.Rect(X+15,Y+90,X+450,Y+270));
    C.ResetClip;
    C.Brush.Color := clRed;
    C.Ellipse(X+300,Y+135,X+410,Y+225);
  finally
    C.RestoreState(SavedState);
  end;
  Note(C,X,Y,'Arbitrary path/region clips; ResetClip removes the old shape.');

  Panel(C,0,1,'Rotate / scale / translate',
    'Transform order is explicit: local -> rotated -> device',X,Y);
  SavedState := C.SaveState;
  try
    { Apply local rotation and scaling before positioning the scene
      on the page; transform composition depends on call order. }
    C.RotateTransform(-20);
    C.ScaleTransform(1.2,0.8);
    C.TranslateTransform(X+125,Y+200);
    C.Brush.Style := bsSolid;
    C.Brush.Color := TColor($E4D883);
    C.Rectangle(-60,-40,120,40);
    C.Pen.Color := clRed;
    C.MoveTo(-70,0);
    C.LineTo(160,0);
  finally
    C.RestoreState(SavedState);
  end;
  Note(C,X,Y,'All geometry shares the same world transform.');

  Panel(C,1,1,'World matrix + inverse coordinates',
    'Set/Get/ResetWorldTransform / LPToDP / DPToLP',X,Y);
  World := TMatrix.Identity;
  World.M11 := 1;
  World.M21 := 0.55; // Horizontal shear proportional to Y.
  World.M22 := 0.8;
  World.M31 := X+80;
  World.M32 := Y+120;
  SavedState := C.SaveState;
  try
    C.SetWorldTransform(World);
    World := C.GetWorldTransform;
    C.Brush.Style := bsSolid;
    C.Brush.Color := TColor($E4D883);
    C.Rectangle(0,0,230,130);
    DevicePoint := C.LPToDP(Types.Point(50,30));
    LogicalPoint := C.DPToLP(DevicePoint);
    C.ResetWorldTransform;
  finally
    C.RestoreState(SavedState);
  end;
  LabelText(C,X+22,Y+265,12,UnicodeString(Format('(50,30) -> (%d,%d) -> (%d,%d)',
    [DevicePoint.X,DevicePoint.Y,LogicalPoint.X,LogicalPoint.Y])));
  Note(C,X,Y,Format('Shear M21 = %.2f; origin restored after Reset.',[World.M21]));

  Panel(C,0,2,'Nested SaveState / RestoreState',
    'Style, matrix, pen position, text mode and clip restored',X,Y);
  SavedState := C.SaveState;
  try
    C.Brush.Style := bsSolid;
    C.Brush.Color := clBlue;
    C.Brush.Alpha := 100;
    C.TranslateTransform(X+55,Y+135);
    C.Rectangle(0,0,150,100);
    InnerState := C.SaveState;
    try
      C.ResetWorldTransform;
      C.RotateTransform(15);
      C.Brush.Color := clRed;
      C.TranslateTransform(X+245,Y+120);
      C.Rectangle(0,0,120,85);
    finally
      C.RestoreState(InnerState);
    end;
    { The translucent blue brush and the outer translation are restored. }
    C.Pen.Color := clGreen;
    C.Rectangle(0,0,150,100);
  finally
    C.RestoreState(SavedState);
  end;
  DevicePoint := C.LPToDP(Types.Point(0,0));
  Note(C,X,Y,Format('LIFO restore: origin (%d,%d), Brush.Alpha=%d',
    [DevicePoint.X,DevicePoint.Y,C.Brush.Alpha]));

  Panel(C,1,2,'Indexed restore / discard inner states',
    'RestoreState(index) unwinds all younger snapshots',X,Y);
  SavedState := C.SaveState;
  try
    for I := 0 to 2 do
    begin
      C.SaveState;
      C.TranslateTransform(35,15);
      C.Brush.Style := bsSolid;
      C.Brush.Color := clBlue;
      C.Brush.Alpha := 70;
      C.Rectangle(X+30,Y+100,X+265,Y+205);
    end;
  finally
    { Restoring this index also discards all younger state snapshots. }
    C.RestoreState(SavedState);
  end;
  C.Pen.Color := clRed;
  C.Brush.Style := bsClear;
  C.Rectangle(X+30,Y+100,X+265,Y+205);
  Note(C,X,Y,'Red outline: original coordinates after indexed unwind.');
end;

procedure DrawTextFonts(C: TSkiaCanvas);
var X,Y,I,TW,TH,Saved: Integer; R: TRect; S: string; Size: TSize; F: TSkiaFont; VclF: TFont;
  Manager: TSkiaFontManager; Custom: ISkTypeface; Stream: TMemoryStream;
  FontFile: string; Metrics: TSkFontMetrics;
  Flags: TTextFormat;
begin
  Panel(C,0,0,'Font rasterization options','FontEdging / FontHinting / FontSubpixel',X,Y);
  Saved:=C.SaveState;
  try
    C.Brush.Style:=bsSolid; C.Brush.Color:=clWhite;
    C.FillRect(Types.Rect(X+22,Y+98,X+442,Y+263)); C.Brush.Style:=bsClear;
    C.Font.Name:='Times New Roman'; C.Font.Height:=-24; C.Font.Color:=Ink;
    C.TextToCurves:=False;
    C.FontEdging:=TSkFontEdging.Alias; C.FontHinting:=TSkFontHinting.None; C.FontSubpixel:=False;
    C.TextOut(X+32,Y+110,'Alias / None / subpixel off');
    C.FontEdging:=TSkFontEdging.AntiAlias; C.FontHinting:=TSkFontHinting.Normal; C.FontSubpixel:=True;
    C.TextOut(X+32,Y+160,'AntiAlias / Normal / subpixel on');
    C.FontEdging:=TSkFontEdging.SubpixelAntiAlias; C.FontHinting:=TSkFontHinting.Full;
    C.TextOut(X+32,Y+210,'SubpixelAntiAlias / Full');
  finally C.RestoreState(Saved); end;
  Note(C,X,Y,'Raster glyph settings; recording canvases retain vector outlines.');
  Panel(C,1,0,'TextRect alignment + clipped overload','tfLeft / tfCenter / tfRight / explicit X,Y',X,Y);
  for I:=0 to 2 do begin
    R:=Types.Rect(X+25,Y+95+I*54,X+435,Y+140+I*54); Backdrop(C,R.Left,R.Top,R.Width,R.Height);
    C.Font.Height:=-23; C.Font.Color:=Ink;
    case I of 0: Flags:=[tfLeft]; 1: Flags:=[tfCenter]; else Flags:=[tfRight]; end;
    S:='TextRect alignment'; C.TextRect(R,S,Flags);
  end;
  C.TextRect(Types.Rect(X+25,Y+255,X+220,Y+280),X+25,Y+252,'Explicit coordinates + clip');
  Note(C,X,Y,'See page 9 for wrapping, ellipsis, tabs and prefix handling.');
  Panel(C,0,1,'Font styles + alpha','Bold / italic / underline / strikeout / transparency',X,Y);
  for I:=0 to 3 do begin
    C.Font.Name:='Arial'; C.Font.Height:=-27; C.Font.Color:=Ink;
    case I of 0: C.Font.Style:=[fsBold]; 1: C.Font.Style:=[fsItalic];
      2: C.Font.Style:=[fsUnderline]; 3: C.Font.Style:=[fsStrikeOut]; end;
    C.Font.Alpha:=255-I*45; C.TextOut(X+25,Y+100+I*44,'Font style / alpha');
  end;
  Note(C,X,Y,'Decorations are drawn by the canvas, not by the font.');
  Panel(C,1,1,'Metrics + tfCalcRect + assignment','TextExtent / TextWidth / TextHeight / AcquireFont',X,Y);
  F:=TSkiaFont.Create; VclF:=TFont.Create;
  try VclF.Name:='Arial'; VclF.Height:=-24; F.Assign(VclF); F.Alpha:=200; C.Font.Assign(F);
  finally VclF.Free; F.Free; end;
  C.Brush.Style:=bsClear; Size:=C.TextExtent('Measure AV'); C.AcquireFont.GetMetrics(Metrics);
  TW:=C.TextWidth('Measure AV'); TH:=C.TextHeight('Measure AV');
  LabelText(C,X+25,Y+100,22,'Measure AV');
  C.Pen.Style:=psDot; C.Rectangle(X+25,Y+100,X+25+Size.cx,Y+100+Size.cy);
  R:=Types.Rect(0,0,0,0); S:='Measure AV'; C.Font.Height:=-24; C.TextRect(R,S,[tfCalcRect]);
  LabelText(C,X+25,Y+165,14,UnicodeString(Format('Extent %dx%d; tfCalcRect %dx%d',[Size.cx,Size.cy,R.Width,R.Height])));
  LabelText(C,X+25,Y+205,14,UnicodeString(Format('Width=%d Height=%d Ascent=%.1f',[TW,TH,Metrics.Ascent])));
  Note(C,X,Y,'TFont.Assign reads VCL properties / real LOGFONT handles.');
  Panel(C,0,2,'Custom typeface registration','LoadTypefaceFromFile / FromStream / register / unregister',X,Y);
  Manager:=TSkiaFontManager.Create; Stream:=TMemoryStream.Create;
  Saved:=C.SaveState;
  try
    {$IFDEF MSWINDOWS}FontFile:=SysUtils.GetEnvironmentVariable('WINDIR')+'\Fonts\cour.ttf';{$ELSE}
    FontFile:='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf';{$ENDIF}
    Custom:=Manager.LoadTypefaceFromFile(FontFile); Stream.LoadFromFile(FontFile);
    Custom:=Manager.LoadTypefaceFromStream(Stream);
    C.FontManager.RegisterTypeface('AtlasCustom',Custom);
    C.Brush.Style:=bsSolid; C.Brush.Color:=clWhite;
    C.FillRect(Types.Rect(X+22,Y+100,X+442,Y+260)); C.Brush.Style:=bsClear;
    C.TextToCurves:=False; C.Font.Name:='AtlasCustom'; C.Font.Height:=-28; C.Font.Color:=Ink;
    C.TextOut(X+32,Y+120,'Custom typeface: 012345');
    C.FontManager.UnregisterTypeface('AtlasCustom');
    C.TextOut(X+32,Y+190,'Fallback: 012345'); Manager.Clear;
  finally
    C.FontManager.UnregisterTypeface('AtlasCustom');
    C.RestoreState(Saved); Stream.Free; Manager.Free;
  end;
  Note(C,X,Y,'Custom faces support shaped outlines and formatted text.');
  Panel(C,1,2,'Opaque / transparent text backgrounds','Brush.Style bsSolid vs bsClear; clipped rendering',X,Y);
  Backdrop(C,X+25,Y+100,410,165);
  C.Font.Height:=-28; C.Font.Color:=Ink; C.Font.Style:=[]; C.Font.Alpha:=255;
  C.Brush.Color:=TColor($C8E7FF); C.Brush.Style:=bsSolid; C.TextOut(X+35,Y+115,'Opaque background');
  C.Brush.Style:=bsClear; C.TextOut(X+35,Y+195,'Transparent background');
  C.Font.Orientation:=900; C.Font.Height:=-16; C.TextOut(X+420,Y+260,'Rotated'); C.Font.Orientation:=0;
  Note(C,X,Y,'Brush paint follows the measured shaped text bounds.');
end;
procedure DrawRasterResources(C: TSkiaCanvas);
var EmfFile:string;X,Y,I,J: Integer; D: TSkiaBitmapCanvas; Bmp: TBitmap; Manager: TSkiaResourceManager;
  B: TSkiaBrush; P: TSkiaPen; F: TFont; Fill1,Fill2,Stroke: ISkPaint; Font: ISkFont;
  Pixmap: ISkPixmap; PixmapPixels: array[0..3] of Cardinal;
  LF: TLogFontW; Key: string; Em,H: Integer; G: TArray<TGdiShapedGlyph>; Path: ISkPath;
  Advance: Single; Bounds: TRectF; Pic: ISkPicture; MC: TSkiaMetafileCanvas; MS: TMemoryStream;
  {$IFDEF MSWINDOWS}Graphic: TMetafile;{$ENDIF} Surface: ISkSurface; Counter: TAtlasChangeCounter; Wrapper: TSkiaCanvas;
begin
  Panel(C,0,0,'Pixels / Flush / Snapshot','A bitmap canvas exposes pixel reads and writes',X,Y);
  D:=TSkiaBitmapCanvas.Create(160,90); Bmp:=TBitmap.Create;
  try
    D.Brush.Color:=TColor($F8EEDF); D.FillRect(Types.Rect(0,0,160,90));
    for I:=0 to 15 do for J:=0 to 8 do D.Pixels[I*10,J*10]:=clRed;
    D.Pen.Color:=Ink; D.Pen.Width:=3; D.MoveTo(10,10); D.LineTo(145,75);
    Wrapper:=TSkiaCanvas.Create(D.SkCanvas,False);
    try Wrapper.Pen.Color:=clBlue; Wrapper.MoveTo(10,75); Wrapper.LineTo(145,10); finally Wrapper.Free; end;
    D.Flush(Bmp); C.StretchDraw(Types.Rect(X+25,Y+105,X+435,Y+255),Bmp);
    Pixmap:=TSkPixmap.Create(TSkImageInfo.Create(2,2,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),@PixmapPixels[0],8);
    if D.ReadPixels(Pixmap,10,10) then C.DrawPixmap(Types.Rect(X+390,Y+105,X+430,Y+145),Pixmap);
    Note(C,X,Y,'Pixels / Flush / Snapshot / ReadPixels / DrawPixmap.');
  finally Bmp.Free; D.Free; end;
  Panel(C,1,0,'FloodFill: surface and border','All targets; seed and boundary color select the filled area',X,Y);
  C.SaveState;
  try
    C.TranslateTransform(X+22,Y+100);
    C.Brush.Style:=bsSolid; C.Brush.Color:=clWhite; C.FillRect(Types.Rect(0,0,420,160));
    C.Brush.Style:=bsClear; C.Pen.Color:=clBlack; C.Pen.Width:=4;
    C.Rectangle(15,15,195,145); C.Rectangle(225,15,405,145);
    C.Brush.Style:=bsSolid; C.Brush.Color:=clBlue; C.FloodFill(80,80,clWhite,fsSurface);
    C.Brush.Color:=clRed; C.FloodFill(280,80,clBlack,fsBorder);
  finally C.RestoreState; end;
  Note(C,X,Y,'fsSurface fills the seed color; fsBorder stops at Color.');
  Panel(C,0,1,'Resource manager / cache lifecycle','Fill / stroke / font caches and explicit invalidation',X,Y);
  Manager:=TSkiaResourceManager.Create; B:=TSkiaBrush.Create; P:=TSkiaPen.Create; F:=TFont.Create;
  Counter:=TAtlasChangeCounter.Create; Manager.FontManager.OnChange:=Counter.Changed;
  try
    Fill1:=Manager.AcquireFillPaint(B,AtlasRectF(0,0,10,10));
    Fill2:=Manager.AcquireFillPaint(B,AtlasRectF(0,0,10,10));
    LabelText(C,X+25,Y+105,18,UnicodeString('Same fill key: '+BoolToStr(Fill1=Fill2,True)));
    Manager.InvalidateBrush; Fill2:=Manager.AcquireFillPaint(B,AtlasRectF(0,0,10,10));
    LabelText(C,X+25,Y+148,18,UnicodeString('After invalidation: '+BoolToStr(Fill1<>Fill2,True)));
    Stroke:=Manager.AcquireStrokePaint(P); Font:=Manager.AcquireFont(F);
    Manager.InvalidatePen; Manager.InvalidateFont; Manager.InvalidateAll;
    LabelText(C,X+25,Y+191,18,UnicodeString('Stroke / font acquired: '+BoolToStr((Stroke<>nil) and (Font<>nil),True)));
    Manager.FontManager.AcquireTypeface(F); Manager.FontManager.Clear;
    LabelText(C,X+25,Y+235,14,UnicodeString(Format('OnChange events: %d; color round-trip=$%x',
      [Counter.Count,Cardinal(AlphaColorToColor(ColorToAlphaColor(clRed,128)))])));
  finally Manager.FontManager.OnChange:=nil; Counter.Free; F.Free; P.Free; B.Free; Manager.Free; end;
  Note(C,X,Y,'Cached interfaces remain valid after manager invalidation.');
  Panel(C,1,1,'Glyph cache + outline metrics','GetLogFont / FontKey / GetEmSquare / ShapeText / Clear',X,Y);
  D:=TSkiaBitmapCanvas.Create(20,20);
  try
    D.Font.Name:='Arial'; D.Font.Height:=-32; D.FontManager.GetLogFont(D.Font,LF);
    Key:=D.FontManager.FontKey(D.Font); Em:=D.GlyphCache.GetEmSquare(LF,Key);
    H:=D.GlyphCache.GetCharHeight(LF,Key); D.GlyphCache.ShapeText(LF,Key,Em,'A',G);
    if Length(G)>0 then Path:=D.GlyphCache.GetGlyphPathByIndex(G[0].GlyphIndex,Advance);
    LabelText(C,X+25,Y+105,18,UnicodeString(Format('EM=%d / actual character height=%d',[Em,H])));
    if Path<>nil then begin Bounds:=Path.GetBounds;
      LabelText(C,X+25,Y+151,18,UnicodeString(Format('A: advance=%.1f; outline %.1fx%.1f',[Advance,Bounds.Width,Bounds.Height]))); end;
    LabelText(C,X+25,Y+198,16,UnicodeString('LOGFONT key: '+Copy(Key,1,30))); D.GlyphCache.Clear;
  finally D.Free; end;
  Note(C,X,Y,'GDI paths use font design units and reusable font/DC resources.');
  Panel(C,0,2,'Metafile / playback / serialization','FinishRecording / both Playback overloads / SerializeToStream',X,Y);
  D:=TSkiaBitmapCanvas.Create(140,90); Bmp:=TBitmap.Create; MS:=TMemoryStream.Create;
  try
    MC:=TSkiaMetafileCanvas.Create(140,90);
    try MakeSource(D); MC.BitBlt(0,0,120,80,D,0,0); C.SkCanvas.Save;
      try C.SkCanvas.Translate(X+25,Y+110); MC.Playback(C.SkCanvas); finally C.SkCanvas.Restore; end; finally MC.Free; end;
    MC:=TSkiaMetafileCanvas.Create(140,90);
    try MC.Brush.Color:=clRed; MC.Ellipse(10,10,125,80); MC.Playback(D); finally MC.Free; end;
    D.Flush(Bmp); C.StretchDraw(Types.Rect(X+25,Y+110,X+220,Y+250),Bmp);
    MC:=TSkiaMetafileCanvas.Create(140,90);
    try MC.Brush.Color:=clBlue; MC.Rectangle(10,10,125,80); Pic:=MC.FinishRecording; finally MC.Free; end;
    Pic.SerializeToStream(MS); Pic.Playback(D.SkCanvas); D.Flush(Bmp);
    C.StretchDraw(Types.Rect(X+240,Y+110,X+435,Y+250),Bmp);
    Note(C,X,Y,Format('Serialized picture: %d bytes; width=140, height=90',[MS.Size]));
  finally MS.Free; Bmp.Free; D.Free; end;
  {$IFDEF MSWINDOWS}
  Panel(C,1,2,'Parsed EMF + seeded surfaces','EMF records / glyph contours / direct Skia surfaces',X,Y);
  
  Graphic:=TMetafile.Create; Graphic.Width:=180; Graphic.Height:=90;
  with TMetafileCanvas.Create(Graphic,0) do try
    Brush.Color:=clGreen; Rectangle(5,5,175,85);
    Font.Color:=clWhite; TextOut(15,30,'Native EMF');
  finally Free; end;
  try C.StretchDraw(Types.Rect(X+25,Y+105,X+230,Y+225),Graphic); finally Graphic.Free; end;
  
  EmfFile:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..\..\..\tests\fixtures\emf\exttextoutw_rotated_glyphs.emf');
  if FileExists(EmfFile) then DrawMetafileFile(C,EmfFile,Types.Rect(X+245,Y+105,X+435,Y+225));
  LabelText(C,X+25,Y+245,14,'Draw / StretchDraw: EMF parser and recorded glyph contours');
  Note(C,X,Y,'Destination reads use a mirrored surface; output stays portable.');
  {$ELSE}
  Panel(C,1,2,'Native Skia surface','Surface constructor / shared wrappers / direct canvas',X,Y);
  Surface:=TSkSurface.MakeRaster(180,90); Surface.GetCanvas.Clear(ColorToAlphaColor(clGreen));
  Wrapper:=TSkiaCanvas.Create(Surface);
  try
    Wrapper.Font.Color:=clWhite; Wrapper.Font.Height:=-22; Wrapper.Brush.Style:=bsClear;
    Wrapper.TextOut(12,25,'Native Linux'); Wrapper.Pen.Color:=clBlue;
    Wrapper.Rectangle(4,4,176,86);
    C.SkCanvas.DrawImage(Surface.MakeImageSnapshot,X+25,Y+105);
  finally Wrapper.Free; end;
  Note(C,X,Y,'Windows EMF playback is available in the Windows demo.');
  {$ENDIF}

end;
procedure DrawRopsAndFormatting(C: TSkiaCanvas);
var S: TSkiaBitmapCanvas; Tile: TSkiaMetafileCanvas; I,J,X,Y,A: Integer; R: TRect; Text: string;
  Surface: ISkSurface; Wrapper: TSkiaCanvas;
begin
  Clean(C);
  LabelText(C,30,150,20,'All 256 ROP3 truth tables (P = red, S = blue, D = green)');
  S:=TSkiaBitmapCanvas.Create(36,36);
  try
    S.Brush.Color:=clBlue; S.FillRect(Types.Rect(0,0,36,36));
    for I:=0 to 255 do begin
      X:=34+(I mod 16)*59; Y:=205+(I div 16)*47;
      Tile:=TSkiaMetafileCanvas.Create(36,26);
      try
        Tile.Brush.Color:=clGreen; Tile.FillRect(Types.Rect(0,0,36,26));
        Tile.Brush.Color:=clRed; Tile.CopyMode:=TCopyMode(Cardinal(I) shl 16);
        Tile.BitBlt(0,0,36,26,S,0,0);
        A:=C.SaveState;
        try
          C.TranslateTransform(X,Y);
          Tile.Playback(C);
        finally C.RestoreState(A); end;
      finally Tile.Free; end;
      LabelText(C,X+39,Y+7,8,UnicodeString(IntToHex(I,2)));
    end;
  finally S.Free; end;
  C.Font.Height:=-22; C.Font.Color:=Ink; C.Brush.Style:=bsClear;
  for J:=0 to 2 do begin
    R:=Types.Rect(35+J*320,1000,330+J*320,1170); A:=C.SaveState;
    try
    C.Pen.Style:=psDot; C.Rectangle(R);
    case J of
      0: begin Text:='&Wrapped text with kerning: AVATAR office. Tabs:'+#9+'123'; C.TextRect(R,Text,[tfWordBreak,tfExpandTabs]); end;
      1: begin Text:='A long filename C:\documents\graphics\shaped-outline.svg'; C.TextRect(R,Text,[tfSingleLine,tfPathEllipsis,tfVerticalCenter]); end;
      2: begin Text:='&Accelerator'; C.TextRect(R,Text,[tfSingleLine,tfCenter,tfBottom,tfPrefixOnly]); end;
    end;
    finally C.RestoreState(A); end;
  end;
  { Surface constructor preserves content created before the canvas wrapper. }
  Surface:=TSkSurface.MakeRaster(12,12); Surface.GetCanvas.Clear(TAlphaColor($FF00FF00));
  Wrapper:=TSkiaCanvas.Create(Surface);
  try Wrapper.Pen.Mode:=pmXor; Wrapper.Pen.Color:=clBlue; Wrapper.MoveTo(0,6); Wrapper.LineTo(12,6);
  finally Wrapper.Free; end;
end;
{$I SkiaUnicodeScenes.inc}
procedure DrawTextPaths(C: TSkiaCanvas);
var X,Y,I: Integer; B: ISkPathBuilder; P: ISkPath; O: TSkiaTextPathOptions; Paint: ISkPaint;
begin
  { Regression: UTF-8 source literals must compile identically in Delphi/FPC. }
  if TextPathCyrillicCaption <> #$0422#$0435#$043A#$0441#$0442' '#$043F#$043E' '#$043A#$0440#$0438#$0432#$043E#$0439 then
    raise Exception.Create('TextOnPath demo: Cyrillic source encoding mismatch');
  if TextPathMixedCaption <> 'AB '+#$0633#$064E#$0644#$0627#$0645#$064F+' 12' then
    raise Exception.Create('TextOnPath demo: Arabic source encoding mismatch');
  for I:=0 to 5 do begin
    case I of
      0: Panel(C,0,0,'Fit text to a cubic curve','Tangent orientation / centered shaped text',X,Y);
      1: Panel(C,1,0,'Distance and offset','Same path / +28 normal / +35 along path',X,Y);
      2: Panel(C,0,1,'Polyline','Repeated vertices / sharp bends / letter spacing',X,Y);
      3: Panel(C,1,1,'Closed path','Wrap around an ellipse / negative offset',X,Y);
      4: Panel(C,0,2,'Reverse and mirror','Reverse direction + vertical mirror / outside',X,Y);
      5: Panel(C,1,2,'Unicode and orientation','Cyrillic / mixed RTL-LTR / vowel marks',X,Y);
    end;
    B:=TSkPathBuilder.Create;
    if I=3 then B.AddOval(AtlasRectF(X+55,Y+100,X+405,Y+245))
    else if I=2 then begin
      B.MoveTo(X+30,Y+240); B.LineTo(X+140,Y+140); B.LineTo(X+140,Y+140);
      B.LineTo(X+270,Y+210); B.LineTo(X+430,Y+125);
    end else begin
      B.MoveTo(X+30,Y+235); B.CubicTo(X+100,Y+85,X+340,Y+85,X+430,Y+235);
    end;
    P:=B.Detach; C.Pen.Color:=TColor($B9AAA0); C.Pen.Width:=1;
    Paint:=TSkPaint.Create; Paint.Style:=TSkPaintStyle.Stroke; Paint.StrokeWidth:=1;
    Paint.AntiAlias:=True; Paint.Color:=ColorToAlphaColor(C.Pen.Color);
    C.SkCanvas.DrawPath(P,Paint);
    C.Font.Name:='Arial'; C.Font.Height:=-26; C.Font.Color:=Ink;
    O:=TSkiaTextPathOptions.Default; O.Alignment:=tpaCenter;
    case I of
      0: C.TextOnPath('AVATAR office along a curve',P,O);
      1: begin
        C.TextOnPath('Offset and distance',P,O); O.Offset:=35; O.Distance:=28;
        C.Font.Color:=TColor($808000); C.TextOnPath('Offset and distance',P,O);
      end;
      2: begin O.LetterSpacing:=2; C.TextOnPath('TEXT ON A POLYLINE',P,O); end;
      3: begin O.Wrap:=True; O.Offset:=-120; O.Distance:=10; C.TextOnPath('Text follows a closed path',P,O); end;
      4: begin O.Reverse:=True; O.MirrorVertical:=True; O.Distance:=-15; C.TextOnPath('Reverse / mirrored text',P,O); end;
      5: begin
        O.Orientation:=tpoHorizontal; C.TextOnPath(TextPathCyrillicCaption,P,O);
        O.Distance:=40; C.TextOnPath(#$0633#$0644#$0627#$0645+'  office',P,O);
        C.FontEdging:=TSkFontEdging.AntiAlias; C.FontHinting:=TSkFontHinting.Normal;
        C.FontSubpixel:=True; O.Orientation:=tpoTangent; O.Distance:=-40;
        C.TextOnPath(TextPathMixedCaption,P,O);
      end;
    end;
    Note(C,X,Y,'TextOnPath / vector outlines in BMP, PDF and SVG');
  end;
end;
procedure DrawAtlasPage(C: TSkiaCanvas; Index: Integer);
begin
  if Index=0 then begin DrawShowcase(C); Exit; end;
  BeginPage(C,Index,'Skia canvas / complete API atlas',AtlasPageName(Index)+' / native results and compatibility operations');
  case Index of
    1: DrawPrimitives(C); 2: DrawBrushes(C); 3: DrawPens(C); 4: DrawTransfers(C);
    5: DrawClipsTransforms(C); 6: DrawTextFonts(C); 7: DrawRasterResources(C); 8: DrawRopsAndFormatting(C);9: DrawUnicodeFonts(C);10: DrawUnicodeRTL(C);11: DrawTextPaths(C);
  else raise ESkiaCanvasError.Create('Unknown atlas page'); end;
  Clean(C);
  Writeln('Atlas rendered: ',AtlasPageName(Index));
end;
end.




