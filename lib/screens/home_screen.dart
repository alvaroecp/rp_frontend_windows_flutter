import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'farmer_status_screen.dart';

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
          _errorMessage = 'Your session has expired. Please sign in again.';
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
          _errorMessage = 'Your session has expired. Please sign in again.';
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
                      'Waiting for authentication in the browser...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              else if (_appToken == null)
                // Vista: No autenticado
                Center(
                  child: FilledButton.icon(
                    onPressed: _handleLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with eSignet'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                    ),
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
                          'Hello!',
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
                          Text('Name: ${_perfilData!['profile']['name'] ?? 'N/A'}'),
                          const SizedBox(height: 8),
                          Text('Email: ${_perfilData!['profile']['email'] ?? 'N/A'}'),
                          if (_sesionExpira != null) ...[
                            const SizedBox(height: 8),
                            Text('Session valid until: ${_formatoHora(_sesionExpira!)}'),
                            const SizedBox(height: 8),
                            Text('Time remaining: ${_formatoRestante(_sesionExpira!.difference(DateTime.now()))}'),
                          ],
                        ] else
                          const Text('Loading profile...'),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              final nombre =
                                  _perfilData?['profile']?['name']?.toString() ?? 'N/A';
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FarmerStatusScreen(name: nombre),
                                ),
                              );
                            },
                            icon: const Icon(Icons.agriculture),
                            label: const Text('Farmer Status'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _handleLogout,
                                icon: const Icon(Icons.logout),
                                label: const Text('Sign out'),
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
