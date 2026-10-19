class UserFoodLocationModel {
  final int id;
  final String? userEmail;
  final String? locationName;
  final double? lat;
  final double? lng;
  final String? floor;
  final String? apartment;
  final String? landmark;
  final String? notes;
  final String? userPhone;
  final String? userName;

  UserFoodLocationModel({
    required this.id,
    this.userEmail,
    this.locationName,
    this.lat,
    this.lng,
    this.floor,
    this.apartment,
    this.landmark,
    this.notes,
    this.userPhone,
    this.userName,
  });

  factory UserFoodLocationModel.fromJson(Map<String, dynamic> json) {
    return UserFoodLocationModel(
      id: json['id'] as int,
      userEmail: json['user_email'] as String?,
      locationName: json['location_name'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      floor: json['floor'] as String?,
      apartment: json['apartement'] as String?,
      landmark: json['landmark'] as String?,
      notes: json['notes'] as String?,
      userPhone: json['user_phone'] as String?,
      userName: json['user_name'] as String?,
    );
  }
}
