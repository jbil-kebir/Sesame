import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyHash = 'app_pin_hash';
  static const _keySalt = 'app_pin_salt';
  static const _keyBackupCodes = 'app_pin_backup_codes';
  static const _prefFailures = 'pin_failures';
  static const _prefCooldownUntil = 'pin_cooldown_until';

  static const int maxEchecs = 10;

  Future<bool> estConfigure() async {
    final hash = await _secureStorage.read(key: _keyHash);
    return hash != null;
  }

  Future<void> configurerPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = _hasherPin(salt, pin);
    await _secureStorage.write(key: _keySalt, value: base64Encode(salt));
    await _secureStorage.write(key: _keyHash, value: hash);
    await _reinitialiserEchecs();
  }

  Future<bool> verifierPin(String pin) async {
    final saltB64 = await _secureStorage.read(key: _keySalt);
    final storedHash = await _secureStorage.read(key: _keyHash);
    if (saltB64 == null || storedHash == null) return false;
    final salt = base64Decode(saltB64);
    return _hasherPin(salt, pin) == storedHash;
  }

  // ─── Codes de secours ────────────────────────────────────────────────────

  // Génère 8 codes de 8 caractères (format XXXX-XXXX), stocke leurs hashes.
  Future<List<String>> genererCodesSecours() async {
    final rng = Random.secure();
    // Alphabet sans 0/O/1/I pour éviter les confusions visuelles
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final codes = List.generate(8, (_) {
      final p1 = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
      final p2 = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
      return '$p1-$p2';
    });
    final hashes = codes.map(_hasherCode).toList();
    await _secureStorage.write(key: _keyBackupCodes, value: jsonEncode(hashes));
    return codes;
  }

  // Retourne true si le code est valide et le consomme (usage unique).
  Future<bool> utiliserCodeSecours(String code) async {
    final raw = await _secureStorage.read(key: _keyBackupCodes);
    if (raw == null) return false;
    final hashes = List<String>.from(jsonDecode(raw));
    final codeHash = _hasherCode(code);
    if (!hashes.contains(codeHash)) return false;
    hashes.remove(codeHash);
    await _secureStorage.write(key: _keyBackupCodes, value: jsonEncode(hashes));
    await _reinitialiserEchecs();
    return true;
  }

  Future<int> codesSecoursRestants() async {
    final raw = await _secureStorage.read(key: _keyBackupCodes);
    if (raw == null) return 0;
    return (jsonDecode(raw) as List).length;
  }

  // ─── Gestion des échecs ───────────────────────────────────────────────────

  Future<int> nombreEchecs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefFailures) ?? 0;
  }

  Future<void> enregistrerEchec() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_prefFailures) ?? 0) + 1;
    await prefs.setInt(_prefFailures, n);
    int delaySec = 0;
    if (n >= 5) {
      delaySec = 300; // 5 minutes
    } else if (n >= 3) {
      delaySec = 30; // 30 secondes
    }
    if (delaySec > 0) {
      final until = DateTime.now()
          .add(Duration(seconds: delaySec))
          .millisecondsSinceEpoch;
      await prefs.setInt(_prefCooldownUntil, until);
    }
  }

  Future<Duration> cooldownRestant() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_prefCooldownUntil) ?? 0;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return Duration.zero;
    return Duration(milliseconds: remaining);
  }

  Future<void> reinitialiserEchecs() => _reinitialiserEchecs();

  // ─── Helpers privés ───────────────────────────────────────────────────────

  Future<void> _reinitialiserEchecs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefFailures);
    await prefs.remove(_prefCooldownUntil);
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static String _hasherPin(Uint8List salt, String pin) {
    final bytes = [...salt, ...utf8.encode(pin)];
    return sha256.convert(bytes).toString();
  }

  static String _hasherCode(String code) {
    final normalized = code.replaceAll('-', '').toUpperCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}
