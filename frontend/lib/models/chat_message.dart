class ChatMessage {
  final String role;
  final String content;
  final DateTime? timestamp;

  ChatMessage({required this.role, required this.content, this.timestamp});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
