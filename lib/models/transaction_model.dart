class TransactionModel {
  final String id;
  final String? userId;
  final String type;
  final double amount;
  final String categoryOrSource;
  final String note;
  final DateTime date;
  final String? frequency;
  final String? receiptImagePath;
  final String? receiptUrl;
  final DateTime? createdAt;

  TransactionModel({
    String? id,
    this.userId,
    required this.type,
    required this.amount,
    required this.categoryOrSource,
    required this.note,
    required this.date,
    this.frequency,
    this.receiptImagePath,
    this.receiptUrl,
    this.createdAt,
  }) : id = (id == null || id.trim().isEmpty)
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : id;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'categoryOrSource': categoryOrSource,
      'note': note,
      'date': date.toIso8601String(),
      'frequency': frequency,
      'receiptImagePath': receiptImagePath,
      'receiptUrl': receiptUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final rawId = map['id']?.toString();
    final rawUserId = map['userId']?.toString();
    final rawType = map['type']?.toString() ?? '';
    final rawAmount = map['amount'];
    final rawCategoryOrSource = map['categoryOrSource']?.toString() ?? '';
    final rawNote = map['note']?.toString() ?? '';
    final rawDate = map['date']?.toString();
    final rawFrequency = map['frequency']?.toString();
    final rawReceiptImagePath = map['receiptImagePath']?.toString();
    final rawReceiptUrl = map['receiptUrl']?.toString();
    final rawCreatedAt = map['createdAt']?.toString();

    return TransactionModel(
      id: rawId,
      userId: rawUserId == null || rawUserId.trim().isEmpty ? null : rawUserId,
      type: rawType,
      amount: rawAmount is num ? rawAmount.toDouble() : 0.0,
      categoryOrSource: rawCategoryOrSource,
      note: rawNote,
      date: rawDate != null && rawDate.isNotEmpty
          ? DateTime.tryParse(rawDate) ?? DateTime.now()
          : DateTime.now(),
      frequency: rawFrequency == null || rawFrequency.trim().isEmpty
          ? null
          : rawFrequency,
      receiptImagePath:
      rawReceiptImagePath == null || rawReceiptImagePath.trim().isEmpty
          ? null
          : rawReceiptImagePath,
      receiptUrl: rawReceiptUrl == null || rawReceiptUrl.trim().isEmpty
          ? null
          : rawReceiptUrl,
      createdAt: rawCreatedAt == null || rawCreatedAt.trim().isEmpty
          ? null
          : DateTime.tryParse(rawCreatedAt),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? type,
    double? amount,
    String? categoryOrSource,
    String? note,
    DateTime? date,
    String? frequency,
    String? receiptImagePath,
    String? receiptUrl,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryOrSource: categoryOrSource ?? this.categoryOrSource,
      note: note ?? this.note,
      date: date ?? this.date,
      frequency: frequency ?? this.frequency,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isIncome => type.toLowerCase() == 'income';

  bool get isExpense => type.toLowerCase() == 'expense';

  bool get isLoanGiven => type.toLowerCase() == 'loan given';

  bool get isLoanTaken => type.toLowerCase() == 'loan taken';

  bool get isLoanReceivedBack => type.toLowerCase() == 'loan received back';

  bool get isLoanPaidBack => type.toLowerCase() == 'loan paid back';

  bool get isLoanRelated =>
      isLoanGiven || isLoanTaken || isLoanReceivedBack || isLoanPaidBack;

  bool get hasReceiptImage =>
      receiptUrl != null && receiptUrl!.trim().isNotEmpty;
}