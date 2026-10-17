program EmfFuzz;

{$APPTYPE CONSOLE}
{$IFDEF FPC}{$MODE DELPHIUNICODE}{$MODESWITCH FUNCTIONREFERENCES}{$ENDIF}
{$R+}{$Q+}

uses
  {$IFDEF FPC}Interfaces,{$ENDIF} SysUtils, Classes,
{$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF},
  EmfFuzzCore;

function ArgText(const S:UnicodeString):{$IFDEF FPC}UTF8String{$ELSE}string{$ENDIF};
begin {$IFDEF FPC}Result:=UTF8Encode(S);{$ELSE}Result:=S;{$ENDIF}end;
function SameArgument(const Left,Right:string):Boolean;
var I:Integer;L,R:WideChar;
begin
  Result:=False;if Length(Left)<>Length(Right) then Exit;
  for I:=1 to Length(Left) do begin
    L:=Left[I];R:=Right[I];
    if (L>='a') and (L<='z') then L:=WideChar(Ord(L)-32);
    if (R>='a') and (R<='z') then R:=WideChar(Ord(R)-32);
    if L<>R then Exit;
  end;
  Result:=True;
end;
function ArgValue(const Name, Default: string): string;
var I: Integer; S: string;
begin
  Result := Default;
  for I := 1 to ParamCount - 1 do begin S := ParamStr(I); if SameArgument(S, Name) then begin Result := ParamStr(I+1); Exit; end; end;
end;
function HasArg(const Name: string): Boolean;
var I: Integer; begin Result := False; for I := 1 to ParamCount do if SameArgument(ParamStr(I), Name) then Exit(True); end;
procedure AddDirs(const Value: string; Dirs: TStrings);
var P, Start: Integer; S: string;
begin Start := 1; for P := 1 to Length(Value)+1 do if (P > Length(Value)) or (Value[P] = ';') then begin S := Copy(Value, Start, P-Start); if S<>'' then Dirs.Add(ArgText(S)); Start := P+1; end; end;
procedure PrintUsage;
begin Writeln('EmfFuzz --seed N --iterations N --time-budget seconds --corpus DIR[;DIR] --regress DIR --render --out DIR'); end;
function ArgCardinal(const Name:string; Default:Cardinal):Cardinal;
var Value:Int64;
begin
  if not TryStrToInt64(ArgText(ArgValue(Name,UnicodeString(IntToStr(Default)))),Value) or
    (Value<0) or (Value>High(Cardinal)) then
    raise EArgumentException.Create(ArgText('Invalid value for '+Name));
  Result:=Cardinal(Value);
end;
procedure Main;
var
  O: TFuzzOptions; E: TFuzzEngine; Dirs: TStringList; Regress: string; Seed, Iterations, Seconds: Cardinal; I: Integer; Good: Boolean; S: string; St: TFuzzStats;
begin
  if HasArg('--help') then begin PrintUsage; Exit; end;
  O := DefaultFuzzOptions; O.Render := HasArg('--render'); O.OutputDir := ArgValue('--out', 'fuzz-output');
  O.TraceStages := HasArg('--trace-stages');
  O.CaseTimeoutMS := ArgCardinal('--case-timeout',O.CaseTimeoutMS);
  O.MemoryLimitMB := ArgCardinal('--mem-limit',O.MemoryLimitMB);
  Iterations := ArgCardinal('--iterations',10000); Seed := ArgCardinal('--seed',1);
  Seconds := ArgCardinal('--time-budget',0);
  if (Iterations>Cardinal(High(Integer))) or (Seconds>High(Cardinal) div 1000) then raise EArgumentException.Create('Fuzz run budget is too large');
  if Seconds <> 0 then O.TimeBudgetMS := Seconds * 1000;
  Dirs := TStringList.Create; try
    S := ArgValue('--corpus', ''); if S <> '' then AddDirs(S, Dirs);
    Regress := ArgValue('--regress', ''); if Regress <> '' then begin Dirs.Clear; Dirs.Add(ArgText(Regress)); Iterations := 0; end;
    E := TFuzzEngine.Create(O, Seed); try
      Good := E.Run(Dirs, Iterations); St := E.Stats;
      Writeln('cases=', St.Cases, ' rejected-by-GDI=', St.RejectedByGDI, ' parsed=', St.Parsed,
        ' expected-rejections=', St.ExpectedRejections, ' failures=', St.Failures, ' hangs=', St.Hangs,
        ' rendered=',St.Rendered,' replayed=',St.Replayed);
      Writeln('record coverage:'); for I := 0 to 255 do if St.RecordTypes[I] <> 0 then Writeln('  ', I, ': ', St.RecordTypes[I]);
      if not Good then ExitCode:=1;
    finally E.Free; end;
  finally Dirs.Free; end;
end;
begin
  try Main;
  except on E:Exception do begin Writeln(ErrOutput,E.ClassName,': ',E.Message);ExitCode:=2;end;end;
end.
