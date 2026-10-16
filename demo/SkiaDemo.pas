{ Raster drawing: create a canvas, draw a scene and copy it to a TBitmap.
  SaveQuickStartBitmap uses the reusable DrawQuickStart scene from
  SkiaUsageExamples; SkiaAtlasScenes contains the full API examples. }
program SkiaDemo;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$CODEPAGE UTF8}{$ELSE}{$APPTYPE CONSOLE}{$ENDIF}

uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}Interfaces,{$ENDIF}
  SysUtils, Vcl.Graphics, Vcl.Graphics.Skia,
  SkiaDemoScenes, SkiaAtlasScenes, SkiaUsageExamples;

procedure SaveQuickStartBitmap(const FileName: string);
var
  Canvas: TSkiaBitmapCanvas;
  Bitmap: TBitmap;
begin
  Canvas := TSkiaBitmapCanvas.Create(QuickStartWidth, QuickStartHeight);
  Bitmap := TBitmap.Create;
  try
    DrawQuickStart(Canvas);
    Canvas.Flush(Bitmap); // Copy the Skia surface into the caller-owned bitmap.
    Bitmap.SaveToFile(FileName);
  finally
    Bitmap.Free;
    Canvas.Free;
  end;
end;

procedure SaveAtlasBitmap(const OutputDir: string; PageIndex: Integer);
var
  Canvas: TSkiaBitmapCanvas;
  Bitmap: TBitmap;
  Name: string;
begin
  Canvas := TSkiaBitmapCanvas.Create(ShowcaseWidth, ShowcaseHeight);
  Bitmap := TBitmap.Create;
  try
    DrawAtlasPage(Canvas, PageIndex);
    Canvas.Flush(Bitmap);
    if PageIndex = 0 then
      Name := 'skia_demo'
    else
      Name := AtlasPageName(PageIndex);
    Bitmap.SaveToFile(OutputDir + Name + '.bmp');
    Writeln(Name, ': ', Canvas.Width, 'x', Canvas.Height,
      '; Snapshot=', Canvas.Snapshot.Width, 'x', Canvas.Snapshot.Height);
  finally
    Bitmap.Free;
    Canvas.Free;
  end;
end;

procedure RecordAtlasPage(PageIndex: Integer);
var
  Canvas: TSkiaMetafileCanvas;
begin
  Canvas := TSkiaMetafileCanvas.Create(ShowcaseWidth, ShowcaseHeight);
  try
    { The same drawing code accepts a recording canvas. FinishRecording
      ends the recording and returns a picture that can be replayed. }
    DrawAtlasPage(Canvas, PageIndex);
    Writeln('Recorder ', Canvas.Width:0:0, 'x', Canvas.Height:0:0,
      '; ops=', Canvas.FinishRecording.ApproximateOpCount);
  finally
    Canvas.Free;
  end;
end;

var
  OutputDir: string;
  PageIndex: Integer;
begin
  OutputDir := ExtractFilePath(ExpandFileName(ParamStr(0)));
  SaveQuickStartBitmap(OutputDir + 'quickstart.bmp');
  for PageIndex := 0 to AtlasPageCount - 1 do
  begin
    SaveAtlasBitmap(OutputDir, PageIndex);
    RecordAtlasPage(PageIndex);
  end;
  
  Writeln('Demo OK: quickstart + ', AtlasPageCount, ' raster / recorded pages');
  
end.
