class RideRequestModel {
  final String id;
  final String? pickupPlace;
  final String? dropoffPlace;

  RideRequestModel({
    required this.id,
    this.pickupPlace,
    this.dropoffPlace,
  });

  factory RideRequestModel.fromJson(Map<String, dynamic> json) {
    return RideRequestModel(
      id: json['id'] as String,
      pickupPlace: json['pickup_place'] as String?,
      dropoffPlace: json['dropoff_place'] as String?,
    );
  }
}
