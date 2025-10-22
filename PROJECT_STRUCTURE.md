# AIChat Installer - Windows Project

## Project Overview

Complete PowerShell-based installer for [aichat](https://github.com/sigoden/aichat) on Windows, providing feature parity with the Linux bash installer while respecting Windows conventions.

## Files Created

### Core Installer
- **`Install-AIChat.ps1`** (554 lines)
  - CmdletBinding with approved verbs
  - Parameters: `-Version`, `-DryRun`, `-Json`, `-NoWrapper`, `-SkipRole`, `-AssumeYes`
  - Helper functions: `Write-Status`, `Confirm-Action`, `Get-AIChatVersion`, `Get-SystemArchitecture`, `Initialize-AIChatConfig`, `Install-ShellIntegration`, `Install-WrapperFunction`, `Install-RoleGenerator`
  - Uses `winget` for package installation
  - Modifies `$PROFILE` for PSReadLine keybindings (`Alt+E`)
  - Registers argument completers for role tab-completion
  - Creates config in `%APPDATA%\aichat\config.yaml`

### Role Generator
- **`scripts/New-AIChatRole.ps1`** (151 lines)
  - Gathers Windows system context via WMI/CIM cmdlets:
    - CPU: `Win32_Processor` (cores, clock speed, model)
    - GPU: `Win32_VideoController` (name, VRAM, driver version)
    - Memory: `Win32_OperatingSystem`, `Win32_ComputerSystem` (total, free, used)
    - Disks: `Win32_LogicalDisk` (size, free space, usage %)
    - Network: `Get-NetAdapter`, `Get-NetIPAddress` (active adapters, link speed, IPs)
    - OS: Version, build, architecture
    - Environment: Hostname, user, domain, timezone, locale
    - Virtualization detection via BIOS manufacturer
  - Generates `local.md` with YAML frontmatter + system context
  - Silent operation (no console output unless error)

### Test Suite
- **`tests/Test-Installer.ps1`** (343 lines)
  - 10 comprehensive test cases:
    1. PowerShell syntax validation
    2. Get-Help support verification
    3. Dry-run flag functionality
    4. JSON output validation
    5. JSON schema required keys check
    6. JSON nested object structure validation
    7. `-NoWrapper` flag behavior
    8. `-SkipRole` flag behavior
    9. Architecture detection
    10. Combined flags scenario
  - Custom assertion framework: `Assert-True`, `Assert-Equal`, `Assert-Contains`, `Assert-FileExists`, `Assert-JsonValid`
  - Colored console output with pass/fail summary
  - Exit code 0 on success, 1 on any failures

### Documentation
- **`README.md`** (comprehensive guide)
  - Quick start with 3 installation methods
  - All parameters documented with examples
  - What gets installed (binary, config, profile, wrapper, role generator)
  - Configuration examples (environment variables, config.yaml, API keys)
  - Uninstall instructions
  - Troubleshooting section (5 common issues with solutions)
  - Testing instructions
  - Comparison table with Linux installer
  - Project structure diagram
  - Contributing guidelines

## Key Design Decisions

### 1. Separate Project vs. Unified Codebase
**Decision:** Create standalone Windows project  
**Rationale:**
- Different package managers (`winget` vs. `tar/curl`)
- Different shell ecosystems (PowerShell vs. Bash/Zsh)
- Different path conventions (`%APPDATA%` vs. `~/.config`)
- Different completion systems (`Register-ArgumentCompleter` vs. completion scripts)
- Easier maintenance and testing for each platform

### 2. PowerShell CmdletBinding
**Decision:** Use advanced functions with approved verbs  
**Rationale:**
- Idiomatic PowerShell (e.g., `-DryRun` vs. `--dry-run`)
- Built-in parameter validation
- Automatic `-Verbose`, `-Debug`, `-ErrorAction` support
- Better integration with PowerShell ecosystem
- Help system (`Get-Help`) works automatically

### 3. PSReadLine for Keybindings
**Decision:** Use `Set-PSReadLineKeyHandler` for `Alt+E`  
**Rationale:**
- Standard PowerShell key customization mechanism
- More reliable than `Register-EngineEvent`
- Works in PowerShell 5.1+ and PowerShell 7+
- Matches Linux installer's `Alt+E` keybinding

### 4. WMI/CIM for System Info
**Decision:** Use CIM cmdlets (`Get-CimInstance`) over WMI cmdlets  
**Rationale:**
- CIM is PowerShell 3.0+ standard (WMI is deprecated)
- Better performance (uses WinRM instead of DCOM)
- Works on remote systems
- More consistent object structure

### 5. JSON Schema Parity
**Decision:** Match Linux installer's JSON dry-run output structure  
**Rationale:**
- Consistent automation experience across platforms
- Same keys: `mode`, `target_version`, `architecture`, `wrapper`, `role_generator`, `shell`, `completions`, `config`, `flags`
- Enables unified CI/CD pipelines
- Cross-platform validation scripts

### 6. Silent Role Generator
**Decision:** No console output from `New-AIChatRole.ps1` by default  
**Rationale:**
- Called automatically by wrapper function before every `aichat` invocation
- Avoid cluttering console with generation messages
- Matches Linux `gen-aichat-role` behavior
- Can still debug by running manually

## Testing Strategy

### Test Coverage
1. **Syntax Validation** - Ensures script parses without errors
2. **Help Documentation** - Verifies Get-Help works
3. **Dry-Run Functionality** - Confirms no side effects in dry-run mode
4. **JSON Output** - Validates well-formed JSON
5. **Schema Compliance** - Checks all required keys present
6. **Nested Objects** - Validates structure of `wrapper`, `role_generator`, `shell`, `flags`
7. **Flag Behavior** - Individual flags work correctly
8. **Architecture Detection** - Valid values (x64, x86, arm64, arm)
9. **Combined Flags** - Multiple flags work together without conflicts

### Not Yet Tested (Requires Windows)
- Actual `winget` installation
- `$PROFILE` modification and reload
- PSReadLine keybinding invocation
- Argument completer in interactive session
- Wrapper function calling role generator
- Role generator WMI/CIM queries on real hardware

## Future Enhancements

### Potential Additions
1. **Chocolatey Support** - Alternative to `winget` for older Windows
2. **Scoop Integration** - Another package manager option
3. **Windows Terminal Settings** - Auto-configure terminal profiles
4. **Task Scheduler** - Periodic role regeneration
5. **Event Viewer Logging** - Installation audit trail
6. **MSI Installer** - GUI-based installation option
7. **Pester Tests** - Use official PowerShell testing framework
8. **Code Signing** - Sign scripts for execution policy compliance
9. **Telemetry** - Optional usage analytics
10. **Auto-Update** - Check for installer script updates

### Known Limitations
1. Requires `winget` (Windows 10 1809+ or Windows 11)
2. PSReadLine keybinding requires PowerShell 5.1+
3. No support for Windows PowerShell ISE (uses console host features)
4. Role generator requires local admin or WMI permissions
5. No automated tests for actual installation (only dry-run)

## JSON Output Schema

```json
{
  "mode": "dry-run",
  "target_version": "latest",
  "architecture": "x64",
  "wrapper": {
    "enabled": true,
    "path": "$PROFILE"
  },
  "role_generator": {
    "enabled": true,
    "path": "%APPDATA%\\aichat\\scripts\\New-AIChatRole.ps1",
    "role_file": "%APPDATA%\\aichat\\roles\\local.md"
  },
  "shell": {
    "integration": true,
    "type": "PowerShell",
    "profile": "$PROFILE",
    "keybinding": "Alt+E"
  },
  "completions": {
    "enabled": true,
    "type": "ArgumentCompleter"
  },
  "config": {
    "path": "%APPDATA%\\aichat\\config.yaml",
    "will_create": true
  },
  "flags": {
    "no_wrapper": false,
    "skip_role": false,
    "assume_yes": false
  }
}
```

## Comparison with Linux Installer

| Aspect | Windows | Linux |
|--------|---------|-------|
| **Language** | PowerShell | Bash |
| **Package Manager** | winget | curl + tar |
| **Config Path** | `%APPDATA%\aichat` | `~/.config/aichat` |
| **Shell Integration** | PSReadLine | bindkey (zsh), bind (bash) |
| **Keybinding** | `Alt+E` | `Alt+E` |
| **Completions** | `Register-ArgumentCompleter` | Completion scripts |
| **System Info** | WMI/CIM cmdlets | /proc, lspci, lscpu |
| **Dry-Run** | JSON output | JSON output |
| **Wrapper** | PowerShell function | Bash/Zsh function |
| **Role Generator** | New-AIChatRole.ps1 | gen-aichat-role |

## Installation Artifacts

After successful installation:
```
%APPDATA%\aichat\
├── config.yaml               # Main config
├── roles\
│   └── local.md             # Generated system context role
└── scripts\
    └── New-AIChatRole.ps1   # Role generator

%USERPROFILE%\Documents\PowerShell\
└── Microsoft.PowerShell_profile.ps1  # Modified with:
                                      # - aichat wrapper function
                                      # - Alt+E keybinding
                                      # - Argument completer

%LOCALAPPDATA%\Microsoft\WinGet\Packages\
└── sigoden.aichat_*\        # Installed aichat.exe
```

## Development Workflow

1. **Edit** `Install-AIChat.ps1` or `scripts/New-AIChatRole.ps1`
2. **Test** with `.\tests\Test-Installer.ps1`
3. **Dry-Run** with `.\Install-AIChat.ps1 -DryRun -Json`
4. **Validate** JSON schema manually
5. **Commit** changes
6. **Tag** release versions

## Credits

- **aichat** by [@sigoden](https://github.com/sigoden)
- **Linux installer** inspiration
- **PowerShell community** for CmdletBinding patterns
- **Windows Terminal** team for modern CLI tooling

---

**Status:** ✅ Complete and ready for testing on Windows systems  
**Next Steps:** Manual testing on Windows 10/11, open-source release, community feedback
