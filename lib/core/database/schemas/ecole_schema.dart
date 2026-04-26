class EcoleSchema {
  static const String tableName = 'ecole';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      slogan TEXT,
      fondateur TEXT NOT NULL,
      directeur TEXT NOT NULL,
      logo TEXT,             -- chemin ou URL du logo
      timbre TEXT,           -- chemin ou URL du timbre
      adresse TEXT,
      telephone TEXT,
      email TEXT,
      ville TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''';
}
