class ClasseSchema {
  static const String tableName = 'classe';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      cycle_id INTEGER,
      salle TEXT,
      niveau_id INTEGER,
      eff_max INTEGER DEFAULT 100,
      next_class_id INTEGER,
      is_final_class INTEGER DEFAULT 0,
      prof_principal_id INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (prof_principal_id) REFERENCES enseignant(id),
      FOREIGN KEY (next_class_id) REFERENCES $tableName(id),
      FOREIGN KEY (cycle_id) REFERENCES cycles_scolaires(id),
      FOREIGN KEY (niveau_id) REFERENCES niveaux(id)
    )
  ''';
}
