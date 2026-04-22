import 'dart:math';

/// Semantic Currents™ — Fluid Auto-Threading
///
/// Automatically groups chat messages into "currents" (topic threads)
/// using on-device keyword extraction and semantic similarity.
///
/// Unlike traditional threads that require manual user action,
/// Semantic Currents uses NLP to detect when conversations naturally
/// shift topics and creates swipeable "current lanes" that users
/// can browse independently.
///
/// All processing is done on-device — no message content is sent
/// to external servers for analysis.
class SemanticCurrentsService {
  SemanticCurrentsService._();
  static final SemanticCurrentsService instance = SemanticCurrentsService._();

  // Topic keyword clusters — each maps a "current" to its trigger words
  static const Map<String, List<String>> _topicKeywords = {
    'plans': [
      'plan', 'planning', 'schedule', 'when', 'tomorrow', 'tonight',
      'weekend', 'meet', 'meeting', 'hangout', 'party', 'trip',
      'event', 'date', 'time', 'place', 'where', 'going', 'come',
      'join', 'invite', 'rsvp', 'calendar', 'book', 'reservation',
    ],
    'media': [
      'photo', 'picture', 'video', 'movie', 'show', 'series',
      'music', 'song', 'album', 'spotify', 'youtube', 'netflix',
      'watch', 'listen', 'stream', 'meme', 'tiktok', 'reel',
      'instagram', 'trending', 'viral', 'clip', 'trailer',
    ],
    'food': [
      'food', 'eat', 'dinner', 'lunch', 'breakfast', 'recipe',
      'cook', 'restaurant', 'order', 'delivery', 'pizza', 'burger',
      'coffee', 'tea', 'drink', 'hungry', 'snack', 'dessert',
      'cafe', 'menu', 'taste', 'delicious', 'yummy',
    ],
    'work': [
      'work', 'project', 'deadline', 'meeting', 'boss', 'client',
      'email', 'report', 'presentation', 'office', 'remote',
      'salary', 'promotion', 'interview', 'job', 'career',
      'task', 'assign', 'review', 'feedback', 'sprint',
    ],
    'tech': [
      'app', 'code', 'bug', 'update', 'phone', 'laptop',
      'software', 'hardware', 'ai', 'flutter', 'android', 'ios',
      'api', 'database', 'server', 'cloud', 'deploy', 'git',
      'feature', 'release', 'version', 'debug', 'error',
    ],
    'health': [
      'health', 'gym', 'workout', 'exercise', 'run', 'walk',
      'diet', 'weight', 'sleep', 'doctor', 'medicine', 'sick',
      'hospital', 'yoga', 'meditation', 'mental', 'stress',
      'anxiety', 'tired', 'energy', 'vitamin', 'protein',
    ],
    'money': [
      'money', 'pay', 'price', 'cost', 'buy', 'sell', 'shop',
      'expensive', 'cheap', 'deal', 'discount', 'sale', 'budget',
      'savings', 'invest', 'crypto', 'stock', 'bank', 'transfer',
      'split', 'owe', 'venmo', 'gpay', 'upi',
    ],
    'travel': [
      'travel', 'flight', 'hotel', 'booking', 'vacation', 'holiday',
      'beach', 'mountain', 'road trip', 'passport', 'visa',
      'airport', 'train', 'bus', 'uber', 'cab', 'drive',
      'destination', 'explore', 'tourist', 'sightseeing',
    ],
    'gaming': [
      'game', 'play', 'gaming', 'xbox', 'ps5', 'switch', 'pc',
      'valorant', 'fortnite', 'minecraft', 'gta', 'league',
      'rank', 'level', 'quest', 'boss', 'raid', 'esports',
      'stream', 'twitch', 'discord', 'squad', 'match',
    ],
    'emotional': [
      'love', 'miss', 'happy', 'sad', 'angry', 'excited',
      'worried', 'scared', 'proud', 'grateful', 'sorry',
      'congratulations', 'celebrate', 'wish', 'hope', 'dream',
      'feel', 'feelings', 'heart', 'hug', 'care',
    ],
  };

  // Current names with emoji icons
  static const Map<String, String> currentIcons = {
    'plans': '📅',
    'media': '🎬',
    'food': '🍕',
    'work': '💼',
    'tech': '💻',
    'health': '🏃',
    'money': '💰',
    'travel': '✈️',
    'gaming': '🎮',
    'emotional': '💝',
    'general': '💬',
  };

  static const Map<String, String> currentLabels = {
    'plans': 'Plans & Events',
    'media': 'Media & Entertainment',
    'food': 'Food & Dining',
    'work': 'Work & Projects',
    'tech': 'Tech & Dev',
    'health': 'Health & Fitness',
    'money': 'Money & Shopping',
    'travel': 'Travel & Transport',
    'gaming': 'Gaming',
    'emotional': 'Feels & Vibes',
    'general': 'General Chat',
  };

  /// Analyze a message and determine its semantic thread/current.
  /// Returns a topic key like 'plans', 'media', 'food', etc.
  /// Falls back to 'general' for unclassifiable messages.
  String classifyMessage(String text) {
    if (text.isEmpty) return 'general';

    final words = text.toLowerCase().split(RegExp(r'[\s,.!?;:]+'));
    final scores = <String, double>{};

    for (final entry in _topicKeywords.entries) {
      final topic = entry.key;
      final keywords = entry.value;
      double score = 0;

      for (final word in words) {
        for (final keyword in keywords) {
          if (word == keyword || word.contains(keyword)) {
            score += 1.0;
          }
        }
      }

      // Normalize by message length to avoid bias towards longer messages
      if (score > 0) {
        scores[topic] = score / words.length;
      }
    }

    if (scores.isEmpty) return 'general';

    // Return the topic with the highest normalized score
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Only classify if confidence is above threshold
    if (sorted.first.value < 0.1) return 'general';

    return sorted.first.key;
  }

  /// Batch classify a list of messages.
  /// Returns a map of messageId → topicKey.
  Map<String, String> classifyBatch(List<MessageEntry> messages) {
    final result = <String, String>{};
    String? lastTopic;

    for (final msg in messages) {
      final topic = classifyMessage(msg.text);

      // Apply topic momentum — if the classified topic is 'general'
      // but the previous messages were about a specific topic,
      // short follow-up messages likely belong to the same topic
      if (topic == 'general' && lastTopic != null && msg.text.length < 30) {
        result[msg.id] = lastTopic;
      } else {
        result[msg.id] = topic;
        if (topic != 'general') lastTopic = topic;
      }
    }

    return result;
  }

  /// Get unique topics from a batch of classified messages.
  /// Returns a list of topic keys sorted by frequency.
  List<String> getActiveTopics(Map<String, String> classifications) {
    final counts = <String, int>{};
    for (final topic in classifications.values) {
      counts[topic] = (counts[topic] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }
}

/// Lightweight entry for batch classification
class MessageEntry {
  final String id;
  final String text;

  const MessageEntry({required this.id, required this.text});
}
