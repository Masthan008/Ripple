import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/daily_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';

/// Daily.co-powered video/audio call screen using InAppWebView.
/// InAppWebView supports camera/mic permissions natively on Android.
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
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isEnding = false;
  String? _errorMessage;

  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _timeoutTimer;
  StreamSubscription? _callStatusSub;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initCall();
    _sendCallNotification();
  }

  Future<void> _requestPermissions() async {
    try {
      await [Permission.camera, Permission.microphone].request();
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

      if (mounted) setState(() {}); // trigger build with URL ready

      // Start timeout — 90 seconds to connect
      _timeoutTimer = Timer(const Duration(seconds: 90), () {
        if (mounted && !_isConnected) {
          _endCall(status: 'missed');
        }
      });

      // Listen for call status changes in Firestore
      _callStatusSub = FirebaseService.firestore
          .collection('calls')
          .doc(widget.callId)
          .snapshots()
          .listen((snap) {
        final status = snap.data()?['status'];
        if (status == 'connected' && !_isConnected) {
          _onCallConnected();
        } else if (status == 'ended' || status == 'declined') {
          if (mounted && !_isEnding) Navigator.of(context).pop();
        }
      });

      // Store room URL for the build method
      _roomUrl = roomUrl;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start call.\n$e');
      }
    }
  }

  String? _roomUrl;

  /// Build the Daily.co URL with params that control their UI
  String _buildDailyUrl() {
    final params = <String, String>{
      'showLeaveButton': 'false',
      'showFullscreenButton': 'false',
      'skipMediaPermissionPrompt': 'true',
    };

    final query =
        params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$_roomUrl?$query';
  }

  void _onCallConnected() {
    if (_isConnected || !mounted) return;
    setState(() => _isConnected = true);
    _timeoutTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });

    // Update Firestore
    FirebaseService.firestore
        .collection('calls')
        .doc(widget.callId)
        .update({'status': 'connected'}).catchError((_) {});
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall({String status = 'ended'}) async {
    if (_isEnding) return;
    _isEnding = true;
    _durationTimer?.cancel();
    _timeoutTimer?.cancel();
    _callStatusSub?.cancel();

    // Leave Daily.co room via JS
    try {
      await _webViewController?.evaluateJavascript(source: '''
        try {
          if (window.callFrame) window.callFrame.leave();
        } catch(e) {}
      ''');
    } catch (_) {}

    // Update Firestore
    try {
      await FirebaseService.firestore
          .collection('calls')
          .doc(widget.callId)
          .update({
        'status': status,
        'endedAt': FieldValue.serverTimestamp(),
        'duration': _callDuration.inSeconds,
      });
    } catch (_) {}

    DailyService.deleteRoom(widget.channelName);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _timeoutTimer?.cancel();
    _callStatusSub?.cancel();
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
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: Stack(
          children: [
            // ── INAPPWEBVIEW — fullscreen ──────────────────
            if (_roomUrl != null)
              Positioned.fill(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_buildDailyUrl()),
                  ),
                  initialSettings: InAppWebViewSettings(
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    javaScriptEnabled: true,
                    allowsBackForwardNavigationGestures: false,
                    supportZoom: false,
                    useHybridComposition: true,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    hardwareAcceleration: true,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    transparentBackground: false,
                    disableContextMenu: true,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;

                    // JS -> Flutter: call connected
                    controller.addJavaScriptHandler(
                      handlerName: 'onCallJoined',
                      callback: (_) => _onCallConnected(),
                    );

                    // JS -> Flutter: call ended
                    controller.addJavaScriptHandler(
                      handlerName: 'onCallLeft',
                      callback: (_) => _endCall(),
                    );
                  },
                  onLoadStart: (_, __) {
                    if (mounted) setState(() => _isLoading = true);
                  },
                  onLoadStop: (controller, _) async {
                    if (mounted) setState(() => _isLoading = false);

                    // Inject JS to detect Daily.co events
                    await controller.evaluateJavascript(source: '''
                      (function() {
                        let attempts = 0;
                        const watchFrame = setInterval(function() {
                          attempts++;
                          if (attempts > 60) {
                            clearInterval(watchFrame);
                            return;
                          }

                          // Listen for Daily.co postMessage events
                          window.addEventListener('message', function(e) {
                            if (!e.data || !e.data.action) return;
                            const action = e.data.action;

                            if (action === 'joined-meeting' ||
                                action === 'participant-joined') {
                              window.flutter_inappwebview
                                .callHandler('onCallJoined');
                            }

                            if (action === 'left-meeting' ||
                                action === 'error') {
                              window.flutter_inappwebview
                                .callHandler('onCallLeft');
                            }
                          });

                          // Also detect via video elements
                          const videos = document.querySelectorAll('video');
                          if (videos.length > 1) {
                            window.flutter_inappwebview
                              .callHandler('onCallJoined');
                            clearInterval(watchFrame);
                          }
                        }, 1500);
                      })();
                    ''');
                  },

                  // CRITICAL: Auto-grant WebView camera/mic permissions
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },

                  onConsoleMessage: (controller, message) {
                    debugPrint('WebView: ${message.message}');
                  },
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
                ),
              ),

            // ── LOADING OVERLAY ───────────────────────────
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF060D1A),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF0EA5E9),
                                Color(0xFF6366F1),
                              ],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFF1A2A40),
                            child: Text(
                              widget.otherUserName.isNotEmpty
                                  ? widget.otherUserName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 42,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.otherUserName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isVideo
                              ? '📹 Video Call'
                              : '📞 Voice Call',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF0EA5E9),
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Connecting...',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── STATUS PILL (top center) ──────────────────
            if (!_isLoading)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isConnected
                                  ? const Color(0xFF22C55E)
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isConnected
                                ? _formatDuration(_callDuration)
                                : 'Connecting...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── END CALL BUTTON (bottom right) ────────────
            if (!_isLoading)
              Positioned(
                bottom: 40,
                right: 20,
                child: GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
