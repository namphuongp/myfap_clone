import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/academic/academic_widgets.dart';
import '../repositories/head_repository.dart';
import '../widgets/head_ui.dart';

/// Danh sách giảng viên với tìm kiếm, lọc trạng thái và phân trang.
class HeadLecturersScreen extends StatefulWidget {
  const HeadLecturersScreen({super.key, required this.repository});
  final HeadRepository repository;
  @override
  State<HeadLecturersScreen> createState() => _LecturersState();
}

class _LecturersState extends State<HeadLecturersScreen> {
  final _search = TextEditingController();
  List<Json> _items = [];
  String _status = 'ALL';
  String? _error;
  int _page = 1, _total = 0, _generation = 0;
  bool _busy = true, _more = false;
  @override
  // Tải dữ liệu ban đầu khi mở màn hình.
  void initState() {
    super.initState();
    _load();
  }

  @override
  // Giải phóng controller tìm kiếm khi rời danh sách.
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Tải danh sách từ API; generation ngăn kết quả cũ ghi đè lần tải mới hơn.
  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.lecturers(
        search: _search.text.trim(),
        status: _status,
        page: _page,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _items = widget.repository.rows(result['items']);
          _total = result['total'] as int;
          _more = result['has_more'] == true;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = '$e');
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  /// Mở form thêm giảng viên; tạo thành công thì về trang đầu và tải lại.
  Future<void> _create() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _withNavigation(_LecturerEditor(repository: widget.repository)),
      ),
    );
    if (changed == true && mounted) {
      _page = 1;
      await _load();
    }
  }

  /// Mở chi tiết theo ID và làm mới danh sách sau khi quay về.
  Future<void> _open(Json row) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _withNavigation(
          _LecturerDetail(
            repository: widget.repository,
            id: row['id'] as String,
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  /// Truyền điều hướng HEAD sang route mới nếu trang hiện tại có scope.
  Widget _withNavigation(Widget child) {
    final navigation = HeadNavigationScope.maybeOf(context);
    return navigation == null
        ? child
        : HeadNavigationScope(
            onHome: navigation.onHome,
            onProfile: navigation.onProfile,
            child: child,
          );
  }

  @override
  // Dựng vùng tìm kiếm/lọc, danh sách kết quả và các nút chuyển trang.
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: HeadPanel(
          child: Column(
            children: [
              const HeadPanelTitle('Quản lý giảng viên'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      enabled: !_busy,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Tìm mã, tên hoặc email',
                        counterText: '',
                      ),
                      onSubmitted: (_) {
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tìm giảng viên',
                    onPressed: _busy
                        ? null
                        : () {
                            _page = 1;
                            _load();
                          },
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: 'Tải lại giảng viên',
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                        DropdownMenuItem(
                          value: 'ACTIVE',
                          child: Text('Đang hoạt động'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVE',
                          child: Text('Ngừng hoạt động'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) {
                              setState(() {
                                _status = v!;
                                _page = 1;
                              });
                              _load();
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Thêm giảng viên'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
      Expanded(
        child: _error != null
            ? Center(
                child: LoadMessage(message: _error!, retry: _load),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (!_busy && _items.isEmpty)
                      const LoadMessage(
                        message: 'Không có giảng viên phù hợp trong bộ môn.',
                      ),
                    for (final row in _items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        shadowColor: const Color(0x101A304B),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE7F1FF),
                            foregroundColor: const Color(0xFF1768B6),
                            child: Icon(
                              row['active'] == true
                                  ? Icons.person
                                  : Icons.person_off,
                            ),
                          ),
                          title: Text('${row['name']} • ${row['user_code']}'),
                          subtitle: Text(
                            '${row['email']}\n${row['active'] == true ? 'Đang hoạt động' : 'Ngừng hoạt động'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(row),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Trang trước',
            onPressed: _busy || _page == 1
                ? null
                : () {
                    _page--;
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              'Trang $_page • $_total giảng viên',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Trang sau',
            onPressed: _busy || !_more
                ? null
                : () {
                    _page++;
                    _load();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  );
}

/// Trang chi tiết hồ sơ, trạng thái tài khoản và số buổi dạy của giảng viên.
class _LecturerDetail extends StatefulWidget {
  const _LecturerDetail({required this.repository, required this.id});
  final HeadRepository repository;
  final String id;
  @override
  State<_LecturerDetail> createState() => _DetailState();
}

class _DetailState extends State<_LecturerDetail> {
  Json? _data;
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tải hồ sơ theo ID; quản lý trạng thái chờ, lỗi và khả năng thử lại.
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Lấy dữ liệu chi tiết mới nhất từ API, không dùng lại bản ghi danh sách.
      final data = await widget.repository.lecturer(widget.id);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mở form sửa bằng dữ liệu chi tiết; lưu thành công thì tải lại hồ sơ.
  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) {
          final navigation = HeadNavigationScope.maybeOf(context);
          final editor = _LecturerEditor(
            repository: widget.repository,
            row: _data,
          );
          return navigation == null
              ? editor
              : HeadNavigationScope(
                  onHome: navigation.onHome,
                  onProfile: navigation.onProfile,
                  child: editor,
                );
        },
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  // Hiển thị hồ sơ, thống kê giảng dạy và nút mở form chỉnh sửa.
  Widget build(BuildContext context) => HeadScaffold(
    appBar: AppBar(title: const Text('Chi tiết giảng viên')),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: LoadMessage(message: _error!, retry: _load),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeadPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeadPanelTitle('${_data!['name']}'),
                      HeadStatus(_data!['active'] == true),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE9EAF0)),
                      HeadInfo('Mã giảng viên', '${_data!['user_code']}'),
                      HeadInfo('Email', '${_data!['email']}'),
                      HeadInfo(
                        'Điện thoại',
                        '${_data!['phone'] ?? 'Chưa cập nhật'}',
                      ),
                      HeadInfo(
                        'Địa chỉ',
                        '${_data!['address'] ?? 'Chưa cập nhật'}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HeadPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const HeadPanelTitle(
                        'Thông tin giảng dạy',
                        icon: Icons.bar_chart_rounded,
                        orange: true,
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Tổng buổi dạy: ${_data!['teaching']['total_sessions']}\nĐang diễn ra / sắp tới: ${_data!['teaching']['upcoming_sessions']}\nĐã hoàn thành: ${_data!['teaching']['completed_sessions']}',
                          style: const TextStyle(
                            color: headNavy,
                            height: 1.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Sửa thông tin giảng viên'),
                ),
              ],
            ),
          ),
  );
}

/// Form thêm/sửa; row rỗng là tạo tài khoản, có row là cập nhật hồ sơ.
class _LecturerEditor extends StatefulWidget {
  const _LecturerEditor({required this.repository, this.row});
  final HeadRepository repository;
  final Json? row;
  @override
  State<_LecturerEditor> createState() => _EditorState();
}

class _EditorState extends State<_LecturerEditor> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(
    text: widget.row?['user_code'] as String?,
  );
  late final _name = TextEditingController(
    text: widget.row?['name'] as String?,
  );
  late final _email = TextEditingController(
    text: widget.row?['email'] as String?,
  );
  late final _phone = TextEditingController(
    text: widget.row?['phone'] as String?,
  );
  late final _address = TextEditingController(
    text: widget.row?['address'] as String?,
  );
  final _password = TextEditingController(), _confirm = TextEditingController();
  late bool _active = widget.row?['active'] != false;
  bool _busy = false, _conflict = false, _obscure = true;
  String? _error;
  /// Quyết định các trường và thao tác chỉ áp dụng khi tạo tài khoản mới.
  bool get _creating => widget.row == null;
  @override
  void dispose() {
    // Giải phóng toàn bộ controller khi đóng form.
    for (final c in [
      _code,
      _name,
      _email,
      _phone,
      _address,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Kiểm tra form, xin xác nhận rồi gửi dữ liệu tạo/cập nhật qua repository.
  /// Khi cập nhật gặp HTTP 409, khóa form để người dùng đóng và tải lại dữ liệu.
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    // Đánh dấu thay đổi email/trạng thái để hiện thông tin về phiên đăng nhập.
    final sensitive =
        !_creating &&
        (_active != widget.row!['active'] ||
            _email.text.trim().toLowerCase() != widget.row!['email']);
    final ok = await showHeadDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          _creating ? 'Tạo tài khoản giảng viên?' : 'Lưu thông tin giảng viên?',
        ),
        content: Text(
          '${_name.text.trim()} • ${_email.text.trim()}${sensitive ? '\nĐổi email hoặc ngừng hoạt động sẽ thu hồi các phiên đăng nhập của giảng viên.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận lưu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Chuẩn hóa dữ liệu; chỉ gửi mã/mật khẩu khi tạo và active khi cập nhật.
      await widget.repository.saveLecturer(widget.row, {
        'name': _name.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        if (_creating) 'user_code': _code.text.trim(),
        if (_creating) 'password': _password.text,
        if (!_creating) 'active': _active,
      });
      if (mounted) {
        showMessage(
          context,
          _creating
              ? 'Đã tạo tài khoản giảng viên'
              : 'Đã lưu thông tin giảng viên',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _conflict = e is ApiException && e.statusCode == 409 && !_creating;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  // Dựng form và kiểm tra từng trường; chặn quay lại khi đang gửi dữ liệu.
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: HeadScaffold(
      appBar: AppBar(
        title: Text(_creating ? 'Thêm giảng viên' : 'Sửa giảng viên'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: HeadPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeadPanelTitle(
                  _creating
                      ? 'Tài khoản giảng viên mới'
                      : 'Thông tin giảng viên',
                ),
                const Text(
                  'Giảng viên được quản lý trong bộ môn của bạn. Mã giảng viên và bộ môn không thay đổi sau khi tạo.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _code,
                  enabled: _creating && !_busy && !_conflict,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Mã giảng viên'),
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v.trim())
                      ? 'Nhập mã gồm chữ, số, _ hoặc -'
                      : null,
                ),
                TextFormField(
                  controller: _name,
                  enabled: !_busy && !_conflict,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Nhập họ và tên' : null,
                ),
                TextFormField(
                  controller: _email,
                  enabled: !_busy && !_conflict,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email đăng nhập',
                  ),
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? 'Nhập email hợp lệ'
                      : null,
                ),
                TextFormField(
                  controller: _phone,
                  enabled: !_busy && !_conflict,
                  maxLength: 16,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  validator: (v) =>
                      v != null &&
                          v.trim().isNotEmpty &&
                          !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v.trim())
                      ? 'Nhập 9–15 chữ số'
                      : null,
                ),
                TextFormField(
                  controller: _address,
                  enabled: !_busy && !_conflict,
                  maxLength: 250,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                ),
                const SizedBox(height: 8),
                HeadPanelTitle(
                  _creating ? 'Bảo mật tài khoản' : 'Trạng thái tài khoản',
                  icon: Icons.manage_accounts_rounded,
                  orange: true,
                ),
                if (_creating) ...[
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu ban đầu',
                      suffixIcon: IconButton(
                        tooltip: 'Hiện hoặc ẩn mật khẩu',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 12
                        ? 'Mật khẩu cần ít nhất 12 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu',
                    ),
                    validator: (v) => v != _password.text
                        ? 'Mật khẩu nhập lại chưa khớp'
                        : null,
                  ),
                ] else ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đang hoạt động'),
                    value: _active,
                    onChanged: _busy || _conflict
                        ? null
                        : (v) => setState(() => _active = v),
                  ),
                  const Text(
                    'Không ngừng hoạt động khi giảng viên còn buổi dạy đang diễn ra hoặc sắp tới. Dữ liệu lịch sử được giữ nguyên.',
                  ),
                ],
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_conflict)
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Đóng và tải lại dữ liệu'),
                  ),
                if (_busy) const LinearProgressIndicator(),
                FilledButton.icon(
                  onPressed: _busy || _conflict ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu giảng viên'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
