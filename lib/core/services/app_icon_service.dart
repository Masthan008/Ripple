import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentAppIconProvider = StateProvider<String>((ref) => 'Default');

class AppIconService {
  static const _channel = MethodChannel('com.valli.ripple/app_icon');

  static Future<bool> changeIcon(String iconName) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('changeIcon', {'iconName': iconName});
      return success ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<String> getCurrentIcon() async {
    try {
      final String? iconName = await _channel.invokeMethod<String>('getCurrentIcon');
      return iconName ?? 'Default';
    } on PlatformException catch (_) {
      return 'Default';
    }
  }

  static String getLogoAsset(String iconId) {
    switch (iconId.toLowerCase()) {
      case 'abyss':
        return 'assets/images/ic_launcher_abyss.png';
      case 'gold':
        return 'assets/images/ic_launcher_gold.png';
      case 'glitch':
        return 'assets/images/ic_launcher_glitch.png';
      case 'forest':
        return 'assets/images/ic_launcher_forest.png';
      case 'sunset':
        return 'assets/images/ic_launcher_sunset.png';
      default:
        return 'assets/images/ripple_logo.png';
    }
  }
}
