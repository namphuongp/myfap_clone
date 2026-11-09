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
      ..showSnackBar(SnackBar(content: Text(message)));
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
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                section.courseName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('${section.code} • ${section.semesterCode}'),
              const SizedBox(height: 8),
              Text('Còn ${section.remaining ?? 0} chỗ trống'),
              const SizedBox(height: 20),
              Text(
                'Lịch học sắp tới',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<SectionSessionPreview>>(
                future: sessions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
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
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: upcoming.length,
                          itemBuilder: (context, index) {
                            final row = upcoming[index];
                            final day = vietnamCalendarDate(row.startAt);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event),
                              title: Text(
                                '${fullWeekdays[day.weekday - 1]}, ${day.day}/${day.month}',
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
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Đã đăng ký')),
              ButtonSegment(value: 1, label: Text('Tìm lớp')),
            ],
            selected: {_tab},
            onSelectionChanged: (selected) =>
                setState(() => _tab = selected.first),
          ),
          const SizedBox(height: 20),
          if (_loading && data == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
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
            const Center(child: CircularProgressIndicator()),
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
            child: const Text('Tìm lớp để đăng ký'),
          ),
        ),
      ];
    }
    final records = [...data.enrollments]
      ..sort((a, b) => a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1));
    return [
      Text('Lớp của tôi', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      for (final row in records)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.mySections[row.sectionId]?.courseName ??
                      data.courseNames[row.courseId] ??
                      'Môn học',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(data.mySections[row.sectionId]?.code ?? 'Lớp đã rút'),
                Text(
                  data.mySections[row.sectionId]?.semesterCode ??
                      data.semesterNames[row.semesterId] ??
                      'Học kỳ',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      row.isActive ? 'Đang học' : 'Đã rút',
                      style: TextStyle(
                        color: row.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (row.isActive)
                      TextButton(
                        onPressed: _submitting ? null : () => _withdraw(row),
                        child: const Text('Rút lớp'),
                      ),
                  ],
                ),
              ],
            ),
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
          action: TextButton(onPressed: _load, child: const Text('Thử lại')),
        ),
      ];
    }
    final semesters = <String, String>{
      for (final row in data.available) row.semesterId: row.semesterCode,
    };
    final query = _search.trim().toLowerCase();
    final filtered = data.available.where((row) {
      if (_semesterId.isNotEmpty && row.semesterId != _semesterId) return false;
      if (query.isEmpty) return true;
      return '${row.courseName} ${row.courseCode} ${row.code}'
          .toLowerCase()
          .contains(query);
    }).toList();
    return [
      Text(
        'Các lớp thuộc ngành của bạn đang mở đăng ký và có lịch học sắp tới.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Tìm môn hoặc mã lớp',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _search = value),
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
                onSelected: (_) => setState(() => _semesterId = ''),
              ),
              for (final entry in semesters.entries) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _semesterId == entry.key,
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
          Icons.search_off,
          data.available.isEmpty
              ? 'Hiện chưa có lớp mở đăng ký cho ngành của bạn.'
              : 'Không tìm thấy lớp phù hợp.',
        )
      else
        for (final section in filtered)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showSection(section),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.courseName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('${section.courseCode} • ${section.code}'),
                    Text(section.semesterCode),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text('Còn ${section.remaining ?? 0} chỗ trống'),
                        const Spacer(),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    ];
  }

  Widget _emptyState(IconData icon, String message, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      );
}
