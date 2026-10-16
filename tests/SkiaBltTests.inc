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

