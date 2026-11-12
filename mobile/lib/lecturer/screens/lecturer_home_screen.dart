import 'package:flutter/material.dart';

import '../../core/widgets/role_layout.dart';

import '../../core/api/api_client.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import '../repositories/lecturer_repository.dart';
import '../widgets/lecturer_ui.dart';
import 'lecturer_schedule_screen.dart';
import 'lecturer_attendance_courses_screen.dart';
import 'lecturer_change_screen.dart';
import 'lecturer_requests_screen.dart';

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;
  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  late final LecturerRepository _repository;
  late ThemeData _theme;
  bool _loggingOut = false;
  @override
  void initState() {
    super.initState();
    _repository = LecturerRepository(widget.api);
  }

  void _signedOut() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _open(Widget screen) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Theme(data: _theme, child: screen),
    ),
  );
  void _profile() => _open(
    ProfileScreen(
      repository: ProfileRepository(widget.api),
      onSignedOut: _signedOut,
    ),
  );
  void _schedule() => _open(LecturerScheduleScreen(repository: _repository));
  void _attendance() =>
      _open(LecturerAttendanceCoursesScreen(repository: _repository));
  void _requests() => _open(LecturerRequestsScreen(repository: _repository));
  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await widget.api.logout();
      if (mounted) _signedOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _theme = lecturerTheme(Theme.of(context));
    return Theme(
      data: _theme,
      child: RoleScaffold(
        appBar: RoleHomeHeader(
          name: widget.user['name'] as String,
          role: 'Giảng viên · MyFAP',
          subtitleColor: lecturerNavy,
          leading: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7047EB), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              initialsForName(widget.user['name'] as String),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          onProfile: _profile,
        ),
        body: _dashboard(),
      ),
    );
  }

  Widget _dashboard() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const SectionHeading('GIẢNG DẠY'),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    [
                          _tile(
                            'Lịch dạy',
                            'Theo tuần và học kỳ',
                            Icons.calendar_month_rounded,
                            const Color(0xFF008DBA),
                            const Color(0xFFDDF3FC),
                            _schedule,
                          ),
                          _tile(
                            'Điểm danh',
                            'Theo môn và lớp phụ trách',
                            Icons.fact_check_rounded,
                            lecturerGreen,
                            const Color(0xFFDDF8ED),
                            _attendance,
                          ),
                          _tile(
                            'Duyệt đơn nghỉ',
                            'Sinh viên lớp phụ trách',
                            Icons.assignment_turned_in_rounded,
                            const Color(0xFF7050B0),
                            const Color(0xFFEEE7FB),
                            () => _requests(),
                          ),
                          _tile(
                            'Đổi lịch / phòng',
                            'Gửi cán bộ phê duyệt',
                            Icons.edit_calendar_rounded,
                            const Color(0xFFA75D00),
                            const Color(0xFFFFEFCF),
                            () => _open(
                              LecturerChangeScreen(repository: _repository),
                            ),
                          ),
                        ]
                        .map(
                          (tile) => SizedBox(
                            width: width,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 156),
                              child: tile,
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
          const SectionHeading('TÀI KHOẢN'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: const Icon(Icons.person_outline, color: lecturerNavy),
              title: const Text('Hồ sơ của tôi'),
              subtitle: const Text('Xem thông tin cá nhân'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _profile,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logout,
            icon: const Icon(Icons.logout),
            label: Text(_loggingOut ? 'Đang đăng xuất…' : 'Đăng xuất'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  Widget _tile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Color background,
    VoidCallback onTap,
  ) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEBEBF2)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7047EB).withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E2D),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8C8CA1)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
