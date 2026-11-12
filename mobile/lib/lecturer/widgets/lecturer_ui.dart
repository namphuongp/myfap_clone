import 'package:flutter/material.dart';

const lecturerNavy = Color(0xFF7047EB);
const lecturerNavyDark = Color(0xFF1E1E2D);
const lecturerOrange = Color(0xFFF69A08);
const lecturerBackground = Color(0xFFF8F9FE);
const lecturerMuted = Color(0xFF8C8CA1);
const lecturerGreen = Color(0xFF10B981);

ThemeData lecturerTheme(ThemeData base) => base.copyWith(
  scaffoldBackgroundColor: lecturerBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: lecturerNavy,
    primary: lecturerNavy,
    secondary: lecturerOrange,
    primaryContainer: const Color(0xFFEDE9FE),
    onPrimaryContainer: lecturerNavy,
    surface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFF1E1E2D),
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: 72,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFEBEBF2)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFEBEBF2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFEBEBF2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: lecturerNavy, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: lecturerNavy,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: lecturerNavy,
      minimumSize: const Size(0, 46),
      side: const BorderSide(color: Color(0xFFDDD2FE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: lecturerNavy,
    indicatorColor: const Color(0xFF384552),
    height: 78,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (s) => TextStyle(
        color: s.contains(WidgetState.selected)
            ? lecturerOrange
            : const Color(0xFFCDD6E1),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (s) => IconThemeData(
        color: s.contains(WidgetState.selected)
            ? lecturerOrange
            : const Color(0xFFB8C6D7),
      ),
    ),
  ),
);

class LecturerPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const LecturerPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: lecturerBackground,
    appBar: AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1E1E2D),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: actions,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: child,
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  const SectionHeading(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 16),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: lecturerNavy,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1E1E2D),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyPanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.event_available_outlined,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFFE8EDF4),
            child: Icon(icon, size: 36, color: lecturerMuted),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: lecturerNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: lecturerMuted),
          ),
        ],
      ),
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorPanel(this.message, {super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại'),
        ),
      ],
    ),
  );
}

const requestStatusLabels = {
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Từ chối',
  'INVALIDATED': 'Hết hiệu lực',
  'EXPIRED': 'Quá hạn',
  'CANCELLED': 'Đã hủy',
};

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const StatusPill(this.text, {super.key, this.color = lecturerNavy});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

Future<T?> pushLecturer<T>(BuildContext context, Widget child) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => Theme(data: Theme.of(context), child: child),
      ),
    );
