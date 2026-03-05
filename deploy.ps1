# ---------------------------------------------------------------------------
# DEPLOY SCRIPT FOR FLUTTER WEB → GITHUB PAGES
# Fixes MSAL 404 errors by restoring index.html and copying MSAL files correctly
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
# 1B. RESTORE CUSTOM index.html + MSAL FILES INTO BUILD
# ---------------------------------------------------------------------------
Write-Host "Restoring custom index.html and MSAL scripts into build..."

# Copy custom index.html
Copy-Item "web/index.html" "$webDir/index.html" -Force

# Ensure build/web/assets exists
$buildAssets = "$webDir/assets"
if (!(Test-Path $buildAssets)) {
    New-Item -ItemType Directory -Path $buildAssets | Out-Null
}

# Copy MSAL JS files into build/web/assets
Copy-Item "web/assets/msal.js" "$buildAssets/msal.js" -Force
Copy-Item "web/assets/msal_interop.js" "$buildAssets/msal_interop.js" -Force

Write-Host "Custom index.html and MSAL scripts restored into build."

# ---------------------------------------------------------------------------
# 1C. REMOVE SERVICE WORKER
# ---------------------------------------------------------------------------
$swPath = Join-Path $webDir "flutter_service_worker.js"
if (Test-Path $swPath) {
    Write-Host "Removing flutter_service_worker.js..."
    Remove-Item -Force $swPath
}

# ---------------------------------------------------------------------------
# 2. CLEAN /docs AND COPY BUILD
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
# 2B. COPY MSAL FILES INTO /docs/assets (CRITICAL FIX)
# ---------------------------------------------------------------------------
Write-Host "Copying MSAL scripts into /docs/assets..."

$docsAssets = "$docsDir/assets"
if (!(Test-Path $docsAssets)) {
    New-Item -ItemType Directory -Path $docsAssets | Out-Null
}

Copy-Item "web/assets/msal.js" "$docsAssets/msal.js" -Force
Copy-Item "web/assets/msal_interop.js" "$docsAssets/msal_interop.js" -Force

Write-Host "MSAL scripts copied into /docs/assets."

# ---------------------------------------------------------------------------
# 3. GIT COMMIT + PUSH
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