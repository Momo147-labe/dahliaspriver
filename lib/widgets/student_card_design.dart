import 'dart:io';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/ecole.dart';

class StudentCardDesign extends StatelessWidget {
  final Student? student;
  final Ecole? ecole;
  final String? anneeLibelle;
  final double scale;

  const StudentCardDesign({
    super.key,
    required this.student,
    required this.ecole,
    required this.anneeLibelle,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (student == null) {
      return _buildEmptyCard();
    }

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 320,
        height: 204,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F4F8),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Blue vertical stripe on the left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF002D62),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
            ),

            // Red footer
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 35,
                decoration: const BoxDecoration(
                  color: Color(0xFFCE1126),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ecole?.nom.toUpperCase() ?? 'NOM DE L\'ÉCOLE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'DISCIPLINE - TRAVAIL - PROGRÈS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Ministry logo (top left)
            if (ecole?.logo != null && ecole!.logo!.isNotEmpty)
              Positioned(
                top: 8,
                left: 14,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF002D62),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.file(
                      File(ecole!.logo!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school,
                        size: 24,
                        color: Color(0xFF002D62),
                      ),
                    ),
                  ),
                ),
              ),

            // Guinea flag (top right)
            Positioned(
              top: 8,
              right: 12,
              child: Container(
                width: 45,
                height: 35,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(child: Container(color: const Color(0xFFCE1126))),
                    Expanded(child: Container(color: const Color(0xFFFCD116))),
                    Expanded(child: Container(color: const Color(0xFF009460))),
                  ],
                ),
              ),
            ),

            // Header text
            Positioned(
              top: 10,
              left: 72,
              right: 65,
              child: Column(
                children: [
                  const Text(
                    'BURKINA FASO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Unité-Progrès-Justice',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ministère de l\'Éducation Nationale de l\'Alphabétisation et de la Promotion des Langues Nationales',
                    style: TextStyle(
                      fontSize: 5.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  Text(
                    'Région des Cascades - Province de la Leraba',
                    style: TextStyle(fontSize: 5, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // "CARTE D'IDENTITÉ SCOLAIRE" banner
            Positioned(
              top: 60,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFCE1126),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Text(
                  'CARTE D\'IDENTITÉ SCOLAIRE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Academic year badge
            Positioned(
              top: 72,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCD116),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'ANNÉE SCOLAIRE ${anneeLibelle ?? '2023-2024'}',
                  style: const TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // Student photo
            Positioned(
              top: 92,
              left: 12,
              child: Container(
                width: 70,
                height: 85,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF002D62), width: 2),
                  color: Colors.grey[200],
                ),
                child: student!.photo.isNotEmpty
                    ? Image.file(
                        File(student!.photo),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(Icons.person, size: 40, color: Colors.grey),
              ),
            ),

            // School stamp overlay on photo (optional)
            if (ecole?.timbre != null && ecole!.timbre!.isNotEmpty)
              Positioned(
                top: 130,
                left: 30,
                child: Opacity(
                  opacity: 0.7,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: Image.file(
                        File(ecole!.timbre!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(),
                      ),
                    ),
                  ),
                ),
              ),

            // Student information
            Positioned(
              top: 92,
              left: 88,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Matricule:', student!.matricule),
                  _buildInfoRow(
                    'Nom et Prénom:',
                    student!.fullName.toUpperCase(),
                  ),
                  _buildInfoRow('Date de Naissance :', student!.dateNaissance),
                  _buildInfoRow('Lieu de Naissance:', student!.lieuNaissance),
                  _buildInfoRow(
                    'Sexe:',
                    student!.sexe == 'M' ? 'Homme' : 'Femme',
                  ),
                  _buildInfoRow('Classe:', student!.classe),
                  if (student!.contactUrgence != null &&
                      student!.contactUrgence!.isNotEmpty)
                    _buildInfoRow(
                      'Personne à prévenir:',
                      '${student!.personneAPrevenir ?? ''} ${student!.contactUrgence ?? ''}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.5),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 7, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: 320,
      height: 204,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'Aucun élève sélectionné',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
