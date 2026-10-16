# Skia4Delphi bindings

The Pascal units and their [license](LICENSE) are in this directory,
`src/fpc/vendor`. Repository-relative paths below start at the project root,
`D:\projects\externals\Skia4DelphiCanvas` on Windows or
`/mnt/d/projects/externals/Skia4DelphiCanvas` in WSL.
See [build and deployment instructions](../../../README.md#skia-version)
and the [runtime layout](../../../runtime/README.md).

[System.Skia.pas](System.Skia.pas) and [System.Skia.API.pas](System.Skia.API.pas) are pinned to the
[Skia4Delphi commit fce5db2](https://github.com/skia4delphi/skia4delphi/tree/fce5db2ffcf547f597f5f0a6b2125d779d5598e3/Source)
(`fce5db2ffcf547f597f5f0a6b2125d779d5598e3`, version 7.3.0 plus subsequent fixes).
Native Skia m151 is pinned separately to `e5e4933ea025f5e1b8a07d038e38869e205deb06`.
The native FPC build requires FPC 3.3.1 or later and a matching
`sk4d.dll` on Windows or Linux64 `libsk4d.so` on Linux. The same bindings are
also used by the Delphi demo and test runners. Windows DLLs in [runtime/win32](../../../runtime/win32)
and [runtime/win64](../../../runtime/win64) are rebuilt from sk4d/m151 (151.0.1); Linux [runtime/linux64](../../../runtime/linux64)
uses the same native revision. Windows static objects and their generated API
are in [runtime/windows-static](../../../runtime/windows-static). Put
`runtime/windows-static/Source` first
in the unit search path and define `SK_STATIC_LIBRARY` when using static linking.
It uses the upstream high-level wrapper, including real surfaces,
paths, shaping, PDF documents, SVG canvases and Skia picture serialization.

The upstream copyright notices are preserved. See [LICENSE](LICENSE) for the
upstream license. The C API declarations retain their upstream BSD-style
license notice.

The API loader uses FPC's `InterlockedIncrement`/`InterlockedDecrement`
in place of the upstream atomic helper names. Local compatibility fixes retain
empty-array guards in the new getters and marshal text shadows through the C API
record, whose padding is explicit for FPC on Windows and 64-bit targets.
FPC implements the empty pixmap constructor directly on `TSkPixmap` to avoid
the class-helper constructor allocation leak. DLL calling conventions are unchanged.

The update includes `TSkFontFeature`, the `TSkTextStyleHelper.FontFeatures` and
`Shadows` getters, font edging/hinting/subpixel properties, the empty pixmap
constructor, and corrected region/clipped-region enumeration. Read the new
properties through a `TSkTextStyle` instance; upstream keeps `ISkTextStyle` unchanged.
The Linux build and runners check all Pascal-loader imports against the
library's exported symbols before execution.

All 37 binding regressions pass with range checking under Delphi/FPC Win32/Win64
DLL/static and Linux FPC 3.3.1. The full unfiltered matrix passes 53,455 checks,
with zero FPC heap leaks. All 815 Pascal C API imports are available in the
pinned native libraries.
