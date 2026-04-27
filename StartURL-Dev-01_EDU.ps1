##================================================
## MARK: Variables
##================================================
    $backgroundColor = "Black"
    $foregroundColor = "Green"
    # Path to CSV and URL
    $csvPath = ".\EDU.csv"
    $csvUrl = 'https://raw.githubusercontent.com/Lenander88/OSDCloud/main/EDU.csv'
    # Write-Host texts before ComboBox
    $startText = "Starting EDU Build Selection"
    # ComboBox action text
    $selectText = "Select EDU Build"
    # SetupComplete folder path
    $setupPath = 'C:\OSDCloud\Scripts\SetupComplete'

##=======================================================================
##   [PreOS] Params
##=======================================================================
$Params = @{
    OSVersion = "Windows 11"
    OSBuild = "25H2" # "24H2" | "25H2"
    OSEdition = "Pro" # "Enterprise" | "Pro"
    OSLanguage = "en-us"
    OSLicense = "Retail" # "Volume" | "Retail"
    ZTI = $true
    Firmware = $false
}

##=======================================================================
##   [PreOS] Update Module
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Updating OSD PowerShell Module"
Install-Module OSD -Force -SkipPublisherCheck

Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Importing OSD PowerShell Module"
Import-Module OSD -Force   
##=======================================================================
##   [PreOS] Group all Add-Type calls together for clarity
##=======================================================================
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

##=======================================================================
##   [PreOS] EDU Build Selection
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor $startText
Start-Sleep -Seconds 5

# Path to CSV file
if (!(Test-Path $csvPath) -or ((Get-Item $csvPath).LastWriteTime -lt (Get-Date).AddDays(-1))) {
    Invoke-WebRequest -Uri $csvUrl -OutFile $csvPath
}
# Import CSV
$options = Import-CSV $csvPath

    # Create Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $selectText
    $form.Size = New-Object System.Drawing.Size(300,150)
    $form.StartPosition = "CenterScreen"

    # Create ComboBox
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(50,20)
    $comboBox.Size = New-Object System.Drawing.Size(200,20)
    $comboBox.DropDownStyle = 'DropDownList'  # Prevent typing, only select

    # Populate ComboBox with OptionName from CSV
    foreach ($item in $options) {
        $comboBox.Items.Add($item.OptionName)
    }

    # Add ComboBox to Form
    $form.Controls.Add($comboBox)

    # Create OK Button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(100,60)

    # OK Button Click Event Handler
    $okButtonClickHandler = {
        $selectedOption = $comboBox.SelectedItem
        if ($selectedOption) {
            # Assign corresponding Value to $edu (hidden from user)
            $global:edu = ($options | Where-Object { $_.OptionName -eq $selectedOption }).Value
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select an option.")
        }
    }
    # Attach Click Event Handler
    $okButton.Add_Click($okButtonClickHandler)

    # Add OK Button to Form
    $form.Controls.Add($okButton)

    # Show Form
    $form.ShowDialog()

##=======================================================================
##   [OS] Start-OSDCloud with Params
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Start OSDCloud"
Start-OSDCloud @Params

##=======================================================================
##   [PostOS] SetupComplete CMD Command Line
##=======================================================================

Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Stage SetupComplete"

# Ensure PSWindowsUpdate is staged for post-boot use
Save-Module -Name PSWindowsUpdate -Path 'C:\Program Files\WindowsPowerShell\Modules' -Force

# Ensure SetupComplete folder exists
if (-not (Test-Path $setupPath)) {
    New-Item -Path $setupPath -ItemType Directory -Force | Out-Null
}

# Run the selected EDU command (from ComboBox selection)
Invoke-Expression $edu

# Download SetupComplete.cmd
# Invoke-WebRequest -Uri 'https://github.com/lenander88/OSDCloud/raw/main/SetupComplete.cmd' -OutFile "$setupPath\SetupComplete.cmd"

# Download Install-LCU.ps1
Invoke-WebRequest -Uri 'https://github.com/lenander88/OSDCloud/raw/main/Install-LCU.ps1' -OutFile "$setupPath\Install-LCU.ps1"

##=======================================================================
##   Restart-Computer
##=======================================================================   
    Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Restart in 20 seconds"
    Start-Sleep -Seconds 20
    wpeutil reboot
##================================================
## MARK: Variables
##================================================
    $backgroundColor = "Black"
    $foregroundColor = "Green"

    # EDU Build CSV
    $csvPath = ".\EDU.csv"
    $csvUrl  = 'https://raw.githubusercontent.com/Lenander88/OSDCloud/main/EDU.csv'

    # Write-Host texts
    $startText  = "Starting EDU Build Selection"
    $selectText = "Select EDU Build"
    $credText   = "Enter Local Account Credentials"

    # SetupComplete folder path
    $setupPath = 'C:\OSDCloud\Scripts\SetupComplete'

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
##   [PreOS] Update Module
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Updating OSD PowerShell Module"
Install-Module OSD -Force -SkipPublisherCheck

Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Importing OSD PowerShell Module"
Import-Module OSD -Force

##=======================================================================
##   [PreOS] Group all Add-Type calls together
##=======================================================================
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

##=======================================================================
##   [PreOS] EDU Build Selection
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor $startText
Start-Sleep -Seconds 5

# Download EDU.csv if missing or older than 1 day
if (!(Test-Path $csvPath) -or ((Get-Item $csvPath).LastWriteTime -lt (Get-Date).AddDays(-1))) {
    Invoke-WebRequest -Uri $csvUrl -OutFile $csvPath -UseBasicParsing
}
$options = Import-CSV $csvPath

    # Create Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $selectText
    $form.Size = New-Object System.Drawing.Size(300,150)
    $form.StartPosition = "CenterScreen"

    # Create ComboBox
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(50,20)
    $comboBox.Size = New-Object System.Drawing.Size(200,20)
    $comboBox.DropDownStyle = 'DropDownList'

    foreach ($item in $options) {
        $comboBox.Items.Add($item.EDU)
    }
    $form.Controls.Add($comboBox)

    # Create OK Button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(100,60)

    $okButtonClickHandler = {
        $selectedOption = $comboBox.SelectedItem
        if ($selectedOption) {
            $global:edu         = ($options | Where-Object { $_.EDU -eq $selectedOption }).Command
            $global:eduSiteName = $selectedOption
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select an option.")
        }
    }
    $okButton.Add_Click($okButtonClickHandler)
    $form.Controls.Add($okButton)
    $form.ShowDialog()

##=======================================================================
##   [PreOS] Credential Input GUI
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor $credText

    $credForm = New-Object System.Windows.Forms.Form
    $credForm.Text = $credText
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

Write-Host "  Username       : $global:LocalUserName"
Write-Host "  Full Name      : $global:LocalUserFullName"
Write-Host "  Computer Prefix: $global:ComputerNamePrefix"
Write-Host "  Password       : [protected]"

##=======================================================================
##   [OS] Start-OSDCloud with Params
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Start OSDCloud"
Start-OSDCloud @Params

##=======================================================================
##   [PostOS] SetupComplete CMD Command Line
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Stage SetupComplete"

# Ensure PSWindowsUpdate is staged for post-boot use
Save-Module -Name PSWindowsUpdate -Path 'C:\Program Files\WindowsPowerShell\Modules' -Force

# Ensure SetupComplete folder exists
if (-not (Test-Path $setupPath)) {
    New-Item -Path $setupPath -ItemType Directory -Force | Out-Null
}

# Run the selected EDU SetupComplete download command (from ComboBox selection)
Invoke-Expression $global:edu

# Download Install-LCU.ps1
Invoke-WebRequest -Uri 'https://github.com/Lenander88/L88/raw/main/Install-LCU.ps1' -OutFile "$setupPath\Install-LCU.ps1" -UseBasicParsing

##=======================================================================
##   [PostOS] Inject Credentials into SetupComplete script
##   Replaces the hardcoded credential variables in the downloaded
##   SetupComplete.ps1 so the correct account is created on first boot.
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Injecting credentials into SetupComplete script"

$setupScript = Get-Item -Path 'C:\Windows\Setup\Scripts\SetupComplete.ps1' -ErrorAction SilentlyContinue

if ($setupScript) {
    $content = Get-Content -Path $setupScript.FullName -Raw

    $content = $content -replace "(?m)^\`$LocalUserName\s*=\s*'[^']*'",        "`$LocalUserName = '$($global:LocalUserName)'"
    $content = $content -replace "(?m)^\`$LocalUserPassword\s*=\s*'[^']*'",    "`$LocalUserPassword = '$($global:LocalUserPassword)'"
    $content = $content -replace "(?m)^\`$LocalUserFullName\s*=\s*'[^']*'",    "`$LocalUserFullName = '$($global:LocalUserFullName)'"
    $content = $content -replace "(?m)^\`$LocalUserDescription\s*=\s*'[^']*'", "`$LocalUserDescription = '$($global:LocalUserDescription)'"
    $content = $content -replace "(?m)^\`$ComputerNamePrefix\s*=\s*'[^']*'",   "`$ComputerNamePrefix = '$($global:ComputerNamePrefix)'"

    Set-Content -Path $setupScript.FullName -Value $content -Force
    Write-Host "  Credentials injected into: $($setupScript.FullName)"
} else {
    Write-Warning "  SetupComplete.ps1 not found in C:\Windows\Setup\Scripts — credentials not injected."
}

##=======================================================================
##   Restart-Computer
##=======================================================================
Write-Host -BackgroundColor $backgroundColor -ForegroundColor $foregroundColor "Restart in 20 seconds"
Start-Sleep -Seconds 20
wpeutil reboot
