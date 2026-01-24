import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/backup.dart';
import '../../domain/repositories/backup_repository.dart';

class BackupRepositoryImpl implements BackupRepository {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  BackupRepositoryImpl(this.firestore, this.storage);

  @override
  Future<String> uploadBackup(String userId, List<int> data, String fileName) async {
    final ref = storage.ref().child('backups/$userId/$fileName');
    await ref.putData(Uint8List.fromList(data));
    return await ref.getDownloadURL();
  }

  @override
  Future<void> saveBackupMetadata(String userId, Backup backup) async {
    await firestore.collection('users').doc(userId).collection('backups').doc(backup.id).set({
      'url': backup.url,
      'timestamp': backup.timestamp.toIso8601String(),
      'fileName': backup.fileName,
    });
  }

  @override
  Future<List<Backup>> getBackupHistory(String userId) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('backups')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Backup(
        id: doc.id,
        url: data['url'],
        timestamp: DateTime.parse(data['timestamp']),
        fileName: data['fileName'],
      );
    }).toList();
  }
}
