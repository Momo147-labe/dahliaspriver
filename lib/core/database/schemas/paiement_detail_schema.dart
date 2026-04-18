class PaiementDetailSchema {
  static const String tableName = 'paiement_detail';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      eleve_id INTEGER NOT NULL,
      montant REAL NOT NULL,
      date_paiement TEXT NOT NULL,
      type_frais TEXT NOT NULL, -- 'inscription', 'scolarite', etc.
      mode_paiement TEXT NOT NULL, -- 'Espèces', 'Virement', 'Chèque', 'Mobile Money'
      observation TEXT,
      annee_scolaire_id INTEGER NOT NULL,
      classe_id INTEGER,
      frais_id INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (eleve_id) REFERENCES eleve(id),
      FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
    )
  ''';
}
