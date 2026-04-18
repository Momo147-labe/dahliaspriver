import 'package:sqflite/sqflite.dart';
import '../../../models/ecole.dart';
import '../schemas/ecole_schema.dart';
import 'base_dao.dart';

class EcoleDao extends BaseDao {
  EcoleDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getEcoles() async {
    return await db.query(EcoleSchema.tableName);
  }

  Future<bool> hasEcoles() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${EcoleSchema.tableName}',
    );
    int? count = Sqflite.firstIntValue(result);
    return count != null && count > 0;
  }

  Future<int> countEcoles() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${EcoleSchema.tableName}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> getSchoolProfile() async {
    final result = await db.query(EcoleSchema.tableName, limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> upsertEcole(Ecole ecole) async {
    final existing = await getSchoolProfile();
    if (existing == null) {
      return await db.insert(EcoleSchema.tableName, ecole.toMap());
    } else {
      Map<String, dynamic> data = ecole.toMap();
      data.remove('id');
      data['updated_at'] = DateTime.now().toIso8601String();
      return await db.update(
        EcoleSchema.tableName,
        data,
        where: 'id = ?',
        whereArgs: [ecole.id ?? 1],
      );
    }
  }
}
