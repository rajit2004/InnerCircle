class Persona {
  final String id;
  final String name;
  final String role;
  final String? greeting;
  final String? avatarEmoji;
  final String? systemPrompt;
  final bool active;
  final String subscriptionTier;

  // FEATURE (custom personas, 2026-07-06): mirrors the backend's
  // PersonaResponse.owned -- true only for a persona this specific user
  // created themselves (see PersonaService.toResponse on the backend).
  // Built-in personas and other users' custom personas always come back
  // false. Drives whether HomeScreen shows a delete option for this card.
  final bool owned;

  Persona({
    required this.id,
    required this.name,
    required this.role,
    this.greeting,
    this.avatarEmoji,
    this.systemPrompt,
    required this.active,
    required this.subscriptionTier,
    this.owned = false,
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
      owned: json['owned'] ?? false,
    );
  }
}