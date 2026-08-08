# ==============================================================
#              WINDOWS & OFFICE LICENSE FORENSIC
#                         Maruchi Edition
#
# READ ONLY:
# - Does NOT activate Windows
# - Does NOT install/remove product keys
# - Does NOT modify Registry
# - Does NOT modify Services
# - Does NOT modify Scheduled Tasks
# ==============================================================

$ErrorActionPreference = "SilentlyContinue"

# --------------------------------------------------------------
# CONFIG
# --------------------------------------------------------------

$ScriptVersion = "1.0.0"

$SuspiciousTaskPatterns = @(
    "AutoKMS",
    "KMSAuto",
    "KMSAutoNet",
    "KMS_VL_ALL",
    "KMS_VL_ALL_AIO",
    "KMS38",
    "KMS38A",
    "HWID",
    "MAS",
    "Microsoft Activation Scripts",
    "Windows Activation"
)

$SuspiciousServicePatterns = @(
    "AutoKMS",
    "KMSAuto",
    "KMS",
    "KMS38"
)

$SuspiciousPathPatterns = @(
    "*\AutoKMS*",
    "*\KMSAuto*",
    "*\KMS_VL_ALL*",
    "*\KMS38*",
    "*\HWID*",
    "*\MAS*"
)

# --------------------------------------------------------------
# UI
# --------------------------------------------------------------

function Write-Color {
    param(
        [string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    Write-Host $Text -ForegroundColor $Color
}

function Header {

    Clear-Host

    Write-Color ""
    Write-Color "============================================================" Cyan
    Write-Color "             WINDOWS & OFFICE LICENSE FORENSIC" Cyan
    Write-Color "                         v$ScriptVersion" DarkCyan
    Write-Color "============================================================" Cyan
    Write-Color ""
}

function Section {
    param([string]$Title)

    Write-Color ""
    Write-Color "------------------------------------------------------------" DarkCyan
    Write-Color " $Title" Cyan
    Write-Color "------------------------------------------------------------" DarkCyan
}

function OK {
    param([string]$Text)
    Write-Color "[+] $Text" Green
}

function WARN {
    param([string]$Text)
    Write-Color "[!] $Text" Yellow
}

function BAD {
    param([string]$Text)
    Write-Color "[-] $Text" Red
}

function INFO {
    param([string]$Text)
    Write-Color "[i] $Text" Gray
}

function Pause-Tool {
    Write-Host ""
    Read-Host "Nhan Enter de quay lai menu"
}

# --------------------------------------------------------------
# WINDOWS PRODUCT
# --------------------------------------------------------------

function Get-WindowsProducts {

    Get-CimInstance SoftwareLicensingProduct |
        Where-Object {
            $_.ApplicationID -eq "55c92734-d682-4d71-983e-d6ec3f16059f" -and
            $_.PartialProductKey
        }
}

# --------------------------------------------------------------
# WINDOWS EDITION
# --------------------------------------------------------------

function Get-WindowsEdition {

    try {
        $os = Get-CimInstance Win32_OperatingSystem

        return @{
            Caption = $os.Caption
            Version = $os.Version
            Build   = $os.BuildNumber
        }
    }
    catch {

        return @{
            Caption = "Unknown"
            Version = "Unknown"
            Build   = "Unknown"
        }
    }
}

# --------------------------------------------------------------
# OEM / BIOS KEY
# --------------------------------------------------------------

function Get-OEMKey {

    try {

        $service = Get-CimInstance SoftwareLicensingService

        $key = $service.OA3OriginalProductKey

        if ($key) {

            return @{
                Found = $true
                Key   = $key
            }
        }
    }
    catch {}

    return @{
        Found = $false
        Key   = $null
    }
}

# --------------------------------------------------------------
# LICENSE CHANNEL
# --------------------------------------------------------------

function Get-LicenseChannel {

    param(
        [string]$Description,
        [string]$Name
    )

    $text = "$Description $Name"

    if ($text -match "VOLUME_KMSCLIENT") {
        return "VOLUME_KMSCLIENT"
    }

    if ($text -match "VOLUME_MAK") {
        return "VOLUME_MAK"
    }

    if ($text -match "RETAIL") {
        return "RETAIL"
    }

    if ($text -match "OEM_DM") {
        return "OEM_DM"
    }

    if ($text -match "OEM_COA") {
        return "OEM_COA"
    }

    if ($text -match "OEM") {
        return "OEM"
    }

    if ($text -match "GVLK") {
        return "GVLK / VOLUME"
    }

    return "UNKNOWN"
}

# --------------------------------------------------------------
# LICENSE STATUS
# --------------------------------------------------------------

function Get-LicenseStatusText {

    param([int]$Status)

    switch ($Status) {

        0 { return "UNLICENSED" }
        1 { return "LICENSED" }
        2 { return "OOB GRACE" }
        3 { return "OOT GRACE" }
        4 { return "NON-GENUINE GRACE" }
        5 { return "NOTIFICATION" }
        6 { return "EXTENDED GRACE" }

        default {
            return "UNKNOWN ($Status)"
        }
    }
}

# --------------------------------------------------------------
# KMS INFORMATION
# --------------------------------------------------------------

function Get-KMSInformation {

    param(
        $Product
    )

    $hostName = $Product.DiscoveredKeyManagementServiceMachineName
    $port     = $Product.DiscoveredKeyManagementServiceMachinePort

    $configuredHost = $null

    try {

        $kmsReg = Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" `
            -ErrorAction SilentlyContinue

        if ($kmsReg.KeyManagementServiceName) {
            $configuredHost = $kmsReg.KeyManagementServiceName
        }

        if ($kmsReg.KeyManagementServicePort) {
            $port = $kmsReg.KeyManagementServicePort
        }
    }
    catch {}

    return @{
        Host = if ($configuredHost) {
            $configuredHost
        }
        else {
            $hostName
        }

        Port = if ($port) {
            $port
        }
        else {
            "1688 / Unknown"
        }
    }
}

# --------------------------------------------------------------
# WINDOWS ACTIVATION EXPIRATION
# --------------------------------------------------------------

function Get-WindowsExpiration {

    try {

        $slmgr = "$env:windir\System32\slmgr.vbs"

        $result = cscript.exe //nologo $slmgr /xpr 2>$null

        if ($result) {
            return ($result -join " ").Trim()
        }
    }
    catch {}

    return "Unable to determine"
}

# --------------------------------------------------------------
# SUSPICIOUS TASKS
# --------------------------------------------------------------

function Find-SuspiciousTasks {

    $found = @()

    try {

        $tasks = Get-ScheduledTask

        foreach ($task in $tasks) {

            $combined = "$($task.TaskName) $($task.TaskPath)"

            foreach ($pattern in $SuspiciousTaskPatterns) {

                if ($combined -match [regex]::Escape($pattern)) {

                    $found += [PSCustomObject]@{
                        Name = $task.TaskName
                        Path = $task.TaskPath
                    }

                    break
                }
            }
        }
    }
    catch {}

    return $found
}

# --------------------------------------------------------------
# SUSPICIOUS SERVICES
# --------------------------------------------------------------

function Find-SuspiciousServices {

    $found = @()

    try {

        $services = Get-CimInstance Win32_Service

        foreach ($service in $services) {

            $combined = "$($service.Name) $($service.DisplayName) $($service.PathName)"

            foreach ($pattern in $SuspiciousServicePatterns) {

                if ($combined -match [regex]::Escape($pattern)) {

                    $found += [PSCustomObject]@{
                        Name        = $service.Name
                        DisplayName = $service.DisplayName
                        State       = $service.State
                        Path        = $service.PathName
                    }

                    break
                }
            }
        }
    }
    catch {}

    return $found
}

# --------------------------------------------------------------
# SUSPICIOUS FILES
# --------------------------------------------------------------

function Find-SuspiciousFiles {

    $found = @()

    $roots = @(
        "$env:ProgramData",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:windir\System32",
        "$env:windir\SysWOW64"
    )

    foreach ($root in $roots) {

        if (-not $root) {
            continue
        }

        if (-not (Test-Path $root)) {
            continue
        }

        foreach ($pattern in $SuspiciousPathPatterns) {

            try {

                $items = Get-ChildItem `
                    -Path $root `
                    -Filter $pattern `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue `
                    -Depth 3

                foreach ($item in $items) {

                    $found += $item.FullName
                }
            }
            catch {}
        }
    }

    return $found | Select-Object -Unique
}

# --------------------------------------------------------------
# REGISTRY INDICATORS
# --------------------------------------------------------------

function Find-RegistryIndicators {

    $found = @()

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
    )

    foreach ($path in $paths) {

        if (-not (Test-Path $path)) {
            continue
        }

        try {

            $data = Get-ItemProperty $path

            if ($data.KeyManagementServiceName) {

                $found += "KMS Host: $($data.KeyManagementServiceName)"
            }

            if ($data.KeyManagementServicePort) {

                $found += "KMS Port: $($data.KeyManagementServicePort)"
            }
        }
        catch {}
    }

    return $found
}

# --------------------------------------------------------------
# KMS DNS
# --------------------------------------------------------------

function Find-KMSDNS {

    try {

        $result = Resolve-DnsName `
            "_vlmcs._tcp" `
            -Type SRV `
            -ErrorAction SilentlyContinue

        if ($result) {

            return $result | ForEach-Object {

                "$($_.NameTarget):$($_.Port)"
            }
        }
    }
    catch {}

    return @()
}

# --------------------------------------------------------------
# ACTIVATION EVENTS
# --------------------------------------------------------------

function Get-ActivationEvents {

    $events = @()

    try {

        $events = Get-WinEvent `
            -FilterHashtable @{
                LogName = "Application"
                Id      = 12288,12289,12290
            } `
            -MaxEvents 10 `
            -ErrorAction SilentlyContinue

    }
    catch {}

    return $events
}

# --------------------------------------------------------------
# WINDOWS CHECK
# --------------------------------------------------------------

function Check-Windows {

    Header

    $edition = Get-WindowsEdition
    $products = @(Get-WindowsProducts)
    $oem = Get-OEMKey

    Section "WINDOWS INFORMATION"

    Write-Host "Windows        : $($edition.Caption)"
    Write-Host "Version        : $($edition.Version)"
    Write-Host "Build          : $($edition.Build)"

    if (-not $products) {

        BAD "Khong tim thay Windows licensing product."
        Pause-Tool
        return
    }

    $product = $products |
        Sort-Object LicenseStatus -Descending |
        Select-Object -First 1

    $status = Get-LicenseStatusText $product.LicenseStatus

    $channel = Get-LicenseChannel `
        $product.Description `
        $product.Name

    Write-Host ""

    Section "ACTIVATION"

    Write-Host "Product        : $($product.Name)"
    Write-Host "Status         : " -NoNewline

    if ($product.LicenseStatus -eq 1) {

        Write-Color $status Green
    }
    else {

        Write-Color $status Red
    }

    Write-Host "License Channel: $channel"
    Write-Host "Partial Key    : XXXXX-$($product.PartialProductKey)"

    if ($product.GenuineStatus) {

        Write-Host "Genuine Status : $($product.GenuineStatus)"
    }

    Section "OEM / FIRMWARE"

    if ($oem.Found) {

        OK "OEM/UEFI product key FOUND"
        Write-Host "Firmware Key   : $($oem.Key)"
    }
    else {

        INFO "No OEM/UEFI product key detected"
    }

    Section "KMS"

    $kms = Get-KMSInformation $product

    if ($channel -match "KMS|VOLUME") {

        WARN "Volume/KMS licensing detected"

        Write-Host "KMS Host       : $($kms.Host)"
        Write-Host "KMS Port       : $($kms.Port)"
        Write-Host "Renew Interval : $($product.VLRenewalInterval) minutes"
        Write-Host "Grace Remaining: $($product.GracePeriodRemaining) minutes"
    }
    else {

        OK "Windows product is not identified as KMS client"
    }

    Section "ACTIVATION EXPIRATION"

    Write-Host (Get-WindowsExpiration)

    Section "KMS DNS DISCOVERY"

    $dns = @(Find-KMSDNS)

    if ($dns.Count -gt 0) {

        WARN "KMS DNS SRV record detected"

        foreach ($entry in $dns) {
            Write-Host "  $entry"
        }
    }
    else {

        OK "No _vlmcs._tcp DNS record detected"
    }

    Section "SUSPICIOUS SCHEDULED TASKS"

    $tasks = @(Find-SuspiciousTasks)

    if ($tasks.Count -eq 0) {

        OK "No known suspicious activation task names detected"
    }
    else {

        WARN "$($tasks.Count) suspicious task(s) detected"

        foreach ($task in $tasks) {

            Write-Host "  $($task.Path)$($task.Name)" -ForegroundColor Yellow
        }
    }

    Section "SUSPICIOUS SERVICES"

    $services = @(Find-SuspiciousServices)

    if ($services.Count -eq 0) {

        OK "No known suspicious activation service names detected"
    }
    else {

        WARN "$($services.Count) suspicious service(s) detected"

        foreach ($service in $services) {

            Write-Host "  $($service.Name) - $($service.State)" `
                -ForegroundColor Yellow
        }
    }

    Section "SUSPICIOUS FILE / FOLDER INDICATORS"

    $files = @(Find-SuspiciousFiles)

    if ($files.Count -eq 0) {

        OK "No known suspicious activation files detected"
    }
    else {

        WARN "$($files.Count) suspicious file/folder indicator(s)"

        foreach ($file in $files) {

            Write-Host "  $file" -ForegroundColor Yellow
        }
    }

    Section "REGISTRY INDICATORS"

    $registry = @(Find-RegistryIndicators)

    if ($registry.Count -eq 0) {

        OK "No KMS configuration found in checked registry locations"
    }
    else {

        foreach ($entry in $registry) {

            WARN $entry
        }
    }

    Section "ACTIVATION EVENTS"

    $events = @(Get-ActivationEvents)

    if ($events.Count -gt 0) {

        INFO "Recent activation-related events found: $($events.Count)"
        INFO "Events are evidence only and are not treated as proof of piracy."
    }
    else {

        INFO "No recent activation events found."
    }

    # ----------------------------------------------------------
    # FINAL VERDICT
    # ----------------------------------------------------------

    Section "FINAL VERDICT"

    $suspiciousScore = 0

    if ($tasks.Count -gt 0) {
        $suspiciousScore++
    }

    if ($services.Count -gt 0) {
        $suspiciousScore++
    }

    if ($files.Count -gt 0) {
        $suspiciousScore++
    }

    if ($channel -match "KMS") {

        WARN "ACTIVATED THROUGH KMS / VOLUME"

        if ($suspiciousScore -gt 0) {

            BAD "KMS activation + suspicious activation indicators detected."
            WARN "This is NOT proof of piracy, but requires manual investigation."
        }
        else {

            WARN "KMS detected, but no known suspicious local indicators found."
            INFO "KMS can be legitimate in organizational volume licensing."
        }
    }
    elseif ($product.LicenseStatus -ne 1) {

        BAD "WINDOWS IS NOT CURRENTLY LICENSED/ACTIVATED"
    }
    elseif ($channel -match "OEM" -and $oem.Found) {

        OK "OEM ACTIVATION DETECTED"

        if ($suspiciousScore -eq 0) {

            OK "No known suspicious activation indicators detected."
        }
    }
    elseif ($channel -match "RETAIL") {

        OK "RETAIL LICENSE CHANNEL DETECTED"

        if ($suspiciousScore -eq 0) {

            OK "No known suspicious activation indicators detected."
        }
    }
    else {

        WARN "ACTIVATED, BUT LICENSE ORIGIN CANNOT BE CONFIRMED FROM LOCAL DATA."

        INFO "Activation status != proof of legal purchase."
    }

    Write-Host ""
    INFO "This tool performs a read-only technical assessment."
    INFO "It cannot prove how a product key was purchased."
    Write-Host ""

    Pause-Tool
}

# --------------------------------------------------------------
# OFFICE PATHS
# --------------------------------------------------------------

function Get-OfficeOSPP {

    $paths = @(
        "$env:ProgramFiles\Microsoft Office\Office16\OSPP.VBS",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OSPP.VBS",
        "$env:ProgramFiles\Microsoft Office\root\Office16\OSPP.VBS",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OSPP.VBS"
    )

    foreach ($path in $paths) {

        if (Test-Path $path) {

            return $path
        }
    }

    return $null
}

# --------------------------------------------------------------
# OFFICE CHECK
# --------------------------------------------------------------

function Check-Office {

    Header

    Section "MICROSOFT OFFICE"

    $ospp = Get-OfficeOSPP

    if (-not $ospp) {

        BAD "OSPP.VBS not found."

        INFO "Office may be Microsoft 365 Click-to-Run or another installation type."

        Pause-Tool
        return
    }

    Write-Host "OSPP Path : $ospp"
    Write-Host ""

    $result = @(

        cscript.exe //nologo $ospp /dstatus 2>$null
    )

    if (-not $result) {

        BAD "Unable to read Office licensing information."

        Pause-Tool
        return
    }

    $products = @()

    $current = @{
        Name   = ""
        Status = ""
        Key    = ""
    }

    foreach ($line in $result) {

        if ($line -match "LICENSE NAME:\s*(.+)") {

            $current.Name = $matches[1].Trim()
        }

        if ($line -match "LICENSE STATUS:\s*(.+)") {

            $current.Status = $matches[1].Trim()
        }

        if ($line -match "Last 5 characters.*:\s*(.+)") {

            $current.Key = $matches[1].Trim()

            $products += [PSCustomObject]@{
                Name   = $current.Name
                Status = $current.Status
                Key    = $current.Key
            }

            $current = @{
                Name   = ""
                Status = ""
                Key    = ""
            }
        }
    }

    if ($products.Count -eq 0) {

        BAD "No Office product records could be parsed."
        Pause-Tool
        return
    }

    foreach ($office in $products) {

        Write-Host ""
        Write-Host "Product : $($office.Name)"

        if ($office.Status -match "LICENSED") {

            Write-Host "Status  : LICENSED" -ForegroundColor Green
        }
        elseif ($office.Status -match "UNLICENSED") {

            Write-Host "Status  : NOT LICENSED" -ForegroundColor Red
        }
        else {

            Write-Host "Status  : $($office.Status)" -ForegroundColor Yellow
        }

        if ($office.Key) {

            Write-Host "Key     : XXXXX-$($office.Key)"
        }

        if ($office.Name -match "KMS|VL|Volume") {

            WARN "Volume/KMS Office product detected."
        }
        elseif ($office.Name -match "Retail") {

            OK "Retail Office product detected."
        }
    }

    Section "OFFICE FINAL"

    $licensed = $products |
        Where-Object { $_.Status -match "LICENSED" }

    if ($licensed.Count -gt 0) {

        OK "At least one Office product is LICENSED."
    }
    else {

        BAD "No licensed Office product detected."
    }

    INFO "Office license origin cannot be proven solely from local status."

    Pause-Tool
}

# --------------------------------------------------------------
# FULL SCAN
# --------------------------------------------------------------

function Full-Scan {

    Header

    Write-Color "Running FULL READ-ONLY SCAN..." Cyan
    Write-Color ""

    Start-Sleep -Milliseconds 500

    # Windows
    Check-Windows

    # Office
    Check-Office
}

# --------------------------------------------------------------
# MAIN MENU
# --------------------------------------------------------------

while ($true) {

    Header

    Write-Color "[1] Check Windows License" Green
    Write-Color "[2] Check Microsoft Office License" Green
    Write-Color "[3] FULL FORENSIC SCAN" Cyan
    Write-Color "[0] Exit" Gray

    Write-Host ""

    $choice = Read-Host "Lua chon"

    switch ($choice) {

        "1" {
            Check-Windows
        }

        "2" {
            Check-Office
        }

        "3" {
            Full-Scan
        }

        "0" {
            Clear-Host
            Write-Color "License Checker closed." Cyan
            exit
        }

        default {

            Write-Color ""
            Write-Color "Lua chon khong hop le!" Red

            Start-Sleep -Seconds 1
        }
    }
}
