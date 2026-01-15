Write-Host "=== Fantasy Pairs Deployment Script (Correct Base Href + Merge Strategy) ===" -ForegroundColor Cyan

# --- 1. Ensure no rebase or merge is active ---
try { git rebase --abort | Out-Null } catch {}
try { git merge --abort  | Out-Null } catch {}

# --- 2. Auto-commit any unstaged changes ---
if ((git status --porcelain) -ne "") {
    Write-Host "Staging and committing local changes..." -ForegroundColor Yellow
    git add .
    git commit -m "Auto-save before deploy"
}

# --- 3. Pull using merge (remote wins cleanly) ---
Write-Host "Pulling latest changes (merge, no rebase)..." -ForegroundColor Yellow
git pull --no-rebase

# --- 4. Ensure index.html contains required tags ---
$indexPath = "web/index.html"
$indexContent = Get-Content $indexPath -Raw

# Ensure base placeholder exists
if ($indexContent -notmatch '<base href="\$FLUTTER_BASE_HREF">') {
    Write-Host "Restoring <base href=""`$FLUTTER_BASE_HREF""> placeholder..." -ForegroundColor Yellow
    $indexContent = $indexContent -replace '<base href=".*?">', '<base href="$FLUTTER_BASE_HREF">'
}

# Ensure service worker is disabled
if ($indexContent -notmatch 'flutter-service-worker') {
    Write-Host "Injecting service worker disable flag..." -ForegroundColor Yellow
    $indexContent = $indexContent -replace '<base href="\$FLUTTER_BASE_HREF">',
        "<meta name='flutter-service-worker' content='false'>`n  <base href=""`$FLUTTER_BASE_HREF"">"
}

Set-Content -Path $indexPath -Value $indexContent

# --- 5. Clean + rebuild Flutter ---
Write-Host "Cleaning Flutter build..." -ForegroundColor Yellow
flutter clean

Write-Host "Fetching dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "Building Flutter web release with correct base href..." -ForegroundColor Yellow
flutter build web --release --base-href /Fantasy-Pairs-and-Weekend-Quads/

# --- 6. Replace docs folder ---
Write-Host "Refreshing docs folder..." -ForegroundColor Yellow
Remove-Item -Recurse -Force docs -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path docs | Out-Null
Copy-Item -Recurse -Force build/web/* docs/

# --- 7. Commit deployment ---
Write-Host "Committing deployment..." -ForegroundColor Yellow
git add docs
git commit -m "Automated deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null

# --- 8. Push to GitHub ---
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push

Write-Host "=== Deployment Complete ===" -ForegroundColor Green