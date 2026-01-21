import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/ecole.dart';

class StudentIdCard extends StatelessWidget {
  final Student? student;
  final Ecole? ecole;
  final String? anneeLibelle;
  final double scale; // To scale the card if needed

  const StudentIdCard({
    super.key,
    required this.student,
    required this.ecole,
    this.anneeLibelle,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Base width 700, aspect ratio 1.6
    final double width = 700 * scale;
    final double height = (700 / 1.6) * scale;

    // Scale fonts and spacing based on scale
    // A simpler approach is to use a Transform.scale wrapper if just visual
    // But keeping it rigorous with dimensions inside the container

    return Container(
      width: width,
      height: height,
      constraints: BoxConstraints(maxWidth: width, maxHeight: height),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: Container(
          width: 700,
          height: 700 / 1.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Background Blur Circle
                Positioned(
                  top: -80,
                  right: -80,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(),
                    ),
                  ),
                ),

                // Header
                Positioned(
                  top: 16,
                  left: 24,
                  right: 24,
                  child: Row(
                    children: [
                      // School Logo
                      Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child:
                            ecole?.logo != null &&
                                File(ecole!.logo!).existsSync()
                            ? ClipOval(
                                child: Image.file(
                                  File(ecole!.logo!),
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Icon(Icons.school, color: Colors.grey),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              "REPUBLIQUE DE GUINEE",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "Travail - Justice - Solidarité",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Ministère de l'Education Nationale et de l'Alphabétisation\nRégion de Conakry - Commune de Kaloum",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Armoiries
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/images/logo_ecole.png',
                            errorBuilder: (c, o, s) =>
                                const Icon(Icons.shield), // Placeholder
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Title Badge
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFe11d48),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          "CARTE D'IDENTITÉ SCOLAIRE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFfff7d1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFeab308)),
                        ),
                        child: Text(
                          "ANNÉE SCOLAIRE ${anneeLibelle ?? '2023-2024'}",
                          style: const TextStyle(
                            color: Color(0xFF854d0e),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Body
                Positioned(
                  top: 170,
                  left: 32,
                  right: 32,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Section
                      Column(
                        children: [
                          Container(
                            width: 130,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border.all(
                                color: Colors.grey[800]!,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (student != null &&
                                    student!.photo.isNotEmpty &&
                                    File(student!.photo).existsSync())
                                  Image.file(
                                    File(student!.photo),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  )
                                else
                                  const Center(
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),

                                // Stamp Overlay
                                Positioned(
                                  bottom: -20,
                                  right: -20,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: Transform.rotate(
                                      angle: -0.26, // -15 deg
                                      child: _buildStamp(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "M. DIALLO",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      // Info Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              "Matricule:",
                              student?.matricule ?? "",
                            ),
                            _buildInfoRow(
                              "Nom et Prénom:",
                              student?.fullName.toUpperCase() ?? "",
                              isBoldValue: true,
                            ),
                            _buildInfoRow(
                              "Date de Nais.:",
                              student?.dateNaissance ?? "",
                            ),
                            _buildInfoRow(
                              "Lieu de Nais.:",
                              student?.lieuNaissance ?? "",
                            ),
                            _buildInfoRow("Sexe:", student?.sexe ?? ""),
                            _buildInfoRow("Classe:", student?.classe ?? ""),
                            const Divider(),
                            _buildInfoRow(
                              "Prév. d'urgence:",
                              "622 15 33 29", // Hardcoded per user request/HTML default
                              valueColor: const Color(0xFFe11d48),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Wave & Footer
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 80,
                    child: Stack(
                      children: [
                        // SVG Wave
                        Positioned.fill(
                          child: CustomPaint(
                            painter: WavePainter(
                              color: const Color(0xFFe11d48),
                            ),
                          ),
                        ),
                        // Text on Wave
                        Positioned(
                          bottom: 12,
                          left: 32,
                          right: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "GUINÉE ÉCOLE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                "TRAVAIL - JUSTICE - SOLIDARITÉ",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBoldValue = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBoldValue ? FontWeight.w900 : FontWeight.w900,
                color: valueColor ?? Colors.grey[900],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStamp() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue[700]!, width: 2),
      ),
      child: Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue[700]!,
              style: BorderStyle.none,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                "VISA",
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    var path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.4);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.3,
      size.width,
      size.height * 0.45,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
