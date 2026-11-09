import 'package:flutter/material.dart';

import '../widgets/student_section_placeholder.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudentSectionPlaceholder(icon: Icons.description, title: 'Đơn từ');
}
