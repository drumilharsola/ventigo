/// Intent helpers - direct port of intent.ts.
enum UserIntent { speak, support }

UserIntent? parseIntent(String? value) {
  if (value == 'speak') return UserIntent.speak;
  if (value == 'support') return UserIntent.support;
  return null;
}

String withIntent(String path, UserIntent? intent) {
  if (intent == null) return path;
  final sep = path.contains('?') ? '&' : '?';
  return '$path${sep}intent=${intent.name}';
}

String intentLabel(UserIntent? intent) {
  if (intent == UserIntent.support) return 'be a listener';
  return 'vent freely';
}

String intentHeading(UserIntent? intent) {
  if (intent == UserIntent.support) return 'Be a Listener.';
  return 'Let it out.';
}

String intentBody(UserIntent? intent) {
  if (intent == UserIntent.support) {
    return 'Hold space for someone. Stay present, listen, and help them feel less alone.';
  }
  return 'You will be matched with one steady listener for a short anonymous conversation.';
}
