class EmploiDuTemps {
  final int? id;
  final int classeId;
  final int matiereId;
  final int? enseignantId;
  final int jourSemaine; // 1: Lundi, 2: Mardi, ..., 7: Dimanche
  final String heureDebut; // Format "HH:mm"
  final String heureFin; // Format "HH:mm"
  final String? salle;
  final int? anneeScolaireId;

  // Fields joined from other tables
  final String? matiereNom;
  final String? enseignantNom;
  final String? enseignantPrenom;

  EmploiDuTemps({
    this.id,
    required this.classeId,
    required this.matiereId,
    this.enseignantId,
    required this.jourSemaine,
    required this.heureDebut,
    required this.heureFin,
    this.salle,
    this.anneeScolaireId,
    this.matiereNom,
    this.enseignantNom,
    this.enseignantPrenom,
  });

  factory EmploiDuTemps.fromMap(Map<String, dynamic> map) {
    return EmploiDuTemps(
      id: map['id'] as int?,
      classeId: map['classe_id'] as int? ?? 0,
      matiereId: map['matiere_id'] as int? ?? 0,
      enseignantId: map['enseignant_id'] as int?,
      jourSemaine: map['jour_semaine'] as int? ?? 1,
      heureDebut: map['heure_debut'] as String? ?? '',
      heureFin: map['heure_fin'] as String? ?? '',
      salle: map['salle'] as String?,
      anneeScolaireId: map['annee_scolaire_id'] as int?,
      matiereNom: map['matiere_nom'] as String?,
      enseignantNom: map['enseignant_nom'] as String?,
      enseignantPrenom: map['enseignant_prenom'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'classe_id': classeId,
      'matiere_id': matiereId,
      'enseignant_id': enseignantId,
      'jour_semaine': jourSemaine,
      'heure_debut': heureDebut,
      'heure_fin': heureFin,
      'salle': salle,
      'annee_scolaire_id': anneeScolaireId,
    };
  }

  String get enseignantNomComplet =>
      enseignantPrenom != null && enseignantNom != null
      ? '$enseignantPrenom $enseignantNom'
      : 'Non assigné';

  EmploiDuTemps copyWith({
    int? id,
    int? classeId,
    int? matiereId,
    int? enseignantId,
    int? jourSemaine,
    String? heureDebut,
    String? heureFin,
    String? salle,
    int? anneeScolaireId,
  }) {
    return EmploiDuTemps(
      id: id ?? this.id,
      classeId: classeId ?? this.classeId,
      matiereId: matiereId ?? this.matiereId,
      enseignantId: enseignantId ?? this.enseignantId,
      jourSemaine: jourSemaine ?? this.jourSemaine,
      heureDebut: heureDebut ?? this.heureDebut,
      heureFin: heureFin ?? this.heureFin,
      salle: salle ?? this.salle,
      anneeScolaireId: anneeScolaireId ?? this.anneeScolaireId,
    );
  }
}
