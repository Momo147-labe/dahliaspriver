import 'package:sqflite/sqflite.dart';
import 'base_dao.dart';

class ReportsDao extends BaseDao {
  ReportsDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getClassesForReports(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT DISTINCT c.* 
      FROM classe c
      JOIN eleve e ON e.classe_id = c.id
      WHERE e.annee_scolaire_id = ?
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentsByClasse(
    int classeId,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT e.*, ep.decision_promotion
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id
      WHERE ep.classe_id = ? AND ep.annee_scolaire_id = ?
      ORDER BY e.nom, e.prenom
    ''',
      [classeId, anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentNotesForBulletin(
    int eleveId,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT n.*, m.nom as matiere_nom, m.code as matiere_code,
             cm.coefficient, cm.groupe
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = e.classe_id
      WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
    ''',
      [eleveId, anneeId],
    );
  }

  Future<Map<String, dynamic>> getBulletinStats(
    int eleveId,
    int anneeId,
  ) async {
    // Complex stats for a student's bulletin
    return {};
  }
}
