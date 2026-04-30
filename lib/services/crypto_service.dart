import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  // Server's static public key (X25519) - base64 encoded
  // keksx server (31.57.105.213) - generated 2026-04-24
  static const _serverPublicKeyBase64 =
      'tSfHUc2YLqQVLzjleId+313F8MdwBitCskVYfH/I3UY=';

  /// Encrypt cookies for transport to server.
  ///
  /// Returns a map with:
  /// - `ephemeral_public`: base64-encoded client ephemeral X25519 public key
  /// - `ciphertext`: base64-encoded AES-256-GCM ciphertext
  /// - `nonce`: base64-encoded 12-byte nonce
  /// - `mac`: base64-encoded GCM authentication tag
  static Future<Map<String, String>> encryptCookies(String cookies) async {
    final algorithm = X25519();

    // Generate ephemeral key pair (forward secrecy: new pair per session)
    final clientKeyPair = await algorithm.newKeyPair();
    final clientPublicKey = await clientKeyPair.extractPublicKey();

    // Decode server's static public key
    final serverPublicKeyBytes = base64Decode(_serverPublicKeyBase64);
    final serverPublicKey = SimplePublicKey(
      serverPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    // ECDH: derive shared secret
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: clientKeyPair,
      remotePublicKey: serverPublicKey,
    );

    // Encrypt with AES-256-GCM using the shared secret
    final aesGcm = AesGcm.with256bits();
    final nonce = aesGcm.newNonce();

    final secretBox = await aesGcm.encrypt(
      utf8.encode(cookies),
      secretKey: sharedSecret,
      nonce: nonce,
    );

    final clientPublicKeyBytes = Uint8List.fromList(clientPublicKey.bytes);

    return {
      'ephemeral_public': base64Encode(clientPublicKeyBytes),
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Generate a fresh X25519 key pair for the server.
  ///
  /// Run this once during server setup and store the private key securely.
  /// Paste the returned `public` value into [_serverPublicKeyBase64].
  static Future<Map<String, String>> generateServerKeyPair() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKey = await keyPair.extractPrivateKeyBytes();

    return {
      'public': base64Encode(Uint8List.fromList(publicKey.bytes)),
      'private': base64Encode(Uint8List.fromList(privateKey)),
    };
  }
}
