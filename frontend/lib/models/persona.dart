class Persona {
  final String id;
  final String name;
  final String role;
  final String? greeting;
  final String? avatarEmoji;
  final String? systemPrompt;
  final bool active;
  final String subscriptionTier;

  Persona({
    required this.id,
    required this.name,
    required this.role,
    this.greeting,
    this.avatarEmoji,
    this.systemPrompt,
    required this.active,
    required this.subscriptionTier,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      greeting: json['greeting'],
      avatarEmoji: json['avatarEmoji'],
      systemPrompt: json['systemPrompt'],
      active: json['active'] ?? true,
      subscriptionTier: json['subscriptionTier'] ?? 'free',
    );
  }
}