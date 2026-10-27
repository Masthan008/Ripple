import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Application update states for the OTA cloud engine.
enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  restartRequired,
  error,
}

/// Metadata representation of an OTA patch.
class AppPatchInfo {
  final int? patchNumber;
  final bool isPatchActive;
  final String displayVersion;

  const AppPatchInfo({
    this.patchNumber,
    required this.isPatchActive,
    required this.displayVersion,
  });
}

/// Riverpod provider for the global OTA update manager.
final updateServiceProvider = ChangeNotifierProvider<UpdateService>((ref) {
  final service = UpdateService();
  service.initialize();
  return service;
});

/// High-performance, brand-neutral update manager for over-the-air patches.
class UpdateService extends ChangeNotifier {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  AppUpdateStatus _status = AppUpdateStatus.idle;
  AppUpdateStatus get status => _status;

  Patch? _currentPatch;
  Patch? get currentPatch => _currentPatch;

  Patch? _stagedPatch;
  Patch? get stagedPatch => _stagedPatch;

  DateTime? _lastCheckedTime;
  DateTime? get lastCheckedTime => _lastCheckedTime;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _autoCheckEnabled = true;
  bool get autoCheckEnabled => _autoCheckEnabled;

  bool _isInitialized = false;

  /// Returns whether the over-the-air updater engine is active on this device/build.
  bool get isUpdaterAvailable => _updater.isAvailable;

  /// Human-readable patch identifier.
  String get patchVersionString {
    if (_currentPatch != null) {
      return 'Patch #${_currentPatch!.number}';
    }
    return 'Base Engine';
  }

  /// Initialize the service, restore settings, and inspect current patch status.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCheckEnabled = prefs.getBool('ota_auto_check_enabled') ?? true;
      final lastCheckedMs = prefs.getInt('ota_last_checked_timestamp');
      if (lastCheckedMs != null) {
        _lastCheckedTime = DateTime.fromMillisecondsSinceEpoch(lastCheckedMs);
      }
    } catch (_) {}

    if (isUpdaterAvailable) {
      try {
        _currentPatch = await _updater.readCurrentPatch();
        _stagedPatch = await _updater.readNextPatch();
        if (_stagedPatch != null &&
            (_currentPatch == null || _stagedPatch!.number != _currentPatch!.number)) {
          _status = AppUpdateStatus.restartRequired;
        }
      } catch (e) {
        debugPrint('[UpdateEngine] Error inspecting local patch: $e');
      }
    }

    notifyListeners();

    // Perform silent background check if auto-check is enabled
    if (_autoCheckEnabled && isUpdaterAvailable && _status != AppUpdateStatus.restartRequired) {
      unawaited(silentBackgroundCheck());
    }
  }

  /// Toggle automatic background update checking.
  Future<void> setAutoCheckEnabled(bool enabled) async {
    _autoCheckEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ota_auto_check_enabled', enabled);
    } catch (_) {}
  }

  /// Non-intrusive background check that stages updates silently.
  Future<void> silentBackgroundCheck() async {
    if (!isUpdaterAvailable) return;
    try {
      final result = await _updater.checkForUpdate();
      _updateLastCheckedTimestamp();
      if (result == UpdateStatus.outdated) {
        // Download in background
        await _updater.update();
        _stagedPatch = await _updater.readNextPatch();
        _status = AppUpdateStatus.restartRequired;
        notifyListeners();
      } else if (result == UpdateStatus.restartRequired) {
        _status = AppUpdateStatus.restartRequired;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[UpdateEngine] Silent check skipped: $e');
    }
  }

  /// User-initiated check for cloud patches.
  Future<AppUpdateStatus> checkForUpdates() async {
    if (_status == AppUpdateStatus.checking || _status == AppUpdateStatus.downloading) {
      return _status;
    }

    _status = AppUpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    _updateLastCheckedTimestamp();

    if (!isUpdaterAvailable) {
      // Updater unavailable on debug builds, simulators, or web
      await Future.delayed(const Duration(milliseconds: 900));
      _status = AppUpdateStatus.upToDate;
      notifyListeners();
      return _status;
    }

    try {
      final result = await _updater.checkForUpdate();

      switch (result) {
        case UpdateStatus.upToDate:
          _status = AppUpdateStatus.upToDate;
          break;
        case UpdateStatus.outdated:
          _status = AppUpdateStatus.updateAvailable;
          break;
        case UpdateStatus.restartRequired:
          _status = AppUpdateStatus.restartRequired;
          break;
        case UpdateStatus.unavailable:
          _status = AppUpdateStatus.upToDate;
          break;
      }
    } catch (e) {
      debugPrint('[UpdateEngine] Error checking updates: $e');
      _errorMessage = 'Unable to reach cloud network. Please check your connection.';
      _status = AppUpdateStatus.error;
    }

    notifyListeners();
    return _status;
  }

  /// Download and stage the available cloud patch.
  Future<bool> downloadAndInstallUpdate() async {
    if (_status == AppUpdateStatus.downloading) return false;

    _status = AppUpdateStatus.downloading;
    _errorMessage = null;
    notifyListeners();

    if (!isUpdaterAvailable) {
      await Future.delayed(const Duration(milliseconds: 1500));
      _status = AppUpdateStatus.restartRequired;
      notifyListeners();
      return true;
    }

    try {
      await _updater.update();
      _stagedPatch = await _updater.readNextPatch();
      _status = AppUpdateStatus.restartRequired;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[UpdateEngine] Download failed: $e');
      _errorMessage = 'Download could not be completed. Please try again.';
      _status = AppUpdateStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Restarts the application immediately so the new patch executes.
  Future<void> restartApp() async {
    try {
      await Restart.restartApp();
    } catch (e) {
      debugPrint('[UpdateEngine] Restart failed: $e');
    }
  }

  void _updateLastCheckedTimestamp() {
    _lastCheckedTime = DateTime.now();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('ota_last_checked_timestamp', _lastCheckedTime!.millisecondsSinceEpoch);
    }).catchError((_) {});
  }
}
