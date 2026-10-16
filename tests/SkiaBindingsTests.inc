{ Shared regression tests for Skia4Delphi fce5db2 and preceding 7.3 fixes. }
procedure TestUpdatedSkiaBindings;
var
  Style: ISkTextStyle;
  StyleObject: TSkTextStyle;
  Features, CopyFeatures: TArray<TSkFontFeature>;
  Shadows: TArray<TSkTextShadow>;
  Edging: TSkFontEdging;
  Hinting: TSkFontHinting;
  Pixmap: ISkPixmap;
  Pixels: array[0..3] of Cardinal;
  Region: ISkRegion;
  R: TRect;
  I, Count: Integer;
begin
  StyleObject := TSkTextStyle.Create;
  Style := StyleObject;
  Check(Length(StyleObject.FontFeatures) = 0, 'updated Skia: default font features empty');
  Check(Length(StyleObject.Shadows) = 0, 'updated Skia: default shadows empty');
  Check(TSkFontFeature.Create('liga', 1) = TSkFontFeature.Create('liga', 1),
    'updated Skia: font feature equality');
  Check(TSkFontFeature.Create('liga', 1) <> TSkFontFeature.Create('kern', 1),
    'updated Skia: font feature name inequality');
  Check(TSkFontFeature.Create('liga', 1) <> TSkFontFeature.Create('liga', 0),
    'updated Skia: font feature value inequality');
  Style.AddFontFeature('liga', 1);
  Style.AddFontFeature('kern', 0);
  Style.AddFontFeature('ss01', -1);
  Style.FontSize := 20;
  Features := StyleObject.FontFeatures;
  Check(Length(Features) = 3, 'updated Skia: font feature count');
  if Length(Features) = 3 then
  begin
    Check(Features[0] = TSkFontFeature.Create('liga', 1), 'updated Skia: liga round trip');
    Check(Features[1] = TSkFontFeature.Create('kern', 0), 'updated Skia: kern round trip');
    Check(Features[2] = TSkFontFeature.Create('ss01', -1), 'updated Skia: signed feature value');
    Features[0].Name := 'copy';
    CopyFeatures := StyleObject.FontFeatures;
    Check(CopyFeatures[0].Name = 'liga', 'updated Skia: feature arrays are independent');
  end;
  Style.AddShadow(TSkTextShadow.Create($80FF0000, PointF(2.5, -3.25), 4.5));
  Style.AddShadow(TSkTextShadow.Create($FF0000FF, PointF(-1, 0), 0));
  Shadows := StyleObject.Shadows;
  Check(Length(Shadows) = 2, 'updated Skia: shadow count');
  if Length(Shadows) = 2 then
  begin
    Check(Shadows[0] = TSkTextShadow.Create($80FF0000, PointF(2.5, -3.25), 4.5),
      'updated Skia: shadow color offset and double blur round trip');
    Check(Shadows[1] = TSkTextShadow.Create($FF0000FF, PointF(-1, 0), 0),
      'updated Skia: second shadow record stride');
  end;
  for I := 1 to 100 do
  begin
    Features := StyleObject.FontFeatures;
    Shadows := StyleObject.Shadows;
  end;
  Check((Length(Features) = 3) and (Length(Shadows) = 2),
    'updated Skia: repeated getter ownership');
  Style.ResetFontFeatures;
  Check(Length(StyleObject.FontFeatures) = 0, 'updated Skia: reset font features');
  Check(Length(StyleObject.Shadows) = 2, 'updated Skia: features reset keeps shadows');
  Style.ResetShadows;
  Check(Length(StyleObject.Shadows) = 0, 'updated Skia: reset shadows');
  Check(Style.FontSize = 20, 'updated Skia: resets preserve font size');
  for Edging := Low(TSkFontEdging) to High(TSkFontEdging) do
  begin
    StyleObject.FontEdging := Edging;
    Check(StyleObject.FontEdging = Edging, 'updated Skia: font edging ' + IntToStr(Ord(Edging)));
  end;
  for Hinting := Low(TSkFontHinting) to High(TSkFontHinting) do
  begin
    StyleObject.FontHinting := Hinting;
    Check(StyleObject.FontHinting = Hinting, 'updated Skia: font hinting ' + IntToStr(Ord(Hinting)));
  end;
  StyleObject.Subpixel := True;
  Check(StyleObject.Subpixel, 'updated Skia: subpixel enabled');
  StyleObject.Subpixel := False;
  Check(not StyleObject.Subpixel, 'updated Skia: subpixel disabled');
  Pixmap := TSkPixmap.Create;
  Check((Pixmap.Width = 0) and (Pixmap.Height = 0) and (Pixmap.Pixels = nil),
    'updated Skia: empty pixmap constructor');
  Pixels[0] := $FFFF0000; Pixels[1] := $FF00FF00;
  Pixels[2] := $FF0000FF; Pixels[3] := $FFFFFFFF;
  Pixmap := TSkPixmap.Create(TSkImageInfo.Create(2, 2, TSkColorType.BGRA8888,
    TSkAlphaType.Unpremul), @Pixels[0], 8);
  Check((Pixmap.Width = 2) and (Pixmap.Height = 2) and
    (Pixmap.GetColor(1, 0) = $FF00FF00), 'updated Skia: populated pixmap constructor retained');
  Region := TSkRegion.Create;
  Region.SetRects(TArray<TRect>.Create(Rect(0, 0, 4, 4), Rect(10, 0, 14, 4)));
  Count := 0;
  for R in Region.GetIterator do
  begin
    Check((R.Left = Count * 10) and (R.Top = 0) and
      (R.Right = Count * 10 + 4) and (R.Bottom = 4),
      'updated Skia: region iterator rectangle ' + IntToStr(Count));
    Inc(Count);
  end;
  Check(Count = 2, 'updated Skia: region iterator includes first and last');
  Count := 0;
  for R in Region.GetCliperator(Rect(1, 1, 12, 4)) do
  begin
    if Count = 0 then
      Check((R.Left = 1) and (R.Top = 1) and (R.Right = 4) and (R.Bottom = 4),
        'updated Skia: clipped region first rectangle')
    else
      Check((R.Left = 10) and (R.Top = 1) and (R.Right = 12) and (R.Bottom = 4),
        'updated Skia: clipped region last rectangle');
    Inc(Count);
  end;
  Check(Count = 2, 'updated Skia: clipped region count');
  Region.SetEmpty;
  Count := 0;
  for R in Region.GetIterator do Inc(Count);
  Check(Count = 0, 'updated Skia: empty region iterator');
  for R in Region.GetCliperator(Rect(0, 0, 20, 20)) do Inc(Count);
  Check(Count = 0, 'updated Skia: empty clipped region iterator');
end;
