# ============================================================
#              WINDOWS & OFFICE LICENSE CHECKER
#                    Maruchi Edition
# ============================================================

$Host.UI.RawUI.WindowTitle = "Windows & Office License Checker"

function Write-Line {
    param([string]$Text = "", [ConsoleColor]$Color = [ConsoleColor]::White)
    Write-Host $Text -ForegroundColor $Color
}

function Show-Header {
    Clear-Host
    Write-Line ""
    Write-Line "==================================================" Cyan
    Write-Line "          WINDOWS & OFFICE LICENSE CHECKER        " Cyan
    Write-Line "==================================================" Cyan
    Write-Line ""
}

function Get-WindowsLicense {

    Show-Header

    Write-Line "[ Windows License ]" Yellow
    Write-Line ""

    $products = Get-CimInstance SoftwareLicensingProduct |
        Where-Object {
            $_.ApplicationID -eq "55c92734-d682-4d71-983e-d6ec3f16059f" -and
            $_.PartialProductKey
        }

    if (-not $products) {
        Write-Line "Khong tim thay thong tin license Windows." Red
        return
    }

    foreach ($product in $products) {

        Write-Line "Product : $($product.Name)"

        switch ($product.LicenseStatus) {

            0 {
                Write-Line "Status  : NOT LICENSED" Red
            }

            1 {
                Write-Line "Status  : LICENSED" Green
            }

            2 {
                Write-Line "Status  : OOB GRACE" Yellow
            }

            3 {
                Write-Line "Status  : OOT GRACE" Yellow
            }

            4 {
                Write-Line "Status  : NON-GENUINE GRACE" Red
            }

            5 {
                Write-Line "Status  : NOTIFICATION" Yellow
            }

            6 {
                Write-Line "Status  : EXTENDED GRACE" Yellow
            }

            default {
                Write-Line "Status  : UNKNOWN ($($product.LicenseStatus))" Red
            }
        }

        Write-Line "Key     : XXXXX-$($product.PartialProductKey)"
        Write-Line ""
    }
}

function Get-OfficePaths {

    $paths = @()

    $paths += "$env:ProgramFiles\Microsoft Office\Office16"
    $paths += "${env:ProgramFiles(x86)}\Microsoft Office\Office16"

    $paths += "$env:ProgramFiles\Microsoft Office\root\Office16"
    $paths += "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16"

    return $paths | Where-Object {
        $_ -and (Test-Path "$_\OSPP.VBS")
    }
}

function Get-OfficeLicense {

    Show-Header

    Write-Line "[ Microsoft Office License ]" Yellow
    Write-Line ""

    $officePaths = Get-OfficePaths

    if (-not $officePaths) {
        Write-Line "Khong tim thay OSPP.VBS cua Microsoft Office." Red
        Write-Line ""
        Write-Line "Co the Office khong duoc cai dat theo kieu Volume/MSI." DarkGray
        return
    }

    foreach ($path in $officePaths) {

        $ospp = Join-Path $path "OSPP.VBS"

        Write-Line "Checking: $path" Cyan
        Write-Line ""

        $result = & cscript.exe //nologo $ospp /dstatus 2>$null

        if (-not $result) {
            Write-Line "Khong lay duoc thong tin license." Red
            continue
        }

        $licenseLines = $result | Where-Object {
            $_ -match "LICENSE STATUS|LICENSED|UNLICENSED|Last 5 characters|LICENSE NAME"
        }

        foreach ($line in $licenseLines) {

            if ($line -match "LICENSE STATUS:\s*(.*)") {

                $status = $matches[1].Trim()

                if ($status -match "LICENSED") {
                    Write-Line "Status  : LICENSED" Green
                }
                elseif ($status -match "UNLICENSED") {
                    Write-Line "Status  : NOT LICENSED" Red
                }
                else {
                    Write-Line "Status  : $status" Yellow
                }

                continue
            }

            if ($line -match "LICENSE NAME:\s*(.*)") {
                Write-Line "Product : $($matches[1].Trim())"
                continue
            }

            if ($line -match "Last 5 characters.*:\s*(.*)") {
                Write-Line "Key     : XXXXX-$($matches[1].Trim())"
                continue
            }
        }

        Write-Line ""
    }
}

function Show-Menu {

    while ($true) {

        Show-Header

        Write-Line "[1] Check Windows License" Green
        Write-Line "[2] Check Microsoft Office License" Green
        Write-Line "[3] Check Both" Green
        Write-Line "[0] Exit" Gray

        Write-Line ""
        $choice = Read-Host "Lua chon"

        switch ($choice) {

            "1" {
                Get-WindowsLicense
                Write-Line ""
                Read-Host "Nhan Enter de quay lai menu"
            }

            "2" {
                Get-OfficeLicense
                Write-Line ""
                Read-Host "Nhan Enter de quay lai menu"
            }

            "3" {
                Get-WindowsLicense

                Write-Line ""
                Write-Line "--------------------------------------------------" DarkGray
                Write-Line ""

                Get-OfficeLicense

                Write-Line ""
                Read-Host "Nhan Enter de quay lai menu"
            }

            "0" {
                Clear-Host
                Write-Line "Cam on ban da su dung License Checker!" Cyan
                exit
            }

            default {
                Write-Line ""
                Write-Line "Lua chon khong hop le!" Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ============================================================
# START
# ============================================================

Show-Menu
