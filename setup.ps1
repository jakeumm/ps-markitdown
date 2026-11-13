<#
.SYNOPSIS
Installs the ps-markitdown module and its Python virtual environment.

.DESCRIPTION
If this script is not already in a folder listed in $env:PSModulePath, it copies the module files
to the PowerShell 7 user modules folder (<Documents>\PowerShell\Modules\ps-markitdown).
It then creates a .venv in the install folder (or reuses an existing one), installs
'markitdown[all]' into it, and shows how to get started.

Running the script again overwrites copied files, reuses the virtual environment, and reruns pip install.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$moduleName = 'ps-markitdown'
$moduleFiles = 'markitdown.psm1', 'ps-markitdown.psd1', 'readme.md', 'setup.ps1'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning 'ps-markitdown requires PowerShell 7 or later. Install it from https://aka.ms/powershell'
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw 'Python was not found on PATH. Install Python 3 and run this script again.'
}

function ConvertTo-NormalizedPath([string]$Path) {
    [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

# Use an existing module directory when its parent is listed in PSModulePath.
$parentDir = ConvertTo-NormalizedPath (Split-Path -Parent $PSScriptRoot)
$moduleRoots = $env:PSModulePath -split [IO.Path]::PathSeparator |
    Where-Object { $_ } |
    ForEach-Object { ConvertTo-NormalizedPath $_ }
$inModulesFolder = $moduleRoots -contains $parentDir

if ($inModulesFolder) {
    $installDir = $PSScriptRoot
}
else {
    $userModules = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
    $installDir = Join-Path $userModules $moduleName
}

if ((ConvertTo-NormalizedPath $installDir) -eq (ConvertTo-NormalizedPath $PSScriptRoot)) {
    Write-Host "Using module folder: $installDir"
}
else {
    if (-not (Test-Path -LiteralPath $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    Write-Host "Copying module files to $installDir"
    foreach ($file in $moduleFiles) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $installDir -Force
    }
}

Push-Location -LiteralPath $installDir
try {
    if (Test-Path -LiteralPath '.venv\Scripts\python.exe') {
        Write-Host 'Using existing virtual environment: .venv'
    }
    else {
        Write-Host 'Creating virtual environment: .venv'
        python -m venv .venv
        if ($LASTEXITCODE -ne 0) { throw "python -m venv failed (exit code $LASTEXITCODE)." }
    }

    .\.venv\Scripts\Activate.ps1
    try {
        Write-Host "Installing markitdown[all]"
        pip install 'markitdown[all]'
        if ($LASTEXITCODE -ne 0) { throw "pip install failed (exit code $LASTEXITCODE)." }
    }
    finally {
        if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
    }
}
finally {
    Pop-Location
}

$installParent = ConvertTo-NormalizedPath (Split-Path -Parent $installDir)
$importCommand = if (($moduleRoots -contains $installParent) -and
    (Split-Path -Leaf $installDir) -eq $moduleName) {
    "Import-Module $moduleName"
}
else {
    $manifestPath = (Join-Path $installDir 'ps-markitdown.psd1').Replace("'", "''")
    "Import-Module '$manifestPath'"
}

Write-Host ''
Write-Host 'Setup complete. To get started, run:' -ForegroundColor Green
Write-Host ''
Write-Host "    $importCommand" -ForegroundColor Cyan
Write-Host '    Get-Help Convert-Markdown -Examples' -ForegroundColor Cyan
Write-Host ''
