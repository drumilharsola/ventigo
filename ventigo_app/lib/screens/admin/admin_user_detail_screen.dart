import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Semantics(header: true, child: Text('User Detail', style: AppTypography.title(fontSize: 22)))),
      body: Center(child: Text('User Detail', style: AppTypography.body())),
    );
  }
}
