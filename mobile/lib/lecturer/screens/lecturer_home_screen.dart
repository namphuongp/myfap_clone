import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import '../repositories/lecturer_repository.dart';
import '../widgets/lecturer_widgets.dart';
import 'lecturer_requests_screen.dart';
import 'lecturer_change_screen.dart';
import 'lecturer_attendance_screen.dart';
import 'lecturer_schedule_screen.dart';

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });
  final Json user;
  final ApiClient api;
  final VoidCallback onLoggedOut;
  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  late final LecturerRepository _repository = LecturerRepository(widget.api);
  int _index = 0;
  bool _busy = false;
  void _signedOut() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _profile() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProfileScreen(
        repository: ProfileRepository(widget.api),
        onSignedOut: _signedOut,
      ),
    ),
  );
  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await widget.api.logout();
      if (mounted) _signedOut();
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        const [
          'Lịch dạy',
          'Duyệt đơn nghỉ',
          'Đổi lịch / phòng',
          'Điểm danh',
        ][_index],
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
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Column(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.school)),
          title: Text(widget.user['name']?.toString() ?? 'Giảng viên'),
          subtitle: const Text('Giảng viên'),
          trailing: TextButton(
            onPressed: _profile,
            child: const Text('Hồ sơ của tôi'),
          ),
        ),
        Expanded(
          child: switch (_index) {
            0 => LecturerScheduleScreen(repository: _repository),
            1 => LecturerRequestsScreen(repository: _repository),
            2 => LecturerChangeScreen(repository: _repository),
            _ => LecturerAttendanceScreen(repository: _repository),
          },
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (v) => setState(() => _index = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.calendar_month),
          label: 'Lịch dạy',
        ),
        NavigationDestination(icon: Icon(Icons.approval), label: 'Đơn nghỉ'),
        NavigationDestination(
          icon: Icon(Icons.swap_horiz),
          label: 'Đổi lịch/phòng',
        ),
        NavigationDestination(icon: Icon(Icons.fact_check), label: 'Điểm danh'),
      ],
    ),
  );
}
