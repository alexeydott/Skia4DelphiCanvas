unit EmfFuzzCore;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$MODESWITCH FUNCTIONREFERENCES}{$ENDIF}
{$R+}{$Q+}

interface

uses
  Classes, SysUtils, Types, Math, SyncObjs,
{$IFDEF FPC}
  Windows, Vcl.Graphics, Vcl.GraphUtil.MetafileParser, Vcl.Graphics.Skia;
{$ELSE}
  Winapi.Windows, Vcl.Graphics, Vcl.GraphUtil.MetafileParser, Vcl.Graphics.Skia;
{$ENDIF}

type
  TFuzzOptions = record
    Render: Boolean;
    TraceStages: Boolean;
    StorePrimitives: Boolean;
    ConvertTextToCurves: Boolean;
    CaseTimeoutMS: Cardinal;
    TimeBudgetMS: Cardinal;
    MemoryLimitMB: Cardinal;
    OutputDir: string;
  end;
  TFuzzStats = record
    Cases: Cardinal;
    RejectedByGDI: Cardinal;
    Parsed: Cardinal;
    Rendered: Cardinal;
    Replayed: Cardinal;
    ExpectedRejections: Cardinal;
    Failures: Cardinal;
    Hangs: Cardinal;
    RecordTypes: array[0..255] of Cardinal;
  end;
  TFuzzEngine = class
  private
    FSeed: Cardinal;
    FState: Cardinal;
    FStats: TFuzzStats;
    FOptions: TFuzzOptions;
    FRecordLog: string;
    FRecordCounts: array[0..255] of Cardinal;
    function NextRandom: Cardinal;
    function Range(AMax: Cardinal): Cardinal;
    procedure RecordSeen(Sender: TObject; ADC: HDC; ATable: Pointer; ARecord: PEnhMetaRecord; AObjects: Integer);
    function MakeSeedEMF: TBytes;
    function Mutate(const Source: TBytes; out Log: string): TBytes;
    function RunCase(const Data: TBytes; const CaseName: string; AIteration: Cardinal): Boolean;
    procedure SaveFailure(const Data: TBytes; const CaseName, Kind, Details: string; AIteration: Cardinal);
    function IsExpectedException(E: Exception): Boolean;
    function IsFailureException(E: Exception): Boolean;
    function HashBytes(const Data: TBytes): string;
    function ParseCase(P:TMetafileParser; M:TMetafile):Boolean;
    procedure TouchPrimitive(P: TMetafilePrimitive);
    procedure TraceStage(const Stage: string);
  public
    constructor Create(const Options: TFuzzOptions; ASeed: Cardinal);
    function Run(const Corpus: TStrings; Iterations: Cardinal): Boolean;
    property Stats: TFuzzStats read FStats;
    property Seed: Cardinal read FSeed;
  end;

function DefaultFuzzOptions: TFuzzOptions;
function RunEmfFuzzSmoke(ASeed, AIterations: Cardinal): Boolean;

implementation

{$IFDEF FPC}
type
  TFuzzStringList = class(TStringList)
  public
    function Add(const S: UnicodeString): Integer; reintroduce;
    procedure SaveToFile(const FileName: UnicodeString); reintroduce;
  end;
function TFuzzStringList.Add(const S:UnicodeString):Integer;
begin Result:=inherited Add(UTF8Encode(S));end;
procedure TFuzzStringList.SaveToFile(const FileName:UnicodeString);
begin inherited SaveToFile(UTF8Encode(FileName));end;
{$ELSE}
type
  TFuzzStringList = class(TStringList)
  public
    procedure SaveToFile(const FileName:UnicodeString); reintroduce;
  end;
procedure TFuzzStringList.SaveToFile(const FileName:UnicodeString);
begin inherited SaveToFile(FileName,TEncoding.UTF8);end;
{$ENDIF}

function FuzzPath(const S:UnicodeString):{$IFDEF FPC}UTF8String{$ELSE}string{$ENDIF};
begin {$IFDEF FPC}Result:=UTF8Encode(S);{$ELSE}Result:=S;{$ENDIF}end;
function FuzzListValue(const S:{$IFDEF FPC}AnsiString{$ELSE}string{$ENDIF}):UnicodeString;
begin {$IFDEF FPC}Result:=UTF8Decode(S);{$ELSE}Result:=S;{$ENDIF}end;
function FuzzInt(Value:Int64):UnicodeString;
begin Result:=UnicodeString(SysUtils.IntToStr(Value));end;
function FuzzHex(Value:Int64;Digits:Integer):UnicodeString;
begin Result:=UnicodeString(SysUtils.IntToHex(Value,Digits));end;

const
  BoundaryValues: array[0..14] of Cardinal = (0,1,2,$7F,$80,$FF,$7FFF,$8000,$FFFF,$7FFFFFFF,$80000000,$FFFFFFFF,$40000000,$3FFFFFFF,$10000);

function FuzzGetTickCount64: UInt64; stdcall; external 'kernel32.dll' name 'GetTickCount64';

function FuzzGetProcessMemoryInfo(Process: THandle; Buffer: Pointer; Size: DWORD): BOOL; stdcall; external 'psapi.dll' name 'GetProcessMemoryInfo';

type
  TFuzzBlendFunction = packed record BlendOp, BlendFlags, SourceConstantAlpha, AlphaFormat: Byte; end;
  TFuzzVertex = packed record X, Y: Longint; Red, Green, Blue, Alpha: Word; end;
  TFuzzGradientRect = packed record UpperLeft, LowerRight: Cardinal; end;
  TFuzzWatchdog = class(TThread)
  private
    FDone: TEvent;
    FLimit: Cardinal;
  protected
    procedure Execute; override;
  public
    constructor Create(ALimit: Cardinal);
    destructor Destroy; override;
    procedure Stop;
  end;

function FuzzAlphaBlend(DC: HDC; X,Y,W,H: Integer; Src: HDC; SX,SY,SW,SH: Integer; Blend: TFuzzBlendFunction): BOOL; stdcall; external 'msimg32.dll' name 'AlphaBlend';
function FuzzGradientFill(DC: HDC; Vertex: Pointer; NumVertex: Cardinal; Mesh: Pointer; NumMesh: Cardinal; Mode: Cardinal): BOOL; stdcall; external 'msimg32.dll' name 'GradientFill';
function FuzzExtCreatePen(Style, Width: Cardinal; Brush: Pointer; Count: Cardinal; Entries: Pointer): HPEN; stdcall; external 'gdi32.dll' name 'ExtCreatePen';

type
  TFuzzMemoryCounters = packed record
    cb: DWORD;
    PageFaultCount: DWORD;
    PeakWorkingSetSize: NativeUInt;
    WorkingSetSize: NativeUInt;
    QuotaPeakPagedPoolUsage: NativeUInt;
    QuotaPagedPoolUsage: NativeUInt;
    QuotaPeakNonPagedPoolUsage: NativeUInt;
    QuotaNonPagedPoolUsage: NativeUInt;
    PagefileUsage: NativeUInt;
    PeakPagefileUsage: NativeUInt;
  end;

constructor TFuzzWatchdog.Create(ALimit: Cardinal);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FDone := TEvent.Create(nil,True,False,'');
  FLimit := ALimit;
end;

destructor TFuzzWatchdog.Destroy;
begin
  Stop;
  inherited;
  FDone.Free;
end;
procedure TFuzzWatchdog.Stop;
begin
  Terminate;
  if FDone<>nil then FDone.SetEvent;
end;
procedure TFuzzWatchdog.Execute;
begin
  if FDone.WaitFor(FLimit)=wrTimeout then ExitProcess(3);
end;

type
  TFuzzReplayContext = record
    Player: TMetafileRecordPlayer;
    Error: Exception;
  end;
  PFuzzReplayContext = ^TFuzzReplayContext;
function FuzzReplayProc(DC:HDC; Table:{$IFDEF FPC}Pointer{$ELSE}PHandleTable{$ENDIF}; R:PEnhMetaRecord; Objects:Integer; User:Pointer):Integer; stdcall;
begin
  try
    PFuzzReplayContext(User).Player.Play(DC,Table,R,Objects);
    Result:=1;
  except
    on E:Exception do begin
      PFuzzReplayContext(User).Error:=ExceptClass(E.ClassType).Create(E.Message);
      Result:=0;
    end;
  end;
end;

function DefaultFuzzOptions: TFuzzOptions;
begin
  Result.Render := False;
  Result.TraceStages := False;
  Result.StorePrimitives := True;
  Result.ConvertTextToCurves := False;
  Result.CaseTimeoutMS := 2000;
  Result.TimeBudgetMS := 0;
  Result.MemoryLimitMB := 512;
  Result.OutputDir := 'fuzz-output';
end;

constructor TFuzzEngine.Create(const Options: TFuzzOptions; ASeed: Cardinal);
begin
  inherited Create;
  FOptions := Options;
  FOptions.OutputDir := ExpandFileName(StringReplace(Options.OutputDir, '/', '\', [rfReplaceAll]));
  FSeed := ASeed;
  if ASeed = 0 then FState := $A341316C else FState := ASeed;
  FillChar(FStats, SizeOf(FStats), 0);
  FillChar(FRecordCounts, SizeOf(FRecordCounts), 0);
end;

function TFuzzEngine.NextRandom: Cardinal;
begin
  FState := FState xor (FState shl 13);
  FState := FState xor (FState shr 17);
  FState := FState xor (FState shl 5);
  if FState = 0 then FState := $6D2B79F5;
  Result := FState;
end;

function TFuzzEngine.Range(AMax: Cardinal): Cardinal;
begin
  if AMax = 0 then Result := 0 else Result := NextRandom mod AMax;
end;

procedure TFuzzEngine.RecordSeen(Sender: TObject; ADC: HDC; ATable: Pointer; ARecord: PEnhMetaRecord; AObjects: Integer);
var K: Cardinal;
begin
  if ARecord = nil then Exit;
  K := ARecord.iType;
  if K <= High(FRecordCounts) then Inc(FRecordCounts[K]);
  if K <= High(FStats.RecordTypes) then Inc(FStats.RecordTypes[K]);
end;

function TFuzzEngine.MakeSeedEMF: TBytes;
var
  Meta: TMetafile;
  C: TMetafileCanvas;
  Pen, ExtPen: HPEN;
  Brush, Hatch: HBRUSH;
  Old: HGDIOBJ;
  LF: TLogFontW;
  LB: TLogBrush;
  X: TXForm;
  P: array[0..3] of TPoint;
  Bmp: TBitmap;
  Y: Integer;
  H: HENHMETAFILE;
  Size: Cardinal;
  TextClip: TRect;
  Rgn: HRGN; Dx: array[0..7] of Integer; Blend: TFuzzBlendFunction; Vtx: array[0..1] of TFuzzVertex; GR: TFuzzGradientRect;
begin
  Meta := TMetafile.Create;
  try
    Meta.Width := 256;
    Meta.Height := 256;
    C := TMetafileCanvas.Create(Meta, 0);
    try
      C.Brush.Color := clWhite;
      C.FillRect(Rect(0, 0, 256, 256));
      C.Pen.Color := clNavy;
      C.Pen.Width := 2;
      C.MoveTo(8, 8); C.LineTo(248, 248);
      P[0] := Point(16, 200); P[1] := Point(80, 40); P[2] := Point(160, 220); P[3] := Point(240, 40);
      C.Polyline(P);
      C.Polygon([Point(20, 20), Point(100, 15), Point(120, 100), Point(15, 120)]);
      C.PolyBezier([Point(20, 140), Point(60, 80), Point(180, 220), Point(230, 130)]);
      C.Arc(20, 20, 120, 120, 120, 70, 20, 70);
      C.Chord(130, 20, 240, 110, 240, 65, 130, 65);
      C.Pie(80, 120, 180, 220, 180, 170, 80, 170);
      Hatch := CreateHatchBrush(HS_DIAGCROSS, ColorToRGB(clGreen));
      if Hatch <> 0 then begin
        Old := SelectObject(C.Handle, Hatch);
        Rectangle(C.Handle, 145, 125, 235, 215);
        SelectObject(C.Handle, Old); DeleteObject(Hatch);
      end;
      Pen := CreatePen(PS_DASHDOT, 3, ColorToRGB(clRed));
      if Pen <> 0 then begin Old := SelectObject(C.Handle, Pen); C.Rectangle(4, 4, 252, 252); SelectObject(C.Handle, Old); DeleteObject(Pen); end;
      LB.lbStyle := BS_SOLID; LB.lbColor := ColorToRGB(TColor($800080)); LB.lbHatch := 0;
      ExtPen := FuzzExtCreatePen(PS_GEOMETRIC or PS_DASH, 4, @LB, 0, nil);
      if ExtPen <> 0 then begin Old := SelectObject(C.Handle, ExtPen); C.MoveTo(0, 128); C.LineTo(256, 128); SelectObject(C.Handle, Old); DeleteObject(ExtPen); end;
      FillChar(LF, SizeOf(LF), 0); LF.lfHeight := -24; LF.lfWeight := FW_BOLD; StrPLCopy(LF.lfFaceName, 'Arial', LF_FACESIZE - 1);
      C.Font.Name := 'Arial'; C.Font.Height := -20; C.Font.Style := [fsBold]; C.Font.Color := clBlack;
      C.TextOut(20, 225, 'EMF fuzz AVATAR');
      for Y := 0 to High(Dx) do Dx[Y] := 12 + (Y mod 3) * 2;
      TextClip:=Rect(10,220,250,255);
{$IFDEF FPC}      Windows.ExtTextOutW(C.Handle, 20, 245, ETO_CLIPPED, @TextClip, PWideChar('Dx fuzz'), 7, @Dx[0]);
{$ELSE}      Winapi.Windows.ExtTextOutW(C.Handle, 20, 245, ETO_CLIPPED, Rect(10, 220, 250, 255), PWideChar('Dx fuzz'), 7, @Dx[0]);
{$ENDIF}
      BeginPath(C.Handle); C.Ellipse(40, 35, 90, 85); EndPath(C.Handle); StrokePath(C.Handle);
      SaveDC(C.Handle); SetMapMode(C.Handle, MM_ISOTROPIC); SetWindowExtEx(C.Handle, 256, 256, nil); SetViewportExtEx(C.Handle, 256, 256, nil);
      SetGraphicsMode(C.Handle, GM_ADVANCED); X.eM11 := 1; X.eM12 := 0.1; X.eM21 := -0.1; X.eM22 := 1; X.eDx := 0; X.eDy := 0; SetWorldTransform(C.Handle, X);
      C.MoveTo(50, 180); C.LineTo(210, 180); RestoreDC(C.Handle, -1);
      SaveDC(C.Handle); Rgn := CreateRectRgn(24, 24, 232, 232); if Rgn <> 0 then begin ExtSelectClipRgn(C.Handle, Rgn, RGN_COPY); DeleteObject(Rgn); end;
      C.Brush.Color := TColor($C0C0C0); C.FillRect(Rect(30, 30, 225, 225)); RestoreDC(C.Handle, -1);
      Bmp := TBitmap.Create;
      try
        Bmp.PixelFormat := pf32bit; Bmp.SetSize(8, 8);
        Bmp.Canvas.Brush.Color:=TColor($7F7F7F);Bmp.Canvas.FillRect(Rect(0,0,8,8));
        BitBlt(C.Handle, 190, 50, 24, 24, Bmp.Canvas.Handle, 0, 0, SRCCOPY);
        StretchBlt(C.Handle, 190, 5, 40, 40, Bmp.Canvas.Handle, 0, 0, 8, 8, SRCCOPY);
        Brush := CreatePatternBrush(Bmp.Handle);
        if Brush <> 0 then begin Old := SelectObject(C.Handle, Brush); Rectangle(C.Handle, 5, 165, 45, 205); SelectObject(C.Handle, Old); DeleteObject(Brush); end;
        FillChar(Blend, SizeOf(Blend), 0); Blend.SourceConstantAlpha := 128; Blend.AlphaFormat := 0;
        FuzzAlphaBlend(C.Handle, 155, 5, 32, 32, Bmp.Canvas.Handle, 0, 0, 8, 8, Blend);
        Vtx[0].X := 60; Vtx[0].Y := 160; Vtx[0].Red := $ffff; Vtx[0].Green := 0; Vtx[0].Blue := 0; Vtx[0].Alpha := $ffff;
        Vtx[1].X := 120; Vtx[1].Y := 210; Vtx[1].Red := 0; Vtx[1].Green := $ffff; Vtx[1].Blue := 0; Vtx[1].Alpha := $ffff;
        GR.UpperLeft := 0; GR.LowerRight := 1; FuzzGradientFill(C.Handle, @Vtx[0], 2, @GR, 1, 0);
      finally Bmp.Free; end;
      Brush := CreateSolidBrush(ColorToRGB(clYellow));
      if Brush <> 0 then begin Old := SelectObject(C.Handle, Brush); Ellipse(C.Handle, 185, 185, 245, 245); SelectObject(C.Handle, Old); DeleteObject(Brush); end;
    finally C.Free; end;
    H := CopyEnhMetaFile(Meta.Handle, nil);
    if H = 0 then begin Result := nil; Exit; end;
    try
      Size := GetEnhMetaFileBits(H, 0, nil);
      SetLength(Result, Size);
      if (Size = 0) or (GetEnhMetaFileBits(H, Size, @Result[0]) <> Size) then SetLength(Result, 0);
    finally DeleteEnhMetaFile(H); end;
  finally Meta.Free; end;
end;

function TFuzzEngine.Mutate(const Source: TBytes; out Log: string): TBytes;
type TRec = record Kind, Declared: Cardinal; Data: TBytes; end;
var R: array of TRec; N, Pos, I, J, Mut, K, Off, D: Integer; T: TRec; V: Cardinal;
  procedure AppendLog(const S: string); begin if Log <> '' then Log := Log + '; '; Log := Log + S; end;
  procedure ReadDWord(var B: TBytes; AOffset: Integer; AValue: Cardinal); begin if (AOffset >= 0) and (AOffset + 4 <= Length(B)) then Move(AValue, B[AOffset], 4); end;
begin
  Result := Copy(Source); Log := '';
  if Length(Result) < 108 then Exit;
  Pos := 108; N := 0;
  while Pos + 8 <= Length(Source) do begin
    SetLength(R, N + 1); R[N].Kind := PCardinal(@Source[Pos])^; R[N].Declared := PCardinal(@Source[Pos + 4])^;
    if R[N].Declared > Cardinal(Length(Source)-Pos) then D := Length(Source)-Pos else D := Integer(R[N].Declared); if D < 8 then D := 8;
    SetLength(R[N].Data, D); Move(Source[Pos], R[N].Data[0], D); Inc(N); Inc(Pos, D); if D < 8 then Break;
  end;
  if N = 0 then Exit;
  Mut := 1 + Integer(Range(3));
  for I := 1 to Mut do begin
    J := Integer(Range(Cardinal(N))); K := Integer(Range(7));
    case K of
      0: begin V := BoundaryValues[Range(Length(BoundaryValues))]; ReadDWord(R[J].Data, 8 + Integer(Range(Cardinal(Max(1, (Length(R[J].Data) - 8) div 4 + 1)))) * 4, V); AppendLog('field='+FuzzInt(J)+'='+FuzzHex(V,8)); end;
      1: begin if Length(R[J].Data) > 8 then begin Off := 8 + Integer(Range(Cardinal(Length(R[J].Data)-8))); R[J].Data[Off] := Byte(R[J].Data[Off]) xor Byte(1 shl Range(8)); AppendLog('bitflip='+FuzzInt(J)+':'+FuzzInt(Off)); end; end;
      2: begin R[J].Kind := BoundaryValues[Range(Length(BoundaryValues))]; Move(R[J].Kind, R[J].Data[0], 4); AppendLog('type='+FuzzInt(J)); end;
      3: begin R[J].Declared := 8 + Range(1024); Move(R[J].Declared, R[J].Data[4], 4); AppendLog('nSize='+FuzzInt(J)); end;
      4: begin if Length(R[J].Data) > 8 then R[J].Data[8 + Range(Length(R[J].Data)-8)] := Byte(NextRandom and $FF); AppendLog('random='+FuzzInt(J)); end;
      5: begin if N > 1 then begin T := R[J]; R[J] := R[(J+1) mod N]; R[(J+1) mod N] := T; AppendLog('swap'); end; end;
      else begin R[J].Declared := 8 + ((Length(R[J].Data)-8) and not 3); if R[J].Declared < 8 then R[J].Declared := 8; Move(R[J].Declared, R[J].Data[4], 4); AppendLog('align='+FuzzInt(J)); end;
    end;
  end;
  if Range(4) = 0 then begin
    SetLength(R, N + 1); Pos:=N; if R[N-1].Kind=14 then begin R[N]:=R[N-1];Pos:=N-1;end; R[Pos].Kind := 0; R[Pos].Declared := 0; R[Pos].Data := nil; K := 84 + Integer(Range(2)) * 34;
    R[Pos].Kind := K; if K = 84 then begin SetLength(R[Pos].Data, 84); FillChar(R[Pos].Data[0], Length(R[Pos].Data), 0); V := $7fffffff; Move(V, R[Pos].Data[40], 4); V := 76; Move(V, R[Pos].Data[48], 4); V := $ffffff00; Move(V, R[Pos].Data[52], 4); end
    else begin SetLength(R[Pos].Data, 44); FillChar(R[Pos].Data[0], Length(R[Pos].Data), 0); V := $7fffffff; Move(V, R[Pos].Data[24], 4); V := $7fffffff; Move(V, R[Pos].Data[28], 4); end;
    R[Pos].Declared := Length(R[Pos].Data); Move(R[Pos].Kind, R[Pos].Data[0], 4); Move(R[Pos].Declared, R[Pos].Data[4], 4); Inc(N); AppendLog('inject='+FuzzInt(K));
  end;
  if Range(2) = 0 then begin I := Integer(Range(Cardinal(N))); T:=R[I]; SetLength(R, N+1);Pos:=N; if R[N-1].Kind=14 then begin R[N]:=R[N-1];Pos:=N-1;end; R[Pos] := T; Inc(N); AppendLog('duplicate='+FuzzInt(I)); end;
  if (N > 2) and (Range(3) = 0) then begin I := Integer(Range(Cardinal(N))); for J := I to N-2 do R[J] := R[J+1]; Dec(N); AppendLog('remove='+FuzzInt(I)); end;
  SetLength(Result, 108); Move(Source[0], Result[0], 108);
  for I := 0 to N - 1 do begin Off := Length(Result); SetLength(Result, Off + Length(R[I].Data)); if Length(R[I].Data) > 0 then Move(R[I].Data[0], Result[Off], Length(R[I].Data)); end;
  if Range(2) = 0 then begin if Length(Result) >= 56 then begin D := Length(Result); Move(D, Result[48], 4); D := N + 1; Move(D, Result[52], 4); AppendLog('fix-header'); end; end else AppendLog('unfixed-header');
end;

function TFuzzEngine.HashBytes(const Data: TBytes): string;
var H: Cardinal; I: Integer;
begin H := $811C9DC5; for I := 0 to High(Data) do begin H := H xor Byte(Data[I]); H := Cardinal((UInt64(H) * 16777619) and $FFFFFFFF); end; Result := FuzzHex(H, 8); end;

procedure TFuzzEngine.SaveFailure(const Data: TBytes; const CaseName, Kind, Details: string; AIteration: Cardinal);
var Dir, Base, FN: string; F: TFileStream; T: TFuzzStringList;
begin
  Dir := IncludeTrailingPathDelimiter(FOptions.OutputDir) + 'crashes'; ForceDirectories(Dir);
  Base := Kind + '-' + HashBytes(Data); FN := IncludeTrailingPathDelimiter(Dir) + Base;
  F := TFileStream.Create(FuzzPath(FN + '.emf'), fmCreate); try if Length(Data)>0 then F.WriteBuffer(Data[0], Length(Data)); finally F.Free; end;
  T := TFuzzStringList.Create; try T.Add('case='+CaseName); T.Add('kind='+Kind); T.Add('seed='+FuzzInt(FSeed)); T.Add('iteration='+FuzzInt(AIteration)); T.Add('hash='+HashBytes(Data)); T.Add('mutations='+FRecordLog); T.Add(Details); T.SaveToFile(FN+'.txt'); finally T.Free; end;
end;

function TFuzzEngine.IsExpectedException(E: Exception): Boolean;
var N: string;
begin N := UnicodeString(E.ClassName); Result := (Pos('ESkiaCanvasError', N) > 0) or (Pos('Metafile', N) > 0) or (Pos('Convert', N) > 0) or (Pos('EInvalidGraphic', N) > 0) or (E is EReadError); end;
function TFuzzEngine.IsFailureException(E: Exception): Boolean;
var N: string;
begin N := UnicodeString(E.ClassName); Result := (Pos('EAccessViolation', N) > 0) or (Pos('EOutOfMemory', N) > 0) or (Pos('EIntOverflow', N) > 0) or (Pos('ERangeError', N) > 0) or (Pos('EInvalidOp', N) > 0) or (Pos('EStackOverflow', N) > 0) or (Pos('EZeroDivide', N) > 0) or (Pos('range check',LowerCase(E.Message))>0) or (Pos('overflow',LowerCase(E.Message))>0) or (Pos('access violation',LowerCase(E.Message))>0) or (Pos('division by zero',LowerCase(E.Message))>0) or (Pos('invalid floating',LowerCase(E.Message))>0); end;

function TFuzzEngine.ParseCase(P:TMetafileParser; M:TMetafile):Boolean;
var Msg:string;
begin
  Result:=P.LoadFromMetafile(M);
  if Result then Exit;
  Msg:=LowerCase(P.LastError);
  if (Pos('range check',Msg)>0) or (Pos('overflow',Msg)>0) or
    (Pos('access violation',Msg)>0) or (Pos('division by zero',Msg)>0) or
    (Pos('invalid floating',Msg)>0) then
    raise ERangeError.Create(FuzzPath('Parser swallowed exception: '+P.LastError));
end;

procedure TFuzzEngine.TraceStage(const Stage: string);
var F: TextFile;MC:TFuzzMemoryCounters;N:string;
begin
  if not FOptions.TraceStages then Exit;
  N:=IncludeTrailingPathDelimiter(FOptions.OutputDir)+'stage.txt';
  AssignFile(F,N);
  if FileExists(N) then Append(F) else Rewrite(F);
  FillChar(MC,SizeOf(MC),0);MC.cb:=SizeOf(MC);
  FuzzGetProcessMemoryInfo(GetCurrentProcess,@MC,SizeOf(MC));
  try Writeln(F,Stage,' working=',MC.WorkingSetSize,' peak=',MC.PeakWorkingSetSize,' private=',MC.PagefileUsage,' peak-private=',MC.PeakPagefileUsage);Flush(F);finally CloseFile(F);end;
end;

procedure TFuzzEngine.TouchPrimitive(P: TMetafilePrimitive);
var J,K:Integer; A:TMetafilePointArray;
begin
  if P=nil then Exit;
  for J:=0 to High(P.Points) do
    if IsNan(P.Points[J].X) or IsInfinite(P.Points[J].X) or
      IsNan(P.Points[J].Y) or IsInfinite(P.Points[J].Y) then
      raise EInvalidOp.Create('Non-finite primitive point');
  for J:=0 to High(P.PointCounts) do begin
    A:=P.SubPoints(J);
    if Length(A)<>P.PointCounts[J] then raise ERangeError.Create('Invalid primitive subpath');
    for K:=0 to High(A) do
      if IsNan(A[K].X) or IsInfinite(A[K].X) or IsNan(A[K].Y) or IsInfinite(A[K].Y) then
        raise EInvalidOp.Create('Non-finite subpath point');
  end;
end;

function TFuzzEngine.RunCase(const Data: TBytes; const CaseName: string; AIteration: Cardinal): Boolean;
var
  H: HENHMETAFILE;
  M: TMetafile;
  P: TMetafileParser;
  Watchdog: TFuzzWatchdog;
  I: Integer;
  C: TSkiaBitmapCanvas;
  DC: HDC;
  Player: TMetafileRecordPlayer;
    StartTick: UInt64;
  MC: TFuzzMemoryCounters;
  BeforeMem: NativeUInt;
  Metadata: TFuzzStringList;
  E: Exception;
  Replay: TFuzzReplayContext;
  Bounds: TRect;
{$IFDEF FPC}
  InputStream: TBytesStream;
{$ENDIF}
begin
  Result := True;
  Inc(FStats.Cases);
  if FOptions.TraceStages then SysUtils.DeleteFile(IncludeTrailingPathDelimiter(FOptions.OutputDir)+'stage.txt');
  ForceDirectories(FOptions.OutputDir);
  with TFileStream.Create(FuzzPath(IncludeTrailingPathDelimiter(FOptions.OutputDir) + 'current.emf'), fmCreate) do
  try
    if Length(Data) > 0 then
      WriteBuffer(Data[0], Length(Data));
  finally
    Free;
  end;
  Metadata:=TFuzzStringList.Create;
  try
    Metadata.Add('case='+CaseName);
    Metadata.Add('seed='+FuzzInt(FSeed));
    Metadata.Add('iteration='+FuzzInt(AIteration));
    Metadata.Add('mutations='+FRecordLog);
    Metadata.SaveToFile(IncludeTrailingPathDelimiter(FOptions.OutputDir)+'current.txt');
  finally Metadata.Free;end;
  FillChar(MC, SizeOf(MC), 0);
  MC.cb := SizeOf(MC);
  BeforeMem := 0;
  if FuzzGetProcessMemoryInfo(GetCurrentProcess, @MC, SizeOf(MC)) then
  begin
    BeforeMem := MC.PeakPagefileUsage;
    if MC.PeakWorkingSetSize > BeforeMem then
      BeforeMem := MC.PeakWorkingSetSize;
  end;
  H := 0;
  M := nil;
  P := nil;
  C := nil;
  DC := 0;
  Player := nil;
  Watchdog := nil;
  StartTick := FuzzGetTickCount64;
  if FOptions.CaseTimeoutMS <> 0 then
  begin
    Watchdog := TFuzzWatchdog.Create(FOptions.CaseTimeoutMS);
    Watchdog.Start;
  end;
  try
   try
    if Length(Data) > 0 then
    begin
      TraceStage('SetEnhMetaFileBits');
      H := SetEnhMetaFileBits(Length(Data), @Data[0]);
      if H = 0 then
        Inc(FStats.RejectedByGDI)
      else
      begin
        M := TMetafile.Create;
{$IFDEF FPC}
        InputStream:=TBytesStream.Create(Data);
        try M.LoadFromStream(InputStream);finally InputStream.Free;end;
        DeleteEnhMetaFile(H);
{$ELSE}
        M.Handle := H;
{$ENDIF}
        H := 0;
        P := TMetafileParser.Create;
        P.StorePrimitives := FOptions.StorePrimitives;
        P.ConvertTextToCurves := False;
        P.OnRecord := RecordSeen;
        TraceStage('parse primitives');
        if ParseCase(P,M) then
        begin
          TraceStage('parsed primitives');
          Inc(FStats.Parsed);
          for I := 0 to P.PrimitiveCount - 1 do
            TouchPrimitive(P.PrimitiveByIndex(I));
          P.ConvertTextToCurves := True;
          TraceStage('parse primitives');
        if ParseCase(P,M) then begin
          TraceStage('parsed text outlines');
          for I:=0 to P.PrimitiveCount-1 do TouchPrimitive(P.PrimitiveByIndex(I));
          if FOptions.Render then
          begin
            C := TSkiaBitmapCanvas.Create(256, 256);
            try
              TraceStage('Skia render');
              C.Draw(0, 0, M);
              Inc(FStats.Rendered);
              TraceStage('Skia rendered');
            finally
              C.Free;
              C := nil;
            end;
          end;
          DC := CreateCompatibleDC(0);
          Player := TMetafileRecordPlayer.Create;
          Replay.Player := Player;
          Replay.Error := nil;
          Bounds := Rect(0,0,256,256);
          TraceStage('native replay');
          EnumEnhMetaFile(DC,M.Handle,@FuzzReplayProc,@Replay,Bounds);
          if Replay.Error <> nil then
            raise Replay.Error;
          Inc(FStats.Replayed);
          end else Inc(FStats.ExpectedRejections);
        end
        else
          Inc(FStats.ExpectedRejections);
      end;
    end;
  except
    on X: Exception do
    begin
      E := X;
      if IsFailureException(E) then
      begin
        Inc(FStats.Failures);
        SaveFailure(Data, CaseName, 'failure', UnicodeString(E.ClassName) + ': ' + UnicodeString(E.Message), AIteration);
        Result := False;
      end
      else if IsExpectedException(E) then
        Inc(FStats.ExpectedRejections)
      else
      begin
        Inc(FStats.Failures);
        SaveFailure(Data, CaseName, 'exception', UnicodeString(E.ClassName) + ': ' + UnicodeString(E.Message), AIteration);
        Result := False;
      end;
    end;
   end;
  finally
    if Watchdog <> nil then
    begin
      Watchdog.Stop;
      Watchdog.WaitFor;
      Watchdog.Free;
    end;
    if C <> nil then
      C.Free;
    if Player <> nil then
      Player.Free;
    if DC <> 0 then
      DeleteDC(DC);
    if P <> nil then
      P.Free;
    if M <> nil then
      M.Free;
    if H <> 0 then
      DeleteEnhMetaFile(H);
  end;
  if (FOptions.CaseTimeoutMS <> 0) and (FuzzGetTickCount64 - StartTick > FOptions.CaseTimeoutMS) then
  begin
    Inc(FStats.Hangs);
    SaveFailure(Data, CaseName, 'hang', 'case exceeded wall-clock budget after return', AIteration);
    Result := False;
  end;
  TraceStage('completed');
  FillChar(MC, SizeOf(MC), 0);
  MC.cb := SizeOf(MC);
  if (BeforeMem <> 0) and FuzzGetProcessMemoryInfo(GetCurrentProcess, @MC, SizeOf(MC)) and
     ((MC.PeakPagefileUsage > UInt64(BeforeMem) + UInt64(FOptions.MemoryLimitMB) * 1024 * 1024) or
      (MC.PeakWorkingSetSize > UInt64(BeforeMem) + UInt64(FOptions.MemoryLimitMB) * 1024 * 1024)) then
  begin
    Inc(FStats.Failures);
    SaveFailure(Data, CaseName, 'memory', 'process memory peak delta exceeded limit', AIteration);
    Result := False;
  end;
end;

function TFuzzEngine.Run(const Corpus: TStrings; Iterations: Cardinal): Boolean;
var I: Integer; Seed, Data: TBytes; Started: UInt64; Name: string; F: TFileStream; Files: TFuzzStringList; SR: TSearchRec; Dir: string; Log: string;
begin
  Result := True; Started := FuzzGetTickCount64; Seed := nil;
  if (Corpus.Count=0) or (Iterations<>0) then begin
    Seed:=MakeSeedEMF;
    if Length(Seed)=0 then raise EReadError.Create('Could not record EMF seed');
    if not RunCase(Seed,'generated-seed',0) then Result:=False;
  end;
  Files := TFuzzStringList.Create; try
    for I := 0 to Corpus.Count - 1 do begin Dir := ExcludeTrailingPathDelimiter(FuzzListValue(Corpus[I])); if FindFirst(FuzzPath(IncludeTrailingPathDelimiter(Dir)+'*.emf'), faAnyFile, SR)=0 then try repeat Files.Add(IncludeTrailingPathDelimiter(Dir)+FuzzListValue(SR.Name)); until FindNext(SR)<>0; finally SysUtils.FindClose(SR); end; end;
    if (Corpus.Count>0) and (Files.Count=0) then raise EArgumentException.Create('No EMF files in corpus/regression directories');
    Files.Sort;
    for I := 0 to Files.Count - 1 do begin if (FOptions.TimeBudgetMS <> 0) and (FuzzGetTickCount64 - Started >= FOptions.TimeBudgetMS) then Break; F := TFileStream.Create(Files[I], fmOpenRead or fmShareDenyNone); try SetLength(Data, F.Size); if Length(Data)>0 then F.ReadBuffer(Data[0], Length(Data)); finally F.Free; end; Name := ExtractFileName(FuzzListValue(Files[I])); FRecordLog := 'corpus'; if not RunCase(Data, Name, I) then Result := False; end;
  finally Files.Free; end;
  for I := 1 to Iterations do begin if (FOptions.TimeBudgetMS <> 0) and (FuzzGetTickCount64 - Started >= FOptions.TimeBudgetMS) then Break; Data := Mutate(Seed, Log); FRecordLog := Log; if not RunCase(Data, 'generated-'+FuzzInt(I), I) then Result := False; end;
end;

function RunEmfFuzzSmoke(ASeed, AIterations: Cardinal): Boolean;
var O: TFuzzOptions; E: TFuzzEngine; L: TStringList;
begin O := DefaultFuzzOptions; O.OutputDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)))+'fuzz-smoke-output'; E := TFuzzEngine.Create(O,ASeed); L := TStringList.Create; try Result := E.Run(L,AIterations); finally L.Free; E.Free; end; end;

end.
