import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../models/teaching_class.dart';
import '../repositories/lecturer_repository.dart';
import '../widgets/attendance_class_card.dart';
import '../widgets/lecturer_ui.dart';
import 'lecturer_attendance_sessions_screen.dart';

class LecturerAttendanceClassesScreen extends StatefulWidget {
  final LecturerRepository repository;
  final String courseId, courseName;
  const LecturerAttendanceClassesScreen({
    super.key,
    required this.repository,
    required this.courseId,
    required this.courseName,
  });
  @override
  State<LecturerAttendanceClassesScreen> createState() =>
      _AttendanceClassesState();
}

class _AttendanceClassesState extends State<LecturerAttendanceClassesScreen> {
  AcademicTerm? _term;
  List<TeachingClass> _classes = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;
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
      final data = await widget.repository.attendanceOverview();
      if (mounted && generation == _generation) {
        setState(() {
          _term = data.term;
          _classes = data.classes
              .where((section) => section.courseId == widget.courseId)
              .toList();
        });
      }
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

  Future<void> _open(TeachingClass section) async {
    await pushLecturer(
      context,
      LecturerAttendanceSessionsScreen(
        repository: widget.repository,
        term: _term!,
        section: section,
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => LecturerPage(
    title: 'Các lớp phụ trách',
    actions: [
      IconButton(
        tooltip: 'Tải lại các lớp',
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorPanel(_error!, onRetry: _load)
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lecturerNavy.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, color: lecturerNavy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Học kỳ hiện tại',
                          style: TextStyle(fontSize: 12, color: lecturerMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _term?.code ?? 'Chưa có học kỳ hiện tại',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: lecturerNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                widget.courseName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: lecturerNavyDark,
                ),
              ),
            ),
            const SectionHeading('DANH SÁCH LỚP'),
            if (_classes.isEmpty)
              EmptyPanel(
                title: _term == null
                    ? 'Hiện đang ngoài học kỳ'
                    : 'Chưa có lớp phụ trách',
                message: 'Chỉ hiển thị các lớp có buổi học được phân công cho bạn trong học kỳ hiện tại.',
                icon: Icons.class_outlined,
              )
            else
              for (final section in _classes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AttendanceClassCard(
                    key: ValueKey('attendance-class-${section.id}'),
                    section: section,
                    onTap: () => _open(section),
                  ),
                ),
          ],
        ],
      ),
    ),
  );
}
