import 'package:sqflite/sqflite.dart';
import '../schemas/promotion_log_schema.dart';
import 'base_dao.dart';

class PromotionLogDao extends BaseDao {
  PromotionLogDao(Database db) : super(db);

  /// Check if a promotion from a class in a specific year has already been logged.
  Future<bool> hasPromotionBeenLogged(int fromAnneeId, int fromClasseId) async {
    final result = await db.query(
      PromotionLogSchema.tableName,
      where: 'id_annee_depart = ? AND classe_depart_id = ?',
      whereArgs: [fromAnneeId, fromClasseId],
    );
    return result.isNotEmpty;
  }

  /// Log a new promotion.
  Future<int> logPromotion({
    required int fromAnneeId,
    required int fromClasseId,
    required int toAnneeId,
    required int toClasseId,
    String? status,
  }) async {
    return await db.insert(PromotionLogSchema.tableName, {
      'id_annee_depart': fromAnneeId,
      'classe_depart_id': fromClasseId,
      'id_annee_arriver': toAnneeId,
      'classe_arriver_id': toClasseId,
      'status': status ?? 'Completed',
    });
  }

  /// Get promotion logs for a specific destination year and class.
  Future<List<Map<String, dynamic>>> getPromotionLogs(
    int toAnneeId,
    int toClasseId,
  ) async {
    return await db.query(
      PromotionLogSchema.tableName,
      where: 'id_annee_arriver = ? AND classe_arriver_id = ?',
      whereArgs: [toAnneeId, toClasseId],
    );
  }
}
