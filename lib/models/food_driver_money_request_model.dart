import 'package:intl/intl.dart';

/// Matches Supabase table `food_driver_request_money` (food driver "Request money").
class FoodDriverMoneyRequestModel {
  final String id;
  final String driverId;
  final double value;
  final bool sent;
  final DateTime? date;

  FoodDriverMoneyRequestModel({
    required this.id,
    required this.driverId,
    required this.value,
    required this.sent,
    this.date,
  });

  factory FoodDriverMoneyRequestModel.fromJson(Map<String, dynamic> json) {
    return FoodDriverMoneyRequestModel(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      value: num.tryParse(json['value']?.toString() ?? '')?.toDouble() ?? 0,
      sent: json['sent'] == true,
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
    );
  }

  FoodDriverMoneyRequestModel copyWith({bool? sent}) {
    return FoodDriverMoneyRequestModel(
      id: id,
      driverId: driverId,
      value: value,
      sent: sent ?? this.sent,
      date: date,
    );
  }

  String get formattedValue => '\$${value.toStringAsFixed(2)}';

  String get formattedDate => date == null
      ? '—'
      : DateFormat('MMM dd, yyyy HH:mm').format(date!.toLocal());
}
