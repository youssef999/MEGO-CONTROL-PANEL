/// Parses restaurant coordinates typed or pasted by an admin.
///
/// Accepts `29.7604, -95.3698` (Google Maps right-click → copy) or a Google
/// Maps link containing `@lat,lng`, `q=lat,lng` or `!3dlat!4dlng`.
({double lat, double lng})? parseCoordinates(String input) {
  final text = Uri.decodeFull(input.trim());
  if (text.isEmpty) return null;
  const c = r'(-?\d{1,3}(?:\.\d+)?)';
  final patterns = [
    RegExp('!3d$c!4d$c'),
    RegExp('@$c,\\s*$c'),
    RegExp('[?&](?:q|query|ll|destination)=$c,\\s*$c'),
    RegExp('^$c\\s*,\\s*$c\$'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(text);
    if (m == null) continue;
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null) continue;
    if (lat.abs() > 90 || lng.abs() > 180) continue;
    return (lat: lat, lng: lng);
  }
  return null;
}

/// Restaurants are limited to Egypt + USA (same bounds as the partner app).
bool isAllowedRestaurantLocation(double lat, double lng) {
  final inEgypt = lat >= 21.5 && lat <= 31.8 && lng >= 24.5 && lng <= 37.2;
  final inUsa = lat >= 24.4 && lat <= 49.5 && lng >= -125.0 && lng <= -66.0;
  final inAlaska = lat >= 51.0 && lat <= 72.0 && lng >= -180.0 && lng <= -129.0;
  final inHawaii = lat >= 18.5 && lat <= 22.5 && lng >= -161.0 && lng <= -154.0;
  return inEgypt || inUsa || inAlaska || inHawaii;
}
