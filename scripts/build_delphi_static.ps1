param(
    [ValidateSet('demo', 'tests')][string]$Target = 'demo',
    [ValidateSet('win32', 'win64')][string[]]$Platforms = @('win64'),
    [string]$StaticSkiaRoot = '',
    [string]$CompilerRoot = 'D:\Embarcadero RAD Studio\23.0'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$StaticSkiaRoot) { $StaticSkiaRoot = Join-Path $root 'runtime\windows-static' }
$StaticSkiaRoot = (Resolve-Path -LiteralPath $StaticSkiaRoot).Path
$binding = Join-Path $StaticSkiaRoot 'Source\System.Skia.API.pas'
$source = Get-Content -LiteralPath $binding -Raw
if (!$source.Contains('sk4d_codec_get_origin')) { throw 'Static API package predates Skia4Delphi 7.x; supply a matching m151 package' }
if (!$source.Contains('../Binary/Static/Win64/')) { throw 'The supplied API does not link Delphi Windows static objects' }
$source = $source.Replace('../Binary/', ($StaticSkiaRoot.Replace('\', '/') + '/Binary/'))
if ($Target -eq 'tests') {
    $python = if ($env:SKIA_PYTHON) { $env:SKIA_PYTHON } else { 'python' }
    & $python (Join-Path $PSScriptRoot 'audit_emf_fixtures.py') --check
    if ($LASTEXITCODE -ne 0) { throw 'EMF fixture coverage audit failed' }
    & $python (Join-Path $PSScriptRoot 'render_emf_reference.py')
    if ($LASTEXITCODE -ne 0) { throw 'Complete EMF reference generation failed' }
}
foreach ($platform in $Platforms) {
    $compilerName = if ($platform -eq 'win64') { 'dcc64.exe' } else { 'dcc32.exe' }
    $compiler = Join-Path $CompilerRoot "bin\$compilerName"
    $objects = Join-Path $StaticSkiaRoot "Binary\Static\$platform"
    if (!(Test-Path -LiteralPath $compiler) -or !(Test-Path -LiteralPath $objects)) {
        throw "Compiler or static objects missing for $platform"
    }
    $output = Join-Path $root "$Target\build\$platform-static"
    $stage = Join-Path $output 'static-bindings'
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    if (Test-Path -LiteralPath (Join-Path $output 'sk4d.dll')) { throw 'Static output directory must not contain sk4d.dll' }
    [IO.File]::WriteAllText((Join-Path $stage 'System.Skia.API.pas'), $source)
    $options = @('-B', '-DSK_STATIC_LIBRARY', '-NSSystem;Winapi;Vcl', "-E$output", "-N0$output",
                 "-U$stage;$root\src\fpc\vendor;$root\src;$CompilerRoot\lib\$platform\release")
    $programs = if ($Target -eq 'tests') { @('SkiaCanvasTests') } else { @('SkiaDemo', 'SkiaPdfSvgDemo') }
    Push-Location (Join-Path $root $Target)
    try {
        foreach ($program in $programs) {
            $log = Join-Path $output "$program.compile.log"
            & $compiler @options "$program.pas" *> $log
            if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $log -Tail 60; throw "Compilation failed: $program / $platform" }
            $previousPath = $env:PATH
            try {
                $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
                & (Join-Path $output "$program.exe")
                if ($LASTEXITCODE -ne 0) { throw "Execution failed: $program / $platform (exit $LASTEXITCODE)" }
            } finally { $env:PATH = $previousPath }
            if ($Target -eq 'tests') {
                & (Join-Path $PSScriptRoot 'run_emf_fuzz.ps1') -CompilerKind Delphi -Platform $platform -Static -CompilerRoot $CompilerRoot -StaticSkiaRoot $StaticSkiaRoot -OutputDirectory (Join-Path $output 'fuzz')
            }
        }
    } finally { Pop-Location }
}
