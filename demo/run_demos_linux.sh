#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../scripts/fpc_linux_common.sh"
linux_fpc_setup demo
for program in SkiaDemo SkiaPdfSvgDemo; do
  "$compiler" "${options[@]}" "$root/demo/$program.pas" > "$out/$program.compile.log" 2>&1 || {
    tail -50 "$out/$program.compile.log"; exit 1;
  }
  linux_fpc_run "$out/$program" 2>&1 | tee "$out/$program.run.log"
done
if [[ ${1:-} == --verify ]]; then
  bash "$root/scripts/render_fpc_exports.sh" "$out"
  python3 "$root/scripts/verify_fpc_exports.py" "$out"
  python3 "$root/scripts/verify_fpc_typography.py" "$out"
  python3 "$root/scripts/verify_linux_renderings.py" "$out"
fi
