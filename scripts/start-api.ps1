$ErrorActionPreference = "Stop"

$serverPath = Join-Path $PSScriptRoot "..\server"
Set-Location $serverPath

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created server/.env from .env.example"
}

if (-not (Test-Path "node_modules")) {
    Write-Host "Installing API dependencies..."
    npm install
}

Write-Host "Starting Daisenko Hero Service API on http://localhost:3000"
npm run dev
