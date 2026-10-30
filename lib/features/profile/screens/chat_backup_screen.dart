import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/glass_card.dart';
import '../services/chat_backup_service.dart';

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
      final chatsSnap = await FirebaseService.firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

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

      for (final chatDoc in chatsSnap.docs) {
        final chatData = ChatBackupService.makeEncodable(chatDoc.data());
        backupData['chats'].add({
          'id': chatDoc.id,
          'data': chatData,
        });

        final msgsSnap = await chatDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': ChatBackupService.makeEncodable(mDoc.data()),
          });
          totalMessages++;
        }
        backupData['chatMessages'][chatDoc.id] = list;

        setState(() {
          _progress = (_progress + stepSize).clamp(0.0, 0.85);
          _statusText = 'Exporting chats... ($totalMessages messages)';
        });
      }

      for (final groupDoc in groupsSnap.docs) {
        final groupData = ChatBackupService.makeEncodable(groupDoc.data());
        backupData['groups'].add({
          'id': groupDoc.id,
          'data': groupData,
        });

        final msgsSnap = await groupDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': ChatBackupService.makeEncodable(mDoc.data()),
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

      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/ripple_backup_$uid.json');
      await backupFile.writeAsString(jsonEncode(backupData));

      final uniqueName = 'backup_${uid}_${DateTime.now().millisecondsSinceEpoch}.json';
      final url = await SupabaseService.uploadFile(backupFile, uniqueName);

      if (url != null) {
        await FirebaseService.firestore
            .collection('user_files')
            .doc(uid)
            .collection('files')
            .add({
          'name': 'Cloud Snapshot (${DateTime.now().toString().split('.').first})',
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

  Future<void> _exportLocalBackup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isActionRunning = true;
      _progress = 0.2;
      _statusText = 'Generating encrypted local backup...';
    });
    AppHaptics.mediumTap();

    try {
      final chatsSnap = await FirebaseService.firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

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

      for (final chatDoc in chatsSnap.docs) {
        backupData['chats'].add({
          'id': chatDoc.id,
          'data': ChatBackupService.makeEncodable(chatDoc.data()),
        });
        final msgsSnap = await chatDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': ChatBackupService.makeEncodable(mDoc.data()),
          });
          totalMessages++;
        }
        backupData['chatMessages'][chatDoc.id] = list;
      }

      for (final groupDoc in groupsSnap.docs) {
        backupData['groups'].add({
          'id': groupDoc.id,
          'data': ChatBackupService.makeEncodable(groupDoc.data()),
        });
        final msgsSnap = await groupDoc.reference.collection('messages').get();
        final list = [];
        for (final mDoc in msgsSnap.docs) {
          list.add({
            'id': mDoc.id,
            'data': ChatBackupService.makeEncodable(mDoc.data()),
          });
          totalMessages++;
        }
        backupData['groupMessages'][groupDoc.id] = list;
      }

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFile = File('${tempDir.path}/ripple_backup_$dateStr.rpbk');
      await backupFile.writeAsString(jsonEncode(backupData));

      setState(() {
        _progress = 1.0;
        _statusText = 'Export ready! Opening share dialog...';
      });
      AppHaptics.success();

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'Encrypted Ripple Chat Backup ($totalMessages messages)',
        subject: 'Ripple Chat Backup',
      );
    } catch (e) {
      setState(() {
        _statusText = 'Export failed: $e';
      });
      AppHaptics.heavyTap();
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
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

  Future<void> _restoreFromLocalFile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(content);

      setState(() {
        _isActionRunning = true;
        _progress = 0.2;
        _statusText = 'Validating and restoring backup...';
      });
      AppHaptics.mediumTap();

      final chats = backupData['chats'] as List? ?? [];
      final groups = backupData['groups'] as List? ?? [];
      final chatMessages = backupData['chatMessages'] as Map? ?? {};
      final groupMessages = backupData['groupMessages'] as Map? ?? {};

      int restoredMsgs = 0;

      for (final chatItem in chats) {
        final id = chatItem['id'] as String;
        final data = Map<String, dynamic>.from(ChatBackupService.parseDecoded(chatItem['data']) as Map);
        await FirebaseService.firestore.collection('chats').doc(id).set(data, SetOptions(merge: true));

        final list = chatMessages[id] as List? ?? [];
        for (final mItem in list) {
          final mId = mItem['id'] as String;
          final mData = Map<String, dynamic>.from(ChatBackupService.parseDecoded(mItem['data']) as Map);
          await FirebaseService.firestore.collection('chats').doc(id).collection('messages').doc(mId).set(mData, SetOptions(merge: true));
          restoredMsgs++;
        }
      }

      for (final groupItem in groups) {
        final id = groupItem['id'] as String;
        final data = Map<String, dynamic>.from(ChatBackupService.parseDecoded(groupItem['data']) as Map);
        await FirebaseService.firestore.collection('groups').doc(id).set(data, SetOptions(merge: true));

        final list = groupMessages[id] as List? ?? [];
        for (final mItem in list) {
          final mId = mItem['id'] as String;
          final mData = Map<String, dynamic>.from(ChatBackupService.parseDecoded(mItem['data']) as Map);
          await FirebaseService.firestore.collection('groups').doc(id).collection('messages').doc(mId).set(mData, SetOptions(merge: true));
          restoredMsgs++;
        }
      }

      setState(() {
        _progress = 1.0;
        _statusText = 'Restored $restoredMsgs messages successfully!';
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

  Future<void> _restoreBackup(Map<String, dynamic> metadata, String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isActionRunning = true;
      _progress = 0.3;
      _statusText = 'Downloading and restoring backup archive...';
    });
    AppHaptics.mediumTap();

    try {
      await ChatBackupService.performRestore(uid, url);

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
        title: Text(L10n.s(ref, 'chatBackup'), style: AppTextStyles.headingSmall),
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
                      Icon(Icons.shield_outlined, color: AppColors.aquaCore, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Encrypted Archive Manager',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Create encrypted backup files of your chats, media references, and groups. Export directly to device storage or cloud snapshots.',
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
                    // Backup buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _backupChats,
                              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                              label: const Text('Cloud Snapshot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.aquaCore,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _exportLocalBackup,
                              icon: const Icon(Icons.file_upload_outlined, color: AppColors.aquaCore, size: 18),
                              label: const Text('Export .rpbk', style: TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.aquaCore),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _restoreFromLocalFile,
                        icon: const Icon(Icons.restore_page_rounded, color: Colors.white70, size: 18),
                        label: const Text('Restore from Local File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (uid != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseService.usersCollection.doc(uid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  
                  final userData = snapshot.data!.data() ?? {};
                  final String backupEmail = userData['backupEmail'] as String? ?? userData['email'] as String? ?? '';
                  final String autoFrequency = userData['autoBackupFrequency'] as String? ?? 'Off';

                  return GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.settings_suggest_rounded, color: AppColors.aquaCore, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Auto Backup Settings',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            const Icon(Icons.email_rounded, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Recovery Email', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(backupEmail.isEmpty ? 'None added' : backupEmail, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: AppColors.aquaCore, size: 20),
                              onPressed: () {
                                AppHaptics.mediumTap();
                                final controller = TextEditingController(text: backupEmail);
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF0F172A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(color: AppColors.glassBorder),
                                    ),
                                    title: const Text('Update Recovery Email', style: TextStyle(color: Colors.white)),
                                    content: TextField(
                                      controller: controller,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        labelText: 'Recovery Email',
                                        labelStyle: TextStyle(color: Colors.white54),
                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.aquaCore)),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaCore),
                                        onPressed: () async {
                                          await FirebaseService.usersCollection.doc(uid).update({
                                            'backupEmail': controller.text.trim(),
                                          });
                                          if (context.mounted) Navigator.pop(context);
                                        },
                                        child: const Text('Save', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        
                        Row(
                          children: [
                            const Icon(Icons.autorenew_rounded, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Backup Frequency', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 2),
                                  Text('Automatically save snapshots', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ),
                            DropdownButton<String>(
                              value: autoFrequency,
                              dropdownColor: const Color(0xFF0F172A),
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.aquaCore),
                              underline: const SizedBox.shrink(),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              items: ['Off', 'Daily', 'Weekly', 'Monthly'].map((val) {
                                return DropdownMenuItem<String>(
                                  value: val,
                                  child: Text(val),
                                );
                              }).toList(),
                              onChanged: (newVal) async {
                                if (newVal != null) {
                                  AppHaptics.selectionTick();
                                  await FirebaseService.usersCollection.doc(uid).update({
                                    'autoBackupFrequency': newVal,
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
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
                          'No backups saved yet.\nTap "Cloud Snapshot" to create your first restore point.',
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
