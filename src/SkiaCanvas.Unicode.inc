{ Scalar decoding and lookup of pinned Unicode properties. }
type
  TSkiaUnicodeRange = record First,Last:Cardinal;Value:Integer;end;
  TSkiaArabicForms = record Scalar:Cardinal;Forms:array[0..3] of Cardinal;end;
{$I SkiaCanvas.UnicodeData.inc}
function UnicodeRangeValue(Value:Cardinal;const Ranges:array of TSkiaUnicodeRange;Default:Integer):Integer;
var L,H,M:Integer;
begin
  L:=0;H:=High(Ranges);
  while L<=H do begin M:=(L+H) div 2;
    if Value<Ranges[M].First then H:=M-1 else if Value>Ranges[M].Last then L:=M+1
    else Exit(Ranges[M].Value);
  end;
  Result:=Default;
end;
class function TSkiaUnicode.ScalarText(Value:Cardinal):UnicodeString;
begin
  if (Value>$10FFFF) or ((Value>=$D800) and (Value<=$DFFF)) then
    raise ESkiaCanvasError.Create(SSkiaInvalidUnicodeScalar);
  if Value<$10000 then Result:=WideChar(Value)
  else begin Dec(Value,$10000);Result:=WideChar($D800+(Value shr 10))+WideChar($DC00+(Value and $3FF));end;
end;
class function TSkiaUnicode.DecodeUtf8(const Text:UTF8String):TArray<TSkiaCodePoint>;
var I,J,N,Count,Start:Integer;B:Byte;Value,Minimum:Cardinal;
begin
  SetLength(Result,Length(Text));I:=1;Count:=0;
  while I<=Length(Text) do begin
    Start:=I;B:=Byte(Text[I]);Inc(I);
    if B<$80 then begin N:=0;Value:=B;Minimum:=0;end
    else if (B>=$C2) and (B<=$DF) then begin N:=1;Value:=B and $1F;Minimum:=$80;end
    else if (B>=$E0) and (B<=$EF) then begin N:=2;Value:=B and $F;Minimum:=$800;end
    else if (B>=$F0) and (B<=$F4) then begin N:=3;Value:=B and 7;Minimum:=$10000;end
    else raise ESkiaCanvasError.CreateFmt(SSkiaInvalidUtf8Byte,[Start]);
    if I+N-1>Length(Text) then raise ESkiaCanvasError.CreateFmt(SSkiaTruncatedUtf8,[Start]);
    for J:=1 to N do begin
      B:=Byte(Text[I]);Inc(I);
      if B and $C0<>$80 then raise ESkiaCanvasError.CreateFmt(SSkiaInvalidUtf8Continuation,[I-1]);
      Value:=(Value shl 6) or (B and $3F);
    end;
    if (Value<Minimum) or (Value>$10FFFF) or ((Value>=$D800) and (Value<=$DFFF)) then
      raise ESkiaCanvasError.CreateFmt(SSkiaInvalidUtf8Scalar,[Start]);
    Result[Count].Value:=Value;Result[Count].ByteOffset:=Start;Result[Count].ByteLength:=I-Start;Inc(Count);
  end;
  SetLength(Result,Count);
end;
class function TSkiaUnicode.CodePoints(const Text:UnicodeString):TArray<Cardinal>;
var I,N:Integer;Value,Low:Cardinal;
begin
  SetLength(Result,Length(Text));I:=1;N:=0;
  while I<=Length(Text) do begin
    Value:=Ord(Text[I]);Inc(I);
    if (Value>=$D800) and (Value<=$DBFF) then begin
      if I>Length(Text) then raise ESkiaCanvasError.Create(SSkiaUnpairedUtf16Surrogate);
      Low:=Ord(Text[I]);Inc(I);
      if (Low<$DC00) or (Low>$DFFF) then raise ESkiaCanvasError.Create(SSkiaUnpairedUtf16Surrogate);
      Value:=$10000+((Value-$D800) shl 10)+(Low-$DC00);
    end else if (Value>=$DC00) and (Value<=$DFFF) then raise ESkiaCanvasError.Create(SSkiaUnpairedUtf16Surrogate);
    Result[N]:=Value;Inc(N);
  end;
  SetLength(Result,N);
end;
class function TSkiaUnicode.ScriptName(Value:Cardinal):string;
begin Result:=UnicodeScriptNames[UnicodeRangeValue(Value,UnicodeScriptRanges,UnicodeUnknownScript)];end;
class function TSkiaUnicode.BidiClass(Value:Cardinal):TSkiaBidiClass;
begin Result:=TSkiaBidiClass(UnicodeRangeValue(Value,UnicodeBidiRanges,0));end;
class function TSkiaUnicode.IsRightToLeft(Value:Cardinal):Boolean;
begin Result:=BidiClass(Value) in [bcR,bcAL];end;
class function TSkiaUnicode.RTLScriptSamples:TArray<Cardinal>;
var I:Integer;
begin SetLength(Result,Length(UnicodeRTLSamples));for I:=0 to High(Result) do Result[I]:=UnicodeRTLSamples[I];end;

class function TSkiaUnicode.IsDefaultIgnorable(Value:Cardinal):Boolean;
begin Result:=UnicodeRangeValue(Value,UnicodeIgnorableRanges,0)<>0;end;

class function TSkiaUnicode.ParagraphLevel(const Text:UnicodeString):Word;
var Value:Cardinal;Depth:Integer;Kind:TSkiaBidiClass;
begin
  Result:=0;Depth:=0;
  for Value in CodePoints(Text) do begin
    Kind:=BidiClass(Value);
    if Kind=bcB then Exit;
    if Kind in [bcLRI,bcRLI,bcFSI] then Inc(Depth)
    else if Kind=bcPDI then begin if Depth>0 then Dec(Depth);end
    else if Depth=0 then begin
      if Kind=bcL then Exit;
      if Kind in [bcR,bcAL] then Exit(1);
    end;
  end;
end;
