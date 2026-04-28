import 'dart:io';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/ecole.dart';

class StudentCardDesign extends StatelessWidget {
  static const String modelClassic = 'classic';
  static const String modelModern = 'modern';
  static const String modelPremium = 'premium';

  final Student? student;
  final Ecole? ecole;
  final String? anneeLibelle;
  final double scale;
  final String designModel;

  const StudentCardDesign({
    super.key,
    required this.student,
    required this.ecole,
    required this.anneeLibelle,
    this.scale = 1.0,
    this.designModel = modelClassic,
  });

  String? _normalizeFilePath(String? rawPath) {
    if (rawPath == null) return null;
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('file://')) {
      return Uri.parse(trimmed).toFilePath();
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (student == null) {
      return _buildEmptyCard();
    }

    Widget cardContent;
    switch (designModel) {
      case modelModern:
        cardContent = _buildModernCard();
        break;
      case modelPremium:
        cardContent = _buildPremiumCard();
        break;
      case modelClassic:
      default:
        cardContent = _buildClassicCard();
        break;
    }

    return Transform.scale(
      scale: scale,
      child: cardContent,
    );
  }

  Widget _buildClassicCard() {
    return _buildCardContainer(
      backgroundColor: const Color(0xFFE8F4F8),
      borderColor: Colors.grey[300]!,
      leftStripe: const Color(0xFF002D62),
      bannerColor: const Color(0xFFCE1126),
      footerColor: const Color(0xFFCE1126),
    );
  }

  Widget _buildModernCard() {
    return _buildPortraitCard(
      topColor: const Color(0xFF0D47A1),
      accentColor: const Color(0xFF1565C0),
      backgroundColor: const Color(0xFFF5F9FF),
      borderColor: const Color(0xFF90CAF9),
      showGoldBadge: false,
    );
  }

  Widget _buildPremiumCard() {
    return _buildPortraitCard(
      topColor: const Color(0xFF5D4037),
      accentColor: const Color(0xFFB8860B),
      backgroundColor: const Color(0xFFFFF8E1),
      borderColor: const Color(0xFFE0C27A),
      showGoldBadge: true,
    );
  }

  Widget _buildPortraitCard({
    required Color topColor,
    required Color accentColor,
    required Color backgroundColor,
    required Color borderColor,
    required bool showGoldBadge,
  }) {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            height: 94,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            decoration: BoxDecoration(
              color: topColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildFlag(),
                    const Spacer(),
                    if (_normalizeFilePath(ecole?.logo) != null &&
                        File(_normalizeFilePath(ecole?.logo)!).existsSync())
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: ClipOval(
                          child: Image.file(
                            File(_normalizeFilePath(ecole?.logo)!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.school, size: 16),
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.school, color: Colors.white, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ecole?.nom.toUpperCase() ?? 'NOM DE L\'ÉCOLE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 8,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  ecole?.ville?.isNotEmpty == true
                      ? ecole!.ville!.toUpperCase()
                      : 'RÉPUBLIQUE DE GUINÉE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 6.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CARTE D\'IDENTITÉ SCOLAIRE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ANNÉE: ${anneeLibelle ?? '2023-2024'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 6.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 84,
                        decoration: BoxDecoration(
                          border: Border.all(color: accentColor, width: 2),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.grey[200],
                        ),
                        child: _normalizeFilePath(student!.photo) != null &&
                                File(_normalizeFilePath(student!.photo)!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.file(
                                  File(_normalizeFilePath(student!.photo)!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 42,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : const Icon(Icons.person, size: 42, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 98,
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            'Matricule:',
                            student!.matricule,
                            fontSize: 6,
                            bottomPadding: 0.3,
                          ),
                          _buildInfoRow(
                            'Nom:',
                            student!.nom.toUpperCase(),
                            fontSize: 6,
                            bottomPadding: 0.3,
                          ),
                          _buildInfoRow(
                            'Prénom:',
                            student!.prenom.toUpperCase(),
                            fontSize: 6,
                            bottomPadding: 0.3,
                          ),
                          _buildInfoRow(
                            'Naissance:',
                            student!.dateNaissance,
                            fontSize: 6,
                            bottomPadding: 0.3,
                          ),
                          _buildInfoRow(
                            'Lieu:',
                            student!.lieuNaissance,
                            fontSize: 6,
                            bottomPadding: 0.3,
                          ),
                          _buildInfoRow(
                            'Sexe:',
                            '${student!.sexe == 'M' ? 'Homme' : 'Femme'}',
                            fontSize: 6,
                            bottomPadding: 0.3,
                          ),
                          _buildInfoRow(
                            'Classe:',
                            student!.classe,
                            fontSize: 6,
                            bottomPadding: 0.1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    ecole?.slogan?.isNotEmpty == true
                        ? ecole!.slogan!.toUpperCase()
                        : 'DISCIPLINE - TRAVAIL - PROGRÈS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlag() {
    return Container(
      width: 30,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white70, width: 0.5),
      ),
      child: Row(
        children: const [
          Expanded(child: ColoredBox(color: Color(0xFFCE1126))),
          Expanded(child: ColoredBox(color: Color(0xFFFCD116))),
          Expanded(child: ColoredBox(color: Color(0xFF009460))),
        ],
      ),
    );
  }

  Widget _buildCardContainer({
    required Color backgroundColor,
    required Color borderColor,
    required Color leftStripe,
    required Color bannerColor,
    required Color footerColor,
    bool useGradient = false,
    Color titleColor = Colors.black,
  }) {
    return Container(
      width: 280,
      height: 200,
      decoration: BoxDecoration(
        gradient: useGradient
            ? LinearGradient(
                colors: [backgroundColor, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: useGradient ? null : backgroundColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              decoration: BoxDecoration(
                color: leftStripe,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 35,
              decoration: BoxDecoration(
                color: footerColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  Text(
                    ecole?.slogan?.isNotEmpty == true
                        ? ecole!.slogan!.toUpperCase()
                        : 'DISCIPLINE - TRAVAIL - PROGRÈS',
                    style: const TextStyle(
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
          if (_normalizeFilePath(ecole?.logo) != null &&
              File(_normalizeFilePath(ecole?.logo)!).existsSync())
            Positioned(
              top: 8,
              left: 14,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: leftStripe, width: 2),
                ),
                child: ClipOval(
                  child: Image.file(
                    File(_normalizeFilePath(ecole?.logo)!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.school,
                      size: 24,
                      color: leftStripe,
                    ),
                  ),
                ),
              ),
            ),
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
          Positioned(
            top: 10,
            left: 72,
            right: 65,
            child: Column(
              children: [
                Text(
                  'République de Guinée',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Travail-Justice-Solidarité',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: titleColor.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ministère de l\'enseignement \n pré-universitaire et de l\'alphabétisation',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Positioned(
            top: 60,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
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
          Positioned(
            top: 80,
            left: 83,
            child: Text(
              'ANNÉE SCOLAIRE ${anneeLibelle ?? '2023-2024'}',
              style: const TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 12,
            child: Container(
              width: 70,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: leftStripe, width: 2),
                color: Colors.grey[200],
              ),
              child: _normalizeFilePath(student!.photo) != null &&
                      File(_normalizeFilePath(student!.photo)!).existsSync()
                  ? Image.file(
                      File(_normalizeFilePath(student!.photo)!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 40, color: Colors.grey),
                    )
                  : const Icon(Icons.person, size: 40, color: Colors.grey),
            ),
          ),
          if (_normalizeFilePath(ecole?.timbre) != null &&
              File(_normalizeFilePath(ecole?.timbre)!).existsSync())
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
                      File(_normalizeFilePath(ecole?.timbre)!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 92,
            left: 88,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Matricule:', student!.matricule),
                _buildInfoRow('Nom et Prénom:', student!.fullName.toUpperCase()),
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
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    double fontSize = 7,
    double bottomPadding = 1.5,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        text: TextSpan(
          style: TextStyle(fontSize: fontSize, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                fontSize: fontSize,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: fontSize,
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
