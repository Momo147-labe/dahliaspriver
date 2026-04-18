import 'package:flutter/material.dart';

class BulletinSummary extends StatelessWidget {
  final String moyenne;
  final String rang;
  final String moyenneGenerale;
  final double moyennePassage;

  const BulletinSummary({
    super.key,
    required this.moyenne,
    required this.rang,
    required this.moyenneGenerale,
    required this.moyennePassage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MOYENNE:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  moyenne,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: Colors.black),
        Flexible(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RANG:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  rang,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: Colors.black),
        Flexible(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'M. GÉNÉRALE:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  moyenneGenerale,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Decision Block
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (double.tryParse(moyenne) ?? 0) >= moyennePassage
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              border: Border.all(
                color: (double.tryParse(moyenne) ?? 0) >= moyennePassage
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DÉCISION:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: (double.tryParse(moyenne) ?? 0) >= moyennePassage
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
                Text(
                  (double.tryParse(moyenne) ?? 0) >= moyennePassage
                      ? 'ADMIS'
                      : 'REDOUBLE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: (double.tryParse(moyenne) ?? 0) >= moyennePassage
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
