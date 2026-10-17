param(
    [Parameter(Mandatory=$true)][ValidateSet('Delphi','FPC')][string]$CompilerKind,
    [Parameter(Mandatory=$true)][ValidateSet('win32','win64')][string]$Platform,
    [switch]$Static,
    [string]$CompilerRoot='D:\Embarcadero RAD Studio\23.0',
    [string]$Compiler='', [string]$Lazarus='D:\fpc\lazarus',
    [string]$StaticSkiaRoot='', [string]$SkiaDll='',
    [string]$OutputDirectory='', [string]$BuildRoot='',
    [ValidateRange(1,86400)][int]$ProcessTimeoutSeconds=300,
    [switch]$Render,
    [ValidateRange(0,10000000)][int]$Iterations=300,
    [uint32]$Seed=324508639,
    [ValidateRange(1,60000)][int]$CaseTimeoutMS=2000
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$fuzz=Join-Path $root 'tests\fuzz'
$python=if($env:SKIA_PYTHON){$env:SKIA_PYTHON}else{'python'}
$kind=$CompilerKind.ToLowerInvariant()
$suffix=if($Static){'-static'}else{''}
$configuration="$kind-$Platform$suffix"
$build=if($BuildRoot){$BuildRoot=[IO.Path]::GetFullPath($BuildRoot);Join-Path $BuildRoot "emf-fuzz-$configuration"}else{Join-Path $root "tests\build\emf-fuzz-$configuration"}
if(!$OutputDirectory){$OutputDirectory=Join-Path $build 'results'}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$OutputDirectory=(Resolve-Path -LiteralPath $OutputDirectory).Path

# Each generator version owns a cache; an exclusive lock protects concurrent builds.
$generator=Join-Path $fuzz 'gen_emf_corpus.py'
$types=Join-Path $root 'tests\fixtures\emf-record-types.json'
function FileDigest([string]$Path){
    $hasher=[Security.Cryptography.SHA256]::Create()
    $inputStream=[IO.File]::OpenRead($Path)
    try{[BitConverter]::ToString($hasher.ComputeHash($inputStream)).Replace('-','')}
    finally{$inputStream.Dispose();$hasher.Dispose()}
}
$stamp=(FileDigest $generator)+(FileDigest $types)
$sha=[Security.Cryptography.SHA256]::Create()
try{$cacheKey=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stamp))).Replace('-','').Substring(0,12)}finally{$sha.Dispose()}
$corpus=Join-Path $root ('tests\build\emf-fuzz-corpus-'+$cacheKey)
$lockPath="$corpus.lock"
$cacheLock=$null
$watch=[Diagnostics.Stopwatch]::StartNew()
while($null -eq $cacheLock){
    try{$cacheLock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
    catch [IO.IOException]{if($watch.Elapsed.TotalSeconds -gt 60){throw};Start-Sleep -Milliseconds 100}
}
try{
    $complete=Join-Path $corpus 'complete.txt'
    if(!(Test-Path -LiteralPath $complete) -or [IO.File]::ReadAllText($complete) -ne $stamp){
        & $python $generator --out $corpus
        if($LASTEXITCODE -ne 0){throw 'EMF fuzz corpus generation failed'}
        if(@(Get-ChildItem -LiteralPath $corpus -Filter '*.emf').Count -ne 2100){throw 'Expected 2100 generated EMFs'}
        [IO.File]::WriteAllText($complete,$stamp)
    }
}finally{$cacheLock.Dispose()}

$arguments=@{Platform=$Platform;Static=$Static;BuildRoot=$BuildRoot;StaticSkiaRoot=$StaticSkiaRoot;SkiaDll=$SkiaDll}
if($CompilerKind -eq 'Delphi'){
    & (Join-Path $fuzz 'build_fuzz_delphi.ps1') @arguments -CompilerRoot $CompilerRoot
}else{
    & (Join-Path $fuzz 'build_fuzz_fpc.ps1') @arguments -Compiler $Compiler -Lazarus $Lazarus
}
$exe=Join-Path $build 'EmfFuzz.exe'
if($Static){
    & $python (Join-Path $PSScriptRoot 'verify_static_skia.py') $exe
    if($LASTEXITCODE -ne 0){throw 'Fuzz executable depends on the Skia DLL'}
}
$regressions=Join-Path $fuzz 'regress'
$stages=@(
    @{Name='corpus';Count=2100;Args=@('--corpus',$corpus,'--iterations','0')},
    @{Name='regress';Count=@(Get-ChildItem -LiteralPath $regressions -Filter '*.emf').Count;Args=@('--regress',$regressions)},
    @{Name=$(if($Iterations -eq 300){'smoke'}else{'random'});Count=$Iterations+1;Args=@('--seed',"$Seed",'--iterations',"$Iterations")}
)
$results=@()
$oldHeap=$env:HEAPTRC
$oldPath=$env:PATH
try{
    $env:HEAPTRC='haltonnotreleased'
    if($Static){$env:PATH="$env:SystemRoot\System32;$env:SystemRoot"}
    foreach($stage in $stages){
        if($stage.Count -eq 0){throw 'No fuzz regressions found'}
        $output=Join-Path $OutputDirectory $stage.Name
        New-Item -ItemType Directory -Force $output | Out-Null
        foreach($name in @('current.emf','current.txt','stage.txt')){Remove-Item -LiteralPath (Join-Path $output $name) -ErrorAction SilentlyContinue}
        $stdout=Join-Path $output 'stdout.log';$stderr=Join-Path $output 'stderr.log'
        $params=@($stage.Args)+@('--out',$output,'--case-timeout',"$CaseTimeoutMS")
        if($Render){$params+=@('--render','--trace-stages')}
        $quoted=($params | ForEach-Object {'"'+$_+'"'}) -join ' '
        $startInfo=New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName=$exe;$startInfo.Arguments=$quoted
        $startInfo.UseShellExecute=$false;$startInfo.CreateNoWindow=$true
        $startInfo.RedirectStandardOutput=$true;$startInfo.RedirectStandardError=$true
        $phaseWatch=[Diagnostics.Stopwatch]::StartNew()
        $process=[Diagnostics.Process]::Start($startInfo)
        $stdoutTask=$process.StandardOutput.ReadToEndAsync()
        $stderrTask=$process.StandardError.ReadToEndAsync()
        $timedOut=!$process.WaitForExit($ProcessTimeoutSeconds*1000)
        if($timedOut){if(!$process.HasExited){$process.Kill()};$process.WaitForExit()}
        $text=$stdoutTask.Result
        [IO.File]::WriteAllText($stdout,$text)
        [IO.File]::WriteAllText($stderr,$stderrTask.Result)
        $exitCode=$process.ExitCode;$process.Dispose()
        $match=[regex]::Match($text,'cases=(\d+) rejected-by-GDI=(\d+) parsed=(\d+) expected-rejections=(\d+) failures=(\d+) hangs=(\d+)')
        $passed=(!$timedOut) -and ($exitCode -eq 0) -and $match.Success -and
                ([int]$match.Groups[1].Value -eq $stage.Count) -and
                ([int]$match.Groups[5].Value -eq 0) -and ([int]$match.Groups[6].Value -eq 0)
        $renderMatch=[regex]::Match($text,'rendered=(\d+) replayed=(\d+)')
        $rendered=if($renderMatch.Success){[int]$renderMatch.Groups[1].Value}else{0}
        $replayed=if($renderMatch.Success){[int]$renderMatch.Groups[2].Value}else{0}
        if($Render -and $stage.Name -in @('smoke','random') -and ($rendered -eq 0 -or $replayed -eq 0)){$passed=$false}
        $findings=@(Get-ChildItem -LiteralPath (Join-Path $output 'crashes') -Filter '*.txt' -ErrorAction SilentlyContinue | ForEach-Object {$_.FullName})
        $results+=@{elapsedSeconds=[math]::Round($phaseWatch.Elapsed.TotalSeconds,3);rendered=$rendered;replayed=$replayed;findings=$findings;stage=$stage.Name;passed=$passed;expectedCases=$stage.Count;exitCode=$exitCode;timeout=$timedOut;caseTimeout=($exitCode -eq 3);render=[bool]$Render;seed=$Seed;summary=$match.Value;directory=$output}
        ConvertTo-Json -InputObject @($results) -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'results.json') -Encoding UTF8
        if(!$passed){
            $crashes=Join-Path $output 'crashes';New-Item -ItemType Directory -Force $crashes | Out-Null
            foreach($name in @('current.emf','current.txt','stage.txt')){
                $current=Join-Path $output $name
                if(Test-Path -LiteralPath $current){Copy-Item -LiteralPath $current -Destination (Join-Path $crashes $name) -Force}
            }
            "Process exit=$($exitCode); timeout=$timedOut; arguments=$quoted" | Set-Content -LiteralPath (Join-Path $crashes 'process.txt')
            Get-Content -LiteralPath $stdout -Tail 12
            Get-Content -LiteralPath $stderr -Tail 12
            throw "EMF fuzz failed: $configuration / $($stage.Name); reproduction: $crashes"
        }
        Write-Host "PASS: EMF fuzz $configuration / $($stage.Name): $($match.Value)"
    }
}finally{$env:HEAPTRC=$oldHeap;$env:PATH=$oldPath}
