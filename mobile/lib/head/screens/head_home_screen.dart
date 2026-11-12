import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/academic/academic_widgets.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import '../repositories/head_repository.dart';
import '../widgets/head_ui.dart';
import 'head_report_screen.dart';
import 'head_request_report_screen.dart';
import 'head_lecturers_screen.dart';

class HeadHomeScreen extends StatefulWidget {
  const HeadHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;
  @override
  State<HeadHomeScreen> createState() => _HeadHomeScreenState();
}

class _HeadHomeScreenState extends State<HeadHomeScreen> {
  late final _repo = HeadRepository(widget.api);
  bool _busy = false;
  void _signedOut() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _open(Widget screen, {bool profile = false}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) {
            final scope = HeadNavigationScope(
              onHome: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              onProfile: _profile,
              child: screen,
            );
            return Theme(
              data: headTheme(Theme.of(context)),
              child: HeadNavigationScope(
                onHome: scope.onHome,
                onProfile: scope.onProfile,
                child: profile
                    ? Scaffold(
                        body: screen,
                        bottomNavigationBar: scope.buildBar(profile: true),
                      )
                    : screen,
              ),
            );
          },
        ),
      );
  Future<void> _profile() => _open(
    ProfileScreen(
      repository: ProfileRepository(widget.api),
      onSignedOut: _signedOut,
    ),
    profile: true,
  );
  void _report() => _open(
    HeadScaffold(
      appBar: AppBar(title: const Text('Báo cáo bộ môn')),
      body: HeadReportScreen(repository: _repo),
    ),
  );
  void _lecturers() => _open(
    HeadScaffold(
      appBar: AppBar(title: const Text('Quản lý giảng viên')),
      body: HeadLecturersScreen(repository: _repo),
    ),
  );
  void _requests() => _open(
    HeadScaffold(
      appBar: AppBar(title: const Text('Đơn từ trong bộ môn')),
      body: HeadRequestReportScreen(repository: _repo),
    ),
  );
  Future<void> _logout() async {
    // DX5: Trưởng bộ môn đăng xuất qua cùng API thu hồi phiên DX2–DX3.
    setState(() => _busy = true);
    try {
      await widget.api.logout();
      if (mounted) _signedOut();
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => HeadScaffold(
    appBar: AppBar(
      toolbarHeight: 88,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: headOrange,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user['name']?.toString() ?? 'Trưởng bộ môn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Trưởng bộ môn · MyFAP',
                  style: TextStyle(fontSize: 11, color: Color(0xFFBACADD)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Hồ sơ cá nhân',
          onPressed: _busy ? null : _profile,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          onPressed: _busy ? null : _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 14),
          child: Text(
            'CHỨC NĂNG BỘ MÔN',
            style: TextStyle(
              color: headNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) {
            final width = ((box.maxWidth - 12) / 2)
                .clamp(0.0, 260.0)
                .toDouble();
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _DashboardTile(
                    label: 'Quản lý giảng viên',
                    icon: Icons.contact_page_rounded,
                    color: const Color(0xFF1768B6),
                    background: const Color(0xFFE7F1FF),
                    onTap: _lecturers,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DashboardTile(
                    label: 'Báo cáo bộ môn',
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFFF39A00),
                    background: const Color(0xFFFFF4D2),
                    onTap: _report,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DashboardTile(
                    label: 'Đơn từ trong bộ môn',
                    icon: Icons.description_outlined,
                    color: const Color(0xFF169B78),
                    background: const Color(0xFFE2F6EF),
                    onTap: _requests,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 14),
          child: Text(
            'TÀI KHOẢN',
            style: TextStyle(
              color: headNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: const Icon(Icons.person_outline_rounded, color: headNavy),
            title: const Text(
              'Hồ sơ của tôi',
              style: TextStyle(color: headNavy, fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: headMuted),
            onTap: _profile,
          ),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (v) {
        if (v == 1) _profile();
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Trang chủ',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          label: 'Hồ sơ',
        ),
      ],
    ),
  );
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color, background;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 1,
    shadowColor: const Color(0x101A304B),
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 124),
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
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: headNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
