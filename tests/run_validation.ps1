param([Parameter(Mandatory = $true)][string]$GodotExe, [string]$RunLabel = 'm16')

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
$taskSuites = @('validate_simulation', 'validate_combat', 'validate_interceptor', 'validate_demo_controls', 'validate_cinematic', 'validate_dynamic_space', 'validate_capital_artillery', 'validate_guided_demonstration', 'validate_hazard_spectacle', 'validate_targeted_evasion', 'validate_threat_choreography', 'validate_arcade_hazards', 'validate_final_study')
$taskResults = @()
foreach ($taskName in $taskSuites) {
    $taskLog = ".godot/${taskName}_${RunLabel}_final.log"
    $taskStarted = Get-Date
    $taskProcess = Start-Process -FilePath $GodotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script',"res://tests/${taskName}.gd",'--log-file',$taskLog -WindowStyle Hidden -PassThru -Wait
    $taskText = Get-Content -LiteralPath $taskLog -Raw
    $taskPassed = $taskProcess.ExitCode -eq 0 -and $taskText.Contains('PASS') -and -not [regex]::IsMatch($taskText, '(?m)^(ERROR:|SCRIPT ERROR:|WARNING:|FAIL)')
    $taskResults += [pscustomobject]@{ name=$taskName; passed=$taskPassed; exit_code=$taskProcess.ExitCode; seconds=((Get-Date)-$taskStarted).TotalSeconds }
    $taskResults | ConvertTo-Json | Set-Content -LiteralPath ".godot/${RunLabel}_suite_results.json" -Encoding utf8
    Write-Output "$taskName : passed=$taskPassed exit=$($taskProcess.ExitCode)"
    if (-not $taskPassed) { Get-Content -LiteralPath $taskLog -Tail 45; exit 1 }
}
Write-Output 'PASS : treize suites M1–M16.'
