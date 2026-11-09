import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../profile/repositories/profile_repository.dart';
import '../profile/screens/profile_screen.dart';

class ScheduleHomeScreen extends StatefulWidget {
  const ScheduleHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });

  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;

  @override
  State<ScheduleHomeScreen> createState() => _ScheduleHomeScreenState();
}

class _ScheduleHomeScreenState extends State<ScheduleHomeScreen> {
  dynamic _data;
  bool _busy = false;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now().toUtc();
      final from = Uri.encodeQueryComponent(
        now.subtract(const Duration(days: 7)).toIso8601String(),
      );
      final to = Uri.encodeQueryComponent(
        now.add(const Duration(days: 30)).toIso8601String(),
      );
      final data = await widget.api.request(
        'GET',
        widget.user['role'] == 'HEAD'
            ? '/department/summary'
            : '/schedule?from=$from&to=$to',
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signedOut() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _openProfile() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
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
      if (mounted) widget.onLoggedOut();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MyFAP'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _openProfile,
          tooltip: 'Hồ sơ cá nhân',
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.user['name']} • ${roleLabels[widget.user['role']] ?? widget.user['role']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              FilledButton(
                onPressed: _busy ? null : _load,
                child: Text(
                  widget.user['role'] == 'HEAD'
                      ? 'Xem báo cáo bộ môn'
                      : 'Tải lịch học / lịch dạy',
                ),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _openProfile,
                child: const Text('Hồ sơ của tôi'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _logout,
                child: const Text('Đăng xuất'),
              ),
              if (_data is Map)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Số lớp: ${_data["sections"]}\nSố buổi: ${_data["sessions"]}\nBuổi đã điểm danh: ${_data["recorded_sessions"]}',
                    ),
                  ),
                ),
              if (_data is List)
                ...(_data as List).map(
                  (dynamic row) => Card(
                    child: ListTile(
                      title: Text('${row['section_code']} • ${row['course']}'),
                      subtitle: Text(
                        '${DateTime.parse(row['start_at'] as String).toLocal()}\nPhòng ${row['room_name']}',
                      ),
                    ),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
