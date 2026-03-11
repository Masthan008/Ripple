import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/daily_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';

/// Daily.co-powered video/audio call screen using WebView.
/// Same constructor interface for drop-in replacement.
class DailyCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String currentUserId;
  final String currentUserName;
  final String otherUserName;
  final String? otherUserId;
  final bool isVideo;
  final bool isGroup;

  const DailyCallScreen({
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
  State<DailyCallScreen> createState() => _DailyCallScreenState();
}

class _DailyCallScreenState extends State<DailyCallScreen> {
  WebViewController? _webController;
  bool _isLoading = true;
  bool _isConnected = false;
  String? _errorMessage;
  final Stopwatch _callStopwatch = Stopwatch();
  Timer? _timeoutTimer;

  // Local control state (visual only — WebView handles actual mute/cam)
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initCall();
    _sendCallNotification();
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.camera,
        Permission.microphone,
      ].request();
    } catch (_) {}
  }

  Future<void> _sendCallNotification() async {
    if (widget.otherUserId == null || widget.otherUserId!.isEmpty) return;
    if (widget.isGroup) return;

    try {
      final userDoc = await FirebaseService.usersCollection
          .doc(widget.otherUserId)
          .get();
      final playerId =
          userDoc.data()?['oneSignalPlayerId'] as String? ?? '';
      if (playerId.isEmpty) return;

      await NotificationService.sendCallNotification(
        recipientPlayerId: playerId,
        callerName: widget.currentUserName,
        callerUserId: widget.currentUserId,
        callId: widget.callId,
        channelName: widget.channelName,
        callType: widget.isVideo ? 'video' : 'audio',
        isGroup: widget.isGroup,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to send call notification: $e');
    }
  }

  Future<void> _initCall() async {
    try {
      // Create or join the Daily.co room
      final roomUrl = await DailyService.createRoom(widget.channelName);
      if (roomUrl == null) {
        if (mounted) {
          setState(() => _errorMessage =
              'Failed to create video room.\n\n'
              'Make sure DAILY_API_KEY is set in your .env file.\n'
              'Get your key at dashboard.daily.co');
        }
        return;
      }

      // Build the WebView URL with user name parameter
      final userName = Uri.encodeComponent(widget.currentUserName);
      final joinUrl = '$roomUrl?t=${widget.currentUserName}';

      // Create WebView controller
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.abyssBackground)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted) {
                setState(() => _isLoading = false);
                // Inject JS to customize Daily.co prebuilt UI
                _injectCustomizations();
              }
            },
            onWebResourceError: (error) {
              debugPrint('❌ WebView error: ${error.description}');
            },
          ),
        )
        ..addJavaScriptChannel(
          'FlutterCallChannel',
          onMessageReceived: (message) {
            _handleJsMessage(message.message);
          },
        )
        ..loadRequest(Uri.parse(joinUrl));

      if (mounted) {
        setState(() => _webController = controller);
      }

      // Start timeout timer — if no one joins in 30 seconds
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && !_isConnected) {
          debugPrint('⏰ Call timed out — no answer in 30s');
          _endCall(status: 'missed');
        }
      });

      // Listen for call status changes in Firestore
      FirebaseService.firestore
          .collection('calls')
          .doc(widget.callId)
          .snapshots()
          .listen((snap) {
        final status = snap.data()?['status'];
        if (status == 'connected' && !_isConnected) {
          if (mounted) {
            setState(() => _isConnected = true);
            _callStopwatch.start();
            _timeoutTimer?.cancel();
          }
        } else if (status == 'ended' || status == 'declined') {
          if (mounted) Navigator.of(context).pop();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start call.\n$e');
      }
    }
  }

  void _handleJsMessage(String message) {
    // Handle messages from Daily.co JS
    if (message == 'participant-joined') {
      if (!_isConnected && mounted) {
        setState(() => _isConnected = true);
        _callStopwatch.start();
        _timeoutTimer?.cancel();

        FirebaseService.firestore
            .collection('calls')
            .doc(widget.callId)
            .update({'status': 'connected'}).catchError((_) {});
      }
    } else if (message == 'left-meeting' || message == 'call-ended') {
      _endCall();
    }
  }

  void _injectCustomizations() {
    // Inject JS to detect participant join/leave and notify Flutter
    _webController?.runJavaScript('''
      (function() {
        // Attempt to hook into Daily.co events
        if (window.callFrame) {
          window.callFrame.on('participant-joined', function(e) {
            if (e && e.participant && !e.participant.local) {
              FlutterCallChannel.postMessage('participant-joined');
            }
          });
          window.callFrame.on('left-meeting', function() {
            FlutterCallChannel.postMessage('left-meeting');
          });
        }
        
        // Periodic check - if no Daily.co API, use MutationObserver
        var checkJoined = setInterval(function() {
          var videos = document.querySelectorAll('video');
          if (videos.length > 1) {
            FlutterCallChannel.postMessage('participant-joined');
            clearInterval(checkJoined);
          }
        }, 2000);
        
        // Auto-clear after 60s
        setTimeout(function() { clearInterval(checkJoined); }, 60000);
      })();
    ''');
  }

  Future<void> _endCall({String status = 'ended'}) async {
    _callStopwatch.stop();
    _timeoutTimer?.cancel();

    // Leave the Daily.co call
    try {
      _webController?.runJavaScript(
          'if(window.callFrame) window.callFrame.leave();');
    } catch (_) {}

    // Update Firestore
    try {
      await FirebaseService.firestore
          .collection('calls')
          .doc(widget.callId)
          .update({
        'status': status,
        'endedAt': FieldValue.serverTimestamp(),
        'duration': _callStopwatch.elapsed.inSeconds,
      });
    } catch (_) {}

    // Clean up room
    DailyService.deleteRoom(widget.channelName);

    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _webController?.runJavaScript(
        'if(window.callFrame) window.callFrame.setLocalAudio(${!_isMuted});');
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _webController?.runJavaScript(
        'if(window.callFrame) window.callFrame.setLocalVideo(${!_isCameraOff});');
  }

  @override
  void dispose() {
    _callStopwatch.stop();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Error state
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white54, size: 64),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          // WebView — Daily.co call
          if (_webController != null)
            WebViewWidget(controller: _webController!)
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
              ),
            ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: AppColors.abyssBackground,
              child: Center(
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
                      'Connecting...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
                    ),
                  ],
                ),
              ),
            ),

          // Call timer
          Positioned(
            top: 52,
            left: 0,
            right: 0,
            child: Center(
              child: _CallTimer(
                stopwatch: _callStopwatch,
                isConnected: _isConnected,
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Calling...',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i + 1),
      builder: (context, snap) {
        final elapsed = stopwatch.elapsed;
        final m = elapsed.inMinutes.toString().padLeft(2, '0');
        final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$m:$s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                        color: const Color(0xFFEF4444)
                            .withValues(alpha: 0.4),
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
