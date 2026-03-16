import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Semantics(header: true, child: Text('Reports', style: AppTypography.title(fontSize: 22)))),
      body: Center(child: Text('Reports', style: AppTypography.body())),
    );
  }
}
