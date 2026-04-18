import 'package:flutter/material.dart';

class BulletinGradesTable extends StatelessWidget {
  final List<Map<String, dynamic>> grades;

  const BulletinGradesTable({super.key, required this.grades});

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
            _buildTableCell('NOTE CTRL', isHeader: true, isCenter: true),
            _buildTableCell('NOTE COMP', isHeader: true, isCenter: true),
            _buildTableCell('MOYENNE', isHeader: true, isCenter: true),
            _buildTableCell('OBSERVATIONS', isHeader: true),
          ],
        ),
        // Rows
        ...grades.map((grade) {
          final ctrl = grade['note_ctrl'] as double?;
          final comp = grade['note_comp'] as double?;
          final moy = grade['note'] as double?;

          return TableRow(
            children: [
              _buildTableCell(grade['matiere'] as String, isBold: true),
              _buildTableCell(grade['coeff'].toString(), isCenter: true),
              _buildTableCell(ctrl?.toStringAsFixed(2) ?? '-', isCenter: true),
              _buildTableCell(comp?.toStringAsFixed(2) ?? '-', isCenter: true),
              _buildTableCell(
                moy?.toStringAsFixed(2) ?? '-',
                isCenter: true,
                isBold: true,
              ),
              _buildTableCell(grade['obs'] as String, isItalic: true),
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
                  .fold<double>(0, (p, e) => p + (e['coeff'] as double))
                  .toStringAsFixed(0),
              isCenter: true,
              isBold: true,
            ),
            _buildTableCell('', isCenter: true),
            _buildTableCell('', isCenter: true),
            _buildTableCell(
              grades
                  .fold<double>(0, (p, e) => p + (e['total'] as double))
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
