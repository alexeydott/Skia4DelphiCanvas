unit Vcl.GraphUtil.MetafileParser;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$MODESWITCH FUNCTIONREFERENCES}{$ENDIF}
{$POINTERMATH ON}

interface

uses
  {$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF}, Classes, SysUtils, Vcl.Graphics, Math;

resourcestring
  SMetafileInvalidRecord = 'Invalid EMF record %d: expected at least %d bytes, found %d';
  SMetafileEmpty = 'Metafile is empty';
  SMetafileFileNotFound = 'File not found: %s';
  SMetafileEnumerationFailed = 'EnumEnhMetaFile failed after record %d (Windows error %d)';
  SMetafilePrimitiveIndex = 'Primitive index %d out of bounds';
  SMetafileRecordPlaybackFailed = 'Cannot replay EMF record %d at index %d (Windows error %d)';

type
  TMetafilePrimitiveKind = (mpkNone, mpkPolyline, mpkPolygon, mpkText, mpkImage);
  TNotifyEventCallback = reference to procedure(Sender: TObject);
  /// <summary>Receives the original enumeration context before a record is parsed.</summary>
  TMetafileRecordEvent = procedure(Sender:TObject;ADC:HDC;ATable:Pointer;
    ARecord:PEnhMetaRecord;AObjects:Integer) of object;

  TMetafilePoint = record
    X: Double;
    Y: Double;
  end;

  TMetafileRect = record
    Left: Double;
    Top: Double;
    Right: Double;
    Bottom: Double;
  end;

  TMetafilePointArray = array of TMetafilePoint;
  TMetafileIntegerArray = array of Integer;
  TMetafileByteArray = TBytes;

  TMetafileBrushDataKind = (mbdkNone, mbdkMonoPattern, mbdkDibPattern, mbdkExtPenPattern);

  TMetafileBrushData = record
    Kind: TMetafileBrushDataKind;
    Usage: Cardinal;
    BitmapInfo: TMetafileByteArray;
    Bits: TMetafileByteArray;
  end;

  TMetafileGradientKind = (mgkNone, mgkRect, mgkTriangle);

  TMetafileGradientVertex = record
    Point: TMetafilePoint;
    Red: Word;
    Green: Word;
    Blue: Word;
    Alpha: Word;
  end;

  TMetafileGradientMesh = record
    Index0: Cardinal;
    Index1: Cardinal;
    Index2: Cardinal;
  end;

  TMetafileGradientVertexArray = array of TMetafileGradientVertex;
  TMetafileGradientMeshArray = array of TMetafileGradientMesh;

  TMetafileGradientFillStyle = record
    Kind: TMetafileGradientKind;
    Mode: Cardinal;
    Vertices: TMetafileGradientVertexArray;
    Meshes: TMetafileGradientMeshArray;
  end;

  TMetafileFillKind = (mfkNone, mfkSolid, mfkHatch, mfkPattern, mfkGradient);

  TMetafileStrokeStyle = record
    Visible: Boolean;
    Color: TColor;
    Width: Double;
    Hairline: Boolean;
    Style: Cardinal;
    BrushStyle:Cardinal;
    Hatch:Cardinal;
    EndCap: Cardinal;
    Join: Cardinal;
    MiterLimit: Double;
    RasterOperation2: Cardinal;
    BrushOrigin: TPoint;
    Brush: TMetafileBrushData;
    function PenStyle: TPenStyle;
  end;

  TMetafileFillStyle = record
    Kind: TMetafileFillKind;
    Visible: Boolean;
    Color: TColor;
    Style: Cardinal;
    Hatch: Cardinal;
    FillMode: Cardinal;
    RasterOperation2: Cardinal;
    BrushOrigin: TPoint;
    Brush: TMetafileBrushData;
    Gradient: TMetafileGradientFillStyle;
  end;

  TMetafileImageData = record
    Usage: Cardinal;
    BitmapInfo: TMetafileByteArray;
    Bits: TMetafileByteArray;
  end;

  TMetafileRasterOperationKind = (mrokNone, mrokRop3, mrokRop4, mrokAlphaBlend, mrokTransparent, mrokSetDIBits, mrokPlgBlt);

  TMetafileImageStyle = record
    OperationKind: TMetafileRasterOperationKind;
    Operation: Cardinal;
    Blend: Cardinal;
    Rop3: Byte;
    ForegroundRop3: Byte;
    BackgroundRop3: Byte;
    OperationName: string;
    BkColorSrc: TColor;
    PatternColor: TColor;
    PatternBrush: TMetafileBrushData;
    PatternBrushOrigin: TPoint;
    StretchMode: Cardinal;
    BlendOperation: Byte;
    BlendFlags: Byte;
    SourceConstantAlpha: Byte;
    AlphaFormat: Byte;
    HasPerPixelAlpha: Boolean;
    TransparentColor: TColor;
    MaskOrigin: TPoint;
    StartScan: Cardinal;
    ScanCount: Cardinal;
    SrcRect: TMetafileRect;
    DestRect: TMetafileRect;
    Bounds: TMetafileRect;
    XForm: TXForm;
    Image: TMetafileImageData;
    Mask: TMetafileImageData;
  end;

  TMetafileTextStyle = record
    Color: TColor;
    BkColor: TColor;
    BkMode: Cardinal;
    Align: Cardinal;
    Font: TLogFontW;
    Options: Cardinal;
    Bounds: TMetafileRect;
    Dx: TMetafileIntegerArray;
    Dy: TMetafileIntegerArray;
    JustificationBreakExtra: Integer;
    JustificationBreakCount: Integer;
    Layout: Cardinal;
  end;

  TMetafileClipStyle = record
    Active: Boolean;
    Bounds: TMetafileRect;
    Points: TMetafilePointArray;
    PointCounts: TMetafileIntegerArray;
    CombineMode: Cardinal;
    BooleanGeometryRequired: Boolean;
    BooleanOperation: Cardinal;
  end;

  TMetafilePrimitive = class
  public
    Kind: TMetafilePrimitiveKind;
    Points: TMetafilePointArray;
    PointCounts: TMetafileIntegerArray;
    Text: UnicodeString;
    Bounds: TMetafileRect;
    Stroke: TMetafileStrokeStyle;
    Fill: TMetafileFillStyle;
    TextStyle: TMetafileTextStyle;
    Clip: TMetafileClipStyle;
    Image: TMetafileImageStyle;
    SourceRecordType: Cardinal;
    SourceRecordIndex: Cardinal;
    SourceRecordName: string;
    procedure Assign(Source: TMetafilePrimitive);
    function Clone: TMetafilePrimitive;
    function SubPoints(Index: Integer): TMetafilePointArray;
  end;

  TMetafileParser = class
  private
    FOnRecord,FOnRecordComplete: TMetafileRecordEvent;
    FCurrent: TMetafilePrimitive;
    FPrimitives: TList;
    FStorePrimitives: Boolean;
    FOnObjectPlay: TNotifyEvent;
    FOnObjectPlayCallback: TNotifyEventCallback;
    FDCState: TObject;
    FPathBuilder: TObject;
    FTextOutlineConverter: TObject;
    FRecordIndex: Cardinal;
    FFlatness: Double;
    FTextFlatness: Double;
    FConvertTextToCurves: Boolean;
    FLastError: string;
    function EnumRecord(ADC: HDC; ARecord: PEnhMetaRecord): Integer;
    procedure Reset;
    procedure ClearPath;
    procedure ClearStoredPrimitives;
    procedure SaveState;
    procedure RestoreState(ARelative: Integer);
    function RecordBytesAvailable(ARecord: PEnhMetaRecord; AOffset, ASize: NativeUInt): Boolean;
    function RecordArrayAvailable(ARecord: PEnhMetaRecord; AOffset, ACount, AElementSize: NativeUInt): Boolean;
    function RecordPtr(ARecord: PEnhMetaRecord; AOffset, ASize: NativeUInt; out APtr: Pointer): Boolean;
    function ReadRecordBytes(ARecord: PEnhMetaRecord; AOffset, ASize: NativeUInt; out ABytes: TMetafileByteArray): Boolean;
    function ReadTextAdvances(ARecord: PEnhMetaRecord; AOffDx, ANChars, AOptions: Cardinal; out ADx, ADy: TMetafileIntegerArray): Boolean;
    procedure SelectObjectHandle(AHandle: Cardinal);
    procedure DeleteObjectHandle(AHandle: Cardinal);
    function LogicalToOutput(const P: TPoint): TMetafilePoint; overload;
    {$IFDEF FPC}function LogicalToOutput(const P: POINTL): TMetafilePoint; overload;{$ENDIF}
    function LogicalToOutput(X, Y: Double): TMetafilePoint; overload;
    function CurrentStroke: TMetafileStrokeStyle;
    function CurrentFill: TMetafileFillStyle;
    function CurrentTextStyle: TMetafileTextStyle;
    function RecordName(AType: Cardinal): string;
    procedure EmitPrimitive(AKind: TMetafilePrimitiveKind; const APoints: TMetafilePointArray; const APointCounts: TMetafileIntegerArray; const AText: UnicodeString; ARecordType: Cardinal;
      const ARecordName: string; AUseStroke, AUseFill: Boolean);
    procedure EmitImagePrimitive(const APoints: TMetafilePointArray; const APointCounts: TMetafileIntegerArray; const AImage: TMetafileImageStyle; ARecordType: Cardinal; const ARecordName: string);
    procedure EmitPath(ARecordType: Cardinal; const ARecordName: string; AUseStroke, AUseFill: Boolean);
    procedure AppendPathContour(const APoints: TMetafilePointArray; AClosed: Boolean);
    procedure AppendPathOpenPolyline(const APoints: TMetafilePointArray);
    procedure PathCloseFigure;
    procedure AddPrimitiveToStore;
    function BuildBounds(const APoints: TMetafilePointArray): TMetafileRect;
    procedure HandlePolyline32(ARecord: PEnhMetaRecord; AClosed: Boolean);
    procedure HandlePolyline16(ARecord: PEnhMetaRecord; AClosed: Boolean);
    procedure HandlePolyPolyline32(ARecord: PEnhMetaRecord; AClosed: Boolean);
    procedure HandlePolyPolyline16(ARecord: PEnhMetaRecord; AClosed: Boolean);
    procedure HandlePolyBezier32(ARecord: PEnhMetaRecord; ABezierTo: Boolean);
    procedure HandlePolyBezier16(ARecord: PEnhMetaRecord; ABezierTo: Boolean);
    procedure HandlePolylineTo32(ARecord: PEnhMetaRecord);
    procedure HandlePolylineTo16(ARecord: PEnhMetaRecord);
    procedure HandlePolyDraw32(ARecord: PEnhMetaRecord);
    procedure HandlePolyDraw16(ARecord: PEnhMetaRecord);
    procedure HandleLineTo(ARecord: PEnhMetaRecord);
    procedure HandleMoveTo(ARecord: PEnhMetaRecord);
    procedure HandleRectangle(ARecord: PEnhMetaRecord);
    procedure HandleEllipse(ARecord: PEnhMetaRecord);
    procedure HandleRoundRect(ARecord: PEnhMetaRecord);
    procedure HandleArcLike(ARecord: PEnhMetaRecord; AKind: Cardinal);
    procedure HandleAngleArc(ARecord: PEnhMetaRecord);
    procedure HandleTextOut(ARecord: PEnhMetaRecord; AWide: Boolean);
    procedure HandleSmallTextOut(ARecord: PEnhMetaRecord);
    procedure HandlePolyTextOut(ARecord: PEnhMetaRecord; AWide: Boolean);
    procedure HandleWidenPath(ARecord: PEnhMetaRecord);
    procedure HandleFillRegion(ARecord: PEnhMetaRecord; AFrame: Boolean);
    procedure HandlePaintOrInvertRegion(ARecord: PEnhMetaRecord);
    procedure HandleExtSelectClipRegion(ARecord: PEnhMetaRecord);
    procedure HandleClipRect(ARecord: PEnhMetaRecord; ACombineMode: Cardinal);
    procedure HandleOffsetClipRegion(ARecord: PEnhMetaRecord);
    procedure HandleCreatePen(ARecord: PEnhMetaRecord);
    procedure HandleExtCreatePen(ARecord: PEnhMetaRecord);
    procedure HandleCreateBrush(ARecord: PEnhMetaRecord);
    procedure HandleCreateMonoBrush(ARecord: PEnhMetaRecord);
    procedure HandleCreateDibPatternBrush(ARecord: PEnhMetaRecord);
    procedure HandleCreateFont(ARecord: PEnhMetaRecord);
    procedure HandleGradientFill(ARecord: PEnhMetaRecord);
    procedure HandleRasterRecord(ARecord: PEnhMetaRecord);
    procedure HandleSetPixelV(ARecord: PEnhMetaRecord);
    procedure HandleHeader(ARecord: PEnhMetaRecord);
    procedure HandleSetMapMode(ARecord: PEnhMetaRecord);
    procedure HandleSetWindowExt(ARecord: PEnhMetaRecord);
    procedure HandleSetWindowOrg(ARecord: PEnhMetaRecord);
    procedure HandleSetViewportExt(ARecord: PEnhMetaRecord);
    procedure HandleSetViewportOrg(ARecord: PEnhMetaRecord);
    procedure HandleScaleWindowExt(ARecord: PEnhMetaRecord);
    procedure HandleScaleViewportExt(ARecord: PEnhMetaRecord);
    procedure HandleSetWorldTransform(ARecord: PEnhMetaRecord);
    procedure HandleModifyWorldTransform(ARecord: PEnhMetaRecord);
    procedure HandleSetColorText(ARecord: PEnhMetaRecord);
    procedure HandleSetBkColor(ARecord: PEnhMetaRecord);
    procedure HandleSetBkMode(ARecord: PEnhMetaRecord);
    procedure HandleSetTextAlign(ARecord: PEnhMetaRecord);
    procedure HandleSetTextJustification(ARecord: PEnhMetaRecord);
    procedure HandleSetPolyFillMode(ARecord: PEnhMetaRecord);
    procedure HandleSetArcDirection(ARecord: PEnhMetaRecord);
    procedure HandleSetMiterLimit(ARecord: PEnhMetaRecord);
    procedure HandleSetRop2(ARecord: PEnhMetaRecord);
    procedure HandleSetStretchMode(ARecord: PEnhMetaRecord);
    procedure HandleSetBrushOrigin(ARecord: PEnhMetaRecord);
    procedure HandleSetLayout(ARecord: PEnhMetaRecord);
    procedure EmitTextCurves(ARecordType: Cardinal; const ARecordName: string; const AText: UnicodeString; const AOrigin: TMetafilePoint; AGlyphIndexes: PWord; AGlyphCount: Integer;
      const ADx, ADy: TMetafileIntegerArray; AOptions: Cardinal);
    function CurrentTextToFlatPolygonsInternal(const AText: UnicodeString; const AOrigin: TMetafilePoint; const ALogFont: TLogFontW; AGlyphIndexes: PWord; AGlyphCount: Integer;
      const ADx, ADy: TMetafileIntegerArray; AOptions: Cardinal; out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Parses an in-memory enhanced metafile without taking ownership.</summary>
    function LoadFromMetafile(AMetafile: TMetafile; APlaybackDC:HDC=0; APlaybackBounds:PRect=nil): Boolean;
    function LoadFromFile(const AFileName: string): Boolean;
    /// Synchronizes the next primitive's logical origin after native current-point updates.
    procedure SynchronizeCurrentPosition(const APosition:TPoint);
    function PrimitiveCount: Integer;
    function PrimitiveByIndex(AIndex: Integer): TMetafilePrimitive;
    function CurrentTextToFlatPolygons(out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
    class function Point(AX, AY: Double): TMetafilePoint;
    class function CubicBezierToFlatPolyline(const P0, P1, P2, P3: TMetafilePoint; ATolerance: Double): TMetafilePointArray;
    class function QuadraticBezierToFlatPolyline(const P0, P1, P2: TMetafilePoint; ATolerance: Double): TMetafilePointArray;
    class function BezierPointsToFlatPolyline(const ABezierPoints: TMetafilePointArray; ATolerance: Double): TMetafilePointArray;
    property OnRecord:TMetafileRecordEvent read FOnRecord write FOnRecord;
    property OnRecordComplete:TMetafileRecordEvent read FOnRecordComplete write FOnRecordComplete;
    property Current: TMetafilePrimitive read FCurrent;
    property StorePrimitives: Boolean read FStorePrimitives write FStorePrimitives;
    property OnObjectPlay: TNotifyEvent read FOnObjectPlay write FOnObjectPlay;
    property OnObjectPlayCallback: TNotifyEventCallback read FOnObjectPlayCallback write FOnObjectPlayCallback;
    property Flatness: Double read FFlatness write FFlatness;
    property TextFlatness: Double read FTextFlatness write FTextFlatness;
    property ConvertTextToCurves: Boolean read FConvertTextToCurves write FConvertTextToCurves;
    property LastError: string read FLastError;
  end;

type
  /// <summary>Decodes PNG/JPEG or a normalized in-memory BMP into a top-down 32-bit BI_RGB DIB.</summary>
  TMetafileImageDecoder = function(const Encoded:TBytes;out Info,Bits:TBytes):Boolean of object;
  TMetafileRecordRecovery = (mrrNone,mrrEmptyPath,mrrOutsideSource,mrrDibHeader,
    mrrPalette,mrrPatternPen,mrrCompressedDib);
  /// <summary>Replays records with bounded in-memory recovery for noncanonical DIBs and pens.</summary>
  /// <remarks>Use one instance per enumeration and process every record in order. Source buffers are never modified.</remarks>
  TMetafileRecordPlayer = class
  private
    FDecoder:TMetafileImageDecoder;
    FRecovery:TMetafileRecordRecovery;
    FError:Cardinal;
    FPathOpen:Boolean;
  public
    /// <summary>Replays one enumeration record, reporting failures instead of silently dropping content.</summary>
    function Play(DC:HDC;Table:Pointer;RecordData:PEnhMetaRecord;Objects:Integer):Boolean;
    property ImageDecoder:TMetafileImageDecoder read FDecoder write FDecoder;
    property Recovery:TMetafileRecordRecovery read FRecovery;
    property ErrorCode:Cardinal read FError;
  end;

/// <summary>Validates and normalizes self-describing DIB metadata without altering its pixels.</summary>
function NormalizeMetafileDIB(var Info:TBytes;const Bits:TBytes;Usage:Cardinal):TMetafileRecordRecovery;

implementation

{$IFDEF FPC}{$I MetafileParser.Fpc.inc}{$ENDIF}

const
  EMF_STOCK_OBJECT_FLAG = Cardinal($80000000);
  MAX_EMF_OBJECT_HANDLES = 65536;
  PS_STYLE_MASK_LOCAL = $0000000F;
  MWT_SET_LOCAL = 4;
  TT_PRIM_CSPLINE_LOCAL = 3;
  GGO_UNHINTED_LOCAL = $0100;
  ETO_NO_RECT_LOCAL = $00000100;
  ETO_SMALL_CHARS_LOCAL = $00000200;
  EMR_SETLAYOUT_LOCAL = 115;
  DEFAULT_ARC_SEGMENTS = 72;
  DEFAULT_ELLIPSE_SEGMENTS = 72;
  MAX_BEZIER_RECURSION = 24;
  TEXT_OUTLINE_EM_SIZE = 4096;
  DEFAULT_TEXT_FLATNESS = 0.02;
  DEFAULT_OUTLINE_TEXT_FACE = 'Arial';
  CLIP_BOOLEAN_EPSILON = 1E-7;

type
  PEMRSetLong = ^TEMRSetLong;

  TEMRSetLong = packed record
    emr: TEMR;
    Value: DWORD;
  end;

  PEMRHeaderLocal = ^TEMRHeaderLocal;

  TEMRHeaderLocal = packed record
    emr: TEMR;
    rclBounds: TRect;
    rclFrame: TRect;
    dSignature: DWORD;
    nVersion: DWORD;
    nBytes: DWORD;
    nRecords: DWORD;
    nHandles: Word;
    sReserved: Word;
    nDescription: DWORD;
    offDescription: DWORD;
    nPalEntries: DWORD;
    szlDevice: TSize;
    szlMillimeters: TSize;
  end;

  PEMRSetPoint = ^TEMRSetPoint;

  TEMRSetPoint = packed record
    emr: TEMR;
    Point: TPoint;
  end;

  PEMRSetPixelVLocal = ^TEMRSetPixelVLocal;

  TEMRSetPixelVLocal = packed record
    emr: TEMR;
    ptlPixel: TPoint;
    crColor: COLORREF;
  end;

  PEMRSetSize = ^TEMRSetSize;

  TEMRSetSize = packed record
    emr: TEMR;
    Size: TSize;
  end;

  PEMRScaleExt = ^TEMRScaleExt;

  TEMRScaleExt = packed record
    emr: TEMR;
    xNum: Integer;
    xDenom: Integer;
    yNum: Integer;
    yDenom: Integer;
  end;

  PEMRWorldTransformLocal = ^TEMRWorldTransformLocal;

  TEMRWorldTransformLocal = packed record
    emr: TEMR;
    XForm: TXForm;
  end;

  PEMRModifyWorldTransformLocal = ^TEMRModifyWorldTransformLocal;

  TEMRModifyWorldTransformLocal = packed record
    emr: TEMR;
    XForm: TXForm;
    iMode: DWORD;
  end;

  PEMRSetMiterLimitLocal = ^TEMRSetMiterLimitLocal;

  TEMRSetMiterLimitLocal = packed record
    emr: TEMR;
    eMiterLimit: Single;
  end;

  PEMRSetTextJustificationLocal = ^TEMRSetTextJustificationLocal;

  TEMRSetTextJustificationLocal = packed record
    emr: TEMR;
    nBreakExtra: Integer;
    nBreakCount: Integer;
  end;

  PEMRRestoreDCLocal = ^TEMRRestoreDCLocal;

  TEMRRestoreDCLocal = packed record
    emr: TEMR;
    iRelative: Integer;
  end;

  PEMRRoundRectLocal = ^TEMRRoundRectLocal;

  TEMRRoundRectLocal = packed record
    emr: TEMR;
    rclBox: TRect;
    szlCorner: TSize;
  end;

  PEMRAngleArcLocal = ^TEMRAngleArcLocal;

  TEMRAngleArcLocal = packed record
    emr: TEMR;
    ptlCenter: TPoint;
    nRadius: DWORD;
    eStartAngle: Single;
    eSweepAngle: Single;
  end;

  { EMF stores 32-bit brush hatch data even in a Win64 process. }
  TEmfExtLogPen32 = packed record
    elpPenStyle,elpWidth,elpBrushStyle,elpColor,elpHatch,elpNumEntries:DWORD;
    elpStyleEntry:array[0..0] of DWORD;
  end;
  PEMRExtCreatePenLocal = ^TEMRExtCreatePenLocal;

  TEMRExtCreatePenLocal = packed record
    emr: TEMR;
    ihPen: DWORD;
    offBmi: DWORD;
    cbBmi: DWORD;
    offBits: DWORD;
    cbBits: DWORD;
    elp: TEmfExtLogPen32;
  end;

  PEMRSmallTextOutLocal = ^TEMRSmallTextOutLocal;

  TEMRSmallTextOutLocal = packed record
    emr: TEMR;
    ptlReference: TPoint;
    nChars: DWORD;
    fuOptions: DWORD;
    iGraphicsMode: DWORD;
    exScale: Single;
    eyScale: Single;
    rclClip: TRect;
  end;

  PEMRClipRectLocal = ^TEMRClipRectLocal;

  TEMRClipRectLocal = packed record
    emr: TEMR;
    rclClip: TRect;
  end;

  PEMROffsetClipRgnLocal = ^TEMROffsetClipRgnLocal;

  TEMROffsetClipRgnLocal = packed record
    emr: TEMR;
    ptlOffset: TPoint;
  end;

  PEMRExtSelectClipRgnLocal = ^TEMRExtSelectClipRgnLocal;

  TEMRExtSelectClipRgnLocal = packed record
    emr: TEMR;
    cbRgnData: DWORD;
    iMode: DWORD;
    RgnData: array [0 .. 0] of Byte;
  end;

  PEMRFillRgnLocal = ^TEMRFillRgnLocal;

  TEMRFillRgnLocal = packed record
    emr: TEMR;
    rclBounds: TRect;
    cbRgnData: DWORD;
    ihBrush: DWORD;
    RgnData: array [0 .. 0] of Byte;
  end;

  PEMRFrameRgnLocal = ^TEMRFrameRgnLocal;

  TEMRFrameRgnLocal = packed record
    emr: TEMR;
    rclBounds: TRect;
    cbRgnData: DWORD;
    ihBrush: DWORD;
    szlStroke: TSize;
    RgnData: array [0 .. 0] of Byte;
  end;

  PEMRRegionLocal = ^TEMRRegionLocal;

  TEMRRegionLocal = packed record
    emr: TEMR;
    rclBounds: TRect;
    cbRgnData: DWORD;
    RgnData: array [0 .. 0] of Byte;
  end;

  PEMRSelectClipPathLocal = ^TEMRSelectClipPathLocal;

  TEMRSelectClipPathLocal = packed record
    emr: TEMR;
    iMode: DWORD;
  end;

  TEMRTextLocal = packed record
    ptlReference: TPoint;
    nChars: DWORD;
    offString: DWORD;
    fOptions: DWORD;
    rcl: TRect;
    offDx: DWORD;
  end;

  PEMRTextLocal = ^TEMRTextLocal;

  PEMRPolyTextOutLocal = ^TEMRPolyTextOutLocal;

  TEMRPolyTextOutLocal = packed record
    emr: TEMR;
    rclBounds: TRect;
    iGraphicsMode: DWORD;
    exScale: Single;
    eyScale: Single;
    cStrings: Longint;
    aemrtext: array [0 .. 0] of TEMRTextLocal;
  end;

  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array [0 .. 0] of Integer;

  PPointArray = ^TPointArray;
  TPointArray = array [0 .. 0] of TPoint;

  PSmallPointArray = ^TSmallPointArray;
  TSmallPointArray = array [0 .. 0] of TSmallPoint;

  PRectArray = ^TRectArray;
  TRectArray = array [0 .. 0] of TRect;

  PTriVertexArray = ^TTriVertexArray;
  TTriVertexArray = array [0 .. 0] of TTriVertex;

  PGradientRectArray = ^TGradientRectArrayLocal;
  TGradientRectArrayLocal = array [0 .. 0] of TGradientRect;

  PGradientTriangleArray = ^TGradientTriangleArrayLocal;
  TGradientTriangleArrayLocal = array [0 .. 0] of TGradientTriangle;

  TMetaObjectKind = (mokNone, mokPen, mokBrush, mokFont);

  TMetaObject = record
    Active: Boolean;
    Kind: TMetaObjectKind;
    Stroke: TMetafileStrokeStyle;
    Fill: TMetafileFillStyle;
    Font: TLogFontW;
  end;

  TDCState = record
    MapMode: Integer;
    WindowOrg: TPoint;
    WindowExt: TSize;
    ViewportOrg: TPoint;
    ViewportExt: TSize;
    WorldTransform: TXForm;
    TextColor: TColor;
    BkColor: TColor;
    BkMode: Cardinal;
    TextAlign: Cardinal;
    TextOptions: Cardinal;
    TextBounds: TMetafileRect;
    TextDx: TMetafileIntegerArray;
    TextDy: TMetafileIntegerArray;
    TextJustificationBreakExtra: Integer;
    TextJustificationBreakCount: Integer;
    PolyFillMode: Cardinal;
    ArcDirection: Cardinal;
    MiterLimit: Double;
    RasterOperation2: Cardinal;
    StretchMode: Cardinal;
    BrushOrigin: TPoint;
    Layout: Cardinal;
    CurrentPos: TPoint;
    NextPos: TPoint;
    Stroke: TMetafileStrokeStyle;
    Fill: TMetafileFillStyle;
    Clip: TMetafileClipStyle;
    Font: TLogFontW;
  end;

  TMetafileDCState = class
  private
    FObjects: array of TMetaObject;
    FStateStack: array of TDCState;
    FHeaderBounds: TRect;
    FFrameRect001MM: TRect;
    FDeviceSizePx: TSize;
    FDeviceSizeMM: TSize;
    FDeviceDpiX: Double;
    FDeviceDpiY: Double;
    FMaxObjectHandle: Cardinal;
    function DeviceScaleX: Double;
    function DeviceScaleY: Double;
    procedure InitDefaultState;
    procedure ClearObjects;
    function GetObject(AHandle: Cardinal; out AObject: TMetaObject): Boolean;
    function SelectStockObject(AHandle: Cardinal): Boolean;
  public
    State: TDCState;
    constructor Create;
    procedure Reset;
    procedure ApplyHeader(const AHeader: TEMRHeaderLocal);
    procedure SaveState;
    procedure RestoreState(ARelative: Integer);
    procedure SetObject(AHandle: Cardinal; const AObject: TMetaObject);
    procedure SelectObjectHandle(AHandle: Cardinal);
    procedure DeleteObjectHandle(AHandle: Cardinal);
    function LogicalToOutput(const P: TPoint): TMetafilePoint; overload;
    function LogicalToOutput(X, Y: Double): TMetafilePoint; overload;
    function LogicalDeltaToOutput(Dx, Dy: Double): TMetafilePoint;
    function LogicalPenWidthToOutput(AWidth: Double): Double;
    function CurrentStroke: TMetafileStrokeStyle;
    function CurrentFill: TMetafileFillStyle;
    function CurrentTextStyle: TMetafileTextStyle;
    function CurrentClip: TMetafileClipStyle;
    procedure SetTextRecordMetrics(AOptions: Cardinal; const ABounds: TMetafileRect; const ADx, ADy: TMetafileIntegerArray);
    procedure SetTextJustification(ABreakExtra, ABreakCount: Integer);
    procedure ClearClip;
    procedure SetClipRegion(const APoints: TMetafilePointArray; const ACounts: TMetafileIntegerArray; ACombineMode: Cardinal);
    procedure ApplyClipRect(const ARect: TRect; ACombineMode: Cardinal);
    procedure OffsetClip(const ADelta: TPoint);
  end;

  TPathContour = record
    Points: TMetafilePointArray;
    Closed: Boolean;
  end;

  TMetafilePathBuilder = class
  private
    FContours: array of TPathContour;
    FRecording: Boolean;
    FReady: Boolean;
  public
    procedure Clear;
    procedure BeginPath;
    procedure EndPath;
    function HasData: Boolean;
    function Build(out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
    procedure ReplaceWith(const APoints: TMetafilePointArray; const APointCounts: TMetafileIntegerArray);
    procedure Widen(AWidth: Double);
    procedure AppendContour(const APoints: TMetafilePointArray; AClosed: Boolean);
    procedure AppendOpenPolyline(const APoints: TMetafilePointArray);
    procedure CloseFigure;
    property Recording: Boolean read FRecording write FRecording;
    property Ready: Boolean read FReady write FReady;
  end;

  TMetafileTextOutlineConverter = class
  public
    function TextToFlatPolygons(const AText: UnicodeString; const AOrigin: TMetafilePoint; const ALogFont: TLogFontW; AGlyphIndexes: PWord; AGlyphCount: Integer; const ADx, ADy: TMetafileIntegerArray;
      AOptions: Cardinal; ADCState: TMetafileDCState; AFlatness: Double; out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
  end;

  TClipBooleanSource = (cbsSubject, cbsClip);

  TClipBooleanEdge = record
    P0: TMetafilePoint;
    P1: TMetafilePoint;
    Source: TClipBooleanSource;
  end;

  TClipBooleanEvent = record
    X: Double;
    EdgeIndex: Integer;
  end;

  TClipBooleanEdgeArray = array of TClipBooleanEdge;
  TClipBooleanEventArray = array of TClipBooleanEvent;
  TClipBooleanYArray = array of Double;

  TMetafileClipBooleanEngine = class
  private
    class procedure AddY(var AYs: TClipBooleanYArray; AY: Double);
    class procedure SortYs(var AYs: TClipBooleanYArray);
    class procedure SortEvents(var AEvents: TClipBooleanEventArray);
    class procedure AddEdge(var AEdges: TClipBooleanEdgeArray; var AYs: TClipBooleanYArray; const AP0, AP1: TMetafilePoint; ASource: TClipBooleanSource);
    class procedure AddContours(const APoints: TMetafilePointArray; const ACounts: TMetafileIntegerArray; ASource: TClipBooleanSource; var AEdges: TClipBooleanEdgeArray; var AYs: TClipBooleanYArray);
    class procedure AddIntersectionYs(const AEdges: TClipBooleanEdgeArray; var AYs: TClipBooleanYArray);
    class function EdgeActiveAtY(const AEdge: TClipBooleanEdge; AY: Double): Boolean;
    class function EdgeXAtY(const AEdge: TClipBooleanEdge; AY: Double): Double;
    class function SegmentIntersectionY(const A, B: TClipBooleanEdge; out AY: Double): Boolean;
    class function CombinedInside(AInsideSubject, AInsideClip: Boolean; ACombineMode: Cardinal): Boolean;
    class function AppendSlabPolygon(const ALeft, ARight: TClipBooleanEdge; AY0, AY1: Double; var APoints: TMetafilePointArray; var ACounts: TMetafileIntegerArray): Boolean;
  public
    class function Execute(const ASubjectPoints: TMetafilePointArray; const ASubjectCounts: TMetafileIntegerArray; const AClipPoints: TMetafilePointArray; const AClipCounts: TMetafileIntegerArray;
      ACombineMode: Cardinal; out AResultPoints: TMetafilePointArray; out AResultCounts: TMetafileIntegerArray): Boolean;
  end;

function MinimumMetafileRecordSize(Kind:Cardinal):Cardinal;
begin
  Result:=8;
  case Kind of
    1:Result:=88;
    2..6,56,85..89,92:Result:=28;
    7,8,90,91:Result:=32;
    9..13,26,27:Result:=16;
    14:Result:=20;
    15:Result:=20;
    16..25,37,40,57,58,67,98,115:Result:=12;
    29..32:Result:=24;
    34:Result:=12;
    35:Result:=32;
    36:Result:=36;
    38:Result:=28;
    39,42,43:Result:=24;
    41:Result:=28;
    44:Result:=32;
    45..47,55:Result:=40;
    54:Result:=16;
    62..64:Result:=24;
    75:Result:=16;
    76:Result:=100;
    77,114,116:Result:=108;
    78:Result:=128;
    79:Result:=140;
    80:Result:=76;
    81:Result:=80;
    82:Result:=104;
    83,84:Result:=76;
    93,94:Result:=32;
    95:Result:=52;
    96,97:Result:=40;
    108:Result:=36;
    118:Result:=36;
    120:Result:=16;
  end;
end;

function EnumMetafilePrimitiveProc(ADC: HDC; ATable: PHandleTable; ARecord: PEnhMetaRecord; AObjects: Integer; AData: Pointer): Integer; stdcall;
var Minimum:Cardinal;
begin
  try
    if ARecord=nil then raise EReadError.Create(SMetafileEmpty);
    Minimum:=MinimumMetafileRecordSize(ARecord.iType);
    if ARecord.nSize<Minimum then raise EReadError.CreateFmt(SMetafileInvalidRecord,[ARecord.iType,Minimum,ARecord.nSize]);
    if Assigned(TMetafileParser(AData).FOnRecord) then
      TMetafileParser(AData).FOnRecord(AData,ADC,ATable,ARecord,AObjects);
    Result:=TMetafileParser(AData).EnumRecord(ADC,ARecord);
    if (Result<>0) and Assigned(TMetafileParser(AData).FOnRecordComplete) then
      TMetafileParser(AData).FOnRecordComplete(AData,ADC,ATable,ARecord,AObjects);
  except on E:Exception do begin TMetafileParser(AData).FLastError:=E.Message;Result:=0;end;end;
end;

function PtrOffset(APtr: Pointer; AOffset: NativeUInt): Pointer;
begin
  Result := Pointer(NativeUInt(APtr) + AOffset);
end;

function IntPoint(AX, AY: Integer): TPoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function EmptyRectD: TMetafileRect;
begin
  Result.Left := 0;
  Result.Top := 0;
  Result.Right := 0;
  Result.Bottom := 0;
end;

function XFormIdentity: TXForm;
begin
  Result.eM11 := 1;
  Result.eM12 := 0;
  Result.eM21 := 0;
  Result.eM22 := 1;
  Result.eDx := 0;
  Result.eDy := 0;
end;

function MultiplyXForm(const A, B: TXForm): TXForm;
begin
  Result.eM11 := A.eM11 * B.eM11 + A.eM12 * B.eM21;
  Result.eM12 := A.eM11 * B.eM12 + A.eM12 * B.eM22;
  Result.eM21 := A.eM21 * B.eM11 + A.eM22 * B.eM21;
  Result.eM22 := A.eM21 * B.eM12 + A.eM22 * B.eM22;
  Result.eDx := A.eDx * B.eM11 + A.eDy * B.eM21 + B.eDx;
  Result.eDy := A.eDx * B.eM12 + A.eDy * B.eM22 + B.eDy;
end;

procedure SetLogFontFace(var AFont: TLogFontW; const AFace: UnicodeString);
begin
  FillChar(AFont.lfFaceName, SizeOf(AFont.lfFaceName), 0);
  if AFace <> '' then
    StringToWideChar(AFace, PWideChar(@AFont.lfFaceName[0]), LF_FACESIZE);
end;

function DefaultTextLogFont: TLogFontW;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.lfHeight := -12;
  Result.lfWeight := FW_NORMAL;
  Result.lfCharSet := DEFAULT_CHARSET;
  Result.lfOutPrecision := OUT_OUTLINE_PRECIS;
  Result.lfClipPrecision := CLIP_DEFAULT_PRECIS;
  Result.lfQuality := PROOF_QUALITY;
  Result.lfPitchAndFamily := VARIABLE_PITCH or FF_SWISS;
  SetLogFontFace(Result, DEFAULT_OUTLINE_TEXT_FACE);
end;

function LogFontFaceName(const AFont: TLogFontW): UnicodeString;
var
  I, Len: Integer;
begin
  Len := 0;
  for I := 0 to LF_FACESIZE - 1 do
  begin
    if AFont.lfFaceName[I] = #0 then
      Break;
    Inc(Len);
  end;
  SetString(Result, PWideChar(@AFont.lfFaceName[0]), Len);
end;

function NeedsOutlineTextFallback(const AFont: TLogFontW): Boolean;
var
  Face: string;
begin
  Face := Trim(string(LogFontFaceName(AFont)));
  Result := (Face = '') or SameText(Face, 'System') or SameText(Face, 'MS Sans Serif') or SameText(Face, 'MS Shell Dlg') or SameText(Face, 'Terminal');
end;

procedure AppendPoint(var APoints: TMetafilePointArray; const P: TMetafilePoint);
var
  L: Integer;
begin
  L := Length(APoints);
  SetLength(APoints, L + 1);
  APoints[L] := P;
end;

procedure AppendPoints(var APoints: TMetafilePointArray; const ASource: TMetafilePointArray; ASkipFirst: Boolean);
var
  I, StartIndex, L: Integer;
begin
  if Length(ASource) = 0 then
    Exit;
  StartIndex := 0;
  if ASkipFirst then
    StartIndex := 1;
  if StartIndex > High(ASource) then
    Exit;
  L := Length(APoints);
  SetLength(APoints, L + Length(ASource) - StartIndex);
  for I := StartIndex to High(ASource) do
    APoints[L + I - StartIndex] := ASource[I];
end;

procedure AppendCount(var ACounts: TMetafileIntegerArray; ACount: Integer);
var
  L: Integer;
begin
  L := Length(ACounts);
  SetLength(ACounts, L + 1);
  ACounts[L] := ACount;
end;

procedure AppendCounts(var ACounts: TMetafileIntegerArray; const ASource: TMetafileIntegerArray);
var
  I, L: Integer;
begin
  if Length(ASource) = 0 then
    Exit;
  L := Length(ACounts);
  SetLength(ACounts, L + Length(ASource));
  for I := 0 to High(ASource) do
    ACounts[L + I] := ASource[I];
end;

function DistancePointToLine(const P, A, B: TMetafilePoint): Double;
var
  Dx, Dy, Len: Double;
begin
  Dx := B.X - A.X;
  Dy := B.Y - A.Y;
  Len := Hypot(Dx, Dy);
  if Len <= 1E-12 then
    Result := Hypot(P.X - A.X, P.Y - A.Y)
  else
    Result := Abs(Dy * P.X - Dx * P.Y + B.X * A.Y - B.Y * A.X) / Len;
end;

function MidPoint(const A, B: TMetafilePoint): TMetafilePoint;
begin
  Result.X := (A.X + B.X) * 0.5;
  Result.Y := (A.Y + B.Y) * 0.5;
end;

function PointsAlmostEqual(const A, B: TMetafilePoint): Boolean;
begin
  Result := (Abs(A.X - B.X) <= 1E-8) and (Abs(A.Y - B.Y) <= 1E-8);
end;

function CopyPoints(const APoints: TMetafilePointArray): TMetafilePointArray;
var
  I: Integer;
begin
  SetLength(Result, Length(APoints));
  for I := 0 to High(APoints) do
    Result[I] := APoints[I];
end;

function CopyCounts(const ACounts: TMetafileIntegerArray): TMetafileIntegerArray;
var
  I: Integer;
begin
  SetLength(Result, Length(ACounts));
  for I := 0 to High(ACounts) do
    Result[I] := ACounts[I];
end;

function CopyBytes(const ABytes: TMetafileByteArray): TMetafileByteArray;
begin
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[0], Length(ABytes) * SizeOf(Byte));
end;

function CopyBrushData(const ABrush: TMetafileBrushData): TMetafileBrushData;
begin
  Result := ABrush;
  Result.BitmapInfo := CopyBytes(ABrush.BitmapInfo);
  Result.Bits := CopyBytes(ABrush.Bits);
end;

function CopyGradientFillStyle(const AGradient: TMetafileGradientFillStyle): TMetafileGradientFillStyle;
var
  I: Integer;
begin
  Result := AGradient;
  SetLength(Result.Vertices, Length(AGradient.Vertices));
  for I := 0 to High(AGradient.Vertices) do
    Result.Vertices[I] := AGradient.Vertices[I];
  SetLength(Result.Meshes, Length(AGradient.Meshes));
  for I := 0 to High(AGradient.Meshes) do
    Result.Meshes[I] := AGradient.Meshes[I];
end;

function CopyStrokeStyle(const AStyle: TMetafileStrokeStyle): TMetafileStrokeStyle;
begin
  Result := AStyle;
  Result.Brush := CopyBrushData(AStyle.Brush);
end;

function CopyFillStyle(const AStyle: TMetafileFillStyle): TMetafileFillStyle;
begin
  Result := AStyle;
  Result.Brush := CopyBrushData(AStyle.Brush);
  Result.Gradient := CopyGradientFillStyle(AStyle.Gradient);
end;

function CopyTextStyle(const AStyle: TMetafileTextStyle): TMetafileTextStyle;
begin
  Result := AStyle;
  Result.Dx := CopyCounts(AStyle.Dx);
  Result.Dy := CopyCounts(AStyle.Dy);
end;

function CopyClipStyle(const AStyle: TMetafileClipStyle): TMetafileClipStyle;
begin
  Result := AStyle;
  Result.Points := CopyPoints(AStyle.Points);
  Result.PointCounts := CopyCounts(AStyle.PointCounts);
end;

function CopyImageData(const AData: TMetafileImageData): TMetafileImageData;
begin
  Result := AData;
  Result.BitmapInfo := CopyBytes(AData.BitmapInfo);
  Result.Bits := CopyBytes(AData.Bits);
end;

function CopyImageStyle(const AImage: TMetafileImageStyle): TMetafileImageStyle;
begin
  Result := AImage;
  Result.PatternBrush := CopyBrushData(AImage.PatternBrush);
  Result.Image := CopyImageData(AImage.Image);
  Result.Mask := CopyImageData(AImage.Mask);
end;

procedure ClearImageStyle(var AImage: TMetafileImageStyle);
begin
  SetLength(AImage.Image.BitmapInfo, 0);
  SetLength(AImage.Image.Bits, 0);
  SetLength(AImage.Mask.BitmapInfo, 0);
  SetLength(AImage.Mask.Bits, 0);
  SetLength(AImage.PatternBrush.BitmapInfo, 0);
  SetLength(AImage.PatternBrush.Bits, 0);
  AImage.OperationKind := mrokNone;
  AImage.Operation := 0;
  AImage.Blend := 0;
  AImage.Rop3 := 0;
  AImage.ForegroundRop3 := 0;
  AImage.BackgroundRop3 := 0;
  AImage.OperationName := '';
  AImage.BkColorSrc := clNone;
  AImage.PatternColor := clNone;
  AImage.PatternBrush.Kind := mbdkNone;
  AImage.PatternBrush.Usage := 0;
  AImage.PatternBrushOrigin := IntPoint(0, 0);
  AImage.StretchMode := 0;
  AImage.BlendOperation := 0;
  AImage.BlendFlags := 0;
  AImage.SourceConstantAlpha := 255;
  AImage.AlphaFormat := 0;
  AImage.HasPerPixelAlpha := False;
  AImage.TransparentColor := clNone;
  AImage.MaskOrigin := IntPoint(0, 0);
  AImage.StartScan := 0;
  AImage.ScanCount := 0;
  AImage.SrcRect := EmptyRectD;
  AImage.DestRect := EmptyRectD;
  AImage.Bounds := EmptyRectD;
  AImage.XForm := XFormIdentity;
  AImage.Image.Usage := 0;
  AImage.Mask.Usage := 0;
end;

function MetafileRopToByte(AOperation: Cardinal): Byte;
begin
  if AOperation <= $FF then
    Result := Byte(AOperation)
  else
    Result := Byte(AOperation shr 16);
end;

function MetafileRop4ForegroundByte(AOperation: Cardinal): Byte;
begin
  Result := MetafileRopToByte(AOperation);
end;

function MetafileRop4BackgroundByte(AOperation: Cardinal): Byte;
begin
  if (AOperation and $FF000000) <> 0 then
    Result := Byte(AOperation shr 24)
  else
    Result := MetafileRop4ForegroundByte(AOperation);
end;

function MetafileRopByteName(ARop3: Byte): string;
begin
  case ARop3 of
    $00:
      Result := 'BLACKNESS';
    $55:
      Result := 'DSTINVERT';
    $66:
      Result := 'SRCINVERT';
    $88:
      Result := 'SRCAND';
    $AA:
      Result := 'D';
    $CC:
      Result := 'SRCCOPY';
    $EE:
      Result := 'SRCPAINT';
    $F0:
      Result := 'PATCOPY';
    $FB:
      Result := 'PATPAINT';
    $FF:
      Result := 'WHITENESS';
  else
    Result := Format('$%.2x', [ARop3]);
  end;
end;

function MetafileRasterOperationName(AKind: TMetafileRasterOperationKind; AOperation: Cardinal): string;
begin
  case AKind of
    mrokAlphaBlend:
      Result := 'ALPHABLEND';
    mrokTransparent:
      Result := Format('TRANSPARENT color=$%.6x', [AOperation and $00FFFFFF]);
    mrokSetDIBits:
      Result := 'SETDIBITSTODEVICE';
    mrokPlgBlt:
      Result := 'PLGBLT';
    mrokRop4:
      Result := Format('ROP4 fg=%s bg=%s',
        [MetafileRopByteName(MetafileRop4ForegroundByte(AOperation)),
         MetafileRopByteName(MetafileRop4BackgroundByte(AOperation))]);
    mrokRop3:
      Result := MetafileRopByteName(MetafileRopToByte(AOperation));
  else
    Result := Format('$%.8x', [AOperation]);
  end;
end;

function BoundsOfPoints(const APoints: TMetafilePointArray): TMetafileRect;
var
  I: Integer;
begin
  Result := EmptyRectD;
  if Length(APoints) = 0 then
    Exit;
  Result.Left := APoints[0].X;
  Result.Right := APoints[0].X;
  Result.Top := APoints[0].Y;
  Result.Bottom := APoints[0].Y;
  for I := 1 to High(APoints) do
  begin
    Result.Left := Min(Result.Left, APoints[I].X);
    Result.Right := Max(Result.Right, APoints[I].X);
    Result.Top := Min(Result.Top, APoints[I].Y);
    Result.Bottom := Max(Result.Bottom, APoints[I].Y);
  end;
end;

function DCStateOf(AImporter: TMetafileParser): TMetafileDCState;
begin
  Result := TMetafileDCState(AImporter.FDCState);
end;

function PathBuilderOf(AImporter: TMetafileParser): TMetafilePathBuilder;
begin
  Result := TMetafilePathBuilder(AImporter.FPathBuilder);
end;

function TextOutlineConverterOf(AImporter: TMetafileParser): TMetafileTextOutlineConverter;
begin
  Result := TMetafileTextOutlineConverter(AImporter.FTextOutlineConverter);
end;

procedure ClearDCStateManagedFields(var AState: TDCState);
begin
  SetLength(AState.TextDx, 0);
  SetLength(AState.TextDy, 0);
  SetLength(AState.Stroke.Brush.BitmapInfo, 0);
  SetLength(AState.Stroke.Brush.Bits, 0);
  SetLength(AState.Fill.Brush.BitmapInfo, 0);
  SetLength(AState.Fill.Brush.Bits, 0);
  SetLength(AState.Fill.Gradient.Vertices, 0);
  SetLength(AState.Fill.Gradient.Meshes, 0);
  SetLength(AState.Clip.Points, 0);
  SetLength(AState.Clip.PointCounts, 0);
end;

{ TMetafileClipBooleanEngine }

class procedure TMetafileClipBooleanEngine.AddY(var AYs: TClipBooleanYArray; AY: Double);
var
  I, L: Integer;
begin
  for I := 0 to High(AYs) do
    if Abs(AYs[I] - AY) <= CLIP_BOOLEAN_EPSILON then
      Exit;
  L := Length(AYs);
  SetLength(AYs, L + 1);
  AYs[L] := AY;
end;

class procedure TMetafileClipBooleanEngine.SortYs(var AYs: TClipBooleanYArray);

  procedure QuickSort(ALeft, ARight: Integer);
  var
    I, J: Integer;
    P, T: Double;
  begin
    I := ALeft;
    J := ARight;
    P := AYs[(ALeft + ARight) div 2];
    repeat
      while AYs[I] < P do
        Inc(I);
      while AYs[J] > P do
        Dec(J);
      if I <= J then
      begin
        T := AYs[I];
        AYs[I] := AYs[J];
        AYs[J] := T;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if ALeft < J then
      QuickSort(ALeft, J);
    if I < ARight then
      QuickSort(I, ARight);
  end;

begin
  if Length(AYs) > 1 then
    QuickSort(0, High(AYs));
end;

class procedure TMetafileClipBooleanEngine.SortEvents(var AEvents: TClipBooleanEventArray);

  procedure QuickSort(ALeft, ARight: Integer);
  var
    I, J: Integer;
    P: Double;
    T: TClipBooleanEvent;
  begin
    I := ALeft;
    J := ARight;
    P := AEvents[(ALeft + ARight) div 2].X;
    repeat
      while AEvents[I].X < P do
        Inc(I);
      while AEvents[J].X > P do
        Dec(J);
      if I <= J then
      begin
        T := AEvents[I];
        AEvents[I] := AEvents[J];
        AEvents[J] := T;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if ALeft < J then
      QuickSort(ALeft, J);
    if I < ARight then
      QuickSort(I, ARight);
  end;

begin
  if Length(AEvents) > 1 then
    QuickSort(0, High(AEvents));
end;

class procedure TMetafileClipBooleanEngine.AddEdge(var AEdges: TClipBooleanEdgeArray; var AYs: TClipBooleanYArray; const AP0, AP1: TMetafilePoint; ASource: TClipBooleanSource);
var
  L: Integer;
begin
  AddY(AYs, AP0.Y);
  AddY(AYs, AP1.Y);
  if PointsAlmostEqual(AP0, AP1) then
    Exit;
  L := Length(AEdges);
  SetLength(AEdges, L + 1);
  AEdges[L].P0 := AP0;
  AEdges[L].P1 := AP1;
  AEdges[L].Source := ASource;
end;

class procedure TMetafileClipBooleanEngine.AddContours(const APoints: TMetafilePointArray; const ACounts: TMetafileIntegerArray; ASource: TClipBooleanSource; var AEdges: TClipBooleanEdgeArray; var AYs: TClipBooleanYArray);
var
  I, J, StartIndex, Count: Integer;
begin
  StartIndex := 0;
  for I := 0 to High(ACounts) do
  begin
    Count := ACounts[I];
    if (Count <= 0) or (StartIndex + Count > Length(APoints)) then
      Break;
    if Count >= 2 then
    begin
      for J := 0 to Count - 2 do
        AddEdge(AEdges, AYs, APoints[StartIndex + J], APoints[StartIndex + J + 1], ASource);
      if not PointsAlmostEqual(APoints[StartIndex], APoints[StartIndex + Count - 1]) then
        AddEdge(AEdges, AYs, APoints[StartIndex + Count - 1], APoints[StartIndex], ASource);
    end;
    Inc(StartIndex, Count);
  end;
end;

class function TMetafileClipBooleanEngine.SegmentIntersectionY(const A, B: TClipBooleanEdge; out AY: Double): Boolean;
var
  Rx, Ry, Sx, Sy, Qx, Qy, Den, T, U: Double;
begin
  Result := False;
  AY := 0;
  Rx := A.P1.X - A.P0.X;
  Ry := A.P1.Y - A.P0.Y;
  Sx := B.P1.X - B.P0.X;
  Sy := B.P1.Y - B.P0.Y;
  Den := Rx * Sy - Ry * Sx;
  if Abs(Den) <= CLIP_BOOLEAN_EPSILON then
    Exit;
  Qx := B.P0.X - A.P0.X;
  Qy := B.P0.Y - A.P0.Y;
  T := (Qx * Sy - Qy * Sx) / Den;
  U := (Qx * Ry - Qy * Rx) / Den;
  if (T > CLIP_BOOLEAN_EPSILON) and (T < 1 - CLIP_BOOLEAN_EPSILON) and
     (U > CLIP_BOOLEAN_EPSILON) and (U < 1 - CLIP_BOOLEAN_EPSILON) then
  begin
    AY := A.P0.Y + T * Ry;
    Result := True;
  end;
end;

class procedure TMetafileClipBooleanEngine.AddIntersectionYs(const AEdges: TClipBooleanEdgeArray; var AYs: TClipBooleanYArray);
var
  I, J: Integer;
  Y: Double;
begin
  for I := 0 to High(AEdges) - 1 do
    for J := I + 1 to High(AEdges) do
      if SegmentIntersectionY(AEdges[I], AEdges[J], Y) then
        AddY(AYs, Y);
end;

class function TMetafileClipBooleanEngine.EdgeActiveAtY(const AEdge: TClipBooleanEdge; AY: Double): Boolean;
var
  MinY, MaxY: Double;
begin
  MinY := Min(AEdge.P0.Y, AEdge.P1.Y);
  MaxY := Max(AEdge.P0.Y, AEdge.P1.Y);
  Result := (MaxY - MinY > CLIP_BOOLEAN_EPSILON) and
    (AY > MinY + CLIP_BOOLEAN_EPSILON) and (AY < MaxY - CLIP_BOOLEAN_EPSILON);
end;

class function TMetafileClipBooleanEngine.EdgeXAtY(const AEdge: TClipBooleanEdge; AY: Double): Double;
var
  T: Double;
begin
  if Abs(AEdge.P1.Y - AEdge.P0.Y) <= CLIP_BOOLEAN_EPSILON then
    Result := (AEdge.P0.X + AEdge.P1.X) * 0.5
  else
  begin
    T := (AY - AEdge.P0.Y) / (AEdge.P1.Y - AEdge.P0.Y);
    Result := AEdge.P0.X + T * (AEdge.P1.X - AEdge.P0.X);
  end;
end;

class function TMetafileClipBooleanEngine.CombinedInside(AInsideSubject, AInsideClip: Boolean; ACombineMode: Cardinal): Boolean;
begin
  case ACombineMode of
    RGN_AND:
      Result := AInsideSubject and AInsideClip;
    RGN_OR:
      Result := AInsideSubject or AInsideClip;
    RGN_XOR:
      Result := AInsideSubject xor AInsideClip;
    RGN_DIFF:
      Result := AInsideSubject and not AInsideClip;
  else
    Result := AInsideClip;
  end;
end;

class function TMetafileClipBooleanEngine.AppendSlabPolygon(const ALeft, ARight: TClipBooleanEdge; AY0, AY1: Double; var APoints: TMetafilePointArray; var ACounts: TMetafileIntegerArray): Boolean;
var
  One: TMetafilePointArray;
  Area: Double;

  function PointOnEdgeAtY(const AEdge: TClipBooleanEdge; AY: Double): TMetafilePoint;
  begin
    Result.Y := AY;
    Result.X := EdgeXAtY(AEdge, AY);
  end;

begin
  Result := False;
  if AY1 - AY0 <= CLIP_BOOLEAN_EPSILON then
    Exit;

  SetLength(One, 5);
  One[0] := PointOnEdgeAtY(ALeft, AY0);
  One[1] := PointOnEdgeAtY(ARight, AY0);
  One[2] := PointOnEdgeAtY(ARight, AY1);
  One[3] := PointOnEdgeAtY(ALeft, AY1);
  One[4] := One[0];

  Area := ((One[0].X * One[1].Y - One[1].X * One[0].Y) +
           (One[1].X * One[2].Y - One[2].X * One[1].Y) +
           (One[2].X * One[3].Y - One[3].X * One[2].Y) +
           (One[3].X * One[0].Y - One[0].X * One[3].Y)) * 0.5;
  if Abs(Area) <= CLIP_BOOLEAN_EPSILON then
    Exit;

  AppendPoints(APoints, One, False);
  AppendCount(ACounts, Length(One));
  Result := True;
end;

class function TMetafileClipBooleanEngine.Execute(const ASubjectPoints: TMetafilePointArray; const ASubjectCounts: TMetafileIntegerArray; const AClipPoints: TMetafilePointArray; const AClipCounts: TMetafileIntegerArray;
  ACombineMode: Cardinal; out AResultPoints: TMetafilePointArray; out AResultCounts: TMetafileIntegerArray): Boolean;
var
  Edges: TClipBooleanEdgeArray;
  Ys: TClipBooleanYArray;
  Events: TClipBooleanEventArray;
  I, J, K, L, StartEdgeIndex, EndEdgeIndex: Integer;
  Y0, Y1, YMid, GroupX: Double;
  InsideSubject, InsideClip, BeforeInside, AfterInside: Boolean;

  procedure AddEvent(AX: Double; AEdgeIndex: Integer);
  var
    N: Integer;
  begin
    N := Length(Events);
    SetLength(Events, N + 1);
    Events[N].X := AX;
    Events[N].EdgeIndex := AEdgeIndex;
  end;

begin
  Result := False;
  SetLength(AResultPoints, 0);
  SetLength(AResultCounts, 0);
  if not ((ACombineMode = RGN_AND) or (ACombineMode = RGN_OR) or (ACombineMode = RGN_XOR) or (ACombineMode = RGN_DIFF)) then
    Exit;

  AddContours(ASubjectPoints, ASubjectCounts, cbsSubject, Edges, Ys);
  AddContours(AClipPoints, AClipCounts, cbsClip, Edges, Ys);
  if Length(Ys) < 2 then
  begin
    Result := True;
    Exit;
  end;

  AddIntersectionYs(Edges, Ys);
  SortYs(Ys);

  for I := 0 to High(Ys) - 1 do
  begin
    Y0 := Ys[I];
    Y1 := Ys[I + 1];
    if Y1 - Y0 <= CLIP_BOOLEAN_EPSILON then
      Continue;
    YMid := (Y0 + Y1) * 0.5;
    SetLength(Events, 0);
    for J := 0 to High(Edges) do
      if EdgeActiveAtY(Edges[J], YMid) then
        AddEvent(EdgeXAtY(Edges[J], YMid), J);
    if Length(Events) = 0 then
      Continue;
    SortEvents(Events);

    InsideSubject := False;
    InsideClip := False;
    StartEdgeIndex := -1;
    J := 0;
    while J <= High(Events) do
    begin
      GroupX := Events[J].X;
      K := J;
      while (K <= High(Events)) and (Abs(Events[K].X - GroupX) <= CLIP_BOOLEAN_EPSILON) do
        Inc(K);

      BeforeInside := CombinedInside(InsideSubject, InsideClip, ACombineMode);
      for L := J to K - 1 do
        if Edges[Events[L].EdgeIndex].Source = cbsSubject then
          InsideSubject := not InsideSubject
        else
          InsideClip := not InsideClip;
      AfterInside := CombinedInside(InsideSubject, InsideClip, ACombineMode);

      if BeforeInside <> AfterInside then
      begin
        if AfterInside then
          StartEdgeIndex := Events[J].EdgeIndex
        else
        begin
          EndEdgeIndex := Events[J].EdgeIndex;
          if StartEdgeIndex >= 0 then
            AppendSlabPolygon(Edges[StartEdgeIndex], Edges[EndEdgeIndex], Y0, Y1, AResultPoints, AResultCounts);
          StartEdgeIndex := -1;
        end;
      end;

      J := K;
    end;
  end;

  Result := True;
end;


{ TMetafileStrokeStyle }

function TMetafileStrokeStyle.PenStyle: TPenStyle;
begin
   if not Visible then
    Exit(psClear);

  case Style and PS_STYLE_MASK of
    PS_SOLID:
      Result := psSolid;
    PS_DASH:
      Result := psDash;
    PS_DOT:
      Result := psDot;
    PS_DASHDOT:
      Result := psDashDot;
    PS_DASHDOTDOT:
      Result := psDashDotDot;
    PS_NULL:
      Result := psClear;
    PS_INSIDEFRAME:
      Result := psInsideFrame;
  else
    // PS_USERSTYLE / PS_ALTERNATE
    Result := psSolid;
  end;
end;

procedure TMetafilePrimitive.Assign(Source: TMetafilePrimitive);
begin
  if Source = nil then
    Exit;
  Kind := Source.Kind;
  Points := CopyPoints(Source.Points);
  PointCounts := CopyCounts(Source.PointCounts);
  Text := Source.Text;
  Bounds := Source.Bounds;
  Stroke := CopyStrokeStyle(Source.Stroke);
  Fill := CopyFillStyle(Source.Fill);
  TextStyle := CopyTextStyle(Source.TextStyle);
  Clip := CopyClipStyle(Source.Clip);
  Image := CopyImageStyle(Source.Image);
  SourceRecordType := Source.SourceRecordType;
  SourceRecordIndex := Source.SourceRecordIndex;
  SourceRecordName := Source.SourceRecordName;
end;

function TMetafilePrimitive.Clone: TMetafilePrimitive;
begin
  Result := TMetafilePrimitive.Create;
  Result.Assign(Self);
end;

function TMetafilePrimitive.SubPoints(Index: Integer): TMetafilePointArray;
var
  I, StartIndex, Count: Integer;
begin
  Result := nil;

  if not InRange(Index, Low(PointCounts), High(PointCounts)) then
    Exit;

  StartIndex := 0;

  for I := Low(PointCounts) to Index - 1 do
  begin
    if PointCounts[I] < 0 then
      Exit;

    Inc(StartIndex, PointCounts[I]);
  end;

  Count := PointCounts[Index];

  if Count <= 0 then
    Exit;

  if StartIndex < 0 then
    Exit;

  if StartIndex + Count > Length(Points) then
    Exit;

  SetLength(Result, Count);

  for I := 0 to Count - 1 do
    Result[I] := Points[StartIndex + I];
end;

constructor TMetafileParser.Create;
begin
  inherited Create;
  FDCState := TMetafileDCState.Create;
  FPathBuilder := TMetafilePathBuilder.Create;
  FTextOutlineConverter := TMetafileTextOutlineConverter.Create;
  FCurrent := TMetafilePrimitive.Create;
  FPrimitives := TList.Create;
  FStorePrimitives := False;
  FFlatness := 0.5;
  FTextFlatness := DEFAULT_TEXT_FLATNESS;
  FOnObjectPlay := nil;
  FOnObjectPlayCallback := nil;
end;

destructor TMetafileParser.Destroy;
begin
  FOnObjectPlay := nil;
  FOnObjectPlayCallback := nil;

  ClearStoredPrimitives;
  FPrimitives.Free;
  FCurrent.Free;
  FTextOutlineConverter.Free;
  FPathBuilder.Free;
  FDCState.Free;
  inherited Destroy;
end;

procedure TMetafileParser.SynchronizeCurrentPosition(const APosition:TPoint);
begin
  DCStateOf(Self).State.NextPos:=APosition;
end;

function TMetafileParser.LoadFromMetafile(AMetafile:TMetafile;APlaybackDC:HDC;APlaybackBounds:PRect):Boolean;
var R:TRect;Playback:HENHMETAFILE;
begin
  Result:=False;FLastError:='';Reset;
  if (AMetafile=nil) or AMetafile.Empty then begin FLastError:=SMetafileEmpty;Exit;end;
  if APlaybackBounds<>nil then R:=APlaybackBounds^ else R:=Rect(0,0,AMetafile.Width,AMetafile.Height);
  { Normalize memory-loaded VCL handles before enumeration. Some GDI versions reject
    the original handle after its header, while an unmodified copy plays correctly. }
  Playback:=CopyEnhMetaFile(AMetafile.Handle,nil);
  if Playback=0 then begin FLastError:=Format(SMetafileEnumerationFailed,[0,GetLastError]);Exit;end;
  try Result:=EnumEnhMetaFile(APlaybackDC,Playback,@EnumMetafilePrimitiveProc,Self,R);
  finally DeleteEnhMetaFile(Playback);end;
  if not Result and (FLastError='') then FLastError:=Format(SMetafileEnumerationFailed,[FRecordIndex,GetLastError]);
end;

function TMetafileParser.LoadFromFile(const AFileName:string):Boolean;
var MF:TMetafile;
begin
  Result:=False;FLastError:='';Reset;
  if not FileExists(AFileName) then begin FLastError:=Format(SMetafileFileNotFound,[AFileName]);Exit;end;
  MF:=TMetafile.Create;
  try
    try MF.LoadFromFile(AFileName);Result:=LoadFromMetafile(MF);
    except on E:Exception do begin FLastError:=E.Message;Result:=False;end;end;
  finally MF.Free;end;
end;

function TMetafileParser.PrimitiveCount: Integer;
begin
  Result := FPrimitives.Count;
end;

function TMetafileParser.PrimitiveByIndex(AIndex: Integer): TMetafilePrimitive;
begin
  if (AIndex < 0) or (AIndex >= FPrimitives.Count) then
    raise EListError.CreateFmt(SMetafilePrimitiveIndex, [AIndex]);
  Result := TMetafilePrimitive(FPrimitives[AIndex]);
end;

class function TMetafileParser.Point(AX, AY: Double): TMetafilePoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

class function TMetafileParser.CubicBezierToFlatPolyline(const P0, P1, P2, P3: TMetafilePoint; ATolerance: Double): TMetafilePointArray;

  procedure Recurse(const A, B, C, D: TMetafilePoint; Depth: Integer);
  var
    AB, BC, CD, ABC, BCD, ABCD: TMetafilePoint;
    Err: Double;
  begin
    Err := Max(DistancePointToLine(B, A, D), DistancePointToLine(C, A, D));
    if (Err <= ATolerance) or (Depth >= MAX_BEZIER_RECURSION) then
    begin
      AppendPoint(Result, D);
      Exit;
    end;

    AB := MidPoint(A, B);
    BC := MidPoint(B, C);
    CD := MidPoint(C, D);
    ABC := MidPoint(AB, BC);
    BCD := MidPoint(BC, CD);
    ABCD := MidPoint(ABC, BCD);

    Recurse(A, AB, ABC, ABCD, Depth + 1);
    Recurse(ABCD, BCD, CD, D, Depth + 1);
  end;

begin
  if ATolerance <= 0 then
    ATolerance := 0.5;
  SetLength(Result, 0);
  AppendPoint(Result, P0);
  Recurse(P0, P1, P2, P3, 0);
end;

class function TMetafileParser.QuadraticBezierToFlatPolyline(const P0, P1, P2: TMetafilePoint; ATolerance: Double): TMetafilePointArray;
var
  C1, C2: TMetafilePoint;
begin
  C1.X := P0.X + (P1.X - P0.X) * 2 / 3;
  C1.Y := P0.Y + (P1.Y - P0.Y) * 2 / 3;
  C2.X := P2.X + (P1.X - P2.X) * 2 / 3;
  C2.Y := P2.Y + (P1.Y - P2.Y) * 2 / 3;
  Result := CubicBezierToFlatPolyline(P0, C1, C2, P2, ATolerance);
end;

class function TMetafileParser.BezierPointsToFlatPolyline(const ABezierPoints: TMetafilePointArray; ATolerance: Double): TMetafilePointArray;
var
  I: Integer;
  Segment: TMetafilePointArray;
begin
  SetLength(Result, 0);
  if Length(ABezierPoints) = 0 then
    Exit;
  AppendPoint(Result, ABezierPoints[0]);
  I := 1;
  while I + 2 <= High(ABezierPoints) do
  begin
    Segment := CubicBezierToFlatPolyline(Result[High(Result)], ABezierPoints[I], ABezierPoints[I + 1], ABezierPoints[I + 2], ATolerance);
    AppendPoints(Result, Segment, True);
    Inc(I, 3);
  end;
end;

procedure TMetafileParser.Reset;
begin
  ClearStoredPrimitives;
  DCStateOf(Self).Reset;
  PathBuilderOf(Self).Clear;
  FRecordIndex := 0;
end;

constructor TMetafileDCState.Create;
begin
  inherited Create;
  Reset;
end;

procedure TMetafileDCState.Reset;
begin
  ClearObjects;
  InitDefaultState;
  FHeaderBounds := Rect(0, 0, 0, 0);
  FFrameRect001MM := Rect(0, 0, 0, 0);
  FDeviceSizePx.cx := 0;
  FDeviceSizePx.cy := 0;
  FDeviceSizeMM.cx := 0;
  FDeviceSizeMM.cy := 0;
  FDeviceDpiX := 96;
  FDeviceDpiY := 96;
  FMaxObjectHandle := MAX_EMF_OBJECT_HANDLES;
end;

procedure TMetafileDCState.ApplyHeader(const AHeader: TEMRHeaderLocal);
begin
  FHeaderBounds := AHeader.rclBounds;
  FFrameRect001MM := AHeader.rclFrame;
  FDeviceSizePx := AHeader.szlDevice;
  FDeviceSizeMM := AHeader.szlMillimeters;
  if AHeader.nHandles > 0 then
    FMaxObjectHandle := Min(Cardinal(AHeader.nHandles) + 1, Cardinal(MAX_EMF_OBJECT_HANDLES))
  else
    FMaxObjectHandle := MAX_EMF_OBJECT_HANDLES;
  { The ink bounds do not describe the reference device's physical resolution. }
  if FDeviceSizeMM.cx>0 then FDeviceDpiX:=FDeviceSizePx.cx*25.4/FDeviceSizeMM.cx;
  if FDeviceSizeMM.cy>0 then FDeviceDpiY:=FDeviceSizePx.cy*25.4/FDeviceSizeMM.cy;
end;

procedure TMetafileDCState.InitDefaultState;
begin
  ClearDCStateManagedFields(State);
  FillChar(State, SizeOf(State), 0);
  State.MapMode := MM_TEXT;
  State.WindowOrg := IntPoint(0, 0);
  State.ViewportOrg := IntPoint(0, 0);
  State.WindowExt.cx := 1;
  State.WindowExt.cy := 1;
  State.ViewportExt.cx := 1;
  State.ViewportExt.cy := 1;
  State.WorldTransform := XFormIdentity;
  State.TextColor := clBlack;
  State.BkColor := clWhite;
  State.BkMode := OPAQUE;
  State.TextAlign := TA_LEFT or TA_TOP;
  State.TextOptions := 0;
  State.TextBounds := EmptyRectD;
  SetLength(State.TextDx, 0);
  SetLength(State.TextDy, 0);
  State.TextJustificationBreakExtra := 0;
  State.TextJustificationBreakCount := 0;
  State.PolyFillMode := ALTERNATE;
  State.ArcDirection := AD_COUNTERCLOCKWISE;
  State.MiterLimit := 4.0;
  State.RasterOperation2 := R2_COPYPEN;
  State.StretchMode := BLACKONWHITE;
  State.BrushOrigin := IntPoint(0, 0);
  State.Layout := 0;
  State.CurrentPos := IntPoint(0, 0);
  State.NextPos := IntPoint(0, 0);

  State.Stroke.Visible := True;
  State.Stroke.Color := clBlack;
  State.Stroke.Width := 1;
  State.Stroke.Hairline:=True;
  State.Stroke.Style := PS_SOLID;
  State.Stroke.EndCap := PS_ENDCAP_FLAT;
  State.Stroke.Join := PS_JOIN_MITER;
  State.Stroke.MiterLimit := State.MiterLimit;

  State.Fill.Visible := True;
  State.Fill.Kind := mfkSolid;
  State.Fill.Color := clWhite;
  State.Fill.Style := BS_SOLID;
  State.Fill.Hatch := 0;
  State.Fill.FillMode := State.PolyFillMode;

  State.Clip.Active := False;
  State.Clip.Bounds := EmptyRectD;
  SetLength(State.Clip.Points, 0);
  SetLength(State.Clip.PointCounts, 0);
  State.Clip.CombineMode := RGN_COPY;

  State.Font := DefaultTextLogFont;
end;

procedure TMetafileDCState.ClearObjects;
begin
  SetLength(FObjects, 0);
  SetLength(FStateStack, 0);
end;

procedure TMetafileParser.ClearStoredPrimitives;
var
  I: Integer;
begin
  if FPrimitives = nil then
    Exit;
  for I := 0 to FPrimitives.Count - 1 do
    TObject(FPrimitives[I]).Free;
  FPrimitives.Clear;
end;

procedure TMetafileParser.ClearPath;
begin
  PathBuilderOf(Self).Clear;
end;

procedure TMetafileParser.SaveState;
begin
  DCStateOf(Self).SaveState;
end;

procedure TMetafileParser.RestoreState(ARelative: Integer);
begin
  DCStateOf(Self).RestoreState(ARelative);
end;

procedure TMetafileParser.SelectObjectHandle(AHandle: Cardinal);
begin
  DCStateOf(Self).SelectObjectHandle(AHandle);
end;

procedure TMetafileParser.DeleteObjectHandle(AHandle: Cardinal);
begin
  DCStateOf(Self).DeleteObjectHandle(AHandle);
end;

{$IFDEF FPC}
function TMetafileParser.LogicalToOutput(const P:POINTL):TMetafilePoint;
begin Result:=LogicalToOutput(P.X,P.Y);end;
{$ENDIF}

function TMetafileParser.LogicalToOutput(const P: TPoint): TMetafilePoint;
begin
  Result := DCStateOf(Self).LogicalToOutput(P);
end;

function TMetafileParser.LogicalToOutput(X, Y: Double): TMetafilePoint;
begin
  Result := DCStateOf(Self).LogicalToOutput(X, Y);
end;

function TMetafileParser.CurrentStroke: TMetafileStrokeStyle;
begin
  Result := DCStateOf(Self).CurrentStroke;
end;

function TMetafileParser.CurrentFill: TMetafileFillStyle;
begin
  Result := DCStateOf(Self).CurrentFill;
end;

function TMetafileParser.CurrentTextStyle: TMetafileTextStyle;
begin
  Result := DCStateOf(Self).CurrentTextStyle;
end;

procedure TMetafileDCState.SaveState;
var
  L: Integer;
begin
  L := Length(FStateStack);
  SetLength(FStateStack, L + 1);
  FStateStack[L] := State;
end;

procedure TMetafileDCState.RestoreState(ARelative: Integer);
var
  CountToPop: Integer;
begin
  if Length(FStateStack) = 0 then
    Exit;

  if ARelative < 0 then
    CountToPop := -ARelative
  else
    CountToPop := Length(FStateStack) - ARelative + 1;

  if (ARelative=0) or (CountToPop<1) or (CountToPop>Length(FStateStack)) then Exit;
  while (CountToPop > 0) and (Length(FStateStack) > 0) do
  begin
    State := FStateStack[High(FStateStack)];
    SetLength(FStateStack, Length(FStateStack) - 1);
    Dec(CountToPop);
  end;
end;

function TMetafileParser.RecordBytesAvailable(ARecord: PEnhMetaRecord; AOffset, ASize: NativeUInt): Boolean;
begin
  Result := (ARecord <> nil) and (AOffset <= ARecord.nSize) and (ASize <= NativeUInt(ARecord.nSize) - AOffset);
end;

function TMetafileParser.RecordArrayAvailable(ARecord: PEnhMetaRecord; AOffset, ACount, AElementSize: NativeUInt): Boolean;
begin
  if AElementSize = 0 then
    Result := RecordBytesAvailable(ARecord, AOffset, 0)
  else
    Result := (ACount <= High(NativeUInt) div AElementSize) and RecordBytesAvailable(ARecord, AOffset, ACount * AElementSize);
end;

function TMetafileParser.RecordPtr(ARecord: PEnhMetaRecord; AOffset, ASize: NativeUInt; out APtr: Pointer): Boolean;
begin
  Result := RecordBytesAvailable(ARecord, AOffset, ASize);
  if Result then
    APtr := PtrOffset(ARecord, AOffset)
  else
    APtr := nil;
end;

function TMetafileParser.ReadRecordBytes(ARecord: PEnhMetaRecord; AOffset, ASize: NativeUInt; out ABytes: TMetafileByteArray): Boolean;
var
  P: Pointer;
begin
  Result := False;
  SetLength(ABytes, 0);
  if ASize = 0 then
  begin
    Result := True;
    Exit;
  end;
  if (ASize > NativeUInt(MaxInt)) or not RecordPtr(ARecord, AOffset, ASize, P) then
    Exit;
  SetLength(ABytes, ASize);
  Move(P^, ABytes[0], ASize);
  Result := True;
end;

function TMetafileParser.ReadTextAdvances(ARecord: PEnhMetaRecord; AOffDx, ANChars, AOptions: Cardinal; out ADx, ADy: TMetafileIntegerArray): Boolean;
var
  Values: PIntegerArray;
  I, Step: Integer;
  Count: NativeUInt;
begin
  Result := False;
  SetLength(ADx, 0);
  SetLength(ADy, 0);
  if (AOffDx = 0) or (ANChars = 0) then
  begin
    Result := True;
    Exit;
  end;

  Step := 1;
  if (AOptions and ETO_PDY) <> 0 then
    Step := 2;
  Count := NativeUInt(ANChars) * NativeUInt(Step);
  if not RecordArrayAvailable(ARecord, AOffDx, Count, SizeOf(Integer)) then
    Exit;

  Values := PIntegerArray(PtrOffset(ARecord, AOffDx));
  SetLength(ADx, ANChars);
  if Step = 2 then
    SetLength(ADy, ANChars);
  for I := 0 to Integer(ANChars) - 1 do
  begin
    ADx[I] := Values[I * Step];
    if Step = 2 then
      ADy[I] := Values[I * Step + 1];
  end;
  Result := True;
end;

procedure TMetafileDCState.SetObject(AHandle: Cardinal; const AObject: TMetaObject);
begin
  if (AHandle >= FMaxObjectHandle) or (AHandle >= MAX_EMF_OBJECT_HANDLES) then
    Exit;
  if AHandle >= Cardinal(Length(FObjects)) then
    SetLength(FObjects, AHandle + 1);
  FObjects[AHandle] := AObject;
end;

function TMetafileDCState.GetObject(AHandle: Cardinal; out AObject: TMetaObject): Boolean;
begin
  Result := (AHandle < Cardinal(Length(FObjects))) and FObjects[AHandle].Active;
  if Result then
    AObject := FObjects[AHandle]
  else
    FillChar(AObject, SizeOf(AObject), 0);
end;

function TMetafileDCState.SelectStockObject(AHandle: Cardinal): Boolean;
var
  Stock: Cardinal;
begin
  Result := True;
  Stock := AHandle;
  if (Stock and EMF_STOCK_OBJECT_FLAG) <> 0 then
    Stock := Stock and not EMF_STOCK_OBJECT_FLAG;

  if Stock<=HOLLOW_BRUSH then begin
    State.Fill.Brush.Kind:=mbdkNone;State.Fill.Brush.Usage:=0;
    State.Fill.Brush.BitmapInfo:=nil;State.Fill.Brush.Bits:=nil;
    State.Fill.Gradient.Kind:=mgkNone;State.Fill.Gradient.Mode:=0;
    State.Fill.Gradient.Vertices:=nil;State.Fill.Gradient.Meshes:=nil;
  end;
  case Stock of
    WHITE_BRUSH:
      begin
        State.Fill.Visible := True;
        State.Fill.Kind := mfkSolid;
        State.Fill.Color := clWhite;
        State.Fill.Style := BS_SOLID;
      end;
    LTGRAY_BRUSH:
      begin
        State.Fill.Visible := True;
        State.Fill.Kind := mfkSolid;
        State.Fill.Color := clLtGray;
        State.Fill.Style := BS_SOLID;
      end;
    GRAY_BRUSH:
      begin
        State.Fill.Visible := True;
        State.Fill.Kind := mfkSolid;
        State.Fill.Color := clGray;
        State.Fill.Style := BS_SOLID;
      end;
    DKGRAY_BRUSH:
      begin
        State.Fill.Visible := True;
        State.Fill.Kind := mfkSolid;
        State.Fill.Color := clDkGray;
        State.Fill.Style := BS_SOLID;
      end;
    BLACK_BRUSH:
      begin
        State.Fill.Visible := True;
        State.Fill.Kind := mfkSolid;
        State.Fill.Color := clBlack;
        State.Fill.Style := BS_SOLID;
      end;
    NULL_BRUSH:
      begin
        State.Fill.Visible := False;
        State.Fill.Kind := mfkNone;
        State.Fill.Style := BS_NULL;
      end;
    WHITE_PEN:
      begin
        State.Stroke.Visible := True;
        State.Stroke.Color := clWhite;
        State.Stroke.Width := 1;
        State.Stroke.Hairline:=True;
        State.Stroke.BrushStyle:=BS_SOLID;
        State.Stroke.Hatch:=0;
        State.Stroke.Brush.Kind:=mbdkNone;State.Stroke.Brush.Usage:=0;
        State.Stroke.Brush.BitmapInfo:=nil;State.Stroke.Brush.Bits:=nil;
        State.Stroke.Style := PS_SOLID;
      end;
    BLACK_PEN:
      begin
        State.Stroke.Visible := True;
        State.Stroke.Color := clBlack;
        State.Stroke.Width := 1;
        State.Stroke.Hairline:=True;
        State.Stroke.BrushStyle:=BS_SOLID;
        State.Stroke.Hatch:=0;
        State.Stroke.Brush.Kind:=mbdkNone;State.Stroke.Brush.Usage:=0;
        State.Stroke.Brush.BitmapInfo:=nil;State.Stroke.Brush.Bits:=nil;
        State.Stroke.Style := PS_SOLID;
      end;
    NULL_PEN:
      begin
        State.Stroke.Visible := False;
        State.Stroke.Width := 0;
        State.Stroke.Style := PS_NULL;
      end;
  else
    Result := False;
  end;
end;

procedure TMetafileDCState.SelectObjectHandle(AHandle: Cardinal);
var
  Obj: TMetaObject;
begin
  if GetObject(AHandle, Obj) then
  begin
    case Obj.Kind of
      mokPen:
        State.Stroke := Obj.Stroke;
      mokBrush:
        State.Fill := Obj.Fill;
      mokFont:
        State.Font := Obj.Font;
    end;
  end
  else
    SelectStockObject(AHandle);
end;

procedure TMetafileDCState.DeleteObjectHandle(AHandle: Cardinal);
begin
  if AHandle < Cardinal(Length(FObjects)) then
    FObjects[AHandle].Active := False;
end;

function TMetafileDCState.DeviceScaleX: Double;
begin
  if FDeviceSizeMM.cx > 0 then
    Result := FDeviceSizePx.cx / FDeviceSizeMM.cx
  else
    Result := FDeviceDpiX / 25.4;
end;

function TMetafileDCState.DeviceScaleY: Double;
begin
  if FDeviceSizeMM.cy > 0 then
    Result := FDeviceSizePx.cy / FDeviceSizeMM.cy
  else
    Result := FDeviceDpiY / 25.4;
end;

function TMetafileDCState.LogicalToOutput(const P: TPoint): TMetafilePoint;
begin
  Result := LogicalToOutput(P.X, P.Y);
end;

function TMetafileDCState.LogicalToOutput(X, Y: Double): TMetafilePoint;
var
  Page: TMetafilePoint;
  SX, SY: Double;
begin
  Page.X := X * State.WorldTransform.eM11 + Y * State.WorldTransform.eM21 + State.WorldTransform.eDx;
  Page.Y := X * State.WorldTransform.eM12 + Y * State.WorldTransform.eM22 + State.WorldTransform.eDy;

  case State.MapMode of
    MM_TEXT:
      begin
        Result.X := (Page.X - State.WindowOrg.X) + State.ViewportOrg.X;
        Result.Y := (Page.Y - State.WindowOrg.Y) + State.ViewportOrg.Y;
      end;
    MM_LOMETRIC:
      begin
        Result.X := (Page.X - State.WindowOrg.X) * DeviceScaleX / 10 + State.ViewportOrg.X;
        Result.Y := -(Page.Y - State.WindowOrg.Y) * DeviceScaleY / 10 + State.ViewportOrg.Y;
      end;
    MM_HIMETRIC:
      begin
        Result.X := (Page.X - State.WindowOrg.X) * DeviceScaleX / 100 + State.ViewportOrg.X;
        Result.Y := -(Page.Y - State.WindowOrg.Y) * DeviceScaleY / 100 + State.ViewportOrg.Y;
      end;
    MM_LOENGLISH:
      begin
        Result.X := (Page.X - State.WindowOrg.X) * FDeviceDpiX / 100 + State.ViewportOrg.X;
        Result.Y := -(Page.Y - State.WindowOrg.Y) * FDeviceDpiY / 100 + State.ViewportOrg.Y;
      end;
    MM_HIENGLISH:
      begin
        Result.X := (Page.X - State.WindowOrg.X) * FDeviceDpiX / 1000 + State.ViewportOrg.X;
        Result.Y := -(Page.Y - State.WindowOrg.Y) * FDeviceDpiY / 1000 + State.ViewportOrg.Y;
      end;
    MM_TWIPS:
      begin
        Result.X := (Page.X - State.WindowOrg.X) * FDeviceDpiX / 1440 + State.ViewportOrg.X;
        Result.Y := -(Page.Y - State.WindowOrg.Y) * FDeviceDpiY / 1440 + State.ViewportOrg.Y;
      end;
  else
    begin
      SX := 1;
      SY := 1;
      if State.WindowExt.cx <> 0 then
        SX := State.ViewportExt.cx / State.WindowExt.cx;
      if State.WindowExt.cy <> 0 then
        SY := State.ViewportExt.cy / State.WindowExt.cy;
      Result.X := (Page.X - State.WindowOrg.X) * SX + State.ViewportOrg.X;
      Result.Y := (Page.Y - State.WindowOrg.Y) * SY + State.ViewportOrg.Y;
    end;
  end;
end;

function TMetafileDCState.LogicalDeltaToOutput(Dx, Dy: Double): TMetafilePoint;
var
  P0, P1: TMetafilePoint;
begin
  P0 := LogicalToOutput(0, 0);
  P1 := LogicalToOutput(Dx, Dy);
  Result.X := P1.X - P0.X;
  Result.Y := P1.Y - P0.Y;
end;

function TMetafileDCState.LogicalPenWidthToOutput(AWidth: Double): Double;
var
  D: TMetafilePoint;
begin
  if AWidth <= 0 then
  begin
    Result := 0;
    Exit;
  end;
  D := LogicalDeltaToOutput(AWidth, 0);
  Result := Hypot(D.X, D.Y);
  if Result <= 0 then
    Result := AWidth;
end;

function TMetafileDCState.CurrentStroke: TMetafileStrokeStyle;
begin
  Result := CopyStrokeStyle(State.Stroke);
  Result.Width := LogicalPenWidthToOutput(Result.Width);
  Result.MiterLimit := State.MiterLimit;
  Result.RasterOperation2 := State.RasterOperation2;
  Result.BrushOrigin := State.BrushOrigin;
end;

function TMetafileDCState.CurrentFill: TMetafileFillStyle;
begin
  Result := CopyFillStyle(State.Fill);
  Result.FillMode := State.PolyFillMode;
  Result.RasterOperation2 := State.RasterOperation2;
  Result.BrushOrigin := State.BrushOrigin;
end;

function TMetafileDCState.CurrentTextStyle: TMetafileTextStyle;
begin
  Result.Color := State.TextColor;
  Result.BkColor := State.BkColor;
  Result.BkMode := State.BkMode;
  Result.Align := State.TextAlign;
  Result.Font := State.Font;
  Result.Options := State.TextOptions;
  Result.Bounds := State.TextBounds;
  Result.Dx := CopyCounts(State.TextDx);
  Result.Dy := CopyCounts(State.TextDy);
  Result.JustificationBreakExtra := State.TextJustificationBreakExtra;
  Result.JustificationBreakCount := State.TextJustificationBreakCount;
  Result.Layout := State.Layout;
end;

function TMetafileDCState.CurrentClip: TMetafileClipStyle;
begin
  Result := CopyClipStyle(State.Clip);
end;

procedure TMetafileDCState.SetTextRecordMetrics(AOptions: Cardinal; const ABounds: TMetafileRect; const ADx, ADy: TMetafileIntegerArray);
begin
  State.TextOptions := AOptions;
  State.TextBounds := ABounds;
  State.TextDx := CopyCounts(ADx);
  State.TextDy := CopyCounts(ADy);
end;

procedure TMetafileDCState.SetTextJustification(ABreakExtra, ABreakCount: Integer);
begin
  State.TextJustificationBreakExtra := ABreakExtra;
  State.TextJustificationBreakCount := ABreakCount;
end;

procedure TMetafileDCState.ClearClip;
begin
  State.Clip.Active := False;
  State.Clip.Bounds := EmptyRectD;
  SetLength(State.Clip.Points, 0);
  SetLength(State.Clip.PointCounts, 0);
  State.Clip.CombineMode := RGN_COPY;
  State.Clip.BooleanGeometryRequired := False;
  State.Clip.BooleanOperation := 0;
end;

procedure TMetafileDCState.SetClipRegion(const APoints: TMetafilePointArray; const ACounts: TMetafileIntegerArray; ACombineMode: Cardinal);
var
  Bounds: TMetafileRect;
  ExistingPoints: TMetafilePointArray;
  ExistingCounts: TMetafileIntegerArray;
  ExistingActive, ExistingBooleanRequired: Boolean;
  CombinedPoints: TMetafilePointArray;
  CombinedCounts: TMetafileIntegerArray;
begin
  if Length(APoints) = 0 then
  begin
    if ACombineMode = RGN_COPY then
      ClearClip;
    Exit;
  end;

  Bounds := BoundsOfPoints(APoints);
  ExistingPoints := State.Clip.Points;
  ExistingCounts := State.Clip.PointCounts;
  ExistingActive := State.Clip.Active;
  ExistingBooleanRequired := State.Clip.BooleanGeometryRequired;

  if (ACombineMode = RGN_COPY) or not ExistingActive then
  begin
    State.Clip.Points := CopyPoints(APoints);
    State.Clip.PointCounts := CopyCounts(ACounts);
    State.Clip.Bounds := Bounds;
    State.Clip.Active := True;
    State.Clip.CombineMode := ACombineMode;
    State.Clip.BooleanGeometryRequired := False;
    State.Clip.BooleanOperation := 0;
    Exit;
  end;

  if TMetafileClipBooleanEngine.Execute(ExistingPoints, ExistingCounts, APoints, ACounts, ACombineMode, CombinedPoints, CombinedCounts) then
  begin
    if Length(CombinedPoints) = 0 then
      ClearClip
    else
    begin
      State.Clip.Points := CopyPoints(CombinedPoints);
      State.Clip.PointCounts := CopyCounts(CombinedCounts);
      State.Clip.Bounds := BoundsOfPoints(State.Clip.Points);
      State.Clip.Active := True;
      State.Clip.CombineMode := ACombineMode;
      State.Clip.BooleanGeometryRequired := False;
      State.Clip.BooleanOperation := 0;
    end;
    Exit;
  end;

  State.Clip.Points := CopyPoints(ExistingPoints);
  State.Clip.PointCounts := CopyCounts(ExistingCounts);
  AppendPoints(State.Clip.Points, APoints, False);
  AppendCounts(State.Clip.PointCounts, ACounts);
  State.Clip.Bounds := BoundsOfPoints(State.Clip.Points);
  State.Clip.Active := True;
  State.Clip.CombineMode := ACombineMode;
  State.Clip.BooleanGeometryRequired := ExistingBooleanRequired or (ACombineMode <> RGN_COPY);
  State.Clip.BooleanOperation := ACombineMode;
end;

procedure TMetafileDCState.ApplyClipRect(const ARect: TRect; ACombineMode: Cardinal);
var
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
begin
  SetLength(Points, 5);
  Points[0] := LogicalToOutput(ARect.Left, ARect.Top);
  Points[1] := LogicalToOutput(ARect.Right, ARect.Top);
  Points[2] := LogicalToOutput(ARect.Right, ARect.Bottom);
  Points[3] := LogicalToOutput(ARect.Left, ARect.Bottom);
  Points[4] := Points[0];
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  SetClipRegion(Points, Counts, ACombineMode);
end;

procedure TMetafileDCState.OffsetClip(const ADelta: TPoint);
var
  I: Integer;
  D: TMetafilePoint;
begin
  if not State.Clip.Active then
    Exit;
  D := LogicalDeltaToOutput(ADelta.X, ADelta.Y);
  State.Clip.Points := CopyPoints(State.Clip.Points);
  for I := 0 to High(State.Clip.Points) do
  begin
    State.Clip.Points[I].X := State.Clip.Points[I].X + D.X;
    State.Clip.Points[I].Y := State.Clip.Points[I].Y + D.Y;
  end;
  State.Clip.Bounds := BoundsOfPoints(State.Clip.Points);
end;

procedure TMetafilePathBuilder.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FContours) do
    SetLength(FContours[I].Points, 0);
  SetLength(FContours, 0);
  FRecording := False;
  FReady := False;
end;

procedure TMetafilePathBuilder.BeginPath;
begin
  Clear;
  FRecording := True;
end;

procedure TMetafilePathBuilder.EndPath;
begin
  FRecording := False;
  FReady := Length(FContours) > 0;
end;

function TMetafilePathBuilder.HasData: Boolean;
begin
  Result := FReady or (Length(FContours) > 0);
end;

function TMetafilePathBuilder.Build(out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
var
  I: Integer;
begin
  SetLength(APoints, 0);
  SetLength(APointCounts, 0);
  for I := 0 to High(FContours) do
  begin
    if Length(FContours[I].Points) = 0 then
      Continue;
    AppendCount(APointCounts, Length(FContours[I].Points));
    AppendPoints(APoints, FContours[I].Points, False);
  end;
  Result := Length(APoints) > 0;
end;

procedure TMetafilePathBuilder.ReplaceWith(const APoints: TMetafilePointArray; const APointCounts: TMetafileIntegerArray);
var
  I, Offset, N: Integer;
  One: TMetafilePointArray;
begin
  Clear;
  Offset := 0;
  for I := 0 to High(APointCounts) do
  begin
    N := APointCounts[I];
    if (N <= 0) or (Offset + N > Length(APoints)) then
      Break;
    SetLength(One, N);
    Move(APoints[Offset], One[0], N * SizeOf(TMetafilePoint));
    AppendContour(One, True);
    Inc(Offset, N);
  end;
  FRecording := False;
  FReady := Length(FContours) > 0;
end;

procedure TMetafilePathBuilder.Widen(AWidth: Double);
var
  NewPoints, Outline, LeftSide, RightSide: TMetafilePointArray;
  NewCounts: TMetafileIntegerArray;
  I, Count: Integer;
  HalfWidth: Double;

  function NormalForSegment(const A, B: TMetafilePoint): TMetafilePoint;
  var
    Dx, Dy, L: Double;
  begin
    Dx := B.X - A.X;
    Dy := B.Y - A.Y;
    L := Hypot(Dx, Dy);
    if L <= 1E-12 then
      Result := TMetafileParser.Point(0, 0)
    else
      Result := TMetafileParser.Point(-Dy / L, Dx / L);
  end;

  function VertexNormal(const APoints: TMetafilePointArray; AIndex: Integer; AClosed: Boolean): TMetafilePoint;
  var
    PrevIndex, NextIndex: Integer;
    N1, N2: TMetafilePoint;
    L: Double;
  begin
    if AIndex = 0 then
    begin
      if AClosed then
        PrevIndex := High(APoints) - Ord(PointsAlmostEqual(APoints[0], APoints[High(APoints)]))
      else
        PrevIndex := 0;
    end
    else
      PrevIndex := AIndex - 1;

    if AIndex = High(APoints) then
    begin
      if AClosed then
        NextIndex := 1
      else
        NextIndex := High(APoints);
    end
    else
      NextIndex := AIndex + 1;

    if PrevIndex = AIndex then
      Result := NormalForSegment(APoints[AIndex], APoints[NextIndex])
    else if NextIndex = AIndex then
      Result := NormalForSegment(APoints[PrevIndex], APoints[AIndex])
    else
    begin
      N1 := NormalForSegment(APoints[PrevIndex], APoints[AIndex]);
      N2 := NormalForSegment(APoints[AIndex], APoints[NextIndex]);
      Result.X := N1.X + N2.X;
      Result.Y := N1.Y + N2.Y;
      L := Hypot(Result.X, Result.Y);
      if L <= 1E-12 then
        Result := N2
      else
      begin
        Result.X := Result.X / L;
        Result.Y := Result.Y / L;
      end;
    end;
  end;

  function ContourOutline(const APoints: TMetafilePointArray; AClosed: Boolean): TMetafilePointArray;
  var
    K, LastIndex: Integer;
    N: TMetafilePoint;
    Closed: Boolean;
  begin
    SetLength(Result, 0);
    if Length(APoints) < 2 then
      Exit;
    Closed := AClosed or PointsAlmostEqual(APoints[0], APoints[High(APoints)]);
    LastIndex := High(APoints);
    if Closed and PointsAlmostEqual(APoints[0], APoints[LastIndex]) then
      Dec(LastIndex);
    if LastIndex < 1 then
      Exit;

    SetLength(LeftSide, LastIndex + 1);
    SetLength(RightSide, LastIndex + 1);
    for K := 0 to LastIndex do
    begin
      N := VertexNormal(APoints, K, Closed);
      LeftSide[K] := TMetafileParser.Point(APoints[K].X + N.X * HalfWidth, APoints[K].Y + N.Y * HalfWidth);
      RightSide[K] := TMetafileParser.Point(APoints[K].X - N.X * HalfWidth, APoints[K].Y - N.Y * HalfWidth);
    end;

    for K := 0 to High(LeftSide) do
      AppendPoint(Result, LeftSide[K]);
    for K := High(RightSide) downto 0 do
      AppendPoint(Result, RightSide[K]);
    if (Length(Result) > 1) and not PointsAlmostEqual(Result[0], Result[High(Result)]) then
      AppendPoint(Result, Result[0]);
  end;

begin
  if AWidth <= 0 then
    AWidth := 1;
  HalfWidth := AWidth * 0.5;
  SetLength(NewPoints, 0);
  SetLength(NewCounts, 0);
  for I := 0 to High(FContours) do
  begin
    Outline := ContourOutline(FContours[I].Points, FContours[I].Closed);
    Count := Length(Outline);
    if Count = 0 then
      Continue;
    AppendPoints(NewPoints, Outline, False);
    AppendCount(NewCounts, Count);
  end;
  ReplaceWith(NewPoints, NewCounts);
end;

procedure TMetafilePathBuilder.AppendContour(const APoints: TMetafilePointArray; AClosed: Boolean);
var
  L: Integer;
begin
  if Length(APoints) = 0 then
    Exit;
  L := Length(FContours);
  SetLength(FContours, L + 1);
  FContours[L].Points := CopyPoints(APoints);
  FContours[L].Closed := AClosed;
end;

procedure TMetafilePathBuilder.AppendOpenPolyline(const APoints: TMetafilePointArray);
var
  L: Integer;
  SkipFirst: Boolean;
begin
  if Length(APoints) = 0 then
    Exit;
  L := Length(FContours);
  if L = 0 then
  begin
    AppendContour(APoints, False);
    Exit;
  end;

  SkipFirst := (Length(FContours[L - 1].Points) > 0) and PointsAlmostEqual(FContours[L - 1].Points[High(FContours[L - 1].Points)], APoints[0]);
  AppendPoints(FContours[L - 1].Points, APoints, SkipFirst);
end;

procedure TMetafilePathBuilder.CloseFigure;
var
  L: Integer;
begin
  L := Length(FContours);
  if L = 0 then
    Exit;
  FContours[L - 1].Closed := True;
  if (Length(FContours[L - 1].Points) > 1) and not PointsAlmostEqual(FContours[L - 1].Points[0], FContours[L - 1].Points[High(FContours[L - 1].Points)]) then
    AppendPoint(FContours[L - 1].Points, FContours[L - 1].Points[0]);
end;

function RegionDataToPolygons(AData: Pointer; ASize: NativeUInt; ADCState: TMetafileDCState; out APoints: TMetafilePointArray; out ACounts: TMetafileIntegerArray): Boolean;
var
  Header: PRgnDataHeader;
  Rects: PRectArray;
  I: Integer;
  R: TRect;
  One: TMetafilePointArray;
begin
  Result := False;
  SetLength(APoints, 0);
  SetLength(ACounts, 0);
  if (AData = nil) or (ADCState = nil) or (ASize < SizeOf(TRgnDataHeader)) then
    Exit;

  Header := PRgnDataHeader(AData);
  if (Header.dwSize <> SizeOf(TRgnDataHeader)) or (Header.iType <> RDH_RECTANGLES) then
    Exit;
  if ASize < SizeOf(TRgnDataHeader) + NativeUInt(Header.nCount) * SizeOf(TRect) then
    Exit;

  Rects := PRectArray(PtrOffset(AData, SizeOf(TRgnDataHeader)));
  for I := 0 to Integer(Header.nCount) - 1 do
  begin
    R := Rects[I];
    SetLength(One, 5);
    One[0] := ADCState.LogicalToOutput(R.Left, R.Top);
    One[1] := ADCState.LogicalToOutput(R.Right, R.Top);
    One[2] := ADCState.LogicalToOutput(R.Right, R.Bottom);
    One[3] := ADCState.LogicalToOutput(R.Left, R.Bottom);
    One[4] := One[0];
    AppendPoints(APoints, One, False);
    AppendCount(ACounts, Length(One));
  end;
  Result := Length(APoints) > 0;
end;

function TMetafileParser.RecordName(AType: Cardinal): string;
begin
  case AType of
    EMR_POLYBEZIER:
      Result := 'EMR_POLYBEZIER';
    EMR_POLYGON:
      Result := 'EMR_POLYGON';
    EMR_POLYLINE:
      Result := 'EMR_POLYLINE';
    EMR_POLYBEZIERTO:
      Result := 'EMR_POLYBEZIERTO';
    EMR_POLYLINETO:
      Result := 'EMR_POLYLINETO';
    EMR_POLYPOLYLINE:
      Result := 'EMR_POLYPOLYLINE';
    EMR_POLYPOLYGON:
      Result := 'EMR_POLYPOLYGON';
    EMR_SETWINDOWEXTEX:
      Result := 'EMR_SETWINDOWEXTEX';
    EMR_SETWINDOWORGEX:
      Result := 'EMR_SETWINDOWORGEX';
    EMR_SETVIEWPORTEXTEX:
      Result := 'EMR_SETVIEWPORTEXTEX';
    EMR_SETVIEWPORTORGEX:
      Result := 'EMR_SETVIEWPORTORGEX';
    EMR_SETMAPMODE:
      Result := 'EMR_SETMAPMODE';
    EMR_SETMAPPERFLAGS:
      Result := 'EMR_SETMAPPERFLAGS';
    EMR_SETBKMODE:
      Result := 'EMR_SETBKMODE';
    EMR_SETPOLYFILLMODE:
      Result := 'EMR_SETPOLYFILLMODE';
    EMR_SETROP2:
      Result := 'EMR_SETROP2';
    EMR_SETSTRETCHBLTMODE:
      Result := 'EMR_SETSTRETCHBLTMODE';
    EMR_SETBRUSHORGEX:
      Result := 'EMR_SETBRUSHORGEX';
    EMR_SETLAYOUT_LOCAL:
      Result := 'EMR_SETLAYOUT';
    EMR_SETTEXTALIGN:
      Result := 'EMR_SETTEXTALIGN';
    EMR_SETTEXTJUSTIFICATION:
      Result := 'EMR_SETTEXTJUSTIFICATION';
    EMR_SETTEXTCOLOR:
      Result := 'EMR_SETTEXTCOLOR';
    EMR_SETBKCOLOR:
      Result := 'EMR_SETBKCOLOR';
    EMR_MOVETOEX:
      Result := 'EMR_MOVETOEX';
    EMR_SETWORLDTRANSFORM:
      Result := 'EMR_SETWORLDTRANSFORM';
    EMR_MODIFYWORLDTRANSFORM:
      Result := 'EMR_MODIFYWORLDTRANSFORM';
    EMR_SELECTOBJECT:
      Result := 'EMR_SELECTOBJECT';
    EMR_CREATEPEN:
      Result := 'EMR_CREATEPEN';
    EMR_CREATEBRUSHINDIRECT:
      Result := 'EMR_CREATEBRUSHINDIRECT';
    EMR_CREATEMONOBRUSH:
      Result := 'EMR_CREATEMONOBRUSH';
    EMR_CREATEDIBPATTERNBRUSHPT:
      Result := 'EMR_CREATEDIBPATTERNBRUSHPT';
    EMR_DELETEOBJECT:
      Result := 'EMR_DELETEOBJECT';
    EMR_EOF:
      Result := 'EMR_EOF';
    EMR_ANGLEARC:
      Result := 'EMR_ANGLEARC';
    EMR_ELLIPSE:
      Result := 'EMR_ELLIPSE';
    EMR_RECTANGLE:
      Result := 'EMR_RECTANGLE';
    EMR_ROUNDRECT:
      Result := 'EMR_ROUNDRECT';
    EMR_ARC:
      Result := 'EMR_ARC';
    EMR_CHORD:
      Result := 'EMR_CHORD';
    EMR_PIE:
      Result := 'EMR_PIE';
    EMR_LINETO:
      Result := 'EMR_LINETO';
    EMR_ARCTO:
      Result := 'EMR_ARCTO';
    EMR_POLYDRAW:
      Result := 'EMR_POLYDRAW';
    EMR_SETARCDIRECTION:
      Result := 'EMR_SETARCDIRECTION';
    EMR_SETMITERLIMIT:
      Result := 'EMR_SETMITERLIMIT';
    EMR_BEGINPATH:
      Result := 'EMR_BEGINPATH';
    EMR_ENDPATH:
      Result := 'EMR_ENDPATH';
    EMR_CLOSEFIGURE:
      Result := 'EMR_CLOSEFIGURE';
    EMR_FILLPATH:
      Result := 'EMR_FILLPATH';
    EMR_STROKEANDFILLPATH:
      Result := 'EMR_STROKEANDFILLPATH';
    EMR_STROKEPATH:
      Result := 'EMR_STROKEPATH';
    EMR_FLATTENPATH:
      Result := 'EMR_FLATTENPATH';
    EMR_WIDENPATH:
      Result := 'EMR_WIDENPATH';
    EMR_ABORTPATH:
      Result := 'EMR_ABORTPATH';
    EMR_EXTSELECTCLIPRGN:
      Result := 'EMR_EXTSELECTCLIPRGN';
    EMR_SELECTCLIPPATH:
      Result := 'EMR_SELECTCLIPPATH';
    EMR_INTERSECTCLIPRECT:
      Result := 'EMR_INTERSECTCLIPRECT';
    EMR_EXCLUDECLIPRECT:
      Result := 'EMR_EXCLUDECLIPRECT';
    EMR_OFFSETCLIPRGN:
      Result := 'EMR_OFFSETCLIPRGN';
    EMR_FILLRGN:
      Result := 'EMR_FILLRGN';
    EMR_FRAMERGN:
      Result := 'EMR_FRAMERGN';
    EMR_INVERTRGN:
      Result := 'EMR_INVERTRGN';
    EMR_PAINTRGN:
      Result := 'EMR_PAINTRGN';
    EMR_SETMETARGN:
      Result := 'EMR_SETMETARGN';
    EMR_EXTCREATEFONTINDIRECTW:
      Result := 'EMR_EXTCREATEFONTINDIRECTW';
    EMR_EXTTEXTOUTA:
      Result := 'EMR_EXTTEXTOUTA';
    EMR_EXTTEXTOUTW:
      Result := 'EMR_EXTTEXTOUTW';
    EMR_SMALLTEXTOUT:
      Result := 'EMR_SMALLTEXTOUT';
    EMR_POLYBEZIER16:
      Result := 'EMR_POLYBEZIER16';
    EMR_POLYGON16:
      Result := 'EMR_POLYGON16';
    EMR_POLYLINE16:
      Result := 'EMR_POLYLINE16';
    EMR_POLYBEZIERTO16:
      Result := 'EMR_POLYBEZIERTO16';
    EMR_POLYLINETO16:
      Result := 'EMR_POLYLINETO16';
    EMR_POLYPOLYLINE16:
      Result := 'EMR_POLYPOLYLINE16';
    EMR_POLYPOLYGON16:
      Result := 'EMR_POLYPOLYGON16';
    EMR_POLYDRAW16:
      Result := 'EMR_POLYDRAW16';
    EMR_EXTCREATEPEN:
      Result := 'EMR_EXTCREATEPEN';
    EMR_BITBLT:
      Result := 'EMR_BITBLT';
    EMR_STRETCHBLT:
      Result := 'EMR_STRETCHBLT';
    EMR_MASKBLT:
      Result := 'EMR_MASKBLT';
    EMR_SETDIBITSTODEVICE:
      Result := 'EMR_SETDIBITSTODEVICE';
    EMR_STRETCHDIBITS:
      Result := 'EMR_STRETCHDIBITS';
    EMR_PLGBLT:
      Result := 'EMR_PLGBLT';
    EMR_ALPHABLEND:
      Result := 'EMR_ALPHABLEND';
    EMR_TRANSPARENTBLT:
      Result := 'EMR_TRANSPARENTBLT';
    EMR_GRADIENTFILL:
      Result := 'EMR_GRADIENTFILL';
    EMR_SETPIXELV:
      Result := 'EMR_SETPIXELV';
    EMR_EXTFLOODFILL:
      Result := 'EMR_EXTFLOODFILL';
    EMR_SELECTPALETTE:
      Result := 'EMR_SELECTPALETTE';
    EMR_CREATEPALETTE:
      Result := 'EMR_CREATEPALETTE';
    EMR_SETPALETTEENTRIES:
      Result := 'EMR_SETPALETTEENTRIES';
    EMR_RESIZEPALETTE:
      Result := 'EMR_RESIZEPALETTE';
    EMR_REALIZEPALETTE:
      Result := 'EMR_REALIZEPALETTE';
    EMR_GDICOMMENT:
      Result := 'EMR_GDICOMMENT';
    EMR_SAVEDC:
      Result := 'EMR_SAVEDC';
    EMR_RESTOREDC:
      Result := 'EMR_RESTOREDC';
    EMR_SCALEWINDOWEXTEX:
      Result := 'EMR_SCALEWINDOWEXTEX';
    EMR_SCALEVIEWPORTEXTEX:
      Result := 'EMR_SCALEVIEWPORTEXTEX';
    EMR_POLYTEXTOUTA:
      Result := 'EMR_POLYTEXTOUTA';
    EMR_POLYTEXTOUTW:
      Result := 'EMR_POLYTEXTOUTW';
  else
    Result := 'EMR_' + IntToStr(AType);
  end;
end;

procedure TMetafileParser.EmitPrimitive(AKind: TMetafilePrimitiveKind; const APoints: TMetafilePointArray; const APointCounts: TMetafileIntegerArray; const AText: UnicodeString;
  ARecordType: Cardinal; const ARecordName: string; AUseStroke, AUseFill: Boolean);
var
  Stroke: TMetafileStrokeStyle;
  Fill: TMetafileFillStyle;
  EmitKind: TMetafilePrimitiveKind;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;

  function SamePoint(const A, B: TMetafilePoint): Boolean;
  const
    EPS = 1E-9;
  begin
    Result := (Abs(A.X - B.X) <= EPS) and (Abs(A.Y - B.Y) <= EPS);
  end;

  procedure CloseContours(var AClosePoints: TMetafilePointArray; var ACloseCounts: TMetafileIntegerArray);
  var
    Source: TMetafilePointArray;
    Sub, I, StartIndex, Count, ExtraCount, OutIndex: Integer;
    NeedsClose: Boolean;
  begin
    ExtraCount := 0;
    StartIndex := 0;
    for Sub := 0 to High(ACloseCounts) do
    begin
      Count := ACloseCounts[Sub];
      NeedsClose := (Count > 1) and (StartIndex + Count <= Length(AClosePoints)) and
        not SamePoint(AClosePoints[StartIndex], AClosePoints[StartIndex + Count - 1]);
      if NeedsClose then
        Inc(ExtraCount);
      Inc(StartIndex, Count);
    end;

    if ExtraCount = 0 then
      Exit;

    Source := AClosePoints;
    SetLength(AClosePoints, Length(Source) + ExtraCount);
    OutIndex := 0;
    StartIndex := 0;
    for Sub := 0 to High(ACloseCounts) do
    begin
      Count := ACloseCounts[Sub];
      for I := 0 to Count - 1 do
      begin
        if StartIndex + I >= Length(Source) then
          Break;
        AClosePoints[OutIndex] := Source[StartIndex + I];
        Inc(OutIndex);
      end;
      if (Count > 1) and (StartIndex + Count <= Length(Source)) and
        not SamePoint(Source[StartIndex], Source[StartIndex + Count - 1]) then
      begin
        AClosePoints[OutIndex] := Source[StartIndex];
        Inc(OutIndex);
        Inc(ACloseCounts[Sub]);
      end;
      Inc(StartIndex, Count);
    end;
    SetLength(AClosePoints, OutIndex);
  end;
begin
  Stroke := CurrentStroke;
  Stroke.Visible := Stroke.Visible and AUseStroke;
  Fill := CurrentFill;
  Fill.Visible := Fill.Visible and AUseFill;
  EmitKind := AKind;
  Points := CopyPoints(APoints);
  Counts := CopyCounts(APointCounts);

  if EmitKind = mpkPolygon then
  begin
    if not Fill.Visible then
    begin
      if not Stroke.Visible then
        Exit;
      EmitKind := mpkPolyline;
      CloseContours(Points, Counts);
    end;
  end
  else if (EmitKind = mpkPolyline) and not Stroke.Visible then
    Exit;

  FCurrent.Kind := EmitKind;
  FCurrent.Points := Points;
  FCurrent.PointCounts := Counts;
  FCurrent.Text := AText;
  FCurrent.Bounds := BuildBounds(Points);
  FCurrent.Stroke := CopyStrokeStyle(Stroke);
  FCurrent.Fill := CopyFillStyle(Fill);
  FCurrent.TextStyle := CurrentTextStyle;
  FCurrent.Clip := CopyClipStyle(DCStateOf(Self).CurrentClip);
  ClearImageStyle(FCurrent.Image);
  FCurrent.SourceRecordType := ARecordType;
  FCurrent.SourceRecordIndex := FRecordIndex;
  FCurrent.SourceRecordName := ARecordName;

  AddPrimitiveToStore;

  if Assigned(FOnObjectPlayCallback) then
    FOnObjectPlayCallback(Self);

  if Assigned(FOnObjectPlay) then
    FOnObjectPlay(Self);
end;

procedure TMetafileParser.EmitImagePrimitive(const APoints: TMetafilePointArray; const APointCounts: TMetafileIntegerArray; const AImage: TMetafileImageStyle; ARecordType: Cardinal; const ARecordName: string);
begin
  FCurrent.Kind := mpkImage;
  FCurrent.Points := CopyPoints(APoints);
  FCurrent.PointCounts := CopyCounts(APointCounts);
  FCurrent.Text := '';
  FCurrent.Bounds := BuildBounds(APoints);
  if (Length(APoints) = 0) and (AImage.Bounds.Right >= AImage.Bounds.Left) and (AImage.Bounds.Bottom >= AImage.Bounds.Top) then
    FCurrent.Bounds := AImage.Bounds;

  FCurrent.Stroke := CopyStrokeStyle(CurrentStroke);
  FCurrent.Stroke.Visible := False;
  FCurrent.Fill := CopyFillStyle(CurrentFill);
  FCurrent.Fill.Visible := False;
  FCurrent.TextStyle := CurrentTextStyle;
  FCurrent.Clip := CopyClipStyle(DCStateOf(Self).CurrentClip);
  FCurrent.Image := CopyImageStyle(AImage);
  FCurrent.SourceRecordType := ARecordType;
  FCurrent.SourceRecordIndex := FRecordIndex;
  FCurrent.SourceRecordName := ARecordName;

  AddPrimitiveToStore;

  if Assigned(FOnObjectPlayCallback) then
    FOnObjectPlayCallback(Self);

  if Assigned(FOnObjectPlay) then
    FOnObjectPlay(Self);
end;

procedure TMetafileParser.EmitPath(ARecordType: Cardinal; const ARecordName: string; AUseStroke, AUseFill: Boolean);
var
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
begin
  if PathBuilderOf(Self).Build(Points, Counts) then
  begin
    if AUseFill then
      EmitPrimitive(mpkPolygon, Points, Counts, '', ARecordType, ARecordName, AUseStroke, True)
    else
      EmitPrimitive(mpkPolyline, Points, Counts, '', ARecordType, ARecordName, AUseStroke, False);
  end;
  ClearPath;
end;

procedure TMetafileParser.AppendPathContour(const APoints: TMetafilePointArray; AClosed: Boolean);
begin
  PathBuilderOf(Self).AppendContour(APoints, AClosed);
end;

procedure TMetafileParser.AppendPathOpenPolyline(const APoints: TMetafilePointArray);
begin
  PathBuilderOf(Self).AppendOpenPolyline(APoints);
end;

procedure TMetafileParser.PathCloseFigure;
begin
  PathBuilderOf(Self).CloseFigure;
end;

procedure TMetafileParser.AddPrimitiveToStore;
begin
  if FStorePrimitives then
    FPrimitives.Add(FCurrent.Clone);
end;

function TMetafileParser.BuildBounds(const APoints: TMetafilePointArray): TMetafileRect;
begin
  Result := BoundsOfPoints(APoints);
end;

procedure TMetafileParser.HandlePolyline32(ARecord: PEnhMetaRecord; AClosed: Boolean);
var
  R: PEMRPolyline;
  I: Integer;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  PointsOffset: NativeUInt;
begin
  R := PEMRPolyline(ARecord);
  if (R.cptl = 0) or (R.cptl > Cardinal(MaxInt)) then
    Exit;
  PointsOffset := NativeUInt(@R.aptl[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cptl, SizeOf(TPoint)) then
    Exit;

  SetLength(Points, Integer(R.cptl));
  for I := 0 to Integer(R.cptl) - 1 do
    Points[I] := LogicalToOutput(R.aptl[I]);
  if AClosed and (Length(Points) > 1) and not PointsAlmostEqual(Points[0], Points[High(Points)]) then
    AppendPoint(Points, Points[0]);
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathContour(Points, AClosed)
  else if AClosed then
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
end;

procedure TMetafileParser.HandlePolyline16(ARecord: PEnhMetaRecord; AClosed: Boolean);
var
  R: PEMRPolyline16;
  I: Integer;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  PointsOffset: NativeUInt;
begin
  R := PEMRPolyline16(ARecord);
  if (R.cpts = 0) or (R.cpts > Cardinal(MaxInt)) then
    Exit;
  PointsOffset := NativeUInt(@R.apts[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cpts, SizeOf(TSmallPoint)) then
    Exit;

  SetLength(Points, Integer(R.cpts));
  for I := 0 to Integer(R.cpts) - 1 do
    Points[I] := LogicalToOutput(R.apts[I].X, R.apts[I].Y);
  if AClosed and (Length(Points) > 1) and not PointsAlmostEqual(Points[0], Points[High(Points)]) then
    AppendPoint(Points, Points[0]);
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathContour(Points, AClosed)
  else if AClosed then
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
end;

procedure TMetafileParser.HandlePolyPolyline32(ARecord: PEnhMetaRecord; AClosed: Boolean);
var
  R: PEMRPolyPolyline;
  CountsPtr: PIntegerArray;
  Pts: PPointArray;
  Points, One: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  Poly, Pt, Total, InputTotal, OutputTotal, N: Integer;
  CountsOffset, PointsOffset, TotalNative: NativeUInt;
begin
  R := PEMRPolyPolyline(ARecord);
  if (R.nPolys = 0) or (R.nPolys > Cardinal(MaxInt div SizeOf(Integer))) then
    Exit;
  CountsOffset := NativeUInt(@R.aPolyCounts[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, CountsOffset, R.nPolys, SizeOf(DWORD)) then
    Exit;

  CountsPtr := PIntegerArray(@R.aPolyCounts[0]);
  PointsOffset := CountsOffset + NativeUInt(R.nPolys) * SizeOf(DWORD);
  Total := 0;
  TotalNative := 0;
  SetLength(Counts, Integer(R.nPolys));
  for Poly := 0 to Integer(R.nPolys) - 1 do
  begin
    N := CountsPtr[Poly];
    if N < 0 then
      Exit;
    Counts[Poly] := N;
    Inc(TotalNative, NativeUInt(N));
    if TotalNative > NativeUInt(MaxInt) then
      Exit;
    Inc(Total, N);
  end;
  if not RecordArrayAvailable(ARecord, PointsOffset, TotalNative, SizeOf(TPoint)) then
    Exit;
  Pts := PPointArray(PtrOffset(ARecord, PointsOffset));
  SetLength(Points, Total + Ord(AClosed) * Integer(R.nPolys));
  InputTotal := 0;
  OutputTotal := 0;
  for Poly := 0 to Integer(R.nPolys) - 1 do
  begin
    N := CountsPtr[Poly];
    SetLength(One, N);
    for Pt := 0 to N - 1 do
      One[Pt] := LogicalToOutput(Pts[InputTotal + Pt]);
    Inc(InputTotal, N);
    if AClosed and (Length(One) > 1) and not PointsAlmostEqual(One[0], One[High(One)]) then
      AppendPoint(One, One[0]);
    Counts[Poly] := Length(One);
    for Pt := 0 to High(One) do
      Points[OutputTotal + Pt] := One[Pt];
    Inc(OutputTotal, Length(One));
    if PathBuilderOf(Self).Recording then
      AppendPathContour(One, AClosed);
  end;
  SetLength(Points, OutputTotal);
  if not PathBuilderOf(Self).Recording then
  begin
    if AClosed then
      EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True)
    else
      EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
  end;
end;

procedure TMetafileParser.HandlePolyPolyline16(ARecord: PEnhMetaRecord; AClosed: Boolean);
var
  R: PEMRPolyPolyline16;
  CountsPtr: PIntegerArray;
  Pts: PSmallPointArray;
  Points, One: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  Poly, Pt, Total, InputTotal, OutputTotal, N: Integer;
  CountsOffset, PointsOffset, TotalNative: NativeUInt;
begin
  R := PEMRPolyPolyline16(ARecord);
  if (R.nPolys = 0) or (R.nPolys > Cardinal(MaxInt div SizeOf(Integer))) then
    Exit;
  CountsOffset := NativeUInt(@R.aPolyCounts[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, CountsOffset, R.nPolys, SizeOf(DWORD)) then
    Exit;

  CountsPtr := PIntegerArray(@R.aPolyCounts[0]);
  PointsOffset := CountsOffset + NativeUInt(R.nPolys) * SizeOf(DWORD);
  Total := 0;
  TotalNative := 0;
  SetLength(Counts, Integer(R.nPolys));
  for Poly := 0 to Integer(R.nPolys) - 1 do
  begin
    N := CountsPtr[Poly];
    if N < 0 then
      Exit;
    Counts[Poly] := N;
    Inc(TotalNative, NativeUInt(N));
    if TotalNative > NativeUInt(MaxInt) then
      Exit;
    Inc(Total, N);
  end;
  if not RecordArrayAvailable(ARecord, PointsOffset, TotalNative, SizeOf(TSmallPoint)) then
    Exit;
  Pts := PSmallPointArray(PtrOffset(ARecord, PointsOffset));
  SetLength(Points, Total + Ord(AClosed) * Integer(R.nPolys));
  InputTotal := 0;
  OutputTotal := 0;
  for Poly := 0 to Integer(R.nPolys) - 1 do
  begin
    N := CountsPtr[Poly];
    SetLength(One, N);
    for Pt := 0 to N - 1 do
      One[Pt] := LogicalToOutput(Pts[InputTotal + Pt].X, Pts[InputTotal + Pt].Y);
    Inc(InputTotal, N);
    if AClosed and (Length(One) > 1) and not PointsAlmostEqual(One[0], One[High(One)]) then
      AppendPoint(One, One[0]);
    Counts[Poly] := Length(One);
    for Pt := 0 to High(One) do
      Points[OutputTotal + Pt] := One[Pt];
    Inc(OutputTotal, Length(One));
    if PathBuilderOf(Self).Recording then
      AppendPathContour(One, AClosed);
  end;
  SetLength(Points, OutputTotal);
  if not PathBuilderOf(Self).Recording then
  begin
    if AClosed then
      EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True)
    else
      EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
  end;
end;

procedure TMetafileParser.HandlePolyBezier32(ARecord: PEnhMetaRecord; ABezierTo: Boolean);
var
  R: PEMRPolyline;
  BezierPoints, Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  I, Offset, Cpt: Integer;
  PointsOffset: NativeUInt;
  SrcPt: PPoint;
begin
  R := PEMRPolyline(ARecord);
  if (R.cptl = 0) or (R.cptl > Cardinal(MaxInt)) then
    Exit;

  PointsOffset := NativeUInt(@R.aptl[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cptl, SizeOf(TPoint)) then
    Exit;

  Offset := 0;
  Cpt := Integer(R.cptl);
  if ABezierTo then
  begin
    SetLength(BezierPoints, Cpt  + 1);
    BezierPoints[0] := LogicalToOutput(DCStateOf(Self).State.CurrentPos);
    Offset := 1;
  end
  else
    SetLength(BezierPoints, Cpt);

  SrcPt := @R.aptl[0];
  for I := 0 to Cpt - 1 do
  begin
    BezierPoints[I + Offset] := LogicalToOutput(SrcPt^);
    Inc(SrcPt);
  end;

  Points := BezierPointsToFlatPolyline(BezierPoints, FFlatness);

  SetLength(Counts, 1);
  Counts[0] := Length(Points);

  if PathBuilderOf(Self).Recording then
    AppendPathOpenPolyline(Points)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);

  if ABezierTo and (Cpt > 0) then
  begin
    SrcPt := @R.aptl[0];
    Inc(SrcPt, Cpt - 1);
    DCStateOf(Self).State.NextPos := IntPoint(SrcPt^.X,SrcPt^.Y);
  end;
end;

procedure TMetafileParser.HandlePolyBezier16(ARecord: PEnhMetaRecord; ABezierTo: Boolean);
var
  R: PEMRPolyline16;
  BezierPoints, Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  I, Offset, Cpt: Integer;
  PointsOffset: NativeUInt;
  SrcPt: PSmallPoint;
begin
  R := PEMRPolyline16(ARecord);
  if (R.cpts = 0) or (R.cpts > Cardinal(MaxInt)) then
    Exit;
  PointsOffset := NativeUInt(@R.apts[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cpts, SizeOf(TSmallPoint)) then
    Exit;

  Offset := 0;
  Cpt := Integer(R.cpts);
  if ABezierTo then
  begin
    SetLength(BezierPoints, Cpt + 1);
    BezierPoints[0] := LogicalToOutput(DCStateOf(Self).State.CurrentPos);
    Offset := 1;
  end
  else
    SetLength(BezierPoints, Cpt);


  SrcPt := @R.apts[0];
  for I := 0 to Cpt - 1 do
  begin
    BezierPoints[I + Offset] := LogicalToOutput(SrcPt^.X,SrcPt^.Y);
    Inc(SrcPt);
  end;

  Points := BezierPointsToFlatPolyline(BezierPoints, FFlatness);
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathOpenPolyline(Points)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);


  if ABezierTo and (Cpt > 0) then
  begin
    SrcPt := @R.apts[0];
    Inc(SrcPt, Cpt - 1);
    DCStateOf(Self).State.NextPos := IntPoint(SrcPt^.X,SrcPt^.Y);
  end;
end;

procedure TMetafileParser.HandlePolylineTo32(ARecord: PEnhMetaRecord);
var
  R: PEMRPolyline;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  I: Integer;
  PointsOffset: NativeUInt;
begin
  R := PEMRPolyline(ARecord);
  if (R.cptl = 0) or (R.cptl > Cardinal(MaxInt - 1)) then
    Exit;
  PointsOffset := NativeUInt(@R.aptl[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cptl, SizeOf(TPoint)) then
    Exit;

  SetLength(Points, Integer(R.cptl) + 1);
  Points[0] := LogicalToOutput(DCStateOf(Self).State.CurrentPos);
  for I := 0 to Integer(R.cptl) - 1 do
    Points[I + 1] := LogicalToOutput(R.aptl[I]);
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathOpenPolyline(Points)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
  if R.cptl > 0 then
    DCStateOf(Self).State.NextPos := IntPoint(R.aptl[R.cptl - 1].X,R.aptl[R.cptl - 1].Y);
end;

procedure TMetafileParser.HandlePolylineTo16(ARecord: PEnhMetaRecord);
var
  R: PEMRPolyline16;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  I: Integer;
  PointsOffset: NativeUInt;
begin
  R := PEMRPolyline16(ARecord);
  if (R.cpts = 0) or (R.cpts > Cardinal(MaxInt - 1)) then
    Exit;
  PointsOffset := NativeUInt(@R.apts[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cpts, SizeOf(TSmallPoint)) then
    Exit;

  SetLength(Points, Integer(R.cpts) + 1);
  Points[0] := LogicalToOutput(DCStateOf(Self).State.CurrentPos);
  for I := 0 to Integer(R.cpts) - 1 do
    Points[I + 1] := LogicalToOutput(R.apts[I].X, R.apts[I].Y);
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathOpenPolyline(Points)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
  if R.cpts > 0 then
    DCStateOf(Self).State.NextPos := IntPoint(R.apts[R.cpts - 1].X, R.apts[R.cpts - 1].Y);
end;

procedure TMetafileParser.HandlePolyDraw32(ARecord: PEnhMetaRecord);
var
  R: PEMRPolyDraw;
  Types: PByte;
  I, BezierLeft: Integer;
  Current, Segment, Flat: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  PointsOffset, TypesOffset: NativeUInt;

  procedure FlushCurrent(AClosed: Boolean);
  begin
    if Length(Current) = 0 then
      Exit;
    if AClosed and (Length(Current) > 1) and not PointsAlmostEqual(Current[0], Current[High(Current)]) then
      AppendPoint(Current, Current[0]);
    if PathBuilderOf(Self).Recording then
      AppendPathContour(Current, AClosed)
    else
    begin
      SetLength(Counts, 1);
      Counts[0] := Length(Current);
      EmitPrimitive(mpkPolyline, Current, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
    end;
    SetLength(Current, 0);
  end;

begin
  R := PEMRPolyDraw(ARecord);
  if (R.cptl = 0) or (R.cptl > Cardinal(MaxInt)) then
    Exit;
  PointsOffset := NativeUInt(@R.aptl[0]) - NativeUInt(ARecord);
  TypesOffset := PointsOffset + NativeUInt(R.cptl) * SizeOf(TPoint);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cptl, SizeOf(TPoint)) or not RecordArrayAvailable(ARecord, TypesOffset, R.cptl, SizeOf(Byte)) then
    Exit;
  Types := PByte(PtrOffset(ARecord, TypesOffset));
  SetLength(Current, 0);
  I := 0;
  while I < Integer(R.cptl) do
  begin
    if (Types^ and PT_MOVETO) = PT_MOVETO then
    begin
      FlushCurrent(False);
      AppendPoint(Current, LogicalToOutput(R.aptl[I]));
    end
    else if (Types^ and PT_LINETO) = PT_LINETO then
    begin
      if Length(Current) = 0 then
        AppendPoint(Current, LogicalToOutput(DCStateOf(Self).State.CurrentPos));
      AppendPoint(Current, LogicalToOutput(R.aptl[I]));
    end
    else if (Types^ and PT_BEZIERTO) = PT_BEZIERTO then
    begin
      if (Length(Current) = 0) then
        AppendPoint(Current, LogicalToOutput(DCStateOf(Self).State.CurrentPos));
      if I + 2 < Integer(R.cptl) then
      begin
        SetLength(Segment, 4);
        Segment[0] := Current[High(Current)];
        Segment[1] := LogicalToOutput(R.aptl[I]);
        Segment[2] := LogicalToOutput(R.aptl[I + 1]);
        Segment[3] := LogicalToOutput(R.aptl[I + 2]);
        Flat := CubicBezierToFlatPolyline(Segment[0], Segment[1], Segment[2], Segment[3], FFlatness);
        AppendPoints(Current, Flat, True);
        BezierLeft := 2;
        while (BezierLeft > 0) and (I + 1 < Integer(R.cptl)) do
        begin
          Inc(I);
          Inc(Types);
          Dec(BezierLeft);
        end;
      end;
    end;

    if (Types^ and PT_CLOSEFIGURE) = PT_CLOSEFIGURE then
      FlushCurrent(True);
    Inc(I);
    Inc(Types);
  end;
  FlushCurrent(False);
  if R.cptl > 0 then
    DCStateOf(Self).State.NextPos := IntPoint(R.aptl[R.cptl - 1].X,R.aptl[R.cptl - 1].Y);
end;

procedure TMetafileParser.HandlePolyDraw16(ARecord: PEnhMetaRecord);
var
  R: PEMRPolyDraw16;
  Types: PByte;
  I, BezierLeft: Integer;
  Current, Segment, Flat: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  PointsOffset, TypesOffset: NativeUInt;

  function P16(AIndex: Integer): TMetafilePoint;
  begin
    Result := LogicalToOutput(R.apts[AIndex].X, R.apts[AIndex].Y);
  end;

  procedure FlushCurrent(AClosed: Boolean);
  begin
    if Length(Current) = 0 then
      Exit;
    if AClosed and (Length(Current) > 1) and not PointsAlmostEqual(Current[0], Current[High(Current)]) then
      AppendPoint(Current, Current[0]);
    if PathBuilderOf(Self).Recording then
      AppendPathContour(Current, AClosed)
    else
    begin
      SetLength(Counts, 1);
      Counts[0] := Length(Current);
      EmitPrimitive(mpkPolyline, Current, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
    end;
    SetLength(Current, 0);
  end;

begin
  R := PEMRPolyDraw16(ARecord);
  if (R.cpts = 0) or (R.cpts > Cardinal(MaxInt)) then
    Exit;
  PointsOffset := NativeUInt(@R.apts[0]) - NativeUInt(ARecord);
  TypesOffset := PointsOffset + NativeUInt(R.cpts) * SizeOf(TSmallPoint);
  if not RecordArrayAvailable(ARecord, PointsOffset, R.cpts, SizeOf(TSmallPoint)) or not RecordArrayAvailable(ARecord, TypesOffset, R.cpts, SizeOf(Byte)) then
    Exit;
  Types := PByte(PtrOffset(ARecord, TypesOffset));
  SetLength(Current, 0);
  I := 0;
  while I < Integer(R.cpts) do
  begin
    if (Types^ and PT_MOVETO) = PT_MOVETO then
    begin
      FlushCurrent(False);
      AppendPoint(Current, P16(I));
    end
    else if (Types^ and PT_LINETO) = PT_LINETO then
    begin
      if Length(Current) = 0 then
        AppendPoint(Current, LogicalToOutput(DCStateOf(Self).State.CurrentPos));
      AppendPoint(Current, P16(I));
    end
    else if (Types^ and PT_BEZIERTO) = PT_BEZIERTO then
    begin
      if Length(Current) = 0 then
        AppendPoint(Current, LogicalToOutput(DCStateOf(Self).State.CurrentPos));
      if I + 2 < Integer(R.cpts) then
      begin
        SetLength(Segment, 4);
        Segment[0] := Current[High(Current)];
        Segment[1] := P16(I);
        Segment[2] := P16(I + 1);
        Segment[3] := P16(I + 2);
        Flat := CubicBezierToFlatPolyline(Segment[0], Segment[1], Segment[2], Segment[3], FFlatness);
        AppendPoints(Current, Flat, True);
        BezierLeft := 2;
        while (BezierLeft > 0) and (I + 1 < Integer(R.cpts)) do
        begin
          Inc(I);
          Inc(Types);
          Dec(BezierLeft);
        end;
      end;
    end;

    if (Types^ and PT_CLOSEFIGURE) = PT_CLOSEFIGURE then
      FlushCurrent(True);
    Inc(I);
    Inc(Types);
  end;
  FlushCurrent(False);
  if R.cpts > 0 then
    DCStateOf(Self).State.NextPos := IntPoint(R.apts[R.cpts - 1].X, R.apts[R.cpts - 1].Y);
end;

procedure TMetafileParser.HandleLineTo(ARecord: PEnhMetaRecord);
var
  R: PEMRLineTo;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
begin
  R := PEMRLineTo(ARecord);
  SetLength(Points, 2);
  Points[0] := LogicalToOutput(DCStateOf(Self).State.CurrentPos);
  Points[1] := LogicalToOutput(R.ptl);
  SetLength(Counts, 1);
  Counts[0] := 2;
  if PathBuilderOf(Self).Recording then
    AppendPathOpenPolyline(Points)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
  DCStateOf(Self).State.NextPos := IntPoint(R.ptl.X,R.ptl.Y);
end;

procedure TMetafileParser.HandleMoveTo(ARecord: PEnhMetaRecord);
var
  R: PEMRMoveToEx;
  Points: TMetafilePointArray;
begin
  R := PEMRMoveToEx(ARecord);
  DCStateOf(Self).State.NextPos := IntPoint(R.ptl.X,R.ptl.Y);
  if PathBuilderOf(Self).Recording then
  begin
    SetLength(Points, 1);
    Points[0] := LogicalToOutput(R.ptl);
    AppendPathContour(Points, False);
  end;
end;

procedure TMetafileParser.HandleRectangle(ARecord: PEnhMetaRecord);
var
  R: PEMRRectangle;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
begin
  R := PEMRRectangle(ARecord);
  SetLength(Points, 5);
  Points[0] := LogicalToOutput(R.rclBox.Left, R.rclBox.Top);
  Points[1] := LogicalToOutput(R.rclBox.Right, R.rclBox.Top);
  Points[2] := LogicalToOutput(R.rclBox.Right, R.rclBox.Bottom);
  Points[3] := LogicalToOutput(R.rclBox.Left, R.rclBox.Bottom);
  Points[4] := Points[0];
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathContour(Points, True)
  else
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True);
end;

procedure TMetafileParser.HandleEllipse(ARecord: PEnhMetaRecord);
var
  R: PEMREllipse;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  I: Integer;
  cx, cy, RX, RY, A: Double;
begin
  R := PEMREllipse(ARecord);
  cx := (R.rclBox.Left + R.rclBox.Right) * 0.5;
  cy := (R.rclBox.Top + R.rclBox.Bottom) * 0.5;
  RX := Abs(R.rclBox.Right - R.rclBox.Left) * 0.5;
  RY := Abs(R.rclBox.Bottom - R.rclBox.Top) * 0.5;
  SetLength(Points, DEFAULT_ELLIPSE_SEGMENTS + 1);
  for I := 0 to DEFAULT_ELLIPSE_SEGMENTS do
  begin
    A := 2 * Pi * I / DEFAULT_ELLIPSE_SEGMENTS;
    Points[I] := LogicalToOutput(cx + Cos(A) * RX, cy + Sin(A) * RY);
  end;
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathContour(Points, True)
  else
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True);
end;

procedure TMetafileParser.HandleRoundRect(ARecord: PEnhMetaRecord);
var
  R: PEMRRoundRectLocal;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  L, T, Rt, B, RX, RY: Double;

  procedure AddArc(cx, cy, A0, A1: Double);
  var
    I, N: Integer;
    A: Double;
  begin
    N := Max(6, Round(Abs(A1 - A0) / (Pi / 12)));
    for I := 0 to N do
    begin
      A := A0 + (A1 - A0) * I / N;
      AppendPoint(Points, LogicalToOutput(cx + Cos(A) * RX, cy + Sin(A) * RY));
    end;
  end;

begin
  R := PEMRRoundRectLocal(ARecord);
  L := R.rclBox.Left;
  T := R.rclBox.Top;
  Rt := R.rclBox.Right;
  B := R.rclBox.Bottom;
  RX := Abs(R.szlCorner.cx) * 0.5;
  RY := Abs(R.szlCorner.cy) * 0.5;
  RX := Min(RX, Abs(Rt - L) * 0.5);
  RY := Min(RY, Abs(B - T) * 0.5);
  SetLength(Points, 0);
  AddArc(Rt - RX, T + RY, -Pi / 2, 0);
  AddArc(Rt - RX, B - RY, 0, Pi / 2);
  AddArc(L + RX, B - RY, Pi / 2, Pi);
  AddArc(L + RX, T + RY, Pi, 3 * Pi / 2);
  if (Length(Points) > 1) and not PointsAlmostEqual(Points[0], Points[High(Points)]) then
    AppendPoint(Points, Points[0]);
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathContour(Points, True)
  else
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True);
end;

procedure TMetafileParser.HandleArcLike(ARecord: PEnhMetaRecord; AKind: Cardinal);
var
  R: PEMRArc;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  cx, cy, RX, RY, A0, A1, A, Sweep: Double;
  I, N: Integer;
  StartP, EndP, CenterP: TMetafilePoint;
  IsClosedShape: Boolean;
begin
  R := PEMRArc(ARecord);
  cx := (R.rclBox.Left + R.rclBox.Right) * 0.5;
  cy := (R.rclBox.Top + R.rclBox.Bottom) * 0.5;
  RX := Abs(R.rclBox.Right - R.rclBox.Left) * 0.5;
  RY := Abs(R.rclBox.Bottom - R.rclBox.Top) * 0.5;
  if (RX <= 0) or (RY <= 0) then
    Exit;

  A0 := ArcTan2((R.ptlStart.Y - cy) / RY, (R.ptlStart.X - cx) / RX);
  A1 := ArcTan2((R.ptlEnd.Y - cy) / RY, (R.ptlEnd.X - cx) / RX);
  if DCStateOf(Self).State.ArcDirection = AD_CLOCKWISE then
  begin
    while A1 < A0 do
      A1 := A1 + 2 * Pi;
  end
  else
  begin
    while A1 > A0 do
      A1 := A1 - 2 * Pi;
  end;
  Sweep := A1 - A0;
  N := Max(4, Round(Abs(Sweep) / (2 * Pi) * DEFAULT_ARC_SEGMENTS));
  SetLength(Points, 0);

  IsClosedShape := AKind in [EMR_CHORD, EMR_PIE];
  if AKind = EMR_PIE then
  begin
    CenterP := LogicalToOutput(cx, cy);
    AppendPoint(Points, CenterP);
  end;

  for I := 0 to N do
  begin
    A := A0 + Sweep * I / N;
    AppendPoint(Points, LogicalToOutput(cx + Cos(A) * RX, cy + Sin(A) * RY));
  end;

  if AKind = EMR_PIE then
    AppendPoint(Points, CenterP)
  else if AKind = EMR_CHORD then
  begin
    StartP := Points[0];
    EndP := Points[High(Points)];
    if not PointsAlmostEqual(StartP, EndP) then
      AppendPoint(Points, StartP);
  end;

  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathContour(Points, IsClosedShape)
  else if IsClosedShape then
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, True)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);

  if AKind = EMR_ARCTO then
    DCStateOf(Self).State.NextPos := IntPoint(R.ptlEnd.X,R.ptlEnd.Y);
end;

procedure TMetafileParser.HandleAngleArc(ARecord: PEnhMetaRecord);
var
  R: PEMRAngleArcLocal;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  I, N: Integer;
  A0, Sweep, A: Double;
  EndLogical: TPoint;
begin
  R := PEMRAngleArcLocal(ARecord);
  A0 := DegToRad(R.eStartAngle);
  Sweep := DegToRad(R.eSweepAngle);
  N := Max(4, Round(Abs(Sweep) / (2 * Pi) * DEFAULT_ARC_SEGMENTS));
  SetLength(Points, N + 1);
  for I := 0 to N do
  begin
    A := A0 + Sweep * I / N;
    Points[I] := LogicalToOutput(R.ptlCenter.X + Cos(A) * R.nRadius, R.ptlCenter.Y - Sin(A) * R.nRadius);
  end;
  SetLength(Counts, 1);
  Counts[0] := Length(Points);
  if PathBuilderOf(Self).Recording then
    AppendPathOpenPolyline(Points)
  else
    EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
  EndLogical.X := Round(R.ptlCenter.X + Cos(A0 + Sweep) * R.nRadius);
  EndLogical.Y := Round(R.ptlCenter.Y - Sin(A0 + Sweep) * R.nRadius);
  DCStateOf(Self).State.NextPos := EndLogical;
end;

procedure TMetafileParser.HandleTextOut(ARecord: PEnhMetaRecord; AWide: Boolean);
var
  R: PEMRExtTextOut;
  TextPtr: Pointer;
  Text: UnicodeString;
  S: AnsiString;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  Origin: TMetafilePoint;
  GlyphPtr: PWord;
  GlyphCount: Integer;
  CharSize: NativeUInt;
  TextBytes: NativeUInt;
  Dx, Dy: TMetafileIntegerArray;
  BoundsPoints: TMetafilePointArray;
  TextBounds: TMetafileRect;
begin
  R := PEMRExtTextOut(ARecord);
  GlyphPtr := nil;
  GlyphCount := 0;

  if AWide or ((R.emrtext.fOptions and ETO_GLYPH_INDEX) <> 0) then
    CharSize := SizeOf(WideChar)
  else
    CharSize := SizeOf(AnsiChar);
  if not RecordArrayAvailable(ARecord, R.emrtext.offString, R.emrtext.nChars, CharSize) then
    Exit;
  TextBytes := NativeUInt(R.emrtext.nChars) * CharSize;
  if not RecordPtr(ARecord, R.emrtext.offString, TextBytes, TextPtr) then
    Exit;

  if (R.emrtext.fOptions and ETO_GLYPH_INDEX) <> 0 then
  begin
    GlyphPtr := PWord(TextPtr);
    GlyphCount := R.emrtext.nChars;
    Text := '';
  end
  else if AWide then
    SetString(Text, PWideChar(TextPtr), R.emrtext.nChars)
  else
  begin
    SetString(S, PAnsiChar(TextPtr), R.emrtext.nChars);
    Text := UnicodeString(string(S));
  end;

  if not ReadTextAdvances(ARecord, R.emrtext.offDx, R.emrtext.nChars, R.emrtext.fOptions, Dx, Dy) then
    Exit;

  Origin := LogicalToOutput(R.emrtext.ptlReference);
  SetLength(BoundsPoints, 5);
  BoundsPoints[0] := LogicalToOutput(R.emrtext.rcl.Left, R.emrtext.rcl.Top);
  BoundsPoints[1] := LogicalToOutput(R.emrtext.rcl.Right, R.emrtext.rcl.Top);
  BoundsPoints[2] := LogicalToOutput(R.emrtext.rcl.Right, R.emrtext.rcl.Bottom);
  BoundsPoints[3] := LogicalToOutput(R.emrtext.rcl.Left, R.emrtext.rcl.Bottom);
  BoundsPoints[4] := BoundsPoints[0];
  TextBounds := BoundsOfPoints(BoundsPoints);
  DCStateOf(Self).SetTextRecordMetrics(R.emrtext.fOptions, TextBounds, Dx, Dy);
  SetLength(Points, 1);
  Points[0] := Origin;
  SetLength(Counts, 1);
  Counts[0] := 1;
  EmitPrimitive(mpkText, Points, Counts, Text, ARecord.iType, RecordName(ARecord.iType), False, False);

  if FConvertTextToCurves then
    EmitTextCurves(ARecord.iType, RecordName(ARecord.iType), Text, Origin, GlyphPtr, GlyphCount, Dx, Dy, R.emrtext.fOptions);
  SetLength(Dx, 0);
  SetLength(Dy, 0);
  DCStateOf(Self).SetTextRecordMetrics(0, EmptyRectD, Dx, Dy);
end;

procedure TMetafileParser.HandleSmallTextOut(ARecord: PEnhMetaRecord);
var
  R: PEMRSmallTextOutLocal;
  TextPtr: Pointer;
  Text: UnicodeString;
  S: AnsiString;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  Origin: TMetafilePoint;
  CharSize, TextBytes, TextOffset: NativeUInt;
  BoundsPoints: TMetafilePointArray;
  TextBounds: TMetafileRect;
  EmptyDx, EmptyDy: TMetafileIntegerArray;
begin
  R := PEMRSmallTextOutLocal(ARecord);
  if (R.nChars = 0) or (R.nChars > Cardinal(MaxInt)) then
    Exit;

  TextOffset := SizeOf(TEMR) + SizeOf(TPoint) + 3 * SizeOf(DWORD) + 2 * SizeOf(Single);
  if (R.fuOptions and ETO_NO_RECT_LOCAL) = 0 then
    Inc(TextOffset, SizeOf(TRect));

  if (R.fuOptions and ETO_SMALL_CHARS_LOCAL) <> 0 then
    CharSize := SizeOf(AnsiChar)
  else
    CharSize := SizeOf(WideChar);
  TextBytes := NativeUInt(R.nChars) * CharSize;
  if not RecordPtr(ARecord, TextOffset, TextBytes, TextPtr) then
    Exit;

  if (R.fuOptions and ETO_SMALL_CHARS_LOCAL) <> 0 then
  begin
    SetString(S, PAnsiChar(TextPtr), R.nChars);
    Text := UnicodeString(string(S));
  end
  else
    SetString(Text, PWideChar(TextPtr), R.nChars);

  Origin := LogicalToOutput(R.ptlReference);
  if (R.fuOptions and ETO_NO_RECT_LOCAL) = 0 then
  begin
    SetLength(BoundsPoints, 5);
    BoundsPoints[0] := LogicalToOutput(R.rclClip.Left, R.rclClip.Top);
    BoundsPoints[1] := LogicalToOutput(R.rclClip.Right, R.rclClip.Top);
    BoundsPoints[2] := LogicalToOutput(R.rclClip.Right, R.rclClip.Bottom);
    BoundsPoints[3] := LogicalToOutput(R.rclClip.Left, R.rclClip.Bottom);
    BoundsPoints[4] := BoundsPoints[0];
    TextBounds := BoundsOfPoints(BoundsPoints);
  end
  else
    TextBounds := EmptyRectD;

  SetLength(EmptyDx, 0);
  SetLength(EmptyDy, 0);
  DCStateOf(Self).SetTextRecordMetrics(R.fuOptions, TextBounds, EmptyDx, EmptyDy);
  SetLength(Points, 1);
  Points[0] := Origin;
  SetLength(Counts, 1);
  Counts[0] := 1;
  EmitPrimitive(mpkText, Points, Counts, Text, ARecord.iType, RecordName(ARecord.iType), False, False);

  if FConvertTextToCurves then
    EmitTextCurves(ARecord.iType, RecordName(ARecord.iType), Text, Origin, nil, 0, EmptyDx, EmptyDy, R.fuOptions);
  DCStateOf(Self).SetTextRecordMetrics(0, EmptyRectD, EmptyDx, EmptyDy);
end;

procedure TMetafileParser.EmitTextCurves(ARecordType: Cardinal; const ARecordName: string; const AText: UnicodeString; const AOrigin: TMetafilePoint; AGlyphIndexes: PWord;
  AGlyphCount: Integer; const ADx, ADy: TMetafileIntegerArray; AOptions: Cardinal);
var
  CurvePoints: TMetafilePointArray;
  CurveCounts: TMetafileIntegerArray;
  OldFill: TMetafileFillStyle;
  OldStroke: TMetafileStrokeStyle;
begin
  if not CurrentTextToFlatPolygonsInternal(AText, AOrigin, DCStateOf(Self).State.Font, AGlyphIndexes, AGlyphCount, ADx, ADy, AOptions, CurvePoints, CurveCounts) then
    Exit;

  OldFill := DCStateOf(Self).State.Fill;
  OldStroke := DCStateOf(Self).State.Stroke;
  try
    DCStateOf(Self).State.Fill.Visible := True;
    DCStateOf(Self).State.Fill.Kind := mfkSolid;
    DCStateOf(Self).State.Fill.Color := DCStateOf(Self).State.TextColor;
    DCStateOf(Self).State.Fill.Style := BS_SOLID;
    DCStateOf(Self).State.Fill.Hatch := 0;
    DCStateOf(Self).State.Stroke.Visible := False;
    EmitPrimitive(mpkPolygon, CurvePoints, CurveCounts, '', ARecordType, ARecordName + '/TEXTCURVES', False, True);
  finally
    DCStateOf(Self).State.Fill := OldFill;
    DCStateOf(Self).State.Stroke := OldStroke;
  end;
end;

procedure TMetafileParser.HandlePolyTextOut(ARecord: PEnhMetaRecord; AWide: Boolean);
var
  R: PEMRPolyTextOutLocal;
  I: Integer;
  TextRecord: PEMRTextLocal;
  TextPtr: Pointer;
  Text: UnicodeString;
  S: AnsiString;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  Origin: TMetafilePoint;
  GlyphPtr: PWord;
  GlyphCount: Integer;
  CharSize: NativeUInt;
  TextBytes: NativeUInt;
  Dx, Dy: TMetafileIntegerArray;
  BoundsPoints: TMetafilePointArray;
  TextBounds: TMetafileRect;
begin
  R := PEMRPolyTextOutLocal(ARecord);
  if R.cStrings < 0 then
    Exit;
  if not RecordArrayAvailable(ARecord, NativeUInt(@R.aemrtext[0]) - NativeUInt(ARecord), R.cStrings, SizeOf(TEMRTextLocal)) then
    Exit;
  for I := 0 to R.cStrings - 1 do
  begin
    TextRecord := @R.aemrtext[I];
    GlyphPtr := nil;
    GlyphCount := 0;
    if AWide or ((TextRecord.fOptions and ETO_GLYPH_INDEX) <> 0) then
      CharSize := SizeOf(WideChar)
    else
      CharSize := SizeOf(AnsiChar);
    if not RecordArrayAvailable(ARecord, TextRecord.offString, TextRecord.nChars, CharSize) then
      Continue;
    TextBytes := NativeUInt(TextRecord.nChars) * CharSize;
    if not RecordPtr(ARecord, TextRecord.offString, TextBytes, TextPtr) then
      Continue;
    if (TextRecord.fOptions and ETO_GLYPH_INDEX) <> 0 then
    begin
      GlyphPtr := PWord(TextPtr);
      GlyphCount := TextRecord.nChars;
      Text := '';
    end
    else if AWide then
      SetString(Text, PWideChar(TextPtr), TextRecord.nChars)
    else
    begin
      SetString(S, PAnsiChar(TextPtr), TextRecord.nChars);
      Text := UnicodeString(string(S));
    end;
    if not ReadTextAdvances(ARecord, TextRecord.offDx, TextRecord.nChars, TextRecord.fOptions, Dx, Dy) then
      Continue;

    Origin := LogicalToOutput(TextRecord.ptlReference);
    SetLength(BoundsPoints, 5);
    BoundsPoints[0] := LogicalToOutput(TextRecord.rcl.Left, TextRecord.rcl.Top);
    BoundsPoints[1] := LogicalToOutput(TextRecord.rcl.Right, TextRecord.rcl.Top);
    BoundsPoints[2] := LogicalToOutput(TextRecord.rcl.Right, TextRecord.rcl.Bottom);
    BoundsPoints[3] := LogicalToOutput(TextRecord.rcl.Left, TextRecord.rcl.Bottom);
    BoundsPoints[4] := BoundsPoints[0];
    TextBounds := BoundsOfPoints(BoundsPoints);
    DCStateOf(Self).SetTextRecordMetrics(TextRecord.fOptions, TextBounds, Dx, Dy);
    SetLength(Points, 1);
    Points[0] := Origin;
    SetLength(Counts, 1);
    Counts[0] := 1;
    EmitPrimitive(mpkText, Points, Counts, Text, ARecord.iType, RecordName(ARecord.iType), False, False);
    if FConvertTextToCurves then
      EmitTextCurves(ARecord.iType, RecordName(ARecord.iType), Text, Origin, GlyphPtr, GlyphCount, Dx, Dy, TextRecord.fOptions);
    SetLength(Dx, 0);
    SetLength(Dy, 0);
    DCStateOf(Self).SetTextRecordMetrics(0, EmptyRectD, Dx, Dy);
  end;
end;

procedure TMetafileParser.HandleWidenPath(ARecord: PEnhMetaRecord);
begin
  PathBuilderOf(Self).Widen(CurrentStroke.Width);
end;

procedure TMetafileParser.HandleFillRegion(ARecord: PEnhMetaRecord; AFrame: Boolean);
var
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  OldFill: TMetafileFillStyle;
  OldStroke: TMetafileStrokeStyle;
  RFill: PEMRFillRgnLocal;
  RFrame: PEMRFrameRgnLocal;
  DataPtr: Pointer;
  DataSize: NativeUInt;
begin
  if AFrame then
  begin
    RFrame := PEMRFrameRgnLocal(ARecord);
    DataPtr := @RFrame.RgnData[0];
    DataSize := RFrame.cbRgnData;
    if not RecordArrayAvailable(ARecord, NativeUInt(DataPtr) - NativeUInt(ARecord), DataSize, SizeOf(Byte)) then
      Exit;
    if not RegionDataToPolygons(DataPtr, DataSize, DCStateOf(Self), Points, Counts) then
      Exit;

    OldFill := DCStateOf(Self).State.Fill;
    OldStroke := DCStateOf(Self).State.Stroke;
    try
      SelectObjectHandle(RFrame.ihBrush);
      DCStateOf(Self).State.Stroke.Visible := True;
      DCStateOf(Self).State.Stroke.Color := DCStateOf(Self).State.Fill.Color;
      DCStateOf(Self).State.Stroke.Width := Max(1, RFrame.szlStroke.cx);
      DCStateOf(Self).State.Fill.Visible := False;
      EmitPrimitive(mpkPolyline, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), True, False);
    finally
      DCStateOf(Self).State.Fill := OldFill;
      DCStateOf(Self).State.Stroke := OldStroke;
    end;
  end
  else
  begin
    RFill := PEMRFillRgnLocal(ARecord);
    DataPtr := @RFill.RgnData[0];
    DataSize := RFill.cbRgnData;
    if not RecordArrayAvailable(ARecord, NativeUInt(DataPtr) - NativeUInt(ARecord), DataSize, SizeOf(Byte)) then
      Exit;
    if not RegionDataToPolygons(DataPtr, DataSize, DCStateOf(Self), Points, Counts) then
      Exit;

    OldFill := DCStateOf(Self).State.Fill;
    try
      SelectObjectHandle(RFill.ihBrush);
      EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), False, True);
    finally
      DCStateOf(Self).State.Fill := OldFill;
    end;
  end;
end;

procedure TMetafileParser.HandlePaintOrInvertRegion(ARecord: PEnhMetaRecord);
var
  R: PEMRRegionLocal;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  DataPtr: Pointer;
begin
  R := PEMRRegionLocal(ARecord);
  DataPtr := @R.RgnData[0];
  if not RecordArrayAvailable(ARecord, NativeUInt(DataPtr) - NativeUInt(ARecord), R.cbRgnData, SizeOf(Byte)) then
    Exit;
  if RegionDataToPolygons(DataPtr, R.cbRgnData, DCStateOf(Self), Points, Counts) then
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), False, True);
end;

procedure TMetafileParser.HandleExtSelectClipRegion(ARecord: PEnhMetaRecord);
var
  R: PEMRExtSelectClipRgnLocal;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  DataPtr: Pointer;
begin
  R := PEMRExtSelectClipRgnLocal(ARecord);
  if R.cbRgnData = 0 then
  begin
    if R.iMode = RGN_COPY then
      DCStateOf(Self).ClearClip;
    Exit;
  end;

  DataPtr := @R.RgnData[0];
  if not RecordArrayAvailable(ARecord, NativeUInt(DataPtr) - NativeUInt(ARecord), R.cbRgnData, SizeOf(Byte)) then
    Exit;
  if RegionDataToPolygons(DataPtr, R.cbRgnData, DCStateOf(Self), Points, Counts) then
    DCStateOf(Self).SetClipRegion(Points, Counts, R.iMode);
end;

procedure TMetafileParser.HandleClipRect(ARecord: PEnhMetaRecord; ACombineMode: Cardinal);
begin
  DCStateOf(Self).ApplyClipRect(PEMRClipRectLocal(ARecord).rclClip, ACombineMode);
end;

procedure TMetafileParser.HandleOffsetClipRegion(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).OffsetClip(PEMROffsetClipRgnLocal(ARecord).ptlOffset);
end;

procedure TMetafileParser.HandleGradientFill(ARecord: PEnhMetaRecord);
var
  R: PEMGradientFill;
  Verts: PTriVertexArray;
  GradRects: PGradientRectArray;
  GradTris: PGradientTriangleArray;
  MeshOffset, VertOffset: NativeUInt;
  I: Integer;
  Mode: Cardinal;
  Fill, OldFill: TMetafileFillStyle;
  Points, One: TMetafilePointArray;
  Counts: TMetafileIntegerArray;

  function VertexInRange(AIndex: Cardinal): Boolean;
  begin
    Result := AIndex < R.nVer;
  end;

  procedure AppendGradientRect(const AR: TGradientRect);
  var
    P0, P1, P2, P3: TMetafilePoint;
    V0, V1: TTriVertex;
  begin
    if not (VertexInRange(AR.UpperLeft) and VertexInRange(AR.LowerRight)) then
      Exit;
    V0 := Verts[AR.UpperLeft];
    V1 := Verts[AR.LowerRight];
    P0 := LogicalToOutput(V0.x, V0.y);
    P1 := LogicalToOutput(V1.x, V0.y);
    P2 := LogicalToOutput(V1.x, V1.y);
    P3 := LogicalToOutput(V0.x, V1.y);
    SetLength(One, 5);
    One[0] := P0;
    One[1] := P1;
    One[2] := P2;
    One[3] := P3;
    One[4] := P0;
    AppendPoints(Points, One, False);
    AppendCount(Counts, Length(One));
  end;

  procedure AppendGradientTriangle(const AT: TGradientTriangle);
  begin
    if not (VertexInRange(AT.Vertex1) and VertexInRange(AT.Vertex2) and VertexInRange(AT.Vertex3)) then
      Exit;
    SetLength(One, 4);
    One[0] := Fill.Gradient.Vertices[AT.Vertex1].Point;
    One[1] := Fill.Gradient.Vertices[AT.Vertex2].Point;
    One[2] := Fill.Gradient.Vertices[AT.Vertex3].Point;
    One[3] := One[0];
    AppendPoints(Points, One, False);
    AppendCount(Counts, Length(One));
  end;

begin
  R := PEMGradientFill(ARecord);
  if (R.nVer = 0) or (R.nVer > Cardinal(MaxInt)) or (R.nTri > Cardinal(MaxInt)) then
    Exit;

  VertOffset := NativeUInt(@R.Ver[0]) - NativeUInt(ARecord);
  if not RecordArrayAvailable(ARecord, VertOffset, R.nVer, SizeOf(TTriVertex)) then
    Exit;
  Verts := PTriVertexArray(@R.Ver[0]);

  Fill := CurrentFill;
  Fill.Kind := mfkGradient;
  Fill.Visible := True;
  Fill.Style := BS_SOLID;
  Fill.Gradient.Mode := R.ulMode;
  Mode := R.ulMode and GRADIENT_FILL_OP_FLAG;
  if Mode = GRADIENT_FILL_TRIANGLE then
    Fill.Gradient.Kind := mgkTriangle
  else
    Fill.Gradient.Kind := mgkRect;

  SetLength(Fill.Gradient.Vertices, R.nVer);
  for I := 0 to Integer(R.nVer) - 1 do
  begin
    Fill.Gradient.Vertices[I].Point := LogicalToOutput(Verts[I].x, Verts[I].y);
    Fill.Gradient.Vertices[I].Red := Verts[I].Red;
    Fill.Gradient.Vertices[I].Green := Verts[I].Green;
    Fill.Gradient.Vertices[I].Blue := Verts[I].Blue;
    Fill.Gradient.Vertices[I].Alpha := Verts[I].Alpha;
  end;
  if R.nVer > 0 then
    Fill.Color := RGB(Verts[0].Red shr 8, Verts[0].Green shr 8, Verts[0].Blue shr 8);

  MeshOffset := VertOffset + NativeUInt(R.nVer) * SizeOf(TTriVertex);
  SetLength(Fill.Gradient.Meshes, R.nTri);
  if Mode = GRADIENT_FILL_TRIANGLE then
  begin
    if not RecordArrayAvailable(ARecord, MeshOffset, R.nTri, SizeOf(TGradientTriangle)) then
      Exit;
    GradTris := PGradientTriangleArray(PtrOffset(ARecord, MeshOffset));
    for I := 0 to Integer(R.nTri) - 1 do
    begin
      Fill.Gradient.Meshes[I].Index0 := GradTris[I].Vertex1;
      Fill.Gradient.Meshes[I].Index1 := GradTris[I].Vertex2;
      Fill.Gradient.Meshes[I].Index2 := GradTris[I].Vertex3;
      AppendGradientTriangle(GradTris[I]);
    end;
  end
  else
  begin
    if not RecordArrayAvailable(ARecord, MeshOffset, R.nTri, SizeOf(TGradientRect)) then
      Exit;
    GradRects := PGradientRectArray(PtrOffset(ARecord, MeshOffset));
    for I := 0 to Integer(R.nTri) - 1 do
    begin
      Fill.Gradient.Meshes[I].Index0 := GradRects[I].UpperLeft;
      Fill.Gradient.Meshes[I].Index1 := GradRects[I].LowerRight;
      Fill.Gradient.Meshes[I].Index2 := 0;
      AppendGradientRect(GradRects[I]);
    end;
  end;

  if Length(Points) = 0 then
    Exit;

  OldFill := DCStateOf(Self).State.Fill;
  try
    DCStateOf(Self).State.Fill := CopyFillStyle(Fill);
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), False, True);
  finally
    DCStateOf(Self).State.Fill := OldFill;
  end;
end;

procedure TMetafileParser.HandleRasterRecord(ARecord: PEnhMetaRecord);
var
  Image: TMetafileImageStyle;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  BitBlt: PEMRBitBlt;
  StretchBlt: PEMRStretchBlt;
  StretchDib: PEMRStretchDIBits;
  MaskBlt: PEMRMaskBlt;
  SetDIBits: PEMRSetDIBitsToDevice;
  AlphaBlend: PEMRAlphaBlend;
  TransparentBlt: PEMRTransparentBLT;
  PlgBlt: PEMRPLGBlt;

  procedure SetImageData(var AData: TMetafileImageData; AUsage, AOffBmi, ACbBmi, AOffBits, ACbBits: Cardinal);
  begin
    AData.Usage := AUsage;
    if not ReadRecordBytes(ARecord, AOffBmi, ACbBmi, AData.BitmapInfo) then
      SetLength(AData.BitmapInfo, 0);
    if not ReadRecordBytes(ARecord, AOffBits, ACbBits, AData.Bits) then
      SetLength(AData.Bits, 0);
    NormalizeMetafileDIB(AData.BitmapInfo,AData.Bits,AUsage);
  end;

  procedure SetRectGeometry(AX, AY, ACX, ACY: Integer);
  begin
    SetLength(Points, 5);
    Points[0] := LogicalToOutput(AX, AY);
    Points[1] := LogicalToOutput(AX + ACX, AY);
    Points[2] := LogicalToOutput(AX + ACX, AY + ACY);
    Points[3] := LogicalToOutput(AX, AY + ACY);
    Points[4] := Points[0];
    SetLength(Counts, 1);
    Counts[0] := Length(Points);
    Image.DestRect := BoundsOfPoints(Points);
    Image.Bounds := Image.DestRect;
  end;

  procedure SetParallelogramGeometry(const AP0, AP1, AP2: {$IFDEF FPC}POINTL{$ELSE}TPoint{$ENDIF});
  var
    P3: TPoint;
  begin
    P3.X := AP1.X + AP2.X - AP0.X;
    P3.Y := AP1.Y + AP2.Y - AP0.Y;
    SetLength(Points, 5);
    Points[0] := LogicalToOutput(AP0);
    Points[1] := LogicalToOutput(AP1);
    Points[2] := LogicalToOutput(P3);
    Points[3] := LogicalToOutput(AP2);
    Points[4] := Points[0];
    SetLength(Counts, 1);
    Counts[0] := Length(Points);
    Image.DestRect := BoundsOfPoints(Points);
    Image.Bounds := Image.DestRect;
  end;

  procedure SetSrcRect(AX, AY, ACX, ACY: Integer);
  begin
    Image.SrcRect.Left := AX;
    Image.SrcRect.Top := AY;
    Image.SrcRect.Right := AX + ACX;
    Image.SrcRect.Bottom := AY + ACY;
  end;

  procedure SetRasterOperation(AKind: TMetafileRasterOperationKind; AOperation: Cardinal);
  var
    Fill: TMetafileFillStyle;
  begin
    Image.OperationKind := AKind;
    Image.Operation := AOperation;
    Image.Rop3 := MetafileRopToByte(AOperation);
    Image.ForegroundRop3 := MetafileRop4ForegroundByte(AOperation);
    Image.BackgroundRop3 := MetafileRop4BackgroundByte(AOperation);
    Image.OperationName := MetafileRasterOperationName(AKind, AOperation);
    if not ((AKind = mrokRop3) or (AKind = mrokRop4)) then
    begin
      Image.Rop3 := 0;
      Image.ForegroundRop3 := 0;
      Image.BackgroundRop3 := 0;
    end;
    Fill := CurrentFill;
    Image.PatternColor := Fill.Color;
    Image.PatternBrush := CopyBrushData(Fill.Brush);
    Image.PatternBrushOrigin := Fill.BrushOrigin;
  end;

  procedure SetAlphaBlendOperation(ABlend: Cardinal);
  begin
    SetRasterOperation(mrokAlphaBlend, ABlend);
    Image.Blend := ABlend;
    Image.BlendOperation := Byte(ABlend);
    Image.BlendFlags := Byte(ABlend shr 8);
    Image.SourceConstantAlpha := Byte(ABlend shr 16);
    Image.AlphaFormat := Byte(ABlend shr 24);
    Image.HasPerPixelAlpha := (Image.AlphaFormat and $01) <> 0;
    Image.OperationName := Format('ALPHABLEND op=%d flags=%d alpha=%d format=%d',
      [Image.BlendOperation, Image.BlendFlags, Image.SourceConstantAlpha, Image.AlphaFormat]);
  end;

begin
  ClearImageStyle(Image);
  Image.StretchMode := DCStateOf(Self).State.StretchMode;
  case ARecord.iType of
    EMR_BITBLT:
      begin
        BitBlt := PEMRBitBlt(ARecord);
        SetRectGeometry(BitBlt.xDest, BitBlt.yDest, BitBlt.cxDest, BitBlt.cyDest);
        SetSrcRect(BitBlt.xSrc, BitBlt.ySrc, BitBlt.cxDest, BitBlt.cyDest);
        SetRasterOperation(mrokRop3, BitBlt.dwRop);
        Image.BkColorSrc := BitBlt.crBkColorSrc;
        Image.XForm := BitBlt.xformSrc;
        SetImageData(Image.Image, BitBlt.iUsageSrc, BitBlt.offBmiSrc, BitBlt.cbBmiSrc, BitBlt.offBitsSrc, BitBlt.cbBitsSrc);
      end;
    EMR_STRETCHBLT:
      begin
        StretchBlt := PEMRStretchBlt(ARecord);
        SetRectGeometry(StretchBlt.xDest, StretchBlt.yDest, StretchBlt.cxDest, StretchBlt.cyDest);
        SetSrcRect(StretchBlt.xSrc, StretchBlt.ySrc, StretchBlt.cxSrc, StretchBlt.cySrc);
        SetRasterOperation(mrokRop3, StretchBlt.dwRop);
        Image.BkColorSrc := StretchBlt.crBkColorSrc;
        Image.XForm := StretchBlt.xformSrc;
        SetImageData(Image.Image, StretchBlt.iUsageSrc, StretchBlt.offBmiSrc, StretchBlt.cbBmiSrc, StretchBlt.offBitsSrc, StretchBlt.cbBitsSrc);
      end;
    EMR_STRETCHDIBITS:
      begin
        StretchDib := PEMRStretchDIBits(ARecord);
        SetRectGeometry(StretchDib.xDest, StretchDib.yDest, StretchDib.cxDest, StretchDib.cyDest);
        SetSrcRect(StretchDib.xSrc, StretchDib.ySrc, StretchDib.cxSrc, StretchDib.cySrc);
        SetRasterOperation(mrokRop3, StretchDib.dwRop);
        SetImageData(Image.Image, StretchDib.iUsageSrc, StretchDib.offBmiSrc, StretchDib.cbBmiSrc, StretchDib.offBitsSrc, StretchDib.cbBitsSrc);
      end;
    EMR_MASKBLT:
      begin
        MaskBlt := PEMRMaskBlt(ARecord);
        SetRectGeometry(MaskBlt.xDest, MaskBlt.yDest, MaskBlt.cxDest, MaskBlt.cyDest);
        SetSrcRect(MaskBlt.xSrc, MaskBlt.ySrc, MaskBlt.cxDest, MaskBlt.cyDest);
        SetRasterOperation(mrokRop4, MaskBlt.dwRop);
        Image.BkColorSrc := MaskBlt.crBkColorSrc;
        Image.XForm := MaskBlt.xformSrc;
        Image.MaskOrigin := IntPoint(MaskBlt.xMask, MaskBlt.yMask);
        SetImageData(Image.Image, MaskBlt.iUsageSrc, MaskBlt.offBmiSrc, MaskBlt.cbBmiSrc, MaskBlt.offBitsSrc, MaskBlt.cbBitsSrc);
        SetImageData(Image.Mask, MaskBlt.iUsageMask, MaskBlt.offBmiMask, MaskBlt.cbBmiMask, MaskBlt.offBitsMask, MaskBlt.cbBitsMask);
      end;
    EMR_SETDIBITSTODEVICE:
      begin
        SetDIBits := PEMRSetDIBitsToDevice(ARecord);
        SetRectGeometry(SetDIBits.xDest, SetDIBits.yDest, SetDIBits.cxSrc, SetDIBits.cySrc);
        SetSrcRect(SetDIBits.xSrc, SetDIBits.ySrc, SetDIBits.cxSrc, SetDIBits.cySrc);
        SetRasterOperation(mrokSetDIBits, SRCCOPY);
        Image.StartScan := SetDIBits.iStartScan;
        Image.ScanCount := SetDIBits.cScans;
        SetImageData(Image.Image, SetDIBits.iUsageSrc, SetDIBits.offBmiSrc, SetDIBits.cbBmiSrc, SetDIBits.offBitsSrc, SetDIBits.cbBitsSrc);
      end;
    EMR_ALPHABLEND:
      begin
        AlphaBlend := PEMRAlphaBlend(ARecord);
        SetRectGeometry(AlphaBlend.xDest, AlphaBlend.yDest, AlphaBlend.cxDest, AlphaBlend.cyDest);
        SetSrcRect(AlphaBlend.xSrc, AlphaBlend.ySrc, AlphaBlend.cxSrc, AlphaBlend.cySrc);
        SetAlphaBlendOperation(AlphaBlend.dwRop);
        Image.BkColorSrc := AlphaBlend.crBkColorSrc;
        Image.XForm := AlphaBlend.xformSrc;
        SetImageData(Image.Image, AlphaBlend.iUsageSrc, AlphaBlend.offBmiSrc, AlphaBlend.cbBmiSrc, AlphaBlend.offBitsSrc, AlphaBlend.cbBitsSrc);
      end;
    EMR_TRANSPARENTBLT:
      begin
        TransparentBlt := PEMRTransparentBLT(ARecord);
        SetRectGeometry(TransparentBlt.xDest, TransparentBlt.yDest, TransparentBlt.cxDest, TransparentBlt.cyDest);
        SetSrcRect(TransparentBlt.xSrc, TransparentBlt.ySrc, TransparentBlt.cxSrc, TransparentBlt.cySrc);
        SetRasterOperation(mrokTransparent, TransparentBlt.dwRop);
        Image.BkColorSrc := TransparentBlt.crBkColorSrc;
        Image.TransparentColor := TColor(TransparentBlt.dwRop and $00FFFFFF);
        Image.XForm := TransparentBlt.xformSrc;
        SetImageData(Image.Image, TransparentBlt.iUsageSrc, TransparentBlt.offBmiSrc, TransparentBlt.cbBmiSrc, TransparentBlt.offBitsSrc, TransparentBlt.cbBitsSrc);
      end;
    EMR_PLGBLT:
      begin
        PlgBlt := PEMRPLGBlt(ARecord);
        SetParallelogramGeometry(PlgBlt.aptlDest[0], PlgBlt.aptlDest[1], PlgBlt.aptlDest[2]);
        SetSrcRect(PlgBlt.xSrc, PlgBlt.ySrc, PlgBlt.cxSrc, PlgBlt.cySrc);
        SetRasterOperation(mrokPlgBlt, SRCCOPY);
        Image.BkColorSrc := PlgBlt.crBkColorSrc;
        Image.XForm := PlgBlt.xformSrc;
        Image.MaskOrigin := IntPoint(PlgBlt.xMask, PlgBlt.yMask);
        SetImageData(Image.Image, PlgBlt.iUsageSrc, PlgBlt.offBmiSrc, PlgBlt.cbBmiSrc, PlgBlt.offBitsSrc, PlgBlt.cbBitsSrc);
        SetImageData(Image.Mask, PlgBlt.iUsageMask, PlgBlt.offBmiMask, PlgBlt.cbBmiMask, PlgBlt.offBitsMask, PlgBlt.cbBitsMask);
      end;
  else
    Exit;
  end;

  EmitImagePrimitive(Points, Counts, Image, ARecord.iType, RecordName(ARecord.iType));
end;

procedure TMetafileParser.HandleSetPixelV(ARecord: PEnhMetaRecord);
var
  R: PEMRSetPixelVLocal;
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
  Fill, OldFill: TMetafileFillStyle;
begin
  if not RecordBytesAvailable(ARecord, 0, SizeOf(TEMRSetPixelVLocal)) then
    Exit;

  R := PEMRSetPixelVLocal(ARecord);
  SetLength(Points, 5);
  Points[0] := LogicalToOutput(R.ptlPixel);
  Points[1] := LogicalToOutput(R.ptlPixel.X + 1, R.ptlPixel.Y);
  Points[2] := LogicalToOutput(R.ptlPixel.X + 1, R.ptlPixel.Y + 1);
  Points[3] := LogicalToOutput(R.ptlPixel.X, R.ptlPixel.Y + 1);
  Points[4] := Points[0];
  SetLength(Counts, 1);
  Counts[0] := Length(Points);

  Fill := CurrentFill;
  Fill.Visible := True;
  Fill.Kind := mfkSolid;
  Fill.Color := TColor(R.crColor);
  Fill.Style := BS_SOLID;
  Fill.Hatch := 0;
  Fill.Brush.Kind := mbdkNone;
  Fill.Brush.Usage := 0;
  SetLength(Fill.Brush.BitmapInfo, 0);
  SetLength(Fill.Brush.Bits, 0);
  Fill.Gradient.Kind := mgkNone;
  Fill.Gradient.Mode := 0;
  SetLength(Fill.Gradient.Vertices, 0);
  SetLength(Fill.Gradient.Meshes, 0);

  OldFill := DCStateOf(Self).State.Fill;
  try
    DCStateOf(Self).State.Fill := CopyFillStyle(Fill);
    EmitPrimitive(mpkPolygon, Points, Counts, '', ARecord.iType, RecordName(ARecord.iType), False, True);
  finally
    DCStateOf(Self).State.Fill := OldFill;
  end;
end;

procedure TMetafileParser.HandleCreatePen(ARecord: PEnhMetaRecord);
var
  R: PEMRCreatePen;
  Obj: TMetaObject;
begin
  R := PEMRCreatePen(ARecord);
  FillChar(Obj, SizeOf(Obj), 0);
  Obj.Active := True;
  Obj.Kind := mokPen;
  Obj.Stroke.Visible := (R.lopn.lopnStyle and PS_STYLE_MASK_LOCAL) <> PS_NULL;
  Obj.Stroke.Color := R.lopn.lopnColor;
  Obj.Stroke.Hairline:=R.lopn.lopnWidth.X=0;
  Obj.Stroke.Width := R.lopn.lopnWidth.X;
  if Obj.Stroke.Width <= 0 then
    Obj.Stroke.Width := 1;
  Obj.Stroke.Style := R.lopn.lopnStyle;
  Obj.Stroke.EndCap := R.lopn.lopnStyle and PS_ENDCAP_MASK;
  Obj.Stroke.Join := R.lopn.lopnStyle and PS_JOIN_MASK;
  Obj.Stroke.MiterLimit := DCStateOf(Self).State.MiterLimit;
  DCStateOf(Self).SetObject(R.ihPen, Obj);
end;

procedure TMetafileParser.HandleExtCreatePen(ARecord: PEnhMetaRecord);
var
  R: PEMRExtCreatePenLocal;
  Obj: TMetaObject;
begin
  R := PEMRExtCreatePenLocal(ARecord);
  FillChar(Obj, SizeOf(Obj), 0);
  Obj.Active := True;
  Obj.Kind := mokPen;
  Obj.Stroke.Visible := (R.elp.elpPenStyle and PS_STYLE_MASK_LOCAL) <> PS_NULL;
  Obj.Stroke.Color := R.elp.elpColor;
  Obj.Stroke.Hairline:=(R.elp.elpPenStyle and PS_GEOMETRIC)=0;
  Obj.Stroke.Width := R.elp.elpWidth;
  if Obj.Stroke.Width <= 0 then
    Obj.Stroke.Width := 1;
  Obj.Stroke.Style := R.elp.elpPenStyle;
  Obj.Stroke.BrushStyle:=R.elp.elpBrushStyle;
  Obj.Stroke.Hatch:=R.elp.elpHatch;
  Obj.Stroke.EndCap := R.elp.elpPenStyle and PS_ENDCAP_MASK;
  Obj.Stroke.Join := R.elp.elpPenStyle and PS_JOIN_MASK;
  Obj.Stroke.MiterLimit := DCStateOf(Self).State.MiterLimit;
  if (R.cbBmi > 0) or (R.cbBits > 0) then
  begin
    Obj.Stroke.Brush.Kind := mbdkExtPenPattern;
    Obj.Stroke.Brush.Usage := R.elp.elpColor and $FFFF;
    if not ReadRecordBytes(ARecord, R.offBmi, R.cbBmi, Obj.Stroke.Brush.BitmapInfo) then
      Exit;
    if not ReadRecordBytes(ARecord, R.offBits, R.cbBits, Obj.Stroke.Brush.Bits) then
      Exit;
    NormalizeMetafileDIB(Obj.Stroke.Brush.BitmapInfo,Obj.Stroke.Brush.Bits,Obj.Stroke.Brush.Usage);
  end;
  DCStateOf(Self).SetObject(R.ihPen, Obj);
end;

procedure TMetafileParser.HandleCreateBrush(ARecord: PEnhMetaRecord);
var
  R: PEMRCreateBrushIndirect;
  Obj: TMetaObject;
begin
  R := PEMRCreateBrushIndirect(ARecord);
  FillChar(Obj, SizeOf(Obj), 0);
  Obj.Active := True;
  Obj.Kind := mokBrush;
  Obj.Fill.Visible := (R.lb.lbStyle<>BS_NULL);
  Obj.Fill.Color := R.lb.lbColor;
  Obj.Fill.Style := R.lb.lbStyle;
  Obj.Fill.Hatch := R.lb.lbHatch;
  Obj.Fill.FillMode := DCStateOf(Self).State.PolyFillMode;
  case R.lb.lbStyle of
    BS_NULL:
      Obj.Fill.Kind := mfkNone;
    BS_HATCHED:
      Obj.Fill.Kind := mfkHatch;
    BS_PATTERN, BS_DIBPATTERN, BS_DIBPATTERNPT:
      Obj.Fill.Kind := mfkPattern;
  else
    Obj.Fill.Kind := mfkSolid;
  end;
  DCStateOf(Self).SetObject(R.ihBrush, Obj);
end;

procedure TMetafileParser.HandleCreateMonoBrush(ARecord: PEnhMetaRecord);
var
  R: PEMRCreateMonoBrush;
  Obj: TMetaObject;
begin
  R := PEMRCreateMonoBrush(ARecord);
  FillChar(Obj, SizeOf(Obj), 0);
  Obj.Active := True;
  Obj.Kind := mokBrush;
  Obj.Fill.Kind := mfkPattern;
  Obj.Fill.Visible := True;
  Obj.Fill.Style := BS_PATTERN;
  Obj.Fill.FillMode := DCStateOf(Self).State.PolyFillMode;
  Obj.Fill.Brush.Kind := mbdkMonoPattern;
  Obj.Fill.Brush.Usage := R.iUsage;
  if not ReadRecordBytes(ARecord, R.offBmi, R.cbBmi, Obj.Fill.Brush.BitmapInfo) then
    Exit;
  if not ReadRecordBytes(ARecord, R.offBits, R.cbBits, Obj.Fill.Brush.Bits) then
    Exit;
  DCStateOf(Self).SetObject(R.ihBrush, Obj);
end;

procedure TMetafileParser.HandleCreateDibPatternBrush(ARecord: PEnhMetaRecord);
var
  R: PEMRCreateDIBPatternBrushPt;
  Obj: TMetaObject;
begin
  R := PEMRCreateDIBPatternBrushPt(ARecord);
  FillChar(Obj, SizeOf(Obj), 0);
  Obj.Active := True;
  Obj.Kind := mokBrush;
  Obj.Fill.Kind := mfkPattern;
  Obj.Fill.Visible := True;
  Obj.Fill.Style := BS_DIBPATTERNPT;
  Obj.Fill.FillMode := DCStateOf(Self).State.PolyFillMode;
  Obj.Fill.Brush.Kind := mbdkDibPattern;
  Obj.Fill.Brush.Usage := R.iUsage;
  if not ReadRecordBytes(ARecord, R.offBmi, R.cbBmi, Obj.Fill.Brush.BitmapInfo) then
    Exit;
  if not ReadRecordBytes(ARecord, R.offBits, R.cbBits, Obj.Fill.Brush.Bits) then
    Exit;
  DCStateOf(Self).SetObject(R.ihBrush, Obj);
end;

procedure TMetafileParser.HandleCreateFont(ARecord: PEnhMetaRecord);
var
  R: PEMRExtCreateFontIndirect;
  Obj: TMetaObject;
begin
  R := PEMRExtCreateFontIndirect(ARecord);
  FillChar(Obj, SizeOf(Obj), 0);
  Obj.Active := True;
  Obj.Kind := mokFont;
  Obj.Font := R.elfw.elfLogFont;
  DCStateOf(Self).SetObject(R.ihFont, Obj);
end;

procedure TMetafileParser.HandleHeader(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).ApplyHeader(PEMRHeaderLocal(ARecord)^);
end;

procedure TMetafileParser.HandleSetMapMode(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.MapMode := PEMRSetLong(ARecord).Value;
end;

procedure TMetafileParser.HandleSetWindowExt(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.WindowExt := PEMRSetSize(ARecord).Size;
end;

procedure TMetafileParser.HandleSetWindowOrg(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.WindowOrg := PEMRSetPoint(ARecord).Point;
end;

procedure TMetafileParser.HandleSetViewportExt(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.ViewportExt := PEMRSetSize(ARecord).Size;
end;

procedure TMetafileParser.HandleSetViewportOrg(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.ViewportOrg := PEMRSetPoint(ARecord).Point;
end;

procedure TMetafileParser.HandleScaleWindowExt(ARecord: PEnhMetaRecord);
var
  R: PEMRScaleExt;
begin
  R := PEMRScaleExt(ARecord);
  if (R.xDenom <> 0) and (R.yDenom <> 0) then
  begin
    DCStateOf(Self).State.WindowExt.cx := Round(DCStateOf(Self).State.WindowExt.cx * R.xNum / R.xDenom);
    DCStateOf(Self).State.WindowExt.cy := Round(DCStateOf(Self).State.WindowExt.cy * R.yNum / R.yDenom);
  end;
end;

procedure TMetafileParser.HandleScaleViewportExt(ARecord: PEnhMetaRecord);
var
  R: PEMRScaleExt;
begin
  R := PEMRScaleExt(ARecord);
  if (R.xDenom <> 0) and (R.yDenom <> 0) then
  begin
    DCStateOf(Self).State.ViewportExt.cx := Round(DCStateOf(Self).State.ViewportExt.cx * R.xNum / R.xDenom);
    DCStateOf(Self).State.ViewportExt.cy := Round(DCStateOf(Self).State.ViewportExt.cy * R.yNum / R.yDenom);
  end;
end;

procedure TMetafileParser.HandleSetWorldTransform(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.WorldTransform := PEMRWorldTransformLocal(ARecord).XForm;
end;

procedure TMetafileParser.HandleModifyWorldTransform(ARecord: PEnhMetaRecord);
var
  R: PEMRModifyWorldTransformLocal;
begin
  R := PEMRModifyWorldTransformLocal(ARecord);
  case R.iMode of
    MWT_IDENTITY:
      DCStateOf(Self).State.WorldTransform := XFormIdentity;
    MWT_LEFTMULTIPLY:
      DCStateOf(Self).State.WorldTransform := MultiplyXForm(R.XForm, DCStateOf(Self).State.WorldTransform);
    MWT_RIGHTMULTIPLY:
      DCStateOf(Self).State.WorldTransform := MultiplyXForm(DCStateOf(Self).State.WorldTransform, R.XForm);
    MWT_SET_LOCAL:
      DCStateOf(Self).State.WorldTransform := R.XForm;
  end;
end;

procedure TMetafileParser.HandleSetColorText(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.TextColor := PEMRSetTextColor(ARecord).crColor;
end;

procedure TMetafileParser.HandleSetBkColor(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.BkColor := PEMRSetTextColor(ARecord).crColor;
end;

procedure TMetafileParser.HandleSetBkMode(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.BkMode := PEMRSetLong(ARecord).Value;
end;

procedure TMetafileParser.HandleSetTextAlign(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.TextAlign := PEMRSetLong(ARecord).Value;
end;

procedure TMetafileParser.HandleSetTextJustification(ARecord: PEnhMetaRecord);
var
  R: PEMRSetTextJustificationLocal;
begin
  R := PEMRSetTextJustificationLocal(ARecord);
  DCStateOf(Self).SetTextJustification(R.nBreakExtra, R.nBreakCount);
end;

procedure TMetafileParser.HandleSetPolyFillMode(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.PolyFillMode := PEMRSetLong(ARecord).Value;
end;

procedure TMetafileParser.HandleSetArcDirection(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.ArcDirection := PEMRSetLong(ARecord).Value;
end;

procedure TMetafileParser.HandleSetMiterLimit(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.MiterLimit := PEMRSetMiterLimitLocal(ARecord).eMiterLimit;
end;

procedure TMetafileParser.HandleSetRop2(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.RasterOperation2 := PEMRSetLong(ARecord).Value;
end;

procedure TMetafileParser.HandleSetStretchMode(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.StretchMode := PEMRSetLong(ARecord).Value;
end;

procedure TMetafileParser.HandleSetBrushOrigin(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.BrushOrigin := PEMRSetPoint(ARecord).Point;
end;

procedure TMetafileParser.HandleSetLayout(ARecord: PEnhMetaRecord);
begin
  DCStateOf(Self).State.Layout := PEMRSetLong(ARecord).Value;
end;

function TMetafileParser.EnumRecord(ADC: HDC; ARecord: PEnhMetaRecord): Integer;
var
  Points: TMetafilePointArray;
  Counts: TMetafileIntegerArray;
begin
  Result := 1;
  if (ARecord = nil) or (ARecord.nSize < SizeOf(TEMR)) then
    Exit;
  Inc(FRecordIndex);
  DCStateOf(Self).State.CurrentPos := DCStateOf(Self).State.NextPos;

  case ARecord.iType of
    EMR_HEADER:
      HandleHeader(ARecord);
    EMR_SETMAPMODE:
      HandleSetMapMode(ARecord);
    EMR_SETWINDOWEXTEX:
      HandleSetWindowExt(ARecord);
    EMR_SETWINDOWORGEX:
      HandleSetWindowOrg(ARecord);
    EMR_SETVIEWPORTEXTEX:
      HandleSetViewportExt(ARecord);
    EMR_SETVIEWPORTORGEX:
      HandleSetViewportOrg(ARecord);
    EMR_SCALEWINDOWEXTEX:
      HandleScaleWindowExt(ARecord);
    EMR_SCALEVIEWPORTEXTEX:
      HandleScaleViewportExt(ARecord);
    EMR_SETWORLDTRANSFORM:
      HandleSetWorldTransform(ARecord);
    EMR_MODIFYWORLDTRANSFORM:
      HandleModifyWorldTransform(ARecord);
    EMR_SETROP2:
      HandleSetRop2(ARecord);
    EMR_SETSTRETCHBLTMODE:
      HandleSetStretchMode(ARecord);
    EMR_SETBRUSHORGEX:
      HandleSetBrushOrigin(ARecord);
    EMR_SETLAYOUT_LOCAL:
      HandleSetLayout(ARecord);
    EMR_SAVEDC:
      SaveState;
    EMR_RESTOREDC:
      RestoreState(PEMRRestoreDCLocal(ARecord).iRelative);
    EMR_SELECTOBJECT:
      SelectObjectHandle(PEMRSelectObject(ARecord).ihObject);
    EMR_DELETEOBJECT:
      DeleteObjectHandle(PEMRSelectObject(ARecord).ihObject);
    EMR_CREATEPEN:
      HandleCreatePen(ARecord);
    EMR_EXTCREATEPEN:
      HandleExtCreatePen(ARecord);
    EMR_CREATEBRUSHINDIRECT:
      HandleCreateBrush(ARecord);
    EMR_CREATEMONOBRUSH:
      HandleCreateMonoBrush(ARecord);
    EMR_CREATEDIBPATTERNBRUSHPT:
      HandleCreateDibPatternBrush(ARecord);
    EMR_EXTCREATEFONTINDIRECTW:
      HandleCreateFont(ARecord);
    EMR_SETTEXTCOLOR:
      HandleSetColorText(ARecord);
    EMR_SETBKCOLOR:
      HandleSetBkColor(ARecord);
    EMR_SETBKMODE:
      HandleSetBkMode(ARecord);
    EMR_SETTEXTALIGN:
      HandleSetTextAlign(ARecord);
    EMR_SETTEXTJUSTIFICATION:
      HandleSetTextJustification(ARecord);
    EMR_SETPOLYFILLMODE:
      HandleSetPolyFillMode(ARecord);
    EMR_SETARCDIRECTION:
      HandleSetArcDirection(ARecord);
    EMR_SETMITERLIMIT:
      HandleSetMiterLimit(ARecord);

    EMR_GRADIENTFILL:
      HandleGradientFill(ARecord);
    EMR_SETPIXELV:
      HandleSetPixelV(ARecord);
    EMR_BITBLT, EMR_STRETCHBLT, EMR_MASKBLT, EMR_SETDIBITSTODEVICE, EMR_STRETCHDIBITS, EMR_ALPHABLEND, EMR_TRANSPARENTBLT, EMR_PLGBLT:
      HandleRasterRecord(ARecord);

    EMR_MOVETOEX:
      HandleMoveTo(ARecord);
    EMR_LINETO:
      HandleLineTo(ARecord);
    EMR_POLYLINE:
      HandlePolyline32(ARecord, False);
    EMR_POLYGON:
      HandlePolyline32(ARecord, True);
    EMR_POLYLINE16:
      HandlePolyline16(ARecord, False);
    EMR_POLYGON16:
      HandlePolyline16(ARecord, True);
    EMR_POLYPOLYLINE:
      HandlePolyPolyline32(ARecord, False);
    EMR_POLYPOLYGON:
      HandlePolyPolyline32(ARecord, True);
    EMR_POLYPOLYLINE16:
      HandlePolyPolyline16(ARecord, False);
    EMR_POLYPOLYGON16:
      HandlePolyPolyline16(ARecord, True);
    EMR_POLYLINETO:
      HandlePolylineTo32(ARecord);
    EMR_POLYLINETO16:
      HandlePolylineTo16(ARecord);
    EMR_POLYBEZIER:
      HandlePolyBezier32(ARecord, False);
    EMR_POLYBEZIERTO:
      HandlePolyBezier32(ARecord, True);
    EMR_POLYBEZIER16:
      HandlePolyBezier16(ARecord, False);
    EMR_POLYBEZIERTO16:
      HandlePolyBezier16(ARecord, True);
    EMR_POLYDRAW:
      HandlePolyDraw32(ARecord);
    EMR_POLYDRAW16:
      HandlePolyDraw16(ARecord);
    EMR_RECTANGLE:
      HandleRectangle(ARecord);
    EMR_ELLIPSE:
      HandleEllipse(ARecord);
    EMR_ROUNDRECT:
      HandleRoundRect(ARecord);
    EMR_ARC, EMR_ARCTO, EMR_CHORD, EMR_PIE:
      HandleArcLike(ARecord, ARecord.iType);
    EMR_ANGLEARC:
      HandleAngleArc(ARecord);
    EMR_EXTTEXTOUTA:
      HandleTextOut(ARecord, False);
    EMR_EXTTEXTOUTW:
      HandleTextOut(ARecord, True);
    EMR_SMALLTEXTOUT:
      HandleSmallTextOut(ARecord);
    EMR_POLYTEXTOUTA:
      HandlePolyTextOut(ARecord, False);
    EMR_POLYTEXTOUTW:
      HandlePolyTextOut(ARecord, True);
    EMR_EXTSELECTCLIPRGN:
      HandleExtSelectClipRegion(ARecord);
    EMR_INTERSECTCLIPRECT:
      HandleClipRect(ARecord, RGN_AND);
    EMR_EXCLUDECLIPRECT:
      HandleClipRect(ARecord, RGN_DIFF);
    EMR_OFFSETCLIPRGN:
      HandleOffsetClipRegion(ARecord);
    EMR_FILLRGN:
      HandleFillRegion(ARecord, False);
    EMR_FRAMERGN:
      HandleFillRegion(ARecord, True);
    EMR_INVERTRGN, EMR_PAINTRGN:
      HandlePaintOrInvertRegion(ARecord);

    EMR_BEGINPATH:
      PathBuilderOf(Self).BeginPath;
    EMR_ENDPATH:
      PathBuilderOf(Self).EndPath;
    EMR_CLOSEFIGURE:
      PathCloseFigure;
    EMR_ABORTPATH:
      ClearPath;
    EMR_FLATTENPATH:
      ;
    EMR_WIDENPATH:
      HandleWidenPath(ARecord);
    EMR_FILLPATH:
      if PathBuilderOf(Self).HasData then
        EmitPath(ARecord.iType, RecordName(ARecord.iType), False, True);
    EMR_STROKEPATH:
      if PathBuilderOf(Self).HasData then
        EmitPath(ARecord.iType, RecordName(ARecord.iType), True, False);
    EMR_STROKEANDFILLPATH:
      if PathBuilderOf(Self).HasData then
        EmitPath(ARecord.iType, RecordName(ARecord.iType), True, True);
    EMR_SELECTCLIPPATH:
      begin
        if PathBuilderOf(Self).Build(Points, Counts) then
          DCStateOf(Self).SetClipRegion(Points, Counts, PEMRSelectClipPathLocal(ARecord).iMode);
        ClearPath;
      end;
  end;
end;

function TMetafileParser.CurrentTextToFlatPolygons(out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
begin
  Result := False;
  SetLength(APoints, 0);
  SetLength(APointCounts, 0);
  if (FCurrent = nil) or (FCurrent.Kind <> mpkText) then
    Exit;
  if Length(FCurrent.Points) = 0 then
    Exit;
  Result := CurrentTextToFlatPolygonsInternal(FCurrent.Text, FCurrent.Points[0], FCurrent.TextStyle.Font, nil, 0, FCurrent.TextStyle.Dx, FCurrent.TextStyle.Dy, FCurrent.TextStyle.Options, APoints,
    APointCounts);
end;

function TMetafileParser.CurrentTextToFlatPolygonsInternal(const AText: UnicodeString; const AOrigin: TMetafilePoint; const ALogFont: TLogFontW; AGlyphIndexes: PWord; AGlyphCount: Integer;
  const ADx, ADy: TMetafileIntegerArray; AOptions: Cardinal; out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
var
  EffectiveFlatness: Double;
begin
  EffectiveFlatness := FTextFlatness;
  if EffectiveFlatness <= 0 then
    EffectiveFlatness := FFlatness;
  Result := TextOutlineConverterOf(Self).TextToFlatPolygons(AText, AOrigin, ALogFont, AGlyphIndexes, AGlyphCount, ADx, ADy, AOptions, DCStateOf(Self), EffectiveFlatness, APoints,
    APointCounts);
end;

function TMetafileTextOutlineConverter.TextToFlatPolygons(const AText: UnicodeString; const AOrigin: TMetafilePoint; const ALogFont: TLogFontW; AGlyphIndexes: PWord; AGlyphCount: Integer;
  const ADx, ADy: TMetafileIntegerArray; AOptions: Cardinal; ADCState: TMetafileDCState; AFlatness: Double; out APoints: TMetafilePointArray; out APointCounts: TMetafileIntegerArray): Boolean;
var
  DC: HDC;
  Font, OldFont: HFONT;
  Mat: TMat2;
  GM: TGlyphMetrics;
  I, GlyphIndex: Integer;
  BufSize: DWORD;
  Glyph: Word;
  GlyphBuf: Pointer;
  PenX, PenY: Double;
  OutlineLogFont, DefaultFont: TLogFontW;
  OriginalHeight: Integer;
  ScaleX, ScaleY: Double;
  Angle, SinAngle, CosAngle: Double;

  function Fx(Value: SmallInt; Fract: Word): Double;
  begin
    Result := Value + Fract / 65536.0;
  end;

  function GlyphPoint(const P: TPointFX): TMetafilePoint;
  var
    D: TMetafilePoint;
    LocalX, LocalY, RotX, RotY: Double;
  begin
    LocalX := PenX + Fx(P.X.Value, P.X.Fract) * ScaleX;
    LocalY := PenY - Fx(P.Y.Value, P.Y.Fract) * ScaleY;
    RotX := LocalX * CosAngle - LocalY * SinAngle;
    RotY := LocalX * SinAngle + LocalY * CosAngle;
    D := ADCState.LogicalDeltaToOutput(RotX, RotY);
    Result.X := AOrigin.X + D.X;
    Result.Y := AOrigin.Y + D.Y;
  end;

  function JustificationExtraForGlyph(AIndex: Integer): Double;
  begin
    Result := 0;
    if (Length(ADx) > 0) or (ADCState.State.TextJustificationBreakCount <= 0) then
      Exit;
    if (AGlyphCount = 0) and (AIndex >= 0) and (AIndex < Length(AText)) and (AText[AIndex + 1] = ' ') then
      Result := ADCState.State.TextJustificationBreakExtra / ADCState.State.TextJustificationBreakCount;
  end;

  procedure ParseNativeGlyph(ABuffer: Pointer; ASize: Integer);
  var
    P, EndP, PolyEnd: PByte;
    PH: PTTPolygonHeader;
    PC: PTTPolyCurve;
    Current, Flat: TMetafilePointArray;
    J, K: Integer;
    P0, P1, P2, P3, Mid: TMetafilePoint;
  begin
    P := PByte(ABuffer);
    EndP := PByte(PtrOffset(ABuffer, ASize));
    while NativeUInt(P) + SizeOf(TTPolygonHeader) <= NativeUInt(EndP) do
    begin
      PH := PTTPolygonHeader(P);
      if (PH.dwType <> TT_POLYGON_TYPE) or (PH.cb < DWORD(SizeOf(TTPolygonHeader))) then
        Break;
      PolyEnd := PByte(PtrOffset(PH, PH.cb));
      if NativeUInt(PolyEnd) > NativeUInt(EndP) then
        Break;

      SetLength(Current, 0);
      AppendPoint(Current, GlyphPoint(PH.pfxStart));
      P := PByte(PtrOffset(P, SizeOf(TTPolygonHeader)));
      while NativeUInt(P) + SizeOf(Word) * 2 <= NativeUInt(PolyEnd) do
      begin
        PC := PTTPolyCurve(P);
        if PC.cpfx = 0 then
          Break;
        if NativeUInt(P) + SizeOf(Word) * 2 + NativeUInt(PC.cpfx) * SizeOf(TPointFX) > NativeUInt(PolyEnd) then
          Break;

        case PC.wType of
          TT_PRIM_LINE:
            for J := 0 to PC.cpfx - 1 do
              AppendPoint(Current, GlyphPoint(PC.apfx[J]));
          TT_PRIM_QSPLINE:
            begin
              for J := 0 to PC.cpfx - 2 do
              begin
                P0 := Current[High(Current)];
                P1 := GlyphPoint(PC.apfx[J]);
                if J < PC.cpfx - 2 then
                begin
                  P2 := GlyphPoint(PC.apfx[J + 1]);
                  Mid := TMetafileParser.Point((P1.X + P2.X) * 0.5, (P1.Y + P2.Y) * 0.5);
                  P2 := Mid;
                end
                else
                  P2 := GlyphPoint(PC.apfx[J + 1]);
                Flat := TMetafileParser.QuadraticBezierToFlatPolyline(P0, P1, P2, AFlatness);
                AppendPoints(Current, Flat, True);
              end;
            end;
          TT_PRIM_CSPLINE_LOCAL:
            begin
              K := 0;
              while K + 2 < PC.cpfx do
              begin
                P0 := Current[High(Current)];
                P1 := GlyphPoint(PC.apfx[K]);
                P2 := GlyphPoint(PC.apfx[K + 1]);
                P3 := GlyphPoint(PC.apfx[K + 2]);
                Flat := TMetafileParser.CubicBezierToFlatPolyline(P0, P1, P2, P3, AFlatness);
                AppendPoints(Current, Flat, True);
                Inc(K, 3);
              end;
            end;
        end;
        P := PByte(PtrOffset(P, SizeOf(Word) * 2 + NativeUInt(PC.cpfx) * SizeOf(TPointFX)));
      end;

      if (Length(Current) > 1) and not PointsAlmostEqual(Current[0], Current[High(Current)]) then
        AppendPoint(Current, Current[0]);
      AppendCount(APointCounts, Length(Current));
      AppendPoints(APoints, Current, False);
      P := PolyEnd;
    end;
  end;

begin
  Result := False;
  SetLength(APoints, 0);
  SetLength(APointCounts, 0);
  if ADCState = nil then
    Exit;
  if (AText = '') and (AGlyphCount <= 0) then
    Exit;

  DC := CreateCompatibleDC(0);
  if DC = 0 then
    Exit;
  Font := 0;
  OldFont := 0;
  try
    OriginalHeight := Abs(ALogFont.lfHeight);
    if OriginalHeight = 0 then
      OriginalHeight := 12;
    ScaleX := OriginalHeight / TEXT_OUTLINE_EM_SIZE;
    ScaleY := ScaleX;
    Angle := DegToRad(ALogFont.lfEscapement / 10);
    SinAngle := Sin(Angle);
    CosAngle := Cos(Angle);

    OutlineLogFont := ALogFont;
    if NeedsOutlineTextFallback(OutlineLogFont) then
    begin
      DefaultFont := DefaultTextLogFont;
      Move(DefaultFont.lfFaceName[0], OutlineLogFont.lfFaceName[0], SizeOf(OutlineLogFont.lfFaceName));
      if OutlineLogFont.lfCharSet = 0 then
        OutlineLogFont.lfCharSet := DefaultFont.lfCharSet;
      if OutlineLogFont.lfPitchAndFamily = 0 then
        OutlineLogFont.lfPitchAndFamily := DefaultFont.lfPitchAndFamily;
    end;
    if ALogFont.lfHeight <= 0 then
      OutlineLogFont.lfHeight := -TEXT_OUTLINE_EM_SIZE
    else
      OutlineLogFont.lfHeight := TEXT_OUTLINE_EM_SIZE;
    if ALogFont.lfWidth <> 0 then
    begin
      OutlineLogFont.lfWidth := Round(ALogFont.lfWidth * (TEXT_OUTLINE_EM_SIZE / OriginalHeight));
      if OutlineLogFont.lfWidth = 0 then
      begin
        if ALogFont.lfWidth < 0 then
          OutlineLogFont.lfWidth := -1
        else
          OutlineLogFont.lfWidth := 1;
      end;
    end;
    OutlineLogFont.lfOutPrecision := OUT_OUTLINE_PRECIS;
    if OutlineLogFont.lfQuality = DEFAULT_QUALITY then
      OutlineLogFont.lfQuality := PROOF_QUALITY;
    OutlineLogFont.lfEscapement := 0;
    OutlineLogFont.lfOrientation := 0;

    Font := CreateFontIndirectW(OutlineLogFont);
    if Font = 0 then
      Exit;
    OldFont := SelectObject(DC, Font);

    Mat.eM11.Value := 1;
    Mat.eM11.Fract := 0;
    Mat.eM12.Value := 0;
    Mat.eM12.Fract := 0;
    Mat.eM21.Value := 0;
    Mat.eM21.Fract := 0;
    Mat.eM22.Value := 1;
    Mat.eM22.Fract := 0;

    PenX := 0;
    PenY := 0;
    if AGlyphCount > 0 then
      GlyphIndex := AGlyphCount
    else
      GlyphIndex := Length(AText);

    for I := 0 to GlyphIndex - 1 do
    begin
      if AGlyphCount > 0 then
        Glyph := AGlyphIndexes^
      else
        Glyph := Word(AText[I + 1]);

      FillChar(GM, SizeOf(GM), 0);
      if AGlyphCount > 0 then
        BufSize := GetGlyphOutlineW(DC, Glyph, GGO_NATIVE or GGO_GLYPH_INDEX or GGO_UNHINTED_LOCAL, {$IFDEF FPC}@GM{$ELSE}GM{$ENDIF}, 0, nil, {$IFDEF FPC}@Mat{$ELSE}Mat{$ENDIF})
      else
        BufSize := GetGlyphOutlineW(DC, Glyph, GGO_NATIVE or GGO_UNHINTED_LOCAL, {$IFDEF FPC}@GM{$ELSE}GM{$ENDIF}, 0, nil, {$IFDEF FPC}@Mat{$ELSE}Mat{$ENDIF});

      if (BufSize > 0) and (BufSize <> GDI_ERROR) then
      begin
        GetMem(GlyphBuf, BufSize);
        try
          if AGlyphCount > 0 then
            BufSize := GetGlyphOutlineW(DC, Glyph, GGO_NATIVE or GGO_GLYPH_INDEX or GGO_UNHINTED_LOCAL, {$IFDEF FPC}@GM{$ELSE}GM{$ENDIF}, BufSize, GlyphBuf, {$IFDEF FPC}@Mat{$ELSE}Mat{$ENDIF})
          else
            BufSize := GetGlyphOutlineW(DC, Glyph, GGO_NATIVE or GGO_UNHINTED_LOCAL, {$IFDEF FPC}@GM{$ELSE}GM{$ENDIF}, BufSize, GlyphBuf, {$IFDEF FPC}@Mat{$ELSE}Mat{$ENDIF});
          if (BufSize > 0) and (BufSize <> GDI_ERROR) then
            ParseNativeGlyph(GlyphBuf, BufSize);
        finally
          FreeMem(GlyphBuf);
        end;
      end;

      if I <= High(ADx) then
      begin
        PenX := PenX + ADx[I];
        if ((AOptions and ETO_PDY) <> 0) and (I <= High(ADy)) then
          PenY := PenY + ADy[I];
      end
      else
      begin
        PenX := PenX + GM.gmCellIncX * ScaleX + JustificationExtraForGlyph(I);
        PenY := PenY + GM.gmCellIncY * ScaleY;
      end;
      if AGlyphCount > 0 then
        Inc(AGlyphIndexes);
    end;
    Result := Length(APoints) > 0;
  finally
    if OldFont <> 0 then
      SelectObject(DC, OldFont);
    if Font <> 0 then
      DeleteObject(Font);
    DeleteDC(DC);
  end;
end;


{$I MetafileParser.Replay.inc}

end.
