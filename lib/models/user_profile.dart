enum Gender { male, female }
enum ActivityLevel { sedentary, light, moderate, active, veryActive }
enum Goal { lose, maintain, gain }

class UserProfile {
  final String id;
  final String name;
  final int age;
  final Gender gender;
  final double heightCm;
  final double weightKg;
  final double targetWeightKg;
  final ActivityLevel activityLevel;
  final Goal goal;
  final bool isPro;
  final int dailyScanCount;
  final DateTime? lastScanDate;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.targetWeightKg,
    required this.activityLevel,
    required this.goal,
    this.isPro = false,
    this.dailyScanCount = 0,
    this.lastScanDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Mifflin-St Jeor BMR
  double get bmr {
    if (gender == Gender.male) {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    }
    return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }

  double get _activityMultiplier => switch (activityLevel) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };

  double get tdee => bmr * _activityMultiplier;

  double get dailyCalorieTarget => switch (goal) {
    Goal.lose => tdee - 500,
    Goal.maintain => tdee,
    Goal.gain => tdee + 300,
  };

  /// Macro targets in grams
  double get proteinTarget => weightKg * 2.0;
  double get fatTarget => (dailyCalorieTarget * 0.25) / 9;
  double get carbTarget =>
      (dailyCalorieTarget - (proteinTarget * 4) - (fatTarget * 9)) / 4;

  int get maxFreeDailyScans => 3;
  bool get canScan => isPro || dailyScanCount < maxFreeDailyScans;

  UserProfile copyWith({
    String? name,
    int? age,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    ActivityLevel? activityLevel,
    Goal? goal,
    bool? isPro,
    int? dailyScanCount,
    DateTime? lastScanDate,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      isPro: isPro ?? this.isPro,
      dailyScanCount: dailyScanCount ?? this.dailyScanCount,
      lastScanDate: lastScanDate ?? this.lastScanDate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender.index,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'targetWeightKg': targetWeightKg,
    'activityLevel': activityLevel.index,
    'goal': goal.index,
    'isPro': isPro,
    'dailyScanCount': dailyScanCount,
    'lastScanDate': lastScanDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['id'],
    name: m['name'],
    age: m['age'],
    gender: Gender.values[m['gender']],
    heightCm: (m['heightCm'] as num).toDouble(),
    weightKg: (m['weightKg'] as num).toDouble(),
    targetWeightKg: (m['targetWeightKg'] as num).toDouble(),
    activityLevel: ActivityLevel.values[m['activityLevel']],
    goal: Goal.values[m['goal']],
    isPro: m['isPro'] == true || m['isPro'] == 1,
    dailyScanCount: m['dailyScanCount'] ?? 0,
    lastScanDate: m['lastScanDate'] != null ? DateTime.parse(m['lastScanDate']) : null,
    createdAt: DateTime.parse(m['createdAt']),
  );
}
