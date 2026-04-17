class CatalogueEnLigneInfo {
  final String id;
  final String nom;
  final String description;
  final int version;
  final String updated;
  final int nbRaccourcis;
  final String url;

  const CatalogueEnLigneInfo({
    required this.id,
    required this.nom,
    required this.description,
    required this.version,
    required this.updated,
    required this.nbRaccourcis,
    required this.url,
  });

  factory CatalogueEnLigneInfo.fromJson(Map<String, dynamic> json) {
    return CatalogueEnLigneInfo(
      id: json['id'] as String,
      nom: json['nom'] as String,
      description: json['description'] as String,
      version: json['version'] as int,
      updated: json['updated'] as String,
      nbRaccourcis: json['nb_raccourcis'] as int,
      url: json['url'] as String,
    );
  }
}
