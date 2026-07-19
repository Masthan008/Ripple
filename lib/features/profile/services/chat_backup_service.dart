import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/supabase_service.dart';

/// Service to handle real-time Firestore chat backups, restores, and automatic frequency sweeps.
class ChatBackupService {
  ChatBackupService._();

  static final FirebaseFirestore _firestore = FirebaseService.firestore;

  /// Recursively convert non-encodable Firestore objects (e.g. Timestamps) into JSON-serializable types.
  static dynamic makeEncodable(dynamic value) {
    if (value is Timestamp) {
      return {'_type': 'Timestamp', 'value': value.millisecondsSinceEpoch};
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), makeEncodable(v)));
    }
    if (value is List) {
      return value.map(makeEncodable).toList();
    }
    if (value is FieldValue) {
      return null;
    }
    return value;
  }

  /// Recursively parse JSON-decoded values back to native Firestore types.
  static dynamic parseDecoded(dynamic value) {
    if (value is Map) {
      if (value['_type'] == 'Timestamp') {
        return Timestamp.fromMillisecondsSinceEpoch(value['value'] as int);
      }
      return value.map((k, v) => MapEntry(k.toString(), parseDecoded(v)));
    }
    if (value is List) {
      return value.map(parseDecoded).toList();
    }
    return value;
  }

  /// Runs the full backup sequence for a user and uploads it to Supabase Storage.
  static Future<String?> performBackup(String uid) async {
    try {
      // 1. Fetch user's direct chats
      final chatsSnap = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      // 2. Fetch user's groups
      final groupsSnap = await _firestore
          .collection('groups')
          .where('members', arrayContains: uid)
          .get();

      final backupData = <String, dynamic>{
        'version': 1,
        'backedUpAt': DateTime.now().toUtc().toIso8601String(),
        'userId': uid,
        'chats': [],
        'groups': [],
        'chatMessages': {},
        'groupMessages': {},
      };

      int totalMessages = 0;

      // Serialize direct chats and their messages
      for (final chatDoc in chatsSnap.docs) {
        final chatData = makeEncodable(chatDoc.data());
        backupData['chats'].add({
          'id': chatDoc.id,
          'data': chatData,
        });

        final msgsSnap = await chatDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': makeEncodable(mDoc.data()),
          });
          totalMessages++;
        }
        backupData['chatMessages'][chatDoc.id] = list;
      }

      // Serialize groups and their messages
      for (final groupDoc in groupsSnap.docs) {
        final groupData = makeEncodable(groupDoc.data());
        backupData['groups'].add({
          'id': groupDoc.id,
          'data': groupData,
        });

        final msgsSnap = await groupDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': makeEncodable(mDoc.data()),
          });
          totalMessages++;
        }
        backupData['groupMessages'][groupDoc.id] = list;
      }

      // Write local temp file
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/ripple_backup_$uid.json');
      await backupFile.writeAsString(jsonEncode(backupData));

      // Upload to Supabase
      final uniqueName = 'backup_${uid}_${DateTime.now().millisecondsSinceEpoch}.json';
      final url = await SupabaseService.uploadFile(backupFile, uniqueName);

      if (url != null) {
        // Save metadata record in user_files
        await _firestore
            .collection('user_files')
            .doc(uid)
            .collection('files')
            .add({
          'name': 'Chat History Backup (${DateTime.now().toString().split('.').first})',
          'url': url,
          'size': await backupFile.length(),
          'type': 'backup',
          'messageCount': totalMessages,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return url;
      }
    } catch (e) {
      print('❌ performBackup error: $e');
    }
    return null;
  }

  /// Runs the full restore sequence for a user from a backup URL.
  static Future<void> performRestore(String uid, String url) async {
    // Download file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_restore_$uid.json');
    
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(url));
    final response = await request.close();
    await response.pipe(file.openWrite());

    final content = await file.readAsString();
    final Map<String, dynamic> backupData = jsonDecode(content);

    if (backupData['userId'] != uid) {
      throw 'Backup archive belongs to another user account.';
    }

    final chats = backupData['chats'] as List? ?? [];
    final groups = backupData['groups'] as List? ?? [];
    final chatMessages = backupData['chatMessages'] as Map? ?? {};
    final groupMessages = backupData['groupMessages'] as Map? ?? {};

    // Restore chats
    for (final chatItem in chats) {
      final id = chatItem['id'] as String;
      final data = Map<String, dynamic>.from(parseDecoded(chatItem['data']) as Map);
      
      await _firestore.collection('chats').doc(id).set(data, SetOptions(merge: true));

      final list = chatMessages[id] as List? ?? [];
      for (final mItem in list) {
        final mId = mItem['id'] as String;
        final mData = Map<String, dynamic>.from(parseDecoded(mItem['data']) as Map);
        
        await _firestore
            .collection('chats')
            .doc(id)
            .collection('messages')
            .doc(mId)
            .set(mData, SetOptions(merge: true));
      }
    }

    // Restore groups
    for (final groupItem in groups) {
      final id = groupItem['id'] as String;
      final data = Map<String, dynamic>.from(parseDecoded(groupItem['data']) as Map);
      
      await _firestore.collection('groups').doc(id).set(data, SetOptions(merge: true));

      final list = groupMessages[id] as List? ?? [];
      for (final mItem in list) {
        final mId = mItem['id'] as String;
        final mData = Map<String, dynamic>.from(parseDecoded(mItem['data']) as Map);
        
        await _firestore
            .collection('groups')
            .doc(id)
            .collection('messages')
            .doc(mId)
            .set(mData, SetOptions(merge: true));
      }
    }
  }

  /// Automatically check if backup frequency duration is met and trigger a silent background backup.
  static Future<void> checkAndRunAutoBackup(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final String autoFrequency = userData['autoBackupFrequency'] as String? ?? 'Off';
      if (autoFrequency == 'Off') return;

      // Determine duration limit
      Duration limit;
      if (autoFrequency == 'Daily') {
        limit = const Duration(hours: 24);
      } else if (autoFrequency == 'Weekly') {
        limit = const Duration(days: 7);
      } else if (autoFrequency == 'Monthly') {
        limit = const Duration(days: 30);
      } else {
        return;
      }

      // Check last backup timestamp
      final lastBackups = await _firestore
          .collection('user_files')
          .doc(uid)
          .collection('files')
          .where('type', isEqualTo: 'backup')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      bool needsBackup = true;
      if (lastBackups.docs.isNotEmpty) {
        final lastBackupData = lastBackups.docs.first.data();
        final lastBackupTime = (lastBackupData['createdAt'] as Timestamp?)?.toDate();
        if (lastBackupTime != null) {
          final difference = DateTime.now().difference(lastBackupTime);
          if (difference < limit) {
            needsBackup = false; // Last backup is fresh
          }
        }
      }

      if (needsBackup) {
        print('⏰ Auto Backup Triggered: Starting background export for $uid...');
        await performBackup(uid);
      }
    } catch (e) {
      print('❌ checkAndRunAutoBackup error: $e');
    }
  }
}
