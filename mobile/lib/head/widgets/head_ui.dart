import 'package:flutter/material.dart';

import '../../core/widgets/role_layout.dart';

import '../../lecturer/widgets/lecturer_ui.dart' as shared;

// Reuse the existing role style without editing any other role or global theme.
/// Tạo theme của HEAD từ theme dùng chung hiện có.
ThemeData headTheme(ThemeData base) => shared.lecturerTheme(base);
const headNavy = shared.lecturerNavy;
const headOrange = shared.lecturerOrange;
const headMuted = shared.lecturerMuted;

/// Hiển thị hộp thoại với theme HEAD và trả về lựa chọn của người dùng.
Future<T?> showHeadDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  builder: (c) => Theme(data: headTheme(Theme.of(context)), child: builder(c)),
);

/// Khung trang HEAD: áp dụng theme, giới hạn chiều rộng và gắn thanh điều hướng.
class HeadScaffold extends StatelessWidget {
  const HeadScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  @override
  Widget build(BuildContext context) => Theme(
    data: headTheme(Theme.of(context)),
    child: RoleScaffold(
      appBar: appBar,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: body,
        ),
      ),
      bottomNavigationBar:
          bottomNavigationBar ??
          HeadNavigationScope.maybeOf(context)?.buildBar(),
    ),
  );
}

/// Chia sẻ callback về Trang chủ/Hồ sơ cho các màn hình con của HEAD.
class HeadNavigationScope extends InheritedWidget {
  const HeadNavigationScope({
    super.key,
    required this.onHome,
    required this.onProfile,
    required super.child,
  });
  final VoidCallback onHome, onProfile;
  /// Tìm scope gần nhất; trả null nếu widget đang nằm ngoài điều hướng HEAD.
  static HeadNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeadNavigationScope>();
  /// Tạo thanh điều hướng và chọn tab Hồ sơ khi profile bằng true.
  Widget buildBar({bool profile = false}) => NavigationBar(
    selectedIndex: profile ? 1 : 0,
    onDestinationSelected: (index) {
      if (index == 0) onHome();
      if (index == 1 && !profile) onProfile();
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
  );
  @override
  // Cập nhật các widget phụ thuộc khi callback điều hướng thay đổi.
  bool updateShouldNotify(HeadNavigationScope oldWidget) =>
      onHome != oldWidget.onHome || onProfile != oldWidget.onProfile;
}

/// Tiêu đề phân mục sử dụng kiểu trình bày dùng chung.
class HeadHeading extends StatelessWidget {
  const HeadHeading(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => shared.SectionHeading(title);
}

/// Nhãn trạng thái hoạt động của tài khoản giảng viên.
class HeadStatus extends StatelessWidget {
  const HeadStatus(this.active, {super.key});
  final bool active;
  @override
  Widget build(BuildContext context) => shared.StatusPill(
    active ? 'Đang hoạt động' : 'Ngừng hoạt động',
    color: active ? shared.lecturerGreen : headMuted,
  );
}

/// Khối nội dung nền trắng, bo góc và đổ bóng trong các trang HEAD.
class HeadPanel extends StatelessWidget {
  const HeadPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D1A304B),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

/// Tiêu đề panel kèm biểu tượng; orange chọn nhóm màu nhấn cam.
class HeadPanelTitle extends StatelessWidget {
  const HeadPanelTitle(
    this.title, {
    super.key,
    this.icon = Icons.contact_page_rounded,
    this.orange = false,
  });
  final String title;
  final IconData icon;
  final bool orange;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: orange ? const Color(0xFFFFF4D2) : const Color(0xFFE7F1FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: orange ? headOrange : const Color(0xFF1768B6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: headNavy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Hiển thị một cặp nhãn/giá trị trong hồ sơ giảng viên.
class HeadInfo extends StatelessWidget {
  const HeadInfo(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: headMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: headNavy, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}
