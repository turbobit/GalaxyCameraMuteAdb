param(
    [switch]$SkipPublish
)

$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        $joined = if ($Arguments.Count -gt 0) { " " + ($Arguments -join " ") } else { "" }
        throw "Command failed: $FilePath$joined"
    }
}

function Get-CommandOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    $output = & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        $joined = if ($Arguments.Count -gt 0) { " " + ($Arguments -join " ") } else { "" }
        throw "Command failed: $FilePath$joined"
    }

    return @($output)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$version = (Get-Content -Raw -Path (Join-Path $scriptDir "VERSION")).Trim()
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "VERSION file is empty."
}

$tag = "v$version"
$title = "GalaxyCameraMuteAdb $tag"
$releaseDir = Join-Path $scriptDir "release"
$assetName = "GalaxyCameraMuteAdb_v$version.exe"
$assetPath = Join-Path $releaseDir $assetName
$notesPath = Join-Path $releaseDir "release-notes-$version.md"

Write-Host "Version: $version"
Write-Host "Tag: $tag"

Invoke-Checked -FilePath "cmd.exe" -Arguments @("/c", "build.cmd")

if (-not (Test-Path -LiteralPath $assetPath)) {
    throw "Build output not found: $assetPath"
}

$allTags = Get-CommandOutput -FilePath "git" -Arguments @("tag", "--list", "v*", "--sort=-version:refname")
$tagExists = $allTags -contains $tag
$previousTag = ($allTags | Where-Object { $_ -and $_ -ne $tag } | Select-Object -First 1)

$notes = New-Object System.Collections.Generic.List[string]
$notes.Add("# $title")
$notes.Add("")

if ($previousTag) {
    $notes.Add("Compare: $previousTag..$tag")
    $notes.Add("")
    $commitLines = Get-CommandOutput -FilePath "git" -Arguments @("log", "$previousTag..HEAD", "--pretty=format:- %h %s")
} else {
    $notes.Add("Initial release")
    $notes.Add("")
    $commitLines = Get-CommandOutput -FilePath "git" -Arguments @("log", "--reverse", "--pretty=format:- %h %s")
}

if ($commitLines.Count -eq 0) {
    $commitLines = @("- No commit changes detected.")
}

$notes.Add("Changes")
$notes.Add("")
foreach ($line in $commitLines) {
    $notes.Add($line)
}

$notes.Add("")
$notes.Add("Asset")
$notes.Add("")
$notes.Add("- $assetName")

Set-Content -Path $notesPath -Value ($notes -join "`r`n") -Encoding ascii

if ($previousTag) {
    Write-Host "Previous tag: $previousTag"
} else {
    Write-Host "Previous tag: (none)"
}
Write-Host "Notes file: $notesPath"
Write-Host "Asset file: $assetPath"

if ($SkipPublish) {
    Write-Host "SkipPublish enabled. Remote tag/release upload skipped."
    exit 0
}

Invoke-Checked -FilePath "gh" -Arguments @("auth", "status")

if ($tagExists) {
    Write-Host "Existing tag found. Updating tag to current HEAD."
    Invoke-Checked -FilePath "git" -Arguments @("tag", "-f", $tag, "HEAD")
} else {
    Write-Host "Creating new tag."
    Invoke-Checked -FilePath "git" -Arguments @("tag", $tag, "HEAD")
}

Invoke-Checked -FilePath "git" -Arguments @("push", "origin", "refs/tags/$tag", "--force")

& gh release view $tag *> $null
$releaseExists = $LASTEXITCODE -eq 0

if ($releaseExists) {
    Write-Host "Existing GitHub release found. Updating release."
    Invoke-Checked -FilePath "gh" -Arguments @("release", "edit", $tag, "--title", $title, "--notes-file", $notesPath)
    Invoke-Checked -FilePath "gh" -Arguments @("release", "upload", $tag, $assetPath, "--clobber")
} else {
    Write-Host "Creating GitHub release."
    Invoke-Checked -FilePath "gh" -Arguments @("release", "create", $tag, $assetPath, "--title", $title, "--notes-file", $notesPath)
}

Write-Host "Release completed: $tag"
