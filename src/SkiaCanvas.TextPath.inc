{ Shape entire runs before positioning: never split Unicode text into characters. }
type
  TSkiaPathGlyph = record
    Path: ISkPath;
    X, Y, Advance: Single;
  end;

  TSkiaPathTextLayout = class
    Glyphs: TArray<TSkiaPathGlyph>;
    procedure Visit(const Line: Integer; const Info: TSkParagraphVisitorInfo);
  end;

procedure TSkiaPathTextLayout.Visit(const Line: Integer; const Info: TSkParagraphVisitorInfo);
var
  I, N: Integer;
begin
  N := Length(Glyphs);
  SetLength(Glyphs, N + Info.Count);
  for I := 0 to Info.Count - 1 do
  begin
    Glyphs[N + I].Path := Info.Font.GetPath(Info.Glyphs[I]);
    Glyphs[N + I].X := Info.Origin.X + Info.Positions[I].X;
    Glyphs[N + I].Y := Info.Origin.Y + Info.Positions[I].Y;
    if I + 1 < Info.Count then
      Glyphs[N + I].Advance := Info.Positions[I + 1].X - Info.Positions[I].X
    else
      Glyphs[N + I].Advance := Info.AdvanceX - Info.Positions[I].X;
  end;
end;

class function TSkiaTextPathOptions.Default: TSkiaTextPathOptions;
begin
  Result.Offset := 0;
  Result.Distance := 0;
  Result.LetterSpacing := 0;
  Result.Alignment := tpaStart;
  Result.Orientation := tpoTangent;
  Result.Reverse := False;
  Result.MirrorHorizontal := False;
  Result.MirrorVertical := False;
  Result.Wrap := False;
end;

procedure TSkiaCanvas.TextOnPath(const Text: string; const Path: ISkPath; Offset, Distance: Single);
var
  Options: TSkiaTextPathOptions;
begin
  Options := TSkiaTextPathOptions.Default;
  Options.Offset := Offset;
  Options.Distance := Distance;
  TextOnPath(Text, Path, Options);
end;

procedure TSkiaCanvas.TextOnPath(const Text: string; const Points: array of TPointF; Offset, Distance: Single);
var
  Options: TSkiaTextPathOptions;
begin
  Options := TSkiaTextPathOptions.Default;
  Options.Offset := Offset;
  Options.Distance := Distance;
  TextOnPath(Text, Points, Options);
end;

procedure TSkiaCanvas.TextOnPath(const Text: string; const Points: array of TPoint; Offset, Distance: Single);
var
  Options: TSkiaTextPathOptions;
begin
  Options := TSkiaTextPathOptions.Default;
  Options.Offset := Offset;
  Options.Distance := Distance;
  TextOnPath(Text, Points, Options);
end;

procedure TSkiaCanvas.TextOnPath(const Text: string; const Points: array of TPoint; const Options: TSkiaTextPathOptions);
var
  Values: TArray<TPointF>;
  I: Integer;
begin
  SetLength(Values, Length(Points));
  for I := 0 to High(Points) do
    Values[I] := PointF(Points[I].X, Points[I].Y);
  TextOnPath(Text, Values, Options);
end;

procedure TSkiaCanvas.TextOnPath(const Text: string; const Points: array of TPointF; const Options: TSkiaTextPathOptions);
var
  Builder: ISkPathBuilder;
  I: Integer;
begin
  Builder := TSkPathBuilder.Create;
  for I := 0 to High(Points) do
  begin
    if IsNan(Points[I].X) or IsInfinite(Points[I].X) or IsNan(Points[I].Y) or IsInfinite(Points[I].Y) then
      raise ESkiaCanvasError.Create('TextOnPath requires finite points');
    if I = 0 then
      Builder.MoveTo(Points[I].X, Points[I].Y)
    else
      Builder.LineTo(Points[I].X, Points[I].Y);
  end;
  TextOnPath(Text, Builder.Detach, Options);
end;

procedure TSkiaCanvas.TextOnPath(const Text: string; const Path: ISkPath; const Options: TSkiaTextPathOptions);
var
  Measure: ISkPathMeasure;
  Font: ISkFont;
  Provider: ISkTypefaceFontProvider;
  Style: ISkParagraphStyle;
  Builder: ISkParagraphBuilder;
  Paragraph: ISkParagraph;
  Layout: TSkiaPathTextLayout;
  Paint: ISkPaint;
  Glyph: TSkiaPathGlyph;
  LengthPx, Start, D, Center, SX, SY, Baseline: Single;
  Position, Tangent: TPointF;
begin
  if IsNan(Options.Offset) or IsInfinite(Options.Offset) or IsNan(Options.Distance) or IsInfinite(Options.Distance) or IsNan(Options.LetterSpacing) or IsInfinite(Options.LetterSpacing) then
    raise ESkiaCanvasError.Create('TextOnPath requires finite offsets');
  if (Text = '') or (Path = nil) then
    Exit;
  if not Path.IsFinite then
    raise ESkiaCanvasError.Create('TextOnPath requires a finite path');
  if (Pos(#10, Text) > 0) or (Pos(#13, Text) > 0) or (Pos(#$2028, Text) > 0) or (Pos(#$2029, Text) > 0) then
    raise ESkiaCanvasError.Create('TextOnPath accepts a single line');
  Measure := TSkPathMeasure.Create(Path, False, 4);
  LengthPx := Measure.Length;
  if (LengthPx <= 0) or IsNan(LengthPx) or IsInfinite(LengthPx) then
    Exit;
  if not BeginOperation(0) then
    Exit;
  Layout := TSkiaPathTextLayout.Create;
  try
    Font := AcquireFont;
    Provider := TSkTypefaceFontProvider.Create;
    Provider.RegisterTypeface(Font.Typeface, 'CanvasPathFont');
    Style := TSkParagraphStyle.Create;
    Style.TextStyle.FontFamilies := TArray<string>.Create('CanvasPathFont');
    Style.TextStyle.FontSize := Font.Size;
    Style.TextStyle.LetterSpacing := Options.LetterSpacing;
    if FShapingRTL then
      Style.TextDirection := TSkTextDirection.RightToLeft;
    Builder := TSkParagraphBuilder.Create(Style, Provider);
    Builder.AddText(Text);
    Paragraph := Builder.Build;
    Paragraph.Layout(1.0E8);
    Paragraph.Visit(
      procedure(const Line: Integer; const Info: TSkParagraphVisitorInfo)
      begin
        Layout.Visit(Line, Info);
      end);
    Baseline := Paragraph.AlphabeticBaseline;
    Start := Options.Offset;
    case Options.Alignment of
      tpaCenter:
        Start := Start + (LengthPx - Paragraph.MaxIntrinsicWidth) / 2;
      tpaEnd:
        Start := Start + LengthPx - Paragraph.MaxIntrinsicWidth;
    end;
    Paint := TSkPaint.Create;
    Paint.AntiAlias := True;
    Paint.Color := ColorToAlphaColor(FFont.Color, FFont.Alpha);
    SX := 1;
    SY := 1;
    if Options.MirrorHorizontal then
      SX := -1;
    if Options.MirrorVertical then
      SY := -1;
    for Glyph in Layout.Glyphs do
    begin
      Center := Glyph.Advance / 2;
      if Options.MirrorHorizontal then
        D := Start + Paragraph.MaxIntrinsicWidth - Glyph.X - Center
      else
        D := Start + Glyph.X + Center;
      if Options.Wrap and Measure.IsClosed then
        D := D - Floor(D / LengthPx) * LengthPx
      else if (D < 0) or (D > LengthPx) then
        Continue;
      if Options.Reverse then
        D := LengthPx - D;
      if (Glyph.Path = nil) or not Measure.GetPositionAndTangent(D, Position, Tangent) then
        Continue;
      if Options.Reverse then
      begin
        Tangent.X := -Tangent.X;
        Tangent.Y := -Tangent.Y;
      end;
      FCanvas.Save;
      try
        FCanvas.Translate(Position.X + Tangent.Y * Options.Distance, Position.Y - Tangent.X * Options.Distance);
        if Options.Orientation = tpoTangent then
          FCanvas.Rotate(ArcTan2(Tangent.Y, Tangent.X) * 180 / Pi);
        FCanvas.Scale(SX, SY);
        FCanvas.Translate(-Center, Glyph.Y - Baseline);
        FCanvas.DrawPath(Glyph.Path, Paint);
      finally
        FCanvas.Restore;
      end;
    end;
  finally
    Layout.Free;
    EndOperation;
  end;
end;
