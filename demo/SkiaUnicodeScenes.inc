{ Unicode examples share the normal canvas API and export as outlines. }
procedure UnicodeSample(C:TSkiaCanvas;X,Y,Size:Integer;const Text,Family:string);
begin
  C.Font.Name:=Family;C.Font.Height:=-Size;C.Font.Style:=[];C.Font.Color:=clNavy;
  C.Brush.Style:=bsClear;C.TextToCurves:=True;C.TextOut(X,Y,Text);
end;
procedure DrawUnicodeFonts(C:TSkiaCanvas);
const
  Samples:array[0..3] of UnicodeString=('Latin AVATAR',#$0627#$0644#$0639#$0631#$0628#$064A#$0629,
    #$4E2D#$6587#$5B57#$4F53,#$65E5#$672C#$8A9E#$304B#$306A);
  Languages:array[0..3] of string=('en','ar','zh-Hans','ja');
var X,Y,I,J,Index:Integer;Face:ISkTypeface;FontFile,Family,Text,Line:string;
  Points:TArray<TSkiaCodePoint>;Point:TSkiaCodePoint;LF:TLogFontW;Glyphs:TArray<TGdiShapedGlyph>;Key:string;R:TRect;
begin
  Panel(C,0,0,'Script-aware font matching','MatchTypefaceForText verifies every visible scalar',X,Y);
  for I:=0 to High(Samples) do begin
    Face:=C.FontManager.MatchTypefaceForText(NativeText(Samples[I]),'Consolas',Languages[I]);
    if Face=nil then Family:='No covering system font' else Family:=Face.GetFamilyName;
    LabelText(C,X+20,Y+88+I*48,12,UnicodeString(Languages[I]+' -> '+Family));
    if Face<>nil then UnicodeSample(C,X+20,Y+104+I*48,27,NativeText(Samples[I]),Family);
    Writeln('Font match ',Languages[I],': ',Family);
  end;
  Panel(C,1,0,'TTC / CJK face mapping','Read collection directory; select by glyph coverage',X,Y);
  {$IFDEF MSWINDOWS}FontFile:=SysUtils.GetEnvironmentVariable('WINDIR')+'\Fonts\simsun.ttc';{$ELSE}
  FontFile:=ExpandFileName(ExtractFilePath(ParamStr(0))+'../../../tests/fixtures/SkiaCjkFixture.ttc');{$ENDIF}
  
  if FileExists(FontFile) then begin
    J:=C.FontManager.CollectionFaceCount(FontFile);
    LabelText(C,X+20,Y+90,15,UnicodeString(ExtractFileName(FontFile)+' / '+IntToStr(J)+' indexed faces'));
    for I:=0 to Math.Min(J-1,2) do begin
      Face:=C.FontManager.LoadTypefaceFromFile(FontFile,I);
      LabelText(C,X+20,Y+120+I*27,14,UnicodeString('Face '+IntToStr(I)+': '+Face.GetFamilyName));
    end;
    {$IFDEF MSWINDOWS}Text:=NativeText(#$4E2D#$6587+' / '+#$6F22#$5B57);{$ELSE}Text:=NativeText(#$4E2D#$6587);{$ENDIF}
    Face:=C.FontManager.MatchCollectionTypeface(FontFile,Text,Index);
    if Face<>nil then begin
      C.FontManager.RegisterTypeface('DemoCollection',Face);
      UnicodeSample(C,X+20,Y+218,34,Text,'DemoCollection');
      LabelText(C,X+20,Y+267,13,UnicodeString('Coverage-selected face index: '+IntToStr(Index)));
      {$IFNDEF MSWINDOWS}LabelText(C,X+20,Y+294,11,'Synthetic test glyphs demonstrate collection face selection.');{$ENDIF}
      Writeln('CJK TTC mapped face ',Index,': ',Face.GetFamilyName);
    end;
  end else LabelText(C,X+20,Y+110,15,'Install the Windows CJK fonts to run this example.');
  Panel(C,0,1,'UTF-8 -> Unicode scalars','Offsets are bytes; supplementary scalars stay intact',X,Y);
  Text:=NativeText('A'+#$00E9+#$4E2D+WideChar($D83D)+WideChar($DE00));
  Points:=TSkiaUnicode.DecodeUtf8(UTF8Encode(UnicodeString('A'+#$00E9+#$4E2D+WideChar($D83D)+WideChar($DE00))));
  LabelText(C,X+20,Y+90,14,'offset / bytes / code point / script');
  I:=0;for Point in Points do begin
    Line:=Format('%d / %d / U+%s / %s',[Point.ByteOffset,Point.ByteLength,
      IntToHex(Point.Value,4),TSkiaUnicode.ScriptName(Point.Value)]);
    LabelText(C,X+20,Y+124+I*32,16,UnicodeString(Line));Inc(I);
  end;
  LabelText(C,X+20,Y+264,12,UnicodeString('ZWNJ is default-ignorable: '+BoolToStr(TSkiaUnicode.IsDefaultIgnorable($200C),True)));
  Panel(C,1,1,'Mixed RTL paragraph','Logical Unicode input -> OpenType visual glyph order',X,Y);
  Text:=NativeText('ABC 123 / '+#$05E9#$05DC#$05D5#$05DD+' / '+#$0633#$0644#$0627#$0645);
  C.Font.Name:='Tahoma';C.Font.Height:=-30;C.Font.Color:=clNavy;C.Brush.Style:=bsClear;
  R:=Types.Rect(X+20,Y+100,X+440,Y+245);C.TextRect(R,Text,[tfWordBreak,tfRtlReading,tfRight]);
  LabelText(C,X+20,Y+236,13,UnicodeString('Automatic base level: '+IntToStr(TSkiaUnicode.ParagraphLevel(UnicodeString(Text)))));
  LabelText(C,X+20,Y+264,13,'Use tfRtlReading for an explicit RTL paragraph base direction.');
  Panel(C,0,2,'Arabic + Persian contextual shaping',{$IFDEF MSWINDOWS}'Internal shaper: Uniscribe OpenType API'{$ELSE}'Internal shaper: HarfBuzz OpenType API'{$ENDIF},X,Y);
  for I:=0 to 1 do begin
    if I=0 then Text:=NativeText(#$0633#$0644#$0627#$0645+' '+#$0644#$0627)
    else Text:=NativeText(#$0641#$0627#$0631#$0633#$06CC+' / '+#$0645#$06CC#$200C#$0631#$0648#$0645);
    C.Font.Name:='Tahoma';C.Font.Height:=-36;
    C.FontManager.GetLogFont(C.Font,LF);Key:=C.FontManager.FontKey(C.Font);
    if C.GlyphCache.ShapeText(LF,Key,C.GlyphCache.GetEmSquare(LF,Key),UnicodeString(Text),Glyphs,True) then begin
      UnicodeSample(C,X+20,Y+102+I*78,36,Text,'Tahoma');
      LabelText(C,X+20,Y+151+I*78,13,UnicodeString(Format('%d UTF-16 units -> %d OpenType glyphs',[Length(Text),Length(Glyphs)])));
    end else LabelText(C,X+20,Y+110+I*78,13,'OpenType shaping unavailable in this configuration.');
  end;
  Panel(C,1,2,'OpenType pipeline + Unicode properties',{$IFDEF MSWINDOWS}'ScriptItemizeOpenType / ShapeOpenType / PlaceOpenType'{$ELSE}'Fontconfig / HarfBuzz / native Skia contours'{$ENDIF},X,Y);
  UnicodeSample(C,X+20,Y+102,40,'AVATAR office','Times New Roman');
  {$IFNDEF MSWINDOWS}
  C.FontManager.GetLogFont(C.Font,LF); Key:=C.FontManager.FontKey(C.Font);
  C.GlyphCache.ShapeText(LF,Key,C.GlyphCache.GetEmSquare(LF,Key),'AVATAR office',Glyphs,True);
  {$ENDIF}
  LabelText(C,X+20,Y+170,15,UnicodeString('Last run used OpenType: '+BoolToStr(C.GlyphCache.LastShapeUsedOpenType,True)));
  LabelText(C,X+20,Y+210,14,UnicodeString('Adlam U+1E900: '+TSkiaUnicode.ScriptName($1E900)));
  LabelText(C,X+20,Y+240,14,UnicodeString('RTL: '+BoolToStr(TSkiaUnicode.IsRightToLeft($1E900),True)));
  LabelText(C,X+20,Y+274,12,UnicodeString('Scalar round-trip: '+IntToHex(TSkiaUnicode.CodePoints(TSkiaUnicode.ScalarText($1E900))[0],5)));
end;
procedure DrawUnicodeRTL(C:TSkiaCanvas);
var Samples:TArray<Cardinal>;I,X,Y,Row,Column:Integer;Face:ISkTypeface;Text,Family,Script:string;
begin
  Samples:=TSkiaUnicode.RTLScriptSamples;
  LabelText(C,40,158,17,UnicodeString(Format('Unicode 17.0: all %d scripts containing assigned R/AL letters',[Length(Samples)])));
  LabelText(C,40,187,13,'The installed font set determines glyph availability. Missing coverage is reported explicitly.');
  for I:=0 to High(Samples) do begin
    Column:=I div 19;Row:=I mod 19;X:=40+Column*488;Y:=224+Row*49;
    Script:=TSkiaUnicode.ScriptName(Samples[I]);Text:=string(TSkiaUnicode.ScalarText(Samples[I]));
    Face:=C.FontManager.MatchTypefaceForText(Text,'Segoe UI Historic','');
    LabelText(C,X,Y,14,UnicodeString(Script+' / U+'+IntToHex(Samples[I],4)));
    if Face=nil then LabelText(C,X,Y+20,11,'No installed font covers this scalar',TColor($4B4BBC))
    else begin
      Family:=Face.GetFamilyName;LabelText(C,X,Y+20,11,UnicodeString(Family));
      UnicodeSample(C,X+367,Y,27,Text,Family);
    end;
  end;
end;


