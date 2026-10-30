import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// A location problem with a message fit to show the user.
class LocationFailure implements Exception {
  LocationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Gets the device's position, asking for permission when needed (the website's
/// "Use my current location"). Unlike the website, a failure never falls back to a made-up
/// position: the user is told why and can type the coordinates instead.
class DeviceLocation {
  DeviceLocation._();

  /// Replaced in tests.
  static Future<(double, double)> Function() locate = _locate;

  static Future<(double, double)> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw LocationFailure(
          'Location is turned off on this device. Turn it on, or type the coordinates.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw LocationFailure(
          'Tideline was not allowed to use your location. Type the coordinates instead.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationFailure(
          "Location access is blocked for Tideline. Allow it in your phone's settings, or type the coordinates.",
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (position.latitude, position.longitude);
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw LocationFailure(
        'Could not find your position in time. Try again outdoors, or type the coordinates.',
      );
    } catch (_) {
      throw LocationFailure(
        'This device could not share its location. Type the coordinates instead.',
      );
    }
  }
}
