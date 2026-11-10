import 'package:flutter/material.dart';

import '../repositories/head_repository.dart';
import 'head_courses_screen.dart';

class HeadAssignmentsScreen extends StatelessWidget {
  const HeadAssignmentsScreen({super.key, required this.repository});
  final HeadRepository repository;
  @override
  Widget build(BuildContext context) =>
      HeadCatalogPanel(repository: repository, assignments: true);
}
