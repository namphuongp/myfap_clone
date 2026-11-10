import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../models/student_request.dart';
import '../repositories/student_request_repository.dart';
import '../utils/schedule_date.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late final StudentRequestRepository _repository;
  StudentRequestsData? _data;
  bool _loading = true;
  int _tab = 0;
  int _filter = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = StudentRequestRepository(widget.api);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.load();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Set<String> get _activeSessionRequests => {
    for (final request in _data?.leaves ?? const <StudentLeaveRequest>[])
      if (request.status == 'PENDING' || request.status == 'APPROVED')
        request.sessionId,
  };

  Future<void> _openLeaveForm() async {
    final data = _data;
    if (data == null) return;
    final active = _activeSessionRequests;
    final eligible = data.sessions
        .where((session) => !active.contains(session.id))
        .toList();
    if (eligible.isEmpty) {
      _showMessage(
        data.sessions.isEmpty
            ? 'Bạn chưa có buổi học tương lai để xin nghỉ.'
            : 'Các buổi học sắp tới đã có đơn chờ duyệt hoặc được duyệt.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    var sessionId = eligible.first.id;
    var submitting = false;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Gửi đơn xin nghỉ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn một buổi học sắp tới. Giảng viên phụ trách sẽ xem xét đơn.',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: sessionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Buổi học',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final session in eligible)
                        DropdownMenuItem(
                          value: session.id,
                          child: Text(
                            session.choiceLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setSheetState(() => sessionId = value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    enabled: !submitting,
                    maxLength: 1000,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Lý do xin nghỉ',
                      hintText: 'Nhập lý do để giảng viên xem xét',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập lý do xin nghỉ.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => submitting = true);
                            try {
                              await _repository.createLeave(
                                sessionId: sessionId,
                                reason: reasonController.text,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop(true);
                              }
                            } catch (error) {
                              if (mounted) _showMessage(error.toString());
                              if (sheetContext.mounted) {
                                setSheetState(() => submitting = false);
                              }
                            }
                          },
                    icon: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(submitting ? 'Đang gửi...' : 'Gửi đơn'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    reasonController.dispose();
    if (submitted == true && mounted) {
      _showMessage('Đã gửi đơn xin nghỉ cho giảng viên.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.event_busy_outlined),
                label: Text('Xin nghỉ'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.swap_horiz),
                label: Text('Chuyển ngành'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) =>
                setState(() => _tab = selection.first),
          ),
          const SizedBox(height: 16),
          if (_tab == 1)
            _transferUnavailable(context)
          else if (_loading && data == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (data == null)
            _messageCard(
              context,
              icon: Icons.wifi_off,
              message: _error ?? 'Không tải được đơn từ.',
              action: TextButton(
                onPressed: _load,
                child: const Text('Thử lại'),
              ),
            )
          else ...[
            _summaryCard(context, data),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _openLeaveForm,
              icon: const Icon(Icons.add),
              label: const Text('Tạo đơn xin nghỉ'),
            ),
            const SizedBox(height: 20),
            Text('Đơn đã gửi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _filterChips(),
            const SizedBox(height: 8),
            ..._filteredRequests(data)
                .map((request) => _requestCard(context, request)),
            if (_filteredRequests(data).isEmpty)
              _messageCard(
                context,
                icon: Icons.description_outlined,
                message: data.leaves.isEmpty
                    ? 'Bạn chưa gửi đơn xin nghỉ nào.'
                    : 'Không có đơn nào trong bộ lọc này.',
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Không tải được dữ liệu mới: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
          if (_tab == 0 && data != null) ...[
            const SizedBox(height: 24),
            _transferInfoCard(context),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, StudentRequestsData data) {
    final pending = data.leaves.where((row) => row.status == 'PENDING').length;
    final processed = data.leaves.length - pending;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theo dõi đơn xin nghỉ',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('$pending chờ duyệt · $processed đã xử lý'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _filterChip(0, 'Tất cả'),
        const SizedBox(width: 8),
        _filterChip(1, 'Chờ duyệt'),
        const SizedBox(width: 8),
        _filterChip(2, 'Đã xử lý'),
      ],
    ),
  );

  Widget _filterChip(int value, String label) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  List<StudentLeaveRequest> _filteredRequests(StudentRequestsData data) {
    final rows = data.leaves.where((request) {
      if (_filter == 1) return request.status == 'PENDING';
      if (_filter == 2) return request.status != 'PENDING';
      return true;
    }).toList();
    rows.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return rows;
  }

  Widget _requestCard(BuildContext context, StudentLeaveRequest request) {
    final colors = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (request.status) {
      'APPROVED' => ('Đã duyệt', colors.primary, Icons.check_circle_outline),
      'REJECTED' => ('Bị từ chối', colors.error, Icons.cancel_outlined),
      'INVALIDATED' => (
        'Không còn hiệu lực',
        colors.error,
        Icons.event_busy_outlined,
      ),
      'CANCELLED' => (
        'Đã hủy',
        colors.onSurfaceVariant,
        Icons.do_not_disturb_on_outlined,
      ),
      _ => ('Chờ giảng viên duyệt', colors.tertiary, Icons.hourglass_top),
    };
    final lesson = request.lesson ?? const <String, dynamic>{};
    final classDate = _formatDate(lesson['session_date']?.toString());
    final start = request.requestedStart;
    final end = request.requestedEnd;
    final time = start == null
        ? ''
        : '${formatVietnamTime(start)}${end == null ? '' : ' – ${formatVietnamTime(end)}'}';
    final course = lesson['course']?.toString() ?? 'Buổi học';
    final section = lesson['section_code']?.toString();
    final slot = lesson['slot_id']?.toString();

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
                    course,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (section != null) section,
                if (classDate.isNotEmpty) classDate,
                if (time.isNotEmpty) time,
                if (slot != null) 'Ca $slot',
              ].join(' · '),
            ),
            const SizedBox(height: 12),
            Text('Lý do: ${request.reason}'),
            if (request.reviewNote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Phản hồi giảng viên: ${request.reviewNote}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            if (request.createdAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Gửi ngày ${_formatDate(_dateOnly(request.createdAt!))}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';
    final pieces = value.split('-');
    if (pieces.length != 3) return value;
    final day = int.tryParse(pieces[2]);
    final month = int.tryParse(pieces[1]);
    final year = int.tryParse(pieces[0]);
    if (day == null || month == null || year == null) return value;
    final date = DateTime.utc(year, month, day);
    return '${fullWeekdays[date.weekday - 1]}, $day/$month/$year';
  }

  String _dateOnly(DateTime value) {
    final local = value.toUtc().add(const Duration(hours: 7));
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Widget _transferUnavailable(BuildContext context) =>
      _transferInfoCard(context);

  Widget _transferInfoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Đơn chuyển ngành chưa khả dụng',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Backend trên main hiện không có API tạo và theo dõi đơn chuyển ngành. Chức năng này cần được bổ sung ở backend trước khi có thể gửi đơn từ ứng dụng.',
          ),
        ],
      ),
    ),
  );

  Widget _messageCard(
    BuildContext context, {
    required IconData icon,
    required String message,
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
