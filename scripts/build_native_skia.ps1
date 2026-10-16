param(
    [string]$SkiaRoot = 'D:\projects\externals\skia',
    [string]$Toolchain = 'D:\projects\externals\skia\toolchains\llvm-mingw-20240619-ucrt-x86_64',
    [string]$Ninja = 'D:\tools\Meson\ninja.exe',
    [ValidateSet('win32','win64')][string]$Platform = 'win64',
    [ValidateSet('static','dll')][string]$Linkage = 'static',
    [string]$Output = '',
    [string]$RuntimeRoot = '',
    [int]$Jobs = 16
)
$ErrorActionPreference = 'Stop'
if (!$RuntimeRoot) { $RuntimeRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime' }
if (!$Output) { $Output = "out\$Linkage-$Platform-pascal" }
$cpu = if ($Platform -eq 'win32') { 'x86' } else { 'x64' }
$component = if ($Linkage -eq 'dll') { 'true' } else { 'false' }
$SkiaRoot = (Resolve-Path -LiteralPath $SkiaRoot).Path
$versionHeader = Get-Content (Join-Path $SkiaRoot 'sk4d\include\sk4d_version.h') -Raw
if ($versionHeader -notmatch '#define SK4D_VERSION "(151\.[^"]+)"') { throw 'The pinned Pascal API requires the sk4d/m151 checkout' }
$nativeVersion = $Matches[1]
$Toolchain = (Resolve-Path -LiteralPath $Toolchain).Path.Replace('\', '/')
$gn = Join-Path $SkiaRoot 'bin\gn.exe'
if (!(Test-Path -LiteralPath $gn)) { throw 'Run python bin/fetch-gn in the Skia checkout first' }
if (!(Test-Path -LiteralPath $Ninja)) { throw "Ninja not found: $Ninja" }
$build = Join-Path $SkiaRoot $Output
New-Item -ItemType Directory -Path $build -Force | Out-Null
$arguments = @"
is_official_build = true
is_debug = false
target_os = "win"
target_cpu = "$cpu"
is_sk4d_build = true
is_sk4d_component_build = $component
win_mingw = "$Toolchain"
skia_use_partition_alloc = false
skia_enable_tools = false
skia_use_libavif = false
skia_use_libjxl = false
skia_use_dng_sdk = false
skia_use_freetype = false
skia_use_system_expat = false
skia_use_system_harfbuzz = false
skia_use_system_icu = false
skia_use_system_libjpeg_turbo = false
skia_use_system_libpng = false
skia_use_system_libwebp = false
skia_use_system_zlib = false
extra_cflags = [ "-fasynchronous-unwind-tables", "-fno-addrsig", "-femulated-tls" ]
extra_cflags_cc = [ "-fno-exceptions" ]
extra_ldflags = [ "-static" ]
skia_use_vulkan = true
"@
[IO.File]::WriteAllText((Join-Path $build 'args.gn'), $arguments)
Push-Location $SkiaRoot
try {
    & $gn gen $Output
    if ($LASTEXITCODE -ne 0) { throw 'Skia GN generation failed' }
    & $Ninja -C $Output -j $Jobs sk4d
    if ($LASTEXITCODE -ne 0) { throw 'Skia native build failed' }
    $binary = if ($Linkage -eq 'dll') { 'sk4d.dll' } else { 'sk4d.a' }
    Get-Item -LiteralPath (Join-Path $build $binary) | Select-Object FullName, Length
    if ($Linkage -eq 'dll') {
        $destination = Join-Path $RuntimeRoot $Platform
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        $installed = Join-Path $destination 'sk4d.dll'
        Copy-Item -LiteralPath (Join-Path $build $binary) -Destination $installed -Force
        $info = @{native_version=$nativeVersion; pascal_api='7.3.0'; platform=$Platform;
                  source_revision=(& git rev-parse HEAD); sha256=(Get-FileHash $installed).Hash; args=$arguments}
        $info | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $destination 'build-info.json') -Encoding utf8
    }
} finally { Pop-Location }
