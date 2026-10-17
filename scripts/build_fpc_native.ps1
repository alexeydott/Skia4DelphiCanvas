param(
    [ValidateSet('demo', 'tests')][string]$Target = 'demo',
    [ValidateSet('win32','win64')][string]$Platform = 'win64',
    [string]$Compiler = '',
    [string]$Lazarus = 'D:\fpc\lazarus',
    [string]$SkiaDll = '',
    [string]$StaticSkiaRoot = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cpu = if ($Platform -eq 'win32') { 'i386' } else { 'x86_64' }
$objectPlatform = if ($Platform -eq 'win32') { 'Win32' } else { 'Win64' }
if (!$Compiler) {
    $compilerDirectory = if ($Platform -eq 'win32') { 'i386-win32' } else { 'x86_64-win64' }
    $Compiler = Join-Path 'D:\fpc\fpc-3.3.1\bin' "$compilerDirectory\fpc.exe"
}
if (!$SkiaDll) { $SkiaDll = Join-Path $root "runtime\$Platform\sk4d.dll" }
function Assert-PETarget([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 77 -or $bytes[1] -ne 90) { throw "Not a PE file: $Path" }
    $pe = [BitConverter]::ToInt32($bytes,60)
    $machine = [BitConverter]::ToUInt16($bytes,$pe+4)
    $expected = if ($Platform -eq 'win32') { 0x14c } else { 0x8664 }
    if ($machine -ne $expected) { throw "PE architecture does not match $Platform : $Path" }
}
if (!(Test-Path -LiteralPath $Compiler)) { throw "FPC compiler not found: $Compiler" }
$version = (& $Compiler -iV | Select-Object -Last 1).Trim()
if ([version]$version -lt [version]'3.3.1') { throw "Native Skia requires FPC 3.3.1 or later; found $version at $Compiler" }
if (!$StaticSkiaRoot -and !(Test-Path -LiteralPath $SkiaDll)) { throw "Matching Skia4Delphi 7.3 / m151 DLL not found: $SkiaDll" }
if (!$StaticSkiaRoot) { $SkiaDll = (Resolve-Path -LiteralPath $SkiaDll).Path }
$configuration = if ($StaticSkiaRoot) { "fpc-static-$Platform" } else { "fpc-native-$Platform" }
$output = Join-Path $root "$Target\build\$configuration"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$staticUnits = @()
if ($StaticSkiaRoot) {
    $StaticSkiaRoot = (Resolve-Path -LiteralPath $StaticSkiaRoot).Path
    $binding = Join-Path $StaticSkiaRoot 'Source\System.Skia.API.pas'
    $objects = Join-Path $StaticSkiaRoot "Binary\Static\FPC\$objectPlatform"
    if (!(Test-Path -LiteralPath $binding) -or !(Test-Path -LiteralPath $objects)) {
        throw "Static Skia requires Windows static API bindings and matching FPC $objectPlatform object files"
    }
    $source = Get-Content -LiteralPath $binding -Raw
    if (!$source.Contains('sk4d_codec_get_origin')) { throw 'Static API package predates Skia4Delphi 7.x; supply a matching m151 package' }
    if (!$source.Contains("../Binary/Static/FPC/$objectPlatform/")) { throw 'The supplied API does not link the requested FPC Windows static objects' }
    $stage = Join-Path $output 'static-bindings'
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    $binaryPath = ($StaticSkiaRoot.Replace('\', '/') + '/Binary/')
    $source = $source.Replace('../Binary/', $binaryPath)
    [IO.File]::WriteAllText((Join-Path $stage 'System.Skia.API.pas'), $source)
    $staticUnits = @($stage)
    if (Test-Path -LiteralPath (Join-Path $output 'sk4d.dll')) { throw 'Static output directory must not contain sk4d.dll' }
}
$unitPaths = @(
    "$output"
) + $staticUnits + @(
    "$root\src\fpc", "$root\src\fpc\vendor", "$root\src", "$root\demo",
    "$Lazarus\lcl", "$Lazarus\lcl\forms", "$Lazarus\lcl\widgetset", "$Lazarus\lcl\interfaces\win32", "$Lazarus\lcl\interfaces",
    "$Lazarus\components\lazutils"
)
$precompiledPaths = @("$Lazarus\lcl\units\$cpu-$Platform\win32", "$Lazarus\lcl\units\$cpu-$Platform", "$Lazarus\components\lazutils\lib\$cpu-$Platform")
$unitPaths += $precompiledPaths | Where-Object { Test-Path -LiteralPath $_ }
foreach ($path in $unitPaths) { if (!(Test-Path -LiteralPath $path)) { throw "Unit path not found: $path" } }
$options = @('-B', '-Mdelphiunicode', "-T$Platform", "-P$cpu", '-dLCL', '-dLCLwin32', '-dSTANDALONE', "-FU$output", "-FE$output", "-Fi$Lazarus\lcl\include")
$options += $unitPaths | ForEach-Object { "-Fu$_" }
if ($StaticSkiaRoot) { $options += '-dSK_STATIC_LIBRARY' }
if ($Target -eq 'tests') { $options += @('-gh', '-gl'); $programs = @('SkiaFpcNativeTests') }
else { $programs = @('SkiaDemo', 'SkiaPdfSvgDemo') }
if ($Target -eq 'tests') {
    $referencePython = if ($env:SKIA_PYTHON) { $env:SKIA_PYTHON } else { 'python' }
    & $referencePython (Join-Path $root 'scripts\audit_emf_fixtures.py') --check
    if ($LASTEXITCODE -ne 0) { throw 'EMF fixture coverage audit failed' }
    & $referencePython (Join-Path $root 'scripts\render_emf_reference.py')
    if ($LASTEXITCODE -ne 0) { throw 'Complete EMF reference generation failed' }
}
if (!$StaticSkiaRoot) {
    Assert-PETarget $SkiaDll
    Copy-Item -LiteralPath $SkiaDll -Destination (Join-Path $output 'sk4d.dll') -Force
}
Write-Host "Native FPC $version / $Platform / $configuration / real Skia: $Target"
Push-Location (Join-Path $root $Target)
try {
    foreach ($program in $programs) {
        $log = Join-Path $output "$program.compile.log"
        & $Compiler @options "$program.pas" *> $log
        if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $log -Tail 80; throw "Compilation failed: $program" }
        $exe = Join-Path $output "$program.exe"
        Assert-PETarget $exe
        $previousPath = $env:PATH
        try {
            if ($StaticSkiaRoot) { $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot" }
            if ($Target -eq 'tests') {
                $previousHeap = $env:HEAPTRC
                try { $env:HEAPTRC = 'haltonnotreleased'; & $exe (Join-Path $root 'tests\fixtures\SkiaFixture.ttf') }
                finally { $env:HEAPTRC = $previousHeap }
            } else { & $exe }
            if ($LASTEXITCODE -ne 0) { throw "Execution failed: $program (exit $LASTEXITCODE)" }
        } finally { $env:PATH = $previousPath }
        if ($Target -eq 'tests') {
            $fuzzArgs=@{CompilerKind='FPC';Platform=$Platform;Compiler=$Compiler;Lazarus=$Lazarus;SkiaDll=$SkiaDll;OutputDirectory=(Join-Path $output 'fuzz')}
            if($StaticSkiaRoot){$fuzzArgs.Static=$true;$fuzzArgs.StaticSkiaRoot=$StaticSkiaRoot}
            & (Join-Path $PSScriptRoot 'run_emf_fuzz.ps1') @fuzzArgs
        }
    }
} finally { Pop-Location }



