Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ======================================================
# 1. Paths and Logging System (KORRIGIERT FÜR ORDNERSTRUKTUR)
# ======================================================
# Geht einen Ordner höher als SRC, um logs und reports zu finden
$scriptPath = $PSScriptRoot
$parentPath = Split-Path -Parent $scriptPath

$logFolder = "$parentPath\logs"
$reportFolder = "$parentPath\reports"
$logFile = "$logFolder\app_log.csv"

# Ordner automatisch erstellen, falls sie fehlen
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory | Out-Null }
if (-not (Test-Path $reportFolder)) { New-Item -Path $reportFolder -ItemType Directory | Out-Null }

# Falls die Datei neu ist, Kopfzeile für CSV erstellen
if (-not (Test-Path $logFile)) {
    "Zeitstempel;Level;Nachricht" | Out-File $logFile -Encoding UTF8
}

function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time;$Level;$Message" | Out-File $logFile -Append -Encoding UTF8
}

function Write-Report {
    param ($IP, $CIDR, $Results, $RunID)
    $timestamp = Get-Date -UFormat "%Y%m%d_%H%M%S"
    $reportFile = "$reportFolder\Report_$($timestamp)_$($RunID).md"
    
    $reportContent = @"
# IP Subnetting Bericht
**Run-ID:** $RunID
**Datum:** $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")
**Eingabe:** $IP / $CIDR

| Eigenschaft     | Wert               |
|-----------------|-------------------|
| **Network ID** | $($Results[0])    |
| **First Host** | $($Results[1])    |
| **Last Host** | $($Results[2])    |
| **Broadcast** | $($Results[3])    |
| **Subnet Mask** | $($Results[4])    |

---
*Automatisch generiert durch IP Subnetting Calculator*
"@
    $reportContent | Out-File $reportFile -Encoding UTF8
}

Write-Log "=== Programmstart ==="

# ======================================================
# 2. GUI Design
# ======================================================
$fontLabel = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$fontInput = New-Object System.Drawing.Font("Segoe UI", 13)
$fontSlash = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$fontResult = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)

$form = New-Object System.Windows.Forms.Form
$form.Text = "IP-Subnetting-Rechner"
$form.Size = [System.Drawing.Size]::new(800, 650)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

$lblIP = New-Object System.Windows.Forms.Label
$lblIP.Text = "IP-Adresse:"
$lblIP.Font = $fontLabel
$lblIP.Location = [System.Drawing.Point]::new(30, 30)
$lblIP.Size = [System.Drawing.Size]::new(150, 30)
$form.Controls.Add($lblIP)

$txtIP = New-Object System.Windows.Forms.TextBox
$txtIP.Font = $fontInput
$txtIP.Text = "10.10.10.10"
$txtIP.Location = [System.Drawing.Point]::new(30, 65)
$txtIP.Size = [System.Drawing.Size]::new(250, 40)
$form.Controls.Add($txtIP)

$lblCIDR = New-Object System.Windows.Forms.Label
$lblCIDR.Text = "CIDR:"
$lblCIDR.Font = $fontLabel
$lblCIDR.Location = [System.Drawing.Point]::new(330, 30)
$lblCIDR.Size = [System.Drawing.Size]::new(100, 30)
$form.Controls.Add($lblCIDR)

$lblStaticSlash = New-Object System.Windows.Forms.Label
$lblStaticSlash.Text = "/"
$lblStaticSlash.Font = $fontSlash
$lblStaticSlash.Location = [System.Drawing.Point]::new(290, 60)
$lblStaticSlash.Size = [System.Drawing.Size]::new(30, 40)
$form.Controls.Add($lblStaticSlash)

$txtCIDR = New-Object System.Windows.Forms.TextBox
$txtCIDR.Font = $fontInput
$txtCIDR.Text = "24"
$txtCIDR.Location = [System.Drawing.Point]::new(330, 65)
$txtCIDR.Size = [System.Drawing.Size]::new(60, 40)
$form.Controls.Add($txtCIDR)

$btn = New-Object System.Windows.Forms.Button
$btn.Text = "Berechnen"
$btn.Font = $fontLabel
$btn.BackColor = [System.Drawing.Color]::LightSteelBlue
$btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btn.Location = [System.Drawing.Point]::new(450, 58)
$btn.Size = [System.Drawing.Size]::new(280, 45)
$form.Controls.Add($btn)

$labelsText = @("Network ID", "First Host", "Last Host", "Broadcast IP", "Subnet Mask")
$txtResults = @()

for ($i = 0; $i -lt $labelsText.Count; $i++) {
    $yPos = 160 + ($i * 85)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labelsText[$i]
    $lbl.Font = $fontLabel
    $lbl.Location = [System.Drawing.Point]::new(30, $yPos)
    $lbl.Size = [System.Drawing.Size]::new(200, 30)
    $form.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Font = $fontResult
    $txt.ReadOnly = $true
    $txt.BackColor = [System.Drawing.Color]::White
    $txt.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $txt.Location = [System.Drawing.Point]::new(250, $yPos - 5)
    $txt.Size = [System.Drawing.Size]::new(250, 45) 
    $form.Controls.Add($txt)
    $txtResults += $txt
}

# 3. Calculation Logic & Reporting

$btn.Add_Click({
    try {
        $runID = Get-Random -Minimum 1000 -Maximum 9999
        $rawIP = $txtIP.Text.Trim()
        $rawCIDR = $txtCIDR.Text.Replace("/", "").Trim()
        
        Write-Log "RunID: $runID - Calculation for $rawIP / $rawCIDR"

        $ipParts = $rawIP.Split('.')
        if ($ipParts.Count -ne 4) { throw "Format Error: 4 Octets required." }
        foreach ($part in $ipParts) {
            if ($part -match "^\d+$") {
                $val = [int]$part
                if ($val -lt 0 -or $val -gt 255) { throw "Value '$part' out of range (0-255)." }
            } else { throw "'$part' is not a valid number." }
        }

        if ($rawCIDR -match "^\d+$") {
            $cidr = [int]$rawCIDR
            if ($cidr -lt 0 -or $cidr -gt 32) { throw "CIDR must be 0-32." }
        } else { throw "CIDR must be a number." }

        [double]$ipNumeric = ([double][int]$ipParts[0] * 16777216) + 
                             ([double][int]$ipParts[1] * 65536) + 
                             ([double][int]$ipParts[2] * 256) + 
                             [double][int]$ipParts[3]

        [double]$totalIPs = [Math]::Pow(2, (32 - $cidr))
        [double]$netNumeric = [Math]::Floor($ipNumeric / $totalIPs) * $totalIPs
        [double]$bcastNumeric = $netNumeric + ($totalIPs - 1)
        [double]$maskNumeric = [Math]::Pow(2, 32) - $totalIPs
        if ($cidr -eq 0) { $maskNumeric = 0 }

        function To-IPString([double]$n) {
            $o1 = [Math]::Floor($n / 16777216) % 256
            $o2 = [Math]::Floor($n / 65536) % 256
            $o3 = [Math]::Floor($n / 256) % 256
            $o4 = $n % 256
            return "$o1.$o2.$o3.$o4"
        }

        $txtResults[0].Text = To-IPString $netNumeric
        $txtResults[1].Text = if ($cidr -lt 31) { To-IPString ($netNumeric + 1) } else { To-IPString $netNumeric }
        $txtResults[2].Text = if ($cidr -lt 31) { To-IPString ($bcastNumeric - 1) } else { To-IPString $bcastNumeric }
        $txtResults[3].Text = To-IPString $bcastNumeric
        $txtResults[4].Text = To-IPString $maskNumeric

        $resValues = $txtResults | ForEach-Object { $_.Text }
        Write-Report -IP $rawIP -CIDR $rawCIDR -Results $resValues -RunID $runID

        Write-Log "RunID: $runID - Success"
    }
    catch {
        Write-Log "RunID: $runID - Error: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show($($_.Exception.Message), "Error", 0, 48)
    }
})

[void]$form.ShowDialog()
Write-Log "=== Programm beendet ==="
