import 'package:flutter/material.dart';

import '../widgets/student_section_placeholder.dart';

class EnrollmentScreen extends StatelessWidget {
  const EnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudentSectionPlaceholder(icon: Icons.school, title: 'Đăng ký môn');
}
