##=======================================================================
##   Mark: Variables and Constants
##=======================================================================
# --- SetupComplete Script URLs ---
$UriSetupComplete = 'https://github.com/Lenander88/EDU/raw/dev/SetupComplete.ps1'
$UriSetupCompleteCmd = 'https://github.com/Lenander88/EDU/raw/dev/SetupComplete.cmd'
$UriInstallLCU = 'https://github.com/Lenander88/EDU/raw/dev/Install-LCU.ps1'
$UriEDUCSV = 'https://raw.githubusercontent.com/Lenander88/EDU/dev/EDU.csv'

# --- Status and Initialization Messages ---
$MsgStartOSDCloud = "Start OSDCloud ZTI"
$MsgUpdateOSDModule = "Updating OSD PowerShell Module"
$MsgImportOSDModule = "Importing OSD PowerShell Module"
$MsgStartOSDCloudDeploy = "Starting OSDCloud"
$MsgStageSetupComplete = "Staging SetupComplete"
$MsgRestartIn20Seconds = "Restarting in 20 seconds"


# --- UI Dialog Messages ---
$MsgEDUTitle = "EDU Build Selection"
$MsgEDULabel = "Build"
$MsgOKButton = "OK"
$MsgOSDCloudTitle = "OSDCloud"
$MsgWarning = "Warning"
$MsgSelectValidOption = "Please select a valid EDU build."
$MsgStartText  = "Starting EDU Build Selection"
$MsgSelectText = "Select EDU Build"
$MsgCredText   = "Enter Local Account Credentials"
$MsgInjectingCredentials = "Injecting credentials into SetupComplete script"

# --- UI Styling ---
$BackgroundColor = "Black"
$ForegroundColor = "Green"

# --- File Paths and Settings ---
$EDUCSVPath = ".\EDU.csv"
$PSWindowsUpdateModulePath = 'C:\Program Files\WindowsPowerShell\Modules'
$SetupCompleteOutPath = 'C:\Windows\Setup\Scripts\SetupComplete.ps1'
$SetupCompleteCmdOutPath = 'C:\OSDCloud\Scripts\SetupComplete\SetupComplete.cmd'
$InstallLCUOutPath = 'C:\OSDCloud\Scripts\SetupComplete\Install-LCU.ps1'
$SetupPath = 'C:\OSDCloud\Scripts\SetupComplete'
$LogRoot = 'X:\OSDCloud\Logs'
$TranscriptPath = Join-Path $LogRoot 'StartURL-Dev-01.log'

function Stop-TranscriptSafe {
    try {
        Stop-Transcript | Out-Null
    } catch {
    }
}

if (-not (Test-Path $LogRoot)) {
    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
}
try {
    Start-Transcript -Path $TranscriptPath -ErrorAction Stop | Out-Null
} catch {
    Write-Warning "Could not start transcript at $TranscriptPath: $($_.Exception.Message)"
}

##=======================================================================
##   [PreOS] Params
##=======================================================================
$Params = @{
    OSVersion  = "Windows 11"
    OSBuild    = "25H2"     # "24H2" | "25H2"
    OSEdition  = "Pro"      # "Enterprise" | "Pro"
    OSLanguage = "en-us"
    OSLicense  = "Retail"   # "Volume" | "Retail"
    ZTI        = $true
    Firmware   = $false
}
##=======================================================================
## [PreOS] Scrpt Start
Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgStartText
Start-Sleep -Seconds 5

##=======================================================================
##   [PreOS] Group all Add-Type calls together
##=======================================================================
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

##=======================================================================
##   [PreOS] EDU Build Selection
##=======================================================================

# Download EDU.csv if missing or older than 1 day
if (!(Test-Path $EDUCSVPath) -or ((Get-Item $EDUCSVPath).LastWriteTime -lt (Get-Date).AddDays(-1))) {
    Invoke-WebRequest -Uri $UriEDUCSV -OutFile $EDUCSVPath -UseBasicParsing
}
$options = Import-CSV $EDUCSVPath

    # Create Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $MsgEDUTitle
    $form.Size = New-Object System.Drawing.Size(350, 150)
    $form.StartPosition = "CenterScreen"

    # Create Label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $MsgEDULabel
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($label)

    # Create ComboBox
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(120, 20)
    $comboBox.Size = New-Object System.Drawing.Size(200, 20)
    $comboBox.DropDownStyle = 'DropDownList'

    # populate ComboBox with options from CSV
    foreach ($item in $options) {
        $comboBox.Items.Add($item.OptionName)
    }

    # Add ComboBox to Form
    $form.Controls.Add($comboBox)

    # Create OK Button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = $MsgOKButton
    $okButton.Location = New-Object System.Drawing.Point(120,60)
    $okButton.Cursor = [System.Windows.Forms.Cursors]::Hand

    # OK Button Click Event Handler
    $okButtonClickHandler = {
        $selectedOption = $comboBox.SelectedItem
        if ($selectedOption) {
            # Assign corresponding value to global variable based on selection
            $global:edu         = ($options | Where-Object { $_.OptionName -eq $selectedOption }).Value
            $global:eduSiteName = $selectedOption
            $form.Close()
        } else {
            # No selection made, show warning message
            [System.Windows.Forms.MessageBox]::Show($MsgSelectValidOption)
        }
    }
    $okButton.Add_Click($okButtonClickHandler)
    $form.Controls.Add($okButton)

    # Show Form
    $form.ShowDialog()

if ([string]::IsNullOrWhiteSpace($global:edu)) {
    Write-Error "No EDU build selected. Aborting deployment flow."
    Stop-TranscriptSafe
    exit 1
}

##=======================================================================
##   [PreOS] Credential Input GUI
##=======================================================================
Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgCredText

    $credForm = New-Object System.Windows.Forms.Form
    $credForm.Text = $MsgCredText
    $credForm.Size = New-Object System.Drawing.Size(360, 310)
    $credForm.StartPosition = "CenterScreen"
    $credForm.FormBorderStyle = 'FixedDialog'
    $credForm.MaximizeBox = $false
    $credForm.MinimizeBox = $false

    # Helper: create a label
    function New-Label($text, $x, $y) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $l.Location = New-Object System.Drawing.Point($x, $y)
        $l.Size = New-Object System.Drawing.Size(130, 20)
        return $l
    }

    # Helper: create a text box
    function New-TextBox($x, $y, [switch]$Password) {
        $t = New-Object System.Windows.Forms.TextBox
        $t.Location = New-Object System.Drawing.Point($x, $y)
        $t.Size = New-Object System.Drawing.Size(180, 20)
        if ($Password) { $t.UseSystemPasswordChar = $true }
        return $t
    }

    # Username
    $credForm.Controls.Add((New-Label "Username:"         20,  20))
    $txtUsername = New-TextBox 160 20
    $credForm.Controls.Add($txtUsername)

    # Password
    $credForm.Controls.Add((New-Label "Password:"         20,  55))
    $txtPassword = New-TextBox 160 55 -Password
    $credForm.Controls.Add($txtPassword)

    # Confirm Password
    $credForm.Controls.Add((New-Label "Confirm Password:" 20,  90))
    $txtConfirm = New-TextBox 160 90 -Password
    $credForm.Controls.Add($txtConfirm)

    # Full Name
    $credForm.Controls.Add((New-Label "Full Name:"        20, 125))
    $txtFullName = New-TextBox 160 125
    $credForm.Controls.Add($txtFullName)

    # Description
    $credForm.Controls.Add((New-Label "Description:"      20, 160))
    $txtDescription = New-TextBox 160 160
    $txtDescription.Text = "Local administrator account for EDU purposes"
    $credForm.Controls.Add($txtDescription)

    # Computer Name Prefix
    $credForm.Controls.Add((New-Label "Computer Prefix:"  20, 195))
    $txtPrefix = New-TextBox 160 195
    $credForm.Controls.Add($txtPrefix)

    # OK Button
    $credOkButton = New-Object System.Windows.Forms.Button
    $credOkButton.Text = "OK"
    $credOkButton.Location = New-Object System.Drawing.Point(130, 235)
    $credOkButton.Size = New-Object System.Drawing.Size(80, 28)

    $credOkButton.Add_Click({
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($txtUsername.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Username is required.", "Validation Error")
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtPassword.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Password is required.", "Validation Error")
            return
        }
        if ($txtPassword.Text -ne $txtConfirm.Text) {
            [System.Windows.Forms.MessageBox]::Show("Passwords do not match.", "Validation Error")
            $txtPassword.Clear()
            $txtConfirm.Clear()
            $txtPassword.Focus()
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtPrefix.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Computer Name Prefix is required.", "Validation Error")
            return
        }
        $global:LocalUserName        = $txtUsername.Text.Trim()
        $global:LocalUserPassword    = $txtPassword.Text
        $global:LocalUserFullName    = $txtFullName.Text.Trim()
        $global:LocalUserDescription = $txtDescription.Text.Trim()
        $global:ComputerNamePrefix   = $txtPrefix.Text.Trim()
        $credForm.Close()
    })

    $credForm.Controls.Add($credOkButton)
    $credForm.AcceptButton = $credOkButton
    $credForm.ShowDialog()

if (
    [string]::IsNullOrWhiteSpace($global:LocalUserName) -or
    [string]::IsNullOrWhiteSpace($global:LocalUserPassword) -or
    [string]::IsNullOrWhiteSpace($global:ComputerNamePrefix)
) {
    Write-Error "Credential dialog was cancelled or required values were empty. Aborting deployment flow."
    Stop-TranscriptSafe
    exit 1
}

Write-Host "  Username       : $global:LocalUserName"
Write-Host "  Full Name      : $global:LocalUserFullName"
Write-Host "  Computer Prefix: $global:ComputerNamePrefix"
Write-Host "  Password       : [protected]"


##=======================================================================
##   [PreOS] Update Module
##=======================================================================
Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgUpdateOSDModule
Install-Module OSD -Force -SkipPublisherCheck

Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgImportOSDModule
Import-Module OSD -Force

##===================================================================
##   [PreOS] OS Installation
##===================================================================
Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgStartOSDCloudDeploy
Start-OSDCloud @Params

##=======================================================================
##   [PostOS] SetupComplete CMD Command Line
##=======================================================================
Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgStageSetupComplete

# Ensure PSWindowsUpdate is staged for post-boot use
Save-Module -Name PSWindowsUpdate -Path $PSWindowsUpdateModulePath -Force

# Ensure SetupComplete folder exists
if (-not (Test-Path $SetupPath)) {
    New-Item -Path $SetupPath -ItemType Directory -Force | Out-Null
}

# Run the selected EDU SetupComplete download command (from ComboBox selection)
$eduCommand = ($global:edu -replace "'\s*-OutFile", "' -OutFile").Trim()

if ($eduCommand -notmatch "^Invoke-WebRequest\s+-Uri\s+'(?<Uri>https://[^']+)'\s+-OutFile\s+(?<OutFile>.+)$") {
    Write-Error "Selected EDU command is malformed and cannot be executed safely."
    Stop-TranscriptSafe
    exit 1
}

$selectedUri = $matches['Uri']
$selectedOutFile = $matches['OutFile'].Trim().Trim("'").Trim('"')
if ($selectedOutFile -ne $SetupCompleteOutPath) {
    Write-Error "Selected EDU command writes to unexpected path '$selectedOutFile'. Expected '$SetupCompleteOutPath'."
    Stop-TranscriptSafe
    exit 1
}
if ($selectedUri -notmatch '^https://(raw\.githubusercontent\.com/Lenander88/EDU/dev|github\.com/Lenander88/EDU/raw/dev)/.+\.ps1$') {
    Write-Error "Selected EDU command URI is outside the approved EDU repository path: $selectedUri"
    Stop-TranscriptSafe
    exit 1
}

Invoke-Expression $eduCommand

# Download Install-LCU.ps1
Invoke-WebRequest -Uri $UriInstallLCU -OutFile $InstallLCUOutPath -UseBasicParsing

##=======================================================================
##   [PostOS] Inject Credentials into SetupComplete script
##   Replaces the hardcoded credential variables in the downloaded
##   SetupComplete.ps1 so the correct account is created on first boot.
##=======================================================================
Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgInjectingCredentials

$setupScript = Get-Item -Path $SetupCompleteOutPath -ErrorAction SilentlyContinue

if ($setupScript) {
    $content = Get-Content -Path $setupScript.FullName -Raw

    $escapedLocalUserName = $global:LocalUserName -replace "'", "''"
    $escapedLocalUserPassword = $global:LocalUserPassword -replace "'", "''"
    $escapedLocalUserFullName = $global:LocalUserFullName -replace "'", "''"
    $escapedLocalUserDescription = $global:LocalUserDescription -replace "'", "''"
    $escapedComputerNamePrefix = $global:ComputerNamePrefix -replace "'", "''"

    $content = $content -replace "(?m)^\`$LocalUserName\s*=\s*'[^']*'",        "\`$LocalUserName = '$escapedLocalUserName'"
    $content = $content -replace "(?m)^\`$LocalUserPassword\s*=\s*'[^']*'",    "\`$LocalUserPassword = '$escapedLocalUserPassword'"
    $content = $content -replace "(?m)^\`$LocalUserFullName\s*=\s*'[^']*'",    "\`$LocalUserFullName = '$escapedLocalUserFullName'"
    $content = $content -replace "(?m)^\`$LocalUserDescription\s*=\s*'[^']*'", "\`$LocalUserDescription = '$escapedLocalUserDescription'"
    $content = $content -replace "(?m)^\`$ComputerNamePrefix\s*=\s*'[^']*'",   "\`$ComputerNamePrefix = '$escapedComputerNamePrefix'"

    Set-Content -Path $setupScript.FullName -Value $content -Force
    Write-Host "  Credentials injected into: $($setupScript.FullName)"
} else {
    Write-Warning "  SetupComplete.ps1 not found in C:\Windows\Setup\Scripts — credentials not injected."
}

##=======================================================================
##   Restart-Computer
##=======================================================================
Write-Host -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor $MsgRestartIn20Seconds
Start-Sleep -Seconds 20
Stop-TranscriptSafe
wpeutil reboot