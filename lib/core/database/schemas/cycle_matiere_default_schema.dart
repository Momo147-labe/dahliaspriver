class CycleMatiereDefaultSchema {
  static const String tableName = 'cycle_matiere_default';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cycle_id INTEGER NOT NULL,
      matiere_nom TEXT NOT NULL,
      coefficient REAL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (cycle_id) REFERENCES cycles_scolaires(id),
      UNIQUE(cycle_id, matiere_nom)
    )
  ''';
}
