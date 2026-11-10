import 'package:flutter/material.dart';

import '../repositories/lecturer_repository.dart';
import '../widgets/lecturer_widgets.dart';

class LecturerAttendanceScreen extends StatelessWidget {
  const LecturerAttendanceScreen({super.key, required this.repository});
  final LecturerRepository repository;
  @override
  Widget build(BuildContext context) => SessionBrowser(
    repository: repository,
    attendance: true,
    onSelect: (row) => Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AttendanceEditor(repository: repository, lesson: row),
      ),
    ),
  );
}

class _AttendanceEditor extends StatefulWidget {
  const _AttendanceEditor({required this.repository, required this.lesson});
  final LecturerRepository repository;
  final Json lesson;
  @override
  State<_AttendanceEditor> createState() => _AttendanceEditorState();
}

class _AttendanceEditorState extends State<_AttendanceEditor> {
  List<Json> _rows = [];
  int _version = 0;
  bool _loading = true,
      _saving = false,
      _dirty = false,
      _saved = false,
      _conflict = false;
  String? _error;
  String _sessionStatus = '';
  DateTime? _startAt;
  bool get _editable =>
      !_loading &&
      !_saving &&
      !_conflict &&
      _sessionStatus != 'CANCELLED' &&
      !(_startAt ?? DateTime.parse(widget.lesson['start_at'] as String))
          .isAfter(DateTime.now());
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _load() async {
    if (_dirty &&
        !await _confirm(
          'Tải lại danh sách?',
          'Các thay đổi điểm danh chưa lưu sẽ bị bỏ.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.attendance(
        widget.lesson['id'] as String,
      );
      if (mounted) {
        setState(() {
          _rows = widget.repository.rows(data['rows']);
          _version = data['version'] as int;
          _sessionStatus = data['session_status'] as String;
          _startAt = DateTime.parse(
            (data['start_at'] ?? widget.lesson['start_at']) as String,
          );
          _saved = data['saved'] == true;
          _dirty = false;
          _conflict = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _conflict = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_rows.any((r) => r['status'] == 'NOT_RECORDED')) {
      showMessage(
        context,
        'Chọn trạng thái cho tất cả sinh viên trước khi lưu',
      );
      return;
    }
    if (!await _confirm(
      'Lưu điểm danh?',
      'Lưu kết quả cho ${_rows.length} sinh viên. Mỗi lần cập nhật đều được lưu lịch sử.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveAttendance(
        widget.lesson['id'] as String,
        _version,
        [
          for (final r in _rows)
            {'student_id': r['student_id'], 'status': r['status']},
        ],
      );
      if (mounted) {
        setState(() => _dirty = false);
        showMessage(context, 'Đã lưu điểm danh');
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _conflict = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop &&
          !_saving &&
          await _confirm(
            'Rời màn hình?',
            'Bỏ các thay đổi điểm danh chưa lưu?',
          ) &&
          mounted) {
        setState(() => _dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh sinh viên'),
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  sessionLabel(widget.lesson),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(sessionDetail(widget.lesson)),
                Text(_saved ? 'Đã lưu điểm danh' : 'Chưa ghi nhận điểm danh'),
                if (!_editable && !_loading)
                  const Text(
                    'Chỉ ghi điểm danh sau khi buổi học bắt đầu; buổi bị hủy không được ghi.',
                  ),
              ],
            ),
          ),
          if (_loading || _saving) const LinearProgressIndicator(),
          if (_error != null)
            LoadMessage(
              message:
                  '$_error${_conflict ? '\nTải lại dữ liệu trước khi lưu tiếp.' : ''}',
              retry: _saving ? null : _load,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_loading && _rows.isEmpty)
                  const LoadMessage(
                    message: 'Buổi học chưa có sinh viên trong danh sách.',
                  ),
                for (final row in _rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['name']} • ${row['user_code']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (row['note'] != null)
                            Text(
                              '${row['note']} (đơn nghỉ đã duyệt)',
                              style: TextStyle(color: Colors.green.shade800),
                            ),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              '${row['student_id']}-$_version-${row['status']}',
                            ),
                            initialValue: row['status'] as String,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Kết quả điểm danh',
                            ),
                            items: [
                              for (final s in [
                                'NOT_RECORDED',
                                'PRESENT',
                                'ABSENT',
                                'LATE',
                                'EXCUSED',
                              ])
                                DropdownMenuItem(
                                  value: s,
                                  child: Text(statusLabels[s]!),
                                ),
                            ],
                            onChanged: !_editable
                                ? null
                                : (v) => setState(() {
                                    row['status'] = v;
                                    _dirty = true;
                                  }),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _editable && _dirty && _rows.isNotEmpty
                      ? _save
                      : null,
                  icon: const Icon(Icons.save),
                  label: Text('Lưu điểm danh (${_rows.length} sinh viên)'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
