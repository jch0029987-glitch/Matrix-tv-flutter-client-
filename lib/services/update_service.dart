import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  // Replace with your actual GitHub repo info
  static const String owner = 'jch0029987-glitch';
  static const String repo = 'Matrix-tv-flutter-client-';

  static Future<void> checkForUpdates({required Function(String) onStatusUpdate}) async {
    try {
      onStatusUpdate('Checking for updates...');
      
      // 1. Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      // 2. Query GitHub Releases API
      final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode != 200) {
        onStatusUpdate('Failed to check for updates.');
        return;
      }

      final data = jsonDecode(response.body);
      final String latestTag = data['tag_name'] ?? ''; // e.g. "v1.0.1" or "1.0.1"
      final cleanLatestVersion = latestTag.replaceAll('v', '');

      if (_isVersionNewer(currentVersion, cleanLatestVersion)) {
        // Find the APK asset in the release
        List assets = data['assets'] ?? [];
        String? apkDownloadUrl;
        
        for (var asset in assets) {
          String name = asset['name'] ?? '';
          if (name.endsWith('.apk')) {
            apkDownloadUrl = asset['browser_download_url'];
            break;
          }
        }

        if (apkDownloadUrl != null) {
          onStatusUpdate('Downloading update v$cleanLatestVersion...');
          await _downloadAndInstall(apkDownloadUrl, onStatusUpdate);
        } else {
          onStatusUpdate('Update found, but no APK asset attached.');
        }
      } else {
        onStatusUpdate('App is up to date.');
      }
    } catch (e) {
      onStatusUpdate('Error checking for updates: $e');
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    List<String> currParts = current.split('.');
    List<String> latestParts = latest.split('.');

    for (int i = 0; i < 3; i++) {
      int curr = int.tryParse(currParts.length > i ? currParts[i] : '0') ?? 0;
      int lat = int.tryParse(latestParts.length > i ? latestParts[i] : '0') ?? 0;
      if (lat > curr) return true;
      if (curr > lat) return false;
    }
    return false;
  }

  static Future<void> _downloadAndInstall(String url, Function(String) onStatusUpdate) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode == 200) {
        // Fixed: Use getTemporaryDirectory() instead of non-existent methods
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/update.apk';
        final file = File(filePath);

        final bytes = await streamedResponse.stream.toBytes();
        await file.writeAsBytes(bytes);

        onStatusUpdate('Installing update...');
        
        // Triggers the system package installer via FileProvider
        await OpenFilex.open(filePath);
      } else {
        onStatusUpdate('Download failed.');
      }
    } catch (e) {
      onStatusUpdate('Installation error: $e');
    }
  }
}
