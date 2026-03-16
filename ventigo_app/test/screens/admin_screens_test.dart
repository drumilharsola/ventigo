import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/screens/admin/admin_dashboard_screen.dart';
import 'package:ventigo_app/screens/admin/admin_reports_screen.dart';
import 'package:ventigo_app/screens/admin/admin_tenants_screen.dart';
import 'package:ventigo_app/screens/admin/admin_analytics_screen.dart';
import 'package:ventigo_app/screens/admin/admin_user_detail_screen.dart';

void main() {
  group('AdminDashboardScreen', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminDashboardScreen()),
      );
      expect(find.text('Admin Dashboard'), findsWidgets);
    });
  });

  group('AdminReportsScreen', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminReportsScreen()),
      );
      expect(find.text('Reports'), findsWidgets);
    });
  });

  group('AdminTenantsScreen', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminTenantsScreen()),
      );
      expect(find.text('Tenants'), findsWidgets);
    });
  });

  group('AdminAnalyticsScreen', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminAnalyticsScreen()),
      );
      expect(find.text('Analytics'), findsWidgets);
    });
  });

  group('AdminUserDetailScreen', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminUserDetailScreen()),
      );
      expect(find.text('User Detail'), findsWidgets);
    });
  });
}
