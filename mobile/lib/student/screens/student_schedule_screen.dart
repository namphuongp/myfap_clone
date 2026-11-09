import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../models/schedule_session.dart';
import '../utils/schedule_date.dart';
import '../widgets/schedule_session_card.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;
  List<ScheduleSession> _sessions = [];
  bool _loading = true;
  String? _error;
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = vietnamToday();
    _weekStart = mondayOf(_selectedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadWeek();
    });
  }

  Future<void> _loadWeek({bool clear = false}) async {
    final requestNumber = ++_requestNumber;
    final weekStart = _weekStart;
    setState(() {
      _loading = true;
      _error = null;
      if (clear) _sessions = [];
    });

    try {
      final from = Uri.encodeQueryComponent(
        utcAtVietnamMidnight(weekStart).toIso8601String(),
      );
      final to = Uri.encodeQueryComponent(
        utcAtVietnamMidnight(weekStart.add(const Duration(days: 7)))
            .toIso8601String(),
      );
      final data = await widget.api.request(
        'GET',
        '/schedule?from=$from&to=$to',
      );
      final sessions =
          (data as List)
              .map(
                (row) => ScheduleSession.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() => _sessions = sessions);
    } catch (e) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && requestNumber == _requestNumber) {
        setState(() => _loading = false);
      }
    }
  }

  void _changeWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: direction * 7));
      _selectedDay = _selectedDay.add(Duration(days: direction * 7));
    });
    _loadWeek(clear: true);
  }

  void _goToThisWeek() {
    final today = vietnamToday();
    final weekStart = mondayOf(today);
    final changedWeek = weekStart != _weekStart;
    setState(() {
      _weekStart = weekStart;
      _selectedDay = today;
    });
    if (changedWeek) _loadWeek(clear: true);
  }

  int _countFor(DateTime day) =>
      _sessions.where((session) => session.day == day).length;

  @override
  Widget build(BuildContext context) {
    final today = vietnamToday();
    final selectedSessions = _sessions
        .where((session) => session.day == _selectedDay)
        .toList();
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadWeek,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Tuần học', style: theme.textTheme.titleLarge),
              ),
              TextButton.icon(
                onPressed: _goToThisWeek,
                icon: const Icon(Icons.today, size: 18),
                label: const Text('Tuần này'),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Tuần trước',
                onPressed: () => _changeWeek(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  formatWeekRange(_weekStart),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Tuần sau',
                onPressed: () => _changeWeek(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (index) {
              final day = _weekStart.add(Duration(days: index));
              final selected = day == _selectedDay;
              final isToday = day == today;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: '${fullWeekdays[index]}, ${day.day}/${day.month}',
                  child: Material(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _selectedDay = day),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Text(
                              shortWeekdays[index],
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${day.day}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: selected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 5),
                            CircleAvatar(
                              radius: 3,
                              backgroundColor: _countFor(day) > 0
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${fullWeekdays[_selectedDay.weekday - 1]}, ${_selectedDay.day}/${_selectedDay.month}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_loading && _error == null)
                Text(
                  '${selectedSessions.length} buổi',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading && _sessions.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ScheduleMessage(
              icon: Icons.wifi_off,
              message: _error!,
              action: TextButton(
                onPressed: _loadWeek,
                child: const Text('Thử lại'),
              ),
            )
          else if (selectedSessions.isEmpty)
            _ScheduleMessage(
              icon: Icons.event_available_outlined,
              message: _sessions.isEmpty
                  ? 'Tuần này chưa có lịch học.'
                  : 'Ngày này chưa có buổi học. Hãy chọn ngày có dấu chấm.',
            )
          else
            ...selectedSessions.map(
              (session) => ScheduleSessionCard(session: session),
            ),
          if (_loading && _sessions.isNotEmpty)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
