#requires -Version 5.1
<#
.SYNOPSIS
    Guarded Windows memory diagnostics and RAMMap maintenance toolkit.
.DESCRIPTION
    Preserves the tested RAMMap standby-list and working-set maintenance actions
    while adding official-source download validation, logging, dry-run support,
    before/after evidence and explicit confirmation.
.NOTES
    Created by Dewald Pretorius - L2 IT Support Engineer.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Diagnose','InstallRAMMap','EmptyStandbyList','EmptyWorkingSets','RepairAllSafe')]
    [string]$Action = 'Diagnose',
    [string]$ToolsPath = "$env:ProgramData\DewaldTools\RAMMap",
    [string]$OutputPath,
    [switch]$DryRun,
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.0.0'
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ExitCode = 0
$RamMapUrl = 'https://download.sysinternals.com/files/RAMMap.zip'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "RAMMap_Memory_Maintenance_$Stamp"
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$LogPath = Join-Path $OutputPath 'maintenance.log'

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DRYRUN')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN' { Write-Host $Message -ForegroundColor Yellow }
        'ERROR' { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        'DRYRUN' { Write-Host "DRY RUN: $Message" -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Require-Administrator {
    if (-not (Test-IsAdministrator)) {
        throw 'This maintenance action requires an elevated PowerShell session.'
    }
}

function Confirm-MaintenanceAction {
    param([Parameter(Mandatory)][string]$Message)
    if ($DryRun -or $Yes) { return $true }
    return (Read-Host "$Message Type REPAIR to continue") -eq 'REPAIR'
}

function Get-MemorySnapshot {
    param([Parameter(Mandatory)][string]$Stage)

    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $topProcesses = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 15 Name, Id,
            @{Name='WorkingSetMB';Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}},
            @{Name='PrivateMemoryMB';Expression={[math]::Round($_.PrivateMemorySize64 / 1MB, 2)}}

    $snapshot = [ordered]@{
        Stage = $Stage
        Generated = (Get-Date).ToString('o')
        ScriptVersion = $ScriptVersion
        Computer = $env:COMPUTERNAME
        IsAdministrator = (Test-IsAdministrator)
        TotalPhysicalMemoryMB = [math]::Round([double]$computer.TotalPhysicalMemory / 1MB, 2)
        FreePhysicalMemoryMB = [math]::Round([double]$os.FreePhysicalMemory / 1024, 2)
        TotalVirtualMemoryMB = [math]::Round([double]$os.TotalVirtualMemorySize / 1024, 2)
        FreeVirtualMemoryMB = [math]::Round([double]$os.FreeVirtualMemory / 1024, 2)
        LastBootUpTime = $os.LastBootUpTime
        TopProcesses = @($topProcesses)
    }

    $path = Join-Path $OutputPath "$Stage.json"
    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Log "Saved $Stage memory snapshot to $path." 'SUCCESS'
    return $snapshot
}

function Get-RAMMapExecutable {
    $preferred = if ([Environment]::Is64BitOperatingSystem) { 'RAMMap64.exe' } else { 'RAMMap.exe' }
    $path = Join-Path $ToolsPath $preferred
    if (Test-Path -LiteralPath $path) { return $path }

    $fallback = Join-Path $ToolsPath 'RAMMap.exe'
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    return $null
}

function Test-MicrosoftSignature {
    param([Parameter(Mandatory)][string]$Path)

    $signature = Get-AuthenticodeSignature -FilePath $Path
    if ($signature.Status -ne 'Valid') { return $false }
    if (-not $signature.SignerCertificate) { return $false }
    return $signature.SignerCertificate.Subject -match 'Microsoft'
}

function Install-RAMMap {
    Require-Administrator

    $existing = Get-RAMMapExecutable
    if ($existing -and (Test-MicrosoftSignature -Path $existing)) {
        Write-Log "A valid Microsoft-signed RAMMap executable is already installed at $existing." 'SUCCESS'
        return $existing
    }

    if (-not (Confirm-MaintenanceAction 'Download and install Microsoft Sysinternals RAMMap?')) {
        throw 'User cancelled.'
    }

    if ($DryRun) {
        Write-Log "Would download $RamMapUrl and install it to $ToolsPath." 'DRYRUN'
        return (Join-Path $ToolsPath 'RAMMap64.exe')
    }

    New-Item -ItemType Directory -Path $ToolsPath -Force | Out-Null
    $zipPath = Join-Path $env:TEMP "RAMMap_$Stamp.zip"
    $extractPath = Join-Path $env:TEMP "RAMMap_$Stamp"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $RamMapUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        $executables = @(Get-ChildItem -LiteralPath $extractPath -Filter 'RAMMap*.exe' -File -ErrorAction Stop)
        if ($executables.Count -eq 0) { throw 'RAMMap archive did not contain an executable.' }

        foreach ($file in $executables) {
            if (-not (Test-MicrosoftSignature -Path $file.FullName)) {
                throw "Signature validation failed for $($file.Name)."
            }
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $ToolsPath $file.Name) -Force
        }
    } finally {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $installed = Get-RAMMapExecutable
    if (-not $installed -or -not (Test-MicrosoftSignature -Path $installed)) {
        throw 'RAMMap installation verification failed.'
    }

    Write-Log "Installed and verified Microsoft Sysinternals RAMMap at $installed." 'SUCCESS'
    return $installed
}

function Ensure-RAMMap {
    $path = Get-RAMMapExecutable
    if ($path -and (Test-MicrosoftSignature -Path $path)) { return $path }
    return Install-RAMMap
}

function Invoke-RAMMapCommand {
    param(
        [Parameter(Mandatory)][ValidateSet('EmptyStandbyList','EmptyWorkingSets')][string]$Command
    )

    Require-Administrator
    $description = if ($Command -eq 'EmptyStandbyList') {
        'Empty the Windows standby memory list'
    } else {
        'Trim process working sets across the system'
    }

    if (-not (Confirm-MaintenanceAction "$description? Applications can temporarily reload data from disk.")) {
        throw 'User cancelled.'
    }

    $ramMap = Ensure-RAMMap
    if ($DryRun) {
        Write-Log "Would run $ramMap -$Command -AcceptEula." 'DRYRUN'
        return
    }

    $process = Start-Process -FilePath $ramMap -ArgumentList "-$Command", '-AcceptEula' -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        throw "RAMMap command $Command returned exit code $($process.ExitCode)."
    }
    Write-Log "RAMMap command $Command completed successfully." 'SUCCESS'
}

Write-Log "RAMMap Memory Maintenance Toolkit $ScriptVersion started. Action=$Action DryRun=$DryRun"
$before = Get-MemorySnapshot -Stage 'before'

try {
    switch ($Action) {
        'Diagnose' {
            $installed = Get-RAMMapExecutable
            if ($installed) {
                Write-Log "RAMMap detected at $installed. Microsoft signature valid: $(Test-MicrosoftSignature -Path $installed)."
            } else {
                Write-Log 'RAMMap is not currently installed by this toolkit.' 'WARN'
            }
        }
        'InstallRAMMap' {
            [void](Install-RAMMap)
        }
        'EmptyStandbyList' {
            Invoke-RAMMapCommand -Command EmptyStandbyList
        }
        'EmptyWorkingSets' {
            Invoke-RAMMapCommand -Command EmptyWorkingSets
        }
        'RepairAllSafe' {
            Invoke-RAMMapCommand -Command EmptyStandbyList
            Invoke-RAMMapCommand -Command EmptyWorkingSets
        }
    }
} catch {
    if ($_.Exception.Message -eq 'User cancelled.') {
        $ExitCode = 10
        Write-Log 'Maintenance cancelled by the user.' 'WARN'
    } elseif ($_.Exception.Message -match 'elevated') {
        $ExitCode = 4
        Write-Log $_.Exception.Message 'ERROR'
    } else {
        $ExitCode = 20
        Write-Log $_.Exception.Message 'ERROR'
    }
} finally {
    Start-Sleep -Seconds 2
    try {
        $after = Get-MemorySnapshot -Stage 'after'
        $comparison = [ordered]@{
            BeforeFreePhysicalMemoryMB = $before.FreePhysicalMemoryMB
            AfterFreePhysicalMemoryMB = $after.FreePhysicalMemoryMB
            DifferenceMB = [math]::Round(($after.FreePhysicalMemoryMB - $before.FreePhysicalMemoryMB), 2)
        }
        $comparison | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputPath 'comparison.json') -Encoding UTF8
    } catch {
        Write-Log "Post-maintenance snapshot failed: $($_.Exception.Message)" 'WARN'
    }
}

if ($ExitCode -eq 0) {
    Write-Log "Completed successfully. Output: $OutputPath" 'SUCCESS'
} else {
    Write-Log "Completed with exit code $ExitCode. Output: $OutputPath" 'ERROR'
}
exit $ExitCode
