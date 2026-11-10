import 'package:flutter/material.dart';

import '../repositories/lecturer_repository.dart';

const statusLabels = {
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Từ chối',
  'INVALIDATED': 'Mất hiệu lực',
  'CANCELLED': 'Đã hủy',
  'SCHEDULED': 'Đã xếp lịch',
  'COMPLETED': 'Đã kết thúc',
  'PRESENT': 'Có mặt',
  'ABSENT': 'Vắng mặt',
  'LATE': 'Đi muộn',
  'EXCUSED': 'Vắng có phép',
  'NOT_RECORDED': 'Chưa ghi nhận',
};
DateTime vietnamNow() => DateTime.now().toUtc().add(const Duration(hours: 7));
String dateValue(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String displayDate(dynamic value) {
  if (value == null) return '—';
  final s = value.toString().split('T').first.split('-');
  return s.length == 3 ? '${s[2]}/${s[1]}/${s[0]}' : value.toString();
}

String sessionLabel(Json row) =>
    '${row['section_code'] ?? ''} • ${row['course'] ?? 'Buổi học'}';
String sessionDetail(Json row) =>
    '${displayDate(row['session_date'])} • Ca ${row['slot_id'] ?? '—'} • ${row['room_name'] ?? 'Chưa có phòng'}';
String minuteLabel(dynamic minute) =>
    '${((minute as num).toInt() ~/ 60).toString().padLeft(2, '0')}:${(minute.toInt() % 60).toString().padLeft(2, '0')}';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(statusLabels[status] ?? status),
    backgroundColor: switch (status) {
      'APPROVED' || 'PRESENT' => Colors.green.shade50,
      'REJECTED' || 'ABSENT' || 'CANCELLED' => Colors.red.shade50,
      _ => Theme.of(context).colorScheme.surfaceContainerHighest,
    },
  );
}

class LoadMessage extends StatelessWidget {
  const LoadMessage({super.key, required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        if (retry != null)
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class SessionBrowser extends StatefulWidget {
  const SessionBrowser({
    super.key,
    required this.repository,
    this.onSelect,
    this.attendance = false,
  });
  final LecturerRepository repository;
  final Future<void> Function(Json)? onSelect;
  final bool attendance;
  @override
  State<SessionBrowser> createState() => _SessionBrowserState();
}

class _SessionBrowserState extends State<SessionBrowser> {
  late DateTime _day;
  List<Json> _rows = [];
  String? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    final now = vietnamNow();
    _day = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.schedule(_day);
      if (mounted && generation == _generation) setState(() => _rows = rows);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pick() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _day = selected);
      _load();
    }
  }

  void _shift(int days) {
    setState(() => _day = _day.add(Duration(days: days)));
    _load();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Tuần trước',
              onPressed: () => _shift(-7),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${displayDate(dateValue(_day))} – ${displayDate(dateValue(_day.add(const Duration(days: 6))))}',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tuần sau',
              onPressed: () => _shift(7),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      const Text('Giờ Việt Nam (UTC+7)'),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            Text('Ca 1: 07:30–09:50'),
            Text('Ca 2: 10:00–12:20'),
            Text('Ca 3: 12:50–15:10'),
            Text('Ca 4: 15:20–17:40'),
          ],
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      Expanded(
        child: _error != null
            ? Center(
                child: LoadMessage(message: _error!, retry: _load),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (!_loading && _rows.isEmpty)
                      const LoadMessage(
                        message: 'Không có lịch dạy trong tuần này.',
                      ),
                    for (final row in _rows)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sessionLabel(row),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(sessionDetail(row)),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  StatusBadge(row['status'] as String),
                                  if (widget.attendance)
                                    Text(
                                      row['attendance_saved'] == true
                                          ? 'Đã điểm danh'
                                          : 'Chưa điểm danh',
                                    ),
                                ],
                              ),
                              if (widget.onSelect != null)
                                OutlinedButton.icon(
                                  onPressed: row['status'] == 'CANCELLED'
                                      ? null
                                      : () async {
                                          await widget.onSelect!(row);
                                          if (mounted) await _load();
                                        },
                                  icon: Icon(
                                    widget.attendance
                                        ? Icons.fact_check
                                        : Icons.swap_horiz,
                                  ),
                                  label: Text(
                                    widget.attendance
                                        ? 'Mở danh sách điểm danh'
                                        : 'Yêu cầu thay đổi',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
}
