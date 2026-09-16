import 'dart:typed_data';

enum StorageBucket {
  profileImages,
  workerDocuments,
}

abstract class IStorageRepository {
  /// Uploads file bytes to a specific bucket and path, returns the public/signed URL or path.
  /// Works on both mobile (dart:io) and web (dart:html) since we pass raw bytes.
  Future<String> uploadFile({
    required StorageBucket bucket,
    required String path,
    required Uint8List fileBytes,
    String? mimeType,
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
