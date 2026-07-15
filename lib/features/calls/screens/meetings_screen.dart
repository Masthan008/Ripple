import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/daily_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  final _titleCtrl = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(minutes: 30));
  bool _isVideo = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _scheduleMeeting() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting title')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final user = ref.read(currentUserProvider).value;
    final hostName = user?.name ?? 'Host';

    AppHaptics.mediumTap();

    try {
      await FirebaseService.firestore.collection('meetings').add({
        'title': title,
        'scheduledAt': Timestamp.fromDate(_selectedDateTime),
        'hostUid': uid,
        'hostName': hostName,
        'isVideo': _isVideo,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [uid],
      });

      _titleCtrl.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting scheduled successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule meeting: $e')),
        );
      }
    }
  }

  void _showScheduleBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule a Meeting',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Meeting Title',
                      labelStyle: const TextStyle(color: Colors.white60),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.aquaCore),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Time: ${_selectedDateTime.toString().split('.').first}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await _selectDateTime(ctx);
                          setModalState(() {});
                        },
                        child: const Text('Change Time',
                            style: TextStyle(color: AppColors.aquaCore)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Camera (Video)',
                        style: TextStyle(color: Colors.white)),
                    value: _isVideo,
                    activeColor: AppColors.aquaCore,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setModalState(() {
                        _isVideo = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _scheduleMeeting,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.aquaCore,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Schedule',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startOrJoinMeeting(String meetingId, bool isVideo) async {
    AppHaptics.mediumTap();
    // Use meeting ID as the daily room name
    final roomUrl = await DailyService.createRoom(meetingId);
    if (roomUrl != null && mounted) {
      context.push(
          '/daily-call?roomUrl=${Uri.encodeComponent(roomUrl)}&callId=$meetingId&isVideo=$isVideo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Scheduled Meetings', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.aquaCore),
            onPressed: _showScheduleBottomSheet,
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please log in', style: TextStyle(color: Colors.white70)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.firestore
                  .collection('meetings')
                  .orderBy('scheduledAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white54)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.aquaCore));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No meetings scheduled.\nTap the + button to create one.',
                      style: TextStyle(color: Colors.white54, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final meetingId = doc.id;
                    final title = data['title'] as String? ?? 'Meeting';
                    final isHost = data['hostUid'] == uid;
                    final hostName = data['hostName'] as String? ?? 'Host';
                    final isVideo = data['isVideo'] as bool? ?? true;
                    final scheduledTimestamp = data['scheduledAt'] as Timestamp?;
                    final scheduledAt = scheduledTimestamp?.toDate();
                    final formattedTime = scheduledAt != null
                        ? scheduledAt.toString().split('.').first
                        : 'N/A';

                    final inviteLink = 'ripple://meeting/$meetingId';

                    return GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.aquaCore.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isVideo
                                      ? Icons.video_call_rounded
                                      : Icons.call_rounded,
                                  color: AppColors.aquaCore,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hosted by $hostName',
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (isHost)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    doc.reference.delete();
                                    AppHaptics.mediumTap();
                                  },
                                ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 20),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: Colors.white38, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: inviteLink));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Invite link copied to clipboard!')),
                                    );
                                    AppHaptics.lightTap();
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Invite Link',
                                      style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _startOrJoinMeeting(meetingId, isVideo),
                                  icon: const Icon(Icons.play_arrow_rounded,
                                      size: 16),
                                  label: Text(isHost ? 'Start' : 'Join',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.aquaCore,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
