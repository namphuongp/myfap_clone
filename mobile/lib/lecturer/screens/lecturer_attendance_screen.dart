import "../widgets/attendance_choice_row.dart";

import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../repositories/lecturer_repository.dart';
import '../utils/lecturer_dates.dart';
import '../widgets/lecturer_ui.dart';

const attendanceLabels = {
  'PRESENT': 'Có mặt',
  'ABSENT': 'Vắng mặt',
  'LATE': 'Đi muộn',
  'EXCUSED': 'Vắng có phép',
};

class LecturerAttendanceScreen extends StatefulWidget {
  final LecturerRepository repository;
  final TeachingSession session;
  const LecturerAttendanceScreen({
    super.key,
    required this.repository,
    required this.session,
  });
  @override
  State<LecturerAttendanceScreen> createState() =>
      _LecturerAttendanceScreenState();
}

class _LecturerAttendanceScreenState extends State<LecturerAttendanceScreen> {
  List<Json> _rows = [];
  int _version = 0;
  bool _loading = true, _saving = false, _dirty = false, _saved = false;
  String? _error, _sessionStatus;
  bool get _canEdit =>
      widget.session.canRecordToday && _sessionStatus != 'CANCELLED';
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
      final result = await widget.repository.attendance(widget.session.id);
      if (mounted) {
        setState(() {
          _rows = jsonList(result['rows']);
          _version = (result['version'] as num).toInt();
          _saved = result['saved'] == true;
          _sessionStatus = result['session_status'] as String;
          _dirty = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmDiscard() async =>
      !_dirty ||
      await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Bỏ thay đổi chưa lưu?'),
              content: const Text(
                'Các trạng thái điểm danh vừa chọn sẽ không được lưu.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Tiếp tục sửa'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Bỏ thay đổi'),
                ),
              ],
            ),
          ) ==
          true;
  Future<void> _reload() async {
    if (await _confirmDiscard() && mounted) _load();
  }

  Future<void> _save() async {
    if (_rows.any((row) => !attendanceLabels.containsKey(row['status']))) {
      setState(
        () => _error = 'Chọn trạng thái cho tất cả sinh viên trước khi lưu.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveAttendance(
        widget.session.id,
        _version,
        _rows
            .map(
              (row) => <String, dynamic>{
                'student_id': row['student_id'],
                'status': row['status'],
              },
            )
            .toList(),
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu điểm danh')));
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '$error\nNếu dữ liệu đã thay đổi, tải lại danh sách trước khi sửa tiếp.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && !_saving && await _confirmDiscard() && context.mounted) {
        setState(() => _dirty = false);
        Navigator.of(context).pop();
      }
    },
    child: LecturerPage(
      title: 'Điểm danh',
      actions: [
        IconButton(
          tooltip: 'Tải lại danh sách',
          onPressed: _saving || _loading ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.section,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: lecturerNavy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(widget.session.course),
                        const SizedBox(height: 10),
                        Text(
                          '${dateLabel(widget.session.day)} · Slot ${widget.session.slot} · ${widget.session.room}',
                          style: const TextStyle(color: lecturerMuted),
                        ),
                        const SizedBox(height: 12),
                        StatusPill(
                          _saved ? 'Đã ghi nhận điểm danh' : 'Chưa ghi nhận',
                          color: _saved ? lecturerGreen : lecturerMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_canEdit)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Chỉ ghi điểm danh trong ngày diễn ra buổi học, sau khi buổi học bắt đầu và trước khi buổi học bị hủy.',
                      style: TextStyle(color: lecturerMuted),
                    ),
                  ),
                if (_error != null) ErrorPanel(_error!, onRetry: _reload),
                SectionHeading('Danh sách sinh viên (${_rows.length})'),
                if (_rows.isEmpty && _error == null)
                  const EmptyPanel(
                    title: 'Chưa có sinh viên',
                    message: 'Danh sách được tính theo sinh viên thuộc lớp tại thời điểm buổi học.',
                    icon: Icons.groups_outlined,
                  ),
                ..._rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: lecturerNavy,
                              ),
                            ),
                            Text(
                              row['user_code'] as String,
                              style: const TextStyle(color: lecturerMuted),
                            ),
                            const SizedBox(height: 8),
                            AttendanceChoiceRow(
                              studentId: row['student_id'] as String,
                              status: row['status'] as String,
                              note: row['note'] as String?,
                              enabled: _canEdit && !_saving,
                              onChanged: (value) => setState(() {
                                row['status'] = value;
                                _dirty = true;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 28),
                    child: FilledButton.icon(
                      onPressed: !_canEdit || _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Đang lưu…' : 'Lưu điểm danh'),
                    ),
                  ),
                const Text(
                  'Sinh viên có đơn nghỉ được duyệt: chọn Vắng mặt sẽ được ghi là Vắng có phép.',
                  style: TextStyle(color: lecturerMuted, fontSize: 12),
                ),
              ],
            ),
    ),
  );
}
