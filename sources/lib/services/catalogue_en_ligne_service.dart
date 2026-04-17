import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalogue.dart';
import '../models/catalogue_en_ligne.dart';

class CatalogueEnLigneService {
  static const _indexUrl =
      'https://raw.githubusercontent.com/jbil-kebir/Sesame/main/catalogues/index.json';
  static const _prefIndexCache = 'catalogue_index_cache';
  static const _prefVersionPrefix = 'catalogue_version_';

  static const _timeout = Duration(seconds: 10);

  /// Télécharge l'index depuis GitHub.
  /// En cas d'erreur réseau, utilise le cache local si disponible.
  /// Lance une exception si aucune donnée n'est disponible.
  Future<List<CatalogueEnLigneInfo>> chargerIndex() async {
    try {
      final response = await http
          .get(Uri.parse(_indexUrl))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final json = utf8.decode(response.bodyBytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefIndexCache, json);
      return _parseIndex(json);
    } catch (_) {
      return _chargerIndexCache();
    }
  }

  Future<List<CatalogueEnLigneInfo>> _chargerIndexCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefIndexCache);
    if (cached == null) throw Exception('Aucun catalogue disponible hors ligne.');
    return _parseIndex(cached);
  }

  List<CatalogueEnLigneInfo> _parseIndex(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((e) => CatalogueEnLigneInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Télécharge et parse un fichier .catalogue.
  Future<List<CatalogueCategorie>> telechargerCatalogue(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['categories'] as List)
        .map((c) => CatalogueCategorie.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Version du catalogue actuellement importé (null si jamais importé).
  Future<int?> versionLocale(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt('$_prefVersionPrefix$id');
    return v;
  }

  /// Enregistre la version importée d'un catalogue.
  Future<void> sauvegarderVersion(String id, int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefVersionPrefix$id', version);
  }
}
