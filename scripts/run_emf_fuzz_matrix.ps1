param(
    [ValidateRange(1,10000000)][int]$Iterations=10000,
    [uint32]$Seed=324508639,
    [ValidateRange(1,60000)][int]$CaseTimeoutMS=2000,
    [ValidateRange(1,86400)][int]$ProcessTimeoutSeconds=1800,
    [string]$OutputDirectory=''
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(!$OutputDirectory){$OutputDirectory=Join-Path $root 'tests\build\emf-fuzz-matrix'}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$OutputDirectory=(Resolve-Path -LiteralPath $OutputDirectory).Path
$matrix=@()
foreach($compiler in @('Delphi','FPC')){
    foreach($platform in @('win32','win64')){
        foreach($static in @($false,$true)){
            $name=$compiler.ToLowerInvariant()+'-'+$platform+$(if($static){'-static'}else{''})
            $directory=Join-Path $OutputDirectory $name
            $log=Join-Path $OutputDirectory ($name+'.log')
            $timer=[Diagnostics.Stopwatch]::StartNew()
            $passed=$false;$errorText=''
            Write-Host "Starting rendered EMF fuzz: $name / $Iterations mutations"
            try{
                $arguments=@{CompilerKind=$compiler;Platform=$platform;Static=$static;
                    Render=$true;Iterations=$Iterations;Seed=$Seed;CaseTimeoutMS=$CaseTimeoutMS;
                    ProcessTimeoutSeconds=$ProcessTimeoutSeconds;OutputDirectory=$directory;BuildRoot=(Join-Path $OutputDirectory 'build')}
                & (Join-Path $PSScriptRoot 'run_emf_fuzz.ps1') @arguments *> $log
                $passed=$true
            }catch{
                $errorText=($_ | Out-String)
                Add-Content -LiteralPath $log -Value $errorText
                # Keep processing all configurations. Failure of the matrix is reported last.
                Write-Host "FAILED: $name; saved diagnostics: $log"
            }
            $matrix+=@{configuration=$name;passed=$passed;iterations=$Iterations;seed=$Seed;
                elapsedSeconds=[math]::Round($timer.Elapsed.TotalSeconds,3);directory=$directory;
                log=$log;error=$errorText}
            ConvertTo-Json -InputObject @($matrix) -Depth 6 |
                Set-Content -LiteralPath (Join-Path $OutputDirectory 'matrix.json') -Encoding UTF8
        }
    }
}
$failures=@($matrix | Where-Object {!$_.passed}).Count
if($failures){throw "$failures of 8 rendered fuzz configurations failed; inspect $OutputDirectory\matrix.json"}
Write-Host 'PASS: all 8 rendered EMF fuzz configurations'
