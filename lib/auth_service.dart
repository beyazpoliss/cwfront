import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  // Singleton instance
  static final StorageService _instance = StorageService._internal();

  // FlutterSecureStorage instance
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  static const url = 'http://66.94.122.16:3000';

  // Private constructor
  StorageService._internal();

  // Factory constructor
  factory StorageService() {
    return _instance;
  }

  // Write a value to storage
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // Read a value from storage
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  // Delete a value from storage
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  // Read all values
  static Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }

  // Delete all values
  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
