# Push this folder to GitHub using a Personal Access Token (classic).
# Run in PowerShell from the tvbox-source directory:
#   powershell -ExecutionPolicy Bypass -File .\push_to_github.ps1

$REPO_OWNER = "zhych0327-dev"
$REPO_NAME  = "tvbox-source"
$REPO_URL   = "https://github.com/$REPO_OWNER/$REPO_NAME.git"

# ---- Locate git.exe (PortableGit is often NOT on PATH) ----
Write-Host "==> Locating git"
$gitDir = $null
$cmd = Get-Command git -ErrorAction SilentlyContinue
if ($cmd) {
    $gitDir = Split-Path $cmd.Source -Parent
} else {
    $candidates = @(
        "D:\workbuddy\resources\vendor\PortableGit\mingw64\bin",
        "D:\workbuddy\resources\vendor\PortableGit\cmd",
        "C:\Program Files\Git\cmd",
        "C:\Program Files\Git\bin",
        "$env:LOCALAPPDATA\Programs\Git\cmd",
        "$env:USERPROFILE\.workbuddy\binaries\PortableGit\mingw64\bin"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "git.exe")) { $gitDir = $c; break }
    }
    if (-not $gitDir) {
        $found = Get-ChildItem -Path "D:\workbuddy","$env:USERPROFILE\.workbuddy" `
            -Filter git.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $gitDir = $found.DirectoryName }
    }
}
if (-not $gitDir) {
    Write-Host "ERROR: git.exe not found. Install Git or add it to PATH."
    exit 1
}
$env:PATH = "$gitDir;$env:PATH"
Write-Host "   git found at: $gitDir"

Write-Host "============================================================"
Write-Host " Push to $REPO_OWNER/$REPO_NAME"
Write-Host "============================================================"
Write-Host ""
Write-Host "Generate a Classic PAT first (one time):"
Write-Host "  https://github.com/settings/tokens"
Write-Host "  Generate new token (classic)"
Write-Host "  Note: anything, Expiration: 90 days"
Write-Host "  Check BOTH scopes:"
Write-Host "    - 'repo' (whole group)      -> push the files"
Write-Host "    - 'workflow'                -> push .github/workflows/*.yml"
Write-Host "  Copy the ghp_... string"
Write-Host ""

$secure = Read-Host -AsSecureString "Paste your PAT (input is hidden)"
$TOKEN = [System.Net.NetworkCredential]::new("", $secure).Password
if ([string]::IsNullOrWhiteSpace($TOKEN)) {
    Write-Host "Token is empty. Exiting."
    exit 1
}

Write-Host "==> Init git"
if (-not (Test-Path .git)) {
    git init -q
    git config core.autocrlf false
}
git config user.name  $REPO_OWNER
git config user.email "$REPO_OWNER@users.noreply.github.com"

Write-Host "==> Commit files"
git add .
git commit -qm "chore: init tvbox source repo [skip ci]"
if ($LASTEXITCODE -ne 0) {
    Write-Host "   (nothing new to commit)"
}

Write-Host "==> Attach remote with token (temporary)"
git remote remove origin 2>$null
git remote add origin "https://$TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git"

Write-Host "==> Push to main"
git branch -M main
git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Push FAILED. Common reasons:"
    Write-Host "  - token missing 'repo' scope"
    Write-Host "  - token missing 'workflow' scope (needed for .github/workflows/*.yml)"
    Write-Host "  - repo name/owner mismatch"
    Write-Host "  - remote already has commits (you created an empty repo, so unlikely)"
    exit 1
}

Write-Host "==> Remove token from remote URL"
git remote set-url origin $REPO_URL

Write-Host ""
Write-Host "SUCCESS. Your import URL:"
Write-Host "  https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/config/tvbox.json"
Write-Host ""
Write-Host "Final step: repo Settings -> Actions -> General -> Workflow permissions"
Write-Host "Check 'Read and write permissions' so auto-update can commit."
