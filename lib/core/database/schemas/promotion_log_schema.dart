class PromotionLogSchema {
  static const String tableName = 'promotion_log';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_annee_depart INTEGER NOT NULL,
      classe_depart_id INTEGER NOT NULL,
      id_annee_arriver INTEGER NOT NULL,
      classe_arriver_id INTEGER NOT NULL,
      cread_date TEXT DEFAULT CURRENT_TIMESTAMP,
      status TEXT,
      FOREIGN KEY (id_annee_depart) REFERENCES annee_scolaire(id),
      FOREIGN KEY (classe_depart_id) REFERENCES classe(id),
      FOREIGN KEY (id_annee_arriver) REFERENCES annee_scolaire(id),
      FOREIGN KEY (classe_arriver_id) REFERENCES classe(id)
    )
  ''';
}
