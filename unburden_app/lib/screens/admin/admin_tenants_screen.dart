import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../config/theme.dart';
import '../../state/auth_provider.dart';

class AdminTenantsScreen extends ConsumerStatefulWidget {
  const AdminTenantsScreen({super.key});

  @override
  ConsumerState<AdminTenantsScreen> createState() => _AdminTenantsScreenState();
}

class _AdminTenantsScreenState extends ConsumerState<AdminTenantsScreen> {
  final _keyController = TextEditingController();
  bool _unlocked = false;
  String _adminKey = '';
  List<Tenant> _tenants = [];
  String? _error;
  bool _loading = false;

  // create form
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _domainController = TextEditingController();
  bool _creating = false;

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _unlock() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final tenants = await _api.adminListTenants(key);
      setState(() {
        _adminKey = key;
        _tenants = tenants;
        _unlocked = true;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Invalid admin key'; _loading = false; });
    }
  }

  Future<void> _refresh() async {
    try {
      final tenants = await _api.adminListTenants(_adminKey);
      setState(() => _tenants = tenants);
    } catch (_) {}
  }

  Future<void> _createTenant() async {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    if (id.isEmpty || name.isEmpty) return;
    setState(() { _creating = true; _error = null; });
    try {
      await _api.adminCreateTenant(_adminKey,
          tenantId: id, name: name, domain: _domainController.text.trim());
      _idController.clear();
      _nameController.clear();
      _domainController.clear();
      await _refresh();
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _creating = false);
  }

  Future<void> _toggleActive(Tenant t) async {
    try {
      await _api.adminUpdateTenant(_adminKey, t.tenantId, active: !t.active);
      await _refresh();
    } catch (_) {}
  }

  @override
  void dispose() {
    _keyController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tenant Management')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter the admin API key to manage tenants.',
                  style: TextStyle(color: AppColors.slate, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Admin API Key',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _unlock(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _unlock,
                    child: _loading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Unlock'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Management')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Create form ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Tenant',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                            color: AppColors.charcoal)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _idController,
                            decoration: const InputDecoration(hintText: 'tenant_id', isDense: true),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(hintText: 'Display name', isDense: true),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _domainController,
                            decoration: const InputDecoration(hintText: 'Domain (optional)', isDense: true),
                          ),
                        ),
                        FilledButton(
                          onPressed: _creating ? null : _createTenant,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                          child: Text(_creating ? 'Creating...' : 'Create'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tenant list ──
            ..._tenants.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Opacity(
                opacity: t.active ? 1.0 : 0.5,
                child: Card(
                  child: ListTile(
                    title: Text(t.name, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                    subtitle: Text('ID: ${t.tenantId}${t.domain.isNotEmpty ? ' | ${t.domain}' : ''}',
                        style: TextStyle(fontSize: 12, color: AppColors.slate)),
                    trailing: FilledButton(
                      onPressed: () => _toggleActive(t),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.active ? AppColors.danger : AppColors.success,
                        minimumSize: const Size(80, 32),
                      ),
                      child: Text(t.active ? 'Disable' : 'Enable', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ),
            )),
            if (_tenants.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No tenants found.', style: TextStyle(color: AppColors.slate, fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}
