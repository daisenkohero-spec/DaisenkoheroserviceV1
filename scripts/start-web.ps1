$ErrorActionPreference = "Stop"

$projectPath = Join-Path $PSScriptRoot ".."
Set-Location $projectPath

Write-Host "Installing Flutter dependencies..."
flutter pub get

Write-Host "Starting Daisenko Hero Service web app on http://localhost:8080"
flutter run -d web-server --web-hostname localhost --web-port 8080
