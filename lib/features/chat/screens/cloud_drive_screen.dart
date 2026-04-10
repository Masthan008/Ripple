import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../shared/widgets/glass_card.dart';

class CloudDriveScreen extends ConsumerStatefulWidget {
  const CloudDriveScreen({super.key});

  @override
  ConsumerState<CloudDriveScreen> createState() => _CloudDriveScreenState();
}

class _CloudDriveScreenState extends ConsumerState<CloudDriveScreen> {
  bool _isUploading = false;

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    setState(() => _isUploading = true);
    AppHaptics.mediumTap();

    try {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      final url = await SupabaseService.uploadFile(file, uniqueName);
      if (url != null) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseService.firestore
            .collection('user_files')
            .doc(uid)
            .collection('files')
            .add({
              'name': fileName,
              'url': url,
              'size': result.files.single.size,
              'type': result.files.single.extension,
              'createdAt': FieldValue.serverTimestamp(),
            });
        AppHaptics.success();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Cloud Drive', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
        actions: [
          if (_isUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.upload_file_rounded,
                color: AppColors.aquaCore,
              ),
              onPressed: _uploadFile,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseService.firestore
                .collection('user_files')
                .doc(uid)
                .collection('files')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = snapshot.data!.docs;
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: Colors.white12,
                  ),
                  const SizedBox(height: 16),
                  Text('Your drive is empty', style: AppTextStyles.bodySmall),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final data = files[index].data() as Map<String, dynamic>;
              final name = data['name'] as String;
              final url = data['url'] as String;
              final type = data['type'] as String? ?? 'file';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  onTap: () => _openFile(url, name),
                  child: ListTile(
                    leading: _getFileIcon(type),
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Added ${_formatDate(data['createdAt'] as Timestamp?)}',
                      style: AppTextStyles.caption,
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white24,
                      ),
                      onPressed: () => files[index].reference.delete(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getFileIcon(String type) {
    IconData icon = Icons.insert_drive_file_rounded;
    Color color = Colors.white54;

    if (['jpg', 'jpeg', 'png', 'gif'].contains(type.toLowerCase())) {
      icon = Icons.image_rounded;
      color = Colors.blue;
    } else if (type.toLowerCase() == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.red;
    } else if (['mp4', 'mov', 'avi'].contains(type.toLowerCase())) {
      icon = Icons.video_library_rounded;
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _openFile(String url, String fileName) async {
    // Open in browser or download and open
    // For simplicity, just opening browser
    OpenFilex.open(url);
  }
}
