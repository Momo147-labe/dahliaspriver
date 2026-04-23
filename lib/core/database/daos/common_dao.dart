import 'package:sqflite/sqflite.dart';
import 'base_dao.dart';

class CommonDao extends BaseDao {
  CommonDao(Database db) : super(db);

  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return await db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values,
    String where,
    List<dynamic> whereArgs,
  ) async {
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    return await db.query(table);
  }

  Future<Map<String, dynamic>?> queryById(String table, int id) async {
    final results = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return await db.rawQuery(sql, arguments);
  }
}
