<#
.SYNOPSIS
    Comprehensive test suite for Install-AIChat.ps1

.DESCRIPTION
    Validates installer syntax, dry-run functionality, JSON output schema,
    flag handling, and overall behavior.

.EXAMPLE
    .\Test-Installer.ps1
    # Run all tests
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------
# Test Framework
# ------------------------------------------------------------------

$script:TestResults = @()
$script:TestCount = 0
$script:PassCount = 0
$script:FailCount = 0

function Test-Case {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [scriptblock]$Test
    )
    
    $script:TestCount++
    Write-Host "Test $script:TestCount : $Name" -ForegroundColor Cyan
    
    try {
        & $Test
        Write-Host "  ✅ PASS" -ForegroundColor Green
        $script:PassCount++
        $script:TestResults += @{ Test = $Name; Result = "PASS"; Error = $null }
    }
    catch {
        Write-Host "  ❌ FAIL: $_" -ForegroundColor Red
        $script:FailCount++
        $script:TestResults += @{ Test = $Name; Result = "FAIL"; Error = $_.Exception.Message }
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message = "Assertion failed")
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message = "Values not equal")
    if ($Expected -ne $Actual) {
        throw "$Message (Expected: $Expected, Actual: $Actual)"
    }
}

function Assert-Contains {
    param($Haystack, $Needle, [string]$Message = "String not found")
    if ($Haystack -notmatch $Needle) {
        throw "$Message (Looking for: $Needle)"
    }
}

function Assert-FileExists {
    param([string]$Path, [string]$Message = "File not found")
    if (-not (Test-Path $Path)) {
        throw "$Message (Path: $Path)"
    }
}

function Assert-JsonValid {
    param([string]$Json, [string]$Message = "Invalid JSON")
    try {
        $null = ConvertFrom-Json $Json
    }
    catch {
        throw "$Message : $_"
    }
}

# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------

$scriptRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $scriptRoot "Install-AIChat.ps1"

Write-Host "`n=== Install-AIChat Test Suite ===" -ForegroundColor Yellow
Write-Host "Installer: $installerPath`n" -ForegroundColor Gray

Assert-FileExists $installerPath "Installer script not found"

# ------------------------------------------------------------------
# Test 1: Syntax Check
# ------------------------------------------------------------------

Test-Case "Installer script has valid PowerShell syntax" {
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $installerPath -Raw), [ref]$errors)
    Assert-True ($errors.Count -eq 0) "Syntax errors found: $($errors | Out-String)"
}

# ------------------------------------------------------------------
# Test 2: Help Available
# ------------------------------------------------------------------

Test-Case "Installer has Get-Help support" {
    $help = Get-Help $installerPath -ErrorAction SilentlyContinue
    Assert-True ($null -ne $help) "No help content found"
    Assert-Contains $help.Synopsis "AIChat" "Help synopsis missing AIChat reference"
}

# ------------------------------------------------------------------
# Test 3: Dry-Run Parameter
# ------------------------------------------------------------------

Test-Case "Dry-run flag produces output" {
    $output = & $installerPath -DryRun 2>&1 | Out-String
    Assert-True ($output.Length -gt 0) "Dry-run produced no output"
    Assert-Contains $output "DRY-RUN MODE" "Missing dry-run indicator"
}

# ------------------------------------------------------------------
# Test 4: JSON Output
# ------------------------------------------------------------------

Test-Case "JSON flag produces valid JSON" {
    $output = & $installerPath -DryRun -Json 2>&1 | Out-String
    $output = $output.Trim()
    
    # Remove any non-JSON prefix/suffix (status messages)
    if ($output -match '\{[\s\S]*\}') {
        $jsonText = $matches[0]
        Assert-JsonValid $jsonText "JSON output is malformed"
    }
    else {
        throw "No JSON object found in output"
    }
}

# ------------------------------------------------------------------
# Test 5: JSON Schema - Required Keys
# ------------------------------------------------------------------

Test-Case "JSON output contains required keys" {
    $output = & $installerPath -DryRun -Json 2>&1 | Out-String
    $output = $output.Trim()
    
    if ($output -match '\{[\s\S]*\}') {
        $json = $matches[0] | ConvertFrom-Json
        
        $requiredKeys = @(
            'mode', 'target_version', 'architecture', 
            'wrapper', 'role_generator', 'shell', 
            'completions', 'config', 'flags'
        )
        
        foreach ($key in $requiredKeys) {
            Assert-True ($null -ne $json.$key) "Missing required key: $key"
        }
    }
    else {
        throw "No JSON found in output"
    }
}

# ------------------------------------------------------------------
# Test 6: JSON Schema - Nested Objects
# ------------------------------------------------------------------

Test-Case "JSON nested objects are properly structured" {
    $output = & $installerPath -DryRun -Json 2>&1 | Out-String
    $output = $output.Trim()
    
    if ($output -match '\{[\s\S]*\}') {
        $json = $matches[0] | ConvertFrom-Json
        
        # Check wrapper object
        Assert-True ($null -ne $json.wrapper.enabled) "wrapper.enabled missing"
        Assert-True ($null -ne $json.wrapper.path) "wrapper.path missing"
        
        # Check role_generator object
        Assert-True ($null -ne $json.role_generator.enabled) "role_generator.enabled missing"
        Assert-True ($null -ne $json.role_generator.path) "role_generator.path missing"
        
        # Check shell object
        Assert-True ($null -ne $json.shell.integration) "shell.integration missing"
        Assert-True ($null -ne $json.shell.type) "shell.type missing"
        
        # Check flags object
        Assert-True ($null -ne $json.flags.no_wrapper) "flags.no_wrapper missing"
        Assert-True ($null -ne $json.flags.skip_role) "flags.skip_role missing"
    }
    else {
        throw "No JSON found in output"
    }
}

# ------------------------------------------------------------------
# Test 7: NoWrapper Flag
# ------------------------------------------------------------------

Test-Case "NoWrapper flag disables wrapper in JSON" {
    $output = & $installerPath -DryRun -Json -NoWrapper 2>&1 | Out-String
    $output = $output.Trim()
    
    if ($output -match '\{[\s\S]*\}') {
        $json = $matches[0] | ConvertFrom-Json
        Assert-Equal $false $json.wrapper.enabled "NoWrapper flag not reflected in JSON"
        Assert-Equal $true $json.flags.no_wrapper "NoWrapper flag not set in flags"
    }
    else {
        throw "No JSON found in output"
    }
}

# ------------------------------------------------------------------
# Test 8: SkipRole Flag
# ------------------------------------------------------------------

Test-Case "SkipRole flag disables role generator in JSON" {
    $output = & $installerPath -DryRun -Json -SkipRole 2>&1 | Out-String
    $output = $output.Trim()
    
    if ($output -match '\{[\s\S]*\}') {
        $json = $matches[0] | ConvertFrom-Json
        Assert-Equal $false $json.role_generator.enabled "SkipRole flag not reflected in JSON"
        Assert-Equal $true $json.flags.skip_role "SkipRole flag not set in flags"
    }
    else {
        throw "No JSON found in output"
    }
}

# ------------------------------------------------------------------
# Test 9: Architecture Detection
# ------------------------------------------------------------------

Test-Case "Architecture is detected correctly" {
    $output = & $installerPath -DryRun -Json 2>&1 | Out-String
    $output = $output.Trim()
    
    if ($output -match '\{[\s\S]*\}') {
        $json = $matches[0] | ConvertFrom-Json
        $validArchs = @('x64', 'x86', 'arm64', 'arm')
        Assert-True ($json.architecture -in $validArchs) "Invalid architecture: $($json.architecture)"
    }
    else {
        throw "No JSON found in output"
    }
}

# ------------------------------------------------------------------
# Test 10: Combined Flags
# ------------------------------------------------------------------

Test-Case "Multiple flags work together" {
    $output = & $installerPath -DryRun -Json -NoWrapper -SkipRole 2>&1 | Out-String
    $output = $output.Trim()
    
    if ($output -match '\{[\s\S]*\}') {
        $json = $matches[0] | ConvertFrom-Json
        Assert-Equal $false $json.wrapper.enabled "Combined flags: wrapper should be disabled"
        Assert-Equal $false $json.role_generator.enabled "Combined flags: role_generator should be disabled"
        Assert-Equal $true $json.flags.no_wrapper "Combined flags: no_wrapper not set"
        Assert-Equal $true $json.flags.skip_role "Combined flags: skip_role not set"
    }
    else {
        throw "No JSON found in output"
    }
}

# ------------------------------------------------------------------
# Test Summary
# ------------------------------------------------------------------

Write-Host "`n=== Test Summary ===" -ForegroundColor Yellow
Write-Host "Total Tests: $script:TestCount" -ForegroundColor Gray
Write-Host "Passed: $script:PassCount" -ForegroundColor Green
Write-Host "Failed: $script:FailCount" -ForegroundColor $(if ($script:FailCount -gt 0) { "Red" } else { "Green" })

if ($script:FailCount -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $script:TestResults | Where-Object { $_.Result -eq "FAIL" } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Error)" -ForegroundColor Red
    }
    exit 1
}
else {
    Write-Host "`n✅ All tests passed!" -ForegroundColor Green
    exit 0
}
