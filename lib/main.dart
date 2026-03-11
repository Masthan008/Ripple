import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'core/utils/env.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'features/chat/services/schedule_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark ocean theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF060D1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    // Load environment variables
    await Env.load();

    // Initialize Firebase
    await FirebaseService.initialize();

    // Initialize Supabase (for file storage)
    await SupabaseService.initialize();

    // ── OneSignal MUST be initialized before runApp() ──
    final oneSignalId = Env.oneSignalAppId;
    if (oneSignalId.isEmpty) {
      debugPrint('❌ ONESIGNAL_APP_ID is missing or empty from .env!');
    } else {
      debugPrint('✅ OneSignal ID loaded: $oneSignalId');
    }

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalId);
    OneSignal.consentRequired(false);
    OneSignal.consentGiven(true);

    debugPrint('🔔 OneSignal initialized, requesting permission...');
    await OneSignal.Notifications.requestPermission(true);
    debugPrint('🔔 OneSignal permission requested successfully');

    // Initialize local notification channels
    await NotificationService.initialize();

    // Start scheduled message checker (every 30s)
    ScheduleService.startScheduleChecker();
  } catch (e, stack) {
    debugPrint('⚠️ Initialization error: $e');
    debugPrint('$stack');
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF060D1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Initialization Error:\n$e',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // Note: AppLifecycleObserver is now registered in HomeScreen
  // with the user's UID after login (requires PresenceService)

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
