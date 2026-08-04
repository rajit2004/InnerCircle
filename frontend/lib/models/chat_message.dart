class ChatMessage {
  final String? id;
  final String role;
  final String content;
  final DateTime? timestamp;
  // FEATURE (message reactions, round 12): not final -- updated in place
  // when the user reacts, so the same ChatMessage instance already in
  // _messages can just be mutated and re-rendered via setState, rather than
  // needing to rebuild the whole list to swap in a new immutable instance.
  String? reaction;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.reaction,
  });

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}