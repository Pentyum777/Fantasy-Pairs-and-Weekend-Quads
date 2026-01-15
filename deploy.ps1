Write-Host "=== Fantasy Pairs Deployment Script ===" -ForegroundColor Cyan

# 1. Ensure no rebase is active
git rebase --abort 2>$null

# 2. Pull remote changes but ignore conflicts (especially in docs/)
Write-Host "Pulling latest changes (safe rebase)..." -ForegroundColor Yellow
git pull --rebase --strategy-option=theirs

if ($LASTEXITCODE -ne 0) {
    Write-Host "Rebase conflict detected. Skipping conflicting commit..." -ForegroundColor Red
    git rebase --skip
}

# 3. Build Flutter web
Write-Host "Building Flutter web release..." -ForegroundColor Yellow
flutter build web --release --base-href /my_app/

# 4. Replace docs folder
Write-Host "Refreshing docs folder..." -ForegroundColor Yellow
Remove-Item -Recurse -Force docs -ErrorAction SilentlyContinue
Copy-Item -Recurse build/web docs

# 5. Commit changes
Write-Host "Committing updated docs..." -ForegroundColor Yellow
git add docs
git commit -m "Automated deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null

# 6. Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push

Write-Host "=== Deployment Complete ===" -ForegroundColor Green