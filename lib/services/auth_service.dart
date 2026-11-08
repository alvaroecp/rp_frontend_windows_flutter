import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  // Establece la URL base del RP backend 
  static const backendUrl = 'http://localhost:3005';

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse(backendUrl).replace(path: path, queryParameters: query);

  /// Pide el ticket, abre el navegador y realiza el sondeo hasta completar el login
  Future<String> iniciarSesion() async {
    final inicioRes = await http.post(_uri('/api/login/start'));
    if (inicioRes.statusCode != 200) {
      throw Exception('Error al iniciar el login (${inicioRes.statusCode})');
    }
    
    final inicio = jsonDecode(inicioRes.body) as Map<String, dynamic>;
    final ticket = inicio['ticket'] as String;
    final secreto = inicio['poll_secret'] as String;

    // Abre el navegador web externo 
    final launched = await launchUrl(
      Uri.parse(inicio['login_url'] as String),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('No se pudo abrir el navegador del sistema.');
    }

    final intervalo = Duration(seconds: inicio['interval'] as int);
    final limite = DateTime.now().add(Duration(seconds: inicio['expires_in'] as int));

    // Sondeo periódico (polling) según el intervalo indicado
    while (DateTime.now().isBefore(limite)) {
      await Future.delayed(intervalo);
      
      final r = await http.get(
        _uri('/api/login/status', {'ticket': ticket}),
        headers: {'X-Poll-Secret': secreto},
      );
      
      if (r.statusCode != 200) {
        throw Exception('Sondeo de inicio de sesión no válido o caducado (${r.statusCode})');
      }
      
      final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
      switch (cuerpo['status']) {
        case 'complete':
          return cuerpo['app_token'] as String;
        case 'error':
          throw Exception('El inicio de sesión falló en el proveedor.');
      }
    }
    throw Exception('El tiempo de espera del inicio de sesión caducó.');
  }

  /// Lee el perfil del usuario autenticado usando el app_token
  Future<dynamic> leerPerfil(String token) async {
    final r = await http.get(
      _uri('/api/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 401) return null; // Sesión caducada
    if (r.statusCode != 200) {
      throw Exception('Error al obtener el perfil (${r.statusCode})');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Cierra la sesión en el backend
  Future<void> cerrarSesion(String token) async {
    await http.post(
      _uri('/api/logout'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
