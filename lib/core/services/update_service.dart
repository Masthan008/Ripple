import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Application update states for the dual-engine OTA cloud system.
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

/// High-performance dual-engine update manager:
/// Engine 1: Shorebird instant bytecode patcher (when running Shorebird release).
/// Engine 2: Zoho Catalyst & GitHub Releases direct APK updater (when physical testing or non-Shorebird build).
class UpdateService extends ChangeNotifier {
  final ShorebirdUpdater _updater = ShorebirdUpdater();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

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

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  String? _availableVersion;
  String? get availableVersion => _availableVersion;

  String? _downloadUrl;
  String? get downloadUrl => _downloadUrl;

  List<String> _changelog = [];
  List<String> get changelog => _changelog;

  String? _downloadedApkPath;

  /// Returns whether Shorebird over-the-air code push is active on this device.
  bool get isUpdaterAvailable => _updater.isAvailable;

  /// Human-readable patch identifier.
  String get patchVersionString {
    if (_currentPatch != null) {
      return 'Shorebird Patch #${_currentPatch!.number}';
    }
    if (_availableVersion != null) {
      return 'Catalyst OTA: $_availableVersion';
    }
    return 'Base Engine v1.0.1';
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
        debugPrint('[UpdateEngine] Error inspecting local Shorebird patch: $e');
      }
    }

    notifyListeners();

    // Perform silent background check if auto-check is enabled
    if (_autoCheckEnabled && _status != AppUpdateStatus.restartRequired) {
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
    try {
      if (isUpdaterAvailable) {
        final result = await _updater.checkForUpdate();
        _updateLastCheckedTimestamp();
        if (result == UpdateStatus.outdated) {
          await _updater.update();
          _stagedPatch = await _updater.readNextPatch();
          _status = AppUpdateStatus.restartRequired;
          notifyListeners();
        } else if (result == UpdateStatus.restartRequired) {
          _status = AppUpdateStatus.restartRequired;
          notifyListeners();
        }
      } else {
        // Query Catalyst endpoint silently
        await _checkCatalystOrGitHubUpdate();
      }
    } catch (e) {
      debugPrint('[UpdateEngine] Silent check skipped: $e');
    }
  }

  /// User-initiated check for cloud patches or APK updates.
  Future<AppUpdateStatus> checkForUpdates() async {
    if (_status == AppUpdateStatus.checking || _status == AppUpdateStatus.downloading) {
      return _status;
    }

    _status = AppUpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    _updateLastCheckedTimestamp();

    if (isUpdaterAvailable) {
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
            // Fall back to Catalyst check
            await _checkCatalystOrGitHubUpdate();
            break;
        }
      } catch (e) {
        debugPrint('[UpdateEngine] Shorebird check failed, trying Catalyst fallback: $e');
        await _checkCatalystOrGitHubUpdate();
      }
    } else {
      // Primary engine for physical devices / standard APK installs
      await _checkCatalystOrGitHubUpdate();
    }

    notifyListeners();
    return _status;
  }

  Future<void> _checkCatalystOrGitHubUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform().catchError((_) => PackageInfo(
        appName: 'Ripple',
        packageName: 'com.ripple.messenger',
        version: '1.0.0',
        buildNumber: '1',
      ));
      final currentBuild = int.tryParse(info.buildNumber) ?? 1;

      // 1. Check Catalyst Backend endpoint
      try {
        final res = await _dio.get(
          'https://ripple-60091711787.development.catalystserverless.in/server/ripple_notify/checkUpdate',
        );
        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data as Map;
          final remoteBuild = data['buildNumber'] as int? ?? 1;
          if (remoteBuild > currentBuild) {
            _availableVersion = data['version'] ?? 'v1.0.1';
            _downloadUrl = data['downloadUrl'] ??
                'https://github.com/Masthan008/Ripple/raw/main/release/ripple-release.apk';
            _changelog = List<String>.from(data['changelog'] ?? []);
            _status = AppUpdateStatus.updateAvailable;
            return;
          }
        }
      } catch (catErr) {
        debugPrint('[UpdateEngine] Catalyst check error: $catErr');
      }

      // 2. Fallback to GitHub Releases API
      try {
        final ghRes = await _dio.get(
          'https://api.github.com/repos/Masthan008/Ripple/releases/latest',
          options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
        );
        if (ghRes.statusCode == 200 && ghRes.data is Map) {
          final ghData = ghRes.data as Map;
          final tagName = ghData['tag_name'] as String? ?? '';
          final assets = (ghData['assets'] as List?) ?? [];
          String? apkUrl;
          for (final a in assets) {
            if (a['name'].toString().endsWith('.apk')) {
              apkUrl = a['browser_download_url'];
              break;
            }
          }

          if (tagName.isNotEmpty && tagName != 'v${info.version}') {
            _availableVersion = tagName;
            _downloadUrl = apkUrl ?? 'https://github.com/Masthan008/Ripple/raw/main/release/ripple-release.apk';
            _changelog = [ghData['body']?.toString() ?? 'Latest performance & security updates'];
            _status = AppUpdateStatus.updateAvailable;
            return;
          }
        }
      } catch (ghErr) {
        debugPrint('[UpdateEngine] GitHub check note: $ghErr');
      }

      _status = AppUpdateStatus.upToDate;
    } catch (e) {
      debugPrint('[UpdateEngine] All update checks completed: $e');
      _status = AppUpdateStatus.upToDate;
    }
  }

  /// Download and stage the available cloud patch or APK package.
  Future<bool> downloadAndInstallUpdate() async {
    if (_status == AppUpdateStatus.downloading) return false;

    _status = AppUpdateStatus.downloading;
    _errorMessage = null;
    _downloadProgress = 0.0;
    notifyListeners();

    if (isUpdaterAvailable && _downloadUrl == null) {
      try {
        await _updater.update();
        _stagedPatch = await _updater.readNextPatch();
        _status = AppUpdateStatus.restartRequired;
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('[UpdateEngine] Shorebird download failed: $e');
        _errorMessage = 'Download could not be completed. Please try again.';
        _status = AppUpdateStatus.error;
        notifyListeners();
        return false;
      }
    }

    // Direct APK Download & Installation for Physical Devices
    try {
      final url = _downloadUrl ??
          'https://github.com/Masthan008/Ripple/raw/main/release/ripple-release.apk';
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/ripple-update.apk';

      // Delete existing temporary file if present
      final oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            notifyListeners();
          }
        },
      );

      _downloadedApkPath = savePath;
      _downloadProgress = 1.0;
      _status = AppUpdateStatus.restartRequired;
      notifyListeners();

      // Launch native Android Package Installer
      await OpenFilex.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );

      return true;
    } catch (e) {
      debugPrint('[UpdateEngine] APK download/install error: $e');
      _errorMessage = 'Failed to download update package: ${e.toString()}';
      _status = AppUpdateStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Restarts the application or re-prompts the downloaded APK installer.
  Future<void> restartApp() async {
    if (_downloadedApkPath != null && await File(_downloadedApkPath!).exists()) {
      await OpenFilex.open(
        _downloadedApkPath!,
        type: 'application/vnd.android.package-archive',
      );
      return;
    }

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
