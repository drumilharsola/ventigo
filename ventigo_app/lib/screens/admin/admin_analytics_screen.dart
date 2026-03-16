import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(title: Semantics(header: true, child: Text('Analytics', style: AppTypography.title(fontSize: 22)))),
      body: Center(child: Text('Analytics', style: AppTypography.body())),
    );
  }
}
