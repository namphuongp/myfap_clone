import 'package:flutter/material.dart';

import '../../core/academic/academic_widgets.dart';
import '../../core/academic/request_list.dart';
import '../repositories/head_repository.dart';

class HeadRoomScreen extends StatefulWidget {
  const HeadRoomScreen({super.key, required this.repository});
  final HeadRepository repository;
  @override
  State<HeadRoomScreen> createState() => _HeadRoomScreenState();
}

class _HeadRoomScreenState extends State<HeadRoomScreen> {
  int _revision = 0;
  Future<void> _open(Json lesson) async {
    if (lesson['status'] != 'SCHEDULED' ||
        lesson['attendance_saved'] == true ||
        DateTime.parse(lesson['start_at'] as String).isBefore(DateTime.now()) ||
        lesson['slot_id'] == null) {
      showMessage(
        context,
        'Chỉ chuyển phòng cho buổi tương lai chưa điểm danh, có ca hợp lệ',
      );
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RoomDialog(repository: widget.repository, lesson: lesson),
    );
    if (changed == true && mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Gửi đơn chuyển phòng'),
            Tab(text: 'Đơn đã gửi'),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Chỉ đổi phòng; ngày và ca giữ nguyên. STAFF duyệt trước khi lịch được cập nhật.',
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              SessionBrowser(
                repository: widget.repository,
                onSelect: _open,
                actionLabel: 'Xin chuyển phòng',
              ),
              RequestList(
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

class _RoomDialog extends StatefulWidget {
  const _RoomDialog({required this.repository, required this.lesson});
  final HeadRepository repository;
  final Json lesson;
  @override
  State<_RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<_RoomDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  List<Json> _rooms = [];
  String? _room, _error;
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
      final rooms = await widget.repository.rooms();
      if (mounted) {
        setState(
          () => _rooms = rooms
              .where(
                (r) =>
                    r['id'] != widget.lesson['room_id'] &&
                    (r['capacity'] as num) >= 30,
              )
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gửi đơn cho STAFF duyệt?'),
        content: Text(
          '${sessionLabel(widget.lesson)}\n${sessionDetail(widget.lesson)}\nPhòng đề xuất: ${_rooms.firstWhere((r) => r['id'] == _room)['name']}\nNgày và ca không thay đổi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận gửi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.change({
        'session_id': widget.lesson['id'],
        'proposed_room_id': _room,
        'proposed_date': widget.lesson['session_date'],
        'proposed_slot_id': widget.lesson['slot_id'],
        'reason': _reason.text.trim(),
      });
      if (mounted) {
        showMessage(context, 'Đã gửi đơn chuyển phòng, đang chờ STAFF duyệt');
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
    child: AlertDialog(
      title: const Text('Đơn xin chuyển phòng'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sessionLabel(widget.lesson),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Lịch giữ nguyên: ${sessionDetail(widget.lesson)}'),
                if (_loading) const LinearProgressIndicator(),
                if (!_loading && _rooms.isEmpty)
                  const Text(
                    'Chưa có phòng khác đủ 30 chỗ. Liên hệ cán bộ để bổ sung phòng.',
                  ),
                if (!_loading && _rooms.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _room,
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
                    validator: (v) => v == null ? 'Chọn phòng đề xuất' : null,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  enabled: !_saving,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Lý do chuyển phòng',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nhập lý do chuyển phòng'
                      : null,
                ),
                if (_error != null)
                  LoadMessage(message: _error!, retry: _saving ? null : _load),
                if (_saving) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: _loading || _saving || _rooms.isEmpty ? null : _send,
          child: const Text('Gửi đơn'),
        ),
      ],
    ),
  );
}
