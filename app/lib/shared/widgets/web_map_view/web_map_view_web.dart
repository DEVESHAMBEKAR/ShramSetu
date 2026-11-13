// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'web_map_platform.dart';

bool _isFactoryRegistered = false;
double _activeLat = 18.5204;
double _activeLng = 73.8567;
html.IFrameElement? _activeIframe;
const String _leafletViewType = 'shramsetu-leaflet-map-view';

void _ensureFactoryRegistered() {
  if (_isFactoryRegistered) return;
  _isFactoryRegistered = true;

  ui_web.platformViewRegistry.registerViewFactory(
    _leafletViewType,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..id = 'shramsetu_map_iframe'
        ..src = 'leaflet_map_picker.html?lat=$_activeLat&lng=$_activeLng'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('allow', 'geolocation');

      _activeIframe = iframe;
      return iframe;
    },
  );
}

Widget buildInteractiveWebMapView({
  required double initialLat,
  required double initialLng,
  required OnLocationSelectedCallback onLocationSelected,
  Key? key,
}) {
  return _WebMapWidget(
    key: key,
    initialLat: initialLat,
    initialLng: initialLng,
    onLocationSelected: onLocationSelected,
  );
}

void moveWebMapCamera(double lat, double lng, {int zoom = 16}) {
  try {
    final payload = jsonEncode({
      'source': 'SHRAMSETU_HOST',
      'action': 'set_location',
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
    });
    _activeIframe?.contentWindow?.postMessage(payload, '*');
  } catch (e) {
    debugPrint('[WebMap] Error sending camera command: $e');
  }
}

class _WebMapWidget extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final OnLocationSelectedCallback onLocationSelected;

  const _WebMapWidget({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.onLocationSelected,
  });

  @override
  State<_WebMapWidget> createState() => _WebMapWidgetState();
}

class _WebMapWidgetState extends State<_WebMapWidget> {
  StreamSubscription<html.MessageEvent>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _activeLat = widget.initialLat;
    _activeLng = widget.initialLng;
    _ensureFactoryRegistered();

    // If iframe was already mounted, update its coordinates
    if (_activeIframe != null) {
      moveWebMapCamera(widget.initialLat, widget.initialLng, zoom: 15);
    }

    // Listen to coordinates posted from Leaflet Map in iframe
    _messageSubscription = html.window.onMessage.listen((event) {
      try {
        final rawData = event.data;
        Map<String, dynamic>? data;

        if (rawData is String) {
          try {
            final decoded = jsonDecode(rawData);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else if (decoded is Map) {
              data = decoded.cast<String, dynamic>();
            }
          } catch (_) {}
        } else if (rawData is Map) {
          data = rawData.cast<String, dynamic>();
        }

        if (data != null && data['source'] == 'SHRAMSETU_MAP') {
          final eventName = data['event'] as String?;
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();

          if (eventName == 'map_ready' && mounted) {
            moveWebMapCamera(widget.initialLat, widget.initialLng, zoom: 15);
          }

          if (lat != null && lng != null && mounted) {
            widget.onLocationSelected(lat, lng);
          }
        }
      } catch (e) {
        debugPrint('[WebMap] Message processing error: $e');
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(
      viewType: _leafletViewType,
    );
  }
}
