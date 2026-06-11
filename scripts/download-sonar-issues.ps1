# scripts/download-sonar-issues.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SonarUrl = $env:SONAR_URL,

    [Parameter(Mandatory = $false)]
    [string]$SonarToken = $env:SONAR_TOKEN,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "sonarqube-issues.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet("basic", "bearer")]
    [string]$AuthMode = "basic"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TempPath = $null
$CurlConfigPath = $null

function Assert-OutputFileName {
    param([string]$FileName)

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        throw "Output filename must not be empty."
    }

    $InvalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    if ($FileName.IndexOfAny($InvalidChars) -ge 0 -or $FileName.Contains("..") -or $FileName.Contains("/") -or $FileName.Contains("\")) {
        throw "Output filename must be a simple file name inside the Git project root."
    }
}

try {
    Write-Host "Checking Git project root..."

    $ProjectRoot = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ProjectRoot)) {
        throw "Current directory is not inside a Git repository."
    }

    $ProjectRoot = $ProjectRoot.Trim()
    Set-Location -LiteralPath $ProjectRoot

    if ([string]::IsNullOrWhiteSpace($SonarUrl)) {
        throw "Missing SonarQube URL. Provide -SonarUrl or set SONAR_URL."
    }

    if ([string]::IsNullOrWhiteSpace($SonarToken)) {
        throw "Missing SonarQube token. Provide -SonarToken or set SONAR_TOKEN."
    }

    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        throw "curl.exe is required to download SonarQube issues."
    }

    Assert-OutputFileName -FileName $OutputFile

    $OutputPath = Join-Path -Path $ProjectRoot -ChildPath $OutputFile
    $TempPath = "$OutputPath.tmp"
    $CurlConfigPath = [System.IO.Path]::GetTempFileName()

    if ($AuthMode -eq "bearer") {
        Set-Content -LiteralPath $CurlConfigPath -Value "header = `"Authorization: Bearer $SonarToken`"" -Encoding ASCII -NoNewline
    } else {
        Set-Content -LiteralPath $CurlConfigPath -Value "user = `"$SonarToken`:`"" -Encoding ASCII -NoNewline
    }

    Write-Host "Downloading SonarQube issues..."
    Write-Host "Output file: $OutputPath"

    & curl.exe --fail --silent --show-error --location --config $CurlConfigPath --output $TempPath $SonarUrl
    if ($LASTEXITCODE -ne 0) {
        throw "Download failed. curl exited with code $LASTEXITCODE."
    }

    if (-not (Test-Path -LiteralPath $TempPath)) {
        throw "Download failed. No output file was created."
    }

    if ((Get-Item -LiteralPath $TempPath).Length -eq 0) {
        throw "Download failed. Output file is empty."
    }

    $Json = Get-Content -LiteralPath $TempPath -Raw | ConvertFrom-Json
    if (-not ($Json.PSObject.Properties.Name -contains "issues")) {
        throw "Downloaded JSON is not a SonarQube issues response because it has no 'issues' property."
    }

    Move-Item -LiteralPath $TempPath -Destination $OutputPath -Force
    $TempPath = $null

    Write-Host "SonarQube issue report downloaded successfully."
    Write-Host "Saved to: $OutputPath"
} catch {
    if ($TempPath -and (Test-Path -LiteralPath $TempPath)) {
        Remove-Item -LiteralPath $TempPath -Force -ErrorAction SilentlyContinue
    }

    Write-Error $_.Exception.Message
    exit 1
} finally {
    if ($CurlConfigPath -and (Test-Path -LiteralPath $CurlConfigPath)) {
        Remove-Item -LiteralPath $CurlConfigPath -Force -ErrorAction SilentlyContinue
    }
}
