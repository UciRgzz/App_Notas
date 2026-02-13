import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<String> getLocationName() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return 'Ubicación desconocida';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Ubicación desconocida';
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      final place = placemarks.first;

      // Debug: ver todos los campos del placemark
      print('=== PLACEMARK DEBUG ===');
      print('name: ${place.name}');
      print('street: ${place.street}');
      print('locality: ${place.locality}');
      print('subLocality: ${place.subLocality}');
      print('administrativeArea: ${place.administrativeArea}');
      print('subAdministrativeArea: ${place.subAdministrativeArea}');
      print('country: ${place.country}');
      print('=======================');

      return place.locality ??
          place.subLocality ??
          place.street ??
          place.administrativeArea ??
          'Ubicación desconocida';
    } catch (_) {
      return 'Ubicación desconocida';
    }
  }
}
