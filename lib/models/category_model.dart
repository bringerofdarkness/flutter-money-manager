class CategoryModel {
  final String name;
  final String icon;
  final double? monthlyBudget;
  final String? userId;
  final DateTime? createdAt;

  CategoryModel({
    required this.name,
    required this.icon,
    this.monthlyBudget,
    this.userId,
    this.createdAt,
  });

  CategoryModel copyWith({
    String? name,
    String? icon,
    double? monthlyBudget,
    bool clearMonthlyBudget = false,
    String? userId,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      monthlyBudget:
      clearMonthlyBudget ? null : (monthlyBudget ?? this.monthlyBudget),
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'monthlyBudget': monthlyBudget,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt']?.toString();

    return CategoryModel(
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      monthlyBudget: map['monthlyBudget'] == null
          ? null
          : (map['monthlyBudget'] as num).toDouble(),
      userId: map['userId']?.toString(),
      createdAt: rawCreatedAt == null || rawCreatedAt.trim().isEmpty
          ? null
          : DateTime.tryParse(rawCreatedAt),
    );
  }
}