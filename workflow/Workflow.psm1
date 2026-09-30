Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Nix = '/nix/var/nix/profiles/default/bin/nix'
$script:Context = $null
$script:LogDirectory = $null
$script:SourceItems = @('adapters', 'desktops', 'dev', 'hosts', 'lib', 'modules', 'options', 'packages', 'shells', 'themes', 'flake.nix', 'flake.lock', 'statix.toml', 'STYLE_GUIDE.md')

function Write-Json($Path, $Value) {
    $json = ConvertTo-Json -InputObject $Value -Depth 100
    $json = $json.Replace("`r`n", "`n").Replace("`r", "`n")
    if (-not $json.EndsWith("`n")) { $json += "`n" }
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Get-SourceManifest($Root) {
    $result = [ordered]@{}
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
        if ($relative -eq 'source-hashes.json') { continue }
        $result[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    return $result
}

function Assert-Budget {
    if (-not $script:Context) { return }
    $deadlineValue = $script:Context.deadline
    $deadline = if ($deadlineValue -is [DateTime]) {
        [DateTimeOffset]$deadlineValue
    } elseif ($deadlineValue -is [DateTimeOffset]) {
        $deadlineValue
    } else {
        [DateTimeOffset]::Parse([string]$deadlineValue, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
    }
    if ([DateTimeOffset]::UtcNow -gt $deadline) { throw 'The frozen run time budget is exhausted.' }
}

function Invoke-LoggedProcess {
    [CmdletBinding()]
    param(
        [string]$File,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 120,
        [string]$InputText,
        [string]$WorkingDirectory,
        [switch]$AllowFailure,
        [switch]$Cleanup,
        [string]$LogName = 'command'
    )
    if (-not $Cleanup) { Assert-Budget }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $File
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.RedirectStandardInput = $true
    $info.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $info.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    if ($WorkingDirectory) { $info.WorkingDirectory = $WorkingDirectory }
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "Cannot start $File" }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if ($InputText) { $process.StandardInput.Write($InputText) }
    $process.StandardInput.Close()
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $nextUpdate = 30
    $expired = $false
    try {
        while (-not $process.WaitForExit(500)) {
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) { $expired = $true; break }
            if (-not $Cleanup) { Assert-Budget }
            if ($watch.Elapsed.TotalSeconds -ge $nextUpdate) {
                Write-Host "$LogName is running ($([int]$watch.Elapsed.TotalSeconds)s)."
                $nextUpdate += 30
            }
        }
    } finally {
        if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    }
    $result = [pscustomobject]@{ exitCode = $process.ExitCode; stdout = $stdout.GetAwaiter().GetResult(); stderr = $stderr.GetAwaiter().GetResult(); seconds = $watch.Elapsed.TotalSeconds }
    if ($script:LogDirectory) {
        $prefix = Join-Path $script:LogDirectory ("{0}-{1}" -f [DateTime]::UtcNow.ToString('HHmmssfff'), $LogName)
        $result.stdout | Set-Content "$prefix.stdout.txt"
        $result.stderr | Set-Content "$prefix.stderr.txt"
        Write-Json "$prefix.json" @{ file = $File; arguments = $Arguments; exitCode = $result.exitCode; seconds = $result.seconds; timeout = $expired }
    }
    if ($expired) { throw "$LogName exceeded its $TimeoutSeconds second timeout." }
    if ($result.exitCode -ne 0 -and -not $AllowFailure) { throw "$LogName failed ($($result.exitCode)): $($result.stderr) $($result.stdout)" }
    return $result
}

function Invoke-Docker([string[]]$Arguments, [int]$TimeoutSeconds = 120, [switch]$AllowFailure) {
    Invoke-LoggedProcess -File 'docker' -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds -AllowFailure:$AllowFailure -LogName 'docker'
}

function Start-Builder {
    $image = Invoke-Docker @('image', 'inspect', 'nixos-config_devcontainer-devcontainer:latest', '--format', '{{.Id}}') -AllowFailure
    $buildOption = if ($image.exitCode -eq 0) { '--no-build' } else { '--build' }
    $startupTimeout = if ($image.exitCode -eq 0) { 180 } else { $script:Settings.buildTimeoutMinutes * 60 }
    Invoke-Docker @('compose', '-f', "$script:ControllerRepository\.devcontainer\docker-compose.yml", '-p', $script:Settings.composeProject, 'up', '-d', $buildOption) -TimeoutSeconds $startupTimeout | Out-Null
    $ready = $false
    for ($attempt = 1; $attempt -le 15; $attempt++) {
        $probe = Invoke-Docker @('exec', '-e', 'HOME=/root', '-e', 'NIX_REMOTE=daemon', '-e', "NIX_STATE_DIR=$($script:Settings.nixStateDir)", $script:Settings.container, $script:Nix, 'store', 'info', '--store', 'daemon') -TimeoutSeconds 15 -AllowFailure
        if ($probe.exitCode -eq 0) { $ready = $true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { throw "Nix daemon did not become ready after container start: $($probe.stderr)" }
}

function Stop-Builder {
    # Stopping the container also cancels any client/child left after a timeout.
    $stopped = Invoke-LoggedProcess 'docker' @('stop', '--time', '10', $script:Settings.container) -TimeoutSeconds 40 -AllowFailure -Cleanup -LogName 'docker-stop'
    if ($stopped.exitCode -ne 0) {
        if (Get-Process 'com.docker.backend' -ErrorAction SilentlyContinue) { throw "Docker backend is present but its builder could not be stopped: $($stopped.stderr)" }
    }
}

function Get-LinuxPath([string]$Path) {
    $projects = [IO.Path]::GetFullPath((Join-Path $script:ControllerRepository '..'))
    $absolute = [IO.Path]::GetFullPath($Path)
    $relative = [IO.Path]::GetRelativePath($projects, $absolute)
    if ($relative.StartsWith('..') -or [IO.Path]::IsPathRooted($relative)) { throw "Docker path must be beneath $projects : $absolute" }
    return '/workspaces/' + $relative.Replace('\', '/')
}

function Initialize-Run($ConfigPath, $RunId, $Edition, $CandidatePath) {
    $script:ControllerRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $script:Settings = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $script:Repository = if ($CandidatePath) { [IO.Path]::GetFullPath($CandidatePath) } else { [IO.Path]::GetFullPath($script:Settings.candidateRoot) }
    if ($script:Settings.maxRepairs -gt 3 -or $script:Settings.maxHours -gt 6 -or $script:Settings.maxRepairs -lt 0) { throw 'Repair limits must stay within three attempts and six hours.' }
    if ($script:Settings.confirmBoots -lt 3 -or $script:Settings.sampleSeconds -lt 120 -or $script:Settings.settleSeconds -lt 60) { throw 'Acceptance requires three boots, 60 seconds settling and 120 seconds sampling.' }
    New-Item -ItemType Directory -Force -Path $script:Settings.artifactRoot | Out-Null
    if ($RunId -and $RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid run ID.' }
    if (-not $RunId) { $RunId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') }
    if ($script:Settings.metricsTimeoutSeconds -lt ($script:Settings.settleSeconds + $script:Settings.sampleSeconds + 60)) { throw 'Metrics timeout must include settling, sampling, and at least 60 seconds for evidence collection.' }
    $script:RunDirectory = Join-Path $script:Settings.artifactRoot $RunId
    $script:LogDirectory = Join-Path $script:RunDirectory 'logs'
    New-Item -ItemType Directory -Force -Path $script:LogDirectory | Out-Null
    $contextPath = Join-Path $script:RunDirectory 'run.json'
    if (Test-Path -LiteralPath $contextPath) {
        $script:Context = Get-Content $contextPath -Raw | ConvertFrom-Json
        $script:Settings = Get-Content "$script:RunDirectory\config.json" -Raw | ConvertFrom-Json
        if ((Get-FileHash "$script:RunDirectory\criteria.json").Hash -ne $script:Context.criteriaHash) { throw 'Frozen acceptance criteria changed.' }
        if ((Get-FileHash "$script:RunDirectory\config.json").Hash -ne $script:Context.configHash) { throw 'Frozen budgets/configuration changed.' }
        if ((Get-FileHash "$script:RunDirectory\references.json").Hash -ne $script:Context.referencesDefinitionHash) { throw 'Frozen reference definitions changed.' }
        if ((Get-FileHash "$script:RunDirectory\visual-review.schema.json").Hash -ne $script:Context.reviewSchemaHash) { throw 'Frozen review schema changed.' }
    } else {
        Copy-Item -LiteralPath $ConfigPath -Destination "$script:RunDirectory\config.json"
        Copy-Item -LiteralPath "$PSScriptRoot\criteria.json" -Destination "$script:RunDirectory\criteria.json"
        Copy-Item -LiteralPath "$PSScriptRoot\references.json" -Destination "$script:RunDirectory\references.json"
        Copy-Item -LiteralPath "$PSScriptRoot\visual-review.schema.json" -Destination "$script:RunDirectory\visual-review.schema.json"
        $script:Context = [pscustomobject]@{
            id = $RunId; started = [DateTimeOffset]::UtcNow.ToString('o'); deadline = [DateTimeOffset]::UtcNow.AddHours($script:Settings.maxHours).ToString('o')
            criteriaHash = (Get-FileHash "$script:RunDirectory\criteria.json").Hash
            referencesDefinitionHash = (Get-FileHash "$script:RunDirectory\references.json").Hash
            reviewSchemaHash = (Get-FileHash "$script:RunDirectory\visual-review.schema.json").Hash
            referencesHash = $null
            configHash = (Get-FileHash "$script:RunDirectory\config.json").Hash
            edition = $Edition; candidates = @(); baselines = @(); repairs = @{ tahoe = 0; win95 = 0 }; failures = @(); status = 'running'
        }
        Save-Run
    }
    Write-Host "Run $RunId; evidence: $script:RunDirectory"
}

function Get-ReferenceEvidence {
    $referenceDirectory = Join-Path $script:RunDirectory 'references'
    $manifestPath = Join-Path $referenceDirectory 'manifest.json'
    if (Test-Path -LiteralPath $manifestPath) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        foreach ($item in $manifest) {
            $path = Join-Path $referenceDirectory $item.file
            if (-not (Test-Path -LiteralPath $path)) { throw "Frozen reference is missing: $($item.id)" }
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.sha256) { throw "Frozen reference changed: $($item.id)" }
        }
        $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
        if ($script:Context.PSObject.Properties['referencesHash'] -and $script:Context.referencesHash -and $script:Context.referencesHash -ne $manifestHash) { throw 'Frozen reference manifest changed.' }
        $script:Context | Add-Member -NotePropertyName referencesHash -NotePropertyValue $manifestHash -Force
        Save-Run
        return $manifest
    }

    New-Item -ItemType Directory -Force -Path $referenceDirectory | Out-Null
    $definitions = Get-Content "$script:RunDirectory\references.json" -Raw | ConvertFrom-Json
    $manifest = @()
    foreach ($definition in $definitions) {
        Assert-Budget
        $uri = [Uri]$definition.url
        $extension = [IO.Path]::GetExtension($uri.AbsolutePath)
        if (-not $extension) { $extension = if ($definition.kind -eq 'image') { '.img' } else { '.html' } }
        $fileName = "$($definition.id)$extension"
        $path = Join-Path $referenceDirectory $fileName
        $response = Invoke-WebRequest -Uri $definition.url -OutFile $path -PassThru -MaximumRedirection 10 -Headers @{ 'User-Agent' = 'nixos-desktop-inspection/1.0' }
        $contentType = [string]$response.Headers.'Content-Type'
        if ($definition.kind -eq 'image' -and $contentType -notmatch '^image/') { throw "Reference $($definition.id) did not return an image: $contentType" }
        $width = $null
        $height = $null
        if ($definition.kind -eq 'image') {
            Add-Type -AssemblyName System.Drawing.Common
            $image = [Drawing.Image]::FromFile($path)
            try { $width = $image.Width; $height = $image.Height } finally { $image.Dispose() }
            if ($width -lt 320 -or $height -lt 200) { throw "Reference $($definition.id) is too small for UX review: ${width}x${height}" }
        }
        $manifest += [pscustomobject]@{
            id = $definition.id
            edition = $definition.edition
            kind = $definition.kind
            official = [bool]$definition.official
            focus = $definition.focus
            sourcePage = if ($definition.PSObject.Properties['sourcePage']) { $definition.sourcePage } else { '' }
            requestedUrl = $definition.url
            finalUrl = [string]$response.BaseResponse.RequestMessage.RequestUri
            retrievedAt = [DateTimeOffset]::UtcNow.ToString('o')
            contentType = $contentType
            width = $width
            height = $height
            file = $fileName
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    Write-Json $manifestPath $manifest
    $script:Context | Add-Member -NotePropertyName referencesHash -NotePropertyValue (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -Force
    Save-Run
    return $manifest
}

function Save-Run {
    Write-Json "$script:RunDirectory\run.json" $script:Context
}

function Normalize-NixSnapshot([string]$Source) {
    $utf8WithoutBom = [Text.UTF8Encoding]::new($false)
    foreach ($nixFile in Get-ChildItem -LiteralPath $Source -Filter '*.nix' -Recurse -File) {
        $contents = [IO.File]::ReadAllText($nixFile.FullName)
        $normalized = $contents.Replace("`r`n", "`n").Replace("`r", "`n")
        if ($normalized -cne $contents) { [IO.File]::WriteAllText($nixFile.FullName, $normalized, $utf8WithoutBom) }
    }
}

function Set-DockerResourceSaverTimeout {
    $settingsPath = Join-Path $env:APPDATA 'Docker\settings-store.json'
    if (-not (Test-Path -LiteralPath $settingsPath)) { throw "Docker Desktop settings are missing: $settingsPath" }
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json -AsHashtable
    if ($settings.Contains('useResourceSaver') -and $settings.useResourceSaver -eq $false) { return }
    $minimum = [int]($script:Settings.maxHours * 3600 + 3600)
    if ($settings.Contains('autoPauseTimeoutSeconds') -and [int]$settings.autoPauseTimeoutSeconds -ge $minimum) { return }
    $backup = Join-Path (Split-Path -Parent $settingsPath) "settings-store.before-inspection-$($script:Context.id).json"
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $settingsPath -Destination $backup }
    $settings.autoPauseTimeoutSeconds = $minimum
    Write-Json $settingsPath $settings
    $script:Context | Add-Member -NotePropertyName dockerResourceSaverBackup -NotePropertyValue $backup -Force
    Save-Run
}

function Invoke-Preflight {
    foreach ($tool in @('docker', 'ssh', 'ssh-keygen', 'scp', 'codex')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing prerequisite: $tool" }
    }
    if (-not (Test-Path -LiteralPath $script:Settings.vmrun)) { throw 'VMware vmrun was not found.' }
    if (-not (Test-Path -LiteralPath $script:Settings.jj)) { throw 'The pinned jj executable was not found.' }
    Set-DockerResourceSaverTimeout
    $engine = Invoke-Docker @('version', '--format', '{{.Server.Version}}') -TimeoutSeconds 30 -AllowFailure
    if ($engine.exitCode -ne 0) {
        $shell = (Get-Process -Id $PID).Path
        Invoke-LoggedProcess $shell @('-NoProfile', '-File', "$PSScriptRoot\repair-docker-secrets.ps1", '-EvidencePath', "$script:RunDirectory\docker-recovery.json") -TimeoutSeconds 280 -LogName 'docker-recovery' | Out-Null
    }
    Invoke-LoggedProcess 'codex' @('login', 'status') -LogName 'codex-login' | Out-Null
    Invoke-LoggedProcess $script:Settings.vmrun @('list') -LogName 'vmware-inventory' | Out-Null
    Start-Builder
    $controllerLinux = Get-LinuxPath $script:ControllerRepository
    Invoke-Docker @('exec', '-e', 'HOME=/root', '-e', 'NIX_REMOTE=daemon', '-e', "NIX_STATE_DIR=$($script:Settings.nixStateDir)", '-w', $controllerLinux, $script:Settings.container, $script:Nix, 'build', '--no-link', '--no-update-lock-file', "path:$controllerLinux#checks.x86_64-linux.desktop-inspection-spec") -TimeoutSeconds ($script:Settings.buildTimeoutMinutes * 60) | Out-Null
    $keys = Join-Path $script:Settings.artifactRoot 'keys'
    New-Item -ItemType Directory -Force -Path $keys | Out-Null
    $script:PrivateKey = Join-Path $keys 'desktop-inspection'
    if (-not (Test-Path -LiteralPath $script:PrivateKey)) {
        Invoke-LoggedProcess 'ssh-keygen' @('-t', 'ed25519', '-N', '', '-C', 'nixos-live-inspection', '-f', $script:PrivateKey) -LogName 'key-generation' | Out-Null
    }
    if (-not (Test-Path "$script:PrivateKey.pub")) { throw 'Inspection public key is missing.' }
    $account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    Invoke-LoggedProcess 'icacls.exe' @($script:PrivateKey, '/inheritance:r', '/grant:r', "${account}:F") -LogName 'inspection-key-acl' | Out-Null
    if (-not (Test-Path "$script:Repository\.jj")) { throw "Candidate path is not a jj workspace: $script:Repository" }
    Invoke-LoggedProcess $script:Settings.jj @('status') -WorkingDirectory $script:Repository -LogName 'jj-status' | Out-Null
    Invoke-LoggedProcess $script:Settings.jj @('log', '-r', $script:Settings.baselineRevision, '--no-graph', '-T', 'commit_id ++ "\n"') -WorkingDirectory $script:Repository -LogName 'baseline-revision' | Out-Null
    Get-ReferenceEvidence | Out-Null
    Write-Json "$script:RunDirectory\preflight.json" @{ status = 'pass'; checkedAt = [DateTimeOffset]::UtcNow.ToString('o'); dockerFileShare = Get-LinuxPath $script:RunDirectory }
}

function Invoke-AdoptionPreflight {
    foreach ($tool in @('ssh', 'scp', 'codex')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing prerequisite: $tool" }
    }
    if (-not (Test-Path -LiteralPath $script:Settings.vmrun)) { throw 'VMware vmrun was not found.' }
    if (-not (Test-Path -LiteralPath $script:Settings.jj)) { throw 'The pinned jj executable was not found.' }
    if (-not (Test-Path -LiteralPath "$($script:Settings.artifactRoot)\keys\desktop-inspection")) { throw 'The existing inspection private key is unavailable.' }
    Invoke-LoggedProcess 'codex' @('login', 'status') -LogName 'codex-login' | Out-Null
    Invoke-LoggedProcess $script:Settings.vmrun @('list') -LogName 'vmware-inventory' | Out-Null
    Get-ReferenceEvidence | Out-Null
    Write-Json "$script:RunDirectory\preflight.json" @{ status = 'pass'; checkedAt = [DateTimeOffset]::UtcNow.ToString('o'); buildArtifacts = 'reused after SHA-256 validation'; docker = 'not required for read-only artifact adoption and VMware verification' }
}

function New-SourceSnapshot([string]$Name, [switch]$Baseline) {
    $source = Join-Path $script:RunDirectory "source-$Name"
    if (Test-Path -LiteralPath $source) { throw "Source snapshot already exists: $source" }
    New-Item -ItemType Directory -Path $source | Out-Null
    $origin = $script:Repository
    $workspaceName = $null
    $revision = if ($Baseline) { $script:Settings.baselineRevision } else { '@' }
    $sourceCommit = (Invoke-LoggedProcess $script:Settings.jj @('log', '-r', $revision, '--no-graph', '-T', 'commit_id ++ "\n"') -WorkingDirectory $script:Repository -LogName 'snapshot-revision').stdout.Trim()
    if ($sourceCommit -notmatch '^[0-9a-f]{40}$') { throw "Cannot resolve source revision: $revision" }
    if ($Baseline) {
        $origin = Join-Path $script:RunDirectory "materialized-$Name"
        $workspaceName = "inspection-$($script:Context.id)-$Name" -replace '[^a-zA-Z0-9_-]', '-'
        Invoke-LoggedProcess $script:Settings.jj @('workspace', 'add', '--name', $workspaceName, '--revision', $revision, '--sparse-patterns', 'full', $origin) -WorkingDirectory $script:Repository -LogName 'materialize-baseline' | Out-Null
    }
    if (-not (Test-Path "$origin\flake.lock")) { throw "Missing original source/lock: $origin" }
    try {
        foreach ($item in $script:SourceItems) {
            if (-not (Test-Path -LiteralPath (Join-Path $origin $item))) { continue }
            Copy-Item -LiteralPath (Join-Path $origin $item) -Destination $source -Recurse
        }
        New-Item -ItemType Directory -Force -Path "$source\workflow" | Out-Null
        Copy-Item "$script:ControllerRepository\hosts\iso\inspection.mod.nix" "$source\hosts\iso\inspection.mod.nix"
        Copy-Item "$script:ControllerRepository\workflow\guest-inspect.py" "$source\workflow\guest-inspect.py"
        Copy-Item "$script:ControllerRepository\workflow\desktop-ready-probe.py" "$source\workflow\desktop-ready-probe.py"
        Copy-Item "$script:ControllerRepository\workflow\ida-functional.py" "$source\workflow\ida-functional.py"
        Copy-Item "$script:ControllerRepository\workflow\inspection-build.nix" "$source\workflow\inspection-build.nix"
    } finally {
        if ($workspaceName) {
            Invoke-LoggedProcess $script:Settings.jj @('workspace', 'forget', $workspaceName) -WorkingDirectory $script:Repository -AllowFailure -LogName 'forget-baseline-workspace' | Out-Null
            $runRoot = [IO.Path]::GetFullPath($script:RunDirectory).TrimEnd('\')
            $materializedRoot = [IO.Path]::GetFullPath($origin)
            if (-not $materializedRoot.StartsWith("$runRoot\materialized-", [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to remove materialized source outside this run: $materializedRoot"
            }
            if (Test-Path -LiteralPath $materializedRoot) { Remove-Item -LiteralPath $materializedRoot -Recurse -Force }
        }
    }
    Normalize-NixSnapshot $source
    Write-Json "$source\source-hashes.json" @{ revision = $revision; commit = $sourceCommit; files = Get-SourceManifest $source }
    return $source
}

function Invoke-SourceChecks([string]$Source) {
    $linux = Get-LinuxPath $Source
    foreach ($check in @('formatting', 'deadnix', 'statix', 'win95-window-control', 'ghostty-iso-tahoe', 'ghostty-iso-win95', 'host-iso-tahoe', 'host-iso-win95')) {
        Invoke-Docker @('exec', '-e', 'HOME=/root', '-e', 'NIX_REMOTE=daemon', '-e', "NIX_STATE_DIR=$($script:Settings.nixStateDir)", '-w', $linux, $script:Settings.container, $script:Nix, 'build', '--no-link', '--no-update-lock-file', "path:$linux#checks.x86_64-linux.$check") -TimeoutSeconds ($script:Settings.buildTimeoutMinutes * 60) | Out-Null
    }
}

function Build-Edition([string]$Edition, [switch]$Baseline) {
    Assert-Budget
    Start-Builder
    $label = '{0}-{1}-{2}' -f $(if ($Baseline) { 'baseline' } else { 'candidate' }), $Edition, [DateTime]::UtcNow.ToString('HHmmssfff')
    $source = New-SourceSnapshot $label -Baseline:$Baseline
    $output = Join-Path $script:RunDirectory $label
    New-Item -ItemType Directory -Path $output | Out-Null
    $linux = Get-LinuxPath $source
    $key = (Get-Content "$($script:Settings.artifactRoot)\keys\desktop-inspection.pub" -Raw).Trim()
    # The public key enters a typed Nix option; the private key stays outside source.
    Copy-Item -LiteralPath "$source\workflow\inspection-build.nix" -Destination "$output\build.nix"
    try {
        if (-not $Baseline) { Invoke-SourceChecks $source }
        $build = Invoke-Docker @('exec', '-e', 'HOME=/root', '-e', 'NIX_REMOTE=daemon', '-e', "NIX_STATE_DIR=$($script:Settings.nixStateDir)", '-w', $linux, $script:Settings.container, $script:Nix, 'build', '--impure', '--no-link', '--json', '--no-update-lock-file', '--file', (Get-LinuxPath "$output\build.nix"), '--argstr', 'source', $linux, '--argstr', 'edition', $Edition, '--argstr', 'publicKey', $key) -TimeoutSeconds ($script:Settings.buildTimeoutMinutes * 60)
        $build.stdout | Set-Content "$output\nix-build.json"
        $store = ($build.stdout | ConvertFrom-Json)[0].outputs.out
        Invoke-Docker @('cp', "$($script:Settings.container):$store/iso/.", $output) | Out-Null
        $iso = @(Get-ChildItem -LiteralPath $output -Filter '*.iso')
        if ($iso.Count -ne 1) { throw 'Build did not produce exactly one ISO.' }
        $candidate = [pscustomobject]@{
            label = $label; edition = $Edition; baseline = [bool]$Baseline; directory = $output; source = $source
            iso = $iso[0].FullName; sha256 = (Get-FileHash $iso[0].FullName).Hash.ToLowerInvariant(); storePath = $store
            sourceManifestHash = (Get-FileHash "$source\source-hashes.json").Hash; verification = @(); accepted = $false; failedCount = 999
        }
        "$($candidate.sha256)  $($iso[0].Name)" | Set-Content "$output\SHA256SUMS"
        Write-Json "$output\candidate.json" $candidate
        if ($Baseline) { $script:Context.baselines += $candidate } else { $script:Context.candidates += $candidate }
        Save-Run
        return $candidate
    } finally { Stop-Builder }
}

function ConvertTo-Vmx([Collections.IDictionary]$Configuration) {
    $lines = foreach ($entry in $Configuration.GetEnumerator()) {
        $value = ([string]$entry.Value).Replace('\', '\\').Replace('"', '\"')
        "$($entry.Key) = `"$value`""
    }
    return ($lines -join "`n") + "`n"
}

function New-Guest($Candidate) {
    $directory = Join-Path $script:Settings.vmRoot $Candidate.edition
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $vmx = Join-Path $directory "nixos-$($Candidate.edition).vmx"
    $marker = Join-Path $directory 'workflow-owned.json'
    if ((Test-Path -LiteralPath $vmx) -and -not (Test-Path -LiteralPath $marker)) { throw "Refusing to replace an unowned VM: $vmx" }
    if (Test-Path $marker) {
        $owned = Get-Content $marker -Raw | ConvertFrom-Json
        if ($owned.vmx -ne $vmx) { throw 'VM ownership marker does not match.' }
    }
    $running = (Invoke-LoggedProcess $script:Settings.vmrun @('list') -LogName 'vmware-list').stdout
    if ($running.Contains($vmx)) { Invoke-LoggedProcess $script:Settings.vmrun @('stop', $vmx, 'hard') -LogName 'stop-owned-vm' | Out-Null }
    $iso = $Candidate.iso.Replace('\', '/')
    $vmxConfiguration = [ordered]@{
        '.encoding' = 'UTF-8'
        'config.version' = '8'
        'virtualHW.version' = '21'
        'pciBridge0.present' = 'TRUE'
        'pciBridge0.pciSlotNumber' = '17'
        'pciBridge4.present' = 'TRUE'
        'pciBridge4.virtualDev' = 'pcieRootPort'
        'pciBridge4.functions' = '8'
        'pciBridge4.pciSlotNumber' = '21'
        'pciBridge5.present' = 'TRUE'
        'pciBridge5.virtualDev' = 'pcieRootPort'
        'pciBridge5.functions' = '8'
        'pciBridge5.pciSlotNumber' = '22'
        'pciBridge6.present' = 'TRUE'
        'pciBridge6.virtualDev' = 'pcieRootPort'
        'pciBridge6.functions' = '8'
        'pciBridge6.pciSlotNumber' = '23'
        'pciBridge7.present' = 'TRUE'
        'pciBridge7.virtualDev' = 'pcieRootPort'
        'pciBridge7.functions' = '8'
        'pciBridge7.pciSlotNumber' = '24'
        displayName = "NixOS $($Candidate.edition) live inspection"
        guestOS = 'otherlinux-64'
        firmware = 'efi'
        numvcpus = '2'
        'cpuid.coresPerSocket' = '2'
        memsize = '4096'
        'ethernet0.present' = 'TRUE'
        'ethernet0.connectionType' = 'nat'
        'ethernet0.virtualDev' = 'vmxnet3'
        'ethernet0.addressType' = 'generated'
        'ethernet0.pciSlotNumber' = '160'
        'sata0.present' = 'TRUE'
        'sata0:0.present' = 'TRUE'
        'sata0:0.deviceType' = 'cdrom-image'
        'sata0:0.fileName' = $iso
        'sata0:0.startConnected' = 'TRUE'
        'sata0.pciSlotNumber' = '35'
        'mks.enable3d' = 'TRUE'
        'svga.vramSize' = '268435456'
        'svga.graphicsMemoryKB' = '1048576'
        'svga.autodetect' = 'TRUE'
        'usb.present' = 'TRUE'
        'usb.pciSlotNumber' = '32'
        'ehci.present' = 'TRUE'
        'ehci.pciSlotNumber' = '34'
        'sound.present' = 'FALSE'
        'tools.syncTime' = 'TRUE'
        'powerType.powerOff' = 'soft'
        'powerType.reset' = 'soft'
    }
    ConvertTo-Vmx $vmxConfiguration | Set-Content -LiteralPath $vmx -Encoding utf8NoBOM
    Write-Json $marker @{ vmx = $vmx; purpose = 'Dedicated live ISO inspection'; edition = $Candidate.edition }
    Copy-Item -LiteralPath $vmx -Destination "$($Candidate.directory)\guest.vmx"
    return $vmx
}

function Get-VmwareLeaseAddress([string]$Vmx) {
    $vmxText = Get-Content -LiteralPath $Vmx -Raw
    $macMatch = [regex]::Match($vmxText, '(?m)^\s*ethernet0\.generatedAddress\s*=\s*"(?<mac>[0-9a-f:]{17})"')
    if (-not $macMatch.Success) { return $null }
    $mac = $macMatch.Groups['mac'].Value.ToLowerInvariant()
    $leases = @()
    foreach ($leaseFile in @($script:Settings.vmwareLeaseFiles)) {
        if (-not (Test-Path -LiteralPath $leaseFile)) { continue }
        $contents = Get-Content -LiteralPath $leaseFile -Raw -ErrorAction SilentlyContinue
        foreach ($lease in [regex]::Matches($contents, '(?ms)^\s*lease\s+(?<ip>(?:\d{1,3}\.){3}\d{1,3})\s*\{(?<body>.*?)^\s*\}')) {
            $body = $lease.Groups['body'].Value
            if ($body -notmatch "(?im)^\s*hardware ethernet\s+$([regex]::Escape($mac));") { continue }
            $started = [DateTimeOffset]::MinValue
            $startMatch = [regex]::Match($body, '(?im)^\s*starts\s+\d\s+(?<date>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2});')
            if ($startMatch.Success) {
                $started = [DateTimeOffset]::ParseExact($startMatch.Groups['date'].Value, 'yyyy/MM/dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
            }
            $leases += [pscustomobject]@{ ip = $lease.Groups['ip'].Value; started = $started }
        }
    }
    if (-not $leases.Count) { return $null }
    return ($leases | Sort-Object started -Descending | Select-Object -First 1).ip
}

function Get-SshArguments([string]$Ip, [string]$KnownHosts) {
    @('-i', "$($script:Settings.artifactRoot)\keys\desktop-inspection", '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', '-o', 'StrictHostKeyChecking=accept-new', '-o', "UserKnownHostsFile=$KnownHosts", "nixos@$Ip")
}

function Invoke-GuestHelper([string]$Name, [string]$Ip, [string[]]$Ssh, [string]$KnownHosts, [string]$BootDirectory) {
    $local = Join-Path $script:ControllerRepository "workflow\$Name"
    $remote = "/tmp/$Name"
    $copy = @('-i', "$($script:Settings.artifactRoot)\keys\desktop-inspection", '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$KnownHosts", $local, "nixos@${Ip}:$remote")
    Invoke-LoggedProcess 'scp' $copy -TimeoutSeconds 60 -LogName "copy-$Name" | Out-Null
    $result = Invoke-LoggedProcess 'ssh' ($Ssh + @("python3 $remote")) -TimeoutSeconds 70 -AllowFailure -LogName $Name
    Write-Json (Join-Path $BootDirectory "$Name.json") @{ scriptSha256 = (Get-FileHash -LiteralPath $local).Hash.ToLowerInvariant(); exitCode = $result.exitCode; stdout = $result.stdout; stderr = $result.stderr }
    return $result
}

function Start-Guest([string]$Vmx, [string]$BootDirectory, $Candidate) {
    $bootWatch = [Diagnostics.Stopwatch]::StartNew()
    Invoke-LoggedProcess $script:Settings.vmrun @('start', $Vmx, 'nogui') -LogName 'vmware-start' | Out-Null
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($script:Settings.bootTimeoutSeconds)
    $knownHosts = Join-Path $BootDirectory 'known_hosts'
    $compatibilityApplied = $false
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        Assert-Budget
        $result = Invoke-LoggedProcess $script:Settings.vmrun @('getGuestIPAddress', $Vmx) -TimeoutSeconds 15 -AllowFailure -LogName 'guest-ip'
        $ip = $result.stdout.Trim()
        if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { $ip = Get-VmwareLeaseAddress $Vmx }
        if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
            $ssh = Get-SshArguments $ip $knownHosts
            $connection = Invoke-LoggedProcess 'ssh' ($ssh + @('true')) -TimeoutSeconds 12 -AllowFailure -LogName 'guest-ssh'
            if ($connection.exitCode -eq 0) {
                if (-not $compatibilityApplied -and $Candidate.baseline -and $Candidate.edition -eq 'win95') {
                    Invoke-GuestHelper 'baseline-win95-compat.py' $ip $ssh $knownHosts $BootDirectory | Out-Null
                    $compatibilityApplied = $true
                }
                $ready = Invoke-GuestHelper 'desktop-ready-probe.py' $ip $ssh $knownHosts $BootDirectory
                if ($ready.exitCode -eq 0) { return [pscustomobject]@{ ip = $ip; knownHosts = $knownHosts; ssh = $ssh; readyWallSeconds = $bootWatch.Elapsed.TotalSeconds } }
            }
        }
        Start-Sleep -Seconds 2
    }
    throw 'Guest did not expose key-only SSH and desktop readiness within its boot timeout.'
}

function Get-Median([double[]]$Values) {
    if (-not $Values.Count) { return $null }
    $sorted = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2) { return $sorted[$middle] }
    return ($sorted[$middle - 1] + $sorted[$middle]) / 2
}

function Compare-Performance($Metrics, $Baseline) {
    $failures = [Collections.Generic.List[string]]::new()
    if ($Metrics.ramBytes -gt $script:Settings.ramLimitGiB * 1GB) { $failures.Add('idle-ram-limit') }
    if ($Metrics.cpuPercent -gt $script:Settings.cpuLimitPercent) { $failures.Add('idle-cpu-limit') }
    if ($null -eq $Metrics.readySeconds -or $Metrics.readySeconds -gt $script:Settings.readyLimitSeconds) { $failures.Add('desktop-readiness') }
    if (-not $Metrics.hardwareRendering) { $failures.Add('hardware-rendering') }
    if ($null -eq $Baseline -or $null -eq $Baseline.ramBytes -or $null -eq $Baseline.cpuPercent -or $null -eq $Baseline.readySeconds -or -not $Baseline.hardwareRendering) { $failures.Add('baseline-unverified') } else {
        $ratio = 1 + $script:Settings.regressionPercent / 100
        if ($Metrics.ramBytes -gt $Baseline.ramBytes * $ratio) { $failures.Add('ram-regression') }
        if ($null -eq $Baseline.readySeconds -or $Metrics.readySeconds -gt $Baseline.readySeconds * $ratio) { $failures.Add('boot-regression') }
        if ($Metrics.cpuPercent -gt [Math]::Max($Baseline.cpuPercent * $ratio, $Baseline.cpuPercent + $script:Settings.cpuTolerancePoints)) { $failures.Add('cpu-regression') }
    }
    return $failures.ToArray()
}

function Review-Boot($Candidate, [string]$Directory) {
    $pictures = @(Get-ChildItem -LiteralPath $Directory -Filter '*.png' | Sort-Object Name)
    if (-not $pictures.Count) { throw 'No guest screenshots are available for visual review.' }
    $references = @(Get-ReferenceEvidence | Where-Object { $_.edition -eq $Candidate.edition })
    $referenceImages = @($references | Where-Object kind -eq 'image')
    if (-not $referenceImages.Count) { throw "No frozen image reference is available for $($Candidate.edition)." }
    $reviewPath = Join-Path $Directory 'visual-review.json'
    $arguments = @('exec', '-c', 'model_reasoning_effort="medium"', '--sandbox', 'read-only', '--skip-git-repo-check', '-C', $Directory, '--output-schema', "$script:RunDirectory\visual-review.schema.json", '-o', $reviewPath, '--json')
    foreach ($reference in $referenceImages) { $arguments += @('--image', (Join-Path "$script:RunDirectory\references" $reference.file)) }
    foreach ($picture in $pictures) { $arguments += @('--image', $picture.FullName) }
    $criteria = Get-Content "$script:RunDirectory\criteria.json" -Raw
    $criteriaObject = $criteria | ConvertFrom-Json
    $required = @($criteriaObject.common) + @($criteriaObject.($Candidate.edition))
    $visualIds = $required -join ', '
    $referenceManifest = $references | ConvertTo-Json -Depth 10
    $imageManifest = @($referenceImages | ForEach-Object file) + @($pictures | ForEach-Object Name) | ConvertTo-Json
    $prompt = @"
Inspect these actual NixOS live desktop screenshots for edition $($Candidate.edition).
Acceptance criteria are frozen: $criteria
First study the frozen reference artifacts and this reference manifest: $referenceManifest
Attached images are ordered exactly as this filename list: $imageManifest
Inspect the attached images directly. Do not re-encode images, emit base64, crop, resize, or load image-processing tools.
Read only relevant bounded excerpts of functional.json, guest journals and fixture sources. The references are already frozen;
do not browse or repeat reference acquisition. Finish with the complete structured JSON after this single evidence review.
Then inspect the candidate screenshots. Do not confuse a reference image with candidate evidence.
Return one check for every common and edition-specific criterion, using its exact ID.
The visual check IDs are exactly: $visualIds
Do not add functional check IDs to the visual review; functional.json already records those checks separately.
For every check report severity, confidence, candidate evidence filenames, reference IDs, observed state,
expected state, concrete difference, and repair scope. Mark anything not observable unverified; do not infer functionality from appearance.
Read functional.json and the guest journals too. In particular keyboard navigation, usable dialogs, browser rendering,
Start menu, launchers and shutdown confirmation need observed evidence. Golden Gate is the visual direction for the glass edition.
For browser rendering, read files/browser.html and files-1280x720/browser.html before judging authored colors.
Compare the screenshot with the actual fixture source; labels alone do not establish expected CSS colors.
Missing evidence must remain unverified. Do not edit source or run further builds. The JSON is the entire review result.
"@
    Invoke-LoggedProcess 'codex' $arguments -InputText $prompt -TimeoutSeconds 600 -LogName 'visual-review' | Out-Null
    $review = Get-Content $reviewPath -Raw | ConvertFrom-Json
    return Assert-VisualReview $Candidate $Directory $review
}

function Assert-VisualReview($Candidate, [string]$Directory, $Review) {
    $review = $Review
    $criteria = Get-Content "$script:RunDirectory\criteria.json" -Raw | ConvertFrom-Json
    $required = @($criteria.common) + @($criteria.($Candidate.edition))
    $references = @(Get-Content "$script:RunDirectory\references\manifest.json" -Raw | ConvertFrom-Json | Where-Object edition -eq $Candidate.edition)
    $evidenceRoot = [IO.Path]::GetFullPath($Directory).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (@($review.checks | Where-Object { $_.id -notin $required }).Count) { throw 'Visual review introduced checks outside the frozen visual criteria.' }
    foreach ($id in $required) {
        $checks = @($review.checks | Where-Object { $_.id -eq $id })
        if ($checks.Count -ne 1) { throw "Visual review omitted/duplicated $id" }
        if ($checks[0].status -eq 'pass') {
            if (-not $checks[0].candidateEvidence.Count) { throw "Passing visual check lacks candidate evidence: $id" }
            foreach ($evidence in $checks[0].candidateEvidence) {
                if ([IO.Path]::IsPathRooted($evidence) -or $evidence -match '(^|[\\/])\.\.?([\\/]|$)') { throw "Invalid review evidence: $evidence" }
                $evidencePath = [IO.Path]::GetFullPath((Join-Path $Directory $evidence))
                if (-not $evidencePath.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) { throw "Invalid review evidence: $evidence" }
            }
        }
        foreach ($referenceId in $checks[0].referenceIds) {
            if ($referenceId -notin @($references.id)) { throw "Review cited an unknown or wrong-edition reference: $referenceId" }
        }
    }
    return $review
}

function Test-ProcessMemoryEvidence($Directory, $Metrics) {
    if ($null -eq $Metrics -or -not $Metrics.PSObject.Properties['processMemoryEvidence'] -or $Metrics.processMemoryEvidence -ne 'process-memory.json') { return $false }
    $path = Join-Path $Directory 'process-memory.json'
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try {
        $evidence = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        return $evidence.metric -eq 'VmRSS' -and
            @($evidence.snapshots).Count -gt 0 -and
            @($evidence.topProcesses).Count -gt 0
    } catch { return $false }
}

function Verify-Candidate($Candidate) {
    if ((Get-FileHash -LiteralPath $Candidate.iso).Hash.ToLowerInvariant() -ne $Candidate.sha256) { throw 'ISO changed since its build manifest.' }
    Stop-Builder
    $vmx = New-Guest $Candidate
    $verifications = @()
    for ($boot = 1; $boot -le $script:Settings.confirmBoots; $boot++) {
        Assert-Budget
        $directory = Join-Path $Candidate.directory "boot-$boot"
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $metrics = $null
        $functional = $null
        try {
            $guest = Start-Guest $vmx $directory $Candidate
            $remote = "/tmp/desktop-inspection-$boot"
            $inspectionScripts = @('guest-inspect.py', 'ida-functional.py')
            $guestCopy = @('-i', "$($script:Settings.artifactRoot)\keys\desktop-inspection", '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$($guest.knownHosts)")
            $scriptHashes = [ordered]@{}
            foreach ($name in $inspectionScripts) {
                $sourceScript = Join-Path "$script:ControllerRepository\workflow" $name
                Invoke-LoggedProcess 'scp' ($guestCopy + @($sourceScript, "nixos@$($guest.ip):/tmp/$name")) -TimeoutSeconds 60 -LogName 'copy-inspection-script' | Out-Null
                $scriptHashes[$name] = (Get-FileHash -LiteralPath $sourceScript).Hash.ToLowerInvariant()
            }
            Write-Json "$directory\inspection-scripts.json" $scriptHashes
            $metricsCommand = "python3 /tmp/guest-inspect.py metrics --edition $($Candidate.edition) --output $remote --settle $($script:Settings.settleSeconds) --sample $($script:Settings.sampleSeconds)"
            Invoke-LoggedProcess 'ssh' ($guest.ssh + @($metricsCommand)) -TimeoutSeconds $script:Settings.metricsTimeoutSeconds -LogName 'idle-metrics' | Out-Null
            if (-not $Candidate.baseline) {
                $acceptScript = Join-Path $script:ControllerRepository 'workflow\ida-accept-eula.py'
                $remoteAcceptScript = '/tmp/desktop-ida-accept-eula.py'
                $guestCopy = @('-i', "$($script:Settings.artifactRoot)\keys\desktop-inspection", '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$($guest.knownHosts)")
                Invoke-LoggedProcess 'scp' ($guestCopy + @($acceptScript, "nixos@$($guest.ip):$remoteAcceptScript")) -TimeoutSeconds 60 -LogName 'copy-ida-eula-helper' | Out-Null
                $acceptance = Invoke-LoggedProcess 'ssh' ($guest.ssh + @("python3 $remoteAcceptScript")) -TimeoutSeconds 60 -AllowFailure -LogName 'ida-eula-acceptance'
                Write-Json "$directory\ida-eula-acceptance.json" @{ scriptSha256 = (Get-FileHash -LiteralPath $acceptScript).Hash.ToLowerInvariant(); exitCode = $acceptance.exitCode; stdout = $acceptance.stdout; stderr = $acceptance.stderr }
                $resolutions = $script:Settings.resolutions -join ' '
                Invoke-LoggedProcess 'ssh' ($guest.ssh + @("IDA_INSPECTION_SCRIPT=/tmp/ida-functional.py python3 /tmp/guest-inspect.py suite --edition $($Candidate.edition) --output $remote --resolutions $resolutions")) -TimeoutSeconds 600 -AllowFailure -LogName 'functional-suite' | Out-Null
            }
            $scp = @('-i', "$($script:Settings.artifactRoot)\keys\desktop-inspection", '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$($guest.knownHosts)", '-r', "nixos@$($guest.ip):$remote/.", $directory)
            Invoke-LoggedProcess 'scp' $scp -TimeoutSeconds 120 -LogName 'copy-evidence' | Out-Null
            $metrics = Get-Content "$directory\metrics.json" -Raw | ConvertFrom-Json
            Write-Json "$directory\host-boot.json" @{ readyWallSeconds = $guest.readyWallSeconds; ip = $guest.ip }
            $metrics.readySeconds = [Math]::Max([double]$metrics.readySeconds, [double]$guest.readyWallSeconds)
            $functional = if (-not $Candidate.baseline -and (Test-Path "$directory\functional.json")) { Get-Content "$directory\functional.json" -Raw | ConvertFrom-Json } else { $null }
            $review = if (-not $Candidate.baseline) { Review-Boot $Candidate $directory } else { $null }
            $verifications += [pscustomobject]@{ boot = $boot; directory = $directory; metrics = $metrics; functional = $functional; visual = $review; error = $null }
        } catch {
            $_.Exception.Message | Set-Content "$directory\failure.txt"
            $verifications += [pscustomobject]@{ boot = $boot; directory = $directory; metrics = $metrics; functional = $functional; visual = $null; error = $_.Exception.Message }
            Write-Warning "$($Candidate.edition) boot ${boot}: $($_.Exception.Message)"
        } finally {
            Invoke-LoggedProcess $script:Settings.vmrun @('stop', $vmx, 'hard') -TimeoutSeconds 40 -AllowFailure -Cleanup -LogName 'vmware-stop' | Out-Null
        }
        $Candidate.verification = $verifications
        Update-CandidateAssessment $Candidate | Out-Null
    }
    $Candidate.verification = $verifications
    return Update-CandidateAssessment $Candidate
}

function Update-CandidateAssessment($Candidate) {
    $verifications = @($Candidate.verification)
    foreach ($boot in 1..$script:Settings.confirmBoots) {
        if (-not @($verifications | Where-Object boot -eq $boot).Count) {
            $verifications += [pscustomobject]@{boot=$boot; directory=(Join-Path $Candidate.directory "boot-$boot"); metrics=$null; functional=$null; visual=$null; error='Missing fresh boot evidence'}
        }
    }
    $measurements = @($verifications | Where-Object { $null -ne $_.metrics })
    $median = [pscustomobject]@{
        ramBytes = Get-Median @($measurements | ForEach-Object { $_.metrics.ramBytes })
        cpuPercent = Get-Median @($measurements | ForEach-Object { $_.metrics.cpuPercent })
        readySeconds = if (@($measurements | Where-Object { $null -eq $_.metrics.readySeconds }).Count -or -not $measurements.Count) { $null } else { Get-Median @($measurements | ForEach-Object { $_.metrics.readySeconds }) }
        hardwareRendering = $measurements.Count -eq $script:Settings.confirmBoots -and @($measurements | Where-Object { -not $_.metrics.hardwareRendering }).Count -eq 0
    }
    $failures = @()
    if ($measurements.Count -ne $script:Settings.confirmBoots) { $failures += 'missing-boot-evidence' }
    foreach ($verification in $verifications) {
        if (-not (Test-ProcessMemoryEvidence $verification.directory $verification.metrics)) {
            $failures += "process-memory-unverified-boot-$($verification.boot)"
        }
    }
    if (-not $Candidate.baseline) {
        $frozenCriteria = Get-Content "$script:RunDirectory\criteria.json" -Raw | ConvertFrom-Json
        $requiredFunctional = @($frozenCriteria.functional.common) + @($frozenCriteria.functional.($Candidate.edition))
        $requiredVisual = @($frozenCriteria.common) + @($frozenCriteria.($Candidate.edition))
        $baseline = @($script:Context.baselines | Where-Object { $_.edition -eq $Candidate.edition } | Select-Object -Last 1)
        $baselineMetrics = if ($baseline.Count -and (Test-Path "$($baseline[0].directory)\performance.json")) { Get-Content "$($baseline[0].directory)\performance.json" -Raw | ConvertFrom-Json } else { $null }
        $failures += Compare-Performance $median $baselineMetrics
        foreach ($verification in $verifications) {
            if ($null -eq $verification.functional) {
                $failures += @($requiredFunctional | ForEach-Object { "functional-unverified-$_" })
            } else {
                $observedIds = @($verification.functional.checks | ForEach-Object id)
                $failures += @($requiredFunctional | Where-Object { $_ -notin $observedIds } | ForEach-Object { "missing-functional-$_" })
                $failures += @($verification.functional.checks | Where-Object status -ne 'pass' | ForEach-Object id)
            }
            if ($null -eq $verification.visual) { $failures += @($requiredVisual | ForEach-Object { "visual-unverified-$_" }) } else { $failures += @($verification.visual.checks | Where-Object status -ne 'pass' | ForEach-Object id) }
            if (-not (Test-Path "$($verification.directory)\resolutions.json")) { $failures += 'resolution-checks-unverified' }
        }
    }
    Write-Json "$($Candidate.directory)\performance.json" $median
    $Candidate.failedCount = @($failures | Select-Object -Unique).Count
    $Candidate.accepted = -not $Candidate.baseline -and $Candidate.failedCount -eq 0
    Write-Json "$($Candidate.directory)\verification.json" @{ boots = $verifications; median = $median; failed = @($failures | Select-Object -Unique); accepted = $Candidate.accepted }
    Write-Json "$($Candidate.directory)\candidate.json" $Candidate
    Save-Run
    return $Candidate
}

function Get-RepairEditions([string[]]$Paths) {
    $editions = foreach ($path in $Paths) {
        if ($path -match '^(shells/(win95/|win95-panel\.mod\.nix|test-win95-window-action\.sh)|packages/win95-window-action/|themes/.*win95)') { 'win95' }
        elseif ($path -match '^(shells/dms\.mod\.nix|themes/.*tahoe)') { 'tahoe' }
        else { 'tahoe'; 'win95' }
    }
    return @($editions | Select-Object -Unique)
}

function Invoke-Repair($Candidate) {
    $edition = $Candidate.edition
    $count = [int]$script:Context.repairs.$edition
    if ($count -ge $script:Settings.maxRepairs) { return $false }
    $script:Context.repairs.$edition = $count + 1
    Save-Run
    $repairSource = New-SourceSnapshot "repair-$edition-$count"
    $before = Get-SourceManifest $repairSource
    $prompt = @"
Repair the $edition live desktop using evidence in $($Candidate.directory)\verification.json and its boot folders.
Read STYLE_GUIDE.md. This is an isolated source snapshot without a version-control checkout; do not run version-control commands.
The controller uses jj after applying approved changes. Preserve flake.lock. Use maintained packaged niri/Quickshell/DMS;
do not write custom Rust or replace niri. Allowed scope: desktops/, shells/, themes/, adapters/, packages/win95-window-action/,
modules/ghostty.mod.nix, modules/file-explorer.mod.nix, modules/helium.mod.nix and hosts/iso/iso.mod.nix.
Do not alter workflow/, acceptance criteria, budgets, test evidence, inspection credentials or unrelated host configuration.
Do not delete source files. Edit only files within this snapshot; the controller will transfer validated changes.
Fix observed failures only, preserve both iso-tahoe and iso-win95 output names, and explain changes in your final response.
Do not build, deploy or test VMware yourself; the parent workflow rechecks both editions sequentially after these changes.
"@
    $result = Invoke-LoggedProcess 'codex' @('exec', '--sandbox', 'workspace-write', '--skip-git-repo-check', '-C', $repairSource, '--json', '-o', "$script:RunDirectory\repair-$edition-$count.txt") -InputText $prompt -TimeoutSeconds 1200 -AllowFailure -LogName 'bounded-repair'
    if ($result.exitCode -ne 0) { return $false }
    $after = Get-SourceManifest $repairSource
    $changed = @(@($before.Keys) + @($after.Keys) | Select-Object -Unique | Where-Object { $before[$_] -ne $after[$_] })
    $allowed = '^(desktops/|shells/|themes/|adapters/|packages/win95-window-action/|modules/(ghostty|file-explorer|helium)\.mod\.nix$|hosts/iso/iso\.mod\.nix$)'
    $outside = @($changed | Where-Object { $_ -notmatch $allowed })
    Write-Json "$script:RunDirectory\repair-$edition-$count-files.json" @{ changed = $changed; outsideScope = $outside }
    if ($outside.Count) { throw "Repair wrote outside approved scope in its isolated snapshot: $($outside -join ', ')" }
    $deleted = @($changed | Where-Object { -not $after.Contains($_) })
    if ($deleted.Count) { throw "Repair deleted source files in its isolated snapshot: $($deleted -join ', ')" }
    if (-not $changed.Count) { return $false }
    $otherEditions = @(Get-RepairEditions $changed | Where-Object { $_ -ne $edition })
    foreach ($other in $otherEditions) {
        if ($script:Context.repairs.$other -ge $script:Settings.maxRepairs) { return $false }
    }
    foreach ($other in $otherEditions) { $script:Context.repairs.$other++ }
    Save-Run
    foreach ($file in $changed) {
        $relative = $file.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $target = Join-Path $script:Repository $relative
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Copy-Item -LiteralPath (Join-Path $repairSource $relative) -Destination $target
    }
    Invoke-LoggedProcess $script:Settings.jj @('diff', '--stat') -WorkingDirectory $script:Repository -LogName 'jj-repair-diff' | Out-Null
    return $true
}

function Write-Report {
    $selected = @()
    foreach ($edition in @('tahoe', 'win95')) {
        $candidates = @($script:Context.candidates | Where-Object { $_.edition -eq $edition })
        if (-not $candidates.Count) { continue }
        $passing = @($candidates | Where-Object accepted | Select-Object -Last 1)
        $selected += if ($passing.Count) { $passing[0] } else { $candidates | Sort-Object failedCount | Select-Object -First 1 }
    }
    Write-Json "$script:RunDirectory\selected.json" $selected
    $rows = foreach ($candidate in $selected) {
        $path = [IO.Path]::GetRelativePath($script:RunDirectory, $candidate.directory).Replace('\', '/')
        $status = if ($candidate.accepted) { 'PASS' } else { "UNVERIFIED / $($candidate.failedCount) failed requirements" }
        '<tr><td>{0}</td><td>{1}</td><td><a href="{2}/verification.json">Verification</a> · <a href="{2}/candidate.json">Source</a></td><td><code>{3}</code></td></tr>' -f $candidate.edition, $status, $path, $candidate.sha256
    }
    $measured = @($selected) + @($script:Context.baselines | Group-Object edition | ForEach-Object { $_.Group | Select-Object -Last 1 })
    $performanceRows = foreach ($candidate in $measured) {
        $evidence = Join-Path $candidate.directory 'performance.json'
        if (-not (Test-Path -LiteralPath $evidence)) { continue }
        $metrics = Get-Content -LiteralPath $evidence -Raw | ConvertFrom-Json
        $path = [IO.Path]::GetRelativePath($script:RunDirectory, $candidate.directory).Replace('\', '/')
        $kind = if ($candidate.baseline) { 'Baseline' } else { 'Candidate' }
        '<tr><td>{0}</td><td>{1}</td><td>{2:N3}</td><td>{3:N3}</td><td>{4:N1}</td><td>{5}</td><td><a href="{6}/performance.json">Measurements</a></td></tr>' -f $candidate.edition, $kind, ($metrics.ramBytes / 1GB), $metrics.cpuPercent, $metrics.readySeconds, $metrics.hardwareRendering, $path
    }
    $candidateFailures = foreach ($candidate in $selected) {
        $evidence = Join-Path $candidate.directory 'verification.json'
        if (Test-Path -LiteralPath $evidence) {
            [ordered]@{ edition = $candidate.edition; candidate = $candidate.label; requirements = (Get-Content -LiteralPath $evidence -Raw | ConvertFrom-Json).failed }
        }
    }
    $memoryRows = foreach ($candidate in $measured) {
        $path = [IO.Path]::GetRelativePath($script:RunDirectory, $candidate.directory).Replace('\', '/')
        $kind = if ($candidate.baseline) { 'Baseline' } else { 'Candidate' }
        foreach ($boot in 1..$script:Settings.confirmBoots) {
            $evidence = Join-Path $candidate.directory "boot-$boot\process-memory.json"
            if (-not (Test-Path -LiteralPath $evidence)) { continue }
            $processes = (Get-Content -LiteralPath $evidence -Raw | ConvertFrom-Json).topProcesses | Select-Object -First 5
            foreach ($process in $processes) {
                '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3} ({4})</td><td>{5:N1}</td><td>{6:N1}</td><td><a href="{7}/boot-{2}/process-memory.json">Samples</a></td></tr>' -f $candidate.edition, $kind, $boot, [Net.WebUtility]::HtmlEncode($process.name), $process.pid, ($process.averageRssBytes / 1MB), ($process.peakRssBytes / 1MB), $path
            }
        }
    }
    $baselineNotes = foreach ($candidate in $script:Context.baselines) {
        $path = [IO.Path]::GetRelativePath($script:RunDirectory, $candidate.directory).Replace('\', '/')
        foreach ($boot in 1..$script:Settings.confirmBoots) {
            $evidence = Join-Path $candidate.directory "boot-$boot\baseline-win95-compat.py.json"
            if (-not (Test-Path -LiteralPath $evidence)) { continue }
            $compatibility = Get-Content -LiteralPath $evidence -Raw | ConvertFrom-Json
            if ($compatibility.exitCode -eq 0 -and $compatibility.stdout -match '"qtQuickBackend"\s*:\s*"software"') {
                '<li>Win95 baseline boot {0}: Quickshell required its recorded software-rendering workaround. The Wayland EGL hardware result does not describe this panel. Candidates receive no such workaround. <a href="{1}/boot-{0}/baseline-win95-compat.py.json">Intervention evidence</a></li>' -f $boot, $path
            }
        }
    }
    $failures = [Net.WebUtility]::HtmlEncode((@{ runErrors = $script:Context.failures; candidates = @($candidateFailures) } | ConvertTo-Json -Depth 10))
    @"
<!doctype html><meta charset="utf-8"><title>Nix desktop inspection</title>
<style>body{font:16px system-ui;margin:40px;max-width:1200px}table{border-collapse:collapse}td,th{padding:12px;border:1px solid #ccc}code{overflow-wrap:anywhere}pre{white-space:pre-wrap}</style>
<h1>Nix desktop inspection</h1><p>Run $($script:Context.id). Status: $($script:Context.status).</p>
<p>Acceptance requires evidence from three fresh boots, both resolutions, hardware rendering, functional checks and median performance relative to the baseline.</p>
<table><tr><th>Edition</th><th>Acceptance</th><th>Report</th><th>ISO SHA-256</th></tr>$($rows -join "`n")</table>
<h2>Median idle performance</h2>
<table><tr><th>Edition</th><th>Source</th><th>RAM GiB</th><th>CPU %</th><th>Ready seconds</th><th>Hardware renderer</th><th>Evidence</th></tr>$($performanceRows -join "`n")</table>
<ul>$($baselineNotes -join "`n")</ul>
<h2>Largest idle processes</h2><p>Average over sampled appearances and peak resident memory during the 120-second idle sample, in MiB. Shared pages make these process values non-additive.</p>
<table><tr><th>Edition</th><th>Source</th><th>Boot</th><th>Process (PID)</th><th>Average MiB</th><th>Peak MiB</th><th>Evidence</th></tr>$($memoryRows -join "`n")</table>
<p><a href="run.json">Complete JSON run</a> · <a href="criteria.json">Frozen visual criteria</a> · <a href="config.json">Frozen limits</a> · <a href="selected.json">Retained candidates</a></p>
<h2>Failures / missing evidence</h2><pre>$failures</pre>
"@ | Set-Content "$script:RunDirectory\report.html" -Encoding utf8NoBOM
}

function Import-RunArtifacts([string]$ReuseRunId, [string[]]$Editions, [switch]$BaselineOnly) {
    if (-not $ReuseRunId) { throw 'Adopt mode requires -ReuseRunId.' }
    $artifactRoot = [IO.Path]::GetFullPath($script:Settings.artifactRoot).TrimEnd('\') + '\'
    $priorDirectory = [IO.Path]::GetFullPath((Join-Path $artifactRoot $ReuseRunId))
    if (-not $priorDirectory.StartsWith($artifactRoot, [StringComparison]::OrdinalIgnoreCase) -or $priorDirectory -eq $script:RunDirectory) { throw 'Prior run must be a different directory under the configured artifact root.' }
    $prior = Get-Content -LiteralPath (Join-Path $priorDirectory 'run.json') -Raw | ConvertFrom-Json
    if (-not $BaselineOnly) {
        foreach ($property in @('criteriaHash', 'configHash', 'referencesDefinitionHash')) {
            if ($prior.$property -ne $script:Context.$property) { throw "Cannot adopt artifacts with different frozen $property." }
        }
    }
    $kinds = if ($BaselineOnly) { @('baselines') } else { @('baselines', 'candidates') }
    foreach ($edition in $Editions) {
        foreach ($kind in $kinds) {
            $original = @($prior.$kind | Where-Object { $_.edition -eq $edition } | Select-Object -Last 1)
            if ($original.Count -ne 1) { throw "Prior run has no built $edition artifact in $kind." }
            $item = $original[0]
            if ($BaselineOnly -and -not $item.baseline) { throw 'Baseline reuse requires a recorded baseline ISO.' }
            $iso = [IO.Path]::GetFullPath($item.iso)
            if (-not $iso.StartsWith($artifactRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $iso)) { throw "Prior ISO is unavailable inside the artifact root: $iso" }
            if ((Get-FileHash -LiteralPath $iso).Hash.ToLowerInvariant() -ne $item.sha256) { throw "Prior ISO checksum changed: $iso" }
            $sourceManifest = Join-Path $item.source 'source-hashes.json'
            if (-not (Test-Path -LiteralPath $sourceManifest) -or (Get-FileHash -LiteralPath $sourceManifest).Hash -ne $item.sourceManifestHash) { throw "Prior source manifest changed: $sourceManifest" }
            $recordedFiles = (Get-Content -LiteralPath $sourceManifest -Raw | ConvertFrom-Json).files
            $liveFiles = Get-SourceManifest $item.source
            if ($liveFiles.Count -ne @($recordedFiles.PSObject.Properties).Count) { throw "Prior source inventory changed: $($item.source)" }
            foreach ($file in $recordedFiles.PSObject.Properties) {
                if (-not $liveFiles.Contains($file.Name) -or $liveFiles[$file.Name] -ne $file.Value) { throw "Prior source file changed: $($file.Name)" }
            }
            $label = "reused-$($item.label)"
            $directory = Join-Path $script:RunDirectory $label
            if (Test-Path -LiteralPath $directory) { throw "Adopt destination already exists: $directory" }
            New-Item -ItemType Directory -Path $directory | Out-Null
            $linkedIso = Join-Path $directory ([IO.Path]::GetFileName($iso))
            New-Item -ItemType HardLink -Path $linkedIso -Target $iso | Out-Null
            $candidate = [pscustomobject]@{
                label = $label; edition = $edition; baseline = ($kind -eq 'baselines'); directory = $directory; source = $item.source
                iso = $linkedIso; sha256 = $item.sha256; storePath = $item.storePath; sourceManifestHash = $item.sourceManifestHash
                verification = @(); accepted = $false; failedCount = 999
            }
            "$($candidate.sha256)  $([IO.Path]::GetFileName($linkedIso))" | Set-Content (Join-Path $directory 'SHA256SUMS')
            Write-Json (Join-Path $directory 'reuse.json') @{ originalRun = $ReuseRunId; originalIso = $iso; sourceManifest = $sourceManifest; isoSha256 = $item.sha256; verification = 'fresh boots required' }
            Write-Json (Join-Path $directory 'candidate.json') $candidate
            if ($candidate.baseline) { $script:Context.baselines += $candidate } else { $script:Context.candidates += $candidate }
        }
    }
    Save-Run
}

function Invoke-DesktopWorkflow {
    [CmdletBinding()]
    param([string]$Mode, [string]$Edition, [string]$ConfigPath, [string]$CandidatePath, [string]$RunId, [string]$ReuseRunId, [switch]$Baseline)
    $script:Context = $null
    $mutex = [Threading.Mutex]::new($false, 'Local\NixDesktopWorkflow')
    if (-not $mutex.WaitOne(0)) { throw 'Another desktop build/inspection workflow is active.' }
    try {
        Initialize-Run $ConfigPath $RunId $Edition $CandidatePath
        $editions = if ($Edition -eq 'both') { @('tahoe', 'win95') } else { @($Edition) }
        if ($Mode -eq 'adopt') { Invoke-AdoptionPreflight } elseif ($Mode -ne 'verify') { Invoke-Preflight }
        switch ($Mode) {
            'preflight' { $script:Context.status = 'preflight-passed' }
            'build' { foreach ($name in $editions) { Build-Edition $name -Baseline:$Baseline | Out-Null }; $script:Context.status = 'built' }
            'adopt' { Import-RunArtifacts $ReuseRunId $editions; $script:Context.status = 'reused-builds' }
            'verify' {
                foreach ($name in $editions) {
                    $list = if ($Baseline) { $script:Context.baselines } else { $script:Context.candidates }
                    $candidate = @($list | Where-Object { $_.edition -eq $name } | Select-Object -Last 1)
                    if (-not $candidate.Count) { throw "No built $name candidate in this run. Supply the build RunId." }
                    Verify-Candidate $candidate[0] | Out-Null
                }
                $script:Context.status = 'verification-finished'
            }
            'improve' {
                if ($ReuseRunId -and -not $script:Context.baselines.Count) {
                    Import-RunArtifacts $ReuseRunId $editions -BaselineOnly
                }
                foreach ($name in $editions) {
                    $baselineCandidate = @($script:Context.baselines | Where-Object { $_.edition -eq $name } | Select-Object -Last 1)
                    $completeBaseline = $baselineCandidate.Count -and (Test-Path "$($baselineCandidate[0].directory)\performance.json") -and @($baselineCandidate[0].verification | Where-Object { $null -ne $_.metrics }).Count -eq $script:Settings.confirmBoots
                    if (-not $completeBaseline) {
                        $baselineCandidate = if ($baselineCandidate.Count) {
                            Verify-Candidate $baselineCandidate[0]
                        } else {
                            Verify-Candidate (Build-Edition $name -Baseline)
                        }
                        if (@($baselineCandidate.verification | Where-Object { $null -ne $_.metrics }).Count -ne $script:Settings.confirmBoots) { throw "The $name baseline did not produce metrics from all $($script:Settings.confirmBoots) fresh boots; candidate builds are blocked." }
                    }
                }
                $previousFailure = @{}
                while ($true) {
                    $candidates = @()
                    foreach ($name in $editions) { $candidates += Verify-Candidate (Build-Edition $name) }
                    if (@($candidates | Where-Object { -not $_.accepted }).Count -eq 0) { $script:Context.status = 'accepted'; break }
                    $target = $candidates | Where-Object { -not $_.accepted } | Sort-Object failedCount -Descending | Select-Object -First 1
                    $failure = Get-Content "$($target.directory)\verification.json" -Raw | ConvertFrom-Json
                    $signature = @($failure.failed | Sort-Object) -join ','
                    if ($previousFailure[$target.edition] -eq $signature) { $script:Context.status = 'repeated-identical-failures'; break }
                    $previousFailure[$target.edition] = $signature
                    if (-not (Invoke-Repair $target)) { $script:Context.status = 'repair-budget-or-no-progress'; break }
                    # Shared desktop changes invalidate both editions. Always build and reverify both.
                    $editions = @('tahoe', 'win95')
                }
            }
        }
    } catch {
        if ($script:Context) { $script:Context.failures += $_.Exception.Message; $script:Context.status = 'stopped-with-failures' }
        Write-Warning $_.Exception.Message
        throw
    } finally {
        if ($script:Context) { Save-Run; Write-Report }
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}

Export-ModuleMember -Function Invoke-DesktopWorkflow, Invoke-LoggedProcess, Get-Median, Get-SourceManifest
