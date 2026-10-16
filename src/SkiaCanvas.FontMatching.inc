{ Native glyph coverage checks and indexed TTC selection. }
function TypefaceCoversText(const Face: ISkTypeface; const Text: string): Boolean;
var
  Font: ISkFont;
  Value: Cardinal;
begin
  Result := False;
  if Face = nil then
    Exit;

  Font := TSkFont.Create(Face, 16);
  for Value in TSkiaUnicode.CodePoints(UnicodeString(Text)) do
  begin
    if (Value < 32) or TSkiaUnicode.IsDefaultIgnorable(Value) then
      Continue;
    if Font.UnicharToGlyph(Value) = 0 then
      Exit;
  end;
  Result := True;

end;

{$IFDEF MSWINDOWS}

function UnicodeFontEnum(const LF: TEnumLogFontExW; const TM: TNewTextMetricW; FontType: DWORD; Data: LPARAM): Integer; stdcall;
var
  Names: TStringList;
  Name: string;
begin
  Names := TStringList(Pointer(Data));
  Name := string(LF.elfLogFont.lfFaceName);
  if (Name <> '') and (Name[1] <> '@') then
    Names.Add(Name);
  Result := 1;
end;

{$ENDIF}

function TSkiaFontManager.MatchTypefaceForText(const Text, PreferredFamily, Language: string): ISkTypeface;
var
  Names: TStringList;
  Name, Script, Key: string;
  Value: Cardinal;
  Face: ISkTypeface;
{$IFDEF MSWINDOWS}DC: HDC;
  LF: TLogFontW; {$ENDIF}
  function TryName(const Family: string): ISkTypeface;
  var
    CacheKey: string;
  begin
    Result := FindCustom(Family);
    if TypefaceCoversText(Result, Text) then
      Exit;
    CacheKey := '$unicode-family:' + LowerCase(Family);
    if not FCache.TryGetValue(CacheKey, Result) then
    begin
      Result := TSkTypeface.MakeFromName(Family, TSkFontStyle.Normal);
      FCache.AddOrSetValue(CacheKey, Result);
    end;
    if not TypefaceCoversText(Result, Text) then
      Result := nil;
  end;

begin
  FLock.Enter;
  try
    Key := '$unicode-match:' + LowerCase(PreferredFamily) + '|' + LowerCase(Language) + '|' + Text;
    if FCache.TryGetValue(Key, Result) then
      Exit;
    Result := TryName(PreferredFamily);
    if Result <> nil then
    begin
      FCache.AddOrSetValue(Key, Result);
      Exit;
    end;
    for Face in FCustom.Values do
      if TypefaceCoversText(Face, Text) then
      begin
        Result := Face;
        FCache.AddOrSetValue(Key, Result);
        Exit;
      end;
    Script := 'Common';
    for Value in TSkiaUnicode.CodePoints(UnicodeString(Text)) do
    begin
      Name := TSkiaUnicode.ScriptName(Value);
      if (Name <> 'Common') and (Name <> 'Inherited') then
      begin
        Script := Name;
        Break;
      end;
    end;
    Names := TStringList.Create;
    try
      if (Copy(LowerCase(Language), 1, 2) = 'ja') or (Script = 'Hiragana') or (Script = 'Katakana') then
      begin
        Names.Add('Yu Gothic');
        Names.Add('MS Gothic');
      end;
      if (Copy(LowerCase(Language), 1, 2) = 'ko') or (Script = 'Hangul') then
        Names.Add('Malgun Gothic');
      if LowerCase(Language) = 'zh-hant' then
      begin
        Names.Add('Microsoft JhengHei');
        Names.Add('MingLiU');
      end;
      if Script = 'Han' then
      begin
        Names.Add('Microsoft YaHei');
        Names.Add('SimSun');
      end;
      if Script = 'Syriac' then
        Names.Add('Estrangelo Edessa');
      if Script = 'Thaana' then
        Names.Add('MV Boli');
      if (Script = 'Adlam') or (Script = 'Nko') then
        Names.Add('Ebrima');
      if Script = 'Arabic' then
      begin
        Names.Add('Tahoma');
        Names.Add('Arial');
      end;
      Names.Add('Segoe UI');
      Names.Add('Segoe UI Historic');
      Names.Add('Segoe UI Symbol');
      for Name in Names do
      begin
        Result := TryName(Name);
        if Result <> nil then
          Break;
      end;

      if Result = nil then
      begin
        Names.Clear;
        Names.Sorted := True;
        Names.Duplicates := dupIgnore;
{$IFDEF MSWINDOWS}
        FillChar(LF, SizeOf(LF), 0);
        LF.lfCharSet := DEFAULT_CHARSET;
        DC := CreateCompatibleDC(0);
        try
          EnumFontFamiliesExW(DC, LF, @UnicodeFontEnum, LPARAM(Pointer(Names)), 0);
        finally
          DeleteDC(DC);
        end;
{$ELSE}
        for Name in Forms.Screen.Fonts do
          Names.Add(Name);
{$ENDIF}
        for Name in Names do
        begin
          Result := TryName(Name);
          if Result <> nil then
            Break;
        end;
      end;

      FCache.AddOrSetValue(Key, Result);
    finally
      Names.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSkiaFontManager.CollectionFaceCount(const FileName: string): Integer;
var
  Stream: TFileStream;
  Header: array [0 .. 11] of Byte;
  Offsets: array [0 .. 3] of Byte;
  I: Integer;
  Offset: Cardinal;
  DirectoryPosition: Int64;
  function BE32(const B: array of Byte; Start: Integer): Cardinal;
  begin
    Result := (Cardinal(B[Start]) shl 24) or (Cardinal(B[Start + 1]) shl 16) or (Cardinal(B[Start + 2]) shl 8) or B[Start + 3];
  end;
  procedure ValidateFace(FaceOffset: Cardinal);
  var
    FaceHeader: array [0 .. 11] of Byte;
    Entry: array [0 .. 15] of Byte;
    Count, J: Integer;
    TableOffset, TableLength: Cardinal;
  begin
    if Int64(FaceOffset) + 12 > Stream.Size then
      raise ESkiaCanvasError.Create(SSkiaTruncatedSfntFace);
    Stream.Position := FaceOffset;
    Stream.ReadBuffer(FaceHeader, 12);
    if (BE32(FaceHeader, 0) <> $00010000) and (BE32(FaceHeader, 0) <> $4F54544F) and (BE32(FaceHeader, 0) <> $74727565) then
      raise ESkiaCanvasError.Create(SSkiaInvalidSfntSignature);
    Count := Integer(FaceHeader[4]) * 256 + FaceHeader[5];
    if (Count = 0) or (Int64(FaceOffset) + 12 + Int64(Count) * 16 > Stream.Size) then
      raise ESkiaCanvasError.Create(SSkiaInvalidSfntDirectory);
    for J := 0 to Count - 1 do
    begin
      Stream.ReadBuffer(Entry, 16);
      TableOffset := BE32(Entry, 8);
      TableLength := BE32(Entry, 12);
      if Int64(TableOffset) + TableLength > Stream.Size then
        raise ESkiaCanvasError.Create(SSkiaInvalidSfntTableBounds);
    end;
  end;

begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size < 12 then
      raise ESkiaCanvasError.Create(SSkiaTruncatedSfntHeader);
    Stream.ReadBuffer(Header, 12);
    case BE32(Header, 0) of
      $00010000, $4F54544F, $74727565:
        begin
          ValidateFace(0);
          Result := 1;
        end;
      $74746366:
        begin
          if (BE32(Header, 4) <> $00010000) and (BE32(Header, 4) <> $00020000) then
            raise ESkiaCanvasError.Create(SSkiaInvalidTtcVersion);
          if (BE32(Header, 8) = 0) or (BE32(Header, 8) > Cardinal(MaxInt)) then
            raise ESkiaCanvasError.Create(SSkiaInvalidTtcFaceCount);
          Result := BE32(Header, 8);
          if Stream.Size < 12 + Int64(Result) * 4 then
            raise ESkiaCanvasError.Create(SSkiaTruncatedTtcDirectory);
          for I := 0 to Result - 1 do
          begin
            Stream.ReadBuffer(Offsets, 4);
            Offset := BE32(Offsets, 0);
            if (Offset < 12 + Cardinal(Result) * 4) or (Int64(Offset) + 12 > Stream.Size) then
              raise ESkiaCanvasError.Create(SSkiaInvalidTtcFaceOffset);
            DirectoryPosition := Stream.Position;
            ValidateFace(Offset);
            Stream.Position := DirectoryPosition;
          end;
        end;
    else
      raise ESkiaCanvasError.Create(SSkiaInvalidFontContainer);
    end;
  finally
    Stream.Free;
  end;
end;

function TSkiaFontManager.MatchCollectionTypeface(const FileName, Text: string; out FaceIndex: Integer): ISkTypeface;
var
  I: Integer;
  Face: ISkTypeface;
begin
  Result := nil;
  FaceIndex := -1;
  for I := 0 to CollectionFaceCount(FileName) - 1 do
  begin
    Face := TSkTypeface.MakeFromFile(FileName, I);
    if TypefaceCoversText(Face, Text) then
    begin
      FaceIndex := I;
      Exit(Face);
    end;
  end;
end;
