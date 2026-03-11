import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/admin_provider.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key});

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  final _controller = TextEditingController();

  void _search() {
    final id = _controller.text.trim();
    if (id.isNotEmpty) {
      ref.read(adminProvider.notifier).loadUser(id);
    }
  }

  String _fmtDate(String ts) {
    if (ts.isEmpty || ts == '0') return 'N/A';
    final ms = int.tryParse(ts);
    if (ms == null) return ts;
    return DateTime.fromMillisecondsSinceEpoch(ms * 1000).toLocal().toString().substring(0, 10);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final user = state.selectedUser;

    return Scaffold(
      appBar: AppBar(title: const Text('User Lookup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter session ID...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(state.error!, style: const TextStyle(color: Colors.red)),
              ),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (user != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.username.isNotEmpty ? user.username : 'No profile',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (user.suspended == '1')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                              child: const Text('SUSPENDED', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          const SizedBox(width: 4),
                          if (user.isAdmin == '1')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                              child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow('Session ID', user.sessionId),
                      _InfoRow('Speak count', user.speakCount),
                      _InfoRow('Listen count', user.listenCount),
                      _InfoRow('Email verified', user.emailVerified == '1' ? 'Yes' : 'No'),
                      _InfoRow('Created', _fmtDate(user.createdAt)),
                      _InfoRow('Reports against', '${user.reportCount}'),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: user.suspended == '1' ? Colors.green : Colors.red,
                              ),
                              onPressed: () => ref.read(adminProvider.notifier).toggleSuspend(
                                    user.sessionId,
                                    user.suspended == '1',
                                  ),
                              child: Text(user.suspended == '1' ? 'Unsuspend' : 'Suspend'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: user.isAdmin == '1' ? Colors.grey : Colors.blue,
                              ),
                              onPressed: () => ref.read(adminProvider.notifier).toggleAdmin(
                                    user.sessionId,
                                    user.isAdmin == '1',
                                  ),
                              child: Text(user.isAdmin == '1' ? 'Revoke Admin' : 'Grant Admin'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
