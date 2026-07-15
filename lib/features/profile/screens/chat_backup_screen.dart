import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../shared/widgets/glass_card.dart';

class ChatBackupScreen extends ConsumerStatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  ConsumerState<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends ConsumerState<ChatBackupScreen> {
  bool _isActionRunning = false;
  double _progress = 0.0;
  String _statusText = '';

  Future<void> _backupChats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isActionRunning = true;
      _progress = 0.1;
      _statusText = 'Collecting chat history...';
    });
    AppHaptics.mediumTap();

    try {
      // 1. Fetch user's direct chats
      final chatsSnap = await FirebaseService.firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      // 2. Fetch user's groups
      final groupsSnap = await FirebaseService.firestore
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
      double stepSize = 0.7 / (chatsSnap.docs.length + groupsSnap.docs.length + 1);

      // Serialize direct chats and their messages
      for (final chatDoc in chatsSnap.docs) {
        final chatData = chatDoc.data();
        backupData['chats'].add({
          'id': chatDoc.id,
          'data': chatData,
        });

        // Messages for this chat
        final msgsSnap = await chatDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': mDoc.data(),
          });
          totalMessages++;
        }
        backupData['chatMessages'][chatDoc.id] = list;

        setState(() {
          _progress = (_progress + stepSize).clamp(0.0, 0.85);
          _statusText = 'Exporting chats... ($totalMessages messages)';
        });
      }

      // Serialize groups and their messages
      for (final groupDoc in groupsSnap.docs) {
        final groupData = groupDoc.data();
        backupData['groups'].add({
          'id': groupDoc.id,
          'data': groupData,
        });

        // Messages for this group
        final msgsSnap = await groupDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': mDoc.data(),
          });
          totalMessages++;
        }
        backupData['groupMessages'][groupDoc.id] = list;

        setState(() {
          _progress = (_progress + stepSize).clamp(0.0, 0.85);
          _statusText = 'Exporting groups... ($totalMessages messages)';
        });
      }

      setState(() {
        _progress = 0.9;
        _statusText = 'Uploading backup archive...';
      });

      // Write local temp file
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/ripple_backup_$uid.json');
      await backupFile.writeAsString(jsonEncode(backupData));

      // Upload to Supabase Storage
      final uniqueName = 'backup_${uid}_${DateTime.now().millisecondsSinceEpoch}.json';
      final url = await SupabaseService.uploadFile(backupFile, uniqueName);

      if (url != null) {
        // Save metadata record in user's cloud drive collection
        await FirebaseService.firestore
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

        setState(() {
          _progress = 1.0;
          _statusText = 'Backup completed successfully!';
        });
        AppHaptics.success();
      } else {
        throw 'Storage upload failed';
      }
    } catch (e) {
      setState(() {
        _statusText = 'Backup failed: $e';
      });
      AppHaptics.heavyTap();
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isActionRunning = false;
            _progress = 0.0;
            _statusText = '';
          });
        }
      });
    }
  }

  Future<void> _restoreBackup(Map<String, dynamic> metadata, String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isActionRunning = true;
      _progress = 0.1;
      _statusText = 'Downloading backup archive...';
    });
    AppHaptics.mediumTap();

    try {
      // 1. Download file via Supabase / temporary file cache
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_restore_$uid.json');
      
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      await response.pipe(file.openWrite());

      setState(() {
        _progress = 0.3;
        _statusText = 'Parsing archive data...';
      });

      final content = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(content);

      // Verify user ID match
      if (backupData['userId'] != uid) {
        throw 'Backup archive belongs to another user account.';
      }

      final chats = backupData['chats'] as List? ?? [];
      final groups = backupData['groups'] as List? ?? [];
      final chatMessages = backupData['chatMessages'] as Map? ?? {};
      final groupMessages = backupData['groupMessages'] as Map? ?? {};

      double stepSize = 0.7 / (chats.length + groups.length + 1);
      int importedCount = 0;

      // Restore chats
      for (final chatItem in chats) {
        final id = chatItem['id'] as String;
        final data = Map<String, dynamic>.from(chatItem['data'] as Map);
        
        await FirebaseService.firestore.collection('chats').doc(id).set(data, SetOptions(merge: true));

        // Restore messages
        final list = chatMessages[id] as List? ?? [];
        for (final mItem in list) {
          final mId = mItem['id'] as String;
          final mData = Map<String, dynamic>.from(mItem['data'] as Map);
          
          // Re-convert timestamp maps
          if (mData['createdAt'] is Map && mData['createdAt']['_seconds'] != null) {
            mData['createdAt'] = Timestamp(mData['createdAt']['_seconds'], mData['createdAt']['_nanoseconds'] ?? 0);
          } else if (mData['createdAt'] == null) {
            mData['createdAt'] = FieldValue.serverTimestamp();
          }

          await FirebaseService.firestore
              .collection('chats')
              .doc(id)
              .collection('messages')
              .doc(mId)
              .set(mData, SetOptions(merge: true));
          importedCount++;
        }

        setState(() {
          _progress = (_progress + stepSize).clamp(0.0, 0.95);
          _statusText = 'Restoring chats... ($importedCount messages)';
        });
      }

      // Restore groups
      for (final groupItem in groups) {
        final id = groupItem['id'] as String;
        final data = Map<String, dynamic>.from(groupItem['data'] as Map);
        
        await FirebaseService.firestore.collection('groups').doc(id).set(data, SetOptions(merge: true));

        // Restore messages
        final list = groupMessages[id] as List? ?? [];
        for (final mItem in list) {
          final mId = mItem['id'] as String;
          final mData = Map<String, dynamic>.from(mItem['data'] as Map);
          
          if (mData['createdAt'] is Map && mData['createdAt']['_seconds'] != null) {
            mData['createdAt'] = Timestamp(mData['createdAt']['_seconds'], mData['createdAt']['_nanoseconds'] ?? 0);
          } else if (mData['createdAt'] == null) {
            mData['createdAt'] = FieldValue.serverTimestamp();
          }

          await FirebaseService.firestore
              .collection('groups')
              .doc(id)
              .collection('messages')
              .doc(mId)
              .set(mData, SetOptions(merge: true));
          importedCount++;
        }

        setState(() {
          _progress = (_progress + stepSize).clamp(0.0, 0.95);
          _statusText = 'Restoring groups... ($importedCount messages)';
        });
      }

      setState(() {
        _progress = 1.0;
        _statusText = 'Restore completed successfully!';
      });
      AppHaptics.success();
    } catch (e) {
      setState(() {
        _statusText = 'Restore failed: $e';
      });
      AppHaptics.heavyTap();
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isActionRunning = false;
            _progress = 0.0;
            _statusText = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Chat Backup & Restore', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: AppColors.aquaCore, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Cloud Backup Settings',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Save your chats, messages, groups, and themes to Ripple\'s secure Supabase Cloud Drive storage.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  if (_isActionRunning) ...[
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.aquaCore),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText,
                      style: const TextStyle(color: AppColors.aquaCore, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.aquaGlow,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _backupChats,
                          icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                          label: const Text('Back Up Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Available Restore Snapshots',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Backups List
            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.firestore
                    .collection('user_files')
                    .doc(uid)
                    .collection('files')
                    .where('type', isEqualTo: 'backup')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white54)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return GlassCard(
                      borderRadius: 14,
                      padding: const EdgeInsets.all(24),
                      child: const Center(
                        child: Text(
                          'No backups saved yet.\nTap "Back Up Now" to create your first restore point.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final url = data['url'] as String? ?? '';
                      final sizeBytes = data['size'] as int? ?? 0;
                      final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);
                      final msgCount = data['messageCount'] as int? ?? 0;
                      final createdAt = data['createdAt'] as Timestamp?;
                      final dateStr = createdAt != null ? createdAt.toDate().toString().split('.').first : 'N/A';

                      return GlassCard(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.aquaCore.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_rounded, color: AppColors.aquaCore),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$sizeMb MB • $msgCount Messages',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isActionRunning)
                              ElevatedButton(
                                onPressed: () => _restoreBackup(data, url),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.aquaCore.withOpacity(0.15),
                                  foregroundColor: AppColors.aquaCore,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
