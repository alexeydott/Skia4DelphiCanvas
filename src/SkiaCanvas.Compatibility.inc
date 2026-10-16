{ Shared operation recorder and CPU truth-table compositor. Raster fallbacks
  are emitted as image patches, so PDF/SVG need no destination-read support. }
type
  TCanvasSynchronization = class(TInterfacedObject, ICanvasSynchronization)
  private
    FLock: SyncObjs.TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enter;
    procedure Leave;
    function TryEnter: Boolean;
  end;

var
  GCompatCanvases: TList<TSkiaCanvas>;
  GCompatCanvasesLock: SyncObjs.TCriticalSection;

constructor TCanvasSynchronization.Create;
begin
  inherited;
  FLock := SyncObjs.TCriticalSection.Create;
end;

destructor TCanvasSynchronization.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TCanvasSynchronization.Enter;
begin
  FLock.Enter;
end;

procedure TCanvasSynchronization.Leave;
begin
  FLock.Leave;
end;

function TCanvasSynchronization.TryEnter: Boolean;
begin
  Result := FLock.TryEnter;
end;

function CompatImage(const Pixels: TArray<TAlphaColor>; W, H: Integer): ISkImage;
begin
  Result := TSkImage.MakeRasterCopy(

    TSkImageInfo.Create(W, H, TSkColorType.BGRA8888, TSkAlphaType.Unpremul), Pointer(Pixels), W * SizeOf(TAlphaColor));
end;

function CompatReadImage(const Image: ISkImage): TArray<TAlphaColor>;

begin
  Result := nil;
  if Image = nil then
    Exit;
  SetLength(Result, Image.Width * Image.Height);

  if not Image.ReadPixels(TSkImageInfo.Create(Image.Width, Image.Height, TSkColorType.BGRA8888, TSkAlphaType.Unpremul), Pointer(Result), Image.Width * 4) then
    raise ESkiaCanvasError.Create(SSkiaImagePixelsUnavailable);

end;

function CompatRop(Table: Byte; P, S, D: Cardinal): Cardinal;
var
  I: Integer;
  Term: Cardinal;
begin
  Result := 0;
  for I := 0 to 7 do
    if (Table and (1 shl I)) <> 0 then
    begin
      if (I and 4) <> 0 then
        Term := P
      else
        Term := not P;
      if (I and 2) <> 0 then
        Term := Term and S
      else
        Term := Term and not S;
      if (I and 1) <> 0 then
        Term := Term and D
      else
        Term := Term and not D;
      Result := Result or Term;
    end;
  Result := Result and $FFFFFF;
end;

function CompatSourceBounds(const Image: ISkImage; WidthSign, HeightSign: Integer): TRectF;
begin
  Result := RectF(0, 0, Image.Width, Image.Height);
  if WidthSign < 0 then
  begin
    Result.Left := Image.Width;
    Result.Right := 0;
  end;
  if HeightSign < 0 then
  begin
    Result.Top := Image.Height;
    Result.Bottom := 0;
  end;
end;

constructor TSkiaCanvas.Create(ASurface: ISkSurface);
var
  Canvas: ISkCanvas;
begin
  if ASurface = nil then
    raise ESkiaCanvasError.Create(SSkiaNilSurface);
  { Serialize the binding's lazy canvas reference initialization. }
  GCompatCanvasesLock.Enter;
  try
    Canvas := ASurface.GetCanvas;
  finally
    GCompatCanvasesLock.Leave;
  end;
  FBacking := ASurface;
  FBackingIsOutput := True;
  Create(Canvas, False);
end;

function TSkiaCanvas.SourceRectangle(Src: TSkiaCanvas; const Bounds: TRectF): ISkImage;
var
  Image: ISkImage;
  Surface: ISkSurface;
  Inverse: TMatrix;
  Det: Single;
  L, T: Single;
  W, H: Integer;
begin
  Result := nil;
  if Src = nil then
    Exit;
  W := Ceil(Abs(Bounds.Width));
  H := Ceil(Abs(Bounds.Height));
  if (W = 0) or (H = 0) then
    Exit;
  Det := Src.FMatrix.M11 * Src.FMatrix.M22 - Src.FMatrix.M12 * Src.FMatrix.M21;
  if Abs(Det) < 1E-12 then
    Exit;
  L := Math.Min(Bounds.Left, Bounds.Right);
  T := Math.Min(Bounds.Top, Bounds.Bottom);
  Inverse := TMatrix.Identity;
  Inverse.M11 := Src.FMatrix.M22 / Det;
  Inverse.M12 := -Src.FMatrix.M12 / Det;
  Inverse.M21 := -Src.FMatrix.M21 / Det;
  Inverse.M22 := Src.FMatrix.M11 / Det;
  Inverse.M31 := (Src.FMatrix.M32 * Src.FMatrix.M21 - Src.FMatrix.M31 * Src.FMatrix.M22) / Det - L;
  Inverse.M32 := (Src.FMatrix.M31 * Src.FMatrix.M12 - Src.FMatrix.M32 * Src.FMatrix.M11) / Det - T;
  Surface := TSkSurface.MakeRaster(W, H);
  Surface.GetCanvas.SetMatrix(Inverse);
  Image := GetSrcImage(Src);
  Surface.GetCanvas.DrawImage(Image, 0, 0);
  Result := Surface.MakeImageSnapshot;
end;

procedure TSkiaCanvas.InitializeCompatibility;
var
  R: TRect;
  C: TSkiaCanvas;
  Image: ISkImage;
begin
  GCompatCanvasesLock.Enter;
  try
    { Stable native handles are independent of temporary operation recorders. }
    for C in GCompatCanvases do
      if C.FNativeCanvasHandle = FNativeCanvasHandle then
      begin
        FCanvasSynchronization := C.FCanvasSynchronization;
        FDeviceWidth := C.FDeviceWidth;
        FDeviceHeight := C.FDeviceHeight;
        if FBacking = nil then
        begin
          FBacking := C.FBacking;
          FBackingIsOutput := C.FBackingIsOutput;
        end;
        Break;
      end;
    if FCanvasSynchronization = nil then
      FCanvasSynchronization := TCanvasSynchronization.Create;
    if (FBacking <> nil) and (FDeviceWidth = 0) then
    begin
      { Only a first wrapper needs a snapshot; existing wrappers supply immutable dimensions. }
      Image := FBacking.MakeImageSnapshot;
      FDeviceWidth := Image.Width;
      FDeviceHeight := Image.Height;
    end;
    if Self is TSkiaBitmapCanvas then
    begin
      FDeviceWidth := TSkiaBitmapCanvas(Self).FWidth;
      FDeviceHeight := TSkiaBitmapCanvas(Self).FHeight;
      FBacking := TSkiaBitmapCanvas(Self).FSurface;
      FBackingIsOutput := True;
    end;
    if FBacking = nil then
    begin
      if Self is TSkiaMetafileCanvas then
      begin
        FDeviceWidth := Ceil(TSkiaMetafileCanvas(Self).FWidth);
        FDeviceHeight := Ceil(TSkiaMetafileCanvas(Self).FHeight);
      end
      else
      begin
        FCanvasSynchronization.Enter;
        try
          R := FCanvas.GetDeviceClipBounds;
        finally
          FCanvasSynchronization.Leave;
        end;
        FDeviceWidth := Math.Max(1, R.Right);
        FDeviceHeight := Math.Max(1, R.Bottom);
      end;
      FBacking := TSkSurface.MakeRaster(FDeviceWidth, FDeviceHeight);
    end;
    GCompatCanvases.Add(Self);
  finally
    GCompatCanvasesLock.Leave;
  end;
end;

procedure TSkiaCanvas.UnregisterCompatibility;
begin
  GCompatCanvasesLock.Enter;
  try
    GCompatCanvases.Remove(Self);
    FNativeCanvasHandle := 0;
  finally
    GCompatCanvasesLock.Leave;
  end;
end;

procedure TSkiaCanvas.AppendClip(const Path: ISkPath; Op: TSkClipOp);
var
  N: Integer;
begin
  N := Length(FClips);
  SetLength(FClips, N + 1);
  FClips[N].Path := Path;
  FClips[N].Op := Op;
  FClipDepth := N + 1;
end;

procedure TSkiaCanvas.ApplyClips(const Target: ISkCanvas);
var
  Entry: TSkiaClipEntry;
begin
  Target.ResetMatrix;
  for Entry in FClips do
    Target.ClipPath(Entry.Path, Entry.Op, False);
  Target.SetMatrix(FMatrix);
end;

function TSkiaCanvas.BeginOperation(Kind: Integer): Boolean;
begin
  Result := not FRecordingClosed;
  if not Result then
    Exit;
  Inc(FOperationDepth);
  if FOperationDepth <> 1 then
    Exit;
  FOperationKind := Kind;
  FOutputCanvas := FCanvas;
  FOperationRecorder := TSkPictureRecorder.Create;
  try
    FCanvas := FOperationRecorder.BeginRecording(FDeviceWidth, FDeviceHeight);
    ApplyClips(FCanvas);
  except
    FCanvas := FOutputCanvas;
    FOutputCanvas := nil;
    FOperationRecorder := nil;
    Dec(FOperationDepth);
    raise;
  end;
end;

function TSkiaCanvas.ReadDevicePixels(out W, H: Integer): TArray<TAlphaColor>;
begin
  W := FDeviceWidth;
  H := FDeviceHeight;
  Result := CompatReadImage(FBacking.MakeImageSnapshot);
end;

function TSkiaCanvas.ClipPixels: TArray<TAlphaColor>;
var
  Surface: ISkSurface;
  Paint: ISkPaint;
  Entry: TSkiaClipEntry;
begin
  Surface := TSkSurface.MakeRaster(FDeviceWidth, FDeviceHeight);
  for Entry in FClips do
    Surface.GetCanvas.ClipPath(Entry.Path, Entry.Op, False);
  Paint := TSkPaint.Create;
  Paint.Color := $FFFFFFFF;
  Paint.AntiAlias := False;
  Surface.GetCanvas.DrawRect(RectF(0, 0, FDeviceWidth, FDeviceHeight), Paint);
  Result := CompatReadImage(Surface.MakeImageSnapshot);
end;

procedure TSkiaCanvas.CommitPatch(const Pixels: TArray<TAlphaColor>; W, H: Integer);
var
  Image: ISkImage;
  Cropped: TArray<TAlphaColor>;
  X, Y, L, T, R, B, CW: Integer;
begin
  L := W;
  T := H;
  R := -1;
  B := -1;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
      if Pixels[Y * W + X] shr 24 <> 0 then
      begin
        L := Math.Min(L, X);
        R := Math.Max(R, X);
        T := Math.Min(T, Y);
        B := Math.Max(B, Y);
      end;
  if R < L then
    Exit;
  CW := R - L + 1;
  SetLength(Cropped, CW * (B - T + 1));
  for Y := T to B do
    Move(Pixels[Y * W + L], Cropped[(Y - T) * CW], CW * SizeOf(TAlphaColor));
  Image := CompatImage(Cropped, CW, B - T + 1);
  FCanvas.Save;
  try
    FCanvas.ResetMatrix;
    FCanvas.DrawImage(Image, L, T);
  finally
    FCanvas.Restore;
  end;
  if (FOperationDepth = 0) and not FBackingIsOutput then
    FBacking.GetCanvas.DrawImage(Image, L, T);
end;

procedure TSkiaCanvas.EndOperation;
const
  Tables: array [TPenMode] of Byte = (0, 15, 10, 5, 12, 3, 13, 4, 11, 2, 14, 1, 8, 7, 6, 9);
var
  Picture: ISkPicture;
  Source, Pattern: ISkSurface;
  Src, Dst, Pat, Patch: TArray<TAlphaColor>;
  W, H, I: Integer;
  Table: Byte;
  Rasterize: Boolean;
  Entry: TSkiaClipEntry;
  Paint: ISkPaint;
  A, B, C, D: TPoint;
  Bounds: TRectF;
begin
  Dec(FOperationDepth);
  if FOperationDepth <> 0 then
    Exit;
  try
    Picture := FOperationRecorder.FinishRecording;
  finally
    FCanvas := FOutputCanvas;
    FOutputCanvas := nil;
    FOperationRecorder := nil;
  end;
  Table := $CC;
  if FOperationKind = 1 then
    Table := Tables[FPen.Mode] or (Tables[FPen.Mode] shl 4);
  if FOperationKind = 2 then
    Table := Byte(Cardinal(FCopyMode) shr 16);
  if FOperationKind = 3 then
    Table := $55;
  Rasterize := (Table <> $CC) or (FOperationKind = 4);
  for Entry in FClips do
    if Entry.Op = TSkClipOp.Difference then
      Rasterize := True;
  if Table = $AA then
    Exit;
  if not Rasterize then
  begin
    FCanvas.Save;
    try
      FCanvas.ResetMatrix;
      Picture.Playback(FCanvas);
    finally
      FCanvas.Restore;
    end;
    if not FBackingIsOutput then
    begin
      FBacking.GetCanvas.Save;
      try
        Picture.Playback(FBacking.GetCanvas);
      finally
        FBacking.GetCanvas.Restore;
      end;
    end;
    Exit;
  end;
  Source := TSkSurface.MakeRaster(FDeviceWidth, FDeviceHeight);
  Picture.Playback(Source.GetCanvas);
  Src := CompatReadImage(Source.MakeImageSnapshot);
  if (Table = $CC) and (FOperationKind <> 4) then
  begin
    CommitPatch(Src, FDeviceWidth, FDeviceHeight);
    Exit;
  end;
  Dst := ReadDevicePixels(W, H);
  Pattern := TSkSurface.MakeRaster(W, H);
  Pattern.GetCanvas.SetMatrix(FMatrix);
  A := DPToLP(Point(0, 0));
  B := DPToLP(Point(W, 0));
  C := DPToLP(Point(0, H));
  D := DPToLP(Point(W, H));
  Bounds := RectF(Math.Min(Math.Min(A.X, B.X), Math.Min(C.X, D.X)) - 2, Math.Min(Math.Min(A.Y, B.Y), Math.Min(C.Y, D.Y)) - 2, Math.Max(Math.Max(A.X, B.X), Math.Max(C.X, D.X)) + 2,
    Math.Max(Math.Max(A.Y, B.Y), Math.Max(C.Y, D.Y)) + 2);
  Paint := FResources.AcquireFillPaint(FBrush, Bounds);
  if Paint <> nil then
    Pattern.GetCanvas.DrawRect(Bounds, Paint);
  Pat := CompatReadImage(Pattern.MakeImageSnapshot);
  if FOperationKind = 4 then
  begin
    for I := 0 to High(Src) do
      if (Src[I] and $FFFFFF) = FOperationKey then
        Src[I] := (Pat[I] and $FFFFFF) or (Cardinal(((Src[I] shr 24) * (Pat[I] shr 24) + 127) div 255) shl 24);
    CommitPatch(Src, W, H);
    Exit;
  end;
  SetLength(Patch, W * H);
  for I := 0 to High(Patch) do
    if Src[I] shr 24 <> 0 then
      Patch[I] := (Src[I] and $FF000000) or CompatRop(Table, Pat[I], Src[I], Dst[I]);
  CommitPatch(Patch, W, H);
end;

procedure TSkiaCanvas.TransferImage(const Image: ISkImage; const Source, Dest: TRectF);
var
  S, D: TRectF;
  Flip, M: TMatrix;
begin
  if (Image = nil) or (Source.Width = 0) or (Source.Height = 0) or (Dest.Width = 0) or (Dest.Height = 0) then
    Exit;
  S := RectF(Math.Min(Source.Left, Source.Right), Math.Min(Source.Top, Source.Bottom), Math.Max(Source.Left, Source.Right), Math.Max(Source.Top, Source.Bottom));
  D := RectF(Math.Min(Dest.Left, Dest.Right), Math.Min(Dest.Top, Dest.Bottom), Math.Max(Dest.Left, Dest.Right), Math.Max(Dest.Top, Dest.Bottom));
  Flip := TMatrix.Identity;
  if (Source.Width < 0) <> (Dest.Width < 0) then
  begin
    Flip.M11 := -1;
    Flip.M31 := D.Left + D.Right;
  end;
  if (Source.Height < 0) <> (Dest.Height < 0) then
  begin
    Flip.M22 := -1;
    Flip.M32 := D.Top + D.Bottom;
  end;
  M := Flip * FMatrix;
  FCanvas.Save;
  try
    FCanvas.SetMatrix(M);
    FCanvas.DrawImageRect(Image, S, D);
  finally
    FCanvas.Restore;
  end;
end;

function TSkiaCanvas.GraphicImage(Graphic: TGraphic): ISkImage;

var
  Black, White: TBitmap;
  Pixels: TArray<TAlphaColor>;
  X, Y, A, Width, Height: Integer;
  B, W: Cardinal;
  RB, RW: PCardinal; {$IFDEF FPC}BlackPixels, WhitePixels: TArray<TAlphaColor>; {$ENDIF}
begin
  Result := nil;
  if Graphic = nil then
    Exit;
  if Graphic is TBitmap then
    Exit(BitmapToSkImage(TBitmap(Graphic)));

  Width := Graphic.Width;
  Height := Graphic.Height;
  if (Width <= 0) or (Height <= 0) then
    Exit;
  Black := TBitmap.Create;
  White := TBitmap.Create;
  try
    Black.PixelFormat := pf32bit;
    Black.SetSize(Width, Height);
    White.PixelFormat := pf32bit;
    White.SetSize(Width, Height);
    Black.Canvas.Brush.Color := clBlack;
    Black.Canvas.FillRect(Rect(0, 0, Width, Height));
    White.Canvas.Brush.Color := clWhite;
    White.Canvas.FillRect(Rect(0, 0, Width, Height));
    Black.Canvas.StretchDraw(Rect(0, 0, Width, Height), Graphic);
    White.Canvas.StretchDraw(Rect(0, 0, Width, Height), Graphic);
    SetLength(Pixels, Width * Height);
{$IFDEF FPC}
    Black.Masked := False;
    White.Masked := False;
    BlackPixels := CompatReadImage(BitmapToSkImage(Black));
    WhitePixels := CompatReadImage(BitmapToSkImage(White));
{$ENDIF}
    for Y := 0 to Height - 1 do
    begin
{$IFDEF FPC}RB := @BlackPixels[Y * Width];
      RW := @WhitePixels[Y * Width];
{$ELSE}RB := Black.ScanLine[Y];
      RW := White.ScanLine[Y]; {$ENDIF}
      for X := 0 to Width - 1 do
      begin
        B := RB[X] and $FFFFFF;
        W := RW[X] and $FFFFFF;
        A := 255 - Math.Max(Math.Max(Integer(W and 255) - Integer(B and 255), Integer((W shr 8) and 255) - Integer((B shr 8) and 255)), Integer((W shr 16) and 255) - Integer((B shr 16) and 255));
        if A > 0 then
          Pixels[Y * Width + X] := (Cardinal(A) shl 24) or (Cardinal(Math.Min(255, Integer(B and 255) * 255 div A))) or (Cardinal(Math.Min(255, Integer((B shr 8) and 255) * 255 div A)) shl 8) or
            (Cardinal(Math.Min(255, Integer((B shr 16) and 255) * 255 div A)) shl 16);
      end;
    end;
    Result := CompatImage(Pixels, Width, Height);
  finally
    White.Free;
    Black.Free;
  end;

end;

procedure TSkiaCanvas.PlainTextPaths(const Text: string; X, Baseline: Single; const Font: ISkFont; const Paint: ISkPaint);

var
  Glyphs: TArray<Word>;
  Widths: TArray<Single>;
  Path: ISkPath;
  I: Integer;
  Surface: ISkSurface;
  Metrics: TSkFontMetrics;
  Margin: Integer;

begin

  Glyphs := Font.GetGlyphs(Text);
  Widths := Font.GetWidths(Glyphs);
  for I := 0 to High(Glyphs) do
  begin
    Path := Font.GetPath(Glyphs[I]);
    if Path <> nil then
    begin
      FCanvas.Save;
      try
        FCanvas.Translate(X, Baseline);
        FCanvas.DrawPath(Path, Paint);
      finally
        FCanvas.Restore;
      end;
    end
    else
    begin
      { Bitmap/color glyphs have no outline: preserve their pixels in vector outputs. }
      Font.GetMetrics(Metrics);
      Margin := Ceil(Font.Size * 2);
      Surface := TSkSurface.MakeRaster(Math.Max(1, Ceil(Widths[I]) + Margin * 2), Math.Max(1, Ceil(Metrics.Descent - Metrics.Ascent) + Margin * 2));
      Surface.GetCanvas.DrawGlyphs(TArray<Word>.Create(Glyphs[I]), TArray<TPointF>.Create(PointF(0, 0)), PointF(Margin, Margin - Metrics.Ascent), Font, Paint);
      FCanvas.DrawImage(Surface.MakeImageSnapshot, X - Margin, Baseline + Metrics.Ascent - Margin);
    end;
    X := X + Widths[I];
  end;

end;
{$IFDEF MSWINDOWS}

procedure TSkiaCanvas.LayoutText(var Rect: TRect; var Text: string; TextFormat: TTextFormat);

var
  Bitmap: TBitmap;
  Original, Work: TRect;
  FontInfo: TLogFontW;
  DC: HDC;
  Saved, N, I: Integer;
  Points: TArray<TPoint>;
  Kinds: TArray<Byte>;
  Path: ISkiaPathBuilder;
  Paint: ISkPaint;
  Flags: TTextFormat;
  Pattern: ISkSurface;
  Pixels, Coverage: TArray<TAlphaColor>;
  XForm: TXForm;
  Prefix: Boolean;
  function RenderCoverage(const Value: string; Format: TTextFormat; OpaqueBackground: Boolean): TArray<TAlphaColor>;
  var
    Mask: TBitmap;
    DC: HDC;
    Saved, I, J: Integer;
    Row: PCardinal;
    R: TRect;
    S: string;
  begin
    Mask := TBitmap.Create;
    try
      Mask.PixelFormat := pf32bit;
      Mask.SetSize(FDeviceWidth, FDeviceHeight);
      Mask.Canvas.Brush.Color := clBlack;
      Mask.Canvas.FillRect(Types.Rect(0, 0, Mask.Width, Mask.Height));
      Mask.Canvas.Font.Assign(Bitmap.Canvas.Font);
      Mask.Canvas.Font.Color := clWhite;
      Mask.Canvas.Brush.Color := clWhite;
      if OpaqueBackground then
        Mask.Canvas.Brush.Style := bsSolid
      else
        Mask.Canvas.Brush.Style := bsClear;
      DC := Mask.Canvas.Handle;
      Saved := SaveDC(DC);
      try
        SelectObject(DC, Mask.Canvas.Font.Handle);
        SetTextColor(DC, $FFFFFF);
        SetBkColor(DC, $FFFFFF);
        if OpaqueBackground then
          SetBkMode(DC, OPAQUE)
        else
          SetBkMode(DC, TRANSPARENT);
        SetGraphicsMode(DC, GM_ADVANCED);
        XForm.eM11 := FMatrix.M11;
        XForm.eM12 := FMatrix.M12;
        XForm.eM21 := FMatrix.M21;
        XForm.eM22 := FMatrix.M22;
        XForm.eDx := FMatrix.M31;
        XForm.eDy := FMatrix.M32;
{$IFDEF FPC}Windows.SetWorldTransform(DC, XForm); {$ELSE}Winapi.Windows.SetWorldTransform(DC, XForm); {$ENDIF}
        R := Original;
        S := Value; {$IFDEF FPC}DrawTextLayout(DC, R, S, Format - [tfComposited, tfModifyString]); {$ELSE}Mask.Canvas.TextRect(R, S, Format - [tfComposited, tfModifyString]); {$ENDIF}
      finally
        RestoreDC(DC, Saved);
      end;
      SetLength(Result, FDeviceWidth * FDeviceHeight);
      for J := 0 to Mask.Height - 1 do
      begin
        Row := Mask.ScanLine[J];
        for I := 0 to Mask.Width - 1 do
          Result[J * Mask.Width + I] := Math.Max(Math.Max(Row[I] and 255, (Row[I] shr 8) and 255), (Row[I] shr 16) and 255);
      end;
    finally
      Mask.Free;
    end;
  end;

begin
  if Text = '' then
    Exit;
  if NeedsSkiaShaper then
  begin
    LayoutPortableText(Rect, Text, TextFormat);
    Exit;
  end;
  Original := Rect;
  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Math.Max(1, Abs(Rect.Width)), Math.Max(1, Abs(Rect.Height)));
    Bitmap.Canvas.Font.Assign(FFont);
    if FResources.FontManager.GetLogFont(FFont, FontInfo) then
      Bitmap.Canvas.Font.Name := string(FontInfo.lfFaceName);
    Bitmap.Canvas.Brush.Style := bsClear;
    DC := Bitmap.Canvas.Handle;
    Saved := SaveDC(DC);
    try
      SelectObject(DC, Bitmap.Canvas.Font.Handle);
      SetBkMode(DC, TRANSPARENT);
      Work.Left := 0;
      Work.Top := 0;
      Work.Right := Rect.Width;
      Work.Bottom := Rect.Height;
      Flags := TextFormat - [tfComposited];
      if not BeginPath(DC) then
        raise ESkiaCanvasError.Create(SSkiaBeginTextOutlineFailed);
{$IFDEF FPC}DrawTextLayout(DC, Work, Text, Flags); {$ELSE}Bitmap.Canvas.TextRect(Work, Text, Flags); {$ENDIF} EndPath(DC);
      if tfCalcRect in TextFormat then
      begin
        Rect.Left := Original.Left + Work.Left;
        Rect.Top := Original.Top + Work.Top;
        Rect.Right := Original.Left + Work.Right;
        Rect.Bottom := Original.Top + Work.Bottom;
        Exit;
      end;
      N := GetPath(DC, nil, nil, 0);
      if N < 0 then
        raise ESkiaCanvasError.Create(SSkiaReadNativeTextPathFailed);
      SetLength(Points, N);
      SetLength(Kinds, N);
      if GetPath(DC, Pointer(Points), Pointer(Kinds), N) <> N then
        raise ESkiaCanvasError.Create(SSkiaReadTextOutlineFailed);
      Path := TSkiaPathBuilder.Create;
      I := 0;
      while I < N do
      begin
        case Kinds[I] and not PT_CLOSEFIGURE of
          PT_MOVETO:
            Path.MoveTo(Points[I].X + Original.Left, Points[I].Y + Original.Top);
          PT_LINETO:
            Path.LineTo(Points[I].X + Original.Left, Points[I].Y + Original.Top);
          PT_BEZIERTO:
            begin
              if I + 2 >= N then
                raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
              Path.CubicTo(Points[I].X + Original.Left, Points[I].Y + Original.Top, Points[I + 1].X + Original.Left, Points[I + 1].Y + Original.Top, Points[I + 2].X + Original.Left,
                Points[I + 2].Y + Original.Top);
              Inc(I, 2);
            end;
        end;
        if Kinds[I] and PT_CLOSEFIGURE <> 0 then
          Path.Close;
        Inc(I);
      end;
    finally
      RestoreDC(DC, Saved);
    end;
    FCanvas.Save;
    try
      if not(tfNoClip in TextFormat) then
        FCanvas.ClipRect(RectToRectF(Original));
      if FBrush.Style <> bsClear then
      begin
        Coverage := RenderCoverage(Text, Flags, True);
        Pattern := TSkSurface.MakeRaster(FDeviceWidth, FDeviceHeight);
        Pattern.GetCanvas.SetMatrix(FMatrix);
        Paint := AcquireFillPaint(RectToRectF(Original));
        if Paint <> nil then
          Pattern.GetCanvas.DrawRect(RectF(-FDeviceWidth * 10, -FDeviceHeight * 10, FDeviceWidth * 10, FDeviceHeight * 10), Paint);
        Pixels := CompatReadImage(Pattern.MakeImageSnapshot);
        for I := 0 to High(Pixels) do
          Pixels[I] := (Pixels[I] and $FFFFFF) or (Cardinal(((Pixels[I] shr 24) * Coverage[I] + 127) div 255) shl 24);
        CommitPatch(Pixels, FDeviceWidth, FDeviceHeight);
      end;
      Paint := TSkPaint.Create;
      Paint.Color := ColorToAlphaColor(FFont.Color, FFont.Alpha);
      Paint.AntiAlias := True;
      FCanvas.DrawPath(Path.Snapshot, Paint);
      Prefix := (tfPrefixOnly in Flags) or ((Pos('&', Text) > 0) and not(tfNoPrefix in Flags) and not(tfHidePrefix in Flags));
      if Prefix then
      begin
        Coverage := RenderCoverage(Text, Flags + [tfPrefixOnly], False);
        SetLength(Pixels, Length(Coverage));
        for I := 0 to High(Pixels) do
          Pixels[I] := (ColorToAlphaColor(FFont.Color) and $FFFFFF) or (Cardinal((Coverage[I] * FFont.Alpha + 127) div 255) shl 24);
        CommitPatch(Pixels, FDeviceWidth, FDeviceHeight);
      end;
    finally
      FCanvas.Restore;
    end;
  finally
    Bitmap.Free;
  end;
end;

{$ELSE}

procedure TSkiaCanvas.LayoutText(var Rect: TRect; var Text: string; TextFormat: TTextFormat);
begin
  LayoutPortableText(Rect, Text, TextFormat);
end;
{$ENDIF}

procedure TSkiaCanvas.LayoutPortableText(var Rect: TRect; var Text: string; TextFormat: TTextFormat);
var
  Lines: TStringList;
  Source, Line, Word: string;
  I, J, X, Y, Height, Width, Maximum, TabSize, Cursor, Start, PrefixX, PrefixW: Integer;
  IsSingle, PreviousRTL, PreviousCurves: Boolean;
  Prefixes: TList<Integer>;
  PrefixPaint: ISkPaint;
  procedure AddLine(const Value: string);
  begin
    Lines.Add(Value);
  end;
  function FitEllipsis(const Value: string): string;
  var
    K: Integer;
    Tail: string;
  begin
    Result := Value;
    if TextWidth(Result) <= Rect.Width then
      Exit;
    Tail := '';
    if tfPathEllipsis in TextFormat then
    begin
      K := LastDelimiter('/\', Result);
      if K > 0 then
        Tail := Copy(Result, K, Length(Result));
    end;
    while (Length(Result) > 0) and (TextWidth(Result + '...' + Tail) > Rect.Width) do
      Delete(Result, Length(Result), 1);
    if tfWordEllipsis in TextFormat then
    begin
      K := LastDelimiter(' ', Result);
      if K > 0 then
        Result := Copy(Result, 1, K - 1);
    end;
    Result := Result + '...' + Tail;
  end;

begin
  if Text = '' then
    Exit;
  Lines := TStringList.Create;
  Prefixes := TList<Integer>.Create;
  PreviousRTL := FShapingRTL;
  PreviousCurves := FTextToCurves;
  FShapingRTL := tfRtlReading in TextFormat;
  FTextToCurves := True;
  try
    Source := StringReplace(Text, #13#10, #10, [rfReplaceAll]);
    Source := StringReplace(Source, #13, #10, [rfReplaceAll]);
    if not(tfNoPrefix in TextFormat) then
    begin
      I := 1;
      Line := '';
      while I <= Length(Source) do
      begin
        if Source[I] = '&' then
        begin
          Inc(I);
          if I > Length(Source) then
            Break;
          if Source[I] <> '&' then
            Prefixes.Add(Length(Line) + 1);
        end;
        Line := Line + Source[I];
        Inc(I);
      end;
      Source := Line;
    end;
    if tfExpandTabs in TextFormat then
    begin
      I := 1;
      Line := '';
      TabSize := 8;
      while I <= Length(Source) do
      begin
        if Source[I] = #9 then
        begin
          J := Length(Line);
          repeat
            Line := Line + ' ';
          until Length(Line) mod TabSize = 0;
          for X := 0 to Prefixes.Count - 1 do
            if Prefixes[X] > I then
              Prefixes[X] := Prefixes[X] + Length(Line) - J - 1;
        end
        else
          Line := Line + Source[I];
        Inc(I);
      end;
      Source := Line;
    end;
    IsSingle := tfSingleLine in TextFormat;
    if IsSingle then
      Source := StringReplace(Source, #10, ' ', [rfReplaceAll]);
    Line := '';
    Word := '';
    for I := 1 to Length(Source) + 1 do
    begin
      if (I > Length(Source)) or (Source[I] = #10) then
      begin
        Line := Line + Word;
        Word := '';
        AddLine(Line);
        Line := '';
        Continue;
      end;
      Word := Word + Source[I];
      if Source[I] = ' ' then
      begin
        if (tfWordBreak in TextFormat) and not IsSingle and (Line <> '') and (TextWidth(Line + Word) > Rect.Width) then
        begin
          AddLine(TrimRight(Line));
          Line := '';
        end;
        Line := Line + Word;
        Word := '';
      end
      else if (tfWordBreak in TextFormat) and not IsSingle and (TextWidth(Line + Word) > Rect.Width) then
      begin
        if Line <> '' then
        begin
          AddLine(TrimRight(Line));
          Line := '';
        end
        else if Length(Word) > 1 then
        begin
          AddLine(Copy(Word, 1, Length(Word) - 1));
          Word := Word[Length(Word)];
        end;
      end;
    end;
    Height := TextHeight('X');
    if tfExternalLeading in TextFormat then
      Inc(Height);
    Maximum := 0;
    for I := 0 to Lines.Count - 1 do
      Maximum := Math.Max(Maximum, TextWidth(Lines[I]));
    if tfCalcRect in TextFormat then
    begin
      Rect.Right := Rect.Left + Maximum;
      Rect.Bottom := Rect.Top + Height * Lines.Count;
      Exit;
    end;
    Cursor := 1;
    PrefixPaint := TSkPaint.Create;
    PrefixPaint.Color := ColorToAlphaColor(FFont.Color, FFont.Alpha);
    Y := Rect.Top;
    if IsSingle and (tfVerticalCenter in TextFormat) then
      Y := Rect.Top + (Rect.Height - Height) div 2;
    if IsSingle and (tfBottom in TextFormat) then
      Y := Rect.Bottom - Height;
    FCanvas.Save;
    try
      if not(tfNoClip in TextFormat) then
        FCanvas.ClipRect(RectToRectF(Rect));
      for I := 0 to Lines.Count - 1 do
      begin
        if (tfEditControl in TextFormat) and (Y + Height > Rect.Bottom) then
          Break;
        Line := Lines[I];
        Start := Pos(Line, Copy(Source, Cursor, Length(Source)));
        if Start = 0 then
          Start := Cursor
        else
          Start := Start + Cursor - 1;
        Cursor := Start + Length(Line);
        if (tfEndEllipsis in TextFormat) or (tfWordEllipsis in TextFormat) or (tfPathEllipsis in TextFormat) then
          Line := FitEllipsis(Line);
        if (tfModifyString in TextFormat) and (Lines.Count = 1) then
          Text := Line;
        Width := TextWidth(Line);
        X := Rect.Left;
        if tfCenter in TextFormat then
          X := Rect.Left + (Rect.Width - Width) div 2;
        if tfRight in TextFormat then
          X := Rect.Right - Width;
        if not(tfPrefixOnly in TextFormat) then
          TextOut(X, Y, Line);
        if not(tfHidePrefix in TextFormat) then
          for J in Prefixes do
            if (J >= Start) and (J < Start + Length(Line)) then
            begin
              PrefixX := X + TextWidth(Copy(Line, 1, J - Start));
              PrefixW := TextWidth(Copy(Line, J - Start + 1, 1));
              FCanvas.DrawRect(RectF(PrefixX, Y + Height - 2, PrefixX + PrefixW, Y + Height - 1), PrefixPaint);
            end;
        Inc(Y, Height);
      end;
    finally
      FCanvas.Restore;
    end;
  finally
    FShapingRTL := PreviousRTL;
    FTextToCurves := PreviousCurves;
    Prefixes.Free;
    Lines.Free;
  end;
end;

function TSkiaCanvas.NeedsSkiaShaper: Boolean;
begin
  { Registered private faces retain their exact Skia typeface identity. }
{$IFDEF MSWINDOWS}Result := FResources.FontManager.FindCustom(FFont.Name) <> nil; {$ELSE}Result := True; {$ENDIF}
end;

procedure TSkiaCanvas.BlobPaths(const Blob: ISkTextBlob; X, Y, Width, Size: Single; const Paint: ISkPaint);
var
  Stream: TMemoryStream;
  SVG: ISkCanvas;
  DOM: ISkSVGDOM;
  Margin: Single;
begin
  Stream := TMemoryStream.Create;
  Margin := Math.Max(4, Size * 4);
  try
    SVG := TSkSVGCanvas.Make(RectF(0, 0, Math.Max(1, Width) + Margin * 2, Margin * 4), Stream, [TSkSVGCanvasFlag.ConvertTextToPaths]);
    SVG.DrawTextBlob(Blob, Margin, Margin, Paint);
    SVG := nil;
    Stream.Position := 0;
    DOM := TSkSVGDOM.MakeFromStream(Stream);
    if DOM = nil then
      raise ESkiaCanvasError.Create(SSkiaTextToOutlinesFailed);
    DOM.Root.TrySetAttribute('overflow', 'visible');
    FCanvas.Save;
    try
      FCanvas.Translate(X - Margin, Y - Margin);
      DOM.Render(FCanvas);
    finally
      FCanvas.Restore;
    end;
  finally
    DOM := nil;
    SVG := nil;
    Stream.Free;
  end;
end;
