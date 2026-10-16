{ API atlas regression tests. Assertions target visible geometry and public state. }
procedure T_AtlasClipResetMatrix;
var C: TSkiaBitmapCanvas; A,Depth: Integer; P: TPoint;
begin
  C:=TSkiaBitmapCanvas.Create(50,50);
  try
    A:=C.SaveState; Depth:=C.SkCanvas.GetSaveCount;
    C.TranslateTransform(5,7); C.SetClipRect(Rect(0,0,30,30));
    C.TranslateTransform(3,4); C.ResetClip;
    Check(C.SkCanvas.GetSaveCount=Depth, 'Clip reset: outer native save depth preserved');
    P:=C.LPToDP(Point(0,0));
    Check((P.X=8) and (P.Y=11), 'Clip reset: logical matrix preserved');
    C.Brush.Color:=clRed; C.FillRect(Rect(0,0,2,2));
    Check(C.Pixels[0,0]=clRed, 'Clip reset: actual canvas uses preserved matrix');
    C.RestoreState(A);
    C.Brush.Color:=clBlue; C.FillRect(Rect(40,40,45,45));
    Check(C.Pixels[42,42]=clBlue, 'Clip reset: outer snapshot remains usable');
  finally C.Free; end;
end;
procedure T_AtlasMaskSelfCopy;
var C: TSkiaBitmapCanvas; Mask: TBitmap; I: Integer;
begin
  C:=TSkiaBitmapCanvas.Create(12,4); Mask:=TBitmap.Create;
  try
    Mask.SetSize(12,4);
    for I:=0 to 11 do Mask.Canvas.Pixels[I,0]:=clWhite;
    C.Pixels[0,0]:=clRed; C.Pixels[1,0]:=clGreen; C.Pixels[2,0]:=clBlue;
    C.MaskBlt(1,0,3,1,C,0,0,Mask,0,0);
    Check(C.Pixels[1,0]=clRed, 'Mask self-copy: first shifted pixel');
    Check(C.Pixels[2,0]=clGreen, 'Mask self-copy: overlap uses original source');
    Check(C.Pixels[3,0]=clBlue, 'Mask self-copy: final pixel not smeared');
  finally Mask.Free; C.Free; end;
end;
procedure T_AtlasTransfers;
var C,S: TSkiaBitmapCanvas; Mask,Bmp: TBitmap; I,J: Integer;
begin
  C:=TSkiaBitmapCanvas.Create(80,80); S:=TSkiaBitmapCanvas.Create(20,20);
  Mask:=TBitmap.Create; Bmp:=TBitmap.Create;
  try
    S.Brush.Color:=clRed; S.FillRect(Rect(0,0,10,20));
    S.Brush.Color:=clBlue; S.FillRect(Rect(10,0,20,20));
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,80,80));
    C.BitBlt(2,2,10,10,S,10,5);
    Check(C.Pixels[5,5]=clBlue, 'BitBlt: source offsets select right half');
    C.StretchBlt(20,0,40,20,S,0,0,20,20);
    Check((C.Pixels[25,10]=clRed) and (C.Pixels[55,10]=clBlue), 'StretchBlt: both halves scaled');
    C.CopyRect(Rect(0,25,20,45),S,Rect(0,0,20,20));
    Check((C.Pixels[5,30]=clRed) and (C.Pixels[15,30]=clBlue), 'CopyRect: oriented source corners');
    C.PlgBlt([Point(30,30),Point(70,35),Point(35,65)],S,0,0,20,20);
    Check(C.Pixels[39,45]=clRed, 'PlgBlt: affine left interior');
    Check(C.Pixels[60,48]=clBlue, 'PlgBlt: affine right interior');
    Check(C.Pixels[75,70]=clWhite, 'PlgBlt: outside parallelogram unchanged');
    Mask.SetSize(24,24);
    for J:=0 to 23 do for I:=0 to 23 do
      if I<14 then Mask.Canvas.Pixels[I,J]:=clWhite else Mask.Canvas.Pixels[I,J]:=clBlack;
    C.MaskBlt(0,60,20,20,S,0,0,Mask,4,2);
    Check(C.Pixels[5,65]=clRed, 'MaskBlt: mask origin honored');
    Check(C.Pixels[15,65]=clWhite, 'MaskBlt: black mask retains destination');
    C.MaskBlt(0,50,3,3,S,0,0,Mask,-1,-1);
    Check(C.Pixels[0,50]=clWhite, 'MaskBlt: negative mask origin is outside');
    Check(C.Pixels[1,51]=clRed, 'MaskBlt: copy begins when mask origin enters bounds');
    S.Flush(Bmp); C.Draw(60,0,Bmp,0);
    Check(C.Pixels[70,10]=clWhite, 'Draw opacity zero: destination preserved');
    C.BitBlt(60,60,0,0,S,0,0); C.StretchBlt(60,60,-1,4,S,0,0,20,20);
    C.PlgBlt([Point(60,60),Point(65,65),Point(70,70)],S,0,0,20,20);
    Check(C.Pixels[70,70]=clWhite, 'Invalid blits / degenerate PlgBlt: no drawing');
  finally Bmp.Free; Mask.Free; S.Free; C.Free; end;
end;
procedure T_AtlasClipShapes;
var C: TSkiaBitmapCanvas;
begin
  C:=TSkiaBitmapCanvas.Create(60,60);
  try
    C.SetClipRect(Rect(5,5,55,55)); C.IntersectClipRect(Rect(10,10,50,50));
    C.ExcludeClipRect(Rect(20,20,40,40));
    C.Brush.Color:=clRed; C.FillRect(Rect(0,0,60,60));
    Check(C.Pixels[15,15]=clRed, 'Clip: intersection interior drawn');
    Check(C.Pixels[30,30]=clBlack, 'Clip: excluded hole retained');
    Check(C.Pixels[7,7]=clBlack, 'Clip: outside intersection retained');
    C.SetClipRegion(Rect(42,42,58,58)); C.Brush.Color:=clBlue; C.FillRect(Rect(0,0,60,60));
    Check(C.Pixels[54,54]=clBlue, 'SetClipRegion replaces previous clip');
    Check(C.Pixels[30,30]=clBlack, 'Region: outside retained');
    C.ResetClip; C.Brush.Color:=clGreen; C.FillRect(Rect(0,0,4,4));
    Check(C.Pixels[1,1]=clGreen, 'ResetClip: entire destination available');
  finally C.Free; end;
end;
procedure T_AtlasStateModes;
var C: TSkiaBitmapCanvas; A,B,I: Integer; P: TPoint;
begin
  C:=TSkiaBitmapCanvas.Create(30,30);
  try
    for I:=Ord(Low(TPenMode)) to Ord(High(TPenMode)) do begin
      C.Pen.Mode:=TPenMode(I); C.CopyMode:=TCopyMode($00660046);
      C.PenPos:=Point(3,4); A:=C.SaveState;
      C.Pen.Mode:=pmCopy; C.CopyMode:=cmSrcCopy; C.PenPos:=Point(20,20);
      B:=C.SaveState; C.TranslateTransform(10,10); C.TextToCurves:=True;
      C.RestoreState(A);
      Check((C.Pen.Mode=TPenMode(I)) and (C.CopyMode=TCopyMode($00660046)), 'State: stores mode '+IntToStr(I));
      P:=C.PenPos;
      Check((P.X=3) and (P.Y=4) and not C.TextToCurves, 'State: PenPos / text mode restored '+IntToStr(I));
      try C.RestoreState(B); Check(False,'State: stale index must fail');
      except on E: ESkiaCanvasError do Check(True,'State: stale inner index rejected'); end;
    end;
  finally C.Free; end;
end;
procedure T_AtlasBrushPenCatalog;
var RM: TSkiaResourceManager; B: TSkiaBrush; P: TSkiaPen; Paint: ISkPaint; I: Integer;
begin
  RM:=TSkiaResourceManager.Create; B:=TSkiaBrush.Create; P:=TSkiaPen.Create;
  try
    for I:=0 to 7 do begin
      B.Style:=TBrushStyle(I); RM.InvalidateBrush; Paint:=RM.AcquireFillPaint(B,RectF(0,0,20,20));
      Check((Paint<>nil)=(B.Style<>bsClear), 'Brush style catalog '+IntToStr(I));
      if I>1 then Check((Paint<>nil) and (Paint.Shader<>nil), 'Hatch style has shader '+IntToStr(I));
    end;
    for I:=0 to 6 do begin
      P.Style:=TPenStyle(I); RM.InvalidatePen; Paint:=RM.AcquireStrokePaint(P);
      Check((Paint<>nil)=(P.Style<>psClear), 'Pen style catalog '+IntToStr(I));
    end;
    P.Style:=psSolid; P.DashPattern:=TArray<Single>.Create(9,3,2,3); RM.InvalidatePen;
    Paint:=RM.AcquireStrokePaint(P); Check(Paint.PathEffect<>nil,'Custom pen dash catalog');
    for I:=0 to 2 do begin
      P.StrokeCap:=TSkStrokeCap(I); P.StrokeJoin:=TSkStrokeJoin(I); P.MiterLimit:=2.5;
      RM.InvalidatePen; Paint:=RM.AcquireStrokePaint(P);
      Check((Paint.StrokeCap=TSkStrokeCap(I)) and (Paint.StrokeJoin=TSkStrokeJoin(I)) and
        (Abs(Paint.StrokeMiter-2.5)<0.01), 'Pen cap / join / miter catalog '+IntToStr(I));
    end;
  finally P.Free; B.Free; RM.Free; end;
end;
