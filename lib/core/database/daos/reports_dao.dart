import 'package:sqflite/sqflite.dart';
import 'base_dao.dart';

class ReportsDao extends BaseDao {
  ReportsDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getClassesForReports(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT DISTINCT c.* 
      FROM classe c
      JOIN eleve_parcours ep ON c.id = ep.classe_id
      WHERE ep.annee_scolaire_id = ?
      ORDER BY c.nom
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
      SELECT e.*, ep.classe_id
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
    int trimestre,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT n.*, m.nom as matiere_nom, COALESCE(cm.coefficient, 1) as coefficient
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND n.annee_scolaire_id = ep.annee_scolaire_id
      LEFT JOIN classe_matiere cm ON m.id = cm.matiere_id AND cm.classe_id = ep.classe_id
      WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
    ''',
      [eleveId, trimestre, anneeId],
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
