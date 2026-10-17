{ Unicode decoding, TTC selection and the strict Uniscribe OpenType path. }
procedure TestUnicodeTextHelpers;
var Points:TArray<TSkiaCodePoint>;Values:TArray<Cardinal>;Value:Cardinal;
  FontManager:TSkiaFontManager;Face:ISkTypeface;Font:ISkFont;Index,I:Integer;Fixture,Sample:string;
  Canvas:TSkiaBitmapCanvas;LF:TLogFontW;Key:string;Glyphs:TArray<TGdiShapedGlyph>;
  procedure RejectUtf8(const Bytes:array of Byte);
  var Data:UTF8String;J:Integer;Rejected:Boolean;Decoded:TArray<TSkiaCodePoint>;
  begin
    SetLength(Data,Length(Bytes));for J:=0 to High(Bytes) do Data[J+1]:=AnsiChar(Bytes[J]);
    Rejected:=False;try Decoded:=TSkiaUnicode.DecodeUtf8(Data);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'UTF-8 rejects invalid sequence '+IntToStr(Length(Bytes)));
  end;
  
  procedure RejectCollection(const Bytes:array of Byte);
  var Path:string;Stream:TFileStream;Rejected:Boolean;
  begin
    Path:=ExtractFilePath(ParamStr(0))+'invalid-collection.tmp';
    Stream:=TFileStream.Create(Path,fmCreate);
    try if Length(Bytes)>0 then Stream.WriteBuffer(Bytes[0],Length(Bytes));finally Stream.Free;end;
    try
      Rejected:=False;try FontManager.CollectionFaceCount(Path);except on E:ESkiaCanvasError do Rejected:=True;end;
      Check(Rejected,'Invalid TTC/SFNT directory is rejected before loading faces');
    finally SysUtils.DeleteFile(Path);end;
  end;
  
begin
  Points:=TSkiaUnicode.DecodeUtf8(UTF8Encode(UnicodeString('A'+#$00E9+#$4E2D+WideChar($D83D)+WideChar($DE00))));
  Check(Length(Points)=4,'UTF-8 decodes four scalars, not UTF-16 units');
  Check((Points[1].Value=$E9) and (Points[1].ByteOffset=2) and (Points[1].ByteLength=2),'UTF-8 two-byte scalar and byte offset');
  Check((Points[3].Value=$1F600) and (Points[3].ByteOffset=7) and (Points[3].ByteLength=4),'UTF-8 supplementary scalar and byte offset');
  Values:=TSkiaUnicode.CodePoints(TSkiaUnicode.ScalarText($1E900));
  Check((Length(Values)=1) and (Values[0]=$1E900),'Supplementary UTF-16 scalar round-trip');
  RejectUtf8([$C0,$AF]);RejectUtf8([$ED,$A0,$80]);RejectUtf8([$F4,$90,$80,$80]);RejectUtf8([$E2,$82]);RejectUtf8([$80]);
  Check(TSkiaUnicode.IsDefaultIgnorable($2060) and TSkiaUnicode.IsDefaultIgnorable($200C),'Unicode default-ignorable join controls');
  Check(not TSkiaUnicode.IsDefaultIgnorable($10FFFF),'Noncharacters are not silently treated as join controls');
  Check(TSkiaUnicode.ScriptName($4E2D)='Han','Unicode script property for CJK');
  Check(TSkiaUnicode.ScriptName($1E900)='Adlam','Unicode supplementary script property');
  Check(TSkiaUnicode.ScriptName($378)='Unknown','Unassigned scalar has Unknown script');
  Check(TSkiaUnicode.ParagraphLevel(#$644#$627)=1,'Arabic paragraph base direction is RTL');
  Check(TSkiaUnicode.ParagraphLevel('123 '+#$5D0)=1,'Neutral digits do not set the paragraph direction');
  Check(TSkiaUnicode.ParagraphLevel('ABC '+#$5D0)=0,'First Latin strong scalar sets LTR paragraph direction');
  Check(TSkiaUnicode.ParagraphLevel(#$2067+#$5D0+#$2069+'ABC')=0,'Bidi isolates do not leak into paragraph base direction');
  Check(TSkiaUnicode.ParagraphLevel('')=0,'Empty paragraph has default LTR base level');
  Check(not TSkiaUnicode.IsRightToLeft(Ord('1')),'European digits are not strong RTL');
  Check(TSkiaUnicode.BidiClass($2067)=bcRLI,'RTL isolate control has its own bidi class');
  Values:=TSkiaUnicode.RTLScriptSamples;
  Check(Length(Values)=37,'Unicode 17 RTL catalog includes all 37 assigned scripts');
  for Value in Values do Check(TSkiaUnicode.IsRightToLeft(Value),'RTL script classification: '+TSkiaUnicode.ScriptName(Value));
  
  FontManager:=TSkiaFontManager.Create;Canvas:=TSkiaBitmapCanvas.Create(400,100);
  try
    RejectCollection([0,1,0,0,0,0,0,0,0,0,0,0]);
    RejectCollection([$74,$74,$63,$66,0,1,0,0,0,0,0,1,$FF,$FF,$FF,$F0]);
    Face:=FontManager.MatchTypefaceForText('A'+WideChar($2060),'Arial','en');
    Check(Face<>nil,'Font matching ignores Unicode WORD JOINER without requiring a glyph');
    Fixture:=ExtractFilePath(ParamStr(0))+'..\..\fixtures\SkiaCjkFixture.ttc';
    Check(FontManager.CollectionFaceCount(Fixture)=2,'TTC validates two indexed faces');
    Sample:=string(UnicodeString(#$4E2D#$6587));
    Face:=FontManager.MatchCollectionTypeface(Fixture,Sample,Index);
    Check((Face<>nil) and (Index=1),'TTC CJK mapping selects nonzero face index by coverage');
    Font:=TSkFont.Create(Face,30);
    Check((Font.UnicharToGlyph($4E2D)<>0) and (Font.UnicharToGlyph($6587)<>0),'Selected TTC face contains requested CJK glyphs');
    Face:=FontManager.MatchCollectionTypeface(Fixture,'Z',Index);
    Check((Face=nil) and (Index=-1),'TTC rejects unsupported scalar instead of returning face zero');
    Face:=FontManager.MatchTypefaceForText(Sample,'Consolas','zh-Hans');
    Check(Face<>nil,'Script-aware matching finds a CJK font after Latin preference');
    if Face<>nil then begin Font:=TSkFont.Create(Face,30);Check(Font.UnicharToGlyph($4E2D)<>0,'Script-aware result has a real CJK glyph');end;
    Face:=FontManager.MatchTypefaceForText(string(TSkiaUnicode.ScalarText($10FFFF)),'Arial','');
    Check(Face=nil,'Font matching reports uncovered scalars without tofu substitution');
    Canvas.Font.Name:='Tahoma';Canvas.Font.Height:=-30;Canvas.FontManager.GetLogFont(Canvas.Font,LF);
    Key:=Canvas.FontManager.FontKey(Canvas.Font);
    for I:=0 to 2 do begin
      case I of
        0:Sample:=string(UnicodeString(#$0644#$0627));
        1:Sample:=string(UnicodeString(#$0641#$0627#$0631#$0633#$06CC));
        2:Sample:=string(UnicodeString(#$0645#$06CC#$200C#$0631#$0648#$0645));
      end;
      Check(Canvas.GlyphCache.ShapeText(LF,Key,Canvas.GlyphCache.GetEmSquare(LF,Key),UnicodeString(Sample),Glyphs,True),'Internal Arabic/Persian OpenType shaping '+IntToStr(I));
      Check(Canvas.GlyphCache.LastShapeUsedOpenType,'OpenType API really used '+IntToStr(I));
      if I=0 then Check(Length(Glyphs)=1,'OpenType lam-alef produces one glyph');
      Check(Length(Glyphs)>0,'OpenType produces contextual glyphs '+IntToStr(I));
    end;
    Sample:='';for I:=1 to 1100 do Sample:=Sample+'a'+WideChar($644);
    Check(Canvas.GlyphCache.ShapeText(LF,Key,Canvas.GlyphCache.GetEmSquare(LF,Key),UnicodeString(Sample),Glyphs,True),
      'OpenType item buffer grows beyond 1024 mixed-script runs');
    Check(Canvas.GlyphCache.LastShapeUsedOpenType,'Large mixed-script paragraph stays on OpenType API');
    Check(Canvas.GlyphCache.ShapeText(LF,Key,1000,'',Glyphs,True) and (Length(Glyphs)=0),
      'Empty OpenType-only ShapeText returns an empty result');
    Check(not Canvas.GlyphCache.ShapeText(LF,Key,1000,WideChar($D800),Glyphs,True),
      'OpenType-only ShapeText rejects malformed UTF-16 without partial glyphs');
    Check((Length(Glyphs)=0) and not Canvas.GlyphCache.LastShapeUsedOpenType,'Failed shaping clears result and backend indicator');
    Check(not Canvas.GlyphCache.ShapeText(LF,Key,1000,WideChar($D800),Glyphs),
      'Review: default shaping also rejects malformed UTF-16 without fallback truncation');
  finally Canvas.Free;FontManager.Free;end;
  
end;procedure TestCanvasApiGuards;
var Canvas:TSkiaBitmapCanvas;Recorder:TSkiaMetafileCanvas;Picture:ISkPicture;Rejected:Boolean; Huge:TSkiaBitmapCanvas; LF:TLogFontW; NativeFont:TFont;
begin
  Canvas:=TSkiaBitmapCanvas.Create(20,20);Recorder:=TSkiaMetafileCanvas.Create(20,20);
  try
    Huge:=nil;Rejected:=False;
    try Huge:=TSkiaBitmapCanvas.Create(High(Integer),2);except on E:ESkiaCanvasError do Rejected:=True;end;
    Huge.Free;Check(Rejected,'Review: oversized raster is rejected before native allocation');
    Rejected:=False;try Canvas.Pen.DashPattern:=TArray<Single>.Create(1);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Review: odd dash interval count rejected');
    Rejected:=False;try Canvas.Pen.DashPattern:=TArray<Single>.Create(0,0);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Review: zero dash total rejected');
    Rejected:=False;try Canvas.Pen.DashPattern:=TArray<Single>.Create(-1,2);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Review: negative dash interval rejected');
    Canvas.Pen.DashPattern:=TArray<Single>.Create(0,2);
    Check(Length(Canvas.Pen.DashPattern)=2,'Review: valid dash pattern with zero interval accepted');
    Rejected:=False;try Canvas.Pen.MiterLimit:=0;except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Review: miter limit below one rejected');
    NativeFont:=TFont.Create;
    try
    FillChar(LF,SizeOf(LF),0);LF.lfPitchAndFamily:=FIXED_PITCH;
    NativeFont.Handle:=CreateFontIndirectW(LF);Canvas.Font.Assign(NativeFont);Check(Canvas.Font.Pitch=fpFixed,'Review: LOGFONT fixed pitch maps to fpFixed');
    LF.lfPitchAndFamily:=VARIABLE_PITCH;NativeFont.Handle:=CreateFontIndirectW(LF);Canvas.Font.Assign(NativeFont);
    Check(Canvas.Font.Pitch=fpVariable,'Review: LOGFONT variable pitch maps to fpVariable');
    LF.lfPitchAndFamily:=DEFAULT_PITCH;NativeFont.Handle:=CreateFontIndirectW(LF);Canvas.Font.Assign(NativeFont);
    Check(Canvas.Font.Pitch=fpDefault,'Review: LOGFONT default pitch maps to fpDefault');
    finally NativeFont.Free;end;
    Rejected:=False;try Canvas.Flush(nil);except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Flush nil target reports an argument error');
    Rejected:=False;try Recorder.Playback(TSkiaCanvas(nil));except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Playback nil wrapper reports an argument error');
    Rejected:=False;try Recorder.Playback(ISkCanvas(nil));except on E:ESkiaCanvasError do Rejected:=True;end;
    Check(Rejected,'Playback nil Skia canvas reports an argument error');
    Recorder.Brush.Color:=clRed;Recorder.FillRect(Types.Rect(0,0,20,20));Picture:=Recorder.FinishRecording;
    Check(Picture<>nil,'Rejected playback does not consume the recording');
    Picture.Playback(Canvas.SkCanvas);Check(Canvas.Pixels[10,10]=clRed,'Recording remains usable after invalid playback calls');
  finally Recorder.Free;Canvas.Free;end;
end;


