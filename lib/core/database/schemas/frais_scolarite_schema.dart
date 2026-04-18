class FraisScolariteSchema {
  static const String tableName = 'frais_scolarite';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      classe_id INTEGER NOT NULL,
      annee_scolaire_id INTEGER NOT NULL,
      inscription REAL DEFAULT 0,
      reinscription REAL DEFAULT 0,
      tranche1 REAL DEFAULT 0,
      date_limite_t1 TEXT,
      tranche2 REAL DEFAULT 0,
      date_limite_t2 TEXT,
      tranche3 REAL DEFAULT 0,
      date_limite_t3 TEXT,
      montant_total REAL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (classe_id) REFERENCES classe(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
