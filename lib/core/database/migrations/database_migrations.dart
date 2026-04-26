import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../schemas/document_template_schema.dart';
import '../schemas/cycle_matiere_default_schema.dart';

class DatabaseMigrations {
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migration vers version 10/11: Ajout de la table matiere_coeff
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS matiere_coeff (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          matiere_id INTEGER NOT NULL,
          cycle TEXT,            
          option_lycee TEXT,     
          coefficient REAL DEFAULT 1,
          FOREIGN KEY (matiere_id) REFERENCES matiere(id)
        )
      ''');
    }

    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS enseignant (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          prenom TEXT NOT NULL,
          telephone TEXT,
          email TEXT,
          specialite TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS emploi_du_temps (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          classe_id INTEGER NOT NULL,
          matiere_id INTEGER NOT NULL,
          enseignant_id INTEGER,
          jour_semaine INTEGER NOT NULL,
          heure_debut TEXT NOT NULL,
          heure_fin TEXT NOT NULL,
          salle TEXT,
          annee_scolaire_id INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (classe_id) REFERENCES classe(id),
          FOREIGN KEY (matiere_id) REFERENCES matiere(id),
          FOREIGN KEY (enseignant_id) REFERENCES enseignant(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
        )
      ''');
    }

    if (oldVersion < 13) {
      // Ajout initial des champs v13 (déjà fait ou tenté)
    }

    if (oldVersion < 14) {
      // On s'assure que TOUTES les colonnes nécessaires existent
      final columns = {
        'specialite': 'TEXT',
        'sexe': 'TEXT CHECK (sexe IN ("M","F"))',
        'photo': 'TEXT',
        'date_naissance': 'TEXT',
      };

      for (var entry in columns.entries) {
        await addColumnSafely(db, 'enseignant', entry.key, entry.value);
      }
    }

    if (oldVersion < 15) {
      await addColumnSafely(db, 'notes', 'sequence', 'INTEGER DEFAULT 1');
    }

    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS frais_scolarite (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          classe_id INTEGER NOT NULL,
          annee_scolaire_id INTEGER NOT NULL,
          inscription REAL DEFAULT 0,
          reinscription REAL DEFAULT 0,
          tranche1 REAL DEFAULT 0,
          date_limite_t1 TEXT,
          tranche2 REAL DEFAULT 0,
          date_limite_t2 TEXT,
          tranche3 REAL DEFAULT 0,
          date_limite_t3 TEXT,
          montant_total REAL DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (classe_id) REFERENCES classe(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS paiement_detail (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eleve_id INTEGER NOT NULL,
          montant REAL NOT NULL,
          date_paiement TEXT NOT NULL,
          mode_paiement TEXT,
          type_frais TEXT,
          mois TEXT,
          annee_scolaire_id INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (eleve_id) REFERENCES eleve(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
        )
      ''');
    }

    if (oldVersion < 17) {
      // Fix paiement_detail table structure - drop old table and recreate with correct schema
      await db.execute('DROP TABLE IF EXISTS paiement_detail');
      await db.execute('''
        CREATE TABLE paiement_detail (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eleve_id INTEGER NOT NULL,
          montant REAL NOT NULL,
          date_paiement TEXT NOT NULL,
          mode_paiement TEXT,
          type_frais TEXT,
          mois TEXT,
          annee_scolaire_id INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (eleve_id) REFERENCES eleve(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
        )
      ''');
    }

    if (oldVersion < 18) {
      // Update paiement table with comprehensive payment tracking fields
      await db.execute('DROP TABLE IF EXISTS paiement');
      await db.execute('''
        CREATE TABLE paiement (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eleve_id INTEGER NOT NULL,
          classe_id INTEGER,
          frais_id INTEGER,
          montant_total REAL NOT NULL,
          montant_paye REAL DEFAULT 0,
          montant_restant REAL DEFAULT 0,
          mode_paiement TEXT,
          reference_paiement TEXT,
          date_paiement TEXT,
          type_paiement TEXT,
          statut TEXT,
          annee_scolaire_id INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (eleve_id) REFERENCES eleve(id),
          FOREIGN KEY (classe_id) REFERENCES classe(id),
          FOREIGN KEY (frais_id) REFERENCES frais_scolarite(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
        )
      ''');
    }

    if (oldVersion < 19) {
      // Create eleve_parcours table for tracking student enrollment history
      await db.execute('''
        CREATE TABLE IF NOT EXISTS eleve_parcours (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eleve_id INTEGER NOT NULL,
          classe_id INTEGER NOT NULL,
          annee_scolaire_id INTEGER NOT NULL,
          type_inscription TEXT,
          date_inscription TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (eleve_id) REFERENCES eleve(id),
          FOREIGN KEY (classe_id) REFERENCES classe(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
        )
      ''');
    }

    if (oldVersion < 21) {
      await addColumnSafely(db, 'paiement_detail', 'observation', 'TEXT');
    }

    if (oldVersion < 22) {
      // Ensuring observation column exists because version 21 upgrade might have been skipped for some users
      await addColumnSafely(db, 'paiement_detail', 'observation', 'TEXT');
    }

    if (oldVersion < 24) {
      await addColumnSafely(db, 'paiement_detail', 'classe_id', 'INTEGER');
      await addColumnSafely(db, 'paiement_detail', 'frais_id', 'INTEGER');
    }

    if (oldVersion < 25) {
      // Ensure 'eleve' table has all necessary columns
      await addColumnSafely(db, 'eleve', 'annee_scolaire_id', 'INTEGER');
      await addColumnSafely(db, 'eleve', 'frais_id', 'INTEGER');
      await addColumnSafely(db, 'eleve', 'photo', 'TEXT');
      await addColumnSafely(db, 'eleve', 'statut', 'TEXT');

      // Ensure 'paiement_detail' has 'annee_scolaire_id'
      await addColumnSafely(
        db,
        'paiement_detail',
        'annee_scolaire_id',
        'INTEGER',
      );
    }

    if (oldVersion < 26) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attribution_enseignant (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          classe_id INTEGER NOT NULL,
          matiere_id INTEGER NOT NULL,
          enseignant_id INTEGER NOT NULL,
          annee_scolaire_id INTEGER NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (classe_id) REFERENCES classe(id),
          FOREIGN KEY (matiere_id) REFERENCES matiere(id),
          FOREIGN KEY (enseignant_id) REFERENCES enseignant(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id),
          UNIQUE(classe_id, matiere_id, annee_scolaire_id)
        )
      ''');
    }

    if (oldVersion < 27) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS classe_matiere (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          classe_id INTEGER NOT NULL,
          matiere_id INTEGER NOT NULL,
          annee_scolaire_id INTEGER NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (classe_id) REFERENCES classe(id),
          FOREIGN KEY (matiere_id) REFERENCES matiere(id),
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id),
          UNIQUE(classe_id, matiere_id, annee_scolaire_id)
        )
      ''');
    }

    if (oldVersion < 28) {
      await addColumnSafely(
        db,
        'classe_matiere',
        'coefficient',
        'REAL DEFAULT 1',
      );
    }

    if (oldVersion < 29) {
      await addColumnSafely(db, 'notes', 'coefficient', 'REAL DEFAULT 1');
    }

    if (oldVersion < 30) {
      // 1. Create new configuration tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mention_config (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          label TEXT NOT NULL,
          note_min REAL NOT NULL,
          note_max REAL NOT NULL,
          couleur TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS appreciation_config (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          note_min REAL NOT NULL,
          note_max REAL NOT NULL,
          commentaire_type TEXT NOT NULL,
          categorie TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 2. Helper to add columns safely to existing tables
      // 3. Update existing tables
      await addColumnSafely(
        db,
        'annee_scolaire',
        'annee_precedente_id',
        'INTEGER',
      );

      await addColumnSafely(
        db,
        'classe',
        'moyenne_min_promotion',
        'REAL DEFAULT 10.0',
      );
      await addColumnSafely(
        db,
        'classe',
        'moyenne_max_promotion',
        'REAL DEFAULT 20.0',
      );
      await addColumnSafely(
        db,
        'classe',
        'created_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await addColumnSafely(
        db,
        'classe',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await addColumnSafely(
        db,
        'eleve',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await addColumnSafely(
        db,
        'matiere',
        'created_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await addColumnSafely(
        db,
        'matiere',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await addColumnSafely(
        db,
        'notes',
        'created_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await addColumnSafely(
        db,
        'notes',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );

      await addColumnSafely(
        db,
        'configuration_annee',
        'mode_calcul_moyenne',
        'TEXT DEFAULT "trimestrielle"',
      );
      await addColumnSafely(
        db,
        'configuration_annee',
        'use_custom_mentions',
        'INTEGER DEFAULT 1',
      );
      await addColumnSafely(
        db,
        'cycles_scolaires',
        'moyenne_passage_cycle',
        'REAL DEFAULT 10.0',
      );
      await addColumnSafely(
        db,
        'cycles_scolaires',
        'moyenne_excellence_cycle',
        'REAL DEFAULT 15.0',
      );
    }

    if (oldVersion < 31) {
      await addColumnSafely(db, 'cycles_scolaires', 'sous_titre_cycle', 'TEXT');
      await addColumnSafely(
        db,
        'cycles_scolaires',
        'droit_redoublement',
        'INTEGER DEFAULT 1',
      );
      await addColumnSafely(
        db,
        'cycles_scolaires',
        'seuil_redoublement',
        'REAL DEFAULT 8.0',
      );
    }

    if (oldVersion < 32) {
      await addColumnSafely(
        db,
        'configuration_annee',
        'base_notation',
        'REAL DEFAULT 20.0',
      );
      await addColumnSafely(
        db,
        'configuration_annee',
        'include_conduite',
        'INTEGER DEFAULT 1',
      );
      await addColumnSafely(db, 'mention_config', 'cycle_id', 'INTEGER');
    }

    if (oldVersion < 34) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sequence_planification (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          annee_scolaire_id INTEGER,
          trimestre INTEGER,
          numero_sequence INTEGER,
          nom TEXT,
          date_debut TEXT,
          date_fin TEXT,
          poids REAL,
          statut TEXT,
          FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
        )
      ''');
    }

    if (oldVersion < 35) {
      // Migration de cycles_scolaires vers le nouveau schéma
      // 1. Renommer l'ancienne table
      await db.execute(
        'ALTER TABLE cycles_scolaires RENAME TO cycles_scolaires_old',
      );

      // 2. Créer la nouvelle table
      await db.execute('''
        CREATE TABLE cycles_scolaires (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          ordre INTEGER NOT NULL,
          niveau_min INTEGER NOT NULL,
          niveau_max INTEGER NOT NULL,
          moyenne_passage REAL NOT NULL,
          is_terminal INTEGER DEFAULT 0,
          actif INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 3. Copier les données
      await db.execute('''
        INSERT INTO cycles_scolaires (id, nom, ordre, niveau_min, niveau_max, moyenne_passage, actif, created_at, updated_at)
        SELECT id, nom_cycle, ordre_cycle, niveau_min, niveau_max, moyenne_passage_cycle, actif, created_at, updated_at
        FROM cycles_scolaires_old
      ''');

      // 4. Supprimer l'ancienne table
      await db.execute('DROP TABLE cycles_scolaires_old');

      // 5. Créer la table niveaux
      await db.execute('''
        CREATE TABLE IF NOT EXISTS niveaux (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          ordre INTEGER NOT NULL,
          cycle_id INTEGER NOT NULL,
          moyenne_passage REAL,
          is_examen INTEGER DEFAULT 0,
          actif INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (cycle_id) REFERENCES cycles_scolaires(id)
        )
      ''');
    }

    if (oldVersion < 36) {
      await addColumnSafely(db, 'mention_config', 'appreciation', 'TEXT');
      await addColumnSafely(db, 'mention_config', 'icone', 'TEXT');
    }

    if (oldVersion < 37) {
      await addColumnSafely(
        db,
        'annee_scolaire',
        'statut',
        "TEXT CHECK (statut IN ('Active', 'Inactive')) DEFAULT 'Active'",
      );
      await addColumnSafely(
        db,
        'annee_scolaire',
        'annee_precedente_id',
        "INTEGER REFERENCES annee_scolaire(id)",
      );
    }

    if (oldVersion < 38) {
      await addColumnSafely(db, 'eleve', 'personne_a_prevenir', 'TEXT');
      await addColumnSafely(db, 'eleve', 'contact_urgence', 'TEXT');
    }

    if (oldVersion < 39) {
      // Rename niveau_min/niveau_max to note_min/note_max in cycles_scolaires
      try {
        // SQLite doesn't support renaming columns directly, so we need to recreate the table
        await db.execute('''
          CREATE TABLE cycles_scolaires_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT NOT NULL,
            ordre INTEGER NOT NULL,
            note_min REAL NOT NULL DEFAULT 0,
            note_max REAL NOT NULL DEFAULT 20,
            moyenne_passage REAL NOT NULL,
            is_terminal INTEGER DEFAULT 0,
            actif INTEGER DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Copy data from old table to new table
        await db.execute('''
          INSERT INTO cycles_scolaires_new (id, nom, ordre, note_min, note_max, moyenne_passage, is_terminal, actif, created_at, updated_at)
          SELECT id, nom, ordre, niveau_min, niveau_max, moyenne_passage, is_terminal, actif, created_at, updated_at
          FROM cycles_scolaires
        ''');

        // Drop old table
        await db.execute('DROP TABLE cycles_scolaires');

        // Rename new table to original name
        await db.execute(
          'ALTER TABLE cycles_scolaires_new RENAME TO cycles_scolaires',
        );

        debugPrint(
          'Successfully migrated cycles_scolaires to use note_min/note_max',
        );
      } catch (e) {
        debugPrint('Error during v39 migration: $e');
      }
    }

    if (oldVersion < 41) {
      debugPrint(
        'Mise à jour vers la version 41 : Refonte de la table classe (Tentative 2)',
      );
      try {
        // Vérifier si la migration a déjà été faite (précaution)
        var tableInfo = await db.rawQuery("PRAGMA table_info(classe)");
        bool alreadyMigrated = tableInfo.any(
          (col) => col['name'] == 'cycle_id',
        );

        if (!alreadyMigrated) {
          // 1. Création de la nouvelle table classe avec le schéma mis à jour
          await db.execute('''
            CREATE TABLE classe_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom TEXT NOT NULL,
              cycle_id INTEGER,
              salle TEXT,
              niveau_id INTEGER,
              eff_max INTEGER DEFAULT 100,
              next_class_id INTEGER,
              is_final_class INTEGER DEFAULT 0,
              annee_scolaire_id INTEGER,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id),
              FOREIGN KEY (next_class_id) REFERENCES classe(id),
              FOREIGN KEY (cycle_id) REFERENCES cycles_scolaires(id),
              FOREIGN KEY (niveau_id) REFERENCES niveaux(id)
            )
          ''');

          // 2. Migration des données
          final List<Map<String, dynamic>> oldClasses = await db.query(
            'classe',
          );

          for (var oldClasse in oldClasses) {
            // Dans l'ancienne table, c'était 'cycle' et 'niveau'
            final String? cycleName = oldClasse['cycle'] as String?;
            final String? niveauName = oldClasse['niveau'] as String?;

            int? cycleId;
            int? niveauId;

            if (cycleName != null && cycleName.isNotEmpty) {
              final List<Map<String, dynamic>> cycles = await db.query(
                'cycles_scolaires',
                where: 'nom = ?',
                whereArgs: [cycleName],
              );

              if (cycles.isNotEmpty) {
                cycleId = cycles.first['id'] as int;
              } else {
                cycleId = await db.insert('cycles_scolaires', {
                  'nom': cycleName,
                  'ordre': 0,
                  'note_min': 0.0,
                  'note_max': 20.0,
                  'moyenne_passage': 10.0,
                });
              }
            }

            if (niveauName != null &&
                niveauName.isNotEmpty &&
                cycleId != null) {
              final List<Map<String, dynamic>> levels = await db.query(
                'niveaux',
                where: 'nom = ? AND cycle_id = ?',
                whereArgs: [niveauName, cycleId],
              );

              if (levels.isNotEmpty) {
                niveauId = levels.first['id'] as int;
              } else {
                niveauId = await db.insert('niveaux', {
                  'nom': niveauName,
                  'ordre': 0,
                  'cycle_id': cycleId,
                  'moyenne_passage': 10.0,
                });
              }
            }

            await db.insert('classe_new', {
              'id': oldClasse['id'],
              'nom': oldClasse['nom'],
              'cycle_id': cycleId,
              'salle': oldClasse['salle'],
              'niveau_id': niveauId,
              'eff_max': oldClasse['eff_max'],
              'next_class_id': oldClasse['next_class_id'],
              'is_final_class': oldClasse['is_final_class'],
              'annee_scolaire_id': oldClasse['annee_scolaire_id'],
              'created_at': oldClasse['created_at'],
              'updated_at': oldClasse['updated_at'],
            });
          }

          // 3. Remplacement
          await db.execute('DROP TABLE classe');
          await db.execute('ALTER TABLE classe_new RENAME TO classe');
          debugPrint('Migration vers la version 41 terminée avec succès.');
        } else {
          debugPrint(
            'La table classe semble déjà être à jour (cycle_id présent).',
          );
        }
      } catch (e) {
        debugPrint('Erreur lors de la migration vers la version 41 : $e');
      }
    }

    if (oldVersion < 42) {
      try {
        // 1. Ensure 'statut' column exists
        await addColumnSafely(
          db,
          'annee_scolaire',
          'statut',
          "TEXT CHECK (statut IN ('Active', 'Inactive')) DEFAULT 'Active'",
        );

        // 2. Migrate from 'etat' if it exists
        final List<Map<String, dynamic>> columns = await db.rawQuery(
          'PRAGMA table_info(annee_scolaire)',
        );
        final bool hasEtat = columns.any((column) => column['name'] == 'etat');
        if (hasEtat) {
          await db.execute(
            "UPDATE annee_scolaire SET statut = 'Active' WHERE etat = 'EN_COURS'",
          );
          await db.execute(
            "UPDATE annee_scolaire SET statut = 'Inactive' WHERE etat = 'TERMINEE'",
          );
          debugPrint('Migrated data from etat to statut in annee_scolaire');
        }
      } catch (e) {
        debugPrint('Error during v42 migration: $e');
      }
    }

    if (oldVersion < 43) {
      try {
        await addColumnSafely(db, 'eleve', 'nom_pere', 'TEXT');
        await addColumnSafely(db, 'eleve', 'prenom_pere', 'TEXT');
        await addColumnSafely(db, 'eleve', 'nom_mere', 'TEXT');
        await addColumnSafely(db, 'eleve', 'prenom_mere', 'TEXT');
        debugPrint('Migration vers la version 43 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v43 : $e');
      }
    }

    if (oldVersion < 44) {
      debugPrint('Mise à jour vers la version 44 : Réparation du schéma');
      try {
        // 1. Créer la table configuration_annee si elle manque
        await db.execute('''
          CREATE TABLE IF NOT EXISTS configuration_annee (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            annee_scolaire_id INTEGER UNIQUE,
            moyenne_passage_cycle1 REAL DEFAULT 10.0,
            moyenne_passage_cycle2 REAL DEFAULT 10.0,
            moyenne_passage_cycle3 REAL DEFAULT 10.0,
            moyenne_generale_min REAL DEFAULT 10.0,
            mode_calcul_moyenne TEXT DEFAULT 'trimestrielle',
            use_custom_mentions INTEGER DEFAULT 1,
            base_notation REAL DEFAULT 20.0,
            include_conduite INTEGER DEFAULT 1,
            appreciation_automatique INTEGER DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
          )
        ''');

        // 2. Créer la table sequence_planification si elle manque
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sequence_planification (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            annee_scolaire_id INTEGER,
            trimestre INTEGER,
            numero_sequence INTEGER,
            nom TEXT,
            date_debut TEXT,
            date_fin TEXT,
            poids REAL,
            statut TEXT,
            FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
          )
        ''');

        // 3. Réparer la table classe (annee_scolaire_id)
        await addColumnSafely(
          db,
          'classe',
          'annee_scolaire_id',
          'INTEGER REFERENCES annee_scolaire(id)',
        );

        debugPrint('Migration vers la version 44 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v44 : $e');
      }
    }
    if (oldVersion < 45) {
      try {
        await addColumnSafely(
          db,
          'classe',
          'prof_principal_id',
          'INTEGER REFERENCES enseignant(id)',
        );
        debugPrint('Migration vers la version 45 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v45 : $e');
      }
    }
    if (oldVersion < 46) {
      try {
        // Migration classe_matiere pour globalisation
        await db.execute(
          'ALTER TABLE classe_matiere RENAME TO classe_matiere_old',
        );
        await db.execute('''
          CREATE TABLE classe_matiere (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            classe_id INTEGER NOT NULL,
            matiere_id INTEGER NOT NULL,
            annee_scolaire_id INTEGER,
            coefficient REAL DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (classe_id) REFERENCES classe(id),
            FOREIGN KEY (matiere_id) REFERENCES matiere(id),
            FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id),
            UNIQUE(classe_id, matiere_id)
          )
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO classe_matiere (id, classe_id, matiere_id, annee_scolaire_id, coefficient, created_at)
          SELECT id, classe_id, matiere_id, annee_scolaire_id, coefficient, created_at FROM classe_matiere_old
        ''');
        await db.execute('DROP TABLE classe_matiere_old');

        // Migration attribution_enseignant pour globalisation
        await db.execute(
          'ALTER TABLE attribution_enseignant RENAME TO attribution_enseignant_old',
        );
        await db.execute('''
          CREATE TABLE attribution_enseignant (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            classe_id INTEGER NOT NULL,
            matiere_id INTEGER NOT NULL,
            enseignant_id INTEGER NOT NULL,
            annee_scolaire_id INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (classe_id) REFERENCES classe(id),
            FOREIGN KEY (matiere_id) REFERENCES matiere(id),
            FOREIGN KEY (enseignant_id) REFERENCES enseignant(id),
            FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id),
            UNIQUE(classe_id, matiere_id)
          )
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO attribution_enseignant (id, classe_id, matiere_id, enseignant_id, annee_scolaire_id, created_at)
          SELECT id, classe_id, matiere_id, enseignant_id, annee_scolaire_id, created_at FROM attribution_enseignant_old
        ''');
        await db.execute('DROP TABLE attribution_enseignant_old');

        debugPrint('Migration vers la version 46 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v46 : $e');
      }
    }

    if (oldVersion < 47) {
      debugPrint(
        'Mise à jour vers la version 47 : Ajout de document_templates',
      );
      try {
        await db.execute(DocumentTemplateSchema.createTable);
        debugPrint('Migration vers la version 47 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v47 : $e');
      }
    }

    if (oldVersion < 48) {
      debugPrint('Mise à jour vers la version 48 : Traçabilité des paiements');
      try {
        // 1. Ajouter nom_complet à la table user
        await addColumnSafely(db, 'user', 'nom_complet', 'TEXT');

        // 2. Initialiser nom_complet avec pseudo pour les utilisateurs existants
        await db.execute(
          'UPDATE user SET nom_complet = pseudo WHERE nom_complet IS NULL',
        );

        // 3. Ajouter created_by_id à la table paiement_detail
        await addColumnSafely(
          db,
          'paiement_detail',
          'created_by_id',
          'INTEGER REFERENCES user(id)',
        );

        debugPrint('Migration vers la version 48 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v48 : $e');
      }
    }

    if (oldVersion < 49) {
      try {
        await addColumnSafely(db, 'paiement_detail', 'numero_recu', 'TEXT');
        await db.execute(
          "UPDATE paiement_detail SET numero_recu = 'OLD-' || id WHERE numero_recu IS NULL",
        );
        debugPrint('Migration vers la version 49 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v49 : $e');
      }
    }

    if (oldVersion < 50) {
      try {
        // Index sur les élèves
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_eleve_annee ON eleve(annee_scolaire_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_eleve_classe ON eleve(classe_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_eleve_matricule ON eleve(matricule)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_eleve_nom_prenom ON eleve(nom, prenom)',
        );

        // Index sur les notes (très important pour les bulletins)
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_note_eleve_annee ON note(eleve_id, annee_scolaire_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_note_matiere_trim ON note(matiere_id, trimestre, sequence)',
        );

        // Index sur les paiements
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_paiement_eleve_annee ON paiement_detail(eleve_id, annee_scolaire_id)',
        );

        debugPrint('Migration vers la version 50 (indexation) terminée.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v50 : $e');
      }
    }

    if (oldVersion < 51) {
      try {
        // Ensure eleve_parcours has decision, moyenne, rang columns
        await addColumnSafely(db, 'eleve_parcours', 'decision', 'TEXT');
        await addColumnSafely(db, 'eleve_parcours', 'moyenne', 'REAL');
        await addColumnSafely(db, 'eleve_parcours', 'rang', 'INTEGER');
        debugPrint(
          'Migration v51: colonnes decision/moyenne/rang ajoutées à eleve_parcours.',
        );
      } catch (e) {
        debugPrint('Erreur migration v51: $e');
      }
    }

    if (oldVersion < 52) {
      debugPrint(
        'Migration v52: Refonte de la promotion et statuts des années',
      );
      try {
        // 1. Recreer annee_scolaire pour la nouvelle contrainte CHECK
        await db.execute(
          'ALTER TABLE annee_scolaire RENAME TO annee_scolaire_old',
        );
        await db.execute('''
          CREATE TABLE annee_scolaire (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            libelle TEXT NOT NULL,
            date_debut TEXT NOT NULL,
            date_fin TEXT NOT NULL,
            active INTEGER DEFAULT 0,
            statut TEXT CHECK (statut IN ('Active', 'Inactive', 'Terminée')) DEFAULT 'Active',
            annee_precedente_id INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (annee_precedente_id) REFERENCES annee_scolaire(id)
          )
        ''');
        await db.execute('''
          INSERT INTO annee_scolaire (id, libelle, date_debut, date_fin, active, statut, annee_precedente_id, created_at, updated_at)
          SELECT id, libelle, date_debut, date_fin, active, statut, annee_precedente_id, created_at, updated_at FROM annee_scolaire_old
        ''');
        await db.execute('DROP TABLE annee_scolaire_old');

        // 2. Ajouter next_niveau_id à niveaux
        await addColumnSafely(
          db,
          'niveaux',
          'next_niveau_id',
          'INTEGER REFERENCES niveaux(id)',
        );

        // 3. Ajouter confirmation_statut à eleve_parcours
        await addColumnSafely(
          db,
          'eleve_parcours',
          'confirmation_statut',
          "TEXT DEFAULT 'Confirmé'",
        );

        // 4. Note: next_class_id reste dans la table classe pour compatibilité mais ne sera plus utilisé
        // Sa suppression complète nécessiterait une recréation de table complexe.

        debugPrint('Migration v52 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur migration v52: $e');
      }
    }

    if (oldVersion < 54) {
      try {
        // Double check all needed columns in eleve_parcours
        // Note: SQLite ALTER TABLE doesn't allow CURRENT_TIMESTAMP as default for new columns
        await addColumnSafely(db, 'eleve_parcours', 'updated_at', 'TEXT');
        await addColumnSafely(
          db,
          'eleve_parcours',
          'confirmation_statut',
          "TEXT",
        );
        debugPrint(
          'Migration v54: Verification des colonnes eleve_parcours terminée.',
        );
      } catch (e) {
        debugPrint('Erreur migration v54: $e');
      }
    }

    if (oldVersion < 55) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS configuration_evaluation (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            annee_scolaire_id INTEGER UNIQUE,
            nombre_sequences_trimestre INTEGER DEFAULT 2,
            nombre_trimestres_annee INTEGER DEFAULT 3,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
          )
        ''');
        debugPrint('Migration vers la version 55 terminée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de la migration v55 : $e');
      }
    }

    if (oldVersion < 56) {
      try {
        await addColumnSafely(db, 'eleve_parcours', 'type_inscription', 'TEXT');
        await addColumnSafely(db, 'eleve_parcours', 'date_inscription', 'TEXT');
        debugPrint(
          'Migration v56: type_inscription et date_inscription ajoutés à eleve_parcours.',
        );
      } catch (e) {
        debugPrint('Erreur migration v56: $e');
      }
    }

    if (oldVersion < 57) {
      try {
        await addColumnSafely(db, 'paiement', 'created_by_id', 'INTEGER');
        await addColumnSafely(
          db,
          'paiement_detail',
          'created_by_id',
          'INTEGER',
        );
        debugPrint(
          'Migration v57: created_by_id ajouté à paiement et paiement_detail.',
        );
      } catch (e) {
        debugPrint('Erreur migration v57: $e');
      }
    }

    if (oldVersion < 58) {
      try {
        await addColumnSafely(
          db,
          'enseignant',
          'sexe',
          "TEXT CHECK (sexe IN ('M','F'))",
        );
        await addColumnSafely(db, 'enseignant', 'date_naissance', "TEXT");
        await addColumnSafely(db, 'enseignant', 'date_embauche', "TEXT");
        await addColumnSafely(db, 'enseignant', 'photo', "TEXT");
        await addColumnSafely(
          db,
          'enseignant',
          'statut',
          "TEXT DEFAULT 'Actif'",
        );
        await addColumnSafely(db, 'enseignant', 'matricule', "TEXT UNIQUE");
        debugPrint(
          'Migration v58: Colonnes manquantes ajoutées à la table enseignant.',
        );
      } catch (e) {
        debugPrint('Erreur migration v58: $e');
      }
    }

    if (oldVersion < 60) {
      try {
        // 1. Create promotion_log table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS promotion_log (
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
        ''');

        // 2. Globalize classe_matiere: remove annee_scolaire_id and keep unique(classe_id, matiere_id)
        await db.execute(
          'ALTER TABLE classe_matiere RENAME TO classe_matiere_old',
        );
        await db.execute('''
          CREATE TABLE classe_matiere (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            classe_id INTEGER NOT NULL,
            matiere_id INTEGER NOT NULL,
            coefficient REAL DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (classe_id) REFERENCES classe(id),
            FOREIGN KEY (matiere_id) REFERENCES matiere(id),
            UNIQUE(classe_id, matiere_id)
          )
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO classe_matiere (id, classe_id, matiere_id, coefficient, created_at, updated_at)
          SELECT id, classe_id, matiere_id, coefficient, created_at, updated_at FROM classe_matiere_old
        ''');
        await db.execute('DROP TABLE classe_matiere_old');

        // 3. Globalize attribution_enseignant: remove annee_scolaire_id and keep unique(classe_id, matiere_id)
        await db.execute(
          'ALTER TABLE attribution_enseignant RENAME TO attribution_enseignant_old',
        );
        await db.execute('''
          CREATE TABLE attribution_enseignant (
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
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO attribution_enseignant (id, enseignant_id, classe_id, matiere_id, is_titulaire, volume_horaire, created_at, updated_at)
          SELECT id, enseignant_id, classe_id, matiere_id, is_titulaire, volume_horaire, created_at, updated_at FROM attribution_enseignant_old
        ''');
        await db.execute('DROP TABLE attribution_enseignant_old');

        debugPrint(
          'Migration vers la version 60 (globalisation et log promotion) terminée.',
        );
      } catch (e) {
        debugPrint('Erreur migration v60: $e');
      }
    }

    if (oldVersion < 61) {
      try {
        await addColumnSafely(db, 'ecole', 'ville', 'TEXT');
        debugPrint('Migration v61: colonne ville ajoutée à la table ecole.');
      } catch (e) {
        debugPrint('Erreur migration v61: $e');
      }
    }

    if (oldVersion < 62) {
      try {
        await db.execute(CycleMatiereDefaultSchema.createTable);

        // Peupler les données par défaut par cycle
        // Primaire (cycle 2)
        final primaireMatieres = [
          "Français",
          "Calculs",
          "Sciences d'observation",
          "Histoire-Géographie",
          "ECM",
          "Dessin / Arts plastiques",
          "Éducation physique et sportive (EPS)",
        ];
        for (var m in primaireMatieres) {
          await db.insert('cycle_matiere_default', {
            'cycle_id': 2,
            'matiere_nom': m,
            'coefficient': 1.0,
          });
        }

        // Collège (cycle 3)
        final collegeMatieres = [
          "Français",
          "Mathématiques",
          "Anglais",
          "Physique",
          "Chimie",
          "Biologie",
          "Géologie",
          "Histoire",
          "Géographie",
          "ECM",
          "Informatique",
          "EPS",
        ];
        for (var m in collegeMatieres) {
          await db.insert('cycle_matiere_default', {
            'cycle_id': 3,
            'matiere_nom': m,
            'coefficient': 1.0,
          });
        }

        // Lycée (cycle 4)
        final lyceeMatieres = [
          "Français",
          "Philosophie",
          "Anglais",
          "Mathématiques",
          "Physique",
          "Chimie",
          "Biologie",
          "Géologie",
          "Histoire",
          "Géographie",
          "EPS",
          "Économie",
        ];
        for (var m in lyceeMatieres) {
          await db.insert('cycle_matiere_default', {
            'cycle_id': 4,
            'matiere_nom': m,
            'coefficient': 1.0,
          });
        }
        debugPrint(
          'Migration v62: table cycle_matiere_default créée et peuplée.',
        );
      } catch (e) {
        debugPrint('Erreur migration v62: $e');
      }
    }

    if (oldVersion < 63) {
      try {
        // Table pour les paiements des enseignants
        await db.execute('''
          CREATE TABLE IF NOT EXISTS paiement_enseignant (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            enseignant_id INTEGER NOT NULL,
            annee_scolaire_id INTEGER NOT NULL,
            montant REAL NOT NULL,
            date_paiement TEXT NOT NULL,
            mode_paiement TEXT NOT NULL,
            type_calcul TEXT NOT NULL,
            nb_heures REAL,
            taux_horaire REAL,
            periode TEXT NOT NULL,
            observations TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (enseignant_id) REFERENCES enseignant(id),
            FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
          )
        ''');

        // Ajout des champs de rémunération à la table enseignant
        await addColumnSafely(
          db,
          'enseignant',
          'type_remuneration',
          "TEXT DEFAULT 'Fixe'",
        );
        await addColumnSafely(
          db,
          'enseignant',
          'salaire_base',
          'REAL DEFAULT 0',
        );

        debugPrint('Migration v63: table paiement_enseignant créée.');
      } catch (e) {
        debugPrint('Erreur migration v63: $e');
      }
    }
  }

  static Future<void> addColumnSafely(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      final List<Map<String, dynamic>> info = await db.rawQuery(
        'PRAGMA table_info($table)',
      );
      final bool exists = info.any((c) => c['name'] == column);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    } catch (e) {
      debugPrint('Error adding $column to $table: $e');
    }
  }
}
