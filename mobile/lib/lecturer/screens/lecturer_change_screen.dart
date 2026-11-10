import 'package:flutter/material.dart';

import '../repositories/lecturer_repository.dart';
import '../widgets/lecturer_widgets.dart';
import 'lecturer_requests_screen.dart';

class LecturerChangeScreen extends StatefulWidget {
  const LecturerChangeScreen({super.key, required this.repository});
  final LecturerRepository repository;
  @override
  State<LecturerChangeScreen> createState() => _LecturerChangeScreenState();
}

class _LecturerChangeScreenState extends State<LecturerChangeScreen> {
  int _revision = 0;
  Future<void> _open(Json row) async {
    if (DateTime.parse(row['start_at'] as String).isBefore(DateTime.now()) ||
        row['attendance_saved'] == true) {
      showMessage(context, 'Chỉ đổi buổi tương lai chưa điểm danh');
      return;
    }
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ChangeForm(repository: widget.repository, lesson: row),
      ),
    );
    if (sent == true && mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Tạo yêu cầu'),
            Tab(text: 'Đơn đã gửi'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              SessionBrowser(repository: widget.repository, onSelect: _open),
              LecturerRequestsScreen(
                key: ValueKey(_revision),
                repository: widget.repository,
                changes: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ChangeForm extends StatefulWidget {
  const _ChangeForm({required this.repository, required this.lesson});
  final LecturerRepository repository;
  final Json lesson;
  @override
  State<_ChangeForm> createState() => _ChangeFormState();
}

class _ChangeFormState extends State<_ChangeForm> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<Json> _rooms = [], _slots = [];
  String? _room, _error;
  late DateTime _date;
  late int _slot;
  bool _loading = true, _saving = false;
  @override
  void initState() {
    super.initState();
    _date = DateTime.parse(widget.lesson['session_date'] as String);
    _slot = widget.lesson['slot_id'] as int;
    _room = widget.lesson['room_id'] as String;
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
      final result = await Future.wait([
        widget.repository.rooms(),
        widget.repository.slots(),
      ]);
      if (mounted) {
        setState(() {
          _rooms = result[0];
          _slots = result[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    final now = vietnamNow();
    final today = DateTime(now.year, now.month, now.day);
    final day = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
    );
    if (day != null && mounted) setState(() => _date = day);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (dateValue(_date) == widget.lesson['session_date'] &&
        _slot == widget.lesson['slot_id'] &&
        _room == widget.lesson['room_id']) {
      showMessage(context, 'Hãy thay đổi ngày, ca hoặc phòng');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gửi yêu cầu cho cán bộ?'),
        content: Text(
          '${sessionLabel(widget.lesson)}\n${displayDate(dateValue(_date))} • Ca $_slot\nPhòng ${_rooms.firstWhere((r) => r['id'] == _room)['name']}\nLịch chỉ thay đổi sau khi cán bộ duyệt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.change({
        'session_id': widget.lesson['id'],
        'reason': _reason.text.trim(),
        'proposed_date': dateValue(_date),
        'proposed_slot_id': _slot,
        'proposed_room_id': _room,
      });
      if (mounted) {
        showMessage(context, 'Đã gửi yêu cầu, đang chờ cán bộ duyệt');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu đổi lịch / phòng')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty || _slots.isEmpty
          ? Center(
              child: LoadMessage(
                message: _error ?? 'Chưa có phòng hoặc ca học',
                retry: _load,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${sessionLabel(widget.lesson)}\nHiện tại: ${sessionDetail(widget.lesson)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Giữ nguyên ngày và ca nếu chỉ muốn chuyển phòng. Giờ học theo UTC+7.',
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pick,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        'Ngày đề xuất: ${displayDate(dateValue(_date))}',
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: _slot,
                      decoration: const InputDecoration(
                        labelText: 'Ca đề xuất',
                      ),
                      items: [
                        for (final s in _slots)
                          DropdownMenuItem(
                            value: s['id'] as int,
                            child: Text(
                              'Ca ${s['id']} • ${minuteLabel(s['start_minute'])}–${minuteLabel(s['end_minute'])}',
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _slot = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _rooms.any((r) => r['id'] == _room)
                          ? _room
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Phòng đề xuất',
                      ),
                      items: [
                        for (final r in _rooms)
                          DropdownMenuItem(
                            value: r['id'] as String,
                            child: Text('${r['name']} • ${r['capacity']} chỗ'),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _room = v),
                      validator: (v) => v == null ? 'Chọn phòng' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reason,
                      enabled: !_saving,
                      maxLength: 1000,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Lý do thay đổi',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nhập lý do' : null,
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_saving) const LinearProgressIndicator(),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: const Icon(Icons.send),
                      label: const Text('Gửi cán bộ duyệt'),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
