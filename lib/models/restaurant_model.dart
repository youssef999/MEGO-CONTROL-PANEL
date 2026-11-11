class RestaurantModel {
  final int id;
  final String? name;
  final String? image;
  final String? category;
  final String? details;
  /// Average of `restaurant_reviews` (filled by SupabaseService, same as the
  /// client app) — read-only, never part of [toJson].
  final double? rate;

  /// Number of `restaurant_reviews` rows behind [rate].
  final int rateCount;
  final String? fcmToken;
  final String? deviceToken;
  final String? email;
  final String? password;
  final bool isAccepted;

  /// `menu_category_order`: menu sections order shown to customers.
  /// Saved separately (not part of [toJson]) so profile edits keep it.
  final List<String> menuCategoryOrder;

  // Read-only profile details (shown in the dashboard, never in [toJson]).
  final String? phone;
  final String? locationName;
  final String? locationDetails;
  final double? lat;
  final double? lng;

  /// Hours as stored (`9.5` = 09:30).
  final double? openAt;
  final double? closeAt;

  /// `active` = taking orders now (false = busy).
  final bool active;

  RestaurantModel({
    required this.id,
    this.name,
    this.image,
    this.category,
    this.details,
    this.rate,
    this.rateCount = 0,
    this.fcmToken,
    this.deviceToken,
    this.email,
    this.password,
    this.isAccepted = false,
    this.menuCategoryOrder = const [],
    this.phone,
    this.locationName,
    this.locationDetails,
    this.lat,
    this.lng,
    this.openAt,
    this.closeAt,
    this.active = false,
  });

  static double? _d(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['menu_category_order'];
    return RestaurantModel(
      id: json['id'] as int,
      name: json['name'] as String?,
      image: json['image'] as String?,
      category: json['category'] as String?,
      details: json['details'] as String?,
      rate: (json['rate'] as num?)?.toDouble(),
      fcmToken: json['fcm_token'] as String?,
      deviceToken: json['device_token'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      isAccepted: json['is_accepted'] as bool? ?? false,
      menuCategoryOrder: rawOrder is List
          ? rawOrder.map((e) => e.toString()).toList()
          : const [],
      phone: json['phone']?.toString(),
      locationName: json['location_name']?.toString(),
      locationDetails: json['location_details']?.toString(),
      lat: _d(json['lat']),
      lng: _d(json['lng']),
      openAt: _d(json['open_at']),
      closeAt: _d(json['close_at']),
      active: json['active'] as bool? ?? false,
    );
  }

  /// `09:30 – 22:00`, or null when hours are not set.
  String? get hoursLabel {
    if (openAt == null || closeAt == null) return null;
    String f(double h) {
      final total = (h * 60).round();
      final hh = (total ~/ 60) % 24;
      final mm = total % 60;
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }

    return '${f(openAt!)} – ${f(closeAt!)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'category': category,
      'details': details,
      'device_token': deviceToken,
      'email': email,
      'password': password,
      'is_accepted': isAccepted,
    };
  }

  RestaurantModel copyWith({
    int? id,
    String? name,
    String? image,
    String? category,
    String? details,
    double? rate,
    int? rateCount,
    String? fcmToken,
    String? deviceToken,
    String? email,
    String? password,
    bool? isAccepted,
    List<String>? menuCategoryOrder,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      category: category ?? this.category,
      details: details ?? this.details,
      rate: rate ?? this.rate,
      rateCount: rateCount ?? this.rateCount,
      fcmToken: fcmToken ?? this.fcmToken,
      deviceToken: deviceToken ?? this.deviceToken,
      email: email ?? this.email,
      password: password ?? this.password,
      isAccepted: isAccepted ?? this.isAccepted,
      menuCategoryOrder: menuCategoryOrder ?? this.menuCategoryOrder,
      phone: phone,
      locationName: locationName,
      locationDetails: locationDetails,
      lat: lat,
      lng: lng,
      openAt: openAt,
      closeAt: closeAt,
      active: active,
    );
  }

  /// Same text as the client app restaurant card: `4.3 (12)` / `0.0`.
  String get rateLabel {
    final avg = (rate ?? 0).toStringAsFixed(1);
    return rateCount > 0 ? '$avg ($rateCount)' : avg;
  }
}
