import 'package:flutter/material.dart';
import 'web_map_view_stub.dart'
    if (dart.library.html) 'web_map_view_web.dart' as platform;

typedef OnLocationSelectedCallback = void Function(double lat, double lng);

/// Builds the interactive live map view across platforms (OpenStreetMap/Leaflet on Web, Stub on Native)
Widget buildInteractiveWebMapView({
  required double initialLat,
  required double initialLng,
  required OnLocationSelectedCallback onLocationSelected,
  Key? key,
}) {
  return platform.buildInteractiveWebMapView(
    initialLat: initialLat,
    initialLng: initialLng,
    onLocationSelected: onLocationSelected,
    key: key,
  );
}

/// Commands the active web map to center and place pin at target coordinates
void moveWebMapCamera(double lat, double lng, {int zoom = 16}) {
  platform.moveWebMapCamera(lat, lng, zoom: zoom);
}

