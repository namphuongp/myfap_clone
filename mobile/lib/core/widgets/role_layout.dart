import 'package:flutter/material.dart';

class RoleScaffold extends StatelessWidget {
  const RoleScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: body,
    bottomNavigationBar: bottomNavigationBar == null
        ? null
        : SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).navigationBarTheme.backgroundColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: bottomNavigationBar,
            ),
          ),
  );
}

class RoleHomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const RoleHomeHeader({
    super.key,
    required this.name,
    required this.role,
    required this.leading,
    required this.onProfile,
    this.onLogout,
    this.subtitleColor,
  });

  final String name;
  final String role;
  final Widget leading;
  final Color? subtitleColor;
  final VoidCallback? onProfile;
  final VoidCallback? onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 88,
    centerTitle: false,
    titleSpacing: 16,
    title: Row(
      children: [
        SizedBox(width: 46, height: 46, child: leading),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      _HeaderAction(
        icon: Icons.person_outline_rounded,
        tooltip: 'Hồ sơ cá nhân',
        onPressed: onProfile,
      ),
      if (onLogout != null) ...[
        const SizedBox(width: 10),
        _HeaderAction(
          icon: Icons.logout_rounded,
          tooltip: 'Đăng xuất',
          onPressed: onLogout,
        ),
      ],
      const SizedBox(width: 16),
    ],
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).dividerColor, width: 1.2),
    ),
    child: IconButton(
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
    ),
  );
}
