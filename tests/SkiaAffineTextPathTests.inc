{ TextOnPath curve and polyline with all font settings and affine clips. }
procedure TestAffineTextOnPathOptions;
const W = 320; H = 240;
var
  Native, Replay: TSkiaBitmapCanvas;
  Recorder: TSkiaMetafileCanvas;
  Picture: ISkPicture;
  Bitmap: TBitmap;
  Pixels, OtherPixels: TArray<TAlphaColor>;
  Matrix: TMatrix;
  Edging: TSkFontEdging;
  Hinting: TSkFontHinting;
  Subpixel, Transform, Clipped: Integer;
  Root, Name: string;
  PathKind, Language: Integer;
  Text: string;
  Samples: TStringList;
  Options: TSkiaTextPathOptions;
  PathBuilder: ISkPathBuilder;
  TextPath: ISkPath;
  Font: ISkFont;
  Saved: Integer;
  DefaultEdging: TSkFontEdging;
  DefaultHinting: TSkFontHinting;
  DefaultSubpixel: Boolean;

  procedure CheckScriptShaping;
  var C: TSkiaBitmapCanvas; F: ISkFont; Provider: ISkTypefaceFontProvider;
    Style: ISkParagraphStyle; Builder: ISkParagraphBuilder; Paragraph: ISkParagraph;
    Count, Missing, ZeroWidth, MarkPaths: Integer; Increasing, Decreasing: Boolean;
  begin
    C := TSkiaBitmapCanvas.Create(1, 1);
    try
      C.Font.Name := 'Arial'; C.Font.Height := -24; F := C.AcquireFont;
      Provider := TSkTypefaceFontProvider.Create;
      Provider.RegisterTypeface(F.Typeface, 'CanvasPathFont');
      Style := TSkParagraphStyle.Create;
      Style.TextStyle.FontFamilies := TArray<string>.Create('CanvasPathFont');
      Style.TextStyle.FontSize := 24;
      Builder := TSkParagraphBuilder.Create(Style, Provider);
      Builder.AddText(Text); Paragraph := Builder.Build; Paragraph.Layout(1.0E8);
      Count := 0; Missing := 0; ZeroWidth := 0; MarkPaths := 0;
      Increasing := False; Decreasing := False;
      Paragraph.Visit(
        procedure(const Line: Integer; const Info: TSkParagraphVisitorInfo)
        var I: Integer; Widths: TArray<Single>; Path: ISkPath;
        begin
          Inc(Count, Info.Count);
          for I := 0 to Info.Count-1 do
          begin
            if Info.Glyphs[I] = 0 then Inc(Missing);
            if I > 0 then
            begin
              Increasing := Increasing or (Info.Utf8Starts[I] > Info.Utf8Starts[I-1]);
              Decreasing := Decreasing or (Info.Utf8Starts[I] < Info.Utf8Starts[I-1]);
            end;
            if Language = 4 then
            begin
              Widths := Info.Font.GetWidths(TArray<Word>.Create(Info.Glyphs[I]));
              if (Length(Widths) = 1) and (Abs(Widths[0]) < 0.01) then
              begin
                Inc(ZeroWidth); Path := Info.Font.GetPath(Info.Glyphs[I]);
                if (Path <> nil) and not Path.IsEmpty then Inc(MarkPaths);
              end;
            end;
          end;
        end);
      Check((Count > 0) and (Missing = 0), 'TextOnPath: Unicode shaping has no missing glyphs '+IntToStr(Language));
      if Language = 2 then
        Check(Count < Length(Text), 'TextOnPath: Arabic lam-alef uses contextual shaping');
      if Language = 3 then
      begin
        Check(Increasing, 'TextOnPath: mixed bidi has a logical LTR run');
        Check(Decreasing, 'TextOnPath: mixed bidi has a reordered RTL run');
      end;
      if Language = 4 then
      begin
        Check(ZeroWidth >= 2, 'TextOnPath: Arabic vowel marks have zero advance');
        Check(MarkPaths >= 2, 'TextOnPath: Arabic vowel marks have visible outlines');
      end;
    finally C.Free; end;
  end;

  procedure MakeMatrix(Index: Integer);
  var A, SX, SY: Single;
  begin
    A := 0; SX := 1; SY := 1;
    case Index of
      1: A := Pi / 6;
      2: SX := -1;
      3: SY := -1;
      4: begin SX := 1.8; SY := 0.65; end;
      5: begin SX := -1.4; SY := 0.75; A := Pi / 7; end;
    end;
    Matrix := TMatrix.Identity;
    Matrix.M11 := SX * Cos(A); Matrix.M12 := SX * Sin(A);
    Matrix.M21 := -SY * Sin(A); Matrix.M22 := SY * Cos(A);
    Matrix.M31 := 160; Matrix.M32 := 120;
  end;

  procedure Scene(C: TSkiaCanvas);
  begin
    C.Brush.Style := bsSolid; C.Brush.Color := clWhite;
    C.FillRect(Rect(0, 0, W, H));
    Saved := C.SaveState;
    DefaultEdging := C.FontEdging; DefaultHinting := C.FontHinting;
    DefaultSubpixel := C.FontSubpixel;
    try
      if Clipped = 1 then C.SetClipRect(Rect(145, 90, 175, 150));
      C.SetWorldTransform(Matrix);
      if Clipped = 2 then C.SetClipRect(Rect(-15, -30, 15, 30));
      begin
        C.Font.Name := 'Arial'; C.Font.Height := -24; C.Font.Color := clNavy;
        C.Brush.Style := bsClear; C.TextToCurves := False;
        C.FontEdging := Edging; C.FontHinting := Hinting;
        C.FontSubpixel := Subpixel <> 0;
        Font := C.AcquireFont;
        Check((Font.Edging = Edging) and (Font.Hinting = Hinting) and
          (Font.Subpixel = (Subpixel <> 0)), 'affine options: native font settings ' + Name);
        Options := TSkiaTextPathOptions.Default;
        Options.Offset := 10; Options.Distance := 3;
        if Language > 0 then begin Options.Alignment := tpaCenter; Options.Offset := 0; end;
        if PathKind = 0 then
          C.TextOnPath(Text, TextPath, Options)
        else
          C.TextOnPath(Text, TArray<TPointF>.Create(PointF(-65, 8),
            PointF(-20, -8), PointF(20, 8), PointF(65, -5)), Options);
      end;
    finally
      C.RestoreState(Saved);
    end;
    Check((C.FontEdging = DefaultEdging) and (C.FontHinting = DefaultHinting) and
      (C.FontSubpixel = DefaultSubpixel) and
      (C.GetWorldTransform.M31 = 0) and (C.GetWorldTransform.M32 = 0) and
      (C.GetWorldTransform.M11 = 1) and (C.GetWorldTransform.M22 = 1) and
      (C.ClipRect.Left = 0) and (C.ClipRect.Top = 0) and
      (C.ClipRect.Right = W) and (C.ClipRect.Bottom = H),
      'affine options: saved state restored ' + Name);
  end;

  procedure Read(C: TSkiaBitmapCanvas; out Values: TArray<TAlphaColor>);
  begin
    SetLength(Values, W*H);
    if not C.Snapshot.ReadPixels(TSkImageInfo.Create(W, H, TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul), Pointer(Values), W*4) then
      raise Exception.Create('Affine regression pixel read failed');
  end;

  procedure ExportSVG(const Pic: ISkPicture; const FileName: string);
  var Output: TFileStream; Canvas: ISkCanvas;
  begin
    Output := TFileStream.Create(FileName, fmCreate);
    try
      Canvas := TSkSVGCanvas.Make(RectF(0, 0, W, H), Output);
      Pic.Playback(Canvas);
    finally Canvas := nil; Output.Free; end;
  end;

  procedure ExportPDF(const Pic: ISkPicture; const FileName: string);
  var Output: TFileStream; Doc: ISkDocument; Page: ISkCanvas;
  begin
    Output := TFileStream.Create(FileName, fmCreate);
    try
      Doc := TSkDocument.MakePDF(Output);
      Page := Doc.BeginPage(W, H); Pic.Playback(Page);
      Doc.EndPage; Page := nil; Doc.Close;
    finally Page := nil; Doc := nil; Output.Free; end;
  end;

  procedure CaseRun;
  var I, X, Y, Ink, Outside, Different: Integer;
    LX, LY, DX, DY, Det: Single;
  begin
    Native := TSkiaBitmapCanvas.Create(W, H);
    Replay := TSkiaBitmapCanvas.Create(W, H);
    Recorder := TSkiaMetafileCanvas.Create(W, H);
    try
      Scene(Native); Scene(Recorder);
      Picture := Recorder.FinishRecording;
      Picture.Playback(Replay.SkCanvas);
      Read(Native, Pixels); Read(Replay, OtherPixels);
      Ink := 0; Outside := 0; Different := 0;
      for Y := 0 to H-1 do for X := 0 to W-1 do
      begin
        I := Y*W+X;
        if Pixels[I] and $FFFFFF <> $FFFFFF then
        begin
          Inc(Ink);
          if (Clipped = 1) and ((X < 144) or (X > 175) or (Y < 89) or (Y > 150)) then Inc(Outside);
          if Clipped = 2 then
          begin
            DX := X+0.5-Matrix.M31; DY := Y+0.5-Matrix.M32;
            Det := Matrix.M11*Matrix.M22-Matrix.M12*Matrix.M21;
            LX := (DX*Matrix.M22-DY*Matrix.M21)/Det;
            LY := (DY*Matrix.M11-DX*Matrix.M12)/Det;
            if (Abs(LX) > 18) or (Abs(LY) > 33) then Inc(Outside);
          end;
        end;
        if Pixels[I] <> OtherPixels[I] then Inc(Different);
      end;
      Check(Ink > 10, 'affine options: visible pixels ' + Name);
      Check(Outside = 0, 'affine options: device clipping ' + Name);
      Check(Different = 0, 'TextOnPath: recording matches native pixels ' + Name);
      Bitmap := TBitmap.Create;
      try Native.Flush(Bitmap); Bitmap.SaveToFile(Root+Name+'.bmp'); finally Bitmap.Free; end;
      ExportSVG(Picture, Root+Name+'.svg');
      ExportPDF(Picture, Root+Name+'.pdf');
    finally
      Picture := nil; Font := nil;
      Recorder.Free; Replay.Free; Native.Free;
    end;
  end;
begin
  Root := ExtractFilePath(ParamStr(0))+'textpath-affine-options'+PathDelim;
  ForceDirectories(Root);
  PathBuilder := TSkPathBuilder.Create;
  PathBuilder.MoveTo(-65, 8);
  PathBuilder.CubicTo(-25, -15, 25, 25, 65, 8);
  TextPath := PathBuilder.Detach;
  Samples := TStringList.Create;
  try
    Samples.LoadFromFile(ExtractFilePath(ParamStr(0))+'../../fixtures/textpath-unicode.txt', TEncoding.UTF8);
    Check(Samples.Count = 5, 'TextOnPath: UTF-8 fixture has five text cases');
    Check(Samples[1] = #$041F#$0440#$0438#$0432#$0435#$0442, 'TextOnPath: Cyrillic UTF-8 decoding');
    Check(Samples[2] = #$0633#$0644#$0627#$0645, 'TextOnPath: Arabic UTF-8 decoding');
    Check(Samples[3] = 'AB '+#$0633#$0644#$0627#$0645+' 12', 'TextOnPath: mixed bidi UTF-8 decoding');
    Check(Samples[4] = #$0633#$064E#$0644#$0627#$0645#$064F, 'TextOnPath: vowel marks UTF-8 decoding');
  for Language := 0 to 4 do
  begin
    Text := Samples[Language];
    CheckScriptShaping;
  for PathKind := 0 to 1 do
  for Edging := Low(TSkFontEdging) to High(TSkFontEdging) do
    for Hinting := Low(TSkFontHinting) to High(TSkFontHinting) do
      for Subpixel := 0 to 1 do for Transform := 0 to 5 do for Clipped := 0 to 2 do
      begin
        MakeMatrix(Transform);
        Name := 'path'+IntToStr(PathKind)+'_e'+IntToStr(Ord(Edging))+'_h'+IntToStr(Ord(Hinting))+
          '_s'+IntToStr(Subpixel)+'_t'+IntToStr(Transform)+'_c'+IntToStr(Clipped);
        if Language > 0 then Name := 'lang'+IntToStr(Language)+'_'+Name;
        CaseRun;
      end;
  end;
  finally Samples.Free; end;
end;
