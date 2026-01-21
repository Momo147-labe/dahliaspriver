import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentReceiptPdf {
  static Future<void> generateAndPrint({
    required Map<String, dynamic> transaction,
    required Map<String, double> financialStatus,
    required Map<String, dynamic> schoolInfo,
    Uint8List? schoolLogo,
    Uint8List? studentPhoto,
    required String anneeScolaire,
    required List<Map<String, dynamic>> history,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    DateTime date;
    try {
      date = DateTime.parse(
        transaction['date_paiement']?.toString() ??
            DateTime.now().toIso8601String(),
      );
    } catch (_) {
      date = DateTime.now();
    }
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
    final amount = NumberFormat(
      '#,###',
      'fr_FR',
    ).format(transaction['montant']);

    final totalPaid = NumberFormat(
      '#,###',
      'fr_FR',
    ).format(financialStatus['totalPaid']);
    final totalExpected = NumberFormat(
      '#,###',
      'fr_FR',
    ).format(financialStatus['totalExpected']);
    final balance = NumberFormat(
      '#,###',
      'fr_FR',
    ).format(financialStatus['balance']);

    pdf.addPage(
      pw.Page(
        pageFormat:
            PdfPageFormat.a5, // Receipt size (A5 is half A4, good for receipts)
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // HEADER
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (schoolLogo != null)
                      pw.Container(
                        width: 60,
                        height: 60,
                        child: pw.Image(pw.MemoryImage(schoolLogo)),
                      ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            schoolInfo['nom'] ?? 'Éclat du Savoir',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 16,
                              color: PdfColors.blue900,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                          pw.Text(
                            schoolInfo['adresse'] ?? 'Conakry, Guinée',
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                          pw.Text(
                            'Tel: ${schoolInfo['telephone'] ?? ''}',
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Divider(color: PdfColors.grey),
                pw.SizedBox(height: 10),

                // TITLE
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue100,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Text(
                      'REÇU DE PAIEMENT',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 18,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Année Scolaire: $anneeScolaire',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 20),

                // STUDENT INFO
                pw.Row(
                  children: [
                    if (studentPhoto != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey),
                          borderRadius: pw.BorderRadius.circular(25),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 25,
                          verticalRadius: 25,
                          child: pw.Image(
                            pw.MemoryImage(studentPhoto),
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      ),
                    pw.SizedBox(width: 15),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${transaction['eleve_prenom']} ${transaction['eleve_nom']}'
                              .toUpperCase(),
                          style: pw.TextStyle(font: fontBold, fontSize: 14),
                        ),
                        pw.Text(
                          'Classe: ${transaction['classe_nom']}',
                          style: pw.TextStyle(font: font, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // TRANSACTION DETAILS
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    children: [
                      _buildRow('Date', formattedDate, font, fontBold),
                      pw.Divider(color: PdfColors.grey300),
                      _buildRow(
                        'Motif',
                        transaction['motif'] ?? 'Frais de scolarité',
                        font,
                        fontBold,
                      ),
                      pw.Divider(color: PdfColors.grey300),
                      _buildRow(
                        'Mode de paiement',
                        transaction['mode_paiement'] ?? 'Espèces',
                        font,
                        fontBold,
                      ),
                      pw.Divider(color: PdfColors.grey300),
                      _buildRow(
                        'Montant payé',
                        '$amount GNF',
                        font,
                        fontBold,
                        isAmount: true,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // HISTORY TABLE
                if (history.isNotEmpty) ...[
                  pw.Text(
                    'Historique des paiements',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Table.fromTextArray(
                    headers: ['Date', 'Motif', 'Montant'],
                    data: history.map((p) {
                      DateTime pDate;
                      try {
                        pDate = DateTime.parse(
                          p['date_paiement']?.toString() ?? '',
                        );
                      } catch (_) {
                        pDate = DateTime.now();
                      }
                      return [
                        DateFormat('dd/MM/yy').format(pDate),
                        p['motif'] ?? '',
                        '${NumberFormat('#,###', 'fr_FR').format(p['montant'])} GNF',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
                    cellStyle: pw.TextStyle(font: font, fontSize: 9),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    cellAlignments: {
                      0: pw.Alignment.centerLeft,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerRight,
                    },
                    border: pw.TableBorder.all(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // FINANCIAL STATUS SUMMARY
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.grey100,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Situation Financière (Annuelle)',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      _buildSummaryRow(
                        'Total versé à ce jour:',
                        '$totalPaid GNF',
                        font,
                        fontBold,
                        PdfColors.green800,
                      ),
                      _buildSummaryRow(
                        'Total scolarité:',
                        '$totalExpected GNF',
                        font,
                        fontBold,
                        PdfColors.black,
                      ),
                      _buildSummaryRow(
                        'Reste à payer:',
                        '$balance GNF',
                        font,
                        fontBold,
                        PdfColors.red800,
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // FOOTER / SIGNATURE
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'Le payeur',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          width: 80,
                          height: 1,
                          color: PdfColors.black,
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Le comptable',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          width: 80,
                          height: 1,
                          color: PdfColors.black,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Merci de votre confiance. Gardez ce reçu précieusement.',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Recu_${transaction['eleve_nom']}_$formattedDate',
    );
  }

  static pw.Widget _buildRow(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold, {
    bool isAmount = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 12)),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: isAmount ? 16 : 12,
            color: isAmount ? PdfColors.blue800 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
    PdfColor color,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text(
            value,
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
