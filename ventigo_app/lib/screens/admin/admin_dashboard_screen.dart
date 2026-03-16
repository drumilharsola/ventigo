import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Semantics(header: true, child: Text('Admin Dashboard', style: AppTypography.title(fontSize: 22)))),
      body: Center(child: Text('Admin Dashboard', style: AppTypography.body())),
    );
  }
}
