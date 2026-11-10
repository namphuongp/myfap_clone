import 'package:flutter/material.dart';

import '../repositories/lecturer_repository.dart';
import '../widgets/lecturer_widgets.dart';

class LecturerRequestsScreen extends StatefulWidget {
  const LecturerRequestsScreen({
    super.key,
    required this.repository,
    this.changes = false,
  });
  final LecturerRepository repository;
  final bool changes;
  @override
  State<LecturerRequestsScreen> createState() => _LecturerRequestsScreenState();
}

class _LecturerRequestsScreenState extends State<LecturerRequestsScreen> {
  List<Json> _items = [];
  String _status = 'PENDING';
  int _page = 1, _total = 0, _generation = 0;
  bool _loading = true, _more = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.requests(
        widget.changes ? 'change' : 'leave',
        _status,
        _page,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _items = widget.repository.rows(result['items']);
          _total = result['total'] as int;
          _more = result['has_more'] == true;
        });
      }
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

  Future<void> _review(Json row, bool approve) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(row: row, approve: approve),
    );
    if (note == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.review(
        row,
        approve ? 'APPROVED' : 'REJECTED',
        note,
      );
      if (mounted) {
        showMessage(context, 'Đã cập nhật kết quả duyệt đơn');
        await _load();
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, '$e');
        await _load();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Trạng thái đơn'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tất cả')),
                  for (final s in [
                    'PENDING',
                    'APPROVED',
                    'REJECTED',
                    if (!widget.changes) 'INVALIDATED',
                    'CANCELLED',
                  ])
                    DropdownMenuItem(value: s, child: Text(statusLabels[s]!)),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() {
                          _status = v!;
                          _page = 1;
                        });
                        _load();
                      },
              ),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _loading || _saving ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      if (_loading || _saving) const LinearProgressIndicator(),
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
                    if (!_loading && _items.isEmpty)
                      const LoadMessage(message: 'Không có đơn phù hợp.'),
                    for (final row in _items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.changes
                                    ? sessionLabel(row)
                                    : '${row['requester_name'] ?? 'Sinh viên'} • ${row['requester_code'] ?? ''}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (!widget.changes) Text(sessionLabel(row)),
                              Text(
                                widget.changes
                                    ? 'Lịch gốc: ${displayDate(row['original_date'])} • Ca ${row['original_slot_id'] ?? '—'}'
                                    : 'Xin nghỉ: ${displayDate(row['requested_start'] == null ? row['session_date'] : DateTime.parse(row['requested_start'] as String).toUtc().add(const Duration(hours: 7)).toIso8601String())} • Ca ${row['slot_id'] ?? '—'}',
                              ),
                              if (widget.changes)
                                Text(
                                  'Đề xuất: ${displayDate(row['proposed_date'])} • Ca ${row['proposed_slot_id']} • ${row['proposed_room_name'] ?? '—'}',
                                ),
                              Text('Lý do: ${row['reason']}'),
                              Text(
                                'Gửi ngày: ${displayDate(row['created_at'])}',
                              ),
                              StatusBadge(row['status'] as String),
                              if (row['review_note'] != null)
                                Text(
                                  'Phản hồi: ${row['review_note']}\nNgười duyệt: ${row['reviewer_name'] ?? '—'}',
                                ),
                              if (!widget.changes && row['status'] == 'PENDING')
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    OutlinedButton(
                                      onPressed: _saving || _loading
                                          ? null
                                          : () => _review(row, false),
                                      child: const Text('Từ chối'),
                                    ),
                                    FilledButton(
                                      onPressed: _saving || _loading
                                          ? null
                                          : () => _review(row, true),
                                      child: const Text('Duyệt nghỉ'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Trang trước',
            onPressed: _page == 1 || _loading || _saving
                ? null
                : () {
                    setState(() => _page--);
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Trang $_page • $_total đơn'),
          IconButton(
            tooltip: 'Trang sau',
            onPressed: !_more || _loading || _saving
                ? null
                : () {
                    setState(() => _page++);
                    _load();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.row, required this.approve});
  final Json row;
  final bool approve;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.approve ? 'Duyệt đơn xin nghỉ?' : 'Từ chối đơn xin nghỉ?',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.row['requester_name']}\n${sessionLabel(widget.row)}\n${sessionDetail(widget.row)}',
            ),
            TextFormField(
              controller: _note,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú phản hồi'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Nhập ghi chú phản hồi'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _note.text.trim());
          }
        },
        child: const Text('Xác nhận'),
      ),
    ],
  );
}
