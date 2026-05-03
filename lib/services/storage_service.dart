import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  //Upload user avatar
  Future<String> uploadAvatar(String uid, File imageFile) async {
    final ref = _storage.ref().child('avatars/$uid/avatar.jpg');
 
    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
 
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Upload trip cover image
 Future<String> uploadTripCover(String tripId, File imageFile) async {
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('trips/$tripId/cover/$fileName');
 
    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
 
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  //Upload activity image
  Future<String> uploadActivityImage(
      String tripId, String activityId, File imageFile) async {
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage
        .ref()
        .child('trips/$tripId/activities/$activityId/$fileName');
 
    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
 
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }


  // Delete a file by its download URL 
    Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      // File may already be deleted — ignore
    }
  }

  // Delete all files for a trip 
    Future<void> deleteTripFolder(String tripId) async {
    try {
      final ref = _storage.ref().child('trips/$tripId');
      final listResult = await ref.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
      for (final prefix in listResult.prefixes) {
        final subList = await prefix.listAll();
        for (final item in subList.items) {
          await item.delete();
        }
      }
    } catch (e) {
      // Folder may not exist
    }
  }
}