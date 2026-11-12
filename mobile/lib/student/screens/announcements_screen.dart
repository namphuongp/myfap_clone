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
    // TB1: Sinh viên mở Thông báo; tải trang đầu và hiển thị danh sách.
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
    // TB5: Chạm thông báo để tải chi tiết từ API, không chỉ dùng nội dung danh sách.
    final detail = _repository.detail(notice.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7047EB),
                      ),
                    ),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notice.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1A3C),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (notice.publishedAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EEFD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF7047EB),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(notice.publishedAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7047EB),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE8FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 14,
                      color: Color(0xFF7047EB),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _audienceLabel(notice.audience),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7047EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (notice.expiresAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_busy_outlined,
                        size: 14,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Hết hạn ${_formatDate(notice.expiresAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 28, color: Color(0xFFEDE9F7)),
          SelectableText(
            notice.content,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF383450),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Thông báo học vụ',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9BAE),
                fontWeight: FontWeight.w500,
              ),
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
          const Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: Color(0xFF7047EB),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tải được thông báo.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF757288), fontSize: 13),
          ),
        ],
      ),
    ),
  );

  String _formatDate(DateTime instant) {
    final vn = instant.toUtc().add(const Duration(hours: 7));
    return '${vn.day}/${vn.month}/${vn.year} · ${formatVietnamTime(instant)}';
  }

  String _audienceLabel(String audience) => switch (audience) {
    'ALL_STUDENTS' => 'Sinh viên',
    'ALL_LECTURERS' => 'Giảng viên',
    'ALL_HEADS' => 'Trưởng bộ môn',
    'ALL_USERS' => 'Toàn trường',
    'DEPARTMENT' => 'Bộ môn của bạn',
    'MAJOR' => 'Ngành của bạn',
    _ => 'Toàn trường',
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotices;
    return RefreshIndicator(
      color: const Color(0xFF7047EB),
      onRefresh: _loadFirstPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Thông báo dành cho sinh viên theo trường, bộ môn hoặc ngành.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B6680)),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECE7F7), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF7047EB),
                ),
                hintText: 'Tìm trong thông báo đã tải',
                hintStyle: const TextStyle(
                  color: Color(0xFF9E9BAE),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF9E9BAE),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading && _notices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7047EB)),
              ),
            )
          else if (_error != null && _notices.isEmpty)
            _emptyState(
              context,
              icon: Icons.wifi_off_rounded,
              message: _error!,
              action: TextButton(
                onPressed: _loadFirstPage,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7047EB),
                ),
                child: const Text('Thử tải lại'),
              ),
            )
          else if (filtered.isEmpty)
            _emptyState(
              context,
              icon: Icons.notifications_none_rounded,
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
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            if (_hasMore && _query.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7047EB),
                    side: const BorderSide(color: Color(0xFFDED8FA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7047EB),
                          ),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_loadingMore ? 'Đang tải...' : 'Tải thêm'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _noticeCard(BuildContext context, StudentNotice notice) {
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openNotice(notice),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE8FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: Color(0xFF7047EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1A3C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1EEFD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _audienceLabel(notice.audience),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7047EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9E9BAE),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notice.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B6680),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Color(0xFF9E9BAE),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      notice.publishedAt == null
                          ? 'Thông báo học vụ'
                          : _formatDate(notice.publishedAt!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9BAE),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        Icon(icon, size: 46, color: const Color(0xFF7047EB)),
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
