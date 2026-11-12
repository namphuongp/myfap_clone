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
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  const Text(
                    'Gửi đơn xin nghỉ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1A3C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: sessionId,
                    decoration: InputDecoration(
                      labelText: 'Buổi học xin nghỉ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: eligible.map((session) {
                      final day = vietnamCalendarDate(session.startAt);
                      return DropdownMenuItem(
                        value: session.id,
                        child: Text(
                          '${session.course} · ${day.day}/${day.month} · Ca ${session.slotId ?? 1}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
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
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Lý do xin nghỉ',
                      hintText: 'Nhập chi tiết lý do...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 5) {
                        return 'Lý do cần tối thiểu 5 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7047EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            setSheetState(() => submitting = true);
                            try {
                              await _repository.createLeave(
                                sessionId: sessionId,
                                reason: reasonController.text.trim(),
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, true);
                              }
                            } catch (error) {
                              if (sheetContext.mounted) {
                                _showMessage(error.toString());
                              }
                              setSheetState(() => submitting = false);
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Gửi đơn',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (submitted == true) {
      _showMessage('Đã gửi đơn xin nghỉ thành công.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return RefreshIndicator(
      color: const Color(0xFF7047EB),
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildTabs(),
          const SizedBox(height: 16),
          if (_tab == 1 && _loading && data == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7047EB)),
              ),
            )
          else if (_tab == 1 && data == null)
            _messageCard(
              context,
              icon: Icons.wifi_off_rounded,
              message: _error ?? 'Không tải được đơn chuyển ngành.',
              action: TextButton(onPressed: _load, child: const Text('Thử lại')),
            )
          else if (_tab == 1)
            _transferContent(context, data!)
          else if (_loading && data == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7047EB)),
              ),
            )
          else if (data == null)
            _messageCard(
              context,
              icon: Icons.wifi_off_rounded,
              message: _error ?? 'Không tải được đơn từ.',
              action: TextButton(
                onPressed: _load,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7047EB),
                ),
                child: const Text('Thử lại'),
              ),
            )
          else ...[
            _summaryCard(context, data),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF835DF8), Color(0xFF6B41EB)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x306B41EB),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _loading ? null : _openLeaveForm,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tạo đơn xin nghỉ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đơn đã gửi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1A3C),
              ),
            ),
            const SizedBox(height: 10),
            _filterChips(),
            const SizedBox(height: 12),
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
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF7047EB)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _transferContent(BuildContext context, StudentRequestsData data) {
    final pending = data.majorTransfers.any((row) => row['status'] == 'PENDING');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.school_outlined, color: Color(0xFF7047EB)),
            title: const Text('Ngành hiện tại'),
            subtitle: Text(data.currentMajorName ?? 'Chưa cập nhật'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading || pending ? null : () => _openMajorTransferForm(data),
          icon: const Icon(Icons.add),
          label: Text(pending ? 'Đơn chuyển ngành đang chờ duyệt' : 'Tạo đơn chuyển ngành'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Đơn chuyển ngành đã gửi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (data.majorTransfers.isEmpty)
          _messageCard(context, icon: Icons.swap_horiz, message: 'Bạn chưa gửi đơn chuyển ngành nào.')
        else
          for (final request in data.majorTransfers)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${(request['from_major'] as Map?)?['name'] ?? 'Ngành hiện tại'} → ${(request['to_major'] as Map?)?['name'] ?? 'Ngành đích'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Chip(label: Text(_transferStatus(request['status']?.toString() ?? 'PENDING'))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Lý do: ${request['reason'] ?? ''}'),
                    if ((request['review_note']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Phản hồi: ${request['review_note']}'),
                    ],
                  ],
                ),
              ),
            ),
        if (_error != null)
          Text('Không tải được dữ liệu mới: $_error', style: const TextStyle(color: Color(0xFFDC2626))),
      ],
    );
  }

  String _transferStatus(String status) => switch (status) {
    'APPROVED' => 'Đã duyệt',
    'REJECTED' => 'Từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chờ duyệt',
  };

  Future<void> _openMajorTransferForm(StudentRequestsData data) async {
    final options = data.majors
        .where((row) => row['id']?.toString() != data.currentMajorId)
        .toList();
    if (options.isEmpty) {
      _showMessage('Không có ngành đích đang hoạt động để chọn.');
      return;
    }
    final key = GlobalKey<FormState>();
    final reason = TextEditingController();
    var targetId = options.first['id'].toString();
    var saving = false;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: Form(
              key: key,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text('Tạo đơn chuyển ngành', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: targetId,
                    decoration: const InputDecoration(labelText: 'Ngành muốn chuyển đến'),
                    items: options.map((row) => DropdownMenuItem(value: row['id'].toString(), child: Text('${row['code']} · ${row['name']}'))).toList(),
                    onChanged: saving ? null : (value) { if (value != null) setSheetState(() => targetId = value); },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reason,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(labelText: 'Lý do chuyển ngành'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Nhập lý do chuyển ngành' : null,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: saving ? null : () async {
                      if (!key.currentState!.validate()) return;
                      setSheetState(() => saving = true);
                      try {
                        await _repository.createMajorTransfer(majorId: targetId, reason: reason.text);
                        if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                      } catch (error) {
                        if (sheetContext.mounted) _showMessage(error.toString());
                        setSheetState(() => saving = false);
                      }
                    },
                    child: Text(saving ? 'Đang gửi...' : 'Gửi đơn'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    reason.dispose();
    if (created == true && mounted) {
      _showMessage('Đã gửi đơn chuyển ngành.');
      await _load();
    }
  }

  Widget _buildTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEBFA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = 0),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: _tab == 0
                      ? const LinearGradient(
                          colors: [Color(0xFF835DF8), Color(0xFF6B41EB)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _tab == 0
                      ? const [
                          BoxShadow(
                            color: Color(0x356B41EB),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 16,
                      color: _tab == 0 ? Colors.white : const Color(0xFF645E7A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Xin nghỉ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _tab == 0
                            ? Colors.white
                            : const Color(0xFF645E7A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = 1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: _tab == 1
                      ? const LinearGradient(
                          colors: [Color(0xFF835DF8), Color(0xFF6B41EB)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _tab == 1
                      ? const [
                          BoxShadow(
                            color: Color(0x356B41EB),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: _tab == 1 ? Colors.white : const Color(0xFF645E7A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chuyển ngành',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _tab == 1
                            ? Colors.white
                            : const Color(0xFF645E7A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, StudentRequestsData data) {
    final pending = data.leaves.where((row) => row.status == 'PENDING').length;
    final processed = data.leaves.length - pending;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B64F6), Color(0xFF6B40E8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x286B40E8),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theo dõi đơn xin nghỉ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pending chờ duyệt · $processed đã xử lý',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _filterChip(int value, String label) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFEDE8FE),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF7047EB) : const Color(0xFF645E7A),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF7047EB) : const Color(0xFFECE7F7),
        ),
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

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
    final (label, color, bg, icon) = switch (request.status) {
      'APPROVED' => (
        'Đã duyệt',
        const Color(0xFF16A34A),
        const Color(0xFFE8F7EE),
        Icons.check_circle_outline_rounded,
      ),
      'REJECTED' => (
        'Bị từ chối',
        const Color(0xFFDC2626),
        const Color(0xFFFEE2E2),
        Icons.cancel_outlined,
      ),
      'INVALIDATED' => (
        'Không còn hiệu lực',
        const Color(0xFFDC2626),
        const Color(0xFFFEE2E2),
        Icons.event_busy_outlined,
      ),
      'CANCELLED' => (
        'Đã hủy',
        const Color(0xFF757288),
        const Color(0xFFF3F2F7),
        Icons.do_not_disturb_on_outlined,
      ),
      _ => (
        'Chờ duyệt',
        const Color(0xFFD97706),
        const Color(0xFFFEF3C7),
        Icons.hourglass_top_rounded,
      ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9F7), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1A3C),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              ?section,
              if (classDate.isNotEmpty) classDate,
              if (time.isNotEmpty) time,
              if (slot != null) 'Ca $slot',
            ].join(' · '),
            style: const TextStyle(fontSize: 13, color: Color(0xFF757288)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 16,
                  color: Color(0xFF7047EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lý do: ${request.reason}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF383450),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (request.reviewNote?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.chat_outlined,
                    size: 16,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phản hồi giảng viên: ${request.reviewNote}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (request.createdAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Gửi ngày ${_formatDate(_dateOnly(request.createdAt!))}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9BAE)),
            ),
          ],
        ],
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

  Widget _messageCard(
    BuildContext context, {
    required IconData icon,
    required String message,
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 44, color: const Color(0xFF7047EB)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF645E7A), fontSize: 14),
        ),
        if (action != null) ...[const SizedBox(height: 8), action],
      ],
    ),
  );
}
