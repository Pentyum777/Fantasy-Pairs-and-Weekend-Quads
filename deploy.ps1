# ---------------------------------------------------------------------------
# SIMPLE DEPLOY SCRIPT FOR FLUTTER WEB → GITHUB PAGES
# Build → wipe /docs → copy → commit source + deploy → push
# ---------------------------------------------------------------------------

Write-Host "=== Starting Deployment ==="

Set-Location $PSScriptRoot

# ---------------------------------------------------------------------------
# 1. CLEAN + BUILD
# ---------------------------------------------------------------------------
Write-Host "Cleaning and building Flutter web release..."
flutter clean
flutter pub get
flutter build web --release

$webDir = "build\web"
if (!(Test-Path $webDir)) {
    Write-Host "Flutter build failed -- web directory not found."
    exit 1
}

Write-Host "Flutter build complete."

# ---------------------------------------------------------------------------
# 1B. RESTORE CUSTOM index.html + MSAL FILES
# ---------------------------------------------------------------------------
Write-Host "Restoring custom index.html and MSAL scripts..."

# Copy your custom index.html into the build output
Copy-Item "web/index.html" "$webDir/index.html" -Force

# Copy MSAL JS files into build output
Copy-Item "web/assets" "$webDir/assets" -Recurse -Force

Write-Host "Custom index.html and MSAL scripts restored."

# ---------------------------------------------------------------------------
# 1C. REMOVE SERVICE WORKER (HARD DELETE)
# ---------------------------------------------------------------------------
$swPath = Join-Path $webDir "flutter_service_worker.js"
if (Test-Path $swPath) {
    Write-Host "Removing flutter_service_worker.js to prevent stale caching..."
    Remove-Item -Force $swPath
    Write-Host "Service worker removed."
} else {
    Write-Host "No service worker found -- nothing to remove."
}

# ---------------------------------------------------------------------------
# 2. CLEAN /docs COMPLETELY AND COPY BUILD
# ---------------------------------------------------------------------------
$docsDir = "docs"

if (Test-Path $docsDir) {
    Write-Host "Removing existing /docs..."
    Remove-Item $docsDir -Recurse -Force
}

Write-Host "Creating /docs and copying build..."
New-Item -ItemType Directory -Path $docsDir | Out-Null
Copy-Item "$webDir\*" $docsDir -Recurse
Write-Host "Copied build to /docs."

# ---------------------------------------------------------------------------
# 3. GIT COMMIT + PUSH (SOURCE CODE FIRST, THEN DEPLOY)
# ---------------------------------------------------------------------------

Write-Host "Committing source code changes..."
git add .
git commit -m "Source update" --allow-empty
git push origin main

Write-Host "Committing and pushing deploy build..."
git add docs
git commit -m "Deploy" --allow-empty
git push origin main --force

Write-Host "Deployment complete."