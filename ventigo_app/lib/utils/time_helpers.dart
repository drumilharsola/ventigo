/// Shared time-formatting helpers used across multiple screens.
import 'package:intl/intl.dart';

/// Parse a Unix-epoch-seconds string into a local [DateTime].
DateTime parseTs(String ts) {
  final epoch = int.tryParse(ts) ?? 0;
  return DateTime.fromMillisecondsSinceEpoch(epoch * 1000).toLocal();
}

/// Relative label: "just now", "5m ago", "2h ago".
String timeAgo(dynamic postedAt) {
  final secs = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (int.tryParse('$postedAt') ?? 0);
  if (secs < 60) return 'just now';
  if (secs < 3600) return '${secs ~/ 60}m ago';
  return '${secs ~/ 3600}h ago';
}

/// Countdown display: "02:45".
String formatRemaining(int secs) {
  return '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
}

/// "Today", "Yesterday", or "Mar 5, 2026".
String formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMM d, yyyy').format(dt);
}

/// Short date: "Today", "Yesterday", or "Mar 5".
String formatDateShort(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMM d').format(dt);
}

/// 12-hour time: "3:30 PM".
String formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

/// "Today at 3:30 PM", "Yesterday at 3:30 PM", or "Mar 5 at 3:30 PM".
String formatDateTimeAt(DateTime dt) {
  final time = formatTime(dt);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return 'Today at $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday at $time';
  return '${DateFormat('MMM d').format(dt)} at $time';
}

/// Full date + time from epoch seconds: "Mar 5, 2026, 3:30 PM".
String formatFullDateTime(int ts) {
  if (ts > 1000000000) {
    return DateFormat.yMMMd().add_jm().format(
      DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal(),
    );
  }
  return ts.toString();
}

/// Parse a raw epoch string/double and return "Mar 5, 2026".
String formatTimestamp(String raw) {
  final ts = int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
  if (ts != null && ts > 1000000000) {
    return DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
  }
  return raw;
}
