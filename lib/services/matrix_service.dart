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

      client = Client(
        'MatrixTVClient',
        databaseBuilder: (_) async => MatrixSdkDatabase.init(
          'MatrixTVClient',
          database: sqfDb,
        ),
      );
      
      await client.init();
      
      // Corrected parameters for Matrix SDK v12 login
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationIdentifier(
          user: username,
          type: AuthenticationIdentifier.idTypeUser,
        ),
        password: password,
        baseUrl: Uri.parse(homeserverUrl),
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
