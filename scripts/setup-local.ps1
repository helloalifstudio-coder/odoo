$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepositoryRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker was not found. Install Docker Desktop and enable its WSL 2 backend."
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker is installed but its engine is not running. Start Docker Desktop and retry."
}

if (-not (Test-Path ".env")) {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $dbAdminBytes = New-Object byte[] 32
        $appBytes = New-Object byte[] 32
        $masterBytes = New-Object byte[] 32
        $rng.GetBytes($dbAdminBytes)
        $rng.GetBytes($appBytes)
        $rng.GetBytes($masterBytes)
    }
    finally {
        $rng.Dispose()
    }

    $dbAdminPassword = [BitConverter]::ToString($dbAdminBytes).Replace("-", "").ToLowerInvariant()
    $appPassword = [BitConverter]::ToString($appBytes).Replace("-", "").ToLowerInvariant()
    $masterPassword = [BitConverter]::ToString($masterBytes).Replace("-", "").ToLowerInvariant()

    @"
POSTGRES_PASSWORD=$dbAdminPassword
ODOO_DB_USER=odoo
ODOO_DB_PASSWORD=$appPassword
ODOO_MASTER_PASSWORD=$masterPassword
ODOO_PORT=8069
ODOO_GEVENT_PORT=8072
ODOO_LOG_LEVEL=info
"@ | Set-Content -Path ".env" -Encoding ascii

    Write-Host "Generated three independent local secrets in .env. Keep this file private."
}
else {
    Write-Host "Existing .env found; preserving its credentials."
}

docker compose config --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose configuration is invalid. Check .env and compose.yaml."
}

docker compose up --build -d
if ($LASTEXITCODE -ne 0) {
    throw "The local stack failed to start. Inspect: docker compose logs"
}

docker compose ps
Write-Host ""
Write-Host "Odoo is starting at http://localhost:8069"
Write-Host "The first startup can take a few minutes while the image is built."
Write-Host "The database master password is stored in .env; it is separate from the Odoo login."
