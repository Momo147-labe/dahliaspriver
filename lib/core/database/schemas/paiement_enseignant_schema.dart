class PaiementEnseignantSchema {
  static const String tableName = 'paiement_enseignant';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      enseignant_id INTEGER NOT NULL,
      annee_scolaire_id INTEGER NOT NULL,
      montant REAL NOT NULL,
      date_paiement TEXT NOT NULL,
      mode_paiement TEXT NOT NULL, -- 'Espèces', 'Virement', 'Chèque', 'Mobile Money'
      type_calcul TEXT NOT NULL, -- 'Fixe', 'Horaire'
      nb_heures REAL,
      taux_horaire REAL,
      periode TEXT NOT NULL, -- e.g., 'Avril 2024'
      observations TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (enseignant_id) REFERENCES enseignant(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
