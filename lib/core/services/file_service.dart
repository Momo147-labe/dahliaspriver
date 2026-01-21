import 'dart:io';
import 'package:path/path.dart' as p;
import '../database/database_path.dart';

class FileService {
  static final FileService instance = FileService._internal();
  FileService._internal();

  static const String studentPhotosDir = 'student_photos';
  static const String schoolAssetsDir = 'school_assets';

  /// Returns the root private directory for the application's images.
  Future<Directory> get _privateImagesDir async {
    final basePath = await getAppStorageDirectory();
    final dir = Directory(p.join(basePath, 'app_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _createNoMediaFile(dir);
    }
    return dir;
  }

  /// Creates a .nomedia file to prevent gallery indexing on Android.
  Future<void> _createNoMediaFile(Directory dir) async {
    if (Platform.isAndroid) {
      final noMedia = File(p.join(dir.path, '.nomedia'));
      if (!await noMedia.exists()) {
        await noMedia.create();
      }
    }
  }

  /// Gets a specific category directory within the private images folder.
  Future<Directory> _getCategoryDir(String category) async {
    final root = await _privateImagesDir;
    final dir = Directory(p.join(root.path, category));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves an image file to private storage.
  /// Returns the absolute path of the saved file.
  Future<String> saveImage(File sourceFile, String category) async {
    final dir = await _getCategoryDir(category);
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourceFile.path).isEmpty ? '.jpg' : p.extension(sourceFile.path)}';
    final String targetPath = p.join(dir.path, fileName);

    final File savedFile = await sourceFile.copy(targetPath);
    return savedFile.path;
  }

  /// Deletes a file if it exists.
  Future<void> deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// migration helper: checks if a path is already in the private directory.
  Future<bool> isPrivate(String path) async {
    final root = await _privateImagesDir;
    return path.startsWith(root.path);
  }
}
