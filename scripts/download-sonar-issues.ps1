# scripts/download-sonar-issues.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SonarUrl,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "sonarqube-issues.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet("basic", "bearer")]
    [string]$AuthMode = "bearer",

    [Parameter(Mandatory = $false)]
    [string]$SessionId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TempPath = $null

function Get-PersistentSonarToken {
    foreach ($Target in @([System.EnvironmentVariableTarget]::User, [System.EnvironmentVariableTarget]::Machine)) {
        $Value = [System.Environment]::GetEnvironmentVariable("SONAR_TOKEN", $Target)
        if (-not [string]::IsNullOrWhiteSpace($Value)) {
            return $Value
        }
    }

    return $null
}

function New-DefaultSessionId {
    $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $ProcessId = [System.Diagnostics.Process]::GetCurrentProcess().Id
    return "$Timestamp-$ProcessId"
}

function Assert-SimpleName {
    param(
        [string]$Value,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Label must not be empty."
    }

    $InvalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    if ($Value.IndexOfAny($InvalidChars) -ge 0 -or $Value.Contains("..") -or $Value.Contains("/") -or $Value.Contains("\")) {
        throw "$Label must be a simple name without path separators."
    }
}

function Assert-SonarUrl {
    param([string]$Url)

    try {
        $Uri = [System.Uri]$Url
    } catch {
        throw "SonarQube URL must be an absolute HTTP or HTTPS URL."
    }

    if (-not $Uri.IsAbsoluteUri -or @("http", "https") -notcontains $Uri.Scheme) {
        throw "SonarQube URL must be an absolute HTTP or HTTPS URL."
    }

    if (-not [string]::IsNullOrEmpty($Uri.UserInfo)) {
        throw "SonarQube URL must not contain embedded credentials."
    }

    if ($Uri.Query -match "(?i)(^|[?&])(token|access_token|authorization|auth|password|passwd|secret)=") {
        throw "SonarQube URL appears to contain a secret. Remove secrets from the URL before running this helper."
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
        throw 'Missing SonarQube URL. Provide -SonarUrl with the SonarQube issues API URL. SONAR_URL and $env:SONAR_URL are intentionally ignored.'
    }

    Assert-SonarUrl -Url $SonarUrl

    $SonarToken = Get-PersistentSonarToken
    if ([string]::IsNullOrWhiteSpace($SonarToken)) {
        throw 'Missing persistent SONAR_TOKEN. Set SONAR_TOKEN in the User or Machine environment with [System.Environment]::SetEnvironmentVariable before running this helper. Do not use $env:SONAR_TOKEN, command arguments, prompts, or chat.'
    }

    Assert-SimpleName -Value $OutputFile -Label "Output filename"

    if ([string]::IsNullOrWhiteSpace($SessionId)) {
        $SessionId = New-DefaultSessionId
    }

    Assert-SimpleName -Value $SessionId -Label "Session id"

    $ArtifactRoot = Join-Path -Path $ProjectRoot -ChildPath ".sonarqube-diff-review"
    $SessionDir = Join-Path -Path $ArtifactRoot -ChildPath $SessionId
    New-Item -ItemType Directory -Force -Path $SessionDir | Out-Null

    $OutputPath = Join-Path -Path $SessionDir -ChildPath $OutputFile
    $TempPath = Join-Path -Path $SessionDir -ChildPath "$OutputFile.tmp"

    if ($AuthMode -eq "bearer") {
        $Headers = @{ Authorization = "Bearer $SonarToken" }
    } else {
        $BasicToken = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(("{0}:" -f $SonarToken)))
        $Headers = @{ Authorization = "Basic $BasicToken" }
    }

    Write-Host "Downloading SonarQube issues..."
    Write-Host "Artifact session: $SessionId"
    Write-Host "Output file: $OutputPath"

    Invoke-WebRequest -Uri $SonarUrl -Headers $Headers -OutFile $TempPath -UseBasicParsing

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
}
