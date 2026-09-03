Set-StrictMode -Version Latest

$Repository = "asaboor-gh/uenv"
$ModuleName = "uenv"
$moduleRoots = @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($moduleRoots.Count -eq 0) {
    throw "PSModulePath is empty. Cannot determine module install location."
}

$currentDir = (Get-Location).ProviderPath
$isListedInPSModulePath = $moduleRoots -contains $currentDir

if (-not $isListedInPSModulePath) {
    Write-Error "Run this installer from a PowerShell Modules directory listed in PSModulePath."
    Write-Host "Current directory: $currentDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Choose one of these, then run the installer again:" -ForegroundColor Yellow
    $moduleRoots | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host "  Set-Location '<path-from-list-ending-in-Modules>'"
    Write-Host "  Invoke-RestMethod 'https://raw.githubusercontent.com/$Repository/main/install.ps1' | Invoke-Expression"
    return
}

$modulePath = Join-Path $currentDir $ModuleName
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null

$baseUrl = "https://raw.githubusercontent.com/$Repository/main"
$psm1Url = "$baseUrl/uenv.psm1"
$psd1Url = "$baseUrl/uenv.psd1"

Invoke-RestMethod $psm1Url | Out-File (Join-Path $modulePath "uenv.psm1") -Encoding utf8
Invoke-RestMethod $psd1Url | Out-File (Join-Path $modulePath "uenv.psd1") -Encoding utf8

Import-Module $modulePath -Force

Write-Host "Installed uenv to $modulePath" -ForegroundColor Green
Write-Host "Run 'uenv help' to verify the command is available." -ForegroundColor Green
