import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AnalyticsPdfService {
  // ---------- Color palette ----------
  static final _primary = PdfColor.fromHex('#0a3d54');
  static final _accent = PdfColor.fromHex('#f5a623');
  static final _success = PdfColor.fromHex('#22c55e');
  static final _purple = PdfColor.fromHex('#8b5cf6');
  static final _rowAlt = PdfColor.fromHex('#f0f4f8');

  static Future<void> generateAndPrint({
    required Map<String, dynamic> schoolInfo,
    required String academicYear,
    required Map<String, dynamic> studentData,
    required Map<String, dynamic> financialData,
    required Map<String, dynamic> academicData,
    required Map<String, dynamic> classData,
    required Map<String, dynamic> teacherData,
    required List<Map<String, dynamic>> ageDistribution,
    required List<Map<String, dynamic>> geographicDistribution,
    required List<Map<String, dynamic>> genderStatsByCycle,
    required List<Map<String, dynamic>> subjectPerformance,
    required List<Map<String, dynamic>> teacherPerformanceStats,
    required List<Map<String, dynamic>> monthlyCollectionCurve,
    Uint8List? schoolLogo,
  }) async {
    final pdf = pw.Document();
    final fontR = await PdfGoogleFonts.robotoRegular();
    final fontB = await PdfGoogleFonts.robotoBold();
    final fontI = await PdfGoogleFonts.robotoItalic();

    final fmt = NumberFormat('#,###', 'fr_FR');
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // ---- Helper builders available across pages ----
    pw.Widget _header() => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (schoolLogo != null)
                pw.Container(
                  width: 40,
                  height: 40,
                  margin: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(pw.MemoryImage(schoolLogo)),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    (schoolInfo['nom'] ?? 'ÉCOLE').toUpperCase(),
                    style: pw.TextStyle(
                      font: fontB,
                      fontSize: 13,
                      color: _primary,
                    ),
                  ),
                  pw.Text(
                    'Rapport Analytics — $academicYear',
                    style: pw.TextStyle(
                      font: fontI,
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Text(
            now,
            style: pw.TextStyle(
              font: fontR,
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );

    pw.Widget _sectionTitle(String title, {PdfColor? color}) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: color ?? _primary,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(font: fontB, fontSize: 10, color: PdfColors.white),
      ),
    );

    pw.Widget _kpiRow(List<Map<String, String>> items) => pw.Row(
      children: items
          .map(
            (item) => pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item['label']!,
                      style: pw.TextStyle(
                        font: fontR,
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      item['value']!,
                      style: pw.TextStyle(
                        font: fontB,
                        fontSize: 14,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );

    pw.Widget _simpleTable(List<String> headers, List<List<String>> rows) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _primary),
            children: headers
                .map(
                  (h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        font: fontB,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                )
                .toList(),
          ),
          ...rows
              .asMap()
              .map(
                (i, row) => MapEntry(
                  i,
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isOdd ? _rowAlt : PdfColors.white,
                    ),
                    children: row
                        .map(
                          (cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              cell,
                              style: pw.TextStyle(font: fontR, fontSize: 8),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              )
              .values
              .toList(),
        ],
      );
    }

    // ---- Section data helpers ----
    final stu = studentData['current'] as Map<String, dynamic>? ?? {};
    final fin = financialData['current'] as Map<String, dynamic>? ?? {};
    final acad = academicData['current'] as Map<String, dynamic>? ?? {};

    final totalStudents = stu['total'] ?? 0;
    final boys = stu['males'] ?? 0;
    final girls = stu['females'] ?? 0;
    final totalRevenue = (fin['total_collected'] ?? 0).toDouble();
    final totalSalaries = (fin['expenses'] ?? 0).toDouble();
    final avgGrade = (acad['average_grade'] ?? 0.0);
    final successRate = (acad['success_rate'] ?? 0.0);
    final totalTeachers = teacherData['totalTeachers'] ?? 0;

    // =========================================================
    //  PAGE 1: Cover + Executive Summary + Student Section
    // =========================================================
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber}/${ctx.pagesCount}',
            style: pw.TextStyle(
              font: fontR,
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ),
        build: (ctx) => [
          // ---- Cover band ----
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 16,
            ),
            margin: const pw.EdgeInsets.only(bottom: 20),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [_primary, _purple]),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RAPPORT ANALYTIQUE',
                  style: pw.TextStyle(
                    font: fontB,
                    fontSize: 22,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Année Scolaire : $academicYear',
                  style: pw.TextStyle(
                    font: fontI,
                    fontSize: 12,
                    color: PdfColor.fromHex('#ffffffbb'),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Généré le $now',
                  style: pw.TextStyle(
                    font: fontR,
                    fontSize: 9,
                    color: PdfColor.fromHex('#ffffff88'),
                  ),
                ),
              ],
            ),
          ),

          // ---- KPI Summary ----
          _sectionTitle('Résumé Exécutif', color: _primary),
          pw.SizedBox(height: 6),
          _kpiRow([
            {'label': 'Total Élèves', 'value': totalStudents.toString()},
            {'label': 'Garçons / Filles', 'value': '$boys / $girls'},
            {'label': 'Revenus (GNF)', 'value': fmt.format(totalRevenue)},
            {'label': 'Salaires (GNF)', 'value': fmt.format(totalSalaries)},
          ]),
          pw.SizedBox(height: 8),
          _kpiRow([
            {
              'label': 'Moyenne Générale',
              'value': '${avgGrade.toStringAsFixed(2)}/20',
            },
            {
              'label': 'Taux de Réussite',
              'value': '${successRate.toStringAsFixed(1)}%',
            },
            {'label': 'Enseignants', 'value': totalTeachers.toString()},
            {
              'label': 'Budget Net (GNF)',
              'value': fmt.format(totalRevenue - totalSalaries),
            },
          ]),

          // ---- Students ----
          _sectionTitle('Effectif & Démographie', color: _primary),
          pw.SizedBox(height: 6),
          if ((classData['byClass'] as List?)?.isNotEmpty == true) ...[
            _simpleTable(
              ['Classe', 'Effectif', 'Garçons', 'Filles'],
              (classData['byClass'] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .map(
                    (c) => [
                      c['classe_nom']?.toString() ?? '',
                      (c['total'] ?? 0).toString(),
                      (c['garcons'] ?? 0).toString(),
                      (c['filles'] ?? 0).toString(),
                    ].cast<String>().toList(),
                  )
                  .toList(),
            ),
          ],

          pw.SizedBox(height: 12),
          // Age Distribution
          if (ageDistribution.isNotEmpty) ...[
            _sectionTitle('Distribution par Âge', color: _purple),
            pw.SizedBox(height: 6),
            _simpleTable(
              ['Tranche d\'Âge', 'Nombre d\'Élèves'],
              ageDistribution
                  .map(
                    (a) => [
                      a['bracket']?.toString() ?? '-',
                      (a['count'] ?? 0).toString(),
                    ].cast<String>().toList(),
                  )
                  .toList(),
            ),
          ],

          pw.SizedBox(height: 12),
          // Gender by Cycle
          if (genderStatsByCycle.isNotEmpty) ...[
            _sectionTitle('Ratio Filles/Garçons par Cycle', color: _purple),
            pw.SizedBox(height: 6),
            _simpleTable(
              ['Cycle', 'Garçons', 'Filles', 'Total'],
              genderStatsByCycle
                  .map(
                    (g) => [
                      g['nom']?.toString() ?? '-',
                      (g['male_count'] ?? 0).toString(),
                      (g['female_count'] ?? 0).toString(),
                      ((g['male_count'] ?? 0) + (g['female_count'] ?? 0))
                          .toString(),
                    ].cast<String>().toList(),
                  )
                  .toList(),
            ),
          ],

          // ---- Financial ----
          _sectionTitle('Finances', color: _success),
          pw.SizedBox(height: 6),
          _kpiRow([
            {
              'label': 'Revenu Total',
              'value': '${fmt.format(totalRevenue)} GNF',
            },
            {
              'label': 'Dépenses (Salaires)',
              'value': '${fmt.format(totalSalaries)} GNF',
            },
            {
              'label': 'Solde Net',
              'value': '${fmt.format(totalRevenue - totalSalaries)} GNF',
            },
          ]),
          pw.SizedBox(height: 10),
          if (monthlyCollectionCurve.isNotEmpty) ...[
            _sectionTitle('Courbe de Collecte Mensuelle', color: _success),
            pw.SizedBox(height: 6),
            _simpleTable(
              ['Mois', 'Revenus (GNF)'],
              monthlyCollectionCurve
                  .map(
                    (m) => [
                      _getMonthName(m['month']?.toString() ?? '01'),
                      fmt.format((m['total'] ?? 0).toDouble()),
                    ].cast<String>().toList(),
                  )
                  .toList(),
            ),
          ],

          // ---- Academic ----
          _sectionTitle('Performance Académique', color: _accent),
          pw.SizedBox(height: 6),
          _kpiRow([
            {
              'label': 'Moyenne Générale',
              'value':
                  '${(acad['average_grade'] ?? 0.0).toStringAsFixed(2)}/20',
            },
            {
              'label': 'Taux de Réussite',
              'value': '${(acad['success_rate'] ?? 0.0).toStringAsFixed(1)}%',
            },
            {
              'label': 'Élèves Évalués',
              'value': (acad['students_graded'] ?? 0).toString(),
            },
          ]),
          pw.SizedBox(height: 10),
          if (subjectPerformance.isNotEmpty) ...[
            _sectionTitle('Performance par Matière', color: _accent),
            pw.SizedBox(height: 6),
            _simpleTable(
              ['Matière', 'Moy. Générale', 'Taux Réussite', 'Nb. Évals'],
              subjectPerformance
                  .map(
                    (s) => [
                      s['matiere_nom']?.toString() ?? '-',
                      (s['avg_note'] ?? 0.0).toStringAsFixed(2),
                      '${((s['taux_reussite'] ?? 0.0) as num).toStringAsFixed(1)}%',
                      (s['nombre_evaluations'] ?? 0).toString(),
                    ].cast<String>().toList(),
                  )
                  .toList(),
            ),
          ],

          // ---- Teacher Performance ----
          if (teacherPerformanceStats.isNotEmpty) ...[
            _sectionTitle('Performance Enseignants', color: _primary),
            pw.SizedBox(height: 6),
            _simpleTable(
              ['Enseignant', 'Matière', 'Moy. Classe', 'Taux Réussite'],
              teacherPerformanceStats
                  .map(
                    (t) => [
                      t['enseignant_nom']?.toString() ?? '-',
                      t['matiere_nom']?.toString() ?? '-',
                      (t['avg_note'] ?? 0.0).toStringAsFixed(2),
                      '${((t['taux_reussite'] ?? 0.0) as num).toStringAsFixed(1)}%',
                    ].cast<String>().toList(),
                  )
                  .toList(),
            ),
          ],

          // ---- Geographic ----
          if (geographicDistribution.isNotEmpty) ...[
            _sectionTitle('Distribution Géographique', color: _purple),
            pw.SizedBox(height: 6),
            _simpleTable(
              ['Localité', 'Nombre d\'Élèves'],
              geographicDistribution
                  .map(
                    (g) => [
                      g['lieu_naissance']?.toString() ?? '-',
                      (g['count'] ?? 0).toString(),
                    ].cast<String>().toList(),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Rapport_Analytics_$academicYear.pdf',
    );
  }

  static String _getMonthName(String monthNum) {
    const months = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    int idx = int.tryParse(monthNum) ?? 0;
    if (idx >= 1 && idx <= 12) return months[idx];
    return 'Inconnu';
  }
}
