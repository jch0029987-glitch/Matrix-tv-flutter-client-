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
      final dbDir = await getApplicationSupportDirectory();
      final dbPath = p.join(dbDir.path, 'matrix_tv_client.db');
      final sqfDb = await sqflite.openDatabase(dbPath);

      client = Client(
        'MatrixTVClient',
        databaseBuilder: (_) async => MatrixSdkDatabase('MatrixTVClient', database: sqfDb),
      );
      
      await client.init();
      
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationIdentifier.user(username),
        password: password,
        url: Uri.parse(homeserverUrl),
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
