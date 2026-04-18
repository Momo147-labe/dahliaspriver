class UserSchema {
  static const String tableName = 'user';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pseudo TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      role TEXT NOT NULL, -- 'admin', 'direction', 'secretaire', 'comptable'
      nom_complet TEXT,
      email TEXT,
      codesecret TEXT,
      actif INTEGER DEFAULT 1,
      last_login TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''';
}
