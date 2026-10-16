{ Exercise erased source types without changing the current sibling hierarchy.
  The explicit cast models the TCanvas view that normal upcasting will provide
  when TSkiaCanvas inherits TCanvas. No TCanvas member may be read on this view. }
procedure T_BltSkiaCanvasDispatch;
var
  Src, Expected, Actual: TSkiaBitmapCanvas;
  DirectSource: TSkiaCanvas;
  CanvasSource: TCanvas;
  Mask: TBitmap;
  Points: array[0..2] of TPoint;
  ExpectedPixels, ActualPixels: TArray<TAlphaColor>;
  Kind, Scenario, I: Integer;
  Equal, PartialAlpha: Boolean;
  Name: string;

  procedure PaintSource(Canvas: TSkiaBitmapCanvas);
  begin
    Canvas.SkCanvas.Clear(0);
    Canvas.Brush.Alpha := 128;
    Canvas.Brush.Color := clRed;
    Canvas.FillRect(Rect(2, 1, 10, 9));
    Canvas.Brush.Color := clLime;
    Canvas.FillRect(Rect(5, 3, 8, 7));
    Canvas.TranslateTransform(1, 1);
  end;

begin
  Mask := TBitmap.Create;
  try
    Mask.SetSize(12, 10);
    Mask.Canvas.Brush.Color := clWhite;
    Mask.Canvas.FillRect(Rect(0, 0, 12, 10));
    Mask.Canvas.Brush.Color := clBlack;
    Mask.Canvas.FillRect(Rect(5, 0, 12, 10));
    Points[0] := Point(4, 3);
    Points[1] := Point(12, 4);
    Points[2] := Point(5, 10);
    for Scenario := 0 to 2 do
      for Kind := 0 to 4 do
      begin
        Src := TSkiaBitmapCanvas.Create(12, 10);
        Expected := TSkiaBitmapCanvas.Create(24, 24);
        Actual := TSkiaBitmapCanvas.Create(24, 24);
        try
          PaintSource(Src);
          if Scenario = 1 then
          begin
            Expected.SkCanvas.Clear($FF0000FF);
            Actual.SkCanvas.Clear($FF0000FF);
          end
          else
          begin
            Expected.SkCanvas.Clear(0);
            Actual.SkCanvas.Clear(0);
          end;
          if Scenario = 2 then
          begin
            PaintSource(Expected);
            PaintSource(Actual);
            DirectSource := Expected;
            CanvasSource := TCanvas(TObject(Actual));
          end
          else
          begin
            DirectSource := Src;
            CanvasSource := TCanvas(TObject(Src));
          end;
          Expected.IntersectClipRect(Rect(2, 2, 20, 20));
          Actual.IntersectClipRect(Rect(2, 2, 20, 20));
          Name := 'Skia source through TCanvas: operation ' + IntToStr(Kind) +
            ', scenario ' + IntToStr(Scenario);
          try
            case Kind of
              0: begin
                Expected.CopyRect(Rect(4, 3, 12, 9), DirectSource, Rect(1, 1, 9, 7));
                Actual.CopyRect(Rect(4, 3, 12, 9), CanvasSource, Rect(1, 1, 9, 7));
              end;
              1: begin
                Expected.BitBlt(4, 3, 8, 6, DirectSource, 1, 1);
                Actual.BitBlt(4, 3, 8, 6, CanvasSource, 1, 1);
              end;
              2: begin
                Expected.StretchBlt(4, 3, 12, 8, DirectSource, 9, 1, -8, 6);
                Actual.StretchBlt(4, 3, 12, 8, CanvasSource, 9, 1, -8, 6);
              end;
              3: begin
                Expected.MaskBlt(4, 3, 8, 6, DirectSource, 1, 1, Mask, 0, 0);
                Actual.MaskBlt(4, 3, 8, 6, CanvasSource, 1, 1, Mask, 0, 0);
              end;
              4: begin
                Expected.PlgBlt(Points, DirectSource, 1, 1, 8, 6);
                Actual.PlgBlt(Points, CanvasSource, 1, 1, 8, 6);
              end;
            end;
            SetLength(ExpectedPixels, 24 * 24);
            SetLength(ActualPixels, 24 * 24);
            Check(Expected.Snapshot.ReadPixels(TSkImageInfo.Create(24, 24,
              TSkColorType.BGRA8888, TSkAlphaType.Unpremul), @ExpectedPixels[0], 24 * 4),
              Name + ': read direct pixels');
            Check(Actual.Snapshot.ReadPixels(TSkImageInfo.Create(24, 24,
              TSkColorType.BGRA8888, TSkAlphaType.Unpremul), @ActualPixels[0], 24 * 4),
              Name + ': read erased pixels');
            Equal := True;
            PartialAlpha := False;
            for I := 0 to High(ActualPixels) do
            begin
              if ExpectedPixels[I] <> ActualPixels[I] then Equal := False;
              if (ActualPixels[I] shr 24 > 0) and (ActualPixels[I] shr 24 < 255) then
                PartialAlpha := True;
            end;
            Check(Equal, Name + ': exact RGBA matches Skia overload');
            { MaskBlt intentionally retains the existing binary-mask alpha policy. }
            if (Scenario <> 1) and (Kind <> 3) then
              Check(PartialAlpha, Name + ': partial alpha preserved');
          except
            on E: Exception do Check(False, Name + ': ' + E.ClassName);
          end;
        finally
          Actual.Free;
          Expected.Free;
          Src.Free;
        end;
      end;
  finally
    Mask.Free;
  end;
end;

{ Shared native source transfer regression tests for Delphi and FPC. }
procedure T_BltNativeSources;
var Bitmap,Mask: TBitmap; Dst: TSkiaBitmapCanvas; Pts: array[0..2] of TPoint;
    Kind: Integer; Src: TSkiaBitmapCanvas; Format: TPixelFormat;
begin
  Bitmap:=TBitmap.Create; Mask:=TBitmap.Create;
  Dst:=TSkiaBitmapCanvas.Create(24,24);
  Src:=TSkiaBitmapCanvas.Create(8,8);
  try
    Bitmap.SetSize(8,8);
    Bitmap.Canvas.Brush.Color:=clBlue; Bitmap.Canvas.FillRect(Rect(0,0,8,8));
    Bitmap.Canvas.Brush.Color:=clRed; Bitmap.Canvas.FillRect(Rect(4,0,8,8));
    Mask.SetSize(8,8);
    Mask.Canvas.Brush.Color:=clBlack; Mask.Canvas.FillRect(Rect(0,0,8,8));
    Mask.Canvas.Brush.Color:=clWhite; Mask.Canvas.FillRect(Rect(0,0,4,8));
    Pts[0]:=Point(4,4); Pts[1]:=Point(12,4); Pts[2]:=Point(4,12);
    Format:=Bitmap.PixelFormat;
    Src.Brush.Color:=clBlue; Src.FillRect(Rect(0,0,8,8));
    Src.Brush.Color:=clRed; Src.FillRect(Rect(4,0,8,8));
    for Kind:=0 to 3 do
    begin
      {$IFNDEF MSWINDOWS}if Kind=1 then Continue;{$ENDIF}
      Dst.Brush.Color:=clBlack; Dst.FillRect(Rect(0,0,24,24));
      if Kind=0 then Dst.BitBlt(2,2,4,4,Bitmap,4,0)
      {$IFDEF MSWINDOWS}
      else if Kind=1 then Dst.BitBlt(2,2,4,4,Bitmap.Canvas.Handle,4,0)
      {$ENDIF}
      else if Kind=2 then Dst.BitBlt(2,2,4,4,Bitmap.Canvas,4,0)
      else Dst.BitBlt(2,2,4,4,Src,4,0);
      Check(Dst.Pixels[3,3]=clRed,'native BitBlt source offset '+IntToStr(Kind));
      Check(Dst.Pixels[0,0]=clBlack,'native BitBlt outside '+IntToStr(Kind));
      Dst.Brush.Color:=clBlack; Dst.FillRect(Rect(0,0,24,24));
      if Kind=0 then Dst.StretchBlt(0,0,16,8,Bitmap,8,0,-8,8)
      {$IFDEF MSWINDOWS}
      else if Kind=1 then Dst.StretchBlt(0,0,16,8,Bitmap.Canvas.Handle,8,0,-8,8)
      {$ENDIF}
      else if Kind=2 then Dst.StretchBlt(0,0,16,8,Bitmap.Canvas,8,0,-8,8)
      else Dst.StretchBlt(0,0,16,8,Src,8,0,-8,8);
      Check((Dst.Pixels[2,3]=clRed) and (Dst.Pixels[13,3]=clBlue),
        'native StretchBlt mirrored '+IntToStr(Kind));
      Dst.Brush.Color:=clBlack; Dst.FillRect(Rect(0,0,24,24));
      if Kind=0 then Dst.MaskBlt(0,0,8,8,Bitmap,0,0,Mask,0,0)
      {$IFDEF MSWINDOWS}
      else if Kind=1 then Dst.MaskBlt(0,0,8,8,Bitmap.Canvas.Handle,0,0,Mask,0,0)
      {$ENDIF}
      else if Kind=2 then Dst.MaskBlt(0,0,8,8,Bitmap.Canvas,0,0,Mask,0,0)
      else Dst.MaskBlt(0,0,8,8,Src,0,0,Mask,0,0);
      Check((Dst.Pixels[2,3]=clBlue) and (Dst.Pixels[6,3]=clBlack),
        'native MaskBlt mask '+IntToStr(Kind));
      Dst.Brush.Color:=clBlack; Dst.FillRect(Rect(0,0,24,24));
      if Kind=0 then Dst.PlgBlt(Pts,Bitmap,0,0,8,8)
      {$IFDEF MSWINDOWS}
      else if Kind=1 then Dst.PlgBlt(Pts,Bitmap.Canvas.Handle,0,0,8,8)
      {$ENDIF}
      else if Kind=2 then Dst.PlgBlt(Pts,Bitmap.Canvas,0,0,8,8)
      else Dst.PlgBlt(Pts,Src,0,0,8,8);
      Check((Dst.Pixels[6,6]=clBlue) and (Dst.Pixels[10,6]=clRed),
        'native PlgBlt '+IntToStr(Kind));
    end;
    T_BltSkiaCanvasDispatch;
    Check((Bitmap.PixelFormat=Format) and (Bitmap.Canvas.Pixels[6,3]=clRed),
      'Blt sources preserve bitmap format and pixels');
    Dst.BitBlt(0,0,4,4,TCanvas(nil),0,0);
    Dst.StretchBlt(0,0,4,4,TCanvas(nil),0,0,4,4);
    Dst.MaskBlt(0,0,4,4,TCanvas(nil),0,0,Mask,0,0);
    Dst.PlgBlt(Pts,TCanvas(nil),0,0,4,4);
    {$IFDEF MSWINDOWS}Dst.BitBlt(0,0,4,4,HDC(0),0,0);{$ENDIF}
    Dst.BitBlt(0,0,4,4,TBitmap(nil),0,0);
  finally Src.Free; Dst.Free; Mask.Free; Bitmap.Free; end;
end;

