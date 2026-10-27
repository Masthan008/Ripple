/// Ephemeral offline mesh message.
/// Strictly in-memory only — never written to disk or flash storage.
/// Auto-evaporates after ttlSeconds.
class EphemeralMessage {
  final String id;
  final String senderId;
  final String senderAlias;
  final String text;
  final DateTime createdAt;
  final int ttlSeconds;
  final bool isMine;

  const EphemeralMessage({
    required this.id,
    required this.senderId,
    required this.senderAlias,
    required this.text,
    required this.createdAt,
    this.ttlSeconds = 60,
    required this.isMine,
  });

  int get remainingSeconds {
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    final left = ttlSeconds - elapsed;
    return left > 0 ? left : 0;
  }

  bool get isExpired => remainingSeconds <= 0;

  double get progressRatio {
    if (ttlSeconds <= 0) return 0.0;
    return remainingSeconds / ttlSeconds.toDouble();
  }
}
