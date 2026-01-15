Write-Host "=== Fantasy Pairs Deployment Script (Merge Strategy, Correct Base Href) ===" -ForegroundColor Cyan

# --- 1. Ensure no rebase or merge is active ---
git rebase --abort 2>$null
git merge --abort 2>$null

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
flutter build web --release --base-href /

# --- 6. Replace docs folder ---
Write-Host "Refreshing docs folder..." -ForegroundColor Yellow
Remove-Item -Recurse -Force docs -ErrorAction SilentlyContinue
Copy-Item -Recurse build/web docs

# --- 7. Commit deployment ---
Write-Host "Committing deployment..." -ForegroundColor Yellow
git add web/index.html
git add docs
git commit -m "Automated deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null

# --- 8. Push to GitHub ---
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push

Write-Host "=== Deployment Complete ===" -ForegroundColor Green