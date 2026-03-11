import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../state/auth_provider.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() =>
      _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  AnalyticsOverview? _overview;
  List<TimeseriesPoint> _tsData = [];
  String _metric = 'dau';
  int _days = 30;
  bool _loading = true;

  static const _metrics = {
    'dau': 'Daily Active Users',
    'sessions': 'Sessions',
    'registrations': 'Registrations',
    'reports': 'Reports',
    'board_posts': 'Board Posts',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadOverview(), _loadTimeseries()]);
    setState(() => _loading = false);
  }

  Future<void> _loadOverview() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final data = await ApiClient().adminAnalyticsOverview(token);
      if (mounted) setState(() => _overview = data);
    } catch (_) {}
  }

  Future<void> _loadTimeseries() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final now = DateTime.now();
    final from = now.subtract(Duration(days: _days - 1));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      final data = await ApiClient()
          .adminAnalyticsTimeseries(token, _metric, fmt(from), fmt(now));
      if (mounted) setState(() => _tsData = data);
    } catch (_) {}
  }

  String _fmtDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_overview != null) _buildOverviewCards(_overview!, theme),
                  const SizedBox(height: 24),
                  _buildChartSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards(AnalyticsOverview o, ThemeData theme) {
    final items = [
      ('DAU', '${o.dau}'),
      ('MAU', '${o.mau}'),
      ('Sessions', '${o.sessionsToday}'),
      ('Registrations', '${o.registrationsToday}'),
      ('Reports', '${o.reportsToday}'),
      ('Board Posts', '${o.boardPostsToday}'),
      ('Avg Duration', _fmtDuration(o.avgSessionDuration)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: items
          .map((e) => Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(e.$1,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(e.$2,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              )))
          .toList(),
    );
  }

  Widget _buildChartSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _metric,
                    isExpanded: true,
                    items: _metrics.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _metric = v);
                        _loadTimeseries();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _days,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7d')),
                    DropdownMenuItem(value: 14, child: Text('14d')),
                    DropdownMenuItem(value: 30, child: Text('30d')),
                    DropdownMenuItem(value: 60, child: Text('60d')),
                    DropdownMenuItem(value: 90, child: Text('90d')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _days = v);
                      _loadTimeseries();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: _tsData.isEmpty
                  ? const Center(child: Text('No data'))
                  : CustomPaint(
                      size: const Size(double.infinity, 150),
                      painter: _ChartPainter(
                        data: _tsData,
                        color: theme.colorScheme.primary,
                      ),
                    ),
            ),
            if (_tsData.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_tsData.first.date,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey)),
                  Text(_tsData.last.date,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<TimeseriesPoint> data;
  final Color color;

  _ChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal > 0 ? maxVal.toDouble() : 1.0;
    const pad = 4.0;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x =
          pad + (i / (data.length - 1).clamp(1, double.infinity)) * (size.width - 2 * pad);
      final y = size.height -
          pad -
          (data[i].value / effectiveMax) * (size.height - 2 * pad);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.data != data || old.color != color;
}
