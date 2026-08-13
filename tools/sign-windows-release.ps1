[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9A-Fa-f]{40}$')]
    [string]$CertificateThumbprint,

    [string]$TimestampUrl = 'http://timestamp.digicert.com',

    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $projectRoot 'build\windows\x64\runner\Release'

$signToolCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\App Certification Kit\signtool.exe')
)
$signTool = $signToolCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $signTool) {
    throw 'signtool.exe was not found. Install the Windows SDK before signing a release.'
}

$thumbprint = $CertificateThumbprint.Replace(' ', '').ToUpperInvariant()
$certificate = Get-ChildItem -Path "Cert:\CurrentUser\My\$thumbprint" -ErrorAction SilentlyContinue
if (-not $certificate) {
    throw "The signing certificate $thumbprint was not found in the current user's certificate store."
}
if (-not $certificate.HasPrivateKey) {
    throw 'The selected certificate does not have an accessible private key.'
}

if (-not $SkipBuild) {
    Push-Location $projectRoot
    try {
        flutter build windows --release
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $releaseRoot)) {
    throw "Release output was not found: $releaseRoot"
}

$files = Get-ChildItem -LiteralPath $releaseRoot -File |
    Where-Object { $_.Extension -in '.exe', '.dll' } |
    Sort-Object Name

if (-not $files) {
    throw "No executable or DLL files were found in $releaseRoot"
}

foreach ($file in $files) {
    & $signTool sign /sha1 $thumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 $file.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Signing failed for $($file.Name)."
    }
}

foreach ($file in $files) {
    & $signTool verify /pa /all /q $file.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Signature verification failed for $($file.Name)."
    }
}

Write-Host "Signed and verified $($files.Count) files in $releaseRoot"
