class EmploiDuTempsSchema {
  static const String tableName = 'emploi_du_temps';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      classe_id INTEGER,
      matiere_id INTEGER,
      enseignant_id INTEGER,
      annee_scolaire_id INTEGER,
      jour_semaine TEXT, -- 'Lundi', 'Mardi', etc.
      heure_debut TEXT,
      heure_fin TEXT,
      salle TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (classe_id) REFERENCES classe(id),
      FOREIGN KEY (matiere_id) REFERENCES matiere(id),
      FOREIGN KEY (enseignant_id) REFERENCES enseignant(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
