param([ValidateSet('all','win32','win64')][string]$Platform='all', [switch]$Static,
      [string]$CompilerRoot='D:\Embarcadero RAD Studio\23.0', [string]$StaticSkiaRoot='', [string]$SkiaDll='', [string]$BuildRoot='')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
foreach($arch in $(if($Platform -eq 'all'){@('win32','win64')}else{@($Platform)})) {
  $suffix=if($Static){'-static'}else{''}
  $out=if($BuildRoot){Join-Path ([IO.Path]::GetFullPath($BuildRoot)) "emf-fuzz-delphi-$arch$suffix"}else{Join-Path $root "tests\build\emf-fuzz-delphi-$arch$suffix"}
  New-Item -ItemType Directory -Force $out | Out-Null
  $unitPaths="$root\src\fpc\vendor;$root\src;$CompilerRoot\lib\$arch\release"
  $options=@('-B','-$R+','-$Q+','-$C+','-NSSystem;Winapi;Vcl',"-E$out","-N0$out")
  if($Static){
    $native=if($StaticSkiaRoot){(Resolve-Path -LiteralPath $StaticSkiaRoot).Path}else{Join-Path $root 'runtime\windows-static'}
    $stage=Join-Path $out 'static-bindings';New-Item -ItemType Directory -Force $stage | Out-Null
    $source=[IO.File]::ReadAllText("$native\Source\System.Skia.API.pas").Replace('../Binary/',($native.Replace('\','/')+'/Binary/'))
    [IO.File]::WriteAllText("$stage\System.Skia.API.pas",$source)
    $options+='-DSK_STATIC_LIBRARY';$unitPaths="$stage;$unitPaths"
    if(Test-Path "$out\sk4d.dll"){throw 'Static output contains sk4d.dll'}
  }
  $options+="-U$unitPaths"
  $dcc=if($arch -eq 'win32'){'dcc32.exe'}else{'dcc64.exe'}
  & "$CompilerRoot\bin\$dcc" @options "$PSScriptRoot\EmfFuzz.dpr" *> "$out\compile.log"
  if($LASTEXITCODE -ne 0){Get-Content "$out\compile.log" -Tail 30;throw "Delphi fuzz compilation failed: $arch$suffix"}
  if(!$Static){$dll=if($SkiaDll){$SkiaDll}else{"$root\runtime\$arch\sk4d.dll"};Copy-Item -LiteralPath $dll -Destination $out -Force}
  Write-Host "Built Delphi $arch$suffix fuzz harness: $out\EmfFuzz.exe"
}
