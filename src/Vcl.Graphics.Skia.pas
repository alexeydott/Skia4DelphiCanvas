/// <summary>
/// Skia-backed VCL canvases for raster/vector drawing.
/// </summary>
unit Vcl.Graphics.Skia;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$IFDEF FPC}{$MODESWITCH ANONYMOUSFUNCTIONS}{$MODESWITCH FUNCTIONREFERENCES}{$ENDIF}
{$POINTERMATH ON}
{$IFDEF FPC}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  Classes, SysUtils, Types, Math,
  Generics.Collections, SyncObjs,
  System.UITypes, {$IFNDEF FPC}System.Math.Vectors, {$ENDIF}
{$IFDEF MSWINDOWS}{$IFDEF FPC}Windows, {$ELSE}Winapi.Windows, {$ENDIF}{$ELSE}LCLType, {$ENDIF} Vcl.Graphics, System.Skia;

type
  { Exact aliases preserve type identity with the native VCL and Skia APIs. }
  TBitmap = Vcl.Graphics.TBitmap;
  TBrush = Vcl.Graphics.TBrush;
  TPen = Vcl.Graphics.TPen;
  TFont = Vcl.Graphics.TFont;
  TGraphic = Vcl.Graphics.TGraphic;
  TPicture = Vcl.Graphics.TPicture;
  TIcon = Vcl.Graphics.TIcon;
{$IFDEF MSWINDOWS}
  TMetafile = Vcl.Graphics.TMetafile;
  TMetafileCanvas = Vcl.Graphics.TMetafileCanvas;
{$ENDIF}
  TCanvas = Vcl.Graphics.TCanvas;
  TCustomCanvas = Vcl.Graphics.TCustomCanvas;
  TColor = Vcl.Graphics.TColor;
  TPenStyle = Vcl.Graphics.TPenStyle;
  TPenMode = Vcl.Graphics.TPenMode;
  TBrushStyle = Vcl.Graphics.TBrushStyle;
  TFontStyle = Vcl.Graphics.TFontStyle;
  TFontStyles = Vcl.Graphics.TFontStyles;
  TFontCharset = Vcl.Graphics.TFontCharset;
  TFontPitch = Vcl.Graphics.TFontPitch;
  TCopyMode = Vcl.Graphics.TCopyMode;
  TFillStyle = Vcl.Graphics.TFillStyle;
  TPixelFormat = Vcl.Graphics.TPixelFormat;
  TAlphaFormat = Vcl.Graphics.TAlphaFormat;
  TCanvasStates = Vcl.Graphics.TCanvasStates;
  TCanvasState = Vcl.Graphics.TCanvasState;
  TCanvasOrientation = Vcl.Graphics.TCanvasOrientation;
  TTextFormats = Vcl.Graphics.TTextFormats;
  TTextFormat = Vcl.Graphics.TTextFormat;

  TAlphaColor = System.UITypes.TAlphaColor;
  TAlphaColorRec = System.UITypes.TAlphaColorRec;
  TPoint = Types.TPoint;
  TPointF = Types.TPointF;
  TRect = Types.TRect;
  TRectF = Types.TRectF;
  TSize = Types.TSize;
  TSizeF = Types.TSizeF;
{$IFDEF FPC}
  TMatrix = System.Skia.TMatrix;
  TVector = System.Skia.TVector;
{$ELSE}
  TMatrix = System.Math.Vectors.TMatrix;
  TVector = System.Math.Vectors.TVector;
{$ENDIF}

  { Compilers do not propagate record helpers through type aliases. }
  TSkiaMatrixConstants = record helper for TMatrix
  const
    Identity: TMatrix = (M11: 1; M12: 0; M13: 0; M21: 0; M22: 1; M23: 0; M31: 0; M32: 0; M33: 1);
  end;

  ISkCanvas = System.Skia.ISkCanvas;
  ISkSurface = System.Skia.ISkSurface;
  ISkImage = System.Skia.ISkImage;
  ISkPaint = System.Skia.ISkPaint;
  ISkFont = System.Skia.ISkFont;
  ISkTypeface = System.Skia.ISkTypeface;
  ISkPath = System.Skia.ISkPath;
  ISkPathBuilder = System.Skia.ISkPathBuilder;
  ISkPathEffect = System.Skia.ISkPathEffect;
  ISkShader = System.Skia.ISkShader;
  ISkColorFilter = System.Skia.ISkColorFilter;
  ISkImageFilter = System.Skia.ISkImageFilter;
  ISkPicture = System.Skia.ISkPicture;
  ISkPictureRecorder = System.Skia.ISkPictureRecorder;
  ISkRegion = System.Skia.ISkRegion;
  ISkRoundRect = System.Skia.ISkRoundRect;
  ISkTextBlob = System.Skia.ISkTextBlob;
  ISkShaper = System.Skia.ISkShaper;
  ISkParagraph = System.Skia.ISkParagraph;
  ISkParagraphBuilder = System.Skia.ISkParagraphBuilder;
  ISkParagraphStyle = System.Skia.ISkParagraphStyle;
  ISkTextStyle = System.Skia.ISkTextStyle;
  ISkTypefaceFontProvider = System.Skia.ISkTypefaceFontProvider;
  ISkSVGDOM = System.Skia.ISkSVGDOM;
  ISkDocument = System.Skia.ISkDocument;
  TSkSurface = System.Skia.TSkSurface;
  TSkImage = System.Skia.TSkImage;
  TSkPaint = System.Skia.TSkPaint;
  TSkFont = System.Skia.TSkFont;
  TSkTypeface = System.Skia.TSkTypeface;
  TSkPath = System.Skia.TSkPath;
  TSkPathBuilder = System.Skia.TSkPathBuilder;
  TSkPathEffect = System.Skia.TSkPathEffect;
  TSkShader = System.Skia.TSkShader;
  TSkColorFilter = System.Skia.TSkColorFilter;
  TSkImageFilter = System.Skia.TSkImageFilter;
  TSkPicture = System.Skia.TSkPicture;
  TSkPictureRecorder = System.Skia.TSkPictureRecorder;
  TSkRegion = System.Skia.TSkRegion;
  TSkRoundRect = System.Skia.TSkRoundRect;
  TSkTextBlob = System.Skia.TSkTextBlob;
  TSkShaper = System.Skia.TSkShaper;
  TSkParagraphBuilder = System.Skia.TSkParagraphBuilder;
  TSkParagraphStyle = System.Skia.TSkParagraphStyle;
  TSkTextStyle = System.Skia.TSkTextStyle;
  TSkTypefaceFontProvider = System.Skia.TSkTypefaceFontProvider;
  TSkSVGDOM = System.Skia.TSkSVGDOM;
  TSkSVGCanvas = System.Skia.TSkSVGCanvas;
  TSkDocument = System.Skia.TSkDocument;
  TSkImageInfo = System.Skia.TSkImageInfo;
  TSkSamplingOptions = System.Skia.TSkSamplingOptions;
  TSkFontMetrics = System.Skia.TSkFontMetrics;
  TSkFontStyle = System.Skia.TSkFontStyle;
  TSkAlphaType = System.Skia.TSkAlphaType;
  TSkColorType = System.Skia.TSkColorType;
  TSkBlendMode = System.Skia.TSkBlendMode;
  TSkPaintStyle = System.Skia.TSkPaintStyle;
  TSkClipOp = System.Skia.TSkClipOp;
  TSkStrokeCap = System.Skia.TSkStrokeCap;
  TSkStrokeJoin = System.Skia.TSkStrokeJoin;
  TSkTileMode = System.Skia.TSkTileMode;
  TSkPathFillType = System.Skia.TSkPathFillType;
  TSkPathDirection = System.Skia.TSkPathDirection;
  TSkPathOp = System.Skia.TSkPathOp;
  TSkPathArcSize = System.Skia.TSkPathArcSize;
  TSkTextDirection = System.Skia.TSkTextDirection;
  TSkTextAlign = System.Skia.TSkTextAlign;
  TSkTextDecoration = System.Skia.TSkTextDecoration;
  TSkTextDecorations = System.Skia.TSkTextDecorations;
  TSkTextDecorationStyle = System.Skia.TSkTextDecorationStyle;
  TSkTextBaseline = System.Skia.TSkTextBaseline;
  TSkFilterMode = System.Skia.TSkFilterMode;
  TSkMipmapMode = System.Skia.TSkMipmapMode;
  TSkEncodedImageFormat = System.Skia.TSkEncodedImageFormat;
  TSkFontEdging = System.Skia.TSkFontEdging;
  TSkFontHinting = System.Skia.TSkFontHinting;
  TSkFontWeight = System.Skia.TSkFontWeight;
  TSkFontWidth = System.Skia.TSkFontWidth;
  TSkFontSlant = System.Skia.TSkFontSlant;
  TSkRegionOp = System.Skia.TSkRegionOp;
  TSkBlurStyle = System.Skia.TSkBlurStyle;

const
  { Unscoped VCL enum values are exported explicitly alongside their type aliases. }
  clNone = Vcl.Graphics.clNone;
  clBlack = Vcl.Graphics.clBlack;
  clMaroon = Vcl.Graphics.clMaroon;
  clGreen = Vcl.Graphics.clGreen;
  clNavy = Vcl.Graphics.clNavy;
  clWhite = Vcl.Graphics.clWhite;
  clSkyBlue = Vcl.Graphics.clSkyBlue;
  clRed = Vcl.Graphics.clRed;
  clLime = Vcl.Graphics.clLime;
  clYellow = Vcl.Graphics.clYellow;
  clFuchsia = Vcl.Graphics.clFuchsia;
  clBlue = Vcl.Graphics.clBlue;
  pfDevice = Vcl.Graphics.pfDevice;
  pf1bit = Vcl.Graphics.pf1bit;
  pf4bit = Vcl.Graphics.pf4bit;
  pf8bit = Vcl.Graphics.pf8bit;
  pf15bit = Vcl.Graphics.pf15bit;
  pf16bit = Vcl.Graphics.pf16bit;
  pf24bit = Vcl.Graphics.pf24bit;
  pf32bit = Vcl.Graphics.pf32bit;
  pfCustom = Vcl.Graphics.pfCustom;
  fpDefault = Vcl.Graphics.fpDefault;
  fpVariable = Vcl.Graphics.fpVariable;
  fpFixed = Vcl.Graphics.fpFixed;
  cmSrcCopy = Vcl.Graphics.cmSrcCopy;
  pmBlack = Vcl.Graphics.pmBlack;
  pmWhite = Vcl.Graphics.pmWhite;
  pmNop = Vcl.Graphics.pmNop;
  pmNot = Vcl.Graphics.pmNot;
  pmCopy = Vcl.Graphics.pmCopy;
  pmNotCopy = Vcl.Graphics.pmNotCopy;
  pmMergePenNot = Vcl.Graphics.pmMergePenNot;
  pmMaskPenNot = Vcl.Graphics.pmMaskPenNot;
  pmMergeNotPen = Vcl.Graphics.pmMergeNotPen;
  pmMaskNotPen = Vcl.Graphics.pmMaskNotPen;
  pmMerge = Vcl.Graphics.pmMerge;
  pmNotMerge = Vcl.Graphics.pmNotMerge;
  pmMask = Vcl.Graphics.pmMask;
  pmNotMask = Vcl.Graphics.pmNotMask;
  pmXor = Vcl.Graphics.pmXor;
  pmNotXor = Vcl.Graphics.pmNotXor;
  bsSolid = Vcl.Graphics.bsSolid;
  bsClear = Vcl.Graphics.bsClear;
  bsHorizontal = Vcl.Graphics.bsHorizontal;
  bsVertical = Vcl.Graphics.bsVertical;
  bsFDiagonal = Vcl.Graphics.bsFDiagonal;
  bsBDiagonal = Vcl.Graphics.bsBDiagonal;
  bsCross = Vcl.Graphics.bsCross;
  bsDiagCross = Vcl.Graphics.bsDiagCross;
  fsBold = Vcl.Graphics.fsBold;
  fsItalic = Vcl.Graphics.fsItalic;
  fsUnderline = Vcl.Graphics.fsUnderline;
  fsStrikeOut = Vcl.Graphics.fsStrikeOut;
  psSolid = Vcl.Graphics.psSolid;
  psDash = Vcl.Graphics.psDash;
  psDot = Vcl.Graphics.psDot;
  psDashDot = Vcl.Graphics.psDashDot;
  psDashDotDot = Vcl.Graphics.psDashDotDot;
  psClear = Vcl.Graphics.psClear;
  psInsideFrame = Vcl.Graphics.psInsideFrame;
  afIgnored = Vcl.Graphics.afIgnored;
  afDefined = Vcl.Graphics.afDefined;
  afPremultiplied = Vcl.Graphics.afPremultiplied;
  fsSurface = Vcl.Graphics.fsSurface;
  fsBorder = Vcl.Graphics.fsBorder;
  tfBottom = Vcl.Graphics.tfBottom;
  tfCalcRect = Vcl.Graphics.tfCalcRect;
  tfCenter = Vcl.Graphics.tfCenter;
  tfEditControl = Vcl.Graphics.tfEditControl;
  tfEndEllipsis = Vcl.Graphics.tfEndEllipsis;
  tfPathEllipsis = Vcl.Graphics.tfPathEllipsis;
  tfExpandTabs = Vcl.Graphics.tfExpandTabs;
  tfExternalLeading = Vcl.Graphics.tfExternalLeading;
  tfLeft = Vcl.Graphics.tfLeft;
  tfModifyString = Vcl.Graphics.tfModifyString;
  tfNoClip = Vcl.Graphics.tfNoClip;
  tfNoPrefix = Vcl.Graphics.tfNoPrefix;
  tfRight = Vcl.Graphics.tfRight;
  tfRtlReading = Vcl.Graphics.tfRtlReading;
  tfSingleLine = Vcl.Graphics.tfSingleLine;
  tfTop = Vcl.Graphics.tfTop;
  tfVerticalCenter = Vcl.Graphics.tfVerticalCenter;
  tfWordBreak = Vcl.Graphics.tfWordBreak;
  tfHidePrefix = Vcl.Graphics.tfHidePrefix;
  tfNoFullWidthCharBreak = Vcl.Graphics.tfNoFullWidthCharBreak;
  tfPrefixOnly = Vcl.Graphics.tfPrefixOnly;
  tfTabStop = Vcl.Graphics.tfTabStop;
  tfWordEllipsis = Vcl.Graphics.tfWordEllipsis;
  tfComposited = Vcl.Graphics.tfComposited;

resourcestring
  { Public resource identifiers allow application-specific translations. }
  SSkiaFontFileNotFound = 'Font file not found: %s';
  SSkiaInvalidFontFile = 'Invalid font file: %s';
  SSkiaNilFontStream = 'Font stream is nil';
  SSkiaInvalidFontStream = 'Invalid font stream';
  SSkiaOpenTypeAbiMismatch = 'Uniscribe OpenType ABI layout mismatch';
  SSkiaNilCanvas = 'ISkCanvas is nil';
  SSkiaInvalidSavedState = 'RestoreState: invalid index %d (saved states: %d)';
  SSkiaInvalidBitmapSize = 'TSkiaBitmapCanvas: invalid size %dx%d';
  SSkiaFlushRequiresBitmap = 'Flush requires a destination bitmap';
  SSkiaFlushPixelsUnavailable = 'Flush: cannot access pixels';
  SSkiaInvalidMetafileSize = 'TSkiaMetafileCanvas: invalid size %gx%g';
  SSkiaRecordingCompleted = 'TSkiaMetafileCanvas: recording has already finished';
  SSkiaPlaybackRequiresCanvas = 'Playback requires a destination canvas';
  SSkiaPlaybackRequiresSkiaCanvas = 'Playback requires a destination Skia canvas';
  SSkiaImagePixelsUnavailable = 'Cannot read Skia image pixels';
  SSkiaNilSurface = 'ISkSurface is nil';
  SSkiaBeginTextOutlineFailed = 'Cannot begin text outline path';
  SSkiaReadNativeTextPathFailed = 'Cannot read native text path';
  SSkiaReadTextOutlineFailed = 'Cannot read text outline path';
  SSkiaInvalidGdiTextPath = 'Invalid GDI text path';
  SSkiaTextToOutlinesFailed = 'Cannot convert shaped text to vector outlines';
  SSkiaInvalidUnicodeScalar = 'Invalid Unicode scalar';
  SSkiaInvalidUtf8Byte = 'Invalid UTF-8 at byte %d';
  SSkiaTruncatedUtf8 = 'Truncated UTF-8 at byte %d';
  SSkiaInvalidUtf8Continuation = 'Invalid UTF-8 continuation at byte %d';
  SSkiaInvalidUtf8Scalar = 'Invalid UTF-8 scalar at byte %d';
  SSkiaUnpairedUtf16Surrogate = 'Unpaired UTF-16 surrogate';
  SSkiaTruncatedSfntFace = 'Truncated SFNT face';
  SSkiaInvalidSfntSignature = 'Invalid SFNT face signature';
  SSkiaInvalidSfntDirectory = 'Invalid SFNT table directory';
  SSkiaInvalidSfntTableBounds = 'Invalid SFNT table bounds';
  SSkiaTruncatedSfntHeader = 'Truncated SFNT header';
  SSkiaInvalidTtcVersion = 'Invalid TTC version';
  SSkiaInvalidTtcFaceCount = 'Invalid TTC face count';
  SSkiaTruncatedTtcDirectory = 'Truncated TTC directory';
  SSkiaInvalidTtcFaceOffset = 'Invalid TTC face offset';
  SSkiaMetafilePlaybackFailed = 'Metafile playback failed: %s';
  SSkiaMetafileGdiFailed = 'Cannot replay metafile record %d';
  SSkiaMetafileBufferFailed = 'Cannot create the metafile playback buffer';
  SSkiaInvalidFontContainer = 'Not an SFNT or TrueType collection';

type

  ISkiaPathBuilder = ISkPathBuilder;
  TSkiaPathBuilder = TSkPathBuilder;

  /// <summary>
  /// Reports invalid canvas operations, resources or dimensions.
  /// </summary>
  ESkiaCanvasError = class(Exception);
  /// <summary>
  /// Reports an operation unavailable on the current backend.
  /// </summary>
  ESkiaNotSupportedError = class(ESkiaCanvasError);

  /// <summary>A decoded Unicode scalar with its one-based UTF-8 byte offset.</summary>
  TSkiaCodePoint = record
    Value: Cardinal;
    ByteOffset, ByteLength: Integer;
  end;

  /// <summary>Unicode bidi properties, in the order defined by the generated tables.</summary>
  TSkiaBidiClass = (bcL, bcR, bcAL, bcEN, bcES, bcET, bcAN, bcCS, bcNSM, bcBN, bcB, bcS, bcWS, bcON, bcLRE, bcLRO, bcRLE, bcRLO, bcPDF, bcLRI, bcRLI, bcFSI, bcPDI);

  /// <summary>Unicode 17 scalar decoding, script properties and Arabic joining helpers.</summary>
  TSkiaUnicode = record
    /// <summary>Strictly decodes UTF-8; rejects truncated, overlong and surrogate encodings.</summary>
    class function DecodeUtf8(const Text: UTF8String): TArray<TSkiaCodePoint>; static;
    /// <summary>Returns scalar values, rejecting unpaired UTF-16 surrogates.</summary>
    class function CodePoints(const Text: UnicodeString): TArray<Cardinal>; static;
    /// <summary>Encodes one valid scalar as UTF-16, including supplementary characters.</summary>
    class function ScalarText(Value: Cardinal): UnicodeString; static;
    /// <summary>Returns the Unicode Script property, independent of installed fonts.</summary>
    class function ScriptName(Value: Cardinal): string; static;
    /// <summary>Returns the Unicode bidi class across all Unicode planes.</summary>
    class function BidiClass(Value: Cardinal): TSkiaBidiClass; static;
    /// <summary>Tests strong RTL classes R and AL, including supplementary scripts.</summary>
    class function IsRightToLeft(Value: Cardinal): Boolean; static;
    /// <summary>Tests Unicode default-ignorable scalars, including joiners and variation selectors.</summary>
    class function IsDefaultIgnorable(Value: Cardinal): Boolean; static;
    /// <summary>Finds paragraph base level by the first strong scalar outside bidi isolates.</summary>
    class function ParagraphLevel(const Text: UnicodeString): Word; static;
    /// <summary>Returns one assigned letter for each Unicode script containing RTL letters.</summary>
    class function RTLScriptSamples: TArray<Cardinal>; static;
  end;

  /// <summary>
  /// Selects no gradient, a horizontal gradient or a vertical gradient.
  /// </summary>
  TSkiaGradientKind = (gkNone, gkHorizontal, gkVertical);

  /// <summary>
  /// Extends a VCL brush with opacity, linear gradients and owned bitmap patterns.
  /// </summary>
  /// <remarks>
  /// Inherited Style must be non-clear. A gradient takes precedence over Pattern;
  /// otherwise Pattern takes precedence over the basic solid or hatch style.
  /// Mutable resources and their bitmap patterns require the owning canvas Lock when shared.
  /// </remarks>
  TSkiaBrush = class(TBrush)
  private
    FAlpha: Byte;
    FGradient: TSkiaGradientKind;
    FGradientStartColor: TColor;
    FGradientEndColor: TColor;
    FPattern: TBitmap;
    procedure SetAlpha(Value: Byte);
    procedure SetGradient(Value: TSkiaGradientKind);
    procedure SetGradientStartColor(Value: TColor);
    procedure SetGradientEndColor(Value: TColor);
    procedure SetPattern(Value: TBitmap);
{$IFDEF MSWINDOWS}
    function TryAssignFromHandle(ABrush: HBRUSH): Boolean;
{$ENDIF}
{$IFDEF MSWINDOWS}
    function TryAssignFromLogBrush(const LB: TLogBrush): Boolean;
{$ENDIF}
  public
    /// <summary>
    /// Creates an opaque brush with no gradient or bitmap pattern.
    /// </summary>
    constructor Create;
    /// <summary>
    /// Releases the owned pattern bitmap.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    /// Copies VCL brush settings, extended Skia settings or a bitmap pattern.
    /// </summary>
    procedure Assign(Source: TPersistent); override;

    /// <summary>
    /// Returns whether the brush has nonzero opacity and a non-clear style.
    /// </summary>
    function IsVisible: Boolean;
    /// <summary>
    /// Brush opacity, from 0 (transparent) to 255 (opaque).
    /// </summary>
    property Alpha: Byte read FAlpha write SetAlpha default 255;
    /// <summary>
    /// Linear gradient direction; gkNone disables the gradient.
    /// </summary>
    property Gradient: TSkiaGradientKind read FGradient write SetGradient default gkNone;
    /// <summary>
    /// Color at the left or top edge of the fill bounds.
    /// </summary>
    property GradientStartColor: TColor read FGradientStartColor write SetGradientStartColor default clBlack;
    /// <summary>
    /// Color at the right or bottom edge of the fill bounds.
    /// </summary>
    property GradientEndColor: TColor read FGradientEndColor write SetGradientEndColor default clWhite;
    /// <summary>
    /// Repeating bitmap pattern; assignment copies the bitmap and nil clears it.
    /// </summary>
    /// <remarks>
    /// The brush owns its copy. Editing the returned bitmap directly does not notify the resource
    /// cache; reassign or explicitly invalidate the brush cache after editing.
    /// </remarks>
    property Pattern: TBitmap read FPattern write SetPattern;
  end;

  /// <summary>
  /// Extends a VCL pen with opacity, stroke geometry and custom dash intervals.
  /// </summary>
  /// <remarks>
  /// Inherited Mode selects one of the sixteen ROP2 combinations for drawing shapes.
  /// psInsideFrame insets strokes for rectangles, ellipses, rounded rectangles, chords and pies.
  /// </remarks>
  /// <remarks>Mutable VCL resource; use its owning canvas Lock or an external lock when shared.</remarks>
  TSkiaPen = class(TPen)
  private
    FAlpha: Byte;
    FStrokeCap: TSkStrokeCap;
    FStrokeJoin: TSkStrokeJoin;
    FMiterLimit: Single;
    FDashPattern: TArray<Single>;
    procedure SetAlpha(Value: Byte);
    procedure SetStrokeCap(Value: TSkStrokeCap);
    procedure SetStrokeJoin(Value: TSkStrokeJoin);
    procedure SetMiterLimit(Value: Single);
    procedure SetDashPattern(const Value: TArray<Single>);
{$IFDEF MSWINDOWS}
    function TryAssignFromHandle(APen: HPEN): Boolean;
{$ENDIF}
  public
    /// <summary>
    /// Creates an opaque pen with butt caps, miter joins and no custom dash pattern.
    /// </summary>
    constructor Create;
    /// <summary>
    /// Copies VCL pen settings, GDI pen attributes and extended Skia stroke settings.
    /// </summary>
    procedure Assign(Source: TPersistent); override;
    /// <summary>
    /// Returns whether the pen has nonzero opacity and a non-clear style.
    /// </summary>
    function IsVisible: Boolean;
    /// <summary>
    /// Stroke opacity, from 0 (transparent) to 255 (opaque).
    /// </summary>
    property Alpha: Byte read FAlpha write SetAlpha default 255;
    /// <summary>
    /// Shape of open stroke endpoints.
    /// </summary>
    property StrokeCap: TSkStrokeCap read FStrokeCap write SetStrokeCap default TSkStrokeCap.Butt;
    /// <summary>
    /// Shape of joins between adjacent stroke segments.
    /// </summary>
    property StrokeJoin: TSkStrokeJoin read FStrokeJoin write SetStrokeJoin default TSkStrokeJoin.Miter;
    /// <summary>
    /// Maximum miter length relative to stroke width.
    /// </summary>
    property MiterLimit: Single read FMiterLimit write SetMiterLimit;

    /// <summary>
    /// Alternating on/off intervals in local coordinate units; nil uses the VCL pen style.
    /// </summary>
    /// <remarks>
    /// Assignment copies the array. A custom pattern overrides the standard dashed pen style; clear
    /// it to restore style-based dashes.
    /// </remarks>
    property DashPattern: TArray<Single> read FDashPattern write SetDashPattern;
  end;

  /// <summary>
  /// Extends a VCL font with text opacity.
  /// </summary>
  /// <remarks>Mutable VCL resource; use its owning canvas Lock or an external lock when shared.</remarks>
  TSkiaFont = class(TFont)
  private
    FAlpha: Byte;
    procedure SetAlpha(Value: Byte);
{$IFDEF MSWINDOWS}
    function TryAssignFromHandle(AFont: HFONT): Boolean;
{$ENDIF}
{$IFDEF MSWINDOWS}
    function TryAssignFromLogFont(const LF: TLogFontW): Boolean;
{$ENDIF}
  public
    /// <summary>
    /// Creates a font with fully opaque text.
    /// </summary>
    constructor Create;
    /// <summary>
    /// Copies VCL or GDI font attributes and Skia text opacity.
    /// </summary>
    procedure Assign(Source: TPersistent); override;
    /// <summary>
    /// Text opacity, from 0 (transparent) to 255 (opaque).
    /// </summary>
    property Alpha: Byte read FAlpha write SetAlpha default 255;
  end;

  /// <summary>
  /// Resolves and caches Skia typefaces from VCL font settings and registered font aliases.
  /// </summary>
  /// <remarks>Cache and alias operations are serialized per manager. Input fonts and streams
  /// remain caller-owned and must not be mutated concurrently. OnChange executes on the calling
  /// thread after releasing the internal cache lock. Stop callers before destruction.</remarks>
  TSkiaFontManager = class
  private
    FLock: SyncObjs.TCriticalSection;
    FCustom: TDictionary<string, ISkTypeface>;
    FCache: TDictionary<string, ISkTypeface>;
    FOnChange: TNotifyEvent;
    FInternalChange: TNotifyEvent;
    FNativeFonts: TList<THandle>;
    procedure DoChange;
    function GetOnChange: TNotifyEvent;
    procedure SetOnChange(const Value: TNotifyEvent);
    function LogFontKey(const LF: TLogFontW): string;
    function FindCustom(const FamilyName: string): ISkTypeface;
  public
    /// <summary>
    /// Creates empty typeface and alias caches.
    /// </summary>
    constructor Create;
    /// <summary>
    /// Releases cached typefaces and private Windows font registrations.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Reads LOGFONT from the VCL font handle or constructs it from font properties.
    /// </summary>
    function GetLogFont(AFont: TFont; out LF: TLogFontW): Boolean;

    /// <summary>
    /// Builds a cache key from the resolved LOGFONT attributes.
    /// </summary>
    function FontKey(AFont: TFont): string;

    /// <summary>
    /// Returns a registered or cached typeface, resolving a system fallback when needed.
    /// </summary>
    function AcquireTypeface(AFont: TFont): ISkTypeface;
    /// <summary>Selects a preferred or system font that contains every visible scalar.</summary>
    /// <remarks>Uses script and language preferences, then installed families. Returns nil
    /// when no single font covers the run; never treats a missing glyph as a match.</remarks>
    function MatchTypefaceForText(const Text, PreferredFamily: string; const Language: string = ''): ISkTypeface;
    /// <summary>Reads and validates the SFNT/TTC face directory without installing fonts.</summary>
    function CollectionFaceCount(const FileName: string): Integer;
    /// <summary>Loads the first TTC face covering all visible scalars; reports its actual index.</summary>
    function MatchCollectionTypeface(const FileName, Text: string; out FaceIndex: Integer): ISkTypeface;

    /// <summary>
    /// Registers a typeface under a case-insensitive family alias and invalidates resolved fonts.
    /// </summary>
    /// <remarks>
    /// The manager retains an interface reference; it does not take ownership of a caller object or
    /// require a globally installed font.
    /// </remarks>
    procedure RegisterTypeface(const FamilyName: string; const Typeface: ISkTypeface);
    /// <summary>
    /// Removes a family alias and invalidates resolved fonts.
    /// </summary>
    procedure UnregisterTypeface(const FamilyName: string);
    /// <summary>
    /// Loads a typeface from a font file or an indexed face in a TrueType collection.
    /// </summary>
    /// <remarks>
    /// Font loading does not register a family alias. The returned interface can be passed to
    /// RegisterTypeface.
    /// </remarks>
    /// <param name="FileName">Path to the font file opened for reading.</param>
    /// <param name="ATTCIndex">Zero-based face index in a font collection.</param>
    /// <exception cref="ESkiaCanvasError">Raised for a missing or invalid font resource.</exception>
    function LoadTypefaceFromFile(const FileName: string; ATTCIndex: Integer = 0): ISkTypeface;
    /// <summary>
    /// Loads a typeface from a stream or an indexed face in a TrueType collection.
    /// </summary>
    /// <remarks>
    /// The caller owns the stream. Font loading does not register a family alias; call
    /// RegisterTypeface to use an alias. Private Windows font registrations live until the manager
    /// is destroyed.
    /// </remarks>
    /// <param name="AStream">Caller-owned font data stream at the starting read position.</param>
    /// <param name="ATTCIndex">Zero-based face index in a font collection.</param>
    /// <exception cref="ESkiaCanvasError">Raised for a missing or invalid font resource.</exception>
    function LoadTypefaceFromStream(AStream: TStream; ATTCIndex: Integer = 0): ISkTypeface;
    /// <summary>
    /// Clears registered aliases and resolved typeface caches.
    /// </summary>
    /// <remarks>
    /// Private Windows font registrations created during loading remain until destruction.
    /// </remarks>
    procedure Clear;
    /// <summary>
    /// Notification raised when aliases or font caches change.
    /// </summary>
    property OnChange: TNotifyEvent read GetOnChange write SetOnChange;
  end;

  /// <summary>
  /// Caches fill paints, stroke paints and Skia fonts for VCL drawing resources.
  /// </summary>
  /// <remarks>Cache operations are serialized with the owned font manager. Input resources
  /// must be stable for each call. Treat returned cached paints and fonts as read-only; copy them
  /// before mutation. Stop callers before destruction.</remarks>
  TSkiaResourceManager = class
  private
    FLock: SyncObjs.TCriticalSection; { Borrowed from the owned font manager. }
    FFillPaint: ISkPaint;
    FFillKey: string;
    FStrokePaint: ISkPaint;
    FStrokeKey: string;
    FFont: ISkFont;
    FFontKey: string;
    FFontManager: TSkiaFontManager;
    procedure FontManagerChanged(Sender: TObject);
    function BrushKey(ABrush: TSkiaBrush; const Bounds: TRectF): string;
    function PenKey(APen: TSkiaPen): string;
    function BuildFillPaint(ABrush: TSkiaBrush; const Bounds: TRectF): ISkPaint;
    function BuildStrokePaint(APen: TSkiaPen): ISkPaint;
    function BuildFont(AFont: TFont): ISkFont;
  public
    /// <summary>
    /// Creates resource caches and an owned font manager.
    /// </summary>
    constructor Create;
    /// <summary>
    /// Releases cached resources and the owned font manager.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Returns a cached fill paint, or nil for an invisible brush.
    /// </summary>
    /// <remarks>
    /// Bounds affect gradient coordinates. Returned interface references remain valid after cache
    /// invalidation; treat cached paints as shared resources.
    /// </remarks>
    function AcquireFillPaint(ABrush: TSkiaBrush; const Bounds: TRectF): ISkPaint;

    /// <summary>
    /// Returns a cached stroke paint, or nil for an invisible pen.
    /// </summary>
    /// <remarks>
    /// Treat returned cached paints as shared resources; modifying them changes subsequent cache
    /// users.
    /// </remarks>
    function AcquireStrokePaint(APen: TSkiaPen): ISkPaint;
    /// <summary>
    /// Returns a cached Skia font for the VCL font settings.
    /// </summary>
    function AcquireFont(AFont: TFont): ISkFont;
    /// <summary>
    /// Drops the cached fill paint and its key.
    /// </summary>
    procedure InvalidateBrush;
    /// <summary>
    /// Drops the cached stroke paint and its key.
    /// </summary>
    procedure InvalidatePen;
    /// <summary>
    /// Drops the cached Skia font and its key.
    /// </summary>
    procedure InvalidateFont;
    /// <summary>
    /// Drops all cached paints and the cached Skia font.
    /// </summary>
    procedure InvalidateAll;
    /// <summary>
    /// Owned manager used to resolve typefaces for font resources.
    /// </summary>
    property FontManager: TSkiaFontManager read FFontManager;
  end;

  /// <summary>
  /// Describes one visually ordered glyph with advances and offsets in font design units.
  /// </summary>
  TGdiShapedGlyph = record
    /// <summary>
    /// Font-specific glyph identifier.
    /// </summary>
    GlyphIndex: Word;
    /// <summary>
    /// Horizontal advance in font design units.
    /// </summary>
    AdvanceX: Single;
    /// <summary>
    /// Horizontal placement offset in font design units.
    /// </summary>
    OffsetX: Single;
    /// <summary>
    /// Vertical placement offset in font design units, with Y pointing up.
    /// </summary>
    OffsetY: Single;
  end;

  /// <summary>
  /// Caches GDI fonts, metrics, outlines, kerning pairs and Uniscribe shaping resources.
  /// </summary>
  /// <remarks>Public cache operations are serialized. Lock/Unlock must cover ShapeText together with subsequent outline queries, since the selected font is shared state.
  /// The cached memory DC supports sequential handoff between workers. Stop callers before freeing.</remarks>
  TSkiaGdiGlyphCache = class
  private
    FLock: SyncObjs.TCriticalSection;
{$IFDEF MSWINDOWS}
    FShapingEmSquare: Integer;
    FDC: HDC;
    FFont: HFONT;
    FStockFont: HGDIOBJ;
    FFontKey: string;
    FEmSquare: Integer;
    FEmSquareKey: string;
    FCharHeight: Integer;
    FCharHeightKey: string;
    FPaths: TDictionary<string, ISkPath>;
    FAdvances: TDictionary<string, Single>;
    FKern: TDictionary<Cardinal, Single>;
    FKernKey: string;
    FUspLib: HMODULE;
    FUspTried: Boolean;
    FLastShapeUsedOpenType: Boolean;
    FScriptCache: Pointer;
    FScriptItemizeOpenType: Pointer;
    FScriptShapeOpenType: Pointer;
    FScriptPlaceOpenType: Pointer;
    FScriptLayout: Pointer;
    FScriptFreeCache: Pointer;
    function GetLastShapeUsedOpenType: Boolean;
    function GlyphKey(GlyphIndex: Word): string;
    procedure EnsureShapingFont(const LF: TLogFontW; const FontKey: string; EmSquare: Integer);
    function LoadUsp10: Boolean;
    function UspShapeText(const Text: UnicodeString; Shaped: TList<TGdiShapedGlyph>): Boolean;
    procedure FallbackShapeText(const Text: UnicodeString; Shaped: TList<TGdiShapedGlyph>);
    function GetGlyphIndexForChar(Ch: WideChar): Word;
    function GetGlyphIndexForPair(Hi, Lo: WideChar): Word;
    function GetKerning(First, Second: Word): Single;
{$ELSE}
    FNativeFont: ISkFont;
    FNativeShaped: Boolean;
    function GetLastShapeUsedOpenType: Boolean;
{$ENDIF}
  public
    /// <summary>
    /// Creates empty GDI metric, outline and shaping caches.
    /// </summary>
    constructor Create;
    /// <summary>Locks a shaping and outline extraction transaction recursively across threads.</summary>
    procedure Lock;
    /// <summary>Releases a matching Lock, normally from a finally block.</summary>
    procedure Unlock;
    /// <summary>
    /// Releases GDI handles, Uniscribe resources and cached glyph data.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    /// Invalidates metrics and outlines and releases font-dependent shaping resources.
    /// </summary>
    procedure Clear;

    /// <summary>
    /// Returns the cached design-units-per-em value for the requested font.
    /// </summary>
    function GetEmSquare(const LF: TLogFontW; const FontKey: string): Integer;

    /// <summary>
    /// Returns the actual character height in pixels, excluding internal leading.
    /// </summary>
    function GetCharHeight(const LF: TLogFontW; const FontKey: string): Integer;

    /// <summary>
    /// Returns a cached glyph outline and its advance in font design units.
    /// </summary>
    /// <remarks>
    /// Requires a font selected by ShapeText. A glyph without an outline can return nil while
    /// retaining a nonzero advance.
    /// </remarks>
    function GetGlyphPathByIndex(GlyphIndex: Word; out Advance: Single): ISkPath;

    /// <summary>
    /// Shapes UTF-16 text into visual-order glyphs with design-unit advances and offsets.
    /// </summary>
    /// <remarks>
    /// Uses Uniscribe when available, otherwise glyph mapping with pair kerning. False indicates
    /// invalid layout input or unavailable font resources. RequireOpenType disables compatibility fallback.
    /// </remarks>
    /// <param name="LF">Logical font attributes used to select the shaping font.</param>
    /// <param name="FontKey">Cache identity for the logical font.</param>
    /// <param name="Text">UTF-16 text to shape.</param>
    /// <param name="EmSquare">Positive design units per em for the selected font.</param>
    /// <param name="Glyphs">Receives visual-order glyphs; cleared when shaping fails.</param>
    /// <param name="RequireOpenType">True requires successful OpenType shaping for nonempty text.</param>
    function ShapeText(const LF: TLogFontW; const FontKey: string; EmSquare: Integer; const Text: UnicodeString; out Glyphs: TArray<TGdiShapedGlyph>; RequireOpenType: Boolean = False): Boolean;
    /// <summary>Reports whether the last shaping call completed through OpenType APIs.</summary>
    property LastShapeUsedOpenType: Boolean read GetLastShapeUsedOpenType;

  end;

  /// <summary>
  /// Controls placement of shaped text along a directed path.
  /// </summary>
  TSkiaTextPathAlignment = (tpaStart, tpaCenter, tpaEnd);
  TSkiaTextPathOrientation = (tpoTangent, tpoHorizontal);

  TSkiaTextPathOptions = record
    Offset, Distance, LetterSpacing: Single;
    Alignment: TSkiaTextPathAlignment;
    Orientation: TSkiaTextPathOrientation;
    Reverse, MirrorHorizontal, MirrorVertical, Wrap: Boolean;
    class function Default: TSkiaTextPathOptions; static;
  end;

  /// Stores prepared text layout for outline drawing and measurement.
  TSkiaCurvesText = record
    /// <summary>
    /// Visual-order GDI glyphs in font design units.
    /// </summary>
    Glyphs: TArray<TGdiShapedGlyph>;
    /// <summary>
    /// Design units per em; used to scale glyphs to pixels.
    /// </summary>
    EmSquare: Integer;
    /// <summary>
    /// Character height used for design-to-pixel scaling.
    /// </summary>
    SizePx: Single;
    /// <summary>
    /// Total shaped horizontal advance in pixels.
    /// </summary>
    WidthPx: Single;

    /// <summary>
    /// Native Skia shaped text for a custom face unavailable to GDI.
    /// </summary>
    Blob: ISkTextBlob;

  end;

  /// <summary>
  /// Stores one device-space clipping path and its Boolean operation.
  /// </summary>
  TSkiaClipEntry = record
    /// <summary>
    /// Clipping path already transformed into device coordinates.
    /// </summary>
    Path: ISkPath;
    /// <summary>
    /// Intersection or difference operation applied to the clip.
    /// </summary>
    Op: TSkClipOp;
  end;

  /// <summary>
  /// Owns a snapshot of canvas resources, coordinates, clipping and drawing modes.
  /// </summary>
  /// <remarks>
  /// Used internally by SaveState and RestoreState; stored Skia paths are retained through
  /// interface references.
  /// </remarks>
  /// <remarks>Mutable snapshot owned by a canvas state stack; protect it with the canvas Lock.</remarks>
  TSkiaCanvasState = class
  public
    /// <summary>
    /// Saved pen attributes.
    /// </summary>
    Pen: TSkiaPen;
    /// <summary>
    /// Saved brush attributes.
    /// </summary>
    Brush: TSkiaBrush;
    /// <summary>
    /// Saved font attributes.
    /// </summary>
    Font: TSkiaFont;
    /// <summary>
    /// Saved logical pen position.
    /// </summary>
    PenPos: TPoint;
    /// <summary>
    /// Saved image-transfer raster operation.
    /// </summary>
    CopyMode: TCopyMode;
    /// <summary>
    /// Saved logical-to-device world matrix.
    /// </summary>
    Matrix: TMatrix;
    /// <summary>
    /// Saved clip tracking value.
    /// </summary>
    ClipDepth: Integer;
    /// <summary>
    /// Saved device-space clip path sequence.
    /// </summary>
    Clips: TArray<TSkiaClipEntry>;
    /// <summary>
    /// Skia save count associated with this snapshot.
    /// </summary>
    SaveCount: Integer;
    /// <summary>
    /// Saved text outline mode.
    /// </summary>
    TextToCurves: Boolean;
    /// <summary>
    /// Creates owned pen, brush and font copies for a state snapshot.
    /// </summary>
    constructor Create;
    /// <summary>
    /// Releases owned snapshot resources.
    /// </summary>
    destructor Destroy; override;
  end;

  { Shared by wrappers of the same native drawing target. }
  ICanvasSynchronization = interface
    ['{8CB3B951-6506-4F3F-8F21-E9BD9C8174A9}']
    procedure Enter;
    procedure Leave;
    function TryEnter: Boolean;
  end;

  /// <summary>
  /// Implements VCL canvas drawing on a Skia canvas, with transforms, clipping and saved states.
  /// </summary>
  /// <remarks>
  /// Independent instances can render concurrently. For a shared instance or native target,
  /// call Lock/Unlock around the complete sequence of resource changes and drawing commands.
  /// Direct Skia access and external bitmaps also require synchronization by the caller.
  /// Destination-dependent operations and difference clips may use raster patches in PDF/SVG.
  /// </remarks>
  TSkiaCanvas = class(TCustomCanvas)
  private
    FCanvas: ISkCanvas;
    FNativeCanvasHandle: NativeUInt;
    FCanvasSynchronization: ICanvasSynchronization;
    FResources: TSkiaResourceManager;
    FBrush: TSkiaBrush;
    FPen: TSkiaPen;
    FFont: TSkiaFont;
    FPenPos: TPoint;
    FCopyMode: TCopyMode;
    FMatrix: TMatrix;
    FClipDepth: Integer;
    FClips: TArray<TSkiaClipEntry>;
    FBacking: ISkSurface;
    FBackingIsOutput: Boolean;
    FDeviceWidth, FDeviceHeight: Integer;
    FOperationDepth, FOperationKind: Integer;
    FShapingRTL: Boolean;
    FOperationKey: Cardinal;
    FRecordingClosed: Boolean;
    FOperationRecorder: ISkPictureRecorder;
    FOutputCanvas: ISkCanvas;
    FStateStack: TObjectList<TSkiaCanvasState>;
    FTextToCurves: Boolean;
    FGlyphCache: TSkiaGdiGlyphCache;
    procedure UnregisterCompatibility;
    procedure InitializeCompatibility;
    function BeginOperation(Kind: Integer): Boolean;
    procedure EndOperation;
    procedure ApplyClips(const Target: ISkCanvas);
    procedure AppendClip(const Path: ISkPath; Op: TSkClipOp);
    function ReadDevicePixels(out W, H: Integer): TArray<TAlphaColor>;
    function ClipPixels: TArray<TAlphaColor>;
    procedure CommitPatch(const Pixels: TArray<TAlphaColor>; W, H: Integer);
    procedure TransferImage(const Image: ISkImage; const Source, Dest: TRectF);
    function GraphicImage(Graphic: TGraphic): ISkImage;
{$IFDEF MSWINDOWS}
    procedure DrawMetafile(Graphic: TMetafile; const Dest: TRectF);
{$ENDIF}
    function SourceRectangle(Src: TSkiaCanvas; const Bounds: TRectF): ISkImage;
    procedure LayoutText(var Rect: TRect; var Text: string; TextFormat: TTextFormat);
    procedure LayoutPortableText(var Rect: TRect; var Text: string; TextFormat: TTextFormat);

    function NeedsSkiaShaper: Boolean;
    procedure BlobPaths(const Blob: ISkTextBlob; X, Y, Width, Size: Single; const Paint: ISkPaint);

    procedure PlainTextPaths(const Text: string; X, Baseline: Single; const Font: ISkFont; const Paint: ISkPaint);
    function GetBrush: TSkiaBrush;
    function GetPen: TSkiaPen;
    function GetFontManager: TSkiaFontManager;
    function GetTextToCurves: Boolean;
    procedure SetTextToCurves(Value: Boolean);
    procedure SetBrush(Value: TSkiaBrush);
    procedure SetPen(Value: TSkiaPen);
    procedure SetFont(Value: TSkiaFont);
    procedure BrushChanged(Sender: TObject);
    procedure PenChanged(Sender: TObject);
    procedure FontChanged(Sender: TObject);
    procedure CaptureState(St: TSkiaCanvasState);
    procedure ApplyState(St: TSkiaCanvasState);
  protected
    /// <summary>
    /// Returns coLeftToRight; bidirectional text layout is handled during shaping.
    /// </summary>
    function GetCanvasOrientation: TCanvasOrientation; override;
    /// <summary>
    /// Returns device-space bounds of the effective wrapper clip.
    /// </summary>
    function GetClipRect: TRect; override;
    /// <summary>
    /// Returns the current logical pen position.
    /// </summary>
    function GetPenPos: TPoint; override;
    /// <summary>
    /// Reads a pixel at a logical coordinate through the mirrored surface.
    /// </summary>
    function GetPixel(X, Y: Integer): TColor; override;
    /// <summary>
    /// Sets the current logical pen position.
    /// </summary>
    procedure SetPenPos(Value: TPoint); override;
    /// <summary>
    /// Writes a pixel at a transformed logical coordinate.
    /// </summary>
    procedure SetPixel(X, Y: Integer; Value: TColor); override;
    /// <summary>
    /// Accepts VCL state requests; Skia resources are resolved when drawing.
    /// </summary>
    procedure RequiredState(ReqState: TCanvasState); override;

    /// <summary>
    /// Provides a pixel buffer when the canvas implementation supports direct access.
    /// </summary>
    function LockPixels(out APixels: TArray<TAlphaColor>; out AWidth, AHeight: Integer): Boolean; virtual;
    /// <summary>
    /// Commits or releases the pixel buffer obtained by LockPixels.
    /// </summary>
    procedure UnlockPixels; virtual;
    /// <summary>
    /// Resolves the current brush for the supplied logical fill bounds.
    /// </summary>
    function AcquireFillPaint(const Bounds: TRectF): ISkPaint;
    /// <summary>
    /// Resolves the current pen to a Skia stroke paint.
    /// </summary>
    function AcquireStrokePaint: ISkPaint;

    /// <summary>
    /// Prepares shaped text and returns False when outline layout is unavailable.
    /// </summary>
    function PrepareCurvesText(const Text: string; out Data: TSkiaCurvesText): Boolean;

    /// <summary>
    /// Draws prepared glyph outlines and font decorations at a logical top-left position.
    /// </summary>
    procedure DrawCurvesText(X, Y: Integer; const Data: TSkiaCurvesText);

    /// <summary>
    /// Snapshots the source canvas backing surface for image transfer.
    /// </summary>
    function GetSrcImage(Src: TSkiaCanvas): ISkImage;

    /// <summary>
    /// Converts VCL counterclockwise arc endpoints to Skia start and sweep angles.
    /// </summary>
    function ArcAngles(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer; out StartAngle, SweepAngle: Single): TRectF;
  public
    /// <summary>
    /// Wraps a non-nil Skia canvas with reference-counted lifetime.
    /// </summary>
    /// <remarks>
    /// AOwnsCanvas is retained for API compatibility and does not change interface ownership. For
    /// prepainted raster content, use the ISkSurface overload.
    /// </remarks>
    /// <param name="ACanvas">Drawing target retained through an interface reference.</param>
    /// <param name="AOwnsCanvas">Compatibility parameter; interface reference counting controls lifetime.</param>
    constructor Create(ACanvas: ISkCanvas; AOwnsCanvas: Boolean = False); overload;
    /// <summary>
    /// Wraps an existing surface and preserves its current pixels for destination-dependent
    /// operations.
    /// </summary>
    /// <param name="ASurface">Non-nil surface retained through an interface reference.</param>
    constructor Create(ASurface: ISkSurface); overload;
    /// <summary>
    /// Releases owned drawing resources and references to Skia targets.
    /// </summary>
    destructor Destroy; override;
    /// <summary>Locks this target and its glyph cache recursively.</summary>
    /// <remarks>Use around shared property changes and drawing, including SaveState/RestoreState.
    /// Wrappers of the same native target share the target lock. Use the TSkiaCanvas type;
    /// the inherited VCL Lock is not virtual. Stop all users before destroying a canvas.</remarks>
    procedure Lock; {$IFNDEF FPC}reintroduce; {$ENDIF}
    /// <summary>Tries to lock the drawing target without waiting for another target owner.</summary>
    function TryLock: Boolean; {$IFNDEF FPC}reintroduce; {$ENDIF}
    /// <summary>Releases a matching Lock or successful TryLock in reverse acquisition order.</summary>
    procedure Unlock; {$IFNDEF FPC}reintroduce; {$ENDIF}
    /// <summary>
    /// Underlying Skia canvas for direct backend access.
    /// </summary>
    /// <remarks>
    /// Direct mutations bypass mirrored pixels and wrapper state tracking. Use wrapper methods for
    /// operations that later read destination pixels.
    /// </remarks>
    property SkCanvas: ISkCanvas read FCanvas;

    /// <summary>
    /// Returns the resolved Skia font for the current Font settings.
    /// </summary>
    function AcquireFont: ISkFont;

    /// <summary>
    /// Strokes a counterclockwise elliptical arc between two radial endpoints.
    /// </summary>
    procedure Arc(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); override;
    /// <summary>
    /// Connects the current pen position to an elliptical arc and updates PenPos.
    /// </summary>
    procedure ArcTo(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); override;
    /// <summary>
    /// Connects the pen position to a circular arc specified in counterclockwise degrees.
    /// </summary>
    procedure AngleArc(X, Y: Integer; Radius: Cardinal; StartAngle, SweepAngle: Single); override;
    /// <summary>
    /// Copies a bitmap rectangle and replaces pixels matching Color with the current brush.
    /// </summary>
    /// <remarks>
    /// With bsClear, key-colored pixels preserve the destination. A solid, pattern or gradient
    /// brush supplies replacement pixels.
    /// </remarks>
    procedure BrushCopy(const Dest: TRect; Bitmap: TBitmap; const Source: TRect; Color: TColor); override;
    /// <summary>
    /// Fills and strokes an elliptical arc closed by a straight chord.
    /// </summary>
    procedure Chord(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); override;
    /// <summary>
    /// Draws a VCL graphic at its natural size; TMetafile commands are replayed through MetafileParser.
    /// </summary>
    procedure Draw(X, Y: Integer; Graphic: TGraphic); overload; override;
    /// <summary>
    /// Draws a VCL graphic at its natural size with opacity from 0 to 255.
    /// Metafiles use the parser and a raster layer to apply group opacity.
    /// </summary>
    procedure Draw(X, Y: Integer; Graphic: TGraphic; Opacity: Byte); overload; override;
    /// <summary>
    /// Draws an XOR focus outline; drawing it twice restores the destination.
    /// </summary>
    procedure DrawFocusRect(const Rect: TRect); override;
    /// <summary>
    /// Fills and strokes an ellipse inside the supplied bounding rectangle.
    /// </summary>
    procedure Ellipse(X1, Y1, X2, Y2: Integer); override;
    /// <summary>
    /// Fills the rectangle with the current brush, without a pen outline.
    /// </summary>
    procedure FillRect(const Rect: TRect); override;
    /// <summary>
    /// Fills a connected area with the current brush using a seed or boundary color.
    /// </summary>
    /// <remarks>
    /// For fsSurface, Color selects the seed area color; for fsBorder, Color selects the stopping
    /// boundary. Drawing respects the current world transform and clip.
    /// </remarks>
    procedure FloodFill(X, Y: Integer; Color: TColor; FillStyle: TFillStyle); override;
    /// <summary>
    /// Draws a one-unit rectangular frame with the current brush.
    /// </summary>
    procedure FrameRect(const Rect: TRect); override;
    /// <summary>
    /// Strokes a segment from PenPos to the endpoint and updates PenPos.
    /// </summary>
    procedure LineTo(X, Y: Integer); override;
    /// <summary>
    /// Sets PenPos without drawing.
    /// </summary>
    procedure MoveTo(X, Y: Integer); override;
    /// <summary>
    /// Fills and strokes an elliptical arc closed by two radial segments.
    /// </summary>
    procedure Pie(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer); override;
    /// <summary>
    /// Fills and strokes a closed polygon.
    /// </summary>
    procedure Polygon(const Points: array of TPoint); override;
    /// <summary>
    /// Strokes an open sequence of connected segments.
    /// </summary>
    procedure Polyline(const Points: array of TPoint); override;
    /// <summary>
    /// Strokes cubic Bezier segments from a starting point and groups of three control/end points.
    /// </summary>
    procedure PolyBezier(const Points: array of TPoint); override;
    /// <summary>
    /// Strokes cubic Bezier segments from PenPos and updates PenPos.
    /// </summary>
    procedure PolyBezierTo(const Points: array of TPoint); override;
    /// <summary>
    /// Fills and strokes an axis-aligned rectangle.
    /// </summary>
    procedure Rectangle(X1, Y1, X2, Y2: Integer); override;
    /// <summary>
    /// Flushes pending backend work for the mirrored drawing surface.
    /// </summary>
    procedure Refresh; override;
    /// <summary>
    /// Fills and strokes a rectangle with corner ellipse diameters X3 and Y3.
    /// </summary>
    procedure RoundRect(X1, Y1, X2, Y2, X3, Y3: Integer); override;
    /// <summary>
    /// Scales a VCL graphic into the destination rectangle. Metafile geometry retains vector paths.
    /// </summary>
    procedure StretchDraw(const Rect: TRect; Graphic: TGraphic); override;

    /// <summary>
    /// Copies and scales a logical source rectangle using the current CopyMode.
    /// </summary>
    procedure CopyRect(const Dest: TRect; SrcCanvas: TCanvas; const SrcRect: TRect); overload;
    procedure CopyRect(const Dest: TRect; SrcCanvas: TSkiaCanvas; const SrcRect: TRect); overload;

    /// <summary>
    /// Copies a Width by Height logical source rectangle using the current CopyMode.
    /// </summary>
    procedure BitBlt(X, Y, Width, Height: Integer; Src: TSkiaCanvas; XSrc, YSrc: Integer); overload;
    { HDC overloads capture opaque pixels using source DC logical coordinates. }
{$IFDEF MSWINDOWS}
    procedure BitBlt(X, Y, Width, Height: Integer; Src: HDC; XSrc, YSrc: Integer); overload;
{$ENDIF}
    procedure BitBlt(X, Y, Width, Height: Integer; Src: TCanvas; XSrc, YSrc: Integer); overload;
    { Bitmap overloads use pixel coordinates and preserve the source bitmap. }
    procedure BitBlt(X, Y, Width, Height: Integer; Src: TBitmap; XSrc, YSrc: Integer); overload;

    /// <summary>
    /// Scales a logical source rectangle; signed source and destination spans support mirroring.
    /// </summary>
    procedure StretchBlt(X, Y, Width, Height: Integer; Src: TSkiaCanvas; XSrc, YSrc, SrcWidth, SrcHeight: Integer); overload;
{$IFDEF MSWINDOWS}
    procedure StretchBlt(X, Y, Width, Height: Integer; Src: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer); overload;
{$ENDIF}
    procedure StretchBlt(X, Y, Width, Height: Integer; Src: TCanvas; XSrc, YSrc, SrcWidth, SrcHeight: Integer); overload;
    procedure StretchBlt(X, Y, Width, Height: Integer; Src: TBitmap; XSrc, YSrc, SrcWidth, SrcHeight: Integer); overload;

    /// <summary>
    /// Copies source pixels selected by nonblack mask pixels using the current CopyMode.
    /// </summary>
    /// <remarks>
    /// Mask coordinates are independent of source coordinates. Black or out-of-bounds mask pixels
    /// preserve the destination.
    /// </remarks>
    procedure MaskBlt(X, Y, Width, Height: Integer; Src: TSkiaCanvas; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer); overload;
{$IFDEF MSWINDOWS}
    procedure MaskBlt(X, Y, Width, Height: Integer; Src: HDC; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer); overload;
{$ENDIF}
    procedure MaskBlt(X, Y, Width, Height: Integer; Src: TCanvas; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer); overload;
    procedure MaskBlt(X, Y, Width, Height: Integer; Src: TBitmap; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer); overload;

    /// <summary>
    /// Maps a logical source rectangle to an affine destination parallelogram.
    /// </summary>
    /// <remarks>
    /// Points must contain at least three entries: destination upper-left, upper-right and lower-
    /// left. Degenerate parallelograms draw nothing.
    /// </remarks>
    procedure PlgBlt(const Points: array of TPoint; Src: TSkiaCanvas; XSrc, YSrc, Width, Height: Integer); overload;
{$IFDEF MSWINDOWS}
    procedure PlgBlt(const Points: array of TPoint; Src: HDC; XSrc, YSrc, Width, Height: Integer); overload;
{$ENDIF}
    procedure PlgBlt(const Points: array of TPoint; Src: TCanvas; XSrc, YSrc, Width, Height: Integer); overload;
    procedure PlgBlt(const Points: array of TPoint; Src: TBitmap; XSrc, YSrc, Width, Height: Integer); overload;
    /// <summary>
    /// Measures text using the layout selected by TextToCurves.
    /// </summary>
    /// <returns>Untransformed text advance and height; world transforms are not included.</returns>
    function TextExtent(const Text: string): TSize; override;
    /// <summary>
    /// Draws text at its logical top-left position with the current font and background brush.
    /// </summary>
    procedure TextOut(X, Y: Integer; const Text: string); override;
    /// Draws shaped glyph outlines along the first contour, using the current font.
    /// Offset follows the path; positive Distance is to its left (above a rightward line).
    /// Glyphs whose advance centers lie outside an open path are omitted.
    /// Wrap repeats distances on a closed contour. Brush and Font.Orientation are ignored.
    procedure TextOnPath(const Text: string; const Path: ISkPath; Offset: Single = 0; Distance: Single = 0); overload;
    procedure TextOnPath(const Text: string; const Path: ISkPath; const Options: TSkiaTextPathOptions); overload;
    procedure TextOnPath(const Text: string; const Points: array of TPointF; Offset: Single = 0; Distance: Single = 0); overload;
    procedure TextOnPath(const Text: string; const Points: array of TPointF; const Options: TSkiaTextPathOptions); overload;
    procedure TextOnPath(const Text: string; const Points: array of TPoint; Offset: Single = 0; Distance: Single = 0); overload;
    procedure TextOnPath(const Text: string; const Points: array of TPoint; const Options: TSkiaTextPathOptions); overload;
    /// <summary>
    /// Draws formatted text and optionally updates the rectangle or string according to TextFormat.
    /// </summary>
    procedure TextRect(var Rect: TRect; var Text: string; TextFormat: TTextFormat = []); override;
    /// <summary>
    /// Draws text at explicit logical coordinates, clipped to Rect.
    /// </summary>
    procedure TextRect(Rect: TRect; X, Y: Integer; const Text: string); override;

    /// <summary>
    /// Replaces clipping with a rectangle transformed by the current world matrix.
    /// </summary>
    procedure SetClipRect(const R: TRect);
    /// <summary>
    /// Replaces clipping with a logical rectangular region.
    /// </summary>
    procedure SetClipRegion(const R: TRect); overload;
    /// <summary>
    /// Replaces clipping with the supplied region under the current world transform.
    /// </summary>
    /// <remarks>
    /// A nil region resets clipping.
    /// </remarks>
    procedure SetClipRegion(const Region: ISkRegion); overload;
    /// <summary>
    /// Replaces clipping with a path transformed by the current world matrix; nil resets clipping.
    /// </summary>
    /// <remarks>
    /// The clip is fixed in device coordinates when set; later world-matrix changes do not move it.
    /// </remarks>
    procedure SetClipPath(const Path: ISkPath);
    /// <summary>
    /// Intersects current clipping with a transformed logical rectangle.
    /// </summary>
    procedure IntersectClipRect(const R: TRect);
    /// <summary>
    /// Subtracts a transformed logical rectangle from current clipping.
    /// </summary>
    procedure ExcludeClipRect(const R: TRect);
    /// <summary>
    /// Removes clipping established through this wrapper.
    /// </summary>
    procedure ResetClip;

    /// <summary>
    /// Replaces the logical-to-device world matrix.
    /// </summary>
    procedure SetWorldTransform(const M: TMatrix);
    /// <summary>
    /// Returns the current logical-to-device world matrix.
    /// </summary>
    function GetWorldTransform: TMatrix;
    /// <summary>
    /// Restores an identity world matrix.
    /// </summary>
    procedure ResetWorldTransform;
    /// <summary>
    /// Composes a translation with the current world matrix.
    /// </summary>
    procedure TranslateTransform(DX, DY: Single);
    /// <summary>
    /// Composes local coordinate scaling with the current world matrix.
    /// </summary>
    procedure ScaleTransform(SX, SY: Single);
    /// <summary>
    /// Composes a clockwise rotation, in degrees, with the current world matrix.
    /// </summary>
    /// <param name="Angle">Clockwise rotation in degrees.</param>
    procedure RotateTransform(Angle: Single);

    /// <summary>
    /// Saves resources, pen position, modes, world matrix and clipping.
    /// </summary>
    /// <returns>A one-based index accepted by RestoreState.</returns>
    function SaveState: Integer;
    /// <summary>
    /// Restores a saved state and discards it together with all younger snapshots.
    /// </summary>
    /// <remarks>
    /// SavedIndex values less than or equal to zero select the latest state. Invalid indices,
    /// including an empty stack, raise ESkiaCanvasError.
    /// </remarks>
    procedure RestoreState(SavedIndex: Integer = -1);

    /// <summary>
    /// Transforms a logical point to device coordinates, rounding to integers.
    /// </summary>
    function LPToDP(const P: TPoint): TPoint;
    /// <summary>
    /// Transforms a device point to logical coordinates, rounding to integers.
    /// </summary>
    /// <remarks>
    /// A singular matrix leaves the input point unchanged.
    /// </remarks>
    function DPToLP(const P: TPoint): TPoint;
    /// <summary>
    /// Owned brush settings; assigning another brush copies its attributes.
    /// </summary>
    property Brush: TSkiaBrush read GetBrush write SetBrush;
    /// <summary>
    /// Owned pen settings; assigning another pen copies its attributes.
    /// </summary>
    property Pen: TSkiaPen read GetPen write SetPen;
    /// <summary>
    /// Owned font settings; assigning another font copies its attributes.
    /// </summary>
    property Font: TSkiaFont read FFont write SetFont;
    /// <summary>
    /// ROP3 raster operation applied to image transfers; defaults to source copy.
    /// </summary>
    property CopyMode: TCopyMode read FCopyMode write FCopyMode default cmSrcCopy;

    /// <summary>
    /// Owned manager for typeface aliases, font loading and font resolution.
    /// </summary>
    property FontManager: TSkiaFontManager read GetFontManager;

    /// <summary>
    /// Owned cache for GDI font metrics, glyph outlines and shaping.
    /// </summary>
    property GlyphCache: TSkiaGdiGlyphCache read FGlyphCache;

    /// <summary>
    /// Enables shaped glyph outlines and matching text measurement.
    /// </summary>
    /// <remarks>
    /// Installed fonts use GDI/Uniscribe; custom faces unavailable to GDI use native Skia shaping.
    /// Outline-free glyphs can require raster fallback.
    /// </remarks>
    property TextToCurves: Boolean read GetTextToCurves write SetTextToCurves default False;
  end;

  /// <summary>
  /// Draws onto an owned raster surface with bitmap export and image snapshots.
  /// </summary>
  TSkiaBitmapCanvas = class(TSkiaCanvas)
  private
    FSurface: ISkSurface;
    FPixelBuffer: TArray<TAlphaColor>;
    FWidth, FHeight: Integer;
  protected
    /// <summary>
    /// Reads the raster surface into an accessible pixel buffer.
    /// </summary>
    function LockPixels(out APixels: TArray<TAlphaColor>; out AWidth, AHeight: Integer): Boolean; override;
    /// <summary>
    /// Commits buffered pixel changes to the raster surface.
    /// </summary>
    procedure UnlockPixels; override;
  public
    /// <summary>
    /// Creates an owned raster surface with positive integer dimensions.
    /// </summary>
    /// <exception cref="ESkiaCanvasError">Raised when either dimension is not positive.</exception>
    constructor Create(AWidth, AHeight: Integer);

    /// <summary>
    /// Copies the current raster result into a caller-owned 32-bit VCL bitmap.
    /// </summary>
    procedure Flush(ABitmap: TBitmap);
    /// <summary>
    /// Returns an immutable image snapshot of the raster surface.
    /// </summary>
    function Snapshot: ISkImage;
    /// <summary>
    /// Raster surface width in pixels.
    /// </summary>
    property Width: Integer read FWidth;
    /// <summary>
    /// Raster surface height in pixels.
    /// </summary>
    property Height: Integer read FHeight;
  end;

  /// <summary>
  /// Records drawing operations into a replayable Skia picture.
  /// </summary>
  TSkiaMetafileCanvas = class(TSkiaCanvas)
  private
    FRecorder: ISkPictureRecorder;
    FDiscardSurface: ISkSurface;
    FWidth, FHeight: Single;
  public
    /// <summary>
    /// Starts a picture recording with positive dimensions in canvas units.
    /// </summary>
    /// <exception cref="ESkiaCanvasError">Raised when either dimension is not positive.</exception>
    constructor Create(AWidth, AHeight: Single);

    /// <summary>
    /// Ends recording and returns the picture; may be called only once.
    /// </summary>
    /// <remarks>
    /// The returned interface remains valid after the canvas is destroyed. Further drawing is
    /// ignored; a second completion raises ESkiaCanvasError.
    /// </remarks>
    function FinishRecording: ISkPicture;

    /// <summary>
    /// Ends recording and replays the resulting picture on the target canvas.
    /// </summary>
    /// <remarks>
    /// Playback consumes the recording just like FinishRecording. Further drawing is ignored;
    /// finishing or playing back again raises ESkiaCanvasError.
    /// </remarks>
    procedure Playback(Target: TSkiaCanvas); overload;
    /// <summary>
    /// Ends recording and replays the resulting picture on the target canvas.
    /// </summary>
    /// <remarks>
    /// Playback consumes the recording just like FinishRecording. Further drawing is ignored;
    /// finishing or playing back again raises ESkiaCanvasError.
    /// </remarks>
    procedure Playback(const Target: ISkCanvas); overload;
    /// <summary>
    /// Recording width in canvas units.
    /// </summary>
    property Width: Single read FWidth;
    /// <summary>
    /// Recording height in canvas units.
    /// </summary>
    property Height: Single read FHeight;
  end;

  /// <summary>
  /// Converts a VCL color to a Skia alpha color with explicit opacity.
  /// </summary>
function ColorToAlphaColor(Color: TColor; Alpha: Byte = 255): TAlphaColor;
/// <summary>
/// Converts a Skia alpha color to a VCL RGB color, discarding alpha.
/// </summary>
function AlphaColorToColor(AC: TAlphaColor): TColor;

/// <summary>Creates an integer point without requiring a separate geometry unit.</summary>
function Point(X, Y: Integer): TPoint; inline;
/// <summary>Creates an integer rectangle from its four edges.</summary>
function Rect(ALeft, ATop, ARight, ABottom: Integer): TRect; inline;
/// <summary>Creates a floating-point rectangle from its four edges.</summary>
function RectF(const ALeft, ATop, ARight, ABottom: Single): TRectF;
/// <summary>Creates a floating-point point.</summary>
function PointF(const X, Y: Single): TPointF;

implementation

uses {$IFDEF MSWINDOWS}Vcl.GraphUtil.MetafileParser{$IFDEF FPC}, IntfGraphics, FPImage{$ENDIF}
{$ELSE}IntfGraphics, FPImage, GraphType, Forms{$ENDIF};

{$I SkiaCanvas.Unicode.inc}
{$IFDEF MSWINDOWS}

const
  TT_PRIM_CSPLINE = 3;
function GetKerningPairsW(DC: HDC; Count: DWORD; Pairs: Pointer): DWORD; stdcall; external 'gdi32.dll' name 'GetKerningPairsW';

{$ENDIF}

function ColorToAlphaColor(Color: TColor; Alpha: Byte): TAlphaColor;
var
  C: TColorRef;
begin
  C := ColorToRGB(Color);
  Result := (Cardinal(Alpha) shl 24) or ((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF);
end;

function AlphaColorToColor(AC: TAlphaColor): TColor;
begin
  Result := TColor(((AC shr 16) and $FF) or (AC and $FF00) or ((AC and $FF) shl 16));
end;

{ Portable rectangle and point constructors shared by the supported compilers. }
function Point(X, Y: Integer): TPoint; inline;
begin
  Result.X := X;
  Result.Y := Y;
end;

function Rect(ALeft, ATop, ARight, ABottom: Integer): TRect; inline;
begin
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Right := ARight;
  Result.Bottom := ABottom;
end;

function RectF(const ALeft, ATop, ARight, ABottom: Single): TRectF;
begin
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Right := ARight;
  Result.Bottom := ABottom;
end;

function PointF(const X, Y: Single): TPointF;
begin
  Result.X := X;
  Result.Y := Y;
end;

function RectToRectF(const R: TRect): TRectF; inline;
begin
  Result := RectF(R.Left, R.Top, R.Right, R.Bottom);
end;

function TransformCanvasPoint(const P: TPointF; const M: TMatrix): TPointF;
begin
  Result.X := P.X * M.M11 + P.Y * M.M21 + M.M31;
  Result.Y := P.X * M.M12 + P.Y * M.M22 + M.M32;
end;

constructor TSkiaBrush.Create;
begin
  inherited;
  FAlpha := 255;
  FGradient := gkNone;
  FGradientStartColor := clBlack;
  FGradientEndColor := clWhite;
  FPattern := nil;
end;

destructor TSkiaBrush.Destroy;
begin
  FPattern.Free;
  inherited;
end;

procedure TSkiaBrush.SetAlpha(Value: Byte);
begin
  if FAlpha <> Value then
  begin
    FAlpha := Value;
    Changed;
  end;
end;

procedure TSkiaBrush.SetGradient(Value: TSkiaGradientKind);
begin
  if FGradient <> Value then
  begin
    FGradient := Value;
    Changed;
  end;
end;

procedure TSkiaBrush.SetGradientStartColor(Value: TColor);
begin
  if FGradientStartColor <> Value then
  begin
    FGradientStartColor := Value;
    Changed;
  end;
end;

procedure TSkiaBrush.SetGradientEndColor(Value: TColor);
begin
  if FGradientEndColor <> Value then
  begin
    FGradientEndColor := Value;
    Changed;
  end;
end;

procedure TSkiaBrush.SetPattern(Value: TBitmap);
begin
  if FPattern <> Value then
  begin
    FreeAndNil(FPattern);
    if Value <> nil then
    begin
      FPattern := TBitmap.Create;
      FPattern.Assign(Value);
    end;
    Changed;
  end;
end;

function TSkiaBrush.IsVisible: Boolean;
begin
  Result := (Style <> bsClear) and (FAlpha > 0);
end;

{$IFDEF MSWINDOWS}

function TSkiaBrush.TryAssignFromLogBrush(const LB: TLogBrush): Boolean;
begin
  Result := True;
  { Reset extended brush state before importing the GDI handle. }
  FAlpha := 255;
  FGradient := gkNone;
  FreeAndNil(FPattern);
  case LB.lbStyle of
    BS_SOLID:
      begin
        Style := bsSolid;
        Color := TColor(LB.lbColor and $FFFFFF);
      end;
    BS_NULL:
      Style := bsClear;
    BS_HATCHED:
      begin
        case LB.lbHatch of
          HS_HORIZONTAL:
            Style := bsHorizontal;
          HS_VERTICAL:
            Style := bsVertical;
          HS_FDIAGONAL:
            Style := bsFDiagonal;
          HS_BDIAGONAL:
            Style := bsBDiagonal;
          HS_CROSS:
            Style := bsCross;
          HS_DIAGCROSS:
            Style := bsDiagCross;
        else
          Style := bsSolid;
        end;
        Color := TColor(LB.lbColor and $FFFFFF);
      end;
    BS_PATTERN, BS_DIBPATTERN, BS_DIBPATTERNPT:
      begin
        { Bitmap patterns are resolved by TryAssignFromHandle. }
        Style := bsSolid;
        Color := TColor(LB.lbColor and $FFFFFF);
      end;
  else
    Result := False;
  end;
  if Result then
    Changed;
end;

function TSkiaBrush.TryAssignFromHandle(ABrush: HBRUSH): Boolean;
var
  LB: TLogBrush;
begin
  Result := False;
  if ABrush = 0 then
    Exit;
  FillChar(LB, SizeOf(LB), 0);
  if GetObject(ABrush, SizeOf(LB), @LB) = 0 then
    Exit;
  Result := TryAssignFromLogBrush(LB);
end;

{$ENDIF}

procedure TSkiaBrush.Assign(Source: TPersistent);
var
  B: TSkiaBrush;
begin
  if Source is TSkiaBrush then
  begin
    B := TSkiaBrush(Source);
    FAlpha := B.FAlpha;
    FGradient := B.FGradient;
    FGradientStartColor := B.FGradientStartColor;
    FGradientEndColor := B.FGradientEndColor;
    FreeAndNil(FPattern);
    if B.FPattern <> nil then
    begin
      FPattern := TBitmap.Create;
      FPattern.Assign(B.FPattern);
    end;
    inherited Assign(Source);
  end
  else if Source is TBitmap then
  begin

    SetPattern(TBitmap(Source));
  end
{$IFDEF MSWINDOWS}
  else if (Source is TBrush) and TBrush(Source).HandleAllocated and TryAssignFromHandle(TBrush(Source).Handle) then
  begin

  end
{$ENDIF}
  else
    inherited Assign(Source);
end;

constructor TSkiaPen.Create;
begin
  inherited;
  FAlpha := 255;
  FStrokeCap := TSkStrokeCap.Butt;
  FStrokeJoin := TSkStrokeJoin.Miter;
  FMiterLimit := 4;
  SetLength(FDashPattern, 0);
end;

procedure TSkiaPen.SetAlpha(Value: Byte);
begin
  if FAlpha <> Value then
  begin
    FAlpha := Value;
    Changed;
  end;
end;

procedure TSkiaPen.SetStrokeCap(Value: TSkStrokeCap);
begin
  if FStrokeCap <> Value then
  begin
    FStrokeCap := Value;
    Changed;
  end;
end;

procedure TSkiaPen.SetStrokeJoin(Value: TSkStrokeJoin);
begin
  if FStrokeJoin <> Value then
  begin
    FStrokeJoin := Value;
    Changed;
  end;
end;

procedure TSkiaPen.SetMiterLimit(Value: Single);
begin
  if FMiterLimit <> Value then
  begin
    FMiterLimit := Value;
    Changed;
  end;
end;

procedure TSkiaPen.SetDashPattern(const Value: TArray<Single>);
begin
  FDashPattern := Copy(Value);
  Changed;
end;

function TSkiaPen.IsVisible: Boolean;
begin
  Result := (Style <> psClear) and (FAlpha > 0);
end;

{$IFDEF MSWINDOWS}

function TSkiaPen.TryAssignFromHandle(APen: HPEN): Boolean;
var
  LP: TLogPen;
  ELP: TExtLogPen;
  StyleBits, CapBits, JoinBits: Cardinal;
  I, DashCount: Integer;
begin
  Result := False;
  if APen = 0 then
    Exit;
  { Reset extended pen state before importing the GDI handle. }
  FAlpha := 255;
  FStrokeCap := TSkStrokeCap.Butt;
  FStrokeJoin := TSkStrokeJoin.Miter;
  FMiterLimit := 4;
  SetLength(FDashPattern, 0);

  FillChar(ELP, SizeOf(ELP), 0);
  if GetObject(APen, SizeOf(ELP), @ELP) >= SizeOf(TExtLogPen) - SizeOf(Cardinal) then
  begin

    StyleBits := ELP.elpPenStyle and PS_STYLE_MASK;
    case StyleBits of
      PS_SOLID:
        Style := psSolid;
      PS_DASH:
        Style := psDash;
      PS_DOT:
        Style := psDot;
      PS_DASHDOT:
        Style := psDashDot;
      PS_DASHDOTDOT:
        Style := psDashDotDot;
      PS_NULL:
        Style := psClear;
      PS_INSIDEFRAME:
        Style := psInsideFrame;
      PS_USERSTYLE:
        Style := psSolid;
    else
      Style := psSolid;
    end;
    Width := ELP.elpWidth;
    Color := TColor(ELP.elpColor and $FFFFFF);

    CapBits := ELP.elpPenStyle and PS_ENDCAP_MASK;
    case CapBits of
      PS_ENDCAP_ROUND:
        FStrokeCap := TSkStrokeCap.Round;
      PS_ENDCAP_SQUARE:
        FStrokeCap := TSkStrokeCap.Square;
    else
      FStrokeCap := TSkStrokeCap.Butt;
    end;
    JoinBits := ELP.elpPenStyle and PS_JOIN_MASK;
    case JoinBits of
      PS_JOIN_ROUND:
        FStrokeJoin := TSkStrokeJoin.Round;
      PS_JOIN_BEVEL:
        FStrokeJoin := TSkStrokeJoin.Bevel;
    else
      FStrokeJoin := TSkStrokeJoin.Miter;
    end;

    if StyleBits = PS_USERSTYLE then
    begin
      DashCount := ELP.elpNumEntries;
      if DashCount > 16 then
        DashCount := 16;
      SetLength(FDashPattern, DashCount);
      for I := 0 to DashCount - 1 do
        FDashPattern[I] := ELP.elpStyleEntry[I];
    end;
    Result := True;
  end
  else
  begin
    FillChar(LP, SizeOf(LP), 0);
    if GetObject(APen, SizeOf(LP), @LP) = 0 then
      Exit;
    case LP.lopnStyle of
      PS_SOLID:
        Style := psSolid;
      PS_DASH:
        Style := psDash;
      PS_DOT:
        Style := psDot;
      PS_DASHDOT:
        Style := psDashDot;
      PS_DASHDOTDOT:
        Style := psDashDotDot;
      PS_NULL:
        Style := psClear;
      PS_INSIDEFRAME:
        Style := psInsideFrame;
    else
      Style := psSolid;
    end;
    Width := LP.lopnWidth.X;
    Color := TColor(LP.lopnColor and $FFFFFF);
    Result := True;
  end;
  if Result then
    Changed;
end;

{$ENDIF}

procedure TSkiaPen.Assign(Source: TPersistent);
var
  P: TSkiaPen;
begin
  if Source is TSkiaPen then
  begin
    P := TSkiaPen(Source);
    FAlpha := P.FAlpha;
    FStrokeCap := P.FStrokeCap;
    FStrokeJoin := P.FStrokeJoin;
    FMiterLimit := P.FMiterLimit;
    FDashPattern := Copy(P.FDashPattern);
    inherited Assign(Source);
  end
{$IFDEF MSWINDOWS}
  else if (Source is TPen) and TPen(Source).HandleAllocated and TryAssignFromHandle(TPen(Source).Handle) then
  begin

  end
{$ENDIF}
  else
    inherited Assign(Source);
end;

constructor TSkiaFont.Create;
begin
  inherited;
  FAlpha := 255;
end;

procedure TSkiaFont.SetAlpha(Value: Byte);
begin
  if FAlpha <> Value then
  begin
    FAlpha := Value;
    Changed;
  end;
end;

{$IFDEF MSWINDOWS}

function TSkiaFont.TryAssignFromLogFont(const LF: TLogFontW): Boolean;
var
  St: TFontStyles;
begin
  Result := True;
  FAlpha := 255;
  Name := string(LF.lfFaceName);
  Height := LF.lfHeight;
  St := [];
  if LF.lfWeight >= FW_BOLD then
    Include(St, fsBold);
  if LF.lfItalic <> 0 then
    Include(St, fsItalic);
  if LF.lfUnderline <> 0 then
    Include(St, fsUnderline);
  if LF.lfStrikeOut <> 0 then
    Include(St, fsStrikeOut);
  Style := St;
  Charset := TFontCharset(LF.lfCharSet);
  Pitch := TFontPitch(LF.lfPitchAndFamily and $0F);
  Changed;
end;

function TSkiaFont.TryAssignFromHandle(AFont: HFONT): Boolean;
var
  LF: TLogFontW;
begin
  Result := False;
  if AFont = 0 then
    Exit;
  FillChar(LF, SizeOf(LF), 0);
  if GetObject(AFont, SizeOf(LF), @LF) = 0 then
    Exit;
  Result := TryAssignFromLogFont(LF);
end;

{$ENDIF}

procedure TSkiaFont.Assign(Source: TPersistent);
var
  F: TSkiaFont;
begin
  if Source is TSkiaFont then
  begin
    F := TSkiaFont(Source);
    FAlpha := F.FAlpha;
    inherited Assign(Source);
  end
{$IFDEF MSWINDOWS}
  else if (Source is TFont) and TFont(Source).HandleAllocated and TryAssignFromHandle(TFont(Source).Handle) then
  begin

  end
{$ENDIF}
  else
    inherited Assign(Source);
end;

constructor TSkiaFontManager.Create;
begin
  inherited;
  FLock := SyncObjs.TCriticalSection.Create;
  FNativeFonts := TList<THandle>.Create;
  FCustom := TDictionary<string, ISkTypeface>.Create;
  FCache := TDictionary<string, ISkTypeface>.Create;
end;

destructor TSkiaFontManager.Destroy;
var
  Handle: THandle;
begin
  { Destruction requires all callers to have stopped. Do not invoke change callbacks here. }
  if FNativeFonts <> nil then
{$IFDEF MSWINDOWS} for Handle in FNativeFonts do
      RemoveFontMemResourceEx(Handle){$ELSE}FNativeFonts.Clear{$ENDIF};
  FNativeFonts.Free;
  FCache.Free;
  FCustom.Free;
  FLock.Free;
  inherited;
end;

procedure TSkiaFontManager.DoChange;
var
  Handler: TNotifyEvent;
begin
  FLock.Enter;
  try
    Handler := FOnChange;
  finally
    FLock.Leave;
  end;
  { User callbacks may call other managers or canvases; never hold the cache lock here. }
  if Assigned(Handler) then
    Handler(Self);
end;

function TSkiaFontManager.GetOnChange: TNotifyEvent;
begin
  FLock.Enter;
  try
    Result := FOnChange;
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaFontManager.SetOnChange(const Value: TNotifyEvent);
begin
  FLock.Enter;
  try
    FOnChange := Value;
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaFontManager.Clear;
begin
  FLock.Enter;
  try
    FCache.Clear;
    FCustom.Clear;
    if Assigned(FInternalChange) then
      FInternalChange(Self);
  finally
    FLock.Leave;
  end;
  DoChange;
end;

function TSkiaFontManager.LogFontKey(const LF: TLogFontW): string;
begin

  Result := Format('%s|%d|%d|%d|%d|%d|%d|%d', [string(LF.lfFaceName), LF.lfHeight, LF.lfWeight, LF.lfItalic, LF.lfUnderline, LF.lfStrikeOut, LF.lfCharSet, LF.lfPitchAndFamily]);
end;

function TSkiaFontManager.GetLogFont(AFont: TFont; out LF: TLogFontW): Boolean;
var
  Custom: ISkTypeface;
begin
  FLock.Enter;
  try
    Result := False;
    if AFont = nil then
      Exit;
    FillChar(LF, SizeOf(LF), 0);

{$IFDEF MSWINDOWS}
    if AFont.HandleAllocated and (GetObject(AFont.Handle, SizeOf(LF), @LF) <> 0) then
    begin
      Custom := FindCustom(AFont.Name);
      if Custom <> nil then
        StrPLCopy(LF.lfFaceName, Custom.GetFamilyName, LF_FACESIZE - 1);
      Exit(True);
    end;

{$ENDIF}
    StrPLCopy(LF.lfFaceName, AFont.Name, LF_FACESIZE - 1);
    LF.lfHeight := AFont.Height;
    if fsBold in AFont.Style then
      LF.lfWeight := FW_BOLD
    else
      LF.lfWeight := FW_NORMAL;
    if fsItalic in AFont.Style then
      LF.lfItalic := 1;
    if fsUnderline in AFont.Style then
      LF.lfUnderline := 1;
    if fsStrikeOut in AFont.Style then
      LF.lfStrikeOut := 1;
    LF.lfCharSet := Byte(AFont.Charset);
    Custom := FindCustom(AFont.Name);
    if Custom <> nil then
      StrPLCopy(LF.lfFaceName, Custom.GetFamilyName, LF_FACESIZE - 1);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TSkiaFontManager.FontKey(AFont: TFont): string;
var
  LF: TLogFontW;
begin
  FLock.Enter;
  try
    if GetLogFont(AFont, LF) then
      Result := LogFontKey(LF)
    else
      Result := '';
  finally
    FLock.Leave;
  end;
end;

function TSkiaFontManager.FindCustom(const FamilyName: string): ISkTypeface;
begin
  FLock.Enter;
  try
    if not FCustom.TryGetValue(LowerCase(FamilyName), Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaFontManager.RegisterTypeface(const FamilyName: string; const Typeface: ISkTypeface);
begin
  if Typeface = nil then
  begin
    UnregisterTypeface(FamilyName);
    Exit;
  end;
  FLock.Enter;
  try
    FCustom.AddOrSetValue(LowerCase(FamilyName), Typeface);
    FCache.Clear;
    if Assigned(FInternalChange) then
      FInternalChange(Self);
  finally
    FLock.Leave;
  end;
  DoChange;
end;

procedure TSkiaFontManager.UnregisterTypeface(const FamilyName: string);
var
  Changed: Boolean;
begin
  FLock.Enter;
  try
    Changed := FCustom.ContainsKey(LowerCase(FamilyName));
    if Changed then
    begin
      FCustom.Remove(LowerCase(FamilyName));
      FCache.Clear;
      if Assigned(FInternalChange) then
        FInternalChange(Self);
    end;
  finally
    FLock.Leave;
  end;
  if Changed then
    DoChange;
end;

function TSkiaFontManager.LoadTypefaceFromFile(const FileName: string; ATTCIndex: Integer): ISkTypeface;
var
  Stream: TFileStream;
begin
  if not FileExists(FileName) then
    raise ESkiaCanvasError.CreateFmt(SSkiaFontFileNotFound, [FileName]);

  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadTypefaceFromStream(Stream, ATTCIndex);
  finally
    Stream.Free;
  end;

  if Result = nil then
    raise ESkiaCanvasError.CreateFmt(SSkiaInvalidFontFile, [FileName]);
end;

function TSkiaFontManager.LoadTypefaceFromStream(AStream: TStream; ATTCIndex: Integer): ISkTypeface;
var
  Bytes: TBytes;
  Position: Int64;
  Count: DWORD;
  Handle: THandle;
begin
  if AStream = nil then
    raise ESkiaCanvasError.Create(SSkiaNilFontStream);

  Position := AStream.Position;
  SetLength(Bytes, AStream.Size - Position);
  if Length(Bytes) > 0 then
    AStream.ReadBuffer(Bytes[0], Length(Bytes));
  AStream.Position := Position;

  Result := TSkTypeface.MakeFromStream(AStream, ATTCIndex);
  if Result = nil then
    raise ESkiaCanvasError.Create(SSkiaInvalidFontStream);

{$IFDEF MSWINDOWS}
  Count := 0;
  Handle := AddFontMemResourceEx(Pointer(Bytes), Length(Bytes), nil, @Count);
  if Handle <> 0 then
  begin
    FLock.Enter;
    try
      try
        FNativeFonts.Add(Handle);
      except
        RemoveFontMemResourceEx(Handle);
        raise;
      end;
    finally
      FLock.Leave;
    end;
  end;
{$ENDIF}
end;

function SkFontStyleOf(AIsBold, AIsItalic: Boolean): TSkFontStyle;
begin
  if AIsBold then
    if AIsItalic then
      Result := TSkFontStyle.BoldItalic
    else
      Result := TSkFontStyle.Bold
  else if AIsItalic then
    Result := TSkFontStyle.Italic
  else
    Result := TSkFontStyle.Normal;
end;

function TSkiaFontManager.AcquireTypeface(AFont: TFont): ISkTypeface;
const
  Fallbacks: array [0 .. 1] of string = ('Arial', 'Microsoft Sans Serif');
var
  LF: TLogFontW;
  Key, Name: string;
  IsBold, IsItalic: Boolean;
  I: Integer;
begin
  FLock.Enter;
  try
    if AFont <> nil then
    begin
      Result := FindCustom(AFont.Name);
      if Result <> nil then
        Exit;
    end;
    Result := nil;
    if not GetLogFont(AFont, LF) then
      Exit;
    Name := string(LF.lfFaceName);

    Result := FindCustom(Name);
    if Result <> nil then
      Exit;

    Key := LogFontKey(LF);
    if FCache.TryGetValue(Key, Result) then
      Exit;

    IsBold := LF.lfWeight >= FW_BOLD;
    IsItalic := LF.lfItalic <> 0;
    for I := -1 to High(Fallbacks) do
    begin
      if I = -1 then
        Result := TSkTypeface.MakeFromName(Name, SkFontStyleOf(IsBold, IsItalic))
      else
        Result := TSkTypeface.MakeFromName(Fallbacks[I], SkFontStyleOf(IsBold, IsItalic));
      if Result <> nil then
      begin
        FCache.Add(Key, Result);
        Exit;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

{$I SkiaCanvas.FontMatching.inc}

constructor TSkiaResourceManager.Create;
begin
  inherited;
  FFontManager := TSkiaFontManager.Create;
  FLock := FFontManager.FLock;
  FFontManager.FInternalChange := FontManagerChanged;
  InvalidateAll;
end;

procedure TSkiaResourceManager.FontManagerChanged(Sender: TObject);
begin
  InvalidateFont;
end;

destructor TSkiaResourceManager.Destroy;
begin
  if FFontManager <> nil then
    FFontManager.FInternalChange := nil;
  FFontManager.Free;
  inherited;
end;

{$IFDEF MSWINDOWS}
function GdiNativeOutlineToSkPath(Buf: Pointer; BufSize: DWORD; Path: ISkiaPathBuilder): Boolean; forward;

type
  { SCRIPT_ANALYSIS packs script flags and SCRIPT_STATE into four bytes. }
  PScriptAnalysis = ^TScriptAnalysis;

  TScriptAnalysis = packed record
    Flags: Word; { bits 0..9: eScript, 10: fRTL, 14: fLogicalOrder, 15: fNoGlyphIndex }
    State: Word; { Low five bits: uBidiLevel. }
  end;

  PScriptItem = ^TScriptItem;

  TScriptItem = packed record
    iCharPos: Integer;
    a: TScriptAnalysis;
  end;

  PScriptGOffset = ^TScriptGOffset;

  TScriptGOffset = packed record
    du: Integer;
    dv: Integer;
  end;

  TOpenTypeFeature = record
    Tag, Parameter: Cardinal;
  end;

  TOpenTypeRange = record
    Features: Pointer;
    Count: Integer;
  end;

  TScriptItemizeOpenTypeFn = function(Text: PWideChar; Count, MaxItems: Integer; Control, State: Pointer; Items: PScriptItem; Tags: Pointer; ItemCount: PInteger): HResult; stdcall;
  TScriptShapeOpenTypeFn = function(DC: HDC; var Cache: Pointer; Analysis: PScriptAnalysis; ScriptTag, LanguageTag: Cardinal; RangeChars, RangeProperties: Pointer; RangeCount: Integer;
    Text: PWideChar; CharCount, MaxGlyphs: Integer; Clusters, CharProps: PWord; Glyphs: PWord; GlyphProps: Pointer; GlyphCount: PInteger): HResult; stdcall;
  TScriptPlaceOpenTypeFn = function(DC: HDC; var Cache: Pointer; Analysis: PScriptAnalysis; ScriptTag, LanguageTag: Cardinal; RangeChars, RangeProperties: Pointer; RangeCount: Integer;
    Text: PWideChar; Clusters, CharProps: PWord; CharCount: Integer; Glyphs: PWord; GlyphProps: Pointer; GlyphCount: Integer; Advances: PInteger; Offsets: PScriptGOffset; ABC: Pointer)
    : HResult; stdcall;
  TScriptLayoutFn = function(cRuns: Integer; const pbLevel: PByte; piVisualToLogical: PInteger; piLogicalToVisual: PInteger): HResult; stdcall;
  TScriptFreeCacheFn = function(var psc: Pointer): HResult; stdcall;

const
  USP_E_SCRIPT_NOT_IN_FONT = HResult($80040200);

function UspFailed(hr: HResult): Boolean; inline;
begin
  Result := hr < 0;
end;

constructor TSkiaGdiGlyphCache.Create;
begin
  inherited;
  FLock := SyncObjs.TCriticalSection.Create;
  FPaths := TDictionary<string, ISkPath>.Create;
  FAdvances := TDictionary<string, Single>.Create;
  FKern := TDictionary<Cardinal, Single>.Create;
  FDC := 0;
  FFont := 0;
  FStockFont := 0;
  FScriptCache := nil;
  FLastShapeUsedOpenType := False;
end;

destructor TSkiaGdiGlyphCache.Destroy;
begin
  if FLock <> nil then
    Clear;
  FKern.Free;
  FAdvances.Free;
  FPaths.Free;
  FLock.Free;
  inherited;
end;

procedure TSkiaGdiGlyphCache.Lock;
begin
  FLock.Enter;
end;

procedure TSkiaGdiGlyphCache.Unlock;
begin
  FLock.Leave;
end;

function TSkiaGdiGlyphCache.GetLastShapeUsedOpenType: Boolean;
begin
  FLock.Enter;
  try
    Result := FLastShapeUsedOpenType;
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaGdiGlyphCache.Clear;
begin
  FLock.Enter;
  try

    if (FScriptCache <> nil) and Assigned(TScriptFreeCacheFn(FScriptFreeCache)) then
      TScriptFreeCacheFn(FScriptFreeCache)(FScriptCache);
    FScriptCache := nil;
    if FUspLib <> 0 then
    begin
      FreeLibrary(FUspLib);
      FUspLib := 0;
    end;
    FUspTried := False;
    FScriptItemizeOpenType := nil;
    FScriptShapeOpenType := nil;
    FScriptPlaceOpenType := nil;
    FScriptLayout := nil;
    FScriptFreeCache := nil;
    { Restore the original DC font before deleting the owned font. }
    if FFont <> 0 then
    begin
      if FDC <> 0 then
      begin
        if FStockFont <> 0 then
          SelectObject(FDC, FStockFont)
        else
          SelectObject(FDC, 0);
      end;
      DeleteObject(FFont);
      FFont := 0;
    end;
    FStockFont := 0;
    if FDC <> 0 then
    begin
      DeleteDC(FDC);
      FDC := 0;
    end;
    FFontKey := '';
    FShapingEmSquare := 0;
    FLastShapeUsedOpenType := False;
    FEmSquareKey := '';
    FEmSquare := 0;
    FCharHeightKey := '';
    FCharHeight := 0;
    FKernKey := '';
    if FPaths <> nil then
      FPaths.Clear;
    if FAdvances <> nil then
      FAdvances.Clear;
    if FKern <> nil then
      FKern.Clear;
  finally
    FLock.Leave;
  end;
end;

function TSkiaGdiGlyphCache.GlyphKey(GlyphIndex: Word): string;
begin
  { The font key is implicit: changing fonts clears this cache. }
  Result := IntToStr(GlyphIndex);
end;

{ Select an EM-height font so GDI logical advances equal font design units without rounding. }
procedure TSkiaGdiGlyphCache.EnsureShapingFont(const LF: TLogFontW; const FontKey: string; EmSquare: Integer);
var
  ShapingLF: TLogFontW;
  ScreenDC: HDC;
begin
  if FDC = 0 then
  begin
    ScreenDC := GetDC(0);
    if ScreenDC <> 0 then
      try
        FDC := CreateCompatibleDC(ScreenDC);
      finally
        ReleaseDC(0, ScreenDC);
      end;
  end;
  if FDC = 0 then
    Exit;
  if (FFont <> 0) and (FFontKey = FontKey) and (FShapingEmSquare = EmSquare) then
    Exit;
  if FFont <> 0 then
  begin
    if FStockFont <> 0 then
      SelectObject(FDC, FStockFont)
    else
      SelectObject(FDC, 0);
    DeleteObject(FFont);
    FFont := 0;
    FStockFont := 0;
  end;
  { SCRIPT_CACHE and kerning pairs depend on the selected font. }
  if (FScriptCache <> nil) and Assigned(TScriptFreeCacheFn(FScriptFreeCache)) then
    TScriptFreeCacheFn(FScriptFreeCache)(FScriptCache);
  FScriptCache := nil;
  FKern.Clear;
  FKernKey := '';
  FPaths.Clear;
  FAdvances.Clear;
  FShapingEmSquare := EmSquare;
  ShapingLF := LF;
  ShapingLF.lfHeight := -EmSquare;
  ShapingLF.lfWidth := 0;
  FFont := CreateFontIndirectW(ShapingLF);
  FFontKey := FontKey;
  if FFont <> 0 then
    FStockFont := SelectObject(FDC, FFont);
end;

{ Use a non-nested callback to match the EnumFontFamiliesExW calling convention. }
function GdiEmSquareEnumProc(const LogFont: TEnumLogFontExW; const Metrics: TNewTextMetricW; FontType: DWORD; Param: LPARAM): Integer; stdcall;
begin
  PInteger(Param)^ := Integer(Metrics.ntmSizeEM);
  Result := 0;
end;

function TSkiaGdiGlyphCache.GetEmSquare(const LF: TLogFontW; const FontKey: string): Integer;
var
  DC: HDC;
  Em: Integer;
begin
  FLock.Enter;
  try

    if (FEmSquareKey = FontKey) and (FEmSquare > 0) then
      Exit(FEmSquare);
    Result := 0;
    DC := CreateCompatibleDC(0);
    if DC = 0 then
      Exit;
    try
      Em := 0;
      EnumFontFamiliesExW(DC, LF, @GdiEmSquareEnumProc, LPARAM(@Em), 0);
      Result := Em;
    finally
      DeleteDC(DC);
    end;
    if Result > 0 then
    begin
      FEmSquare := Result;
      FEmSquareKey := FontKey;
    end;
  finally
    FLock.Leave;
  end;
end;

{ The design-to-pixel scale uses (tmHeight - tmInternalLeading) / EmSquare. }
function TSkiaGdiGlyphCache.GetCharHeight(const LF: TLogFontW; const FontKey: string): Integer;
var
  DC: HDC;
  NewFont, OldFont: HFONT;
  TM: TTextMetricW;
begin
  FLock.Enter;
  try
    if (FCharHeightKey = FontKey) and (FCharHeight > 0) then
      Exit(FCharHeight);
    Result := 0;
    DC := CreateCompatibleDC(0);
    if DC = 0 then
      Exit;
    NewFont := CreateFontIndirectW(LF);
    if NewFont = 0 then
    begin
      DeleteDC(DC);
      Exit;
    end;
    OldFont := SelectObject(DC, NewFont);
    try
      FillChar(TM, SizeOf(TM), 0);
      if GetTextMetricsW(DC, TM) then
        Result := TM.tmHeight - TM.tmInternalLeading;
    finally
      SelectObject(DC, OldFont);
      DeleteObject(NewFont);
      DeleteDC(DC);
    end;
    if Result > 0 then
    begin
      FCharHeight := Result;
      FCharHeightKey := FontKey;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSkiaGdiGlyphCache.GetGlyphPathByIndex(GlyphIndex: Word; out Advance: Single): ISkPath;
var
  Key: string;
  GM: GLYPHMETRICS;
  Mat: MAT2;
  BufSize: DWORD;
  Buf: TBytes;
  Path: ISkiaPathBuilder;
begin
  FLock.Enter;
  try
    Result := nil;
    Advance := 0;
    Key := GlyphKey(GlyphIndex);

    if FAdvances.TryGetValue(Key, Advance) then
    begin
      FPaths.TryGetValue(Key, Result);
      Exit;
    end;
    if (FDC = 0) or (FFont = 0) then
      Exit;
    FillChar(Mat, SizeOf(Mat), 0);
    Mat.eM11.Value := 1;
    Mat.eM22.Value := 1;
    FillChar(GM, SizeOf(GM), 0);
    BufSize := GetGlyphOutlineW(FDC, GlyphIndex, GGO_NATIVE or GGO_GLYPH_INDEX,
{$IFDEF FPC}@GM{$ELSE}GM{$ENDIF}, 0, nil, {$IFDEF FPC}@Mat{$ELSE}Mat{$ENDIF});
    { Read the advance even when no outline exists, including spaces and failed outline queries. }
    Advance := GM.gmCellIncX;
    FAdvances.AddOrSetValue(Key, Advance);
    if (BufSize = 0) or (BufSize = GDI_ERROR) then
      Exit;
    SetLength(Buf, BufSize);
    if GetGlyphOutlineW(FDC, GlyphIndex, GGO_NATIVE or GGO_GLYPH_INDEX, {$IFDEF FPC}@GM{$ELSE}GM{$ENDIF}, BufSize, @Buf[0], {$IFDEF FPC}@Mat{$ELSE}Mat{$ENDIF}) = GDI_ERROR then
      Exit;
    Path := TSkiaPathBuilder.Create;
    if GdiNativeOutlineToSkPath(@Buf[0], BufSize, Path) then
    begin
      Result := Path.Snapshot;
      FPaths.AddOrSetValue(Key, Result);
    end
    else
      Path := nil;
  finally
    FLock.Leave;
  end;
end;

function TSkiaGdiGlyphCache.GetGlyphIndexForChar(Ch: WideChar): Word;
var
  Idx: Word;
begin
  Idx := $FFFF;
  if (FDC <> 0) and (FFont <> 0) then
    GetGlyphIndicesW(FDC, @Ch, 1, @Idx, 0);
  if Idx = $FFFF then
    Idx := 0; { .notdef }
  Result := Idx;
end;

function TSkiaGdiGlyphCache.GetGlyphIndexForPair(Hi, Lo: WideChar): Word;
var
  Pair: array [0 .. 1] of WideChar;
  Idxs: array [0 .. 1] of Word;
begin
  Idxs[0] := $FFFF;
  Idxs[1] := $FFFF;
  if (FDC <> 0) and (FFont <> 0) then
  begin
    Pair[0] := Hi;
    Pair[1] := Lo;
    GetGlyphIndicesW(FDC, @Pair[0], 2, @Idxs[0], 0);
  end;
  if Idxs[0] = $FFFF then
    Idxs[0] := 0;
  Result := Idxs[0];
end;

{ The EM-height DC font makes GDI kerning amounts equal font design units. }
function TSkiaGdiGlyphCache.GetKerning(First, Second: Word): Single;
var
  Key: Cardinal;
  Count: DWORD;
  Pairs: TArray<TKerningPair>;
  I: Integer;
begin
  Result := 0;
  if (FDC = 0) or (FFont = 0) then
    Exit;
  if FKernKey <> FFontKey then
  begin
    FKern.Clear;
    FKernKey := FFontKey;
    Count := GetKerningPairsW(FDC, 0, nil);
    if Count > 0 then
    begin
      SetLength(Pairs, Count);
      if GetKerningPairsW(FDC, Count, @Pairs[0]) = Count then
        for I := 0 to Count - 1 do
          FKern.AddOrSetValue((Cardinal(GetGlyphIndexForChar(WideChar(Pairs[I].wFirst))) shl 16) or GetGlyphIndexForChar(WideChar(Pairs[I].wSecond)), Pairs[I].iKernAmount);
    end;
  end;
  Key := (Cardinal(First) shl 16) or Second;
  FKern.TryGetValue(Key, Result);
end;

function TSkiaGdiGlyphCache.LoadUsp10: Boolean;
begin
  if (SizeOf(TScriptAnalysis) <> 4) or (SizeOf(TScriptItem) <> 8) or (SizeOf(TScriptGOffset) <> 8) or (SizeOf(TOpenTypeRange) <> 2 * SizeOf(Pointer)) then
    raise ESkiaCanvasError.Create(SSkiaOpenTypeAbiMismatch);
  if FUspTried then
    Exit(FUspLib <> 0);
  FUspTried := True;
  FUspLib := LoadLibraryW('usp10.dll');
  if FUspLib <> 0 then
  begin
    FScriptItemizeOpenType := GetProcAddress(FUspLib, 'ScriptItemizeOpenType');
    FScriptShapeOpenType := GetProcAddress(FUspLib, 'ScriptShapeOpenType');
    FScriptPlaceOpenType := GetProcAddress(FUspLib, 'ScriptPlaceOpenType');
    FScriptLayout := GetProcAddress(FUspLib, 'ScriptLayout');
    FScriptFreeCache := GetProcAddress(FUspLib, 'ScriptFreeCache');
    if not(Assigned(FScriptItemizeOpenType) and Assigned(FScriptShapeOpenType) and Assigned(FScriptPlaceOpenType) and Assigned(FScriptLayout) and Assigned(FScriptFreeCache)) then
    begin
      FreeLibrary(FUspLib);
      FUspLib := 0;
      FScriptItemizeOpenType := nil;
      FScriptShapeOpenType := nil;
      FScriptPlaceOpenType := nil;
      FScriptLayout := nil;
      FScriptFreeCache := nil;
    end;
  end;
  Result := FUspLib <> 0;
end;

{ Uniscribe performs ligatures, kerning, contextual shaping and bidi layout; output is in visual order. }
function TSkiaGdiGlyphCache.UspShapeText(const Text: UnicodeString; Shaped: TList<TGdiShapedGlyph>): Boolean;
const
  E_OUTOFMEMORY = HResult($8007000E);
var
  Items: TArray<TScriptItem>;
  ItemCount, CapItems: Integer;
  hr: HResult;
  Levels: TArray<Byte>;
  VisToLog: TArray<Integer>;
  Vi, Li, I, J: Integer;
  Start, Cnt: Integer;
  MaxG, GotG: Integer;
  GW: TArray<Word>;
  LogClust: TArray<Word>;
  CharProps: TArray<Word>;
  GlyphProps, Tags: TArray<Cardinal>;
  Control: Cardinal;
  State: Word;
  Scalars: TArray<Cardinal>;
  Feature: TOpenTypeFeature;
  FeatureRange: TOpenTypeRange;
  RangePointer: Pointer;
  RangeLength: Integer;
  Adv: TArray<Integer>;
  Off: TArray<TScriptGOffset>;
  G: TGdiShapedGlyph;
begin
  Result := False;
  FLastShapeUsedOpenType := False;

  try
    Scalars := TSkiaUnicode.CodePoints(Text);
  except
    on E: ESkiaCanvasError do
      Exit;
  end;

  CapItems := 16;
  repeat
    SetLength(Items, CapItems + 1);
    SetLength(Tags, CapItems);
    Control := 0;
    State := TSkiaUnicode.ParagraphLevel(Text);
    ItemCount := 0;
    hr := TScriptItemizeOpenTypeFn(FScriptItemizeOpenType)(PWideChar(Text), Length(Text), CapItems, @Control, @State, @Items[0], @Tags[0], @ItemCount);
    if hr = E_OUTOFMEMORY then
    begin
      if CapItems > MaxInt div 2 then
        Exit;
      CapItems := CapItems * 2;
      Continue;
    end;
    Break;
  until False;
  if UspFailed(hr) or (ItemCount <= 0) then
    Exit;
  if (ItemCount > Length(Tags)) or (ItemCount + 1 > Length(Items)) or (Items[0].iCharPos <> 0) or (Items[ItemCount].iCharPos <> Length(Text)) then
    Exit; { No valid terminal item. }

  for I := 0 to ItemCount - 1 do
    if (Items[I].iCharPos < 0) or (Items[I + 1].iCharPos <= Items[I].iCharPos) or (Items[I + 1].iCharPos > Length(Text)) then
      Exit;

  SetLength(Levels, ItemCount);
  for I := 0 to ItemCount - 1 do
    Levels[I] := Byte(Items[I].a.State and $1F); { uBidiLevel }
  SetLength(VisToLog, ItemCount);
  hr := TScriptLayoutFn(FScriptLayout)(ItemCount, @Levels[0], @VisToLog[0], nil);
  if UspFailed(hr) then
    Exit;

  for Vi := 0 to ItemCount - 1 do
  begin
    Li := VisToLog[Vi];
    if (Li < 0) or (Li >= ItemCount) then
      Exit;
    Start := Items[Li].iCharPos;
    Cnt := Items[Li + 1].iCharPos - Start;
    if Cnt <= 0 then
      Continue;

    Items[Li].a.Flags := Items[Li].a.Flags and not $8000; { Clear fNoGlyphIndex; the script identifier occupies the low ten bits. }
    Feature.Tag := $6E72656B;
    Feature.Parameter := 1; { kern }
    FeatureRange.Features := @Feature;
    FeatureRange.Count := 1;
    RangePointer := @FeatureRange;
    RangeLength := Cnt;
    if Cnt > (MaxInt - 16) div 3 then
      Exit;
    MaxG := Cnt * 3 + 16;
    repeat
      SetLength(GW, MaxG);
      SetLength(LogClust, Cnt);
      SetLength(GlyphProps, MaxG);
      SetLength(CharProps, Cnt);
      GotG := 0;
      hr := TScriptShapeOpenTypeFn(FScriptShapeOpenType)(FDC, FScriptCache, @Items[Li].a, Tags[Li], 0, @RangeLength, @RangePointer, 1, @Text[Start + 1], Cnt, MaxG, @LogClust[0], @CharProps[0], @GW[0],
        @GlyphProps[0], @GotG);
      if hr = E_OUTOFMEMORY then
      begin
        if MaxG > MaxInt div 2 then
          Exit;
        MaxG := MaxG * 2;
        Continue;
      end;
      Break;
    until False;
    { Cluster indexes are WORDs; reject an unaddressable run rather than wrap them. }
    if UspFailed(hr) or (GotG <= 0) or (GotG > MaxG) or (GotG > Integer(High(Word)) + 1) or ((Items[Li].a.Flags and $8000) <> 0) then
      Exit; { A failed run invalidates the complete shaping result. }
    SetLength(Adv, GotG);
    SetLength(Off, GotG);
    hr := TScriptPlaceOpenTypeFn(FScriptPlaceOpenType)(FDC, FScriptCache, @Items[Li].a, Tags[Li], 0, @RangeLength, @RangePointer, 1, @Text[Start + 1], @LogClust[0], @CharProps[0], Cnt, @GW[0],
      @GlyphProps[0], GotG, @Adv[0], @Off[0], nil);
    if UspFailed(hr) then
      Exit;
    { ScriptShapeOpenType returns visual order unless fLogicalOrder is explicitly set. }
    if (Items[Li].a.Flags and $4400) = $4400 then { fRTL and fLogicalOrder }
    begin
      for J := GotG - 1 downto 0 do
      begin
        G.GlyphIndex := GW[J];
        G.AdvanceX := Adv[J];
        G.OffsetX := Off[J].du;
        G.OffsetY := Off[J].dv;
        Shaped.Add(G);
      end;
    end
    else
      for J := 0 to GotG - 1 do
      begin
        G.GlyphIndex := GW[J];
        G.AdvanceX := Adv[J];
        G.OffsetX := Off[J].du;
        G.OffsetY := Off[J].dv;
        Shaped.Add(G);
      end;
  end;
  Result := True;
  FLastShapeUsedOpenType := True;
end;

{ Fallback maps UTF-16 characters to glyphs, preserves surrogate pairs and applies GDI pair kerning. }
procedure TSkiaGdiGlyphCache.FallbackShapeText(const Text: UnicodeString; Shaped: TList<TGdiShapedGlyph>);
var
  I, N: Integer;
  W: WideChar;
  Idx, PrevIdx: Word;
  HasPrev: Boolean;
  G: TGdiShapedGlyph;
  Adv, Kern: Single;
  Previous: TGdiShapedGlyph;
begin
  N := Length(Text);
  I := 1;
  HasPrev := False;
  PrevIdx := 0;
  while I <= N do
  begin
    W := Text[I];
    { Map the complete surrogate pair to one glyph. }
    if (W >= #$D800) and (W <= #$DBFF) and (I < N) and (Text[I + 1] >= #$DC00) and (Text[I + 1] <= #$DFFF) then
    begin
      Idx := GetGlyphIndexForPair(W, Text[I + 1]);
      Inc(I, 2);
    end
    else if (W >= #$D800) and (W <= #$DFFF) then
    begin
      Inc(I); { Skip an unpaired surrogate. }
      Continue;
    end
    else
    begin
      { C0 controls have zero advance. }
      if Ord(W) < 32 then
      begin
        Inc(I);
        Continue;
      end;
      Idx := GetGlyphIndexForChar(W);
      Inc(I);
    end;

    GetGlyphPathByIndex(Idx, Adv);
    G.GlyphIndex := Idx;
    G.AdvanceX := Adv;
    G.OffsetX := 0;
    G.OffsetY := 0;
    { Adjust the previous advance so kerning affects both placement and width. }
    if HasPrev then
    begin
      Kern := GetKerning(PrevIdx, Idx);
      Previous := Shaped[Shaped.Count - 1];
      Previous.AdvanceX := Previous.AdvanceX + Kern;
      Shaped[Shaped.Count - 1] := Previous;
    end;
    Shaped.Add(G);
    PrevIdx := Idx;
    HasPrev := True;
  end;
end;

function TSkiaGdiGlyphCache.ShapeText(const LF: TLogFontW; const FontKey: string; EmSquare: Integer; const Text: UnicodeString; out Glyphs: TArray<TGdiShapedGlyph>; RequireOpenType: Boolean): Boolean;
var
  List: TList<TGdiShapedGlyph>;
begin
  FLock.Enter;
  try
    Result := False;
    FLastShapeUsedOpenType := False;
    SetLength(Glyphs, 0);
    if Text = '' then
      Exit(True);
    if EmSquare <= 0 then
      Exit;
    EnsureShapingFont(LF, FontKey, EmSquare);
    if (FDC = 0) or (FFont = 0) then
      Exit;
    List := TList<TGdiShapedGlyph>.Create;
    try
      if LoadUsp10 then
      begin
        { Fall back to glyph mapping and kerning when Uniscribe cannot shape the text. }
        if not UspShapeText(Text, List) then
        begin
          if RequireOpenType then
            Exit;
          List.Clear;
          FallbackShapeText(Text, List);
        end;
      end
      else
      begin
        if RequireOpenType then
          Exit;
        FallbackShapeText(Text, List);
      end;
      Glyphs := List.ToArray;
      Result := True;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{$ELSE}
{$I SkiaCanvas.NativeGlyphs.inc}
{$ENDIF}

function TSkiaResourceManager.BrushKey(ABrush: TSkiaBrush; const Bounds: TRectF): string;
begin
  { Gradient shaders depend on the fill bounds; other brushes do not. }
  if ABrush.Gradient <> gkNone then
    Result := Format('b%d|%x|%d|%d|%x|%x|%p|%g|%g|%g|%g', [Ord(ABrush.Style), ColorToAlphaColor(ABrush.Color, ABrush.Alpha), ABrush.Alpha, Ord(ABrush.Gradient),
      ColorToAlphaColor(ABrush.GradientStartColor), ColorToAlphaColor(ABrush.GradientEndColor), Pointer(ABrush.Pattern), Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom])
  else
    Result := Format('b%d|%x|%d|%d|%x|%x|%p', [Ord(ABrush.Style), ColorToAlphaColor(ABrush.Color, ABrush.Alpha), ABrush.Alpha, Ord(ABrush.Gradient), ColorToAlphaColor(ABrush.GradientStartColor),
      ColorToAlphaColor(ABrush.GradientEndColor), Pointer(ABrush.Pattern)]);
end;

function TSkiaResourceManager.PenKey(APen: TSkiaPen): string;
var
  I: Integer;
begin
  Result := Format('p%d|%x|%d|%d|%d|%d|%g|%d|', [Ord(APen.Style), ColorToAlphaColor(APen.Color, APen.Alpha), APen.Width, APen.Alpha, Ord(APen.StrokeCap), Ord(APen.StrokeJoin), APen.MiterLimit,
    Length(APen.DashPattern)]);
  for I := 0 to High(APen.DashPattern) do
    Result := Result + Format('%g;', [APen.DashPattern[I]]);
end;

{ Deterministic VCL/GDI-compatible 8 x 8 hatch phase on every platform. }
function MakeHatchImage(Style: TBrushStyle; FG: TAlphaColor): ISkImage;
var
  Pixels: TArray<TAlphaColor>;
  X, Y: Integer;
  Active: Boolean;
begin
  SetLength(Pixels, 64);
  for Y := 0 to 7 do
    for X := 0 to 7 do
    begin
      case Style of
        bsHorizontal:
          Active := Y = 3;
        bsVertical:
          Active := X = 4;
        bsFDiagonal:
          Active := X = Y;
        bsBDiagonal:
          Active := X + Y = 7;
        bsCross:
          Active := (Y = 3) or (X = 4);
        bsDiagCross:
          Active := (X = Y) or (X + Y = 7);
      else
        Active := False;
      end;
      if Active then
        Pixels[Y * 8 + X] := FG;
    end;
  Result := TSkImage.MakeRasterCopy(TSkImageInfo.Create(8, 8, TSkColorType.BGRA8888, TSkAlphaType.Unpremul), Pointer(Pixels), 8 * SizeOf(TAlphaColor));
end;

{ Convert VCL bitmap pixels to an unpremultiplied Skia image, preserving defined alpha and color keys. }
function BitmapToSkImage(ABitmap: TBitmap): ISkImage;
var
  Pixels: TArray<TAlphaColor>;
  X, Y: Integer;
  Row: PCardinal;
  C: Cardinal;
{$IFDEF FPC}Image: TLazIntfImage;
  Color: TFPColor;
  RowPixels: TArray<Cardinal>; {$ENDIF}
begin
  Result := nil;
  if (ABitmap = nil) or (ABitmap.Width <= 0) or (ABitmap.Height <= 0) then
    Exit;
{$IFDEF FPC}
  { LCL SetPixelFormat discards the image; read its actual channel layout instead. }
  Image := ABitmap.CreateIntfImage;
  try
    SetLength(RowPixels, ABitmap.Width);
{$ELSE}
  ABitmap.PixelFormat := pf32bit;
{$ENDIF}
  SetLength(Pixels, ABitmap.Width * ABitmap.Height);
  for Y := 0 to ABitmap.Height - 1 do
  begin
{$IFDEF FPC}
    for X := 0 to ABitmap.Width - 1 do
    begin
      Color := Image.Colors[X, Y];
      RowPixels[X] := (Cardinal(Color.Alpha shr 8) shl 24) or (Cardinal(Color.Red shr 8) shl 16) or (Cardinal(Color.Green shr 8) shl 8) or Cardinal(Color.Blue shr 8);
    end;
    Row := Pointer(RowPixels);
{$ELSE}
    Row := ABitmap.ScanLine[Y];
{$ENDIF}
    if Row = nil then
      Continue;
    for X := 0 to ABitmap.Width - 1 do
    begin
      C := Row[X] and $FFFFFF;

      if ABitmap.AlphaFormat = afIgnored then
        Pixels[Y * ABitmap.Width + X] := $FF000000 or C
      else
        Pixels[Y * ABitmap.Width + X] := Row[X];
      if (ABitmap.AlphaFormat = afPremultiplied) and (Row[X] shr 24 > 0) then
        Pixels[Y * ABitmap.Width + X] := (Row[X] and $FF000000) or Cardinal(Math.Min(255, Integer(Row[X] and 255) * 255 div Integer(Row[X] shr 24))) or
          (Cardinal(Math.Min(255, Integer((Row[X] shr 8) and 255) * 255 div Integer(Row[X] shr 24))) shl 8) or
          (Cardinal(Math.Min(255, Integer((Row[X] shr 16) and 255) * 255 div Integer(Row[X] shr 24))) shl 16);
      { In LCL Transparent also means an alpha channel, not a color-key mask. }
      if {$IFDEF FPC}ABitmap.Masked{$ELSE}ABitmap.Transparent{$ENDIF} and (C = (ColorToAlphaColor(ABitmap.TransparentColor) and $FFFFFF)) then
        Pixels[Y * ABitmap.Width + X] := 0;

    end;
  end;
  Result := TSkImage.MakeRasterCopy(

    TSkImageInfo.Create(ABitmap.Width, ABitmap.Height, TSkColorType.BGRA8888, TSkAlphaType.Unpremul), Pointer(Pixels), ABitmap.Width * SizeOf(TAlphaColor));
{$IFDEF FPC} finally
  Image.Free;
end; {$ENDIF}
end;

function TSkiaResourceManager.BuildFillPaint(ABrush: TSkiaBrush; const Bounds: TRectF): ISkPaint;
var
  Img: ISkImage;
  P1, P2: TPointF;
begin
  Result := TSkPaint.Create;
  Result.Style := TSkPaintStyle.Fill;
  Result.AntiAlias := True;
  Result.Alpha := ABrush.Alpha;
  case ABrush.Style of
    bsSolid:
      begin
        Result.Color := ColorToAlphaColor(ABrush.Color);
        Result.Alpha := ABrush.Alpha;
      end;
    bsClear:
      begin
        Result := nil;
        Exit;
      end;
    bsHorizontal, bsVertical, bsFDiagonal, bsBDiagonal, bsCross, bsDiagCross:
      begin
        Img := MakeHatchImage(ABrush.Style, ColorToAlphaColor(ABrush.Color, ABrush.Alpha));
        Result.Shader := TSkShader.MakeImage(Img, TSkTileMode.&Repeat, TSkTileMode.&Repeat);
        { The shader already supplies the color and alpha. }
        Result.Alpha := 255;
      end;
  else
    begin
      Result.Color := ColorToAlphaColor(ABrush.Color);
      Result.Alpha := ABrush.Alpha;
    end;
  end;
  { A gradient overrides the bitmap pattern; either overrides a non-clear basic brush style. }
  if ABrush.Gradient <> gkNone then
  begin
    case ABrush.Gradient of
      gkHorizontal:
        begin
          P1 := PointF(Bounds.Left, Bounds.Top);
          P2 := PointF(Bounds.Right, Bounds.Top);
        end;
      gkVertical:
        begin
          P1 := PointF(Bounds.Left, Bounds.Top);
          P2 := PointF(Bounds.Left, Bounds.Bottom);
        end;
    else
      P1 := PointF(0, 0);
      P2 := PointF(0, 0);
    end;
    Result.Shader := TSkShader.MakeGradientLinear(P1, P2, ColorToAlphaColor(ABrush.GradientStartColor, ABrush.Alpha), ColorToAlphaColor(ABrush.GradientEndColor, ABrush.Alpha));
    Result.Alpha := 255;
  end
  else if ABrush.Pattern <> nil then
  begin
    Img := BitmapToSkImage(ABrush.Pattern);
    if Img <> nil then
    begin
      Result.Shader := TSkShader.MakeImage(Img, TSkTileMode.&Repeat, TSkTileMode.&Repeat);
      Result.Alpha := ABrush.Alpha;
    end;
  end;
end;

function DashIntervalsForStyle(Style: TPenStyle; Width: Single; const Custom: TArray<Single>): TArray<Single>;
var
  W: Single;
begin
  W := Math.Max(Single(1), Width);
  if Length(Custom) > 0 then
  begin
    Result := Copy(Custom);
    Exit;
  end;
  case Style of
    psDash:
      Result := TArray<Single>.Create(6 * W, 2 * W);
    psDot:
      Result := TArray<Single>.Create(1 * W, 1 * W);
    psDashDot:
      Result := TArray<Single>.Create(6 * W, 2 * W, 1 * W, 2 * W);
    psDashDotDot:
      Result := TArray<Single>.Create(6 * W, 2 * W, 1 * W, 2 * W, 1 * W, 2 * W);
  else
    SetLength(Result, 0);
  end;
end;

function TSkiaResourceManager.BuildStrokePaint(APen: TSkiaPen): ISkPaint;
var
  Intervals: TArray<Single>;
begin
  if APen.Style = psClear then
  begin
    Result := nil;
    Exit;
  end;
  Result := TSkPaint.Create;
  Result.Style := TSkPaintStyle.Stroke;
  Result.AntiAlias := True;
  Result.Color := ColorToAlphaColor(APen.Color);
  Result.Alpha := APen.Alpha;
  if APen.Width <= 1 then
    Result.StrokeWidth := 1
  else
    Result.StrokeWidth := APen.Width;
  Result.StrokeCap := APen.StrokeCap;
  Result.StrokeJoin := APen.StrokeJoin;
  Result.StrokeMiter := APen.MiterLimit;
  Intervals := DashIntervalsForStyle(APen.Style, Result.StrokeWidth, APen.DashPattern);
  if Length(Intervals) > 0 then
    Result.PathEffect := TSkPathEffect.MakeDash(Intervals, 0);
end;

function TSkiaResourceManager.AcquireFillPaint(ABrush: TSkiaBrush; const Bounds: TRectF): ISkPaint;
var
  Key: string;
begin
  FLock.Enter;
  try
    if not ABrush.IsVisible then
      Exit(nil);
    Key := BrushKey(ABrush, Bounds);
    if (FFillPaint = nil) or (FFillKey <> Key) then
    begin
      FFillPaint := BuildFillPaint(ABrush, Bounds);
      FFillKey := Key;
    end;
    Result := FFillPaint;
  finally
    FLock.Leave;
  end;
end;

function TSkiaResourceManager.AcquireStrokePaint(APen: TSkiaPen): ISkPaint;
var
  Key: string;
begin
  FLock.Enter;
  try
    if not APen.IsVisible then
      Exit(nil);
    Key := PenKey(APen);
    if (FStrokePaint = nil) or (FStrokeKey <> Key) then
    begin
      FStrokePaint := BuildStrokePaint(APen);
      FStrokeKey := Key;
    end;
    Result := FStrokePaint;
  finally
    FLock.Leave;
  end;
end;

function TSkiaResourceManager.BuildFont(AFont: TFont): ISkFont;
var
  TF: ISkTypeface;
  SizePx: Single;
begin
  TF := FFontManager.AcquireTypeface(AFont);
  if TF = nil then
    TF := TSkTypeface.MakeDefault;
  if AFont.Height <> 0 then
    SizePx := Abs(AFont.Height)
  else
    SizePx := Math.Max(1, Round(AFont.Size * 96 / 72));
  Result := TSkFont.Create(TF, SizePx);
{$IFNDEF MSWINDOWS}Result.Subpixel := True;
  Result.Hinting := TSkFontHinting.None; {$ENDIF}
end;

function TSkiaResourceManager.AcquireFont(AFont: TFont): ISkFont;
var
  Key: string;
begin
  FLock.Enter;
  try
    Key := FFontManager.FontKey(AFont);
    if (FFont = nil) or (FFontKey <> Key) then
    begin
      FFont := BuildFont(AFont);
      FFontKey := Key;
    end;
    Result := FFont;
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaResourceManager.InvalidateBrush;
begin
  FLock.Enter;
  try
    FFillPaint := nil;
    FFillKey := '';
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaResourceManager.InvalidatePen;
begin
  FLock.Enter;
  try
    FStrokePaint := nil;
    FStrokeKey := '';
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaResourceManager.InvalidateFont;
begin
  FLock.Enter;
  try
    FFont := nil;
    FFontKey := '';
  finally
    FLock.Leave;
  end;
end;

procedure TSkiaResourceManager.InvalidateAll;
begin
  FLock.Enter;
  try
    InvalidateBrush;
    InvalidatePen;
    InvalidateFont;
  finally
    FLock.Leave;
  end;
end;

{$I SkiaCanvas.Compatibility.inc}
{$I SkiaCanvas.TextPath.inc}
{$IFDEF MSWINDOWS}{$I SkiaCanvas.Metafile.inc}{$ENDIF}

constructor TSkiaCanvasState.Create;
begin
  inherited;
  Pen := TSkiaPen.Create;
  Brush := TSkiaBrush.Create;
  Font := TSkiaFont.Create;
end;

destructor TSkiaCanvasState.Destroy;
begin
  Font.Free;
  Brush.Free;
  Pen.Free;
  inherited;
end;

constructor TSkiaCanvas.Create(ACanvas: ISkCanvas; AOwnsCanvas: Boolean);
begin
  inherited Create;
  if ACanvas = nil then
    raise ESkiaCanvasError.Create(SSkiaNilCanvas);
  FCanvas := ACanvas;
  { ISkCanvas lifetime is reference-counted; AOwnsCanvas is retained for API compatibility. }
  FResources := TSkiaResourceManager.Create;
  FBrush := TSkiaBrush.Create;
  FBrush.OnChange := BrushChanged;
  FPen := TSkiaPen.Create;
  FPen.OnChange := PenChanged;
  FFont := TSkiaFont.Create;
  FFont.OnChange := FontChanged;
  FCopyMode := cmSrcCopy;
  FNativeCanvasHandle := NativeUInt(FCanvas.Handle);
  FClipDepth := -1;
  FStateStack := TObjectList<TSkiaCanvasState>.Create;
  FGlyphCache := TSkiaGdiGlyphCache.Create;
  InitializeCompatibility;
  FCanvasSynchronization.Enter;
  try
    FMatrix := FCanvas.GetLocalToDeviceAs3x3;
  finally
    FCanvasSynchronization.Leave;
  end;
end;

destructor TSkiaCanvas.Destroy;
begin
  UnregisterCompatibility;
  FGlyphCache.Free;
  FStateStack.Free;
  FFont.Free;
  FPen.Free;
  FBrush.Free;
  FResources.Free;
  FCanvas := nil;
  FCanvasSynchronization := nil;
  inherited;
end;

procedure TSkiaCanvas.Lock;
begin
  FCanvasSynchronization.Enter;
  try
    FGlyphCache.Lock;
  except
    FCanvasSynchronization.Leave;
    raise;
  end;
end;

function TSkiaCanvas.TryLock: Boolean;
begin
  Result := FCanvasSynchronization.TryEnter;
  if Result and not FGlyphCache.FLock.TryEnter then
  begin
    FCanvasSynchronization.Leave;
    Result := False;
  end;
end;

procedure TSkiaCanvas.Unlock;
begin
  FGlyphCache.Unlock;
  FCanvasSynchronization.Leave;
end;

function TSkiaCanvas.GetBrush: TSkiaBrush;
begin
  RequiredState([csHandleValid, csPenValid]);
  Result := FBrush;
end;

function TSkiaCanvas.GetPen: TSkiaPen;
begin
  RequiredState([csHandleValid, csPenValid]);
  Result := FPen;
end;

function TSkiaCanvas.GetFontManager: TSkiaFontManager;
begin
  Result := FResources.FontManager;
end;

function TSkiaCanvas.GetTextToCurves: Boolean;
begin
  Result := FTextToCurves;
end;

procedure TSkiaCanvas.SetTextToCurves(Value: Boolean);
begin
  FTextToCurves := Value;
end;

procedure TSkiaCanvas.SetBrush(Value: TSkiaBrush);
begin
  FBrush.Assign(Value);
end;

procedure TSkiaCanvas.SetPen(Value: TSkiaPen);
begin
  FPen.Assign(Value);
end;

procedure TSkiaCanvas.SetFont(Value: TSkiaFont);
begin
  FFont.Assign(Value);
end;

procedure TSkiaCanvas.BrushChanged(Sender: TObject);
begin
  FResources.InvalidateBrush;
  Changed;
end;

procedure TSkiaCanvas.PenChanged(Sender: TObject);
begin
  FResources.InvalidatePen;
  Changed;
end;

procedure TSkiaCanvas.FontChanged(Sender: TObject);
begin
  FResources.InvalidateFont;
  { Font changes invalidate cached GDI glyph resources. }
  if FGlyphCache <> nil then
    FGlyphCache.Clear;
  Changed;
end;

procedure TSkiaCanvas.CaptureState(St: TSkiaCanvasState);
begin
  St.Pen.Assign(FPen);
  St.Brush.Assign(FBrush);
  St.Font.Assign(FFont);
  St.PenPos := FPenPos;
  St.CopyMode := FCopyMode;
  St.Matrix := FMatrix;
  St.ClipDepth := FClipDepth;
  St.Clips := Copy(FClips);
  St.SaveCount := FCanvas.GetSaveCount;
  St.TextToCurves := FTextToCurves;
end;

procedure TSkiaCanvas.ApplyState(St: TSkiaCanvasState);
begin
  FPen.Assign(St.Pen);
  FBrush.Assign(St.Brush);
  FFont.Assign(St.Font);
  FPenPos := St.PenPos;
  FCopyMode := St.CopyMode;
  FMatrix := St.Matrix;
  FClipDepth := St.ClipDepth;
  FClips := Copy(St.Clips);
  FTextToCurves := St.TextToCurves;
  FCanvas.SetMatrix(FMatrix);
end;

function TSkiaCanvas.GetCanvasOrientation: TCanvasOrientation;
begin
  Result := coLeftToRight;
end;

function TSkiaCanvas.GetClipRect: TRect;
var
  Pixels: TArray<TAlphaColor>;
  X, Y: Integer;
begin
  if Length(FClips) = 0 then
    Exit(Rect(0, 0, FDeviceWidth, FDeviceHeight));
  Pixels := ClipPixels;
  Result := Rect(FDeviceWidth, FDeviceHeight, 0, 0);
  for Y := 0 to FDeviceHeight - 1 do
    for X := 0 to FDeviceWidth - 1 do
      if Pixels[Y * FDeviceWidth + X] shr 24 <> 0 then
      begin
        Result.Left := Math.Min(Result.Left, X);
        Result.Top := Math.Min(Result.Top, Y);
        Result.Right := Math.Max(Result.Right, X + 1);
        Result.Bottom := Math.Max(Result.Bottom, Y + 1);
      end;
  if Result.Right <= Result.Left then
    Result := Rect(0, 0, 0, 0);
end;

function TSkiaCanvas.GetPenPos: TPoint;
begin
  Result := FPenPos;
end;

procedure TSkiaCanvas.SetPenPos(Value: TPoint);
begin
  FPenPos := Value;
end;

function TSkiaCanvas.GetPixel(X, Y: Integer): TColor;
var
  Pixels: TArray<TAlphaColor>;
  W, H: Integer;
  P: TPoint;
begin
  P := LPToDP(Point(X, Y));
  Pixels := ReadDevicePixels(W, H);
  Result := clBlack;
  if (P.X >= 0) and (P.Y >= 0) and (P.X < W) and (P.Y < H) then
    Result := AlphaColorToColor(Pixels[P.Y * W + P.X]);
end;

procedure TSkiaCanvas.SetPixel(X, Y: Integer; Value: TColor);
var
  Paint: ISkPaint;
  P: TPoint;
begin
  if not BeginOperation(0) then
    Exit;
  try
    P := LPToDP(Point(X, Y));
    Paint := TSkPaint.Create;
    Paint.Color := ColorToAlphaColor(Value);
    Paint.AntiAlias := False;
    FCanvas.Save;
    try
      FCanvas.ResetMatrix;
      FCanvas.DrawPoint(P.X, P.Y, Paint);
    finally
      FCanvas.Restore;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.RequiredState(ReqState: TCanvasState);
begin

end;

function TSkiaCanvas.LockPixels(out APixels: TArray<TAlphaColor>; out AWidth, AHeight: Integer): Boolean;
begin
  APixels := ReadDevicePixels(AWidth, AHeight);
  Result := Length(APixels) > 0;
end;

procedure TSkiaCanvas.UnlockPixels;
begin
end;

function TSkiaCanvas.AcquireFillPaint(const Bounds: TRectF): ISkPaint;
begin
  Result := FResources.AcquireFillPaint(FBrush, Bounds);
end;

function TSkiaCanvas.AcquireStrokePaint: ISkPaint;
begin
  Result := FResources.AcquireStrokePaint(FPen);
end;

function TSkiaCanvas.AcquireFont: ISkFont;
begin
  Result := FResources.AcquireFont(FFont);
end;

{ Convert the VCL counterclockwise arc to Skia angles: clockwise from the positive X axis, with a negative sweep. }
function TSkiaCanvas.ArcAngles(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer; out StartAngle, SweepAngle: Single): TRectF;
var
  CX, CY: Double;
begin
  Result := RectF(X1, Y1, X2, Y2);
  CX := (X1 + X2) / 2;
  CY := (Y1 + Y2) / 2;
  StartAngle := RadToDeg(ArcTan2(Y3 - CY, X3 - CX));
  SweepAngle := RadToDeg(ArcTan2(Y4 - CY, X4 - CX)) - StartAngle;
  while SweepAngle >= 0 do
    SweepAngle := SweepAngle - 360;
  while SweepAngle < -360 do
    SweepAngle := SweepAngle + 360;
end;

procedure TSkiaCanvas.Arc(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
var
  P: ISkPaint;
  R: TRectF;
  SA, SW: Single;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (X2 <= X1) or (Y2 <= Y1) then
      Exit;
    P := AcquireStrokePaint;
    if P = nil then
      Exit;
    R := ArcAngles(X1, Y1, X2, Y2, X3, Y3, X4, Y4, SA, SW);
    FCanvas.DrawArc(R, SA, SW, False, P);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.ArcTo(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
var
  P: ISkPaint;
  R: TRectF;
  SA, SW, EA: Single;
  CX, CY, SX, SY, EX, EY: Single;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (X2 <= X1) or (Y2 <= Y1) then
      Exit;
    P := AcquireStrokePaint;
    if P = nil then
      Exit;
    R := ArcAngles(X1, Y1, X2, Y2, X3, Y3, X4, Y4, SA, SW);
    CX := (X1 + X2) / 2;
    CY := (Y1 + Y2) / 2;
    SX := CX + ((X2 - X1) / 2) * Cos(DegToRad(SA));
    SY := CY + ((Y2 - Y1) / 2) * Sin(DegToRad(SA));
    EA := SA + SW;
    EX := CX + ((X2 - X1) / 2) * Cos(DegToRad(EA));
    EY := CY + ((Y2 - Y1) / 2) * Sin(DegToRad(EA));
    if (FPenPos.X <> Round(SX)) or (FPenPos.Y <> Round(SY)) then
      FCanvas.DrawLine(FPenPos.X, FPenPos.Y, SX, SY, P);
    FCanvas.DrawArc(R, SA, SW, False, P);
    FPenPos := Point(Round(EX), Round(EY));
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.AngleArc(X, Y: Integer; Radius: Cardinal; StartAngle, SweepAngle: Single);
var
  P: ISkPaint;
  R: TRectF;
  SX, SY, EX, EY: Single;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if Radius = 0 then
      Exit;
    P := AcquireStrokePaint;
    if P = nil then
      Exit;
    { VCL AngleArc uses counterclockwise degrees; negate the angles for Skia. }
    R := RectF(X - Single(Radius), Y - Single(Radius), X + Single(Radius), Y + Single(Radius));
    SX := X + Radius * Cos(DegToRad(StartAngle));
    SY := Y - Radius * Sin(DegToRad(StartAngle));
    EX := X + Radius * Cos(DegToRad(StartAngle + SweepAngle));
    EY := Y - Radius * Sin(DegToRad(StartAngle + SweepAngle));
    if (FPenPos.X <> Round(SX)) or (FPenPos.Y <> Round(SY)) then
      FCanvas.DrawLine(FPenPos.X, FPenPos.Y, SX, SY, P);
    FCanvas.DrawArc(R, -StartAngle, -SweepAngle, False, P);
    FPenPos := Point(Round(EX), Round(EY));
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.Chord(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
var
  B, P: ISkPaint;
  R: TRectF;
  SA, SW, Inset: Single;
  Path: ISkiaPathBuilder;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (X2 <= X1) or (Y2 <= Y1) then
      Exit;
    R := ArcAngles(X1, Y1, X2, Y2, X3, Y3, X4, Y4, SA, SW);
    Path := TSkiaPathBuilder.Create;
    Path.AddArc(R, SA, SW);
    Path.Close;
    B := AcquireFillPaint(R);
    if B <> nil then
      FCanvas.DrawPath(Path.Snapshot, B);
    P := AcquireStrokePaint;
    if P <> nil then
    begin
      FCanvas.Save;
      try
        if FPen.Style = psInsideFrame then
        begin
          FCanvas.ClipRect(R);
          Inset := Math.Min(P.StrokeWidth / 2, Math.Max(0, Math.Min(R.Width, R.Height) / 2 - 0.01));
          R := RectF(R.Left + Inset, R.Top + Inset, R.Right - Inset, R.Bottom - Inset);
          Path := TSkiaPathBuilder.Create;
          Path.AddArc(R, SA, SW);
          Path.Close;
        end;
        FCanvas.DrawPath(Path.Snapshot, P);
      finally
        FCanvas.Restore;
      end;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.Pie(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
var
  B, P: ISkPaint;
  R: TRectF;
  SA, SW, Inset: Single;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (X2 <= X1) or (Y2 <= Y1) then
      Exit;
    R := ArcAngles(X1, Y1, X2, Y2, X3, Y3, X4, Y4, SA, SW);
    B := AcquireFillPaint(R);
    if B <> nil then
      FCanvas.DrawArc(R, SA, SW, True, B);
    P := AcquireStrokePaint;
    if P <> nil then
    begin
      FCanvas.Save;
      try
        if FPen.Style = psInsideFrame then
        begin
          FCanvas.ClipRect(R);
          Inset := Math.Min(P.StrokeWidth / 2, Math.Max(0, Math.Min(R.Width, R.Height) / 2 - 0.01));
          R := RectF(R.Left + Inset, R.Top + Inset, R.Right - Inset, R.Bottom - Inset);
        end;
        FCanvas.DrawArc(R, SA, SW, True, P);
      finally
        FCanvas.Restore;
      end;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.Ellipse(X1, Y1, X2, Y2: Integer);
var
  B, P: ISkPaint;
  R: TRectF;
  Inset: Single;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (X2 <= X1) or (Y2 <= Y1) then
      Exit;
    R := RectF(X1, Y1, X2, Y2);
    B := AcquireFillPaint(R);
    if B <> nil then
      FCanvas.DrawOval(R, B);
    FCanvas.Save;
    try
      if FPen.Style = psInsideFrame then
        FCanvas.ClipRect(RectF(X1, Y1, X2, Y2));
      P := AcquireStrokePaint;
      if P <> nil then

      begin
        if FPen.Style = psInsideFrame then
        begin
          Inset := Math.Min(P.StrokeWidth / 2, Math.Max(0, Math.Min(X2 - X1, Y2 - Y1) / 2 - 0.01));
          FCanvas.DrawOval(RectF(X1 + Inset, Y1 + Inset, X2 - Inset, Y2 - Inset), P);
        end
        else
          FCanvas.DrawOval(RectF(X1, Y1, X2 - 1, Y2 - 1), P);
      end;
    finally
      FCanvas.Restore;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.Rectangle(X1, Y1, X2, Y2: Integer);
var
  B, P: ISkPaint;
  R: TRectF;
  Inset: Single;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (X2 <= X1) or (Y2 <= Y1) then
      Exit;
    R := RectF(X1, Y1, X2, Y2);
    B := AcquireFillPaint(R);
    if B <> nil then
      FCanvas.DrawRect(R, B);
    FCanvas.Save;
    try
      if FPen.Style = psInsideFrame then
        FCanvas.ClipRect(RectF(X1, Y1, X2, Y2));
      P := AcquireStrokePaint;
      if P <> nil then
      begin
        if FPen.Style = psInsideFrame then
        begin
          Inset := Math.Min(P.StrokeWidth / 2, Math.Max(0, Math.Min(X2 - X1, Y2 - Y1) / 2 - 0.01));
          FCanvas.DrawRect(RectF(X1 + Inset, Y1 + Inset, X2 - Inset, Y2 - Inset), P);
        end
        else
          FCanvas.DrawRect(RectF(X1, Y1, X2 - 1, Y2 - 1), P);
      end;
    finally
      FCanvas.Restore;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.RoundRect(X1, Y1, X2, Y2, X3, Y3: Integer);
var
  B, P: ISkPaint;
  Path: ISkiaPathBuilder;
  Inset: Single;
  Round: ISkRoundRect;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (X2 <= X1) or (Y2 <= Y1) then
      Exit;
    Path := TSkiaPathBuilder.Create;

    Round := TSkRoundRect.Create(RectF(X1, Y1, X2, Y2), X3 / 2, Y3 / 2);
    Path.AddRoundRect(Round);
    B := AcquireFillPaint(RectF(X1, Y1, X2, Y2));
    if B <> nil then
      FCanvas.DrawPath(Path.Snapshot, B);
    FCanvas.Save;
    try
      if FPen.Style = psInsideFrame then
        FCanvas.ClipRect(RectF(X1, Y1, X2, Y2));
      P := AcquireStrokePaint;
      if P <> nil then
      begin
        Path := TSkiaPathBuilder.Create;
        if FPen.Style = psInsideFrame then
        begin
          Inset := Math.Min(P.StrokeWidth / 2, Math.Max(0, Math.Min(X2 - X1, Y2 - Y1) / 2 - 0.01));
          Round := TSkRoundRect.Create(RectF(X1 + Inset, Y1 + Inset, X2 - Inset, Y2 - Inset), Math.Max(0, X3 / 2 - Inset), Math.Max(0, Y3 / 2 - Inset));
        end
        else
          Round := TSkRoundRect.Create(RectF(X1, Y1, X2 - 1, Y2 - 1), X3 / 2, Y3 / 2);
        Path.AddRoundRect(Round);
        FCanvas.DrawPath(Path.Snapshot, P);
      end;
    finally
      FCanvas.Restore;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.FillRect(const Rect: TRect);
var
  B: ISkPaint;
begin
  if not BeginOperation(0) then
    Exit;
  try
    B := AcquireFillPaint(RectToRectF(Rect));
    if B <> nil then
      FCanvas.DrawRect(RectToRectF(Rect), B);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.FrameRect(const Rect: TRect);
var
  Paint: ISkPaint;
begin
  if not BeginOperation(0) then
    Exit;
  try
    Paint := AcquireFillPaint(RectToRectF(Rect));
    if Paint = nil then
      Exit;
    FCanvas.DrawRect(RectF(Rect.Left, Rect.Top, Rect.Right, Rect.Top + 1), Paint);
    FCanvas.DrawRect(RectF(Rect.Left, Rect.Bottom - 1, Rect.Right, Rect.Bottom), Paint);
    FCanvas.DrawRect(RectF(Rect.Left, Rect.Top + 1, Rect.Left + 1, Rect.Bottom - 1), Paint);
    FCanvas.DrawRect(RectF(Rect.Right - 1, Rect.Top + 1, Rect.Right, Rect.Bottom - 1), Paint);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.LineTo(X, Y: Integer);
var
  P: ISkPaint;
begin
  if not BeginOperation(1) then
    Exit;
  try
    P := AcquireStrokePaint;
    if P = nil then
    begin
      FPenPos := Point(X, Y);
      Exit;
    end;
    FCanvas.DrawLine(FPenPos.X, FPenPos.Y, X, Y, P);
    FPenPos := Point(X, Y);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.MoveTo(X, Y: Integer);
begin
  FPenPos := Point(X, Y);
end;

procedure TSkiaCanvas.Polygon(const Points: array of TPoint);
var
  B, P: ISkPaint;
  Path: ISkiaPathBuilder;
  I: Integer;
  R: TRectF;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if Length(Points) < 2 then
      Exit;
    Path := TSkiaPathBuilder.Create;
    Path.MoveTo(Points[0].X, Points[0].Y);
    for I := 1 to High(Points) do
      Path.LineTo(Points[I].X, Points[I].Y);
    Path.Close;
    R := Path.GetBounds;
    B := AcquireFillPaint(R);
    if B <> nil then
      FCanvas.DrawPath(Path.Snapshot, B);
    P := AcquireStrokePaint;
    if P <> nil then
      FCanvas.DrawPath(Path.Snapshot, P);
    FPenPos := Points[High(Points)];
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.Polyline(const Points: array of TPoint);
var
  P: ISkPaint;
  Path: ISkiaPathBuilder;
  I: Integer;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if Length(Points) < 2 then
      Exit;
    P := AcquireStrokePaint;
    if P = nil then
    begin
      FPenPos := Points[High(Points)];
      Exit;
    end;
    Path := TSkiaPathBuilder.Create;
    Path.MoveTo(Points[0].X, Points[0].Y);
    for I := 1 to High(Points) do
      Path.LineTo(Points[I].X, Points[I].Y);
    FCanvas.DrawPath(Path.Snapshot, P);
    FPenPos := Points[High(Points)];
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.PolyBezier(const Points: array of TPoint);
var
  P: ISkPaint;
  Path: ISkiaPathBuilder;
  I: Integer;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (Length(Points) < 4) or ((Length(Points) - 1) mod 3 <> 0) then
      Exit;
    P := AcquireStrokePaint;
    if P = nil then
    begin
      FPenPos := Points[High(Points)];
      Exit;
    end;
    Path := TSkiaPathBuilder.Create;
    Path.MoveTo(Points[0].X, Points[0].Y);
    I := 1;
    while I + 2 < Length(Points) do
    begin
      Path.CubicTo(Points[I].X, Points[I].Y, Points[I + 1].X, Points[I + 1].Y, Points[I + 2].X, Points[I + 2].Y);
      Inc(I, 3);
    end;
    FCanvas.DrawPath(Path.Snapshot, P);
    FPenPos := Points[High(Points)];
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.PolyBezierTo(const Points: array of TPoint);
var
  Full: TArray<TPoint>;
  I: Integer;
begin
  if not BeginOperation(1) then
    Exit;
  try
    if (Length(Points) < 3) or (Length(Points) mod 3 <> 0) then
      Exit;
    SetLength(Full, Length(Points) + 1);
    Full[0] := FPenPos;
    for I := 0 to High(Points) do
      Full[I + 1] := Points[I];
    PolyBezier(Full);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.DrawFocusRect(const Rect: TRect);
var
  P: ISkPaint;
begin
  if not BeginOperation(3) then
    Exit;
  try

    P := TSkPaint.Create;
    P.Style := TSkPaintStyle.Stroke;
    P.Color := $FF000000;
    P.StrokeWidth := 1;
    P.PathEffect := TSkPathEffect.MakeDash(TArray<Single>.Create(1, 1), 0);
    FCanvas.DrawRect(RectF(Rect.Left, Rect.Top, Rect.Right - 1, Rect.Bottom - 1), P);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.Refresh;
begin
  FBacking.Flush;
end;

procedure TSkiaCanvas.Draw(X, Y: Integer; Graphic: TGraphic);
var
  Image: ISkImage;
begin
{$IFDEF MSWINDOWS}
  if Graphic is TMetafile then
  begin
    DrawMetafile(TMetafile(Graphic), RectF(X, Y, X + Graphic.Width, Y + Graphic.Height));
    Exit;
  end;
{$ENDIF}
  if not BeginOperation(2) then
    Exit;
  try
    Image := GraphicImage(Graphic);
    if Image <> nil then
      FCanvas.DrawImage(Image, X, Y);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.Draw(X, Y: Integer; Graphic: TGraphic; Opacity: Byte);
var
  Image: ISkImage;
  Pixels: TArray<TAlphaColor>;
  I: Integer;
  Layer: TSkiaBitmapCanvas;
begin
{$IFDEF MSWINDOWS}
  if Graphic is TMetafile then
  begin
    if Opacity = 255 then
    begin
      Draw(X, Y, Graphic);
      Exit;
    end;
    if (Opacity = 0) or Graphic.Empty or (Graphic.Width <= 0) or (Graphic.Height <= 0) then
      Exit;
    Layer := TSkiaBitmapCanvas.Create(Graphic.Width, Graphic.Height);
    try
      Layer.Draw(0, 0, Graphic);
      Image := Layer.Snapshot;
      Pixels := CompatReadImage(Image);
      for I := 0 to High(Pixels) do
        Pixels[I] := (Pixels[I] and $FFFFFF) or (Cardinal(((Pixels[I] shr 24) * Opacity + 127) div 255) shl 24);
      Image := CompatImage(Pixels, Image.Width, Image.Height);
    finally
      Layer.Free;
    end;
    if BeginOperation(2) then
      try
        FCanvas.DrawImage(Image, X, Y);
      finally
        EndOperation;
      end;
    Exit;
  end;
{$ENDIF}
  if not BeginOperation(2) then
    Exit;
  try
    Image := GraphicImage(Graphic);
    if Image = nil then
      Exit;
    if Opacity <> 255 then
    begin
      Pixels := CompatReadImage(Image);
      for I := 0 to High(Pixels) do
        Pixels[I] := (Pixels[I] and $FFFFFF) or (Cardinal(((Pixels[I] shr 24) * Opacity + 127) div 255) shl 24);
      Image := CompatImage(Pixels, Image.Width, Image.Height);
    end;
    FCanvas.DrawImage(Image, X, Y);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.StretchDraw(const Rect: TRect; Graphic: TGraphic);
var
  Image: ISkImage;
begin
{$IFDEF MSWINDOWS}
  if Graphic is TMetafile then
  begin
    DrawMetafile(TMetafile(Graphic), RectToRectF(Rect));
    Exit;
  end;
{$ENDIF}
  if not BeginOperation(2) then
    Exit;
  try
    Image := GraphicImage(Graphic);
    if Image <> nil then
      TransferImage(Image, RectF(0, 0, Image.Width, Image.Height), RectToRectF(Rect));
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.BrushCopy(const Dest: TRect; Bitmap: TBitmap; const Source: TRect; Color: TColor);
var
  Image: ISkImage;
begin
  if not BeginOperation(4) then
    Exit;
  try
    Image := BitmapToSkImage(Bitmap);
    if Image = nil then
      Exit;
    FOperationKey := ColorToAlphaColor(Color) and $FFFFFF;
    TransferImage(Image, RectToRectF(Source), RectToRectF(Dest));
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.CopyRect(const Dest: TRect; SrcCanvas: TSkiaCanvas; const SrcRect: TRect);
var
  Image: ISkImage;
begin
  if not BeginOperation(2) then
    Exit;
  try
    Image := SourceRectangle(SrcCanvas, RectToRectF(SrcRect));
    if Image <> nil then
      TransferImage(Image, CompatSourceBounds(Image, SrcRect.Width, SrcRect.Height), RectToRectF(Dest));
  finally
    EndOperation;
  end;
end;

function TSkiaCanvas.GetSrcImage(Src: TSkiaCanvas): ISkImage;
begin
  Result := nil;
  if Src <> nil then
    Result := Src.FBacking.MakeImageSnapshot;
end;

{ Copy the bitmap before conversion: BitmapToSkImage normalizes its pixel format. }
function BltBitmapSource(Bitmap: TBitmap): TSkiaBitmapCanvas;
var
  Copy: TBitmap;
  Image: ISkImage;
begin
  Result := nil;
  if (Bitmap = nil) or (Bitmap.Width <= 0) or (Bitmap.Height <= 0) then
    Exit;
  Copy := TBitmap.Create;
  try
    Copy.Assign(Bitmap);
    Image := BitmapToSkImage(Copy);
    Result := TSkiaBitmapCanvas.Create(Copy.Width, Copy.Height);
    try
      Result.FCanvas.DrawImage(Image, 0, 0);
    except
      Result.Free;
      raise;
    end;
  finally
    Copy.Free;
  end;
end;

{ GDI reads source logical coordinates; destination DIB pixels have opaque alpha. }
{$IFDEF MSWINDOWS}

function BltDCSource(DC: HDC; X, Y, Width, Height: Integer): TSkiaBitmapCanvas;
var
  CaptureDC: HDC;
  Bitmap, OldBitmap: HGDIOBJ;
  Info: TBitmapInfo;
  Bits: Pointer;
  Pixels: PCardinal;
  I: NativeInt;
  Image: ISkImage;
begin
  Result := nil;
  if (DC = 0) or (Width = 0) or (Height = 0) then
    Exit;
  if Width < 0 then
    X := X + Width;
  if Height < 0 then
    Y := Y + Height;
  Width := Abs(Width);
  Height := Abs(Height);
  FillChar(Info, SizeOf(Info), 0);
  Info.bmiHeader.biSize := SizeOf(Info.bmiHeader);
  Info.bmiHeader.biWidth := Width;
  Info.bmiHeader.biHeight := -Height;
  Info.bmiHeader.biPlanes := 1;
  Info.bmiHeader.biBitCount := 32;
  Info.bmiHeader.biCompression := BI_RGB;
  CaptureDC := CreateCompatibleDC(DC);
  if CaptureDC = 0 then
    RaiseLastOSError;
  try
    Bitmap := CreateDIBSection(CaptureDC, Info, DIB_RGB_COLORS, Bits, 0, 0);
    if Bitmap = 0 then
      RaiseLastOSError;
    try
      OldBitmap := SelectObject(CaptureDC, Bitmap);
      if (OldBitmap = 0) or (NativeInt(OldBitmap) = -1) then
        RaiseLastOSError;
      try
        if not {$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF}.BitBlt(CaptureDC, 0, 0, Width, Height, DC, X, Y, SRCCOPY) then
          RaiseLastOSError;
        GdiFlush;
        Pixels := Bits;
        for I := 0 to NativeInt(Width) * Height - 1 do
          Pixels[I] := Pixels[I] or $FF000000;
        Image := TSkImage.MakeRasterCopy(TSkImageInfo.Create(Width, Height, TSkColorType.BGRA8888, TSkAlphaType.Unpremul), Bits, Width * 4);
        Result := TSkiaBitmapCanvas.Create(Width, Height);
        try
          Result.FCanvas.DrawImage(Image, 0, 0);
        except
          Result.Free;
          raise;
        end;
      finally
        SelectObject(CaptureDC, OldBitmap);
      end;
    finally
      DeleteObject(Bitmap);
    end;
  finally
    DeleteDC(CaptureDC);
  end;
end;

{$ENDIF}

{ Inspect TObject first: TCanvas and TSkiaCanvas are currently siblings.
  Borrow the existing Skia source; never capture it through HDC/RGB pixels. }
function BltSkiaCanvasSource(Canvas: TCanvas): TSkiaCanvas;
begin
  Result := nil;
  if TObject(Canvas) is TSkiaCanvas then
    Result := TSkiaCanvas(TObject(Canvas));
end;

{ Ordinary native canvases expose RGB pixels. Skia sources are dispatched by
  the TCanvas overloads before entering this capture helper. }

function BltCanvasSource(Canvas: TCanvas; X, Y, Width, Height: Integer): TSkiaBitmapCanvas;
{$IFNDEF MSWINDOWS}
var
  Pixels: TArray<TAlphaColor>;
  IX, IY: Integer;
  Image: ISkImage;
{$ENDIF}
begin
  Result := nil;
  if (Canvas = nil) or (Width = 0) or (Height = 0) then
    Exit;
{$IFDEF MSWINDOWS}
  Result := BltDCSource(Canvas.Handle, X, Y, Width, Height);
{$ELSE}
  if Width < 0 then
    X := X + Width;
  if Height < 0 then
    Y := Y + Height;
  Width := Abs(Width);
  Height := Abs(Height);
  SetLength(Pixels, NativeInt(Width) * Height);
  Canvas.Lock;
  try
    for IY := 0 to Height - 1 do
      for IX := 0 to Width - 1 do
        Pixels[IY * Width + IX] := ColorToAlphaColor(Canvas.Pixels[X + IX, Y + IY]);
  finally
    Canvas.Unlock;
  end;
  Image := CompatImage(Pixels, Width, Height);
  Result := TSkiaBitmapCanvas.Create(Width, Height);
  try
    Result.FCanvas.DrawImage(Image, 0, 0);
  except
    Result.Free;
    raise;
  end;
{$ENDIF}
end;

procedure TSkiaCanvas.CopyRect(const Dest: TRect; SrcCanvas: TCanvas; const SrcRect: TRect);
var
  SkiaSource: TSkiaCanvas;
  Source: TSkiaBitmapCanvas;
  Bounds: TRect;
begin
  SkiaSource := BltSkiaCanvasSource(SrcCanvas);
  if SkiaSource <> nil then
  begin
    CopyRect(Dest, SkiaSource, SrcRect);
    Exit;
  end;
  if (SrcCanvas = nil) or (Dest.Width = 0) or (Dest.Height = 0) or (SrcRect.Width = 0) or (SrcRect.Height = 0) then
    Exit;
  Source := BltCanvasSource(SrcCanvas, SrcRect.Left, SrcRect.Top, SrcRect.Width, SrcRect.Height);
  if Source = nil then
    Exit;
  try
    Bounds := Rect(0, 0, SrcRect.Width, SrcRect.Height);
    if SrcRect.Width < 0 then
    begin
      Bounds.Left := -SrcRect.Width;
      Bounds.Right := 0;
    end;
    if SrcRect.Height < 0 then
    begin
      Bounds.Top := -SrcRect.Height;
      Bounds.Bottom := 0;
    end;
    CopyRect(Dest, Source, Bounds);
  finally
    Source.Free;
  end;
end;

procedure TSkiaCanvas.BitBlt(X, Y, Width, Height: Integer; Src: TCanvas; XSrc, YSrc: Integer);
var
  SkiaSource: TSkiaCanvas;
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  SkiaSource := BltSkiaCanvasSource(Src);
  if SkiaSource <> nil then
  begin
    BitBlt(X, Y, Width, Height, SkiaSource, XSrc, YSrc);
    Exit;
  end;
  if (Width <= 0) or (Height <= 0) then
    Exit;
  Source := BltCanvasSource(Src, XSrc, YSrc, Width, Height);
  XS := 0;
  YS := 0;
  if Width < 0 then
    XS := -Width;
  if Height < 0 then
    YS := -Height;
  if Source = nil then
    Exit;
  try
    BitBlt(X, Y, Width, Height, Source, XS, YS);
  finally
    Source.Free;
  end;
end;

procedure TSkiaCanvas.StretchBlt(X, Y, Width, Height: Integer; Src: TCanvas; XSrc, YSrc, SrcWidth, SrcHeight: Integer);
var
  SkiaSource: TSkiaCanvas;
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  SkiaSource := BltSkiaCanvasSource(Src);
  if SkiaSource <> nil then
  begin
    StretchBlt(X, Y, Width, Height, SkiaSource, XSrc, YSrc, SrcWidth, SrcHeight);
    Exit;
  end;
  if (Width = 0) or (Height = 0) then
    Exit;
  Source := BltCanvasSource(Src, XSrc, YSrc, SrcWidth, SrcHeight);
  XS := 0;
  YS := 0;
  if SrcWidth < 0 then
    XS := -SrcWidth;
  if SrcHeight < 0 then
    YS := -SrcHeight;
  if Source = nil then
    Exit;
  try
    StretchBlt(X, Y, Width, Height, Source, XS, YS, SrcWidth, SrcHeight);
  finally
    Source.Free;
  end;
end;

procedure TSkiaCanvas.MaskBlt(X, Y, Width, Height: Integer; Src: TCanvas; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer);
var
  SkiaSource: TSkiaCanvas;
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  SkiaSource := BltSkiaCanvasSource(Src);
  if SkiaSource <> nil then
  begin
    MaskBlt(X, Y, Width, Height, SkiaSource, XSrc, YSrc, Mask, XMask, YMask);
    Exit;
  end;
  if (Width <= 0) or (Height <= 0) then
    Exit;
  if Mask = nil then
    Exit;
  Source := BltCanvasSource(Src, XSrc, YSrc, Width, Height);
  XS := 0;
  YS := 0;
  if Width < 0 then
    XS := -Width;
  if Height < 0 then
    YS := -Height;
  if Source = nil then
    Exit;
  try
    MaskBlt(X, Y, Width, Height, Source, XS, YS, Mask, XMask, YMask);
  finally
    Source.Free;
  end;
end;

procedure TSkiaCanvas.PlgBlt(const Points: array of TPoint; Src: TCanvas; XSrc, YSrc, Width, Height: Integer);
var
  SkiaSource: TSkiaCanvas;
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  SkiaSource := BltSkiaCanvasSource(Src);
  if SkiaSource <> nil then
  begin
    PlgBlt(Points, SkiaSource, XSrc, YSrc, Width, Height);
    Exit;
  end;
  if Length(Points) < 3 then
    Exit;
  Source := BltCanvasSource(Src, XSrc, YSrc, Width, Height);
  XS := 0;
  YS := 0;
  if Width < 0 then
    XS := -Width;
  if Height < 0 then
    YS := -Height;
  if Source = nil then
    Exit;
  try
    PlgBlt(Points, Source, XS, YS, Width, Height);
  finally
    Source.Free;
  end;
end;

{$IFDEF MSWINDOWS}

procedure TSkiaCanvas.BitBlt(X, Y, Width, Height: Integer; Src: HDC; XSrc, YSrc: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;
  Source := BltDCSource(Src, XSrc, YSrc, Width, Height);
  XS := 0;
  YS := 0;
  if Width < 0 then
    XS := -Width;
  if Height < 0 then
    YS := -Height;
  if Source = nil then
    Exit;
  try
    BitBlt(X, Y, Width, Height, Source, XS, YS);
  finally
    Source.Free;
  end;
end;
{$ENDIF}

procedure TSkiaCanvas.BitBlt(X, Y, Width, Height: Integer; Src: TBitmap; XSrc, YSrc: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;
  Source := BltBitmapSource(Src);
  XS := XSrc;
  YS := YSrc;
  if Source = nil then
    Exit;
  try
    BitBlt(X, Y, Width, Height, Source, XS, YS);
  finally
    Source.Free;
  end;
end;

{$IFDEF MSWINDOWS}

procedure TSkiaCanvas.StretchBlt(X, Y, Width, Height: Integer; Src: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if (Width = 0) or (Height = 0) then
    Exit;
  Source := BltDCSource(Src, XSrc, YSrc, SrcWidth, SrcHeight);
  XS := 0;
  YS := 0;
  if SrcWidth < 0 then
    XS := -SrcWidth;
  if SrcHeight < 0 then
    YS := -SrcHeight;
  if Source = nil then
    Exit;
  try
    StretchBlt(X, Y, Width, Height, Source, XS, YS, SrcWidth, SrcHeight);
  finally
    Source.Free;
  end;
end;
{$ENDIF}

procedure TSkiaCanvas.StretchBlt(X, Y, Width, Height: Integer; Src: TBitmap; XSrc, YSrc, SrcWidth, SrcHeight: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if (Width = 0) or (Height = 0) then
    Exit;
  Source := BltBitmapSource(Src);
  XS := XSrc;
  YS := YSrc;
  if Source = nil then
    Exit;
  try
    StretchBlt(X, Y, Width, Height, Source, XS, YS, SrcWidth, SrcHeight);
  finally
    Source.Free;
  end;
end;

{$IFDEF MSWINDOWS}

procedure TSkiaCanvas.MaskBlt(X, Y, Width, Height: Integer; Src: HDC; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;
  if Mask = nil then
    Exit;
  Source := BltDCSource(Src, XSrc, YSrc, Width, Height);
  XS := 0;
  YS := 0;
  if Width < 0 then
    XS := -Width;
  if Height < 0 then
    YS := -Height;
  if Source = nil then
    Exit;
  try
    MaskBlt(X, Y, Width, Height, Source, XS, YS, Mask, XMask, YMask);
  finally
    Source.Free;
  end;
end;
{$ENDIF}

procedure TSkiaCanvas.MaskBlt(X, Y, Width, Height: Integer; Src: TBitmap; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;
  if Mask = nil then
    Exit;
  Source := BltBitmapSource(Src);
  XS := XSrc;
  YS := YSrc;
  if Source = nil then
    Exit;
  try
    MaskBlt(X, Y, Width, Height, Source, XS, YS, Mask, XMask, YMask);
  finally
    Source.Free;
  end;
end;

{$IFDEF MSWINDOWS}

procedure TSkiaCanvas.PlgBlt(const Points: array of TPoint; Src: HDC; XSrc, YSrc, Width, Height: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if Length(Points) < 3 then
    Exit;
  Source := BltDCSource(Src, XSrc, YSrc, Width, Height);
  XS := 0;
  YS := 0;
  if Width < 0 then
    XS := -Width;
  if Height < 0 then
    YS := -Height;
  if Source = nil then
    Exit;
  try
    PlgBlt(Points, Source, XS, YS, Width, Height);
  finally
    Source.Free;
  end;
end;
{$ENDIF}

procedure TSkiaCanvas.PlgBlt(const Points: array of TPoint; Src: TBitmap; XSrc, YSrc, Width, Height: Integer);
var
  Source: TSkiaBitmapCanvas;
  XS, YS: Integer;
begin
  if Length(Points) < 3 then
    Exit;
  Source := BltBitmapSource(Src);
  XS := XSrc;
  YS := YSrc;
  if Source = nil then
    Exit;
  try
    PlgBlt(Points, Source, XS, YS, Width, Height);
  finally
    Source.Free;
  end;
end;

procedure TSkiaCanvas.BitBlt(X, Y, Width, Height: Integer; Src: TSkiaCanvas; XSrc, YSrc: Integer);
var
  Image: ISkImage;
begin
  if not BeginOperation(2) then
    Exit;
  try
    if (Width <= 0) or (Height <= 0) then
      Exit;
    Image := SourceRectangle(Src, RectF(XSrc, YSrc, XSrc + Width, YSrc + Height));
    if Image <> nil then
      FCanvas.DrawImage(Image, X, Y);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.StretchBlt(X, Y, Width, Height: Integer; Src: TSkiaCanvas; XSrc, YSrc, SrcWidth, SrcHeight: Integer);
var
  Image: ISkImage;
begin
  if not BeginOperation(2) then
    Exit;
  try
    if (Width = 0) or (Height = 0) or (SrcWidth = 0) or (SrcHeight = 0) then
      Exit;
    Image := SourceRectangle(Src, RectF(XSrc, YSrc, XSrc + SrcWidth, YSrc + SrcHeight));
    if Image <> nil then
      TransferImage(Image, CompatSourceBounds(Image, SrcWidth, SrcHeight), RectF(X, Y, X + Width, Y + Height));
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.MaskBlt(X, Y, Width, Height: Integer; Src: TSkiaCanvas; XSrc, YSrc: Integer; Mask: TBitmap; XMask, YMask: Integer);
var
  Image: ISkImage;
  Source, Pixels: TArray<TAlphaColor>;
  IX, IY, SX, SY, MX, MY: Integer;
  Point: TPointF;
begin
  if not BeginOperation(2) then
    Exit;
  try
    if (Width <= 0) or (Height <= 0) or (Mask = nil) then
      Exit;
    Image := SourceRectangle(Src, RectF(XSrc, YSrc, XSrc + Width, YSrc + Height));
    if Image = nil then
      Exit;
    Source := CompatReadImage(Image);
    SetLength(Pixels, Width * Height);
    for IY := 0 to Height - 1 do
      for IX := 0 to Width - 1 do
      begin
        Point := TransformCanvasPoint(PointF(XSrc + IX + 0.5, YSrc + IY + 0.5), Src.FMatrix);
        SX := Floor(Point.X);
        SY := Floor(Point.Y);
        MX := XMask + IX;
        MY := YMask + IY;
        if (SX >= 0) and (SY >= 0) and (SX < Src.FDeviceWidth) and (SY < Src.FDeviceHeight) and (MX >= 0) and (MY >= 0) and (MX < Mask.Width) and (MY < Mask.Height) and
          (ColorToRGB(Mask.Canvas.Pixels[MX, MY]) <> 0) then
          Pixels[IY * Width + IX] := Source[IY * Image.Width + IX] or $FF000000;
      end;
    FCanvas.DrawImage(CompatImage(Pixels, Width, Height), X, Y);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.PlgBlt(const Points: array of TPoint; Src: TSkiaCanvas; XSrc, YSrc, Width, Height: Integer);
var
  Image: ISkImage;
  M, Combined: TMatrix;
  DX1, DY1, DX2, DY2: Single;
begin
  if not BeginOperation(2) then
    Exit;
  try
    if (Length(Points) < 3) or (Width = 0) or (Height = 0) then
      Exit;
    DX1 := Points[1].X - Points[0].X;
    DY1 := Points[1].Y - Points[0].Y;
    DX2 := Points[2].X - Points[0].X;
    DY2 := Points[2].Y - Points[0].Y;
    if Abs(DX1 * DY2 - DX2 * DY1) < 1E-12 then
      Exit;
    Image := SourceRectangle(Src, RectF(XSrc, YSrc, XSrc + Width, YSrc + Height));
    if Image = nil then
      Exit;
    M := TMatrix.Identity;
    M.M11 := DX1 / Width;
    M.M12 := DY1 / Width;
    M.M21 := DX2 / Height;
    M.M22 := DY2 / Height;
    M.M31 := Points[0].X;
    M.M32 := Points[0].Y;
    if Width < 0 then
    begin
      M.M31 := M.M31 + DX1;
      M.M32 := M.M32 + DY1;
    end;
    if Height < 0 then
    begin
      M.M31 := M.M31 + DX2;
      M.M32 := M.M32 + DY2;
    end;
    Combined := M * FMatrix;
    FCanvas.Save;
    try
      FCanvas.SetMatrix(Combined);
      FCanvas.DrawImage(Image, 0, 0);
    finally
      FCanvas.Restore;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.TextOut(X, Y: Integer; const Text: string);
var
  Fnt: ISkFont;
  Paint: ISkPaint;
  Metrics: TSkFontMetrics;
  Baseline, TextW: Single;
  LinePaint: ISkPaint;
  BgPaint: ISkPaint;
  Curves: TSkiaCurvesText;
  UseCurves: Boolean;
begin
  if not BeginOperation(0) then
    Exit;
  FCanvas.Save;
  try

    if FFont.Orientation <> 0 then
    begin
      FCanvas.Translate(X, Y);
      FCanvas.Rotate(-FFont.Orientation / 10);
      FCanvas.Translate(-X, -Y);
    end;

    if Text = '' then
      Exit;
    { Shape once so text outlines and their background share the same advance. }
    UseCurves := FTextToCurves and PrepareCurvesText(Text, Curves);
    { A non-clear brush paints an opaque text background using the measured bounds. }
    if FBrush.Style <> bsClear then
    begin
      Fnt := AcquireFont;
      if UseCurves then
        TextW := Curves.WidthPx
      else
        TextW := Fnt.MeasureText(Text);
      Fnt.GetMetrics(Metrics);
      BgPaint := AcquireFillPaint(RectF(X, Y, X + TextW, Y + Metrics.Descent - Metrics.Ascent));
      if BgPaint <> nil then
        FCanvas.DrawRect(RectF(X, Y, X + TextW, Y + Metrics.Descent - Metrics.Ascent), BgPaint);
    end;

    if UseCurves then
    begin
      DrawCurvesText(X, Y, Curves);
      Exit;
    end;
    Fnt := AcquireFont;
    Paint := TSkPaint.Create;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := ColorToAlphaColor(FFont.Color, FFont.Alpha);
    Paint.AntiAlias := True;
    { Skia draws at the baseline; its negative ascent converts the VCL top coordinate. }
    Fnt.GetMetrics(Metrics);
    Baseline := Y - Metrics.Ascent;
    PlainTextPaths(Text, X, Baseline, Fnt, Paint);
    { Draw underline and strikeout explicitly because glyph outlines exclude decorations. }
    if (fsUnderline in FFont.Style) or (fsStrikeOut in FFont.Style) then
    begin
      TextW := Fnt.MeasureText(Text);
      LinePaint := TSkPaint.Create;
      LinePaint.Style := TSkPaintStyle.Fill;
      LinePaint.Color := Paint.Color;
      LinePaint.AntiAlias := True;
      if fsUnderline in FFont.Style then
      begin

        FCanvas.DrawRect(RectF(X, Baseline + Metrics.Descent - 1, X + TextW, Baseline + Metrics.Descent), LinePaint);
      end;
      if fsStrikeOut in FFont.Style then
      begin

        FCanvas.DrawRect(RectF(X, Baseline + (Metrics.Ascent + Metrics.Descent) / 2 - 0.5, X + TextW, Baseline + (Metrics.Ascent + Metrics.Descent) / 2 + 0.5), LinePaint);
      end;
    end;
  finally
    FCanvas.Restore;
    EndOperation;
  end;
end;

{ Prepare shaping once and reuse it for drawing, background bounds and text measurement. }
function TSkiaCanvas.PrepareCurvesText(const Text: string; out Data: TSkiaCurvesText): Boolean;
var
  LF: TLogFontW;
  FontKey: string;
  I: Integer;
  Shaper: ISkShaper;
  Font: ISkFont;
  Endpoint: TPointF;
  Face: ISkTypeface;
  Provider: ISkTypefaceFontProvider;
  Style: ISkParagraphStyle;
  Builder: ISkParagraphBuilder;
  Paragraph: ISkParagraph;
begin
  Result := False;
  { Do not zero this record with FillChar: it contains managed fields. }
  Data.Blob := nil;
  Data.Glyphs := nil;
  Data.EmSquare := 0;
  Data.SizePx := 0;
  Data.WidthPx := 0;
  if Text = '' then
    Exit(True);

  if NeedsSkiaShaper then
  begin
    Font := AcquireFont;
{$IFNDEF MSWINDOWS}
    if not TypefaceCoversText(Font.Typeface, Text) then
    begin
      Face := FResources.FontManager.MatchTypefaceForText(Text, FFont.Name);
      if Face <> nil then
      begin
        Font := TSkFont.Create(Face, Font.Size);
        Font.Subpixel := True;
        Font.Hinting := TSkFontHinting.None;
      end;
    end;
{$ENDIF}
    Shaper := TSkShaper.Create;
    Data.Blob := Shaper.Shape(Text, Font, not FShapingRTL, 1.0E8, PointF(0, 0), Endpoint);
    { SkShaper.endPoint is the next line origin, not the text advance. }
    Provider := TSkTypefaceFontProvider.Create;
    Provider.RegisterTypeface(Font.Typeface, 'CanvasPrivateFont');
    Style := TSkParagraphStyle.Create;
    if FShapingRTL then
      Style.TextDirection := TSkTextDirection.RightToLeft;
    Style.TextStyle.FontFamilies := TArray<string>.Create('CanvasPrivateFont');
    Style.TextStyle.FontSize := Font.Size;
    Builder := TSkParagraphBuilder.Create(Style, Provider);
    Builder.AddText(Text);
    Paragraph := Builder.Build;
    Paragraph.Layout(1.0E8);
    Data.WidthPx := Paragraph.MaxIntrinsicWidth;
    Data.SizePx := Font.Size;
    Data.EmSquare := 1;
    Exit(Data.Blob <> nil);
  end;

{$IFDEF MSWINDOWS}
  if not FResources.FontManager.GetLogFont(FFont, LF) then
    Exit;
  FontKey := FResources.FontManager.FontKey(FFont);

  Data.EmSquare := FGlyphCache.GetEmSquare(LF, FontKey);
  if Data.EmSquare <= 0 then
    Exit;
  { Scale by the actual character height, not the requested LOGFONT height, which can differ after font substitution. }
  Data.SizePx := FGlyphCache.GetCharHeight(LF, FontKey);
  if Data.SizePx <= 0 then
  begin
    if LF.lfHeight <> 0 then
      Data.SizePx := Abs(LF.lfHeight)
    else
      Data.SizePx := AcquireFont.GetSize;
  end;
  if Data.SizePx <= 0 then
    Exit;

  if not FGlyphCache.ShapeText(LF, FontKey, Data.EmSquare, UnicodeString(Text), Data.Glyphs) then
    Exit;
  Data.WidthPx := 0;
  for I := 0 to High(Data.Glyphs) do
    Data.WidthPx := Data.WidthPx + Data.Glyphs[I].AdvanceX;
  Data.WidthPx := Data.WidthPx * Data.SizePx / Data.EmSquare;
  Result := True; {$ENDIF}
end;

{ GDI outlines use design units with Y pointing up. Local translation and scaling compose with the current world transform. }
procedure TSkiaCanvas.DrawCurvesText(X, Y: Integer; const Data: TSkiaCurvesText);
var
  Fnt: ISkFont;
  Metrics: TSkFontMetrics;
  Paint, LinePaint: ISkPaint;
  Baseline, Scale: Single;
  PenX: Double;
  I: Integer;
  GlyphPath: ISkPath;
  Adv: Single;
begin
  Fnt := AcquireFont;
  Fnt.GetMetrics(Metrics);
  Baseline := Y - Metrics.Ascent;
  Scale := Data.SizePx / Data.EmSquare;
  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := ColorToAlphaColor(FFont.Color, FFont.Alpha);
  Paint.AntiAlias := True;

  if Data.Blob <> nil then
    BlobPaths(Data.Blob, X, Y, Data.WidthPx, Data.SizePx, Paint)
  else

  begin
    FCanvas.Save;
    try
      FCanvas.Translate(X, Baseline);
      FCanvas.Scale(Scale, -Scale);
      PenX := 0;
      for I := 0 to High(Data.Glyphs) do
      begin
        GlyphPath := FGlyphCache.GetGlyphPathByIndex(Data.Glyphs[I].GlyphIndex, Adv);
        if GlyphPath <> nil then
        begin
          FCanvas.Save;
          try
            FCanvas.Translate(PenX + Data.Glyphs[I].OffsetX, Data.Glyphs[I].OffsetY);
            FCanvas.DrawPath(GlyphPath, Paint);
          finally
            FCanvas.Restore;
          end;
        end;
        PenX := PenX + Data.Glyphs[I].AdvanceX;
      end;
    finally
      FCanvas.Restore;
    end;
  end;

  if (fsUnderline in FFont.Style) or (fsStrikeOut in FFont.Style) then
  begin
    LinePaint := TSkPaint.Create;
    LinePaint.Style := TSkPaintStyle.Fill;
    LinePaint.Color := Paint.Color;
    LinePaint.AntiAlias := True;
    if fsUnderline in FFont.Style then
      FCanvas.DrawRect(RectF(X, Baseline + Metrics.Descent - 1, X + Data.WidthPx, Baseline + Metrics.Descent), LinePaint);
    if fsStrikeOut in FFont.Style then
      FCanvas.DrawRect(RectF(X, Baseline + (Metrics.Ascent + Metrics.Descent) / 2 - 0.5, X + Data.WidthPx, Baseline + (Metrics.Ascent + Metrics.Descent) / 2 + 0.5), LinePaint);
  end;
end;
{ Validate GGO_NATIVE records before building paths. Quadratic spline endpoints are implied midpoints between adjacent off-curve points. }
{$IFDEF MSWINDOWS}

function GdiNativeOutlineToSkPath(Buf: Pointer; BufSize: DWORD; Path: ISkiaPathBuilder): Boolean;

const
  TT_POLYGON_TYPE = 24;

  function FxToFloat(const Fx: FIXED): Single; inline;
  begin
    Result := Fx.Value + Fx.fract / 65536;
  end;

{ Validate the entire outline before modifying the destination path. }
  function ValidateOutline(P: PByte; Size: DWORD): Boolean;
  var
    Q, QEnd, QLim: PByte;
    Hdr: PTTPOLYGONHEADER;
    Curve: PTTPOLYCURVE;
  begin
    Result := False;
    Q := P;
    QEnd := P + Size;
    while Q < QEnd do
    begin
      if Q + SizeOf(TTPOLYGONHEADER) > QEnd then
        Exit;
      Hdr := PTTPOLYGONHEADER(Q);
      if (Hdr.dwType <> TT_POLYGON_TYPE) or (Hdr.cb < SizeOf(TTPOLYGONHEADER)) or (Q + Hdr.cb > QEnd) then
        Exit;
      QLim := Q + Hdr.cb;
      Q := Q + SizeOf(TTPOLYGONHEADER);
      while Q < QLim do
      begin
        if Q + SizeOf(TTPOLYCURVE) > QLim then
          Exit;
        Curve := PTTPOLYCURVE(Q);
        if (Curve.cpfx = 0) or (Q + SizeOf(TTPOLYCURVE) - SizeOf(POINTFX) + DWORD(Curve.cpfx) * SizeOf(POINTFX) > QLim) then
          Exit;
        case Curve.wType of
          TT_PRIM_LINE:
            ;
          TT_PRIM_QSPLINE:
            if Curve.cpfx < 2 then
              Exit;
          TT_PRIM_CSPLINE:
            if Curve.cpfx mod 3 <> 0 then
              Exit;
        else
          Exit;
        end;
        Q := Q + SizeOf(TTPOLYCURVE) - SizeOf(POINTFX) + DWORD(Curve.cpfx) * SizeOf(POINTFX);
      end;
    end;
    Result := True;
  end;

var
  P, EndP: PByte;
  Hdr: PTTPOLYGONHEADER;
  Curve: PTTPOLYCURVE;
  I, J: Integer;
  Pt: PPOINTFX;
  CX, CY, EX, EY: Single;
begin
  Result := False;
  if (Buf = nil) or (BufSize < SizeOf(TTPOLYGONHEADER)) or (Path = nil) then
    Exit;
  if not ValidateOutline(PByte(Buf), BufSize) then
    Exit;
  P := PByte(Buf);
  EndP := P + BufSize;
  while P < EndP do
  begin
    Hdr := PTTPOLYGONHEADER(P);
    Path.MoveTo(FxToFloat(Hdr.pfxStart.X), FxToFloat(Hdr.pfxStart.Y));
    Result := True;
    P := P + SizeOf(TTPOLYGONHEADER);
    while P < PByte(Hdr) + Hdr.cb do
    begin
      Curve := PTTPOLYCURVE(P);
      Pt := @Curve.apfx[0];
      case Curve.wType of
        TT_PRIM_LINE:
          for I := 0 to Curve.cpfx - 1 do
            Path.LineTo(FxToFloat(Pt[I].X), FxToFloat(Pt[I].Y));
        TT_PRIM_QSPLINE:
          { Intermediate quadratic endpoints are midpoints; the final point is an explicit endpoint. }
          for J := 0 to Curve.cpfx - 2 do
          begin
            CX := FxToFloat(Pt[J].X);
            CY := FxToFloat(Pt[J].Y);
            if J = Curve.cpfx - 2 then
            begin
              EX := FxToFloat(Pt[J + 1].X);
              EY := FxToFloat(Pt[J + 1].Y);
            end
            else
            begin
              EX := (CX + FxToFloat(Pt[J + 1].X)) / 2;
              EY := (CY + FxToFloat(Pt[J + 1].Y)) / 2;
            end;
            Path.QuadTo(CX, CY, EX, EY);
          end;
        TT_PRIM_CSPLINE:
          begin
            I := 0;
            while I < Curve.cpfx do
            begin
              Path.CubicTo(FxToFloat(Pt[I].X), FxToFloat(Pt[I].Y), FxToFloat(Pt[I + 1].X), FxToFloat(Pt[I + 1].Y), FxToFloat(Pt[I + 2].X), FxToFloat(Pt[I + 2].Y));
              Inc(I, 3);
            end;
          end;
      end;
      P := P + SizeOf(TTPOLYCURVE) - SizeOf(POINTFX) + DWORD(Curve.cpfx) * SizeOf(POINTFX);
    end;
    { Close the contour even if its last point differs from its first point. }
    Path.Close;
    P := PByte(Hdr) + Hdr.cb;
  end;
end;

{$ENDIF}

function TSkiaCanvas.TextExtent(const Text: string): TSize;
var
  Fnt: ISkFont;
  Metrics: TSkFontMetrics;
  Curves: TSkiaCurvesText;
begin
  if Text = '' then
    Exit(TSize.Create(0, 0));
  Fnt := AcquireFont;
  Fnt.GetMetrics(Metrics);
  { Measure with the same shaping as drawing so centered and right-aligned text stays aligned. }
  if FTextToCurves and PrepareCurvesText(Text, Curves) then
    Result := TSize.Create(Ceil(Curves.WidthPx), Ceil(Metrics.Descent - Metrics.Ascent))
  else
    Result := TSize.Create(Ceil(Fnt.MeasureText(Text)), Ceil(Metrics.Descent - Metrics.Ascent));
end;

procedure TSkiaCanvas.TextRect(Rect: TRect; X, Y: Integer; const Text: string);
begin
  if not BeginOperation(0) then
    Exit;
  try
    if Text = '' then
      Exit;
    FCanvas.Save;
    try
      FCanvas.ClipRect(RectToRectF(Rect));
      TextOut(X, Y, Text);
    finally
      FCanvas.Restore;
    end;
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.TextRect(var Rect: TRect; var Text: string; TextFormat: TTextFormat);
begin
  if not BeginOperation(0) then
    Exit;
  try
    LayoutText(Rect, Text, TextFormat);
  finally
    EndOperation;
  end;
end;

procedure TSkiaCanvas.FloodFill(X, Y: Integer; Color: TColor; FillStyle: TFillStyle);
var
  Pixels, Clip, Fill, Patch: TArray<TAlphaColor>;
  Visited: TArray<Boolean>;
  Stack: TArray<TPoint>;
  SP, W, H, I: Integer;
  Seed, Target: Cardinal;
  P, a, B, C, D: TPoint;
  Surface: ISkSurface;
  Paint: ISkPaint;
  Bounds: TRectF;
  procedure Push(XX, YY: Integer);
  begin
    if (XX < 0) or (YY < 0) or (XX >= W) or (YY >= H) then
      Exit;
    if SP = Length(Stack) then
      SetLength(Stack, SP + 1024);
    Stack[SP] := Point(XX, YY);
    Inc(SP);
  end;

begin
  if not BeginOperation(0) then
    Exit;
  try
    Pixels := ReadDevicePixels(W, H);
    Clip := ClipPixels;
    P := LPToDP(Point(X, Y));
    if (P.X < 0) or (P.Y < 0) or (P.X >= W) or (P.Y >= H) or (FBrush.Style = bsClear) then
      Exit;
    Seed := Pixels[P.Y * W + P.X] and $FFFFFF;
    Target := ColorToAlphaColor(Color) and $FFFFFF;
    if (FillStyle = fsSurface) and (Seed <> Target) then
      Exit;
    Surface := TSkSurface.MakeRaster(W, H);
    Surface.GetCanvas.SetMatrix(FMatrix);
    a := DPToLP(Point(0, 0));
    B := DPToLP(Point(W, 0));
    C := DPToLP(Point(0, H));
    D := DPToLP(Point(W, H));
    Bounds := RectF(Math.Min(Math.Min(a.X, B.X), Math.Min(C.X, D.X)) - 2, Math.Min(Math.Min(a.Y, B.Y), Math.Min(C.Y, D.Y)) - 2, Math.Max(Math.Max(a.X, B.X), Math.Max(C.X, D.X)) + 2,
      Math.Max(Math.Max(a.Y, B.Y), Math.Max(C.Y, D.Y)) + 2);
    Paint := AcquireFillPaint(Bounds);
    if Paint = nil then
      Exit;
    Surface.GetCanvas.DrawRect(Bounds, Paint);
    Fill := CompatReadImage(Surface.MakeImageSnapshot);
    SetLength(Patch, W * H);
    SetLength(Visited, W * H);
    SP := 0;
    Push(P.X, P.Y);
    while SP > 0 do
    begin
      Dec(SP);
      P := Stack[SP];
      I := P.Y * W + P.X;
      if Visited[I] then
        Continue;
      Visited[I] := True;
      if Clip[I] shr 24 = 0 then
        Continue;
      if (FillStyle = fsSurface) and ((Pixels[I] and $FFFFFF) <> Target) then
        Continue;
      if (FillStyle = fsBorder) and ((Pixels[I] and $FFFFFF) = Target) then
        Continue;
      Patch[I] := Fill[I];
      Push(P.X - 1, P.Y);
      Push(P.X + 1, P.Y);
      Push(P.X, P.Y - 1);
      Push(P.X, P.Y + 1);
    end;
    CommitPatch(Patch, W, H);
  finally
    EndOperation;
  end;
end;

{ Store clip paths in device coordinates; state snapshots preserve the complete clip sequence. }

procedure TSkiaCanvas.SetClipRect(const R: TRect);
var
  Path: ISkiaPathBuilder;
begin
  Path := TSkiaPathBuilder.Create;
  Path.AddRect(RectToRectF(R));
  SetClipPath(Path.Snapshot);
end;

procedure TSkiaCanvas.SetClipPath(const Path: ISkPath);
begin
  FClips := nil;
  if Path <> nil then
    AppendClip(Path.Transform(FMatrix), TSkClipOp.Intersect);
end;

procedure TSkiaCanvas.SetClipRegion(const R: TRect);
begin
  SetClipRect(R);
end;

procedure TSkiaCanvas.SetClipRegion(const Region: ISkRegion);

begin
  if Region = nil then
  begin
    ResetClip;
    Exit;
  end;
  SetClipPath(Region.GetBoundaryPath);
end;

procedure TSkiaCanvas.IntersectClipRect(const R: TRect);
var
  Path: ISkiaPathBuilder;
begin
  Path := TSkiaPathBuilder.Create;
  Path.AddRect(RectToRectF(R));
  AppendClip(Path.Snapshot.Transform(FMatrix), TSkClipOp.Intersect);
end;

procedure TSkiaCanvas.ExcludeClipRect(const R: TRect);
var
  Path: ISkiaPathBuilder;
begin
  Path := TSkiaPathBuilder.Create;
  Path.AddRect(RectToRectF(R));
  AppendClip(Path.Snapshot.Transform(FMatrix), TSkClipOp.Difference);
end;

procedure TSkiaCanvas.ResetClip;
begin
  FClips := nil;
  FClipDepth := -1;
end;

{ Keep the world matrix in the wrapper for coordinate conversion and operation recording. }

procedure TSkiaCanvas.SetWorldTransform(const M: TMatrix);
begin
  FMatrix := M;
  FCanvas.SetMatrix(M);
end;

function TSkiaCanvas.GetWorldTransform: TMatrix;
begin
  Result := FMatrix;
end;

procedure TSkiaCanvas.ResetWorldTransform;
begin
  FMatrix := TMatrix.Identity;
  FCanvas.ResetMatrix;
end;

procedure TSkiaCanvas.TranslateTransform(DX, DY: Single);
var
  M: TMatrix;
begin
  M := TMatrix.Identity;
  { Delphi row-vector convention stores translation in M31 and M32. }
  M.M31 := DX;
  M.M32 := DY;
  FMatrix := FMatrix * M;
  FCanvas.SetMatrix(FMatrix);
end;

procedure TSkiaCanvas.ScaleTransform(SX, SY: Single);
var
  M: TMatrix;
begin
  M := TMatrix.Identity;
  M.M11 := SX;
  M.M22 := SY;
  FMatrix := FMatrix * M;
  FCanvas.SetMatrix(FMatrix);
end;

procedure TSkiaCanvas.RotateTransform(Angle: Single);
var
  M: TMatrix;
  R: Single;
begin
  R := DegToRad(Angle);
  M := TMatrix.Identity;
  { Delphi row-vector rotation: M11 = cos, M21 = -sin, M12 = sin, M22 = cos. }
  M.M11 := Cos(R);
  M.M21 := -Sin(R);
  M.M12 := Sin(R);
  M.M22 := Cos(R);
  FMatrix := FMatrix * M;
  FCanvas.SetMatrix(FMatrix);
end;

function TSkiaCanvas.SaveState: Integer;
var
  St: TSkiaCanvasState;
begin
  St := TSkiaCanvasState.Create;
  try
    St.SaveCount := FCanvas.Save;
    try
      CaptureState(St);
    except
      FCanvas.RestoreToCount(St.SaveCount - 1);
      raise;
    end;
    FStateStack.Add(St);
    Result := FStateStack.Count;
  except
    St.Free;
    raise;
  end;
end;

procedure TSkiaCanvas.RestoreState(SavedIndex: Integer);
var
  I: Integer;
begin
  if SavedIndex <= 0 then
    SavedIndex := FStateStack.Count;
  if (SavedIndex < 1) or (SavedIndex > FStateStack.Count) then
    raise ESkiaCanvasError.CreateFmt(SSkiaInvalidSavedState, [SavedIndex, FStateStack.Count]);

  FCanvas.RestoreToCount(FStateStack[SavedIndex - 1].SaveCount - 1);
  ApplyState(FStateStack[SavedIndex - 1]);
  for I := FStateStack.Count - 1 downto SavedIndex - 1 do
    FStateStack.Delete(I);
end;

function TSkiaCanvas.LPToDP(const P: TPoint): TPoint;
var
  Pt: TPointF;
begin
  Pt := TransformCanvasPoint(PointF(P.X, P.Y), FMatrix);
  Result := Point(Round(Pt.X), Round(Pt.Y));
end;

function TSkiaCanvas.DPToLP(const P: TPoint): TPoint;
var
  Det, InvDet: Single;
  Pt: TPointF;
begin
  { Inverse affine transform for Delphi row vectors: X = x*M11 + y*M21 + M31; Y = x*M12 + y*M22 + M32. }
  Det := FMatrix.M11 * FMatrix.M22 - FMatrix.M12 * FMatrix.M21;
  if Abs(Det) < 1E-12 then
    Exit(P);
  InvDet := 1 / Det;
  Pt.X := ((P.X - FMatrix.M31) * FMatrix.M22 - (P.Y - FMatrix.M32) * FMatrix.M21) * InvDet;
  Pt.Y := ((P.Y - FMatrix.M32) * FMatrix.M11 - (P.X - FMatrix.M31) * FMatrix.M12) * InvDet;
  Result := Point(Round(Pt.X), Round(Pt.Y));
end;

constructor TSkiaBitmapCanvas.Create(AWidth, AHeight: Integer);
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise ESkiaCanvasError.CreateFmt(SSkiaInvalidBitmapSize, [AWidth, AHeight]);
  FSurface := TSkSurface.MakeRaster(AWidth, AHeight);
  FWidth := AWidth;
  FHeight := AHeight;
  inherited Create(FSurface.GetCanvas, False);
end;

function TSkiaBitmapCanvas.LockPixels(out APixels: TArray<TAlphaColor>; out AWidth, AHeight: Integer): Boolean;

begin
  AWidth := FWidth;
  AHeight := FHeight;
  SetLength(FPixelBuffer, FWidth * FHeight);
  Result := (FSurface <> nil) and FSurface.ReadPixels(TSkImageInfo.Create(FWidth, FHeight, TSkColorType.BGRA8888, TSkAlphaType.Unpremul), Pointer(FPixelBuffer), FWidth * SizeOf(TAlphaColor));
  APixels := FPixelBuffer;
end;

procedure TSkiaBitmapCanvas.UnlockPixels;
begin

  if (FSurface <> nil) and (Length(FPixelBuffer) > 0) then
    FSurface.WritePixels(TSkImageInfo.Create(FWidth, FHeight, TSkColorType.BGRA8888, TSkAlphaType.Unpremul), Pointer(FPixelBuffer), FWidth * SizeOf(TAlphaColor));
  FPixelBuffer := nil;

end;

procedure TSkiaBitmapCanvas.Flush(ABitmap: TBitmap);
var
  Pixels: TArray<TAlphaColor>;
  W, H, X, Y: Integer;
{$IFDEF MSWINDOWS}Row: PCardinal; {$ELSE}Image: TLazIntfImage;
  C: TFPColor;
  Value: Cardinal; {$ENDIF}
begin
  if ABitmap = nil then
    raise ESkiaCanvasError.Create(SSkiaFlushRequiresBitmap);
  if not LockPixels(Pixels, W, H) then
    raise ESkiaCanvasError.Create(SSkiaFlushPixelsUnavailable);
  try
{$IFNDEF MSWINDOWS}
    Image := TLazIntfImage.Create(W, H, [riqfRGB, riqfAlpha]);
    try
      for Y := 0 to H - 1 do
        for X := 0 to W - 1 do
        begin
          Value := Pixels[Y * W + X];
          C.Red := ((Value shr 16) and 255) * 257;
          C.Green := ((Value shr 8) and 255) * 257;
          C.Blue := (Value and 255) * 257;
          C.Alpha := (Value shr 24) * 257;
          Image.Colors[X, Y] := C;
        end;
      ABitmap.LoadFromIntfImage(Image);
      ABitmap.AlphaFormat := afDefined;
    finally
      Image.Free;
    end;
{$ELSE}
    ABitmap.PixelFormat := pf32bit;
    ABitmap.SetSize(W, H);
    ABitmap.AlphaFormat := afDefined;
    for Y := 0 to H - 1 do
    begin
      { VCL ScanLine[Y] addresses logical row Y; pf32bit stores BGRA rather than COLORREF. }
      Row := ABitmap.ScanLine[Y];
      for X := 0 to W - 1 do

        Row[X] := Cardinal(Pixels[Y * W + X]);

    end;
{$ENDIF}
  finally
    UnlockPixels;
  end;
end;

function TSkiaBitmapCanvas.Snapshot: ISkImage;
begin
  Result := FSurface.MakeImageSnapshot;
end;

constructor TSkiaMetafileCanvas.Create(AWidth, AHeight: Single);
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise ESkiaCanvasError.CreateFmt(SSkiaInvalidMetafileSize, [AWidth, AHeight]);
  FRecorder := TSkPictureRecorder.Create;
  FWidth := AWidth;
  FHeight := AHeight;
  inherited Create(FRecorder.BeginRecording(AWidth, AHeight), False);
end;

function TSkiaMetafileCanvas.FinishRecording: ISkPicture;
begin
  if FRecorder = nil then
    raise ESkiaCanvasError.Create(SSkiaRecordingCompleted);
  { Do not keep an expired recording handle in the native-target registry. }
  UnregisterCompatibility;
  Result := FRecorder.FinishRecording;
  FRecordingClosed := True;

  { The recording canvas expires at FinishRecording. Subsequent drawing is
    discarded on an empty clip instead of accessing its released handle. }
  FDiscardSurface := TSkSurface.MakeRaster(1, 1);
  FCanvas := FDiscardSurface.Canvas;
  FCanvas.ClipRect(RectF(0, 0, 0, 0));

  FRecorder := nil;
end;

procedure TSkiaMetafileCanvas.Playback(Target: TSkiaCanvas);
var
  Pic: ISkPicture;
begin
  if Target = nil then
    raise ESkiaCanvasError.Create(SSkiaPlaybackRequiresCanvas);
  Pic := FinishRecording;
  if Target.BeginOperation(0) then
    try
      Pic.Playback(Target.FCanvas);
    finally
      Target.EndOperation;
    end;
end;

procedure TSkiaMetafileCanvas.Playback(const Target: ISkCanvas);
var
  Pic: ISkPicture;
begin
  if Target = nil then
    raise ESkiaCanvasError.Create(SSkiaPlaybackRequiresSkiaCanvas);
  Pic := FinishRecording;
  Pic.Playback(Target);
end;

initialization

{$IFDEF FPC}{$IFNDEF MSWINDOWS}
{ Skia uses IEEE nontrapping math, matching the Windows Skia API loader. }
SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
{$ENDIF}{$ENDIF}
GCompatCanvasesLock := SyncObjs.TCriticalSection.Create;
GCompatCanvases := TList<TSkiaCanvas>.Create;

finalization

FreeAndNil(GCompatCanvases);
FreeAndNil(GCompatCanvasesLock);

end.
