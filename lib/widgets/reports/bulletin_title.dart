import 'package:flutter/material.dart';

class BulletinTitle extends StatelessWidget {
  final String trimestre;
  final String annee;

  const BulletinTitle({
    super.key,
    required this.trimestre,
    required this.annee,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bulletin de Notes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.double,
              decorationThickness: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$trimestre - ANNÉE $annee',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
