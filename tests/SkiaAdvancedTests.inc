{ Native text shaping and outline export integration tests. }
function AdvancedShape(C: TSkiaBitmapCanvas; const Text: UnicodeString;
  out Glyphs: TArray<TGdiShapedGlyph>): Single;
var LF: TLogFontW; Key: string; Em, I: Integer;
begin
  Result := 0;
  if not C.FontManager.GetLogFont(C.Font, LF) then
    raise Exception.Create('AdvancedShape: LOGFONT unavailable');
  Key := C.FontManager.FontKey(C.Font);
  Em := C.GlyphCache.GetEmSquare(LF, Key);
  if not C.GlyphCache.ShapeText(LF, Key, Em, Text, Glyphs) then
    raise Exception.Create('AdvancedShape: shaping failed');
  for I := 0 to High(Glyphs) do Result := Result + Glyphs[I].AdvanceX;
end;
procedure T_AdvancedKerning;
var C: TSkiaBitmapCanvas; A,V,Pair,Triplet: TArray<TGdiShapedGlyph>;
  WA,WV,WP,WT: Single; LF: TLogFontW; Key: string; Scale: Single;
begin
  C:=TSkiaBitmapCanvas.Create(200,80);
  try
    C.Font.Name:='Times New Roman'; C.Font.Height:=-40;
    WA:=AdvancedShape(C,'A',A); WV:=AdvancedShape(C,'V',V);
    WP:=AdvancedShape(C,'AV',Pair); WT:=AdvancedShape(C,'AVA',Triplet);
    Check((Length(Pair)=2) and (Length(Triplet)=3), 'Kerning: glyph count unchanged');
    Check(WP < WA+WV, 'Kerning: AV narrower than independent A + V');
    Check(WT < WA*2+WV, 'Kerning: adjustment propagates to third glyph');
    
    C.TextToCurves:=True;
    C.FontManager.GetLogFont(C.Font,LF); Key:=C.FontManager.FontKey(C.Font);
    Scale:=C.GlyphCache.GetCharHeight(LF,Key)/C.GlyphCache.GetEmSquare(LF,Key);
    Check(Abs(C.TextExtent('AV').cx-Round(WP*Scale))<=1, 'Curves TextExtent: includes kerning');
    Check(Abs(AdvancedShape(C,'AV',Pair)-WP)<0.01, 'Kerning: cached repeat stable');
  finally C.Free; end;
end;
procedure T_AdvancedEmptyAndInvalid;
var C: TSkiaBitmapCanvas; G: TArray<TGdiShapedGlyph>; LF: TLogFontW; Key: string;
begin
  C:=TSkiaBitmapCanvas.Create(20,20);
  try
    SetLength(G,2);
    Check(AdvancedShape(C,'',G)=0, 'Shape empty: zero width');
    Check(Length(G)=0, 'Shape empty: clears prior output');
    C.FontManager.GetLogFont(C.Font,LF); Key:=C.FontManager.FontKey(C.Font);
    Check(not C.GlyphCache.ShapeText(LF,Key,0,'A',G), 'Shape invalid EM: rejected');
    Check(Length(G)=0, 'Shape invalid EM: no stale glyphs');
    C.TextToCurves:=True;
    Check(C.TextExtent('').cx=0, 'Curves empty: zero extent');
  finally C.Free; end;
end;
procedure T_AdvancedComplexShaping;

const Hebrew: UnicodeString=#$05E9#$05DC#$05D5#$05DD;
  Arabic: UnicodeString=#$0633#$0644#$0627#$0645;
var C: TSkiaBitmapCanvas; G,One,Other: TArray<TGdiShapedGlyph>;
  W,W2: Single; I: Integer;

begin
  
  C:=TSkiaBitmapCanvas.Create(400,100);
  try
    C.Font.Name:='Arial'; C.Font.Height:=-36;
    W:=AdvancedShape(C,#$0644#$0627,G);
    Check((Length(G)=1) and (G[0].GlyphIndex<>0) and (W>0), 'Arabic lam-alef: two code units form one glyph');
    AdvancedShape(C,Arabic,G);
    Check((Length(G)>0) and (Length(G)<Length(Arabic)), 'Arabic word: contextual ligature reduces count');
    { Compare lam-alef with standalone lam and alef; it must be a substitution. }
    AdvancedShape(C,#$0644,One); AdvancedShape(C,#$0644#$0627,G);
    Check((Length(One)=1) and (G[0].GlyphIndex<>One[0].GlyphIndex), 'Arabic: contextual glyph differs from isolated lam');
    W:=AdvancedShape(C,'e'+#$0301,G); W2:=AdvancedShape(C,#$00E9,Other);
    Check((Length(G)=1) and (Length(Other)=1) and (G[0].GlyphIndex=Other[0].GlyphIndex), 'Combining acute: decomposed and precomposed glyph match');
    Check(Abs(W-W2)<0.01, 'Combining acute: equal advance');
    AdvancedShape(C,Hebrew,G);
    Check(Length(G)=Length(Hebrew), 'RTL Hebrew: count preserved');
    if Length(G)=Length(Hebrew) then
      for I:=1 to Length(Hebrew) do begin
        AdvancedShape(C,Copy(Hebrew,I,1),One);
        Check((Length(One)=1) and (G[Length(G)-I].GlyphIndex=One[0].GlyphIndex), 'RTL Hebrew: visual position '+IntToStr(I));
      end;
    AdvancedShape(C,'ABC '+Hebrew,G);
    Check(Length(G)=8, 'Mixed bidi: Latin + space + Hebrew count');
    if Length(G)=8 then
    begin
      AdvancedShape(C,'ABC ',Other);
      for I:=0 to 3 do Check(G[I].GlyphIndex=Other[I].GlyphIndex, 'Mixed bidi: Latin position '+IntToStr(I));
      AdvancedShape(C,Hebrew,Other);
      for I:=0 to 3 do Check(G[I+4].GlyphIndex=Other[I].GlyphIndex, 'Mixed bidi: Hebrew position '+IntToStr(I));
    end;
    C.Font.Name:='Segoe UI Symbol';
    W:=AdvancedShape(C,WideChar($D83D)+WideChar($DE00),G);
    Check((Length(G)=1) and (G[0].GlyphIndex<>0) and (W>0), 'Surrogate: one visual glyph with advance');
  finally C.Free; end;
  
end;
procedure T_AdvancedNestedState;
var C: TSkiaBitmapCanvas; First,Second: Integer; P: TPoint;
begin
  C:=TSkiaBitmapCanvas.Create(80,80);
  try
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,80,80));
    C.Brush.Color:=clRed; C.Brush.Alpha:=128; C.Font.Alpha:=180;
    C.Pen.DashPattern:=TArray<Single>.Create(7,3); C.TextToCurves:=True;
    First:=C.SaveState;
    C.TranslateTransform(10,12); C.SetClipRect(Rect(10,12,30,32));
    Second:=C.SaveState;
    C.RotateTransform(90); C.Brush.Alpha:=12; C.Font.Alpha:=22;
    C.TextToCurves:=False; C.Pen.DashPattern:=nil;
    C.RestoreState(Second);
    P:=C.LPToDP(Point(0,0));
    Check((P.X=10) and (P.Y=12), 'Nested state: inner transform restored');
    Check(C.TextToCurves and (C.Brush.Alpha=128) and (C.Font.Alpha=180), 'Nested state: text mode and alpha restored');
    Check((Length(C.Pen.DashPattern)=2) and (C.Pen.DashPattern[0]=7), 'Nested state: custom dash restored');
    C.RestoreState(First);
    P:=C.LPToDP(Point(0,0));
    Check((P.X=0) and (P.Y=0), 'Nested state: outer transform restored');
    C.Brush.Alpha:=255; C.Brush.Color:=clBlue;
    C.FillRect(Rect(60,60,70,70));
    Check(C.Pixels[65,65]=clBlue, 'Nested state: inner clip removed');
  finally C.Free; end;
end;
procedure T_AdvancedOutlineExport;
var MC: TSkiaMetafileCanvas; C: TSkiaBitmapCanvas; Pic: ISkPicture;
  MS: TMemoryStream; Svg: ISkCanvas; Bytes: UTF8String; XML: string;
  BeforeCount: Integer;
begin
  MC:=TSkiaMetafileCanvas.Create(320,180);
  try
    MC.Brush.Style:=bsClear; MC.Font.Name:='Arial'; MC.Font.Height:=-36;
    MC.Font.Color:=clWhite; MC.TextToCurves:=True;
    MC.SaveState;
    MC.SetClipRect(Rect(0,0,300,160));
    MC.RotateTransform(8); MC.TranslateTransform(20,20);
    MC.TextOut(0,0,'AVATAR / curves');
    MC.RestoreState;
    Pic:=MC.FinishRecording;
  finally MC.Free; end;
  BeforeCount:=Pic.ApproximateOpCount;
  Check(BeforeCount>0, 'Outline export: recorded operations');
  C:=TSkiaBitmapCanvas.Create(320,180);
  try
    Pic.Playback(C.SkCanvas);
    Check(HasInk(C), 'Outline export: playback has visible glyphs');
    Check(C.Pixels[319,179]=clBlack, 'Outline export: clip preserves outside');
  finally C.Free; end;
  MS:=TMemoryStream.Create;
  try
    Svg:=TSkSVGCanvas.Make(RectF(0,0,320,180),MS);
    Pic.Playback(Svg); Svg:=nil;
    SetLength(Bytes,MS.Size); MS.Position:=0;
    if Length(Bytes)>0 then MS.ReadBuffer(Bytes[1],Length(Bytes));
    XML:=UTF8ToString(Bytes);
    Check(Pos('<svg',XML)>0, 'Outline export: SVG document');
    Check(Pos('<path',XML)>0, 'Outline export: glyph paths');
    Check(Pos('<text',XML)=0, 'Outline export: no font-dependent text elements');
    Check(Pic.ApproximateOpCount=BeforeCount, 'Outline export: playback preserves picture');
  finally Svg:=nil; MS.Free; end;
end;

procedure T_AdvancedAlpha;
var C: TSkiaBitmapCanvas; Color: Cardinal;
  function Near(A,B: Integer): Boolean;
  begin Result:=Abs(A-B)<=2; end;
begin
  C:=TSkiaBitmapCanvas.Create(80,60);
  try
    C.Brush.Color:=clWhite; C.FillRect(Rect(0,0,80,60));
    C.Brush.Color:=clRed; C.Brush.Alpha:=128;
    C.FillRect(Rect(0,0,40,40));
    Color:=Cardinal(ColorToRGB(C.Pixels[20,20]));
    Check(Near(Color and 255,255) and Near((Color shr 8) and 255,127) and
      Near((Color shr 16) and 255,127), 'Solid alpha: red half over white');
    C.Brush.Color:=clBlue;
    C.FillRect(Rect(10,10,50,50));
    Color:=Cardinal(ColorToRGB(C.Pixels[20,20]));
    Check(Near(Color and 255,127) and Near((Color shr 8) and 255,63) and
      Near((Color shr 16) and 255,191), 'Solid alpha: overlapping layers blend');
    C.Brush.Alpha:=0; C.Brush.Color:=clGreen;
    C.FillRect(Rect(60,0,80,20));
    Check(C.Pixels[70,10]=clWhite, 'Solid alpha: transparent fill preserves destination');
    C.Brush.Alpha:=128; C.Brush.Gradient:=gkHorizontal;
    C.Brush.GradientStartColor:=clRed; C.Brush.GradientEndColor:=clRed;
    C.FillRect(Rect(60,30,80,50));
    Color:=Cardinal(ColorToRGB(C.Pixels[70,40]));
    Check(Near(Color and 255,255) and Near((Color shr 8) and 255,127), 'Gradient alpha: applied once');
  finally C.Free; end;
end;
