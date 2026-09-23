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

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
