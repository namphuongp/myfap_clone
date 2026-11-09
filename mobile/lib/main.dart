import 'package:flutter/material.dart';

import 'api_client.dart';

void main() => runApp(const MyFapApp());

class MyFapApp extends StatelessWidget {
  const MyFapApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MyFAP Demo',
    theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
    home: const LoginScreen(),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiClient();
  Map<String, dynamic>? _user;
  dynamic _data;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await _api.login(_email.text.trim(), _password.text);
      _password.clear();
      if (mounted) setState(() => _user = user);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
      final data = await _api.request('GET', '/schedule?from=$from&to=$to');
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await _api.logout();
      if (mounted) {
        setState(() {
          _user = null;
          _data = null;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MyFAP • môi trường phát triển')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_user == null)
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Nhập email hợp lệ'
                            : null,
                      ),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _login,
                        child: const Text('Đăng nhập'),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  '${_user!['name']} • ${_user!['role']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Tải lịch học / lịch dạy'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _logout,
                  child: const Text('Đăng xuất'),
                ),
                if (_data is List)
                  ...(_data as List).map(
                    (dynamic row) => Card(
                      child: ListTile(
                        title: Text(
                          '${row['section_code']} • ${row['course']}',
                        ),
                        subtitle: Text(
                          '${DateTime.parse(row['start_at'] as String).toLocal()}\nPhòng ${row['room_name']}',
                        ),
                      ),
                    ),
                  ),
              ],
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
