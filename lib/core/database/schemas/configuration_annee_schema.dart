class ConfigurationAnneeSchema {
  static const String tableName = 'configuration_annee';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      annee_scolaire_id INTEGER,
      moyenne_passage_cycle1 REAL DEFAULT 10.0,
      moyenne_passage_cycle2 REAL DEFAULT 10.0,
      moyenne_passage_cycle3 REAL DEFAULT 10.0,
      moyenne_generale_min REAL DEFAULT 10.0,
      appreciation_excellent TEXT DEFAULT 'Excellent',
      appreciation_tres_bien TEXT DEFAULT 'Tr\u00C3\u00A8s bien',
      appreciation_bien TEXT DEFAULT 'Bien',
      appreciation_abien TEXT DEFAULT 'Assez bien',
      appreciation_passable TEXT DEFAULT 'Passable',
      appreciation_insuffisant TEXT DEFAULT 'Insuffisant',
      mode_calcul_moyenne TEXT DEFAULT 'trimestrielle',
      use_custom_mentions INTEGER DEFAULT 1,
      base_notation REAL DEFAULT 20.0,
      include_conduite INTEGER DEFAULT 1,
      nombre_sequences_trimestre INTEGER DEFAULT 3,
      nombre_trimestres_annee INTEGER DEFAULT 3,
      coefficient_max_matiere REAL DEFAULT 10.0,
      note_maximale REAL DEFAULT 20.0,
      note_minimale REAL DEFAULT 0.0,
      appreciation_automatique INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(annee_scolaire_id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
