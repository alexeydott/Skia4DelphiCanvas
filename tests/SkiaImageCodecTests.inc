{ The PNG bytes are copied from test_libuemf_ref.emf without modifying the fixture.
  Decode pixels explicitly: lazy image creation alone misses native codec failures. }
procedure TestNativePngDecoding;
const Png:array[0..137] of Byte=(
  $89,$50,$4E,$47,$0D,$0A,$1A,$0A,$00,$00,$00,$0D,$49,$48,$44,$52,
  $00,$00,$00,$0A,$00,$00,$00,$0A,$08,$02,$00,$00,$00,$02,$50,$58,
  $EA,$00,$00,$00,$50,$49,$44,$41,$54,$18,$95,$6D,$8E,$C1,$0D,$C0,
  $30,$08,$03,$AF,$12,$63,$C0,$FE,$83,$01,$73,$B4,$8F,$54,$09,$41,
  $F8,$85,$30,$67,$F3,$BC,$10,$4A,$28,$6E,$C3,$20,$01,$A0,$8C,$8A,
  $DF,$9E,$2E,$12,$40,$FC,$2C,$AC,$72,$4B,$9B,$2E,$19,$65,$D5,$6C,
  $C8,$AB,$A5,$86,$6F,$EE,$B4,$14,$FA,$CA,$D1,$DB,$CE,$FE,$F8,$BA,
  $10,$EF,$5C,$95,$7D,$4F,$0D,$1B,$2C,$7B,$16,$38,$83,$00,$00,$00,
  $00,$00,$49,$45,$4E,$44,$AE,$42,$60,$82);
var Encoded,RoundTrip:TBytes;Image,Decoded:ISkImage;
  Pixels:array[0..99] of Cardinal;Format:TSkEncodedImageFormat;
begin
  SetLength(Encoded,SizeOf(Png));Move(Png[0],Encoded[0],SizeOf(Png));
  Image:=TSkImage.MakeFromEncoded(Encoded);
  Check((Image<>nil) and (Image.Width=10) and (Image.Height=10),'native PNG dimensions');
  if Image=nil then Exit;
  if not Image.ReadPixels(TSkImageInfo.Create(10,10,TSkColorType.BGRA8888,
    TSkAlphaType.Unpremul),@Pixels[0],40) then begin
    Check(False,'native PNG pixels decode');Exit;
  end;
  Check((Pixels[0]=$FFFF0000) and (Pixels[99]=$FF0000FF),
    'native PNG decoded pixels match the source');
  for Format in [TSkEncodedImageFormat.PNG,TSkEncodedImageFormat.JPEG] do begin
    RoundTrip:=Image.Encode(Format,95);
    Check(Length(RoundTrip)>0,'native PNG/JPEG encoder produces data');
    if Length(RoundTrip)=0 then Continue;
    Decoded:=TSkImage.MakeFromEncoded(RoundTrip);
    Check((Decoded<>nil) and (Decoded.Width=10) and (Decoded.Height=10),
      'native PNG/JPEG round trip dimensions');
    if Decoded<>nil then
      Check(Decoded.ReadPixels(TSkImageInfo.Create(10,10,TSkColorType.BGRA8888,
        TSkAlphaType.Unpremul),@Pixels[0],40),'native PNG/JPEG round trip pixels decode');
  end;
  { Skia may supply partial pixels for incomplete input. Both rejection and
    partial decoding must return normally, and leave subsequent decoding intact. }
  SetLength(Encoded,48);
  Decoded:=TSkImage.MakeFromEncoded(Encoded);
  if Decoded<>nil then
    Decoded.ReadPixels(TSkImageInfo.Create(10,10,TSkColorType.BGRA8888,
      TSkAlphaType.Unpremul),@Pixels[0],40);
  SetLength(Encoded,SizeOf(Png));Move(Png[0],Encoded[0],SizeOf(Png));
  Decoded:=TSkImage.MakeFromEncoded(Encoded);
  Check((Decoded<>nil) and Decoded.ReadPixels(TSkImageInfo.Create(10,10,
    TSkColorType.BGRA8888,TSkAlphaType.Unpremul),@Pixels[0],40) and
    (Pixels[0]=$FFFF0000) and (Pixels[99]=$FF0000FF),
    'native PNG decoder recovers after incomplete input');
end;
