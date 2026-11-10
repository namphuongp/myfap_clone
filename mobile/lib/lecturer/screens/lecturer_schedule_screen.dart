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
      _termId = current?.id ?? terms.firstOrNull?.id;
      if (current == null && terms.isNotEmpty) {
        _day = vnDay(terms.first.start);
        _week = monday(_day);
      }
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

  void _selectTerm(AcademicTerm term) {
    setState(() {
      _termId = term.id;
      _day = term.includes(vnDay()) ? vnDay() : vnDay(term.start);
      _week = monday(_day);
    });
    _load();
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

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _week.add(Duration(days: i)));
    final matching = _sessions.where((s) => s.semesterId == _termId);
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
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _terms
                    .map(
                      (term) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(term.code),
                          selected: term.id == _termId,
                          selectedColor: const Color(0xFFFFE2AF),
                          onSelected: (_) => _selectTerm(term),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Tuần trước',
                  onPressed: _loading ? null : () => _moveWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${dateLabel(_week)} – ${dateLabel(_week.add(const Duration(days: 6)))}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: lecturerNavy,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tuần sau',
                  onPressed: _loading ? null : () => _moveWeek(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Row(
                  children: days.map((day) {
                    final active = day == _day;
                    final hasLesson = matching.any((s) => s.day == day);
                    return Expanded(
                      child: Semantics(
                        key: ValueKey('teaching-day-${dateKey(day)}'),
                        selected: active,
                        button: true,
                        label: 'Ngày ${dateLabel(day)}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _day = day),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                Text(
                                  weekdayNames[day.weekday - 1],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: lecturerMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: active
                                      ? lecturerNavy
                                      : Colors.transparent,
                                  foregroundColor: active
                                      ? Colors.white
                                      : lecturerNavy,
                                  child: Text(
                                    '${day.day}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: hasLesson
                                        ? lecturerOrange
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
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
                    onAttendance: () => pushLecturer(
                      context,
                      LecturerAttendanceScreen(
                        repository: widget.repository,
                        session: session,
                      ),
                    ),
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
