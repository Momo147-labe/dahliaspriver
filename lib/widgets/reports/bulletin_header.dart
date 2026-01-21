import 'package:flutter/material.dart';
import '../../models/ecole.dart';
import 'dart:io';

class BulletinHeader extends StatelessWidget {
  final Ecole? ecole;
  final String? anneeLibelle;
  final String? trimestreLibelle;

  const BulletinHeader({
    super.key,
    this.ecole,
    this.anneeLibelle,
    this.trimestreLibelle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Piece: Republic Logo & Motto
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 40,
              margin: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(width: 10, color: const Color(0xFFCE1126)), // Red
                  const SizedBox(width: 2),
                  Container(
                    width: 10,
                    color: const Color(0xFFFCD116),
                  ), // Yellow
                  const SizedBox(width: 2),
                  Container(width: 10, color: const Color(0xFF009460)), // Green
                ],
              ),
            ),
            const Text(
              'RÉPUBLIQUE DE GUINÉE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'TRAVAIL - JUSTICE - SOLIDARITÉ',
              style: TextStyle(
                fontSize: 5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),

        // Center Piece: School Name & Info
        Expanded(
          child: Column(
            children: [
              if (ecole?.logo != null && File(ecole!.logo!).existsSync())
                Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Image.file(File(ecole!.logo!), fit: BoxFit.contain),
                ),
              Text(
                ecole?.nom.toUpperCase() ?? 'GROUPE SCOLAIRE',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ecole?.adresse ?? 'Conakry, République de Guinée',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (ecole?.telephone != null)
                Text(
                  'Tél: ${ecole!.telephone}',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (ecole?.email != null)
                Text(
                  ecole!.email!,
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),

        // Right Piece: Academic Year & Term
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'ANNÉE SCOLAIRE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              anneeLibelle ?? '2023 - 2024',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF13DAEC),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trimestreLibelle?.toUpperCase() ?? 'TRIMESTRE 1',
                style: const TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
