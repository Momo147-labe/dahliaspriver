import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../services/file_service.dart';

/// Sélectionne une image et remplace l'ancienne photo de l'élève
Future<String?> pickAndSaveStudentPhoto(Database db, int eleveId) async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // compression légère
    );

    if (pickedFile == null) return null;

    // 📌 1. Sauvegarder l'image localement via FileService
    final savedPath = await FileService.instance.saveImage(
      File(pickedFile.path),
      FileService.studentPhotosDir,
    );

    // 📌 2. Mettre à jour SQLite
    await db.update(
      'eleves',
      {'photo': savedPath},
      where: 'id = ?',
      whereArgs: [eleveId],
    );

    return savedPath;
  } catch (e) {
    print('❌ Erreur photo élève : $e');
    return null;
  }
}

/// Sélectionne et sauvegarde le logo de l'école
Future<String?> pickAndSaveSchoolLogo(Database db, int schoolId) async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile == null) return null;

    // 📌 1. Sauvegarder l'image localement via FileService
    final savedPath = await FileService.instance.saveImage(
      File(pickedFile.path),
      FileService.schoolAssetsDir,
    );

    // 📌 2. Mettre à jour SQLite (seulement si schoolId > 0)
    if (schoolId > 0) {
      await db.update(
        'ecole',
        {'logo': savedPath},
        where: 'id = ?',
        whereArgs: [schoolId],
      );
    }

    return savedPath;
  } catch (e) {
    print('❌ Erreur logo école : $e');
    return null;
  }
}

/// Sélectionne et sauvegarde le timbre de l'école
Future<String?> pickAndSaveSchoolStamp(Database db, int schoolId) async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile == null) return null;

    // 📌 1. Sauvegarder l'image localement via FileService
    final savedPath = await FileService.instance.saveImage(
      File(pickedFile.path),
      FileService.schoolAssetsDir,
    );

    // 📌 2. Mettre à jour SQLite (seulement si schoolId > 0)
    if (schoolId > 0) {
      await db.update(
        'ecole',
        {'timbre': savedPath},
        where: 'id = ?',
        whereArgs: [schoolId],
      );
    }

    return savedPath;
  } catch (e) {
    print('❌ Erreur timbre école : $e');
    return null;
  }
}

/// Crée une nouvelle école avec logo et timbre
Future<int?> createSchoolWithImages(
  Database db,
  Map<String, dynamic> schoolData,
  String? logoPath,
  String? stampPath,
) async {
  try {
    // 📌 1. Préparer les données avec les chemins des images
    final data = Map<String, dynamic>.from(schoolData);
    if (logoPath != null) data['logo'] = logoPath;
    if (stampPath != null) data['timbre'] = stampPath;

    // 📌 2. Insérer dans la base de données
    final id = await db.insert('ecole', data);

    print('✅ École créée avec ID: $id');
    return id;
  } catch (e) {
    print('❌ Erreur création école : $e');
    return null;
  }
}
