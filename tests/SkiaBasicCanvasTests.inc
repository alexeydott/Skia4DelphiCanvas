{ Portable canvas tests shared by Delphi/Windows and FPC/Linux. }
procedure T_BrushAssignFromProps;
var
  B, B2: TSkiaBrush;
begin
  B := TSkiaBrush.Create;
  B2 := TSkiaBrush.Create;
  try
    B.Color := clRed;
    B.Style := bsSolid;
    B.Alpha := 128;
    B2.Assign(B);
    Check(B2.Color = clRed, 'Brush.Assign: Color');
    Check(B2.Alpha = 128, 'Brush.Assign: Alpha');
    Check(B2.Style = bsSolid, 'Brush.Assign: Style');
  finally
    B.Free; B2.Free;
  end;
end;

procedure T_PenAssignFromProps;
var
  P, P2: TSkiaPen;
begin
  P := TSkiaPen.Create;
  P2 := TSkiaPen.Create;
  try
    P.Color := clBlue;
    P.Width := 3;
    P.Style := psDash;
    P.Alpha := 200;
    P.StrokeCap := TSkStrokeCap.Round;
    P.StrokeJoin := TSkStrokeJoin.Bevel;
    P.DashPattern := TArray<Single>.Create(5, 2);
    P2.Assign(P);
    Check(P2.Color = clBlue, 'Pen.Assign: Color');
    Check(P2.Width = 3, 'Pen.Assign: Width');
    Check(P2.Alpha = 200, 'Pen.Assign: Alpha');
    Check(P2.StrokeCap = TSkStrokeCap.Round, 'Pen.Assign: StrokeCap');
    Check(P2.StrokeJoin = TSkStrokeJoin.Bevel, 'Pen.Assign: StrokeJoin');
    Check(Length(P2.DashPattern) = 2, 'Pen.Assign: DashPattern копируется');
  finally
    P.Free; P2.Free;
  end;
end;

procedure T_BrushPatternFromBitmap;
var
  B: TSkiaBrush;
  Bmp: TBitmap;
begin
  B := TSkiaBrush.Create;
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(4, 4);
    B.Assign(Bmp);
    Check(B.Pattern <> nil, 'Brush.Assign(TBitmap): паттерн создан');
    Check(B.Pattern.Width = 4, 'Brush.Assign(TBitmap): размер паттерна');
  finally
    B.Free; Bmp.Free;
  end;
end;

procedure T_ResourceManagerCache;
var
  M: TSkiaResourceManager;
  B: TSkiaBrush;
  P1, P2: ISkPaint;
begin
  M := TSkiaResourceManager.Create;
  B := TSkiaBrush.Create;
  try
    B.Color := clGreen;
    B.Style := bsSolid;
    P1 := M.AcquireFillPaint(B, RectF(0, 0, 10, 10));
    P2 := M.AcquireFillPaint(B, RectF(0, 0, 10, 10));
    Check(P1 = P2, 'ResourceManager: кэш fill paint');
    Check(P1.Style = TSkPaintStyle.Fill, 'ResourceManager: style=Fill');
    Check(P1.Color = ColorToAlphaColor(clGreen), 'ResourceManager: цвет');
    B.Color := clRed;
    M.InvalidateBrush;
    P2 := M.AcquireFillPaint(B, RectF(0, 0, 10, 10));
    Check(P2.Color = ColorToAlphaColor(clRed), 'ResourceManager: инвалидация');
    B.Style := bsClear;
    Check(M.AcquireFillPaint(B, RectF(0, 0, 10, 10)) = nil,
      'ResourceManager: bsClear -> nil');
  finally
    B.Free; M.Free;
  end;
end;

procedure T_FontAlpha;
var
  F: TSkiaFont;
begin
  F := TSkiaFont.Create;
  try
    Check(F.Alpha = 255, 'Font: alpha по умолчанию 255');
    F.Alpha := 128;
    Check(F.Alpha = 128, 'Font: alpha устанавливается');
  finally
    F.Free;
  end;
end;

procedure T_FontManagerCache;
var
  M: TSkiaFontManager;
  F: TSkiaFont;
  T1, T2: ISkTypeface;
begin
  M := TSkiaFontManager.Create;
  F := TSkiaFont.Create;
  try
    F.Name := 'Arial';
    F.Height := -16;
    T1 := M.AcquireTypeface(F);
    T2 := M.AcquireTypeface(F);
    Check(T1 <> nil, 'FontManager: typeface создан');
    Check(T1 = T2, 'FontManager: кэш по LOGFONT');
    F.Height := -20;
    T2 := M.AcquireTypeface(F);
    Check(T2 <> T1, 'FontManager: другой LOGFONT — другой typeface');
  finally
    F.Free; M.Free;
  end;
end;

procedure T_FontManagerCustom;
var
  M: TSkiaFontManager;
  F: TSkiaFont;
  Custom, Got: ISkTypeface;
begin
  M := TSkiaFontManager.Create;
  F := TSkiaFont.Create;
  try
    F.Name := 'MyCustom';
    F.Height := -16;
    Custom := TSkTypeface.MakeFromName('Courier New', TSkFontStyle.Normal);
    M.RegisterTypeface('MyCustom', Custom);
    Got := M.AcquireTypeface(F);
    Check(Got = Custom, 'FontManager: кастомный typeface перекрывает системный');
    M.UnregisterTypeface('MyCustom');
    Got := M.AcquireTypeface(F);
    Check(Got <> Custom, 'FontManager: после unregister — системный');
    
    Check(Got.GetFamilyName <> '', 'FontManager: fallback family');
    
  finally
    F.Free; M.Free;
  end;
end;

procedure T_FontManagerInvalidatesResourceCache;
var
  RM: TSkiaResourceManager;
  F: TSkiaFont;
  Custom: ISkTypeface;
  Fnt1, Fnt2: ISkFont;
begin
  { Регистрация кастомного шрифта должна сбрасывать кэш ISkFont. }
  RM := TSkiaResourceManager.Create;
  F := TSkiaFont.Create;
  try
    F.Name := 'MyCustom';
    F.Height := -16;
    Fnt1 := RM.AcquireFont(F);
    Custom := TSkTypeface.MakeFromName('Courier New', TSkFontStyle.Normal);
    RM.FontManager.RegisterTypeface('MyCustom', Custom);
    Fnt2 := RM.AcquireFont(F);
    Check(Fnt1 <> Fnt2, 'FontManager: RegisterTypeface инвалидирует кэш шрифта');
    Check(Fnt2.GetTypeface.GetFamilyName = Custom.GetFamilyName, 'FontManager: новый шрифт с кастомным typeface');
  finally
    F.Free; RM.Free;
  end;
end;

procedure T_PenDashEffect;
var
  M: TSkiaResourceManager;
  P: TSkiaPen;
  Paint: ISkPaint;
begin
  M := TSkiaResourceManager.Create;
  P := TSkiaPen.Create;
  try
    P.Style := psDash;
    P.Width := 2;
    Paint := M.AcquireStrokePaint(P);
    Check(Paint <> nil, 'Stroke paint создан');
    Check(Paint.PathEffect <> nil, 'psDash -> PathEffect');
    
    P.Style := psSolid;
    M.InvalidatePen;
    Paint := M.AcquireStrokePaint(P);
    Check(Paint.PathEffect = nil, 'psSolid -> без PathEffect');
    P.Style := psClear;
    Check(M.AcquireStrokePaint(P) = nil, 'psClear -> nil');
  finally
    P.Free; M.Free;
  end;
end;

procedure T_FillRectPixel;
var
  C: TSkiaBitmapCanvas;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Color := clRed;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(2, 2, 10, 10));
    Check(C.Pixels[5, 5] = clRed, 'FillRect: пиксель внутри красный');
    Check(C.Pixels[0, 0] = clBlack, 'FillRect: пиксель снаружи чёрный');
    Check(C.Pixels[15, 15] = clBlack, 'FillRect: за пределами чёрный');
  finally
    C.Free;
  end;
end;

procedure T_StrokeRectPixel;
var
  C: TSkiaBitmapCanvas;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Style := bsClear;
    C.Pen.Color := clBlue;
    C.Pen.Width := 1;
    C.Pen.Style := psSolid;
    C.Rectangle(2, 2, 10, 10);
    Check(C.Pixels[2, 5] = clBlue, 'Rectangle: левая граница синяя');
    Check(C.Pixels[5, 5] = clBlack, 'Rectangle: внутри не закрашено (bsClear)');
  finally
    C.Free;
  end;
end;

procedure T_EllipsePixel;
var
  C: TSkiaBitmapCanvas;
begin
  C := TSkiaBitmapCanvas.Create(30, 30);
  try
    C.Brush.Color := clGreen;
    C.Brush.Style := bsSolid;
    C.Pen.Style := psClear;
    C.Ellipse(5, 5, 25, 25);
    Check(C.Pixels[15, 15] = clGreen, 'Ellipse: центр зелёный');
    Check(C.Pixels[0, 0] = clBlack, 'Ellipse: угол чёрный');
  finally
    C.Free;
  end;
end;

procedure T_GradientPixel;
var
  C: TSkiaBitmapCanvas;
  C1, C2: TColor;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Gradient := gkHorizontal;
    C.Brush.GradientStartColor := clBlack;
    C.Brush.GradientEndColor := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 20, 20));
    C1 := C.Pixels[0, 10];
    C2 := C.Pixels[19, 10];
    Check(C1 <> C2, 'Gradient: края различаются');
    
  finally
    C.Free;
  end;
end;

procedure T_HatchPixel;
var
  C: TSkiaBitmapCanvas;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Style := bsHorizontal;
    C.Brush.Color := clWhite;
    C.FillRect(Rect(0, 0, 16, 16));
    
    { Горизонтальная штриховка: строка 3 белая, строка 1 чёрная. }
    Check(C.Pixels[5, 3] = clWhite, 'Hatch: линия штриховки белая');
    Check(C.Pixels[5, 1] = clBlack, 'Hatch: между линиями чёрный');
  finally
    C.Free;
  end;
end;

procedure T_DrawImagePixel;
var
  C: TSkiaBitmapCanvas;
  Bmp: TBitmap;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(4, 4);
    Bmp.Canvas.Pixels[1, 1] := clRed; // красный
    C.Draw(5, 5, Bmp);
    Check(C.Pixels[6, 6] = clRed, 'Draw: пиксель битмапа скопирован');
    Check(C.Pixels[0, 0] = clBlack, 'Draw: вне битмапа чёрный');
  finally
    Bmp.Free; C.Free;
  end;
end;

procedure T_DrawWithOpacity;
var
  C: TSkiaBitmapCanvas;
  Bmp: TBitmap;
  Px: TColor;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(4, 4);
    Bmp.Canvas.Pixels[1, 1] := clRed; // красный
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 20, 20));
    C.Draw(5, 5, Bmp, 128); // 50% прозрачности
    Px := C.Pixels[6, 6];
    { Красный 50% поверх белого = розовый, не чисто красный и не белый. }
    Check((Px <> clRed) and (Px <> clWhite), 'Draw(Opacity): смешивание применено');
  finally
    Bmp.Free; C.Free;
  end;
end;

procedure T_FlushToBitmap;
var
  C: TSkiaBitmapCanvas;
  Bmp: TBitmap;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  Bmp := TBitmap.Create;
  try
    C.Brush.Color := clRed;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(5, 5, 15, 15));
    C.Flush(Bmp);
    Check(Bmp.Width = 20, 'Flush: ширина битмапа');
    Check(Bmp.Height = 20, 'Flush: высота битмапа');
    { GetTestPixel читает FBits напрямую (top-down индекс). }
    Check(Cardinal(Bmp.Canvas.Pixels[10, 10]) = Cardinal(clRed), 'Flush: пиксель внутри');
    Check(Cardinal(Bmp.Canvas.Pixels[0, 0]) = 0, 'Flush: пиксель снаружи');
  finally
    Bmp.Free;
    C.Free;
  end;
end;

procedure T_FloodFill;
var
  C: TSkiaBitmapCanvas;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 20, 20));
    C.Pen.Color := clBlack;
    C.Pen.Style := psSolid;
    C.Pen.Width := 1;
    C.Rectangle(2, 2, 10, 10);
    C.Brush.Color:=clRed;
    C.FloodFill(5, 5, clWhite, fsSurface);
    Check(C.Pixels[5, 5] = clRed, 'FloodFill: внутри залито красным');
    Check(C.Pixels[15, 15] = clWhite, 'FloodFill: снаружи белый');
  finally
    C.Free;
  end;
end;

procedure T_ClipRect;
var
  C: TSkiaBitmapCanvas;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Color := clRed;
    C.Brush.Style := bsSolid;
    C.SetClipRect(Rect(0, 0, 10, 10));
    C.FillRect(Rect(0, 0, 20, 20));
    Check(C.Pixels[5, 5] = clRed, 'ClipRect: внутри клипа закрашено');
    Check(C.Pixels[15, 15] = clBlack, 'ClipRect: вне клипа чёрный');
    
    C.ResetClip;
    C.FillRect(Rect(0, 0, 20, 20));
    Check(C.Pixels[15, 15] = clRed, 'ResetClip: клип сброшен');
  finally
    C.Free;
  end;
end;

procedure T_RotateTransform;
var
  C: TSkiaBitmapCanvas;
  P: TPoint;
begin
  C := TSkiaBitmapCanvas.Create(40, 40);
  try
    { Математика поворота. }
    C.RotateTransform(90);
    P := C.LPToDP(Point(10, 0));
    Check((P.X = 0) and (P.Y = 10), 'Rotate(90): LPToDP(10,0)=(0,10)');
    P := C.DPToLP(Point(0, 10));
    Check((P.X = 10) and (P.Y = 0), 'Rotate(90): DPToLP(0,10)=(10,0)');
    { Растеризация повёрнутого прямоугольника. }
    C.Brush.Color := clRed;
    C.Brush.Style := bsSolid;
    { Прямоугольник 10x20 в локальных координатах, повернётся на 90°. }
    C.FillRect(Rect(0, 0, 10, 20));
    { После поворота на 90° вокруг начала: локальный (0,0)-(10,20)
      занимает пиксели примерно x∈[−20,0], y∈[0,10]. Точка (-10,5) внутри. }
    Check(C.Pixels[5, 5] = clBlack, 'Rotate: исходная область не закрашена');
  finally
    C.Free;
  end;
end;

procedure T_RotateDrawRect;
var
  C: TSkiaBitmapCanvas;
begin
  { Рисуем прямоугольник, повёрнутый на 90° вокруг центра канваса.
    Порядок для Delphi-конвенции (row-vector): сначала сдвиг центра
    в начало координат, потом поворот, потом сдвиг обратно. }
  C := TSkiaBitmapCanvas.Create(40, 40);
  try
    C.Brush.Color := clRed;
    C.Brush.Style := bsSolid;
    C.TranslateTransform(-20, -20);
    C.RotateTransform(90);
    C.TranslateTransform(20, 20);
    { Горизонтальный прямоугольник 20x10 станет вертикальным 10x20. }
    C.FillRect(Rect(10, 15, 30, 25));
    { Центр (20,20) внутри; углы исходного прямоугольника снаружи. }
    Check(C.Pixels[20, 20] = clRed, 'Rotate DrawRect: центр закрашен');
    Check(C.Pixels[5,5]=clBlack, 'Rotate DrawRect: logical outside point remains clear');
  finally
    C.Free;
  end;
end;

procedure T_TranslateTransform;
var
  C: TSkiaBitmapCanvas;
begin
  C := TSkiaBitmapCanvas.Create(30, 30);
  try
    C.Brush.Color := clBlue;
    C.Brush.Style := bsSolid;
    C.TranslateTransform(10, 10);
    C.FillRect(Rect(0, 0, 5, 5));
    Check(C.Pixels[2,2]=clBlue, 'Translate: logical pixel maps to translated rectangle');
    Check(C.Pixels[12,12]=clBlack, 'Translate: logical outside point remains clear');
    Check(C.LPToDP(Point(0, 0)) = Point(10, 10), 'LPToDP: (0,0)->(10,10)');
    Check(C.DPToLP(Point(10, 10)) = Point(0, 0), 'DPToLP: (10,10)->(0,0)');
  finally
    C.Free;
  end;
end;

procedure T_SaveRestoreState;
var
  C: TSkiaBitmapCanvas;
  Idx: Integer;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Color := clRed;
    Idx := C.SaveState;
    Check(Idx = 1, 'SaveState: индекс 1');
    C.Brush.Color := clBlue;
    Check(C.Brush.Color = clBlue, 'SaveState: цвет изменён');
    C.RestoreState(Idx);
    Check(C.Brush.Color = clRed, 'RestoreState: цвет восстановлен');
  finally
    C.Free;
  end;
end;

procedure T_TextOutLog;
var
  C: TSkiaBitmapCanvas;
begin
  
  C := TSkiaBitmapCanvas.Create(40, 40);
  try
    C.Font.Name := 'Arial';
    C.Font.Color := clWhite;
    
    C.Font.Color := clWhite;
    C.Brush.Style := bsClear;
    
    C.TextOut(5, 5, 'Hi');
    
    
    Check(HasInk(C), 'T_TextOutLog: visible text');
  finally
    C.Free;
  end;
end;

procedure T_TextExtent;
var
  C: TSkiaBitmapCanvas;
  Sz: TSize;
begin
  C := TSkiaBitmapCanvas.Create(40, 40);
  try
    C.Font.Height := -20;
    Sz := C.TextExtent('AB');
    Check(Sz.cx > 0, 'TextExtent: ширина > 0');
    Check(Sz.cy > 0, 'TextExtent: высота > 0');
    Check(C.TextExtent('') = TSize.Create(0, 0), 'TextExtent: пустая строка');
  finally
    C.Free;
  end;
end;

procedure T_ArcAngles;
var
  C: TSkiaBitmapCanvas;
begin
  
  C := TSkiaBitmapCanvas.Create(40, 40);
  try
    C.Pen.Style := psSolid;
    C.Pen.Color := clWhite;
    { Восток -> юг: VCL идёт против часовой = длинная дуга -270. }
    C.Arc(5, 5, 35, 35, 35, 20, 20, 35);
    
    Check(HasInk(C), 'Arc: visible pixels');
  finally
    C.Free;
  end;
end;

procedure T_MetafileRecordPlayback;
var
  MC: TSkiaMetafileCanvas;
  Pic: ISkPicture;
  C: TSkiaBitmapCanvas;
begin
  
  MC := TSkiaMetafileCanvas.Create(100, 100);
  try
    MC.Brush.Color := clRed;
    MC.Brush.Style := bsSolid;
    MC.FillRect(Rect(10, 10, 30, 30));
    MC.Pen.Color := clBlue;
    MC.Pen.Style := psSolid;
    MC.MoveTo(0, 0);
    MC.LineTo(50, 50);
    Pic := MC.FinishRecording;
    Check(Pic <> nil, 'Metafile: картинка создана');
    Check(Pic.ApproximateOpCount >= 2, 'Metafile: операции записаны');
  finally
    MC.Free;
  end;
  C := TSkiaBitmapCanvas.Create(100, 100);
  try
    Pic.Playback(C.SkCanvas);
    { (20,20) лежит на синей диагонали LineTo — проверяем точку rect вне её. }
    Check(C.Pixels[12, 28] = clRed, 'Metafile.Playback: rect воспроизведён');
    Check(C.Pixels[20, 20] = clBlue, 'Metafile.Playback: линия воспроизведена');
  finally
    C.Free;
  end;
end;

procedure T_MetafileDrawAfterFinish;
var
  MC: TSkiaMetafileCanvas;
  Pic: ISkPicture; BeforeCount: Integer;
begin
  { Рисование после FinishRecording не должно падать. }
  MC := TSkiaMetafileCanvas.Create(50, 50);
  try
    MC.Brush.Color := clGreen;
    MC.Brush.Style := bsSolid;
    MC.FillRect(Rect(0, 0, 10, 10));
    Pic := MC.FinishRecording;
    BeforeCount:=Pic.ApproximateOpCount;
    Check(BeforeCount>0, 'Metafile: operations recorded before finish');
    MC.FillRect(Rect(20, 20, 30, 30)); // после финиша — игнорируется
    Check(Pic.ApproximateOpCount = BeforeCount, 'Metafile: после финиша операций не добавляется');
  finally
    MC.Free;
  end;
end;

procedure T_FloodFillBorder;
var
  C: TSkiaBitmapCanvas;
begin
  { fsBorder: заливаем цветом кисти, граница — Color. }
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 20, 20));
    C.Pen.Color := clBlack;
    C.Pen.Width := 2; // solid interior pixels even with antialiasing
    C.Rectangle(5, 5, 15, 15);
    C.Brush.Color := clRed;
    C.FloodFill(10, 10, clBlack, fsBorder);
    Check(C.Pixels[10, 10] = clRed, 'FloodFill fsBorder: внутри красный');
    Check(C.Pixels[0, 0] = clWhite, 'FloodFill fsBorder: снаружи белый');
  finally
    C.Free;
  end;
end;

procedure T_TextUnderline;
var
  C: TSkiaBitmapCanvas;
  Fnt: ISkFont;
  Metrics: TSkFontMetrics;
  Baseline: Integer;
begin
  C := TSkiaBitmapCanvas.Create(60, 30);
  try
    C.Font.Name := 'Arial';
    C.Font.Size := 12;
    C.Font.Style := [fsUnderline];
    C.Font.Color := clBlack;
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 60, 30));
    C.TextOut(5, 5, 'Test');
    { Подчёркивание рисуется под baseline. Проверяем, что линия есть:
      берём метрики и смотрим пиксель на уровне descent. }
    Fnt := C.AcquireFont;
    Fnt.GetMetrics(Metrics);
    Baseline := 5 - Round(Metrics.Ascent);
    { Пиксель подчёркивания должен быть не белым.
      Линия: [Baseline+Descent-1, Baseline+Descent), проверяем внутри. }
    Check(C.Pixels[10, Baseline + Round(Metrics.Descent) - 1] <> clWhite,
      'TextOut underline: линия подчёркивания нарисована');
  finally
    C.Free;
  end;
end;

procedure T_TextToCurves;
var
  C: TSkiaBitmapCanvas;
begin
  { TextToCurves: текст рисуется контурами глифов (DrawPath),
    а не DrawSimpleText. }
  
  C := TSkiaBitmapCanvas.Create(60, 30);
  try
    C.Font.Name := 'Arial';
    C.Font.Size := 12;
    C.Font.Color := clBlack;
    C.Brush.Style := bsClear;
    C.TextToCurves := True;
    
    C.Font.Color := clWhite;
    C.Brush.Style := bsClear;
    
    C.TextOut(5, 5, 'Hi');
    
    
    Check(HasInk(C), 'T_TextToCurves: visible text');
  finally
    C.Free;
  end;
end;

procedure T_TextToCurvesOff;
var
  C: TSkiaBitmapCanvas;
begin
  { Без опции — обычный DrawSimpleText. }
  
  C := TSkiaBitmapCanvas.Create(60, 30);
  try
    C.Font.Name := 'Arial';
    C.Font.Size := 12;
    C.Brush.Style := bsClear;
    C.TextToCurves := False;
    
    C.Font.Color := clWhite;
    C.Brush.Style := bsClear;
    
    C.TextOut(5, 5, 'Hi');
    
    Check(HasInk(C), 'T_TextToCurvesOff: visible text');
  finally
    C.Free;
  end;
end;

procedure T_TextOpaqueBackground;
var
  C: TSkiaBitmapCanvas;
  Fnt: ISkFont;
  Metrics: TSkFontMetrics;
  H: Integer;
begin
  { GDI: если Brush.Style <> bsClear, TextOut заливает фон кистью. }
  C := TSkiaBitmapCanvas.Create(60, 30);
  try
    C.Font.Name := 'Arial';
    C.Font.Size := 12;
    C.Font.Color := clBlack;
    C.Brush.Color := clYellow;
    C.Brush.Style := bsSolid;
    { Фон чёрный, после TextOut с opaque-кистью должен стать жёлтым. }
    C.Brush.Color := clBlack;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 60, 30));
    C.Brush.Color := clYellow;
    C.Brush.Style := bsSolid;
    C.TextOut(5, 5, 'Hi');
    { Пиксель в области фона текста, заведомо не на глифе:
      'H' не имеет выносных элементов вниз, берём точку в зоне
      descent слева (под baseline, но в фоне). }
    Fnt := C.AcquireFont;
    Fnt.GetMetrics(Metrics);
    H := Floor(Metrics.Descent - Metrics.Ascent);
    Check(C.Pixels[6, 5 + H - 1] = clYellow, 'TextOut opaque: фон залит кистью');
  finally
    C.Free;
  end;
end;

procedure T_TextTransparentBackground;
var
  C: TSkiaBitmapCanvas;
begin
  { GDI: если Brush.Style = bsClear, фон прозрачный. }
  C := TSkiaBitmapCanvas.Create(60, 30);
  try
    C.Font.Name := 'Arial';
    C.Font.Size := 12;
    C.Font.Color := clBlack;
    C.Brush.Color := clBlack;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 60, 30));
    C.Brush.Style := bsClear;
    C.TextOut(5, 5, 'Hi');
    { Фон остался чёрным (не залит). }
    Check(C.Pixels[50, 8] = clBlack, 'TextOut transparent: фон не залит');
  finally
    C.Free;
  end;
end;

procedure T_MetafileSerialize;
var
  MC: TSkiaMetafileCanvas;
  Pic: ISkPicture;
  MS: TMemoryStream;
begin
  MC := TSkiaMetafileCanvas.Create(50, 50);
  try
    MC.Brush.Color := clGreen;
    MC.Brush.Style := bsSolid;
    MC.FillRect(Rect(0, 0, 10, 10));
    Pic := MC.FinishRecording;
    MS := TMemoryStream.Create;
    try
      Pic.SerializeToStream(MS);
      Check(MS.Size > 0, 'Metafile: сериализация непустая');
      
    finally
      MS.Free;
    end;
  finally
    MC.Free;
  end;
end;

procedure T_PdfExport;
var
  MC: TSkiaMetafileCanvas;
  Pic: ISkPicture;
  Doc: ISkDocument;
  Page: ISkCanvas;
  MS: TMemoryStream;
  Head: AnsiString;
begin
  MC := TSkiaMetafileCanvas.Create(100, 100);
  try
    MC.Brush.Color := clRed;
    MC.Brush.Style := bsSolid;
    MC.FillRect(Rect(10, 10, 50, 50));
    Pic := MC.FinishRecording;
  finally
    MC.Free;
  end;
  MS := TMemoryStream.Create;
  try
    Doc := TSkDocument.MakePDF(MS);
    Page := Doc.BeginPage(100, 100);
    Pic.Playback(Page);
    Doc.EndPage;
    Doc.Close;
    Check(MS.Size > 0, 'PDF: поток непустой');
    SetLength(Head, Min(8, MS.Size));
    MS.Position := 0;
    MS.ReadBuffer(Head[1], Length(Head));
    Check(Copy(Head, 1, 5) = '%PDF-', 'PDF: заголовок %PDF-');
  finally
    MS.Free;
  end;
end;

procedure T_SvgExport;
var
  MC: TSkiaMetafileCanvas;
  Pic: ISkPicture;
  Svg: ISkCanvas;
  MS: TMemoryStream;
  Bytes: UTF8String;
  S: string;
begin
  MC := TSkiaMetafileCanvas.Create(100, 100);
  try
    MC.Brush.Color := clRed;
    MC.Brush.Style := bsSolid;
    MC.FillRect(Rect(10, 10, 50, 50));
    MC.Pen.Color := clBlue;
    MC.Pen.Width := 2;
    MC.MoveTo(0, 0);
    MC.LineTo(100, 100);
    Pic := MC.FinishRecording;
  finally
    MC.Free;
  end;
  MS := TMemoryStream.Create;
  try
    Svg := TSkSVGCanvas.Make(RectF(0, 0, 100, 100), MS);
    Pic.Playback(Svg);
    Svg := nil; // SVG дописывается при освобождении
    Check(MS.Size > 0, 'SVG: поток непустой');
    SetLength(Bytes, MS.Size);
    MS.Position := 0;
    MS.ReadBuffer(Bytes[1], Length(Bytes));
    S := UTF8ToString(Bytes);
    Check(Pos('<svg', S) > 0, 'SVG: есть тег <svg>');
    Check(Pos('</svg>', S) > 0, 'SVG: есть закрывающий тег');
    Check((Pos('<polygon', S) > 0) or (Pos('<rect', S) > 0), 'SVG: прямоугольник записан');
    Check((Pos('<line', S) > 0) or (Pos('<path', S) > 0), 'SVG: линия записана');
  finally
    MS.Free;
  end;
end;

procedure T_SvgTransform;
var
  MC: TSkiaMetafileCanvas;
  Pic: ISkPicture;
  Svg: ISkCanvas;
  MS: TMemoryStream;
  Bytes: UTF8String;
  S: string;
begin
  { Проверяем, что трансформации применяются при экспорте в SVG. }
  MC := TSkiaMetafileCanvas.Create(100, 100);
  try
    MC.Brush.Color := clRed;
    MC.Brush.Style := bsSolid;
    MC.SaveState;
    MC.TranslateTransform(50, 50);
    MC.FillRect(Rect(0, 0, 10, 10));
    MC.RestoreState;
    Pic := MC.FinishRecording;
  finally
    MC.Free;
  end;
  MS := TMemoryStream.Create;
  try
    Svg := TSkSVGCanvas.Make(RectF(0, 0, 100, 100), MS);
    Pic.Playback(Svg);
    Svg := nil;
    SetLength(Bytes, MS.Size);
    MS.Position := 0;
    MS.ReadBuffer(Bytes[1], Length(Bytes));
    S := UTF8ToString(Bytes);
    { Прямоугольник (0,0)-(10,10) со сдвигом (50,50) -> точки около (50,50). }
    Check((Pos('50,50', S) > 0) or (Pos('translate(50 50)', S) > 0) or (Pos('matrix(1 0 0 1 50 50)', S) > 0), 'SVG: трансформация применена');
  finally
    MS.Free;
  end;
end;

procedure T_TextRectNoSaveLeak;
var
  C: TSkiaBitmapCanvas;
  R: TRect;
begin
  
  C := TSkiaBitmapCanvas.Create(40, 40);
  try
    R := Rect(0, 0, 40, 40);
    C.TextRect(R, 5, 5, 'Test');
    { Save/Restore сбалансированы: в логе поровну. }
    Check(C.SkCanvas.GetSaveCount = 1, 'TextRect: стек save пуст после вызова');
  finally
    C.Free;
  end;
end;

procedure T_TextRectCalcRect;
var
  C: TSkiaBitmapCanvas;
  R: TRect;
  S: string;
begin
  C := TSkiaBitmapCanvas.Create(40, 40);
  try
    R := Rect(5, 5, 100, 100);
    S := 'AB';
    C.TextRect(R, S, [tfCalcRect]);
    Check(R.Left = 5, 'TextRect(tfCalcRect): Left не меняется');
    Check(R.Top = 5, 'TextRect(tfCalcRect): Top не меняется');
    Check(R.Right > R.Left, 'TextRect(tfCalcRect): Right вычислен');
    Check(R.Bottom > R.Top, 'TextRect(tfCalcRect): Bottom вычислен');
  finally
    C.Free;
  end;
end;

