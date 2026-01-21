import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/ecole.dart';

class BulletinPdfHelper {
  static Future<pw.Document> generateSingleBulletin({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> stats,
    required Ecole? ecole,
    required String trimestre,
    required String annee,
  }) async {
    final pdf = pw.Document();
    await _addBulletinPage(
      pdf,
      student,
      grades,
      stats,
      ecole,
      trimestre,
      annee,
    );
    return pdf;
  }

  static Future<pw.Document> generateBatchBulletins({
    required List<Map<String, dynamic>>
    studentsData, // List of {student, grades, stats}
    required Ecole? ecole,
    required String trimestre,
    required String annee,
  }) async {
    final pdf = pw.Document();
    for (var data in studentsData) {
      await _addBulletinPage(
        pdf,
        data['student'],
        data['grades'],
        data['stats'],
        ecole,
        trimestre,
        annee,
      );
    }
    return pdf;
  }

  static Future<pw.Document> generateSingleAnnualBulletin({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> stats,
    required Ecole? ecole,
    required String annee,
  }) async {
    final pdf = pw.Document();
    await _addAnnualBulletinPage(pdf, student, grades, stats, ecole, annee);
    return pdf;
  }

  static Future<pw.Document> generateBatchAnnualBulletins({
    required List<Map<String, dynamic>> studentsData,
    required Ecole? ecole,
    required String annee,
  }) async {
    final pdf = pw.Document();
    for (var data in studentsData) {
      await _addAnnualBulletinPage(
        pdf,
        data['student'],
        data['grades'],
        data['stats'],
        ecole,
        annee,
      );
    }
    return pdf;
  }

  static Future<void> _addBulletinPage(
    pw.Document pdf,
    Map<String, dynamic> student,
    List<Map<String, dynamic>> grades,
    Map<String, dynamic> stats,
    Ecole? ecole,
    String trimestre,
    String annee,
  ) async {
    // Load logo if available
    final logoPath = ecole?.logo;
    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    // Load student photo if available
    final photoPath = student['photo'];
    pw.MemoryImage? studentPhoto;
    if (photoPath != null && File(photoPath).existsSync()) {
      studentPhoto = pw.MemoryImage(File(photoPath).readAsBytesSync());
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(logoImage, ecole, annee, trimestre),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 10),
                _buildTitle(trimestre, annee),
                pw.SizedBox(height: 15),
                _buildStudentInfo(student, stats, studentPhoto),
                pw.SizedBox(height: 20),
                _buildGradesTable(grades),
                pw.SizedBox(height: 20),
                _buildSummary(stats),
                pw.SizedBox(height: 30),
                _buildFooter(),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    'Document généré par Guinée École - Système de Gestion Scolaire',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _addAnnualBulletinPage(
    pw.Document pdf,
    Map<String, dynamic> student,
    List<Map<String, dynamic>> grades,
    Map<String, dynamic> stats,
    Ecole? ecole,
    String annee,
  ) async {
    // Load logo if available
    final logoPath = ecole?.logo;
    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    // Load student photo if available
    final photoPath = student['photo'];
    pw.MemoryImage? studentPhoto;
    if (photoPath != null && File(photoPath).existsSync()) {
      studentPhoto = pw.MemoryImage(File(photoPath).readAsBytesSync());
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(logoImage, ecole, annee, 'BILAN ANNUEL'),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 10),
                _buildTitle('BILAN ANNUEL', annee),
                pw.SizedBox(height: 15),
                _buildStudentInfo(student, stats, studentPhoto),
                pw.SizedBox(height: 20),
                _buildAnnualGradesTable(grades),
                pw.SizedBox(height: 20),
                _buildSummary(stats, title: 'RÉSULTATS ANNUELS'),
                pw.SizedBox(height: 30),
                _buildFooter(),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    'Document généré par Guinée École - Système de Gestion Scolaire',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static pw.Widget _buildHeader(
    pw.MemoryImage? logo,
    Ecole? ecole,
    String annee,
    String trimestre,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Republic Logo
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 10,
                  height: 30,
                  color: PdfColor.fromInt(0xFFCE1126),
                ),
                pw.SizedBox(width: 2),
                pw.Container(
                  width: 10,
                  height: 30,
                  color: PdfColor.fromInt(0xFFFCD116),
                ),
                pw.SizedBox(width: 2),
                pw.Container(
                  width: 10,
                  height: 30,
                  color: PdfColor.fromInt(0xFF009460),
                ),
              ],
            ),
            pw.Text(
              'RÉPUBLIQUE DE GUINÉE',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'TRAVAIL - JUSTICE - SOLIDARITÉ',
              style: const pw.TextStyle(fontSize: 5),
            ),
          ],
        ),
        // School Info
        pw.Expanded(
          child: pw.Column(
            children: [
              if (logo != null)
                pw.Container(width: 40, height: 40, child: pw.Image(logo)),
              pw.Text(
                ecole?.nom.toUpperCase() ?? 'GROUPE SCOLAIRE',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                ecole?.adresse ?? '',
                style: const pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
              if (ecole?.telephone != null)
                pw.Text(
                  'Tél: ${ecole!.telephone}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
            ],
          ),
        ),
        // Academic Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'ANNÉE SCOLAIRE',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              annee,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF13DAEC),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                trimestre,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTitle(String trimestre, String annee) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'BULLETIN DE NOTES',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '$trimestre - $annee',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStudentInfo(
    Map<String, dynamic> student,
    Map<String, dynamic> stats,
    pw.MemoryImage? photo,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 80,
          height: 80,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          child: photo != null
              ? pw.Image(photo, fit: pw.BoxFit.cover)
              : pw.Center(
                  child: pw.Text(
                    'PHOTO',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ÉLÈVE: ${student['nom']} ${student['prenom']}'.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Matricule: ${student['matricule']}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Classe: ${student['classe_nom']}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Né(e) le: ${student['date_naissance']} à ${student['lieu_naissance']}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _buildPdfMetric(
              'MOYENNE',
              '${(stats['average'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
            ),
            pw.SizedBox(height: 5),
            _buildPdfMetric(
              'RANG',
              '${stats['rank'] ?? '-'} / ${stats['totalStudents'] ?? '-'}',
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPdfMetric(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildGradesTable(List<Map<String, dynamic>> grades) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeader('Matières'),
            _tableHeader('Coeff'),
            _tableHeader('Moyenne'),
            _tableHeader('Total'),
            _tableHeader('Observations'),
          ],
        ),
        ...grades.map((g) {
          final note = (g['note'] as num?)?.toDouble() ?? 0.0;
          final coeff = (g['coefficient'] as num?)?.toDouble() ?? 1.0;
          return pw.TableRow(
            children: [
              _tableCell(g['matiere_nom'] ?? '', alignLeft: true),
              _tableCell(coeff.toStringAsFixed(0)),
              _tableCell(note.toStringAsFixed(2)),
              _tableCell((note * coeff).toStringAsFixed(2)),
              _tableCell(_getObservation(note)),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildAnnualGradesTable(List<Map<String, dynamic>> grades) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3), // Matières
        1: const pw.FlexColumnWidth(1), // Coeff
        2: const pw.FlexColumnWidth(1), // Tot T1
        3: const pw.FlexColumnWidth(1), // Tot T2
        4: const pw.FlexColumnWidth(1), // Tot T3
        5: const pw.FlexColumnWidth(1.2), // Moy An
        6: const pw.FlexColumnWidth(1), // Rang
        7: const pw.FlexColumnWidth(2), // Appreciation
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeader('Matières'),
            _tableHeader('Coeff'),
            _tableHeader('Moy T1'),
            _tableHeader('Moy T2'),
            _tableHeader('Moy T3'),
            _tableHeader('Moy An'),
            _tableHeader('Rang'),
            _tableHeader('Appréciation'),
          ],
        ),
        ...grades.map((g) {
          final t1 = (g['moy_t1'] as num?)?.toDouble();
          final t2 = (g['moy_t2'] as num?)?.toDouble();
          final t3 = (g['moy_t3'] as num?)?.toDouble();
          final moyAn = (g['moy_annuelle'] as num?)?.toDouble() ?? 0.0;

          return pw.TableRow(
            children: [
              _tableCell(g['matiere_nom'] ?? '', alignLeft: true),
              _tableCell('${g['coefficient']}'),
              _tableCell(t1?.toStringAsFixed(2) ?? '-'),
              _tableCell(t2?.toStringAsFixed(2) ?? '-'),
              _tableCell(t3?.toStringAsFixed(2) ?? '-'),
              _tableCell(moyAn.toStringAsFixed(2), isBold: true),
              _tableCell('${g['rang']}e'),
              _tableCell(g['appreciation'] ?? ''),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool alignLeft = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildSummary(
    Map<String, dynamic> stats, {
    String title = 'RÉSULTATS DU TRIMESTRE',
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.Text(
                'Moyenne de l\'élève: ${(stats['average'] as double?)?.toStringAsFixed(2) ?? '-'}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Rang: ${stats['rank'] ?? '-'} / ${stats['totalStudents'] ?? '-'}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Moyenne de classe: ${(stats['classAverage'] as double?)?.toStringAsFixed(2) ?? '-'}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 200,
          height: 80,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(
            children: [
              pw.Text(
                'OBSERVATIONS ET VISA',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              pw.Text('Le Directeur', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Fait à Conakry, le ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  static String _getObservation(double note) {
    if (note >= 16) return 'Très Bien';
    if (note >= 14) return 'Bien';
    if (note >= 12) return 'Assez Bien';
    if (note >= 10) return 'Passable';
    return 'Insuffisant';
  }
}
