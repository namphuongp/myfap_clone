import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../models/schedule_session.dart';
import '../utils/schedule_date.dart';
import '../widgets/schedule_session_card.dart';

enum ScheduleViewMode { week, list }

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;
  List<ScheduleSession> _sessions = [];
  bool _loading = true;
  String? _error;
  int _requestNumber = 0;
  ScheduleViewMode _viewMode = ScheduleViewMode.week;

  @override
  void initState() {
    super.initState();
    _selectedDay = vietnamToday();
    _weekStart = mondayOf(_selectedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadWeek();
    });
  }

  Future<void> _loadWeek({bool clear = false}) async {
    final requestNumber = ++_requestNumber;
    final weekStart = _weekStart;
    setState(() {
      _loading = true;
      _error = null;
      if (clear) _sessions = [];
    });

    try {
      final from = Uri.encodeQueryComponent(
        utcAtVietnamMidnight(weekStart).toIso8601String(),
      );
      final to = Uri.encodeQueryComponent(
        utcAtVietnamMidnight(weekStart.add(const Duration(days: 7)))
            .toIso8601String(),
      );
      final data = await widget.api.request(
        'GET',
        '/schedule?from=$from&to=$to',
      );
      final sessions =
          (data as List)
              .map(
                (row) => ScheduleSession.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() => _sessions = sessions);
    } catch (e) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && requestNumber == _requestNumber) {
        setState(() => _loading = false);
      }
    }
  }

  void _changeWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: direction * 7));
      _selectedDay = _selectedDay.add(Duration(days: direction * 7));
    });
    _loadWeek(clear: true);
  }

  void _goToThisWeek() {
    final today = vietnamToday();
    final weekStart = mondayOf(today);
    final changedWeek = weekStart != _weekStart;
    setState(() {
      _weekStart = weekStart;
      _selectedDay = today;
    });
    if (changedWeek) _loadWeek(clear: true);
  }

  int _countFor(DateTime day) =>
      _sessions.where((session) => session.day == day).length;

  @override
  Widget build(BuildContext context) {
    final selectedSessions = _sessions
        .where((session) => session.day == _selectedDay)
        .toList();

    return RefreshIndicator(
      color: const Color(0xFF7047EB),
      onRefresh: _loadWeek,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // 1. Tab Selector: "Tuần học" vs "Lịch học"
          _buildViewModeToggle(),
          const SizedBox(height: 16),

          // 2. Week navigation: [<] [📅 09/11 – 15/11/2026] [>]
          _buildWeekNavigator(),
          const SizedBox(height: 14),

          // 3. 7 Days Row (Monday to Sunday)
          _buildWeekDaysRow(),
          const SizedBox(height: 20),

          // 4. Day Header: 📅 Thứ Tư, 11/11     [ 2 buổi ]
          _buildDayHeader(selectedSessions.length),
          const SizedBox(height: 14),

          // 5. Session List or Empty/Error/Loading State
          if (_loading && _sessions.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7047EB)),
              ),
            )
          else if (_error != null)
            _ScheduleMessage(
              icon: Icons.wifi_off_rounded,
              message: _error!,
              action: TextButton(
                onPressed: _loadWeek,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7047EB),
                ),
                child: const Text('Thử lại'),
              ),
            )
          else if (_viewMode == ScheduleViewMode.week) ...[
            if (selectedSessions.isEmpty)
              _ScheduleMessage(
                icon: Icons.event_available_outlined,
                message: _sessions.isEmpty
                    ? 'Tuần này chưa có lịch học.'
                    : 'Ngày này chưa có buổi học. Hãy chọn ngày có dấu chấm.',
              )
            else
              ...List.generate(selectedSessions.length, (index) {
                final session = selectedSessions[index];
                return ScheduleSessionCard(
                  session: session,
                  accentColor: ScheduleSessionCard.pickAccentColor(
                    session.course,
                    index,
                  ),
                );
              }),
          ] else ...[
            // List View Mode
            if (_sessions.isEmpty)
              const _ScheduleMessage(
                icon: Icons.event_available_outlined,
                message: 'Tuần này chưa có lịch học nào.',
              )
            else
              ..._buildGroupedSessionsList(),
          ],

          if (_loading && _sessions.isNotEmpty)
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

  Widget _buildViewModeToggle() {
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
              onTap: () => setState(() => _viewMode = ScheduleViewMode.week),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: _viewMode == ScheduleViewMode.week
                      ? const LinearGradient(
                          colors: [Color(0xFF835DF8), Color(0xFF6B41EB)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _viewMode == ScheduleViewMode.week
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.date_range_outlined,
                      size: 17,
                      color: _viewMode == ScheduleViewMode.week
                          ? Colors.white
                          : const Color(0xFF645E7A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tuần học',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _viewMode == ScheduleViewMode.week
                            ? Colors.white
                            : const Color(0xFF645E7A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = ScheduleViewMode.list),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: _viewMode == ScheduleViewMode.list
                      ? const LinearGradient(
                          colors: [Color(0xFF835DF8), Color(0xFF6B41EB)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _viewMode == ScheduleViewMode.list
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 17,
                      color: _viewMode == ScheduleViewMode.list
                          ? Colors.white
                          : const Color(0xFF645E7A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lịch học',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _viewMode == ScheduleViewMode.list
                            ? Colors.white
                            : const Color(0xFF645E7A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator() {
    return Row(
      children: [
        // Left arrow button
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
            onPressed: () => _changeWeek(-1),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF2E2A44),
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Week range display
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
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _goToThisWeek,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Color(0xFF6E46EB),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatWeekRange(_weekStart),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1A3C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Right arrow button
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
            onPressed: () => _changeWeek(1),
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF2E2A44),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDaysRow() {
    return Row(
      children: List.generate(7, (index) {
        final day = _weekStart.add(Duration(days: index));
        final selected = day == _selectedDay;
        final hasClasses = _countFor(day) > 0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 6 ? 6.0 : 0.0),
            child: Semantics(
              button: true,
              selected: selected,
              label: '${fullWeekdays[index]}, ${day.day}/${day.month}',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedDay = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF8B64F6), Color(0xFF6B40E8)],
                          )
                        : null,
                    color: selected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? null
                        : Border.all(color: const Color(0xFFEFEBF8)),
                    boxShadow: selected
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
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shortWeekdays[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF4C4762),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF1E1A3C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (selected)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                      else if (hasClasses)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayHeader(int count) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_month_outlined,
          size: 20,
          color: Color(0xFF6E46EB),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${fullWeekdays[_selectedDay.weekday - 1]}, ${_selectedDay.day.toString().padLeft(2, '0')}/${_selectedDay.month.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1A3C),
            ),
          ),
        ),
        if (!_loading && _error == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEAF7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count buổi',
              style: const TextStyle(
                color: Color(0xFF55506E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildGroupedSessionsList() {
    final widgets = <Widget>[];
    for (int i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      final daySessions = _sessions
          .where((session) => session.day == day)
          .toList();
      if (daySessions.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF7047EB),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${fullWeekdays[day.weekday - 1]}, ${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1E1A3C),
                ),
              ),
              const Spacer(),
              Text(
                '${daySessions.length} buổi',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF706D85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

      for (int sIndex = 0; sIndex < daySessions.length; sIndex++) {
        final session = daySessions[sIndex];
        widgets.add(
          ScheduleSessionCard(
            session: session,
            accentColor: ScheduleSessionCard.pickAccentColor(
              session.course,
              sIndex,
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 48, color: const Color(0xFF7047EB)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF4B4660), fontSize: 14),
        ),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ],
    ),
  );
}
