import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;

class MatrixService {
  final String homeserverUrl;
  late final Client client;

  MatrixService({required this.homeserverUrl});

  Future<bool> login(String username, String password) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final dbPath = p.join(directory.path, 'matrix_tv_client.db');
      final sqfDb = await sqflite.openDatabase(dbPath);

      // Initialize the client using databaseBuilder as required by the SDK
      client = Client(
        'MatrixTVClient',
        databaseBuilder: (_) async => MatrixSdkDatabase(
          'MatrixTVClient',
          database: sqfDb,
        ),
      );
      
      await client.init();
      
      // Resolve and verify homeserver URL
      await client.checkHomeserver(Uri.parse(homeserverUrl));
      
      // Perform password authentication using AuthenticationUserIdentifier
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: username),
        password: password,
      );

      return client.isLogged();
    } catch (e) {
      return false;
    }
  }

  Future<List<Room>> getJoinedRooms() async {
    if (!client.isLogged()) return [];
    return client.rooms;
  }
}
