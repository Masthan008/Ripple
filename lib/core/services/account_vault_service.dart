import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account metadata for Telegram-style Multi-Account switching
class SavedAccount {
  final String uid;
  final String email;
  final String displayName;
  final String? password;
  final String? photoUrl;
  final String? phoneNumber;
  final DateTime lastActive;

  SavedAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    this.password,
    this.photoUrl,
    this.phoneNumber,
    required this.lastActive,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'password': password,
    'photoUrl': photoUrl,
    'phoneNumber': phoneNumber,
    'lastActive': lastActive.toIso8601String(),
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    uid: json['uid'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    password: json['password'] as String?,
    photoUrl: json['photoUrl'] as String?,
    phoneNumber: json['phoneNumber'] as String?,
    lastActive: DateTime.tryParse(json['lastActive'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Vault managing multi-account credentials and instant account switching
class AccountVaultService {
  static const _storage = FlutterSecureStorage();
  static const _accountsKey = 'ripple_multi_accounts';
  static const _currentUidKey = 'ripple_active_uid';

  /// Retrieve all registered accounts on this device
  static Future<List<SavedAccount>> getSavedAccounts() async {
    try {
      final jsonStr = await _storage.read(key: _accountsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((item) => SavedAccount.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save or update an account in the local secure vault
  static Future<void> saveAccount(SavedAccount account) async {
    try {
      final accounts = await getSavedAccounts();
      final index = accounts.indexWhere((a) => a.uid == account.uid);
      if (index >= 0) {
        accounts[index] = account;
      } else {
        accounts.add(account);
      }
      final jsonStr = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await _storage.write(key: _accountsKey, value: jsonStr);
      await _storage.write(key: _currentUidKey, value: account.uid);
    } catch (_) {}
  }

  /// Remove an account from the local device vault
  static Future<void> removeAccount(String uid) async {
    try {
      final accounts = await getSavedAccounts();
      accounts.removeWhere((a) => a.uid == uid);
      final jsonStr = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await _storage.write(key: _accountsKey, value: jsonStr);
    } catch (_) {}
  }

  /// Perform live account authentication switch
  static Future<bool> switchAccount(SavedAccount target) async {
    try {
      if (target.email.isNotEmpty && target.password != null && target.password!.isNotEmpty) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: target.email,
          password: target.password!,
        );
      }
      await _storage.write(key: _currentUidKey, value: target.uid);
      return true;
    } catch (e) {
      debugPrint('AccountVaultService: error switching account: $e');
      return false;
    }
  }

  /// Set the currently active account UID
  static Future<void> setActiveAccount(String uid) async {
    await _storage.write(key: _currentUidKey, value: uid);
  }

  /// Get the currently active account UID
  static Future<String?> getActiveAccountUid() async {
    return await _storage.read(key: _currentUidKey);
  }
}
