class AttributionEnseignantSchema {
  static const String tableName = 'attribution_enseignant';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      enseignant_id INTEGER NOT NULL,
      classe_id INTEGER NOT NULL,
      matiere_id INTEGER NOT NULL,
      is_titulaire INTEGER DEFAULT 0,
      volume_horaire REAL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (enseignant_id) REFERENCES enseignant(id),
      FOREIGN KEY (classe_id) REFERENCES classe(id),
      FOREIGN KEY (matiere_id) REFERENCES matiere(id),
      UNIQUE(classe_id, matiere_id)
    )
  ''';
}
