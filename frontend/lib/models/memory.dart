class Memory {
  final String id;
  final String fact;
  final int importance;
  final DateTime? lastAccessed;

  Memory({
    required this.id,
    required this.fact,
    this.importance = 1,
    this.lastAccessed,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'] ?? '',
      fact: json['fact'] ?? '',
      importance: json['importance'] ?? 1,
      lastAccessed: json['lastAccessed'] != null
          ? DateTime.parse(json['lastAccessed'])
          : null,
    );
  }
}
