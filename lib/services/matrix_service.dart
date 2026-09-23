import 'dart:convert';
import 'package:http/http.dart' as http;

class MatrixService {
  final String homeserverUrl;
  String? accessToken;
  String? userId;

  MatrixService({required this.homeserverUrl});

  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$homeserverUrl/_matrix/client/v3/login');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "type": "m.login.password",
          "identifier": {
            "type": "m.id.user",
            "user": username,
          },
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        accessToken = data['access_token'];
        userId = data['user_id'];
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getJoinedRooms() async {
    if (accessToken == null) return [];

    final url = Uri.parse('$homeserverUrl/_matrix/client/v3/joined_rooms');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['joined_rooms'] ?? [];
      }
    } catch (e) {
      // Handle network exceptions
    }
    return [];
  }
}
