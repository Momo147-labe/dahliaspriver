class PaiementSchema {
  static const String tableName = 'paiement';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      eleve_id INTEGER NOT NULL,
      classe_id INTEGER,
      frais_id INTEGER,
      annee_scolaire_id INTEGER NOT NULL,
      montant_total REAL NOT NULL,
      montant_paye REAL DEFAULT 0,
      montant_restant REAL NOT NULL,
      date_paiement TEXT,
      type_paiement TEXT,
      mode_paiement TEXT,
      reference_paiement TEXT,
      statut TEXT CHECK (statut IN ('Réglé', 'Partiel', 'Impayé')) DEFAULT 'Impayé',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (eleve_id) REFERENCES eleve(id),
      FOREIGN KEY (classe_id) REFERENCES classe(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
