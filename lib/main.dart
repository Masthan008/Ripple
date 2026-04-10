import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/utils/env.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'features/chat/services/schedule_service.dart';
import 'app.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter-level errors
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('🔴 Flutter Error: ${details.exception}');
        debugPrint('Stack trace: ${details.stack}');
      };

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
        if (Env.supabaseUrl.isNotEmpty &&
            (Env.supabaseAnonKey.isNotEmpty ||
                Env.supabaseServiceRoleKey.isNotEmpty)) {
          await SupabaseService.initialize();
        } else {
          debugPrint(
            '⚠️ Supabase credentials missing — skipping initialization',
          );
        }

        // ── OneSignal MUST be initialized before runApp() ──
        final oneSignalId = Env.oneSignalAppId;
        if (oneSignalId.isEmpty) {
          debugPrint(
            '❌ ONESIGNAL_APP_ID is missing or empty from .env! Skipping OneSignal init.',
          );
        } else {
          debugPrint('✅ OneSignal ID loaded: $oneSignalId');
          OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
          OneSignal.initialize(oneSignalId);
          OneSignal.consentRequired(false);
          OneSignal.consentGiven(true);

          // Requesting permission is async and shouldn't block app launch
          // On some devices, awaiting this before runApp() can cause issues
          OneSignal.Notifications.requestPermission(true)
              .then((_) {
                debugPrint('🔔 OneSignal permission requested successfully');
              })
              .catchError((e) {
                debugPrint('⚠️ OneSignal permission error: $e');
              });
        }

        // Initialize local notification channels
        await NotificationService.initialize();

        // Start scheduled message checker (every 30s)
        ScheduleService.startScheduleChecker();

        // Restore screenshot block setting
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('screenshot_block') ?? false) {
          await FlutterWindowManagerPlus.addFlags(
            FlutterWindowManagerPlus.FLAG_SECURE,
          );
        }
      } catch (e, stack) {
        debugPrint('⚠️ Initialization error: $e');
        debugPrint('$stack');
        runApp(
          MaterialApp(
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
          ),
        );
        return;
      }

      // Note: AppLifecycleObserver is now registered in HomeScreen
      // with the user's UID after login (requires PresenceService)

      runApp(const ProviderScope(child: App()));
    },
    (error, stack) {
      debugPrint('🔴 Global Async Error: $error');
      debugPrint('Stack trace: $stack');
    },
  );
}
