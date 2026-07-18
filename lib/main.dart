import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/utils/env.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'features/chat/services/schedule_service.dart';
import 'features/challenges/services/challenges_service.dart';
import 'features/gifts/services/gift_service.dart';
import 'app.dart';

/// Splash shown immediately if core initialization takes too long,
/// preventing the black-screen / ANR issue on slow devices.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF060D1A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF060D1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color(0xFF0EA5E9),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ripple',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter-level errors and forward to Crashlytics
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
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

      // Show splash immediately, then proceed with init — prevents black screen
      runApp(const _SplashApp());

      try {
        // Load environment variables
        await Env.load();

        // Initialize Firebase (core init only — Firestore/FCM used later)
        await FirebaseService.initialize();

        // Initialize Supabase (for file storage)
        if (Env.supabaseUrl.isNotEmpty &&
            (Env.supabaseAnonKey.isNotEmpty ||
                Env.supabaseServiceRoleKey.isNotEmpty)) {
          await SupabaseService.initialize();
        }

        // ── OneSignal ──
        final oneSignalId = Env.oneSignalAppId;
        if (oneSignalId.isNotEmpty) {
          assert(() {
            OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
            return true;
          }());
          OneSignal.initialize(oneSignalId);
          OneSignal.consentRequired(false);
          OneSignal.consentGiven(true);
          OneSignal.Notifications.requestPermission(true).catchError((_) => false);
        }

        // Initialize local notification channels
        await NotificationService.initialize();

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

      // Launch the real app — splash replaced instantly
      runApp(const ProviderScope(child: App()));

      // Non-critical initialisation — runs after the UI is visible
      ScheduleService.startScheduleChecker();
      ChallengesService.initializeWeeklyChallenges().catchError((_) {});
      GiftService.initializeGiftCards().catchError((_) {});
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    },
  );
}
