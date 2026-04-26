class Enseignant {
  final int? id;
  final String? matricule;
  final String nom;
  final String prenom;
  final String? telephone;
  final String? email;
  final String? specialite;
  final String? sexe; // 'M' ou 'F'
  final String? photo;
  final String? dateNaissance;
  final String? typeRemuneration; // 'Fixe' ou 'Horaire'
  final double? salaireBase;

  Enseignant({
    this.id,
    this.matricule,
    required this.nom,
    required this.prenom,
    this.telephone,
    this.email,
    this.specialite,
    this.sexe,
    this.photo,
    this.dateNaissance,
    this.typeRemuneration = 'Fixe',
    this.salaireBase = 0.0,
  });

  factory Enseignant.fromMap(Map<String, dynamic> map) {
    return Enseignant(
      id: map['id'] as int?,
      matricule: map['matricule'] as String?,
      nom: map['nom'] as String? ?? '',
      prenom: map['prenom'] as String? ?? '',
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      specialite: map['specialite'] as String?,
      sexe: map['sexe'] as String?,
      photo: map['photo'] as String?,
      dateNaissance: map['date_naissance'] as String?,
      typeRemuneration: map['type_remuneration'] as String? ?? 'Fixe',
      salaireBase: (map['salaire_base'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'specialite': specialite,
      'sexe': sexe,
      'photo': photo,
      'date_naissance': dateNaissance,
      'type_remuneration': typeRemuneration,
      'salaire_base': salaireBase,
    };
  }

  String get nomComplet => '$prenom $nom';

  Enseignant copyWith({
    int? id,
    String? matricule,
    String? nom,
    String? prenom,
    String? telephone,
    String? email,
    String? specialite,
    String? sexe,
    String? photo,
    String? dateNaissance,
    String? typeRemuneration,
    double? salaireBase,
  }) {
    return Enseignant(
      id: id ?? this.id,
      matricule: matricule ?? this.matricule,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      specialite: specialite ?? this.specialite,
      sexe: sexe ?? this.sexe,
      photo: photo ?? this.photo,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      typeRemuneration: typeRemuneration ?? this.typeRemuneration,
      salaireBase: salaireBase ?? this.salaireBase,
    );
  }
}
