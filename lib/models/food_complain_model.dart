import 'package:intl/intl.dart';

class FoodComplainModel {
  final int id;
  final bool isSolve;
  final String? type;
  final String? message;
  final int? orderId;
  final DateTime createdAt;
  final String? userId;

  const FoodComplainModel({
    required this.id,
    this.isSolve = false,
    this.type,
    this.message,
    this.orderId,
    required this.createdAt,
    this.userId,
  });

  factory FoodComplainModel.fromJson(Map<String, dynamic> json) {
    return FoodComplainModel(
      id: (json['id'] as num).toInt(),
      isSolve: json['is_solve'] as bool? ?? false,
      type: json['type'] as String?,
      message: json['message'] as String?,
      orderId: (json['order_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id']?.toString(),
    );
  }

  FoodComplainModel copyWith({
    int? id,
    bool? isSolve,
    String? type,
    String? message,
    int? orderId,
    DateTime? createdAt,
    String? userId,
  }) {
    return FoodComplainModel(
      id: id ?? this.id,
      isSolve: isSolve ?? this.isSolve,
      type: type ?? this.type,
      message: message ?? this.message,
      orderId: orderId ?? this.orderId,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  bool get isOrderType =>
      (type ?? '').trim().toLowerCase() == 'order';

  String get formattedCreatedAt =>
      DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toLocal());
}
