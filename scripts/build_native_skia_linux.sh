#!/usr/bin/env bash
# Build Skia m151 for the pinned Skia4Delphi 7.3 Pascal bindings.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SKIA_SOURCE_DIR=${SKIA_SOURCE_DIR:-"$root/skia"}
source_dir=$(realpath "$SKIA_SOURCE_DIR")
version_header="$source_dir/sk4d/include/sk4d_version.h"
grep -Eq 'SK4D_VERSION[[:space:]]+"151\.' "$version_header" || {
  echo 'This build requires sk4d/m151, matching the pinned Pascal API.' >&2
  exit 1
}
build_dir=${SKIA_BUILD_DIR:-"$root/runtime/build/linux64"}
runtime_dir=${SKIA_RUNTIME_DIR:-"$root/runtime/linux64"}
cd "$source_dir"
if [[ ${SKIA_SYNC_DEPS:-0} == 1 ]]; then
  GIT_SYNC_DEPS_SKIP_EMSDK=1 python3 tools/git-sync-deps
fi
[[ -x bin/gn ]] || python3 bin/fetch-gn
bin/gn gen "$build_dir" --args='
is_official_build = true
is_sk4d_build = true
is_sk4d_component_build = true
cc = "clang"
cxx = "clang++"
skia_enable_ganesh = true
skia_use_partition_alloc = false
skia_enable_tools = false
skia_use_dng_sdk = false
skia_use_system_icu = true
skia_use_icu_static = false
skia_use_system_harfbuzz = true
skia_use_system_expat = true
skia_use_system_libjpeg_turbo = true
skia_use_system_libpng = true
skia_use_system_libwebp = true
skia_use_system_zlib = true
skia_use_system_freetype2 = true
'
python3 "$root/scripts/prepare_native_skia_compat.py" --skia-root "$source_dir" --build-dir "$build_dir" --svg-only
ninja -C "$build_dir" -j "${SKIA_BUILD_JOBS:-$(nproc)}" sk4d
python3 "$root/scripts/verify_native_skia_api.py" "$build_dir/libsk4d.so"
mkdir -p "$runtime_dir"
install -m 755 "$build_dir/libsk4d.so" "$runtime_dir/libsk4d.so"
install -m 644 "$source_dir/LICENSE" "$runtime_dir/LICENSE.skia"
install -m 644 "$build_dir/compat/manifest.json" "$runtime_dir/build-compat.json"
install -m 644 "$build_dir/args.gn" "$runtime_dir/args.gn"
{
  grep SK4D_VERSION "$version_header" | tail -1
  echo 'Skia4Delphi 7.3.0 Pascal API; native SVG gradients'
  git -C "$source_dir" rev-parse HEAD
  clang++ --version | head -n 1
  (cd "$runtime_dir" && sha256sum libsk4d.so)
} > "$runtime_dir/build-info.txt"
echo "Set SKIA_LIBRARY_DIR=$runtime_dir"
