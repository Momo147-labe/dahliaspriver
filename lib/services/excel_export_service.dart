import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExcelExportService {
  static final ExcelExportService instance = ExcelExportService._internal();
  ExcelExportService._internal();

  /// Generates an Excel template for grades with students and sequence/trimester structure.
  Future<String?> generateGradeTemplate({
    required String className,
    required String subjectName,
    required List<Map<String, dynamic>> students,
    required List<int> trimesters,
    required Map<int, List<Map<String, dynamic>>> trimesterSequences,
    required Map<String, dynamic> schoolInfo,
    required String teacherName,
    required String academicYear,
  }) async {
    try {
      final excel = Excel.createExcel();

      // Define Styles
      CellStyle headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString("#4F46E5"), // App Primary
        fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      CellStyle schoolNameStyle = CellStyle(
        bold: true,
        fontSize: 18,
        fontColorHex: ExcelColor.fromHexString("#4F46E5"),
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle infoStyle = CellStyle(
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString("#4B5563"),
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle labelStyle = CellStyle(bold: true, fontSize: 12);

      // Flag to track if any sheet was added
      bool anySheetAdded = false;

      for (int tri in trimesters) {
        String sheetName = "Trimestre $tri";
        var sheet = excel[sheetName];
        anySheetAdded = true;

        List<Map<String, dynamic>> sequences = trimesterSequences[tri] ?? [];

        // Row 0: School Name
        sheet.appendRow([TextCellValue(schoolInfo['nom'] ?? "DAHLIAS PRIVER")]);
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0),
        );
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
                .cellStyle =
            schoolNameStyle;

        // Row 1: Slogan
        sheet.appendRow([
          TextCellValue(
            schoolInfo['slogan'] ?? "L'excellence au service de l'éducation",
          ),
        ]);
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1),
        );
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
                .cellStyle =
            infoStyle;

        // Row 2: Empty
        sheet.appendRow([TextCellValue("")]);

        // Row 3: Title
        sheet.appendRow([TextCellValue("FICHE DE NOTES - TRIMESTRE $tri")]);
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3),
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
            .cellStyle = CellStyle(
          bold: true,
          fontSize: 16,
          horizontalAlign: HorizontalAlign.Center,
        );

        // Row 4: Empty
        sheet.appendRow([TextCellValue("")]);

        // Row 5: Metadata (Classe / Matiere)
        sheet.appendRow([
          TextCellValue("Classe :"),
          TextCellValue(className),
          TextCellValue(""),
          TextCellValue("Matière :"),
          TextCellValue(subjectName),
        ]);
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5))
                .cellStyle =
            labelStyle;
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 5))
                .cellStyle =
            labelStyle;

        // Row 6: Metadata (Enseignant / Annee)
        sheet.appendRow([
          TextCellValue("Enseignant :"),
          TextCellValue(teacherName),
          TextCellValue(""),
          TextCellValue("Année Scolaire :"),
          TextCellValue(academicYear),
        ]);
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6))
                .cellStyle =
            labelStyle;
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 6))
                .cellStyle =
            labelStyle;

        // Row 7: Empty space before table
        sheet.appendRow([TextCellValue("")]);

        // Row 8: Table Header
        List<CellValue> headerCells = [
          TextCellValue("Matricule"),
          TextCellValue("Nom Complet"),
        ];

        for (var seq in sequences) {
          headerCells.add(TextCellValue(seq['nom'] ?? "Sequence"));
        }
        sheet.appendRow(headerCells);

        // Style Header and set width
        sheet.setColumnWidth(0, 20.0);
        sheet.setColumnWidth(1, 45.0);
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 8))
                .cellStyle =
            headerStyle;
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 8))
                .cellStyle =
            headerStyle;
        for (int i = 0; i < sequences.length; i++) {
          int colIdx = 2 + i;
          sheet.setColumnWidth(colIdx, 15.0);
          sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: colIdx,
                      rowIndex: 8,
                    ),
                  )
                  .cellStyle =
              headerStyle;
        }

        // Row 9+: Data
        for (var s in students) {
          List<CellValue> rowData = [
            TextCellValue(s['matricule'] ?? ""),
            TextCellValue("${s['prenom'] ?? ""} ${s['nom'] ?? ""}"),
          ];
          for (int j = 0; j < sequences.length; j++) {
            rowData.add(TextCellValue(""));
          }
          sheet.appendRow(rowData);
        }
      }

      // Remove default sheet only if we added another one
      if (anySheetAdded && excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final directory = await getApplicationDocumentsDirectory();
      // Use timestamp to ensure a fresh file is created every time
      String ts = DateTime.now().millisecondsSinceEpoch.toString();
      final String trimesterSuffix = trimesters.length == 1
          ? "_Trim_${trimesters.first}"
          : "";
      final fileName =
          "Fiche_Notes_${className}_${subjectName}${trimesterSuffix}.xlsx"
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = "${directory.path}/$fileName";

      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return path;
      }
      return null;
    } catch (e) {
      debugPrint("Excel Export Error: $e");
      return null;
    }
  }

  /// Generates an Excel export for student payments/transactions
  Future<String?> generatePaymentsExport({
    required List<Map<String, dynamic>> transactions,
    required Map<String, dynamic> schoolInfo,
    required String academicYear,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Paiements'];

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Define Styles
      CellStyle headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString("#4F46E5"),
        fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      CellStyle schoolNameStyle = CellStyle(
        bold: true,
        fontSize: 18,
        fontColorHex: ExcelColor.fromHexString("#4F46E5"),
        horizontalAlign: HorizontalAlign.Center,
      );

      // Row 0: School Name
      sheet.appendRow([TextCellValue(schoolInfo['nom'] ?? "DAHLIAS PRIVER")]);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0),
      );
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
              .cellStyle =
          schoolNameStyle;

      // Row 1: Slogan
      sheet.appendRow([TextCellValue(schoolInfo['slogan'] ?? "")]);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1),
      );

      // Row 2: Empty
      sheet.appendRow([TextCellValue("")]);

      // Row 3: Title
      sheet.appendRow([TextCellValue("HISTORIQUE DES PAIEMENTS")]);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
          .cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Row 4: Academic Year
      sheet.appendRow([
        TextCellValue("Année Scolaire :"),
        TextCellValue(academicYear),
      ]);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
          .cellStyle = CellStyle(
        bold: true,
      );

      // Row 5: Empty
      sheet.appendRow([TextCellValue("")]);

      // Row 6: Table Header
      List<CellValue> headerCells = [
        TextCellValue("Date"),
        TextCellValue("Matricule"),
        TextCellValue("Nom & Prénom"),
        TextCellValue("Classe"),
        TextCellValue("Montant"),
        TextCellValue("Mode"),
      ];
      sheet.appendRow(headerCells);

      for (int i = 0; i < headerCells.length; i++) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6))
                .cellStyle =
            headerStyle;
      }

      sheet.setColumnWidth(0, 15.0);
      sheet.setColumnWidth(1, 20.0);
      sheet.setColumnWidth(2, 35.0);
      sheet.setColumnWidth(3, 15.0);
      sheet.setColumnWidth(4, 15.0);
      sheet.setColumnWidth(5, 15.0);

      // Row 7+: Data
      double totalMontant = 0;
      for (var t in transactions) {
        String date = t['date_paiement'] ?? '';
        if (date.length > 10)
          date = date.substring(0, 10); // extract yyyy-mm-dd

        double montant = (t['montant'] ?? 0).toDouble();
        totalMontant += montant;

        sheet.appendRow([
          TextCellValue(date),
          TextCellValue(t['eleve_matricule'] ?? t['matricule'] ?? ""),
          TextCellValue("${t['eleve_nom'] ?? ''} ${t['eleve_prenom'] ?? ''}"),
          TextCellValue(t['classe_nom'] ?? ""),
          DoubleCellValue(montant),
          TextCellValue(t['mode_paiement'] ?? ""),
        ]);
      }

      // Add Total Row
      sheet.appendRow([
        TextCellValue("TOTAL"),
        TextCellValue(""),
        TextCellValue(""),
        TextCellValue(""),
        DoubleCellValue(totalMontant),
        TextCellValue(""),
      ]);
      int totalRowIdx = 7 + transactions.length;
      CellStyle totalStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#E5E7EB"),
      );
      for (int i = 0; i < headerCells.length; i++) {
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: i,
                    rowIndex: totalRowIdx,
                  ),
                )
                .cellStyle =
            totalStyle;
      }

      final directory = await getApplicationDocumentsDirectory();
      String ts = DateTime.now().millisecondsSinceEpoch.toString();
      final path = "${directory.path}/Historique_Paiements_$ts.xlsx";

      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return path;
      }
      return null;
    } catch (e) {
      debugPrint("Excel Export Error: $e");
      return null;
    }
  }
}
