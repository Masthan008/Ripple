import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Chronos Unlock Service — Contextual Time-Capsules™
///
/// Monitors real-world device conditions (battery level, location,
/// time, weather-proxy) and unlocks chronos-locked messages when
/// the recipient's device meets the sender's specified criteria.
///
/// Supported unlock condition types:
/// - **battery** — Unlocks when battery drops below a threshold
/// - **time** — Unlocks at a specific date/time
/// - **location** — Unlocks within a radius of a GPS coordinate
/// - **shake** — Unlocks when the user shakes their device
///
/// All sensor data is processed locally — nothing is transmitted.
class ChronosUnlockService {
  ChronosUnlockService._();
  static final ChronosUnlockService instance = ChronosUnlockService._();

  final Battery _battery = Battery();
  Timer? _pollingTimer;

  // Condition display helpers
  static const Map<String, IconData> conditionIcons = {
    'battery': Icons.battery_alert_rounded,
    'time': Icons.access_time_rounded,
    'location': Icons.location_on_rounded,
    'shake': Icons.vibration_rounded,
  };

  static const Map<String, String> conditionLabels = {
    'battery': 'Battery Level',
    'time': 'Scheduled Time',
    'location': 'Location Arrival',
    'shake': 'Shake to Unlock',
  };

  /// Start monitoring conditions for locked messages in a chat.
  /// Polls every 10 seconds to check if any conditions are met.
  void startMonitoring({
    required String chatId,
    required String currentUid,
    required bool isGroup,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkAndUnlock(
        chatId: chatId,
        currentUid: currentUid,
        isGroup: isGroup,
      ),
    );
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Check all locked messages and unlock any that meet conditions.
  Future<void> _checkAndUnlock({
    required String chatId,
    required String currentUid,
    required bool isGroup,
  }) async {
    try {
      final collection = isGroup ? 'groups' : 'chats';
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .doc(chatId)
          .collection('messages')
          .where('isChronosLocked', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Don't unlock your own messages — they're visible to sender
        if (data['senderId'] == currentUid) continue;

        final type = data['chronosConditionType'] as String?;
        final value = data['chronosConditionValue'] as String?;

        if (type == null || value == null) continue;

        final shouldUnlock = await _evaluateCondition(type, value);
        if (shouldUnlock) {
          await doc.reference.update({'isChronosLocked': false});
          debugPrint('⏳ Chronos unlocked message: ${doc.id}');
        }
      }
    } catch (e) {
      debugPrint('⏳ Chronos check error: $e');
    }
  }

  /// Evaluate a single condition against current device state.
  Future<bool> _evaluateCondition(String type, String value) async {
    switch (type) {
      case 'battery':
        return _checkBattery(value);
      case 'time':
        return _checkTime(value);
      case 'location':
        return _checkLocation(value);
      case 'shake':
        // Shake is handled by the UI widget, not by polling
        return false;
      default:
        return false;
    }
  }

  /// Check if battery is at or below the specified percentage.
  Future<bool> _checkBattery(String value) async {
    try {
      final threshold = int.tryParse(value) ?? 0;
      final level = await _battery.batteryLevel;
      return level <= threshold;
    } catch (e) {
      return false;
    }
  }

  /// Check if the current time has passed the specified timestamp.
  bool _checkTime(String value) {
    try {
      final targetTime = DateTime.tryParse(value);
      if (targetTime == null) return false;
      return DateTime.now().isAfter(targetTime);
    } catch (e) {
      return false;
    }
  }

  /// Check if user is within 200m radius of the target location.
  Future<bool> _checkLocation(String value) async {
    try {
      // Value format: "lat,lng"
      final parts = value.split(',');
      if (parts.length != 2) return false;

      final targetLat = double.tryParse(parts[0].trim());
      final targetLng = double.tryParse(parts[1].trim());
      if (targetLat == null || targetLng == null) return false;

      // Check permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      // Unlock within 200 meters
      return distance <= 200;
    } catch (e) {
      return false;
    }
  }

  /// Format condition for display in the locked bubble.
  static String formatCondition(String type, String value) {
    switch (type) {
      case 'battery':
        return 'Opens when battery ≤ $value%';
      case 'time':
        final dt = DateTime.tryParse(value);
        if (dt != null) {
          final h = dt.hour.toString().padLeft(2, '0');
          final m = dt.minute.toString().padLeft(2, '0');
          return 'Opens at $h:$m';
        }
        return 'Opens at scheduled time';
      case 'location':
        return 'Opens when you arrive';
      case 'shake':
        return 'Shake your phone to open';
      default:
        return 'Locked';
    }
  }
}
