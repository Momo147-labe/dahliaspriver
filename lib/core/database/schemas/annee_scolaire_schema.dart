class AnneeScolaireSchema {
  static const String tableName = 'annee_scolaire';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      libelle TEXT NOT NULL,
      date_debut TEXT NOT NULL,
      date_fin TEXT NOT NULL,
      active INTEGER DEFAULT 0,
      statut TEXT CHECK (statut IN ('Active', 'Inactive', 'Terminée')) DEFAULT 'Active',
      annee_precedente_id INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (annee_precedente_id) REFERENCES $tableName(id)
    )
  ''';
}
