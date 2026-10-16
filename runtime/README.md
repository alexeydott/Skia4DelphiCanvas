# Native Skia runtimes

The default shared-library and static builds use Skia 151.0.1 and the Skia4Delphi 7.3.0
Pascal bindings in `src/fpc/vendor`.

This directory contains distributable runtime and link-time dependencies, not
test or demo outputs. Keep the DLLs and Linux shared library for dynamic linking.
For static linking, keep `windows-static/Source` and all four
`windows-static/Binary/Static` architecture/compiler directories: their `.o`
files are required linker inputs. Build metadata, manifests and licenses identify
the supplied binaries and should accompany them. Generated application files,
compiler caches and test exports belong in the separate build directories.

| Directory | Native library | Source |
| --- | --- | --- |
| `linux64` | Skia 151.0.1, x86-64 ELF | Local `skia4delphi/skia` checkout, commit `05fae0ee01e9e21a99355f89f8b5dacad2611a2c` |
| `win32` | Skia 151.0.1, x86 PE DLL | Same local native checkout as Linux |
| `win64` | Skia 151.0.1, x86-64 PE DLL | Same local native checkout as Linux |
| `windows-static` | Win32/Win64 COFF objects and static Pascal API | Same local native checkout as Linux |

Windows DLLs are rebuilt with LLVM-MinGW 18.1.8 UCRT. Their C++ runtime is
embedded; deploy only the DLL matching the EXE architecture. `build-info.json`
records the native revision, GN arguments and DLL hash.

The static package contains separate `Binary/Static/Win32`, `Win64`,
`FPC/Win32` and `FPC/Win64` directories. Delphi Win32/Win64 and FPC 3.3.1
Win32/Win64 are validated with both DLL and static linking.
Put `windows-static/Source` before `src/fpc/vendor` in the unit search path,
define `SK_STATIC_LIBRARY`, and retain the package directory layout. No Skia
DLL is used. C++ runtime code is embedded, while Windows/UCRT system imports
are resolved at startup. Native C++ exceptions are disabled.

Rebuild with `scripts/build_native_skia.ps1 -Platform win32|win64 -Linkage dll|static`.
DLL builds install automatically. Run `scripts/prepare_windows_static_m151.py`
for each static platform; its manifests record native/COFF hashes and API imports.
See the main [README](../README.md#windows-dll-and-static-runtimes) for complete
commands and application settings.

Linux is built with Clang 21 on Ubuntu 26.04. It links the distribution's
Fontconfig, FreeType, HarfBuzz, ICU, Expat, JPEG, PNG, WebP, zlib and OpenGL
libraries. Rebuild on the intended distribution rather than assuming these
system-library versions are available on an older Linux installation.

Run `scripts/build_native_skia_linux.sh` with `SKIA_SOURCE_DIR` pointing to a
dependency-populated sk4d/m151 checkout. The script records compiler, native
version, GN arguments and SHA-256 beside the installed library, and checks
every C API symbol used by the Pascal loader before installation.

The upstream license is preserved in `linux64/LICENSE.skia` and
`LICENSE.skia`. Original external runtime packages are unchanged.
