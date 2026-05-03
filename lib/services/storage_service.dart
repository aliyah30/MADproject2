import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Pick an image from the gallery
  Future<File?> pickImage({bool fromCamera = false}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  // Upload user avatar — returns CDN download URL
  Future<String> uploadAvatar(String uid, File imageFile) async {
    final ref = _storage.ref().child('avatars/$uid.jpg');
    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  // Upload activity image — returns CDN download URL
  Future<String> uploadActivityImage(
      String tripId, String activityId, File imageFile) async {
    final ref = _storage
        .ref()
        .child('trips/$tripId/activities/$activityId.jpg');
    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  // Upload trip cover image — returns CDN download URL
  Future<String> uploadTripCover(String tripId, File imageFile) async {
    final ref = _storage.ref().child('trips/$tripId/cover.jpg');
    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  // Delete a file by its storage path
  Future<void> deleteFile(String storagePath) async {
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (_) {
      // Silently ignore if file doesn't exist
    }
  }
}