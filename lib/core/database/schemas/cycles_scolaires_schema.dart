class CyclesScolairesSchema {
  static const String tableName = 'cycles_scolaires';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      ordre INTEGER NOT NULL,
      note_min REAL NOT NULL DEFAULT 0,
      note_max REAL NOT NULL DEFAULT 20,
      moyenne_passage REAL NOT NULL,
      is_terminal INTEGER DEFAULT 0,
      actif INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''';
}
