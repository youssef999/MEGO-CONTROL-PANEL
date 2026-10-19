import 'package:intl/intl.dart';

/// Matches Supabase table `partner_payout_methods` (filled from the partner app profile).
/// `partner_type`: 'restaurant' (partner_id = restaurants.id) or 'driver' (partner_id = drivers.id).
class PartnerPayoutMethodModel {
  static const String typeRestaurant = 'restaurant';
  static const String typeDriver = 'driver';

  final int id;
  final String partnerType;
  final String partnerId;
  final String title;
  final String description;
  final DateTime? updatedAt;

  PartnerPayoutMethodModel({
    required this.id,
    required this.partnerType,
    required this.partnerId,
    required this.title,
    required this.description,
    this.updatedAt,
  });

  factory PartnerPayoutMethodModel.fromJson(Map<String, dynamic> json) {
    return PartnerPayoutMethodModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      partnerType: json['partner_type']?.toString() ?? '',
      partnerId: json['partner_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  String get formattedUpdatedAt => updatedAt == null
      ? '—'
      : DateFormat('MMM dd, yyyy HH:mm').format(updatedAt!.toLocal());
}
