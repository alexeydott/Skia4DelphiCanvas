{ Reusable examples for raster and recording canvases.
  Pass a TSkiaBitmapCanvas or TSkiaMetafileCanvas owned by the caller.
  Input images also remain caller-owned. Each example restores canvas state. }
unit SkiaUsageExamples;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$CODEPAGE UTF8}{$ENDIF}

interface

uses Vcl.Graphics.Skia;

const
  QuickStartWidth = 600;
  QuickStartHeight = 360;

{$IFDEF MSWINDOWS}
procedure DrawMetafileFile(Canvas:TSkiaCanvas;const FileName:string;const Dest:TRect);
{$ENDIF}
procedure DrawQuickStart(Canvas: TSkiaCanvas);
procedure DrawMaskedTransfer(Canvas, Source: TSkiaCanvas; Mask: TBitmap;
  const SourceRect: TRect; const Origin: TPoint; Scale: Single);
procedure DrawKeyedBitmap(Canvas: TSkiaCanvas; Bitmap: TBitmap;
  const SourceRect, DestinationRect: TRect; KeyColor, ReplacementColor: TColor);
procedure DrawXorCopy(Canvas, Source: TSkiaCanvas;
  const SourceRect, DestinationRect: TRect);
function DrawClippedFill(Canvas: TSkiaCanvas;
  const InitialClip, Intersection, Hole, FillBounds: TRect; Color: TColor): TRect;

implementation

{$IFDEF MSWINDOWS}
procedure DrawMetafileFile(Canvas:TSkiaCanvas;const FileName:string;const Dest:TRect);
var Metafile:TMetafile;Saved:Integer;
begin
  Metafile:=TMetafile.Create;
  try
    Metafile.LoadFromFile(FileName);
    Canvas.Lock;
    try
      Saved:=Canvas.SaveState;
      try Canvas.StretchDraw(Dest,Metafile);
      finally Canvas.RestoreState(Saved);end;
    finally Canvas.Unlock;end;
  finally Metafile.Free;end;
end;


{$ENDIF}
procedure DrawMaskedTransfer(Canvas, Source: TSkiaCanvas; Mask: TBitmap;
  const SourceRect: TRect; const Origin: TPoint; Scale: Single);
var
  SavedState: Integer;
begin
  SavedState := Canvas.SaveState;
  try
    { Scale local coordinates first, then position the result.
      Reversing these calls would also scale the translation. }
    Canvas.CopyMode := cmSrcCopy;
    Canvas.ScaleTransform(Scale, Scale);
    Canvas.TranslateTransform(Origin.X, Origin.Y);

    { White mask pixels copy the source; black pixels preserve the destination.
      The mask starts at (0,0) and matches the size of SourceRect. }
    Canvas.MaskBlt(0, 0, SourceRect.Width, SourceRect.Height,
      Source, SourceRect.Left, SourceRect.Top, Mask, 0, 0);
  finally
    Canvas.RestoreState(SavedState);
  end;
end;

procedure DrawKeyedBitmap(Canvas: TSkiaCanvas; Bitmap: TBitmap;
  const SourceRect, DestinationRect: TRect; KeyColor, ReplacementColor: TColor);
var
  SavedState: Integer;
begin
  SavedState := Canvas.SaveState;
  try
    { BrushCopy replaces key-colored pixels with the current brush.
      Use Brush.Style := bsClear to preserve the destination at those pixels. }
    Canvas.Brush.Pattern := nil;
    Canvas.Brush.Gradient := gkNone;
    Canvas.Brush.Alpha := 255;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := ReplacementColor;
    Canvas.BrushCopy(DestinationRect, Bitmap, SourceRect, KeyColor);
  finally
    Canvas.RestoreState(SavedState);
  end;
end;

procedure DrawXorCopy(Canvas, Source: TSkiaCanvas;
  const SourceRect, DestinationRect: TRect);
const
  SourceInvert: TCopyMode = $00660046; // Win32 SRCINVERT: source XOR destination
var
  SavedState: Integer;
begin
  SavedState := Canvas.SaveState;
  try
    Canvas.CopyMode := SourceInvert;
    Canvas.CopyRect(DestinationRect, Source, SourceRect);
    { PDF/SVG output automatically embeds the destination-dependent result. }
  finally
    Canvas.RestoreState(SavedState); // Restore the previous CopyMode.
  end;
end;

function DrawClippedFill(Canvas: TSkiaCanvas;
  const InitialClip, Intersection, Hole, FillBounds: TRect; Color: TColor): TRect;
var
  SavedState: Integer;
begin
  SavedState := Canvas.SaveState;
  try
    Canvas.SetClipRect(InitialClip);
    Canvas.IntersectClipRect(Intersection);
    Canvas.ExcludeClipRect(Hole);
    Canvas.Brush.Pattern := nil;
    Canvas.Brush.Gradient := gkNone;
    Canvas.Brush.Alpha := 255;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Color;
    Canvas.FillRect(FillBounds);
    Result := Canvas.ClipRect;
  finally
    Canvas.RestoreState(SavedState); // Restore the previous clip as well as drawing attributes.
  end;
end;

procedure DrawQuickStart(Canvas: TSkiaCanvas);
var
  SavedState, LocalState: Integer;
  TextBounds: TRect;
  Text: string;
begin
  { Keep resource changes and SaveState/RestoreState in one shared-target transaction. }
  if not Canvas.TryLock then Canvas.Lock;
  try
  SavedState := Canvas.SaveState;
  try
    Canvas.ResetWorldTransform;
    Canvas.ResetClip;
    Canvas.Brush.Pattern := nil;
    Canvas.Brush.Gradient := gkNone;
    Canvas.Brush.Alpha := 255;
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Mode := pmCopy;
    Canvas.Pen.Alpha := 255;
    Canvas.Pen.DashPattern := nil;
    Canvas.Font.Style := [];
    Canvas.Font.Alpha := 255;
    Canvas.Font.Orientation := 0;
    Canvas.CopyMode := cmSrcCopy;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clWhite;
    Canvas.FillRect(Rect(0, 0, QuickStartWidth, QuickStartHeight));

    { Configure the gradient fill and pen outline independently. }
    Canvas.Brush.Gradient := gkHorizontal;
    Canvas.Brush.GradientStartColor := clBlue;
    Canvas.Brush.GradientEndColor := TColor($FFFF00);
    Canvas.Pen.Color := clNavy;
    Canvas.Pen.Width := 3;
    Canvas.RoundRect(30, 30, 570, 120, 20, 20);
    Canvas.Brush.Gradient := gkNone;

    { This scene works on both raster and recording canvases.
      TextToCurves enables shaped text with portable glyph outlines. }
    Canvas.TextToCurves := True;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Arial';
    Canvas.Font.Height := -28;
    Canvas.Font.Color := clWhite;
    Canvas.TextOut(50, 55, 'Skia canvas: AVATAR / office');

    LocalState := Canvas.SaveState;
    try
      Canvas.SetClipRect(Rect(30, 150, 270, 310));
      Canvas.RotateTransform(-15);
      Canvas.TranslateTransform(80, 220);
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := TColor($FFFF00);
      Canvas.Pen.Style := psDash;
      Canvas.Rectangle(-30, -40, 180, 60);
    finally
      Canvas.RestoreState(LocalState);
    end;

    { RestoreState has returned the world transform, pen and brush to their previous values. }
    Canvas.Font.Height := -22;
    Canvas.Font.Color := clNavy;
    TextBounds := Rect(300, 155, 570, 315);
    Text := 'A shaped text paragraph with word wrapping and a restored canvas state.';
    Canvas.TextRect(TextBounds, Text, [tfWordBreak]);
  finally
    Canvas.RestoreState(SavedState);
  end;
  finally Canvas.Unlock; end;
end;

end.
