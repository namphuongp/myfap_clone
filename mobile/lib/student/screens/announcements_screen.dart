import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../models/student_notice.dart';
import '../repositories/student_notice_repository.dart';
import '../utils/schedule_date.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const _pageSize = 20;

  late final StudentNoticeRepository _repository;
  final _searchController = TextEditingController();
  List<StudentNotice> _notices = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = StudentNoticeRepository(widget.api);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFirstPage();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notices = await _repository.list();
      if (!mounted) return;
      setState(() {
        _notices = notices;
        _page = 1;
        _hasMore = notices.length == _pageSize;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final nextPage = _page + 1;
      final notices = await _repository.list(page: nextPage);
      if (!mounted) return;
      setState(() {
        _notices = [..._notices, ...notices];
        _page = nextPage;
        _hasMore = notices.length == _pageSize;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<StudentNotice> get _filteredNotices {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _notices;
    return _notices
        .where(
          (notice) =>
              notice.title.toLowerCase().contains(query) ||
              notice.content.toLowerCase().contains(query),
        )
        .toList();
  }

  void _openNotice(StudentNotice notice) {
    final detail = _repository.detail(notice.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: FutureBuilder<StudentNotice>(
              future: detail,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _detailError(context, snapshot.error.toString());
                }
                return _noticeDetail(context, snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _noticeDetail(BuildContext context, StudentNotice notice) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (notice.publishedAt != null)
                Chip(
                  avatar: const Icon(Icons.schedule, size: 16),
                  label: Text(_formatDate(notice.publishedAt!)),
                ),
              Chip(
                avatar: const Icon(Icons.groups_outlined, size: 16),
                label: Text(_audienceLabel(notice.audience)),
              ),
              if (notice.expiresAt != null)
                Chip(
                  avatar: const Icon(Icons.event_busy_outlined, size: 16),
                  label: Text('Hết hạn ${_formatDate(notice.expiresAt!)}'),
                ),
            ],
          ),
          const Divider(height: 28),
          SelectableText(
            notice.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Thông báo học vụ',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailError(BuildContext context, String error) => SizedBox(
    height: 220,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('Không tải được thông báo.'),
          const SizedBox(height: 6),
          Text(error, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  String _formatDate(DateTime instant) {
    final vn = instant.toUtc().add(const Duration(hours: 7));
    return '${vn.day}/${vn.month}/${vn.year} · ${formatVietnamTime(instant)}';
  }

  String _audienceLabel(String audience) => switch (audience) {
    'DEPARTMENT' => 'Bộ môn của bạn',
    'MAJOR' => 'Ngành của bạn',
    _ => 'Toàn trường',
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotices;
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Thông báo dành cho sinh viên theo trường, bộ môn hoặc ngành.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm trong thông báo đã tải',
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading && _notices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _notices.isEmpty)
            _emptyState(
              context,
              icon: Icons.wifi_off_outlined,
              message: _error!,
              action: TextButton(
                onPressed: _loadFirstPage,
                child: const Text('Thử tải lại'),
              ),
            )
          else if (filtered.isEmpty)
            _emptyState(
              context,
              icon: Icons.notifications_none,
              message: _notices.isEmpty
                  ? 'Hiện chưa có thông báo học vụ dành cho bạn.'
                  : 'Không tìm thấy thông báo phù hợp.',
            )
          else ...[
            for (final notice in filtered) _noticeCard(context, notice),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Không tải thêm được thông báo: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_hasMore && _query.isEmpty)
              OutlinedButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Đang tải...' : 'Tải thêm'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _noticeCard(BuildContext context, StudentNotice notice) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNotice(notice),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notice.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                notice.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      notice.publishedAt == null
                          ? 'Thông báo học vụ'
                          : _formatDate(notice.publishedAt!),
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    _audienceLabel(notice.audience),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
