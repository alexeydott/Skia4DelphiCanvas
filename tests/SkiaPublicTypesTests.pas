{ This consumer intentionally imports no Vcl.Graphics, System.Skia or System.UITypes. }
unit SkiaPublicTypesTests;
{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
interface
uses Vcl.Graphics.Skia;
function TestPublicGraphicsTypes: Boolean;
implementation
function TestPublicGraphicsTypes: Boolean;
var Canvas:TSkiaBitmapCanvas;Bitmap:TBitmap;Brush:TBrush;Pen:TPen;Font:TFont;
  Image:ISkImage;Face:ISkTypeface;Path:ISkPath;Builder:ISkPathBuilder;
  Paint:ISkPaint;NativeFont:ISkFont;Matrix:TMatrix;Bounds:TRectF;
  Pixel:TAlphaColor;Metrics:TSkFontMetrics;Formats:TTextFormat;
begin
  Canvas:=TSkiaBitmapCanvas.Create(32,32);Bitmap:=TBitmap.Create;
  Brush:=TBrush.Create;Pen:=TPen.Create;Font:=TFont.Create;
  try
    Brush.Style:=bsSolid;Brush.Color:=clRed;Canvas.Brush.Assign(Brush);
    Pen.Style:=psDash;Pen.Mode:=pmCopy;Pen.Color:=clBlue;Canvas.Pen.Assign(Pen);
    Font.Name:='Arial';Font.Style:=[fsBold];Font.Height:=-16;Canvas.Font.Assign(Font);
    Canvas.CopyMode:=cmSrcCopy;Canvas.FillRect(TRect.Create(0,0,32,32));
    Canvas.Flush(Bitmap);Bitmap.PixelFormat:=pf32bit;Bitmap.AlphaFormat:=afDefined;
    Image:=Canvas.Snapshot;Face:=TSkTypeface.MakeDefault;
    NativeFont:=TSkFont.Create(Face,16);NativeFont.GetMetrics(Metrics);
    Paint:=TSkPaint.Create;Paint.Style:=TSkPaintStyle.Fill;Paint.Color:=ColorToAlphaColor(clRed);
    Paint.StrokeCap:=TSkStrokeCap.Round;Paint.StrokeJoin:=TSkStrokeJoin.Bevel;
    Bounds:=TRectF.Create(1,1,20,20);Builder:=TSkPathBuilder.Create;
    Builder.AddOval(Bounds);Path:=Builder.Snapshot;
    Canvas.SetClipPath(Path);Canvas.ResetClip;
    Matrix:=TMatrix.Identity;Canvas.SetWorldTransform(Matrix);
    Pixel:=ColorToAlphaColor(clRed);Formats:=[tfSingleLine,tfNoPrefix];
    Result:=(Image.Width=32) and (Bitmap.Canvas.Pixels[10,10]=clRed) and
      (NativeFont.UnicharToGlyph(Ord('A'))<>0) and (Pixel=$FFFF0000) and
      (Formats=[tfSingleLine,tfNoPrefix]) and (Metrics.Descent>=0);
  finally Font.Free;Pen.Free;Brush.Free;Bitmap.Free;Canvas.Free;end;
end;
end.
