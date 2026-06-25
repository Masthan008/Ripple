import 'package:flutter/services.dart';

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
}
