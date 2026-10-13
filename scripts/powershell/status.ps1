#Requires -Version 5.1
param([string]$Feature)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-RepoRoot([string]$StartDir) {
    $dir = $StartDir
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.specify') -PathType Container) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}
function Get-CheckboxCounts([string]$Path) {
    $checked = 0; $total = 0; $fence = ''; $size = 0
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $stripped = $line.TrimStart()
        if ($stripped -match '^(`{3,}|~{3,})(.*)$') {
            $token = $Matches[1]; $tail = $Matches[2]
            if (-not $fence) { $fence = $token.Substring(0,1); $size = $token.Length }
            elseif ($token.Substring(0,1) -eq $fence -and $token.Length -ge $size -and -not $tail.Trim()) { $fence = '' }
            continue
        }
        if (-not $fence -and $stripped -match '^-\s+\[([ xX])\](?:\s|$)') {
            $total++
            if ($Matches[1] -match '[xX]') { $checked++ }
        }
    }
    return @{ completed = $checked; total = $total }
}
function Get-FeatureStatus([string]$Directory) {
    $artifacts = [ordered]@{}
    foreach ($key in @('spec','plan','tasks','research','data-model','quickstart')) {
        $artifacts[$key.Replace('-','_')] = [bool]($Directory -and (Test-Path -LiteralPath (Join-Path $Directory "$key.md") -PathType Leaf))
    }
    $tasks = @{ completed = 0; total = 0 }; $name = ''
    $phase = 'no_feature'; $hint = 'Select -Feature or a numbered branch; no latest feature is inferred'
    $contracts = @(); $checklists = @(); $checklistsPass = $true
    if ($Directory) {
        $name = Split-Path $Directory -Leaf
        if ($artifacts.tasks) {
            $tasks = Get-CheckboxCounts (Join-Path $Directory 'tasks.md')
            if ($tasks.total -eq 0) { $phase = 'no_tasks'; $hint = 'No actionable tasks; roadmap pending' }
            elseif ($tasks.completed -eq $tasks.total) { $phase = 'tasks_checked'; $hint = 'Task bookkeeping checked; engineering acceptance is not assessed' }
            else { $phase = 'implement'; $hint = 'Tasks available; verify authorization before implementation' }
        } elseif ($artifacts.plan) { $phase = 'tasks'; $hint = 'Plan exists; tasks are absent' }
        elseif ($artifacts.spec) { $phase = 'plan'; $hint = 'Specification exists; plan is absent' }
        else { $phase = 'not_started'; $hint = 'Specification is absent' }
        if (Test-Path -LiteralPath (Join-Path $Directory 'contracts') -PathType Container) {
            $contracts = @(Get-ChildItem -LiteralPath (Join-Path $Directory 'contracts') -File)
        }
        if (Test-Path -LiteralPath (Join-Path $Directory 'checklists') -PathType Container) {
            $checklists = @(Get-ChildItem -LiteralPath (Join-Path $Directory 'checklists') -File -Filter '*.md')
        }
        foreach ($checklist in $checklists) {
            $counts = Get-CheckboxCounts $checklist.FullName
            if ($counts.completed -ne $counts.total) { $checklistsPass = $false }
        }
    }
    $artifacts.contracts = $contracts.Count -gt 0; $artifacts.contract_count = $contracts.Count
    $artifacts.checklists = $checklists.Count -gt 0; $artifacts.checklist_count = $checklists.Count
    $artifacts.checklists_all_pass = $checklistsPass
    $state = if ($tasks.total -gt 0) { 'TASKS_AVAILABLE' } else { 'ROADMAP_PENDING' }
    return [ordered]@{ feature_name=$name; artifacts=$artifacts; tasks=$tasks; task_state=$state; phase=$phase; phase_hint=$hint; acceptance='NOT_ASSESSED' }
}
try {
    if ($args.Count -gt 0) { throw 'Unknown arguments; use -Feature NNN[-name]' }
    if ($PSBoundParameters.ContainsKey('Feature') -and -not $Feature) { throw '-Feature requires a value' }
    if ($env:SPECIFY_INIT_DIR) {
        $RepoRoot = (Resolve-Path -LiteralPath $env:SPECIFY_INIT_DIR).Path
    } else { $RepoRoot = Find-RepoRoot (Get-Location).Path }
    if (-not $RepoRoot -or -not (Test-Path -LiteralPath (Join-Path $RepoRoot '.specify') -PathType Container)) { throw 'Not a spec-kit project (no .specify directory)' }
    $SpecifyDir = Join-Path $RepoRoot '.specify'; $SpecsDir = Join-Path $RepoRoot 'specs'
    $HasGit = $false; $CurrentBranch = ''
    if (Get-Command git -ErrorAction SilentlyContinue) {
        # Native stderr becomes terminating ErrorRecord on Windows PowerShell 5.1
        # under Stop; absence of a Git worktree is a supported summary case.
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $gitRoot = & git -C $RepoRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0) {
                $HasGit = $true
                $branch = & git -C $RepoRoot symbolic-ref --quiet --short HEAD 2>$null
                if ($LASTEXITCODE -eq 0) { $CurrentBranch = [string]$branch }
            }
        } finally { $ErrorActionPreference = $previousPreference }
    }
    $selector = if ($PSBoundParameters.ContainsKey('Feature')) { $Feature } else { $env:SPECIFY_FEATURE }
    if (-not $selector -and $CurrentBranch -match '^\d{3}-') { $selector = $CurrentBranch }
    $directories = @()
    if (Test-Path -LiteralPath $SpecsDir -PathType Container) {
        $directories = @(Get-ChildItem -LiteralPath $SpecsDir -Directory | Where-Object { $_.Name -match '^\d{3}-' } | Sort-Object Name)
    }
    $FeatureDir = ''
    if ($selector) {
        if ($selector -notmatch '^\d{3}(-[a-zA-Z0-9-]+)?$') { throw 'Feature must be NNN or NNN-name' }
        $exact = @($directories | Where-Object { $_.Name -eq $selector })
        if ($exact.Count -eq 1) { $FeatureDir = $exact[0].FullName }
        else {
            $prefix = $selector.Substring(0,3)
            $candidates = @($directories | Where-Object { $_.Name.StartsWith("$prefix-") })
            if ($candidates.Count -gt 1) { throw "Ambiguous feature prefix: $selector; use the exact directory name" }
            if ($candidates.Count -eq 0) { throw "No specification directory for: $selector" }
            $FeatureDir = $candidates[0].FullName
        }
    }
$AgentDefs = @(
    @{ Key='copilot';      Name='GitHub Copilot'; Folder='.github';        CmdDir='agents' },
    @{ Key='claude';       Name='Claude Code';    Folder='.claude';        CmdDir='commands' },
    @{ Key='gemini';       Name='Gemini CLI';     Folder='.gemini';        CmdDir='commands' },
    @{ Key='cursor-agent'; Name='Cursor';         Folder='.cursor';        CmdDir='commands' },
    @{ Key='qwen';         Name='Qwen Code';      Folder='.qwen';          CmdDir='commands' },
    @{ Key='opencode';     Name='opencode';        Folder='.opencode';      CmdDir='command' },
    @{ Key='codex';        Name='Codex CLI';      Folder='.codex';         CmdDir='prompts' },
    @{ Key='windsurf';     Name='Windsurf';        Folder='.windsurf';      CmdDir='workflows' },
    @{ Key='kilocode';     Name='Kilo Code';      Folder='.kilocode';      CmdDir='workflows' },
    @{ Key='auggie';       Name='Auggie CLI';     Folder='.augment';       CmdDir='commands' },
    @{ Key='codebuddy';    Name='CodeBuddy';       Folder='.codebuddy';     CmdDir='commands' },
    @{ Key='qodercli';     Name='Qoder CLI';      Folder='.qoder';         CmdDir='commands' },
    @{ Key='roo';          Name='Roo Code';        Folder='.roo';           CmdDir='commands' },
    @{ Key='kiro-cli';     Name='Kiro CLI';       Folder='.kiro';          CmdDir='prompts' },
    @{ Key='amp';          Name='Amp';              Folder='.agents';        CmdDir='commands' },
    @{ Key='shai';         Name='SHAI';             Folder='.shai';          CmdDir='commands' },
    @{ Key='tabnine';      Name='Tabnine CLI';    Folder='.tabnine/agent'; CmdDir='commands' },
    @{ Key='agy';          Name='Antigravity';     Folder='.agent';         CmdDir='workflows' },
    @{ Key='bob';          Name='IBM Bob';         Folder='.bob';           CmdDir='commands' },
    @{ Key='vibe';         Name='Mistral Vibe';   Folder='.vibe';          CmdDir='prompts' },
    @{ Key='kimi';         Name='Kimi Code';      Folder='.kimi';          CmdDir='skills' }
)

    $codexSkills = @(Get-ChildItem -Path (Join-Path $RepoRoot '.agents/skills/speckit-*/SKILL.md') -File -ErrorAction SilentlyContinue).Count -gt 0
    $detected = @()
    foreach ($agent in $AgentDefs) {
        $agentDir = Join-Path $RepoRoot $agent.Folder
        if ($agent.Key -eq 'amp' -and -not (Test-Path -LiteralPath (Join-Path $agentDir 'commands') -PathType Container)) { continue }
        if ((Test-Path -LiteralPath $agentDir -PathType Container) -or ($agent.Key -eq 'codex' -and $codexSkills)) {
            $cmdDir = Join-Path $agentDir $agent.CmdDir
            $hasCommands = (Test-Path -LiteralPath $cmdDir -PathType Container) -and (@(Get-ChildItem -LiteralPath $cmdDir).Count -gt 0)
            $folder = $agent.Folder
            if ($agent.Key -eq 'codex' -and $codexSkills) { $hasCommands = $true; $folder = '.agents/skills' }
            $detected += @{ key=$agent.Key; name=$agent.Name; folder="$folder/"; has_commands=[bool]$hasCommands }
        }
    }
    $scriptType = 'none'
    if (Test-Path -LiteralPath (Join-Path $SpecifyDir 'scripts/bash') -PathType Container) { $scriptType = 'sh' }
    if (Test-Path -LiteralPath (Join-Path $SpecifyDir 'scripts/powershell') -PathType Container) {
        $scriptType = if ($scriptType -eq 'sh') { 'sh + ps' } else { 'ps' }
    }
    $features = @(); $total = 0; $completed = 0
    foreach ($directory in $directories) {
        $row = Get-FeatureStatus $directory.FullName; $features += $row
        $total += $row.tasks.total; $completed += $row.tasks.completed
    }
    $installedCount = $null
    $registryFile = Join-Path $SpecifyDir 'extensions/.registry'
    if (Test-Path -LiteralPath $registryFile -PathType Leaf) {
        $registry = Get-Content -LiteralPath $registryFile -Raw | ConvertFrom-Json
        if (-not ($registry.PSObject.Properties.Name -contains 'extensions') -or $registry.extensions -isnot [System.Management.Automation.PSCustomObject]) { throw 'Invalid extension registry' }
        $installedCount = @($registry.extensions.PSObject.Properties).Count
    }
    $result = Get-FeatureStatus $FeatureDir
    $result.project_name = Split-Path $RepoRoot -Leaf
    $result.has_git = $HasGit; $result.current_branch = $CurrentBranch; $result.script_type = $scriptType
    $result.agents = @($detected); $result.installed_extensions = $installedCount; $result.feature_count = $features.Count
    $result.features = @($features)
    $state = if ($total -gt 0) { 'TASKS_AVAILABLE' } else { 'ROADMAP_PENDING' }
    $result.summary = @{ tasks=@{ completed=$completed; total=$total }; task_state=$state; acceptance='NOT_ASSESSED' }
    $result.live_status = 'NOT_QUERIED'
    $result | ConvertTo-Json -Depth 12 -Compress
} catch {
    @{ error=$_.Exception.Message } | ConvertTo-Json -Compress
    exit 1
}
