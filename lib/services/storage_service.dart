import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import 'auth_service.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String?> uploadReceiptImage(String localFilePath) async {
    try {
      final String? userId = AuthService.currentUserId;

      print('Storage upload started');
      print('Current userId: $userId');
      print('Local file path: $localFilePath');

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final File file = File(localFilePath);

      final bool exists = file.existsSync();
      print('File exists: $exists');

      if (!exists) {
        throw Exception('File does not exist');
      }

      final String fileName = path.basename(localFilePath);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final String storagePath = 'receipts/$userId/${timestamp}_$fileName';
      print('Storage path: $storagePath');

      final Reference ref = _storage.ref().child(storagePath);

      final UploadTask uploadTask = ref.putFile(file);

      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Upload success. Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      print('Storage upload error: $e');
      print('Storage upload stackTrace: $stackTrace');
      return null;
    }
  }

  static Future<void> deleteReceiptImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Failed to delete image: $e');
    }
  }
}