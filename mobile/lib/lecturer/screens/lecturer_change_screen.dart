import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../repositories/lecturer_repository.dart';
import '../utils/lecturer_dates.dart';
import '../widgets/lecturer_ui.dart';

class LecturerChangeScreen extends StatefulWidget {
  final LecturerRepository repository;
  final TeachingSession? initialSession;
  const LecturerChangeScreen({
    super.key,
    required this.repository,
    this.initialSession,
  });
  @override
  State<LecturerChangeScreen> createState() => _LecturerChangeScreenState();
}

class _LecturerChangeScreenState extends State<LecturerChangeScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  List<TeachingSession> _sessions = [];
  List<Json> _rooms = [];
  List<AcademicTerm> _terms = [];
  TeachingSession? _session;
  String? _roomId, _error;
  DateTime? _day;
  int? _slot;
  bool _loading = true, _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait<dynamic>([
        widget.repository.rooms(),
        widget.repository.terms(),
        if (widget.initialSession == null)
          widget.repository.schedule(
            vnDay(),
            vnDay().add(const Duration(days: 92)),
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _rooms = data[0] as List<Json>;
        _terms = data[1] as List<AcademicTerm>;
        _sessions = widget.initialSession == null
            ? (data[2] as List<TeachingSession>)
                  .where((s) => s.canChange)
                  .toList()
            : [widget.initialSession!];
        if (_sessions.isNotEmpty) _select(_sessions.first);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(TeachingSession session) {
    _session = session;
    _roomId = _rooms.any((r) => r['id'] == session.roomId)
        ? session.roomId
        : null;
    _day = session.day;
    _slot = session.slot;
  }

  Future<void> _pickDate() async {
    final term = _terms.where((s) => s.id == _session!.semesterId).firstOrNull;
    if (term == null) {
      setState(
        () => _error = 'Không tìm thấy học kỳ của buổi học. Hãy tải lại.',
      );
      return;
    }
    final start = vnDay(term.start).isAfter(vnDay())
        ? vnDay(term.start)
        : vnDay();
    final end = vnDay(term.end).subtract(const Duration(days: 1));
    final initial = _day!.isBefore(start) ? start : _day!;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(start.year, start.month, start.day),
      lastDate: DateTime(end.year, end.month, end.day),
      helpText: 'Chọn ngày trong học kỳ',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && mounted) {
      setState(
        () => _day = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_day == _session!.day &&
        _slot == _session!.slot &&
        _roomId == _session!.roomId) {
      setState(
        () =>
            _error = 'Hãy thay đổi ngày, slot hoặc phòng so với lịch hiện tại.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createChange(
        session: _session!,
        roomId: _roomId!,
        day: _day!,
        slot: _slot!,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu cho cán bộ duyệt')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: LecturerPage(
      title: 'Yêu cầu đổi lịch / phòng',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  ErrorPanel(_error!, onRetry: _load)
                else
                  const EmptyPanel(
                    title: 'Chưa có buổi phù hợp',
                    message: 'Chọn buổi tương lai, chưa điểm danh. Tìm các buổi xa hơn trong màn Lịch dạy.',
                    icon: Icons.edit_calendar_outlined,
                  ),
              ],
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Yêu cầu sẽ được cán bộ kiểm tra và phê duyệt. Lịch hiện tại giữ nguyên trong lúc chờ.',
                    style: TextStyle(color: lecturerMuted),
                  ),
                  const SectionHeading('Buổi học hiện tại'),
                  DropdownButtonFormField<String>(
                    initialValue: _session?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Buổi dạy'),
                    items: _sessions
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              '${dateLabel(s.day)} · Slot ${s.slot} · ${s.section}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(
                            () => _select(
                              _sessions.firstWhere((s) => s.id == value),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _session!.course,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${dateLabel(_session!.day)} · ${slotLabels[_session!.slot]}\nPhòng ${_session!.room}',
                            style: const TextStyle(color: lecturerMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SectionHeading('Lịch / phòng đề xuất'),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Ngày học: ${dateLabel(_day!)}'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey('slot-${_session!.id}'),
                    initialValue: _slot,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Slot đề xuất',
                    ),
                    items: slotLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('Slot ${e.key} · ${e.value}'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _slot = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('room-${_session!.id}'),
                    initialValue: _roomId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Phòng đề xuất',
                    ),
                    items: _rooms
                        .map(
                          (room) => DropdownMenuItem(
                            value: room['id'] as String,
                            child: Text(
                              '${room['name']} · ${room['capacity']} chỗ',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _roomId = value),
                    validator: (value) =>
                        value == null ? 'Chọn phòng học' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('change-reason'),
                    controller: _reason,
                    enabled: !_saving,
                    maxLength: 1000,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Lý do thay đổi',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập lý do thay đổi'
                        : null,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_saving ? 'Đang gửi…' : 'Gửi yêu cầu'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Đổi ngày hoặc slot sẽ làm đơn nghỉ cũ hết hiệu lực khi được duyệt. Chỉ đổi phòng vẫn giữ đơn nghỉ.',
                    style: TextStyle(color: lecturerMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
    ),
  );
}
