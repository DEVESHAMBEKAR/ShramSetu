import 'dart:io';

enum StorageBucket {
  profileImages,
  workerDocuments,
}

abstract class IStorageRepository {
  /// Uploads a file to a specific bucket and path, returns the public/signed URL or path
  Future<String> uploadFile({
    required StorageBucket bucket,
    required String path,
    required File file,
  });

  /// Deletes a file from storage
  Future<void> deleteFile({
    required StorageBucket bucket,
    required String path,
  });

  /// Gets a signed URL for private buckets (e.g., worker-documents)
  Future<String> getSignedUrl({
    required StorageBucket bucket,
    required String path,
    int expiresIn = 3600,
  });
}
