class DocumentTemplateSchema {
  static const String tableName = 'document_templates';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      annee_scolaire_id INTEGER,
      type TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id) ON DELETE CASCADE
    )
  ''';
}
