import 'package:sqflite/sqflite.dart';
import '../schemas/matiere_schema.dart';
import '../../../models/matiere.dart';
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

  Future<List<Map<String, dynamic>>> getMatieresStats() async {
    return await db.rawQuery('''
      SELECT m.*, 
             (SELECT COUNT(DISTINCT eleve_id) FROM notes WHERE matiere_id = m.id) as students_count,
             (SELECT COUNT(DISTINCT classe_id) FROM classe_matiere WHERE matiere_id = m.id) as classes_count
      FROM matiere m
    ''');
  }

  Future<int> deleteSubject(int id) async {
    return await db.delete(
      MatiereSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSubjectsByClass(int classeId) async {
    return await db.rawQuery(
      '''
      SELECT m.*, cm.coefficient
      FROM ${MatiereSchema.tableName} m
      JOIN classe_matiere cm ON m.id = cm.matiere_id
      WHERE cm.classe_id = ?
      ORDER BY m.nom ASC
    ''',
      [classeId],
    );
  }

  Future<bool> isSubjectInClass(int classeId, int matiereId) async {
    final result = await db.query(
      'classe_matiere',
      where: 'classe_id = ? AND matiere_id = ?',
      whereArgs: [classeId, matiereId],
    );
    return result.isNotEmpty;
  }

  Future<List<Matiere>> getMatieresByAnnee(int anneeId) async {
    // Retourne toutes les matières (pas seulement celles assignées à une classe)
    // pour que les matières nouvellement créées soient visibles immédiatement.
    final result = await db.query(MatiereSchema.tableName, orderBy: 'nom ASC');
    return result.map((m) => Matiere.fromMap(m)).toList();
  }

  Future<int> saveSubject(Map<String, dynamic> subject) async {
    if (subject['id'] != null) {
      return await updateSubject(subject['id'], subject);
    } else {
      return await insertSubject(subject);
    }
  }
}
