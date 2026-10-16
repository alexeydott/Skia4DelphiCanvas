param(
    [string]$Distribution = 'Ubuntu',
    [string[]]$Configurations = @('win32','win64','win32-static','win64-static','fpc-native-win32','fpc-native-win64','fpc-static-win32','fpc-static-win64')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$linuxRoot = & wsl.exe -d $Distribution -- wslpath -a $root.Replace('\','/')
if ($LASTEXITCODE -ne 0 -or !$linuxRoot) { throw 'Cannot resolve the workspace path in WSL' }
$linuxRoot = $linuxRoot.Trim()
foreach ($configuration in $Configurations) {
    $output = Join-Path $root "demo\build\$configuration"
    if (!(Test-Path -LiteralPath (Join-Path $output 'skia_demo.pdf'))) { throw "Build the demos first: $configuration" }
    $linuxOutput = & wsl.exe -d $Distribution -- wslpath -a $output.Replace('\','/')
    if ($LASTEXITCODE -ne 0 -or !$linuxOutput) { throw "Cannot resolve demo path: $configuration" }
    $linuxOutput = $linuxOutput.Trim()
    Write-Host "Verify PDF/SVG/BMP/SKP: $configuration"
    & wsl.exe -d $Distribution -- bash "$linuxRoot/scripts/render_fpc_exports.sh" $linuxOutput
    if ($LASTEXITCODE -ne 0) { throw "Rendering failed: $configuration" }
    foreach ($verifier in @('verify_fpc_exports.py','verify_fpc_typography.py','verify_linux_renderings.py')) {
        & wsl.exe -d $Distribution -- python3 "$linuxRoot/scripts/$verifier" $linuxOutput
        if ($LASTEXITCODE -ne 0) { throw "Verification failed: $configuration / $verifier" }
    }
}
