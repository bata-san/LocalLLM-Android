enum Role { user, assistant }

class ChatMessage {
  final int id;
  final Role role;
  final String content;
  final bool isStreaming;
  final DateTime timestamp;

  const ChatMessage({
    this.id = 0,
    required this.role,
    required this.content,
    this.isStreaming = false,
    required this.timestamp,
  });

  ChatMessage copyWith({String? content, bool? isStreaming}) => ChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    isStreaming: isStreaming ?? this.isStreaming,
    timestamp: timestamp,
  );

  Map<String, dynamic> toMap() => {
    'role': role.name,
    'content': content,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] as int,
    role: Role.values.byName(m['role'] as String),
    content: m['content'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
  );
}
