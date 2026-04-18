import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/catalogue.dart';

class CatalogueService {
  Future<List<CatalogueCategorie>> chargerCategories() async {
    final jsonStr = await rootBundle.loadString('assets/default.catalogue');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return (data['categories'] as List)
        .map((c) => CatalogueCategorie.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}
