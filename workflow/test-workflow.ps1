#Requires -Version 7.4
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\Workflow.psm1" -Force
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
Assert ((Get-Median @(9, 1, 3)) -eq 3) 'Odd median'
Assert ((Get-Median @(2, 4)) -eq 3) 'Even median'
$shell = (Get-Process -Id $PID).Path
$payload = 'spaces and "quotes"; literal $() and `backticks`'
$script = '[Console]::Out.Write($args[0]); [Console]::Error.Write("error stream")'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('desktop-test-' + [Guid]::NewGuid() + '.ps1')
try {
    $script | Set-Content -LiteralPath $temporary
    $result = Invoke-LoggedProcess $shell @('-NoProfile', '-File', $temporary, $payload) -TimeoutSeconds 20
    Assert ($result.stdout -eq $payload) 'Process arguments changed literal characters'
    Assert ($result.stderr -eq 'error stream') 'stderr missing'
    '[Console]::InputEncoding = [Text.Encoding]::UTF8; [Console]::OutputEncoding = [Text.Encoding]::UTF8; [Console]::Out.Write([Console]::In.ReadToEnd())' | Set-Content -LiteralPath $temporary
    $unicode = 'Windows 95 · £ € ✓'
    $result = Invoke-LoggedProcess $shell @('-NoProfile', '-File', $temporary) -InputText $unicode -TimeoutSeconds 20
    Assert ($result.stdout -eq $unicode) 'UTF-8 stdin changed review reference text'
    'Start-Sleep -Seconds 20' | Set-Content -LiteralPath $temporary
    $expired = $false
    try { Invoke-LoggedProcess $shell @('-NoProfile', '-File', $temporary) -TimeoutSeconds 1 | Out-Null } catch { $expired = $_.Exception.Message -match 'timeout' }
    Assert $expired 'Timeout failed to terminate the child process'
} finally { Remove-Item -LiteralPath $temporary -Force }
$module = Get-Module Workflow
$workflowConfig = Get-Content "$PSScriptRoot\config.json" -Raw | ConvertFrom-Json
$criteria = Get-Content "$PSScriptRoot\criteria.json" -Raw | ConvertFrom-Json
Assert ($workflowConfig.metricsTimeoutSeconds -ge ($workflowConfig.settleSeconds + $workflowConfig.sampleSeconds + 60)) 'Metrics timeout leaves too little time for evidence collection'
Assert ('ida-analysis-roundtrip' -in $criteria.functional.common) 'IDA functional analysis is not required for acceptance'
foreach ($edition in @('tahoe', 'win95')) {
    $ids = @($criteria.functional.common) + @($criteria.functional.$edition)
    Assert (($ids | Select-Object -Unique).Count -eq $ids.Count) "Functional acceptance duplicates an ID for $edition"
}
& $module {
    $script:Context = [pscustomobject]@{deadline=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToString('o')}
    $blocked = $false
    try { Invoke-LoggedProcess 'pwsh' @('-NoProfile', '-Command', 'exit 0') | Out-Null } catch { $blocked = $_.Exception.Message -match 'budget' }
    if (-not $blocked) { throw 'Expired run budget permitted new work' }
    try {
        Invoke-LoggedProcess 'pwsh' @('-NoProfile', '-Command', 'exit 0') -Cleanup -TimeoutSeconds 5 | Out-Null
    } finally { $script:Context = $null }
    if (@(Get-RepairEditions @('desktops/niri.mod.nix')).Count -ne 2) { throw 'Shared niri repair did not consume both edition budgets' }
    if (@(Get-RepairEditions @('shells/win95/Taskbar.qml')) -join ',' -ne 'win95') { throw 'Win95-only repair consumed the Tahoe budget' }
    $emptyJson = Join-Path ([IO.Path]::GetTempPath()) ('desktop-json-' + [Guid]::NewGuid() + '.json')
    try {
        Write-Json $emptyJson @()
        if ((Get-Content $emptyJson -Raw).Trim() -ne '[]') { throw 'Empty evidence list did not serialize as JSON array' }
        $jsonContents = [IO.File]::ReadAllText($emptyJson)
        if ($jsonContents.Contains("`r")) { throw 'Generated JSON retained Windows CRLF line endings' }
        if (-not $jsonContents.EndsWith("`n")) { throw 'Generated JSON omitted its final newline' }
    } finally { Remove-Item -LiteralPath $emptyJson -Force }
    $snapshot = Join-Path ([IO.Path]::GetTempPath()) ('desktop-source-' + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $snapshot | Out-Null
    try {
        $nixFile = Join-Path $snapshot 'embedded-shell.nix'
        [IO.File]::WriteAllText($nixFile, "runCommand ''`r`n  echo ok`r`n''`r`n", [Text.Encoding]::UTF8)
        Normalize-NixSnapshot $snapshot
        if ([IO.File]::ReadAllText($nixFile) -ne "runCommand ''`n  echo ok`n''`n") { throw 'Nix snapshot retained CRLF line endings' }

        $script:Settings = [pscustomobject]@{
            vmRoot = Join-Path $snapshot 'vms'
            vmrun = 'C:\Program Files\VMware\VMware Workstation\vmrun.exe'
            vmwareLeaseFiles = @()
        }
        $artifact = Join-Path $snapshot 'artifact'
        New-Item -ItemType Directory -Path $artifact | Out-Null
        $vmx = New-Guest ([pscustomobject]@{ edition = 'tahoe'; iso = 'C:\test.iso'; directory = $artifact })
        $vmxText = Get-Content -LiteralPath $vmx -Raw
        foreach ($line in @(
            'pciBridge0.present = "TRUE"',
            'pciBridge4.virtualDev = "pcieRootPort"',
            'pciBridge5.virtualDev = "pcieRootPort"',
            'pciBridge6.virtualDev = "pcieRootPort"',
            'pciBridge7.virtualDev = "pcieRootPort"',
            'ethernet0.pciSlotNumber = "160"'
        )) {
            if (-not $vmxText.Contains($line)) { throw "VMX omits PCIe layout setting: $line" }
        }
        [IO.File]::AppendAllText($vmx, "ethernet0.generatedAddress = `"00:0c:29:3e:55:8d`"`n")
        $leaseFile = Join-Path $snapshot 'vmnetdhcp.leases~'
        $leaseText = "lease 192.168.79.130 {`n starts 1 2026/09/28 22:13:20;`n hardware ethernet 00:0c:29:3e:55:8d;`n}`n"
        [IO.File]::WriteAllText($leaseFile, $leaseText, [Text.Encoding]::UTF8)
        $script:Settings.vmwareLeaseFiles = @($leaseFile)
        if ((Get-VmwareLeaseAddress $vmx) -ne '192.168.79.130') { throw 'VMware DHCP lease fallback did not resolve the generated MAC address' }
    } finally { Remove-Item -LiteralPath $snapshot -Recurse -Force }
    $script:Settings = [pscustomobject]@{ ramLimitGiB = 1.5; cpuLimitPercent = 2; readyLimitSeconds = 60; regressionPercent = 10; cpuTolerancePoints = 0.2 }
    $baseline = [pscustomobject]@{ ramBytes = 1GB; cpuPercent = 0.05; readySeconds = 20; hardwareRendering = $true }
    $passing = [pscustomobject]@{ ramBytes = 1.05GB; cpuPercent = 0.2; readySeconds = 21; hardwareRendering = $true }
    if (@(Compare-Performance $passing $baseline).Count) { throw 'CPU near-zero tolerance was rejected' }
    $passing.hardwareRendering = $false
    if ('hardware-rendering' -notin @(Compare-Performance $passing $baseline)) { throw 'Software renderer was accepted' }
    if ('baseline-unverified' -notin @(Compare-Performance $passing $null)) { throw 'Missing baseline was accepted' }

    $processDirectory = Join-Path ([IO.Path]::GetTempPath()) ('desktop-process-' + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $processDirectory | Out-Null
    try {
        $metrics = [pscustomobject]@{ processMemoryEvidence = 'process-memory.json' }
        if (Test-ProcessMemoryEvidence $processDirectory $metrics) { throw 'Missing process evidence was accepted' }
        Write-Json (Join-Path $processDirectory 'process-memory.json') @{ metric = 'VmRSS'; snapshots = @(@{ top = @(@{ name = 'niri'; rssBytes = 100 }) }); topProcesses = @(@{ name = 'niri'; peakRssBytes = 100 }) }
        if (-not (Test-ProcessMemoryEvidence $processDirectory $metrics)) { throw 'Valid process evidence was rejected' }
    } finally { Remove-Item -LiteralPath $processDirectory -Recurse -Force }
    $assessmentDirectory = Join-Path ([IO.Path]::GetTempPath()) ('desktop-assessment-' + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $assessmentDirectory | Out-Null
    try {
        $script:RunDirectory = $assessmentDirectory
        $script:Context = [pscustomobject]@{ candidates = @(); baselines = @() }
        $script:Settings | Add-Member -NotePropertyName confirmBoots -NotePropertyValue 3
        $boots = @(1..3 | ForEach-Object { [pscustomobject]@{ boot = $_; directory = Join-Path $assessmentDirectory "boot-$_"; metrics = $passing; functional = $null; visual = $null; error = $null } })
        $candidate = [pscustomobject]@{ baseline = $true; directory = $assessmentDirectory; verification = $boots; accepted = $false; failedCount = 999 }
        Update-CandidateAssessment $candidate | Out-Null
        $assessment = Get-Content (Join-Path $assessmentDirectory 'verification.json') -Raw | ConvertFrom-Json
        if ($candidate.failedCount -ne 3 -or @($assessment.failed).Count -ne 3) { throw 'Failure IDs were concatenated instead of counted separately' }
        Write-Json (Join-Path $assessmentDirectory 'criteria.json') @{ common = @('readable-text'); tahoe = @() }
        New-Item -ItemType Directory -Path (Join-Path $assessmentDirectory 'references'), (Join-Path $assessmentDirectory 'fixture') | Out-Null
        Write-Json (Join-Path $assessmentDirectory 'references\manifest.json') @(@{id='reference'; edition='tahoe'})
        [IO.File]::WriteAllText((Join-Path $assessmentDirectory 'fixture\readme.txt'), 'fixture')
        $review = [pscustomobject]@{ checks = @([pscustomobject]@{id='readable-text'; status='pass'; candidateEvidence=@('fixture/readme.txt'); referenceIds=@('reference')}) }
        Assert-VisualReview ([pscustomobject]@{edition='tahoe'}) $assessmentDirectory $review | Out-Null
        foreach ($invalidEvidence in @('../readme.txt', 'C:\outside.txt', 'fixture/missing.txt')) {
            $review.checks[0].candidateEvidence = @($invalidEvidence)
            $rejected = $false
            try { Assert-VisualReview ([pscustomobject]@{edition='tahoe'}) $assessmentDirectory $review | Out-Null } catch { $rejected = $true }
            if (-not $rejected) { throw "Invalid review evidence was accepted: $invalidEvidence" }
        }
    } finally {
        $script:Context = $null
        $script:RunDirectory = $null
        Remove-Item -LiteralPath $assessmentDirectory -Recurse -Force
    }
}
& (Get-Module Workflow) {
    $root = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('desktop-reuse-' + [Guid]::NewGuid())))
    $source = Join-Path $root 'prior\source'
    $script:RunDirectory = Join-Path $root 'current'
    New-Item -ItemType Directory -Path $source, $script:RunDirectory | Out-Null
    try {
        $iso = Join-Path $root 'prior\baseline.iso'
        [IO.File]::WriteAllText($iso, 'baseline fixture')
        [IO.File]::WriteAllText((Join-Path $source 'fixture.txt'), 'source fixture')
        $manifest = Join-Path $source 'source-hashes.json'
        Write-Json $manifest @{ files = Get-SourceManifest $source }
        $baseline = @{ edition = 'tahoe'; baseline = $true; label = 'baseline'; iso = $iso; sha256 = (Get-FileHash $iso).Hash.ToLowerInvariant(); source = $source; sourceManifestHash = (Get-FileHash $manifest).Hash; storePath = '/nix/store/fixture' }
        Write-Json (Join-Path $root 'prior\run.json') @{ baselines = @($baseline); candidates = @(@{ edition = 'tahoe' }); criteriaHash = 'old'; configHash = 'old'; referencesDefinitionHash = 'old' }
        $script:Settings = [pscustomobject]@{ artifactRoot = $root }
        $script:Context = [pscustomobject]@{ baselines = @(); candidates = @(); criteriaHash = 'new'; configHash = 'new'; referencesDefinitionHash = 'new' }
        Import-RunArtifacts 'prior' @('tahoe') -BaselineOnly
        if ($script:Context.candidates.Count -or $script:Context.baselines.Count -ne 1) { throw 'Baseline reuse imported candidate artifacts' }
        if ($script:Context.baselines[0].verification.Count -or $script:Context.baselines[0].accepted) { throw 'Baseline reuse copied prior acceptance' }
        $rejected = $false
        try { Import-RunArtifacts 'prior' @('tahoe') } catch { $rejected = $_.Exception.Message -match 'different frozen' }
        if (-not $rejected) { throw 'Candidate adoption accepted changed criteria' }
        [IO.File]::WriteAllText((Join-Path $source 'fixture.txt'), 'changed source')
        $rejected = $false
        try { Import-RunArtifacts 'prior' @('tahoe') -BaselineOnly } catch { $rejected = $_.Exception.Message -match 'source file changed' }
        if (-not $rejected) { throw 'Baseline reuse accepted modified source' }
    } finally {
        $script:Context = $null
        $script:RunDirectory = $null
        if (-not $root.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected test directory' }
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
foreach ($file in Get-ChildItem $PSScriptRoot -Include '*.ps1', '*.psm1' -Recurse) {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    Assert (-not $errors.Count) "PowerShell syntax errors: $errors"
}
Write-Host 'Workflow host tests passed.'
