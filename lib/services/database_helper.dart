import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class User {
  final int? id;
  final String fullName;
  final String email;
  final String password;
  final String userType;
  final String nationality;
  final String digitalId;
  final DateTime createdAt;

  User({
    this.id,
    required this.fullName,
    required this.email,
    required this.password,
    required this.userType,
    required this.nationality,
    required this.digitalId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'password': password,
      'userType': userType,
      'nationality': nationality,
      'digitalId': digitalId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      fullName: map['fullName'],
      email: map['email'],
      password: map['password'],
      userType: map['userType'],
      nationality: map['nationality'],
      digitalId: map['digitalId'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tourist_safety.db');
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
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName $textType,
        email $textType UNIQUE,
        password $textType,
        userType $textType,
        nationality $textType,
        digitalId $textType UNIQUE,
        createdAt $textType
      )
    ''');

    // Insert default demo users
    await _insertDemoUsers(db);
  }

  Future _insertDemoUsers(Database db) async {
    final demoUsers = [
      {
        'fullName': 'John Smith',
        'email': 'tourist@example.com',
        'password': _hashPassword('tourist123'),
        'userType': 'Tourist',
        'nationality': 'United States',
        'digitalId': '1123456789',
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'fullName': 'Sarah Johnson',
        'email': 'admin@example.com',
        'password': _hashPassword('admin123'),
        'userType': 'Administrator',
        'nationality': 'India',
        'digitalId': '2234567890',
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'fullName': 'Officer Rajesh Kumar',
        'email': 'police@example.com',
        'password': _hashPassword('police123'),
        'userType': 'Police Officer',
        'nationality': 'India',
        'digitalId': '3345678901',
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'fullName': 'Priya Sharma',
        'email': 'tourism@example.com',
        'password': _hashPassword('tourism123'),
        'userType': 'Tourism Officer',
        'nationality': 'India',
        'digitalId': '4456789012',
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'fullName': 'Dr. Michael Brown',
        'email': 'emergency@example.com',
        'password': _hashPassword('emergency123'),
        'userType': 'Emergency Responder',
        'nationality': 'Canada',
        'digitalId': '5567890123',
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];

    for (var user in demoUsers) {
      await db.insert('users', user);
    }
  }

  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User> createUser(User user) async {
    final db = await instance.database;
    
    // Hash the password before storing
    final hashedUser = User(
      fullName: user.fullName,
      email: user.email,
      password: _hashPassword(user.password),
      userType: user.userType,
      nationality: user.nationality,
      digitalId: user.digitalId,
      createdAt: user.createdAt,
    );

    final id = await db.insert('users', hashedUser.toMap());
    return hashedUser.copyWith(id: id);
  }

  Future<User?> loginUser(String email, String password, String userType) async {
    final db = await instance.database;
    final hashedPassword = _hashPassword(password);

    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ? AND userType = ?',
      whereArgs: [email, hashedPassword, userType],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await instance.database;

    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users', orderBy: 'createdAt DESC');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<int> updateUser(User user) async {
    final db = await instance.database;

    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;

    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // Generate unique digital ID
  static String generateDigitalId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return '${timestamp.toString().substring(3)}$random';
  }
}

// Extension to add copyWith method to User class
extension UserExtension on User {
  User copyWith({
    int? id,
    String? fullName,
    String? email,
    String? password,
    String? userType,
    String? nationality,
    String? digitalId,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      userType: userType ?? this.userType,
      nationality: nationality ?? this.nationality,
      digitalId: digitalId ?? this.digitalId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}