// lib/services/update_service_stub.dart
class UpdateService {
  static Future<void> checkForUpdates({
    required Function(String) onStatusUpdate,
  }) async {
    onStatusUpdate('Web PWA updates automatically via browser cache.');
  }
}
