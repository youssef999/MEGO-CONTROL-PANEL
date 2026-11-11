/// Restaurant created by an admin from the dashboard.
///
/// Same columns as restaurant sign-up in the partner app, but it is live right
/// away (`is_accepted` + `active`). `rate` is never sent: ratings only come
/// from customer reviews. `device_token` is filled when the restaurant logs in.
class NewRestaurantModel {
  final String name;
  final String image;
  final String category;
  final String? details;
  final String email;
  final String password;
  final String phone;
  final double lat;
  final double lng;
  final String locationName;
  final String locationDetails;

  /// Minutes from midnight.
  final int openAtMinutes;
  final int closeAtMinutes;

  const NewRestaurantModel({
    required this.name,
    required this.image,
    required this.category,
    this.details,
    required this.email,
    required this.password,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.locationName,
    required this.locationDetails,
    required this.openAtMinutes,
    required this.closeAtMinutes,
  });

  /// `open_at` / `close_at` are stored as hours (e.g. 9.5 = 09:30).
  static double minutesToHours(int minutes) =>
      ((minutes ~/ 60) % 24) + (minutes % 60) / 60.0;

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'image': image,
        'category': category,
        if (details != null && details!.isNotEmpty) 'details': details,
        'email': email,
        'password': password,
        'phone': phone,
        'lat': lat,
        'lng': lng,
        'location_name': locationName,
        'location_details': locationDetails,
        'open_at': minutesToHours(openAtMinutes),
        'close_at': minutesToHours(closeAtMinutes),
        'is_accepted': true,
        'active': true,
      };
}
