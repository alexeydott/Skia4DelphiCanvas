type
  TReviewLimitProbe = class
    TextCallbacks:Integer;
    procedure RecordReady(Sender:TObject;DC:HDC;Table:Pointer;RecordData:PEnhMetaRecord;Objects:Integer);
  end;
procedure TReviewLimitProbe.RecordReady(Sender:TObject;DC:HDC;Table:Pointer;RecordData:PEnhMetaRecord;Objects:Integer);
begin
  if RecordData.iType in [83,84,96,97,108] then Inc(TextCallbacks);
end;

function TestEmfAlphaBlend(Dest:HDC;X,Y,W,H:Integer;Source:HDC;SX,SY,SW,SH:Integer;Blend:Cardinal):BOOL;stdcall;
  external 'msimg32.dll' name 'AlphaBlend';

procedure TestEmfAlphaAndOpacity;
var Meta:TMetafile;Writer:TMetafileCanvas;Source:TBitmap;Canvas,Layer:TSkiaBitmapCanvas;
  X,Y:Integer;Row:PCardinal;Pixels:TArray<TAlphaColor>;Image:ISkImage;
  function PixelAlpha(Target:TSkiaBitmapCanvas):Integer;
  begin
    Image:=Target.Snapshot;SetLength(Pixels,32*32);
    Image.ReadPixels(TSkImageInfo.Create(32,32,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),32*4);
    Result:=Pixels[5*32+5] shr 24;
  end;
begin
  Meta:=TMetafile.Create;Source:=TBitmap.Create;Canvas:=TSkiaBitmapCanvas.Create(32,32);Layer:=TSkiaBitmapCanvas.Create(32,32);
  try
    Source.PixelFormat:=pf32bit;Source.SetSize(20,20);
    for Y:=0 to 19 do begin Row:=Source.ScanLine[Y];for X:=0 to 19 do Row[X]:=$80800000;end;
    Meta.Width:=32;Meta.Height:=32;Writer:=TMetafileCanvas.Create(Meta,0);
    try
      Check(TestEmfAlphaBlend(Writer.Handle,2,2,20,20,Source.Canvas.Handle,0,0,20,20,$01FF0000),'EMF alpha record creation');
    finally Writer.Free;end;
    Canvas.Draw(0,0,Meta);Check(Abs(PixelAlpha(Canvas)-128)<=1,'EMF AlphaBlend preserves transparent destination alpha');
    Canvas.Draw(0,0,Meta);Check(Abs(PixelAlpha(Canvas)-192)<=2,'EMF AlphaBlend composes over partial destination alpha');
    Layer.Draw(0,0,Meta,128);Check(Abs(PixelAlpha(Layer)-64)<=1,'EMF Draw opacity applies to the complete source graphic');
  finally Layer.Free;Canvas.Free;Source.Free;Meta.Free;end;
end;

procedure TestEmfPendingPath;
var Meta:TMetafile;Writer:TMetafileCanvas;Canvas:TSkiaBitmapCanvas;Image:ISkImage;Bitmap:TBitmap;
  Pixels:TArray<TAlphaColor>;Mode:Integer;Ink,Bad:Integer;I,X,Y:Integer;Row:PCardinal;NativeMeta:HENHMETAFILE;
begin
  for Mode:=0 to 1 do begin
    Meta:=TMetafile.Create;Canvas:=TSkiaBitmapCanvas.Create(160,100);
    try
      Meta.Width:=160;Meta.Height:=100;Writer:=TMetafileCanvas.Create(Meta,0);
      try
        Writer.Brush.Style:=bsClear;Writer.Pen.Color:=clRed;Writer.Pen.Width:=4;
        Writer.Font.Name:='Arial';Writer.Font.Height:=-24;
        if Mode=1 then begin Writer.Brush.Style:=bsSolid;Writer.Brush.Color:=clBlack;end;
        BeginPath(Writer.Handle);
        if Mode=0 then begin
          Writer.Rectangle(10,10,150,90);EndPath(Writer.Handle);
          Writer.TextOut(30,35,'Pending path');
          StrokePath(Writer.Handle);
        end else begin
          Writer.TextOut(30,35,'Path text');EndPath(Writer.Handle);
          FillPath(Writer.Handle);
        end;
      finally Writer.Free;end;
      Canvas.Brush.Color:=clWhite;Canvas.FillRect(Rect(0,0,160,100));Canvas.StretchDraw(Rect(0,0,160,100),Meta);
      Image:=Canvas.Snapshot;SetLength(Pixels,160*100);
      Image.ReadPixels(TSkImageInfo.Create(160,100,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),160*4);
      Bitmap:=TBitmap.Create;try Canvas.Flush(Bitmap);Bitmap.SaveToFile(ExtractFilePath(ParamStr(0))+'pending-path-'+IntToStr(Mode)+'.bmp');finally Bitmap.Free;end;
      if Mode=0 then begin
        Bitmap:=TBitmap.Create;
        try
          Bitmap.PixelFormat:=pf32bit;Bitmap.SetSize(160,100);
          Bitmap.Canvas.Brush.Color:=clWhite;Bitmap.Canvas.FillRect(Rect(0,0,160,100));
          NativeMeta:=CopyEnhMetaFile(Meta.Handle,nil);
          try PlayEnhMetaFile(Bitmap.Canvas.Handle,NativeMeta,Rect(0,0,159,99));finally DeleteEnhMetaFile(NativeMeta);end;
          Bitmap.SaveToFile(ExtractFilePath(ParamStr(0))+'pending-path-gdi.bmp');
          Bad:=0;Ink:=0;
          for Y:=0 to 99 do begin Row:=Bitmap.ScanLine[Y];for X:=0 to 159 do begin
            if Pixels[Y*160+X] and $FFFFFF<>Row[X] and $FFFFFF then Inc(Bad);
            if Pixels[Y*160+X] and $FFFFFF=$FF0000 then Inc(Ink);
          end;end;
          Check(Bad=0,'EMF text preserves a completed pending path: exact GDI comparison');
          Check(Ink>100,'EMF pending path retains its red stroke');
        finally Bitmap.Free;end;
      end else begin
        Ink:=0;for I:=0 to High(Pixels) do if Pixels[I] and $FFFFFF<>$FFFFFF then Inc(Ink);
        Check(Ink>100,'EMF text inside BeginPath is painted by FillPath');
      end;
    finally Canvas.Free;Meta.Free;end;
  end;
end;

{ EMF fixtures are replayed through the parser and compared with native GDI. }
procedure TestEmfRecoveryMetadata;
var Info,Bits,Original:TBytes;Header:PBitmapInfoHeader;Player:TMetafileRecordPlayer;Invalid:TBytes;
  DC:HDC;Objects:array[0..1] of THandle;
begin
  SetLength(Info,440);SetLength(Bits,4);Header:=PBitmapInfoHeader(@Info[0]);
  Header.biSize:=40;Header.biWidth:=1;Header.biHeight:=1;Header.biPlanes:=1;Header.biBitCount:=8;
  Bits[0]:=99;Original:=Info;
  Check(NormalizeMetafileDIB(Info,Bits,0)=mrrPalette,'EMF short palette recovery validates existing pixel indexes');
  Check(PBitmapInfoHeader(@Info[0]).biClrUsed=100,'EMF recovered palette retains all supplied colors');
  Check(PBitmapInfoHeader(@Original[0]).biClrUsed=0,'EMF normalization preserves aliased source bytes');
  Info:=Original;Bits[0]:=100;
  Check((NormalizeMetafileDIB(Info,Bits,0)=mrrNone) and (PBitmapInfoHeader(@Info[0]).biClrUsed=0),
    'EMF missing palette colors are rejected instead of invented');
  SetLength(Info,52);FillChar(Info[0],Length(Info),0);SetLength(Bits,256);
  Header:=PBitmapInfoHeader(@Info[0]);Header.biSize:=$20000000;Header.biWidth:=8;Header.biHeight:=8;
  Header.biPlanes:=1;Header.biBitCount:=32;Header.biCompression:=BI_BITFIELDS;
  PCardinal(@Info[40])^:=$FF0000;PCardinal(@Info[44])^:=$00FF00;PCardinal(@Info[48])^:=$0000FF;
  Original:=Info;
  Check((NormalizeMetafileDIB(Info,Bits,0)=mrrDibHeader) and (PBitmapInfoHeader(@Info[0]).biSize=40),
    'EMF corrupt DIB size is recovered from a complete validated scanline buffer');
  Info:=Original;SetLength(Bits,255);
  Check(NormalizeMetafileDIB(Info,Bits,0)=mrrNone,'EMF truncated pattern pixels are not guessed');
  Player:=TMetafileRecordPlayer.Create;DC:=CreateCompatibleDC(0);
  try
    Check(not Player.Play(DC,nil,nil,0),'EMF compatibility player rejects a missing record');
    SetLength(Invalid,8);PCardinal(@Invalid[0])^:=95;PCardinal(@Invalid[4])^:=8;
    Check((not Player.Play(DC,nil,PEnhMetaRecord(@Invalid[0]),0)) and (Player.ErrorCode=ERROR_INVALID_DATA),
      'EMF compatibility player rejects a truncated extended pen');
    SetLength(Invalid,56);FillChar(Invalid[0],Length(Invalid),0);FillChar(Objects,SizeOf(Objects),0);
    PCardinal(@Invalid[0])^:=95;PCardinal(@Invalid[4])^:=56;PCardinal(@Invalid[8])^:=1;
    PCardinal(@Invalid[28])^:=PS_GEOMETRIC;PCardinal(@Invalid[32])^:=10;PCardinal(@Invalid[36])^:=$FFFFFFFF;
    Check((not Player.Play(DC,@Objects[0],PEnhMetaRecord(@Invalid[0]),Length(Objects))) and (Player.ErrorCode<>0),
      'EMF unrecoverable records report an error instead of successful empty playback');
  finally if DC<>0 then DeleteDC(DC);Player.Free;end;
end;

function TestEmfGdiResources(Process:THandle;Flags:DWORD):DWORD;stdcall;
  external 'user32.dll' name 'GetGuiResources';

procedure TestEmfRecoveryHandles;
var Meta:TMetafile;Canvas:TSkiaBitmapCanvas;Root:string;BeforeCount,AfterCount:Cardinal;I:Integer;
begin
  Root:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..\..\fixtures\emf\');
  Meta:=TMetafile.Create;Canvas:=TSkiaBitmapCanvas.Create(128,96);
  try
    Meta.LoadFromFile(Root+'extcreatepen_monopattern.emf');Canvas.StretchDraw(Rect(0,0,128,96),Meta);
    BeforeCount:=TestEmfGdiResources(GetCurrentProcess,0);
    for I:=1 to 16 do begin
      if I mod 2=0 then Meta.LoadFromFile(Root+'extcreatepen_monopattern.emf')
      else Meta.LoadFromFile(Root+'extcreatepen_pattern_brushorg_xform.emf');
      Canvas.StretchDraw(Rect(0,0,128,96),Meta);
    end;
    AfterCount:=TestEmfGdiResources(GetCurrentProcess,0);
    Check(AfterCount<=BeforeCount+1,'EMF compatibility replay releases native pens, pattern bitmaps and DCs');
  finally Canvas.Free;Meta.Free;end;
end;

function MakeEmfWithRecords(const RecordData:TBytes;RecordCount:Cardinal=1):TMetafile;
var Writer:TMetafileCanvas;Original,Data:TBytes;Size,Offset:Cardinal;Stream:TMemoryStream;
begin
  Result:=TMetafile.Create;
  try
    Result.Width:=32;Result.Height:=32;Writer:=TMetafileCanvas.Create(Result,0);
    try Writer.Brush.Color:=clWhite;Writer.Rectangle(0,0,32,32);finally Writer.Free;end;
    Size:=GetEnhMetaFileBits(Result.Handle,0,nil);SetLength(Original,Size);
    GetEnhMetaFileBits(Result.Handle,Size,Pointer(Original));Offset:=0;
    while (Offset+8<=Size) and (PCardinal(@Original[Offset])^<>14) do
      Inc(Offset,PCardinal(@Original[Offset+4])^);
    SetLength(Data,NativeInt(Size)+Length(RecordData));Move(Original[0],Data[0],Offset);
    Move(RecordData[0],Data[Offset],Length(RecordData));Move(Original[Offset],Data[Offset+Cardinal(Length(RecordData))],Size-Offset);
    PCardinal(@Data[48])^:=Length(Data);Inc(PCardinal(@Data[52])^,RecordCount);
    Stream:=TMemoryStream.Create;
    try Stream.WriteBuffer(Data[0],Length(Data));Stream.Position:=0;Result.LoadFromStream(Stream);finally Stream.Free;end;
  except Result.Free;raise;end;
end;

function ReviewSetWorld(DC:HDC;Transform:Pointer):BOOL;stdcall;
  external 'gdi32.dll' name 'SetWorldTransform';
procedure TestReviewSetPixelBatch;
var Meta:TMetafile;Writer:TMetafileCanvas;Canvas:TSkiaBitmapCanvas;Reference:TBitmap;
  M:TMatrix;XF:TXForm;Native:HENHMETAFILE;DC:HDC;Image:ISkImage;Pixels:TArray<TAlphaColor>;
  I,X,Y,Mode,Bad,Ink:Integer;Color:Cardinal;Header:TEnhMetaHeader;Started,Elapsed:UInt64;
begin
  Meta:=TMetafile.Create;Reference:=TBitmap.Create;
  try
    Meta.Width:=4096;Meta.Height:=4096;Writer:=TMetafileCanvas.Create(Meta,0);
    try
      for I:=0 to 9999 do
      begin
        if Odd(I) then Color:=ColorToRGB(clRed) else Color:=ColorToRGB(clBlue);
        SetPixel(Writer.Handle,50+(I mod 100),50+(I div 100),Color);
      end;
    finally Writer.Free;end;
    FillChar(Header,SizeOf(Header),0);
    Check((GetEnhMetaFileHeader(Meta.Handle,SizeOf(Header),@Header)<>0) and (Header.nRecords>=10002),
      'Review: 10000 SETPIXELV records generated');
    Reference.PixelFormat:=pf32bit;Reference.SetSize(4096,4096);
    SetLength(Pixels,400*400);
    for Mode:=0 to 1 do
    begin
      Canvas:=TSkiaBitmapCanvas.Create(4096,4096);
      try
        M:=TMatrix.Identity;
        if Mode=1 then begin M.M11:=0.75;M.M12:=0.25;M.M21:=0.125;M.M31:=160;M.M32:=40;end;
        Canvas.SkCanvas.Clear($FFFFFFFF);Canvas.SetWorldTransform(M);
        Started:=GetTickCount64;Canvas.StretchDraw(Rect(0,0,4096,4096),Meta);Elapsed:=GetTickCount64-Started;
        Writeln(Format('EMF SETPIXELV: 10000 records / 4096x4096 / transform %d / %d ms',[Mode,Elapsed]));
        Reference.Canvas.Brush.Color:=clWhite;Reference.Canvas.FillRect(Rect(0,0,4096,4096));
        DC:=Reference.Canvas.Handle;SetGraphicsMode(DC,GM_ADVANCED);
        XF.eM11:=M.M11;XF.eM12:=M.M12;XF.eM21:=M.M21;XF.eM22:=M.M22;XF.eDx:=M.M31;XF.eDy:=M.M32;
        ReviewSetWorld(DC,@XF);Native:=CopyEnhMetaFile(Meta.Handle,nil);
        try Check(PlayEnhMetaFile(DC,Native,Rect(0,0,4095,4095)),'Review: native SETPIXELV batch reference');
        finally DeleteEnhMetaFile(Native);end;
        XF.eM11:=1;XF.eM12:=0;XF.eM21:=0;XF.eM22:=1;XF.eDx:=0;XF.eDy:=0;ReviewSetWorld(DC,@XF);
        Image:=Canvas.Snapshot;
        Check(Image.ReadPixels(TSkImageInfo.Create(400,400,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),400*4),
          'Review: SETPIXELV batch pixels readable');
        Bad:=0;Ink:=0;
        for Y:=0 to 399 do for X:=0 to 399 do
        begin
          Color:=ColorToAlphaColor(TColor(GetPixel(DC,X,Y))) and $FFFFFF;
          if (Pixels[Y*400+X] and $FFFFFF)<>Color then Inc(Bad);
          if Color<>$FFFFFF then Inc(Ink);
        end;
        Check((Bad=0) and (Ink>1000),Format('Review: tiled SETPIXELV batch exactly matches native GDI (bad %d, ink %d)',[Bad,Ink]));
      finally Image:=nil;Canvas.Free;end;
    end;
  finally Reference.Free;Meta.Free;end;
end;

function ReviewDrawText(DC:HDC;Text:PWideChar;Count:Integer;Bounds:PRect;Flags:UINT):Integer;stdcall;
  external 'user32.dll' name 'DrawTextW';
procedure TestReviewOpaqueText;
var Bitmap:TBitmap;Canvas:TSkiaBitmapCanvas;R:TRect;Text:string;
begin
  Bitmap:=TBitmap.Create;Canvas:=TSkiaBitmapCanvas.Create(64,48);
  try
    Bitmap.PixelFormat:=pf32bit;Bitmap.SetSize(64,48);
    Bitmap.Canvas.Brush.Color:=clWhite;Bitmap.Canvas.FillRect(Rect(0,0,64,48));
    Bitmap.Canvas.Font.Name:='Arial';Bitmap.Canvas.Font.Height:=-16;
    SelectObject(Bitmap.Canvas.Handle,Bitmap.Canvas.Font.Handle);
    SetBkMode(Bitmap.Canvas.Handle,OPAQUE);SetBkColor(Bitmap.Canvas.Handle,ColorToRGB(clRed));
    SetTextColor(Bitmap.Canvas.Handle,0);R:=Rect(0,0,64,48);
    ReviewDrawText(Bitmap.Canvas.Handle,'A',1,@R,DT_SINGLELINE);
    Canvas.Brush.Color:=clWhite;Canvas.FillRect(Rect(0,0,64,48));
    Canvas.Brush.Color:=clRed;Canvas.Font.Assign(Bitmap.Canvas.Font);
    R:=Rect(0,0,64,48);Text:='A';Canvas.TextRect(R,Text,[tfSingleLine]);
    Check(Bitmap.Canvas.Pixels[60,44]=clWhite,'Review: GDI opaque text leaves unused layout area unchanged');
    Check(Canvas.Pixels[60,44]=clWhite,'Review: Skia opaque text agrees with GDI outside character cells');
  finally Canvas.Free;Bitmap.Free;end;
end;

function ReviewLPtoDP(DC:HDC;Points:Pointer;Count:Integer):BOOL;stdcall;
  external 'gdi32.dll' name 'LPtoDP';
procedure TestReviewIsotropic;
var Meta:TMetafile;Writer:TMetafileCanvas;Parser:TMetafileParser;P:TPoint;I,SignY,Order:Integer;Found:Boolean;
begin
  for SignY:=-1 to 1 do if SignY<>0 then
  for Order:=0 to 3 do
  begin
    Meta:=TMetafile.Create;Parser:=TMetafileParser.Create;
    try
      Meta.Width:=32;Meta.Height:=32;Writer:=TMetafileCanvas.Create(Meta,0);
      try
        SetMapMode(Writer.Handle,MM_ISOTROPIC);
        if Order=1 then
        begin
          SetViewportExtEx(Writer.Handle,200,SignY*100,nil);
          SetWindowExtEx(Writer.Handle,100,100,nil);
        end
        else
        begin
          SetWindowExtEx(Writer.Handle,100,100,nil);
          SetViewportExtEx(Writer.Handle,200,SignY*100,nil);
        end;
        if Order=2 then ScaleWindowExtEx(Writer.Handle,2,1,1,1,nil);
        if Order=3 then ScaleViewportExtEx(Writer.Handle,1,1,2,1,nil);
        P:=Point(10,10);Check(ReviewLPtoDP(Writer.Handle,@P,1),'Review: native isotropic reference');
        Writer.MoveTo(0,0);Writer.LineTo(10,10);
      finally Writer.Free;end;
      Parser.StorePrimitives:=True;
      Check(Parser.LoadFromMetafile(Meta),'Review: isotropic metafile parses');Found:=False;
      for I:=0 to Parser.PrimitiveCount-1 do
        if Parser.PrimitiveByIndex(I).SourceRecordType=54 then
        begin
          Found:=True;
          Check(Abs((Parser.PrimitiveByIndex(I).Bounds.Right-Parser.PrimitiveByIndex(I).Bounds.Left)-Abs(P.X))<0.001,
            Format('Review: isotropic X scale agrees with GDI (parser %.3f, native %d)',[Parser.PrimitiveByIndex(I).Bounds.Right-Parser.PrimitiveByIndex(I).Bounds.Left,Abs(P.X)]));
          Check(Abs((Parser.PrimitiveByIndex(I).Bounds.Bottom-Parser.PrimitiveByIndex(I).Bounds.Top)-Abs(P.Y))<0.001,
            Format('Review: isotropic Y scale agrees with GDI (parser %.3f, native %d)',[Parser.PrimitiveByIndex(I).Bounds.Bottom-Parser.PrimitiveByIndex(I).Bounds.Top,Abs(P.Y)]));
          Check(Abs(Parser.PrimitiveByIndex(I).Points[High(Parser.PrimitiveByIndex(I).Points)].X-P.X)<0.001,
            'Review: isotropic X orientation agrees with GDI');
          Check(Abs(Parser.PrimitiveByIndex(I).Points[High(Parser.PrimitiveByIndex(I).Points)].Y-P.Y)<0.001,
            'Review: isotropic Y orientation agrees with GDI');
        end;
      Check(Found,'Review: isotropic line emitted');
    finally Parser.Free;Meta.Free;end;
  end;
end;

procedure TestReviewInputBounds;
var Primitive:TMetafilePrimitive; Meta:TMetafile; Parser:TMetafileParser;
  Records:TBytes; Kind,Size:Integer; Accepted:Boolean; Limits:TMetafileLimits; I,CaseIndex:Integer; Probe:TReviewLimitProbe; FileName:string; Stream:TFileStream;
begin
  Primitive:=TMetafilePrimitive.Create;
  try
    SetLength(Primitive.Points,2);SetLength(Primitive.PointCounts,3);
    Primitive.PointCounts[0]:=High(Integer);Primitive.PointCounts[1]:=High(Integer);
    Primitive.PointCounts[2]:=2;
    Check(Length(Primitive.SubPoints(2))=0,'Review: overflowing subpath prefix is rejected');
    Primitive.PointCounts[0]:=1;Primitive.PointCounts[1]:=High(Integer);
    Check(Length(Primitive.SubPoints(1))=0,'Review: overflowing subpath end is rejected');
    Primitive.PointCounts[1]:=1;
    Check(Length(Primitive.SubPoints(1))=1,'Review: valid subpath remains available');
  finally Primitive.Free;end;
  SetLength(Records,24);FillChar(Records[0],Length(Records),0);
  for Kind:=0 to 2 do begin PCardinal(@Records[Kind*8])^:=33;PCardinal(@Records[Kind*8+4])^:=8;end;
  Meta:=MakeEmfWithRecords(Records,3);Parser:=TMetafileParser.Create;
  try
    Limits:=Parser.Limits;Limits.MaxSaveDepth:=2;Parser.Limits:=Limits;
    Check(not Parser.LoadFromMetafile(Meta),'Review: SaveDC depth budget rejects excessive nesting');
    Check(Pos('depth limit',Parser.LastError)>0,'Review: SaveDC budget failure identifies resource limit');
    Limits.MaxSaveDepth:=3;Parser.Limits:=Limits;
    Check(Parser.LoadFromMetafile(Meta),'Review: increased SaveDC budget permits valid nesting');
    Limits.MaxTotalBytes:=88;Parser.Limits:=Limits;
    Check(not Parser.LoadFromMetafile(Meta),'Review: total input byte budget rejects oversized metafile');
    Check(Pos('total record byte limit',Parser.LastError)>0,'Review: total input byte budget reports error');
    Limits.MaxTotalBytes:=512*1024*1024;Parser.Limits:=Limits;
    Check(Parser.LoadFromMetafile(Meta),'Review: input byte accounting resets on the next load');
    Limits.MaxTotalPoints:=4;Parser.Limits:=Limits;
    Check(not Parser.LoadFromMetafile(Meta),'Review: total generated point budget enforced');
    Check(Pos('generated point limit',Parser.LastError)>0,'Review: generated point budget reports error');
    Limits.MaxTotalPoints:=100;Parser.Limits:=Limits;
    Check(Parser.LoadFromMetafile(Meta),'Review: generated point accounting resets on the next load');
  finally Parser.Free;Meta.Free;end;
  FileName:=ExtractFilePath(ParamStr(0))+'review-byte-limit.emf';
  Stream:=TFileStream.Create(FileName,fmCreate);
  try Stream.Size:=256;finally Stream.Free;end;
  Parser:=TMetafileParser.Create;
  try
    Limits:=Parser.Limits;Limits.MaxTotalBytes:=88;Parser.Limits:=Limits;
    Check(not Parser.LoadFromFile(FileName),'Review: file byte limit enforced before native loading');
    Check(Pos('before loading',Parser.LastError)>0,'Review: oversized file reports input byte limit');
    Limits.MaxTotalBytes:=512*1024*1024;Parser.Limits:=Limits;
    Meta:=MakeEmfWithRecords(Records,3);
    try
      Meta.SaveToFile(FileName);Parser.StorePrimitives:=True;
      Check(Parser.LoadFromFile(FileName) and (Parser.PrimitiveCount>0),
        'Review: bounded native file loader accepts valid metafiles');
    finally Meta.Free;end;
  finally Parser.Free;SysUtils.DeleteFile(FileName);end;
  SetLength(Records,80);FillChar(Records[0],Length(Records),0);
  PCardinal(@Records[0])^:=84;PCardinal(@Records[4])^:=80;
  PCardinal(@Records[44])^:=$80000000;
  Meta:=MakeEmfWithRecords(Records);Parser:=TMetafileParser.Create;Probe:=TReviewLimitProbe.Create;
  try
    Parser.OnRecord:=Probe.RecordReady;
    Check(not Parser.LoadFromMetafile(Meta),'Review: hostile text character count rejected before allocation');
    Check(Pos('text length limit',Parser.LastError)>0,'Review: hostile text reports length limit');
    Check(Probe.TextCallbacks=0,'Review: text length checked before native replay callbacks');
  finally Probe.Free;Parser.Free;Meta.Free;end;
  SetLength(Records,32);FillChar(Records[0],Length(Records),0);
  PCardinal(@Records[0])^:=35;PCardinal(@Records[4])^:=32;
  PCardinal(@Records[8])^:=$7FC00000;
  Meta:=MakeEmfWithRecords(Records);Parser:=TMetafileParser.Create;
  try
    Check(not Parser.LoadFromMetafile(Meta),'Review: non-finite world transform rejected');
    Check(Pos('Non-finite',Parser.LastError)>0,'Review: invalid world transform reports error');
  finally Parser.Free;Meta.Free;end;
  SetLength(Records,24);FillChar(Records[0],Length(Records),0);
  PCardinal(@Records[0])^:=33;PCardinal(@Records[4])^:=8;
  PCardinal(@Records[8])^:=34;PCardinal(@Records[12])^:=12;PCardinal(@Records[16])^:=$80000000;
  SetLength(Records,20);
  Meta:=MakeEmfWithRecords(Records,2);Parser:=TMetafileParser.Create;
  try Check(Parser.LoadFromMetafile(Meta),'Review: RestoreDC Low(Integer) does not overflow');
  finally Parser.Free;Meta.Free;end;
  SetLength(Records,80);FillChar(Records[0],Length(Records),0);
  PCardinal(@Records[0])^:=59;PCardinal(@Records[4])^:=8;
  PCardinal(@Records[8])^:=27;PCardinal(@Records[12])^:=16;
  PCardinal(@Records[24])^:=54;PCardinal(@Records[28])^:=16;
  PCardinal(@Records[32])^:=10;PCardinal(@Records[36])^:=10;
  PCardinal(@Records[40])^:=60;PCardinal(@Records[44])^:=8;
  PCardinal(@Records[48])^:=61;PCardinal(@Records[52])^:=8;
  PCardinal(@Records[56])^:=64;PCardinal(@Records[60])^:=24;
  Meta:=MakeEmfWithRecords(Records,6);Parser:=TMetafileParser.Create;
  try
    Parser.StorePrimitives:=True;
    Check(Parser.LoadFromMetafile(Meta),'Review: completed path remains parseable');
    Accepted:=False;
    for I:=0 to Parser.PrimitiveCount-1 do
      if Parser.PrimitiveByIndex(I).SourceRecordType=64 then
        Accepted:=Length(Parser.PrimitiveByIndex(I).Points)=2;
    Check(Accepted,'Review: CLOSEFIGURE outside path bracket leaves pending open path unchanged');
  finally Parser.Free;Meta.Free;end;
  for CaseIndex:=0 to 1 do
  begin
    if CaseIndex=0 then Size:=36 else Size:=80;
    SetLength(Records,Size);FillChar(Records[0],Length(Records),0);
    PCardinal(@Records[4])^:=Size;
    if CaseIndex=0 then
    begin PCardinal(@Records[0])^:=108;PCardinal(@Records[16])^:=$80000000;end
    else
    begin PCardinal(@Records[0])^:=97;PCardinal(@Records[36])^:=1;PCardinal(@Records[48])^:=$80000000;end;
    Meta:=MakeEmfWithRecords(Records);Parser:=TMetafileParser.Create;Probe:=TReviewLimitProbe.Create;
    try
      Parser.OnRecord:=Probe.RecordReady;
      Check(not Parser.LoadFromMetafile(Meta),'Review: alternate text record checks length before allocation '+IntToStr(CaseIndex));
      Check(Pos('text length limit',Parser.LastError)>0,'Review: alternate text record reports length limit '+IntToStr(CaseIndex));
      Check(Probe.TextCallbacks=0,'Review: alternate text limit precedes native replay callback '+IntToStr(CaseIndex));
    finally Probe.Free;Parser.Free;Meta.Free;end;
  end;
  SetLength(Records,84);FillChar(Records[0],Length(Records),0);
  PCardinal(@Records[0])^:=17;PCardinal(@Records[4])^:=12;PCardinal(@Records[8])^:=MM_ISOTROPIC;
  PCardinal(@Records[12])^:=9;PCardinal(@Records[16])^:=16;PCardinal(@Records[20])^:=100;PCardinal(@Records[24])^:=100;
  PCardinal(@Records[28])^:=11;PCardinal(@Records[32])^:=16;PCardinal(@Records[36])^:=100;PCardinal(@Records[40])^:=100;
  PCardinal(@Records[44])^:=32;PCardinal(@Records[48])^:=24;
  PCardinal(@Records[56])^:=1;PCardinal(@Records[60])^:=1;PCardinal(@Records[64])^:=1;
  PCardinal(@Records[68])^:=54;PCardinal(@Records[72])^:=16;PCardinal(@Records[76])^:=10;PCardinal(@Records[80])^:=10;
  Meta:=MakeEmfWithRecords(Records,5);Parser:=TMetafileParser.Create;
  try
    Parser.StorePrimitives:=True;
    Check(Parser.LoadFromMetafile(Meta),'Review: zero scale numerator does not create a zero divisor');
    Accepted:=False;
    for I:=0 to Parser.PrimitiveCount-1 do
      if Parser.PrimitiveByIndex(I).SourceRecordType=54 then
        Accepted:=(Abs(Parser.PrimitiveByIndex(I).Bounds.Right-10)<0.001) and
          (Abs(Parser.PrimitiveByIndex(I).Bounds.Bottom-10)<0.001);
    Check(Accepted,'Review: invalid scale operation preserves preceding mapping');
  finally Parser.Free;Meta.Free;end;
  for CaseIndex:=0 to 3 do
  begin
    SetLength(Records,76);FillChar(Records[0],Length(Records),0);
    PCardinal(@Records[0])^:=118;PCardinal(@Records[4])^:=76;
    PCardinal(@Records[24])^:=2;PCardinal(@Records[28])^:=1;
    PCardinal(@Records[52])^:=8;PCardinal(@Records[56])^:=8;
    PCardinal(@Records[68])^:=0;PCardinal(@Records[72])^:=1;
    case CaseIndex of
      1:PCardinal(@Records[72])^:=2;
      2:PCardinal(@Records[32])^:=3;
      3:PCardinal(@Records[28])^:=$7FFFFFFF;
    end;
    Meta:=MakeEmfWithRecords(Records);Parser:=TMetafileParser.Create;
    try
      Parser.StorePrimitives:=True;
      Accepted:=Parser.LoadFromMetafile(Meta);
      if CaseIndex=3 then
        Check(not Accepted,'Review: huge gradient mesh count rejected before allocation')
      else
      begin
        Check(Accepted,'Review: gradient record parsed safely '+IntToStr(CaseIndex));
        Accepted:=False;
        for I:=0 to Parser.PrimitiveCount-1 do
          if Parser.PrimitiveByIndex(I).SourceRecordType=118 then Accepted:=True;
        Check(Accepted=(CaseIndex=0),'Review: only valid gradient mesh is published '+IntToStr(CaseIndex));
      end;
    finally Parser.Free;Meta.Free;end;
  end;
  for CaseIndex:=0 to 2 do
  begin
    SetLength(Records,80);FillChar(Records[0],Length(Records),0);
    PCardinal(@Records[0])^:=71;PCardinal(@Records[4])^:=80;
    PCardinal(@Records[24])^:=48;PCardinal(@Records[28])^:=$80000000;
    PCardinal(@Records[32])^:=32;PCardinal(@Records[36])^:=1;
    PCardinal(@Records[40])^:=1;PCardinal(@Records[44])^:=16;
    PCardinal(@Records[72])^:=8;PCardinal(@Records[76])^:=8;
    if CaseIndex=1 then PCardinal(@Records[40])^:=$10000000;
    if CaseIndex=2 then PCardinal(@Records[44])^:=0;
    Meta:=MakeEmfWithRecords(Records);Parser:=TMetafileParser.Create;
    try
      Parser.StorePrimitives:=True;
      Check(Parser.LoadFromMetafile(Meta),'Review: region count and size checked safely '+IntToStr(CaseIndex));
      Accepted:=False;
      for I:=0 to Parser.PrimitiveCount-1 do
        if Parser.PrimitiveByIndex(I).SourceRecordType=71 then Accepted:=True;
      Check(Accepted=(CaseIndex=0),'Review: only bounded consistent region is published '+IntToStr(CaseIndex));
    finally Parser.Free;Meta.Free;end;
  end;
  for Kind:=71 to 74 do
  begin
    if Kind=71 then Size:=32 else if Kind=72 then Size:=40 else Size:=28;
    SetLength(Records,Size-4);FillChar(Records[0],Length(Records),0);
    PCardinal(@Records[0])^:=Kind;PCardinal(@Records[4])^:=Length(Records);
    Meta:=MakeEmfWithRecords(Records);Parser:=TMetafileParser.Create;
    try
      Accepted:=Parser.LoadFromMetafile(Meta);
      Check(not Accepted,'Review: truncated region prefix rejected '+IntToStr(Kind));
      Check(Parser.LastError<>'','Review: truncated region reports an error '+IntToStr(Kind));
    finally Parser.Free;Meta.Free;end;
  end;
end;

procedure TestEmfInvalidOpenPath;
var Records:TBytes;Meta:TMetafile;Canvas:TSkiaBitmapCanvas;Raised:Boolean;
begin
  SetLength(Records,56);
  PCardinal(@Records[0])^:=59;PCardinal(@Records[4])^:=8;
  PCardinal(@Records[8])^:=43;PCardinal(@Records[12])^:=24;
  PCardinal(@Records[24])^:=8;PCardinal(@Records[28])^:=8;
  PCardinal(@Records[32])^:=63;PCardinal(@Records[36])^:=24;
  PCardinal(@Records[48])^:=8;PCardinal(@Records[52])^:=8;
  Meta:=MakeEmfWithRecords(Records,3);Canvas:=TSkiaBitmapCanvas.Create(32,32);
  try
    Canvas.Brush.Color:=clBlue;Canvas.FillRect(Rect(0,0,32,32));Raised:=False;
    try Canvas.StretchDraw(Rect(0,0,32,32),Meta);
    except on E:ESkiaCanvasError do Raised:=True;end;
    Check(Raised,'EMF an unclosed nonempty path is not mistaken for an empty path');
    Check(Canvas.Pixels[5,5]=clBlue,'EMF failed preflight preserves existing destination pixels');
  finally Canvas.Free;Meta.Free;end;
end;

procedure TestEmfDIBOrigins;
const Colors:array[0..3] of Cardinal=($FFFF0000,$FF00FF00,$FF0000FF,$FFFFFF00);
var Mode,Orientation,Crop,SourceY,SourceH,Y,X,StorageRow,Bad:Integer;Info,Bits,ExpectedInfo,ExpectedBits,Encoded:TBytes;
  Header:PBitmapInfoHeader;Source,Expected:TMetafile;Canvas:TSkiaBitmapCanvas;Bitmap:TBitmap;
  Image:ISkImage;Pixels:TArray<TAlphaColor>;Native:HENHMETAFILE;Row:PCardinal;Accepted:Boolean;
  function RecordBytes(const DIB,Data:TBytes):TBytes;
    procedure Put(Offset:Integer;Value:Cardinal);
    begin PCardinal(@Result[Offset])^:=Value;end;
  begin
    SetLength(Result,(80+Length(DIB)+Length(Data)+3) and not 3);
    Put(0,81);Put(4,Length(Result));Put(8,4);Put(12,4);Put(16,27);Put(20,27);
    Put(24,4);Put(28,4);Put(32,0);Put(36,Cardinal(SourceY));Put(40,1);Put(44,Cardinal(SourceH));
    Put(48,80);Put(52,Length(DIB));Put(56,80+Length(DIB));Put(60,Length(Data));
    Put(64,0);Put(68,SRCCOPY);Put(72,24);Put(76,24);
    Move(DIB[0],Result[80],Length(DIB));Move(Data[0],Result[80+Length(DIB)],Length(Data));
  end;

begin
  Image:=TSkImage.MakeRasterCopy(TSkImageInfo.Create(1,4,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),@Colors[0],4);
  Encoded:=Image.Encode(TSkEncodedImageFormat.PNG);
  for Mode:=0 to 1 do for Orientation:=-1 to 1 do if Orientation<>0 then for Crop:=0 to 2 do begin
    SourceY:=1;SourceH:=1;
    if Crop=1 then begin SourceY:=3;SourceH:=-1;end;
    if Crop=2 then begin SourceY:=-1;SourceH:=2;end;
    SetLength(ExpectedInfo,40);FillChar(ExpectedInfo[0],40,0);Header:=PBitmapInfoHeader(@ExpectedInfo[0]);
    Header.biSize:=40;Header.biWidth:=1;Header.biHeight:=4*Orientation;Header.biPlanes:=1;Header.biBitCount:=32;
    Header.biSizeImage:=16;SetLength(ExpectedBits,16);
    for Y:=0 to 3 do begin StorageRow:=Y;if Orientation>0 then StorageRow:=3-Y;PCardinal(@ExpectedBits[StorageRow*4])^:=Colors[Y];end;
    if Mode=0 then begin
      SetLength(Info,56);FillChar(Info[0],56,0);Move(ExpectedInfo[0],Info[0],40);
      Header:=PBitmapInfoHeader(@Info[0]);Header.biBitCount:=8;Header.biClrUsed:=0;
      for Y:=0 to 3 do PCardinal(@Info[40+Y*4])^:=Colors[Y] and $FFFFFF;
      SetLength(Bits,16);FillChar(Bits[0],16,0);
      for Y:=0 to 3 do begin StorageRow:=Y;if Orientation>0 then StorageRow:=3-Y;Bits[StorageRow*4]:=Y;end;
    end else begin
      Info:=Copy(ExpectedInfo,0,40);Header:=PBitmapInfoHeader(@Info[0]);Header.biBitCount:=0;
      Header.biCompression:=5;Header.biSizeImage:=Length(Encoded);Bits:=Encoded;
    end;
    Source:=MakeEmfWithRecords(RecordBytes(Info,Bits));Expected:=MakeEmfWithRecords(RecordBytes(ExpectedInfo,ExpectedBits));
    Canvas:=TSkiaBitmapCanvas.Create(32,32);Bitmap:=TBitmap.Create;
    try
      Canvas.Brush.Color:=clWhite;Canvas.FillRect(Rect(0,0,32,32));Canvas.StretchDraw(Rect(0,0,32,32),Source);
      Bitmap.PixelFormat:=pf32bit;Bitmap.SetSize(32,32);Bitmap.Canvas.Brush.Color:=clWhite;Bitmap.Canvas.FillRect(Rect(0,0,32,32));
      Native:=CopyEnhMetaFile(Expected.Handle,nil);
      try Accepted:=PlayEnhMetaFile(Bitmap.Canvas.Handle,Native,Rect(0,0,31,31));finally DeleteEnhMetaFile(Native);end;
      Check(Accepted,'EMF DIB origin reference plays successfully');
      Image:=Canvas.Snapshot;SetLength(Pixels,32*32);Image.ReadPixels(TSkImageInfo.Create(32,32,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),32*4);
      Bad:=0;for Y:=0 to 31 do begin Row:=Bitmap.ScanLine[Y];for X:=0 to 31 do
        if Pixels[Y*32+X] and $FFFFFF<>Row[X] and $FFFFFF then Inc(Bad);end;
      Check(Bad=0,'EMF decoded DIB preserves crop, mirror and row direction: '+IntToStr(Mode)+'/'+IntToStr(Orientation)+'/'+IntToStr(Crop));
    finally Bitmap.Free;Canvas.Free;Expected.Free;Source.Free;end;
  end;
end;

procedure TestEmfPlayback;
const Scales:array[0..1] of Integer=(1,2);
var W,H,ScaleIndex,FileCount:Integer;Search:TSearchRec;FileName,Root,Output,Name,BaseOutput,Filter,ReferenceRoot,ReferenceFile:string;Meta:TMetafile;
  Canvas:TSkiaBitmapCanvas;Recorder:TSkiaMetafileCanvas;Bitmap,Reference:TBitmap;
  X,Y,Bad,ExactDifferent,Ink,ExpectedInk:Integer;
  BX,BY,XX,YY,C,CoarseBad:Integer;SumA,SumB:array[0..2] of Integer;
  Difference:Integer;A,B:Cardinal;Image,ReferenceImage:ISkImage;Pixels,ReferencePixels:TArray<TAlphaColor>;Encoded:TBytes;
  NativeAccepted:Boolean;NativeMetafile:HENHMETAFILE;
  Row:PCardinal;Stream:TMemoryStream;SVG:ISkCanvas;Picture:ISkPicture;Document:ISkDocument;Bytes:UTF8String;
begin
  Filter:=SysUtils.GetEnvironmentVariable('SKIA_EMF_FILTER');
  TestEmfAlphaAndOpacity;
  TestEmfPendingPath;
  TestEmfRecoveryMetadata;
  TestEmfRecoveryHandles;
  TestEmfDIBOrigins;
  TestReviewInputBounds;
  TestReviewSetPixelBatch;
  TestReviewOpaqueText;
  TestReviewIsotropic;
  TestEmfInvalidOpenPath;
  Root:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..\..\fixtures\emf\');
  BaseOutput:=ExtractFilePath(ParamStr(0))+'emf\';
  ReferenceRoot:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..\emf-reference\');
  Check(DirectoryExists(Root),'EMF fixture directory exists');
  for ScaleIndex:=Low(Scales) to High(Scales) do begin
  W:=384*Scales[ScaleIndex];H:=256*Scales[ScaleIndex];FileCount:=0;
  Output:=BaseOutput;
  if Scales[ScaleIndex]<>1 then Output:=Output+IntToStr(Scales[ScaleIndex])+'x\';
  ForceDirectories(Output);
  if FindFirst(Root+'*.emf',faAnyFile,Search)<>0 then begin Check(False,'EMF fixtures are present');Exit;end;
  try
    repeat
      if (Filter<>'') and (Pos(Filter,Search.Name)=0) then Continue;
      Inc(FileCount);FileName:=Root+Search.Name;Name:=ChangeFileExt(Search.Name,'');
      Meta:=TMetafile.Create;Canvas:=TSkiaBitmapCanvas.Create(W,H);Bitmap:=TBitmap.Create;Reference:=TBitmap.Create;
      try
        Meta.LoadFromFile(FileName);
        Canvas.Brush.Color:=clWhite;Canvas.FillRect(Rect(0,0,W,H));
        Canvas.StretchDraw(Rect(0,0,W,H),Meta);
        Canvas.Flush(Bitmap);Bitmap.SaveToFile(Output+Name+'.bmp');
        Reference.PixelFormat:=pf32bit;Reference.SetSize(W,H);
        Reference.Canvas.Brush.Color:=clWhite;Reference.Canvas.FillRect(Rect(0,0,W,H));
        NativeMetafile:=CopyEnhMetaFile(Meta.Handle,nil);
        try NativeAccepted:=PlayEnhMetaFile(Reference.Canvas.Handle,NativeMetafile,Rect(0,0,W-1,H-1));
        finally DeleteEnhMetaFile(NativeMetafile);end;Reference.SaveToFile(Output+Name+'-gdi.bmp');
        ReferenceFile:=ReferenceRoot;
        if Scales[ScaleIndex]<>1 then ReferenceFile:=ReferenceFile+IntToStr(Scales[ScaleIndex])+'x\';
        ReferenceFile:=ReferenceFile+Name+'-reference.bmp';
        if not NativeAccepted then Check(FileExists(ReferenceFile),'EMF complete compatibility reference exists: '+Name);
        SetLength(ReferencePixels,W*H);
        if FileExists(ReferenceFile) then begin
          Reference.LoadFromFile(ReferenceFile);
          Reference.SaveToFile(Output+Name+'-reference.bmp');
          Stream:=TMemoryStream.Create;
          try
            Stream.LoadFromFile(ReferenceFile);SetLength(Encoded,Stream.Size);
            Stream.ReadBuffer(Encoded[0],Length(Encoded));ReferenceImage:=TSkImage.MakeFromEncoded(Encoded);
            ReferenceImage.ReadPixels(TSkImageInfo.Create(W,H,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(ReferencePixels),W*4);
          finally Stream.Free;ReferenceImage:=nil;end;
        end else for Y:=0 to H-1 do Move(Reference.ScanLine[Y]^,ReferencePixels[Y*W],W*4);
        Image:=Canvas.Snapshot;SetLength(Pixels,W*H);
        Image.ReadPixels(TSkImageInfo.Create(W,H,TSkColorType.BGRA8888,TSkAlphaType.Unpremul),Pointer(Pixels),W*4);
        Bad:=0;ExactDifferent:=0;Ink:=0;ExpectedInk:=0;
        for Y:=0 to H-1 do begin
          Row:=@ReferencePixels[Y*W];
          for X:=0 to W-1 do begin
            A:=Pixels[Y*W+X] and $FFFFFF;B:=Row[X] and $FFFFFF;
            if A<>B then Inc(ExactDifferent);
            if A<>$FFFFFF then Inc(Ink);if B<>$FFFFFF then Inc(ExpectedInk);
            if (Abs(Integer(A and 255)-Integer(B and 255))>45) or
              (Abs(Integer((A shr 8) and 255)-Integer((B shr 8) and 255))>45) or
              (Abs(Integer((A shr 16) and 255)-Integer((B shr 16) and 255))>45) then Inc(Bad);
          end;
        end;
        Writeln('EMF ',Name,' @',W,'x',H,': bad=',Bad,'/',W*H,' ink=',Ink,' expected=',ExpectedInk,' native=',NativeAccepted);
        { Compare block averages for dense pages: GDI and Skia use different text antialiasing. }
        CoarseBad:=0;
        for BY:=0 to H div 8-1 do for BX:=0 to W div 8-1 do begin
          FillChar(SumA,SizeOf(SumA),0);FillChar(SumB,SizeOf(SumB),0);
          for YY:=0 to 7 do begin
            Row:=@ReferencePixels[(BY*8+YY)*W];
            for XX:=0 to 7 do begin
              A:=Pixels[(BY*8+YY)*W+BX*8+XX];B:=Row[BX*8+XX];
              for C:=0 to 2 do begin
                Inc(SumA[C],(A shr (C*8)) and 255);Inc(SumB[C],(B shr (C*8)) and 255);
              end;
            end;
          end;
          Difference:=0;
          for C:=0 to 2 do Difference:=Math.Max(Difference,Abs(SumA[C]-SumB[C]) div 64);
          if Difference>45 then Inc(CoarseBad);
        end;
        if not NativeAccepted or (Copy(Name,1,7)='bitblt_') or (Copy(Name,1,8)='maskblt_') or
          (Copy(Name,1,7)='patblt_') or (Copy(Name,1,7)='plgblt_') or (Copy(Name,1,11)='stretchblt_') or
          (Copy(Name,1,13)='extcreatepen_') or (Pos('test_records_setpixel',Name)=1) or
          (Pos('test_records_alphablend',Name)=1) or (Pos('test_records_transparentblt',Name)=1) or
          (Pos('test_records_setdibitstodevice',Name)=1) then
          Check(ExactDifferent=0,'EMF raster pixels exactly match complete reference: '+Name)
        else if (Copy(Name,1,5)='real_') or (Copy(Name,1,5)='test_') or
          (Pos('opaque_transform_',Name)>0) or (Pos('exttextoutw_aligned_',Name)=1) or
          (Pos('exttextoutw_index_rtl_',Name)=1) or (Pos('polytextout',Name)=1) or
          (Pos('smalltextout',Name)=1) then
          Check((CoarseBad<W*H div 64 div 100) and (Ink*2>=ExpectedInk),'EMF page geometry matches GDI: '+Name)
        else Check((Bad<W*H div 20) and (Ink*2>=ExpectedInk),'EMF matches GDI: '+Name);

        Recorder:=TSkiaMetafileCanvas.Create(W,H);Stream:=TMemoryStream.Create;
        try
          Recorder.Brush.Color:=clWhite;Recorder.FillRect(Rect(0,0,W,H));
          Recorder.StretchDraw(Rect(0,0,W,H),Meta);Picture:=Recorder.FinishRecording;
          SVG:=TSkSVGCanvas.Make(RectF(0,0,W,H),Stream);Picture.Playback(SVG);SVG:=nil;
          Stream.SaveToFile(Output+Name+'.svg');
          if (Copy(Name,1,10)='exttextout') or (Pos('polytextout',Name)=1) or
            (Pos('smalltextout',Name)=1) then begin
            SetLength(Bytes,Stream.Size);Stream.Position:=0;Stream.ReadBuffer(Bytes[1],Length(Bytes));
            Check(((ExpectedInk=0) or (Pos(AnsiString('<path'),AnsiString(Bytes))>0)) and
              (Pos(AnsiString('<image'),AnsiString(Bytes))=0),'EMF text remains vector contours or clipped no-op: '+Name);
          end;
          Check(Stream.Size>100,'EMF recording exports SVG: '+Name);
          Stream.Clear;Document:=TSkDocument.MakePDF(Stream);
          SVG:=Document.BeginPage(W,H);Picture.Playback(SVG);SVG:=nil;
          Document.EndPage;Document.Close;Document:=nil;
          Stream.SaveToFile(Output+Name+'.pdf');
          Check(Stream.Size>500,'EMF recording exports PDF: '+Name);
        finally SVG:=nil;Stream.Free;Recorder.Free;end;
      finally Reference.Free;Bitmap.Free;Canvas.Free;Meta.Free;end;
    until FindNext(Search)<>0;
  finally SysUtils.FindClose(Search);end;
  Check(FileCount>0,'EMF image comparisons completed at '+IntToStr(W)+'x'+IntToStr(H));
  end;
end;
