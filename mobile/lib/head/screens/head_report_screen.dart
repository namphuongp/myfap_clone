import 'package:flutter/material.dart';

import '../../core/academic/academic_widgets.dart';
import '../repositories/head_repository.dart';

/// Báo cáo tổng quan bộ môn và thống kê điểm danh theo các bộ lọc.
class HeadReportScreen extends StatefulWidget {
  const HeadReportScreen({super.key, required this.repository});
  final HeadRepository repository;
  @override
  State<HeadReportScreen> createState() => _HeadReportScreenState();
}

class _HeadReportScreenState extends State<HeadReportScreen> {
  Json? _options, _summary;
  List<Json> _items = [];
  String? _semester, _course, _lecturer, _error;
  String _group = 'SECTION';
  bool _loading = true;
  @override
  // Tự tải báo cáo lần đầu khi màn hình được khởi tạo.
  void initState() {
    super.initState();
    _load();
  }

  /// Tải song song danh mục bộ lọc, tổng quan bộ môn và báo cáo điểm danh.
  /// Chỉ cập nhật giao diện khi màn hình còn tồn tại.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final semester = {'semester_id': ?_semester};
      final results = await Future.wait([
        widget.repository.options(),
        widget.repository.report('/department/summary', semester),
        widget.repository.report('/reports/attendance', {
          ...semester,
          'course_id': ?_course,
          'lecturer_id': ?_lecturer,
          'group_by': _group,
        }),
      ]);
      if (mounted) {
        setState(() {
          _options = results[0];
          _summary = results[1];
          _items = widget.repository.rows(results[2]['items']);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Tạo bộ lọc; giá trị rỗng là Tất cả và mỗi lần đổi sẽ tải lại báo cáo.
  Widget _filter(
    String label,
    String? value,
    List<Json> rows,
    String field,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value ?? '',
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('Tất cả')),
      for (final r in rows)
        DropdownMenuItem(
          value: r['id'] as String,
          child: Text('${r[field]}', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _loading
        ? null
        : (v) {
            onChanged(v == '' ? null : v);
            _load();
          },
  );
  /// Định dạng tỷ lệ; giữ rõ trường hợp API chưa có dữ liệu để tính.
  String _rate(dynamic v) => v == null ? 'Chưa có dữ liệu' : '$v%';
  @override
  // Hiển thị bộ lọc, tổng quan, các nhóm kết quả và trạng thái tải/lỗi.
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
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Xem báo cáo bộ môn'),
              ),
              const SizedBox(height: 16),
              if (_options != null) ...[
                _filter(
                  'Học kỳ',
                  _semester,
                  widget.repository.rows(_options!['semesters']),
                  'code',
                  (v) => setState(() => _semester = v),
                ),
                const SizedBox(height: 12),
                if (_summary != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng quan ${_semester == null ? 'các học kỳ' : 'học kỳ đã chọn'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Số lớp: ${_summary!['sections']}\nSố buổi: ${_summary!['sessions']}\nBuổi đã điểm danh: ${_summary!['recorded_sessions']}\nBuổi hoàn thành: ${_summary!['completed_sessions'] ?? 0}\nBuổi hủy: ${_summary!['cancelled_sessions'] ?? 0}',
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Báo cáo giảng dạy tổng hợp',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _filter(
                  'Môn học',
                  _course,
                  widget.repository.rows(_options!['courses']),
                  'name',
                  (v) => setState(() => _course = v),
                ),
                const SizedBox(height: 16),
                _filter(
                  'Giảng viên',
                  _lecturer,
                  widget.repository.rows(_options!['lecturers']),
                  'name',
                  (v) => setState(() => _lecturer = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _group,
                  decoration: const InputDecoration(
                    labelText: 'Nhóm báo cáo theo',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SECTION', child: Text('Lớp học')),
                    DropdownMenuItem(value: 'COURSE', child: Text('Môn học')),
                    DropdownMenuItem(
                      value: 'LECTURER',
                      child: Text('Giảng viên'),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (v) {
                          setState(() => _group = v!);
                          _load();
                        },
                ),
                const SizedBox(height: 16),
                if (!_loading && _items.isEmpty)
                  const LoadMessage(
                    message: 'Chưa có dữ liệu theo bộ lọc này.',
                  ),
                for (final r in _items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['section_code'] ?? r['name'] ?? '—'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (r['course'] != null)
                            Text('${r['course']} • ${r['lecturer'] ?? '—'}'),
                          Text(
                            'Sinh viên đang học: ${r['active_students']}\nSố buổi: ${r['sessions']} • Đã điểm danh: ${r['recorded_sessions']}\nTỷ lệ có mặt / muộn: ${_rate(r['presence_rate'])}',
                          ),
                        ],
                      ),
                    ),
                  ),
                const Text(
                  'Tỷ lệ chỉ tính trên các lượt điểm danh đã ghi nhận; không coi dữ liệu chưa ghi là vắng.',
                ),
              ],
              if (_error != null) LoadMessage(message: _error!, retry: _load),
            ],
          ),
        ),
      ),
    ],
  );
}
