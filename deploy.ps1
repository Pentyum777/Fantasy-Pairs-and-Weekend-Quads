# ---------------------------------------------------------------------------
# DEPLOY SCRIPT FOR FLUTTER WEB → GITHUB PAGES
# Cache-busting (JS only), MSAL-safe, deterministic
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
    Write-Host "❌ Flutter build failed — web directory not found."
    exit 1
}

Write-Host "✅ Flutter build complete."

# ---------------------------------------------------------------------------
# 2. APPLY CACHE-BUSTING VERSION HASH (JS ONLY)
# ---------------------------------------------------------------------------
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$versionHash = $timestamp
Write-Host "Applying version hash: $versionHash"

$filesToHash = @(
    "flutter.js",
    "main.dart.js",
    "flutter_service_worker.js"
)

foreach ($file in $filesToHash) {
    $fullPath = Join-Path $webDir $file
    if (Test-Path $fullPath) {
        $dir = Split-Path $fullPath
        $name = Split-Path $fullPath -Leaf
        $newName = "$name.$versionHash"
        $newFullPath = Join-Path $dir $newName

        if ($fullPath -ne $newFullPath) {
            if (Test-Path $newFullPath) {
                Remove-Item $newFullPath -Force
            }
            Rename-Item -Path $fullPath -NewName $newName
        }
    }
}

# ---------------------------------------------------------------------------
# 3. UPDATE INDEX.HTML REFERENCES
# ---------------------------------------------------------------------------
$indexPath = Join-Path $webDir "index.html"
$index = Get-Content $indexPath

foreach ($file in $filesToHash) {
    $pattern = [regex]::Escape($file)
    $replacement = "$file.$versionHash"
    $index = $index -replace $pattern, $replacement
}

Set-Content -Path $indexPath -Value $index -Encoding UTF8
Write-Host "✅ index.html updated with hashed JS references."

# ---------------------------------------------------------------------------
# 4. CLEAN /docs COMPLETELY AND COPY BUILD
# ---------------------------------------------------------------------------
$docsDir = "docs"

if (Test-Path $docsDir) {
    Write-Host "Removing existing /docs..."
    Remove-Item $docsDir -Recurse -Force
}

Write-Host "Creating /docs and copying build..."
New-Item -ItemType Directory -Path $docsDir | Out-Null
Copy-Item "$webDir\*" $docsDir -Recurse
Write-Host "✅ Copied build to /docs."

# ---------------------------------------------------------------------------
# 5. COPY MSAL.JS INTO /docs
# ---------------------------------------------------------------------------
$msalSourcePaths = @("web/msal.js", "msal.js")
$msalCopied = $false

foreach ($path in $msalSourcePaths) {
    if (Test-Path $path) {
        Copy-Item $path "$docsDir/msal.js"
        Write-Host "✅ msal.js copied from $path"
        $msalCopied = $true
        break
    }
}

if (-not $msalCopied) {
    Write-Host "⚠️ WARNING: msal.js not found — login will fail."
}

# ---------------------------------------------------------------------------
# 6. GIT COMMIT + PUSH
# ---------------------------------------------------------------------------
Write-Host "Committing and pushing to GitHub..."
git add docs
git commit -m "Deploy $versionHash" --allow-empty
git pull origin main
git push origin main

Write-Host "✅ Deployment complete."