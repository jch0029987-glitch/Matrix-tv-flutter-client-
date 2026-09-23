import 'package:matrix/matrix.dart';

class MatrixService {
  final String homeserverUrl;
  late final Client client;

  MatrixService({required this.homeserverUrl}) {
    client = Client('MatrixTVClient');
  }

  Future<bool> login(String username, String password) async {
    try {
      await client.init();
      
      // Use the official SDK login method which handles tokens and local storage securely
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationIdentifier(user: username),
        password: password,
        baseUrl: Uri.parse(homeserverUrl),
      );

      return client.isLoggedIn();
    } catch (e) {
      return false;
    }
  }

  Future<List<Room>> getJoinedRooms() async {
    if (!client.isLoggedIn()) return [];
    return client.rooms;
  }
}
