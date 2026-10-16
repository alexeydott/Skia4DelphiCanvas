{ Typography examples shared by raster and recording canvases. }
unit SkiaDemoScenes;
{$IFDEF FPC}{$MODE DELPHIUNICODE}{$CODEPAGE UTF8}{$ENDIF}
interface
uses Classes, SysUtils, Types, Math, {$IFDEF MSWINDOWS}{$IFDEF FPC}Windows,{$ELSE}Winapi.Windows,{$ENDIF}{$ELSE}LCLType,{$ENDIF} Vcl.Graphics,
  System.Skia, Vcl.Graphics.Skia;
const ShowcaseWidth = 1000; ShowcaseHeight = 1280;
procedure DrawShowcase(C: TSkiaCanvas);
function NativeText(const S: UnicodeString): string;
procedure LabelText(C: TSkiaCanvas; X,Y,Size: Integer;
  const S: UnicodeString; Color: TColor = clNavy);
procedure Card(C: TSkiaCanvas; X,Y: Integer; const Title,Subtitle: string);
implementation
function NativeText(const S: UnicodeString): string;
begin
  Result := S;
end;
procedure LabelText(C: TSkiaCanvas; X,Y,Size: Integer;
  const S: UnicodeString; Color: TColor);
begin
  C.Font.Name := 'Arial'; C.Font.Height := -Size;
  C.Font.Style := []; C.Font.Color := Color; C.Font.Alpha := 255;
  C.Brush.Style := bsClear; C.TextToCurves := True;
  C.TextOut(X,Y,NativeText(S));
end;
function ShapeWidth(C: TSkiaCanvas; const S: UnicodeString;
  out Count: Integer): Single;
var LF: TLogFontW; Key: string; G: TArray<TGdiShapedGlyph>;
  Em,I: Integer;
begin
  Result := 0; Count := 0;
  if not C.FontManager.GetLogFont(C.Font,LF) then Exit;
  Key := C.FontManager.FontKey(C.Font);
  Em := C.GlyphCache.GetEmSquare(LF,Key);
  if not C.GlyphCache.ShapeText(LF,Key,Em,S,G) then Exit;
  Count := Length(G);
  for I := 0 to High(G) do Result := Result + G[I].AdvanceX;
  Result := Result * C.GlyphCache.GetCharHeight(LF,Key) / Em;
end;
procedure Card(C: TSkiaCanvas; X,Y: Integer; const Title,Subtitle: string);
begin
  C.Brush.Style := bsSolid; C.Brush.Color := clWhite; C.Brush.Alpha := 255;
  C.Pen.Style := psSolid; C.Pen.Color := TColor($E4DDE0); C.Pen.Width := 1;
  C.RoundRect(X,Y,X+464,Y+340,18,18);
  LabelText(C,X+20,Y+18,21,UnicodeString(Title));
  LabelText(C,X+20,Y+50,13,UnicodeString(Subtitle),TColor($78665E));
end;
procedure DrawShowcase(C: TSkiaCanvas);
const
  KernText: UnicodeString = 'AVATAR To WA';
  Arabic: UnicodeString = #$0633#$0644#$0627#$0645;
  LamAlef: UnicodeString = #$0644#$0627;
  Hebrew: UnicodeString = #$05E9#$05DC#$05D5#$05DD;
var X,Y,I,N: Integer; W,RawW,KernW,Cursor: Single; S: UnicodeString;
  P: TPoint;
begin
  C.Brush.Style := bsSolid; C.Brush.Color := TColor($F7F5F1);
  C.FillRect(Types.Rect(0,0,ShowcaseWidth,ShowcaseHeight));
  C.Brush.Gradient := gkHorizontal;
  C.Brush.GradientStartColor := TColor($512514);
  C.Brush.GradientEndColor := TColor($805D21);
  C.FillRect(Types.Rect(0,0,ShowcaseWidth,124)); C.Brush.Gradient := gkNone;
  LabelText(C,28,24,34,'Skia canvas / typography lab',clWhite);
  LabelText(C,30,76,16,'One scene: raster, recorded picture, PDF and SVG. Text exported as paths.',clWhite);

  X:=24; Y:=148;
  Card(C,X,Y,'01 / Pair kerning','Times New Roman / separate characters vs shaped run');
  LabelText(C,X+20,Y+90,13,'SEPARATE CHARACTERS',TColor($78665E));
  C.Font.Name:='Times New Roman'; C.Font.Height:=-46;
  C.Font.Color:=TColor($78665E); Cursor:=X+20; RawW:=0;
  for I:=1 to Length(KernText) do begin
    S:=Copy(KernText,I,1); W:=ShapeWidth(C,S,N);
    C.TextOut(Round(Cursor),Y+113,NativeText(S)); Cursor:=Cursor+W; RawW:=RawW+W;
  end;
  LabelText(C,X+20,Y+182,13,'SHAPED RUN / PAIR ADJUSTMENTS',TColor($78665E));
  C.Font.Name:='Times New Roman'; C.Font.Height:=-46; C.Font.Color:=clNavy;
  W:=ShapeWidth(C,KernText,N); KernW:=W;
  C.TextOut(X+20,Y+205,NativeText(KernText));
  LabelText(C,X+20,Y+281,14,UnicodeString(Format('Widths: %.1f -> %.1f px   /   %d glyphs',[RawW,W,N])));

  X:=512;
  Card(C,X,Y,'02 / Context and ligatures','Arial / Arabic joining and lam-alef substitution');
  LabelText(C,X+20,Y+90,13,'ISOLATED LETTERS',TColor($78665E));
  C.Font.Height:=-42; Cursor:=X+20;
  for I:=Length(Arabic) downto 1 do begin
    S:=Copy(Arabic,I,1); W:=ShapeWidth(C,S,N);
    C.TextOut(Round(Cursor),Y+112,NativeText(S)); Cursor:=Cursor+W+12;
  end;
  LabelText(C,X+20,Y+180,13,'JOINED WORD                       LAM + ALEF',TColor($78665E));
  C.Font.Height:=-52; C.Font.Color:=clNavy;
  C.TextOut(X+20,Y+205,NativeText(Arabic));
  C.TextOut(X+280,Y+205,NativeText(LamAlef));
  ShapeWidth(C,LamAlef,N);
  LabelText(C,X+20,Y+281,14,UnicodeString(Format('Lam-alef: 2 UTF-16 units -> %d glyph(s)',[N])));

  X:=24; Y:=508;
  Card(C,X,Y,'03 / Combining marks + scripts','Precomposed / decomposed accents; Cyrillic and Greek');
  LabelText(C,X+20,Y+92,35,'Caf'+#$00E9+'  /  Cafe'+#$0301);
  LabelText(C,X+20,Y+154,29,#$041F#$0440#$0438#$0432#$0435#$0442+'  /  '+#$039A#$03B1#$03BB#$03B7#$03BC#$03AD#$03C1#$03B1);
  LabelText(C,X+20,Y+221,26,'A'+#$030A+'   n'+#$0303+'   a'+#$0308+'   o'+#$0302);
  LabelText(C,X+280,Y+220,13,'UTF-16 pair');
  C.Font.Name:='Segoe UI Symbol'; C.Font.Height:=-30;
  C.TextOut(X+377,Y+212,NativeText(WideChar($D83D)+WideChar($DE00)));
  C.Font.Name:='Arial'; C.Font.Height:=-26; ShapeWidth(C,'e'+#$0301,N);
  LabelText(C,X+20,Y+281,14,UnicodeString(Format('e + combining acute: 2 units -> %d glyph(s)',[N])));

  X:=512;
  Card(C,X,Y,'04 / Bidirectional layout','Logical input / visual glyph order / punctuation and digits');
  LabelText(C,X+20,Y+100,30,'ABC 123 - '+Hebrew);
  LabelText(C,X+20,Y+158,30,Arabic+' 2026 / XYZ');
  LabelText(C,X+20,Y+221,26,'('+Hebrew+') / '+Arabic);
  LabelText(C,X+20,Y+281,14,'Contours retain joining and visual glyph order.');

  X:=24; Y:=868;
  Card(C,X,Y,'05 / Transform + clip + state','Rotated, scaled glyph outlines inside a fixed viewport');
  C.SaveState;
  try
    C.SetClipRect(Types.Rect(X+20,Y+90,X+444,Y+258));
    C.Brush.Style:=bsSolid; C.Brush.Color:=TColor($F8EEDF);
    C.FillRect(Types.Rect(X+20,Y+90,X+444,Y+258));
    C.RotateTransform(-12); C.ScaleTransform(1.15,1.15);
    C.TranslateTransform(X+24,Y+155);
    LabelText(C,0,0,44,'OUTLINE / AVATAR');
    LabelText(C,0,55,28,'Clipped vector typography');
  finally C.RestoreState; end;
  P:=C.LPToDP(Types.Point(0,0));
  LabelText(C,X+20,Y+281,14,UnicodeString(Format('After RestoreState: origin = (%d, %d)',[P.X,P.Y])));

  X:=512;
  Card(C,X,Y,'06 / Alpha + patterns + dashes','Layered fills, GDI hatching and custom dash pattern');
  C.Brush.Style:=bsDiagCross; C.Brush.Color:=TColor($C0A875);
  C.FillRect(Types.Rect(X+20,Y+90,X+444,Y+258));
  C.Brush.Style:=bsSolid; C.Brush.Color:=clRed; C.Brush.Alpha:=130;
  C.Pen.Style:=psClear; C.Ellipse(X+60,Y+104,X+242,Y+246);
  C.Brush.Color:=clBlue; C.Ellipse(X+190,Y+104,X+372,Y+246);
  C.Brush.Alpha:=255; C.Brush.Style:=bsClear;
  C.Pen.Style:=psSolid; C.Pen.Width:=3; C.Pen.Color:=clNavy;
  C.Pen.DashPattern:=TArray<Single>.Create(12,4,2,4);
  C.RoundRect(X+20,Y+90,X+444,Y+258,16,16);
  C.Pen.DashPattern:=nil;
  LabelText(C,X+20,Y+281,14,'130/255 alpha; dash = [12, 4, 2, 4].');

  
  {$IFDEF MSWINDOWS}LabelText(C,28,1232,14,'Native Windows: GDI outlines + Uniscribe shaping. No SVG font dependency.');{$ELSE}
  LabelText(C,28,1232,14,'Native Linux: Skia outlines and shaping. No SVG font dependency.');{$ENDIF}
  
  Writeln(Format('Showcase: %dx%d; independent vs shaped = %.1f / %.1f px',
    [ShowcaseWidth,ShowcaseHeight,RawW,KernW]));
end;
end.

