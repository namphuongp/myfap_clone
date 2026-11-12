import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../models/teaching_course.dart';
import '../repositories/lecturer_repository.dart';
import '../widgets/attendance_course_card.dart';
import '../widgets/lecturer_ui.dart';
import 'lecturer_attendance_classes_screen.dart';

class LecturerAttendanceCoursesScreen extends StatefulWidget {
  final LecturerRepository repository;
  const LecturerAttendanceCoursesScreen({super.key, required this.repository});
  @override
  State<LecturerAttendanceCoursesScreen> createState() =>
      _AttendanceCoursesState();
}

class _AttendanceCoursesState extends State<LecturerAttendanceCoursesScreen> {
  AcademicTerm? _term;
  List<TeachingCourse> _courses = [];
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
          _courses = TeachingCourse.group(data.classes);
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

  Future<void> _open(TeachingCourse section) async {
    await pushLecturer(
      context,
      LecturerAttendanceClassesScreen(
        repository: widget.repository,
        courseId: section.id,
        courseName: section.title,
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => LecturerPage(
    title: 'Điểm danh theo môn',
    actions: [
      IconButton(
        tooltip: 'Tải lại các môn',
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
            const SectionHeading('MÔN PHỤ TRÁCH'),
            if (_courses.isEmpty)
              EmptyPanel(
                title: _term == null
                    ? 'Hiện đang ngoài học kỳ'
                    : 'Chưa có môn phụ trách',
                message: 'Chỉ hiển thị các môn có buổi học được phân công cho bạn trong học kỳ hiện tại.',
                icon: Icons.menu_book_outlined,
              )
            else
              for (final section in _courses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AttendanceCourseCard(
                    key: ValueKey('attendance-course-${section.id}'),
                    course: section,
                    onTap: () => _open(section),
                  ),
                ),
          ],
        ],
      ),
    ),
  );
}
