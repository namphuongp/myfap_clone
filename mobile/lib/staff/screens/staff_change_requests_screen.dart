import 'package:flutter/material.dart';

import '../../lecturer/widgets/lecturer_ui.dart';
import '../repositories/staff_repository.dart';

class StaffChangeRequestsScreen extends StatefulWidget {
  const StaffChangeRequestsScreen({super.key, required this.repository});
  final StaffRepository repository;

  @override
  State<StaffChangeRequestsScreen> createState() =>
      _StaffChangeRequestsScreenState();
}

class _StaffChangeRequestsScreenState extends State<StaffChangeRequestsScreen> {
  static const _statusOptions = <(String, String)>[
    ('ALL', 'Tất cả trạng thái'),
    ('PENDING', 'Chờ duyệt'),
    ('APPROVED', 'Đã duyệt'),
    ('REJECTED', 'Đã từ chối'),
    ('CANCELLED', 'Đã hủy'),
  ];

  String? _status = 'PENDING';
  bool _majorTransferTab = false;
  int _page = 1;
  bool _loading = true;
  String? _error;
  StaffPage? _data;

  String get _selectedStatusLabel =>
      _statusOptions.firstWhere((option) => option.$1 == (_status ?? 'ALL')).$2;

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
      final data = _majorTransferTab
          ? await widget.repository.majorTransfers(status: _status, page: _page)
          : await widget.repository.changeRequests(
              status: _status,
              page: _page,
            );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(StaffJson request) async {
    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangeDecisionDialog(
        repository: widget.repository,
        request: request,
        majorTransfer: _majorTransferTab,
      ),
    );
    if (decision != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'APPROVED'
                ? 'Đã duyệt yêu cầu.'
                : 'Đã từ chối yêu cầu.',
          ),
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Duyệt đơn học vụ'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loại đơn',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.event_available_outlined),
                            label: Text('Đổi lịch / phòng'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.swap_horiz),
                            label: Text('Chuyển ngành'),
                          ),
                        ],
                        selected: {_majorTransferTab},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _majorTransferTab = selection.first;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_majorTransferTab) ...[
                const SectionHeading('ĐƠN CHUYỂN NGÀNH'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Trạng thái đơn chuyển ngành'),
                        ),
                        MenuAnchor(
                          menuChildren: [
                            for (final option in _statusOptions)
                              MenuItemButton(
                                onPressed: () {
                                  setState(() {
                                    _status = option.$1 == 'ALL'
                                        ? null
                                        : option.$1;
                                    _page = 1;
                                  });
                                  _load();
                                },
                                child: Text(option.$2),
                              ),
                          ],
                          builder: (context, controller, child) =>
                              OutlinedButton(
                                onPressed: _loading ? null : controller.open,
                                child: Text(_selectedStatusLabel),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  ErrorPanel(_error!, onRetry: _load)
                else if (_data?.items.isEmpty ?? true)
                  const EmptyPanel(
                    title: 'Không có đơn chuyển ngành',
                    message: 'Đơn sinh viên gửi sẽ hiển thị tại đây.',
                    icon: Icons.swap_horiz,
                  )
                else ...[
                  for (final request in _data!.items)
                    _MajorTransferCard(
                      request: request,
                      onReview: request['status'] == 'PENDING'
                          ? () => _review(request)
                          : null,
                    ),
                  if (_page > 1 || (_data?.hasNext ?? false))
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
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trạng thái yêu cầu',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        MenuAnchor(
                          alignmentOffset: const Offset(0, 8),
                          menuChildren: [
                            for (final option in _statusOptions)
                              MenuItemButton(
                                leadingIcon: Icon(
                                  _status == option.$1
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _status = option.$1 == 'ALL'
                                        ? null
                                        : option.$1;
                                    _page = 1;
                                  });
                                  _load();
                                },
                                child: Text(option.$2),
                              ),
                          ],
                          builder: (context, controller, child) =>
                              OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => controller.isOpen
                                          ? controller.close()
                                          : controller.open(),
                                icon: const Icon(Icons.arrow_drop_down),
                                label: Text(
                                  _selectedStatusLabel,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeading('YÊU CẦU TỪ GIẢNG VIÊN'),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  ErrorPanel(_error!, onRetry: _load)
                else if (_data?.items.isEmpty ?? true)
                  const EmptyPanel(
                    title: 'Không có yêu cầu phù hợp',
                    message: 'Yêu cầu đổi lịch hoặc phòng sẽ hiển thị tại đây.',
                    icon: Icons.event_busy_outlined,
                  )
                else ...[
                  for (final request in _data!.items)
                    _ChangeRequestCard(
                      request: request,
                      onReview: request['status'] == 'PENDING'
                          ? () => _review(request)
                          : null,
                    ),
                  if (_page > 1 || (_data?.hasNext ?? false))
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
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _MajorTransferCard extends StatelessWidget {
  const _MajorTransferCard({required this.request, this.onReview});
  final StaffJson request;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final student = request['student'] is Map
        ? Map<String, dynamic>.from(request['student'] as Map)
        : const <String, dynamic>{};
    final from = request['from_major'] is Map
        ? Map<String, dynamic>.from(request['from_major'] as Map)
        : const <String, dynamic>{};
    final to = request['to_major'] is Map
        ? Map<String, dynamic>.from(request['to_major'] as Map)
        : const <String, dynamic>{};
    final status = request['status']?.toString() ?? 'PENDING';
    final statusLabel = switch (status) {
      'APPROVED' => 'Đã duyệt',
      'REJECTED' => 'Đã từ chối',
      'CANCELLED' => 'Đã hủy',
      _ => 'Chờ duyệt',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${student['name'] ?? 'Sinh viên'} · ${student['user_code'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text(statusLabel)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Từ: ${from['code'] ?? ''} · ${from['name'] ?? 'Ngành hiện tại'}',
            ),
            Text('Đến: ${to['code'] ?? ''} · ${to['name'] ?? 'Ngành đích'}'),
            if (status != 'REJECTED' && status != 'CANCELLED')
              Text(
                request['applied_at'] != null
                    ? 'Đã áp dụng chuyển ngành'
                    : 'Hiệu lực từ kỳ: ${(request['effective_semester'] as Map?)?['code'] ?? 'Kỳ tiếp theo'}',
              ),
            const SizedBox(height: 8),
            const Text('Lý do', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(request['reason']?.toString() ?? 'Không có nội dung'),
            if ((request['review_note']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Phản hồi: ${request['review_note']}'),
            ],
            if (onReview != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Xem và xử lý đơn'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeRequestCard extends StatelessWidget {
  const _ChangeRequestCard({required this.request, this.onReview});
  final StaffJson request;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final lesson = request['lesson'] is Map
        ? Map<String, dynamic>.from(request['lesson'] as Map)
        : <String, dynamic>{};
    final requester = request['requester'] is Map
        ? Map<String, dynamic>.from(request['requester'] as Map)
        : <String, dynamic>{};
    final status = request['status']?.toString() ?? 'PENDING';
    final originalDate = _dateLabel(request['original_date']);
    final proposedDate = _dateLabel(request['proposed_date']);
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    lesson['section_code']?.toString() ?? 'Lớp học phần',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: lecturerNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text(_statusLabel(status))),
              ],
            ),
            Text(
              [
                lesson['course'],
                lesson['course_code'],
              ].whereType<String>().join(' · '),
              style: const TextStyle(color: lecturerMuted),
            ),
            const SizedBox(height: 12),
            _RequestLine(
              icon: Icons.person_outline,
              label: 'Người gửi',
              value: [
                requester['name'],
                requester['user_code'],
              ].whereType<String>().join(' · '),
            ),
            const SizedBox(height: 8),
            _RequestLine(
              icon: Icons.event_outlined,
              label: 'Lịch hiện tại',
              value:
                  '$originalDate · Slot ${request['original_slot_id'] ?? '—'} · ${request['original_room_name'] ?? 'Chưa có phòng'}',
            ),
            const SizedBox(height: 8),
            _RequestLine(
              icon: Icons.edit_calendar_outlined,
              label: 'Đề xuất',
              value:
                  '$proposedDate · Slot ${request['proposed_slot_id'] ?? '—'} · ${request['proposed_room_name'] ?? 'Chưa có phòng'}',
            ),
            const SizedBox(height: 12),
            Text('Lý do', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(
              request['reason']?.toString() ?? 'Không có nội dung',
            ),
            if (request['review_note'] != null) ...[
              const SizedBox(height: 10),
              Text(
                'Phản hồi: ${request['review_note']}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            if (onReview != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Xem và xử lý yêu cầu'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String value) => switch (value) {
    'APPROVED' => 'Đã duyệt',
    'REJECTED' => 'Đã từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chờ duyệt',
  };

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Chưa có ngày';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _RequestLine extends StatelessWidget {
  const _RequestLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: lecturerMuted),
      const SizedBox(width: 8),
      SizedBox(
        width: 94,
        child: Text(label, style: const TextStyle(color: lecturerMuted)),
      ),
      Expanded(child: Text(value.isEmpty ? '—' : value)),
    ],
  );
}

class _ChangeDecisionDialog extends StatefulWidget {
  const _ChangeDecisionDialog({
    required this.repository,
    required this.request,
    this.majorTransfer = false,
  });
  final StaffRepository repository;
  final StaffJson request;
  final bool majorTransfer;

  @override
  State<_ChangeDecisionDialog> createState() => _ChangeDecisionDialogState();
}

class _ChangeDecisionDialogState extends State<_ChangeDecisionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(String decision) async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.majorTransfer) {
        await widget.repository.reviewMajorTransfer(
          widget.request,
          decision: decision,
          note: _note.text.trim(),
        );
      } else {
        await widget.repository.reviewChange(
          widget.request,
          decision: decision,
          note: _note.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(decision);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.majorTransfer
            ? 'Xử lý đơn chuyển ngành'
            : 'Xử lý yêu cầu đổi lịch / phòng',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.majorTransfer
                      ? 'Lý do của sinh viên'
                      : 'Lý do của giảng viên',
                ),
                const SizedBox(height: 6),
                Text(
                  widget.request['reason']?.toString() ?? 'Không có nội dung',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _note,
                  enabled: !_saving,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ý kiến phản hồi (bắt buộc)',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập ý kiến phản hồi'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => _submit('REJECTED'),
          child: const Text('Từ chối'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _submit('APPROVED'),
          child: Text(_saving ? 'Đang lưu...' : 'Duyệt'),
        ),
      ],
    ),
  );
}
