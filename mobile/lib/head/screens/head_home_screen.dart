import 'package:flutter/material.dart';

import '../../core/widgets/role_layout.dart';

import '../../core/api/api_client.dart';
import '../../core/academic/academic_widgets.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import '../repositories/head_repository.dart';
import '../widgets/head_ui.dart';
import 'head_report_screen.dart';
import 'head_lecturers_screen.dart';

/// Trang chủ của Trưởng bộ môn: quản lý giảng viên, báo cáo và hồ sơ.
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
  /// Đóng các trang con rồi thông báo cho luồng đăng nhập rằng đã đăng xuất.
  void _signedOut() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onLoggedOut();
  }

  /// Mở trang con với theme HEAD và giữ điều hướng Trang chủ/Hồ sơ.
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
                    ? RoleScaffold(
                        body: screen,
                        bottomNavigationBar: scope.buildBar(profile: true),
                      )
                    : screen,
              ),
            );
          },
        ),
      );
  /// Mở hồ sơ cá nhân dùng chung và chọn tab Hồ sơ ở thanh điều hướng.
  Future<void> _profile() => _open(
    ProfileScreen(
      repository: ProfileRepository(widget.api),
      onSignedOut: _signedOut,
    ),
    profile: true,
  );
  /// Mở báo cáo bộ môn, truyền repository để màn hình tự tải dữ liệu.
  void _report() => _open(
    HeadScaffold(
      appBar: AppBar(title: const Text('Báo cáo bộ môn')),
      body: HeadReportScreen(repository: _repo),
    ),
  );
  /// Mở danh sách giảng viên thuộc phạm vi quản lý của Trưởng bộ môn.
  void _lecturers() => _open(
    HeadScaffold(
      appBar: AppBar(title: const Text('Quản lý giảng viên')),
      body: HeadLecturersScreen(repository: _repo),
    ),
  );
  /// Gọi API đăng xuất; khóa thao tác trong lúc chờ và hiển thị lỗi nếu có.
  Future<void> _logout() async {
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
  // Dựng header, các ô chức năng, mục tài khoản và thanh điều hướng dưới.
  Widget build(BuildContext context) => HeadScaffold(
    appBar: RoleHomeHeader(
      name: widget.user['name']?.toString() ?? 'Trưởng bộ môn',
      role: 'Trưởng bộ môn · MyFAP',
      subtitleColor: const Color(0xFFBACADD),
      leading: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.school_rounded, color: headOrange, size: 28),
      ),
      onProfile: _busy ? null : _profile,
      onLogout: _busy ? null : _logout,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 16),
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
            final width = (box.maxWidth - 12) / 2;
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
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
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

/// Ô chức năng trên trang chủ; nhận biểu tượng, màu và callback mở màn hình.
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
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 156),
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
                  fontSize: 15,
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
