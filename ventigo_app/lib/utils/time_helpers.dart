/// Shared time-formatting helpers used across multiple screens.

String timeAgo(dynamic postedAt) {
  final secs = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse('$postedAt') ?? 0);
  if (secs < 60) return 'just now';
  if (secs < 3600) return '${secs ~/ 60}m ago';
  return '${secs ~/ 3600}h ago';
}

String formatRemaining(int secs) {
  return '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
}
