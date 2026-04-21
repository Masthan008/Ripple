# Firestore Requirements for Priority 2 & 4 Features

## Priority 2: AI-Powered Productivity
✅ **No additional Firestore requirements**
- Conversation Summarization: Uses existing message data
- Action Item Identification: Client-side AI processing
- Real-time Translation: Client-side AI processing
- Proactive AI Assistant (@ripple bot): Client-side AI processing

## Priority 4: Advanced Privacy & Security

### ✅ Privacy Dashboard
**No additional Firestore requirements**
- Uses existing user document and privacy sub-map

### ✅ Granular Stealth Mode
**New Firestore field:**
- `users/{uid}/privacy/stealthContacts` - Array of UIDs for which stealth is enabled
  - Type: `array of strings`
  - Example: `["user123", "user456"]`

### ⚠️ Secret Chats (E2E Encrypted)
**Requires new Firestore collection and fields:**

#### New Collection: `secretChats`
```
secretChats/{chatId}
  ├─ participants: array of strings (user UIDs)
  ├─ createdAt: timestamp
  ├─ updatedAt: timestamp
  ├─ isGroup: boolean (default: false)
  └─ encrypted: boolean (always true)
```

#### New Sub-collection: `secretChats/{chatId}/messages`
```
secretChats/{chatId}/messages/{messageId}
  ├─ encryptedText: string (AES-256 encrypted message)
  ├─ senderId: string
  ├─ createdAt: timestamp
  ├─ iv: string (initialization vector for decryption)
  └─ isDeleted: boolean
```

#### New User Document Fields:
```
users/{uid}
  └─ secretChats: array of strings (secret chat IDs)
```

#### New Index Requirements:
```
Collection: secretChats
Index: participants (array) - for querying user's secret chats

Collection: secretChats/{chatId}/messages  
Index: createdAt (descending) - for message ordering
```

#### Security Requirements:
- **Encryption Library**: Need to add `encrypt` or `flutter_secure_storage` package
- **Key Management**: Each secret chat needs unique encryption key
- **Local Storage**: Keys should be stored in device secure storage (not Firestore)
- **PIN/Biometric**: Separate authentication layer for accessing secret chats

### Summary of Firestore Changes Needed for Secret Chats:
1. Create new collection `secretChats`
2. Add sub-collection `secretChats/{chatId}/messages`
3. Add field `users/{uid}/secretChats` (array)
4. Add field `users/{uid}/privacy/stealthContacts` (array)
5. Create compound index on `secretChats` for `participants` array
6. Create index on `secretChats/{chatId}/messages` for `createdAt`

**Note**: Secret Chats is a complex feature requiring E2E encryption implementation. The actual encryption/decryption logic would need to be implemented using a cryptography library, with keys stored locally on the device (not in Firestore) for true end-to-end security.
