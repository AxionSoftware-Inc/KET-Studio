param(
    [string]$Configuration = "release",
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
$scriptPath = Join-Path $repoRoot "installer\ket_studio.iss"
$distDir = Join-Path $repoRoot "dist\windows-installer"

function Add-GitToPath {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        return
    }

    $candidate = "C:\Program Files\Git\cmd"
    if (Test-Path $candidate) {
        $env:Path = "$candidate;$env:Path"
    }
}

function Get-PubspecVersion {
    $pubspecPath = Join-Path $repoRoot "pubspec.yaml"
    $versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
    if (-not $versionLine) {
        throw "pubspec.yaml ichidan version topilmadi."
    }

    return $versionLine.Matches[0].Groups[1].Value
}

function Get-InnoCompiler {
    $candidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    throw "Inno Setup compiler topilmadi. Inno Setup 6 ni o'rnating: https://jrsoftware.org/isinfo.php"
}

if ($Configuration -ne "release") {
    throw "Faqat release konfiguratsiya qo'llab-quvvatlanadi."
}

Add-GitToPath

if (-not $SkipFlutterBuild) {
    Push-Location $repoRoot
    try {
        flutter build windows --release
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $releaseDir)) {
    throw "Release build papkasi topilmadi: $releaseDir"
}

if (-not (Test-Path (Join-Path $releaseDir "ket_studio.exe"))) {
    throw "Release build ichida ket_studio.exe topilmadi."
}

if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
}

$appVersion = Get-PubspecVersion
$compiler = Get-InnoCompiler

& $compiler `
    "/DMyAppVersion=$appVersion" `
    "/DSourceDir=$releaseDir" `
    "/DOutputDir=$distDir" `
    $scriptPath

Write-Host ""
Write-Host "Installer tayyor:"
Get-ChildItem $distDir -Filter "*.exe" | Select-Object FullName, Length, LastWriteTime
