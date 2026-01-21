class FraisScolaire {
  final int? id;
  final int classeId;
  final int anneeScolaireId;
  final double inscription;
  final double reinscription;
  final double tranche1;
  final String? dateLimiteT1;
  final double tranche2;
  final String? dateLimiteT2;
  final double tranche3;
  final String? dateLimiteT3;
  final double montantTotal;
  final String? createdAt;
  final String? updatedAt;

  FraisScolaire({
    this.id,
    required this.classeId,
    required this.anneeScolaireId,
    this.inscription = 0.0,
    this.reinscription = 0.0,
    this.tranche1 = 0.0,
    this.dateLimiteT1,
    this.tranche2 = 0.0,
    this.dateLimiteT2,
    this.tranche3 = 0.0,
    this.dateLimiteT3,
    this.montantTotal = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  factory FraisScolaire.fromMap(Map<String, dynamic> map) {
    return FraisScolaire(
      id: map['id'] as int?,
      classeId: map['classe_id'] as int,
      anneeScolaireId: map['annee_scolaire_id'] as int,
      inscription: (map['inscription'] as num?)?.toDouble() ?? 0.0,
      reinscription: (map['reinscription'] as num?)?.toDouble() ?? 0.0,
      tranche1: (map['tranche1'] as num?)?.toDouble() ?? 0.0,
      dateLimiteT1: map['date_limite_t1'] as String?,
      tranche2: (map['tranche2'] as num?)?.toDouble() ?? 0.0,
      dateLimiteT2: map['date_limite_t2'] as String?,
      tranche3: (map['tranche3'] as num?)?.toDouble() ?? 0.0,
      dateLimiteT3: map['date_limite_t3'] as String?,
      montantTotal: (map['montant_total'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'classe_id': classeId,
      'annee_scolaire_id': anneeScolaireId,
      'inscription': inscription,
      'reinscription': reinscription,
      'tranche1': tranche1,
      'date_limite_t1': dateLimiteT1,
      'tranche2': tranche2,
      'date_limite_t2': dateLimiteT2,
      'tranche3': tranche3,
      'date_limite_t3': dateLimiteT3,
      'montant_total': montantTotal,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  FraisScolaire copyWith({
    int? id,
    int? classeId,
    int? anneeScolaireId,
    double? inscription,
    double? reinscription,
    double? tranche1,
    String? dateLimiteT1,
    double? tranche2,
    String? dateLimiteT2,
    double? tranche3,
    String? dateLimiteT3,
    double? montantTotal,
    String? createdAt,
    String? updatedAt,
  }) {
    return FraisScolaire(
      id: id ?? this.id,
      classeId: classeId ?? this.classeId,
      anneeScolaireId: anneeScolaireId ?? this.anneeScolaireId,
      inscription: inscription ?? this.inscription,
      reinscription: reinscription ?? this.reinscription,
      tranche1: tranche1 ?? this.tranche1,
      dateLimiteT1: dateLimiteT1 ?? this.dateLimiteT1,
      tranche2: tranche2 ?? this.tranche2,
      dateLimiteT2: dateLimiteT2 ?? this.dateLimiteT2,
      tranche3: tranche3 ?? this.tranche3,
      dateLimiteT3: dateLimiteT3 ?? this.dateLimiteT3,
      montantTotal: montantTotal ?? this.montantTotal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get calculatedTotal => inscription + reinscription + tranche1 + tranche2 + tranche3;
}