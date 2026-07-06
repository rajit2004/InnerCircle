class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String subscriptionTier;
  final int messagesUsedToday;
  final int dailyMessageLimit; // 0 = unlimited
  final DateTime? memberSince;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    required this.subscriptionTier,
    required this.messagesUsedToday,
    required this.dailyMessageLimit,
    this.memberSince,
  });

  bool get isPremium => subscriptionTier.toLowerCase() == 'premium';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      subscriptionTier: json['subscriptionTier'] ?? 'free',
      messagesUsedToday: json['messagesUsedToday'] ?? 0,
      dailyMessageLimit: json['dailyMessageLimit'] ?? 0,
      memberSince: json['memberSince'] != null
          ? DateTime.tryParse(json['memberSince'])
          : null,
    );
  }
}
