# ---------------------------------------------------------------------------
# DEPLOY SCRIPT FOR FLUTTER WEB -> GITHUB PAGES
# Deterministic, idempotent, cache-busting, clean output
# ---------------------------------------------------------------------------

Write-Host "=== Starting Deployment ==="

# Ensure script runs from project root
Set-Location $PSScriptRoot

# ---------------------------------------------------------------------------
# 1. FLUTTER BUILD
# ---------------------------------------------------------------------------
Write-Host "Building Flutter web release..."
flutter build web --release

$webDir = "build\web"
if (!(Test-Path $webDir)) {
    Write-Host "Flutter build failed - web directory not found."
    exit 1
}

Write-Host "Flutter build complete."

# ---------------------------------------------------------------------------
# 2. APPLY CACHE-BUSTING VERSION HASH
# ---------------------------------------------------------------------------
Write-Host "Applying cache-busting version hash..."

$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$versionHash = $timestamp

# Files to rename + rewrite references
$filesToHash = @(
    "flutter.js",
    "main.dart.js",
    "flutter_service_worker.js",
    "assets/AssetManifest.json",
    "assets/FontManifest.json"
)

foreach ($file in $filesToHash) {
    $fullPath = Join-Path $webDir $file

    if (Test-Path $fullPath) {
        $dir = Split-Path $fullPath
        $name = Split-Path $fullPath -Leaf
        $newName = "$name.$versionHash"
        $newFullPath = Join-Path $dir $newName

        # Prevent "file already exists" error
        if ($fullPath -ne $newFullPath) {
            if (Test-Path $newFullPath) {
                Remove-Item $newFullPath -Force
            }
            Rename-Item -Path $fullPath -NewName $newName
        }
    }
}

Write-Host "Version hash applied: $versionHash"

# ---------------------------------------------------------------------------
# 3. UPDATE INDEX.HTML REFERENCES
# ---------------------------------------------------------------------------
$indexPath = Join-Path $webDir "index.html"
if (Test-Path $indexPath) {
    $index = Get-Content $indexPath

    foreach ($file in $filesToHash) {
        $pattern = [regex]::Escape($file)
        $replacement = "$file.$versionHash"
        $index = $index -replace $pattern, $replacement
    }

    Set-Content -Path $indexPath -Value $index -Encoding UTF8
    Write-Host "index.html updated with cache-busting references."
}

# ---------------------------------------------------------------------------
# 4. COPY TO /docs FOR GITHUB PAGES
# ---------------------------------------------------------------------------
$docsDir = "docs"

if (Test-Path $docsDir) {
    Remove-Item $docsDir -Recurse -Force
}

Copy-Item $webDir $docsDir -Recurse

Write-Host "Copied build to /docs."

# ---------------------------------------------------------------------------
# 5. GIT COMMIT + PUSH
# ---------------------------------------------------------------------------
Write-Host "Committing and pushing to GitHub..."

git add .
git commit -m "Deploy $versionHash" --allow-empty
git pull origin main
git push origin main

Write-Host "=== Deployment Complete ==="