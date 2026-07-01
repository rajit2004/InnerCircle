class User {
  final String id;
  final String email;
  final String role;
  final String subscriptionTier;
  final String? token;

  User({
    required this.id,
    required this.email,
    required this.role,
    this.subscriptionTier = 'free',
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['sub'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'USER',
      subscriptionTier:
          json['subscriptionTier'] ?? json['subscription_tier'] ?? 'free',
      token: json['token'],
    );
  }
}
