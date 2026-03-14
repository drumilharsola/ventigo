class ChatMessage {
  final String type;
  final String from;
  final String? fromSession;
  final String text;
  final double ts;
  final String? clientId;

  const ChatMessage({
    this.type = 'message',
    required this.from,
    this.fromSession,
    required this.text,
    required this.ts,
    this.clientId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      type: json['type'] as String? ?? 'message',
      from: json['from'] as String,
      fromSession: json['from_session'] as String?,
      text: json['text'] as String,
      ts: (json['ts'] as num).toDouble(),
      clientId: json['client_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        if (clientId != null) 'client_id': clientId,
      };
}

/// Session marker for transcript display - not a real message.
class SessionMarker {
  final String event; // "started" | "ended"
  final String roomId;
  final double ts;

  const SessionMarker({
    required this.event,
    required this.roomId,
    required this.ts,
  });
}

/// Union of items that can appear in the transcript.
sealed class TranscriptItem {
  double get ts;
}

class TranscriptMessage extends TranscriptItem {
  final String from;
  final String? fromSession;
  final String text;
  @override
  final double ts;
  final String? clientId;
  final String? replyTo;     // clientId of the message being replied to
  final String? replyText;   // preview text of the replied message
  final String? replyFrom;   // author of the replied message

  TranscriptMessage({required this.from, this.fromSession, required this.text, required this.ts, this.clientId, this.replyTo, this.replyText, this.replyFrom});
}

class TranscriptMarker extends TranscriptItem {
  final String event;
  final String roomId;
  @override
  final double ts;

  TranscriptMarker({required this.event, required this.roomId, required this.ts});
}
