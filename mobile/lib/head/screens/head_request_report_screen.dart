import 'package:flutter/material.dart';

import '../../core/academic/academic_widgets.dart';
import '../repositories/head_repository.dart';

class HeadRequestReportScreen extends StatefulWidget {
  const HeadRequestReportScreen({super.key, required this.repository});
  final HeadRepository repository;

  @override
  State<HeadRequestReportScreen> createState() => _RequestReportState();
}

class _RequestReportState extends State<HeadRequestReportScreen> {
  List<Json> _semesters = [];
  Json? _report;
  String? _semester, _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // BT1: Chọn học kỳ rồi tải báo cáo đơn từ của bộ môn.
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.options(),
        widget.repository.report('/reports/requests', {
          'semester_id': ?_semester,
        }),
      ]);
      if (mounted) {
        setState(() {
          _semesters = widget.repository.rows(results[0]['semesters']);
          _report = results[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_loading) const LinearProgressIndicator(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(_semester),
                initialValue: _semester ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Học kỳ'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tất cả')),
                  for (final row in _semesters)
                    DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('${row['code']}'),
                    ),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _semester = value == '' ? null : value);
                        _load();
                      },
              ),
              const SizedBox(height: 16),
              if (_error != null)
                LoadMessage(message: _error!, retry: _load)
              else if (_report != null)
                for (final entry in const {
                  'leave_requests': 'Đơn xin nghỉ',
                  'change_requests': 'Đơn đổi lịch / phòng',
                }.entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (widget.repository
                              .rows(_report![entry.key])
                              .isEmpty)
                            const Text('Chưa có đơn'),
                          for (final row in widget.repository.rows(
                            _report![entry.key],
                          ))
                            Text(
                              '${statusLabels[row['status']] ?? row['status']}: ${row['count']}',
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
