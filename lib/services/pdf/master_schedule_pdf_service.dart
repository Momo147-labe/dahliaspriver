import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MasterSchedulePdfService {
  static Future<void> generateAndPrint({
    required List<Map<String, dynamic>> classes,
    required Map<int, Map<String, Map<int, Map<String, dynamic>>>> matrix,
    required String schoolName,
    required String schoolYear,
  }) async {
    final pdf = pw.Document();

    // Setup fonts
    final pFont = pw.Font.helvetica();
    final pFontBold = pw.Font.helveticaBold();

    const List<String> days = [
      '',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    schoolName,
                    style: pw.TextStyle(font: pFontBold, fontSize: 16),
                  ),
                  pw.Text(
                    'PLANNING GLOBAL',
                    style: pw.TextStyle(font: pFontBold, fontSize: 22),
                  ),
                  pw.Text(
                    'Année: $schoolYear',
                    style: pw.TextStyle(font: pFont, fontSize: 14),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Build the giant table
            _buildGiantTable(classes, matrix, days, pFont, pFontBold),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static pw.Widget _buildGiantTable(
    List<Map<String, dynamic>> classes,
    Map<int, Map<String, Map<int, Map<String, dynamic>>>> matrix,
    List<String> days,
    pw.Font font,
    pw.Font fontBold,
  ) {
    if (classes.isEmpty) {
      return pw.Text("Aucune donnée.", style: pw.TextStyle(font: font));
    }

    final tableRows = <pw.TableRow>[];

    // Header Row
    final classHeaders = [
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          'Horaires',
          style: pw.TextStyle(font: fontBold, fontSize: 9),
        ),
      ),
    ];
    for (var c in classes) {
      classHeaders.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            c['nom'] ?? '',
            style: pw.TextStyle(font: fontBold, fontSize: 9),
          ),
        ),
      );
    }

    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: classHeaders,
      ),
    );

    for (int day = 1; day <= 7; day++) {
      if (!matrix.containsKey(day)) continue;

      // Day Row spanning across
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 4,
              ),
              child: pw.Text(
                days[day].toUpperCase(),
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
            ),
            for (int i = 0; i < classes.length; i++) pw.Container(),
          ],
        ),
      );

      final timeSlots = matrix[day]!.keys.toList()..sort();
      for (var slot in timeSlots) {
        final rowCells = <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: pw.Text(
              slot,
              style: pw.TextStyle(font: fontBold, fontSize: 8),
            ),
          ),
        ];

        for (var c in classes) {
          final course = matrix[day]![slot]![c['id']];
          if (course == null) {
            rowCells.add(pw.Container(padding: const pw.EdgeInsets.all(2)));
          } else {
            rowCells.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      course['matiere_nom'] ?? '',
                      style: pw.TextStyle(font: fontBold, fontSize: 8),
                      maxLines: 1,
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      '${course['enseignant_prenom'] ?? ''} ${course['enseignant_nom'] ?? ''}',
                      style: pw.TextStyle(font: font, fontSize: 7),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            );
          }
        }

        tableRows.add(pw.TableRow(children: rowCells));
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        // The rest distribute equally
        for (int i = 1; i <= classes.length; i++) i: const pw.FlexColumnWidth(),
      },
      children: tableRows,
    );
  }
}
