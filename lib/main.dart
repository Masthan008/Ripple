import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/env.dart';
import 'core/services/firebase_service.dart';
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
  } catch (e, stack) {
    debugPrint('⚠️ Initialization error: $e');
    debugPrint('$stack');
    // Show error app instead of black screen
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

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

