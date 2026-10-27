import 'dart:io';

/// Ephemeral offline peer discovered over local mesh / UDP broadcast.
/// Never written to disk — exists only in volatile RAM.
class EphemeralPeer {
  final String peerId;
  final String alias;
  final InternetAddress ipAddress;
  final int port;
  final DateTime lastSeen;
  final int avatarSeed;

  const EphemeralPeer({
    required this.peerId,
    required this.alias,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    required this.avatarSeed,
  });

  EphemeralPeer copyWith({
    String? alias,
    DateTime? lastSeen,
    int? avatarSeed,
  }) {
    return EphemeralPeer(
      peerId: peerId,
      alias: alias ?? this.alias,
      ipAddress: ipAddress,
      port: port,
      lastSeen: lastSeen ?? this.lastSeen,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }

  Map<String, dynamic> toMap() => {
        'peerId': peerId,
        'alias': alias,
        'ip': ipAddress.address,
        'port': port,
        'avatarSeed': avatarSeed,
      };

  factory EphemeralPeer.fromMap(Map<String, dynamic> map, InternetAddress senderIp, int senderPort) {
    return EphemeralPeer(
      peerId: map['peerId'] as String? ?? 'unknown',
      alias: map['alias'] as String? ?? 'Anonymous Peer',
      ipAddress: senderIp,
      port: senderPort,
      lastSeen: DateTime.now(),
      avatarSeed: map['avatarSeed'] as int? ?? 1,
    );
  }
}
