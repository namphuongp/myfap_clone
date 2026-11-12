import 'package:flutter/material.dart';

import '../../lecturer/widgets/lecturer_ui.dart';
import '../repositories/staff_repository.dart';

class StaffNoticesScreen extends StatefulWidget {
  const StaffNoticesScreen({super.key, required this.repository});
  final StaffRepository repository;

  @override
  State<StaffNoticesScreen> createState() => _StaffNoticesScreenState();
}

class _StaffNoticesScreenState extends State<StaffNoticesScreen> {
  String? _status;
  int _page = 1;
  bool _loading = true;
  String? _error;
  StaffPage? _data;

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
      final data = await widget.repository.notices(
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

  Future<void> _compose() async {
    // PT1: Cán bộ mở form soạn thông báo mới.
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StaffNoticeFormScreen(repository: widget.repository),
      ),
    );
    if (created == true && mounted) {
      setState(() {
        _status = 'DRAFT';
        _page = 1;
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thông báo đã được lưu thành bản nháp.'),
          ),
        );
      }
    }
  }

  String _audienceLabel(String? audience) => switch (audience) {
    'ALL_LECTURERS' => 'Chỉ giảng viên',
    'ALL_HEADS' => 'Chỉ trưởng bộ môn',
    'ALL_USERS' => 'Tất cả mọi người',
    'DEPARTMENT' => 'Theo bộ môn',
    'MAJOR' => 'Theo ngành học',
    _ => 'Toàn bộ sinh viên',
  };

  Future<void> _publish(StaffJson notice) async {
    // PT5: Xác nhận đối tượng nhận trước khi phát hành bản nháp.
    final target = _audienceLabel(notice['audience']?.toString()).toLowerCase();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phát hành thông báo?'),
        content: Text('“${notice['title']}” sẽ được gửi tới $target.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Phát hành'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.publishNotice(notice);
      if (!mounted) return;
      setState(() {
        _status = 'PUBLISHED';
        _page = 1;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã phát hành thông báo.')));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo học vụ'),
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
                color: Colors.white,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 26,
                        color: lecturerNavy,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Thông báo được gửi tới toàn bộ sinh viên. Bản nháp chỉ hiển thị với cán bộ cho đến khi phát hành.',
                          style: TextStyle(color: lecturerNavy),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _compose,
                icon: const Icon(Icons.add),
                label: const Text('Soạn thông báo'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_status),
                initialValue: _status ?? 'ALL',
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                  DropdownMenuItem(value: 'DRAFT', child: Text('Bản nháp')),
                  DropdownMenuItem(
                    value: 'PUBLISHED',
                    child: Text('Đã phát hành'),
                  ),
                  DropdownMenuItem(
                    value: 'ARCHIVED',
                    child: Text('Đã lưu trữ'),
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
              const SizedBox(height: 16),
              const SectionHeading('DANH SÁCH THÔNG BÁO'),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                ErrorPanel(_error!, onRetry: _load)
              else if (_data?.items.isEmpty ?? true)
                const EmptyPanel(
                  title: 'Chưa có thông báo',
                  message: 'Thông báo theo bộ lọc sẽ hiển thị tại đây.',
                  icon: Icons.campaign_outlined,
                )
              else ...[
                for (final notice in _data!.items)
                  _NoticeCard(
                    notice: notice,
                    onPublish: notice['status'] == 'DRAFT'
                        ? () => _publish(notice)
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
          ),
        ),
      ),
    ),
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, this.onPublish});
  final StaffJson notice;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final status = notice['status']?.toString() ?? 'DRAFT';
    final expires = DateTime.tryParse(notice['expires_at']?.toString() ?? '');
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
                    notice['title']?.toString() ?? 'Thông báo học vụ',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text(_statusLabel(status))),
              ],
            ),
            const SizedBox(height: 8),
            Text(notice['content']?.toString() ?? ''),
            const SizedBox(height: 10),
            Text(
              expires == null
                  ? 'Đối tượng: ${_audienceText(notice['audience']?.toString())}'
                  : '${_audienceText(notice['audience']?.toString())} · Hết hạn ${_dateLabel(expires)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onPublish != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onPublish,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Phát hành'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _audienceText(String? audience) => switch (audience) {
    'ALL_LECTURERS' => 'Chỉ giảng viên',
    'ALL_HEADS' => 'Chỉ trưởng bộ môn',
    'ALL_USERS' => 'Tất cả mọi người',
    'DEPARTMENT' => 'Theo bộ môn',
    'MAJOR' => 'Theo ngành học',
    _ => 'Toàn bộ sinh viên',
  };

  String _statusLabel(String status) => switch (status) {
    'PUBLISHED' => 'Đã phát hành',
    'ARCHIVED' => 'Đã lưu trữ',
    _ => 'Bản nháp',
  };

  String _dateLabel(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
}

class StaffNoticeFormScreen extends StatefulWidget {
  const StaffNoticeFormScreen({super.key, required this.repository});
  final StaffRepository repository;

  @override
  State<StaffNoticeFormScreen> createState() => _StaffNoticeFormScreenState();
}

class _StaffNoticeFormScreenState extends State<StaffNoticeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _audience = 'ALL_STUDENTS';
  DateTime? _expiresAt;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(
        () => _expiresAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
        ),
      );
    }
  }

  Future<void> _save() async {
    // PT2: Kiểm tra tiêu đề/nội dung rồi lưu bản nháp.
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createNotice(
        title: _title.text.trim(),
        content: _content.text.trim(),
        audience: _audience,
        expiresAt: _expiresAt,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Soạn thông báo')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _title,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập tiêu đề thông báo'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                maxLength: 5000,
                minLines: 7,
                maxLines: 14,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 130),
                    child: Icon(Icons.notes),
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập nội dung thông báo'
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(
                  labelText: 'Đối tượng nhận thông báo',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL_STUDENTS',
                    child: Text('Chỉ sinh viên'),
                  ),
                  DropdownMenuItem(
                    value: 'ALL_LECTURERS',
                    child: Text('Chỉ giảng viên'),
                  ),
                  DropdownMenuItem(
                    value: 'ALL_HEADS',
                    child: Text('Chỉ trưởng bộ môn'),
                  ),
                  DropdownMenuItem(
                    value: 'ALL_USERS',
                    child: Text('Tất cả mọi người'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _audience = value);
                      },
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text(
                    _expiresAt == null
                        ? 'Không đặt ngày hết hạn'
                        : 'Hết hạn ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Chọn ngày hết hạn',
                        onPressed: _saving ? null : _pickExpiry,
                        icon: const Icon(Icons.calendar_month),
                      ),
                      if (_expiresAt != null)
                        IconButton(
                          tooltip: 'Bỏ ngày hết hạn',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _expiresAt = null),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu bản nháp'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
