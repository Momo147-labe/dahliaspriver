import 'package:sqflite/sqflite.dart';
import '../schemas/user_schema.dart';
import 'base_dao.dart';

class UserDao extends BaseDao {
  UserDao(Database db) : super(db);

  Future<Map<String, dynamic>?> getUser(int id) async {
    final results = await db.query(
      UserSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    return await db.query(UserSchema.tableName, orderBy: 'pseudo ASC');
  }

  Future<int> addUser(Map<String, dynamic> user) async {
    return await db.insert(UserSchema.tableName, user);
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    user['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      UserSchema.tableName,
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  Future<int> changePassword(int id, String newPassword) async {
    return await db.update(
      UserSchema.tableName,
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(int id) async {
    return await db.delete(
      UserSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> login(String pseudo, String password) async {
    final results = await db.query(
      UserSchema.tableName,
      where: 'pseudo = ? AND password = ? AND actif = 1',
      whereArgs: [pseudo, password],
      limit: 1,
    );
    if (results.isNotEmpty) {
      final user = results.first;
      await db.update(
        UserSchema.tableName,
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [user['id']],
      );
      return user;
    }
    return null;
  }
}
