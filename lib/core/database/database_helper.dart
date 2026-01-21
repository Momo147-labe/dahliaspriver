import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import '../../models/ecole.dart';
import '../../models/matiere.dart';
import 'database_path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _db;
  static Completer<Database>? _dbCompleter;
  static int? activeAnneeId;

  Future<Database> get database async {
    if (_db != null) return _db!;

    if (_dbCompleter != null) {
      return _dbCompleter!.future;
    }

    _dbCompleter = Completer<Database>();
    try {
      _db = await _initDatabase();
      _dbCompleter!.complete(_db!);
      return _db!;
    } catch (e) {
      _dbCompleter!.completeError(e);
      _dbCompleter = null; // Allow retry on failure
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasePath();
    return await openDatabase(
      path,
      version: 31,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // -------------------------
    // Tables principales
    // -------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS annee_scolaire (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libelle TEXT NOT NULL,
        date_debut TEXT NOT NULL,
        date_fin TEXT NOT NULL,
        active INTEGER DEFAULT 0,
        statut TEXT CHECK (statut IN ('Active','Inactive')) DEFAULT 'Active',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        annee_precedente_id INTEGER,
        FOREIGN KEY (annee_precedente_id) REFERENCES annee_scolaire(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ecole (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        fondateur TEXT NOT NULL,
        directeur TEXT NOT NULL,
        logo TEXT,             -- chemin ou URL du logo
        timbre TEXT,           -- chemin ou URL du timbre
        adresse TEXT,
        telephone TEXT,
        email TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS classe (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        cycle TEXT NOT NULL,
        salle TEXT,
        niveau TEXT,
        eff_max INTEGER DEFAULT 100,
        next_class_id INTEGER,
        is_final_class INTEGER DEFAULT 0,
        annee_scolaire_id INTEGER,
        moyenne_min_promotion REAL DEFAULT 10.0,
        moyenne_max_promotion REAL DEFAULT 20.0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id),
        FOREIGN KEY (next_class_id) REFERENCES classe(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS eleve (
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
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (classe_id) REFERENCES classe(id),
        FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
      )
    ''');

    // Table des matières
    await db.execute('''
    CREATE TABLE IF NOT EXISTS matiere (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

    // Table des coefficients par cycle ou option lycée
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eleve_id INTEGER NOT NULL,
        matiere_id INTEGER NOT NULL,
        note REAL NOT NULL,
        coefficient REAL DEFAULT 1,
        trimestre INTEGER,
        sequence INTEGER DEFAULT 1,
        annee_scolaire_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (eleve_id) REFERENCES eleve(id),
        FOREIGN KEY (matiere_id) REFERENCES matiere(id),
        FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuration_ecole (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        annee_scolaire_id INTEGER,
        moyenne_passage_cycle1 REAL DEFAULT 10.0,
        moyenne_passage_cycle2 REAL DEFAULT 10.0,
        moyenne_passage_cycle3 REAL DEFAULT 10.0,
        moyenne_generale_min REAL DEFAULT 10.0,
        appreciation_excellent TEXT DEFAULT 'Excellent',
        appreciation_tres_bien TEXT DEFAULT 'Très bien',
        appreciation_bien TEXT DEFAULT 'Bien',
        appreciation_abien TEXT DEFAULT 'Assez bien',
        appreciation_passable TEXT DEFAULT 'Passable',
        appreciation_insuffisant TEXT DEFAULT 'Insuffisant',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        mode_calcul_moyenne TEXT DEFAULT 'trimestrielle',
        use_custom_mentions INTEGER DEFAULT 1,
        FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuration_evaluation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        annee_scolaire_id INTEGER,
        nombre_sequences_trimestre INTEGER DEFAULT 3,
        nombre_trimestres_annee INTEGER DEFAULT 3,
        coefficient_max_matiere REAL DEFAULT 10.0,
        note_maximale REAL DEFAULT 20.0,
        note_minimale REAL DEFAULT 0.0,
        appreciation_automatique INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cycles_scolaires (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom_cycle TEXT NOT NULL,
        code_cycle TEXT UNIQUE NOT NULL,
        niveau_min INTEGER NOT NULL,
        niveau_max INTEGER NOT NULL,
        ordre_cycle INTEGER NOT NULL,
        couleur_cycle TEXT DEFAULT '#2196F3',
        sous_titre_cycle TEXT,
        droit_redoublement INTEGER DEFAULT 1,
        seuil_redoublement REAL DEFAULT 8.0,
        actif INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        moyenne_passage_cycle REAL DEFAULT 10.0,
        moyenne_excellence_cycle REAL DEFAULT 15.0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS paiement (
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS averages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eleve_id INTEGER NOT NULL,
        annee_scolaire_id INTEGER NOT NULL,
        moyenne REAL,
        rang INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enseignant (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        telephone TEXT,
        email TEXT,
        specialite TEXT,
        sexe TEXT CHECK (sexe IN ('M','F')),
        photo TEXT,
        date_naissance TEXT,
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
        jour_semaine INTEGER NOT NULL, -- 1: Lundi, 2: Mardi, etc.
        heure_debut TEXT NOT NULL,     -- Format "HH:mm"
        heure_fin TEXT NOT NULL,       -- Format "HH:mm"
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
        mode_paiement TEXT, -- Espèces, Virement, etc.
        type_frais TEXT,    -- Inscription, Tranche 1, etc.
        mois TEXT,          -- Pour les frais mensuels si applicable
        observation TEXT,   -- Notes ou référence détaillée
        classe_id INTEGER,
        frais_id INTEGER,
        annee_scolaire_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (eleve_id) REFERENCES eleve(id),
        FOREIGN KEY (classe_id) REFERENCES classe(id),
        FOREIGN KEY (frais_id) REFERENCES frais_scolarite(id),
        FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id)
      )
    ''');

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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pseudo TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        codesecret TEXT NOT NULL,
        role TEXT CHECK (role IN ('admin','enseignant','comptable')) DEFAULT 'enseignant',
        photo TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS classe_matiere (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        classe_id INTEGER NOT NULL,
        matiere_id INTEGER NOT NULL,
        annee_scolaire_id INTEGER NOT NULL,
        coefficient REAL DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (classe_id) REFERENCES classe(id),
        FOREIGN KEY (matiere_id) REFERENCES matiere(id),
        FOREIGN KEY (annee_scolaire_id) REFERENCES annee_scolaire(id),
        UNIQUE(classe_id, matiere_id, annee_scolaire_id)
      )
    ''');

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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
        try {
          await db.execute(
            'ALTER TABLE enseignant ADD COLUMN ${entry.key} ${entry.value}',
          );
          print('Colonne ${entry.key} ajoutée avec succès.');
        } catch (e) {
          print('La colonne ${entry.key} existe probablement déjà : $e');
        }
      }
    }

    if (oldVersion < 15) {
      try {
        await db.execute(
          'ALTER TABLE notes ADD COLUMN sequence INTEGER DEFAULT 1',
        );
      } catch (e) {
        print('La colonne sequence existe probablement déjà : $e');
      }
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
      try {
        await db.execute(
          'ALTER TABLE paiement_detail ADD COLUMN observation TEXT',
        );
      } catch (e) {
        debugPrint('Column observation may already exist: $e');
      }
    }

    if (oldVersion < 22) {
      // Ensuring observation column exists because version 21 upgrade might have been skipped for some users
      try {
        final List<Map<String, dynamic>> columns = await db.rawQuery(
          'PRAGMA table_info(paiement_detail)',
        );
        final bool hasObservation = columns.any(
          (column) => column['name'] == 'observation',
        );
        if (!hasObservation) {
          await db.execute(
            'ALTER TABLE paiement_detail ADD COLUMN observation TEXT',
          );
        }
      } catch (e) {
        debugPrint('Error checking column observation: $e');
      }
    }

    if (oldVersion < 24) {
      try {
        final List<Map<String, dynamic>> columns = await db.rawQuery(
          'PRAGMA table_info(paiement_detail)',
        );

        final bool hasClasseId = columns.any(
          (column) => column['name'] == 'classe_id',
        );
        if (!hasClasseId) {
          await db.execute(
            'ALTER TABLE paiement_detail ADD COLUMN classe_id INTEGER',
          );
        }

        final bool hasFraisId = columns.any(
          (column) => column['name'] == 'frais_id',
        );
        if (!hasFraisId) {
          await db.execute(
            'ALTER TABLE paiement_detail ADD COLUMN frais_id INTEGER',
          );
        }
      } catch (e) {
        debugPrint('Error during v24 migration: $e');
      }
    }

    if (oldVersion < 25) {
      // Ensure 'eleve' table has all necessary columns
      try {
        final List<Map<String, dynamic>> columns = await db.rawQuery(
          'PRAGMA table_info(eleve)',
        );

        final List<String> requiredColumns = [
          'annee_scolaire_id',
          'frais_id',
          'photo',
          'statut',
        ];

        for (var col in requiredColumns) {
          final bool exists = columns.any((column) => column['name'] == col);
          if (!exists) {
            String type = col == 'photo' || col == 'statut'
                ? 'TEXT'
                : 'INTEGER';
            await db.execute('ALTER TABLE eleve ADD COLUMN $col $type');
            debugPrint('Column $col added to table eleve');
          }
        }
      } catch (e) {
        debugPrint('Error during v25 migration for table eleve: $e');
      }

      // Ensure 'paiement_detail' has 'annee_scolaire_id'
      try {
        final List<Map<String, dynamic>> columns = await db.rawQuery(
          'PRAGMA table_info(paiement_detail)',
        );
        final bool hasAnnee = columns.any(
          (column) => column['name'] == 'annee_scolaire_id',
        );
        if (!hasAnnee) {
          await db.execute(
            'ALTER TABLE paiement_detail ADD COLUMN annee_scolaire_id INTEGER',
          );
          debugPrint('Column annee_scolaire_id added to table paiement_detail');
        }
      } catch (e) {
        debugPrint('Error during v25 migration for table paiement_detail: $e');
      }
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
      try {
        await db.execute(
          'ALTER TABLE classe_matiere ADD COLUMN coefficient REAL DEFAULT 1',
        );
      } catch (e) {
        debugPrint('Error adding coefficient to classe_matiere: $e');
      }
    }

    if (oldVersion < 29) {
      try {
        await db.execute(
          'ALTER TABLE notes ADD COLUMN coefficient REAL DEFAULT 1',
        );
      } catch (e) {
        debugPrint('Error adding coefficient to notes: $e');
      }
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
      await _addColumnSafely(
        db,
        'annee_scolaire',
        'annee_precedente_id',
        'INTEGER',
      );

      await _addColumnSafely(
        db,
        'classe',
        'moyenne_min_promotion',
        'REAL DEFAULT 10.0',
      );
      await _addColumnSafely(
        db,
        'classe',
        'moyenne_max_promotion',
        'REAL DEFAULT 20.0',
      );
      await _addColumnSafely(
        db,
        'classe',
        'created_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await _addColumnSafely(
        db,
        'classe',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await _addColumnSafely(
        db,
        'eleve',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await _addColumnSafely(
        db,
        'matiere',
        'created_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await _addColumnSafely(
        db,
        'matiere',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await _addColumnSafely(
        db,
        'notes',
        'created_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      await _addColumnSafely(
        db,
        'notes',
        'updated_at',
        'TEXT DEFAULT CURRENT_TIMESTAMP',
      );

      await _addColumnSafely(
        db,
        'configuration_ecole',
        'mode_calcul_moyenne',
        'TEXT DEFAULT "trimestrielle"',
      );
      await _addColumnSafely(
        db,
        'configuration_ecole',
        'use_custom_mentions',
        'INTEGER DEFAULT 1',
      );
      await _addColumnSafely(
        db,
        'cycles_scolaires',
        'moyenne_passage_cycle',
        'REAL DEFAULT 10.0',
      );
      await _addColumnSafely(
        db,
        'cycles_scolaires',
        'moyenne_excellence_cycle',
        'REAL DEFAULT 15.0',
      );
    }

    if (oldVersion < 31) {
      await _addColumnSafely(
        db,
        'cycles_scolaires',
        'sous_titre_cycle',
        'TEXT',
      );
      await _addColumnSafely(
        db,
        'cycles_scolaires',
        'droit_redoublement',
        'INTEGER DEFAULT 1',
      );
      await _addColumnSafely(
        db,
        'cycles_scolaires',
        'seuil_redoublement',
        'REAL DEFAULT 8.0',
      );
    }
  }

  Future<void> _addColumnSafely(
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

  // -------------------------
  // CRUD générique
  // -------------------------
  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(table, values);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<Map<String, dynamic>?> queryById(String table, int id) async {
    final db = await database;
    final result = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  // -------------------------
  // Méthodes Configuration École
  // -------------------------
  Future<int> saveConfigurationEcole(Map<String, dynamic> config) async {
    final db = await database;
    return await db.insert('configuration_ecole', config);
  }

  Future<int> updateConfigurationEcole(
    int id,
    Map<String, dynamic> config,
  ) async {
    final db = await database;
    config['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'configuration_ecole',
      config,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getConfigurationEcole(
    int anneeScolaireId,
  ) async {
    final db = await database;
    final result = await db.query(
      'configuration_ecole',
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeScolaireId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> saveConfigurationEvaluation(Map<String, dynamic> config) async {
    final db = await database;
    return await db.insert('configuration_evaluation', config);
  }

  Future<int> updateConfigurationEvaluation(
    int id,
    Map<String, dynamic> config,
  ) async {
    final db = await database;
    config['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'configuration_evaluation',
      config,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getConfigurationEvaluation(
    int anneeScolaireId,
  ) async {
    final db = await database;
    final result = await db.query(
      'configuration_evaluation',
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeScolaireId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> saveCycleScolaire(Map<String, dynamic> cycle) async {
    final db = await database;
    return await db.insert('cycles_scolaires', cycle);
  }

  Future<List<Map<String, dynamic>>> getCyclesScolaires() async {
    final db = await database;
    return await db.query('cycles_scolaires', orderBy: 'ordre_cycle');
  }

  Future<int> updateCycleScolaire(int id, Map<String, dynamic> cycle) async {
    final db = await database;
    cycle['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'cycles_scolaires',
      cycle,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCycleScolaire(int id) async {
    final db = await database;
    return await db.update(
      'cycles_scolaires',
      {'actif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -------------------------
  // Moyennes, rangs et passage
  // -------------------------
  Future<double> calculerMoyenneGenerale(int eleveId, int anneeId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT n.note, cm.coefficient 
      FROM notes n
      JOIN eleve e ON n.eleve_id = e.id
      JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id 
        AND cm.classe_id = e.classe_id 
        AND cm.annee_scolaire_id = n.annee_scolaire_id
      WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
    ''',
      [eleveId, anneeId],
    );

    double sommeNotes = 0.0;
    double sommeCoeff = 0.0;

    for (var row in result) {
      double note = (row['note'] as num?)?.toDouble() ?? 0.0;
      double coeff = (row['coefficient'] as num?)?.toDouble() ?? 1.0;
      sommeNotes += note * coeff;
      sommeCoeff += coeff;
    }

    return sommeCoeff == 0 ? 0.0 : (sommeNotes / sommeCoeff);
  }

  Future<void> calculerRangsClasse(int classeId, int anneeId) async {
    final db = await database;
    final eleves = await db.query(
      'eleve',
      where: 'classe_id = ?',
      whereArgs: [classeId],
    );

    List<Map<String, dynamic>> resultats = [];

    for (var eleve in eleves) {
      double moyenne = await calculerMoyenneGenerale(
        eleve['id'] as int,
        anneeId,
      );
      resultats.add({'eleve_id': eleve['id'], 'moyenne': moyenne});
    }

    resultats.sort(
      (a, b) => (b['moyenne'] as double).compareTo(a['moyenne'] as double),
    );

    for (int i = 0; i < resultats.length; i++) {
      await db.insert('averages', {
        'eleve_id': resultats[i]['eleve_id'],
        'annee_scolaire_id': anneeId,
        'moyenne': resultats[i]['moyenne'],
        'rang': i + 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> passerEleves(int anneeId, int nouvelleAnneeId) async {
    final db = await database;
    final eleves = await db.query(
      'eleve',
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeId],
    );

    for (var eleve in eleves) {
      double moyenne = await calculerMoyenneGenerale(
        eleve['id'] as int,
        anneeId,
      );
      final classe = await queryById('classe', eleve['classe_id'] as int);
      int? nextClassId = classe?['next_class_id'] as int?;
      bool isFinal = classe?['is_final_class'] == 1;
      final config = await queryAll('configuration_ecole');
      double moyennePassage = config.isNotEmpty
          ? (config.first['moyenne_generale_min'] as num?)?.toDouble() ?? 10.0
          : 10.0;

      if (moyenne >= moyennePassage && !isFinal && nextClassId != null) {
        await db.update(
          'eleve',
          {'classe_id': nextClassId, 'annee_scolaire_id': nouvelleAnneeId},
          where: 'id = ?',
          whereArgs: [eleve['id']],
        );
      } else if (isFinal) {
        await db.update(
          'eleve',
          {'statut': 'sorti'},
          where: 'id = ?',
          whereArgs: [eleve['id']],
        );
      } else {
        await db.update(
          'eleve',
          {
            'classe_id': eleve['classe_id'],
            'annee_scolaire_id': nouvelleAnneeId,
          },
          where: 'id = ?',
          whereArgs: [eleve['id']],
        );
      }
    }
  }

  String appreciationAutomatique(double moyenne) {
    if (moyenne >= 16) return "Excellent";
    if (moyenne >= 14) return "Très bien";
    if (moyenne >= 12) return "Bien";
    if (moyenne >= 10) return "Assez bien";
    if (moyenne >= 8) return "Passable";
    return "Insuffisant";
  }

  Future<bool> estBloque(int eleveId, int anneeId) async {
    final db = await database;
    final result = await db.query(
      'paiement',
      where: 'eleve_id = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, anneeId],
    );

    if (result.isEmpty) return false;
    double reste = (result.first['montant_restant'] as num?)?.toDouble() ?? 0;
    return reste > 0;
  }

  Future<int?> ensureActiveAnneeCached({bool forceRefresh = false}) async {
    if (activeAnneeId != null && !forceRefresh) return activeAnneeId;
    final annee = await getActiveAnnee();
    activeAnneeId = annee?['id'];
    return activeAnneeId;
  }

  Future<void> setActiveAnnee(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'annee_scolaire',
        {'statut': 'Inactive'},
        where: 'statut = ?',
        whereArgs: ['Active'],
      );
      await txn.update(
        'annee_scolaire',
        {'statut': 'Active'},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await ensureActiveAnneeCached(forceRefresh: true);
  }

  Future<Map<String, dynamic>?> getActiveAnnee() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'annee_scolaire',
      where: 'statut = ?',
      whereArgs: ['Active'],
      limit: 1,
    );
    if (result.isNotEmpty) return result.first;

    // Fallback to the latest one if no active year is set
    final latest = await db.query(
      'annee_scolaire',
      orderBy: 'date_debut DESC',
      limit: 1,
    );
    return latest.isNotEmpty ? latest.first : null;
  }

  // -------------------------
  // Méthodes Écoles
  // -------------------------
  Future<List<Map<String, dynamic>>> getEcoles() async {
    final db = await database;
    return await db.query('ecole');
  }

  Future<int> countEcoles() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ecole');
    return result.first['count'] as int;
  }

  Future<bool> hasEcoles() async {
    final count = await countEcoles();
    return count > 0;
  }

  Future<Ecole?> getEcole() async {
    final db = await database;
    final result = await db.query('ecole', limit: 1);
    if (result.isNotEmpty) {
      return Ecole.fromMap(result.first);
    }
    return null;
  }

  Future<int> upsertEcole(Ecole ecole) async {
    final db = await database;
    final count = await countEcoles();
    if (count == 0) {
      return await db.insert('ecole', ecole.toMap());
    } else {
      Map<String, dynamic> data = ecole.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();
      return await db.update(
        'ecole',
        data,
        where: 'id = ?',
        whereArgs: [ecole.id ?? 1],
      );
    }
  }

  // -------------------------
  // Méthodes Matières
  // -------------------------
  Future<List<Matiere>> getMatieresByAnnee(int anneeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('matiere');
    return maps.map((map) => Matiere.fromMap(map)).toList();
  }

  Future<int> saveMatiere(Matiere matiere) async {
    final db = await database;
    return await db.insert('matiere', matiere.toMap());
  }

  Future<void> updateMatiere(Matiere matiere) async {
    final db = await database;
    await db.update(
      'matiere',
      matiere.toMap(),
      where: 'id = ?',
      whereArgs: [matiere.id],
    );
  }

  Future<void> deleteMatiere(int id) async {
    final db = await database;
    await db.delete('matiere', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getMatieresStats() async {
    final db = await database;
    // This is a complex query to get stats like class count per subject
    // For now, let's return subjects with their usage count in notes or just the basic count
    return await db.rawQuery('''
      SELECT m.*, 
             (SELECT COUNT(DISTINCT eleve_id) FROM notes WHERE matiere_id = m.id) as students_count,
             (SELECT COUNT(DISTINCT classe_id) FROM classe_matiere WHERE matiere_id = m.id) as classes_count
      FROM matiere m
    ''');
  }

  // -------------------------
  // Méthodes Enseignants
  // -------------------------
  Future<List<Map<String, dynamic>>> getEnseignants() async {
    final db = await database;
    return await db.query('enseignant', orderBy: 'nom, prenom');
  }

  Future<Map<String, dynamic>> getEnseignantsStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        (SELECT COUNT(*) FROM enseignant) as total_enseignants,
        (SELECT COUNT(DISTINCT specialite) FROM enseignant WHERE specialite IS NOT NULL AND specialite != '') as total_specialites,
        (SELECT COUNT(*) FROM emploi_du_temps) as assignments_count
    ''');
    return result.first;
  }

  Future<int> deleteEnseignant(int id) async {
    final db = await database;
    return await db.delete('enseignant', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------
  // Méthodes Emploi du Temps
  // -------------------------
  Future<List<Map<String, dynamic>>> getEmploiDuTempsByClasse(
    int classeId,
    int anneeScolaireId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT edt.*, m.nom as matiere_nom, e.nom as enseignant_nom, e.prenom as enseignant_prenom
      FROM emploi_du_temps edt
      JOIN matiere m ON edt.matiere_id = m.id
      LEFT JOIN enseignant e ON edt.enseignant_id = e.id
      WHERE edt.classe_id = ? AND edt.annee_scolaire_id = ?
      ORDER BY edt.jour_semaine, edt.heure_debut
    ''',
      [classeId, anneeScolaireId],
    );
  }

  Future<int> checkConflicts(
    int jour,
    String debut,
    String fin, {
    int? enseignantId,
    int? classeId,
    int? excludeId,
  }) async {
    final db = await database;
    // Simple conflict check: same teacher or same class at overlapping time
    String query = '''
      SELECT COUNT(*) as count FROM emploi_du_temps
      WHERE jour_semaine = ? 
      AND (
        (heure_debut < ? AND heure_fin > ?) OR
        (heure_debut < ? AND heure_fin > ?) OR
        (heure_debut >= ? AND heure_fin <= ?)
      )
    ''';
    List<dynamic> args = [jour, fin, debut, fin, debut, debut, fin];

    if (enseignantId != null && classeId != null) {
      query += ' AND (enseignant_id = ? OR classe_id = ?)';
      args.addAll([enseignantId, classeId]);
    } else if (enseignantId != null) {
      query += ' AND enseignant_id = ?';
      args.add(enseignantId);
    } else if (classeId != null) {
      query += ' AND classe_id = ?';
      args.add(classeId);
    }

    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }

    final result = await db.rawQuery(query, args);
    return result.first['count'] as int;
  }

  // -------------------------
  // Méthodes Bulletins / Rapports
  // -------------------------

  Future<Map<String, dynamic>?> getActiveAnneeScolaire() async {
    return await getActiveAnnee();
  }

  Future<List<Map<String, dynamic>>> getClassesForReports() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, 
             (SELECT COUNT(*) FROM eleve WHERE classe_id = c.id) as student_count
      FROM classe c
      ORDER BY c.nom
    ''');
  }

  Future<List<Map<String, dynamic>>> getStudentsByClasse(int classeId) async {
    final db = await database;
    return await db.query(
      'eleve',
      where: 'classe_id = ?',
      whereArgs: [classeId],
      orderBy: 'nom, prenom',
    );
  }

  Future<List<Map<String, dynamic>>> getStudentNotesForBulletin(
    int studentId,
    int trimestre,
    int anneeId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT n.*, m.nom as matiere_nom, COALESCE(cm.coefficient, 1) as coefficient
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
           AND cm.annee_scolaire_id = n.annee_scolaire_id
      WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
    ''',
      [studentId, trimestre, anneeId],
    );
  }

  Future<Map<String, dynamic>> getBulletinStats(
    int studentId,
    int classId,
    int trimestre,
    int anneeId,
  ) async {
    final db = await database;

    // 1. Get average for the specific student
    final studentAvgResult = await db.rawQuery(
      '''
      SELECT SUM(note * COALESCE(cm.coefficient, 1)) / SUM(COALESCE(cm.coefficient, 1)) as average
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
           AND cm.annee_scolaire_id = n.annee_scolaire_id
      WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
    ''',
      [studentId, trimestre, anneeId],
    );

    double studentAvg =
        (studentAvgResult.first['average'] as num?)?.toDouble() ?? 0.0;

    // 2. Get averages for all students in the class to calculate rank and class average
    final allAvgsResult = await db.rawQuery(
      '''
      SELECT e.id, SUM(note * COALESCE(cm.coefficient, 1)) / SUM(COALESCE(cm.coefficient, 1)) as average
      FROM eleve e
      JOIN notes n ON n.eleve_id = e.id
      JOIN matiere m ON n.matiere_id = m.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
           AND cm.annee_scolaire_id = n.annee_scolaire_id
      WHERE e.classe_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
      GROUP BY e.id
      ORDER BY average DESC
    ''',
      [classId, trimestre, anneeId],
    );

    int rank = 0;
    double totalClassAvg = 0;
    for (int i = 0; i < allAvgsResult.length; i++) {
      totalClassAvg += (allAvgsResult[i]['average'] as num?)?.toDouble() ?? 0.0;
      if (allAvgsResult[i]['id'] == studentId) {
        rank = i + 1;
      }
    }

    double classAvg = allAvgsResult.isNotEmpty
        ? totalClassAvg / allAvgsResult.length
        : 0.0;

    return {
      'average': studentAvg,
      'rank': rank,
      'classAverage': classAvg,
      'totalStudents': allAvgsResult.length,
    };
  }

  // --- ANNUAL REPORT METHODS ---

  Future<List<Map<String, dynamic>>> getAnnualGradesForStudent(
    int studentId,
    int anneeId, {
    int? classId, // Optional, but recommended for rank calculation
  }) async {
    final db = await database;

    // Fetch classId if not provided (needed for rank)
    int? effectiveClassId = classId;
    if (effectiveClassId == null) {
      final studentInfo = await db.query(
        'eleve',
        columns: ['classe_id'],
        where: 'id = ?',
        whereArgs: [studentId],
      );
      if (studentInfo.isNotEmpty) {
        effectiveClassId = studentInfo.first['classe_id'] as int;
      }
    }

    // 1. Get all grades for the year
    final allGrades = await db.rawQuery(
      '''
      SELECT n.note, n.trimestre, 
             m.id as matiere_id, m.nom as matiere_nom, 
             COALESCE(cm.coefficient, 1) as coefficient
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
           AND cm.annee_scolaire_id = n.annee_scolaire_id
      WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
      ORDER BY m.nom
    ''',
      [studentId, anneeId],
    );

    // 2. Pivot and calculate averages per subject
    Map<int, Map<String, dynamic>> subjectStats = {};

    for (var row in allGrades) {
      int matId = row['matiere_id'] as int;
      String matNom = row['matiere_nom'] as String;
      double coeff = (row['coefficient'] as num).toDouble();
      double note = (row['note'] as num).toDouble();
      int tri = row['trimestre'] as int; // 1, 2, or 3

      if (!subjectStats.containsKey(matId)) {
        subjectStats[matId] = {
          'matiere_id': matId,
          'matiere_nom': matNom,
          'coefficient': coeff,
          't1': null,
          't2': null,
          't3': null,
        };
      }
      if (tri == 1) subjectStats[matId]!['t1'] = note;
      if (tri == 2) subjectStats[matId]!['t2'] = note;
      if (tri == 3) subjectStats[matId]!['t3'] = note;
    }

    // 3. Calculate annual averages and subject ranks
    List<Map<String, dynamic>> results = [];
    for (var stat in subjectStats.values) {
      double? t1 = stat['t1'];
      double? t2 = stat['t2'];
      double? t3 = stat['t3'];

      int count = 0;
      double sum = 0;
      if (t1 != null) {
        sum += t1;
        count++;
      }
      if (t2 != null) {
        sum += t2;
        count++;
      }
      if (t3 != null) {
        sum += t3;
        count++;
      }

      double moyAnnuelle = count > 0 ? sum / count : 0.0;

      int rank = 0;
      if (effectiveClassId != null) {
        rank = await _getAnnualSubjectRank(
          stat['matiere_id'],
          moyAnnuelle,
          effectiveClassId,
          anneeId,
        );
      }

      results.add({
        'matiere_nom': stat['matiere_nom'],
        'coefficient': stat['coefficient'],
        'moy_t1': t1,
        'moy_t2': t2,
        'moy_t3': t3,
        'moy_annuelle': moyAnnuelle,
        'rang': rank,
        'appreciation': appreciationAutomatique(moyAnnuelle),
      });
    }

    return results;
  }

  Future<int> _getAnnualSubjectRank(
    int matiereId,
    double targetAvg,
    int classeId,
    int anneeId,
  ) async {
    final db = await database;

    // Get annual averages for this subject for all students in the class
    final allGrades = await db.rawQuery(
      '''
      SELECT n.eleve_id, n.note, n.trimestre
      FROM notes n
      JOIN eleve e ON n.eleve_id = e.id
      WHERE n.matiere_id = ? 
        AND n.annee_scolaire_id = ?
        AND e.classe_id = ?
    ''',
      [matiereId, anneeId, classeId],
    );

    // Pivot in memory to get annual avg per student
    Map<int, List<double>> studentGrades = {};
    for (var row in allGrades) {
      int sId = row['eleve_id'] as int;
      double note = (row['note'] as num).toDouble();
      if (!studentGrades.containsKey(sId)) {
        studentGrades[sId] = [];
      }
      studentGrades[sId]!.add(note);
    }

    List<double> annualAvgs = [];
    for (var grades in studentGrades.values) {
      if (grades.isNotEmpty) {
        double avg = grades.reduce((a, b) => a + b) / grades.length;
        annualAvgs.add(avg);
      }
    }

    annualAvgs.sort((a, b) => b.compareTo(a)); // Descending
    int rank = annualAvgs.indexOf(targetAvg) + 1;
    return rank > 0 ? rank : annualAvgs.length + 1; // Fallback
  }

  Future<Map<String, dynamic>> getAnnualStats(
    int studentId,
    int classId,
    int anneeId,
  ) async {
    final grades = await getAnnualGradesForStudent(studentId, anneeId);

    double totalPoints = 0;
    double totalCoeff = 0;

    for (var g in grades) {
      double moy = (g['moy_annuelle'] as num?)?.toDouble() ?? 0.0;
      double coeff = (g['coefficient'] as num?)?.toDouble() ?? 1.0;
      totalPoints += moy * coeff;
      totalCoeff += coeff;
    }

    double annualAvg = totalCoeff > 0 ? totalPoints / totalCoeff : 0.0;

    // Calculate Rank
    // We need annual averages of ALL students in the class
    final allStudents = await getStudentsByClasse(classId);
    List<double> allAverages = [];

    for (var s in allStudents) {
      final sGrades = await getAnnualGradesForStudent(s['id'] as int, anneeId);
      double sTotalPoints = 0;
      double sTotalCoeff = 0;
      for (var g in sGrades) {
        double sMoy = (g['moy_annuelle'] as num?)?.toDouble() ?? 0.0;
        double sCoeff = (g['coefficient'] as num?)?.toDouble() ?? 1.0;
        sTotalPoints += sMoy * sCoeff;
        sTotalCoeff += sCoeff;
      }
      allAverages.add(sTotalCoeff > 0 ? sTotalPoints / sTotalCoeff : 0.0);
    }

    allAverages.sort((a, b) => b.compareTo(a)); // Descending
    int rank = allAverages.indexOf(annualAvg) + 1;

    // Class Annual Average
    double classTotalAvg = allAverages.isNotEmpty
        ? allAverages.reduce((a, b) => a + b) / allAverages.length
        : 0.0;

    return {
      'average': annualAvg,
      'rank': rank,
      'classAverage': classTotalAvg,
      'totalStudents': allStudents.length,
    };
  }

  // --- GRADES MANAGEMENT ---

  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    final db = await database;
    return await db.query('matiere', orderBy: 'nom ASC');
  }

  Future<List<Map<String, dynamic>>> getGradesByClassSubject(
    int classId,
    int subjectId,
    int trimestre,
    int sequence,
    int anneeId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT e.id as eleve_id, e.nom, e.prenom, e.matricule, e.photo, n.note, n.id as note_id,
             COALESCE(cm.coefficient, 1) as coefficient
      FROM eleve e
      LEFT JOIN notes n ON n.eleve_id = e.id 
          AND n.matiere_id = ? 
          AND n.trimestre = ? 
          AND n.sequence = ?
          AND n.annee_scolaire_id = ?
      LEFT JOIN classe_matiere cm ON cm.matiere_id = ? 
          AND cm.classe_id = e.classe_id
          AND cm.annee_scolaire_id = ?
      WHERE e.classe_id = ?
      ORDER BY e.nom ASC, e.prenom ASC
    ''',
      [subjectId, trimestre, sequence, anneeId, subjectId, anneeId, classId],
    );
  }

  Future<void> saveGrade(Map<String, dynamic> noteData) async {
    final db = await database;

    // 1. Validation : Vérifier si un enseignant est affecté
    // On récupère d'abord la classe de l'élève
    final eleveResult = await db.query(
      'eleve',
      columns: ['classe_id'],
      where: 'id = ?',
      whereArgs: [noteData['eleve_id']],
    );

    if (eleveResult.isEmpty) {
      throw Exception("Élève non trouvé");
    }

    final int classeId = eleveResult.first['classe_id'] as int;

    // Vérifier l'attribution
    final attribution = await db.query(
      'attribution_enseignant',
      where: 'classe_id = ? AND matiere_id = ? AND annee_scolaire_id = ?',
      whereArgs: [
        classeId,
        noteData['matiere_id'],
        noteData['annee_scolaire_id'],
      ],
    );

    if (attribution.isEmpty) {
      throw Exception(
        "Impossible d'enregistrer la note : aucun enseignant n'est affecté à cette matière pour cette classe.",
      );
    }

    // 2. Enregistrement
    // Check if it already exists
    final existing = await db.query(
      'notes',
      where:
          'eleve_id = ? AND matiere_id = ? AND trimestre = ? AND sequence = ? AND annee_scolaire_id = ?',
      whereArgs: [
        noteData['eleve_id'],
        noteData['matiere_id'],
        noteData['trimestre'],
        noteData['sequence'],
        noteData['annee_scolaire_id'],
      ],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'notes',
        noteData,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('notes', noteData);
    }
  }

  Future<Map<String, dynamic>> getGradesStats(
    int classId,
    int subjectId,
    int trimestre,
    int sequence,
    int anneeId,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        AVG(note) as average,
        MAX(note) as maxNote,
        MIN(note) as minNote,
        COUNT(id) as total,
        SUM(CASE WHEN note >= 10 THEN 1 ELSE 0 END) as passed
      FROM notes
      WHERE matiere_id = ? AND trimestre = ? AND sequence = ? AND annee_scolaire_id = ?
      AND eleve_id IN (SELECT id FROM eleve WHERE classe_id = ?)
    ''',
      [subjectId, trimestre, sequence, anneeId, classId],
    );

    if (result.isEmpty || result.first['total'] == 0) {
      return {
        'average': 0.0,
        'maxNote': 0.0,
        'minNote': 0.0,
        'successRate': 0.0,
        'total': 0,
      };
    }

    final data = result.first;
    final total = data['total'] as int;
    final passed = data['passed'] as int;

    return {
      'average': (data['average'] as num?)?.toDouble() ?? 0.0,
      'maxNote': (data['maxNote'] as num?)?.toDouble() ?? 0.0,
      'minNote': (data['minNote'] as num?)?.toDouble() ?? 0.0,
      'successRate': total > 0 ? (passed / total) * 100 : 0.0,
      'total': total,
    };
  }

  Future<List<Map<String, dynamic>>> getGradesOverview(int anneeId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        c.id as classe_id,
        c.nom as classe_nom, 
        m.id as matiere_id,
        m.nom as matiere_nom, 
        cm.coefficient,
        n.trimestre,
        n.sequence,
        COUNT(n.id) as count,
        AVG(n.note) as average,
        ens.nom as enseignant_nom,
        ens.prenom as enseignant_prenom
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
      JOIN classe_matiere cm ON cm.matiere_id = m.id AND cm.classe_id = c.id AND cm.annee_scolaire_id = ?
      LEFT JOIN attribution_enseignant ae ON ae.classe_id = c.id AND ae.matiere_id = m.id AND ae.annee_scolaire_id = ?
      LEFT JOIN enseignant ens ON ae.enseignant_id = ens.id
      WHERE n.annee_scolaire_id = ?
      GROUP BY c.id, m.id, n.trimestre, n.sequence
      ORDER BY c.nom ASC, n.trimestre DESC, n.sequence DESC
    ''',
      [anneeId, anneeId, anneeId],
    );
  }

  // --- PAYMENTS MANAGEMENT ---

  Future<Map<String, dynamic>?> getFraisByClasse(
    int classId,
    int anneeId,
  ) async {
    final db = await database;
    final result = await db.query(
      'frais_scolarite',
      where: 'classe_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classId, anneeId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getPaiementsByEleve(
    int eleveId,
    int anneeId,
  ) async {
    final db = await database;
    return await db.query(
      'paiement_detail',
      where: 'eleve_id = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, anneeId],
      orderBy: 'date_paiement DESC',
    );
  }

  Future<void> addPaiement(Map<String, dynamic> data) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Insert into paiement_detail
      // Ensure classe_id and frais_id are included if available or fetch them
      if (!data.containsKey('classe_id') || !data.containsKey('frais_id')) {
        final eleve = await txn.query(
          'eleve',
          columns: ['classe_id'],
          where: 'id = ?',
          whereArgs: [data['eleve_id']],
        );
        if (eleve.isNotEmpty) {
          final int classeId = eleve.first['classe_id'] as int;
          data['classe_id'] = classeId;

          final fees = await txn.query(
            'frais_scolarite',
            columns: ['id'],
            where: 'classe_id = ? AND annee_scolaire_id = ?',
            whereArgs: [classeId, data['annee_scolaire_id']],
          );
          if (fees.isNotEmpty) {
            data['frais_id'] = fees.first['id'];
          }
        }
      }

      await txn.insert('paiement_detail', data);

      // 2. Update or insert into aggregate 'paiement' table
      final existing = await txn.query(
        'paiement',
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [data['eleve_id'], data['annee_scolaire_id']],
      );

      if (existing.isNotEmpty) {
        final double currentPaid =
            (existing.first['montant_paye'] as num?)?.toDouble() ?? 0.0;
        final double total =
            (existing.first['montant_total'] as num?)?.toDouble() ?? 0.0;
        final double newPaid =
            currentPaid + (data['montant'] as num).toDouble();
        final double newRemaining = total - newPaid;

        await txn.update(
          'paiement',
          {
            'montant_paye': newPaid,
            'montant_restant': newRemaining,
            'mode_paiement': data['mode_paiement'],
            'reference_paiement': data['observation'],
            'date_paiement': data['date_paiement'],
            'type_paiement': data['type_frais'],
            'statut': newRemaining <= 0 ? 'Réglé' : 'Partiel',
            'classe_id': data['classe_id'],
            'frais_id': data['frais_id'],
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        // We need to know the total fees for the class
        final eleve = await txn.query(
          'eleve',
          columns: ['classe_id'],
          where: 'id = ?',
          whereArgs: [data['eleve_id']],
        );
        int? classeId = eleve.isNotEmpty
            ? eleve.first['classe_id'] as int?
            : null;

        double totalFees = 0.0;
        if (classeId != null) {
          final fees = await txn.query(
            'frais_scolarite',
            columns: ['montant_total'],
            where: 'classe_id = ? AND annee_scolaire_id = ?',
            whereArgs: [classeId, data['annee_scolaire_id']],
          );
          if (fees.isNotEmpty) {
            totalFees =
                (fees.first['montant_total'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final double montantPaye = (data['montant'] as num).toDouble();
        await txn.insert('paiement', {
          'eleve_id': data['eleve_id'],
          'classe_id': data['classe_id'],
          'frais_id': data['frais_id'],
          'annee_scolaire_id': data['annee_scolaire_id'],
          'montant_total': totalFees,
          'montant_paye': montantPaye,
          'montant_restant': totalFees - montantPaye,
          'mode_paiement': data['mode_paiement'],
          'reference_paiement': data['observation'],
          'date_paiement': data['date_paiement'],
          'type_paiement': data['type_frais'],
          'statut': (totalFees - montantPaye) <= 0 ? 'Réglé' : 'Partiel',
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> searchEleves(String query) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom 
      FROM eleve e
      LEFT JOIN classe c ON e.classe_id = c.id
      WHERE e.nom LIKE ? OR e.prenom LIKE ? OR e.matricule LIKE ?
      LIMIT 20
    ''',
      ['%$query%', '%$query%', '%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> getClassesByAnnee(int anneeId) async {
    final db = await database;
    return await db.query(
      'classe',
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeId],
      orderBy: 'nom ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getElevesByClasse(int classeId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom 
      FROM eleve e
      LEFT JOIN classe c ON e.classe_id = c.id
      WHERE e.classe_id = ?
    ''',
      [classeId],
    );
  }

  // ===================================================================
  // ANALYTICS METHODS - Year-over-Year Comparison
  // ===================================================================

  /// Get current and previous academic year IDs for comparison
  Future<Map<String, int?>> getYearComparison() async {
    final db = await database;

    // Get current active year
    final currentYear = await getActiveAnnee();
    final currentYearId = currentYear?['id'] as int?;

    // Get previous year (the one before the active year by date)
    final previousYearResult = await db.rawQuery(
      '''
      SELECT id FROM annee_scolaire 
      WHERE date_debut < (SELECT date_debut FROM annee_scolaire WHERE id = ?)
      ORDER BY date_debut DESC
      LIMIT 1
    ''',
      [currentYearId],
    );

    final previousYearId = previousYearResult.isNotEmpty
        ? previousYearResult.first['id'] as int?
        : null;

    return {'currentYearId': currentYearId, 'previousYearId': previousYearId};
  }

  /// Get student enrollment analytics comparing two years
  Future<Map<String, dynamic>> getStudentAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    final db = await database;

    // Current year students
    final currentStudents = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN sexe = 'M' THEN 1 ELSE 0 END) as males,
        SUM(CASE WHEN sexe = 'F' THEN 1 ELSE 0 END) as females,
        SUM(CASE WHEN statut = 'inscrit' THEN 1 ELSE 0 END) as new_students,
        SUM(CASE WHEN statut = 'reinscrit' THEN 1 ELSE 0 END) as returning_students
      FROM eleve
      WHERE annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    // Previous year students
    Map<String, dynamic>? previousStudents;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN sexe = 'M' THEN 1 ELSE 0 END) as males,
          SUM(CASE WHEN sexe = 'F' THEN 1 ELSE 0 END) as females
        FROM eleve
        WHERE annee_scolaire_id = ?
      ''',
        [previousYearId],
      );
      previousStudents = prevResult.first;
    }

    // Distribution by cycle
    final cycleDistribution = await db.rawQuery(
      '''
      SELECT c.cycle, COUNT(e.id) as count
      FROM eleve e
      JOIN classe c ON e.classe_id = c.id
      WHERE e.annee_scolaire_id = ?
      GROUP BY c.cycle
    ''',
      [currentYearId],
    );

    return {
      'current': currentStudents.first,
      'previous': previousStudents,
      'cycleDistribution': cycleDistribution,
    };
  }

  /// Get financial analytics comparing two years
  Future<Map<String, dynamic>> getFinancialAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    final db = await database;

    // Current year financial data
    final currentFinances = await db.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT pd.eleve_id) as students_paid,
        SUM(pd.montant) as total_collected,
        COUNT(pd.id) as payment_count
      FROM paiement_detail pd
      JOIN eleve e ON pd.eleve_id = e.id
      WHERE e.annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    // Get total expected fees for current year
    final currentExpected = await db.rawQuery(
      '''
      SELECT 
        SUM(
          (fs.inscription + fs.reinscription + fs.tranche1 + fs.tranche2 + fs.tranche3) * 
          (SELECT COUNT(*) FROM eleve WHERE classe_id = fs.classe_id AND annee_scolaire_id = ?)
        ) as total_expected
      FROM frais_scolarite fs
      JOIN classe c ON fs.classe_id = c.id
      WHERE c.annee_scolaire_id = ? AND fs.annee_scolaire_id = ?
    ''',
      [currentYearId, currentYearId, currentYearId],
    );

    // Previous year financial data
    Map<String, dynamic>? previousFinances;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          COUNT(DISTINCT pd.eleve_id) as students_paid,
          SUM(pd.montant) as total_collected,
          COUNT(pd.id) as payment_count
        FROM paiement_detail pd
        JOIN eleve e ON pd.eleve_id = e.id
        WHERE e.annee_scolaire_id = ?
      ''',
        [previousYearId],
      );
      previousFinances = prevResult.first;
    }

    // Payment methods distribution
    final paymentMethods = await db.rawQuery(
      '''
      SELECT pd.mode_paiement, COUNT(*) as count, SUM(pd.montant) as total
      FROM paiement_detail pd
      JOIN eleve e ON pd.eleve_id = e.id
      WHERE e.annee_scolaire_id = ?
      GROUP BY pd.mode_paiement
    ''',
      [currentYearId],
    );

    return {
      'current': {
        ...currentFinances.first,
        'expected': currentExpected.first['total_expected'] ?? 0,
      },
      'previous': previousFinances,
      'paymentMethods': paymentMethods,
    };
  }

  /// Get academic performance analytics comparing two years
  Future<Map<String, dynamic>> getAcademicAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    final db = await database;

    // Current year academic performance
    final currentAcademic = await db.rawQuery(
      '''
      SELECT 
        AVG(n.note) as average_grade,
        COUNT(DISTINCT n.eleve_id) as students_graded,
        COUNT(n.id) as total_grades
      FROM notes n
      JOIN eleve e ON n.eleve_id = e.id
      WHERE e.annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    // Previous year academic performance
    Map<String, dynamic>? previousAcademic;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          AVG(n.note) as average_grade,
          COUNT(DISTINCT n.eleve_id) as students_graded,
          COUNT(n.id) as total_grades
        FROM notes n
        JOIN eleve e ON n.eleve_id = e.id
        WHERE e.annee_scolaire_id = ?
      ''',
        [previousYearId],
      );
      previousAcademic = prevResult.first;
    }

    // Performance by trimester (current year)
    final trimesterPerformance = await db.rawQuery(
      '''
      SELECT 
        n.trimestre,
        AVG(n.note) as average,
        COUNT(DISTINCT n.eleve_id) as students
      FROM notes n
      JOIN eleve e ON n.eleve_id = e.id
      WHERE e.annee_scolaire_id = ?
      GROUP BY n.trimestre
      ORDER BY n.trimestre
    ''',
      [currentYearId],
    );

    // Performance by class (current year)
    final classPerformance = await db.rawQuery(
      '''
      SELECT 
        c.nom as class_name,
        c.cycle,
        AVG(n.note) as average,
        COUNT(DISTINCT n.eleve_id) as students
      FROM notes n
      JOIN eleve e ON n.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
      WHERE e.annee_scolaire_id = ?
      GROUP BY c.id
      ORDER BY c.cycle, c.nom
    ''',
      [currentYearId],
    );

    return {
      'current': currentAcademic.first,
      'previous': previousAcademic,
      'trimesterPerformance': trimesterPerformance,
      'classPerformance': classPerformance,
    };
  }

  /// Get class distribution analytics comparing two years
  Future<Map<String, dynamic>> getClassAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    final db = await database;

    // Current year class data
    final currentClasses = await db.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT c.id) as total_classes,
        AVG(student_counts.count) as avg_class_size,
        MAX(student_counts.count) as max_class_size,
        MIN(student_counts.count) as min_class_size
      FROM classe c
      LEFT JOIN (
        SELECT classe_id, COUNT(*) as count
        FROM eleve
        WHERE annee_scolaire_id = ?
        GROUP BY classe_id
      ) student_counts ON c.id = student_counts.classe_id
      WHERE c.annee_scolaire_id = ?
    ''',
      [currentYearId, currentYearId],
    );

    // Previous year class data
    Map<String, dynamic>? previousClasses;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          COUNT(DISTINCT c.id) as total_classes,
          AVG(student_counts.count) as avg_class_size
        FROM classe c
        LEFT JOIN (
          SELECT classe_id, COUNT(*) as count
          FROM eleve
          WHERE annee_scolaire_id = ?
          GROUP BY classe_id
        ) student_counts ON c.id = student_counts.classe_id
        WHERE c.annee_scolaire_id = ?
      ''',
        [previousYearId, previousYearId],
      );
      previousClasses = prevResult.first;
    }

    // Distribution by cycle (current year)
    final cycleDistribution = await db.rawQuery(
      '''
      SELECT 
        c.cycle,
        COUNT(DISTINCT c.id) as class_count,
        COUNT(e.id) as student_count
      FROM classe c
      LEFT JOIN eleve e ON c.id = e.classe_id AND e.annee_scolaire_id = ?
      WHERE c.annee_scolaire_id = ?
      GROUP BY c.cycle
    ''',
      [currentYearId, currentYearId],
    );

    // Distribution by level (current year)
    final levelDistribution = await db.rawQuery(
      '''
      SELECT 
        c.niveau,
        COUNT(DISTINCT c.id) as class_count,
        COUNT(e.id) as student_count
      FROM classe c
      LEFT JOIN eleve e ON c.id = e.classe_id AND e.annee_scolaire_id = ?
      WHERE c.annee_scolaire_id = ?
      GROUP BY c.niveau
      ORDER BY c.niveau
    ''',
      [currentYearId, currentYearId],
    );

    return {
      'current': currentClasses.first,
      'previous': previousClasses,
      'cycleDistribution': cycleDistribution,
      'levelDistribution': levelDistribution,
    };
  }

  /// Get teacher analytics comparing two years
  Future<Map<String, dynamic>> getTeacherAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    final db = await database;

    // Total teachers (not year-specific in current schema)
    final teacherCount = await db.rawQuery(
      'SELECT COUNT(*) as total FROM enseignant',
    );

    // Get student count for ratio calculation
    final currentStudentCount = await db.rawQuery(
      '''
      SELECT COUNT(*) as total FROM eleve WHERE annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    int? previousStudentCount;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as total FROM eleve WHERE annee_scolaire_id = ?
      ''',
        [previousYearId],
      );
      previousStudentCount = prevResult.first['total'] as int?;
    }

    // Teachers by speciality
    final specialityDistribution = await db.rawQuery('''
      SELECT specialite, COUNT(*) as count
      FROM enseignant
      WHERE specialite IS NOT NULL AND specialite != ''
      GROUP BY specialite
      ORDER BY count DESC
    ''');

    final totalTeachers = teacherCount.first['total'] as int;
    final currentStudents = currentStudentCount.first['total'] as int;

    return {
      'totalTeachers': totalTeachers,
      'current': {
        'studentTeacherRatio': totalTeachers > 0
            ? currentStudents / totalTeachers
            : 0,
        'students': currentStudents,
      },
      'previous': previousStudentCount != null
          ? {
              'studentTeacherRatio': totalTeachers > 0
                  ? previousStudentCount / totalTeachers
                  : 0,
              'students': previousStudentCount,
            }
          : null,
      'specialityDistribution': specialityDistribution,
    };
  }

  // --- NEW FINANCIAL ANALYTICS ---

  Future<Map<String, dynamic>> getFinancialSummary(int anneeId) async {
    final db = await database;

    // Total expected: Sum of class fees for all enrolled students
    final expectedResult = await db.rawQuery(
      '''
      SELECT SUM(fs.montant_total) as total
      FROM eleve e
      JOIN frais_scolarite fs ON e.classe_id = fs.classe_id AND e.annee_scolaire_id = fs.annee_scolaire_id
      WHERE e.annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    // Total collected
    final collectedResult = await db.rawQuery(
      '''
      SELECT SUM(montant_paye) as total
      FROM paiement
      WHERE annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    // Growth comparison (this month vs last month)
    final now = DateTime.now();
    final firstDayThisMonth = DateTime(
      now.year,
      now.month,
      1,
    ).toIso8601String();
    final firstDayLastMonth = DateTime(
      now.year,
      now.month - 1,
      1,
    ).toIso8601String();

    final thisMonthResult = await db.rawQuery(
      '''
      SELECT SUM(montant) as total
      FROM paiement_detail
      WHERE annee_scolaire_id = ? AND date_paiement >= ?
    ''',
      [anneeId, firstDayThisMonth],
    );

    final lastMonthResult = await db.rawQuery(
      '''
      SELECT SUM(montant) as total
      FROM paiement_detail
      WHERE annee_scolaire_id = ? AND date_paiement >= ? AND date_paiement < ?
    ''',
      [anneeId, firstDayLastMonth, firstDayThisMonth],
    );

    double expected =
        (expectedResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double collected =
        (collectedResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double remaining = expected - collected;
    double recoveryRate = expected > 0 ? (collected / expected) * 100 : 0.0;

    double thisMonth =
        (thisMonthResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double lastMonth =
        (lastMonthResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double growth = lastMonth > 0
        ? ((thisMonth - lastMonth) / lastMonth) * 100
        : 0.0;

    return {
      'expected': expected,
      'collected': collected,
      'remaining': remaining,
      'recoveryRate': recoveryRate,
      'thisMonth': thisMonth,
      'growth': growth,
    };
  }

  Future<List<Map<String, dynamic>>> getRecoveryByClass(int anneeId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT c.nom, SUM(p.montant_paye) as paid, SUM(p.montant_total) as expected
      FROM classe c
      LEFT JOIN eleve e ON e.classe_id = c.id
      LEFT JOIN paiement p ON p.eleve_id = e.id AND p.annee_scolaire_id = ?
      WHERE c.annee_scolaire_id = ?
      GROUP BY c.id
      ORDER BY c.nom ASC
    ''',
      [anneeId, anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodsBreakdown(
    int anneeId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT COALESCE(mode_paiement, 'Inconnu') as mode, SUM(montant) as total, COUNT(*) as count
      FROM paiement_detail
      WHERE annee_scolaire_id = ?
      GROUP BY mode_paiement
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions(
    int anneeId, {
    int limit = 10,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT pd.*, e.nom as eleve_nom, e.prenom as eleve_prenom, e.id as eleve_id, e.photo as eleve_photo, c.nom as classe_nom
      FROM paiement_detail pd
      JOIN eleve e ON pd.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
      WHERE pd.annee_scolaire_id = ?
      ORDER BY pd.date_paiement DESC
      LIMIT ?
    ''',
      [anneeId, limit],
    );
  }

  Future<Map<String, double>> getStudentFinancialStatus(
    int eleveId,
    int anneeId,
  ) async {
    final db = await database;

    // 1. Get total paid by student for the year
    final paidResult = await db.rawQuery(
      '''
      SELECT SUM(montant) as total_paid
      FROM paiement_detail
      WHERE eleve_id = ? AND annee_scolaire_id = ?
    ''',
      [eleveId, anneeId],
    );

    final totalPaid =
        (paidResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;

    // 2. Get student's class ID and status
    final studentResult = await db.query(
      'eleve',
      columns: ['classe_id', 'statut'],
      where: 'id = ?',
      whereArgs: [eleveId],
      limit: 1,
    );

    if (studentResult.isEmpty) {
      return {'totalPaid': totalPaid, 'totalExpected': 0.0, 'balance': 0.0};
    }

    final classeId = studentResult.first['classe_id'] as int;
    final statut = studentResult.first['statut'] as String?;

    // 3. Get total expected fees for the class from frais_scolarite
    final feesResult = await db.query(
      'frais_scolarite',
      where: 'classe_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classeId, anneeId],
      limit: 1,
    );

    double totalExpected = 0.0;
    if (feesResult.isNotEmpty) {
      final fees = feesResult.first;
      final double inscription =
          (fees['inscription'] as num?)?.toDouble() ?? 0.0;
      final double reinscription =
          (fees['reinscription'] as num?)?.toDouble() ?? 0.0;
      final double t1 = (fees['tranche1'] as num?)?.toDouble() ?? 0.0;
      final double t2 = (fees['tranche2'] as num?)?.toDouble() ?? 0.0;
      final double t3 = (fees['tranche3'] as num?)?.toDouble() ?? 0.0;

      // Determine registration fee based on status (inscrit = Nouveau, else = Ancien)
      double registrationFee = (statut == 'inscrit')
          ? inscription
          : reinscription;

      totalExpected = registrationFee + t1 + t2 + t3;
    }

    return {
      'totalPaid': totalPaid,
      'totalExpected': totalExpected,

      'balance': totalExpected - totalPaid,
    };
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory(
    int eleveId,
    int anneeId,
  ) async {
    final db = await database;
    return await db.query(
      'paiement_detail',
      columns: [
        'date_paiement',
        'type_frais as motif',
        'montant',
        'mode_paiement',
      ],
      where: 'eleve_id = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, anneeId],
      orderBy: 'date_paiement DESC',
    );
  }

  Future<Map<String, dynamic>> getDashboardStats(int anneeId) async {
    final db = await database;

    final studentResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM eleve WHERE annee_scolaire_id = ?',
      [anneeId],
    );
    final classeResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM classe WHERE annee_scolaire_id = ?',
      [anneeId],
    );
    final teacherResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM enseignant',
    );

    final financial = await getFinancialSummary(anneeId);

    // Recent payments
    final recentPayments = await db.rawQuery(
      '''
      SELECT pd.*, e.nom, e.prenom, c.nom as classe_nom
      FROM paiement_detail pd
      JOIN eleve e ON pd.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
      WHERE pd.annee_scolaire_id = ?
      ORDER BY pd.date_paiement DESC
      LIMIT 5
    ''',
      [anneeId],
    );

    // Students by level (existing)
    final levelStats = await db.rawQuery(
      '''
      SELECT c.niveau, COUNT(e.id) as count
      FROM eleve e
      JOIN classe c ON e.classe_id = c.id
      WHERE e.annee_scolaire_id = ?
      GROUP BY c.niveau
    ''',
      [anneeId],
    );

    // Stats par sexe
    final genderStats = await db.rawQuery(
      'SELECT sexe, COUNT(*) as count FROM eleve WHERE annee_scolaire_id = ? GROUP BY sexe',
      [anneeId],
    );

    // Stats par cycle
    final cycleStats = await db.rawQuery(
      '''
      SELECT c.cycle, COUNT(e.id) as count 
      FROM eleve e 
      JOIN classe c ON e.classe_id = c.id 
      WHERE e.annee_scolaire_id = ? 
      GROUP BY c.cycle
      ''',
      [anneeId],
    );

    // Stats par classe
    final classStats = await db.rawQuery(
      '''
      SELECT c.nom, COUNT(e.id) as count 
      FROM eleve e 
      JOIN classe c ON e.classe_id = c.id 
      WHERE e.annee_scolaire_id = ? 
      GROUP BY c.nom
      ORDER BY count DESC
      LIMIT 10
      ''',
      [anneeId],
    );

    // Paiements par mois (6 derniers mois)
    // Note: on utilise SUBSTR pour extraire le mois si le format est YYYY-MM-DD
    final paymentMonthlyStats = await db.rawQuery(
      '''
      SELECT SUBSTR(pd.date_paiement, 1, 7) as month, SUM(pd.montant) as total 
      FROM paiement_detail pd
      WHERE pd.annee_scolaire_id = ?
      GROUP BY month
      ORDER BY month DESC
      LIMIT 6
    ''',
      [anneeId],
    );

    return {
      'students': studentResult.first['count'] as int? ?? 0,
      'classes': classeResult.first['count'] as int? ?? 0,
      'teachers': teacherResult.first['count'] as int? ?? 0,
      'financial': financial,
      'recentPayments': recentPayments,
      'levelStats': levelStats,
      'genderStats': genderStats,
      'cycleStats': cycleStats,
      'classStats': classStats,
      'paymentMonthlyStats': paymentMonthlyStats,
    };
  }

  Future<List<Map<String, dynamic>>> getStudentPaymentControlData(
    int anneeId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        e.id, e.nom, e.prenom, e.matricule, e.statut as eleve_statut, e.photo,
        c.nom as classe_nom,
        fs.inscription, fs.reinscription, fs.tranche1, fs.tranche2, fs.tranche3, fs.montant_total,
        COALESCE(p.montant_paye, 0) as total_paye
      FROM eleve e
      JOIN classe c ON e.classe_id = c.id
      LEFT JOIN frais_scolarite fs ON e.classe_id = fs.classe_id AND e.annee_scolaire_id = fs.annee_scolaire_id
      LEFT JOIN paiement p ON p.eleve_id = e.id AND p.annee_scolaire_id = e.annee_scolaire_id
      WHERE e.annee_scolaire_id = ?
      ORDER BY c.nom ASC, e.nom ASC
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getOverdueStudents(int anneeId) async {
    final db = await database;
    final now = DateTime.now();
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    // 1. Get all students with their class and fee info
    final data = await db.rawQuery(
      '''
      SELECT 
        e.id, e.nom, e.prenom, e.matricule, e.photo,
        c.nom as classe_nom,
        fs.date_limite_t1, fs.tranche1,
        fs.date_limite_t2, fs.tranche2,
        fs.date_limite_t3, fs.tranche3,
        COALESCE(p.montant_paye, 0) as total_paye,
        COALESCE(fs.inscription, 0) as inscription,
        COALESCE(fs.reinscription, 0) as reinscription,
        e.statut as eleve_statut
      FROM eleve e
      JOIN classe c ON e.classe_id = c.id
      JOIN frais_scolarite fs ON e.classe_id = fs.classe_id AND e.annee_scolaire_id = fs.annee_scolaire_id
      LEFT JOIN paiement p ON p.eleve_id = e.id AND p.annee_scolaire_id = e.annee_scolaire_id
      WHERE e.annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    List<Map<String, dynamic>> overdue = [];

    for (var row in data) {
      double totalPaye = (row['total_paye'] as num).toDouble();
      double initialFee = (row['eleve_statut'] == 'inscrit'
          ? (row['inscription'] as num).toDouble()
          : (row['reinscription'] as num).toDouble());

      double remainingAfterInitial = totalPaye - initialFee;

      // Check Tranche 1
      if (row['date_limite_t1'] != null && (row['tranche1'] as num) > 0) {
        try {
          DateTime deadline = formatter.parse(row['date_limite_t1'] as String);
          if (now.isAfter(deadline)) {
            double tranche1 = (row['tranche1'] as num).toDouble();
            if (remainingAfterInitial < tranche1) {
              overdue.add({
                ...row,
                'overdue_tranche': 'Tranche 1',
                'amount_due':
                    tranche1 -
                    (remainingAfterInitial > 0 ? remainingAfterInitial : 0),
                'deadline': row['date_limite_t1'],
              });
              continue; // Only report the first overdue tranche
            }
            remainingAfterInitial -= tranche1;
          } else {
            remainingAfterInitial -= (row['tranche1'] as num).toDouble();
          }
        } catch (e) {
          debugPrint('Error parsing T1 deadline: ${row['date_limite_t1']}');
        }
      }

      // Check Tranche 2
      if (row['date_limite_t2'] != null && (row['tranche2'] as num) > 0) {
        try {
          DateTime deadline = formatter.parse(row['date_limite_t2'] as String);
          if (now.isAfter(deadline)) {
            double tranche2 = (row['tranche2'] as num).toDouble();
            if (remainingAfterInitial < tranche2) {
              overdue.add({
                ...row,
                'overdue_tranche': 'Tranche 2',
                'amount_due':
                    tranche2 -
                    (remainingAfterInitial > 0 ? remainingAfterInitial : 0),
                'deadline': row['date_limite_t2'],
              });
              continue;
            }
            remainingAfterInitial -= tranche2;
          } else {
            remainingAfterInitial -= (row['tranche2'] as num).toDouble();
          }
        } catch (e) {
          debugPrint('Error parsing T2 deadline: ${row['date_limite_t2']}');
        }
      }

      // Check Tranche 3
      if (row['date_limite_t3'] != null && (row['tranche3'] as num) > 0) {
        try {
          DateTime deadline = formatter.parse(row['date_limite_t3'] as String);
          if (now.isAfter(deadline)) {
            double tranche3 = (row['tranche3'] as num).toDouble();
            if (remainingAfterInitial < tranche3) {
              overdue.add({
                ...row,
                'overdue_tranche': 'Tranche 3',
                'amount_due':
                    tranche3 -
                    (remainingAfterInitial > 0 ? remainingAfterInitial : 0),
                'deadline': row['date_limite_t3'],
              });
            }
          }
        } catch (e) {
          debugPrint('Error parsing T3 deadline: ${row['date_limite_t3']}');
        }
      }
    }

    return overdue;
  }

  Future<List<Map<String, dynamic>>> getAttributionsByClass(
    int classeId,
    int anneeId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT ae.*, e.nom, e.prenom, m.nom as matiere_nom
      FROM attribution_enseignant ae
      JOIN enseignant e ON ae.enseignant_id = e.id
      JOIN matiere m ON ae.matiere_id = m.id
      WHERE ae.classe_id = ? AND ae.annee_scolaire_id = ?
    ''',
      [classeId, anneeId],
    );
  }

  Future<void> saveAllAttributions(
    int classeId,
    int anneeId,
    Map<int, int?> assignments,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var entry in assignments.entries) {
        if (entry.value != null) {
          await txn.insert('attribution_enseignant', {
            'classe_id': classeId,
            'matiere_id': entry.key,
            'enseignant_id': entry.value,
            'annee_scolaire_id': anneeId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> saveAttribution(Map<String, dynamic> attribution) async {
    final db = await database;
    // Sauvegarder l'affectation enseignant seulement pour cette classe spécifique
    await db.insert(
      'attribution_enseignant',
      attribution,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAssignedTeacher(
    int classeId,
    int matiereId,
    int anneeId,
  ) async {
    final db = await database;
    final results = await db.rawQuery(
      '''
      SELECT e.*
      FROM attribution_enseignant ae
      JOIN enseignant e ON ae.enseignant_id = e.id
      WHERE ae.classe_id = ? AND ae.matiere_id = ? AND ae.annee_scolaire_id = ?
    ''',
      [classeId, matiereId, anneeId],
    );

    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<List<Map<String, dynamic>>> getSubjectsByClass(
    int classeId,
    int anneeId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT m.*, cm.coefficient
      FROM matiere m
      JOIN classe_matiere cm ON m.id = cm.matiere_id
      WHERE cm.classe_id = ? AND cm.annee_scolaire_id = ?
      ORDER BY m.nom ASC
    ''',
      [classeId, anneeId],
    );
  }

  Future<void> saveClassSubjects(
    int classeId,
    int anneeId,
    List<Map<String, dynamic>> subjectsData,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      // Remove existing
      await txn.delete(
        'classe_matiere',
        where: 'classe_id = ? AND annee_scolaire_id = ?',
        whereArgs: [classeId, anneeId],
      );

      // Insert new
      for (var data in subjectsData) {
        await txn.insert('classe_matiere', {
          'classe_id': classeId,
          'matiere_id': data['id'],
          'annee_scolaire_id': anneeId,
          'coefficient': data['coefficient'] ?? 1.0,
        });
      }
    });
  }

  Future<bool> isSubjectInClass(
    int classeId,
    int matiereId,
    int anneeId,
  ) async {
    final db = await database;
    final result = await db.query(
      'classe_matiere',
      where: 'classe_id = ? AND matiere_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classeId, matiereId, anneeId],
    );
    return result.isNotEmpty;
  }

  // --- STUDENT DETAILS & HISTORY ---

  Future<Map<String, dynamic>?> getStudentById(int id) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM eleve e
      LEFT JOIN classe c ON e.classe_id = c.id
      LEFT JOIN annee_scolaire a ON e.annee_scolaire_id = a.id
      WHERE e.id = ?
    ''',
      [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getStudentParcours(int id) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT p.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM eleve_parcours p
      JOIN classe c ON p.classe_id = c.id
      JOIN annee_scolaire a ON p.annee_scolaire_id = a.id
      WHERE p.eleve_id = ?
      ORDER BY a.date_debut DESC
    ''',
      [id],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentPayments(int id) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT p.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM paiement p
      JOIN classe c ON p.classe_id = c.id
      JOIN annee_scolaire a ON p.annee_scolaire_id = a.id
      WHERE p.eleve_id = ?
      ORDER BY a.date_debut DESC
    ''',
      [id],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentPaymentDetails(
    int id, {
    int? anneeId,
  }) async {
    final db = await database;
    String query = '''
      SELECT pd.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM paiement_detail pd
      LEFT JOIN classe c ON pd.classe_id = c.id
      LEFT JOIN annee_scolaire a ON pd.annee_scolaire_id = a.id
      WHERE pd.eleve_id = ?
    ''';
    List<dynamic> args = [id];

    if (anneeId != null) {
      query += ' AND pd.annee_scolaire_id = ?';
      args.add(anneeId);
    }

    query += ' ORDER BY pd.date_paiement DESC';

    return await db.rawQuery(query, args);
  }

  Future<List<Map<String, dynamic>>> getStudentResults(int id) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT n.*, m.nom as matiere_nom, a.libelle as annee_nom,
             ens.nom as enseignant_nom, ens.prenom as enseignant_prenom
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN annee_scolaire a ON n.annee_scolaire_id = a.id
      LEFT JOIN attribution_enseignant ae ON ae.classe_id = (SELECT classe_id FROM eleve WHERE id = n.eleve_id) 
           AND ae.matiere_id = n.matiere_id AND ae.annee_scolaire_id = n.annee_scolaire_id
      LEFT JOIN enseignant ens ON ae.enseignant_id = ens.id
      WHERE n.eleve_id = ?
      ORDER BY a.date_debut DESC, n.trimestre ASC, n.sequence ASC
    ''',
      [id],
    );
  }

  // --- FRAIS SCOLAIRES MANAGEMENT ---

  /// Créer des frais pour plusieurs classes avec les mêmes montants
  Future<void> createFraisForMultipleClasses(
    List<int> classeIds,
    int anneeScolaireId,
    Map<String, dynamic> fraisData,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int classeId in classeIds) {
        final fraisMap = {
          'classe_id': classeId,
          'annee_scolaire_id': anneeScolaireId,
          ...fraisData,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Vérifier si des frais existent déjà pour cette classe
        final existing = await txn.query(
          'frais_scolarite',
          where: 'classe_id = ? AND annee_scolaire_id = ?',
          whereArgs: [classeId, anneeScolaireId],
        );

        if (existing.isNotEmpty) {
          // Mettre à jour les frais existants
          await txn.update(
            'frais_scolarite',
            fraisMap,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        } else {
          // Créer de nouveaux frais
          await txn.insert('frais_scolarite', fraisMap);
        }
      }
    });
  }

  /// Obtenir toutes les classes avec leurs frais pour une année scolaire
  Future<List<Map<String, dynamic>>> getClassesWithFrais(
    int anneeScolaireId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT c.*, fs.id as frais_id, fs.inscription, fs.reinscription, 
             fs.tranche1, fs.date_limite_t1, fs.tranche2, fs.date_limite_t2,
             fs.tranche3, fs.date_limite_t3, fs.montant_total,
             (SELECT COUNT(*) FROM eleve WHERE classe_id = c.id AND annee_scolaire_id = ?) as nb_eleves
      FROM classe c
      LEFT JOIN frais_scolarite fs ON c.id = fs.classe_id AND fs.annee_scolaire_id = ?
      WHERE c.annee_scolaire_id = ?
      ORDER BY c.nom ASC
    ''',
      [anneeScolaireId, anneeScolaireId, anneeScolaireId],
    );
  }

  /// Obtenir les classes qui ont les mêmes frais (montants identiques)
  Future<List<Map<String, dynamic>>> getClassesWithSameFees(
    int anneeScolaireId,
    Map<String, dynamic> fraisReference,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT c.*, fs.*
      FROM classe c
      JOIN frais_scolarite fs ON c.id = fs.classe_id
      WHERE fs.annee_scolaire_id = ? 
        AND fs.inscription = ? 
        AND fs.reinscription = ?
        AND fs.tranche1 = ?
        AND fs.tranche2 = ?
        AND fs.tranche3 = ?
      ORDER BY c.nom ASC
    ''',
      [
        anneeScolaireId,
        fraisReference['inscription'] ?? 0.0,
        fraisReference['reinscription'] ?? 0.0,
        fraisReference['tranche1'] ?? 0.0,
        fraisReference['tranche2'] ?? 0.0,
        fraisReference['tranche3'] ?? 0.0,
      ],
    );
  }

  /// Dupliquer les frais d'une classe vers d'autres classes
  Future<void> duplicateFraisToClasses(
    int sourceClasseId,
    List<int> targetClasseIds,
    int anneeScolaireId,
  ) async {
    final db = await database;

    // Obtenir les frais de la classe source
    final sourceFrais = await getFraisByClasse(sourceClasseId, anneeScolaireId);
    if (sourceFrais == null) {
      throw Exception('Aucun frais trouvé pour la classe source');
    }

    // Copier vers les classes cibles
    final fraisData = {
      'inscription': sourceFrais['inscription'],
      'reinscription': sourceFrais['reinscription'],
      'tranche1': sourceFrais['tranche1'],
      'date_limite_t1': sourceFrais['date_limite_t1'],
      'tranche2': sourceFrais['tranche2'],
      'date_limite_t2': sourceFrais['date_limite_t2'],
      'tranche3': sourceFrais['tranche3'],
      'date_limite_t3': sourceFrais['date_limite_t3'],
      'montant_total': sourceFrais['montant_total'],
    };

    await createFraisForMultipleClasses(
      targetClasseIds,
      anneeScolaireId,
      fraisData,
    );
  }

  /// Obtenir les statistiques des frais par année scolaire
  Future<Map<String, dynamic>> getFraisStatistics(int anneeScolaireId) async {
    final db = await database;

    final stats = await db.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT fs.classe_id) as classes_with_fees,
        COUNT(DISTINCT c.id) as total_classes,
        AVG(fs.montant_total) as average_fees,
        MIN(fs.montant_total) as min_fees,
        MAX(fs.montant_total) as max_fees,
        SUM(fs.montant_total * (
          SELECT COUNT(*) FROM eleve 
          WHERE classe_id = fs.classe_id AND annee_scolaire_id = ?
        )) as total_expected_revenue
      FROM classe c
      LEFT JOIN frais_scolarite fs ON c.id = fs.classe_id AND fs.annee_scolaire_id = ?
      WHERE c.annee_scolaire_id = ?
    ''',
      [anneeScolaireId, anneeScolaireId, anneeScolaireId],
    );

    return stats.first;
  }

  Future<List<Map<String, dynamic>>> getClassesByTeacher(
    int enseignantId,
    int anneeId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT DISTINCT c.nom, c.cycle, c.niveau
      FROM classe c
      JOIN attribution_enseignant ae ON c.id = ae.classe_id
      WHERE ae.enseignant_id = ? AND ae.annee_scolaire_id = ?
      ORDER BY c.nom ASC
    ''',
      [enseignantId, anneeId],
    );
  }

  /// Supprimer les frais pour plusieurs classes
  Future<void> deleteFraisForClasses(
    List<int> classeIds,
    int anneeScolaireId,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int classeId in classeIds) {
        await txn.delete(
          'frais_scolarite',
          where: 'classe_id = ? AND annee_scolaire_id = ?',
          whereArgs: [classeId, anneeScolaireId],
        );
      }
    });
  }
  // ==============================================================================
  // GESTION DES UTILISATEURS
  // ==============================================================================

  Future<Map<String, dynamic>?> getUser(int id) async {
    final db = await database;
    final results = await db.query(
      'user',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('user', orderBy: 'pseudo ASC');
  }

  Future<int> addUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('user', user);
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.update(
      'user',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  Future<Map<String, dynamic>> getEcoleInfo() async {
    final db = await database;
    try {
      final result = await db.query('ecole', limit: 1);
      if (result.isNotEmpty) {
        return result.first;
      }
    } catch (e) {
      debugPrint('Error fetching school info: $e');
    }
    return {
      'nom': 'Guiner Schools',
      'adresse': 'Conakry, Guinée',
      'telephone': '+224 600 00 00 00',
      'email': 'contact@guinerschools.com',
      'logo': null,
    };
  }

  Future<int> changePassword(int id, String newPassword) async {
    final db = await database;
    return await db.update(
      'user',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('user', where: 'id = ?', whereArgs: [id]);
  }
}
