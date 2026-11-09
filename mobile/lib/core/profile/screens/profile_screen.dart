import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../repositories/profile_repository.dart';

const roleLabels = {
  'STUDENT': 'Sinh viên',
  'LECTURER': 'Giảng viên',
  'HEAD': 'Trưởng bộ môn',
  'STAFF': 'Cán bộ',
};
String initialsForName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts
      .skip(parts.length > 1 ? parts.length - 2 : 0)
      .map((part) => String.fromCharCode(part.runes.first))
      .join()
      .toUpperCase();
}

class ProfileScreen extends StatefulWidget {
  final ProfileRepository repository;
  final VoidCallback onSignedOut;
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.onSignedOut,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _dob = TextEditingController();
  UserProfile? _profile;
  String? _date;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _dob.dispose();
    super.dispose();
  }

  void _fill(UserProfile profile) {
    _profile = profile;
    _phone.text = profile.phone ?? '';
    _address.text = profile.address ?? '';
    _date = profile.dateOfBirth;
    _dob.text = _date == null ? '' : _displayDate(_date!);
  }

  String _displayDate(String value) {
    final parts = value.split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _handleError(Object error) async {
    if (error is ApiException && error.statusCode == 401) {
      await widget.repository.clearSession();
      if (mounted) widget.onSignedOut();
    } else if (mounted) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.getProfile();
      if (mounted) setState(() => _fill(profile));
    } catch (error) {
      await _handleError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateContact(
        version: _profile!.version,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        dateOfBirth: _date,
      );
      if (!mounted) return;
      setState(() => _fill(updated));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ')));
    } catch (error) {
      await _handleError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date == null
          ? DateTime(2005, 1, 1)
          : DateTime.parse(_date!),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (selected != null && mounted) {
      setState(() {
        _date =
            '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
        _dob.text = _displayDate(_date!);
      });
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangePasswordDialog(repository: widget.repository),
    );
    if (changed == true && mounted) widget.onSignedOut();
  }

  Widget _info(String label, String value, IconData icon) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: SelectableText(value),
  );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            onPressed: _saving || _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại hồ sơ',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Không tải được hồ sơ',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: colors.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: colors.primary,
                                foregroundColor: colors.onPrimary,
                                child: Text(
                                  initialsForName(_profile!.name),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _profile!.name,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colors.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  roleLabels[_profile!.role] ?? _profile!.role,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              _info(
                                'Mã tài khoản',
                                _profile!.userCode,
                                Icons.badge_outlined,
                              ),
                              _info(
                                'Email',
                                _profile!.email,
                                Icons.mail_outline,
                              ),
                              _info(
                                'Bộ môn',
                                _profile!.departmentName,
                                Icons.school_outlined,
                              ),
                              if (_profile!.role == 'STUDENT')
                                _info(
                                  'Ngành học',
                                  _profile!.majorName,
                                  Icons.menu_book_outlined,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Thông tin liên hệ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('profile-phone'),
                              controller: _phone,
                              enabled: !_saving,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Số điện thoại',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v != null &&
                                      v.trim().isNotEmpty &&
                                      !RegExp(r'^[+0-9 ()-]{7,20}$')
                                          .hasMatch(v.trim())
                                  ? 'Số điện thoại không hợp lệ'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dob,
                              readOnly: true,
                              enabled: !_saving,
                              onTap: _pickDate,
                              decoration: InputDecoration(
                                labelText: 'Ngày sinh',
                                hintText: 'Chưa cập nhật',
                                prefixIcon: const Icon(Icons.cake_outlined),
                                border: const OutlineInputBorder(),
                                suffixIcon: _date == null
                                    ? const Icon(Icons.calendar_month_outlined)
                                    : IconButton(
                                        tooltip: 'Xóa ngày sinh',
                                        onPressed: _saving
                                            ? null
                                            : () => setState(() {
                                                _date = null;
                                                _dob.clear();
                                              }),
                                        icon: const Icon(Icons.clear),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('profile-address'),
                              controller: _address,
                              enabled: !_saving,
                              minLines: 2,
                              maxLines: 3,
                              maxLength: 250,
                              decoration: const InputDecoration(
                                labelText: 'Địa chỉ liên hệ',
                                prefixIcon: Icon(Icons.location_on_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Đang lưu…' : 'Lưu thay đổi'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _changePassword,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Đổi mật khẩu'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tên, mã tài khoản, email, vai trò và ngành học do nhà trường quản lý.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final ProfileRepository repository;
  const ChangePasswordDialog({super.key, required this.repository});
  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _next = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.changePassword(_current.text, _next.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sau khi đổi mật khẩu, bạn cần đăng nhập lại trên các thiết bị.',
                ),
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Nhập mật khẩu hiện tại' : null,
                ),
                TextFormField(
                  controller: _next,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                  validator: (v) => v == null || v.length < 12
                      ? 'Cần ít nhất 12 ký tự'
                      : null,
                ),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới',
                  ),
                  validator: (v) =>
                      v != _next.text ? 'Mật khẩu nhập lại không khớp' : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Đang đổi…' : 'Xác nhận'),
        ),
      ],
    ),
  );
}
