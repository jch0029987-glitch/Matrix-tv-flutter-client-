import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';
import '../services/app_webserver.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final Client client;

  const SettingsScreen({super.key, required this.client});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final AppWebserver _webserver = AppWebserver();
  String _appVersion = 'Loading...';
  String _updateStatus = '';
  bool _isCheckingUpdate = false;
  bool _isServerToggling = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
      });
    }
  }

  Future<void> _handleCheckForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = 'Checking GitHub releases...';
    });

    await UpdateService.checkForUpdates(
      onStatusUpdate: (status) {
        if (mounted) {
          setState(() {
            _updateStatus = status;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
      });
    }
  }

  Future<void> _handleToggleServer(bool value) async {
    setState(() => _isServerToggling = true);
    try {
      if (value) {
        await _webserver.start();
      } else {
        await _webserver.stop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle web server: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isServerToggling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Application Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // Web Server Control Tile
            Focus(
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return Card(
                    color: hasFocus ? const Color(0xFF03DAC6) : const Color(0xFF2C2C2C),
                    child: SwitchListTile(
                      title: Text(
                        'Local Web Control Panel (Port 8086)',
                        style: TextStyle(
                          color: hasFocus ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _webserver.isRunning 
                            ? 'Running on port ${_webserver.port} (0.0.0.0)' 
                            : 'Server is currently offline',
                        style: TextStyle(
                          color: hasFocus ? Colors.black54 : Colors.white70,
                        ),
                      ),
                      secondary: _isServerToggling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.dns,
                              color: hasFocus ? Colors.black : const Color(0xFF03DAC6),
                            ),
                      value: _webserver.isRunning,
                      onChanged: _isServerToggling 
                          ? null 
                          : (bool value) => _handleToggleServer(value),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Check for Updates Tile
            Focus(
              autofocus: true,
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return Card(
                    color: hasFocus ? const Color(0xFF03DAC6) : const Color(0xFF2C2C2C),
                    child: ListTile(
                      title: Text(
                        _isCheckingUpdate ? 'Updating...' : 'Check for Updates',
                        style: TextStyle(
                          color: hasFocus ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _updateStatus.isNotEmpty ? _updateStatus : 'Current version: $_appVersion',
                        style: TextStyle(
                          color: hasFocus ? Colors.black54 : Colors.white70,
                        ),
                      ),
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.system_update,
                              color: hasFocus ? Colors.black : const Color(0xFF03DAC6),
                            ),
                      onTap: _isCheckingUpdate ? null : _handleCheckForUpdates,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Logout / Sign Out Tile
            Focus(
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return Card(
                    color: hasFocus ? Colors.redAccent : const Color(0xFF2C2C2C),
                    child: ListTile(
                      title: Text(
                        'Log Out',
                        style: TextStyle(
                          color: hasFocus ? Colors.white : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Disconnect session from homeserver (${widget.client.userID ?? ""})',
                        style: TextStyle(
                          color: hasFocus ? Colors.white70 : Colors.white54,
                        ),
                      ),
                      trailing: Icon(
                        Icons.logout,
                        color: hasFocus ? Colors.white : Colors.redAccent,
                      ),
                      onTap: () async {
                        await widget.client.logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen(client: widget.client)),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
