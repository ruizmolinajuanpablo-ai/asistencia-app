import 'package:flutter/material.dart';

import '../services/api.dart';
import 'attendance_screen.dart';
import 'config_screen.dart';
import 'grades_screen.dart';
import 'login_screen.dart';

class AlumnoHome extends StatelessWidget {
  const AlumnoHome({super.key});

  Future<void> _logout(BuildContext context) async {
    await Api.clearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _config(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final name = Api.user?['name'] as String? ?? 'Alumno';
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Hola, $name'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.event_available), text: 'Asistencia'),
              Tab(icon: Icon(Icons.assignment), text: 'Actividades'),
              Tab(icon: Icon(Icons.quiz), text: 'Exámenes'),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.dns), tooltip: 'Servidor', onPressed: () => _config(context)),
            IconButton(icon: const Icon(Icons.logout), tooltip: 'Salir', onPressed: () => _logout(context)),
          ],
        ),
        body: const TabBarView(
          children: [
            AttendanceScreen(),
            GradesScreen(kind: 'activities', title: 'Actividades'),
            GradesScreen(kind: 'exams', title: 'Exámenes'),
          ],
        ),
      ),
    );
  }
}
