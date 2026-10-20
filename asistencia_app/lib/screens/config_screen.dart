import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../widgets/qr_scan_sheet.dart';
import 'alumno_home.dart';
import 'docente_home.dart';
import 'login_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _urlCtrl = TextEditingController(text: Api.baseUrl ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _msg('Ingresa la dirección del servidor');
      return;
    }
    setState(() => _busy = true);
    final prev = Api.baseUrl;
    await Api.setServerUrl(url);
    try {
      await Api.get('/api/network');
      if (!mounted) return;
      if (Api.token != null) {
        try {
          final data = await Api.me();
          final role = data['user']['role'];
          _goHome(role);
          return;
        } catch (_) {
          await Api.clearSession();
          _go(const LoginScreen());
          return;
        }
      }
      _go(const LoginScreen());
    } catch (_) {
      await Api.setServerUrl(prev ?? '');
      if (!mounted) return;
      _msg('No se pudo conectar con el servidor. Revisa que estés en la misma red WiFi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final raw = await showQrScanner(context);
    if (raw == null || !mounted) return;
    final url = parseServerUrlFromQr(raw);
    if (url == null) {
      _msg('Ese QR no contiene la dirección del servidor');
      return;
    }
    _urlCtrl.text = url;
    await _save();
  }

  void _go(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  void _goHome(String role) {
    _go(role == 'docente' ? const DocenteHome() : const AlumnoHome());
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.school, size: 72, color: Color(0xFF1E3A5F)),
                const SizedBox(height: 12),
                Text(
                  'Asistencia y Notas',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A5F),
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Conéctate al servidor del docente\n(debes estar en su red WiFi)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Dirección del servidor',
                    hintText: 'http://192.168.1.5:3000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link),
                  label: const Text('Conectar'),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear QR del docente'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
