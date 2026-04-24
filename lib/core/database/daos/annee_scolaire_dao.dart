import 'package:sqflite/sqflite.dart';
import '../schemas/annee_scolaire_schema.dart';
import 'base_dao.dart';

class AnneeScolaireDao extends BaseDao {
  AnneeScolaireDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getAnneesScolaires() async {
    return await db.query(
      AnneeScolaireSchema.tableName,
      orderBy: 'date_debut DESC',
    );
  }

  Future<Map<String, dynamic>?> getActiveAnnee() async {
    final result = await db.query(
      AnneeScolaireSchema.tableName,
      where: "statut = ?",
      whereArgs: ['Active'],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertAnnee(Map<String, dynamic> annee) async {
    return await db.insert(AnneeScolaireSchema.tableName, annee);
  }

  Future<int> updateAnnee(int id, Map<String, dynamic> annee) async {
    annee['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      AnneeScolaireSchema.tableName,
      annee,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setActiveAnnee(int id) async {
    await db.transaction((txn) async {
      await txn.update(
        AnneeScolaireSchema.tableName,
        {'statut': 'Inactive'},
        where: "statut = ?",
        whereArgs: ['Active'],
      );
      await txn.update(
        AnneeScolaireSchema.tableName,
        {'statut': 'Active'},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<Map<String, dynamic>?> getAnneeById(int id) async {
    final result = await db.query(
      AnneeScolaireSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, int?>> getYearComparison([int? currentYearId]) async {
    // Get current active year if not provided
    if (currentYearId == null) {
      final currentYear = await getActiveAnnee();
      currentYearId = currentYear?['id'] as int?;
    }

    if (currentYearId == null)
      return {'currentYearId': null, 'previousYearId': null};

    // Get previous year using the explicit annee_precedente_id column
    final yearResult = await db.query(
      AnneeScolaireSchema.tableName,
      columns: ['annee_precedente_id'],
      where: 'id = ?',
      whereArgs: [currentYearId],
    );

    final previousYearId = yearResult.isNotEmpty
        ? yearResult.first['annee_precedente_id'] as int?
        : null;

    return {'currentYearId': currentYearId, 'previousYearId': previousYearId};
  }
}
