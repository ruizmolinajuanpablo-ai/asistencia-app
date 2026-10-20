import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static String? baseUrl;
  static String? token;
  static Map<String, dynamic>? user;
  static SharedPreferences? _prefs;

  static Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    baseUrl = _prefs!.getString('serverUrl');
    token = _prefs!.getString('token');
    // En web (app alojada por el propio servidor) la URL es la de la página.
    if (kIsWeb && (baseUrl == null || baseUrl!.isEmpty)) {
      baseUrl = Uri.base.origin;
    }
  }

  static Future<void> setServerUrl(String url) async {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs!.setString('serverUrl', baseUrl!);
  }

  static Future<void> setSession(String t, Map<String, dynamic> u) async {
    token = t;
    user = u;
    await _prefs!.setString('token', t);
  }

  static Future<void> clearSession() async {
    token = null;
    user = null;
    await _prefs!.remove('token');
  }

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static dynamic _handle(http.Response r) {
    final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      throw Exception(data is Map && data['error'] != null ? data['error'] : 'Error ${r.statusCode}');
    }
    return data;
  }

  static Future<dynamic> get(String path) async {
    final r = await http.get(_uri(path), headers: _headers);
    return _handle(r);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(_uri(path), headers: _headers, body: jsonEncode(body));
    return _handle(r);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await http.patch(_uri(path), headers: _headers, body: jsonEncode(body));
    return _handle(r);
  }

  static Future<dynamic> del(String path) async {
    final r = await http.delete(_uri(path), headers: _headers);
    return _handle(r);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/api/auth/login', {'email': email, 'password': password});
    await setSession(data['token'], Map<String, dynamic>.from(data['user']));
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final data = await post('/api/auth/register', {'name': name, 'email': email, 'password': password});
    await setSession(data['token'], Map<String, dynamic>.from(data['user']));
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> me() async {
    final data = await get('/api/me');
    user = Map<String, dynamic>.from(data['user']);
    return Map<String, dynamic>.from(data);
  }
}
