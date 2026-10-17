{ GDI may enumerate millions of geometric dashes or construct enormous round
  joins even when the destination clip is tiny. Bound device-space work before
  either ordinary replay or the renderer's native path capture. Logical CAD
  coordinates remain valid when their mapping reduces them to a modest size. }
function MetafilePenObject(Handle: THandle; Size: Integer; Data: Pointer): Integer; stdcall; external 'gdi32.dll' name 'GetObjectW';
function MetafileWindowExtent(DC: HDC; Extent: Pointer): BOOL; stdcall; external 'gdi32.dll' name 'GetWindowExtEx';
function MetafileViewportExtent(DC: HDC; Extent: Pointer): BOOL; stdcall; external 'gdi32.dll' name 'GetViewportExtEx';
function MetafileCurrentPoint(DC: HDC; Position: Pointer): BOOL; stdcall; external 'gdi32.dll' name 'GetCurrentPositionEx';

procedure TMetafileRecordPlayer.ValidateWork(DC: HDC; RecordData: PEnhMetaRecord);
const MaxDeviceSpan = 1048576.0; MaxDevicePenWidth = 65536.0;
var
  XF: TXForm;
  WindowSize, ViewSize: TSize;
  SX,SY,Scale,Width,LengthSum,DX,DY,SpanLimit: Double;
  PenData: TBytes;
  PenHandle: THandle;
  Size,I,Count,Offset,Stride: Integer;
  Previous,Next: TPoint;
  Kind: Cardinal;
  function IntAt(At:Integer):Integer;
  begin Result:=PInteger(NativeUInt(RecordData)+NativeUInt(At))^;end;
  procedure Segment(X,Y:Double);
  begin
    DX:=(X*XF.eM11+Y*XF.eM21)*SX;
    DY:=(X*XF.eM12+Y*XF.eM22)*SY;
    LengthSum:=LengthSum+Abs(DX)+Abs(DY);
    if IsNan(LengthSum) or IsInfinite(LengthSum) or (LengthSum>SpanLimit) then
      raise EReadError.Create('EMF native stroke work limit exceeded');
  end;
  procedure ValidateText(HeaderOffset,MinimumOffset:Integer);
  var TextCount,TextOffset,TextStride:Cardinal;J,At:Integer;
  begin
    TextCount:=PCardinal(NativeUInt(RecordData)+NativeUInt(HeaderOffset+8))^;
    TextOffset:=PCardinal(NativeUInt(RecordData)+NativeUInt(HeaderOffset+36))^;
    if (TextOffset=0) or (TextCount=0) then Exit;
    TextStride:=4;
    if PCardinal(NativeUInt(RecordData)+NativeUInt(HeaderOffset+16))^ and ETO_PDY<>0 then TextStride:=8;
    if (TextCount>65536) or (TextOffset<Cardinal(MinimumOffset)) or
      (TextOffset and 3<>0) or (TextOffset>RecordData.nSize) or
      (TextCount>(RecordData.nSize-TextOffset) div TextStride) then
      raise EReadError.Create('Invalid EMF native text advances');
    SpanLimit:=65536;
    for J:=0 to Integer(TextCount)-1 do
    begin
      At:=Integer(TextOffset+Cardinal(J)*TextStride);
      if TextStride=8 then Segment(IntAt(At),IntAt(At+4)) else Segment(IntAt(At),0);
    end;
  end;
begin
  if (DC=0) or (RecordData=nil) then Exit;
  Kind:=RecordData.iType;
  if not (Kind in [2..8,41..47,54..56,62..64,83,84,85..92,96,97]) then Exit;
  FillChar(XF,SizeOf(XF),0);XF.eM11:=1;XF.eM22:=1;
  GetWorldTransform(DC,XF);
  SX:=1;SY:=1;
  if MetafileWindowExtent(DC,@WindowSize) and MetafileViewportExtent(DC,@ViewSize) then
  begin
    if WindowSize.cx<>0 then SX:=ViewSize.cx/Double(WindowSize.cx);
    if WindowSize.cy<>0 then SY:=ViewSize.cy/Double(WindowSize.cy);
  end;
  Scale:=Max(Abs(XF.eM11*SX)+Abs(XF.eM12*SY),Abs(XF.eM21*SX)+Abs(XF.eM22*SY));
  SpanLimit:=MaxDeviceSpan;
  if Kind in [83,84] then
  begin
    LengthSum:=0;
    if RecordData.nSize>=76 then ValidateText(36,76);
    Exit;
  end;
  if Kind in [96,97] then
  begin
    if RecordData.nSize<40 then Exit;
    Count:=IntAt(36);
    if (Count<0) or (Cardinal(Count)>(RecordData.nSize-40) div 40) or (Count>65536) then
      raise EReadError.Create('Invalid EMF native text array');
    LengthSum:=0;
    for I:=0 to Count-1 do ValidateText(40+I*40,40+Count*40);
    Exit;
  end;
  PenHandle:=GetCurrentObject(DC,OBJ_PEN);
  Size:=MetafilePenObject(PenHandle,0,nil);
  if (Size>=16) and (Size<=1024*1024) then
  begin
    SetLength(PenData,Size);
    if MetafilePenObject(PenHandle,Size,@PenData[0])=Size then
    begin
      if PCardinal(@PenData[0])^ and $F=PS_NULL then Exit;
      Width:=PCardinal(@PenData[4])^;
      if Size=SizeOf(TLogPen) then Width:=Abs(Double(PInteger(@PenData[4])^));
      if PCardinal(@PenData[0])^ and $F in [PS_DASH,PS_DOT,PS_DASHDOT,PS_DASHDOTDOT,PS_USERSTYLE,PS_ALTERNATE] then
        SpanLimit:=Min(SpanLimit,8192*Max(1.0,Width*Scale));
      if IsNan(Scale) or IsInfinite(Scale) or (Width*Scale>MaxDevicePenWidth) then
        raise EReadError.Create('EMF native pen work limit exceeded');
    end;
  end;
  LengthSum:=0;
  if (Kind=54) and (RecordData.nSize>=16) then
  begin
    if MetafileCurrentPoint(DC,@Previous) then
      Segment(Double(IntAt(8))-Previous.X,Double(IntAt(12))-Previous.Y);
  end
  else if (Kind in [42..47,55]) and (RecordData.nSize>=24) then
  begin
    Segment(2*(Double(IntAt(16))-IntAt(8)),0);
    Segment(0,2*(Double(IntAt(20))-IntAt(12)));
  end
  else if (Kind in [2..6,56,85..89,92]) and (RecordData.nSize>=28) then
  begin
    Count:=IntAt(24);Offset:=28;Stride:=8;
    if Kind>=85 then Stride:=4;
    if (Count<0) or (Cardinal(Count)>(RecordData.nSize-28) div Cardinal(Stride)) then
      raise EReadError.CreateFmt('Invalid EMF native point array: type %d count %d size %d',[Kind,Count,RecordData.nSize]);
    if Count>1048576 then raise EReadError.Create('EMF native point work limit exceeded');
    Previous:=Point(0,0);
    if Kind in [5,6,56,88,89,92] then MetafileCurrentPoint(DC,@Previous);
    for I:=0 to Count-1 do
    begin
      if Stride=8 then Next:=Point(IntAt(Offset),IntAt(Offset+4))
      else begin
        Next.X:=PSmallInt(NativeUInt(RecordData)+NativeUInt(Offset))^;
        Next.Y:=PSmallInt(NativeUInt(RecordData)+NativeUInt(Offset+2))^;
      end;
      if (I>0) or (Kind in [5,6,56,88,89,92]) then
        Segment(Double(Next.X)-Previous.X,Double(Next.Y)-Previous.Y);
      Previous:=Next;Inc(Offset,Stride);
    end;
  end;
end;

{ Compatibility replay for records whose content is representable but rejected by GDI. }
function MetafileNativePlay(DC: HDC; Table, Rec: Pointer; Count: UINT): BOOL; stdcall; external 'gdi32.dll' name 'PlayEnhMetaFileRecord';
function MetafileNativePath(DC: HDC; Points, Kinds: Pointer; Count: Integer): Integer; stdcall; external 'gdi32.dll' name 'GetPath';
function MetafileNativeExtPen(Style, Width: DWORD; Brush: Pointer; Count: DWORD; Entries: Pointer): HPEN; stdcall; external 'gdi32.dll' name 'ExtCreatePen';
function MetafileNativeBitmap(Width, Height: Integer; Planes, Bpp: UINT; Bits: Pointer): HBITMAP; stdcall; external 'gdi32.dll' name 'CreateBitmap';

function NormalizeMetafileDIB(var Info: TBytes; const Bits: TBytes; Usage: Cardinal): TMetafileRecordRecovery;
var
  Header: PBitmapInfoHeader;
  Colors, Available, UnitSize: Cardinal;
  Stride, Required: UInt64;
  X, Y, Height, Value, PixelIndex: Integer;
  Valid: Boolean;
  RedMask, GreenMask, BlueMask: Cardinal;
begin
  Result := mrrNone;
  if Length(Info) < 40 then
    Exit;
  Info := Copy(Info, 0, Length(Info));
  Header := PBitmapInfoHeader(@Info[0]);
  { A known producer writes $20000000 instead of the 40-byte BITMAPINFOHEADER.
    Require the remaining fields and the complete scanline buffer to agree. }
  if (Header.biSize = $20000000) and (Header.biPlanes = 1) and (Header.biWidth > 0) and (Header.biHeight <> 0) and (Header.biHeight <> Low(Integer)) and (Header.biBitCount in [1, 4, 8, 16, 24, 32])
    and (Header.biCompression in [BI_RGB, BI_BITFIELDS]) then
  begin
    if Header.biCompression = BI_BITFIELDS then
    begin
      if (Length(Info) < 52) or not(Header.biBitCount in [16, 32]) then
        Exit;
      RedMask := PCardinal(@Info[40])^;
      GreenMask := PCardinal(@Info[44])^;
      BlueMask := PCardinal(@Info[48])^;
      if (RedMask = 0) or (GreenMask = 0) or (BlueMask = 0) or ((RedMask and GreenMask) <> 0) or ((RedMask and BlueMask) <> 0) or ((GreenMask and BlueMask) <> 0) then
        Exit;
    end;
    Stride := ((UInt64(Header.biWidth) * Header.biBitCount + 31) div 32) * 4;
    Required := Stride * UInt64(Abs(Int64(Header.biHeight)));
    if Required <= UInt64(Length(Bits)) then
    begin
      Header.biSize := 40;
      Result := mrrDibHeader;
    end;
  end;
  if (Header.biSize < 40) or (Header.biSize > Cardinal(Length(Info))) or (Header.biPlanes <> 1) or (Header.biWidth <= 0) or (Header.biHeight = 0) then
    Exit;
  if (Header.biBitCount in [1, 4, 8]) and (Usage <> 2) and (Header.biCompression = BI_RGB) then
  begin
    Colors := Header.biClrUsed;
    if Colors = 0 then
      Colors := Cardinal(1) shl Header.biBitCount;
    UnitSize := 4;
    if Usage = 1 then
      UnitSize := 2;
    Available := (Cardinal(Length(Info)) - Header.biSize) div UnitSize;
    { A short, explicit palette supplies its own cardinality. Never invent colors. }
    if (Available > 0) and (Available < Colors) then
    begin
      Stride := ((UInt64(Header.biWidth) * Header.biBitCount + 31) div 32) * 4;
      Required := Stride * UInt64(Abs(Int64(Header.biHeight)));
      if Required > UInt64(Length(Bits)) then
        Exit;
      if UInt64(Header.biWidth) * UInt64(Abs(Int64(Header.biHeight))) > 32 * 1024 * 1024 then
        Exit;
      Height := Integer(Abs(Int64(Header.biHeight)));
      Valid := True;
      for Y := 0 to Height - 1 do
      begin
        for X := 0 to Header.biWidth - 1 do
        begin
          Value := Bits[NativeUInt(Y) * NativeUInt(Stride) + NativeUInt(X) * Header.biBitCount div 8];
          PixelIndex := (Value shr (8 - Header.biBitCount - (X mod (8 div Header.biBitCount)) * Header.biBitCount)) and ((1 shl Header.biBitCount) - 1);
          if Cardinal(PixelIndex) >= Available then
          begin
            Valid := False;
            Break;
          end;
        end;
        if not Valid then
          Break;
      end;
      if Valid then
      begin
        Header.biClrUsed := Available;
        Result := mrrPalette;
      end;
    end;
  end;
end;

function TMetafileRecordPlayer.Play(DC: HDC; Table: Pointer; RecordData: PEnhMetaRecord; Objects: Integer): Boolean;
var
  CopyRecord, Info, Bits, DecodedInfo, DecodedBits, MonoBits: TBytes;
  Rec: PEnhMetaRecord;
  Kind, OffInfo, SizeInfo, OffBits, SizeBits, Usage, FixedSize, Style, Count, Index: Cardinal;
  Width, Height, SourceX, SourceY, SourceW, SourceH, X, Y, SrcStride, DstStride, PathBefore: Integer;
  DIB: PBitmapInfoHeader;
  Recovery: TMetafileRecordRecovery;
  Brush: TLogBrush;
  Pen: HPEN;
  Bitmap: HBITMAP;
  Entries: Pointer;
  Handles: ^THandle;
  Compressed: Boolean;
  function DWordAt(Offset: Cardinal): Cardinal;
  begin
    Result := PCardinal(NativeUInt(RecordData) + Offset)^;
  end;
  procedure SetDWord(Offset, Value: Cardinal);
  begin
    PCardinal(@CopyRecord[Offset])^ := Value;
  end;
  function Extract(Offset, Size: Cardinal; out Data: TBytes): Boolean;
  begin
    Result := (Size <= 128 * 1024 * 1024) and (Offset <= RecordData.nSize) and (Size <= RecordData.nSize - Offset);
    if Result then
    begin
      SetLength(Data, Size);
      if Size > 0 then
        Move(PByte(NativeUInt(RecordData) + Offset)^, Data[0], Size);
    end;
  end;
  function RebuildDIBRecord: Boolean;
  begin
    Result := False;
    if (UInt64(FixedSize) + UInt64(Length(Info)) + UInt64(Length(Bits))) > High(Integer) - 3 then
      Exit;
    SetLength(CopyRecord, (FixedSize + Cardinal(Length(Info)) + Cardinal(Length(Bits)) + 3) and not Cardinal(3));
    Move(RecordData^, CopyRecord[0], FixedSize);
    SetDWord(4, Length(CopyRecord));
    if Length(Info) > 0 then
      Move(Info[0], CopyRecord[FixedSize], Length(Info));
    if Length(Bits) > 0 then
      Move(Bits[0], CopyRecord[FixedSize + Cardinal(Length(Info))], Length(Bits));
    if Kind = 95 then
    begin
      SetDWord(12, FixedSize);
      SetDWord(16, Length(Info));
      SetDWord(20, FixedSize + Cardinal(Length(Info)));
      SetDWord(24, Length(Bits));
    end
    else if Kind = 81 then
    begin
      SetDWord(48, FixedSize);
      SetDWord(52, Length(Info));
      SetDWord(56, FixedSize + Cardinal(Length(Info)));
      SetDWord(60, Length(Bits));
    end
    else
    begin
      SetDWord(84, FixedSize);
      SetDWord(88, Length(Info));
      SetDWord(92, FixedSize + Cardinal(Length(Info)));
      SetDWord(96, Length(Bits));
    end;
    Result := True;
  end;
  function AcceptDecodedDIB: Boolean;
  var
    Decoded: PBitmapInfoHeader;
    W, H, Stride, Row: Integer;
    Temporary: TBytes;
  begin
    Result := False;
    if Length(DecodedInfo) < 40 then
      Exit;
    Decoded := PBitmapInfoHeader(@DecodedInfo[0]);
    if (Decoded.biSize <> 40) or (Decoded.biPlanes <> 1) or (Decoded.biBitCount <> 32) or (Decoded.biCompression <> BI_RGB) or (Decoded.biWidth <> DIB.biWidth) or (Decoded.biHeight >= 0) or
      (Abs(Int64(Decoded.biHeight)) <> Abs(Int64(DIB.biHeight))) then
      Exit;
    W := Decoded.biWidth;
    if (W <= 0) or (W > High(Integer) div 4) or (Abs(Int64(Decoded.biHeight)) > High(Integer)) or (UInt64(W) * UInt64(Abs(Int64(Decoded.biHeight))) * 4 > UInt64(Length(DecodedBits))) then
      Exit;
    H := Integer(Abs(Int64(Decoded.biHeight)));
    Stride := W * 4;
    if DIB.biHeight > 0 then
    begin
      { StretchDIBits uses a lower-left source origin for bottom-up DIBs.
        Preserve the original sign, not just the displayed pixel colors. }
      DecodedInfo := Copy(DecodedInfo, 0, Length(DecodedInfo));
      DecodedBits := Copy(DecodedBits, 0, Length(DecodedBits));
      PBitmapInfoHeader(@DecodedInfo[0]).biHeight := H;
      SetLength(Temporary, Stride);
      for Row := 0 to H div 2 - 1 do
      begin
        Move(DecodedBits[Row * Stride], Temporary[0], Stride);
        Move(DecodedBits[(H - 1 - Row) * Stride], DecodedBits[Row * Stride], Stride);
        Move(Temporary[0], DecodedBits[(H - 1 - Row) * Stride], Stride);
      end;
    end;
    Result := True;
  end;

begin
  FRecovery := mrrNone;
  FError := 0;
  Result := False;
  if (DC = 0) or (RecordData = nil) or (Objects < 0) then
  begin
    FError := ERROR_INVALID_PARAMETER;
    Exit;
  end;
  if (RecordData.nSize > 128 * 1024 * 1024) or
    (RecordData.nSize < MinimumMetafileRecordSize(RecordData.iType)) then
  begin
    FError := ERROR_INVALID_DATA;
    Exit;
  end;
  ValidateWork(DC,RecordData);
  Kind := RecordData.iType;
  PathBefore := 0;
  Count := 0;
  if Kind = 1 then
    FPathOpen := False;
  if Kind in [62, 63, 64] then
    PathBefore := MetafileNativePath(DC, nil, nil, 0);
  SetLastError(0);
  Result := MetafileNativePlay(DC, Table, RecordData, Objects);
  if Result then
  begin
    if Kind = 59 then
      FPathOpen := True;
    if Kind in [60, 68] then
      FPathOpen := False;
    Exit;
  end;
  FError := GetLastError;
  Kind := RecordData.iType;
  if FError = 0 then
    FError := ERROR_INVALID_DATA;
  { There is no geometry to paint when a producer calls a path operation
    after an immediate drawing command, outside any path bracket. }
  if (Kind in [62, 63, 64]) and (PathBefore < 0) and not FPathOpen then
  begin
    FRecovery := mrrEmptyPath;
    FError := 0;
    Exit(True);
  end;
  if not(Kind in [76, 77, 81, 95]) then
    Exit;
  if Kind = 95 then
  begin
    if RecordData.nSize < 52 then
      Exit;
    OffInfo := DWordAt(12);
    SizeInfo := DWordAt(16);
    OffBits := DWordAt(20);
    SizeBits := DWordAt(24);
    Usage := DWordAt(40) and $FFFF;
    Count := DWordAt(48);
    if Count > (RecordData.nSize - 52) div 4 then
      Exit;
    FixedSize := 52 + Count * 4;
  end
  else if Kind = 81 then
  begin
    if RecordData.nSize < 80 then
      Exit;
    OffInfo := DWordAt(48);
    SizeInfo := DWordAt(52);
    OffBits := DWordAt(56);
    SizeBits := DWordAt(60);
    Usage := DWordAt(64);
    FixedSize := 80;
  end
  else
  begin
    FixedSize := 100;
    if Kind = 77 then
      FixedSize := 108;
    if RecordData.nSize < FixedSize then
      Exit;
    OffInfo := DWordAt(84);
    SizeInfo := DWordAt(88);
    OffBits := DWordAt(92);
    SizeBits := DWordAt(96);
    Usage := DWordAt(80);
  end;
  if not Extract(OffInfo, SizeInfo, Info) or not Extract(OffBits, SizeBits, Bits) then
    Exit;
  Recovery := NormalizeMetafileDIB(Info, Bits, Usage);
  if Kind = 95 then
  begin
    if (Table = nil) or (Objects <= 0) then
      Exit;
    Index := DWordAt(8);
    if (Table = nil) or (Index >= Cardinal(Objects)) then
      Exit;
    Handles := Table;
    if Handles[Index] <> 0 then
      Exit; { Reject duplicate live handles instead of leaking the original object. }
    FillChar(Brush, SizeOf(Brush), 0);
    Brush.lbStyle := DWordAt(36);
    Brush.lbColor := DWordAt(40);
    Brush.lbHatch := DWordAt(44);
    Style := DWordAt(28);
    Entries := nil;
    { EMF producers sometimes serialize unused style entries for a solid pen. }
    if Style and $F = PS_USERSTYLE then
    begin
      if (Count = 0) or (Count > 16) then
        Exit;
      Entries := Pointer(NativeUInt(RecordData) + 52);
    end
    else
      Count := 0;
    Bitmap := 0;
    try
      if Brush.lbStyle in [3, 5, 6, 7, 8, 9] then
      begin
        if Length(Info) < 40 then
          Exit;
        DIB := PBitmapInfoHeader(@Info[0]);
        if (DIB.biSize <> 40) or (DIB.biWidth <= 0) or (DIB.biHeight = 0) or (DIB.biHeight = Low(Integer)) then
          Exit;
        if (Brush.lbStyle = 9) or ((DIB.biBitCount = 1) and (Usage = 2)) then
        begin
          { A monochrome DDB preserves dynamic text/background colors. }
          if (DIB.biBitCount <> 1) or (DIB.biCompression <> BI_RGB) then
            Exit;
          Width := DIB.biWidth;
          Height := Abs(DIB.biHeight);
          SrcStride := Integer(((UInt64(Width) + 31) div 32) * 4);
          DstStride := Integer(((UInt64(Width) + 15) div 16) * 2);
          if (UInt64(SrcStride) * Cardinal(Height) > UInt64(Length(Bits))) or (UInt64(DstStride) * Cardinal(Height) > High(Integer)) then
            Exit;
          SetLength(MonoBits, DstStride * Height);
          for Y := 0 to Height - 1 do
          begin
            X := Y;
            if DIB.biHeight > 0 then
              X := Height - 1 - Y;
            Move(Bits[X * SrcStride], MonoBits[Y * DstStride], DstStride);
          end;
          Bitmap := MetafileNativeBitmap(Width, Height, 1, 1, Pointer(MonoBits));
          if Bitmap = 0 then
            Exit;
          Brush.lbStyle := BS_PATTERN;
          Brush.lbHatch := {$IFDEF FPC}NativeUInt{$ELSE}NativeInt{$ENDIF}(Bitmap);
          Brush.lbColor := 0;
        end
        else
        begin
          { Packed DIB aliases share the same pixels; BS_DIBPATTERNPT is the
            supported pointer form expected by ExtCreatePen. }
          if Length(Info) > High(Integer) - Length(Bits) then
            Exit;
          SetLength(DecodedBits, Length(Info) + Length(Bits));
          Move(Info[0], DecodedBits[0], Length(Info));
          if Length(Bits) > 0 then
            Move(Bits[0], DecodedBits[Length(Info)], Length(Bits));
          Brush.lbStyle := BS_DIBPATTERNPT;
          Brush.lbHatch := {$IFDEF FPC}NativeUInt{$ELSE}NativeInt{$ENDIF}(Pointer(DecodedBits));
          Brush.lbColor := Usage;
        end;
      end;
      Pen := MetafileNativeExtPen(Style, DWordAt(32), @Brush, Count, Entries);
      if Pen = 0 then
      begin
        FError := GetLastError;
        if FError = 0 then
          FError := ERROR_INVALID_DATA;
        Exit;
      end;
      Handles := Table;
      Handles[Index] := THandle(Pen);
      FRecovery := mrrPatternPen;
      FError := 0;
      Result := True;
    finally
      if Bitmap <> 0 then
        DeleteObject(Bitmap);
    end;
    Exit;
  end;
  if Length(Info) < 40 then
    Exit;
  DIB := PBitmapInfoHeader(@Info[0]);
  Compressed := DIB.biCompression in [4, 5];
  if Compressed then
  begin
    if not Assigned(FDecoder) or not FDecoder(Bits, DecodedInfo, DecodedBits) then
      Exit;
    if not AcceptDecodedDIB then
      Exit;
    Info := DecodedInfo;
    Bits := DecodedBits;
    Recovery := mrrCompressedDib;
    Usage := 0;
  end
  else if (Recovery = mrrPalette) and (Usage = 0) and Assigned(FDecoder) then
  begin
    { Normalize indexed transfers to BGRA as well. GDI selects a different
      rotated blit rasterizer for indexed DIBs; using canonical pixels keeps
      clipping and sampling consistent with other decoded images. }
    if UInt64(Length(Info)) + UInt64(Length(Bits)) + 14 > High(Integer) then
      Exit;
    SetLength(DecodedBits, 14 + Length(Info) + Length(Bits));
    PWord(@DecodedBits[0])^ := $4D42;
    PCardinal(@DecodedBits[2])^ := Length(DecodedBits);
    PCardinal(@DecodedBits[10])^ := 14 + Length(Info);
    Move(Info[0], DecodedBits[14], Length(Info));
    if Length(Bits) > 0 then
      Move(Bits[0], DecodedBits[14 + Length(Info)], Length(Bits));
    CopyRecord := DecodedBits;
    if not FDecoder(CopyRecord, DecodedInfo, DecodedBits) then
      Exit;
    if not AcceptDecodedDIB then
      Exit;
    Info := DecodedInfo;
    Bits := DecodedBits;
  end;
  if (Recovery <> mrrNone) and RebuildDIBRecord then
  begin
    if Kind = 81 then
      SetDWord(64, Usage)
    else
      SetDWord(80, Usage);
    Rec := PEnhMetaRecord(@CopyRecord[0]);
    Result := MetafileNativePlay(DC, Table, Rec, Objects);
    if Result then
    begin
      FRecovery := Recovery;
      FError := 0;
      Exit;
    end;
    FError := GetLastError;
    if FError = 0 then
      FError := ERROR_INVALID_DATA;
  end;
  { Completely clipped source rectangles contain no source pixels. Preserve
    this as a successful empty transfer rather than treating it as lost data. }
  if Kind = 81 then
  begin
    DIB := PBitmapInfoHeader(@Info[0]);
    SourceX := Integer(DWordAt(32));
    SourceY := Integer(DWordAt(36));
    SourceW := Integer(DWordAt(40));
    SourceH := Integer(DWordAt(44));
    if (DWordAt(68) = SRCCOPY) and (SourceW >= 0) and (SourceH >= 0) and ((Int64(SourceX) + SourceW <= 0) or (Int64(SourceY) + SourceH <= 0) or (SourceX >= DIB.biWidth) or
      (Int64(SourceY) >= Abs(Int64(DIB.biHeight)))) then
    begin
      Result := True;
      FRecovery := mrrOutsideSource;
      FError := 0;
    end;
  end;
end;
