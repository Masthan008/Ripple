# Firebase Firestore Deploy Script
# This script handles the JSON parsing bug in Firebase CLI

param(
    [switch]$IndexesOnly,
    [switch]$RulesOnly,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying Firestore..." -ForegroundColor Cyan

# First, ensure we're logged in
$loginCheck = firebase login:list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in. Running firebase login..." -ForegroundColor Red
    firebase login
}

# Build the command
$cmd = "firebase deploy --only firestore"

if ($IndexesOnly) {
    $cmd += ":indexes"
}
elseif ($RulesOnly) {
    $cmd += ":rules"
}

if ($Force) {
    $cmd += " --force"
}

# Handle the interactive prompt automatically using echo
Write-Host "Running: $cmd" -ForegroundColor Yellow

# The issue is that Firebase CLI expects TTY for prompts
# We pipe 'n' to skip deletion of old indexes
try {
    $process = Start-Process -FilePath "powershell" -ArgumentList "-Command", "echo 'n' | $cmd" -PassThru -Wait -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host "✅ Deploy completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Deploy may have issues. Exit code: $($process.ExitCode)" -ForegroundColor Yellow
        
        # If it failed with JSON error, suggest manual console upload
        Write-Host "`n📝 Alternative: Upload indexes manually via Firebase Console:" -ForegroundColor Cyan
        Write-Host "   1. Go to: https://console.firebase.google.com/project/ripple-cd77c/firestore/indexes" -ForegroundColor White
        Write-Host "   2. Click 'Import JSON' button" -ForegroundColor White
        Write-Host "   3. Select: firestore.indexes.json" -ForegroundColor White
        Write-Host "   4. Click 'Import'" -ForegroundColor White
    }
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
}
