import 'dart:io';
import 'i_storage_repository.dart';

class MockStorageRepository implements IStorageRepository {
  @override
  Future<String> uploadFile({
    required StorageBucket bucket,
    required String path,
    required File file,
  }) async {
    return 'mock_url_for_';
  }

  @override
  Future<void> deleteFile({
    required StorageBucket bucket,
    required String path,
  }) async {}

  @override
  Future<String> getSignedUrl({
    required StorageBucket bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    return 'mock_signed_url_for_';
  }
}
