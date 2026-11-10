import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../models/enrollment_data.dart';
import '../repositories/enrollment_repository.dart';
import '../utils/schedule_date.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({
    super.key,
    required this.api,
    required this.studentId,
    required this.onEnrollmentChanged,
  });

  final ApiClient api;
  final String studentId;
  final VoidCallback onEnrollmentChanged;

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  late final EnrollmentRepository _repository;
  EnrollmentData? _data;
  bool _loading = true;
  bool _submitting = false;
  int _tab = 0;
  String _search = '';
  String _semesterId = '';

  @override
  void initState() {
    super.initState();
    _repository = EnrollmentRepository(widget.api);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repository.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        if (_semesterId.isNotEmpty &&
            !data.available.any((row) => row.semesterId == _semesterId)) {
          _semesterId = '';
        }
      });
    } catch (error) {
      if (mounted) _showMessage(error.toString());
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

  bool _alreadyStudies(SectionOption section) =>
      _data?.enrollments.any(
        (row) =>
            row.isActive &&
            row.courseId == section.courseId &&
            row.semesterId == section.semesterId,
      ) ??
      false;

  Future<void> _register(SectionOption section) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _repository.register(section.id);
      if (!mounted) return;
      _showMessage('Đã đăng ký lớp ${section.code}.');
      setState(() => _tab = 0);
      widget.onEnrollmentChanged();
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
        await _load();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _withdraw(EnrollmentRecord enrollment) async {
    final section = _data?.mySections[enrollment.sectionId];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rút lớp học?'),
        content: Text(
          'Bạn sẽ rút khỏi ${section?.code ?? 'lớp này'}. '
          'Lịch học của lớp sẽ không còn trong lịch cá nhân.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rút lớp'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _repository.withdraw(
        sectionId: enrollment.sectionId,
        studentId: widget.studentId,
        version: enrollment.version,
      );
      if (!mounted) return;
      _showMessage('Đã rút lớp.');
      widget.onEnrollmentChanged();
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
        await _load();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSection(SectionOption section) {
    final alreadyStudies = _alreadyStudies(section);
    final canRegister = !alreadyStudies && (section.remaining ?? 0) > 0;
    final sessions = _repository.sessions(section.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                section.courseName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1A3C),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE8FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      section.code,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7047EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    section.semesterCode,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757288),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (section.remaining ?? 0) > 0
                      ? const Color(0xFFE8F7EE)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (section.remaining ?? 0) > 0
                          ? Icons.people_outline_rounded
                          : Icons.person_off_outlined,
                      size: 16,
                      color: (section.remaining ?? 0) > 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Còn ${section.remaining ?? 0} chỗ trống',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: (section.remaining ?? 0) > 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lịch học sắp tới',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1A3C),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<SectionSessionPreview>>(
                future: sessions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7047EB),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(snapshot.error.toString()),
                    );
                  }
                  final upcoming = snapshot.data!
                      .where(
                        (row) =>
                            row.status == 'SCHEDULED' &&
                            row.startAt.isAfter(DateTime.now()),
                      )
                      .take(5)
                      .toList();
                  if (upcoming.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Chưa có buổi học sắp tới.'),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: upcoming.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFEDE9F7),
                          ),
                          itemBuilder: (context, index) {
                            final row = upcoming[index];
                            final day = vietnamCalendarDate(row.startAt);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1EEFD),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: Color(0xFF7047EB),
                                ),
                              ),
                              title: Text(
                                '${fullWeekdays[day.weekday - 1]}, ${day.day}/${day.month}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${formatVietnamTime(row.startAt)} – ${formatVietnamTime(row.endAt)}',
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7047EB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: canRegister
                            ? () {
                                Navigator.pop(sheetContext);
                                _register(section);
                              }
                            : null,
                        child: Text(
                          alreadyStudies
                              ? 'Đã đăng ký môn này'
                              : canRegister
                              ? 'Đăng ký lớp'
                              : 'Lớp đã đầy',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          // Segmented tab control
          _buildTabs(),
          const SizedBox(height: 16),
          if (_loading && data == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7047EB)),
              ),
            )
          else if (data == null)
            Center(
              child: TextButton(
                onPressed: _load,
                child: const Text('Không tải được dữ liệu. Thử lại'),
              ),
            )
          else if (_tab == 0)
            ..._myClasses(data)
          else
            ..._availableClasses(data),
          if (_loading && data != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7047EB)),
              ),
            ),
        ],
      ),
    );
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
                child: Text(
                  'Đã đăng ký',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _tab == 0 ? Colors.white : const Color(0xFF645E7A),
                  ),
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
                child: Text(
                  'Tìm lớp',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _tab == 1 ? Colors.white : const Color(0xFF645E7A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _myClasses(EnrollmentData data) {
    if (data.enrollments.isEmpty) {
      return [
        _emptyState(
          Icons.school_outlined,
          'Bạn chưa đăng ký lớp nào.',
          action: TextButton(
            onPressed: () => setState(() => _tab = 1),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7047EB),
            ),
            child: const Text('Tìm lớp để đăng ký'),
          ),
        ),
      ];
    }
    final records = [...data.enrollments]
      ..sort((a, b) => a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1));
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Lớp của tôi',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1A3C),
          ),
        ),
      ),
      const SizedBox(height: 8),
      for (final row in records)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.mySections[row.sectionId]?.courseName ??
                          data.courseNames[row.courseId] ??
                          'Môn học',
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
                      color: row.isActive
                          ? const Color(0xFFE8F7EE)
                          : const Color(0xFFF3F2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      row.isActive ? 'Đang học' : 'Đã rút',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: row.isActive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF757288),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE8FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.mySections[row.sectionId]?.code ?? 'Lớp đã rút',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7047EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.mySections[row.sectionId]?.semesterCode ??
                        data.semesterNames[row.semesterId] ??
                        'Học kỳ',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757288),
                    ),
                  ),
                ],
              ),
              if (row.isActive) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7047EB),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () => _showAttendanceHistory(
                        row,
                        data.mySections[row.sectionId]?.courseName ??
                            data.courseNames[row.courseId] ??
                            'Môn học',
                      ),
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text(
                        'Xem điểm danh',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                      ),
                      onPressed: _submitting ? null : () => _withdraw(row),
                      child: const Text('Rút lớp'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _availableClasses(EnrollmentData data) {
    if (data.availableError != null) {
      return [
        _emptyState(
          Icons.info_outline,
          data.availableError!,
          action: TextButton(
            onPressed: _load,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7047EB),
            ),
            child: const Text('Thử lại'),
          ),
        ),
      ];
    }
    final semesters = <String, String>{
      for (final row in data.available) row.semesterId: row.semesterCode,
    };
    final query = _search.trim().toLowerCase();
    final filtered = data.available.where((row) {
      if (_semesterId.isNotEmpty && row.semesterId != _semesterId) {
        return false;
      }
      if (query.isEmpty) return true;
      return '${row.courseName} ${row.courseCode} ${row.code}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return [
      const Text(
        'Các lớp thuộc ngành của bạn đang mở đăng ký và có lịch học sắp tới.',
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
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: Color(0xFF7047EB)),
            hintText: 'Tìm môn hoặc mã lớp',
            hintStyle: TextStyle(color: Color(0xFF9E9BAE), fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
      ),
      if (semesters.length > 1) ...[
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Tất cả kỳ'),
                selected: _semesterId.isEmpty,
                selectedColor: const Color(0xFFEDE8FE),
                labelStyle: TextStyle(
                  color: _semesterId.isEmpty
                      ? const Color(0xFF7047EB)
                      : const Color(0xFF645E7A),
                  fontWeight: _semesterId.isEmpty
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _semesterId.isEmpty
                        ? const Color(0xFF7047EB)
                        : const Color(0xFFECE7F7),
                  ),
                ),
                onSelected: (_) => setState(() => _semesterId = ''),
              ),
              for (final entry in semesters.entries) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _semesterId == entry.key,
                  selectedColor: const Color(0xFFEDE8FE),
                  labelStyle: TextStyle(
                    color: _semesterId == entry.key
                        ? const Color(0xFF7047EB)
                        : const Color(0xFF645E7A),
                    fontWeight: _semesterId == entry.key
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _semesterId == entry.key
                          ? const Color(0xFF7047EB)
                          : const Color(0xFFECE7F7),
                    ),
                  ),
                  onSelected: (_) => setState(() => _semesterId = entry.key),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (filtered.isEmpty)
        _emptyState(
          Icons.search_off_rounded,
          data.available.isEmpty
              ? 'Hiện chưa có lớp mở đăng ký cho ngành của bạn.'
              : 'Không tìm thấy lớp phù hợp.',
        )
      else
        for (final section in filtered)
          Container(
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
                onTap: () => _showSection(section),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              section.courseName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1A3C),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF9E9BAE),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE8FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${section.courseCode} • ${section.code}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7047EB),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            section.semesterCode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF757288),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F7EE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_outline_rounded,
                                  size: 15,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Còn ${section.remaining ?? 0} chỗ trống',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    ];
  }

  void _showAttendanceHistory(EnrollmentRecord enrollment, String courseName) {
    final section = _data?.mySections[enrollment.sectionId];
    final sessionsFuture = _repository.sessions(enrollment.sectionId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: FutureBuilder<List<SectionSessionPreview>>(
              future: sessionsFuture,
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
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(snapshot.error.toString()),
                  );
                }
                final list = snapshot.data ?? [];
                final recorded = list.where((s) => s.attendanceSaved).toList();
                final presentCount = recorded
                    .where((s) => s.attendanceStatus == 'PRESENT')
                    .length;
                final absentCount = recorded
                    .where((s) => s.attendanceStatus == 'ABSENT')
                    .length;
                final lateCount = recorded
                    .where((s) => s.attendanceStatus == 'LATE')
                    .length;
                final excusedCount = recorded
                    .where((s) => s.attendanceStatus == 'EXCUSED')
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      courseName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1A3C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${section?.code ?? 'Lớp'} · ${section?.semesterCode ?? ''}',
                      style: const TextStyle(
                        color: Color(0xFF757288),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Thẻ thống kê
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B64F6), Color(0xFF6B40E8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statCol('Tổng buổi', '${list.length}'),
                          _statCol(
                            'Có mặt',
                            '$presentCount',
                            const Color(0xFF86EFAC),
                          ),
                          _statCol(
                            'Vắng',
                            '$absentCount',
                            const Color(0xFFFCA5A5),
                          ),
                          _statCol(
                            'Đi muộn',
                            '$lateCount',
                            const Color(0xFFFDE047),
                          ),
                          _statCol(
                            'Có phép',
                            '$excusedCount',
                            const Color(0xFFDDD6FE),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chi tiết từng buổi học',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1A3C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(
                              child: Text('Chưa có lịch buổi học cho lớp này.'),
                            )
                          : ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFEDE9F7),
                                  ),
                              itemBuilder: (context, index) {
                                final s = list[index];
                                final day = vietnamCalendarDate(s.startAt);
                                final (
                                  statusText,
                                  statusColor,
                                  statusBg,
                                ) = switch (s) {
                                  _
                                      when s.attendanceSaved &&
                                          s.attendanceStatus == 'PRESENT' =>
                                    (
                                      'Có mặt',
                                      const Color(0xFF16A34A),
                                      const Color(0xFFE8F7EE),
                                    ),
                                  _
                                      when s.attendanceSaved &&
                                          s.attendanceStatus == 'ABSENT' =>
                                    (
                                      'Vắng mặt',
                                      const Color(0xFFDC2626),
                                      const Color(0xFFFEE2E2),
                                    ),
                                  _
                                      when s.attendanceSaved &&
                                          s.attendanceStatus == 'LATE' =>
                                    (
                                      'Đi muộn',
                                      const Color(0xFFD97706),
                                      const Color(0xFFFEF3C7),
                                    ),
                                  _
                                      when s.attendanceSaved &&
                                          s.attendanceStatus == 'EXCUSED' =>
                                    (
                                      'Có phép',
                                      const Color(0xFF7047EB),
                                      const Color(0xFFEDE8FE),
                                    ),
                                  _ when s.attendanceSaved => (
                                    'Đã điểm danh',
                                    const Color(0xFF16A34A),
                                    const Color(0xFFE8F7EE),
                                  ),
                                  _ => (
                                    'Chưa diễn ra',
                                    const Color(0xFF757288),
                                    const Color(0xFFF3F2F7),
                                  ),
                                };

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1EEFD),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Color(0xFF7047EB),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${fullWeekdays[day.weekday - 1]}, ${day.day}/${day.month}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF1E1A3C),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Ca ${s.slotId ?? 1} (${formatVietnamTime(s.startAt)} – ${formatVietnamTime(s.endAt)})',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF757288),
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
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCol(
    String label,
    String value, [
    Color valueColor = Colors.white,
  ]) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String message, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF7047EB)),
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
