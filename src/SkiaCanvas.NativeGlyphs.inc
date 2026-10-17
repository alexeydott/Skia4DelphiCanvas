{ Linux font selection and OpenType shaping. Fontconfig resolves the same
  installed faces used by Skia; HarfBuzz supplies glyph advances and offsets. }
type
  THbGlyphInfo = record
    Codepoint, Mask, Cluster, Var1, Var2: Cardinal;
  end;

  PHbGlyphInfo = ^THbGlyphInfo;

  THbGlyphPosition = record
    XAdvance, YAdvance, XOffset, YOffset: LongInt;
    Reserved: Cardinal;
  end;

  PHbGlyphPosition = ^THbGlyphPosition;
function FcPatternCreate: Pointer; cdecl; external 'libfontconfig.so.1';
procedure FcPatternDestroy(P: Pointer); cdecl; external 'libfontconfig.so.1';
function FcPatternAddString(P: Pointer; Name, Value: PAnsiChar): LongBool; cdecl; external 'libfontconfig.so.1';
function FcPatternAddInteger(P: Pointer; Name: PAnsiChar; Value: Integer): LongBool; cdecl; external 'libfontconfig.so.1';
function FcPatternAddCharSet(P: Pointer; Name: PAnsiChar; Charset: Pointer): LongBool; cdecl; external 'libfontconfig.so.1';
function FcCharSetCreate: Pointer; cdecl; external 'libfontconfig.so.1';
procedure FcCharSetDestroy(P: Pointer); cdecl; external 'libfontconfig.so.1';
function FcCharSetAddChar(P: Pointer; Value: Cardinal): LongBool; cdecl; external 'libfontconfig.so.1';
function FcConfigSubstitute(Config, P: Pointer; Kind: Integer): LongBool; cdecl; external 'libfontconfig.so.1';
procedure FcDefaultSubstitute(P: Pointer); cdecl; external 'libfontconfig.so.1';
function FcFontMatch(Config, P: Pointer; out Status: Integer): Pointer; cdecl; external 'libfontconfig.so.1';
function FcPatternGetString(P: Pointer; Name: PAnsiChar; I: Integer; out Value: PAnsiChar): Integer; cdecl; external 'libfontconfig.so.1';
function FcPatternGetInteger(P: Pointer; Name: PAnsiChar; I: Integer; out Value: Integer): Integer; cdecl; external 'libfontconfig.so.1';
function hb_blob_create_from_file_or_fail(FileName: PAnsiChar): Pointer; cdecl; external 'libharfbuzz.so.0';
procedure hb_blob_destroy(P: Pointer); cdecl; external 'libharfbuzz.so.0';
function hb_face_create(Blob: Pointer; Index: Cardinal): Pointer; cdecl; external 'libharfbuzz.so.0';
procedure hb_face_destroy(P: Pointer); cdecl; external 'libharfbuzz.so.0';
function hb_face_get_upem(P: Pointer): Cardinal; cdecl; external 'libharfbuzz.so.0';
function hb_font_create(Face: Pointer): Pointer; cdecl; external 'libharfbuzz.so.0';
procedure hb_font_destroy(P: Pointer); cdecl; external 'libharfbuzz.so.0';
procedure hb_ot_font_set_funcs(P: Pointer); cdecl; external 'libharfbuzz.so.0';
procedure hb_font_set_scale(P: Pointer; X, Y: Integer); cdecl; external 'libharfbuzz.so.0';
function hb_buffer_create: Pointer; cdecl; external 'libharfbuzz.so.0';
procedure hb_buffer_destroy(P: Pointer); cdecl; external 'libharfbuzz.so.0';
procedure hb_buffer_add_utf16(P: Pointer; Text: PWideChar; Length: Integer; Offset: Cardinal; ItemLength: Integer); cdecl; external 'libharfbuzz.so.0';
procedure hb_buffer_guess_segment_properties(P: Pointer); cdecl; external 'libharfbuzz.so.0';
procedure hb_shape(Font, Buffer, Features: Pointer; Count: Cardinal); cdecl; external 'libharfbuzz.so.0';
function hb_buffer_get_glyph_infos(P: Pointer; Count: PCardinal): PHbGlyphInfo; cdecl; external 'libharfbuzz.so.0';
function hb_buffer_get_glyph_positions(P: Pointer; Count: PCardinal): PHbGlyphPosition; cdecl; external 'libharfbuzz.so.0';

function fribidi_log2vis(Text: PCardinal; Length: Integer; BaseDirection: PCardinal; Visual: PCardinal; LogicalToVisual, VisualToLogical: PInteger; Levels: PByte): Byte; cdecl;
  external 'libfribidi.so.0';
procedure hb_buffer_set_direction(Buffer: Pointer; Direction: Integer); cdecl; external 'libharfbuzz.so.0';

function NativeShapeRuns(Font: Pointer; const Text: UnicodeString; out Glyphs: TArray<TGdiShapedGlyph>): Boolean;
type
  TRun = record
    First, Count, Visual: Integer;
    Level: Byte;
  end;
var
  Values: TArray<Cardinal>;
  Levels: TArray<Byte>;
  Mapping: TArray<Integer>;
  Scripts: TArray<string>;
  Runs: TArray<TRun>;
  Run, Swap: TRun;
  Base: Cardinal;
  I, J, N, First, OldCount: Integer;
  RunText, Scalar: UnicodeString;
  RunLength: Integer;
  Buffer: Pointer;
  Count, PositionCount: Cardinal;
  Infos: PHbGlyphInfo;
  Positions: PHbGlyphPosition;
begin
  Result := False;
  Glyphs := nil;
  Values := TSkiaUnicode.CodePoints(Text);
  N := Length(Values);
  if N = 0 then
    Exit(True);
  SetLength(Levels, N);
  SetLength(Mapping, N);
  SetLength(Scripts, N);
  Base := $40;
  if fribidi_log2vis(Pointer(Values), N, @Base, nil, Pointer(Mapping), nil, Pointer(Levels)) = 0 then
    Exit;
  for I := 0 to N - 1 do
  begin
    Scripts[I] := TSkiaUnicode.ScriptName(Values[I]);
    if (Scripts[I] = 'Common') or (Scripts[I] = 'Inherited') then
    begin
      Scripts[I] := '';
      if (I > 0) and (Levels[I] = Levels[I - 1]) then
        Scripts[I] := Scripts[I - 1];
    end;
  end;
  for I := N - 2 downto 0 do
    if (Scripts[I] = '') and (Levels[I] = Levels[I + 1]) then
      Scripts[I] := Scripts[I + 1];
  First := 0;
  while First < N do
  begin
    Run.First := First;
    Run.Level := Levels[First];
    Run.Visual := Mapping[First];
    I := First + 1;
    while (I < N) and (Levels[I] = Run.Level) and (Scripts[I] = Scripts[First]) do
    begin
      Run.Visual := Math.Min(Run.Visual, Mapping[I]);
      Inc(I);
    end;
    Run.Count := I - First;
    SetLength(Runs, Length(Runs) + 1);
    Runs[High(Runs)] := Run;
    First := I;
  end;
  for I := 0 to High(Runs) - 1 do
    for J := I + 1 to High(Runs) do
      if Runs[J].Visual < Runs[I].Visual then
      begin
        Swap := Runs[I];
        Runs[I] := Runs[J];
        Runs[J] := Swap;
      end;
  for Run in Runs do
  begin
    SetLength(RunText, Math.Min(Int64(Run.Count) * 2, Int64(Length(Text))));
    RunLength := 0;
    for I := Run.First to Run.First + Run.Count - 1 do
    begin
      Scalar := TSkiaUnicode.ScalarText(Values[I]);
      Move(Scalar[1], RunText[RunLength+1], Length(Scalar) * SizeOf(WideChar));
      Inc(RunLength, Length(Scalar));
    end;
    SetLength(RunText, RunLength);
    Buffer := hb_buffer_create;
    try
      hb_buffer_add_utf16(Buffer, PWideChar(RunText), Length(RunText), 0, Length(RunText));
      hb_buffer_set_direction(Buffer, 4 + (Run.Level and 1));
      hb_buffer_guess_segment_properties(Buffer);
      hb_shape(Font, Buffer, nil, 0);
      Infos := hb_buffer_get_glyph_infos(Buffer, @Count);
      Positions := hb_buffer_get_glyph_positions(Buffer, @PositionCount);
      if (Infos = nil) or (Positions = nil) or (Count <> PositionCount) then
      begin
        Glyphs := nil;
        Exit;
      end;
      OldCount := Length(Glyphs);
      SetLength(Glyphs, OldCount + Integer(Count));
      for I := 0 to Integer(Count) - 1 do
      begin
        Glyphs[OldCount + I].GlyphIndex := Infos[I].Codepoint;
        Glyphs[OldCount + I].AdvanceX := Positions[I].XAdvance;
        Glyphs[OldCount + I].OffsetX := Positions[I].XOffset;
        Glyphs[OldCount + I].OffsetY := Positions[I].YOffset;
      end;
    finally
      hb_buffer_destroy(Buffer);
    end;
  end;
  Result := True;
end;

function NativeFontFile(const LF: TLogFontW; const Text: UnicodeString; out FileName: UTF8String; out Index: Integer): Boolean;
var
  Pattern, Match, Charset: Pointer;
  Family: UTF8String;
  Value: PAnsiChar;
  Status: Integer;
  Point: Cardinal;
begin
  Result := False;
  FileName := '';
  Index := 0;
  Family := UTF8Encode(UnicodeString(LF.lfFaceName));
  Pattern := FcPatternCreate;
  if Pattern = nil then
    Exit;
  try
    FcPatternAddString(Pattern, 'family', PAnsiChar(Family));
    if LF.lfWeight >= FW_BOLD then
      FcPatternAddInteger(Pattern, 'weight', 200)
    else
      FcPatternAddInteger(Pattern, 'weight', 80);
    if LF.lfItalic <> 0 then
      FcPatternAddInteger(Pattern, 'slant', 100);
    if Text <> '' then
    begin
      Charset := FcCharSetCreate;
      if Charset = nil then
        Exit;
      try
        for Point in TSkiaUnicode.CodePoints(Text) do
          if not TSkiaUnicode.IsDefaultIgnorable(Point) then
            FcCharSetAddChar(Charset, Point);
        FcPatternAddCharSet(Pattern, 'charset', Charset);
      finally
        FcCharSetDestroy(Charset);
      end;
    end;
    FcConfigSubstitute(nil, Pattern, 0);
    FcDefaultSubstitute(Pattern);
    Match := FcFontMatch(nil, Pattern, Status);
    if Match = nil then
      Exit;
    try
      if FcPatternGetString(Match, 'file', 0, Value) <> 0 then
        Exit;
      FileName := UTF8String(Value);
      FcPatternGetInteger(Match, 'index', 0, Index);
      Result := FileName <> '';
    finally
      FcPatternDestroy(Match);
    end;
  finally
    FcPatternDestroy(Pattern);
  end;
end;

constructor TSkiaGdiGlyphCache.Create;
begin
  inherited Create;
  FLock := SyncObjs.TCriticalSection.Create;
end;

destructor TSkiaGdiGlyphCache.Destroy;
begin
  FNativeFont := nil;
  FLock.Free;
  inherited;
end;

procedure TSkiaGdiGlyphCache.Lock;
begin
  FLock.Enter;
end;

procedure TSkiaGdiGlyphCache.Unlock;
begin
  FLock.Leave;
end;

procedure TSkiaGdiGlyphCache.Clear;
begin
  Lock;
  try
    FNativeFont := nil;
    FNativeShaped := False;
    FEmSquare := 0;
    FEmSquareKey := '';
  finally
    Unlock;
  end;
end;

function TSkiaGdiGlyphCache.GetLastShapeUsedOpenType: Boolean;
begin
  Lock;
  try
    Result := FNativeShaped;
  finally
    Unlock;
  end;
end;

function TSkiaGdiGlyphCache.GetEmSquare(const LF: TLogFontW; const FontKey: string): Integer;
var
  FileName: UTF8String;
  Index: Integer;
  Blob, Face: Pointer;
begin
  Lock;
  try
    if (FEmSquareKey = FontKey) and (FEmSquare > 0) then
      Exit(FEmSquare);
    Result := 0;
    if not NativeFontFile(LF, '', FileName, Index) then
      Exit;
    Blob := hb_blob_create_from_file_or_fail(PAnsiChar(FileName));
    if Blob = nil then
      Exit;
    try
      Face := hb_face_create(Blob, Index);
      try
        Result := hb_face_get_upem(Face);
      finally
        hb_face_destroy(Face);
      end;
    finally
      hb_blob_destroy(Blob);
    end;
    if Result > 0 then
    begin
      FEmSquare := Result;
      FEmSquareKey := FontKey;
    end;
  finally
    Unlock;
  end;
end;

function TSkiaGdiGlyphCache.GetCharHeight(const LF: TLogFontW; const FontKey: string): Integer;
begin
  Result := Math.Max(1, Abs(LF.lfHeight));
end;

function TSkiaGdiGlyphCache.GetGlyphPathByIndex(GlyphIndex: Word; out Advance: Single): ISkPath;
var
  Widths: TArray<Single>;
begin
  Lock;
  try
    Result := nil;
    Advance := 0;
    if FNativeFont = nil then
      Exit;
    Widths := FNativeFont.GetWidths(TArray<Word>.Create(GlyphIndex));
    if Length(Widths) <> 1 then
      Exit;
    Advance := Widths[0];
    Result := FNativeFont.GetPath(GlyphIndex);
    if Result <> nil then
      Result := Result.Transform(TMatrix.CreateScaling(1, -1));
  finally
    Unlock;
  end;
end;

function TSkiaGdiGlyphCache.ShapeText(const LF: TLogFontW; const FontKey: string; EmSquare: Integer; const Text: UnicodeString; out Glyphs: TArray<TGdiShapedGlyph>; RequireOpenType: Boolean): Boolean;
var
  FileName: UTF8String;
  Index: Integer;
  Blob, Face, Font: Pointer;
  Typeface: ISkTypeface;
begin
  Lock;
  try
    Glyphs := nil;
    FNativeShaped := False;
    Result := False;
    if EmSquare <= 0 then
      Exit;
    if Text = '' then
      Exit(True);
    try
      TSkiaUnicode.CodePoints(Text);
    except
      on E: ESkiaCanvasError do
        Exit;
    end;
    if not NativeFontFile(LF, Text, FileName, Index) then
      Exit;
    Typeface := TSkTypeface.MakeFromFile(string(FileName), Index);
    if Typeface = nil then
      Exit;
    Blob := hb_blob_create_from_file_or_fail(PAnsiChar(FileName));
    if Blob = nil then
      Exit;
    try
      Face := hb_face_create(Blob, Index);
      try
        Font := hb_font_create(Face);
        try
          hb_ot_font_set_funcs(Font);
          hb_font_set_scale(Font, EmSquare, EmSquare);
          if not NativeShapeRuns(Font, Text, Glyphs) then
            Exit;
          FNativeFont := TSkFont.Create(Typeface, EmSquare);
          FNativeFont.Hinting := TSkFontHinting.None;
          FNativeFont.Subpixel := True;
          FNativeShaped := True;
          Result := True;
        finally
          hb_font_destroy(Font);
        end;
      finally
        hb_face_destroy(Face);
      end;
    finally
      hb_blob_destroy(Blob);
    end;
  finally
    Unlock;
  end;
end;
