import 'package:flutter/material.dart';

class BulletinFooter extends StatelessWidget {
  final String observations;

  const BulletinFooter({
    super.key,
    required this.observations,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OBSERVATIONS DU PROFESSEUR PRINCIPAL :',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"$observations"',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Flexible(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade400, width: 2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: 0.2,
                    child: Text(
                      'DIRECTION GÉNÉRALE\nGUINÉE ÉCOLE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LE DIRECTEUR DES ÉTUDES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                height: 1,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
