import 'package:flutter/material.dart';

class BulletinGradesTable extends StatelessWidget {
  final List<Map<String, dynamic>> grades;

  const BulletinGradesTable({
    super.key,
    required this.grades,
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
            _buildTableCell('NOTES', isHeader: true, isCenter: true),
            _buildTableCell('TOTAL', isHeader: true, isCenter: true),
            _buildTableCell('OBSERVATIONS', isHeader: true),
          ],
        ),
        // Rows
        ...grades.map((grade) => TableRow(
          children: [
            _buildTableCell(grade['matiere'] as String, isBold: true),
            _buildTableCell(grade['coeff'].toString(), isCenter: true),
            _buildTableCell(grade['note'].toString(), isCenter: true),
            _buildTableCell(grade['total'].toString(), isCenter: true),
            _buildTableCell(grade['obs'] as String, isItalic: true),
          ],
        )),
        // Footer
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            _buildTableCell('TOTAUX', isBold: true),
            _buildTableCell('17', isCenter: true, isBold: true),
            _buildTableCell('', isCenter: true, isBold: true),
            _buildTableCell('236.5', isCenter: true, isBold: true),
            _buildTableCell('', isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, bool isItalic = false, bool isCenter = false}) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Text(
          text,
          textAlign: isCenter ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHeader || isBold ? FontWeight.w700 : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
