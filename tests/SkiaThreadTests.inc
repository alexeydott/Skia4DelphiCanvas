{ Cross-platform start signals and bounded joins for the rendering workers. }
type TThreadStartSignal={$IFDEF MSWINDOWS}THandle{$ELSE}SyncObjs.TEvent{$ENDIF};
function CreateStartSignal:TThreadStartSignal;
begin {$IFDEF MSWINDOWS}Result:=CreateEvent(nil,True,False,nil);{$ELSE}Result:=SyncObjs.TEvent.Create(nil,True,False,'');{$ENDIF} end;
procedure ResetStartSignal(Signal:TThreadStartSignal);
begin {$IFDEF MSWINDOWS}ResetEvent(Signal);{$ELSE}Signal.ResetEvent;{$ENDIF} end;
procedure ReleaseStartSignal(Signal:TThreadStartSignal);
begin {$IFDEF MSWINDOWS}SetEvent(Signal);{$ELSE}Signal.SetEvent;{$ENDIF} end;
procedure DestroyStartSignal(Signal:TThreadStartSignal);
begin {$IFDEF MSWINDOWS}CloseHandle(Signal);{$ELSE}Signal.Free;{$ENDIF} end;
function AwaitStartSignal(Signal:TThreadStartSignal;Timeout:Cardinal):Boolean;
begin {$IFDEF MSWINDOWS}Result:=WaitForSingleObject(Signal,Timeout)=WAIT_OBJECT_0;{$ELSE}Result:=Signal.WaitFor(Timeout)=SyncObjs.wrSignaled;{$ENDIF} end;
function AwaitThread(Worker:TThread;Timeout:Cardinal):Boolean;
{$IFNDEF MSWINDOWS}var Started:QWord;{$ENDIF}
begin
  {$IFDEF MSWINDOWS}Result:=WaitForSingleObject(Worker.Handle,Timeout)=WAIT_OBJECT_0;
  {$ELSE}
  Started:=GetTickCount64;
  while not Worker.Finished and (GetTickCount64-Started<Timeout) do Sleep(1);
  Result:=Worker.Finished;
  {$ENDIF}
end;

{ Native multithreaded rendering, shared caches and target-lock integration tests. }
type
  TSkiaThreadWorker = class(TThread)
  private
    FMode,FIndex: Integer;
    FStart: TThreadStartSignal;
    FManager: TSkiaFontManager;
    FResources: TSkiaResourceManager;
    FGlyphs: TSkiaGdiGlyphCache;
    FTarget: ISkCanvas;
    FAlias: TSkiaCanvas;
    FError: string;
    FCompleted: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(Mode,Index:Integer;Start:TThreadStartSignal;Manager:TSkiaFontManager;
      Resources:TSkiaResourceManager;Glyphs:TSkiaGdiGlyphCache;const Target:ISkCanvas);
  end;

constructor TSkiaThreadWorker.Create(Mode,Index:Integer;Start:TThreadStartSignal;
  Manager:TSkiaFontManager;Resources:TSkiaResourceManager;Glyphs:TSkiaGdiGlyphCache;
  const Target:ISkCanvas);
begin
  inherited Create(True); FreeOnTerminate:=False;
  FMode:=Mode;FIndex:=Index;FStart:=Start;FManager:=Manager;FResources:=Resources;
  FGlyphs:=Glyphs;FTarget:=Target;
end;

procedure TSkiaThreadWorker.Execute;
var I,S,Em:Integer;C:TSkiaBitmapCanvas;AliasCanvas:TSkiaCanvas;Font:TFont;
  Brush:TSkiaBrush;Face:ISkTypeface;Paint:ISkPaint;LF:TLogFontW;Key:string;
  Glyphs:TArray<TGdiShapedGlyph>;Path:ISkPath;Advance:Single;Color:TColor;{$IFDEF MSWINDOWS}Meta:TMetafile;{$ENDIF}
begin
  try
    if not AwaitStartSignal(FStart,10000) then
      raise Exception.Create('Worker start timed out');
    case FMode of
      0:for I:=1 to 80 do begin
        C:=TSkiaBitmapCanvas.Create(24,24);
        try
          AliasCanvas:=TSkiaCanvas.Create(C.SkCanvas);
          try
            AliasCanvas.Lock;
            try
              AliasCanvas.Brush.Color:=clRed;AliasCanvas.FillRect(Rect(0,0,24,24));
              AliasCanvas.CopyMode:=TCopyMode($00550009);AliasCanvas.BitBlt(0,0,24,24,C,0,0);
            finally AliasCanvas.Unlock;end;
            if C.Pixels[10,10]<>TColor($FFFF00) then raise Exception.Create('Alias backing lost ROP pixels');
          finally AliasCanvas.Free;end;
        finally C.Free;end;
        Inc(FCompleted);
      end;
      1:begin
        Font:=TFont.Create;Brush:=TSkiaBrush.Create;
        try
          Font.Name:='Arial';Font.Height:=-20;Brush.Color:=TColor($102030+FIndex);
          for I:=1 to 100 do begin
            Face:=FManager.AcquireTypeface(Font);
            if Face=nil then raise Exception.Create('Shared typeface lookup failed');
            FManager.RegisterTypeface('Concurrent'+IntToStr(FIndex),Face);
            if FManager.MatchTypefaceForText('AV','Arial')=nil then raise Exception.Create('Shared coverage lookup failed');
            FManager.UnregisterTypeface('Concurrent'+IntToStr(FIndex));
            if I mod 7=0 then FManager.Clear;
            if I mod 20=0 then
              Face:=FManager.LoadTypefaceFromFile(ExtractFilePath(ParamStr(0))+'..'+PathDelim+'..'+PathDelim+'fixtures'+PathDelim+'SkiaFixture.ttf');
            Paint:=FResources.AcquireFillPaint(Brush,RectF(0,0,24,24));
            if (Paint=nil) or (Paint.Color<>ColorToAlphaColor(Brush.Color)) then raise Exception.Create('Shared paint cache returned wrong color');
            if FResources.AcquireFont(Font)=nil then raise Exception.Create('Shared resource font failed');
            if I mod 5=0 then FResources.InvalidateAll;
            Inc(FCompleted);
          end;
        finally Brush.Free;Font.Free;end;
      end;
      2:begin
        FillChar(LF,SizeOf(LF),0);LF.lfHeight:=-20;LF.lfWeight:=FW_NORMAL;
        if FIndex mod 2=0 then StrPLCopy(LF.lfFaceName,'Arial',LF_FACESIZE-1)
        else StrPLCopy(LF.lfFaceName,'Times New Roman',LF_FACESIZE-1);
        Key:=string(LF.lfFaceName);
        for I:=1 to 70 do begin
          FGlyphs.Lock;
          try
            Em:=FGlyphs.GetEmSquare(LF,Key);
            if not FGlyphs.ShapeText(LF,Key,Em,#$0633#$0644#$0627#$0645,Glyphs,True) then raise Exception.Create('Shared OpenType shaping failed');
            if not FGlyphs.LastShapeUsedOpenType then raise Exception.Create('Shared shaping bypassed OpenType');
            if Length(Glyphs)=0 then raise Exception.Create('Shared glyph run is empty');
            Path:=FGlyphs.GetGlyphPathByIndex(Glyphs[0].GlyphIndex,Advance);
            if (Path=nil) or (Advance<=0) then raise Exception.Create('Shared glyph outline missing');
            if I mod 9=0 then FGlyphs.Clear;
          finally FGlyphs.Unlock;end;
          Inc(FCompleted);
        end;
      end;
      3:begin
        AliasCanvas:=TSkiaCanvas.Create(FTarget);
        try
          Color:=TColor($102030+FIndex*$10101);
          for I:=1 to 70 do begin
            AliasCanvas.Lock;
            try
              if not AliasCanvas.TryLock then raise Exception.Create('Recursive TryLock failed');
              AliasCanvas.Unlock;
              S:=AliasCanvas.SaveState;
              try
                AliasCanvas.Brush.Color:=Color;
                AliasCanvas.FillRect(Rect(0,FIndex*4,32,FIndex*4+4));
                AliasCanvas.TranslateTransform(1,1);
              finally AliasCanvas.RestoreState(S);end;
            finally AliasCanvas.Unlock;end;
            Inc(FCompleted);
          end;
        finally AliasCanvas.Free;end;
      end;
      {$IFDEF MSWINDOWS}
      5:for I:=1 to 5 do begin
        Meta:=TMetafile.Create;C:=TSkiaBitmapCanvas.Create(160,100);
        try
          case FIndex mod 3 of
            0:Key:='exttextoutw_glyphs.emf';
            1:Key:='extcreatepen_monopattern.emf';
            2:Key:='extcreatepen_pattern8x8_brushorg_rotateshear_xform.emf';
          end;
          Meta.LoadFromFile(ExtractFilePath(ParamStr(0))+'..\..\fixtures\emf\'+Key);
          C.Brush.Color:=clWhite;C.FillRect(Rect(0,0,160,100));
          C.StretchDraw(Rect(0,0,160,100),Meta);
          Inc(FCompleted);
        finally C.Free;Meta.Free;end;
      end;
      {$ENDIF}
      4:begin
        if FAlias.TryLock then begin FAlias.Unlock;raise Exception.Create('Alias TryLock ignored another owner');end;
        FCompleted:=1;
      end;
    end;
  except on E:Exception do FError:=E.ClassName+': '+E.Message;end;
end;

type
  TSkiaCallbackReader = class(TThread)
  public
    Manager: TSkiaFontManager;
    Success: Boolean;
    procedure Execute; override;
  end;
  TSkiaChangeObserver = class
  public
    Manager: TSkiaFontManager;
    Count: Integer;
    procedure Changed(Sender:TObject);
  end;

procedure TSkiaCallbackReader.Execute;
begin
  try Success:=Manager.MatchTypefaceForText('AV','Arial')<>nil;
  except Success:=False;end;
end;

procedure TSkiaChangeObserver.Changed(Sender:TObject);
var Reader:TSkiaCallbackReader;
begin
  Inc(Count);
  Reader:=TSkiaCallbackReader.Create(True);
  Reader.FreeOnTerminate:=False;Reader.Manager:=Manager;Reader.Start;
  if not AwaitThread(Reader,10000) then begin
    Writeln('FAIL: font callback holds the cache lock');Halt(1);
  end;
  Reader.WaitFor;
  try
    if not Reader.Success then raise Exception.Create('Callback worker cannot read font cache');
  finally Reader.Free;end;
end;

procedure TestFontThreadCallbacks;
var Manager:TSkiaFontManager;Observer:TSkiaChangeObserver;Face:ISkTypeface;
begin
  Manager:=TSkiaFontManager.Create;Observer:=TSkiaChangeObserver.Create;
  try
    Observer.Manager:=Manager;Manager.OnChange:=Observer.Changed;
    Face:=Manager.MatchTypefaceForText('AV','Arial');
    Manager.RegisterTypeface('CallbackFace',Face);
    Manager.Clear;
    Check(Observer.Count=2,'font callbacks allow another thread to read the manager');
    Manager.Free;Manager:=nil;
    Check(Observer.Count=2,'font destruction does not call subscribers');
  finally Manager.Free;Observer.Free;end;
end;

procedure TestThreadSafety;
const WorkerCount=8;
var Workers:array[0..WorkerCount-1] of TSkiaThreadWorker;
  Manager:TSkiaFontManager;Resources:TSkiaResourceManager;Cache,Reference:TSkiaGdiGlyphCache;
  Target:TSkiaBitmapCanvas;AliasCanvas:TSkiaCanvas;Start:TThreadStartSignal;Mode,I,Expected,Em:Integer;
  LF:TLogFontW;Glyphs:TArray<TGdiShapedGlyph>;Path:ISkPath;A,B:Single;
  procedure RunWorkers(WorkerMode,Count,Iterations:Integer);
  var J:Integer;
  begin
    ResetStartSignal(Start);
    for J:=0 to Count-1 do begin
      Workers[J]:=TSkiaThreadWorker.Create(WorkerMode,J,Start,Manager,Resources,Cache,Target.SkCanvas);
      Workers[J].Start;
    end;
    ReleaseStartSignal(Start);
    for J:=0 to Count-1 do begin
      if not AwaitThread(Workers[J],60000) then begin
        Writeln('FAIL: worker deadlock in mode ',WorkerMode);Halt(1);
      end;
      Workers[J].WaitFor;
      Check((Workers[J].FError='') and (Workers[J].FCompleted=Iterations),
        'thread mode '+IntToStr(WorkerMode)+' worker '+IntToStr(J)+' '+Workers[J].FError);
      Workers[J].Free;
    end;
  end;
begin
  TestFontThreadCallbacks;
  Resources:=TSkiaResourceManager.Create;Manager:=Resources.FontManager;
  Cache:=TSkiaGdiGlyphCache.Create;Reference:=TSkiaGdiGlyphCache.Create;
  Target:=TSkiaBitmapCanvas.Create(32,32);Start:=CreateStartSignal;
  try
    for Mode:=0 to 3 do begin
      case Mode of 0:Expected:=80;1:Expected:=100;else Expected:=70;end;
      RunWorkers(Mode,WorkerCount,Expected);
    end;
    {$IFDEF MSWINDOWS}RunWorkers(5,WorkerCount,5);{$ENDIF}
    for I:=0 to WorkerCount-1 do Check(Target.Pixels[10,I*4+1]=TColor($102030+I*$10101),'shared target row '+IntToStr(I));
    AliasCanvas:=TSkiaCanvas.Create(Target.SkCanvas);
    try
      Workers[0]:=TSkiaThreadWorker.Create(4,0,Start,Manager,Resources,Cache,Target.SkCanvas);
      Workers[0].FAlias:=AliasCanvas;
      Target.Lock;
      try
        Check(Target.TryLock,'same-thread recursive target lock');Target.Unlock;
        Workers[0].Start;
        if not AwaitThread(Workers[0],10000) then Halt(1);
        Workers[0].WaitFor;
        Check((Workers[0].FError='') and (Workers[0].FCompleted=1),'alias TryLock rejects another thread');
      finally Target.Unlock;end;
      Workers[0].Free;
      Check(AliasCanvas.TryLock,'alias TryLock succeeds after owner releases');AliasCanvas.Unlock;
    finally AliasCanvas.Free;end;
    { A cached DC survives the worker that first created it. }
    Cache.Clear;RunWorkers(2,1,70);RunWorkers(2,1,70);
    { Changing fonts invalidates cached outlines even when callers reuse glyph indices. }
    FillChar(LF,SizeOf(LF),0);LF.lfHeight:=-20;LF.lfWeight:=FW_NORMAL;
    StrPLCopy(LF.lfFaceName,'Arial',LF_FACESIZE-1);Em:=Cache.GetEmSquare(LF,'Arial');
    Cache.ShapeText(LF,'Arial',Em,'W',Glyphs);Path:=Cache.GetGlyphPathByIndex(Glyphs[0].GlyphIndex,A);
    StrPLCopy(LF.lfFaceName,'Times New Roman',LF_FACESIZE-1);Em:=Cache.GetEmSquare(LF,'Times');
    Cache.ShapeText(LF,'Times',Em,'W',Glyphs);Path:=Cache.GetGlyphPathByIndex(Glyphs[0].GlyphIndex,A);
    Reference.ShapeText(LF,'Times',Em,'W',Glyphs);Path:=Reference.GetGlyphPathByIndex(Glyphs[0].GlyphIndex,B);
    Check(A=B,'font switch discards stale glyph advances');
    Cache.Clear;Check(not Cache.LastShapeUsedOpenType,'Clear resets OpenType status');
  finally DestroyStartSignal(Start);Target.Free;Reference.Free;Cache.Free;Resources.Free;end;
end;
