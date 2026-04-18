class EleveParcoursSchema {
  static const String tableName = 'eleve_parcours';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      eleve_id INTEGER NOT NULL,
      classe_id INTEGER NOT NULL,
      annee_scolaire_id INTEGER NOT NULL,
      decision TEXT, -- 'Admis', 'Redoublant', 'Sorti'
      moyenne REAL,
      rang INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (eleve_id) REFERENCES eleve(id),
      FOREIGN KEY (classe_id) REFERENCES classe(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
