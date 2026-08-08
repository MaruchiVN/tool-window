# ============================================================
#              WINDOWS & OFFICE LICENSE CHECKER
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

function Header {
    Clear-Host

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "          WINDOWS & OFFICE LICENSE CHECKER" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Menu {
    Write-Host ""
    Read-Host "Nhan Enter de quay lai"
}

# ============================================================
# WINDOWS
# ============================================================

function Check-Windows {

    Header

    Write-Host "[ WINDOWS LICENSE ]" -ForegroundColor Yellow
    Write-Host ""

    $windows = Get-CimInstance SoftwareLicensingProduct |
        Where-Object {
            $_.ApplicationID -eq "55c92734-d682-4d71-983e-d6ec3f16059f" -and
            $_.PartialProductKey
        }

    if (-not $windows) {
        Write-Host "Khong tim thay thong tin license Windows." -ForegroundColor Red
        Pause-Menu
        return
    }

    foreach ($item in $windows) {

        Write-Host "Windows : $($item.Name)"
        Write-Host "Key     : XXXXX-$($item.PartialProductKey)"

        switch ($item.LicenseStatus) {

            1 {
                Write-Host "Status  : ACTIVATED" -ForegroundColor Green
            }

            0 {
                Write-Host "Status  : NOT ACTIVATED" -ForegroundColor Red
            }

            2 {
                Write-Host "Status  : OOB GRACE" -ForegroundColor Yellow
            }

            3 {
                Write-Host "Status  : OOT GRACE" -ForegroundColor Yellow
            }

            4 {
                Write-Host "Status  : NON-GENUINE GRACE" -ForegroundColor Red
            }

            5 {
                Write-Host "Status  : NOTIFICATION" -ForegroundColor Yellow
            }

            6 {
                Write-Host "Status  : EXTENDED GRACE" -ForegroundColor Yellow
            }

            default {
                Write-Host "Status  : UNKNOWN" -ForegroundColor Red
            }
        }

        Write-Host ""
    }

    # Thêm thông tin slmgr /xpr
    Write-Host "Activation expiration:" -ForegroundColor Yellow
    cscript.exe //nologo "$env:windir\System32\slmgr.vbs" /xpr

    Pause-Menu
}

# ============================================================
# OFFICE
# ============================================================

function Find-Office {

    $possiblePaths = @(
        "$env:ProgramFiles\Microsoft Office\Office16",
        "$env:ProgramFiles\Microsoft Office\root\Office16",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16"
    )

    foreach ($path in $possiblePaths) {

        $ospp = Join-Path $path "OSPP.VBS"

        if (Test-Path $ospp) {
            return $ospp
        }
    }

    return $null
}

function Check-Office {

    Header

    Write-Host "[ MICROSOFT OFFICE LICENSE ]" -ForegroundColor Yellow
    Write-Host ""

    $ospp = Find-Office

    if (-not $ospp) {

        Write-Host "Khong tim thay Microsoft Office." -ForegroundColor Red
        Write-Host ""
        Write-Host "Tool hien tai ho tro Office co OSPP.VBS." -ForegroundColor DarkGray

        Pause-Menu
        return
    }

    Write-Host "Office found:" -ForegroundColor Cyan
    Write-Host $ospp
    Write-Host ""

    $result = cscript.exe //nologo $ospp /dstatus 2>$null

    $products = @()

    $licenseName = ""
    $licenseStatus = ""
    $lastFive = ""

    foreach ($line in $result) {

        if ($line -match "LICENSE NAME:\s*(.+)") {
            $licenseName = $matches[1].Trim()
        }

        if ($line -match "LICENSE STATUS:\s*(.+)") {
            $licenseStatus = $matches[1].Trim()
        }

        if ($line -match "Last 5 characters.*:\s*(.+)") {
            $lastFive = $matches[1].Trim()
        }

        if ($line -match "LICENSE STATUS") {

            Write-Host "Product : $licenseName"

            if ($licenseStatus -match "LICENSED") {
                Write-Host "Status  : ACTIVATED" -ForegroundColor Green
            }
            elseif ($licenseStatus -match "UNLICENSED") {
                Write-Host "Status  : NOT ACTIVATED" -ForegroundColor Red
            }
            else {
                Write-Host "Status  : $licenseStatus" -ForegroundColor Yellow
            }

            if ($lastFive) {
                Write-Host "Key     : XXXXX-$lastFive"
            }

            Write-Host ""
        }
    }

    Pause-Menu
}

# ============================================================
# BOTH
# ============================================================

function Check-Both {

    Header

    Write-Host "[ WINDOWS ]" -ForegroundColor Cyan
    Write-Host ""

    $windows = Get-CimInstance SoftwareLicensingProduct |
        Where-Object {
            $_.ApplicationID -eq "55c92734-d682-4d71-983e-d6ec3f16059f" -and
            $_.PartialProductKey
        }

    foreach ($item in $windows) {

        Write-Host "Windows : $($item.Name)"

        if ($item.LicenseStatus -eq 1) {
            Write-Host "Status  : ACTIVATED" -ForegroundColor Green
        }
        else {
            Write-Host "Status  : NOT ACTIVATED" -ForegroundColor Red
        }

        Write-Host ""
    }

    Write-Host "--------------------------------------------------"
    Write-Host ""

    Write-Host "[ OFFICE ]" -ForegroundColor Cyan
    Write-Host ""

    $ospp = Find-Office

    if (-not $ospp) {

        Write-Host "Office : NOT FOUND" -ForegroundColor Red

    }
    else {

        $result = cscript.exe //nologo $ospp /dstatus 2>$null

        $found = $false

        foreach ($line in $result) {

            if ($line -match "LICENSE STATUS:\s*(.+)") {

                $found = $true
                $status = $matches[1].Trim()

                if ($status -match "LICENSED") {
                    Write-Host "Office  : ACTIVATED" -ForegroundColor Green
                }
                else {
                    Write-Host "Office  : NOT ACTIVATED" -ForegroundColor Red
                }
            }
        }

        if (-not $found) {
            Write-Host "Office : Khong lay duoc trang thai" -ForegroundColor Yellow
        }
    }

    Pause-Menu
}

# ============================================================
# MENU
# ============================================================

while ($true) {

    Header

    Write-Host "[1] Check Windows License" -ForegroundColor Green
    Write-Host "[2] Check Office License" -ForegroundColor Green
    Write-Host "[3] Check Windows + Office" -ForegroundColor Green
    Write-Host "[0] Exit" -ForegroundColor Gray

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
            Check-Both
        }

        "0" {
            Clear-Host
            exit
        }

        default {
            Write-Host ""
            Write-Host "Lua chon khong hop le!" -ForegroundColor Red
            Start-Sleep 1
        }
    }
}
