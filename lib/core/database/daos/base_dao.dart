import 'package:sqflite/sqflite.dart';

abstract class BaseDao {
  final Database db;

  BaseDao(this.db);

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

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return await db.rawQuery(sql, arguments);
  }
}
