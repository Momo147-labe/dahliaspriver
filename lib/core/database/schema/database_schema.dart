import 'package:sqflite/sqflite.dart';
import '../schemas/annee_scolaire_schema.dart';
import '../schemas/ecole_schema.dart';
import '../schemas/classe_schema.dart';
import '../schemas/eleve_schema.dart';
import '../schemas/matiere_schema.dart';
import '../schemas/notes_schema.dart';
import '../schemas/configuration_annee_schema.dart';
import '../schemas/cycles_scolaires_schema.dart';
import '../schemas/niveaux_schema.dart';
import '../schemas/paiement_schema.dart';
import '../schemas/enseignant_schema.dart';
import '../schemas/emploi_du_temps_schema.dart';
import '../schemas/frais_scolarite_schema.dart';
import '../schemas/paiement_detail_schema.dart';
import '../schemas/eleve_parcours_schema.dart';
import '../schemas/user_schema.dart';
import '../schemas/attribution_enseignant_schema.dart';
import '../schemas/classe_matiere_schema.dart';
import '../schemas/promotion_log_schema.dart';
import '../schemas/cycle_matiere_default_schema.dart';
import '../schemas/paiement_enseignant_schema.dart';
// These tables are defined directly in the create method below because their schema files are missing
import '../schemas/document_template_schema.dart';
import '../migrations/database_migrations.dart';

class DatabaseSchema {
  static Future<void> create(Database db) async {
    await db.execute(AnneeScolaireSchema.createTable);
    await db.execute(EcoleSchema.createTable);
    await db.execute(ClasseSchema.createTable);
    await db.execute(EleveSchema.createTable);
    await db.execute(MatiereSchema.createTable);

    // matiere_coeff doesn't have a separate schema file in the list I saw,
    // but it was in _onCreate. I'll check if a schema exists or keep it here.
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

    await db.execute(NotesSchema.createTable);
    await db.execute(ConfigurationAnneeSchema.createTable);
    await db.execute(CyclesScolairesSchema.createTable);
    await db.execute(NiveauxSchema.createTable);
    await db.execute(PaiementSchema.createTable);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS averages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eleve_id INTEGER NOT NULL,
        annee_scolaire_id INTEGER NOT NULL,
        moyenne REAL,
        rang INTEGER,
        mention TEXT
      )
    ''');

    await db.execute(EnseignantSchema.createTable);
    await db.execute(EmploiDuTempsSchema.createTable);
    await db.execute(FraisScolariteSchema.createTable);
    await db.execute(PaiementDetailSchema.createTable);
    await db.execute(EleveParcoursSchema.createTable);
    await db.execute(UserSchema.createTable);
    await db.execute(AttributionEnseignantSchema.createTable);
    await db.execute(ClasseMatiereSchema.createTable);
    await db.execute(PromotionLogSchema.createTable);
    await db.execute(CycleMatiereDefaultSchema.createTable);
    await DatabaseMigrations.populateDefaultSubjects(db);
    await db.execute(PaiementEnseignantSchema.createTable);

    // Check if mention_config and appreciation_config have schemas
    // I didn't see them in the list earlier, let's re-verify
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mention_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        note_min REAL NOT NULL,
        note_max REAL NOT NULL,
        couleur TEXT,
        cycle_id INTEGER,
        appreciation TEXT,
        icone TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (cycle_id) REFERENCES cycles_scolaires(id)
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

    await db.execute(DocumentTemplateSchema.createTable);

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
  }
}
