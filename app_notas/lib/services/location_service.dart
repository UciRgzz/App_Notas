import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<String> getLocationName() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Ubicación desconocida';
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

    final place = placemarks.first;

    return place.name ??
        place.locality ??
        place.administrativeArea ??
        'Ubicación desconocida';
  }
}
