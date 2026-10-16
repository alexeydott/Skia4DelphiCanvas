{ Compatibility replay for records whose content is representable but rejected by GDI. }
function MetafileNativePlay(DC:HDC;Table,Rec:Pointer;Count:UINT):BOOL;stdcall;
  external 'gdi32.dll' name 'PlayEnhMetaFileRecord';
function MetafileNativePath(DC:HDC;Points,Kinds:Pointer;Count:Integer):Integer;stdcall;
  external 'gdi32.dll' name 'GetPath';
function MetafileNativeExtPen(Style,Width:DWORD;Brush:Pointer;Count:DWORD;Entries:Pointer):HPEN;stdcall;
  external 'gdi32.dll' name 'ExtCreatePen';
function MetafileNativeBitmap(Width,Height:Integer;Planes,Bpp:UINT;Bits:Pointer):HBITMAP;stdcall;
  external 'gdi32.dll' name 'CreateBitmap';

function NormalizeMetafileDIB(var Info:TBytes;const Bits:TBytes;Usage:Cardinal):TMetafileRecordRecovery;
var Header:PBitmapInfoHeader;Colors,Available,UnitSize:Cardinal;Stride,Required:UInt64;
  X,Y,Height,Value,PixelIndex:Integer;Valid:Boolean;RedMask,GreenMask,BlueMask:Cardinal;
begin
  Result:=mrrNone;
  if Length(Info)<40 then Exit;
  Info:=Copy(Info,0,Length(Info));
  Header:=PBitmapInfoHeader(@Info[0]);
  { A known producer writes $20000000 instead of the 40-byte BITMAPINFOHEADER.
    Require the remaining fields and the complete scanline buffer to agree. }
  if (Header.biSize=$20000000) and (Header.biPlanes=1) and (Header.biWidth>0) and
    (Header.biHeight<>0) and (Header.biHeight<>Low(Integer)) and
    (Header.biBitCount in [1,4,8,16,24,32]) and (Header.biCompression in [BI_RGB,BI_BITFIELDS]) then begin
    if Header.biCompression=BI_BITFIELDS then begin
      if (Length(Info)<52) or not (Header.biBitCount in [16,32]) then Exit;
      RedMask:=PCardinal(@Info[40])^;GreenMask:=PCardinal(@Info[44])^;BlueMask:=PCardinal(@Info[48])^;
      if (RedMask=0) or (GreenMask=0) or (BlueMask=0) or
        ((RedMask and GreenMask)<>0) or ((RedMask and BlueMask)<>0) or ((GreenMask and BlueMask)<>0) then Exit;
    end;
    Stride:=((UInt64(Header.biWidth)*Header.biBitCount+31) div 32)*4;
    Required:=Stride*UInt64(Abs(Int64(Header.biHeight)));
    if Required<=UInt64(Length(Bits)) then begin
      Header.biSize:=40;Result:=mrrDibHeader;
    end;
  end;
  if (Header.biSize<40) or (Header.biSize>Cardinal(Length(Info))) or
    (Header.biPlanes<>1) or (Header.biWidth<=0) or (Header.biHeight=0) then Exit;
  if (Header.biBitCount in [1,4,8]) and (Usage<>2) and (Header.biCompression=BI_RGB) then begin
    Colors:=Header.biClrUsed;if Colors=0 then Colors:=Cardinal(1) shl Header.biBitCount;
    UnitSize:=4;if Usage=1 then UnitSize:=2;
    Available:=(Cardinal(Length(Info))-Header.biSize) div UnitSize;
    { A short, explicit palette supplies its own cardinality. Never invent colors. }
    if (Available>0) and (Available<Colors) then begin
      Stride:=((UInt64(Header.biWidth)*Header.biBitCount+31) div 32)*4;
      Required:=Stride*UInt64(Abs(Int64(Header.biHeight)));
      if Required>UInt64(Length(Bits)) then Exit;
      Height:=Integer(Abs(Int64(Header.biHeight)));Valid:=True;
      for Y:=0 to Height-1 do begin
        for X:=0 to Header.biWidth-1 do begin
          Value:=Bits[NativeUInt(Y)*NativeUInt(Stride)+NativeUInt(X)*Header.biBitCount div 8];
          PixelIndex:=(Value shr (8-Header.biBitCount-(X mod (8 div Header.biBitCount))*Header.biBitCount)) and
            ((1 shl Header.biBitCount)-1);
          if Cardinal(PixelIndex)>=Available then begin Valid:=False;Break;end;
        end;
        if not Valid then Break;
      end;
      if Valid then begin Header.biClrUsed:=Available;Result:=mrrPalette;end;
    end;
  end;
end;

function TMetafileRecordPlayer.Play(DC:HDC;Table:Pointer;RecordData:PEnhMetaRecord;Objects:Integer):Boolean;
var CopyRecord,Info,Bits,DecodedInfo,DecodedBits,MonoBits:TBytes;Rec:PEnhMetaRecord;
  Kind,OffInfo,SizeInfo,OffBits,SizeBits,Usage,FixedSize,Style,Count,Index:Cardinal;
  Width,Height,SourceX,SourceY,SourceW,SourceH,X,Y,SrcStride,DstStride,PathBefore:Integer;
  DIB:PBitmapInfoHeader;Recovery:TMetafileRecordRecovery;Brush:TLogBrush;Pen:HPEN;Bitmap:HBITMAP;
  Entries:Pointer;Handles:^THandle;Compressed:Boolean;
  function DWordAt(Offset:Cardinal):Cardinal;
  begin Result:=PCardinal(NativeUInt(RecordData)+Offset)^;end;
  procedure SetDWord(Offset,Value:Cardinal);
  begin PCardinal(@CopyRecord[Offset])^:=Value;end;
  function Extract(Offset,Size:Cardinal;out Data:TBytes):Boolean;
  begin
    Result:=(Offset<=RecordData.nSize) and (Size<=RecordData.nSize-Offset);
    if Result then begin SetLength(Data,Size);if Size>0 then Move(PByte(NativeUInt(RecordData)+Offset)^,Data[0],Size);end;
  end;
  function RebuildDIBRecord:Boolean;
  begin
    Result:=False;
    if (UInt64(FixedSize)+UInt64(Length(Info))+UInt64(Length(Bits)))>High(Integer)-3 then Exit;
    SetLength(CopyRecord,(FixedSize+Cardinal(Length(Info))+Cardinal(Length(Bits))+3) and not Cardinal(3));
    Move(RecordData^,CopyRecord[0],FixedSize);
    SetDWord(4,Length(CopyRecord));
    if Length(Info)>0 then Move(Info[0],CopyRecord[FixedSize],Length(Info));
    if Length(Bits)>0 then Move(Bits[0],CopyRecord[FixedSize+Cardinal(Length(Info))],Length(Bits));
    if Kind=95 then begin
      SetDWord(12,FixedSize);SetDWord(16,Length(Info));
      SetDWord(20,FixedSize+Cardinal(Length(Info)));SetDWord(24,Length(Bits));
    end else if Kind=81 then begin
      SetDWord(48,FixedSize);SetDWord(52,Length(Info));
      SetDWord(56,FixedSize+Cardinal(Length(Info)));SetDWord(60,Length(Bits));
    end else begin
      SetDWord(84,FixedSize);SetDWord(88,Length(Info));
      SetDWord(92,FixedSize+Cardinal(Length(Info)));SetDWord(96,Length(Bits));
    end;
    Result:=True;
  end;
  function AcceptDecodedDIB:Boolean;
  var Decoded:PBitmapInfoHeader;W,H,Stride,Row:Integer;Temporary:TBytes;
  begin
    Result:=False;
    if Length(DecodedInfo)<40 then Exit;
    Decoded:=PBitmapInfoHeader(@DecodedInfo[0]);
    if (Decoded.biSize<>40) or (Decoded.biPlanes<>1) or (Decoded.biBitCount<>32) or
      (Decoded.biCompression<>BI_RGB) or (Decoded.biWidth<>DIB.biWidth) or
      (Decoded.biHeight>=0) or (Abs(Int64(Decoded.biHeight))<>Abs(Int64(DIB.biHeight))) then Exit;
    W:=Decoded.biWidth;
    if (W<=0) or (UInt64(W)*UInt64(Abs(Int64(Decoded.biHeight)))*4>UInt64(Length(DecodedBits))) then Exit;
    H:=Integer(Abs(Int64(Decoded.biHeight)));Stride:=W*4;
    if DIB.biHeight>0 then begin
      { StretchDIBits uses a lower-left source origin for bottom-up DIBs.
        Preserve the original sign, not just the displayed pixel colors. }
      DecodedInfo:=Copy(DecodedInfo,0,Length(DecodedInfo));
      DecodedBits:=Copy(DecodedBits,0,Length(DecodedBits));
      PBitmapInfoHeader(@DecodedInfo[0]).biHeight:=H;
      SetLength(Temporary,Stride);
      for Row:=0 to H div 2-1 do begin
        Move(DecodedBits[Row*Stride],Temporary[0],Stride);
        Move(DecodedBits[(H-1-Row)*Stride],DecodedBits[Row*Stride],Stride);
        Move(Temporary[0],DecodedBits[(H-1-Row)*Stride],Stride);
      end;
    end;
    Result:=True;
  end;
begin
  FRecovery:=mrrNone;FError:=0;
  Result:=False;
  if (DC=0) or (RecordData=nil) or (Objects<0) then begin FError:=ERROR_INVALID_PARAMETER;Exit;end;
  if RecordData.nSize<MinimumMetafileRecordSize(RecordData.iType) then begin FError:=ERROR_INVALID_DATA;Exit;end;
  Kind:=RecordData.iType;PathBefore:=0;Count:=0;
  if Kind=1 then FPathOpen:=False;
  if Kind in [62,63,64] then PathBefore:=MetafileNativePath(DC,nil,nil,0);
  SetLastError(0);Result:=MetafileNativePlay(DC,Table,RecordData,Objects);
  if Result then begin
    if Kind=59 then FPathOpen:=True;
    if Kind in [60,68] then FPathOpen:=False;
    Exit;
  end;
  FError:=GetLastError;Kind:=RecordData.iType;
  if FError=0 then FError:=ERROR_INVALID_DATA;
  { There is no geometry to paint when a producer calls a path operation
    after an immediate drawing command, outside any path bracket. }
  if (Kind in [62,63,64]) and (PathBefore<0) and not FPathOpen then begin
    FRecovery:=mrrEmptyPath;FError:=0;Exit(True);
  end;
  if not (Kind in [76,77,81,95]) then Exit;
  if Kind=95 then begin
    if RecordData.nSize<52 then Exit;
    OffInfo:=DWordAt(12);SizeInfo:=DWordAt(16);OffBits:=DWordAt(20);SizeBits:=DWordAt(24);
    Usage:=DWordAt(40) and $FFFF;Count:=DWordAt(48);
    if Count>(RecordData.nSize-52) div 4 then Exit;
    FixedSize:=52+Count*4;
  end else if Kind=81 then begin
    if RecordData.nSize<80 then Exit;
    OffInfo:=DWordAt(48);SizeInfo:=DWordAt(52);OffBits:=DWordAt(56);SizeBits:=DWordAt(60);
    Usage:=DWordAt(64);FixedSize:=80;
  end else begin
    FixedSize:=100;if Kind=77 then FixedSize:=108;
    if RecordData.nSize<FixedSize then Exit;
    OffInfo:=DWordAt(84);SizeInfo:=DWordAt(88);OffBits:=DWordAt(92);SizeBits:=DWordAt(96);Usage:=DWordAt(80);
  end;
  if not Extract(OffInfo,SizeInfo,Info) or not Extract(OffBits,SizeBits,Bits) then Exit;
  Recovery:=NormalizeMetafileDIB(Info,Bits,Usage);
  if Kind=95 then begin
    if (Table=nil) or (Objects<=0) then Exit;
    Index:=DWordAt(8);if Index>=Cardinal(Objects) then Exit;
    FillChar(Brush,SizeOf(Brush),0);Brush.lbStyle:=DWordAt(36);Brush.lbColor:=DWordAt(40);Brush.lbHatch:=DWordAt(44);
    Style:=DWordAt(28);Entries:=nil;
    { EMF producers sometimes serialize unused style entries for a solid pen. }
    if Style and $F=PS_USERSTYLE then begin
      if (Count=0) or (Count>16) then Exit;
      Entries:=Pointer(NativeUInt(RecordData)+52);
    end else Count:=0;
    Bitmap:=0;
    try
      if Brush.lbStyle in [3,5,6,7,8,9] then begin
        if Length(Info)<40 then Exit;
        DIB:=PBitmapInfoHeader(@Info[0]);
        if (DIB.biSize<>40) or (DIB.biWidth<=0) or (DIB.biHeight=0) or
          (DIB.biHeight=Low(Integer)) then Exit;
        if (Brush.lbStyle=9) or ((DIB.biBitCount=1) and (Usage=2)) then begin
          { A monochrome DDB preserves dynamic text/background colors. }
          if (DIB.biBitCount<>1) or (DIB.biCompression<>BI_RGB) then Exit;
          Width:=DIB.biWidth;Height:=Abs(DIB.biHeight);
          SrcStride:=Integer(((UInt64(Width)+31) div 32)*4);
          DstStride:=Integer(((UInt64(Width)+15) div 16)*2);
          if (UInt64(SrcStride)*Cardinal(Height)>UInt64(Length(Bits))) or
            (UInt64(DstStride)*Cardinal(Height)>High(Integer)) then Exit;
          SetLength(MonoBits,DstStride*Height);
          for Y:=0 to Height-1 do begin
            X:=Y;if DIB.biHeight>0 then X:=Height-1-Y;
            Move(Bits[X*SrcStride],MonoBits[Y*DstStride],DstStride);
          end;
          Bitmap:=MetafileNativeBitmap(Width,Height,1,1,Pointer(MonoBits));
          if Bitmap=0 then Exit;
          Brush.lbStyle:=BS_PATTERN;Brush.lbHatch:=NativeUInt(Bitmap);Brush.lbColor:=0;
        end else begin
          { Packed DIB aliases share the same pixels; BS_DIBPATTERNPT is the
            supported pointer form expected by ExtCreatePen. }
          SetLength(DecodedBits,Length(Info)+Length(Bits));
          Move(Info[0],DecodedBits[0],Length(Info));
          if Length(Bits)>0 then Move(Bits[0],DecodedBits[Length(Info)],Length(Bits));
          Brush.lbStyle:=BS_DIBPATTERNPT;Brush.lbHatch:=NativeUInt(Pointer(DecodedBits));Brush.lbColor:=Usage;
        end;
      end;
      Pen:=MetafileNativeExtPen(Style,DWordAt(32),@Brush,Count,Entries);
      if Pen=0 then begin FError:=GetLastError;if FError=0 then FError:=ERROR_INVALID_DATA;Exit;end;
      Handles:=Table;Handles[Index]:=THandle(Pen);
      FRecovery:=mrrPatternPen;FError:=0;Result:=True;
    finally if Bitmap<>0 then DeleteObject(Bitmap);end;
    Exit;
  end;
  if Length(Info)<40 then Exit;
  DIB:=PBitmapInfoHeader(@Info[0]);
  Compressed:=DIB.biCompression in [4,5];
  if Compressed then begin
    if not Assigned(FDecoder) or not FDecoder(Bits,DecodedInfo,DecodedBits) then Exit;
    if not AcceptDecodedDIB then Exit;
    Info:=DecodedInfo;Bits:=DecodedBits;Recovery:=mrrCompressedDib;Usage:=0;
  end else if (Recovery=mrrPalette) and (Usage=0) and Assigned(FDecoder) then begin
    { Normalize indexed transfers to BGRA as well. GDI selects a different
      rotated blit rasterizer for indexed DIBs; using canonical pixels keeps
      clipping and sampling consistent with other decoded images. }
    if UInt64(Length(Info))+UInt64(Length(Bits))+14>High(Integer) then Exit;
    SetLength(DecodedBits,14+Length(Info)+Length(Bits));
    PWord(@DecodedBits[0])^:=$4D42;
    PCardinal(@DecodedBits[2])^:=Length(DecodedBits);
    PCardinal(@DecodedBits[10])^:=14+Length(Info);
    Move(Info[0],DecodedBits[14],Length(Info));
    if Length(Bits)>0 then Move(Bits[0],DecodedBits[14+Length(Info)],Length(Bits));
    CopyRecord:=DecodedBits;
    if not FDecoder(CopyRecord,DecodedInfo,DecodedBits) then Exit;
    if not AcceptDecodedDIB then Exit;
    Info:=DecodedInfo;Bits:=DecodedBits;
  end;
  if (Recovery<>mrrNone) and RebuildDIBRecord then begin
    if Kind=81 then SetDWord(64,Usage) else SetDWord(80,Usage);
    Rec:=PEnhMetaRecord(@CopyRecord[0]);
    Result:=MetafileNativePlay(DC,Table,Rec,Objects);
    if Result then begin FRecovery:=Recovery;FError:=0;Exit;end;
    FError:=GetLastError;
    if FError=0 then FError:=ERROR_INVALID_DATA;
  end;
  { Completely clipped source rectangles contain no source pixels. Preserve
    this as a successful empty transfer rather than treating it as lost data. }
  if Kind=81 then begin
    DIB:=PBitmapInfoHeader(@Info[0]);
    SourceX:=Integer(DWordAt(32));SourceY:=Integer(DWordAt(36));
    SourceW:=Integer(DWordAt(40));SourceH:=Integer(DWordAt(44));
    if (DWordAt(68)=SRCCOPY) and (SourceW>=0) and (SourceH>=0) and
      ((Int64(SourceX)+SourceW<=0) or (Int64(SourceY)+SourceH<=0) or
       (SourceX>=DIB.biWidth) or (Int64(SourceY)>=Abs(Int64(DIB.biHeight)))) then begin
      Result:=True;FRecovery:=mrrOutsideSource;FError:=0;
    end;
  end;
end;
