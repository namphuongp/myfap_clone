import 'package:flutter/material.dart';

import '../widgets/student_section_placeholder.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) => const StudentSectionPlaceholder(
    icon: Icons.notifications,
    title: 'Thông báo học vụ',
  );
}
