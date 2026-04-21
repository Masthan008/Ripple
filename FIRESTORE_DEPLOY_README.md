# Firestore Deploy Guide

## ⚠️ Known Issue
Firebase CLI has a bug when deploying indexes with conflicts. Use **Console Import** instead.

## ✅ Recommended Method: Console Import

1. Double-click: `open-firebase-console.bat`
2. Click **"Import JSON"** button
3. Select: `firestore.indexes.json`
4. Click **"Import"**

Done! Takes 10 seconds.

## Alternative Methods

### Deploy Rules Only (CLI works fine)
```powershell
firebase deploy --only firestore:rules
```

### Deploy Everything (Console Import still needed for indexes)
```powershell
firebase deploy --only firestore
# If indexes fail, use Console Import
```

## When Adding New Indexes

1. Add index to `firestore.indexes.json`
2. Use **Console Import** (not CLI)
3. Much faster and 100% reliable

## Files

- `firestore.rules` - Security rules
- `firestore.indexes.json` - Index definitions
- `open-firebase-console.bat` - Opens console in browser
