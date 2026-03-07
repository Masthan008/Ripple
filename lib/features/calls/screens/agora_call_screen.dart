import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/env.dart';

/// Agora-powered video/audio call screen
/// Replaces ZegoCloud (which had irresolvable SDK build errors)
class AgoraCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String currentUserId;
  final String currentUserName;
  final String otherUserName;
  final String? otherUserId; // needed to send call notification
  final bool isVideo;
  final bool isGroup;

  const AgoraCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherUserName,
    this.otherUserId,
    this.isVideo = true,
    this.isGroup = false,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  int? _remoteUid;
  bool _isInitialized = false;
  String? _errorMessage;

  // Timer state — only starts counting when remote user joins
  final Stopwatch _callStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initAgora();
    _sendCallNotification();
  }

  /// Send push notification to the callee so they know about the call
  Future<void> _sendCallNotification() async {
    if (widget.otherUserId == null || widget.otherUserId!.isEmpty) return;
    if (widget.isGroup) return; // Group call notifications handled separately

    try {
      // Fetch callee's OneSignal player ID
      final userDoc = await FirebaseService.usersCollection
          .doc(widget.otherUserId)
          .get();
      final playerId =
          userDoc.data()?['oneSignalPlayerId'] as String? ?? '';
      if (playerId.isEmpty) return;

      await NotificationService.sendCallNotification(
        recipientPlayerId: playerId,
        callerName: widget.currentUserName,
        callId: widget.callId,
        callType: widget.isVideo ? 'video' : 'audio',
        isGroup: widget.isGroup,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to send call notification: $e');
    }
  }

  Future<void> _initAgora() async {
    // Request permissions (skip on web — browser handles it natively)
    try {
      if (widget.isVideo) {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        debugPrint('📸 Camera: $cameraStatus, 🎤 Mic: $micStatus');
      } else {
        await Permission.microphone.request();
      }
    } catch (_) {
      // permission_handler not available on web — that's OK,
      // browser will prompt natively when Agora accesses camera/mic
    }

    final appId = Env.agoraAppId;
    if (appId.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage =
            'Agora App ID not configured.\nAdd AGORA_APP_ID to your .env file.\n\nGet a free App ID at console.agora.io');
      }
      return;
    }

    // Create Agora engine
    try {
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Set up event handlers
      _engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('✅ Joined channel successfully');
          if (mounted) setState(() => _localUserJoined = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('✅ Remote user joined: $remoteUid');
          if (mounted) {
            setState(() => _remoteUid = remoteUid);
            // Start the call timer ONLY when remote user joins
            _callStopwatch.start();
          }

          // Update call status to 'connected'
          FirebaseService.firestore
              .collection('calls')
              .doc(widget.callId)
              .update({'status': 'connected'}).catchError((_) {});
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('📴 Remote user left: $remoteUid');
          if (mounted) {
            setState(() => _remoteUid = null);
            _callStopwatch.stop();
          }
          _endCall();
        },
        onError: (err, msg) {
          debugPrint('❌ Agora error: $err — $msg');
        },
      ));

      if (widget.isVideo) {
        await _engine.enableVideo();
        await _engine.startPreview();
      } else {
        await _engine.disableVideo();
      }

      await _engine.enableAudio();

      if (mounted) setState(() => _isInitialized = true);

      // Join channel — token empty for testing mode
      await _engine.joinChannel(
        token: '',
        channelId: widget.channelName,
        uid: 0,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.isVideo,
          publishCameraTrack: widget.isVideo,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      // Set speakerphone AFTER joining channel (error -3 if called before)
      try {
        await _engine.setEnableSpeakerphone(widget.isVideo);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start call.\n$e');
      }
    }
  }

  Future<void> _endCall() async {
    _callStopwatch.stop();

    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (_) {}

    try {
      await FirebaseService.firestore
          .collection('calls')
          .doc(widget.callId)
          .update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'duration': _callStopwatch.elapsed.inSeconds,
      });
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _engine.muteLocalVideoStream(_isCameraOff);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  void _switchCamera() {
    _engine.switchCamera();
  }

  @override
  void dispose() {
    _callStopwatch.stop();
    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (_) {}
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Show error if Agora is not configured
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.abyssBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Call', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.abyssBackground,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (widget.isVideo && _remoteUid != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            )
          else
            // Audio call or waiting screen
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF0EA5E9),
                    child: Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _remoteUid != null
                        ? (widget.isVideo ? 'Video Call' : 'Voice Call')
                        : 'Calling...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          // Local video preview (small pip)
          if (widget.isVideo && _localUserJoined && !_isCameraOff)
            Positioned(
              top: 60,
              right: 16,
              width: 100,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),

          // Call timer — only shows elapsed time since remote user joined
          Positioned(
            top: 52,
            left: 0,
            right: 0,
            child: Center(
              child: _CallTimer(
                stopwatch: _callStopwatch,
                isConnected: _remoteUid != null,
              ),
            ),
          ),

          // Control buttons
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: _isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onTap: _toggleMute,
                    isActive: _isMuted,
                  ),
                  if (widget.isVideo)
                    _CallButton(
                      icon: _isCameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      label: _isCameraOff ? 'Cam On' : 'Cam Off',
                      onTap: _toggleCamera,
                      isActive: _isCameraOff,
                    ),
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    onTap: _endCall,
                    isEndCall: true,
                  ),
                  _CallButton(
                    icon: _isSpeakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    label: 'Speaker',
                    onTap: _toggleSpeaker,
                    isActive: !_isSpeakerOn,
                  ),
                  if (widget.isVideo)
                    _CallButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Flip',
                      onTap: _switchCamera,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timer widget — only counts when call is connected ──
class _CallTimer extends StatelessWidget {
  final Stopwatch stopwatch;
  final bool isConnected;

  const _CallTimer({
    required this.stopwatch,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    if (!isConnected) {
      return const Text(
        '00:00',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i + 1),
      builder: (context, snap) {
        final elapsed = stopwatch.elapsed;
        final m = elapsed.inMinutes.toString().padLeft(2, '0');
        final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          '$m:$s',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

// ── Control button ──
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isEndCall;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isEndCall
                  ? const Color(0xFFEF4444)
                  : isActive
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              boxShadow: isEndCall
                  ? [
                      BoxShadow(
                        color:
                            const Color(0xFFEF4444).withValues(alpha: 0.4),
                        blurRadius: 16,
                      )
                    ]
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
