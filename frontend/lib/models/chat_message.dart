class ChatMessage {
  final String? id;
  final String role;
  final String content;
  final DateTime? timestamp;
  String? reaction;
  bool failed;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.reaction,
    this.failed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String?,
    role: json['role'] as String,
    content: json['content'] as String? ?? '',
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null,
    reaction: json['reaction'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'role': role,
    'content': content,
    if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    if (reaction != null) 'reaction': reaction,
  };
}
