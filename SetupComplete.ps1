# OSDCloud SetupComplete.ps1; Location: C:\Windows\Setup\Scripts\SetupComplete.ps1
# Logs setup process, imports OSD modules, sets power plan, runs custom SetupComplete.cmd, and reboots when finished.

# These values are replaced by StartURL at deployment time.
$LocalUserName = 'LocalAdmin'
$LocalUserPassword = 'ChangeMe!123!'

# Logging first
$StartTime = Get-Date
Start-Transcript -Path 'C:\OSDCloud\Logs\SetupComplete.log' -ErrorAction Ignore
Write-Host "Starting SetupComplete Script Process"
Write-Host ("Start Time: {0}" -f $StartTime.ToString("HH:mm:ss"))

# Module import (OSD)
try {
    Import-Module OSD -Force -ErrorAction Stop
} catch {
    $ModulePath = (Get-ChildItem -Path "$env:ProgramFiles\WindowsPowerShell\Modules\osd" -Directory | Select-Object -Last 1).FullName
    if ($ModulePath) { Import-Module "$ModulePath\OSD.psd1" -Force }
}

# Optional: pull OSD Anywhere helpers
try {
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_anywhere.psm1')
} catch {
    Write-Warning "Could not load _anywhere.psm1: $($_.Exception.Message)"
}
Start-Sleep -Seconds 10

# Ensure Microsoft Defender remains enabled.
try {
    Set-Service -Name WinDefend -StartupType Automatic -ErrorAction Stop
    if ((Get-Service -Name WinDefend).Status -ne 'Running') {
        Start-Service -Name WinDefend -ErrorAction Stop
    }
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
} catch {
    Write-Warning "Defender enablement check failed: $($_.Exception.Message)"
}

# Ensure the requested local admin account exists and is in Administrators.
try {
    $existingUser = Get-LocalUser -Name $LocalUserName -ErrorAction SilentlyContinue
    $securePassword = ConvertTo-SecureString $LocalUserPassword -AsPlainText -Force

    if (-not $existingUser) {
        New-LocalUser -Name $LocalUserName -Password $securePassword -PasswordNeverExpires -AccountNeverExpires | Out-Null
        Write-Host "Created local user '$LocalUserName'"
    } else {
        Set-LocalUser -Name $LocalUserName -Password $securePassword
        Write-Host "Updated password for existing local user '$LocalUserName'"
    }

    if (-not (Get-LocalGroupMember -Group 'Administrators' -Member $LocalUserName -ErrorAction SilentlyContinue)) {
        Add-LocalGroupMember -Group 'Administrators' -Member $LocalUserName -ErrorAction Stop
        Write-Host "Added '$LocalUserName' to local Administrators group"
    }
} catch {
    Write-Warning "Local admin provisioning failed: $($_.Exception.Message)"
}

# Set hostname to EDU-<SerialNumber> (truncated to 15-char NetBIOS limit).
try {
    $serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber.Trim()
    $prefix  = 'EDU-'
    if ($serial.Length -gt 9) { $serial = $serial.Substring(0, 9) }
    $newName = "$prefix$serial"
    Rename-Computer -NewName $newName -Force -ErrorAction Stop
    Write-Host "Computer will be renamed to '$newName' after reboot"
} catch {
    Write-Warning "Hostname assignment failed: $($_.Exception.Message)"
}

# Power plan: High performance during post-setup
Write-Host 'Setting PowerPlan to High Performance'
powercfg /setactive DED574B5-45A0-4F42-8737-46345C09C238 | Out-Null
Write-Host 'Confirming PowerPlan [powercfg /getactivescheme]'
powercfg /getactivescheme

# Keep the device awake while we run post-setup tasks
powercfg -x -standby-timeout-ac 0
powercfg -x -standby-timeout-dc 0
powercfg -x -hibernate-timeout-ac 0
powercfg -x -hibernate-timeout-dc 0
Set-PowerSettingSleepAfter -PowerSource AC -Minutes 0
Set-PowerSettingTurnMonitorOffAfter -PowerSource AC -Minutes 0

# Run your custom SetupComplete.cmd if present
Write-OutPut 'Running Scripts in Custom OSDCloud SetupComplete Folder'
$SetupCompletePath = "C:\OSDCloud\Scripts\SetupComplete\SetupComplete.cmd"
if (Test-Path $SetupCompletePath) {
    $SetupComplete = Get-ChildItem $SetupCompletePath -Filter SetupComplete.cmd
    if ($SetupComplete) {cmd.exe /start /wait /c $SetupComplete.FullName}
} else {
    Write-Host "No custom SetupComplete.cmd found at $SetupCompletePath"
}

# Sets property in registry to disable Windows automatic encrytion from start during oobe phase, it does not block Intune bitlocker policy from encrypting devices post enrollment.  
# https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/
Write-Host -BackgroundColor Black -ForegroundColor Green "Disable Windows Automatic Encryption"
if (-not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker')) { 
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' -Force | Out-Null}
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' -Name 'PreventDeviceEncryption' -Value 1 -PropertyType DWord -Force | Out-Null

# Configure OOBE suppression directly in registry for reliability in SetupComplete phase.
Write-Host 'Configuring OOBE suppression flags'
try {
        $oobePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'
        if (-not (Test-Path $oobePath)) { New-Item -Path $oobePath -Force | Out-Null }

        New-ItemProperty -Path $oobePath -Name 'SkipMachineOOBE' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $oobePath -Name 'SkipUserOOBE' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $oobePath -Name 'HideOnlineAccountScreens' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $oobePath -Name 'HideLocalAccountScreen' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $oobePath -Name 'HideWirelessSetupInOOBE' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $oobePath -Name 'HideEULAPage' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $oobePath -Name 'UnattendCreatedUser' -Value 1 -PropertyType DWord -Force | Out-Null

        # BypassNRO prevents forced network/account path from re-enabling consumer OOBE prompts.
        New-ItemProperty -Path $oobePath -Name 'BypassNRO' -Value 1 -PropertyType DWord -Force | Out-Null

        # Keep the setup type on organizational flow to avoid personal/work-school chooser.
        $setupOobePath = 'HKLM:\SYSTEM\Setup\OOBE'
        if (-not (Test-Path $setupOobePath)) { New-Item -Path $setupOobePath -Force | Out-Null }
        New-ItemProperty -Path $setupOobePath -Name 'SetupType' -Value 2 -PropertyType DWord -Force | Out-Null
} catch {
        Write-Warning "OOBE suppression configuration failed: $($_.Exception.Message)"
}

# Restore Balanced plan after tasks
Write-Host 'Setting PowerPlan to Balanced'
Set-PowerSettingTurnMonitorOffAfter -PowerSource AC -Minutes 15
powercfg /setactive 381B4222-F694-41F0-9685-FF5BB260DF2E | Out-Null

# Timing & wrap-up
$EndTime = Get-Date
$RunTimeMinutes = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes, 0)
Write-Host ("End Time: {0}" -f $EndTime.ToString("HH:mm:ss"))
Write-Host "Run Time: $RunTimeMinutes Minutes"
Stop-Transcript

# Reboot after completion
Restart-Computer -Force