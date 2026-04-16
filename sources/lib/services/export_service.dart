import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' show AES, AESMode, Encrypted, Encrypter, IV, Key;

import '../models/raccourci.dart';

class ExportService {
  static const int _iterations = 100000;
  static const int _keyLength = 32; // AES-256
  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _version = 1;

  /// Chiffre les raccourcis + mots de passe avec la passphrase donnée.
  /// Exécuté dans un isolate pour ne pas bloquer l'UI.
  static Future<String> chiffrer({
    required List<Raccourci> raccourcis,
    required Map<String, String> passwords,
    required String passphrase,
  }) async {
    final raccourcisJson = raccourcis.map((r) => r.toJson()).toList();
    return Isolate.run(
      () => _chiffrerSync(raccourcisJson, passwords, passphrase),
    );
  }

  /// Déchiffre le contenu et retourne raccourcis + mots de passe.
  /// Lance une [FormatException] si la passphrase est incorrecte ou le fichier corrompu.
  static Future<({List<Raccourci> raccourcis, Map<String, String> passwords})>
      dechiffrer({
    required String contenu,
    required String passphrase,
  }) async {
    return Isolate.run(() => _dechiffrerSync(contenu, passphrase));
  }

  // ─── Implémentations synchrones (exécutées dans l'isolate) ───────────────

  static String _chiffrerSync(
    List<Map<String, dynamic>> raccourcisJson,
    Map<String, String> passwords,
    String passphrase,
  ) {
    final salt = _randomBytes(_saltLength);
    final ivBytes = _randomBytes(_ivLength);
    final key = Key(_deriveKey(passphrase, salt));
    final iv = IV(ivBytes);

    final plaintext = jsonEncode({
      'raccourcis': raccourcisJson,
      'passwords': passwords,
    });

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return jsonEncode({
      'v': _version,
      'salt': base64.encode(salt),
      'iv': base64.encode(ivBytes),
      'data': encrypted.base64,
    });
  }

  static ({List<Raccourci> raccourcis, Map<String, String> passwords})
      _dechiffrerSync(String contenu, String passphrase) {
    try {
      final Map<String, dynamic> envelope = jsonDecode(contenu);
      final salt = base64.decode(envelope['salt'] as String);
      final iv = IV(base64.decode(envelope['iv'] as String));
      final data = Encrypted.fromBase64(envelope['data'] as String);
      final key = Key(_deriveKey(passphrase, salt));

      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final plaintext = encrypter.decrypt(data, iv: iv);

      final Map<String, dynamic> payload = jsonDecode(plaintext);
      final raccourcis = (payload['raccourcis'] as List)
          .map((e) => Raccourci.fromJson(e as Map<String, dynamic>))
          .toList();
      final passwords = Map<String, String>.from(
        (payload['passwords'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
      );
      return (raccourcis: raccourcis, passwords: passwords);
    } catch (_) {
      throw const FormatException('Passphrase incorrecte ou fichier corrompu.');
    }
  }

  // ─── Dérivation de clé PBKDF2-HMAC-SHA256 ────────────────────────────────

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final passwordBytes = utf8.encode(passphrase);
    final blockCount = (_keyLength / 32).ceil();
    final result = Uint8List(_keyLength);

    for (var block = 1; block <= blockCount; block++) {
      final blockBytes =
          _pbkdf2Block(passwordBytes, salt, block, _iterations);
      final offset = (block - 1) * 32;
      final len = min(32, _keyLength - offset);
      result.setRange(offset, offset + len, blockBytes);
    }

    return result;
  }

  static Uint8List _pbkdf2Block(
    List<int> password,
    Uint8List salt,
    int blockIndex,
    int iterations,
  ) {
    final hmac = Hmac(sha256, password);

    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setRange(0, salt.length, salt);
    saltWithIndex[salt.length] = (blockIndex >> 24) & 0xff;
    saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xff;
    saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xff;
    saltWithIndex[salt.length + 3] = blockIndex & 0xff;

    var u = Uint8List.fromList(hmac.convert(saltWithIndex).bytes);
    final result = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    return result;
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }
}
