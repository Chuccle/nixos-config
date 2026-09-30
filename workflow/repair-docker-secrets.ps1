#Requires -Version 7.4
[CmdletBinding()]
param([string]$EvidencePath)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\Workflow.psm1" -Force

$result = [ordered]@{ status = 'unverified'; checkedAt = [DateTimeOffset]::UtcNow.ToString('o') }
try {
    $probe = Invoke-LoggedProcess 'docker' @('info', '--format', '{{.ServerVersion}}') -TimeoutSeconds 20 -AllowFailure
    if ($probe.exitCode -eq 0) {
        $result.status = 'healthy'
        $result.serverVersion = $probe.stdout.Trim()
    } else {
        $logRoot = Join-Path $env:LOCALAPPDATA 'Docker\log\host'
        $logs = @(Get-ChildItem -LiteralPath $logRoot -File -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 12)
        $signature = 'docker-secrets-engine.*engine\.sock.*(cannot be accessed|1920)'
        $failureLines = @($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Tail 300 } | Where-Object { $_ -match $signature })
        if (-not $failureLines.Count) { throw 'Engine unavailable without the recognized Secrets Engine socket failure; automatic directory recovery is inapplicable.' }
        $result.failureSignature = 'Secrets Engine orphaned AF_UNIX socket / ERROR_CANT_ACCESS_FILE'
        Invoke-LoggedProcess 'docker' @('desktop', 'stop', '--timeout', '60') -TimeoutSeconds 70 | Out-Null
        $stopDeadline = [DateTimeOffset]::UtcNow.AddSeconds(30)
        while (Get-Process -Name 'com.docker.backend' -ErrorAction SilentlyContinue) {
            if ([DateTimeOffset]::UtcNow -gt $stopDeadline) { throw 'Docker backend remains active; refusing socket-directory recovery.' }
            Start-Sleep -Seconds 1
        }
        $localRoot = [IO.Path]::GetFullPath($env:LOCALAPPDATA)
        $socketDirectory = [IO.Path]::GetFullPath((Join-Path $localRoot 'docker-secrets-engine'))
        if ([IO.Path]::GetDirectoryName($socketDirectory) -ne $localRoot) { throw 'Socket directory escaped the expected local application directory.' }
        $directory = Get-Item -LiteralPath $socketDirectory
        if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Socket parent is a reparse point; refusing to rename it.' }
        $contents = @(Get-ChildItem -LiteralPath $socketDirectory -Force)
        if (-not $contents.Count -or @($contents | Where-Object { $_.PSIsContainer -or $_.Name -notmatch '^engine\.sock(?:\.stale)?$' }).Count) { throw 'Socket directory contains unexpected files; leaving it intact.' }
        $preservedName = 'docker-secrets-engine.recovered-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff')
        Rename-Item -LiteralPath $socketDirectory -NewName $preservedName
        $result.preservedDirectory = Join-Path $localRoot $preservedName
        Invoke-LoggedProcess 'docker' @('desktop', 'start', '--timeout', '120') -TimeoutSeconds 130 | Out-Null
        $probe = Invoke-LoggedProcess 'docker' @('info', '--format', '{{.ServerVersion}}') -TimeoutSeconds 30
        $result.status = 'recovered'
        $result.serverVersion = $probe.stdout.Trim()
    }
} catch {
    $result.status = 'failed'
    $result.reason = $_.Exception.Message
} finally {
    $json = $result | ConvertTo-Json -Depth 5
    if ($EvidencePath) { [IO.File]::WriteAllText([IO.Path]::GetFullPath($EvidencePath), $json + "`n", [Text.UTF8Encoding]::new($false)) }
    $json
}
if ($result.status -eq 'failed') { exit 1 }
