import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SQLite {
  static final SQLite instance = SQLite._init();
  static Database? _database;

  SQLite._init();
  static void printDbVersion() async {
    final db = await SQLite._init().database;
    log("Database version: ${await db.getVersion()}");
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB('KS_bullkysms.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  FutureOr<void> _createDB(Database db, int version) async {
    await db.execute('''
              CREATE TABLE User
							(UserID INTEGER PRIMARY KEY, Email TEXT, Password TEXT, Mobile TEXT, APIKey TEXT, AppKey TEXT) 
          ''');
    await db.rawInsert("""
        INSERT INTO User
        (UserID, Email, Password, Mobile, APIKey, AppKey)
        VALUES (0, '', '', '', '', '')
        """);
  }

  static Future<String> getValue(
    String field,
    String table,
    String where,
  ) async {
    String value = "";
    try {
      final db = await instance.database;
      var queryData = await db.rawQuery(
        "SELECT $field FROM $table WHERE $where",
      );
      value = (queryData.first[field]).toString();
    } catch (e) {
      if (kDebugMode) {
        print('GetValue EXP: $e');
      }
    }
    return value;
  }

  static Future<void> updateValue(
    String field,
    String table,
    String where,
    String value,
  ) async {
    try {
      final db = await instance.database;
      await db.rawQuery("""
               UPDATE $table SET 
               $field = '$value'
               WHERE $where
               """);
    } catch (e) {
      log('UpdateValue EXP: $e');
    }
  }
}
