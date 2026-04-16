import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/raccourci.dart';

class StorageService {
  static const _key = 'raccourcis';
  static const _secureStorage = FlutterSecureStorage();

  Future<List<Raccourci>> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final List<dynamic> json = jsonDecode(data);
    return json.map((e) => Raccourci.fromJson(e)).toList();
  }

  Future<void> sauvegarder(List<Raccourci> raccourcis) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(raccourcis.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  Future<String?> chargerMotDePasse(String id) async {
    return await _secureStorage.read(key: 'pwd_$id');
  }

  Future<void> sauvegarderMotDePasse(String id, String motDePasse) async {
    await _secureStorage.write(key: 'pwd_$id', value: motDePasse);
  }

  Future<void> supprimerMotDePasse(String id) async {
    await _secureStorage.delete(key: 'pwd_$id');
  }

  Future<void> effacerTout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await _secureStorage.deleteAll();
  }
}
