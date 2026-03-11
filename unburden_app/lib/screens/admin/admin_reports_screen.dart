import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/admin_provider.dart';
import '../../services/api_client.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadReports());
  }

  String _fmtTime(String ts) {
    if (ts.isEmpty) return '';
    final ms = int.tryParse(ts);
    if (ms == null) return ts;
    return DateTime.fromMillisecondsSinceEpoch(ms * 1000).toString().substring(0, 16);
  }

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'harassment':
        return Colors.red;
      case 'spam':
        return Colors.orange;
      case 'hate_speech':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: state.loading && state.reports.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.reports.isEmpty
              ? const Center(child: Text('No reports found'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(adminProvider.notifier).loadReports(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.reports.length,
                    itemBuilder: (context, i) {
                      final r = state.reports[i];
                      final expanded = _expandedId == r.reportId;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setState(() {
                            _expandedId = expanded ? null : r.reportId;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _reasonColor(r.reason),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(r.reason,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                    const Spacer(),
                                    Text(_fmtTime(r.ts), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                if (expanded) ...[
                                  const SizedBox(height: 12),
                                  Text('Reporter: ${r.reporterSession}', style: const TextStyle(fontSize: 13)),
                                  Text('Reported: ${r.reportedSession}', style: const TextStyle(fontSize: 13)),
                                  Text('Room: ${r.roomId}', style: const TextStyle(fontSize: 13)),
                                  if (r.detail.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Detail: ${r.detail}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
