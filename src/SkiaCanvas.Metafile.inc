{ EMF vector playback with native per-record raster composition. }
type
  TMetafileTextRun = record
    Glyphs,Background,OpaqueRect,Clip:ISkPath;
  end;
  TMetafilePlayback = class
  private
    FTarget:TSkiaCanvas;
    FParser:TMetafileParser;
    FReplay:TMetafileRecordPlayer;
    FDC:HDC;
    FBitmap,FPreviousBitmap:HGDIOBJ;
    FBits:PCardinal;
    FBefore,FClip:TArray<TAlphaColor>;
    FTextPath,FTextBackgroundPath,FTextOpaqueRectPath,FTextClipPath,FTextNativeClipPath:ISkPath;
    FStrokePath:ISkPath;
    FTextRuns:TArray<TMetafileTextRun>;
    FDevicePixel:TPoint;
    FMapping:TMatrix;
    FNativeCommitted,FNativeDrawing,FAlphaBlend,FTextCommitted,FHandled,FNativeFailed,FForceNativeState,FInNativePath,FHasNativePath,FPathHasText,FProbe:Boolean;
    FDest:TRect;
    FRecordIndex:Cardinal;
    procedure RecordReady(Sender:TObject;ADC:HDC;ATable:Pointer;ARecord:PEnhMetaRecord;AObjects:Integer);
    procedure RecordComplete(Sender:TObject;ADC:HDC;ATable:Pointer;ARecord:PEnhMetaRecord;AObjects:Integer);
    procedure PrimitiveReady(Sender:TObject);
    procedure CommitNative;
    procedure DrawVector(const Path:ISkPath;const Paint:ISkPaint;DeviceCoordinates:Boolean=False);
    function BuildPath(const Points:TMetafilePointArray;const Counts:TMetafileIntegerArray;
      Closed:Boolean;EvenOdd:Boolean):ISkPath;
    function ReadTextPath:ISkPath;
    function TextRectangle(ADC:HDC;const Data:TBytes;Offset:Integer):ISkPath;
    function NativeTextClip(ADC:HDC):ISkPath;
    procedure CapturePolyText(ADC:HDC;ATable:Pointer;ARecord:PEnhMetaRecord;AObjects:Integer);
    function DecodeDIBImage(const Encoded:TBytes;out Info,Bits:TBytes):Boolean;
  public
    constructor Create(Target:TSkiaCanvas;Metafile:TMetafile;const Dest:TRectF);
    destructor Destroy;override;
    procedure Play(Metafile:TMetafile);
  end;

function MetafilePlayRecord(DC:HDC;Table,Rec:Pointer;Count:UINT):BOOL;stdcall;
  external 'gdi32.dll' name 'PlayEnhMetaFileRecord';
function MetafileAbortPath(DC:HDC):BOOL;stdcall;external 'gdi32.dll' name 'AbortPath';
function MetafileWidenPath(DC:HDC):BOOL;stdcall;external 'gdi32.dll' name 'WidenPath';
function MetafileGetPath(DC:HDC;Points,Types:Pointer;Count:Integer):Integer;stdcall;
  external 'gdi32.dll' name 'GetPath';
function MetafileCreateDIB(DC:HDC;Info:Pointer;Usage:UINT;Bits:Pointer;Section:THandle;Offset:DWORD):HBITMAP;stdcall;
  external 'gdi32.dll' name 'CreateDIBSection';
function MetafileSetWorldTransform(DC:HDC;Transform:Pointer):BOOL;stdcall;
  external 'gdi32.dll' name 'SetWorldTransform';
function MetafileLPtoDP(DC:HDC;Points:Pointer;Count:Integer):BOOL;stdcall;
  external 'gdi32.dll' name 'LPtoDP';
function MetafileGetRandomRgn(DC:HDC;Region:HRGN;Kind:Integer):Integer;stdcall;
  external 'gdi32.dll' name 'GetRandomRgn';
function MetafileGetRegionData(Region:HRGN;Size:DWORD;Data:Pointer):DWORD;stdcall;
  external 'gdi32.dll' name 'GetRegionData';
function MetafileGetCurrentPosition(DC:HDC;Position:Pointer):BOOL;stdcall;
  external 'gdi32.dll' name 'GetCurrentPositionEx';

constructor TMetafilePlayback.Create(Target:TSkiaCanvas;Metafile:TMetafile;const Dest:TRectF);
var Info:TBitmapInfo;Header:TEnhMetaHeader;Screen:HDC;XF:TXForm;
  SX,SY,Left,Top,Width,Height:Double;M:TMatrix;
begin
  inherited Create;FTarget:=Target;
  FParser:=TMetafileParser.Create;
  FReplay:=TMetafileRecordPlayer.Create;FReplay.ImageDecoder:=DecodeDIBImage;
  FParser.OnRecord:=RecordReady;FParser.OnRecordComplete:=RecordComplete;FParser.OnObjectPlay:=PrimitiveReady;
  { Native text paths retain recorded glyph indices, advances, alignment and OpenType layout. }
  FParser.ConvertTextToCurves:=False;
  FParser.StorePrimitives:=False;
  FParser.Flatness:=0.2;
  FDest:=Rect(Round(Dest.Left),Round(Dest.Top),Round(Dest.Right)-1,Round(Dest.Bottom)-1);
  { Match VCL TMetafile.Draw's inclusive EMF playback rectangle. }
  FillChar(Header,SizeOf(Header),0);
  if GetEnhMetaFileHeader(Metafile.Handle,SizeOf(Header),@Header)=0 then
    raise ESkiaCanvasError.Create(SSkiaMetafileBufferFailed);
  SX:=1;SY:=1;
  if Header.szlMillimeters.cx>0 then SX:=Header.szlDevice.cx/(Header.szlMillimeters.cx*100.0);
  if Header.szlMillimeters.cy>0 then SY:=Header.szlDevice.cy/(Header.szlMillimeters.cy*100.0);
  Left:=Header.rclFrame.Left*SX;Top:=Header.rclFrame.Top*SY;
  Width:=(Header.rclFrame.Right-Header.rclFrame.Left)*SX;
  Height:=(Header.rclFrame.Bottom-Header.rclFrame.Top)*SY;
  if (Abs(Width)<1E-9) or (Abs(Height)<1E-9) then Exit;
  M:=TMatrix.Identity;M.M11:=FDest.Width/Width;M.M22:=FDest.Height/Height;
  M.M31:=FDest.Left-Left*M.M11;M.M32:=FDest.Top-Top*M.M22;
  FMapping:=M*Target.FMatrix;
  Screen:=GetDC(0);
  if Screen<>0 then try FDC:=CreateCompatibleDC(Screen);finally ReleaseDC(0,Screen);end;
  if FDC=0 then raise ESkiaCanvasError.Create(SSkiaMetafileBufferFailed);
  FillChar(Info,SizeOf(Info),0);Info.bmiHeader.biSize:=SizeOf(Info.bmiHeader);
  Info.bmiHeader.biWidth:=Target.FDeviceWidth;Info.bmiHeader.biHeight:=-Target.FDeviceHeight;
  Info.bmiHeader.biPlanes:=1;Info.bmiHeader.biBitCount:=32;Info.bmiHeader.biCompression:=BI_RGB;
  FBitmap:=MetafileCreateDIB(FDC,@Info,DIB_RGB_COLORS,@FBits,0,0);
  if (FBitmap=0) or (FBits=nil) then raise ESkiaCanvasError.Create(SSkiaMetafileBufferFailed);
  FPreviousBitmap:=SelectObject(FDC,FBitmap);
  SetGraphicsMode(FDC,GM_ADVANCED);
  XF.eM11:=Target.FMatrix.M11;XF.eM12:=Target.FMatrix.M12;
  XF.eM21:=Target.FMatrix.M21;XF.eM22:=Target.FMatrix.M22;
  XF.eDx:=Target.FMatrix.M31;XF.eDy:=Target.FMatrix.M32;
  if not MetafileSetWorldTransform(FDC,@XF) then raise ESkiaCanvasError.Create(SSkiaMetafileBufferFailed);
  FClip:=Target.ClipPixels;
end;

destructor TMetafilePlayback.Destroy;
begin
  FParser.Free;
  FReplay.Free;
  if FDC<>0 then begin
    if FPreviousBitmap<>0 then SelectObject(FDC,FPreviousBitmap);
    DeleteDC(FDC);
  end;
  if FBitmap<>0 then DeleteObject(FBitmap);
  inherited;
end;

procedure TMetafilePlayback.Play(Metafile:TMetafile);
var Saved:Integer;
begin
  if FDC=0 then Exit;
  { Preflight before painting. A noncanonical source keeps consistent native
    rasterization from its first record, including inputs to later ROPs. }
  Saved:=SaveDC(FDC);FProbe:=True;FRecordIndex:=0;
  try
    if not FParser.LoadFromMetafile(Metafile,FDC,@FDest) then
      raise ESkiaCanvasError.CreateFmt(SSkiaMetafilePlaybackFailed,[FParser.LastError]);
  finally
    RestoreDC(FDC,Saved);MetafileAbortPath(FDC);FProbe:=False;
    FInNativePath:=False;FHasNativePath:=False;FPathHasText:=False;
    FRecordIndex:=0;
  end;
  if not FParser.LoadFromMetafile(Metafile,FDC,@FDest) then
    raise ESkiaCanvasError.CreateFmt(SSkiaMetafilePlaybackFailed,[FParser.LastError]);
end;

function TMetafilePlayback.DecodeDIBImage(const Encoded:TBytes;out Info,Bits:TBytes):Boolean;
var Image:ISkImage;Header:PBitmapInfoHeader;
begin
  Result:=False;Info:=nil;Bits:=nil;
  Image:=TSkImage.MakeFromEncoded(Encoded);
  if (Image=nil) or (Image.Width<=0) or (Image.Height<=0) or
    (UInt64(Image.Width)*Cardinal(Image.Height)>High(Integer) div 4) then Exit;
  SetLength(Info,40);Header:=PBitmapInfoHeader(@Info[0]);
  Header.biSize:=40;Header.biWidth:=Image.Width;Header.biHeight:=-Image.Height;
  Header.biPlanes:=1;Header.biBitCount:=32;Header.biCompression:=BI_RGB;
  Header.biSizeImage:=Image.Width*Image.Height*4;
  SetLength(Bits,Header.biSizeImage);
  Result:=Image.ReadPixels(TSkImageInfo.Create(Image.Width,Image.Height,TSkColorType.BGRA8888,
    TSkAlphaType.Unpremul),Pointer(Bits),Image.Width*4);
end;

function TMetafilePlayback.BuildPath(const Points:TMetafilePointArray;const Counts:TMetafileIntegerArray;
  Closed:Boolean;EvenOdd:Boolean):ISkPath;
var Builder:ISkPathBuilder;Offset,I,J,N,Last:Integer;CloseContour:Boolean;
begin
  Builder:=TSkPathBuilder.Create;
  if EvenOdd then Builder.FillType:=TSkPathFillType.EvenOdd;
  Offset:=0;
  for I:=0 to High(Counts) do begin
    N:=Counts[I];
    if (N<0) or (N>Length(Points)-Offset) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
    if N>0 then begin
      Builder.MoveTo(Points[Offset].X,Points[Offset].Y);
      Last:=N-1;CloseContour:=Closed;
      if (N>1) and (Points[Offset].X=Points[Offset+Last].X) and
        (Points[Offset].Y=Points[Offset+Last].Y) then begin Dec(Last);CloseContour:=True;end;
      for J:=1 to Last do Builder.LineTo(Points[Offset+J].X,Points[Offset+J].Y);
      if CloseContour then Builder.Close;
    end;
    Inc(Offset,N);
  end;
  Result:=Builder.Snapshot;
end;

function TMetafilePlayback.ReadTextPath:ISkPath;
var Points:TArray<TPoint>;Kinds:TArray<Byte>;N,I,Saved:Integer;Builder:ISkPathBuilder;XF:TXForm;
begin
  Result:=nil;Saved:=SaveDC(FDC);
  try
    SetMapMode(FDC,MM_TEXT);SetWindowOrgEx(FDC,0,0,nil);SetViewportOrgEx(FDC,0,0,nil);
    FillChar(XF,SizeOf(XF),0);XF.eM11:=1;XF.eM22:=1;MetafileSetWorldTransform(FDC,@XF);
    N:=MetafileGetPath(FDC,nil,nil,0);if N<=0 then Exit;
    SetLength(Points,N);SetLength(Kinds,N);
    if MetafileGetPath(FDC,@Points[0],@Kinds[0],N)<>N then Exit;
    Builder:=TSkPathBuilder.Create;Builder.FillType:=TSkPathFillType.Winding;I:=0;
    while I<N do begin
      case Kinds[I] and not PT_CLOSEFIGURE of
        PT_MOVETO:Builder.MoveTo(Points[I].X,Points[I].Y);
        PT_LINETO:Builder.LineTo(Points[I].X,Points[I].Y);
        PT_BEZIERTO:begin
          if I+2>=N then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
          Builder.CubicTo(Points[I].X,Points[I].Y,Points[I+1].X,Points[I+1].Y,Points[I+2].X,Points[I+2].Y);
          Inc(I,2);
        end;
      end;
      if Kinds[I] and PT_CLOSEFIGURE<>0 then Builder.Close;
      Inc(I);
    end;
    Result:=Builder.Snapshot;
  finally RestoreDC(FDC,Saved);MetafileAbortPath(FDC);end;
end;

function TMetafilePlayback.NativeTextClip(ADC:HDC):ISkPath;
var Region:HRGN;Status:Integer;Size,Count,I:Cardinal;Data:TBytes;R:TRect;Builder:ISkPathBuilder;
begin
  Result:=nil;Region:=CreateRectRgn(0,0,0,0);
  try
    { APIRGN is the effective application + metafile clipping region, in device units. }
    Status:=MetafileGetRandomRgn(ADC,Region,3);
    if Status=0 then Exit;
    if Status<>1 then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
    Size:=MetafileGetRegionData(Region,0,nil);
    if (Size<32) or (Size>Cardinal(MaxInt)) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
    SetLength(Data,Size);
    if MetafileGetRegionData(Region,Size,@Data[0])<>Size then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
    Count:=PCardinal(@Data[8])^;
    if Count>(Size-32) div SizeOf(R) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
    Builder:=TSkPathBuilder.Create;
    if Count>0 then for I:=0 to Count-1 do begin
      Move(Data[32+I*SizeOf(R)],R,SizeOf(R));
      Builder.AddRect(RectF(R.Left,R.Top,R.Right,R.Bottom));
    end;
    Result:=Builder.Detach;
  finally DeleteObject(Region);end;
end;

function TMetafilePlayback.TextRectangle(ADC:HDC;const Data:TBytes;Offset:Integer):ISkPath;
var R:TRect;Points:array[0..3] of TPoint;Builder:ISkPathBuilder;I:Integer;
begin
  Result:=nil;
  if (Offset<0) or (Offset>Length(Data)-SizeOf(R)) then Exit;
  Move(Data[Offset],R,SizeOf(R));
  Points[0]:=Point(R.Left,R.Top);Points[1]:=Point(R.Right,R.Top);
  Points[2]:=Point(R.Right,R.Bottom);Points[3]:=Point(R.Left,R.Bottom);
  if not MetafileLPtoDP(ADC,@Points[0],4) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
  Builder:=TSkPathBuilder.Create;Builder.MoveTo(Points[0].X,Points[0].Y);
  for I:=1 to 3 do Builder.LineTo(Points[I].X,Points[I].Y);
  Builder.Close;Result:=Builder.Detach;
end;

procedure TMetafilePlayback.CapturePolyText(ADC:HDC;ATable:Pointer;ARecord:PEnhMetaRecord;AObjects:Integer);
var Source,Data:TBytes;Count,I,Offset,N,CharSize,TextSize,DxSize,TextEnd,Saved,RunSaved,Bk:Integer;
  Options,TextOffset,DxOffset:Cardinal;Next:TPoint;Run:TMetafileTextRun;Builder:ISkPathBuilder;
begin
  SetLength(Source,ARecord.nSize);Move(ARecord^,Source[0],ARecord.nSize);
  if Length(Source)<40 then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
  Count:=PInteger(@Source[36])^;
  if (Count<0) or (Count>(Length(Source)-40) div 40) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
  Saved:=SaveDC(ADC);Bk:=GetBkMode(ADC);
  try
    for I:=0 to Count-1 do begin
      Offset:=40+I*40;N:=PCardinal(@Source[Offset+8])^;Options:=PCardinal(@Source[Offset+16])^;
      CharSize:=1;if (ARecord.iType=97) or (Options and ETO_GLYPH_INDEX<>0) then CharSize:=2;
      if (N<0) or (N>Length(Source) div CharSize) or (N>MaxInt div 8) then
        raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
      TextSize:=N*CharSize;TextOffset:=PCardinal(@Source[Offset+12])^;DxOffset:=PCardinal(@Source[Offset+36])^;
      DxSize:=0;if DxOffset<>0 then begin DxSize:=N*4;if Options and $2000<>0 then DxSize:=DxSize*2;end;
      if (TextOffset>Cardinal(Length(Source))) or (TextSize>Length(Source)-Integer(TextOffset)) or
        (DxOffset>Cardinal(Length(Source))) or (DxSize>Length(Source)-Integer(DxOffset)) then
        raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
      TextEnd:=76+((TextSize+3) and not 3);
      if DxSize>MaxInt-TextEnd then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
      SetLength(Data,TextEnd+DxSize);FillChar(Data[0],Length(Data),0);
      PCardinal(@Data[0])^:=ARecord.iType-13;PCardinal(@Data[4])^:=Length(Data);
      Move(Source[8],Data[8],28);Move(Source[Offset],Data[36],40);
      PCardinal(@Data[48])^:=76;PCardinal(@Data[72])^:=0;
      if TextSize>0 then Move(Source[TextOffset],Data[76],TextSize);
      if DxSize>0 then begin Move(Source[DxOffset],Data[TextEnd],DxSize);PCardinal(@Data[72])^:=TextEnd;end;
      Run.Glyphs:=nil;Run.Background:=nil;Run.OpaqueRect:=nil;Run.Clip:=nil;
      if Options and ETO_OPAQUE<>0 then Run.OpaqueRect:=TextRectangle(ADC,Data,56);
      if Options and ETO_CLIPPED<>0 then Run.Clip:=TextRectangle(ADC,Data,56);
      PCardinal(@Data[52])^:=Options and not (ETO_OPAQUE or ETO_CLIPPED);
      RunSaved:=SaveDC(ADC);
      try
        SetBkMode(ADC,TRANSPARENT);
        if not BeginPath(ADC) or not MetafilePlayRecord(ADC,ATable,@Data[0],AObjects) or not EndPath(ADC) then
          raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
        Run.Glyphs:=ReadTextPath;
        if not MetafileGetCurrentPosition(ADC,@Next) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
        if Bk=OPAQUE then begin
          RestoreDC(ADC,RunSaved);RunSaved:=SaveDC(ADC);SetBkMode(ADC,OPAQUE);
          if not BeginPath(ADC) or not MetafilePlayRecord(ADC,ATable,@Data[0],AObjects) or not EndPath(ADC) then
            raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
          Run.Background:=ReadTextPath;
        end;
      finally RestoreDC(ADC,RunSaved);MetafileAbortPath(ADC);end;
      if not MoveToEx(ADC,Next.X,Next.Y,nil) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
      SetLength(FTextRuns,Length(FTextRuns)+1);FTextRuns[High(FTextRuns)]:=Run;
    end;
    { Empty outlines are valid for clipped/space-only runs. The run array owns
      the per-string paths; these sentinels keep the vector dispatch active. }
    Builder:=TSkPathBuilder.Create;FTextPath:=Builder.Detach;FTextBackgroundPath:=FTextPath;
  finally RestoreDC(ADC,Saved);MetafileAbortPath(ADC);end;
end;

function ExpandSmallTextRecord(const Source:TBytes):TBytes;
var Count,Options,Offset,CharSize,TextSize:Cardinal;
begin
  Result:=nil;
  if Length(Source)<36 then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
  Count:=PCardinal(@Source[16])^;Options:=PCardinal(@Source[20])^;Offset:=36;
  CharSize:=2;if Options and $200<>0 then CharSize:=1;
  if Options and $100=0 then Inc(Offset,16);
  if (Offset>Cardinal(Length(Source))) or (Count>(Cardinal(Length(Source))-Offset) div CharSize) then
    raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
  TextSize:=Count*CharSize;SetLength(Result,76+((TextSize+3) and not 3));FillChar(Result[0],Length(Result),0);
  PCardinal(@Result[0])^:=84;if CharSize=1 then PCardinal(@Result[0])^:=83;
  PCardinal(@Result[4])^:=Length(Result);Move(Source[24],Result[24],12);Move(Source[8],Result[36],8);
  PCardinal(@Result[44])^:=Count;PCardinal(@Result[48])^:=76;
  PCardinal(@Result[52])^:=Options and not ($100 or $200);
  if Options and $100=0 then Move(Source[36],Result[56],16);
  if TextSize>0 then Move(Source[Offset],Result[76],TextSize);
end;

procedure TMetafilePlayback.RecordReady(Sender:TObject;ADC:HDC;ATable:Pointer;ARecord:PEnhMetaRecord;AObjects:Integer);
var I,W,H,Saved,Bk,J,Count:Integer;A,Value:Cardinal;TextRecord:Boolean;CopyRecord:TBytes;Rec:PEnhMetaRecord;XF:TXForm;
begin
  Inc(FRecordIndex);
  FNativeCommitted:=False;FTextCommitted:=False;FHandled:=False;FNativeFailed:=False;
  FTextPath:=nil;FTextBackgroundPath:=nil;FTextOpaqueRectPath:=nil;FTextClipPath:=nil;
  FTextNativeClipPath:=nil;
  FStrokePath:=nil;
  FTextRuns:=nil;
  if (ARecord.iType=15) and not FProbe then begin
    Move(PByte(ARecord)[8],FDevicePixel,SizeOf(FDevicePixel));
    if not MetafileLPtoDP(ADC,@FDevicePixel,1) then FDevicePixel:=Point(-2,-2);
  end;
  FAlphaBlend:=ARecord.iType=114;
  FNativeDrawing:=False;
  case ARecord.iType of
    2..8,15,41..47,53..56,62..64,71..74,76..81,83..92,96,97,108,114,116,118:FNativeDrawing:=True;
  end;
  if FNativeDrawing and not FProbe then begin
    W:=FTarget.FDeviceWidth;H:=FTarget.FDeviceHeight;
    SetLength(FBefore,W*H);
    if not FTarget.FBacking.ReadPixels(TSkImageInfo.Create(W,H,TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul),Pointer(FBefore),W*4) then raise ESkiaCanvasError.Create(SSkiaImagePixelsUnavailable);
    for I:=0 to High(FBefore) do begin
      if FAlphaBlend then begin
        A:=FBefore[I] shr 24;Value:=A shl 24;
        for J:=0 to 2 do Value:=Value or (((((FBefore[I] shr (J*8)) and 255)*A+127) div 255) shl (J*8));
        FBits[I]:=Value;
      end else FBits[I]:=(FBefore[I] and $FFFFFF) or $7F000000;
    end;
  end;
  TextRecord:=ARecord.iType in [83,84,96,97,108];
  if not FProbe and not FForceNativeState and not FHasNativePath and not FInNativePath and
    (ARecord.iType in [2..8,41..47,54..56,85..92]) and GetWorldTransform(ADC,XF) and
    ((Abs(XF.eM11*XF.eM21+XF.eM12*XF.eM22)>1E-5) or
     (Abs(Sqr(XF.eM11)+Sqr(XF.eM12)-Sqr(XF.eM21)-Sqr(XF.eM22))>1E-5)) then begin
    { A scalar stroke width cannot describe a sheared or anisotropic pen.
      Capture GDI's widened contour before replay advances the current point. }
    Saved:=SaveDC(ADC);
    try
      if BeginPath(ADC) and MetafilePlayRecord(ADC,ATable,ARecord,AObjects) and EndPath(ADC) and
        MetafileWidenPath(ADC) then FStrokePath:=ReadTextPath;
    finally RestoreDC(ADC,Saved);MetafileAbortPath(ADC);end;
  end;
  if TextRecord and FInNativePath then FPathHasText:=True;
  if TextRecord and not FHasNativePath and not FProbe and not FForceNativeState then begin
    FTextNativeClipPath:=NativeTextClip(ADC);
    if ARecord.iType in [96,97] then CapturePolyText(ADC,ATable,ARecord,AObjects)
    else begin
    Saved:=SaveDC(ADC);Bk:=SetBkMode(ADC,TRANSPARENT);
    try
      SetLength(CopyRecord,ARecord.nSize);Move(ARecord^,CopyRecord[0],ARecord.nSize);
      if ARecord.iType=108 then CopyRecord:=ExpandSmallTextRecord(CopyRecord);
      Rec:=PEnhMetaRecord(@CopyRecord[0]);
      { EXTTEXTOUT's fOptions is a fixed DWORD at byte 52 in both A and W records. }
      if (Rec.iType in [83,84]) and (Length(CopyRecord)>=76) then begin
        Value:=PCardinal(@CopyRecord[52])^;
        if Value and ETO_OPAQUE<>0 then FTextOpaqueRectPath:=TextRectangle(ADC,CopyRecord,56);
        if Value and ETO_CLIPPED<>0 then FTextClipPath:=TextRectangle(ADC,CopyRecord,56);
        { GetPath is independent of the GDI clipping region. Apply the recorded
          clipping quadrilateral explicitly after capturing glyph outlines. }
        PCardinal(@CopyRecord[52])^:=Value and not (ETO_OPAQUE or ETO_CLIPPED);
      end;
      if (ARecord.iType in [96,97]) and (Length(CopyRecord)>=40) then begin
        Count:=PCardinal(@CopyRecord[36])^;
        if (Count>=0) and (Count<=(Length(CopyRecord)-40) div 40) then
          for J:=0 to Count-1 do PCardinal(@CopyRecord[56+J*40])^:=PCardinal(@CopyRecord[56+J*40])^ and not ETO_OPAQUE;
      end;
      if not BeginPath(ADC) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
      if not MetafilePlayRecord(ADC,ATable,Rec,AObjects) then
        raise ESkiaCanvasError.CreateFmt(SSkiaMetafileGdiFailed,[ARecord.iType]);
      if not EndPath(ADC) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
      FTextPath:=ReadTextPath;
      if Bk=OPAQUE then begin
        { GDI records the character-cell background in opaque text paths.
          Capture it separately so neither the background nor glyphs need a bitmap. }
        RestoreDC(ADC,Saved);Saved:=SaveDC(ADC);
        SetBkMode(ADC,OPAQUE);
        if not BeginPath(ADC) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
        if not MetafilePlayRecord(ADC,ATable,Rec,AObjects) then
          raise ESkiaCanvasError.CreateFmt(SSkiaMetafileGdiFailed,[ARecord.iType]);
        if not EndPath(ADC) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
        FTextBackgroundPath:=ReadTextPath;
      end;
    finally RestoreDC(ADC,Saved);SetBkMode(ADC,Bk);end;
    end;
  end;
  FNativeFailed:=not FReplay.Play(ADC,ATable,ARecord,AObjects);
  if FNativeFailed then
    raise ESkiaCanvasError.CreateFmt(SMetafileRecordPlaybackFailed,[ARecord.iType,FRecordIndex,FReplay.ErrorCode]);
  { Keep one rasterizer after compatibility recovery: later destination-dependent
    records must see the exact GDI pixels, including thin pen edges. }
  if FReplay.Recovery<>mrrNone then FForceNativeState:=True;
  if ARecord.iType=59 then begin FInNativePath:=True;FHasNativePath:=True;FPathHasText:=False;end;
  if ARecord.iType in [60,68] then FInNativePath:=False;
  if (ARecord.iType=67) and FPathHasText then FForceNativeState:=True;
  GdiFlush;
end;

procedure TMetafilePlayback.RecordComplete(Sender:TObject;ADC:HDC;ATable:Pointer;ARecord:PEnhMetaRecord;AObjects:Integer);
var Position:TPoint;
begin
  { Preserve native drawing records for which the parser emits no vector primitive. }
  if FNativeDrawing and not FHandled and not FNativeFailed and not FProbe then CommitNative;
  if (ARecord.iType in [83,84,96,97,108]) and (GetTextAlign(ADC) and TA_UPDATECP<>0) then begin
    if not MetafileGetCurrentPosition(ADC,@Position) then raise ESkiaCanvasError.Create(SSkiaInvalidGdiTextPath);
    FParser.SynchronizeCurrentPosition(Position);
  end;
  if ARecord.iType in [62,63,64,67,68] then begin FPathHasText:=False;FHasNativePath:=False;end;
end;

procedure TMetafilePlayback.CommitNative;
var Patch:TArray<TAlphaColor>;I,J,OldAlpha,NewAlpha,SourceAlpha,Channel:Integer;Value,Source:Cardinal;
begin
  if FNativeCommitted or not FNativeDrawing then Exit;
  SetLength(Patch,Length(FBefore));
  for I:=0 to High(Patch) do begin
    Value:=FBits[I];
    if FAlphaBlend then begin
      OldAlpha:=FBefore[I] shr 24;NewAlpha:=Value shr 24;
      if (OldAlpha=255) and ((Value and $FFFFFF)=(FBefore[I] and $FFFFFF)) then Continue;
      if OldAlpha=255 then Source:=(Value and $FFFFFF) or $FF000000
      else begin
        SourceAlpha:=0;
        if NewAlpha>=OldAlpha then SourceAlpha:=Math.Min(255,((NewAlpha-OldAlpha)*255+(255-OldAlpha) div 2) div (255-OldAlpha));
        Source:=Cardinal(SourceAlpha) shl 24;
        if SourceAlpha>0 then for J:=0 to 2 do begin
          Channel:=Integer((Value shr (J*8)) and 255)-
            Integer((Integer((FBefore[I] shr (J*8)) and 255)*OldAlpha*(255-SourceAlpha)+32512) div 65025);
          Channel:=Math.Max(0,Math.Min(255,(Channel*255+SourceAlpha div 2) div SourceAlpha));
          Source:=Source or (Cardinal(Channel) shl (J*8));
        end;
      end;
      if Source shr 24>0 then Patch[I]:=(Source and $FFFFFF) or
        (Cardinal(((Source shr 24)*(FClip[I] shr 24)+127) div 255) shl 24);
      Continue;
    end;
    if ((Value and $FFFFFF)<>(FBefore[I] and $FFFFFF)) or
      ((Value shr 24<>$7F) and (FBefore[I] shr 24<>255)) then
      Patch[I]:=(Value and $FFFFFF) or (FClip[I] and $FF000000);
  end;
  FTarget.CommitPatch(Patch,FTarget.FDeviceWidth,FTarget.FDeviceHeight);
  FNativeCommitted:=True;
end;

procedure TMetafilePlayback.DrawVector(const Path:ISkPath;const Paint:ISkPaint;DeviceCoordinates:Boolean);
  procedure DrawTo(const Canvas:ISkCanvas);
  begin
    Canvas.Save;
    try
      FTarget.ApplyClips(Canvas);
      if DeviceCoordinates then Canvas.ResetMatrix;
      Canvas.DrawPath(Path,Paint);
    finally Canvas.Restore;end;
  end;
begin
  DrawTo(FTarget.FCanvas);
  if not FTarget.FBackingIsOutput then DrawTo(FTarget.FBacking.GetCanvas);
end;

procedure TMetafilePlayback.PrimitiveReady(Sender:TObject);
var P:TMetafilePrimitive;Path:ISkPath;ClipBuilder:ISkPathBuilder;Paint:ISkPaint;Saved,I,RunSaved,X,Y,Candidate:Integer;Intervals:TArray<Single>;
  Native,DeviceStroke,Painted:Boolean;XF:TXForm;Value:Cardinal;
  function PixelChanged(AIndex:Integer):Boolean;
  begin
    Value:=FBits[AIndex];
    Result:=((Value and $FFFFFF)<>(FBefore[AIndex] and $FFFFFF)) or
      ((Value shr 24<>$7F) and (FBefore[AIndex] shr 24<>255));
  end;
begin
  if FProbe then Exit;
  FHandled:=True;
  P:=FParser.Current;
  if FNativeFailed then Exit;
  if P.SourceRecordType=15 then begin
    if FForceNativeState then begin CommitNative;Exit;end;
    I:=-1;
    { Win32 GDI's SETPIXELV and LPtoDP can round adjacent device pixels.
      Read the pixel actually changed by native replay, not the estimate. }
    if (FDevicePixel.X>=-1) and (FDevicePixel.Y>=-1) and (FDevicePixel.X<=FTarget.FDeviceWidth) and
      (FDevicePixel.Y<=FTarget.FDeviceHeight) then
      for Y:=Math.Max(0,FDevicePixel.Y-1) to Math.Min(FTarget.FDeviceHeight-1,FDevicePixel.Y+1) do begin
        for X:=Math.Max(0,FDevicePixel.X-1) to Math.Min(FTarget.FDeviceWidth-1,FDevicePixel.X+1) do begin
          Candidate:=Y*FTarget.FDeviceWidth+X;
          if PixelChanged(Candidate) then begin I:=Candidate;Break;end;
        end;
        if I>=0 then Break;
      end;
    if I<0 then for Candidate:=0 to High(FBefore) do
      if PixelChanged(Candidate) then begin I:=Candidate;Break;end;
    if I<0 then Exit;
    FDevicePixel:=Point(I mod FTarget.FDeviceWidth,I div FTarget.FDeviceWidth);Value:=FBits[I];
    { SETPIXELV paints one device pixel even under a scaled logical map.
      Use a solid unit rectangle, avoiding PDF image interpolation. }
    ClipBuilder:=TSkPathBuilder.Create;
    ClipBuilder.AddRect(RectF(FDevicePixel.X,FDevicePixel.Y,FDevicePixel.X+1,FDevicePixel.Y+1));
    Paint:=TSkPaint.Create;Paint.Color:=TAlphaColor($FF000000 or (Value and $FFFFFF));Paint.AntiAlias:=False;
    DrawVector(ClipBuilder.Detach,Paint,True);Exit;
  end;
  if FInNativePath or ((P.Kind=mpkText) and FTextCommitted) then Exit;
  if (P.Kind=mpkText) and (FTextClipPath<>nil) then begin
    { Capturing an unclipped outline must not revive a native fully clipped
      text record. The actual GDI replay has already updated its current point. }
    Painted:=False;
    for I:=0 to High(FBefore) do begin
      Value:=FBits[I];
      if ((Value and $FFFFFF)<>(FBefore[I] and $FFFFFF)) or
        ((Value shr 24<>$7F) and (FBefore[I] shr 24<>255)) then begin Painted:=True;Break;end;
    end;
    if not Painted then Exit;
  end;
  Native:=FForceNativeState or (P.SourceRecordType in [15,62,63,64]) or (P.Kind=mpkImage) or (P.SourceRecordType in [71,72,73,74]) or
    ((P.Kind=mpkText) and ((FTextPath=nil) or
      ((P.TextStyle.BkMode=OPAQUE) and (FTextBackgroundPath=nil)))) or
    (P.Fill.Visible and ((P.Fill.Kind<>mfkSolid) or (P.Fill.RasterOperation2<>R2_COPYPEN))) or
    (P.Stroke.Visible and ((P.Stroke.Brush.Kind<>mbdkNone) or (P.Stroke.BrushStyle<>BS_SOLID) or
      (P.Stroke.Style and $F=PS_USERSTYLE) or (P.Stroke.Style and $F=PS_INSIDEFRAME) or (P.Stroke.RasterOperation2<>R2_COPYPEN)));
  { GDI cosmetic pens use discrete device pixels, including under rotated maps. }
  if P.Stroke.Visible and P.Stroke.Hairline and GetWorldTransform(FDC,XF) then
    Native:=Native or (Abs(XF.eM12)>1E-6) or (Abs(XF.eM21)>1E-6);
  if Native then begin CommitNative;Exit;end;
  Saved:=FTarget.SaveState;
  try
    FTarget.SetWorldTransform(FMapping);
    if (P.Kind=mpkText) and (FTextNativeClipPath<>nil) then
      FTarget.AppendClip(FTextNativeClipPath,TSkClipOp.Intersect)
    else if P.Clip.Active then begin
      Path:=BuildPath(P.Clip.Points,P.Clip.PointCounts,True,False);
      FTarget.AppendClip(Path.Transform(FMapping),TSkClipOp.Intersect);
    end;
    if P.Kind=mpkText then begin
      FTextCommitted:=True;
      if Length(FTextRuns)>0 then begin
        for I:=0 to High(FTextRuns) do begin
          RunSaved:=FTarget.SaveState;
          try
            Paint:=TSkPaint.Create;Paint.Color:=ColorToAlphaColor(P.TextStyle.BkColor);
            if FTextRuns[I].OpaqueRect<>nil then DrawVector(FTextRuns[I].OpaqueRect,Paint,True);
            if FTextRuns[I].Clip<>nil then FTarget.AppendClip(FTextRuns[I].Clip,TSkClipOp.Intersect);
            if FTextRuns[I].Background<>nil then DrawVector(FTextRuns[I].Background,Paint,True);
            Paint.Color:=ColorToAlphaColor(P.TextStyle.Color);Paint.AntiAlias:=True;
            if FTextRuns[I].Glyphs<>nil then DrawVector(FTextRuns[I].Glyphs,Paint,True);
          finally FTarget.RestoreState(RunSaved);end;
        end;
        Exit;
      end;
      if FTextOpaqueRectPath<>nil then begin
        Paint:=TSkPaint.Create;Paint.Color:=ColorToAlphaColor(P.TextStyle.BkColor);
        DrawVector(FTextOpaqueRectPath,Paint,True);
      end else if P.TextStyle.Options and ETO_OPAQUE<>0 then begin
        Paint:=TSkPaint.Create;Paint.Color:=ColorToAlphaColor(P.TextStyle.BkColor);
        ClipBuilder:=TSkPathBuilder.Create;
        ClipBuilder.AddRect(RectF(P.TextStyle.Bounds.Left,P.TextStyle.Bounds.Top,
          P.TextStyle.Bounds.Right,P.TextStyle.Bounds.Bottom));
        DrawVector(ClipBuilder.Snapshot,Paint);
      end;
      if FTextClipPath<>nil then FTarget.AppendClip(FTextClipPath,TSkClipOp.Intersect)
      else if P.TextStyle.Options and ETO_CLIPPED<>0 then begin
        ClipBuilder:=TSkPathBuilder.Create;ClipBuilder.AddRect(RectF(P.TextStyle.Bounds.Left,P.TextStyle.Bounds.Top,P.TextStyle.Bounds.Right,P.TextStyle.Bounds.Bottom));Path:=ClipBuilder.Snapshot;
        FTarget.AppendClip(Path.Transform(FMapping),TSkClipOp.Intersect);
      end;
      if FTextBackgroundPath<>nil then begin
        Paint:=TSkPaint.Create;Paint.Color:=ColorToAlphaColor(P.TextStyle.BkColor);
        DrawVector(FTextBackgroundPath,Paint,True);
      end;
      Paint:=TSkPaint.Create;Paint.Color:=ColorToAlphaColor(P.TextStyle.Color);Paint.AntiAlias:=True;
      DrawVector(FTextPath,Paint,True);
      Exit;
    end;
    Path:=BuildPath(P.Points,P.PointCounts,P.Kind=mpkPolygon,P.Fill.FillMode=ALTERNATE);
    if P.Fill.Visible then begin
        Paint:=TSkPaint.Create;Paint.Style:=TSkPaintStyle.Fill;
        Paint.Color:=ColorToAlphaColor(P.Fill.Color);Paint.AntiAlias:=True;
        DrawVector(Path,Paint);
      end;
      if P.Stroke.Visible then begin
        Paint:=TSkPaint.Create;Paint.Style:=TSkPaintStyle.Stroke;
        Paint.Color:=ColorToAlphaColor(P.Stroke.Color);Paint.AntiAlias:=True;
        if FStrokePath<>nil then begin
          Paint.Style:=TSkPaintStyle.Fill;DrawVector(FStrokePath,Paint,True);Exit;
        end;
        DeviceStroke:=P.Stroke.Hairline;
        if DeviceStroke then Paint.AntiAlias:=False;
        if DeviceStroke then begin Path:=Path.Transform(FMapping);Paint.StrokeWidth:=1;end
        else Paint.StrokeWidth:=P.Stroke.Width;
        Paint.StrokeMiter:=P.Stroke.MiterLimit;
        case P.Stroke.EndCap of PS_ENDCAP_SQUARE:Paint.StrokeCap:=TSkStrokeCap.Square;
          PS_ENDCAP_FLAT:Paint.StrokeCap:=TSkStrokeCap.Butt;else Paint.StrokeCap:=TSkStrokeCap.Round;end;
        case P.Stroke.Join of PS_JOIN_BEVEL:Paint.StrokeJoin:=TSkStrokeJoin.Bevel;
          PS_JOIN_MITER:Paint.StrokeJoin:=TSkStrokeJoin.Miter;else Paint.StrokeJoin:=TSkStrokeJoin.Round;end;
        Intervals:=DashIntervalsForStyle(P.Stroke.PenStyle,Paint.StrokeWidth,nil);
        if Length(Intervals)>0 then Paint.PathEffect:=TSkPathEffect.MakeDash(Intervals,0);
        if DeviceStroke or (Length(Intervals)>0) then begin
          { Export hairlines and dashes as actual contours for consistent PDF/SVG output. }
          Path:=Paint.GetFillPath(Path);Paint.PathEffect:=nil;Paint.Style:=TSkPaintStyle.Fill;
        end;
        DrawVector(Path,Paint,DeviceStroke);
      end;
  finally FTarget.RestoreState(Saved);end;
end;

procedure TSkiaCanvas.DrawMetafile(Graphic:TMetafile;const Dest:TRectF);
var Player:TMetafilePlayback;
begin
  if (Graphic=nil) or Graphic.Empty or FRecordingClosed or (Dest.Width=0) or (Dest.Height=0) then Exit;
  Player:=TMetafilePlayback.Create(Self,Graphic,Dest);
  try Player.Play(Graphic);finally Player.Free;end;
end;
