import 'package:sqflite/sqflite.dart';
import '../schemas/matiere_schema.dart';
import 'base_dao.dart';

class MatiereDao extends BaseDao {
  MatiereDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    return await db.query(MatiereSchema.tableName, orderBy: 'nom ASC');
  }

  Future<int> insertSubject(Map<String, dynamic> subject) async {
    return await db.insert(MatiereSchema.tableName, subject);
  }

  Future<int> updateSubject(int id, Map<String, dynamic> subject) async {
    subject['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      MatiereSchema.tableName,
      subject,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSubject(int id) async {
    return await db.delete(
      MatiereSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSubjectsByClass(
    int classeId,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT m.*, cm.coefficient
      FROM ${MatiereSchema.tableName} m
      JOIN classe_matiere cm ON m.id = cm.matiere_id
      WHERE cm.classe_id = ? AND cm.annee_scolaire_id = ?
      ORDER BY m.nom ASC
    ''',
      [classeId, anneeId],
    );
  }

  Future<bool> isSubjectInClass(
    int classeId,
    int matiereId,
    int anneeId,
  ) async {
    final result = await db.query(
      'classe_matiere',
      where: 'classe_id = ? AND matiere_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classeId, matiereId, anneeId],
    );
    return result.isNotEmpty;
  }
}
