import 'package:flutter/material.dart';
import 'bulletin_header.dart';
import 'bulletin_title.dart';
import 'bulletin_student_info.dart';
import 'bulletin_grades_table.dart';
import 'bulletin_summary.dart';
import 'bulletin_footer.dart';
import '../../models/ecole.dart';

class BulletinPreview extends StatelessWidget {
  final double zoomLevel;
  final String trimestre;
  final String annee;
  final Ecole? ecole;
  final Map<String, dynamic> studentInfo;
  final List<Map<String, dynamic>> grades;
  final Map<String, dynamic> summary;
  final bool isAnnual;
  final List<Map<String, dynamic>> columns;
  final String noteKey;
  final List<Map<String, dynamic>> mentions;

  const BulletinPreview({
    super.key,
    required this.zoomLevel,
    required this.trimestre,
    required this.annee,
    this.ecole,
    required this.studentInfo,
    required this.grades,
    required this.summary,
    this.isAnnual = false,
    required this.columns,
    this.noteKey = 'notes_par_sequence',
    this.mentions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: zoomLevel,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(minHeight: 840),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bulletin Header
            BulletinHeader(
              ecole: ecole,
              anneeLibelle: annee,
              trimestreLibelle: trimestre,
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              height: 2,
              color: Colors.black,
            ),

            // Student Title Block
            BulletinTitle(
              trimestre: isAnnual ? 'BILAN ANNUEL' : trimestre,
              annee: annee,
            ),
            const SizedBox(height: 24),

            // Student Info
            BulletinStudentInfo(
              nom: studentInfo['nom'] ?? '',
              prenom: studentInfo['prenom'] ?? '',
              dateNaissance: studentInfo['date_naissance'] ?? '',
              lieuNaissance: studentInfo['lieu_naissance'] ?? '',
              sexe: studentInfo['sexe'] ?? '',
              classe: studentInfo['classe_nom'] ?? '',
              matricule: studentInfo['matricule'] ?? '',
              photoPath: studentInfo['photo'],
              moyenne: summary['moyenne'] ?? '',
              rang: summary['rang'] ?? '',
              absences: studentInfo['absences']?.toString() ?? '0',
              moyenneBase: (summary['note_max'] as num?)?.toDouble() ?? 20.0,
            ),
            const SizedBox(height: 24),

            // Grades Table
            BulletinGradesTable(
              grades: grades,
              noteMax: (summary['note_max'] as num?)?.toDouble() ?? 20.0,
              columns: columns,
              noteKey: noteKey,
              mentions: mentions,
            ),
            const SizedBox(height: 16),

            // Results Summary
            BulletinSummary(
              moyenne: summary['moyenne'] ?? '',
              rang: summary['rang'] ?? '',
              moyenneGenerale: summary['moyenneGenerale'] ?? '',
              moyennePassage:
                  (summary['moyennePassage'] as num?)?.toDouble() ?? 10.0,
            ),
            const SizedBox(height: 24),

            // Teacher Comments & Stamp
            BulletinFooter(observations: summary['observations'] ?? ''),
            const SizedBox(height: 32),

            // Footer text
            Center(
              child: Text(
                'Document généré par Guinée École - Système de Gestion Scolaire',
                style: TextStyle(
                  fontSize: 7,
                  color: Colors.grey.shade500,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
