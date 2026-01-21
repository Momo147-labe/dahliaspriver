class Enseignant {
  final int? id;
  final String nom;
  final String prenom;
  final String? telephone;
  final String? email;
  final String? specialite;
  final String? sexe; // 'M' ou 'F'
  final String? photo;
  final String? dateNaissance;

  Enseignant({
    this.id,
    required this.nom,
    required this.prenom,
    this.telephone,
    this.email,
    this.specialite,
    this.sexe,
    this.photo,
    this.dateNaissance,
  });

  factory Enseignant.fromMap(Map<String, dynamic> map) {
    return Enseignant(
      id: map['id'] as int?,
      nom: map['nom'] as String? ?? '',
      prenom: map['prenom'] as String? ?? '',
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      specialite: map['specialite'] as String?,
      sexe: map['sexe'] as String?,
      photo: map['photo'] as String?,
      dateNaissance: map['date_naissance'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'specialite': specialite,
      'sexe': sexe,
      'photo': photo,
      'date_naissance': dateNaissance,
    };
  }

  String get nomComplet => '$prenom $nom';

  Enseignant copyWith({
    int? id,
    String? nom,
    String? prenom,
    String? telephone,
    String? email,
    String? specialite,
    String? sexe,
    String? photo,
    String? dateNaissance,
  }) {
    return Enseignant(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      specialite: specialite ?? this.specialite,
      sexe: sexe ?? this.sexe,
      photo: photo ?? this.photo,
      dateNaissance: dateNaissance ?? this.dateNaissance,
    );
  }
}
