import 'dart:math' as math;

/// A town with its district, province and rough centre.
class Place {
  const Place(this.name, this.province, this.district, this.lat, this.lon);
  final String name;
  final String province;
  final String district;
  final double lat;
  final double lon;
}

/// Generated from frontend/src/lib/places.js (same 63 towns, same coordinates), so a
/// captured position names the same town on the phone as on the website.
const places = <Place>[
  Place('Colombo', 'Western Province', 'Colombo', 6.9271, 79.8612),
  Place('Dehiwala', 'Western Province', 'Colombo', 6.8512, 79.8653),
  Place('Mount Lavinia', 'Western Province', 'Colombo', 6.8389, 79.8653),
  Place('Moratuwa', 'Western Province', 'Colombo', 6.7730, 79.8816),
  Place('Panadura', 'Western Province', 'Kalutara', 6.7133, 79.9026),
  Place('Wadduwa', 'Western Province', 'Kalutara', 6.6600, 79.9300),
  Place('Kalutara', 'Western Province', 'Kalutara', 6.5854, 79.9607),
  Place('Beruwala', 'Western Province', 'Kalutara', 6.4788, 79.9828),
  Place('Bentota', 'Western Province', 'Kalutara', 6.4258, 79.9959),
  Place('Negombo', 'Western Province', 'Gampaha', 7.2083, 79.8358),
  Place('Gampaha', 'Western Province', 'Gampaha', 7.0917, 80.0000),
  Place('Wattala', 'Western Province', 'Gampaha', 6.9897, 79.8914),
  Place('Ja-Ela', 'Western Province', 'Gampaha', 7.0744, 79.8919),
  Place('Kelaniya', 'Western Province', 'Gampaha', 6.9553, 79.9220),
  Place(
    'Sri Jayawardenepura Kotte',
    'Western Province',
    'Colombo',
    6.8885,
    79.9179,
  ),
  Place('Galle', 'Southern Province', 'Galle', 6.0535, 80.2210),
  Place('Unawatuna', 'Southern Province', 'Galle', 6.0100, 80.2490),
  Place('Hikkaduwa', 'Southern Province', 'Galle', 6.1395, 80.1063),
  Place('Ambalangoda', 'Southern Province', 'Galle', 6.2354, 80.0539),
  Place('Weligama', 'Southern Province', 'Matara', 5.9749, 80.4294),
  Place('Mirissa', 'Southern Province', 'Matara', 5.9483, 80.4589),
  Place('Matara', 'Southern Province', 'Matara', 5.9549, 80.5550),
  Place('Dikwella', 'Southern Province', 'Matara', 5.9667, 80.6914),
  Place('Tangalle', 'Southern Province', 'Hambantota', 6.0240, 80.7940),
  Place('Hambantota', 'Southern Province', 'Hambantota', 6.1241, 81.1185),
  Place('Tissamaharama', 'Southern Province', 'Hambantota', 6.2789, 81.2872),
  Place('Trincomalee', 'Eastern Province', 'Trincomalee', 8.5874, 81.2152),
  Place('Nilaveli', 'Eastern Province', 'Trincomalee', 8.7000, 81.1900),
  Place('Kinniya', 'Eastern Province', 'Trincomalee', 8.4894, 81.1811),
  Place('Batticaloa', 'Eastern Province', 'Batticaloa', 7.7102, 81.6924),
  Place('Kalmunai', 'Eastern Province', 'Ampara', 7.4091, 81.8344),
  Place('Ampara', 'Eastern Province', 'Ampara', 7.2970, 81.6747),
  Place('Arugam Bay', 'Eastern Province', 'Ampara', 6.8400, 81.8360),
  Place('Pottuvil', 'Eastern Province', 'Ampara', 6.8757, 81.8300),
  Place('Jaffna', 'Northern Province', 'Jaffna', 9.6615, 80.0255),
  Place('Point Pedro', 'Northern Province', 'Jaffna', 9.8167, 80.2333),
  Place('Chavakachcheri', 'Northern Province', 'Jaffna', 9.6594, 80.1636),
  Place('Kilinochchi', 'Northern Province', 'Kilinochchi', 9.3961, 80.4036),
  Place('Mannar', 'Northern Province', 'Mannar', 8.9810, 79.9044),
  Place('Vavuniya', 'Northern Province', 'Vavuniya', 8.7514, 80.4971),
  Place('Mullaitivu', 'Northern Province', 'Mullaitivu', 9.2671, 80.8142),
  Place('Puttalam', 'North Western Province', 'Puttalam', 8.0362, 79.8283),
  Place('Kalpitiya', 'North Western Province', 'Puttalam', 8.2300, 79.7600),
  Place('Chilaw', 'North Western Province', 'Puttalam', 7.5758, 79.7953),
  Place('Marawila', 'North Western Province', 'Puttalam', 7.4200, 79.8200),
  Place('Kurunegala', 'North Western Province', 'Kurunegala', 7.4863, 80.3647),
  Place(
    'Kuliyapitiya',
    'North Western Province',
    'Kurunegala',
    7.4689,
    80.0406,
  ),
  Place('Kandy', 'Central Province', 'Kandy', 7.2906, 80.6337),
  Place('Matale', 'Central Province', 'Matale', 7.4675, 80.6234),
  Place('Nuwara Eliya', 'Central Province', 'Nuwara Eliya', 6.9497, 80.7891),
  Place('Gampola', 'Central Province', 'Kandy', 7.1642, 80.5767),
  Place('Dambulla', 'Central Province', 'Matale', 7.8731, 80.6511),
  Place(
    'Anuradhapura',
    'North Central Province',
    'Anuradhapura',
    8.3114,
    80.4037,
  ),
  Place(
    'Polonnaruwa',
    'North Central Province',
    'Polonnaruwa',
    7.9403,
    81.0188,
  ),
  Place('Kekirawa', 'North Central Province', 'Anuradhapura', 8.0375, 80.5922),
  Place('Badulla', 'Uva Province', 'Badulla', 6.9934, 81.0550),
  Place('Bandarawela', 'Uva Province', 'Badulla', 6.8322, 80.9869),
  Place('Monaragala', 'Uva Province', 'Monaragala', 6.8714, 81.3487),
  Place('Ella', 'Uva Province', 'Badulla', 6.8667, 81.0466),
  Place('Ratnapura', 'Sabaragamuwa Province', 'Ratnapura', 6.6828, 80.3992),
  Place('Kegalle', 'Sabaragamuwa Province', 'Kegalle', 7.2513, 80.3464),
  Place('Balangoda', 'Sabaragamuwa Province', 'Ratnapura', 6.6500, 80.7000),
  Place('Embilipitiya', 'Sabaragamuwa Province', 'Ratnapura', 6.3433, 80.8492),
];

/// The nearest listed town to [latitude], [longitude] and how far it is, by great-circle
/// distance (as nearestPlace() in places.js).
(Place, double)? nearestPlace(double latitude, double longitude) {
  double rad(double deg) => deg * math.pi / 180;
  Place? best;
  var bestKm = double.infinity;
  for (final p in places) {
    final dLat = rad(p.lat - latitude);
    final dLon = rad(p.lon - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(p.lat)) *
            math.pow(math.sin(dLon / 2), 2);
    final km = 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    if (km < bestKm) {
      bestKm = km;
      best = p;
    }
  }
  return best == null ? null : (best, bestKm);
}
