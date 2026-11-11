import 'package:flutter/material.dart';

import '../../lecturer/widgets/lecturer_ui.dart' as shared;

// Reuse the existing role style without editing any other role or global theme.
ThemeData headTheme(ThemeData base) => shared.lecturerTheme(base);
const headNavy = shared.lecturerNavy;
const headOrange = shared.lecturerOrange;
const headMuted = shared.lecturerMuted;

Future<T?> showHeadDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  builder: (c) => Theme(data: headTheme(Theme.of(context)), child: builder(c)),
);

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
    child: Scaffold(
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

class HeadNavigationScope extends InheritedWidget {
  const HeadNavigationScope({
    super.key,
    required this.onHome,
    required this.onProfile,
    required super.child,
  });
  final VoidCallback onHome, onProfile;
  static HeadNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeadNavigationScope>();
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
  bool updateShouldNotify(HeadNavigationScope oldWidget) =>
      onHome != oldWidget.onHome || onProfile != oldWidget.onProfile;
}

class HeadHeading extends StatelessWidget {
  const HeadHeading(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => shared.SectionHeading(title);
}

class HeadStatus extends StatelessWidget {
  const HeadStatus(this.active, {super.key});
  final bool active;
  @override
  Widget build(BuildContext context) => shared.StatusPill(
    active ? 'Đang hoạt động' : 'Ngừng hoạt động',
    color: active ? shared.lecturerGreen : headMuted,
  );
}

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
