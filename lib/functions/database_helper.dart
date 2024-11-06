part of 'functions.dart';

class User {
  final int id;
  final String name;
  final String embedding;

  User({
    required this.id,
    required this.name,
    required this.embedding,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      name: map['name'] as String,
      embedding: map['vector'] as String,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, embedding: ${embedding.substring(0, 20)}...)';
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('face_vectors.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE face_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        vector TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<int> insertFaceData(String name, List<double> vector) async {
    final db = await instance.database;

    final data = {
      'name': name,
      'vector': jsonEncode(vector),
    };

    return await db.insert('face_data', data);
  }

  Future<List<Map<String, dynamic>>> getAllFaceData() async {
    final db = await instance.database;
    return await db.query('face_data', orderBy: 'created_at DESC');
  }

  Future<void> deleteFaceData(int id) async {
    final db = await instance.database;
    await db.delete(
      'face_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }

  Future<Map<String, dynamic>?> findMatchingFace(
      List<double>? newEmbedding) async {
    final db = await database;
    final faceData = await db.query('face_data');

    double threshold = 0.6;
    User? matchedUser;
    double bestSimilarity = -1;

    for (var data in faceData) {
      List<double> storedEmbedding = List<double>.from(
        jsonDecode(data['vector'] as String),
      );

      MSG.DBG("Data Face ${data['name']}");

      double similarity = calculateCosineSimilarity(newEmbedding!, storedEmbedding);

      if (similarity > threshold && similarity > bestSimilarity) {
        bestSimilarity = similarity;
        matchedUser = User(
          id: data['id'] as int,
          name: data['name'] as String,
          embedding: data['vector'] as String,
        );
      }
    }

    if (matchedUser != null) {
      double confidencePercentage = bestSimilarity * 100;
      return {
        'user': matchedUser,
        'confidence': confidencePercentage,
      };
    }

    return null;
  }

  Future<void> deleteAllData() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('face_data');

      await txn.rawDelete("DELETE FROM sqlite_sequence WHERE name='face_data'");
    });

    MSG.DBG('All data deleted successfully');
  }

  // Add this method to your DatabaseHelper class
  Future<void> updateUserName(int id, String newName) async {
    final db = await instance.database;
    await db.update(
      'face_data',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
