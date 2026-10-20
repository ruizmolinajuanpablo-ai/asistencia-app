import 'package:flutter/material.dart';

import '../services/api.dart';
import 'config_screen.dart';
import 'login_screen.dart';
import 'student_detail_screen.dart';

class DocenteHome extends StatefulWidget {
  const DocenteHome({super.key});

  @override
  State<DocenteHome> createState() => _DocenteHomeState();
}

class _DocenteHomeState extends State<DocenteHome> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.get('/api/admin/students') as List;
      _students = data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await Api.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = Api.user?['name'] as String? ?? 'Docente';
    return Scaffold(
      appBar: AppBar(
        title: Text('Docente · $name'),
        actions: [
          IconButton(icon: const Icon(Icons.dns), tooltip: 'Servidor', onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigScreen()));
          }),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Salir', onPressed: _logout),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _students.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aún no hay alumnos registrados.\nLos alumnos se registran desde la app con su correo.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (context, i) {
                          final s = _students[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(child: Text((s['name'] as String).substring(0, 1).toUpperCase())),
                              title: Text(s['name'] as String),
                              subtitle: Text(s['email'] as String),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
                                );
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
