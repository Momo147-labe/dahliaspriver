class EleveSchema {
  static const String tableName = 'eleve';

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS \$tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matricule TEXT UNIQUE NOT NULL,
      nom TEXT NOT NULL,
      prenom TEXT NOT NULL,
      date_naissance TEXT,
      lieu_naissance TEXT,
      sexe TEXT CHECK (sexe IN ('M','F')),
      classe_id INTEGER NOT NULL,
      statut TEXT CHECK (statut IN ('inscrit','reinscrit','sorti')) DEFAULT 'inscrit',
      annee_scolaire_id INTEGER,
      frais_id INTEGER,
      photo TEXT,
      nom_pere TEXT,
      prenom_pere TEXT,
      nom_mere TEXT,
      prenom_mere TEXT,
      personne_a_prevenir TEXT,
      contact_urgence TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (classe_id) REFERENCES classe(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
