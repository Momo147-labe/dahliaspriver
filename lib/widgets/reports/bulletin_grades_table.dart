import 'package:flutter/material.dart';

class BulletinGradesTable extends StatelessWidget {
  final List<Map<String, dynamic>> grades;
  final double noteMax;
  final List<Map<String, dynamic>>
  columns; // e.g. [{'label': 'S1', 'key': 1}, ...]
  final List<Map<String, dynamic>> mentions;
  final String noteKey; // 'notes_par_sequence' or 'notes_par_trimestre'

  const BulletinGradesTable({
    super.key,
    required this.grades,
    required this.columns,
    this.noteMax = 20.0,
    this.noteKey = 'notes_par_sequence',
    this.mentions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableCell('MATIÈRES', isHeader: true),
            _buildTableCell('COEFF', isHeader: true, isCenter: true),
            ...columns.map(
              (col) => _buildTableCell(
                '${col['label']}',
                isHeader: true,
                isCenter: true,
              ),
            ),
            _buildTableCell('MOYENNE', isHeader: true, isCenter: true),
            _buildTableCell('OBSERVATIONS', isHeader: true),
          ],
        ),
        // Rows
        ...grades.map((grade) {
          final notesMap = (grade[noteKey] as Map<dynamic, dynamic>?) ?? {};
          final moy = grade['note'] as double?;

          return TableRow(
            children: [
              _buildTableCell(
                (grade['matiere']?.toString() ?? ''),
                isBold: true,
              ),
              _buildTableCell(
                grade['coeff']?.toString() ?? '1',
                isCenter: true,
              ),
              ...columns.map((col) {
                final key = col['key'];
                final val = (notesMap[key] as num?)?.toDouble();
                return _buildTableCell(
                  val?.toStringAsFixed(2) ?? '-',
                  isCenter: true,
                );
              }),
              _buildTableCell(
                moy?.toStringAsFixed(2) ?? '-',
                isCenter: true,
                isBold: true,
              ),
              Builder(
                builder: (context) {
                  // If mentions provided, we can re-calculate or use pre-calculated 'obs'
                  // For parity with PDF helper, we check mentions first
                  String observation = grade['obs']?.toString() ?? '';
                  // Note: We don't re-calculate here because reports_page does it.
                  // But we could if needed.
                  return _buildTableCell(observation, isItalic: true);
                },
              ),
            ],
          );
        }),
        // Footer (Totals)
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            _buildTableCell('TOTAUX', isBold: true),
            _buildTableCell(
              grades
                  .fold<double>(
                    0,
                    (p, e) => p + ((e['coeff'] as num?)?.toDouble() ?? 0.0),
                  )
                  .toStringAsFixed(0),
              isCenter: true,
              isBold: true,
            ),
            ...columns.map((_) => _buildTableCell('', isCenter: true)),
            _buildTableCell(
              grades
                  .fold<double>(
                    0,
                    (p, e) => p + ((e['total'] as num?)?.toDouble() ?? 0.0),
                  )
                  .toStringAsFixed(2),
              isCenter: true,
              isBold: true,
            ),
            _buildTableCell('', isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool isItalic = false,
    bool isCenter = false,
  }) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Text(
          text,
          textAlign: isCenter ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHeader || isBold
                ? FontWeight.w700
                : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
