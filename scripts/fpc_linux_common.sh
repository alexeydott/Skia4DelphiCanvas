#!/usr/bin/env bash
# Shared native Linux FPC/LCL build configuration.
linux_fpc_setup() {
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
compiler=${FPC:-fpc}
version=$("$compiler" -iV)
if ! printf '%s\n%s\n' 3.3.1 "$version" | sort -VC; then
  echo "FPC 3.3.1 or later required; found $version" >&2
  exit 1
fi
: "${LAZARUS_ROOT:?Set LAZARUS_ROOT to the Lazarus source directory}"
SKIA_LIBRARY_DIR=${SKIA_LIBRARY_DIR:-"$root/runtime/linux64"}
compiler_path=$(readlink -f "$(command -v "$compiler")")
target=$("$compiler" -iTP)-$("$compiler" -iTO)
units=${FPC_UNITS_ROOT:-$(dirname "$compiler_path")/units/$target}
if [[ ! -d "$units" ]]; then
  units=${FPC_UNITS_ROOT:-$(dirname "$compiler_path")/../lib/fpc/$version/units/$target}
fi
[[ -d "$units" ]] || { echo 'Set FPC_UNITS_ROOT to matching compiler units' >&2; exit 1; }
[[ -f "$SKIA_LIBRARY_DIR/libsk4d.so" ]] || {
  echo "Missing $SKIA_LIBRARY_DIR/libsk4d.so; run scripts/build_native_skia_linux.sh or set SKIA_LIBRARY_DIR" >&2
  exit 1
}
python3 "$root/scripts/verify_native_skia_api.py" "$SKIA_LIBRARY_DIR/libsk4d.so"
out="$root/$1/build/fpc-linux-$target"
mkdir -p "$out"
options=(-n -Sc -Mdelphiunicode -dLCL -dLCLgtk2 -gh -gl
  "-FU$out" "-FE$out" "-Fu$out"
  "-Fu$root/demo" "-Fu$root/tests" "-Fu$root/src/fpc" "-Fu$root/src/fpc/vendor" "-Fu$root/src"
  "-Fu$LAZARUS_ROOT/lcl" "-Fu$LAZARUS_ROOT/lcl/forms"
  "-Fu$LAZARUS_ROOT/lcl/widgetset" "-Fu$LAZARUS_ROOT/lcl/interfaces"
  "-Fu$LAZARUS_ROOT/lcl/interfaces/gtk2" "-Fu$LAZARUS_ROOT/components/lazutils"
  "-Fu$LAZARUS_ROOT/packager/registration" "-Fi$LAZARUS_ROOT/lcl/include"
  "-Fl$SKIA_LIBRARY_DIR")
for unit_dir in "$units"/*; do
  # Free Vision also exports Menus; LCL must use its own GUI Menus unit.
  [[ ${unit_dir##*/} == freevision || ${unit_dir##*/} == fv ]] && continue
  options+=("-Fu$unit_dir")
done
}

linux_fpc_run() {
  export LD_LIBRARY_PATH="$SKIA_LIBRARY_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export HEAPTRC=haltonnotreleased
  if [[ -z "${DISPLAY:-}" ]]; then xvfb-run -a "$1"; else "$1"; fi
}
