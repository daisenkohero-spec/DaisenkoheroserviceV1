# Build the web app and deploy it (with security rules) to Firebase Hosting.
#
# Usage (from the project folder, in PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy-web.ps1
# (-ExecutionPolicy Bypass is needed on machines that block .ps1 scripts.)
#
# Stops before deploying if `flutter analyze` reports any error.
# Each build gets a BUILD_ID that is baked into the app and written to
# build/web/build_id.txt; open apps compare the two and show
# "มีเวอร์ชันใหม่ แตะเพื่อโหลด" after a deploy.

# Native tools write progress to stderr; check exit codes instead of stopping.
$ErrorActionPreference = "Continue"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Checking for errors..."
$errors = flutter analyze 2>&1 | Select-String " error - "
if ($errors) {
  $errors
  Write-Host "STOP: found errors, nothing was deployed." -ForegroundColor Red
  exit 1
}
Write-Host "NO ERRORS" -ForegroundColor Green

$buildId = Get-Date -Format "yyyyMMddHHmmss"
flutter build web --release --dart-define=BUILD_ID=$buildId
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }
Set-Content -Path "build\web\build_id.txt" -Value $buildId -NoNewline -Encoding ascii

$firebase = ".\rules-tests\node_modules\.bin\firebase.cmd"
if (-not (Test-Path $firebase)) {
  Write-Host "Installing Firebase CLI (one time)..."
  Push-Location rules-tests; npm.cmd install; Pop-Location
}
& $firebase deploy --only "firestore:rules,hosting" --project daisenkoheroservicev1
if ($LASTEXITCODE -ne 0) { throw "firebase deploy failed" }

Write-Host "Deployed build $buildId" -ForegroundColor Green
