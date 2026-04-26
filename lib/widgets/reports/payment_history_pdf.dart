import 'dart:typed_data';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentHistoryPdf {
  static Future<void> generateAndPrint({
    required List<Map<String, dynamic>> transactions,
    required Map<String, dynamic> schoolInfo,
    Uint8List? schoolLogo,
    required String academicYear,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final primaryBlue = PdfColor.fromHex('#0a3d54');
    final secondaryOrange = PdfColor.fromHex('#f5a623');

    // Create chunks of transactions (e.g. 25 per page)
    const itemsPerPage = 25;
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < transactions.length; i += itemsPerPage) {
      chunks.add(
        transactions.sublist(
          i,
          i + itemsPerPage > transactions.length
              ? transactions.length
              : i + itemsPerPage,
        ),
      );
    }

    if (chunks.isEmpty) {
      chunks.add([]); // ensure at least one page
    }

    double totalGeneral = 0;
    for (var t in transactions) {
      totalGeneral += (t['montant'] ?? 0).toDouble();
    }

    for (int pageIndex = 0; pageIndex < chunks.length; pageIndex++) {
      final chunk = chunks[pageIndex];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header (only on first page or all? Let's put a smaller one on every page)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (schoolLogo != null)
                          pw.Container(
                            width: 60,
                            height: 60,
                            margin: const pw.EdgeInsets.only(right: 15),
                            child: pw.Image(pw.MemoryImage(schoolLogo)),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              (schoolInfo['nom'] ?? 'NOM DE L\'ÉCOLE')
                                  .toUpperCase(),
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 16,
                                color: primaryBlue,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              schoolInfo['slogan'] ?? '',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Année Scolaire: $academicYear',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'HISTORIQUE DES PAIEMENTS',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: secondaryOrange,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Page ${pageIndex + 1} / ${chunks.length}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5), // Date
                    1: const pw.FlexColumnWidth(1.5), // Matricule
                    2: const pw.FlexColumnWidth(3), // Nom
                    3: const pw.FlexColumnWidth(1.5), // Classe
                    4: const pw.FlexColumnWidth(2), // Montant
                    5: const pw.FlexColumnWidth(1.5), // Mode
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: primaryBlue),
                      children:
                          [
                                'Date',
                                'Matricule',
                                'Élève',
                                'Classe',
                                'Montant (GNF)',
                                'Mode',
                              ]
                              .map(
                                (header) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(
                                    header,
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 9,
                                      color: PdfColors.white,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    // Table Rows
                    ...chunk.map((t) {
                      String date = t['date_paiement'] ?? '';
                      if (date.length > 10) date = date.substring(0, 10);
                      final montant = (t['montant'] ?? 0).toDouble();
                      return pw.TableRow(
                        children: [
                          _buildTableCell(date, font),
                          _buildTableCell(
                            t['eleve_matricule'] ?? t['matricule'] ?? '',
                            font,
                          ),
                          _buildTableCell(
                            "${t['eleve_nom'] ?? ''} ${t['eleve_prenom'] ?? ''}",
                            font,
                            align: pw.TextAlign.left,
                          ),
                          _buildTableCell(t['classe_nom'] ?? '', font),
                          _buildTableCell(
                            NumberFormat('#,###', 'fr_FR').format(montant),
                            font,
                            align: pw.TextAlign.right,
                          ),
                          _buildTableCell(
                            (t['mode_paiement'] ?? '').toUpperCase(),
                            font,
                          ),
                        ],
                      );
                    }),
                    // Total row (only on last page)
                    if (pageIndex == chunks.length - 1)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          _buildTableCell(
                            'TOTAL',
                            fontBold,
                            align: pw.TextAlign.left,
                          ),
                          _buildTableCell('', font),
                          _buildTableCell('', font),
                          _buildTableCell('', font),
                          _buildTableCell(
                            NumberFormat('#,###', 'fr_FR').format(totalGeneral),
                            fontBold,
                            align: pw.TextAlign.right,
                          ),
                          _buildTableCell('', font),
                        ],
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Historique_Paiements_$academicYear.pdf',
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: align,
      ),
    );
  }
}
