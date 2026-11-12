import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import '../../lecturer/widgets/lecturer_ui.dart';
import '../repositories/staff_repository.dart';
import 'staff_change_requests_screen.dart';
import 'staff_notices_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });

  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  late final StaffRepository _repository = StaffRepository(widget.api);
  late ThemeData _theme;
  bool _loggingOut = false;

  void _signedOut() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _openProfile() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => Theme(
        data: _theme,
        child: ProfileScreen(
          repository: ProfileRepository(widget.api),
          onSignedOut: _signedOut,
        ),
      ),
    ),
  );

  Future<void> _open(Widget screen) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => Theme(data: _theme, child: screen),
    ),
  );

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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cán bộ học vụ'),
          actions: [
            IconButton(
              tooltip: 'Hồ sơ cá nhân',
              onPressed: _openProfile,
              icon: const Icon(Icons.account_circle_outlined),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: _loggingOut ? null : _logout,
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Xin chào, ${widget.user['name'] ?? 'Cán bộ'}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: lecturerNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SectionHeading('NGHIỆP VỤ HỌC VỤ'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 650 ? 2 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 14) / columns;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: width,
                          child: _StaffTile(
                            title: 'Duyệt đơn học vụ',
                            subtitle: 'Đổi lịch / phòng và chuyển ngành',
                            icon: Icons.event_available_rounded,
                            color: const Color(0xFF087F67),
                            background: const Color(0xFFDDF8ED),
                            onTap: () => _open(
                              StaffChangeRequestsScreen(
                                repository: _repository,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _StaffTile(
                            title: 'Thông báo học vụ',
                            subtitle: 'Soạn, lưu nháp và phát hành thông báo',
                            icon: Icons.campaign_rounded,
                            color: const Color(0xFFA75D00),
                            background: const Color(0xFFFFEFCF),
                            onTap: () => _open(
                              StaffNoticesScreen(repository: _repository),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SectionHeading('TÀI KHOẢN'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Hồ sơ của tôi'),
                    subtitle: const Text('Xem thông tin cá nhân'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openProfile,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(color: lecturerMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
