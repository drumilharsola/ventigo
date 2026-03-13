import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AdminTenantsScreen extends StatelessWidget {
  const AdminTenantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Text('Tenants', style: AppTypography.title(fontSize: 22))),
      body: Center(child: Text('Tenants', style: AppTypography.body())),
    );
  }
}
