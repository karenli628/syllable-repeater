// AI-Generate

/// 敏感設定儲存抽象（backend-design.md §3.2.5 介面 11）。
/// Domain 只看 key/value port；macOS Keychain 等平台實作留在 infra/app。
abstract interface class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}
