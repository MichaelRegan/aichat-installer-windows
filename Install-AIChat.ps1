<#
.SYNOPSIS
    Install aichat CLI tool on Windows with comprehensive configuration.

.DESCRIPTION
    Downloads and installs aichat using winget, configures shell integration,
    installs completions, and sets up the local system context role.

.PARAMETER Version
    Specific version to install (default: latest)

.PARAMETER DryRun
    Preview changes without making modifications

.PARAMETER Json
    Output dry-run plan as JSON (requires -DryRun)

.PARAMETER NoWrapper
    Skip creating the aichat wrapper function

.PARAMETER SkipRole
    Skip installing the role generator and system context configuration

.PARAMETER AssumeYes
    Automatically answer yes to all prompts (non-interactive mode)

.EXAMPLE
    .\Install-AIChat.ps1
    # Interactive installation with latest version

.EXAMPLE
    .\Install-AIChat.ps1 -DryRun -Json
    # Preview installation plan as JSON

.EXAMPLE
    .\Install-AIChat.ps1 -NoWrapper -SkipRole -AssumeYes
    # Minimal automated installation
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Version = "latest",
    
    [switch]$DryRun,
    [switch]$Json,
    [switch]$NoWrapper,
    [switch]$SkipRole,
    [switch]$AssumeYes
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------

function Write-Status {
    param([string]$Message, [string]$Emoji = "ℹ️")
    if (-not $Json -or -not $DryRun) {
        Write-Host "$Emoji $Message" -ForegroundColor Cyan
    }
}

function Write-Success {
    param([string]$Message)
    if (-not $Json -or -not $DryRun) {
        Write-Host "✅ $Message" -ForegroundColor Green
    }
}

function Write-Warning2 {
    param([string]$Message)
    if (-not $Json -or -not $DryRun) {
        Write-Warning "⚠️  $Message"
    }
}

function Confirm-Action {
    param(
        [string]$Message,
        [bool]$DefaultYes = $true
    )
    
    if ($AssumeYes) {
        Write-Status "(auto-yes) $Message" "🤖"
        return $true
    }
    
    $prompt = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    $response = Read-Host "$Message $prompt"
    
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }
    
    return $response -match '^[Yy]'
}

function Get-AIChatVersion {
    try {
        $installed = winget list --id sigoden.aichat --exact 2>$null | Select-String "sigoden.aichat"
        if ($installed) {
            $parts = $installed -split '\s+' | Where-Object { $_ -match '^\d+\.\d+\.\d+$' }
            return $parts[0]
        }
    }
    catch {
        return $null
    }
    return $null
}

function Get-SystemArchitecture {
    $arch = [System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')
    switch ($arch) {
        'AMD64' { return 'x86_64' }
        'ARM64' { return 'aarch64' }
        default { return $arch.ToLower() }
    }
}

function Get-ConfigPath {
    $configBase = if ($env:APPDATA) { $env:APPDATA } else { "$env:USERPROFILE\AppData\Roaming" }
    return Join-Path $configBase "aichat"
}

function Initialize-AIChatConfig {
    $configDir = Get-ConfigPath
    $rolesDir = Join-Path $configDir "roles"
    $configFile = Join-Path $configDir "config.yaml"
    
    Write-Status "Ensuring aichat configuration directories exist..." "📁"
    
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path $rolesDir)) {
        New-Item -Path $rolesDir -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $configFile)) {
        Write-Status "Creating default configuration..." "📝"
        
        @"
# see https://github.com/sigoden/aichat/blob/main/config.example.yaml

model: gpt-4o-mini
stream: true
keybindings: emacs

# Visit https://github.com/sigoden/llm-functions for setup instructions
function_calling: true
mapping_tools:
  fs: 'fs_cat,fs_ls,fs_mkdir,fs_rm,fs_write'
use_tools: null

save_session: null
compress_threshold: 4000
highlight: true
save_shell_history: true

# Use local role by default for system-aware responses
prelude: "role:local"
"@ | Out-File -FilePath $configFile -Encoding UTF8
        
        Write-Success "Config file created: $configFile"
    }
    else {
        Write-Status "Config file already exists: $configFile"
    }
}

function Install-ShellIntegration {
    Write-Status "Installing PowerShell integration..." "🔗"
    
    $profileDir = Split-Path -Parent $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
    }
    
    $integrationBlock = @'

# aichat PowerShell integration
function Invoke-AIChatEnhance {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    
    if ($line) {
        try {
            $enhanced = aichat -e $line 2>$null
            if ($enhanced) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $enhanced)
            }
        }
        catch {
            # Silently fail if aichat not available
        }
    }
}

# Bind Alt+E to AI enhancement
Set-PSReadLineKeyHandler -Chord 'Alt+e' -ScriptBlock { Invoke-AIChatEnhance }
'@
    
    if (Test-Path $PROFILE) {
        $content = Get-Content $PROFILE -Raw
        if ($content -match 'aichat PowerShell integration') {
            Write-Status "PowerShell integration already installed"
            
            if (Confirm-Action "Reinstall PowerShell integration?") {
                $content = $content -replace '(?s)# aichat PowerShell integration.*?Set-PSReadLineKeyHandler.*?\n', ''
                $content += $integrationBlock
                $content | Out-File -FilePath $PROFILE -Encoding UTF8
                Write-Success "PowerShell integration reinstalled"
            }
        }
        else {
            $integrationBlock | Out-File -FilePath $PROFILE -Append -Encoding UTF8
            Write-Success "PowerShell integration added to profile"
        }
    }
    else {
        $integrationBlock | Out-File -FilePath $PROFILE -Encoding UTF8
        Write-Success "PowerShell profile created with integration"
    }
    
    Write-Status "Press Alt+E in your terminal to enhance commands with AI" "💡"
}

function Install-Completions {
    Write-Status "Installing PowerShell completions..." "⚙️"
    
    # PowerShell completions are typically handled by the module itself
    # For aichat, we'll register a basic argument completer
    
    $completionScript = @'

# aichat PowerShell completions
Register-ArgumentCompleter -Native -CommandName aichat -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $completions = @(
        '--help', '--version', '--model', '--role', '--session',
        '--save-session', '--serve', '--execute', '-e',
        '--code', '-c', '--file', '-f', '--no-stream',
        '--dry-run', '--info', '--list-models', '--list-roles',
        '--list-sessions'
    )
    
    $completions | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
'@
    
    if (Test-Path $PROFILE) {
        $content = Get-Content $PROFILE -Raw
        if ($content -notmatch 'aichat PowerShell completions') {
            $completionScript | Out-File -FilePath $PROFILE -Append -Encoding UTF8
            Write-Success "Completions registered in PowerShell profile"
        }
        else {
            Write-Status "Completions already registered"
        }
    }
}

# ------------------------------------------------------------------
# Main Installation Logic
# ------------------------------------------------------------------

function Main {
    Write-Host "`n🚀 AIChat Windows Installer" -ForegroundColor Cyan
    Write-Host "=" * 50
    
    # Detect current version
    $currentVersion = Get-AIChatVersion
    $arch = Get-SystemArchitecture
    
    # Build dry-run plan
    if ($DryRun) {
        $plan = @{
            mode = "dry-run"
            target_version = $Version
            current_version = $currentVersion
            architecture = $arch
            package_manager = "winget"
            package_id = "sigoden.aichat"
            config_path = Get-ConfigPath
            wrapper = @{
                planned = -not $NoWrapper
                skip_reason = if ($NoWrapper) { "--NoWrapper specified" } else { $null }
            }
            role_generator = @{
                planned = -not $SkipRole
                skip_reason = if ($SkipRole) { "--SkipRole specified" } else { $null }
            }
            shell = @{
                detected = "PowerShell"
                version = $PSVersionTable.PSVersion.ToString()
                integration_planned = $true
            }
            completions = @("PowerShell")
            config = @{
                path = Join-Path (Get-ConfigPath) "config.yaml"
                action = "create_or_augment"
            }
            flags = @{
                dry_run = $DryRun.IsPresent
                json = $Json.IsPresent
                no_wrapper = $NoWrapper.IsPresent
                skip_role = $SkipRole.IsPresent
                assume_yes = $AssumeYes.IsPresent
            }
        }
        
        if ($Json) {
            $plan | ConvertTo-Json -Depth 10
        }
        else {
            Write-Host "`n🧪 DRY-RUN MODE (no changes will be made)" -ForegroundColor Yellow
            Write-Host "   Target version: $($plan.target_version)"
            Write-Host "   Current version: $(if ($plan.current_version) { $plan.current_version } else { 'not installed' })"
            Write-Host "   Architecture: $($plan.architecture)"
            Write-Host "   Package manager: winget"
            Write-Host "   Config path: $($plan.config_path)"
            if ($NoWrapper) {
                Write-Host "   Wrapper: skipped (--NoWrapper)" -ForegroundColor Yellow
            }
            else {
                Write-Host "   Wrapper: PowerShell function will be created"
            }
            if ($SkipRole) {
                Write-Host "   Role generator: skipped (--SkipRole)" -ForegroundColor Yellow
            }
            else {
                Write-Host "   Role generator: New-AIChatRole.ps1 will be installed"
            }
            Write-Host "   Shell integration: PowerShell (Alt+E binding)"
            Write-Host "   Completions: PowerShell argument completer"
            Write-Host "`n✅ Dry-run completed successfully (no filesystem changes)" -ForegroundColor Green
        }
        return
    }
    
    # Real installation
    Write-Status "Target version: $Version"
    if ($currentVersion) {
        Write-Status "Current version: $currentVersion" "ℹ️"
        if (-not (Confirm-Action "Continue with installation/update?")) {
            Write-Warning2 "Installation cancelled"
            return
        }
    }
    
    # Install via winget
    Write-Status "Installing aichat via winget..." "📦"
    try {
        if ($Version -eq "latest") {
            winget install --id sigoden.aichat --silent --accept-package-agreements --accept-source-agreements
        }
        else {
            winget install --id sigoden.aichat --version $Version --silent --accept-package-agreements --accept-source-agreements
        }
        Write-Success "aichat installed successfully"
    }
    catch {
        Write-Error "Failed to install aichat: $_"
        return
    }
    
    # Initialize configuration
    Initialize-AIChatConfig
    
    # Install role generator
    if (-not $SkipRole) {
        $roleScriptPath = Join-Path $PSScriptRoot "scripts\New-AIChatRole.ps1"
        if (Test-Path $roleScriptPath) {
            Write-Status "Installing role generator..." "🧩"
            $installPath = Join-Path $env:USERPROFILE ".local\bin"
            if (-not (Test-Path $installPath)) {
                New-Item -Path $installPath -ItemType Directory -Force | Out-Null
            }
            Copy-Item $roleScriptPath -Destination (Join-Path $installPath "New-AIChatRole.ps1") -Force
            Write-Success "Role generator installed to: $(Join-Path $installPath 'New-AIChatRole.ps1')"
            
            # Generate initial role
            try {
                & (Join-Path $installPath "New-AIChatRole.ps1") -ErrorAction SilentlyContinue
                Write-Success "Initial local role generated"
            }
            catch {
                Write-Warning2 "Could not generate initial role (will be created on first run)"
            }
        }
        else {
            Write-Warning2 "Role generator script not found at: $roleScriptPath"
        }
    }
    
    # Install shell integration
    if (Confirm-Action "Install PowerShell integration (Alt+E command enhancement)?") {
        Install-ShellIntegration
        Install-Completions
    }
    
    # Create wrapper function
    if (-not $NoWrapper -and -not $SkipRole) {
        Write-Status "Creating aichat wrapper function..." "🔄"
        
        $wrapperFunction = @'

# aichat wrapper - ensures local role is always fresh and uses local role by default
function aichat {
    $roleScript = Join-Path $env:USERPROFILE ".local\bin\New-AIChatRole.ps1"
    if (Test-Path $roleScript) {
        & $roleScript -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Check if no role is specified and add -r local if so
    $hasRoleArg = $false
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq '-r' -or $args[$i] -eq '--role') {
            $hasRoleArg = $true
            break
        }
    }
    
    if (-not $hasRoleArg) {
        # No role specified, add local role as default
        $finalArgs = @('-r', 'local') + $args
    } else {
        # Role already specified, use as-is
        $finalArgs = $args
    }
    
    # Call actual aichat with final arguments
    & (Get-Command aichat.exe).Source @finalArgs
}
'@
        
        if (Test-Path $PROFILE) {
            $content = Get-Content $PROFILE -Raw
            if ($content -notmatch '# aichat wrapper') {
                $wrapperFunction | Out-File -FilePath $PROFILE -Append -Encoding UTF8
                Write-Success "Wrapper function added to PowerShell profile"
            }
        }
    }
    
    # Summary
    Write-Host "`n✨ Installation Complete!" -ForegroundColor Green
    Write-Host "=" * 50
    Write-Host "📍 aichat is now installed and configured"
    Write-Host "🔄 Restart PowerShell or run: . `$PROFILE"
    Write-Host "💡 Try: aichat 'Tell me about this system'"
    Write-Host "🔧 Config: $(Join-Path (Get-ConfigPath) 'config.yaml')"
    Write-Host "📚 Help: aichat --help"
    Write-Host ""
}

# Execute main
Main
