import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../database/database_helper.dart';

class TemplateEngine {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Replace tags in the raw Delta JSON string with real data from the database.
  Future<quill.Document?> renderTemplate(
    String templateType,
    int anneeScolaireId, {
    int? eleveId,
  }) async {
    try {
      final template = await _db.getDocumentTemplate(
        anneeScolaireId,
        templateType,
      );
      if (template == null || template['content'] == null) {
        return null;
      }

      String contentStr = template['content'] as String;

      // Fetch School Info
      final ecoleInfo = await _db.getEcoleInfo();
      String nomEcole = ecoleInfo['nom'] ?? 'Guiner Schools';
      String logoEcole =
          '[LOGO]'; // Usually handling images requires injecting Image spans in Delta, for text we use a string.

      // Fetch Student Info if provided
      String nomEleve = '[Nom Élève]';
      String prenomEleve = '[Prénom Élève]';
      String classeStr = '[Classe]';
      String dateNaissance = '[Date Naissance]';
      String matricule = '[Matricule]';

      if (eleveId != null) {
        final eleve = await _db.getStudentById(eleveId);
        if (eleve != null) {
          nomEleve = eleve['nom'] ?? '';
          prenomEleve = eleve['prenom'] ?? '';
          dateNaissance = eleve['date_naissance'] ?? '';
          matricule = eleve['matricule'] ?? '';

          // Try to get class
          final parcours = await _db.getStudentParcours(eleveId);
          if (parcours.isNotEmpty) {
            final classeList = await _db.queryAll('classe');
            final cls = classeList
                .where((c) => c['id'] == parcours.first['classe_id'])
                .firstOrNull;
            if (cls != null) classeStr = cls['nom'] ?? '';
          }
        }
      }

      // Replace tags
      contentStr = contentStr.replaceAll('{{nom_ecole}}', nomEcole);
      contentStr = contentStr.replaceAll('{{logo_ecole}}', logoEcole);
      contentStr = contentStr.replaceAll('{{nom_eleve}}', nomEleve);
      contentStr = contentStr.replaceAll('{{prenom_eleve}}', prenomEleve);
      contentStr = contentStr.replaceAll('{{classe}}', classeStr);
      contentStr = contentStr.replaceAll('{{date_naissance}}', dateNaissance);
      contentStr = contentStr.replaceAll('{{matricule}}', matricule);
      contentStr = contentStr.replaceAll('{{cachet}}', "[Cachet de l'École]");

      return quill.Document.fromJson(jsonDecode(contentStr));
    } catch (e) {
      print('Error rendering template: \$e');
      return null;
    }
  }
}
