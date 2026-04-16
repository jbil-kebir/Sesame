class Raccourci {
  final String id;
  String nom;
  String url;
  String? login;

  Raccourci({
    required this.id,
    required this.nom,
    required this.url,
    this.login,
  });

  factory Raccourci.fromJson(Map<String, dynamic> json) {
    return Raccourci(
      id: json['id'],
      nom: json['nom'],
      url: json['url'],
      login: json['login'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'url': url,
      if (login != null) 'login': login,
    };
  }
}
