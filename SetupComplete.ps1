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

# Stage unattend.xml so OOBE skips the device-name and private/work-school prompts.
# SetupComplete runs before OOBE, so C:\Windows\Panther\unattend.xml is picked up by the oobeSystem pass.
Write-Host 'Staging unattend.xml to suppress OOBE prompts'
$panther = 'C:\Windows\Panther'
if (-not (Test-Path $panther)) { New-Item -Path $panther -ItemType Directory -Force | Out-Null }
$unattendContent = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <OOBE>
        <!-- Skip "Name your device" prompt -->
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <!-- Skip per-user OOBE (privacy settings, etc.) -->
        <SkipUserOOBE>true</SkipUserOOBE>
        <!-- Hide "How will you use this PC?" (personal/work-school) -->
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <!-- Hide local account creation screen (account is provisioned by SetupComplete) -->
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <!-- Hide OEM registration, wireless setup, and EULA pages -->
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <HideEULAPage>true</HideEULAPage>
        <!-- Default network location to Work to suppress the private/public prompt -->
        <NetworkLocation>Work</NetworkLocation>
      </OOBE>
    </component>
  </settings>
</unattend>
'@
Set-Content -Path "$panther\unattend.xml" -Value $unattendContent -Encoding UTF8 -Force

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