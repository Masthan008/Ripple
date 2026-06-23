import 'dart:math';

/// Sentient Decoy Matrix Generator
///
/// Dynamically constructs realistic simulated chats, contacts, groups, and
/// message histories to present a believable digital footprint during physical inspection.
class DecoyMatrixGenerator {
  static final Random _random = Random();

  /// Returns a mock list of chats for the Decoy environment.
  static List<Map<String, dynamic>> getDecoyChats() {
    final now = DateTime.now();

    return [
      {
        'id': 'decoy_chat_1',
        'isGroup': false,
        'otherUid': 'decoy_user_mom',
        'partnerName': 'Mom 💙',
        'partnerPhoto': null,
        'unreadCount': 0,
        'streak': 12,
        'lastMessage': {
          'text': 'Make sure you eat some dinner, honey!',
          'timestamp': now.subtract(const Duration(minutes: 14)),
          'senderId': 'decoy_user_mom',
        },
        'messages': [
          {'senderId': 'current_user', 'text': 'Hey Mom, just finished work.'},
          {'senderId': 'decoy_user_mom', 'text': 'Okay dear. Did you drink enough water today?'},
          {'senderId': 'current_user', 'text': 'Yes, I did!'},
          {'senderId': 'decoy_user_mom', 'text': 'Make sure you eat some dinner, honey!'},
        ]
      },
      {
        'id': 'decoy_chat_2',
        'isGroup': true,
        'partnerName': 'Project Neptune Team 🔱',
        'partnerPhoto': null,
        'unreadCount': 2,
        'streak': 0,
        'lastMessage': {
          'text': 'Dave: I uploaded the final PDFs to the shared folder.',
          'timestamp': now.subtract(const Duration(minutes: 42)),
          'senderId': 'decoy_user_dave',
        },
        'messages': [
          {'senderId': 'decoy_user_alice', 'text': 'Do we have the design specs for the login flow?'},
          {'senderId': 'current_user', 'text': 'Yes, Sarah sent them yesterday.'},
          {'senderId': 'decoy_user_sarah', 'text': 'Let me resend them here just in case.'},
          {'senderId': 'decoy_user_dave', 'text': 'Dave: I uploaded the final PDFs to the shared folder.'},
        ]
      },
      {
        'id': 'decoy_chat_3',
        'isGroup': false,
        'otherUid': 'decoy_user_sarah',
        'partnerName': 'Sarah (Designer)',
        'partnerPhoto': null,
        'unreadCount': 0,
        'streak': 4,
        'lastMessage': {
          'text': 'The liquid glass theme colors look fantastic.',
          'timestamp': now.subtract(const Duration(hours: 2)),
          'senderId': 'current_user',
        },
        'messages': [
          {'senderId': 'decoy_user_sarah', 'text': 'Hey, let me know what you think of the new icons.'},
          {'senderId': 'current_user', 'text': 'They look perfect! Let\'s go with the clean rounded style.'},
          {'senderId': 'decoy_user_sarah', 'text': 'Great. I will update the master asset library.'},
          {'senderId': 'current_user', 'text': 'The liquid glass theme colors look fantastic.'},
        ]
      },
      {
        'id': 'decoy_chat_4',
        'isGroup': false,
        'otherUid': 'decoy_user_john_ceo',
        'partnerName': 'John (CEO)',
        'partnerPhoto': null,
        'unreadCount': 0,
        'streak': 0,
        'lastMessage': {
          'text': 'Thanks for the quick turnaround.',
          'timestamp': now.subtract(const Duration(hours: 5)),
          'senderId': 'decoy_user_john_ceo',
        },
        'messages': [
          {'senderId': 'decoy_user_john_ceo', 'text': 'Can you jump on a quick sync about the roadmap?'},
          {'senderId': 'current_user', 'text': 'Sure, joining the daily room now.'},
          {'senderId': 'decoy_user_john_ceo', 'text': 'Thanks for the quick turnaround.'},
        ]
      },
      {
        'id': 'decoy_chat_5',
        'isGroup': true,
        'partnerName': 'Gym Buddies 💪',
        'partnerPhoto': null,
        'unreadCount': 0,
        'streak': 0,
        'lastMessage': {
          'text': 'Marc: Who is in for 6 AM tomorrow?',
          'timestamp': now.subtract(const Duration(days: 1)),
          'senderId': 'decoy_user_marc',
        },
        'messages': [
          {'senderId': 'decoy_user_steve', 'text': 'Hit a new PR on deadlift today!'},
          {'senderId': 'current_user', 'text': 'Awesome job Steve!'},
          {'senderId': 'decoy_user_marc', 'text': 'Marc: Who is in for 6 AM tomorrow?'},
        ]
      }
    ];
  }
}
