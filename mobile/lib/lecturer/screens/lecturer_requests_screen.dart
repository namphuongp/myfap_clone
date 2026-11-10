import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../repositories/lecturer_repository.dart';
import '../utils/lecturer_dates.dart';
import '../widgets/lecturer_ui.dart';

class LecturerRequestsScreen extends StatefulWidget {
  final LecturerRepository repository;
  const LecturerRequestsScreen({super.key, required this.repository});
  @override
  State<LecturerRequestsScreen> createState() => _LecturerRequestsScreenState();
}

class _LecturerRequestsScreenState extends State<LecturerRequestsScreen> {
  String? _status = 'PENDING', _error;
  int _page = 1, _generation = 0;
  bool _loading = true;
  RequestPage? _data;
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
      final data = await widget.repository.leaveRequests(
        status: _status,
        page: _page,
      );
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _review(Json row) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Theme(
        data: Theme.of(context),
        child: LeaveDecisionDialog(repository: widget.repository, request: row),
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật đơn nghỉ')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => LecturerPage(
    title: 'Duyệt đơn nghỉ',
    actions: [
      IconButton(
        tooltip: 'Tải lại đơn',
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(_status),
            initialValue: _status ?? 'ALL',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Trạng thái đơn'),
            items: [
              const DropdownMenuItem(
                value: 'ALL',
                child: Text('Tất cả trạng thái'),
              ),
              ...requestStatusLabels.entries.map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _status = value == 'ALL' ? null : value;
                _page = 1;
              });
              _load();
            },
          ),
          const SectionHeading('Đơn nghỉ của sinh viên'),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorPanel(_error!, onRetry: _load)
          else if (_data?.items.isEmpty ?? true)
            const EmptyPanel(
              title: 'Không có đơn phù hợp',
              message:
                  'Đơn xin nghỉ của lớp bạn phụ trách sẽ xuất hiện tại đây.',
              icon: Icons.assignment_outlined,
            )
          else
            ..._data!.items.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: LeaveRequestCard(
                  row: row,
                  onReview: row['status'] == 'PENDING'
                      ? () => _review(row)
                      : null,
                ),
              ),
            ),
          if (!_loading &&
              _error == null &&
              (_page > 1 || (_data?.hasNext ?? false)))
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _page > 1
                      ? () {
                          setState(() => _page--);
                          _load();
                        }
                      : null,
                  child: const Text('Trang trước'),
                ),
                Text('Trang $_page'),
                TextButton(
                  onPressed: _data?.hasNext == true
                      ? () {
                          setState(() => _page++);
                          _load();
                        }
                      : null,
                  child: const Text('Trang sau'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class LeaveRequestCard extends StatelessWidget {
  final Json row;
  final VoidCallback? onReview;
  const LeaveRequestCard({super.key, required this.row, this.onReview});
  @override
  Widget build(BuildContext context) {
    final lesson = row['lesson'] is Map
        ? jsonObject(row['lesson'])
        : <String, dynamic>{};
    final requester = row['requester'] is Map
        ? jsonObject(row['requester'])
        : <String, dynamic>{};
    final status = row['status'] as String;
    final date = row['session_date'] as String?;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: status == 'PENDING'
                  ? lecturerOrange
                  : status == 'APPROVED'
                  ? lecturerGreen
                  : lecturerMuted,
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(
              requestStatusLabels[status] ?? status,
              color: status == 'APPROVED' ? lecturerGreen : lecturerNavy,
            ),
            const SizedBox(height: 12),
            Text(
              requester['name']?.toString() ?? 'Sinh viên',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: lecturerNavy,
              ),
            ),
            if (requester['user_code'] != null)
              Text(
                requester['user_code'] as String,
                style: const TextStyle(color: lecturerMuted),
              ),
            const SizedBox(height: 8),
            Text(
              [
                lesson['section_code'],
                lesson['course'],
              ].whereType<String>().join(' · '),
              style: const TextStyle(color: lecturerMuted),
            ),
            if (date != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Xin nghỉ: ${dateLabel(DateTime.parse(date))} · Slot ${row['slot_id']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 12),
            Text(row['reason'] as String),
            if (row['review_note'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Phản hồi: ${row['review_note']}',
                  style: const TextStyle(color: lecturerMuted),
                ),
              ),
            if (onReview != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: OutlinedButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Xem và duyệt đơn'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LeaveDecisionDialog extends StatefulWidget {
  final LecturerRepository repository;
  final Json request;
  const LeaveDecisionDialog({
    super.key,
    required this.repository,
    required this.request,
  });
  @override
  State<LeaveDecisionDialog> createState() => _LeaveDecisionDialogState();
}

class _LeaveDecisionDialogState extends State<LeaveDecisionDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  String? _error;
  bool _saving = false, _conflict = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(String decision) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.reviewLeave(
        widget.request,
        decision,
        _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              '$error\nĐóng hộp thoại và tải lại danh sách nếu đơn đã thay đổi.';
          _conflict = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Duyệt đơn xin nghỉ'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.request['reason'] as String),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('leave-review-note'),
                  controller: _note,
                  enabled: !_saving && !_conflict,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ý kiến phản hồi',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập ý kiến phản hồi'
                      : null,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Duyệt nghỉ chỉ thêm ghi chú Nghỉ có phép, không tự ghi Có mặt.',
                  style: TextStyle(color: lecturerMuted, fontSize: 12),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Đóng'),
        ),
        TextButton(
          onPressed: _saving || _conflict ? null : () => _submit('REJECTED'),
          child: const Text('Từ chối'),
        ),
        FilledButton(
          onPressed: _saving || _conflict ? null : () => _submit('APPROVED'),
          child: Text(_saving ? 'Đang xử lý…' : 'Duyệt nghỉ'),
        ),
      ],
    ),
  );
}
