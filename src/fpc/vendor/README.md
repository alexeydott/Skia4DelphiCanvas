# Skia4Delphi bindings

The Pascal units and their [license](LICENSE) are in this directory,
`src/fpc/vendor`. Repository-relative paths below start at the project root,
`D:\projects\externals\Skia4DelphiCanvas` on Windows or
`/mnt/d/projects/externals/Skia4DelphiCanvas` in WSL.
See [build and deployment instructions](../../../README.md#skia-version)
and the [runtime layout](../../../runtime/README.md).

[System.Skia.pas](System.Skia.pas) and [System.Skia.API.pas](System.Skia.API.pas) are pinned to the
[Skia4Delphi v7.3.0 release](https://github.com/skia4delphi/skia4delphi/tree/v7.3.0/Source)
(commit `7e92bcd4d739c1fc66543d208a5db581567ac0b7`), using Skia m151.
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
in place of the upstream atomic helper names; no API declarations or DLL
calling conventions are changed.
The Linux build and runners check all Pascal-loader imports against the
library's exported symbols before execution.
