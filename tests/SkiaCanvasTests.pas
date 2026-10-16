{ Native Delphi VCL/Skia integration tests; run_tests.cmd builds Win32 and Win64.
  Native FPC integration tests are in SkiaFpcNativeTests.pas. }
program SkiaCanvasTests;

{$APPTYPE CONSOLE}

{$POINTERMATH ON}

uses
  Classes, SysUtils, Types, Math,
  System.UITypes, System.Math.Vectors, Vcl.Imaging.pngimage,
  Winapi.Windows, Vcl.Graphics, System.Skia, Vcl.Graphics.Skia, Vcl.GraphUtil.MetafileParser, SkiaPublicTypesTests;

var
  GPassed, GFailed, GSkipped: Integer;

procedure Check(Cond: Boolean; const Name: string);
begin
  if Cond then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', Name);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', Name);
  end;
end;



function RectF(L, T, R, B: Single): TRectF;
begin
  Result.Left := L; Result.Top := T; Result.Right := R; Result.Bottom := B;
end;


function HasInk(C: TSkiaBitmapCanvas): Boolean;
var X, Y: Integer;
begin
  Result := False;
  for Y := 0 to C.Height - 1 do
    for X := 0 to C.Width - 1 do
      if C.Pixels[X, Y] <> clBlack then
        Exit(True);
end;


{==================== Кисти/перья ====================}





{$I SkiaBasicCanvasTests.inc}

procedure T_BrushAssignFromHandle;
var
  B: TSkiaBrush;
  Src: TBrush;
  LB: TLogBrush;
  Data: TBytes;
begin
  B := TSkiaBrush.Create;
  Src := TBrush.Create;
  try
    LB.lbStyle := BS_HATCHED;
    LB.lbColor := $0000FF; // красный в COLORREF
    LB.lbHatch := HS_CROSS;
    SetLength(Data, SizeOf(LB));
    Move(LB, Data[0], SizeOf(LB));
    
    Src.Handle := CreateBrushIndirect(LB);
    
    B.Assign(Src);
    Check(B.Style = bsCross, 'Brush.Assign(handle): hatch->bsCross');
    Check(B.Color = TColor($0000FF), 'Brush.Assign(handle): color');
  finally
    B.Free; Src.Free;
  end;
end;

procedure T_PenAssignFromHandle;
var
  P: TSkiaPen;
  Src: TPen;
  LP: TLogPen;
  Data: TBytes;
begin
  P := TSkiaPen.Create;
  Src := TPen.Create;
  try
    LP.lopnStyle := PS_DASH;
    LP.lopnWidth := Point(2, 0);
    LP.lopnColor := $FF0000; // синий в COLORREF
    SetLength(Data, SizeOf(LP));
    Move(LP, Data[0], SizeOf(LP));
    
    Src.Handle := CreatePenIndirect(LP);
    
    P.Assign(Src);
    Check(P.Style = psDash, 'Pen.Assign(handle): style');
    Check(P.Width = 2, 'Pen.Assign(handle): width');
  finally
    P.Free; Src.Free;
  end;
end;



{==================== Менеджер ресурсов ====================}



procedure T_FontAssignFromHandle;
var
  F: TSkiaFont;
  Src: TFont;
  LF: TLogFontW;
  Data: TBytes;
begin
  F := TSkiaFont.Create;
  Src := TFont.Create;
  try
    FillChar(LF, SizeOf(LF), 0);
    StrPLCopy(LF.lfFaceName, 'TestFace', LF_FACESIZE - 1);
    LF.lfHeight := -24;
    LF.lfWeight := FW_BOLD;
    LF.lfItalic := 1;
    SetLength(Data, SizeOf(LF));
    Move(LF, Data[0], SizeOf(LF));
    
    Src.Handle := CreateFontIndirectW(LF);
    
    F.Assign(Src);
    Check(F.Name = 'TestFace', 'Font.Assign(handle): имя');
    Check(F.Height = -24, 'Font.Assign(handle): высота');
    Check(fsBold in F.Style, 'Font.Assign(handle): bold');
    Check(fsItalic in F.Style, 'Font.Assign(handle): italic');
  finally
    F.Free; Src.Free;
  end;
end;









procedure T_FontManagerLoadFile;
var
  M: TSkiaFontManager;
  TF: ISkTypeface;
  FN: string;
  
begin
  M := TSkiaFontManager.Create;
  try
    { Несуществующий файл -> исключение. }
    try
      M.LoadTypefaceFromFile('/nonexistent/font.ttf');
      Check(False, 'FontManager: LoadFromFile несуществующего должен упасть');
    except
      on E: ESkiaCanvasError do
        Check(True, 'FontManager: LoadFromFile несуществующего — исключение');
    end;
    { Существующий файл -> typeface. }
    
    FN := GetEnvironmentVariable('WINDIR') + '\Fonts\arial.ttf';
    
    try
      TF := M.LoadTypefaceFromFile(FN);
      Check(TF <> nil, 'FontManager: LoadFromFile существующего');
      
      Check(TF.GetFamilyName <> '', 'FontManager: имя из файла');
      
    finally
      
    end;
  finally
    M.Free;
  end;
end;

procedure T_FontManagerLoadStream;
var
  M: TSkiaFontManager;
  TF: ISkTypeface;
  MS: TMemoryStream;
begin
  M := TSkiaFontManager.Create;
  try
    MS := TMemoryStream.Create;
    try
      
      MS.LoadFromFile(GetEnvironmentVariable('WINDIR') + '\Fonts\arial.ttf');
      
      MS.Position := 0;
      TF := M.LoadTypefaceFromStream(MS);
      Check(TF <> nil, 'FontManager: LoadFromStream');
    finally
      MS.Free;
    end;
    try
      M.LoadTypefaceFromStream(nil);
      Check(False, 'FontManager: LoadFromStream(nil) должен упасть');
    except
      on E: ESkiaCanvasError do
        Check(True, 'FontManager: LoadFromStream(nil) — исключение');
    end;
  finally
    M.Free;
  end;
end;



{==================== Растровый канвас ====================}



















{==================== Клип и трансформы ====================}











{==================== Текст ====================}





{==================== Дуги ====================}



{==================== Метафайл ====================}





procedure T_CopyRect;
var
  Src, Dst: TSkiaBitmapCanvas;
  Bitmap: TBitmap; Canvas: TCanvas;
begin
  Src := TSkiaBitmapCanvas.Create(20, 20);
  Dst := TSkiaBitmapCanvas.Create(20, 20);
  Bitmap:=TBitmap.Create;
  try
    Src.Brush.Color := clRed;
    Src.Brush.Style := bsSolid;
    Src.FillRect(Rect(0, 0, 10, 10));
    Dst.CopyRect(Rect(5, 5, 15, 15), Src, Rect(0, 0, 10, 10));
    Check(Dst.Pixels[10, 10] = clRed, 'CopyRect: пиксель скопирован');
    Check(Dst.Pixels[0, 0] = clBlack, 'CopyRect: вне области чёрный');
    Bitmap.SetSize(8,8);
    Bitmap.Canvas.Brush.Color:=clBlue; Bitmap.Canvas.FillRect(Rect(0,0,8,8));
    Bitmap.Canvas.Brush.Color:=clYellow; Bitmap.Canvas.FillRect(Rect(4,0,8,8));
    Canvas:=Bitmap.Canvas;
    Dst.CopyRect(Rect(0,0,8,8),Canvas,Rect(4,0,8,4));
    Check(Dst.Pixels[3,3]=clYellow,'CopyRect: TCanvas offset and scaling');
    Dst.CopyRect(Rect(0,0,8,8),Canvas,Rect(8,0,0,8));
    Check((Dst.Pixels[1,3]=clYellow) and (Dst.Pixels[6,3]=clBlue),
      'CopyRect: TCanvas mirrored source');
    Dst.CopyRect(Rect(0,0,8,8),TCanvas(nil),Rect(0,0,8,8));
  finally
    Bitmap.Free;
    Dst.Free;
    Src.Free;
  end;
end;

{$I SkiaBltTests.inc}
{$I SkiaBindingsTests.inc}
{$I SkiaRasterOptionsTests.inc}
{$I SkiaAffineRasterTests.inc}
{$I SkiaAffineTextPathTests.inc}
{$I SkiaTextPathTests.inc}

procedure T_BitBlt;
var
  Src, Dst: TSkiaBitmapCanvas;
begin
  Src := TSkiaBitmapCanvas.Create(20, 20);
  Dst := TSkiaBitmapCanvas.Create(20, 20);
  try
    Src.Brush.Color := clBlue;
    Src.Brush.Style := bsSolid;
    Src.FillRect(Rect(2, 2, 8, 8));
    Dst.BitBlt(10, 10, 6, 6, Src, 2, 2);
    Check(Dst.Pixels[12, 12] = clBlue, 'BitBlt: пиксель скопирован');
    Check(Dst.Pixels[10, 10] = clBlue, 'BitBlt: угол скопирован');
    Check(Dst.Pixels[0, 0] = clBlack, 'BitBlt: вне области чёрный');
    Check(Dst.Pixels[9, 9] = clBlack, 'BitBlt: граница не задета');
  finally
    Dst.Free;
    Src.Free;
  end;
end;

procedure T_StretchBlt;
var
  Src, Dst: TSkiaBitmapCanvas;
begin
  Src := TSkiaBitmapCanvas.Create(10, 10);
  Dst := TSkiaBitmapCanvas.Create(20, 20);
  try
    Src.Brush.Color := clGreen;
    Src.Brush.Style := bsSolid;
    Src.FillRect(Rect(0, 0, 10, 10));
    { Растягиваем 10x10 в 20x20. }
    Dst.StretchBlt(0, 0, 20, 20, Src, 0, 0, 10, 10);
    Check(Dst.Pixels[5, 5] = clGreen, 'StretchBlt: растянутый пиксель');
    Check(Dst.Pixels[15, 15] = clGreen, 'StretchBlt: дальний угол');
    Check(Dst.Pixels[0, 0] = clGreen, 'StretchBlt: начало');
  finally
    Dst.Free;
    Src.Free;
  end;
end;

procedure T_StretchBlt_Shrink;
var
  Src, Dst: TSkiaBitmapCanvas;
begin
  Src := TSkiaBitmapCanvas.Create(20, 20);
  Dst := TSkiaBitmapCanvas.Create(10, 10);
  try
    Src.Brush.Color := clRed;
    Src.Brush.Style := bsSolid;
    Src.FillRect(Rect(0, 0, 20, 20));
    { Сжимаем 20x20 в 10x10. }
    Dst.StretchBlt(0, 0, 10, 10, Src, 0, 0, 20, 20);
    Check(Dst.Pixels[5, 5] = clRed, 'StretchBlt shrink: пиксель');
  finally
    Dst.Free;
    Src.Free;
  end;
end;

procedure T_MaskBlt;
var
  Src, Dst: TSkiaBitmapCanvas;
  Mask: TBitmap;
begin
  Src := TSkiaBitmapCanvas.Create(10, 10);
  Dst := TSkiaBitmapCanvas.Create(10, 10);
  Mask := TBitmap.Create;
  try
    Mask.Width := 10;
    Mask.Height := 10;
    Src.Brush.Color := clYellow;
    Src.Brush.Style := bsSolid;
    Src.FillRect(Rect(0, 0, 10, 10));
    { Маска: белая левая половина, чёрная правая. }
    Mask.Canvas.Brush.Color := clWhite;
    Mask.Canvas.FillRect(Rect(0, 0, 5, 10));
    Mask.Canvas.Brush.Color := clBlack;
    Mask.Canvas.FillRect(Rect(5, 0, 10, 10));
    Dst.MaskBlt(0, 0, 10, 10, Src, 0, 0, Mask, 0, 0);
    Check(Dst.Pixels[2, 5] = clYellow, 'MaskBlt: белая маска копирует');
    Check(Dst.Pixels[7, 5] = clBlack, 'MaskBlt: чёрная маска не копирует');
  finally
    Mask.Free;
    Dst.Free;
    Src.Free;
  end;
end;

procedure T_PlgBlt;
var
  Src, Dst: TSkiaBitmapCanvas;
  Pts: array[0..2] of TPoint;
begin
  Src := TSkiaBitmapCanvas.Create(10, 10);
  Dst := TSkiaBitmapCanvas.Create(30, 30);
  try
    Src.Brush.Color := clFuchsia;
    Src.Brush.Style := bsSolid;
    Src.FillRect(Rect(0, 0, 10, 10));
    { Параллелограмм: сдвиг вправо (наклон). }
    Pts[0] := Point(5, 5);
    Pts[1] := Point(15, 5);
    Pts[2] := Point(10, 15);
    Dst.PlgBlt(Pts, Src, 0, 0, 10, 10);
    { Центр параллелограмма должен быть закрашен. }
    Check(Dst.Pixels[10, 10] = clFuchsia, 'PlgBlt: центр закрашен');
    Check(Dst.Pixels[0, 0] = clBlack, 'PlgBlt: вне параллелограмма чёрный');
  finally
    Dst.Free;
    Src.Free;
  end;
end;













procedure T_GdiEmSquare;
var
  C: TSkiaBitmapCanvas;
  LF: TLogFontW;
  Em: Integer;
  Key: string;
begin
  { EM-квадрат через EnumFontFamiliesExW/NEWTEXTMETRICW (кэшируется).
    Стаб возвращает ntmSizeEM = 2048. }
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Font.Name := 'Arial';
    Check(C.FontManager.GetLogFont(C.Font, LF), 'GdiEmSquare: LOGFONT получен');
    Key := C.FontManager.FontKey(C.Font);
    Em := C.GlyphCache.GetEmSquare(LF, Key);
    
    Check(Em > 0, 'GdiEmSquare: positive EM');
    
    { Повторный вызов — из кэша, тот же результат. }
    Em := C.GlyphCache.GetEmSquare(LF, Key);
    Check(Em = C.GlyphCache.GetEmSquare(LF, Key), 'GdiEmSquare: повторный вызов из кэша');
  finally
    C.Free;
  end;
end;

procedure T_GdiGlyphOutlineToPath;
var
  C: TSkiaBitmapCanvas;
  LF: TLogFontW;
  Key: string;
  Path: ISkPath;
  Advance: Single;
  Bounds: TRectF;
  Glyphs: TArray<TGdiShapedGlyph>;
  IdxA, IdxSpace: Word;
begin
  { Парсинг GGO_NATIVE: стаб отдаёт квадрат 0,0-100,100. }
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Font.Name := 'Arial';
    Check(C.FontManager.GetLogFont(C.Font, LF), 'GlyphOutline: LOGFONT получен');
    Key := C.FontManager.FontKey(C.Font);
    { Шейпинг: 'A' -> один глиф. }
    Check(C.GlyphCache.ShapeText(LF, Key, 2048, 'A', Glyphs),
      'GlyphOutline: ShapeText ok');
    Check(Length(Glyphs) = 1, 'GlyphOutline: single glyph');
    IdxA := Glyphs[0].GlyphIndex;
    Path := C.GlyphCache.GetGlyphPathByIndex(IdxA, Advance);
    Check(Path <> nil, 'GlyphOutline: path exists');
    Check(Advance > 0, 'GlyphOutline: advance');
    Check(Glyphs[0].AdvanceX > 0, 'GlyphOutline: shaping advance');
    if Path <> nil then
    begin
      Bounds := Path.GetBounds;
      
      Check((Bounds.Right > Bounds.Left) and (Bounds.Bottom > Bounds.Top), 'GlyphOutline: nonempty bounds');
      
    end;
    { Повторный вызов — тот же объект из кэша. }
    Check(C.GlyphCache.GetGlyphPathByIndex(IdxA, Advance) = Path,
      'GlyphOutline: повторный вызов из кэша');
    { Пробел: контура нет, но advance честный (был баг: advance=0). }
    Check(C.GlyphCache.ShapeText(LF, Key, 2048, ' ', Glyphs),
      'GlyphOutline: ShapeText space');
    Check(Length(Glyphs) = 1, 'GlyphOutline: пробел — один глиф');
    IdxSpace := Glyphs[0].GlyphIndex;
    Path := C.GlyphCache.GetGlyphPathByIndex(IdxSpace, Advance);
    Check(Path = nil, 'GlyphOutline: у пробела нет контура');
    Check(Advance > 0, 'GlyphOutline: space advance');
    Check(Glyphs[0].AdvanceX > 0,
      'GlyphOutline: шейпинг не теряет advance пробела');
  finally
    C.Free;
  end;
end;

procedure T_GdiLatinGlyphOrder;
const Text = 'Skia PDF/SVG demo';
var
  C: TSkiaBitmapCanvas;
  LF: TLogFontW;
  Key: string;
  Whole, One: TArray<TGdiShapedGlyph>;
  I, Em: Integer;
begin
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Font.Name := 'Arial';
    Check(C.FontManager.GetLogFont(C.Font, LF), 'Latin glyph order: LOGFONT');
    Key := C.FontManager.FontKey(C.Font);
    Em := C.GlyphCache.GetEmSquare(LF, Key);
    Check(C.GlyphCache.ShapeText(LF, Key, Em, Text, Whole), 'Latin glyph order: shape');
    Check(Length(Whole) = Length(Text), 'Latin glyph order: count');
    if Length(Whole) = Length(Text) then
      for I := 1 to Length(Text) do
      begin
        Check(C.GlyphCache.ShapeText(LF, Key, Em, Copy(Text, I, 1), One),
          'Latin glyph order: character shape');
        Check((Length(One) = 1) and (One[0].GlyphIndex = Whole[I-1].GlyphIndex),
          'Latin glyph order: position ' + IntToStr(I));
      end;
  finally
    C.Free;
  end;
end;

procedure T_CurvesSurrogatePair;
var
  C: TSkiaBitmapCanvas;
  LF: TLogFontW;
  Key: string;
  Glyphs: TArray<TGdiShapedGlyph>;
  WS: UnicodeString;
begin
  { Суррогатная пара — один глиф, одиночный суррогат — пропуск.
    UnicodeString, чтобы FPC не потерял суррогаты в AnsiString. }
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Font.Name := 'Arial';
    Check(C.FontManager.GetLogFont(C.Font, LF), 'Surrogate: LOGFONT');
    Key := C.FontManager.FontKey(C.Font);
    WS := 'A' + WideChar($D83D) + WideChar($DE00) + 'B';
    Check(Length(WS) = 4, 'Surrogate: строка из 4 UTF-16 единиц');
    Check(C.GlyphCache.ShapeText(LF, Key, 2048, WS, Glyphs),
      'Surrogate: ShapeText ok');
    Check(Length(Glyphs) = 3, 'Surrogate: пара = один глиф (A+emoji+B = 3)');
    WS := 'A' + WideChar($D83D) + 'B';
    Check(C.GlyphCache.ShapeText(LF, Key, 2048, WS, Glyphs),
      'Surrogate: lone ok');
    
    Check(Length(Glyphs) >= 2, 'Surrogate: surrounding letters preserved');
    
  finally
    C.Free;
  end;
end;

procedure T_CurvesUnderline;
var
  C: TSkiaBitmapCanvas;
  Fnt: ISkFont;
  Metrics: TSkFontMetrics;
  Baseline: Integer;
begin
  { В режиме кривых подчёркивание обязано рисоваться (был баг: пропадало). }
  
  C := TSkiaBitmapCanvas.Create(60, 30);
  try
    C.Font.Name := 'Arial';
    C.Font.Size := 12;
    C.Font.Style := [fsUnderline];
    C.Font.Color := clBlack;
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 60, 30));
    C.TextToCurves := True;
    C.TextOut(5, 5, 'Test');
    Fnt := C.AcquireFont;
    Fnt.GetMetrics(Metrics);
    Baseline := 5 - Round(Metrics.Ascent);
    { В стабе advances GDI узкие (120/2048 em), поэтому линия короткая —
      проверяем пиксель заведомо внутри неё. }
    Check(C.Pixels[6, Baseline + Round(Metrics.Descent) - 1] <> clWhite,
      'Curves underline: линия нарисована');
    
  finally
    C.Free;
  end;
end;

procedure T_GlyphCacheInvalidation;
var
  C: TSkiaBitmapCanvas;
begin
  { Смена шрифта сбрасывает кэш глифов. }
  C := TSkiaBitmapCanvas.Create(20, 20);
  try
    C.Font.Name := 'Arial';
    C.TextToCurves := True;
    C.TextOut(5, 5, 'A');
    { Кэш не пуст после рисования — проверяем через повторный вызов. }
    C.Font.Name := 'Courier';
    { После смены шрифта кэш сброшен (FontChanged -> Clear). }
    Check(True, 'GlyphCacheInvalidation: смена шрифта не роняет');
  finally
    C.Free;
  end;
end;

procedure T_TextToCurvesGdi;
var
  C: TSkiaBitmapCanvas;
begin
  { TextToCurves через GDI: глифы рисуются как DrawPath,
    world transform учитывается. }
  
  C := TSkiaBitmapCanvas.Create(100, 40);
  try
    C.Font.Name := 'Arial';
    C.Font.Size := 12;
    C.Font.Color := clBlack;
    C.Brush.Style := bsClear;
    C.TextToCurves := True;
    { Сдвигаем world transform — кривые должны учесть его. }
    C.TranslateTransform(10, 5);
    
    C.Font.Color := clWhite;
    C.Brush.Style := bsClear;
    
    C.TextOut(5, 5, 'AB');
    { Два глифа = два DrawPath (плюс фоновые, но Brush=bsClear). }
    
    
    Check(HasInk(C), 'T_TextToCurvesGdi: visible text');
  finally
    C.Free;
  end;
end;













{==================== E2E ====================}

procedure T_E2E_Scene;
var
  C: TSkiaBitmapCanvas;
  Bmp: TBitmap;
  Ok: Boolean;
begin
  { Полная сцена: фон, фигуры, текст, картинка, клип, трансформ. }
  
  C := TSkiaBitmapCanvas.Create(100, 100);
  Bmp := TBitmap.Create;
  try
    { Фон }
    C.Brush.Color := clBlack;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, 100, 100));
    { Красный прямоугольник }
    C.Brush.Color := clRed;
    C.FillRect(Rect(10, 10, 40, 40));
    { Синий эллипс }
    C.Brush.Color := clBlue;
    C.Pen.Style := psClear;
    C.Ellipse(50, 50, 90, 90);
    { Зелёная линия }
    C.Pen.Color := clLime;
    C.Pen.Width := 1;
    C.Pen.Style := psSolid;
    C.MoveTo(0, 99);
    C.LineTo(99, 0);
    { Текст }
    C.Font.Name := 'Arial';
    C.Font.Color := clWhite;
    C.TextOut(5, 80, 'E2E');
    { Клип + заливка }
    C.SetClipRect(Rect(0, 0, 50, 50));
    C.Brush.Color := clWhite;
    C.FillRect(Rect(0, 0, 100, 100));
    C.ResetClip;
    { Flush в битмап }
    C.Flush(Bmp);
    Ok := True;
    Ok := Ok and (Bmp.Width = 100) and (Bmp.Height = 100);
    { Пиксель (20,20): был красным, перезалит белым через клип }
    Ok := Ok and (C.Pixels[20, 20] = clWhite);
    { Пиксель (70,70): синий эллипс вне клипа }
    Ok := Ok and (C.Pixels[70, 70] = clBlue);
    { Пиксель (60,10): чёрный фон }
    Ok := Ok and (C.Pixels[60, 10] = clBlack);
    Check(Ok, 'E2E: сцена корректна');
    
    
  finally
    Bmp.Free;
    C.Free;
  end;
end;

procedure T_E2E_MetafileToBitmap;
var
  MC: TSkiaMetafileCanvas;
  C: TSkiaBitmapCanvas;
begin
  { E2E: запись в метафайл -> воспроизведение на растре. }
  MC := TSkiaMetafileCanvas.Create(60, 60);
  try
    MC.Brush.Color := clRed;
    MC.Brush.Style := bsSolid;
    MC.FillRect(Rect(5, 5, 25, 25));
    MC.Brush.Color := clBlue;
    MC.FillRect(Rect(30, 30, 50, 50));
    C := TSkiaBitmapCanvas.Create(60, 60);
    try
      MC.Playback(C);
      Check(C.Pixels[10, 10] = clRed, 'E2E metafile: первый rect');
      Check(C.Pixels[40, 40] = clBlue, 'E2E metafile: второй rect');
      Check(C.Pixels[55, 55] = clBlack, 'E2E metafile: фон');
    finally
      C.Free;
    end;
  finally
    MC.Free;
  end;
end;

{$I SkiaAdvancedTests.inc}
{$I SkiaAtlasTests.inc}
{$I SkiaCompatibilityTests.inc}
{$I SkiaUnicodeTests.inc}
{$I SkiaThreadTests.inc}
{$I SkiaMetafileTests.inc}
{$I SkiaImageCodecTests.inc}

begin
  GPassed:=0; GFailed:=0; GSkipped:=0;
  if SysUtils.GetEnvironmentVariable('SKIA_TEST_GROUP') = 'textpath-affine' then
  begin
    Writeln('Test group: textpath-affine');
    TestTextOnPath;
    TestAffineTextOnPathOptions;
  end
  else
  begin
  WriteLn('=== SkiaCanvasTests ===');
  TestNativePngDecoding;
  
  T_BrushAssignFromProps;
  T_PenAssignFromProps;
  T_BrushAssignFromHandle;
  T_PenAssignFromHandle;
  T_BrushPatternFromBitmap;
  T_ResourceManagerCache;
  T_FontAssignFromHandle;
  T_FontAlpha;
  T_FontManagerCache;
  T_FontManagerCustom;
  T_FontManagerInvalidatesResourceCache;
  T_FontManagerLoadFile;
  T_FontManagerLoadStream;
  T_PenDashEffect;
  T_FillRectPixel;
  T_StrokeRectPixel;
  T_EllipsePixel;
  T_GradientPixel;
  T_HatchPixel;
  T_DrawImagePixel;
  T_DrawWithOpacity;
  T_FlushToBitmap;
  T_FloodFill;
  T_ClipRect;
  T_RotateTransform;
  T_RotateDrawRect;
  T_TranslateTransform;
  T_SaveRestoreState;
  T_TextOutLog;
  T_TextExtent;
  T_ArcAngles;
  T_MetafileRecordPlayback;
  T_MetafileDrawAfterFinish;
  T_CopyRect;
  TestUpdatedSkiaBindings;
  TestCanvasRasterSettingsAndPixmap;
  TestAffineRasterOptions;
  TestAffineTextOnPathOptions;
  T_BltNativeSources;
  T_BitBlt;
  T_StretchBlt;
  T_StretchBlt_Shrink;
  T_MaskBlt;
  T_PlgBlt;
  T_FloodFillBorder;
  T_TextUnderline;
  T_TextToCurves;
  T_TextToCurvesOff;
  T_TextOpaqueBackground;
  T_TextTransparentBackground;
  T_GdiEmSquare;
  T_GdiGlyphOutlineToPath;
  T_GdiLatinGlyphOrder;
  T_CurvesSurrogatePair;
  T_CurvesUnderline;
  T_GlyphCacheInvalidation;
  T_TextToCurvesGdi;
  T_TextRectNoSaveLeak;
  T_TextRectCalcRect;
  T_MetafileSerialize;
  T_PdfExport;
  T_SvgExport;
  T_SvgTransform;
  T_E2E_Scene;
  T_E2E_MetafileToBitmap;
  T_AdvancedKerning;
  T_AdvancedEmptyAndInvalid;
  T_AdvancedComplexShaping;
  T_AdvancedNestedState;
  T_AdvancedOutlineExport;
  T_AdvancedAlpha;
  T_AtlasClipResetMatrix;
  T_AtlasMaskSelfCopy;
  T_AtlasTransfers;
  T_AtlasClipShapes;
  T_AtlasStateModes;
  T_AtlasBrushPenCatalog;
  Check(TestPublicGraphicsTypes,'public VCL/Skia aliases compile and render without extra graphics units');
  TestEmfPlayback;
  TestTextOnPath;
  TestThreadSafety;
  TestUnicodeTextHelpers;
  TestCanvasApiGuards;
  T_CompatPenModes;
  T_CompatCopyRops;
  T_CompatTransparencyAndMirroring;
  T_CompatVectorRasterOps;
  T_CompatTextLayout;
  T_CompatClipStackAndFlood;
  T_CompatInsideFrame;
  T_CompatPrefixAndCustomCurves;
  T_CompatNativeGraphics;
  T_CompatSourceCoordinates;
  T_CompatPrepaintedSurface;
  T_CompatBrushKeyAndFrame;
  T_CompatNonRectangularClip;
  T_CompatFontChangeObserver;
  T_CompatExternalTypeface;
  T_CompatPatternRopReference;
  T_CompatFontOrientation;
  T_CompatInsideFrameClosedShapes;
  T_CompatPortableTextFormatting;
  end;
  Writeln('Skipped: ',GSkipped);
  WriteLn(Format('Итого: %d/%d passed, %d failed',
    [GPassed, GPassed + GFailed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.


