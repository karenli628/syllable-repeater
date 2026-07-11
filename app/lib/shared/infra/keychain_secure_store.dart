// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SecureStorageBackend（REQ-07/M10）：隔離 Keychain plugin，讓測試不碰真 keychain。
abstract interface class SecureStorageBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

/// FlutterSecureStorageBackend（backend-design.md §3.2.5）：macOS Keychain 實作。
class FlutterSecureStorageBackend implements SecureStorageBackend {
  const FlutterSecureStorageBackend([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// KeychainSecureStore（REQ-07/M10）：AI key 只走 SecureStore，不落 DB/pack/log。
class KeychainSecureStore implements SecureStore {
  const KeychainSecureStore({
    this.backend = const FlutterSecureStorageBackend(),
  });

  final SecureStorageBackend backend;

  @override
  Future<String?> read(String key) async {
    _validateKey(key);
    try {
      return await backend.read(key);
    } catch (_) {
      throw _keychainFailure('read-failed');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _validateKey(key);
    try {
      await backend.write(key, value);
    } catch (_) {
      throw _keychainFailure('write-failed');
    }
  }

  void _validateKey(String key) {
    if (key.trim().isEmpty) {
      throw _keychainFailure('empty-key');
    }
  }
}

DomainException _keychainFailure(String reason) =>
    DomainException(ErrorCodes.aiCallFailed, 'Keychain 存取失敗（$reason）');
