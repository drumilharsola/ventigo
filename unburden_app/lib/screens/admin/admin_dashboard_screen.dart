import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/admin_provider.dart';
import '../../config/brand.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final stats = state.stats;

    return Scaffold(
      appBar: AppBar(
        title: Text('${Brand.appName} Admin'),
      ),
      body: state.loading && stats == null
          ? const Center(child: CircularProgressIndicator())
          : stats == null
              ? Center(child: Text(state.error ?? 'Failed to load', style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: () => ref.read(adminProvider.notifier).loadStats(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatCard(label: 'Active Rooms', value: stats.activeRooms, color: Colors.green),
                      const SizedBox(height: 12),
                      _StatCard(label: 'Queued Users', value: stats.queuedUsers, color: Colors.blue),
                      const SizedBox(height: 12),
                      _StatCard(label: 'Board Requests', value: stats.boardRequests, color: Colors.purple),
                      const SizedBox(height: 12),
                      _StatCard(label: 'Reports', value: stats.totalReports, color: Colors.red),
                      const SizedBox(height: 24),
                      _NavButton(label: 'Analytics', onTap: () => Navigator.pushNamed(context, '/admin/analytics')),
                      const SizedBox(height: 8),
                      _NavButton(label: 'View Reports', onTap: () => Navigator.pushNamed(context, '/admin/reports')),
                      const SizedBox(height: 8),
                      _NavButton(label: 'User Lookup', onTap: () => Navigator.pushNamed(context, '/admin/users')),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey))),
            Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(label),
    );
  }
}
