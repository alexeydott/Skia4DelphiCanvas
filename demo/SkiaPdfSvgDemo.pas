{ Record a scene once and replay it to PDF and SVG.
  ExportQuickStart uses the same DrawQuickStart scene as the raster demo;
  changing the output format does not require changing the drawing code. }
program SkiaPdfSvgDemo;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$CODEPAGE UTF8}{$ELSE}{$APPTYPE CONSOLE}{$ENDIF}

uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}Interfaces,{$ENDIF}
  Classes, SysUtils, Types, System.Skia, Vcl.Graphics.Skia,
  SkiaDemoScenes, SkiaAtlasScenes, SkiaUsageExamples;

procedure ExportSVG(const Picture: ISkPicture; const FileName: string;
  Width, Height: Integer);
var
  Stream: TFileStream;
  Canvas: ISkCanvas;
  Bounds: TRectF;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Bounds.Left := 0;
    Bounds.Top := 0;
    Bounds.Right := Width;
    Bounds.Bottom := Height;
    Canvas := TSkSVGCanvas.Make(Bounds, Stream);
    Picture.Playback(Canvas);
  finally
    { Releasing the SVG canvas finalizes its output; keep the stream alive until then. }
    Canvas := nil;
    Stream.Free;
  end;
end;

procedure ExportQuickStart(const OutputDir: string);
var
  Recorder: TSkiaMetafileCanvas;
  Picture: ISkPicture;
  Stream: TFileStream;
  Document: ISkDocument;
  Page: ISkCanvas;
begin
  Recorder := TSkiaMetafileCanvas.Create(QuickStartWidth, QuickStartHeight);
  try
    DrawQuickStart(Recorder);
    Picture := Recorder.FinishRecording;
  finally
    Recorder.Free; // The ISkPicture reference keeps the recording alive.
  end;

  ExportSVG(Picture, OutputDir + 'quickstart.svg', QuickStartWidth, QuickStartHeight);
  Stream := TFileStream.Create(OutputDir + 'quickstart.pdf', fmCreate);
  try
    Document := TSkDocument.MakePDF(Stream);
    Page := Document.BeginPage(QuickStartWidth, QuickStartHeight);
    Picture.Playback(Page);
    Document.EndPage;
    Page := nil;
    Document.Close; // Finalize the PDF before releasing its output stream.
  finally
    Page := nil;
    Document := nil;
    Stream.Free;
  end;
end;

function RecordAtlasPage(PageIndex: Integer): ISkPicture;
var
  Recorder: TSkiaMetafileCanvas;
begin
  Recorder := TSkiaMetafileCanvas.Create(ShowcaseWidth, ShowcaseHeight);
  try
    DrawAtlasPage(Recorder, PageIndex);
    Result := Recorder.FinishRecording;
  finally
    Recorder.Free;
  end;
end;

procedure ExportPicture(const Picture: ISkPicture; const FileName: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Picture.SerializeToStream(Stream); // Save a reusable Skia picture in SKP format.
  finally
    Stream.Free;
  end;
end;

procedure ExportAtlas(const OutputDir: string);
var
  Stream: TFileStream;
  Picture: ISkPicture;
  Document: ISkDocument;
  Page: ISkCanvas;
  PageIndex: Integer;
  Name: string;
begin
  Stream := TFileStream.Create(OutputDir + 'skia_demo.pdf', fmCreate);
  try
    Document := TSkDocument.MakePDF(Stream);
    for PageIndex := 0 to AtlasPageCount - 1 do
    begin
      Picture := RecordAtlasPage(PageIndex);
      if PageIndex = 0 then
        Name := 'skia_demo'
      else
        Name := AtlasPageName(PageIndex);
      ExportSVG(Picture, OutputDir + Name + '.svg', ShowcaseWidth, ShowcaseHeight);
      ExportPicture(Picture, OutputDir + Name + '.skp');

      Page := Document.BeginPage(ShowcaseWidth, ShowcaseHeight);
      Picture.Playback(Page);
      Document.EndPage;
      Page := nil;
      Writeln(Name, ': PDF page / SVG / serialized picture; ops=', Picture.ApproximateOpCount);
    end;
    Document.Close;
  finally
    Page := nil;
    Document := nil;
    Stream.Free;
  end;
end;

var
  OutputDir: string;
begin
  OutputDir := ExtractFilePath(ExpandFileName(ParamStr(0)));
  ExportQuickStart(OutputDir);
  ExportAtlas(OutputDir);
  
  Writeln('Export OK: quickstart + ', AtlasPageCount, ' pages');
  
end.
