{ Native FPC resource adapter. LCL owns platform fonts, brushes, pens and
  bitmaps; TCustomCanvas supplies the VCL drawing contract. GDI/EMF is Windows-only. }
unit Vcl.Graphics;
{$mode delphiunicode}
interface
uses Classes, SysUtils, Types, {$IFDEF MSWINDOWS}Windows{$ELSE}LCLType{$ENDIF}, Graphics;
type
  TCanvas = Graphics.TCanvas;
  TPicture = Graphics.TPicture;
  TIcon = Graphics.TIcon;
  TColor = Graphics.TColor;
  TPenMode = Graphics.TPenMode;
  TBrushStyle = Graphics.TBrushStyle;
  TFillStyle = (fsSurface,fsBorder);
  TFontStyle = Graphics.TFontStyle;
  TFontStyles = Graphics.TFontStyles;
  TFontCharset = Graphics.TFontCharset;
  TFontPitch = Graphics.TFontPitch;
  TCopyMode = Graphics.TCopyMode;
  TPixelFormat = Graphics.TPixelFormat;
  TColorRef = Cardinal;
  TPenStyle = (psSolid,psDash,psDot,psDashDot,psDashDotDot,psClear,psInsideFrame);
  TCanvasStates = (csHandleValid, csFontValid, csPenValid, csBrushValid);
  TCanvasState = set of TCanvasStates;
  TCanvasOrientation = (coLeftToRight, coRightToLeft);
  TTextFormats = (tfBottom, tfCalcRect, tfCenter, tfEditControl, tfEndEllipsis,
    tfPathEllipsis, tfExpandTabs, tfExternalLeading, tfLeft, tfModifyString,
    tfNoClip, tfNoPrefix, tfRight, tfRtlReading, tfSingleLine, tfTop,
    tfVerticalCenter, tfWordBreak, tfHidePrefix, tfNoFullWidthCharBreak,
    tfPrefixOnly, tfTabStop, tfWordEllipsis, tfComposited);
  TTextFormat = set of TTextFormats;

  TAlphaFormat = (afIgnored,afDefined,afPremultiplied);
  TGraphic = Graphics.TGraphic;
  {$IFDEF MSWINDOWS}
  TMetafile = class(Graphics.TGraphic)
  private
    FHandle: HENHMETAFILE;
    FWidth,FHeight: Integer;
    FTransparent:Boolean;
  protected
    procedure Draw(ACanvas:Graphics.TCanvas;const Rect:TRect);override;
    function GetEmpty:Boolean;override;
    function GetWidth:Integer;override;
    function GetHeight:Integer;override;
    function GetTransparent:Boolean;override;
    procedure SetWidth(Value:Integer);override;
    procedure SetHeight(Value:Integer);override;
    procedure SetTransparent(Value:Boolean);override;
  public
    constructor Create;override;
    destructor Destroy;override;
    property Handle:HENHMETAFILE read FHandle;
    procedure LoadFromStream(Stream:TStream);override;
    procedure SaveToStream(Stream:TStream);override;
  end;
  TMetafileCanvas = class(Graphics.TCanvas)
  private
    FMetafile:TMetafile;
  public
    constructor Create(Metafile:TMetafile;ReferenceDC:HDC);
    destructor Destroy;override;
  end;
  {$ENDIF}
  TPortableNetworkGraphic = Graphics.TPortableNetworkGraphic;
  TFont = class(Graphics.TFont)
  private
    function GetUnicodeName:string;
    procedure SetUnicodeName(const Value:string);
  public
    property Name:string read GetUnicodeName write SetUnicodeName;
  end;
  TBrush = class(Graphics.TBrush)
  public
    function HandleAllocated: Boolean;
  end;
  TPen = class(Graphics.TPen)
  private
    function GetVclStyle: TPenStyle;
    procedure SetVclStyle(Value: TPenStyle);
  public
    function HandleAllocated: Boolean;
    property Style: TPenStyle read GetVclStyle write SetVclStyle;
  end;
  TBitmap = class(Graphics.TBitmap)
  private
    FAlphaFormat: TAlphaFormat;
  public
    procedure Assign(Source:TPersistent);override;
    property AlphaFormat: TAlphaFormat read FAlphaFormat write FAlphaFormat;
  end;
const
  PS_JOIN_MASK = $F000;
  GGO_GLYPH_INDEX = $0080;
  clNone = TColor($1FFFFFFF);
  clBlack = TColor($000000);
  clMaroon = TColor($000080);
  clGreen = TColor($008000);
  clNavy = TColor($800000);
  clWhite = TColor($FFFFFF);
  clSkyBlue = TColor($F0CAA6);
  clRed = TColor($0000FF);
  clLime = TColor($00FF00);
  clYellow = TColor($00FFFF);
  clFuchsia = TColor($00FF00FF);
  clBlue = TColor($FF0000);
  cmSrcCopy = $00CC0020;

  pmBlack = Graphics.pmBlack;
  pmWhite = Graphics.pmWhite;
  pmNop = Graphics.pmNop;
  pmNot = Graphics.pmNot;
  pmCopy = Graphics.pmCopy;
  pmNotCopy = Graphics.pmNotCopy;
  pmMergePenNot = Graphics.pmMergePenNot;
  pmMaskPenNot = Graphics.pmMaskPenNot;
  pmMergeNotPen = Graphics.pmMergeNotPen;
  pmMaskNotPen = Graphics.pmMaskNotPen;
  pmMerge = Graphics.pmMerge;
  pmNotMerge = Graphics.pmNotMerge;
  pmMask = Graphics.pmMask;
  pmNotMask = Graphics.pmNotMask;
  pmXor = Graphics.pmXor;
  pmNotXor = Graphics.pmNotXor;
  bsSolid = Graphics.bsSolid;
  bsClear = Graphics.bsClear;
  bsHorizontal = Graphics.bsHorizontal;
  bsVertical = Graphics.bsVertical;
  bsFDiagonal = Graphics.bsFDiagonal;
  bsBDiagonal = Graphics.bsBDiagonal;
  bsCross = Graphics.bsCross;
  bsDiagCross = Graphics.bsDiagCross;
  fsBold = Graphics.fsBold;
  fsItalic = Graphics.fsItalic;
  fsUnderline = Graphics.fsUnderline;
  fsStrikeOut = Graphics.fsStrikeOut;
  fpDefault = Graphics.fpDefault;
  fpVariable = Graphics.fpVariable;
  fpFixed = Graphics.fpFixed;
  pfDevice = Graphics.pfDevice;
  pf1bit = Graphics.pf1bit;
  pf4bit = Graphics.pf4bit;
  pf8bit = Graphics.pf8bit;
  pf15bit = Graphics.pf15bit;
  pf16bit = Graphics.pf16bit;
  pf24bit = Graphics.pf24bit;
  pf32bit = Graphics.pf32bit;
  pfCustom = Graphics.pfCustom;
function ColorToRGB(Color:TColor):TColorRef;
{$IFDEF MSWINDOWS}
function AddFontMemResourceEx(Data:Pointer;Size:DWORD;Reserved:Pointer;Count:PDWORD):THandle;stdcall;external 'gdi32.dll';
function RemoveFontMemResourceEx(Handle:THandle):BOOL;stdcall;external 'gdi32.dll';
function CreateFontIndirectW(const Font:TLogFontW):HFONT;
function GetTextMetricsW(DC:HDC;out Metrics:TTextMetricW):BOOL;
function GetGlyphIndicesW(DC:HDC;Text:PWideChar;Count:Integer;Indices:PWord;Flags:DWORD):DWORD;stdcall;external 'gdi32.dll';
function EnumFontFamiliesExW(DC:HDC;const Font:TLogFontW;Proc:Pointer;Data:LPARAM;Flags:DWORD):Integer;
procedure DrawTextLayout(DC:HDC;var Bounds:TRect;var Text:string;Format:TTextFormat);
{$ENDIF}

type
  TCustomCanvas = class(TPersistent)
  protected
    function GetCanvasOrientation: TCanvasOrientation; virtual; abstract;
    function GetClipRect: TRect; virtual; abstract;
    function GetPenPos: TPoint; virtual; abstract;
    function GetPixel(X, Y: Integer): TColor; virtual; abstract;
    procedure SetPenPos(Value: TPoint); virtual; abstract;
    procedure SetPixel(X, Y: Integer; Value: TColor); virtual; abstract;
    procedure Changed; virtual;
    procedure Changing; virtual;
    procedure RequiredState(ReqState: TCanvasState); virtual; abstract;
  public
    procedure Arc(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); virtual; abstract;
    procedure ArcTo(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); virtual; abstract;
    procedure AngleArc(X, Y: Integer; Radius: Cardinal; StartAngle, SweepAngle: Single); virtual; abstract;
    procedure BrushCopy(const Dest: TRect; Bitmap: TBitmap;
      const Source: TRect; Color: TColor); virtual; abstract;
    procedure Chord(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); virtual; abstract;
    procedure Draw(X, Y: Integer; Graphic: TGraphic); overload; virtual; abstract;
    procedure Draw(X, Y: Integer; Graphic: TGraphic; Opacity: Byte); overload; virtual; abstract;
    procedure DrawFocusRect(const Rect: TRect); virtual; abstract;
    procedure Ellipse(X1, Y1, X2, Y2: Integer); overload; virtual; abstract;
    procedure Ellipse(const Rect: TRect); overload;
    procedure FillRect(const Rect: TRect); virtual; abstract;
    procedure FloodFill(X, Y: Integer; Color: TColor; FillStyle: TFillStyle); virtual; abstract;
    procedure FrameRect(const Rect: TRect); virtual; abstract;
    procedure LineTo(X, Y: Integer); virtual; abstract;
    procedure MoveTo(X, Y: Integer); virtual; abstract;
    procedure Pie(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); virtual; abstract;
    procedure Polygon(const Points: array of TPoint); virtual; abstract;
    procedure Polyline(const Points: array of TPoint); virtual; abstract;
    procedure PolyBezier(const Points: array of TPoint); virtual; abstract;
    procedure PolyBezierTo(const Points: array of TPoint); virtual; abstract;
    procedure Rectangle(X1, Y1, X2, Y2: Integer); overload; virtual; abstract;
    procedure Rectangle(const Rect: TRect); overload;
    procedure Refresh; virtual; abstract;
    procedure RoundRect(X1, Y1, X2, Y2, X3, Y3: Integer); overload; virtual; abstract;
    procedure RoundRect(const Rect: TRect; CX, CY: Integer); overload;
    procedure StretchDraw(const Rect: TRect; Graphic: TGraphic); virtual; abstract;
    function TextExtent(const Text: string): TSize; virtual; abstract;
    function TextHeight(const Text: string): Integer;
    procedure TextOut(X, Y: Integer; const Text: string); virtual; abstract;
    procedure TextRect(var Rect: TRect; var Text: string; TextFormat: TTextFormat = []); overload; virtual; abstract;
    procedure TextRect(Rect: TRect; X, Y: Integer; const Text: string); overload; virtual; abstract;
    function TextWidth(const Text: string): Integer;
    property ClipRect: TRect read GetClipRect;
    property CanvasOrientation: TCanvasOrientation read GetCanvasOrientation;
    property PenPos: TPoint read GetPenPos write SetPenPos;
    property Pixels[X, Y: Integer]: TColor read GetPixel write SetPixel;
  end;

implementation

{$IFDEF MSWINDOWS}
function NativeCreateFontIndirectW(Font:Pointer):HFONT;stdcall;external 'gdi32.dll' name 'CreateFontIndirectW';
function NativeEnumFontFamiliesExW(DC:HDC;Font:Pointer;Proc:Pointer;Data:LPARAM;Flags:DWORD):Integer;stdcall;external 'gdi32.dll' name 'EnumFontFamiliesExW';
function NativeDrawTextW(DC:HDC;Text:PWideChar;Count:Integer;Bounds:PRect;Flags:UINT):Integer;stdcall;external 'user32.dll' name 'DrawTextW';
function CreateFontIndirectW(const Font:TLogFontW):HFONT;
begin Result:=NativeCreateFontIndirectW(@Font);end;
function GetTextMetricsW(DC:HDC;out Metrics:TTextMetricW):BOOL;
begin Result:=Windows.GetTextMetricsW(DC,@Metrics);end;
function EnumFontFamiliesExW(DC:HDC;const Font:TLogFontW;Proc:Pointer;Data:LPARAM;Flags:DWORD):Integer;
begin Result:=NativeEnumFontFamiliesExW(DC,@Font,Proc,Data,Flags);end;
procedure DrawTextLayout(DC:HDC;var Bounds:TRect;var Text:string;Format:TTextFormat);
const Values:array[TTextFormats] of Cardinal=($8,$400,$1,$2000,$8000,$4000,$40,$200,$0,$10000,$100,$800,$2,$20000,$20,$0,$4,$10,$100000,$80000,$200000,$80,$40000,$0);
var Flag:TTextFormats;Flags:Cardinal;Buffer:UnicodeString;
begin
  Flags:=0;for Flag in Format do Flags:=Flags or Values[Flag];
  Buffer:=Text+#0#0#0#0#0;
  NativeDrawTextW(DC,PWideChar(Buffer),Length(Text),@Bounds,Flags);
  if tfModifyString in Format then Text:=PWideChar(Buffer);
end;
{$ENDIF}
function TFont.GetUnicodeName:string;begin Result:=UTF8Decode(inherited Name);end;
procedure TFont.SetUnicodeName(const Value:string);begin inherited Name:=UTF8Encode(Value);end;
{$IFDEF MSWINDOWS}
constructor TMetafile.Create;begin inherited;FTransparent:=True;end;
destructor TMetafile.Destroy;begin if FHandle<>0 then DeleteEnhMetaFile(FHandle);inherited;end;
function TMetafile.GetEmpty:Boolean;begin Result:=FHandle=0;end;
function TMetafile.GetWidth:Integer;begin Result:=FWidth;end;
function TMetafile.GetHeight:Integer;begin Result:=FHeight;end;
function TMetafile.GetTransparent:Boolean;begin Result:=FTransparent;end;
procedure TMetafile.SetWidth(Value:Integer);begin FWidth:=Value;end;
procedure TMetafile.SetHeight(Value:Integer);begin FHeight:=Value;end;
procedure TMetafile.SetTransparent(Value:Boolean);begin FTransparent:=Value;end;
procedure TMetafile.Draw(ACanvas:Graphics.TCanvas;const Rect:TRect);
var Bounds:TRect;
begin
  Bounds:=Rect;Dec(Bounds.Right);Dec(Bounds.Bottom);
  if FHandle<>0 then PlayEnhMetaFile(ACanvas.Handle,FHandle,Bounds);
end;
procedure TMetafile.LoadFromStream(Stream:TStream);
var Data:TBytes;Header:TEnhMetaHeader;NewHandle:HENHMETAFILE;
begin
  SetLength(Data,Stream.Size-Stream.Position);if Length(Data)=0 then raise EReadError.Create('Empty metafile');
  Stream.ReadBuffer(Data[0],Length(Data));NewHandle:=SetEnhMetaFileBits(Length(Data),Pointer(Data));
  if NewHandle=0 then RaiseLastOSError;
  if FHandle<>0 then DeleteEnhMetaFile(FHandle);FHandle:=NewHandle;
  GetEnhMetaFileHeader(FHandle,SizeOf(Header),@Header);
  FWidth:=Header.rclBounds.Right-Header.rclBounds.Left;FHeight:=Header.rclBounds.Bottom-Header.rclBounds.Top;
end;
procedure TMetafile.SaveToStream(Stream:TStream);
var Data:TBytes;Size:Cardinal;
begin if FHandle=0 then Exit;Size:=GetEnhMetaFileBits(FHandle,0,nil);SetLength(Data,Size);
 if GetEnhMetaFileBits(FHandle,Size,Pointer(Data))<>Size then RaiseLastOSError;Stream.WriteBuffer(Data[0],Size);end;
constructor TMetafileCanvas.Create(Metafile:TMetafile;ReferenceDC:HDC);
var Frame:TRect;DC:HDC;
begin
  inherited Create;FMetafile:=Metafile;
  Frame:=Types.Rect(0,0,Windows.MulDiv(Metafile.Width,2540,96),Windows.MulDiv(Metafile.Height,2540,96));
  DC:=CreateEnhMetaFileW(ReferenceDC,nil,@Frame,nil);if DC=0 then RaiseLastOSError;Handle:=DC;
end;
destructor TMetafileCanvas.Destroy;
var DC:HDC;Native:HENHMETAFILE;
begin DC:=Handle;Handle:=0;Native:=CloseEnhMetaFile(DC);
 if FMetafile.FHandle<>0 then DeleteEnhMetaFile(FMetafile.FHandle);FMetafile.FHandle:=Native;inherited;end;
{$ENDIF}
function ColorToRGB(Color:TColor):TColorRef;
begin Result:=Graphics.ColorToRGB(Color); end;
procedure TBitmap.Assign(Source:TPersistent);
begin
  inherited Assign(Source);
  if Source is TBitmap then FAlphaFormat:=TBitmap(Source).AlphaFormat else FAlphaFormat:=afIgnored;
end;
function TBrush.HandleAllocated:Boolean;
begin Result:=Handle<>0; end;
function TPen.HandleAllocated:Boolean;
begin Result:=Handle<>0; end;
function TPen.GetVclStyle:TPenStyle;
begin
  case inherited Style of
    Graphics.psClear:Result:=psClear;
    Graphics.psInsideFrame:Result:=psInsideFrame;
    Graphics.psPattern:Result:=psSolid;
  else Result:=TPenStyle(Ord(inherited Style)); end;
end;
procedure TPen.SetVclStyle(Value:TPenStyle);
begin
  case Value of
    psClear:inherited Style:=Graphics.psClear;
    psInsideFrame:inherited Style:=Graphics.psInsideFrame;
  else inherited Style:=Graphics.TPenStyle(Ord(Value)); end;
end;
procedure TCustomCanvas.Changed; begin end;
procedure TCustomCanvas.Changing; begin end;
procedure TCustomCanvas.Ellipse(const Rect:TRect); begin Ellipse(Rect.Left,Rect.Top,Rect.Right,Rect.Bottom); end;
procedure TCustomCanvas.Rectangle(const Rect:TRect); begin Rectangle(Rect.Left,Rect.Top,Rect.Right,Rect.Bottom); end;
procedure TCustomCanvas.RoundRect(const Rect:TRect;CX,CY:Integer); begin RoundRect(Rect.Left,Rect.Top,Rect.Right,Rect.Bottom,CX,CY); end;
function TCustomCanvas.TextHeight(const Text:string):Integer; begin Result:=TextExtent(Text).cy; end;
function TCustomCanvas.TextWidth(const Text:string):Integer; begin Result:=TextExtent(Text).cx; end;
end.
