import 'package:cryptography/cryptography.dart';

void main() async {
  print("🚀 Starting Crypto Test...");
  final x25519 = X25519();

  // 1. Generate Alice's Keypair
  final aliceKeyPair = await x25519.newKeyPair();
  final alicePublic = await aliceKeyPair.extractPublicKey();
  print("Alice Public Key Bytes: ${alicePublic.bytes.length}");

  // 2. Generate Bob's Keypair
  final bobKeyPair = await x25519.newKeyPair();
  final bobPublic = await bobKeyPair.extractPublicKey();
  print("Bob Public Key Bytes: ${bobPublic.bytes.length}");

  // 3. Compute Shared Secret on Alice's side
  final aliceSharedSecret = await x25519.sharedSecretKey(
    keyPair: aliceKeyPair,
    remotePublicKey: bobPublic,
  );
  final aliceSharedBytes = await aliceSharedSecret.extractBytes();
  print("Alice Shared Secret Length: ${aliceSharedBytes.length}");

  // 4. Compute Shared Secret on Bob's side
  final bobSharedSecret = await x25519.sharedSecretKey(
    keyPair: bobKeyPair,
    remotePublicKey: alicePublic,
  );
  final bobSharedBytes = await bobSharedSecret.extractBytes();
  print("Bob Shared Secret Length: ${bobSharedBytes.length}");

  // 5. Verify they match
  bool match = true;
  for (int i = 0; i < aliceSharedBytes.length; i++) {
    if (aliceSharedBytes[i] != bobSharedBytes[i]) {
      match = false;
      break;
    }
  }
  print("Secrets Match? $match");

  // 6. Test reconstructing keypair from seed/private bytes
  final alicePrivate = await aliceKeyPair.extractPrivateKeyBytes();
  // In cryptography package, SimpleKeyPairData can be used to construct key pairs
  final reconstructedKeyPair = SimpleKeyPairData(
    alicePrivate,
    publicKey: alicePublic,
    type: KeyPairType.x25519,
  );
  
  final reconstructedSharedSecret = await x25519.sharedSecretKey(
    keyPair: reconstructedKeyPair,
    remotePublicKey: bobPublic,
  );
  final reconstructedSharedBytes = await reconstructedSharedSecret.extractBytes();
  
  bool reconMatch = true;
  for (int i = 0; i < aliceSharedBytes.length; i++) {
    if (aliceSharedBytes[i] != reconstructedSharedBytes[i]) {
      reconMatch = false;
      break;
    }
  }
  print("Reconstructed KeyPair Shared Secret Match? $reconMatch");
}
