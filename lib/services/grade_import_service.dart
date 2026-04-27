import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../core/database/database_helper.dart';

class GradeImportService {
  static final GradeImportService instance = GradeImportService._internal();
  GradeImportService._internal();

  /// Parses a CSV file and return a list of students with their potential notes.
  /// Format expected: Matricule, Note
  Future<List<Map<String, dynamic>>> parseGradeCSV(File file) async {
    final input = file.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(fieldDelimiter: ';'))
        .toList();

    if (fields.isEmpty) return [];

    // Skip header if necessary (Basic check: if first row contains non-numerical grade)
    int startRow = 0;
    if (fields[0][0].toString().toLowerCase().contains('matricule') ||
        fields[0][1].toString().toLowerCase().contains('note')) {
      startRow = 1;
    }

    List<Map<String, dynamic>> results = [];
    for (var i = startRow; i < fields.length; i++) {
      if (fields[i].length < 2) continue;

      final matricule = fields[i][0].toString().trim();
      final String noteStr = fields[i][1].toString().trim().replaceAll(
        ',',
        '.',
      );
      final double? note = double.tryParse(noteStr);

      if (matricule.isNotEmpty) {
        results.add({
          'matricule': matricule,
          'note': note,
          'raw_row': fields[i],
        });
      }
    }

    return results;
  }

  /// Parses an Excel file and returns a map with students' notes and sequence names.
  /// Validates that the file's class AND subject match those selected in the UI.
  Future<Map<String, dynamic>> parseGradeExcel(
    File file, {
    required int trimester,
    required int sequence,
    required int anneeId,
    required String expectedClassName,
    String? expectedSubjectName,
  }) async {
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    // Try multiple sheet name variants for "Trimestre X"
    String? sheetName;
    final List<String> possibleNames = [
      "Trimestre $trimester",
      "${trimester}er Trimestre",
      "${trimester}ème Trimestre",
      "Trimestre $trimester ", // Some excels have trailing spaces
    ];

    for (var name in possibleNames) {
      if (excel.sheets.containsKey(name)) {
        sheetName = name;
        break;
      }
    }

    // Last resort: find any sheet containing the trimester number
    if (sheetName == null) {
      for (var name in excel.sheets.keys) {
        if (name.contains(trimester.toString()) &&
            name.toLowerCase().contains("trim")) {
          sheetName = name;
          break;
        }
      }
    }

    if (sheetName == null || !excel.sheets.containsKey(sheetName)) {
      return {
        'students': <Map<String, dynamic>>[],
        'sequenceNames': <int, String>{},
      };
    }

    final sheet = excel.sheets[sheetName]!;
    if (sheet.maxRows < 2)
      return {
        'students': <Map<String, dynamic>>[],
        'sequenceNames': <int, String>{},
      };

    // Verify metadata — Row 5 (index 5) contains:
    //   col 0: "Classe :"  col 1: className   col 3: "Matière :"  col 4: subjectName
    if (sheet.maxRows > 5) {
      final metaRow = sheet.rows[5];
      // Validate class name (col 1)
      final fileClassName = metaRow.length > 1
          ? (metaRow[1]?.value?.toString().trim() ?? '')
          : '';
      if (fileClassName.isNotEmpty &&
          !fileClassName.toLowerCase().contains(
            expectedClassName.toLowerCase(),
          ) &&
          !expectedClassName.toLowerCase().contains(
            fileClassName.toLowerCase(),
          )) {
        throw Exception(
          'Fichier incorrect : Ce fichier est pour la classe "$fileClassName" '
          'mais vous avez sélectionné "$expectedClassName".',
        );
      }
      // Validate subject name (col 4) when provided
      if (expectedSubjectName != null && expectedSubjectName.isNotEmpty) {
        final fileSubjectName = metaRow.length > 4
            ? (metaRow[4]?.value?.toString().trim() ?? '')
            : '';
        if (fileSubjectName.isNotEmpty &&
            !fileSubjectName.toLowerCase().contains(
              expectedSubjectName.toLowerCase(),
            ) &&
            !expectedSubjectName.toLowerCase().contains(
              fileSubjectName.toLowerCase(),
            )) {
          throw Exception(
            'Fichier incorrect : Ce fichier contient des notes de "$fileSubjectName" '
            'mais vous avez sélectionné "$expectedSubjectName".',
          );
        }
      }
    }

    // Find the actual header row (ignoring metadata rows at the top)
    int headerRowIndex = -1;
    for (int i = 0; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isNotEmpty && row[0] != null) {
        final firstCell = row[0]?.value?.toString().toLowerCase() ?? '';
        if (firstCell.contains('matricule')) {
          headerRowIndex = i;
          break;
        }
      }
    }

    if (headerRowIndex == -1)
      return {
        'students': <Map<String, dynamic>>[],
        'sequenceNames': <int, String>{},
      };

    // Fetch the sequences for this trimester from database to build column mappings
    Map<int, int> sequenceCols = {}; // sequenceNumber -> colIndex
    Map<int, String> sequenceNamesMap = {}; // sequenceNumber -> rawName
    try {
      final dbHelper = DatabaseHelper.instance;
      // CRITICAL FIX: Filter by annee_scolaire_id
      final seqData = await dbHelper.rawQuery(
        'SELECT numero_sequence, nom FROM sequence_planification WHERE trimestre = ? AND annee_scolaire_id = ?',
        [trimester, anneeId],
      );

      final headerRow = sheet.rows[headerRowIndex];

      for (var seq in seqData) {
        String sequenceName = seq['nom']?.toString().toLowerCase().trim() ?? '';
        int sequenceNum = seq['numero_sequence'] as int;
        sequenceNamesMap[sequenceNum] =
            seq['nom']?.toString() ?? 'S$sequenceNum';

        for (int i = 0; i < headerRow.length; i++) {
          final cellValue =
              headerRow[i]?.value?.toString().toLowerCase().trim() ?? "";
          if (cellValue == sequenceName ||
              cellValue.contains("sequence $sequenceNum") ||
              cellValue.contains("séquence $sequenceNum")) {
            sequenceCols[sequenceNum] = i;
            break;
          }
        }
      }
    } catch (_) {}

    // Fallback if no sequences matched: Try matching "Note" column or index 2 for the default single sequence
    if (sequenceCols.isEmpty) {
      final headerRow = sheet.rows[headerRowIndex];
      int fallbackCol = -1;
      for (int i = 0; i < headerRow.length; i++) {
        if (headerRow[i]?.value?.toString().toLowerCase().contains('note') ??
            false) {
          fallbackCol = i;
          break;
        }
      }
      if (fallbackCol == -1 && headerRow.length >= 3) fallbackCol = 2;
      if (fallbackCol != -1) {
        sequenceCols[sequence] = fallbackCol; // Map to the UI-selected sequence
        sequenceNamesMap[sequence] = 'Note';
      }
    }

    if (sequenceCols.isEmpty)
      return {
        'students': <Map<String, dynamic>>[],
        'sequenceNames': <int, String>{},
      };

    List<Map<String, dynamic>> results = [];
    for (int i = headerRowIndex + 1; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      final matricule = row[0]?.value?.toString().trim() ?? "";
      if (matricule.isEmpty) continue;

      // Extract Nom Complet
      final nomComp = row.length > 1
          ? row[1]?.value?.toString().trim() ?? ""
          : "";

      Map<int, double> extractedNotes = {};

      sequenceCols.forEach((seqNum, colIdx) {
        final noteValue = row.length > colIdx ? row[colIdx]?.value : null;
        if (noteValue != null) {
          final String noteStr = noteValue.toString().trim().replaceAll(
            ',',
            '.',
          );
          double? note = double.tryParse(noteStr);
          if (note != null) {
            extractedNotes[seqNum] = note;
          }
        }
      });

      // Still provide 'note' for backward compatibility or when a single note is found
      double? singleNote = extractedNotes.isNotEmpty
          ? extractedNotes.values.first
          : null;

      results.add({
        'matricule': matricule,
        'nom': nomComp,
        'note': singleNote,
        'notes':
            extractedNotes, // Map of sequence numbers to their respective extracted notes
      });
    }

    return {'students': results, 'sequenceNames': sequenceNamesMap};
  }

  /// Counts how many notes already exist for the given subject/trimester/year.
  /// Used to warn the user before overwriting data.
  Future<int> countExistingGrades({
    required List<Map<String, dynamic>> parsedData,
    required int subjectId,
    required int trimester,
    required int anneeId,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    int count = 0;

    for (var item in parsedData) {
      final matricule = item['matricule'] as String;
      final students = await dbHelper.rawQuery(
        '''SELECT e.id FROM eleve e
           JOIN eleve_parcours ep ON e.id = ep.eleve_id
           WHERE e.matricule = ? AND ep.annee_scolaire_id = ?''',
        [matricule, anneeId],
      );
      if (students.isEmpty) continue;
      final eleveId = students.first['id'] as int;

      final existing = await dbHelper.rawQuery(
        '''SELECT COUNT(*) as cnt FROM notes
           WHERE eleve_id = ? AND matiere_id = ? AND trimestre = ? AND annee_scolaire_id = ?''',
        [eleveId, subjectId, trimester, anneeId],
      );
      count += (existing.first['cnt'] as int? ?? 0);
    }
    return count;
  }

  /// Processes the parsed grades and saves them to the database.
  Future<Map<String, int>> importGrades({
    required List<Map<String, dynamic>> parsedData,
    required int subjectId,
    required int trimester,
    required int sequence,
    required int anneeId,
  }) async {
    int successCount = 0;
    int failureCount = 0;

    final dbHelper = DatabaseHelper.instance;

    for (var item in parsedData) {
      final matricule = item['matricule'] as String;

      final Map<int, double>? multiNotes = item['notes'] as Map<int, double>?;
      final double? singleNote = item['note'] as double?;

      if ((multiNotes == null || multiNotes.isEmpty) && singleNote == null) {
        failureCount++;
        continue;
      }

      try {
        // Find student by matricule and ensure they are in this class/year
        final students = await dbHelper.rawQuery(
          '''
          SELECT e.id 
          FROM eleve e
          JOIN eleve_parcours ep ON e.id = ep.eleve_id
          WHERE e.matricule = ? AND ep.annee_scolaire_id = ?
        ''',
          [matricule, anneeId],
        );

        if (students.isEmpty) {
          failureCount++;
          continue;
        }

        final eleveId = students.first['id'] as int;

        if (multiNotes != null && multiNotes.isNotEmpty) {
          for (var seqEntry in multiNotes.entries) {
            await dbHelper.saveGrade({
              'eleve_id': eleveId,
              'matiere_id': subjectId,
              'trimestre': trimester,
              'sequence': seqEntry.key,
              'note': seqEntry.value,
              'annee_scolaire_id': anneeId,
            });
          }
        } else {
          // Save single grade (This will trigger ranking in NotesDao)
          await dbHelper.saveGrade({
            'eleve_id': eleveId,
            'matiere_id': subjectId,
            'trimestre': trimester,
            'sequence': sequence,
            'note': singleNote,
            'annee_scolaire_id': anneeId,
          });
        }

        successCount++;
      } catch (e) {
        failureCount++;
      }
    }

    return {'success': successCount, 'failure': failureCount};
  }
}
