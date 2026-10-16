{ Canvas font rasterization options and caller-owned pixmap integration. }
procedure TestCanvasRasterSettingsAndPixmap;
var
  Canvas, Other: TSkiaBitmapCanvas;
  Recorder: TSkiaMetafileCanvas;
  Font, OldFont: ISkFont;
  Edging: TSkFontEdging;
  Hinting: TSkFontHinting;
  Saved: Integer;
  Source, Dest, Subset: ISkPixmap;
  Data: array[0..5] of Cardinal;
  Output: array[0..3] of Cardinal;
  Pixels: TArray<TAlphaColor>;
  Image: ISkImage;
  I, Partial: Integer;
  DefaultEdging: TSkFontEdging;
  DefaultHinting: TSkFontHinting;
  DefaultSubpixel: Boolean;
begin
  Canvas := TSkiaBitmapCanvas.Create(160, 64);
  Other := TSkiaBitmapCanvas.Create(160, 64);
  try
    Font := Canvas.AcquireFont;
    DefaultEdging := Font.Edging;
    DefaultHinting := Font.Hinting;
    DefaultSubpixel := Font.Subpixel;
    Check((Canvas.FontEdging = DefaultEdging) and
      (Canvas.FontHinting = DefaultHinting) and (Canvas.FontSubpixel = DefaultSubpixel),
      'raster options: platform defaults retained');
    Saved := Canvas.SaveState;
    for Edging := Low(TSkFontEdging) to High(TSkFontEdging) do
    begin
      Canvas.FontEdging := Edging;
      Check(Canvas.AcquireFont.Edging = Edging, 'raster options: edging ' + IntToStr(Ord(Edging)));
    end;
    for Hinting := Low(TSkFontHinting) to High(TSkFontHinting) do
    begin
      Canvas.FontHinting := Hinting;
      Check(Canvas.AcquireFont.Hinting = Hinting, 'raster options: hinting ' + IntToStr(Ord(Hinting)));
    end;
    Canvas.FontSubpixel := True;
    Check(Canvas.AcquireFont.Subpixel, 'raster options: subpixel on');
    OldFont := Canvas.AcquireFont;
    Canvas.FontSubpixel := False;
    Check(not Canvas.AcquireFont.Subpixel, 'raster options: subpixel off');
    Check(OldFont.Subpixel, 'raster options: previously acquired font remains unchanged');
    Check((Other.AcquireFont.Edging = DefaultEdging) and
      (Other.AcquireFont.Hinting = DefaultHinting) and
      (Other.AcquireFont.Subpixel = DefaultSubpixel), 'raster options: independent canvases');
    Canvas.Font.Height := -25;
    Check((Canvas.AcquireFont.Hinting = TSkFontHinting.Full) and
      not Canvas.AcquireFont.Subpixel, 'raster options: survive font cache invalidation');
    Canvas.RestoreState(Saved);
    Check((Canvas.FontEdging = DefaultEdging) and (Canvas.FontHinting = DefaultHinting) and
      (Canvas.FontSubpixel = DefaultSubpixel), 'raster options: state restores all settings');
    Canvas.Font.Height := -31;
    Canvas.Brush.Style := bsClear;
    Canvas.FontEdging := TSkFontEdging.Alias;
    Canvas.TextOut(4, 4, 'Skia');
    Image := Canvas.Snapshot;
    SetLength(Pixels, 160 * 64);
    Check(Image.ReadPixels(TSkImageInfo.Create(160, 64, TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul), Pointer(Pixels), 160 * 4), 'raster options: alias pixels readable');
    Partial := 0;
    for I := 0 to High(Pixels) do
      if ((Pixels[I] shr 24) <> 0) and ((Pixels[I] shr 24) <> 255) then Inc(Partial);
    Check(Partial = 0, 'raster options: alias has no antialiased edge pixels');
    Other.Font.Height := -31;
    Other.Brush.Style := bsClear;
    Other.FontEdging := TSkFontEdging.AntiAlias;
    Other.TextOut(4, 4, 'Skia');
    Image := Other.Snapshot;
    Check(Image.ReadPixels(TSkImageInfo.Create(160, 64, TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul), Pointer(Pixels), 160 * 4), 'raster options: antialiased pixels readable');
    Partial := 0;
    for I := 0 to High(Pixels) do
      if ((Pixels[I] shr 24) <> 0) and ((Pixels[I] shr 24) <> 255) then Inc(Partial);
    Check(Partial > 0, 'raster options: antialias produces edge pixels');
    Data[0] := $FFFF0000; Data[1] := $FF00FF00; Data[2] := $DEADBEEF;
    Data[3] := $800000FF; Data[4] := $FFFFFFFF; Data[5] := $DEADBEEF;
    Source := TSkPixmap.Create(TSkImageInfo.Create(2, 2, TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul), @Data[0], 12);
    Subset := TSkPixmap.Create;
    Check(Source.ExtractSubset(Subset, Rect(1, 0, 2, 2)), 'pixmap: empty constructor accepts extracted subset');
    Check((Subset.Width = 1) and (Subset.Height = 2) and
      (Subset.GetColor(0, 0) = $FF00FF00), 'pixmap: subset dimensions and pixels');
    Canvas.DrawPixmap(100, 30, Source);
    Data[0] := $FF000000;
    Dest := TSkPixmap.Create(TSkImageInfo.Create(2, 2, TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul), @Output[0], 8);
    Check(Canvas.ReadPixels(Dest, 100, 30), 'pixmap: read into caller storage with source offset');
    Check((Output[0] = $FFFF0000) and (Output[1] = $FF00FF00) and
      (Output[2] = $800000FF) and (Output[3] = $FFFFFFFF),
      'pixmap: padded stride alpha and copied source lifetime');
    Check((Data[2] = $DEADBEEF) and (Data[5] = $DEADBEEF), 'pixmap: source padding unchanged');
    Subset := TSkPixmap.Create;
    Check(not Canvas.ReadPixels(Subset), 'pixmap: empty destination rejected');
    Check(not Canvas.ReadPixels(nil), 'pixmap: nil destination rejected');
    Check(not Canvas.ReadPixels(Dest, 1000, 1000), 'pixmap: out-of-bounds read rejected');
    Canvas.DrawPixmap(0, 0, nil);
    Canvas.DrawPixmap(Rect(0, 0, 4, 4), Subset);
    Check(Canvas.ReadPixels(Dest, 100, 30) and (Output[0] = $FFFF0000),
      'pixmap: nil and empty drawing preserve destination');
    Canvas.DrawPixmap(Rect(120, 30, 124, 34), Source);
    Check(Canvas.ReadPixels(Dest, 122, 30) and (Output[1] = $FF00FF00),
      'pixmap: destination rectangle scales source');
    Canvas.SetClipRect(Rect(141, 40, 142, 42));
    Canvas.DrawPixmap(Rect(140, 40, 144, 44), Source);
    Canvas.ResetClip;
    Check(Canvas.ReadPixels(Dest, 140, 40) and (Output[0] = 0) and (Output[1] <> 0),
      'pixmap: drawing respects clipping');
    Recorder := TSkiaMetafileCanvas.Create(160, 64);
    try
      Data[0] := $FFFF0000;
      Recorder.DrawPixmap(100, 50, Source);
      Data[0] := $FF000000;
      Source := nil;
      Recorder.Playback(Other);
    finally
      Recorder.Free;
    end;
    Check(Other.ReadPixels(Dest, 100, 50), 'pixmap: recorded pixels readable after source release');
    Check((Output[0] = $FFFF0000) and (Output[1] = $FF00FF00) and
      (Output[2] = $800000FF), 'pixmap: recording owns an immutable copy');
  finally
    Other.Free;
    Canvas.Free;
  end;
end;
