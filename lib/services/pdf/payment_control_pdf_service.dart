import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PaymentControlPdfService {
  static String _getStatus(Map<String, dynamic> student, String type) {
    final double totalPaid = (student['total_paye'] as num?)?.toDouble() ?? 0.0;
    final double inscription =
        (student['inscription'] as num?)?.toDouble() ?? 0.0;
    final double reinscription =
        (student['reinscription'] as num?)?.toDouble() ?? 0.0;
    final double t1 = (student['tranche1'] as num?)?.toDouble() ?? 0.0;
    final double t2 = (student['tranche2'] as num?)?.toDouble() ?? 0.0;
    final double t3 = (student['tranche3'] as num?)?.toDouble() ?? 0.0;

    final bool isReinscrit = student['eleve_statut'] == 'reinscrit';
    final double firstFee = isReinscrit ? reinscription : inscription;

    double sum1 = firstFee;
    double sum2 = sum1 + t1;
    double sum3 = sum2 + t2;
    double sum4 = sum3 + t3;

    final double? rest = student['montant_restant'] != null
        ? (student['montant_restant'] as num).toDouble()
        : null;

    if (rest != null && rest <= 0) return 'Payé';

    switch (type) {
      case 'Inscription':
        if (totalPaid >= sum1) return 'Payé';
        if (totalPaid > 0) return 'Partiel';
        return 'Impayé';
      case 'Tranche 1':
        if (totalPaid >= sum2) return 'Payé';
        if (totalPaid > sum1) return 'Partiel';
        return 'Impayé';
      case 'Tranche 2':
        if (totalPaid >= sum3) return 'Payé';
        if (totalPaid > sum2) return 'Partiel';
        return 'Impayé';
      case 'Tranche 3':
        if (totalPaid >= sum4) return 'Payé';
        if (totalPaid > sum3) return 'Partiel';
        return 'Impayé';
      default:
        return '-';
    }
  }

  static PdfColor _statusColor(String status) {
    switch (status) {
      case 'Payé':
        return PdfColor.fromHex('#22C55E'); // Green
      case 'Partiel':
        return PdfColor.fromHex('#F59E0B'); // Amber
      case 'Impayé':
        return PdfColor.fromHex('#EF4444'); // Red
      default:
        return PdfColors.grey;
    }
  }

  Future<pw.Document> generate(
    List<Map<String, dynamic>> students,
    String anneeLabel, {
    bool impayesOnly = false,
    bool isPaidOnly = false,
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'GNF',
      decimalDigits: 0,
    );

    final filteredStudents = isPaidOnly
        ? students.where((s) {
            final double? rest = s['montant_restant'] != null
                ? (s['montant_restant'] as num).toDouble()
                : null;
            final total = (s['montant_total'] as num?)?.toDouble() ?? 0.0;
            final paid = (s['total_paye'] as num?)?.toDouble() ?? 0.0;

            if (rest != null) return rest <= 0 && total > 0;
            return total > 0 && paid >= total;
          }).toList()
        : impayesOnly
        ? students.where((s) {
            final double? rest = s['montant_restant'] != null
                ? (s['montant_restant'] as num).toDouble()
                : null;
            final total = (s['montant_total'] as num?)?.toDouble() ?? 0.0;
            final paid = (s['total_paye'] as num?)?.toDouble() ?? 0.0;

            if (total == 0) return false;
            if (rest != null) return rest > 0;
            return paid < total;
          }).toList()
        : students;

    final displayedLabel = isPaidOnly
        ? 'Liste des Élèves Soldés'
        : impayesOnly
        ? 'Liste des Élèves Impayés'
        : 'Contrôle des Frais Scolaires';

    final int enRegle = students.where((s) {
      final double? rest = s['montant_restant'] != null
          ? (s['montant_restant'] as num).toDouble()
          : null;
      final total = (s['montant_total'] as num?)?.toDouble() ?? 0.0;
      final paid = (s['total_paye'] as num?)?.toDouble() ?? 0.0;

      if (total == 0) return false;
      if (rest != null) return rest <= 0;
      return paid >= total;
    }).length;
    final int enRetard =
        students
            .where((s) => ((s['montant_total'] as num?)?.toDouble() ?? 0.0) > 0)
            .length -
        enRegle;
    final double totalExpected = students.fold(
      0,
      (sum, s) => sum + ((s['montant_total'] as num?)?.toDouble() ?? 0.0),
    );
    final double totalCollected = students.fold(
      0,
      (sum, s) => sum + ((s['total_paye'] as num?)?.toDouble() ?? 0.0),
    );
    final double tauxRecouvrement = totalExpected > 0
        ? (totalCollected / totalExpected) * 100
        : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        header: (ctx) => _buildHeader(
          anneeLabel,
          displayedLabel,
          currency,
          enRegle,
          enRetard,
          tauxRecouvrement,
          totalExpected,
          totalCollected,
        ),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.5), // Elève
              1: const pw.FlexColumnWidth(2), // Classe
              2: const pw.FlexColumnWidth(2), // Inscription
              3: const pw.FlexColumnWidth(2), // T1
              4: const pw.FlexColumnWidth(2), // T2
              5: const pw.FlexColumnWidth(2), // T3
              6: const pw.FlexColumnWidth(2.5), // Payé
            },
            children: [
              // Header Row
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E3A5F'),
                ),
                children:
                    [
                          'ÉLÈVE',
                          'CLASSE',
                          'INSCRIPTION',
                          'TRANCHE 1',
                          'TRANCHE 2',
                          'TRANCHE 3',
                          'TOTAL PAYÉ',
                        ]
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              // Data Rows
              ...filteredStudents.asMap().entries.map((entry) {
                final i = entry.key;
                final student = entry.value;
                final isEven = i % 2 == 0;
                final bgColor = isEven
                    ? PdfColors.white
                    : PdfColor.fromHex('#F8FAFC');

                final paid = (student['total_paye'] as num?)?.toDouble() ?? 0.0;
                final total =
                    (student['montant_total'] as num?)?.toDouble() ?? 0.0;
                final isUpToDate = paid >= total;

                final insc = _getStatus(student, 'Inscription');
                final t1 = _getStatus(student, 'Tranche 1');
                final t2 = _getStatus(student, 'Tranche 2');
                final t3 = _getStatus(student, 'Tranche 3');

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgColor),
                  children: [
                    // Student Name
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${student['prenom']} ${student['nom']}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            student['matricule'] ?? '',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Classe
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: pw.Text(
                        student['classe_nom'] ?? '',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    // Statuses
                    ...[insc, t1, t2, t3].map(
                      (status) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: pw.BoxDecoration(
                            color: _statusColor(status).shade(0.2),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(6),
                            ),
                          ),
                          child: pw.Text(
                            status,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: _statusColor(status),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Total Payé
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            currency.format(paid),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                              color: isUpToDate
                                  ? PdfColor.fromHex('#22C55E')
                                  : PdfColor.fromHex('#EF4444'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '/ ${currency.format(total)}',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total: ${filteredStudents.length} élève(s);  Impayés: $enRetard; En règle: $enRegle',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(
    String anneeLabel,
    String title,
    NumberFormat currency,
    int enRegle,
    int enRetard,
    double taux,
    double totalExpected,
    double totalCollected,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1E3A5F'),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Année scolaire : $anneeLabel',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Généré le : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            // Stats blocks
            pw.Row(
              children: [
                _statBlock(
                  'En règle',
                  enRegle.toString(),
                  PdfColor.fromHex('#22C55E'),
                ),
                pw.SizedBox(width: 12),
                _statBlock(
                  'En retard',
                  enRetard.toString(),
                  PdfColor.fromHex('#EF4444'),
                ),
                pw.SizedBox(width: 12),
                _statBlock(
                  'Recouvrement',
                  '${taux.toStringAsFixed(1)}%',
                  PdfColor.fromHex('#3B82F6'),
                ),
                pw.SizedBox(width: 12),
                _statBlock(
                  'Collecté',
                  currency.format(totalCollected),
                  PdfColor.fromHex('#8B5CF6'),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(color: PdfColor.fromHex('#1E3A5F'), thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _statBlock(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: color.shade(0.15),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color.shade(0.3), width: 0.8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}
