Write-Host "=== Fantasy Pairs Deployment Script ===" -ForegroundColor Cyan

# 1. Ensure no rebase is active
git rebase --abort 2>$null

# 2. Pull remote changes safely (ignore conflicts, especially in docs/)
Write-Host "Pulling latest changes (safe rebase)..." -ForegroundColor Yellow
git pull --rebase --strategy-option=theirs

if ($LASTEXITCODE -ne 0) {
    Write-Host "Rebase conflict detected. Skipping conflicting commit..." -ForegroundColor Red
    git rebase --skip
}

# 3. Ensure service worker is disabled in web/index.html
Write-Host "Ensuring service worker is disabled..." -ForegroundColor Yellow
$indexPath = "web/index.html"
$indexContent = Get-Content $indexPath -Raw

if ($indexContent -notmatch 'flutter-service-worker') {
    Write-Host "Adding <meta name='flutter-service-worker' content='false'> to index.html" -ForegroundColor Green
    $indexContent = $indexContent -replace '<base href="\$FLUTTER_BASE_HREF">',
        "<meta name='flutter-service-worker' content='false'>`n  <base href=`"\$FLUTTER_BASE_HREF`">"
    Set-Content -Path $indexPath -Value $indexContent
} else {
    Write-Host "Service worker already disabled." -ForegroundColor Green
}

# 4. Clean Flutter build
Write-Host "Cleaning Flutter build..." -ForegroundColor Yellow
flutter clean

# 5. Build Flutter web with correct base-href
Write-Host "Building Flutter web release..." -ForegroundColor Yellow
flutter build web --release --base-href /my_app/

# 6. Replace docs folder
Write-Host "Refreshing docs folder..." -ForegroundColor Yellow
Remove-Item -Recurse -Force docs -ErrorAction SilentlyContinue
Copy-Item -Recurse build/web docs

# 7. Commit changes
Write-Host "Committing updated docs..." -ForegroundColor Yellow
git add web/index.html
git add docs
git commit -m "Automated deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null

# 8. Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push

Write-Host "=== Deployment Complete ===" -ForegroundColor Green