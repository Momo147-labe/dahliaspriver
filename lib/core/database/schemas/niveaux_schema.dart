class NiveauxSchema {
  static const String tableName = 'niveaux';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      ordre INTEGER NOT NULL,
      cycle_id INTEGER NOT NULL,
      moyenne_passage REAL,
      is_examen INTEGER DEFAULT 0,
      actif INTEGER DEFAULT 1,
      next_niveau_id INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (cycle_id) REFERENCES cycles_scolaires(id)
    )
  ''';
}
