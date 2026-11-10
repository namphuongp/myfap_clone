import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/academic/academic_widgets.dart';
import '../repositories/head_repository.dart';

class HeadCoursesScreen extends StatelessWidget {
  const HeadCoursesScreen({super.key, required this.repository});
  final HeadRepository repository;
  @override
  Widget build(BuildContext context) =>
      HeadCatalogPanel(repository: repository);
}

class HeadCatalogPanel extends StatefulWidget {
  const HeadCatalogPanel({
    super.key,
    required this.repository,
    this.assignments = false,
  });
  final HeadRepository repository;
  final bool assignments;
  @override
  State<HeadCatalogPanel> createState() => _HeadCatalogPanelState();
}

class _HeadCatalogPanelState extends State<HeadCatalogPanel> {
  final _search = TextEditingController();
  List<Json> _items = [];
  Json? _options;
  int _page = 1, _total = 0;
  bool _more = false, _loading = true;
  String? _semester, _course, _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.options(),
        widget.repository.list(
          widget.assignments ? 'sections' : 'courses',
          search: _search.text.trim(),
          semester: _semester,
          course: _course,
          page: _page,
        ),
      ]);
      if (mounted) {
        setState(() {
          _options = results[0];
          _items = widget.repository.rows(results[1]['items']);
          _total = results[1]['total'] as int;
          _more = results[1]['has_more'] == true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Json? row) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => widget.assignments
          ? _AssignmentDialog(
              repository: widget.repository,
              row: row!,
              lecturers: widget.repository.rows(_options!['lecturers']),
            )
          : _CourseDialog(repository: widget.repository, row: row),
    );
    if (changed == true && mounted) {
      if (row == null) _page = 1;
      await _load();
    }
  }

  Widget _filter(
    String label,
    String? selected,
    List<Json> rows,
    String field,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    initialValue: selected ?? '',
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('Tất cả')),
      for (final r in rows)
        DropdownMenuItem(
          value: r['id'] as String,
          child: Text('${r[field]}', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _loading
        ? null
        : (v) {
            setState(() {
              changed(v == '' ? null : v);
              _page = 1;
            });
            _load();
          },
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    enabled: !_loading,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: widget.assignments
                          ? 'Tìm mã lớp'
                          : 'Tìm mã hoặc tên môn',
                      counterText: '',
                    ),
                    onSubmitted: (_) {
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Tìm kiếm',
                  onPressed: _loading
                      ? null
                      : () {
                          _page = 1;
                          _load();
                        },
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (!widget.assignments)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _edit(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm môn học'),
                ),
              ),
            if (widget.assignments && _options != null) ...[
              _filter(
                'Học kỳ',
                _semester,
                widget.repository.rows(_options!['semesters']),
                'code',
                (v) => _semester = v,
              ),
              _filter(
                'Môn học',
                _course,
                widget.repository.rows(_options!['courses']),
                'name',
                (v) => _course = v,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Phân công trên lớp do cán bộ mở. Chỉ đổi giảng viên khi lớp chưa có buổi học.',
                ),
              ),
            ],
          ],
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
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
                    if (!_loading && _items.isEmpty)
                      LoadMessage(
                        message: widget.assignments
                            ? 'Chưa có lớp phù hợp. Cán bộ cần mở lớp trước.'
                            : 'Chưa có môn phù hợp.',
                      ),
                    for (final row in _items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.assignments
                                    ? '${row['code']} • ${row['course']}'
                                    : '${row['code']} • ${row['name']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (widget.assignments) ...[
                                Text(
                                  '${row['semester_code']}\nGiảng viên: ${row['lecturer'] ?? '—'} • ${row['lecturer_code'] ?? ''}\nSố buổi đã xếp: ${row['session_count']}',
                                ),
                                if (row['session_count'] != 0)
                                  const Text(
                                    'Đã khóa phân công vì lớp có buổi học.',
                                  ),
                              ],
                              OutlinedButton.icon(
                                onPressed:
                                    _loading ||
                                        (widget.assignments &&
                                            row['session_count'] != 0)
                                    ? null
                                    : () => _edit(row),
                                icon: Icon(
                                  widget.assignments
                                      ? Icons.person_add_alt
                                      : Icons.edit,
                                ),
                                label: Text(
                                  widget.assignments
                                      ? 'Phân công giảng viên'
                                      : 'Sửa môn học',
                                ),
                              ),
                            ],
                          ),
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
            onPressed: _loading || _page == 1
                ? null
                : () {
                    _page--;
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Trang $_page • $_total ${widget.assignments ? 'lớp' : 'môn'}'),
          IconButton(
            tooltip: 'Trang sau',
            onPressed: _loading || !_more
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

class _CourseDialog extends StatefulWidget {
  const _CourseDialog({required this.repository, this.row});
  final HeadRepository repository;
  final Json? row;
  @override
  State<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<_CourseDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(
    text: widget.row?['code'] as String?,
  );
  late final _name = TextEditingController(
    text: widget.row?['name'] as String?,
  );
  bool _busy = false, _conflict = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveCourse(
        widget.row,
        _code.text.trim(),
        _name.text.trim(),
      );
      if (mounted) {
        showMessage(context, 'Đã lưu môn học');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _conflict = e is ApiException && e.statusCode == 409;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.row == null ? 'Thêm môn học' : 'Sửa môn học'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Môn học thuộc bộ môn của bạn. Mã môn có lớp liên quan sẽ không được thay đổi.',
              ),
              TextFormField(
                controller: _code,
                enabled: !_busy && !_conflict,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Mã môn'),
                validator: (v) =>
                    v == null || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v.trim())
                    ? 'Nhập mã gồm chữ, số, dấu _ hoặc -'
                    : null,
              ),
              TextFormField(
                controller: _name,
                enabled: !_busy && !_conflict,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Tên môn'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nhập tên môn' : null,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _conflict),
          child: Text(_conflict ? 'Đóng và tải lại' : 'Hủy'),
        ),
        FilledButton(
          onPressed: _busy || _conflict ? null : _save,
          child: const Text('Lưu môn học'),
        ),
      ],
    ),
  );
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({
    required this.repository,
    required this.row,
    required this.lecturers,
  });
  final HeadRepository repository;
  final Json row;
  final List<Json> lecturers;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  String? _selected, _error;
  bool _busy = false, _conflict = false;
  @override
  void initState() {
    super.initState();
    _selected =
        widget.lecturers.any((r) => r['id'] == widget.row['lecturer_id'])
        ? widget.row['lecturer_id'] as String
        : null;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.assign(widget.row, _selected!);
      if (mounted) {
        showMessage(context, 'Đã cập nhật phân công');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _conflict = e is ApiException && e.statusCode == 409;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Phân công giảng viên'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.row['code']} • ${widget.row['course']}\n${widget.row['semester_code']}',
            ),
            if (widget.lecturers.isEmpty)
              const Text('Bộ môn chưa có giảng viên hoạt động.'),
            DropdownButtonFormField<String>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Giảng viên trong bộ môn',
              ),
              items: [
                for (final r in widget.lecturers)
                  DropdownMenuItem(
                    value: r['id'] as String,
                    child: Text(
                      '${r['name']} • ${r['user_code']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy || _conflict
                  ? null
                  : (v) => setState(() => _selected = v),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Xác nhận sẽ cập nhật giảng viên phụ trách lớp. Cán bộ tiếp tục xếp ngày, ca và phòng.',
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _conflict),
          child: Text(_conflict ? 'Đóng và tải lại' : 'Hủy'),
        ),
        FilledButton(
          onPressed:
              _busy ||
                  _conflict ||
                  _selected == null ||
                  _selected == widget.row['lecturer_id']
              ? null
              : _save,
          child: const Text('Xác nhận phân công'),
        ),
      ],
    ),
  );
}
