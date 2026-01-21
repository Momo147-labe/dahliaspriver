class Ecole {
  final int? id;
  final String nom;
  final String fondateur;
  final String directeur;
  final String? logo;
  final String? timbre;
  final String? adresse;
  final String? telephone;
  final String? email;
  final String? createdAt;
  final String? updatedAt;

  Ecole({
    this.id,
    required this.nom,
    required this.fondateur,
    required this.directeur,
    this.logo,
    this.timbre,
    this.adresse,
    this.telephone,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'fondateur': fondateur,
      'directeur': directeur,
      'logo': logo,
      'timbre': timbre,
      'adresse': adresse,
      'telephone': telephone,
      'email': email,
    };
  }

  factory Ecole.fromMap(Map<String, dynamic> map) {
    return Ecole(
      id: map['id'],
      nom: map['nom'],
      fondateur: map['fondateur'],
      directeur: map['directeur'],
      logo: map['logo'],
      timbre: map['timbre'],
      adresse: map['adresse'],
      telephone: map['telephone'],
      email: map['email'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Ecole copyWith({
    int? id,
    String? nom,
    String? fondateur,
    String? directeur,
    String? logo,
    String? timbre,
    String? adresse,
    String? telephone,
    String? email,
  }) {
    return Ecole(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      fondateur: fondateur ?? this.fondateur,
      directeur: directeur ?? this.directeur,
      logo: logo ?? this.logo,
      timbre: timbre ?? this.timbre,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
    );
  }
}
