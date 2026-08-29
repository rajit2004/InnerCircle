class Persona {
  final String id;
  final String name;
  final String role;
  final String? greeting;
  final String? avatarEmoji;
  final String? personality;
  final String? systemPrompt;
  final String? voice;
  final bool active;
  final bool nsfwEnabled;
  final String subscriptionTier;
  final String? userId;

  Persona({
    required this.id,
    required this.name,
    required this.role,
    this.greeting,
    this.avatarEmoji,
    this.personality,
    this.systemPrompt,
    this.voice,
    required this.active,
    this.nsfwEnabled = false,
    required this.subscriptionTier,
    this.userId,
  });

  bool get isOwned => userId != null;

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      greeting: json['greeting'],
      avatarEmoji: json['avatarEmoji'],
      personality: json['personality'],
      systemPrompt: json['systemPrompt'],
      voice: json['voice'],
      active: json['active'] ?? true,
      nsfwEnabled: json['nsfwEnabled'] ?? false,
      subscriptionTier: json['subscriptionTier'] ?? 'free',
      userId: json['userId'],
    );
  }
}