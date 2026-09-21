# Install-LCU.ps1; Location: C:\OSDCloud\Scripts\SetupComplete\Install-LCU.ps1
# Installs latest SSU/LCU + critical updates (max 3 retries). Does not auto-reboot during install; reboot handled separately.

# Logging first
$StartTime = Get-Date
Start-Transcript -Path 'C:\OSDCloud\Logs\Install-LCU.log' -ErrorAction Ignore
Write-Host "Starting Install-LCU Script Process"
Write-Host ("Start Time: {0}" -f $StartTime.ToString("HH:mm:ss"))
Start-Sleep -Seconds 10

# Install-Module PSWindowsUpdate -Force
Import-Module PSWindowsUpdate -Force

# Pull latest SSU/LCU + critical updates - targeted for speed during OOBE
# Only install Security Updates and Critical Updates (skip optional Updates)
<
$tries = 0
while ($tries -lt 3) {
  try {
    Get-WindowsUpdate -MicrosoftUpdate -Category "Security Updates","Critical Updates" -AcceptAll -Install -IgnoreReboot
    break
  } catch {
    Write-Host "Update installation failed (attempt $($tries + 1)/3): $_" -ForegroundColor Yellow
    $tries++
    Start-Sleep -Seconds 60
  }
}
# Final status check: warn if all retries failed
if ($tries -ge 3) {
    Write-Host "WARNING: Update installation failed after 3 attempts" -ForegroundColor Red
}
>

# Trigger Microsoft Edge update
try {
  Start-Process -FilePath "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" `
    -ArgumentList "/silent /install appguid={56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}&appname=Microsoft%20Edge&needsadmin=True" `
    -Wait -ErrorAction Stop
} catch {
  Write-Host "Microsoft Edge update was not started: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Timing & wrap-up
$EndTime = Get-Date
$RunTimeMinutes = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes, 0)
Write-Host ("End Time: {0}" -f $EndTime.ToString("HH:mm:ss"))
Write-Host "Run Time: $RunTimeMinutes Minutes"
Stop-Transcript