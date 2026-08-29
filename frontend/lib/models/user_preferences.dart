class UserPreferences {
  final String userId;
  final String? preferredName;
  final String communicationStyle;
  final String responseLength;
  final String interests;
  final String goals;
  final bool memoryEnabled;

  UserPreferences({
    required this.userId,
    this.preferredName,
    this.communicationStyle = 'casual',
    this.responseLength = 'moderate',
    this.interests = '[]',
    this.goals = '[]',
    this.memoryEnabled = true,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['userId'] ?? '',
      preferredName: json['preferredName'],
      communicationStyle: json['communicationStyle'] ?? 'casual',
      responseLength: json['responseLength'] ?? 'moderate',
      interests: json['interests'] ?? '[]',
      goals: json['goals'] ?? '[]',
      memoryEnabled: json['memoryEnabled'] ?? true,
    );
  }
}
