import 'package:flutter/foundation.dart' show kIsWeb;
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
      final sqfDb = kIsWeb ? null : await _openDatabase();

      // Initialize the client using the correct 'database:' property and MatrixSdkDatabase.init
      client = Client(
        'MatrixTVClient',
        database: await MatrixSdkDatabase.init(
          'MatrixTVClient',
          database: sqfDb,
        ),
      );
      
      await client.init();
      
      // Verify and configure the homeserver URL on the client instance
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

  Future<sqflite.Database> _openDatabase() async {
    final directory = await getApplicationSupportDirectory();
    final dbPath = p.join(directory.path, 'matrix_tv_client.db');
    return sqflite.openDatabase(dbPath);
  }

  Future<List<Room>> getJoinedRooms() async {
    if (!client.isLogged()) return [];
    return client.rooms;
  }
}
