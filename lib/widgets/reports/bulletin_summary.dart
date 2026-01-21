import 'package:flutter/material.dart';

class BulletinSummary extends StatelessWidget {
  final String moyenne;
  final String rang;
  final String moyenneGenerale;

  const BulletinSummary({
    super.key,
    required this.moyenne,
    required this.rang,
    required this.moyenneGenerale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MOYENNE:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(moyenne, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        Container(width: 1, color: Colors.black),
        Flexible(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('RANG:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(rang, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        Container(width: 1, color: Colors.black),
        Flexible(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('M. GÉNÉRALE:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(moyenneGenerale, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
