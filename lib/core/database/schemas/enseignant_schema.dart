class EnseignantSchema {
  static const String tableName = 'enseignant';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matricule TEXT UNIQUE,
      nom TEXT NOT NULL,
      prenom TEXT NOT NULL,
      telephone TEXT,
      email TEXT,
      specialite TEXT,
      date_embauche TEXT,
      photo TEXT,
      statut TEXT DEFAULT 'Actif',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''';
}
