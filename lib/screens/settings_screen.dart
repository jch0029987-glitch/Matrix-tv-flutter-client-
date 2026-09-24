import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _autoStartOnLogin = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAppVersion();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoStartOnLogin = prefs.getBool('autostart_on_login') ?? true;
      });
    }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server started on port 8086!')),
          );
        }
      } else {
        await _webserver.stop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server stopped.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
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

  Future<void> _toggleAutoStartOnLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autostart_on_login', value);
    setState(() {
      _autoStartOnLogin = value;
    });
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
        child: ListView(
          children: [
            const Text(
              'Application Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            
            // 1. Web Server Control Tile
            Focus(
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  
                  // Expose startup error on TV screen if present
                  final String subtitleText = _webserver.isRunning 
                      ? 'Running on port ${_webserver.port} (0.0.0.0)' 
                      : (_webserver.lastError != null 
                          ? 'Error: ${_webserver.lastError}' 
                          : 'Server is currently offline');

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
                        subtitleText,
                        style: TextStyle(
                          color: hasFocus 
                              ? Colors.black54 
                              : (_webserver.lastError != null ? Colors.redAccent : Colors.white70),
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

            // 2. Start on Login Toggle Tile
            Focus(
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return Card(
                    color: hasFocus ? const Color(0xFF03DAC6) : const Color(0xFF2C2C2C),
                    child: SwitchListTile(
                      title: Text(
                        'Start Web Server on App Login',
                        style: TextStyle(
                          color: hasFocus ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _autoStartOnLogin 
                            ? 'Automatically boots port 8086 upon login' 
                            : 'Manual start only',
                        style: TextStyle(
                          color: hasFocus ? Colors.black54 : Colors.white70,
                        ),
                      ),
                      secondary: Icon(
                        Icons.login,
                        color: hasFocus ? Colors.black : const Color(0xFF03DAC6),
                      ),
                      value: _autoStartOnLogin,
                      onChanged: (val) => _toggleAutoStartOnLogin(val),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 3. Check for Updates Tile
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

            // 4. Logout / Sign Out Tile
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
                        await _webserver.stop();
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
