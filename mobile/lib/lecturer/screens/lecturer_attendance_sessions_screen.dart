import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../models/teaching_class.dart';
import '../repositories/lecturer_repository.dart';
import '../utils/lecturer_dates.dart';
import '../widgets/attendance_class_card.dart';
import '../widgets/attendance_status_pill.dart';
import '../widgets/lecturer_ui.dart';

class LecturerAttendanceSessionsScreen extends StatefulWidget {
  final LecturerRepository repository;
  final AcademicTerm term;
  final TeachingClass section;
  const LecturerAttendanceSessionsScreen({
    super.key,
    required this.repository,
    required this.term,
    required this.section,
  });
  @override
  State<LecturerAttendanceSessionsScreen> createState() =>
      _AttendanceSessionsState();
}

class _AttendanceSessionsState extends State<LecturerAttendanceSessionsScreen> {
  late TeachingClass _section;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _section = widget.section;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await widget.repository.attendanceSessions(widget.term);
      if (mounted && generation == _generation) {
        setState(
          () => _section = widget.section.withSessions(
            sessions.where((s) => s.sectionId == widget.section.id).toList(),
          ),
        );
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

  @override
  Widget build(BuildContext context) => LecturerPage(
    title: 'Các buổi học',
    actions: [
      IconButton(
        tooltip: 'Tải lại các buổi học',
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
          AttendanceClassCard(section: _section),
          SectionHeading('DANH SÁCH BUỔI HỌC (${_section.sessions.length})'),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorPanel(_error!, onRetry: _load)
          else if (_section.sessions.isEmpty)
            const EmptyPanel(
              title: 'Không có buổi học phụ trách',
              message: 'Các buổi đã hủy hoặc được phân công cho giảng viên khác không hiển thị ở đây.',
            )
          else
            for (final session in _section.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  key: ValueKey('attendance-session-${session.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ngày ${dateLabel(session.day)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: lecturerNavyDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Slot ${session.slot} · ${slotLabels[session.slot] ?? 'Chưa có slot'}',
                          style: const TextStyle(color: lecturerMuted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Phòng ${session.room}',
                          style: const TextStyle(
                            color: lecturerNavy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AttendanceStatusPill(session: session),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
