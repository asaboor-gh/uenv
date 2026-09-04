Set-StrictMode -Version Latest

$Repository = "asaboor-gh/uenv"
$ModuleName = "uenv"

function Test-IsWindows {
    $isWindowsVar = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
    if ($null -ne $isWindowsVar) {
        return [bool]$isWindowsVar.Value
    }

    return $env:OS -eq "Windows_NT"
}

function Test-PathWritable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
        }

        $probeFile = Join-Path $Path (".uenv-write-test-{0}" -f [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType File -Path $probeFile -Force -ErrorAction Stop | Out-Null
        Remove-Item -Path $probeFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}

function Get-ModuleRoots {
    return @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-UenvModuleInstallRoot {
    $moduleRoots = Get-ModuleRoots
    if ($moduleRoots.Count -eq 0) {
        throw "PSModulePath is empty. Cannot determine module install location."
    }

    $candidates = New-Object System.Collections.Generic.List[string]

    if (Test-IsWindows) {
        $documentsDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        if ([string]::IsNullOrWhiteSpace($documentsDir)) {
            throw "Unable to resolve the Documents folder for the current user."
        }

        $modulesSubDir = if ($PSVersionTable.PSVersion.Major -ge 6) {
            Join-Path "PowerShell" "Modules"
        }
        else {
            Join-Path "WindowsPowerShell" "Modules"
        }

        $preferredUserRoot = Join-Path $documentsDir $modulesSubDir
        $candidates.Add($preferredUserRoot)
    }

    foreach ($root in $moduleRoots) {
        if (-not $candidates.Contains($root)) {
            $candidates.Add($root)
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-PathWritable -Path $candidate) {
            return $candidate
        }
    }

    throw "No writable module path found. Checked: $($candidates -join ', ')"
}

$installRoot = Get-UenvModuleInstallRoot
$modulePath = Join-Path $installRoot $ModuleName
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null

$baseUrl = "https://raw.githubusercontent.com/$Repository/main"
$psm1Url = "$baseUrl/uenv.psm1"
$psd1Url = "$baseUrl/uenv.psd1"

Invoke-RestMethod $psm1Url | Out-File (Join-Path $modulePath "uenv.psm1") -Encoding utf8
Invoke-RestMethod $psd1Url | Out-File (Join-Path $modulePath "uenv.psd1") -Encoding utf8

Import-Module (Join-Path $modulePath "uenv.psd1") -Force

Write-Host "Installed uenv to $modulePath" -ForegroundColor Green
Write-Host "Run 'uenv help' to verify the command is available." -ForegroundColor Green
