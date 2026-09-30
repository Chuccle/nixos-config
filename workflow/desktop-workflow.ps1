#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('preflight', 'build', 'adopt', 'verify', 'improve')][string]$Mode = 'preflight',
    [ValidateSet('both', 'tahoe', 'win95')][string]$Edition = 'both',
    [string]$Config = "$PSScriptRoot\config.json",
    [string]$CandidatePath,
    [string]$RunId,
    [string]$ReuseRunId,
    [switch]$Baseline
)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\Workflow.psm1" -Force
Invoke-DesktopWorkflow -Mode $Mode -Edition $Edition -ConfigPath $Config -CandidatePath $CandidatePath -RunId $RunId -ReuseRunId $ReuseRunId -Baseline:$Baseline
