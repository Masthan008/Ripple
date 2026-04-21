@echo off
REM Firebase Firestore Deploy Script (Windows Batch)
REM Handles the JSON parsing bug by auto-answering prompts

echo Deploying Firestore...
echo n | firebase deploy --only firestore --force 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo === DEPLOY PARTIALLY FAILED ===
    echo If you see "JSON" error, indexes need manual upload:
    echo 1. Go to: https://console.firebase.google.com/project/ripple-cd77c/firestore/indexes
    echo 2. Click "Import JSON" button
    echo 3. Select file: firestore.indexes.json
    echo 4. Click "Import"
    echo.
    echo Rules should have deployed successfully.
)

pause
