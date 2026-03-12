import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/achievement_model.dart';
import '../widgets/achievement_unlock_overlay.dart';

class SocialService {
  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static String get _uid => _auth.currentUser!.uid;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STREAKS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  // Call this every time a message is sent
  static Future<int> updateStreak({
    required String chatId,
    required String senderId,
    required String recipientId,
  }) async {
    final chatRef = _fs.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final data = chatDoc.data() ?? {};

    final lastStreakDate = data['lastStreakDate'] as Timestamp?;
    int currentStreak = data['streak'] as int? ?? 0;
    final streakUsers = List<String>.from(data['streakUsers'] as List? ?? []);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastStreakDate == null) {
      // First message — start streak
      currentStreak = 1;
      await chatRef.update({
        'streak': 1,
        'lastStreakDate': Timestamp.fromDate(today),
        'streakUsers': [senderId, recipientId],
      });
      return 1;
    }

    final lastDate = DateTime(
      lastStreakDate.toDate().year,
      lastStreakDate.toDate().month,
      lastStreakDate.toDate().day,
    );

    final daysDiff = today.difference(lastDate).inDays;

    if (daysDiff == 0) {
      // Already messaged today
      // streak stays same
      return currentStreak;
    } else if (daysDiff == 1) {
      // Consecutive day — increment
      currentStreak++;
      await chatRef.update({
        'streak': currentStreak,
        'lastStreakDate': Timestamp.fromDate(today),
      });

      // Check streak achievements
      await _checkStreakAchievements(senderId, currentStreak);

      return currentStreak;
    } else {
      // Gap > 1 day — reset streak
      await chatRef.update({
        'streak': 1,
        'lastStreakDate': Timestamp.fromDate(today),
      });
      return 1;
    }
  }

  static Future<void> _checkStreakAchievements(String uid, int streak) async {
    if (streak >= 7) {
      await unlockAchievement(uid: uid, achievementId: 'on_fire');
    }
    if (streak >= 30) {
      await unlockAchievement(uid: uid, achievementId: 'unstoppable');
    }
    if (streak >= 100) {
      await unlockAchievement(uid: uid, achievementId: 'legendary');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ACHIEVEMENTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<bool> unlockAchievement({
    required String uid,
    required String achievementId,
    BuildContext? context,
  }) async {
    final ref = _fs
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(achievementId);

    // Already unlocked — skip
    final existing = await ref.get();
    if (existing.exists) return false;

    final definition = AchievementDefinitions.findById(achievementId);
    if (definition == null) return false;

    await ref.set({
      'id': achievementId,
      'title': definition.title,
      'emoji': definition.emoji,
      'description': definition.description,
      'tier': definition.tier.name,
      'unlockedAt': FieldValue.serverTimestamp(),
    });

    // Add to ripple score
    final tierPoints = {
      'bronze': 50,
      'silver': 100,
      'gold': 200,
      'diamond': 500,
    };
    await addRippleScore(
      uid: uid,
      points: tierPoints[definition.tier.name] ?? 50,
      reason: 'achievement_$achievementId',
    );

    final wasNew = !existing.exists;
    if (wasNew && context != null && context.mounted) {
      final def = AchievementDefinitions.findById(achievementId);
      if (def != null) {
        AchievementUnlockOverlay.show(context, def);

        // Post to activity feed
        await postActivity(
          uid: uid,
          type: 'achievement',
          title: 'Unlocked ${def.title}',
          emoji: def.emoji,
          extra: {'achievementId': achievementId},
        );
      }
    }

    return true; // Newly unlocked
  }

  static Stream<List<AchievementModel>> getAchievements(String uid) {
    return _fs
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .orderBy('unlockedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AchievementModel.fromFirestore).toList());
  }

  static Future<void> checkAndUnlock({
    required String uid,
    required String trigger,
    // 'message_sent' | 'image_sent' |
    // 'voice_sent' | 'friend_added' |
    // 'group_joined' | 'group_created' |
    // 'translator_used' | 'ai_used' |
    // 'profile_completed'
  }) async {
    // Increment counters
    final field = _triggerToField(trigger);
    if (field != null) {
      await _fs.collection('users').doc(uid).update({
        field: FieldValue.increment(1),
      });
    }

    // Get updated user doc
    final doc = await _fs.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    final msgs = data['totalMessagesSent'] as int? ?? 0;
    final images = data['totalImagesSent'] as int? ?? 0;
    final voices = data['totalVoiceMessages'] as int? ?? 0;
    final friends = data['totalFriends'] as int? ?? 0;
    final translator = data['translatorUsed'] as int? ?? 0;
    final ai = data['aiFeaturesUsed'] as int? ?? 0;

    // Check each achievement condition
    if (msgs >= 1) {
      await unlockAchievement(uid: uid, achievementId: 'first_wave');
    }
    if (msgs >= 100) {
      await unlockAchievement(uid: uid, achievementId: 'chatterbox');
    }
    if (msgs >= 1000) {
      await unlockAchievement(uid: uid, achievementId: 'mega_messenger');
    }
    if (images >= 50) {
      await unlockAchievement(uid: uid, achievementId: 'photographer');
    }
    if (voices >= 20) {
      await unlockAchievement(uid: uid, achievementId: 'podcaster');
    }
    if (friends >= 1) {
      await unlockAchievement(uid: uid, achievementId: 'friendly');
    }
    if (friends >= 10) {
      await unlockAchievement(uid: uid, achievementId: 'social_butterfly');
    }
    if (friends >= 50) {
      await unlockAchievement(uid: uid, achievementId: 'popular');
    }
    if (translator >= 5) {
      await unlockAchievement(uid: uid, achievementId: 'multilingual');
    }
    if (ai >= 20) {
      await unlockAchievement(uid: uid, achievementId: 'ai_master');
    }

    // Add ripple score for activity
    await addRippleScore(
      uid: uid,
      points: _triggerPoints(trigger),
      reason: trigger,
    );
  }

  static String? _triggerToField(String trigger) {
    switch (trigger) {
      case 'message_sent':
        return 'totalMessagesSent';
      case 'image_sent':
        return 'totalImagesSent';
      case 'voice_sent':
        return 'totalVoiceMessages';
      case 'friend_added':
        return 'totalFriends';
      case 'translator_used':
        return 'translatorUsed';
      case 'ai_used':
        return 'aiFeaturesUsed';
      default:
        return null;
    }
  }

  static int _triggerPoints(String trigger) {
    switch (trigger) {
      case 'message_sent':
        return 1;
      case 'image_sent':
        return 3;
      case 'voice_sent':
        return 5;
      case 'friend_added':
        return 10;
      case 'group_joined':
        return 15;
      case 'group_created':
        return 20;
      case 'translator_used':
        return 2;
      case 'ai_used':
        return 2;
      default:
        return 1;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // RIPPLE SCORE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<void> addRippleScore({
    required String uid,
    required int points,
    required String reason,
  }) async {
    await _fs.collection('users').doc(uid).update({
      'rippleScore': FieldValue.increment(points),
    });
  }

  static String getRippleRank(int score) {
    if (score >= 10000) return '💎 Diamond';
    if (score >= 5000) return '🥇 Gold';
    if (score >= 2000) return '🥈 Silver';
    if (score >= 500) return '🥉 Bronze';
    return '🌊 Rippler';
  }

  static Color getRippleRankColor(int score) {
    if (score >= 10000) return const Color(0xFF22D3EE);
    if (score >= 5000) return const Color(0xFFF59E0B);
    if (score >= 2000) return const Color(0xFF94A3B8);
    if (score >= 500) return const Color(0xFFCD7F32);
    return const Color(0xFF0EA5E9);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PROFILE VISITORS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<void> recordProfileVisit({
    required String profileOwnerId,
    required String visitorId,
    required String visitorName,
    required String visitorPhoto,
  }) async {
    // Don't record self-visits
    if (profileOwnerId == visitorId) return;

    await _fs
        .collection('users')
        .doc(profileOwnerId)
        .collection('visitors')
        .doc(visitorId)
        .set({
      'uid': visitorId,
      'name': visitorName,
      'photo': visitorPhoto,
      'visitedAt': FieldValue.serverTimestamp(),
    });

    // Clean up visits older than 7 days
    _cleanOldVisitors(profileOwnerId);
  }

  static Future<void> _cleanOldVisitors(String uid) async {
    final sevenDaysAgo =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    final old = await _fs
        .collection('users')
        .doc(uid)
        .collection('visitors')
        .where('visitedAt', isLessThan: sevenDaysAgo)
        .get();
    for (final doc in old.docs) {
      await doc.reference.delete();
    }
  }

  static Stream<List<Map<String, dynamic>>> getProfileVisitors(String uid) {
    return _fs
        .collection('users')
        .doc(uid)
        .collection('visitors')
        .orderBy('visitedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // MUTUAL FRIENDS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<List<Map<String, dynamic>>> getMutualFriends({
    required String currentUid,
    required String targetUid,
  }) async {
    final currentDoc = await _fs.collection('users').doc(currentUid).get();
    final targetDoc = await _fs.collection('users').doc(targetUid).get();

    final myFriends = List<String>.from(currentDoc.data()?['friends'] as List? ?? []);
    final theirFriends =
        List<String>.from(targetDoc.data()?['friends'] as List? ?? []);

    // Find intersection
    final mutualIds = myFriends.where((id) => theirFriends.contains(id)).toList();

    if (mutualIds.isEmpty) return [];

    // Fetch mutual friend profiles
    final mutual = <Map<String, dynamic>>[];
    for (final id in mutualIds.take(10)) {
      final doc = await _fs.collection('users').doc(id).get();
      if (doc.exists) {
        mutual.add({
          ...doc.data()!,
          'uid': doc.id,
        });
      }
    }
    return mutual;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FRIEND SUGGESTIONS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<List<Map<String, dynamic>>> getFriendSuggestions() async {
    final myDoc = await _fs.collection('users').doc(_uid).get();
    final myFriends = List<String>.from(myDoc.data()?['friends'] as List? ?? []);

    if (myFriends.isEmpty) {
      // No friends yet — show recent users
      final snap = await _fs
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: _uid)
          .limit(10)
          .get();
      return snap.docs
          .map((d) => {
                ...d.data(),
                'uid': d.id,
                'mutualCount': 0,
              })
          .toList();
    }

    // Get friends-of-friends
    final suggested = <String, Map<String, dynamic>>{};

    for (final friendId in myFriends.take(10)) {
      final friendDoc = await _fs.collection('users').doc(friendId).get();
      final friendsFriends =
          List<String>.from(friendDoc.data()?['friends'] as List? ?? []);

      for (final fof in friendsFriends) {
        // Skip self and existing friends
        if (fof == _uid) continue;
        if (myFriends.contains(fof)) continue;

        if (suggested.containsKey(fof)) {
          suggested[fof]!['mutualCount']++;
        } else {
          suggested[fof] = {
            'uid': fof,
            'mutualCount': 1,
          };
        }
      }
    }

    // Sort by mutual count
    final sorted = suggested.values.toList()
      ..sort((a, b) => (b['mutualCount'] as int).compareTo(a['mutualCount'] as int));

    // Fetch profiles
    final result = <Map<String, dynamic>>[];
    for (final s in sorted.take(15)) {
      final doc = await _fs.collection('users').doc(s['uid'] as String).get();
      if (doc.exists) {
        result.add({
          ...doc.data()!,
          'uid': doc.id,
          'mutualCount': s['mutualCount'],
        });
      }
    }

    return result;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ACTIVITY FEED
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<void> postActivity({
    required String uid,
    required String type,
    // 'achievement' | 'new_friend' |
    // 'streak_milestone' | 'joined'
    required String title,
    required String emoji,
    Map<String, dynamic>? extra,
  }) async {
    await _fs.collection('activityFeed').add({
      'uid': uid,
      'type': type,
      'title': title,
      'emoji': emoji,
      'extra': extra ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<Map<String, dynamic>>> getFriendsActivity(
      List<String> friendUids) {
    if (friendUids.isEmpty) {
      return Stream.value([]);
    }

    final uids = friendUids.take(30).toList();

    return _fs
        .collection('activityFeed')
        .where('uid', whereIn: uids)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {
              ...d.data(),
              'id': d.id,
            }).toList());
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // LEADERBOARD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<List<Map<String, dynamic>>> getFriendsLeaderboard(
      List<String> friendUids) async {
    if (friendUids.isEmpty) return [];

    final allUids = [
      ...friendUids.take(29),
      _uid, // Include self
    ];

    final snap = await _fs
        .collection('users')
        .where(FieldPath.documentId, whereIn: allUids)
        .get();

    final users = snap.docs.map((d) => {
          ...d.data(),
          'uid': d.id,
        }).toList();

    // Sort by ripple score descending
    users.sort((a, b) =>
        (b['rippleScore'] as int? ?? 0).compareTo(a['rippleScore'] as int? ?? 0));

    return users;
  }
}
