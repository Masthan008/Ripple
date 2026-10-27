import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/ephemeral_message.dart';
import '../models/ephemeral_peer.dart';
import 'ephemeral_vault.dart';

final offlineMeshServiceProvider = Provider<OfflineMeshService>((ref) {
  final vault = ref.read(ephemeralVaultProvider.notifier);
  final service = OfflineMeshService(vault: vault);
  ref.onDispose(() => service.stopMesh());
  return service;
});

final discoveredPeersProvider =
    StateNotifierProvider<DiscoveredPeersNotifier, List<EphemeralPeer>>((ref) {
  final mesh = ref.watch(offlineMeshServiceProvider);
  return mesh.peersNotifier;
});

class DiscoveredPeersNotifier extends StateNotifier<List<EphemeralPeer>> {
  DiscoveredPeersNotifier() : super([]);

  void updatePeers(List<EphemeralPeer> peers) {
    state = peers;
  }

  void clear() {
    state = [];
  }
}

/// BitChat Offline Mesh Engine using Local UDP Broadcast/Multicast.
/// Decentralized, serverless, peer-to-peer, memory-only communications.
class OfflineMeshService {
  final EphemeralVault vault;
  final DiscoveredPeersNotifier peersNotifier = DiscoveredPeersNotifier();

  static const int meshPort = 8888;
  static final InternetAddress broadcastAddress = InternetAddress('255.255.255.255');

  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  Timer? _peerPruneTimer;

  late String myPeerId;
  String myAlias = 'Ripple Peer';
  late int myAvatarSeed;
  bool isRunning = false;

  final Map<String, EphemeralPeer> _discoveredPeers = {};

  OfflineMeshService({required this.vault}) {
    myPeerId = const Uuid().v4().substring(0, 8);
    myAvatarSeed = math.Random().nextInt(9999);
  }

  void setAlias(String alias) {
    if (alias.trim().isNotEmpty) {
      myAlias = alias.trim();
    }
  }

  /// Starts the local offline mesh listener and broadcaster
  Future<bool> startMesh({String? customAlias}) async {
    if (isRunning) return true;
    if (customAlias != null && customAlias.isNotEmpty) {
      myAlias = customAlias;
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        meshPort,
        reuseAddress: true,
        reusePort: true,
      );

      _socket?.broadcastEnabled = true;
      isRunning = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram);
          }
        }
      });

      // Broadcast presence beacon every 2.5 seconds
      _beaconTimer?.cancel();
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        _broadcastPresenceBeacon();
      });

      // Prune inactive peers every 4 seconds
      _peerPruneTimer?.cancel();
      _peerPruneTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _pruneInactivePeers();
      });

      _broadcastPresenceBeacon();
      debugPrint('🌊 [Ripple Mesh] Offline P2P BitChat socket active on port $meshPort');
      return true;
    } catch (e) {
      debugPrint('❌ [Ripple Mesh] Failed to bind local socket: $e');
      isRunning = false;
      return false;
    }
  }

  /// Sends a local presence beacon
  void _broadcastPresenceBeacon() {
    if (_socket == null || !isRunning) return;

    final beaconData = jsonEncode({
      'type': 'beacon',
      'peerId': myPeerId,
      'alias': myAlias,
      'avatarSeed': myAvatarSeed,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(beaconData);
    try {
      _socket?.send(bytes, broadcastAddress, meshPort);
    } catch (e) {
      debugPrint('Beacon send note: $e');
    }
  }

  /// Handles incoming datagrams from nearby peers
  void _handleIncomingPacket(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'beacon') {
        final senderPeerId = json['peerId'] as String?;
        if (senderPeerId == null || senderPeerId == myPeerId) return;

        final peer = EphemeralPeer.fromMap(json, datagram.address, datagram.port);
        _discoveredPeers[senderPeerId] = peer;
        peersNotifier.updatePeers(_discoveredPeers.values.toList());
      } else if (type == 'msg') {
        final senderPeerId = json['senderId'] as String?;
        if (senderPeerId == null || senderPeerId == myPeerId) return;

        final msgId = json['id'] as String? ?? const Uuid().v4();
        final senderAlias = json['senderAlias'] as String? ?? 'Peer';
        final messageText = json['text'] as String? ?? '';
        final ttl = json['ttl'] as int? ?? 60;

        final message = EphemeralMessage(
          id: msgId,
          senderId: senderPeerId,
          senderAlias: senderAlias,
          text: messageText,
          createdAt: DateTime.now(),
          ttlSeconds: ttl,
          isMine: false,
        );

        vault.addMessage(message);
      }
    } catch (e) {
      debugPrint('Error parsing mesh packet: $e');
    }
  }

  /// Prune peers that haven't been heard from in 8 seconds
  void _pruneInactivePeers() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _discoveredPeers.forEach((id, peer) {
      if (now.difference(peer.lastSeen).inSeconds > 8) {
        toRemove.add(id);
      }
    });

    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        _discoveredPeers.remove(id);
      }
      peersNotifier.updatePeers(_discoveredPeers.values.toList());
    }
  }

  /// Sends an ephemeral message to all peers or a targeted peer
  void sendMessage({
    required String text,
    int ttlSeconds = 60,
    EphemeralPeer? targetPeer,
  }) {
    if (_socket == null || !isRunning || text.trim().isEmpty) return;

    final msgId = const Uuid().v4();
    final payload = jsonEncode({
      'type': 'msg',
      'id': msgId,
      'senderId': myPeerId,
      'senderAlias': myAlias,
      'text': text.trim(),
      'ttl': ttlSeconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(payload);

    try {
      if (targetPeer != null) {
        _socket?.send(bytes, targetPeer.ipAddress, targetPeer.port);
      } else {
        _socket?.send(bytes, broadcastAddress, meshPort);
      }

      // Add to own volatile vault
      final myMsg = EphemeralMessage(
        id: msgId,
        senderId: myPeerId,
        senderAlias: myAlias,
        text: text.trim(),
        createdAt: DateTime.now(),
        ttlSeconds: ttlSeconds,
        isMine: true,
      );

      vault.addMessage(myMsg);
    } catch (e) {
      debugPrint('Error sending mesh message: $e');
    }
  }

  /// Stops mesh networking and cleans state
  void stopMesh() {
    _beaconTimer?.cancel();
    _peerPruneTimer?.cancel();
    _socket?.close();
    _socket = null;
    isRunning = false;
    _discoveredPeers.clear();
    peersNotifier.clear();
    debugPrint('🛑 [Ripple Mesh] BitChat offline engine stopped.');
  }
}
