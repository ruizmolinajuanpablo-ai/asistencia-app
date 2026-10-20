import 'package:flutter/material.dart';

import '../services/api.dart';
import 'attendance_screen.dart' show kStatusColors, kStatusLabels;
import 'grades_screen.dart' show showGradeDialog;

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await Api.get('/api/admin/students/${widget.student['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String table, int id) async {
    try {
      await Api.del('/api/admin/$table/$id');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addAttendance() async {
    final statusCtrl = ValueNotifier<String>('presente');
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setModal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Asistencia', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: statusCtrl,
                builder: (_, value, __) => Wrap(
                  spacing: 8,
                  children: kStatusLabels.entries
                      .map((e) => ChoiceChip(
                            label: Text(e.value),
                            selected: value == e.key,
                            selectedColor: kStatusColors[e.key]!.withOpacity(0.25),
                            onSelected: (_) => setModal(() => statusCtrl.value = e.key),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setModal(() => date = picked);
                },
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Nota (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      try {
        await Api.post('/api/admin/students/${widget.student['id']}/attendance', {
          'date':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'status': statusCtrl.value,
          'note': noteCtrl.text,
        });
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _addGrade(String table) async {
    final result = await showGradeDialog(context);
    if (result == null || !mounted) return;
    try {
      await Api.post('/api/admin/students/${widget.student['id']}/$table', result);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    return Scaffold(
      appBar: AppBar(title: Text(student['name'] as String)),
      body: _loading || _data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                ListTile(
                  subtitle: Text('${student['email']}'),
                ),
                _section(
                  title: 'Asistencia',
                  icon: Icons.event_available,
                  onAdd: _addAttendance,
                  children: ((_data!['attendance']) as List).map((r) {
                    final status = r['status'] as String;
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.circle, size: 12, color: kStatusColors[status]),
                      title: Text('${r['date']} · ${kStatusLabels[status]}'),
                      subtitle: (r['note'] as String?)?.isEmpty == true ? null : Text(r['note'] as String),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete('attendance', r['id'] as int),
                      ),
                    );
                  }).toList(),
                ),
                _section(
                  title: 'Actividades',
                  icon: Icons.assignment,
                  onAdd: () => _addGrade('activities'),
                  children: ((_data!['activities']) as List)
                      .map((r) => ListTile(
                            dense: true,
                            title: Text('${r['name']}'),
                            subtitle: Text('${r['date']}${(r['note'] as String?)?.isEmpty == true ? '' : ' · ${r['note']}'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${r['score']}/${r['max_score']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete('activities', r['id'] as int),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                _section(
                  title: 'Exámenes',
                  icon: Icons.quiz,
                  onAdd: () => _addGrade('exams'),
                  children: ((_data!['exams']) as List)
                      .map((r) => ListTile(
                            dense: true,
                            title: Text('${r['name']}'),
                            subtitle: Text('${r['date']}${(r['note'] as String?)?.isEmpty == true ? '' : ' · ${r['note']}'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${r['score']}/${r['max_score']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete('exams', r['id'] as int),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onAdd),
        children: children.isEmpty
            ? [const ListTile(title: Text('Sin registros', style: TextStyle(color: Colors.grey)))]
            : children,
      ),
    );
  }
}
