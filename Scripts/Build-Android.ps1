param(
    [string]$EngineRoot = "C:\\Program Files\\Epic Games\\UE_5.8",
    [ValidateSet("Development", "Shipping")]
    [string]$Configuration = "Development"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $ProjectRoot "HippoOS.uproject"
$RunUAT = Join-Path $EngineRoot "Engine\\Build\\BatchFiles\\RunUAT.bat"
$Archive = Join-Path $ProjectRoot "Artifacts\\Android"

if (!(Test-Path $Project)) { throw "HippoOS.uproject not found at $Project" }
if (!(Test-Path $RunUAT)) { throw "RunUAT.bat not found. Pass -EngineRoot pointing to Unreal Engine 5.8." }

New-Item -ItemType Directory -Force -Path $Archive | Out-Null

& $RunUAT BuildCookRun `
    -project="$Project" `
    -noP4 `
    -platform=Android `
    -clientconfig=$Configuration `
    -build `
    -cook `
    -pak `
    -stage `
    -package `
    -archive `
    -archivedirectory="$Archive" `
    -cookflavor=ASTC `
    -utf8output

if ($LASTEXITCODE -ne 0) { throw "Android packaging failed with exit code $LASTEXITCODE" }

$Apks = Get-ChildItem -Path $Archive -Filter *.apk -Recurse
if (!$Apks) { throw "Packaging completed but no APK was found under $Archive" }

Write-Host "APK READY:" -ForegroundColor Green
$Apks | ForEach-Object { Write-Host $_.FullName }
