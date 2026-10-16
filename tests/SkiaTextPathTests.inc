procedure TestTextOnPath;
var A,B: TSkiaBitmapCanvas; Path,Empty: ISkPath; PB: ISkPathBuilder;
  O: TSkiaTextPathOptions; I,J,Ink,Shifted,Different,Depth: Integer;
  Recorder: TSkiaMetafileCanvas; Picture: ISkPicture; Stream: TMemoryStream;
  SVG: ISkCanvas; Doc: ISkDocument; Bytes: UTF8String; Raised: Boolean;
  PA,PC: TArray<TAlphaColor>;
  Measure: ISkPathMeasure;
  Face: ISkTypeface;
  procedure Read(C: TSkiaBitmapCanvas; out Pixels: TArray<TAlphaColor>);
  begin
    SetLength(Pixels,320*180);
    C.Snapshot.ReadPixels(TSkImageInfo.Create(320,180,TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul),Pointer(Pixels),320*4);
  end;
  procedure Setup(C: TSkiaCanvas);
  begin
    C.Brush.Style:=bsSolid; C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,320,180));
    C.Brush.Style:=bsClear; C.Font.Name:='Arial'; C.Font.Height:=-28;
    C.Font.Color:=clBlack;
  end;
begin
  A:=TSkiaBitmapCanvas.Create(320,180); B:=TSkiaBitmapCanvas.Create(320,180);
  try
    Setup(A); Setup(B); PB:=TSkPathBuilder.Create;
    PB.MoveTo(20,90); PB.LineTo(300,90); Path:=PB.Detach; Empty:=PB.Detach;
    Depth:=A.SkCanvas.GetSaveCount;
    A.TextOnPath('AV office',Path);
    B.TextOnPath('AV office',[PointF(20,90),PointF(20,90),PointF(300,90)],12,8);
    Read(A,PA); Read(B,PC);
    Ink:=0; Shifted:=0;
    for J:=20 to 120 do for I:=20 to 260 do
      if PA[J*320+I] and $FFFFFF<>$FFFFFF then begin
        { Path sampling may move an edge by float rounding: at most 5/255 AA coverage. }
        Inc(Ink); if Abs(Integer(PA[J*320+I] and 255)-Integer(PC[(J-8)*320+I+12] and 255))<=5 then Inc(Shifted);
      end;
    Check(Ink>100,'TextOnPath: straight path has visible glyph outlines');
    Check(Shifted=Ink,'TextOnPath: along/normal offsets translate pixels within AA rounding; repeated points ignored');
    Check(A.SkCanvas.GetSaveCount=Depth,'TextOnPath: native save depth restored');
    Setup(B); B.TextOnPath('AV office',[Point(20,90),Point(300,90)]); Read(B,PC);
    Different:=0; for I:=0 to High(PA) do if PA[I]<>PC[I] then Inc(Different);
    Check(Different=0,'TextOnPath: integer polyline overload agrees with native path');
    Setup(B); O:=TSkiaTextPathOptions.Default; O.MirrorVertical:=True;
    B.TextOnPath('Mirror',Path,O); Read(B,PC); Ink:=0;
    for J:=91 to 125 do for I:=20 to 180 do if PC[J*320+I] and $FFFFFF<>$FFFFFF then Inc(Ink);
    Check(Ink>50,'TextOnPath: vertical mirror places outlines below the baseline');
    Setup(A); Setup(B); O:=TSkiaTextPathOptions.Default; O.Alignment:=tpaCenter;
    A.TextOnPath('AV office',Path,O); Read(A,PA); O.MirrorHorizontal:=True;
    B.TextOnPath('AV office',Path,O); Read(B,PC); Different:=0;
    { Reflected contour edges have different AA winding/coverage rounding. }
    for J:=0 to 179 do for I:=0 to 319 do
      if Abs(Integer(PA[J*320+I] and 255)-Integer(PC[J*320+319-I] and 255))>16 then Inc(Different);
    Check(Different=0,'TextOnPath: horizontal mirror reflects glyphs and run order');
    Setup(A); A.TextOnPath('AV office',Path); Read(A,PA);
    Setup(B); B.SetClipRect(Rect(0,0,10,10)); B.TextOnPath('Clipped',Path); B.ResetClip;
    Read(B,PC); Ink:=0; for I:=0 to High(PC) do if PC[I] and $FFFFFF<>$FFFFFF then Inc(Ink);
    Check(Ink=0,'TextOnPath: respects the canvas clip');
    Setup(B); B.TranslateTransform(12,-8); B.TextOnPath('AV office',Path); B.ResetWorldTransform;
    Read(B,PC); Different:=0;
    for J:=8 to 179 do for I:=0 to 307 do
      if Abs(Integer(PA[J*320+I] and 255)-Integer(PC[(J-8)*320+I+12] and 255))>5 then Inc(Different);
    Check(Different=0,'TextOnPath: composes with the canvas world transform');
    Setup(B); B.TextOnPath('',Path); B.TextOnPath('ABC',Empty); B.TextOnPath('ABC',ISkPath(nil));
    Check(B.Pixels[30,80]=clWhite,'TextOnPath: empty text and degenerate paths draw nothing');
    O:=TSkiaTextPathOptions.Default; O.Alignment:=tpaEnd;
    B.TextOnPath('AV office',Path,O); Different:=0; Read(B,PC);
    for J:=30 to 100 do for I:=20 to 300 do if PA[J*320+I]<>PC[J*320+I] then Inc(Different);
    Check(Different>100,'TextOnPath: end alignment changes placement');
    Setup(B); B.TextOnPath('ABC',Path,400,0);
    Read(B,PC); Ink:=0; for J:=0 to High(PC) do if PC[J] and $FFFFFF<>$FFFFFF then Inc(Ink);
    Check(Ink=0,'TextOnPath: open path overflow is omitted');
    Raised:=False; try B.TextOnPath('a'+#10+'b',Path); except on E:ESkiaCanvasError do Raised:=True; end;
    Check(Raised,'TextOnPath: multiline input rejected');
    O.Offset:=NaN; Raised:=False;
    try B.TextOnPath('ABC',Path,O); except on E:ESkiaCanvasError do Raised:=True; end;
    Check(Raised,'TextOnPath: nonfinite offsets rejected');
    PB.MoveTo(30,120); PB.CubicTo(80,0,220,0,290,120); Path:=PB.Detach;
    Setup(B); O:=TSkiaTextPathOptions.Default; O.Alignment:=tpaCenter;
    B.TextOnPath('Curve AV office',Path,O); Ink:=0;
    Read(B,PC); for J:=0 to High(PC) do if PC[J] and $FFFFFF<>$FFFFFF then Inc(Ink);
    Check(Ink>100,'TextOnPath: cubic curve has visible shaped text');
    Read(B,PA); Setup(B); O.Orientation:=tpoHorizontal;
    B.TextOnPath('Curve AV office',Path,O); Read(B,PC); Different:=0;
    for I:=0 to High(PA) do if PA[I]<>PC[I] then Inc(Different);
    Check(Different>100,'TextOnPath: horizontal orientation differs from tangent placement');
    PB.MoveTo(20,90); PB.LineTo(300,90); Path:=PB.Detach;
    Setup(B); O:=TSkiaTextPathOptions.Default; O.Reverse:=True;
    B.TextOnPath('Reverse',Path,O); Read(B,PC); Ink:=0;
    for J:=85 to 125 do for I:=200 to 300 do if PC[J*320+I] and $FFFFFF<>$FFFFFF then Inc(Ink);
    Check(Ink>50,'TextOnPath: reverse starts at the path end and reverses tangent');
    PB.AddOval(RectF(40,35,280,145)); Path:=PB.Detach;
    Setup(A); Setup(B); O:=TSkiaTextPathOptions.Default; O.Wrap:=True; O.Offset:=15;
    A.TextOnPath('Wrapped',Path,O);
    Measure:=TSkPathMeasure.Create(Path,False,4); O.Offset:=O.Offset+Measure.Length;
    B.TextOnPath('Wrapped',Path,O); Read(A,PA); Read(B,PC); Different:=0;
    for I:=0 to High(PA) do if Abs(Integer(PA[I] and 255)-Integer(PC[I] and 255))>3 then Inc(Different);
    Check(Different=0,'TextOnPath: wrapping a closed path by its length preserves placement');
    Setup(B); Face:=TSkTypeface.MakeFromFile(ExpandFileName(
      ExtractFilePath(ParamStr(0))+'../../fixtures/SkiaFixture.ttf'));
    B.FontManager.RegisterTypeface('PathFixture',Face);
    B.Font.Name:='PathFixture'; B.TextOnPath('AV office',Path); Read(B,PC); Ink:=0;
    for I:=0 to High(PC) do if PC[I] and $FFFFFF<>$FFFFFF then Inc(Ink);
    Check((Face<>nil) and (Ink>50),'TextOnPath: registered private typeface renders glyph outlines');
    Setup(B); B.Font.Height:=-28; B.TextOnPath(#$0633#$0644#$0627#$0645,Path,40,0);
    Read(B,PC); Ink:=0; for I:=0 to High(PC) do if PC[I] and $FFFFFF<>$FFFFFF then Inc(Ink);
    Check(Ink>50,'TextOnPath: shaped Arabic has visible contours');
    Recorder:=TSkiaMetafileCanvas.Create(320,180); Stream:=TMemoryStream.Create;
    try
      Recorder.Font.Name:='Arial'; Recorder.Font.Height:=-28;
      Recorder.TextOnPath('Vector office',Path,O);
      O.Reverse:=True; O.MirrorVertical:=True; O.Distance:=20;
      Recorder.TextOnPath('Reverse',Path,O);
      Picture:=Recorder.FinishRecording;
      SVG:=TSkSVGCanvas.Make(RectF(0,0,320,180),Stream); Picture.Playback(SVG); SVG:=nil;
      SetLength(Bytes,Stream.Size); Stream.Position:=0; Stream.ReadBuffer(Bytes[1],Length(Bytes));
      Check((Pos(UTF8String('<path'),Bytes)>0) and (Pos(UTF8String('<image'),Bytes)=0),
        'TextOnPath: recorded SVG contains vector paths without raster fragments');
      Stream.Clear; Doc:=TSkDocument.MakePDF(Stream); SVG:=Doc.BeginPage(320,180);
      Picture.Playback(SVG); SVG:=nil; Doc.EndPage; Doc.Close; Doc:=nil;
      Check(Stream.Size>500,'TextOnPath: recorded PDF exports');
    finally SVG:=nil; Doc:=nil; Recorder.Free; Stream.Free; end;
  finally A.Free; B.Free; end;
end;
