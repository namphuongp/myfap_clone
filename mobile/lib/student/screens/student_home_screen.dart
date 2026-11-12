import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import 'announcements_screen.dart';
import 'requests_screen.dart';
import 'student_schedule_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });

  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;
  bool _loggingOut = false;

  void _signedOutFromProfile() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _openProfile() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ProfileScreen(
        repository: ProfileRepository(widget.api),
        onSignedOut: _signedOutFromProfile,
      ),
    ),
  );

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await widget.api.logout();
      if (mounted) widget.onLoggedOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _buildTopHeader() {
    final tabsMeta = [
      (
        Icons.calendar_month_rounded,
        'Lịch học',
        'Quản lý thời khóa biểu của bạn',
      ),
      (Icons.description_rounded, 'Đơn từ', 'Quản lý yêu cầu sinh viên'),
      (
        Icons.notifications_rounded,
        'Thông báo học vụ',
        'Cập nhật tin tức mới nhất',
      ),
    ];

    final (icon, title, subtitle) = tabsMeta[_selectedIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFA582F7), Color(0xFF7248EA)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x307248EA),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1A3C),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF78758D),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E2F5), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Hồ sơ cá nhân',
              onPressed: _loggingOut ? null : _openProfile,
              icon: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF332F4C),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E2F5), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Đăng xuất',
              onPressed: _loggingOut ? null : _logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFF332F4C),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final items = [
      (Icons.calendar_month_rounded, 'Lịch'),
      (Icons.description_outlined, 'Đơn từ'),
      (Icons.notifications_none_outlined, 'Thông báo'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEDE9F7), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final (icon, label) = items[index];
          final isSelected = _selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFEDE8FE)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? const Color(0xFF7047EB)
                          : const Color(0xFF6B6680),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF7047EB)
                            : const Color(0xFF6B6680),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.22, 1.0],
          colors: [Color(0xFFEDE9FE), Color(0xFFF7F5FE), Color(0xFFFAF9FD)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  StudentScheduleScreen(api: widget.api),
                  RequestsScreen(api: widget.api),
                  AnnouncementsScreen(api: widget.api),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    ),
  );
}
