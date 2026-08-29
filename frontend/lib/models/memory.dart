class Memory {
  final String id;
  final String fact;
  final String? content;
  final String? memoryType;
  final int importance;
  final DateTime? lastAccessed;
  final DateTime? deletedAt;

  Memory({
    required this.id,
    required this.fact,
    this.content,
    this.memoryType,
    this.importance = 1,
    this.lastAccessed,
    this.deletedAt,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'] ?? '',
      fact: json['fact'] ?? '',
      content: json['content'],
      memoryType: json['memoryType'],
      importance: json['importance'] ?? 1,
      lastAccessed: json['lastAccessed'] != null
          ? DateTime.tryParse(json['lastAccessed'])
          : null,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'])
          : null,
    );
  }
}
