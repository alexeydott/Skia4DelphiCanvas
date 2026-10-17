param([ValidateSet('all','win32','win64')][string]$Platform='all', [switch]$Static,
      [string]$FpcRoot='D:\fpc\fpc-3.3.1', [string]$Lazarus='D:\fpc\lazarus',
      [string]$Compiler='', [string]$StaticSkiaRoot='', [string]$SkiaDll='', [string]$BuildRoot='')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
foreach($arch in $(if($Platform -eq 'all'){@('win32','win64')}else{@($Platform)})) {
  $cpu=if($arch -eq 'win32'){'i386'}else{'x86_64'}
  $compilerPath=if($Compiler){$Compiler}else{Join-Path $FpcRoot "bin\$cpu-$arch\fpc.exe"}
  if([version]((& $compilerPath -iV | Select-Object -Last 1).Trim()) -lt [version]'3.3.1'){throw 'FPC 3.3.1 or later required'}
  $suffix=if($Static){'-static'}else{''}
  $out=if($BuildRoot){Join-Path ([IO.Path]::GetFullPath($BuildRoot)) "emf-fuzz-fpc-$arch$suffix"}else{Join-Path $root "tests\build\emf-fuzz-fpc-$arch$suffix"}
  New-Item -ItemType Directory -Force $out | Out-Null
  $paths=@("$root\src\fpc","$root\src\fpc\vendor","$root\src","$Lazarus\lcl","$Lazarus\lcl\forms","$Lazarus\lcl\widgetset","$Lazarus\lcl\interfaces\win32","$Lazarus\lcl\interfaces","$Lazarus\components\lazutils","$Lazarus\lcl\units\$cpu-$arch\win32","$Lazarus\lcl\units\$cpu-$arch","$Lazarus\components\lazutils\lib\$cpu-$arch")
  $options=@('-B','-Mdelphiunicode','-Cr','-Co','-gh','-gl','-O1',"-T$arch","-P$cpu",'-dLCL','-dLCLwin32','-dSTANDALONE',"-FU$out","-FE$out","-Fi$Lazarus\lcl\include")
  if($Static){
    $native=if($StaticSkiaRoot){(Resolve-Path -LiteralPath $StaticSkiaRoot).Path}else{Join-Path $root 'runtime\windows-static'}
    $stage=Join-Path $out 'static-bindings';New-Item -ItemType Directory -Force $stage | Out-Null
    $source=[IO.File]::ReadAllText("$native\Source\System.Skia.API.pas").Replace('../Binary/',($native.Replace('\','/')+'/Binary/'))
    [IO.File]::WriteAllText("$stage\System.Skia.API.pas",$source)
    $options+='-dSK_STATIC_LIBRARY';$paths=@($stage)+$paths
    if(Test-Path "$out\sk4d.dll"){throw 'Static output contains sk4d.dll'}
  }
  $options+=$paths | Where-Object {Test-Path -LiteralPath $_} | ForEach-Object {"-Fu$_"}
  & $compilerPath @options "$PSScriptRoot\EmfFuzz.dpr" *> "$out\compile.log"
  if($LASTEXITCODE -ne 0){Get-Content "$out\compile.log" -Tail 30;throw "FPC fuzz compilation failed: $arch"}
  if(!$Static){$dll=if($SkiaDll){$SkiaDll}else{"$root\runtime\$arch\sk4d.dll"};Copy-Item -LiteralPath $dll -Destination $out -Force}
  Write-Host "Built FPC $arch fuzz harness: $out\EmfFuzz.exe"
}
