# Native Skia runtimes

The default shared-library and static builds use Skia 151.0.1 and the Skia4Delphi 7.3.0
Pascal bindings at `fce5db2ffcf547f597f5f0a6b2125d779d5598e3` in [src/fpc/vendor](../src/fpc/vendor/README.md).

All paths and commands below are relative to the [project root](../README.md),
`D:\projects\externals\Skia4DelphiCanvas` on Windows or
`/mnt/d/projects/externals/Skia4DelphiCanvas` in WSL. Run build commands from
that directory, rather than from `runtime`.

Installed files are in `runtime/linux64`, `runtime/win32`, `runtime/win64`
and `runtime/windows-static`. Native intermediates are isolated in
`runtime/build`; test and demo outputs are in `tests/build` and `demo/build`. Keep the DLLs and Linux shared library for dynamic linking.
For static linking, keep `runtime/windows-static/Source` and all four
`runtime/windows-static/Binary/Static` architecture/compiler directories: their `.o`
files are required linker inputs. Build metadata, manifests and licenses identify
the supplied binaries and should accompany them. Generated application files,
compiler caches and test exports belong in the separate build directories.

| Directory | Native library | Source |
| --- | --- | --- |
| `runtime/linux64` | Skia 151.0.1, x86-64 ELF | Pinned [skia submodule](../skia), commit `e5e4933ea025f5e1b8a07d038e38869e205deb06` |
| `runtime/win32` | Skia 151.0.1, x86 PE DLL | Same pinned submodule as Linux |
| `runtime/win64` | Skia 151.0.1, x86-64 PE DLL | Same pinned submodule as Linux |
| `runtime/windows-static` | Win32/Win64 COFF objects and static Pascal API | Same pinned submodule as Linux |

Windows DLLs are rebuilt with LLVM-MinGW 18.1.8 UCRT. Their C++ runtime is
embedded; deploy only the DLL matching the EXE architecture. `build-info.json`
records the native revision, GN arguments and DLL hash.

The static package contains separate `runtime/windows-static/Binary/Static/Win32`,
`runtime/windows-static/Binary/Static/Win64`,
`runtime/windows-static/Binary/Static/FPC/Win32` and
`runtime/windows-static/Binary/Static/FPC/Win64` directories. Delphi Win32/Win64 and FPC 3.3.1
Win32/Win64 are validated with both DLL and static linking.
Put `runtime/windows-static/Source` before `src/fpc/vendor` in the unit search path,
define `SK_STATIC_LIBRARY`, and retain the package directory layout. No Skia
DLL is used. C++ runtime code is embedded, while Windows/UCRT system imports
are resolved at startup. Native C++ exceptions are disabled.

Rebuild with `./scripts/build_native_skia.ps1 -Platform win64 -Linkage dll`.
DLL and static builds install automatically. `scripts/prepare_windows_static_m151.py`
is called by the static builder; its manifests record native/COFF hashes and API imports.
See the main [README](../README.md#skia-version) for complete
commands and application settings.

Linux is built with Clang 21 on Ubuntu 26.04. It links the distribution's
Fontconfig, FreeType, HarfBuzz, ICU, Expat, JPEG, PNG, WebP, zlib and OpenGL
libraries. Rebuild on the intended distribution rather than assuming these
system-library versions are available on an older Linux installation.

Run `SKIA_SYNC_DEPS=1 bash scripts/build_native_skia_linux.sh` for the first build.
It defaults to the pinned `skia` submodule; `SKIA_SOURCE_DIR` overrides it.
All native intermediates are placed in `runtime/build`, separate from installed
DLLs, shared libraries and Pascal static packages. The script records compiler, native
version, GN arguments and SHA-256 beside the installed library, and checks
every C API symbol used by the Pascal loader before installation.

The upstream license is preserved in [runtime/linux64/LICENSE.skia](linux64/LICENSE.skia) and
[runtime/LICENSE.skia](LICENSE.skia). Original external runtime packages are unchanged.
