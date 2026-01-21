class Matiere {
  final int? id;
  final String nom;

  Matiere({this.id, required this.nom});

  factory Matiere.fromMap(Map<String, dynamic> map) {
    return Matiere(id: map['id'] as int?, nom: map['nom'] as String? ?? '');
  }

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'nom': nom};
  }

  Matiere copyWith({int? id, String? nom}) {
    return Matiere(id: id ?? this.id, nom: nom ?? this.nom);
  }
}
