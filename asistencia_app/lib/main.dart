import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/alumno_home.dart';
import 'screens/config_screen.dart';
import 'screens/docente_home.dart';
import 'screens/login_screen.dart';
import 'services/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  await Api.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistencia y Notas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A5F)),
        useMaterial3: true,
      ),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    Widget next;
    if (Api.baseUrl == null || Api.baseUrl!.isEmpty) {
      next = const ConfigScreen();
    } else if (Api.token == null) {
      next = const LoginScreen();
    } else {
      try {
        final data = await Api.me();
        next = data['user']['role'] == 'docente' ? const DocenteHome() : const AlumnoHome();
      } catch (_) {
        await Api.clearSession();
        next = const LoginScreen();
      }
    }
    if (mounted) setState(() => _screen = next);
  }

  @override
  Widget build(BuildContext context) {
    return _screen ??
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
  }
}
