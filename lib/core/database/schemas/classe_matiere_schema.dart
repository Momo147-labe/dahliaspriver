class ClasseMatiereSchema {
  static const String tableName = 'classe_matiere';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      classe_id INTEGER NOT NULL,
      matiere_id INTEGER NOT NULL,
      coefficient REAL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (classe_id) REFERENCES classe(id),
      FOREIGN KEY (matiere_id) REFERENCES matiere(id),
      UNIQUE(classe_id, matiere_id)
    )
  ''';
}
