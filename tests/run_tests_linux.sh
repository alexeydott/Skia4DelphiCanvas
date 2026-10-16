#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../scripts/fpc_linux_common.sh"
linux_fpc_setup tests
"$compiler" "${options[@]}" "$root/tests/SkiaLinuxTests.pas" > "$out/compile.log" 2>&1 || {
  tail -60 "$out/compile.log"; exit 1;
}
# Ensure the Windows-only overloads cannot accidentally re-enter the Linux API.
cat > "$out/HdcNotAvailable.pas" <<'PASCAL'
program HdcNotAvailable;
{$mode delphiunicode}
uses Vcl.Graphics.Skia, LCLType;
var Canvas:TSkiaCanvas; DC:HDC; Points:array[0..2] of TPoint;
begin
  Canvas.BitBlt(0,0,1,1,DC,0,0);
  Canvas.StretchBlt(0,0,1,1,DC,0,0,1,1);
  Canvas.MaskBlt(0,0,1,1,DC,0,0,nil,0,0);
  Canvas.PlgBlt(Points,DC,0,0,1,1);
end.
PASCAL
if "$compiler" "${options[@]}" "$out/HdcNotAvailable.pas" > "$out/no-hdc.log" 2>&1; then
  echo 'FAIL: HDC overloads are available under Linux' >&2; exit 1
fi
if [[ $(grep -c 'Incompatible type for arg no.' "$out/no-hdc.log") != 4 ]]; then
  cat "$out/no-hdc.log"; exit 1
fi
echo 'PASS: all four HDC overloads are absent from the Linux API'
linux_fpc_run "$out/SkiaLinuxTests"
