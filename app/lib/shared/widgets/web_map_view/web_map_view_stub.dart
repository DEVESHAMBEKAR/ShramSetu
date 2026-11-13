import 'package:flutter/material.dart';
import 'web_map_platform.dart';

Widget buildInteractiveWebMapView({
  required double initialLat,
  required double initialLng,
  required OnLocationSelectedCallback onLocationSelected,
  Key? key,
}) {
  return const SizedBox.shrink();
}

void moveWebMapCamera(double lat, double lng, {int zoom = 16}) {}

