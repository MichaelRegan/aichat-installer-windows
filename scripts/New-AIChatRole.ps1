<#
.SYNOPSIS
    Generate a dynamic local role for aichat with Windows system context.

.DESCRIPTION
    Gathers comprehensive system information (CPU, GPU, memory, OS, network)
    and creates a local role file for aichat with current system context.

.EXAMPLE
    .\New-AIChatRole.ps1
    # Generate local role with current system state
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

# Determine config path
$configBase = if ($env:APPDATA) { $env:APPDATA } else { "$env:USERPROFILE\AppData\Roaming" }
$rolesDir = Join-Path $configBase "aichat\roles"

# Ensure roles directory exists
if (-not (Test-Path $rolesDir)) {
    New-Item -Path $rolesDir -ItemType Directory -Force | Out-Null
}

# ------------------------------------------------------------------
# Gather System Information
# ------------------------------------------------------------------

# Basic system info
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$bios = Get-CimInstance -ClassName Win32_BIOS

$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$domain = $env:USERDOMAIN
$osName = $os.Caption
$osVersion = $os.Version
$osBuild = $os.BuildNumber
$osArchitecture = $os.OSArchitecture

# CPU info
$cpuName = $processor.Name
$cpuCores = $processor.NumberOfCores
$cpuLogicalProcessors = $processor.NumberOfLogicalProcessors
$cpuMaxClockSpeed = $processor.MaxClockSpeed

# Memory
$totalMemoryGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
$freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB / 1024, 2)
$usedMemoryGB = [math]::Round($totalMemoryGB - $freeMemoryGB, 2)

# GPU info
$gpuList = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -notmatch 'Remote|Virtual|Basic' }
if ($gpuList) {
    $gpuSection = "GPUs:`n"
    foreach ($gpu in $gpuList) {
        $vram = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB, 2) } else { "Unknown" }
        $gpuSection += "- $($gpu.Name) | VRAM: ${vram}GB | Driver: $($gpu.DriverVersion)`n"
    }
    $gpuSection = $gpuSection.TrimEnd("`n")
}
else {
    $gpuSection = "None detected"
}

# Disk info
$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | 
    Select-Object DeviceID, 
                  @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}}, 
                  @{N='Free(GB)';E={[math]::Round($_.FreeSpace/1GB,2)}},
                  @{N='Used%';E={[math]::Round((($_.Size-$_.FreeSpace)/$_.Size)*100,1)}}

$diskInfo = "Drives:`n"
foreach ($disk in $disks) {
    $diskInfo += "  $($disk.DeviceID) - Size: $($disk.'Size(GB)')GB, Free: $($disk.'Free(GB)')GB, Used: $($disk.'Used%')%`n"
}
$diskInfo = $diskInfo.TrimEnd("`n")

# Network adapters and IP addresses
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object Name, InterfaceDescription, LinkSpeed
$networkInfo = if ($adapters) {
    $netText = "Active adapters:`n"
    foreach ($adapter in $adapters) {
        $ipv4 = (Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        $netText += "  - $($adapter.Name): $($adapter.InterfaceDescription)`n"
        $netText += "    Link Speed: $($adapter.LinkSpeed), IP: $(if($ipv4){$ipv4}else{'none'})`n"
    }
    $netText.TrimEnd("`n")
}
else {
    "No active adapters"
}

# Extract just IP addresses for easy reference
$allIPs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
    Where-Object { $_.IPAddress -notmatch '^127\.|^169\.254\.' } | 
    Select-Object -ExpandProperty IPAddress
$ipAddresses = if ($allIPs) { $allIPs -join ", " } else { "none detected" }

# Timezone and locale
$timezone = (Get-TimeZone).DisplayName
$culture = (Get-Culture).DisplayName

# Current directory
$currentDir = Get-Location

# PowerShell version
$psVersion = $PSVersionTable.PSVersion.ToString()

# Virtualization detection
$virtualization = if ($bios.Manufacturer -match 'VMware|QEMU|Xen|Amazon|Google|Microsoft Corporation') {
    "Virtual Machine ($($bios.Manufacturer))"
}
elseif ($computerSystem.Model -match 'Virtual|VMware') {
    "Virtual Machine ($($computerSystem.Model))"
}
else {
    "Physical or Unknown"
}

# Package manager
$packageManager = if (Get-Command winget -ErrorAction SilentlyContinue) { "winget" } else { "none" }

# Current timestamp
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

# ------------------------------------------------------------------
# Generate Role File
# ------------------------------------------------------------------

$roleContent = @"
# local

## init
You are a direct, concise Windows system assistant with access to live system data below.

CRITICAL RULES:
- NEVER show <think> tags or reasoning process  
- ALWAYS read and use the system context data below to answer questions
- When asked "What is my IP address?" answer with the specific IPs from ip_addresses field
- When asked about RAM, use the memory values from context
- When asked about CPU, use the cpu name from context  
- Provide EXACT values from the machine snapshot first, then verification commands
- Use PowerShell examples by default
- Include cmd.exe alternatives when useful

EXAMPLES:
- Q: "What is my IP address?" → A: "Your IP addresses are: [list from ip_addresses field]"
- Q: "How much RAM?" → A: "You have [total_gb] GB RAM ([used_gb] GB used, [free_gb] GB free)"

## context (machine snapshot; use this data to answer questions)
``````yaml
# Generated: $timestamp
# INSTRUCTION: Use the specific values below when answering system questions
host: $hostname
user: $username
domain: $domain
platform: $virtualization
os: $osName
os_version: $osVersion
os_build: $osBuild
architecture: $osArchitecture
shell: PowerShell
shell_version: $psVersion

cpu:
  name: $cpuName
  cores: $cpuCores
  logical_processors: $cpuLogicalProcessors
  max_clock_mhz: $cpuMaxClockSpeed

gpu: |
  $gpuSection

memory:
  total_gb: $totalMemoryGB
  used_gb: $usedMemoryGB
  free_gb: $freeMemoryGB

disks: |
  $diskInfo

networking: |
  $networkInfo

ip_addresses: $ipAddresses

runtime:
  current_directory: $currentDir
  timezone: $timezone
  locale: $culture

package_manager: $packageManager
``````

"@

$roleFile = Join-Path $rolesDir "local.md"
$roleContent | Out-File -FilePath $roleFile -Encoding UTF8 -Force

# Silent success (no output unless error)
# Uncomment for debugging:
# Write-Host "✅ Local role generated: $roleFile" -ForegroundColor Green
