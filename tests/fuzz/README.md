# EMF parser fuzz tests

The Windows harness parses accepted EMFs with text conversion off and on,
visits every stored subpath and point, and exercises `TMetafileRecordPlayer`
using a real GDI object table. `--render` additionally uses
`TSkiaBitmapCanvas.Draw`. Range/overflow exceptions caught internally by the
parser are reported as findings, rather than accepted validation failures.

## Automatic test runs

The normal Windows test scripts automatically build and run the checked harness
for the same compiler, architecture and linking mode:

- `tests/run_tests.cmd`: Delphi Win32 and Win64 DLL.
- `scripts/build_delphi_static.ps1 -Target tests`: selected Delphi static builds.
- `scripts/build_fpc_native.ps1 -Target tests`: FPC DLL, or static with `-StaticSkiaRoot`.

Each build runs all **2,100** generated EMFs, every file in `tests/fuzz/regress`,
and **300** mutations with seed `324508639` plus one unmodified seed. Windows test
executables also include `T_EmfFuzzSmoke`; `SKIA_TEST_GROUP=fuzz` selects it alone.
Unset `SKIA_TEST_GROUP` and `SKIA_EMF_FILTER` for the complete normal suite. Linux
runs the portable suite; this harness requires Windows GDI.

`scripts/run_emf_fuzz.ps1` creates a versioned corpus under `tests/build`, locks
cache creation across concurrent builds, and checks exact case counts and exit
codes. Fuzz compilation enables Delphi `-$R+ -$Q+ -$C+` or FPC `-Cr -Co -gl -gh`,
including parser units. Static harnesses are checked for Skia DLL dependencies.

Each case has a **2-second watchdog** and each phase a **300-second process
timeout**. Timeouts, crashes, incorrect case counts and findings fail the calling
script. Reports include `results.json`, stdout/stderr and
`crashes/current.emf`, `current.txt`, `process.txt`. Caught failures also save
an EMF with an exception/mutation sidecar. Standard builds keep these files in
`tests/build/<configuration>/fuzz`.

To adjust timeouts or rerun a checked configuration from the project root:

```powershell
./scripts/run_emf_fuzz.ps1 -CompilerKind Delphi -Platform win64 -Static -CaseTimeoutMS 5000 -ProcessTimeoutSeconds 600
./scripts/run_emf_fuzz.ps1 -CompilerKind FPC -Platform win32
```

## Standalone builds

From `tests/fuzz`, `run_fuzz.cmd` builds both Delphi DLL harnesses. Its first
argument can override `rsvars.bat`; remaining arguments are forwarded to
`build_fuzz_delphi.ps1`, such as `-Static` or `-Platform win64`.
`run_fuzz_fpc.cmd` builds both FPC 3.3.1 DLL harnesses; pass `-Static` for static.
The build helpers accept compiler, Lazarus, DLL and static-package paths.
Outputs go to ignored `tests/build/emf-fuzz-*` directories.

From the project root:

```powershell
python tests/fuzz/gen_emf_corpus.py --out tests/build/manual-fuzz-corpus
./tests/build/emf-fuzz-delphi-win64/EmfFuzz.exe --corpus tests/build/manual-fuzz-corpus --iterations 0 --out tests/build/manual-fuzz
./tests/build/emf-fuzz-delphi-win64/EmfFuzz.exe --regress tests/fuzz/regress --out tests/build/manual-regress
./tests/build/emf-fuzz-delphi-win64/EmfFuzz.exe --seed 324508639 --iterations 10000 --time-budget 3600 --render --out tests/build/manual-long-fuzz
python -m unittest discover -s tests -p test_emf_fuzz_corpus.py
```

`--corpus` accepts semicolon-separated directories; `--regress` disables random
mutations. `--case-timeout` is in milliseconds and `--mem-limit` in MiB.
Exit codes: 0 success, 1 findings, 2 invocation/setup error, 3 case watchdog.
The supervisor also handles process failures without a final summary.

## Reproductions and coverage

The corpus has invalid lengths, counts, offsets, sizes and types inside a valid
EMF envelope. GDI rejection and explicit parser validation/quota rejection are
expected outcomes. Access violations, range errors, arithmetic faults and
timeouts are failures. Statistics are not disjoint: input may parse first and
be rejected during text conversion. Record coverage counts callbacks.

Keep minimized findings and explanatory sidecars in `regress`. Current cases
cover invalid map mode, large ANGLEARC endpoints, high-bit pen color and
unrepresentable normalized outline-font width, high-bit raster background color,
excessive native stroke/dash work, and invalid/large EXTTEXTOUT/POLYTEXTOUT advances. Reproduce from saved EMF:
GDI seed bytes may differ across Windows/compiler versions with the same seed.

The watchdog also bounds native GDI calls. Native stroke and text work is
validated before replay or vector path capture: excessive pen widths, geometric
dash work and text advances are explicit rejections. These limits use the DC
mapping, so ordinary output with large downscaled logical coordinates is valid.
Rendering and native replay run for inputs accepted by both parser passes.

## Long rendered matrix

```powershell
./scripts/run_emf_fuzz_matrix.ps1 -Iterations 10000 -OutputDirectory tests/build/long-fuzz
```

The matrix runs all eight Delphi/FPC Win32/Win64 DLL/static configurations and
continues to collect other configurations after a failure. It returns failure
only after writing all eight outcomes to `matrix.json`. Each configuration has
its own build/output directory. Phases have a 1,800-second outer timeout by
default; `-CaseTimeoutMS` and `-ProcessTimeoutSeconds` override the limits.
For one configuration, use `scripts/run_emf_fuzz.ps1 -CompilerKind FPC -Platform
win64 -Static -Render -Iterations 10000 -ProcessTimeoutSeconds 1800`.

`results.json` records exact case counts, elapsed time, rendered/replayed counts,
exit status and findings. `--trace-stages` records stage and process-memory
measurements. Diagnostic text files use UTF-8 under Delphi and FPC, including
Unicode source names and output paths. No string-conversion warnings are
suppressed in the harness.

## Verified results (2026-10-17)

| Compiler | Platform | Linking | Cases per build | Failures / hangs |
| --- | --- | --- | ---: | ---: |
| Delphi 12 | Win32 | DLL / static | 12,116 | 0 / 0 |
| Delphi 12 | Win64 | DLL / static | 12,116 | 0 / 0 |
| FPC 3.3.1 | Win32 | DLL / static | 12,116 | 0 / 0 |
| FPC 3.3.1 | Win64 | DLL / static | 12,116 | 0 / 0 |

Each build used `--render`, seed `324508639`, 10,000 mutations, 2,100 corpus
files, 15 regressions and an unmodified seed. Total: **96,928 inputs**, zero
unexpected exceptions, memory findings or timeouts; all FPC runs had zero
unfreed blocks. The four static harnesses have no Skia DLL dependency.

The initial eight campaigns logged two range-error observations and six memory
observations. Together with the earlier stroke timeouts these produced nine new
saved regressions. High-bit raster colors now preserve their bit pattern;
native stroke/dash work and EXTTEXTOUT/POLYTEXTOUT advances are bounded before
GDI replay/capture. All final campaigns used unchanged parser/harness sources
and the same fifteen saved inputs. Harness units and the command-line program
compile with no warnings under all eight compiler/linking combinations. Unicode
paths and Cyrillic metadata round-trip as UTF-8 under Delphi and FPC.

The unfiltered regular suite also passed **355,158 checks** across all eight
Windows configurations and Linux FPC in WSL. Automatic short fuzz phases passed
**19,328 inputs**. The largest observed long-fuzz process working-set/private-commit
peak was **19.39 MiB**, versus the earlier multi-gigabyte transient allocations.
