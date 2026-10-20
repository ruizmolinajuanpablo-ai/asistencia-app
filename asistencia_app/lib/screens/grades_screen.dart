import 'package:flutter/material.dart';

import '../services/api.dart';

class GradesScreen extends StatefulWidget {
  final String kind; // 'activities' | 'exams'
  final String title;

  const GradesScreen({super.key, required this.kind, required this.title});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Api.get('/api/me/${widget.kind}') as List;
      _items = data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _percent {
    if (_items.isEmpty) return 0;
    final score = _items.fold<double>(0, (a, r) => a + (r['score'] as num).toDouble());
    final max = _items.fold<double>(0, (a, r) => a + (r['max_score'] as num).toDouble());
    return max == 0 ? 0 : score / max * 20;
  }

  Future<void> _editDialog([Map<String, dynamic>? item]) async {
    final result = await showGradeDialog(context, item: item);
    if (result == null || !mounted) return;
    try {
      if (item == null) {
        await Api.post('/api/me/${widget.kind}', result);
      } else {
        await Api.patch('/api/me/${widget.kind}/${item['id']}', result);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      await Api.del('/api/me/${widget.kind}/$id');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      body: _items.isEmpty
          ? const Center(child: Text('Aún no hay registros. Toca + para agregar.'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Promedio (sobre 20)'),
                        Text(
                          _percent.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                        ),
                      ],
                    ),
                  ),
                ),
                ..._items.map(
                  (r) => Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text('${r['name']}'),
                      subtitle: Text('${r['date']}${(r['note'] as String?)?.isEmpty == true ? '' : ' · ${r['note']}'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${r['score']}/${r['max_score']}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(r['id'] as int),
                          ),
                        ],
                      ),
                      onTap: () => _editDialog(r),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

/// Diálogo para crear/editar una nota de actividad o examen.
Future<Map<String, dynamic>?> showGradeDialog(BuildContext context, {Map<String, dynamic>? item}) {
  final nameCtrl = TextEditingController(text: item?['name'] ?? '');
  final scoreCtrl = TextEditingController(text: item != null ? '${item['score']}' : '');
  final maxCtrl = TextEditingController(text: item != null ? '${item['max_score']}' : '20');
  final noteCtrl = TextEditingController(text: item?['note'] ?? '');
  DateTime date = item != null ? DateTime.parse(item['date'] as String) : DateTime.now();

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) => AlertDialog(
        title: Text(item == null ? 'Agregar' : 'Editar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: scoreCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Nota', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Máximo', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
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
                decoration: const InputDecoration(labelText: 'Observación (opcional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final score = double.tryParse(scoreCtrl.text);
              final max = double.tryParse(maxCtrl.text);
              if (nameCtrl.text.trim().isEmpty || score == null || max == null || max <= 0 || score < 0 || score > max) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Revisa: nombre y nota válida (0 hasta el máximo)')),
                );
                return;
              }
              Navigator.pop(ctx, {
                'name': nameCtrl.text.trim(),
                'score': score,
                'max_score': max,
                'date':
                    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                'note': noteCtrl.text,
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
