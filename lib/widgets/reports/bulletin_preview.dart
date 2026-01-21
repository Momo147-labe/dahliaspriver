import 'package:flutter/material.dart';
import 'bulletin_header.dart';
import 'bulletin_title.dart';
import 'bulletin_student_info.dart';
import 'bulletin_grades_table.dart';
import 'bulletin_summary.dart';
import 'bulletin_footer.dart';
import '../../models/ecole.dart';

import 'bulletin_annual_grades_table.dart';

class BulletinPreview extends StatelessWidget {
  final double zoomLevel;
  final String trimestre;
  final String annee;
  final Ecole? ecole;
  final Map<String, dynamic> studentInfo;
  final List<Map<String, dynamic>> grades;
  final Map<String, dynamic> summary;
  final bool isAnnual;

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
              color: Colors.black.withOpacity(0.1),
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
              classe: studentInfo['classe_nom'] ?? '',
              matricule: studentInfo['matricule'] ?? '',
              photoPath: studentInfo['photo'],
              moyenne: summary['moyenne'] ?? '',
              rang: summary['rang'] ?? '',
              absences: studentInfo['absences']?.toString() ?? '0',
            ),
            const SizedBox(height: 24),

            // Grades Table
            isAnnual
                ? BulletinAnnualGradesTable(grades: grades)
                : BulletinGradesTable(grades: grades),
            const SizedBox(height: 16),

            // Results Summary
            BulletinSummary(
              moyenne: summary['moyenne'] ?? '',
              rang: summary['rang'] ?? '',
              moyenneGenerale: summary['moyenneGenerale'] ?? '',
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
