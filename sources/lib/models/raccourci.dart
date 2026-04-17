class Raccourci {
  final String id;
  String nom;
  String url;
  String? login;
  bool estSeparateur;

  Raccourci({
    required this.id,
    required this.nom,
    required this.url,
    this.login,
    this.estSeparateur = false,
  });

  factory Raccourci.separateur(String id) =>
      Raccourci(id: id, nom: '', url: '', estSeparateur: true);

  factory Raccourci.fromJson(Map<String, dynamic> json) {
    return Raccourci(
      id: json['id'],
      nom: json['nom'],
      url: json['url'],
      login: json['login'],
      estSeparateur: json['separateur'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'url': url,
      if (login != null) 'login': login,
      if (estSeparateur) 'separateur': true,
    };
  }
}
