import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'chat_lock_service.dart';

final stealthVaultProvider =
    StateNotifierProvider<StealthVaultNotifier, Set<String>>((ref) {
  return StealthVaultNotifier();
});

class StealthVaultNotifier extends StateNotifier<Set<String>> {
  static const _storage = FlutterSecureStorage();
  static const _hiddenChatsKey = 'ripple_stealth_hidden_chats';
  static const _secretCodeKey = 'ripple_stealth_secret_passcode';
  static const String defaultSecretCode = '*7777#';

  StealthVaultNotifier() : super(<String>{}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final jsonStr = await _storage.read(key: _hiddenChatsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = List<String>.from(jsonDecode(jsonStr) as List);
        state = list.toSet();
      }
    } catch (e) {
      debugPrint('Error loading stealth vault: $e');
    }
  }

  Future<void> hideChat(String chatId) async {
    final updated = Set<String>.from(state)..add(chatId);
    state = updated;
    await _persist();
  }

  Future<void> unhideChat(String chatId) async {
    final updated = Set<String>.from(state)..remove(chatId);
    state = updated;
    await _persist();
  }

  bool isHidden(String chatId) => state.contains(chatId);

  Future<void> _persist() async {
    try {
      final jsonStr = jsonEncode(state.toList());
      await _storage.write(key: _hiddenChatsKey, value: jsonStr);
    } catch (e) {
      debugPrint('Error persisting stealth vault: $e');
    }
  }

  Future<String> getSecretCode() async {
    try {
      final code = await _storage.read(key: _secretCodeKey);
      if (code != null && code.isNotEmpty) return code;
    } catch (_) {}
    return defaultSecretCode;
  }

  Future<void> setSecretCode(String newCode) async {
    try {
      await _storage.write(key: _secretCodeKey, value: newCode.trim());
    } catch (e) {
      debugPrint('Error setting secret code: $e');
    }
  }

  Future<bool> verifySecretCode(String input) async {
    final code = await getSecretCode();
    return input.trim() == code.trim();
  }

  Future<bool> authenticate({String reason = 'Authenticate to access Stealth Vault'}) async {
    return await ChatLockService.authenticate(reason: reason);
  }
}
