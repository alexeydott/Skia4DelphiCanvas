{ All font raster settings and caller-owned pixmaps under affine transforms. }
procedure TestAffineRasterOptions;
const W = 320; H = 240;
var
  Native, Replay: TSkiaBitmapCanvas;
  Recorder: TSkiaMetafileCanvas;
  Picture: ISkPicture;
  Bitmap: TBitmap;
  Source, Probe: ISkPixmap;
  Data: array[0..23] of Cardinal;
  ProbePixel: Cardinal;
  Pixels, OtherPixels: TArray<TAlphaColor>;
  Matrix: TMatrix;
  Edging: TSkFontEdging;
  Hinting: TSkFontHinting;
  Subpixel, Transform, Clipped: Integer;
  Root, Name: string;
  PixmapCase: Boolean;
  Font: ISkFont;
  Saved: Integer;
  DefaultEdging: TSkFontEdging;
  DefaultHinting: TSkFontHinting;
  DefaultSubpixel: Boolean;

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

  procedure FillSource;
  var Row, Col: Integer;
  begin
    for Row := 0 to 3 do
    begin
      for Col := 0 to 3 do
        if Row < 2 then
        begin
          if Col < 2 then Data[Row*6+Col] := $FFFF0000
          else Data[Row*6+Col] := $FF00FF00;
        end
        else if Col < 2 then Data[Row*6+Col] := $800000FF
        else Data[Row*6+Col] := $FFFFFF00;
      Data[Row*6+4] := $DEADBEEF; Data[Row*6+5] := $DEADBEEF;
    end;
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
      if PixmapCase then
        C.DrawPixmap(Rect(-40, -30, 40, 30), Source)
      else
      begin
        C.Font.Name := 'Arial'; C.Font.Height := -24; C.Font.Color := clNavy;
        C.Brush.Style := bsClear; C.TextToCurves := False;
        C.FontEdging := Edging; C.FontHinting := Hinting;
        C.FontSubpixel := Subpixel <> 0;
        Font := C.AcquireFont;
        Check((Font.Edging = Edging) and (Font.Hinting = Hinting) and
          (Font.Subpixel = (Subpixel <> 0)), 'affine options: native font settings ' + Name);
        C.TextOut(-60, -12, 'Skia AV');
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
      FillSource;
      Scene(Native); Scene(Recorder);
      { Recording must own its pixmap even when the original pixels change. }
      Data[0] := $FF000000; Data[1] := $FF000000;
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
      if PixmapCase then
      begin
        Check(Different = 0, 'affine pixmap: recording matches native pixels ' + Name);
        Check((Data[4] = $DEADBEEF) and (Data[23] = $DEADBEEF),
          'affine pixmap: padded source retained ' + Name);
        if Clipped = 0 then
        begin
          X := Round(-20*Matrix.M11-15*Matrix.M21+Matrix.M31);
          Y := Round(-20*Matrix.M12-15*Matrix.M22+Matrix.M32);
          Native.SetWorldTransform(Matrix);
          Native.SetClipRect(Rect(-500, -500, 500, 500));
          Check(Native.ReadPixels(Probe, X, Y) and (ProbePixel = $FFFF0000),
            'affine pixmap: transformed red and device-coordinate read ' + Name);
        end;
      end;
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
  Root := ExtractFilePath(ParamStr(0))+'affine-options'+PathDelim;
  ForceDirectories(Root);
  Source := TSkPixmap.Create(TSkImageInfo.Create(4, 4, TSkColorType.BGRA8888,
    TSkAlphaType.Unpremul), @Data[0], 24);
  Probe := TSkPixmap.Create(TSkImageInfo.Create(1, 1, TSkColorType.BGRA8888,
    TSkAlphaType.Unpremul), @ProbePixel, 4);
  PixmapCase := False;
  for Edging := Low(TSkFontEdging) to High(TSkFontEdging) do
    for Hinting := Low(TSkFontHinting) to High(TSkFontHinting) do
      for Subpixel := 0 to 1 do for Transform := 0 to 5 do for Clipped := 0 to 2 do
      begin
        MakeMatrix(Transform);
        Name := 'text_e'+IntToStr(Ord(Edging))+'_h'+IntToStr(Ord(Hinting))+
          '_s'+IntToStr(Subpixel)+'_t'+IntToStr(Transform)+'_c'+IntToStr(Clipped);
        CaseRun;
      end;
  PixmapCase := True;
  for Transform := 0 to 5 do for Clipped := 0 to 2 do
  begin
    MakeMatrix(Transform);
    Name := 'pixmap_t'+IntToStr(Transform)+'_c'+IntToStr(Clipped);
    CaseRun;
  end;
end;
