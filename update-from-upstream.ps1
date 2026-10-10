# Pull Duarte's latest openGym into this fork, push it (Netlify rebuilds the frontend on push),
# and redeploy the Fly.io API only when api/ changed.
# Usage: powershell -File .\update-from-upstream.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (git status --porcelain) { throw 'Working tree has uncommitted changes. Commit or stash them first.' }

git fetch origin
$behind = [int](git rev-list --count main..origin/main)
if ($behind -eq 0) { Write-Host 'Already up to date with upstream.'; return }

Write-Host "Upstream has $behind new commit(s):"
git log --oneline main..origin/main | Select-Object -First 20

$before = git rev-parse HEAD
git merge origin/main --no-edit
if ($LASTEXITCODE -ne 0) {
    git merge --abort
    throw 'Merge conflict. Aborted; nothing changed. Resolve by hand (git merge origin/main).'
}

git push fork main
if ($LASTEXITCODE -ne 0) { throw 'Push to fork failed.' }
Write-Host 'Pushed. Netlify will rebuild the frontend.'

if (git diff --name-only $before HEAD -- api/) {
    $fly = (Get-Command flyctl -ErrorAction SilentlyContinue).Source
    if (-not $fly) { $fly = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Fly-io.flyctl*" -Recurse -Filter flyctl.exe | Select-Object -First 1).FullName }
    Write-Host 'api/ changed - redeploying the Fly.io API...'
    Push-Location api
    & $fly deploy --remote-only --ha=false --yes
    Pop-Location
} else {
    Write-Host 'api/ unchanged - no backend redeploy needed.'
}
