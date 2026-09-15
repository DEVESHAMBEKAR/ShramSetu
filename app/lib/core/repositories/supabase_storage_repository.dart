import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'i_storage_repository.dart';

class SupabaseStorageRepository implements IStorageRepository {
  final SupabaseClient _client;

  SupabaseStorageRepository(this._client);

  String _getBucketName(StorageBucket bucket) {
    switch (bucket) {
      case StorageBucket.profileImages:
        return 'profile-images';
      case StorageBucket.workerDocuments:
        return 'worker-documents';
    }
  }

  @override
  Future<String> uploadFile({
    required StorageBucket bucket,
    required String path,
    required File file,
  }) async {
    final bucketName = _getBucketName(bucket);
    
    // Upload the file
    final extension = file.path.split('.').last;
    final finalPath = '$path.\$extension';
    
    await _client.storage.from(bucketName).upload(
      finalPath,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    if (bucket == StorageBucket.profileImages) {
      return _client.storage.from(bucketName).getPublicUrl(finalPath);
    } else {
      return finalPath; // Return the path for private buckets to generate signed URLs later
    }
  }

  @override
  Future<void> deleteFile({
    required StorageBucket bucket,
    required String path,
  }) async {
    final bucketName = _getBucketName(bucket);
    await _client.storage.from(bucketName).remove([path]);
  }

  @override
  Future<String> getSignedUrl({
    required StorageBucket bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    final bucketName = _getBucketName(bucket);
    return await _client.storage.from(bucketName).createSignedUrl(path, expiresIn);
  }
}
