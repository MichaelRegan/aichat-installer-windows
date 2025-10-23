<#
.SYNOPSIS
    Diagnostic script to check AIChat role generator installation and status.

.DESCRIPTION
    Verifies that the role generator script is installed correctly and can generate
    the local role file. Useful for troubleshooting installation issues.

.EXAMPLE
    .\Test-AIChatRole.ps1
    # Run diagnostics and display results
#>

[CmdletBinding()]
param()

Write-Host "=== AIChat Role Generator Diagnostics ===" -ForegroundColor Cyan
Write-Host

# Check if role generator script exists
$roleScript = Join-Path $env:USERPROFILE ".local\bin\New-AIChatRole.ps1"
Write-Host "1. Checking role generator script location..." -ForegroundColor Yellow
Write-Host "   Expected path: $roleScript"

if (Test-Path $roleScript) {
    Write-Host "   ✅ Role generator script found" -ForegroundColor Green
    
    # Check script size and modification date
    $scriptInfo = Get-Item $roleScript
    Write-Host "   📄 Size: $($scriptInfo.Length) bytes"
    Write-Host "   📅 Modified: $($scriptInfo.LastWriteTime)"
} else {
    Write-Host "   ❌ Role generator script NOT found" -ForegroundColor Red
    Write-Host "   💡 Solution: Re-run the installer without -SkipRole flag"
    return
}

Write-Host

# Check roles directory
$rolesDir = Join-Path $env:APPDATA "aichat\roles"
Write-Host "2. Checking roles directory..." -ForegroundColor Yellow
Write-Host "   Expected path: $rolesDir"

if (Test-Path $rolesDir) {
    Write-Host "   ✅ Roles directory exists" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Roles directory does not exist (will be created)" -ForegroundColor Yellow
}

# Check local role file
$localRole = Join-Path $rolesDir "local.md"
Write-Host "   Local role path: $localRole"

if (Test-Path $localRole) {
    Write-Host "   ✅ Local role file exists" -ForegroundColor Green
    
    # Check role file content and age
    $roleInfo = Get-Item $localRole
    $content = Get-Content $localRole -Raw
    Write-Host "   📄 Size: $($roleInfo.Length) bytes"
    Write-Host "   📅 Generated: $($roleInfo.LastWriteTime)"
    
    # Check if it contains expected sections
    if ($content -match "host:" -and $content -match "cpu:" -and $content -match "memory:") {
        Write-Host "   ✅ Role file contains expected system information" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Role file may be incomplete or corrupted" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ Local role file NOT found" -ForegroundColor Red
}

Write-Host

# Test role generator execution
Write-Host "3. Testing role generator execution..." -ForegroundColor Yellow
try {
    $beforeTime = Get-Date
    & $roleScript -ErrorAction Stop
    $afterTime = Get-Date
    $duration = ($afterTime - $beforeTime).TotalMilliseconds
    
    Write-Host "   ✅ Role generator executed successfully ($($duration.ToString('F0'))ms)" -ForegroundColor Green
    
    # Verify role was generated/updated
    if (Test-Path $localRole) {
        $newRoleInfo = Get-Item $localRole
        if ($newRoleInfo.LastWriteTime -ge $beforeTime) {
            Write-Host "   ✅ Local role file updated successfully" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Role file was not updated (may already be current)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "   ❌ Role generator execution failed" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host

# Check wrapper function
Write-Host "4. Checking aichat wrapper function..." -ForegroundColor Yellow
$aichatCmd = Get-Command aichat -ErrorAction SilentlyContinue
if ($aichatCmd -and $aichatCmd.CommandType -eq 'Function') {
    Write-Host "   ✅ aichat wrapper function is loaded" -ForegroundColor Green
} elseif ($aichatCmd -and $aichatCmd.CommandType -eq 'Application') {
    Write-Host "   ⚠️  aichat command found but wrapper function not loaded" -ForegroundColor Yellow
    Write-Host "   💡 Wrapper may not be in your PowerShell profile"
} else {
    Write-Host "   ❌ aichat command not found" -ForegroundColor Red
    Write-Host "   💡 AIChat may not be installed or not in PATH"
}

Write-Host

# Summary
Write-Host "=== Diagnostic Summary ===" -ForegroundColor Cyan
if ((Test-Path $roleScript) -and (Test-Path $localRole)) {
    Write-Host "✅ Role generator appears to be working correctly" -ForegroundColor Green
    Write-Host "   You can test with: aichat 'What is my system info?'" -ForegroundColor White
} else {
    Write-Host "❌ Role generator setup has issues" -ForegroundColor Red
    Write-Host "   Consider re-running: Install-AIChat.ps1" -ForegroundColor White
}