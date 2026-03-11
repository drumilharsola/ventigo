/// Intent helpers — direct port of intent.ts.
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
  if (intent == UserIntent.support) return 'support someone';
  return 'open up';
}

String intentHeading(UserIntent? intent) {
  if (intent == UserIntent.support) return 'Show up for someone.';
  return 'Speak without holding back.';
}

String intentBody(UserIntent? intent) {
  if (intent == UserIntent.support) {
    return 'You will only be asked to listen, stay present, and help someone feel less alone.';
  }
  return 'You will be matched with one steady person for a short anonymous conversation.';
}
