import 'package:flutter/material.dart';

class BulletinAnnualGradesTable extends StatelessWidget {
  final List<Map<String, dynamic>> grades;

  const BulletinAnnualGradesTable({super.key, required this.grades});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(3), // Matière
        1: FlexColumnWidth(1), // Coeff
        2: FlexColumnWidth(1), // T1
        3: FlexColumnWidth(1), // T2
        4: FlexColumnWidth(1), // T3
        5: FlexColumnWidth(1.2), // Moy An
        6: FlexColumnWidth(1), // Rang
        7: FlexColumnWidth(2), // Appréciation
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: [
            _buildCell('Matières', isHeader: true),
            _buildCell('Coeff', isHeader: true),
            _buildCell('Moy T1', isHeader: true),
            _buildCell('Moy T2', isHeader: true),
            _buildCell('Moy T3', isHeader: true),
            _buildCell('Moy An', isHeader: true),
            _buildCell('Rang', isHeader: true),
            _buildCell('Appréciation', isHeader: true),
          ],
        ),
        ...grades.map((grade) {
          final noteT1 = grade['moy_t1'] as double?;
          final noteT2 = grade['moy_t2'] as double?;
          final noteT3 = grade['moy_t3'] as double?;
          final moyAn = grade['moy_annuelle'] as double?;

          return TableRow(
            children: [
              _buildCell(grade['matiere_nom'] ?? '', alignLeft: true),
              _buildCell('${grade['coefficient'] ?? 1}'),
              _buildCell(noteT1?.toStringAsFixed(2) ?? '-'),
              _buildCell(noteT2?.toStringAsFixed(2) ?? '-'),
              _buildCell(noteT3?.toStringAsFixed(2) ?? '-'),
              _buildCell(moyAn?.toStringAsFixed(2) ?? '-', isBold: true),
              _buildCell('${grade['rang']}e'),
              _buildCell(grade['appreciation'] ?? ''),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCell(
    String text, {
    bool isHeader = false,
    bool alignLeft = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: (isHeader || isBold)
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    );
  }
}
