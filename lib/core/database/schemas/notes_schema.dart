class NotesSchema {
  static const String tableName = 'notes';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      eleve_id INTEGER NOT NULL,
      matiere_id INTEGER NOT NULL,
      note REAL NOT NULL,
      coefficient REAL DEFAULT 1,
      trimestre INTEGER,
      sequence INTEGER DEFAULT 1,
      annee_scolaire_id INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (eleve_id) REFERENCES eleve(id),
      FOREIGN KEY (matiere_id) REFERENCES matiere(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
