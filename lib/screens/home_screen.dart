import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  
  String? _appToken;
  Map<String, dynamic>? _perfilData;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _reloj;
  DateTime? _sesionExpira;
  Uint8List? _foto;

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  // Iniciar sesión (Paso 1, 2 y sondeo)
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apptoken = await _authService.iniciarSesion();
      setState(() {
        _appToken = apptoken;
      });
      // Una vez obtenido el token, cargamos el perfil
      await _loadProfile(apptoken);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Cargar perfil usando el app_token
  Future<void> _loadProfile(String token) async {
    setState(() {
      _errorMessage = null;
    });
    try {
      final perfil = await _authService.leerPerfil(token);
      if (perfil == null) {
        // Token caducado o inválido (401)
        _handleLogoutLocally();
        setState(() {
          _errorMessage = 'La sesión ha caducado. Por favor, inicia sesión nuevamente.';
        });
      } else {
        final expira = perfil['session_expires_at'];
        setState(() {
          _perfilData = perfil;
          _foto = decodeDataUri(perfil['profile']?['picture']);
          _sesionExpira = expira is num
              ? DateTime.fromMillisecondsSinceEpoch(expira.toInt() * 1000)
              : null;
        });
        _iniciarReloj();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  void _iniciarReloj() {
    _reloj?.cancel();
    if (_sesionExpira == null) return;
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final expira = _sesionExpira;
      if (expira != null && !DateTime.now().isBefore(expira)) {
        _handleLogoutLocally();
        setState(() {
          _errorMessage = 'La sesión ha caducado. Por favor, inicia sesión nuevamente.';
        });
        return;
      }
      setState(() {});
    });
  }

  // Cerrar sesión
  Future<void> _handleLogout() async {
    if (_appToken != null) {
      try {
        await _authService.cerrarSesion(_appToken!);
      } catch (_) {
        // 
      }
    }
    _handleLogoutLocally();
  }

  void _handleLogoutLocally() {
    _reloj?.cancel();
    setState(() {
      _appToken = null;
      _perfilData = null;
      _foto = null;
      _sesionExpira = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final photo = _foto;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RP Desktop Client'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Esperando la autenticación en el navegador ....',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              else if (_appToken == null)
                // Vista: No autenticado
                FilledButton.icon(
                  onPressed: _handleLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar sesión con eSignet'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              else
                // Vista: Autenticado con perfil cargado
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¡Hola!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Divider(height: 24),
                        if (_perfilData != null && _perfilData!['profile'] != null) ...[
                          Center(
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.blue.shade100,
                              backgroundImage: photo != null ? MemoryImage(photo) : null,
                              child: photo == null
                                  ? const Icon(Icons.person, size: 40, color: Colors.blue)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Nombre: ${_perfilData!['profile']['name'] ?? 'N/D'}'),
                          const SizedBox(height: 8),
                          Text('Correo: ${_perfilData!['profile']['email'] ?? 'N/D'}'),
                          if (_sesionExpira != null) ...[
                            const SizedBox(height: 8),
                            Text('Sesión válida hasta: ${_formatoHora(_sesionExpira!)}'),
                            const SizedBox(height: 8),
                            Text('Tiempo restante: ${_formatoRestante(_sesionExpira!.difference(DateTime.now()))}'),
                          ],
                        ] else
                          const Text('Cargando perfil...'),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _handleLogout,
                                icon: const Icon(Icons.logout),
                                label: const Text('Cerrar Sesión'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Uint8List? decodeDataUri(Object? value) {
  if (value is! String || !value.startsWith('data:image/')) {
    return null;
  }
  final comma = value.indexOf(',');
  if (comma < 0) {
    return null;
  }
  try {
    return base64Decode(value.substring(comma + 1));
  } on FormatException {
    return null;
  }
}

String _dos(int n) => n.toString().padLeft(2, '0');

String _formatoHora(DateTime t) => '${_dos(t.hour)}:${_dos(t.minute)}:${_dos(t.second)}';

String _formatoRestante(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${_dos(total ~/ 60)}:${_dos(total % 60)}';
}
