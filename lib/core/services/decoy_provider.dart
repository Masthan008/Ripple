import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track whether the app is currently running in Decoy Mode.
/// If true, the app replaces active Firestore streams with simulated chats.
final decoyModeProvider = StateProvider<bool>((ref) => false);
