# AIChat Installer for Windows

**PowerShell-based installer for [aichat](https://github.com/sigoden/aichat)** - An all-in-one AI-powered CLI chat and copilot.

This installer automates the complete setup of aichat on Windows, including:
- Installation via `winget`
- PowerShell profile integration with keybindings
- Argument completion
- Wrapper function with dynamic system context
- Clean output filtering (removes AI thinking blocks)
- Configuration file initialization

## Features

✅ **Automated Installation** - Uses `winget` for clean package management  
✅ **Shell Integration** - Adds `Alt+E` keybinding for inline command execution  
✅ **Smart Wrapper** - Injects live system context before each aichat invocation  
✅ **Clean Output** - Automatically filters out AI thinking blocks for cleaner responses  
✅ **Argument Completion** - Tab completion for aichat commands and roles  
✅ **Dry-Run Mode** - Preview changes without modifying your system  
✅ **JSON Output** - Machine-readable installation plan for automation  
✅ **Flexible Configuration** - Skip wrapper or role generator if not needed  

## Quick Start

### Prerequisites

- **Windows 10/11** (with PowerShell 5.1+ or PowerShell 7+)
- **winget** (Windows Package Manager) - [Install instructions](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- **PSReadLine** module (usually pre-installed)

### Installation

**Option 1: Direct execution**
```powershell
# Download and run (review script first!)
Invoke-WebRequest -Uri "[https://raw.githubusercontent.com/michaelregan/aichat-installer-windows/main/Install-AIChat.ps1]" -OutFile "$env:TEMP\Install-AIChat.ps1"
& "$env:TEMP\Install-AIChat.ps1"
```

**Option 2: Clone and run**
```powershell
git clone https://github.com/michaelregan/aichat-installer-windows.git
cd aichat-installer-windows
.\Install-AIChat.ps1
```

**Option 3: Dry-run first**
```powershell
# See what would happen without making changes
.\Install-AIChat.ps1 -DryRun

# Machine-readable plan
.\Install-AIChat.ps1 -DryRun -Json
```

## Usage

### Basic Usage
```powershell
# Install latest version
.\Install-AIChat.ps1

# Install specific version
.\Install-AIChat.ps1 -Version "0.12.0"

# Skip all prompts
.\Install-AIChat.ps1 -AssumeYes
```

### Advanced Options
```powershell
# Skip wrapper function (use raw aichat command)
.\Install-AIChat.ps1 -NoWrapper

# Skip role generator (no system context injection)
.\Install-AIChat.ps1 -SkipRole

# Minimal install (no wrapper, no role, just aichat + config)
.\Install-AIChat.ps1 -NoWrapper -SkipRole

# Preview with structured output
.\Install-AIChat.ps1 -DryRun -Json | ConvertFrom-Json
```

### Parameters

| Parameter | Alias | Description |
|-----------|-------|-------------|
| `-Version` | N/A | Specific aichat version (default: latest) |
| `-DryRun` | N/A | Preview changes without applying |
| `-Json` | N/A | Output plan in JSON format |
| `-NoWrapper` | N/A | Skip wrapper function creation |
| `-SkipRole` | N/A | Skip role generator script |
| `-AssumeYes` | `-y` | Skip all confirmation prompts |

## What Gets Installed

### 1. AIChat Binary
- Installed via `winget install --id sigoden.aichat`
- Typically places `aichat.exe` in `%LOCALAPPDATA%\Microsoft\WinGet\Packages\`
- Auto-added to PATH

### 2. Configuration File
**Location:** `%APPDATA%\aichat\config.yaml`

```yaml
model: openai:gpt-4o-mini
temperature: 1.0
save: true
save_session: null
highlight: true
light_theme: false
wrap: no
wrap_code: false
keybindings: vi
prelude: ''
```

### 3. PowerShell Profile Integration
**Location:** `$PROFILE` (usually `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)

**Keybinding:** `Alt+E` - Execute current input with aichat
```powershell
Set-PSReadLineKeyHandler -Key Alt+e -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    Invoke-Expression "aichat -e `"$line`""
}
```

**Argument Completer:**
```powershell
Register-ArgumentCompleter -CommandName aichat -ScriptBlock {
    param($commandName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $roles = Get-ChildItem "$env:APPDATA\aichat\roles" -Filter "*.md" -ErrorAction SilentlyContinue | 
        ForEach-Object { $_.BaseName }
    $roles | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
```

### 4. Wrapper Function (Optional)
**Location:** `$PROFILE`

```powershell
function aichat {
    # Refresh system context
    $roleScript = Join-Path $env:USERPROFILE ".local\bin\New-AIChatRole.ps1"
    if (Test-Path $roleScript) {
        & $roleScript -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Auto-apply local role if no role specified
    $hasRoleArg = $false
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq '-r' -or $args[$i] -eq '--role') {
            $hasRoleArg = $true; break
        }
    }
    
    $finalArgs = if (-not $hasRoleArg) { @('-r', 'local') + $args } else { $args }
    
    # Execute aichat and filter out thinking blocks
    $output = & (Get-Command aichat.exe).Source @finalArgs | Out-String
    ($output -replace '(?s)<think>.*?</think>\s*', '').Trim() | Write-Host
}
```

The wrapper ensures the `local` role has current system context before each run and provides clean output by filtering AI thinking blocks.

### 5. Role Generator Script (Optional)
**Location:** `%APPDATA%\aichat\scripts\New-AIChatRole.ps1`

Generates `local.md` role with:
- Hostname, username, domain
- OS version, build, architecture
- CPU specs (cores, clock speed)
- GPU details (name, VRAM, drivers)
- Memory usage (total, used, free)
- Disk information (drives, space)
- Active network adapters
- PowerShell version
- Timezone and locale

## Configuration

### Environment Variables

Control installer behavior:
```powershell
$env:AICHAT_VERSION = "0.12.0"  # Force specific version
$env:AICHAT_CONFIG_DIR = "C:\CustomPath\aichat"  # Override config location
```

### Post-Install Config

Edit `%APPDATA%\aichat\config.yaml`:
```yaml
# Change model
model: anthropic:claude-3-5-sonnet-20241022

# Adjust temperature (0.0 = deterministic, 2.0 = creative)
temperature: 0.7

# Enable session persistence
save_session: default

# Use light theme
light_theme: true
```

### API Keys

Set your API keys as environment variables:
```powershell
# OpenAI
[System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'sk-...', 'User')

# Anthropic
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-...', 'User')

# Others (see aichat docs)
```

Or add to config.yaml:
```yaml
clients:
  - type: openai
    api_key: sk-...
```

## Uninstall

```powershell
# Remove aichat package
winget uninstall --id sigoden.aichat

# Remove config and roles
Remove-Item -Recurse -Force "$env:APPDATA\aichat"

# Manually remove from $PROFILE:
# - aichat function
# - Set-PSReadLineKeyHandler for Alt+E
# - Register-ArgumentCompleter for aichat
```

## Troubleshooting

### Issue: `winget` not found
**Solution:** Install Windows Package Manager:
```powershell
# Via Microsoft Store (recommended)
# Search for "App Installer"

# Or download from GitHub
# https://github.com/microsoft/winget-cli/releases
```

### Issue: PSReadLine keybinding not working
**Solution:** Ensure PSReadLine is loaded:
```powershell
Import-Module PSReadLine
Set-PSReadLineOption -EditMode Windows  # or Emacs, Vi
```

### Issue: Permission denied when modifying $PROFILE
**Solution:** Run PowerShell as Administrator:
```powershell
Start-Process powershell -Verb RunAs -ArgumentList "-File Install-AIChat.ps1"
```

### Issue: Wrapper function not calling role generator
**Solution:** Verify script path:
```powershell
Test-Path "$env:APPDATA\aichat\scripts\New-AIChatRole.ps1"
```

### Issue: Role generator fails silently
**Solution:** Run manually to see errors:
```powershell
& "$env:APPDATA\aichat\scripts\New-AIChatRole.ps1"
Get-Content "$env:APPDATA\aichat\roles\local.md"
```

## Testing

Run the included test suite:
```powershell
# Full test suite
.\tests\Test-Installer.ps1

# Tests validate:
# - PowerShell syntax
# - Dry-run functionality
# - JSON schema compliance
# - Flag behavior
# - Architecture detection
# - Combined flag scenarios
```

**Expected output:**
```
=== Install-AIChat Test Suite ===
Test 1: Installer script has valid PowerShell syntax
  ✅ PASS
Test 2: Installer has Get-Help support
  ✅ PASS
...
Test 10: Multiple flags work together
  ✅ PASS

=== Test Summary ===
Total Tests: 10
Passed: 10
Failed: 0

✅ All tests passed!
```

## Comparison with Linux Installer

| Feature | Windows (PowerShell) | Linux (Bash) |
|---------|---------------------|--------------|
| Package Manager | `winget` | `tar + curl` |
| Config Location | `%APPDATA%\aichat` | `~/.config/aichat` |
| Shell Integration | PSReadLine (`Alt+E`) | `bindkey` (`Alt+E`) |
| Completions | `Register-ArgumentCompleter` | Bash/Zsh completion scripts |
| Wrapper Function | PowerShell function | Bash/Zsh function |
| Role Generator | WMI/CIM cmdlets | `/proc`, `lspci`, `lscpu` |
| Dry-Run | ✅ JSON output | ✅ JSON output |
| Flags | `-NoWrapper`, `-SkipRole` | `--no-wrapper`, `--skip-role` |

## Project Structure

```
aichat-installer-windows/
├── Install-AIChat.ps1         # Main installer script
├── scripts/
│   └── New-AIChatRole.ps1     # Role generator (gathers system info)
├── tests/
│   └── Test-Installer.ps1     # Test suite
├── docs/
│   └── (future: detailed guides)
└── README.md                  # This file
```

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test changes (`.\tests\Test-Installer.ps1`)
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

MIT License - See LICENSE file for details

## Related Projects

- **aichat** - https://github.com/sigoden/aichat
- **Linux Installer** - https://github.com/sigoden/aichat (official installer)

## Support

- **Issues:** https://github.com/michaelregan/aichat-installer-windows/issues
- **Discussions:** https://github.com/michaelregan/aichat-installer-windows/discussions
- **AIChat Docs:** https://github.com/sigoden/aichat/wiki

---

**Made with ❤️ for the aichat community**
