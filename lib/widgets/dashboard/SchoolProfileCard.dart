import 'dart:io';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SchoolProfileCard extends StatelessWidget {
  final Map<String, dynamic>? school;
  final bool isDark;
  final bool isLoading;

  const SchoolProfileCard({
    super.key,
    required this.school,
    required this.isDark,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLogo(),
          const SizedBox(height: 12),

          Text(
            school?['nom'] ?? 'Nom de l\'école',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          _statusBadge(),
          const Divider(height: 28),

          _infoRow(Icons.location_on, school?['adresse']),
          _infoRow(Icons.phone, school?['telephone']),
          _infoRow(Icons.email, school?['email']),
          const SizedBox(height: 12),
          _infoRow(Icons.person, 'Directeur : ${school?['directeur'] ?? '-'}'),
          _infoRow(Icons.school, 'Fondateur : ${school?['fondateur'] ?? '-'}'),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: ouvrir page paramètres école
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Modifier le profil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    if (school?['logo'] != null && File(school!['logo']).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(school!['logo']),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.school, color: Colors.white, size: 36),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'École active',
        style: TextStyle(
          color: AppTheme.successColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
