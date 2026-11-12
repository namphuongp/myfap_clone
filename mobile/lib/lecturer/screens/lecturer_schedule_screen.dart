import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../repositories/lecturer_repository.dart';
import '../utils/lecturer_dates.dart';
import '../widgets/lecturer_ui.dart';
import '../widgets/teaching_session_card.dart';
import 'lecturer_attendance_screen.dart';
import 'lecturer_change_screen.dart';

class LecturerScheduleScreen extends StatefulWidget {
  final LecturerRepository repository;
  const LecturerScheduleScreen({super.key, required this.repository});
  @override
  State<LecturerScheduleScreen> createState() => _LecturerScheduleScreenState();
}

class _LecturerScheduleScreenState extends State<LecturerScheduleScreen> {
  List<AcademicTerm> _terms = [];
  String? _termId;
  DateTime _day = vnDay(), _week = monday(vnDay());
  List<TeachingSession> _sessions = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final terms = await widget.repository.terms();
      if (!mounted) return;
      _terms = terms;
      final current = terms.where((s) => s.includes(vnDay())).firstOrNull;
      _termId = current?.id;
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _load() async {
    // GD1: Giảng viên chọn tuần/kỳ để tải lịch dạy của mình.
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.schedule(
        _week,
        _week.add(const Duration(days: 7)),
      );
      if (mounted && generation == _generation) {
        setState(() => _sessions = data);
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

  void _moveWeek(int direction) {
    setState(() {
      _week = _week.add(Duration(days: direction * 7));
      _day = _week;
    });
    _load();
  }

  Future<void> _change(TeachingSession session) async {
    await pushLecturer(
      context,
      LecturerChangeScreen(
        repository: widget.repository,
        initialSession: session,
      ),
    );
    if (mounted) _load();
  }

  Future<void> _attendance(TeachingSession session) async {
    await pushLecturer(
      context,
      LecturerAttendanceScreen(repository: widget.repository, session: session),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _week.add(Duration(days: i)));
    final matching = _sessions.where(
      (s) => s.semesterId == _termId && s.status != 'CANCELLED',
    );
    final selected = matching.where((s) => s.day == _day).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    return LecturerPage(
      title: 'Lịch dạy',
      actions: [
        IconButton(
          onPressed: _loading ? null : _initialize,
          tooltip: 'Tải lại lịch',
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _initialize,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECE7F7)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE8FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: Color(0xFF7047EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Học kỳ hiện tại',
                          style: TextStyle(fontSize: 12, color: lecturerMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _terms
                                  .where((term) => term.id == _termId)
                                  .firstOrNull
                                  ?.code ??
                              (_loading
                                  ? 'Đang tải…'
                                  : 'Chưa có học kỳ hiện tại'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1E1A3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECE7F7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Tuần trước',
                    onPressed: _loading ? null : () => _moveWeek(-1),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF2E2A44),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECE7F7)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Color(0xFF6E46EB),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${dateLabel(_week)} – ${dateLabel(_week.add(const Duration(days: 6)))}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1A3C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECE7F7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Tuần sau',
                    onPressed: _loading ? null : () => _moveWeek(1),
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF2E2A44),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(days.length, (index) {
                final day = days[index];
                final active = day == _day;
                final hasLesson = matching.any((s) => s.day == day);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index < 6 ? 6.0 : 0.0),
                    child: Semantics(
                      key: ValueKey('teaching-day-${dateKey(day)}'),
                      selected: active,
                      button: true,
                      label: 'Ngày ${dateLabel(day)}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _day = day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: active
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF8B64F6),
                                      Color(0xFF6B40E8),
                                    ],
                                  )
                                : null,
                            color: active ? null : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: active
                                ? null
                                : Border.all(color: const Color(0xFFEFEBF8)),
                            boxShadow: active
                                ? const [
                                    BoxShadow(
                                      color: Color(0x356B40E8),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : const [
                                    BoxShadow(
                                      color: Color(0x05000000),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                weekdayNames[day.weekday - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.88)
                                      : lecturerMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors.white
                                      : const Color(0xFF1E1A3C),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: hasLesson
                                      ? (active
                                            ? Colors.white
                                            : const Color(0xFFEF4444))
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SectionHeading('Lịch ngày ${dateLabel(_day)}'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ErrorPanel(_error!, onRetry: _terms.isEmpty ? _initialize : _load)
            else if (selected.isEmpty)
              const EmptyPanel(
                title: 'Không có lịch dạy',
                message: 'Ngày này chưa có buổi học trong học kỳ đã chọn.',
              )
            else
              ...selected.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TeachingSessionCard(
                    session: session,
                    onAttendance: () => _attendance(session),
                    onChange: () => _change(session),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Giờ Việt Nam (UTC+7) · 4 slot mỗi ngày',
              textAlign: TextAlign.center,
              style: TextStyle(color: lecturerMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
