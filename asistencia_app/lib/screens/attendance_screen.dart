import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/api.dart';

const kStatusColors = {
  'presente': Color(0xFF16A34A),
  'ausente': Color(0xFFDC2626),
  'tardanza': Color(0xFFD97706),
  'justificada': Color(0xFF2563EB),
};

const kStatusLabels = {
  'presente': 'Presente',
  'ausente': 'Ausente',
  'tardanza': 'Tardanza',
  'justificada': 'Justificada',
};

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> _records = [];
  Map<String, Map<String, dynamic>> _byDate = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Api.get('/api/me/attendance') as List;
      _records = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _byDate = {for (final r in _records) r['date'] as String: r};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _markDay(DateTime day) async {
    final date = _fmt(day);
    final existing = _byDate[date];
    final statusCtrl = ValueNotifier<String>(existing?['status'] ?? 'presente');
    final noteCtrl = TextEditingController(text: existing?['note'] ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Asistencia del $date', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
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
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      try {
        await Api.post('/api/me/attendance', {
          'date': date,
          'status': statusCtrl.value,
          'note': noteCtrl.text,
        });
        await _load();
        if (mounted) setState(() => _selectedDay = day);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      await Api.del('/api/me/attendance/$id');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        TableCalendar(
          locale: 'es_ES',
          firstDay: DateTime(2023, 1, 1),
          lastDay: DateTime(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
            _markDay(selected);
          },
          eventLoader: (day) {
            final r = _byDate[_fmt(day)];
            return r == null ? [] : [r];
          },
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(color: Color(0xFF94A3B8), shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: Color(0xFF1E3A5F), shape: BoxShape.circle),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final status = (events.first as Map)['status'] as String;
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: kStatusColors[status], shape: BoxShape.circle),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 12,
            children: kStatusLabels.entries
                .map((e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: kStatusColors[e.key], shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(e.value, style: const TextStyle(fontSize: 12)),
                      ],
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _records.isEmpty
              ? const Center(child: Text('Toca un día en el calendario para registrar tu asistencia'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _records.length,
                  itemBuilder: (context, i) {
                    final r = _records[i];
                    final status = r['status'] as String;
                    return Dismissible(
                      key: ValueKey('att-${r['id']}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(r['id'] as int),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kStatusColors[status]!.withOpacity(0.15),
                          child: Icon(
                            status == 'presente'
                                ? Icons.check
                                : status == 'ausente'
                                    ? Icons.close
                                    : status == 'tardanza'
                                        ? Icons.schedule
                                        : Icons.article,
                            color: kStatusColors[status],
                          ),
                        ),
                        title: Text('${r['date']} · ${kStatusLabels[status]}'),
                        subtitle: (r['note'] as String?)?.isEmpty == true ? null : Text(r['note']),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
