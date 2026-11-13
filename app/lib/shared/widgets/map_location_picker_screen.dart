import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/config/dependency_injection.dart';
import '../../core/services/india_geography_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'web_map_view/web_map_platform.dart';

/// Result returned from MapLocationPickerScreen
class LocationPickerResult {
  final double latitude;
  final double longitude;
  final GeoAddress? address;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

/// Standard Web Mercator (EPSG:3857) projection calculations for Slippy Maps
class MapProjection {
  static const double tileSize = 256.0;

  static double lngToTileX(double lng, int zoom) {
    return ((lng + 180.0) / 360.0) * (1 << zoom);
  }

  static double latToTileY(double lat, int zoom) {
    final latRad = lat * pi / 180.0;
    return (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * (1 << zoom);
  }

  static double tileXToLng(double x, int zoom) {
    return x / (1 << zoom) * 360.0 - 180.0;
  }

  static double tileYToLat(double y, int zoom) {
    final n = pi - 2.0 * pi * y / (1 << zoom);
    return 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
  }
}

class _AreaPreset {
  final String label;
  final String city;
  final String addressLine;
  final String area;
  final String postalCode;
  final double latitude;
  final double longitude;

  const _AreaPreset({
    required this.label,
    required this.city,
    required this.addressLine,
    required this.area,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
  });
}

const List<_AreaPreset> _popularPresets = [
  _AreaPreset(
    label: 'Kothrud',
    city: 'Pune',
    addressLine: '12 Mayur Colony, Paud Road',
    area: 'Kothrud',
    postalCode: '411038',
    latitude: 18.5074,
    longitude: 73.8077,
  ),
  _AreaPreset(
    label: 'Shivajinagar',
    city: 'Pune',
    addressLine: 'FC Road, Near Deccan Gymkhana',
    area: 'Shivajinagar',
    postalCode: '411005',
    latitude: 18.5314,
    longitude: 73.8446,
  ),
  _AreaPreset(
    label: 'Hinjewadi',
    city: 'Pune',
    addressLine: 'Phase 1, Rajiv Gandhi Infotech Park',
    area: 'Hinjewadi',
    postalCode: '411057',
    latitude: 18.5913,
    longitude: 73.7389,
  ),
  _AreaPreset(
    label: 'Baner',
    city: 'Pune',
    addressLine: 'Survey 44, Pan Card Club Road',
    area: 'Baner',
    postalCode: '411045',
    latitude: 18.5590,
    longitude: 73.7868,
  ),
  _AreaPreset(
    label: 'Hadapsar',
    city: 'Pune',
    addressLine: 'Magarpatta City Main Road',
    area: 'Hadapsar',
    postalCode: '411028',
    latitude: 18.5089,
    longitude: 73.9259,
  ),
  _AreaPreset(
    label: 'Bhavani Nagar',
    city: 'Ahmednagar',
    addressLine: 'Bhavani Nagar, Station Road',
    area: 'Bhavani Nagar',
    postalCode: '414001',
    latitude: 19.0948,
    longitude: 74.7480,
  ),
  _AreaPreset(
    label: 'Dharampeth',
    city: 'Nagpur',
    addressLine: 'West High Court Road, Dharampeth',
    area: 'Dharampeth',
    postalCode: '440010',
    latitude: 21.1458,
    longitude: 79.0608,
  ),
  _AreaPreset(
    label: 'Sitabuldi',
    city: 'Nagpur',
    addressLine: 'Variety Square, Sitabuldi',
    area: 'Sitabuldi',
    postalCode: '440012',
    latitude: 21.1444,
    longitude: 79.0833,
  ),
  _AreaPreset(
    label: 'Panchavati',
    city: 'Nashik',
    addressLine: 'Ramkund Road, Panchavati',
    area: 'Panchavati',
    postalCode: '422003',
    latitude: 20.0063,
    longitude: 73.7925,
  ),
  _AreaPreset(
    label: 'Andheri West',
    city: 'Mumbai',
    addressLine: 'SV Road, Near Station, Andheri West',
    area: 'Andheri West',
    postalCode: '400058',
    latitude: 19.1197,
    longitude: 72.8464,
  ),
  _AreaPreset(
    label: 'Thane West',
    city: 'Thane',
    addressLine: 'Gokhale Road, Naupada, Thane West',
    area: 'Thane West',
    postalCode: '400602',
    latitude: 19.1860,
    longitude: 72.9757,
  ),
];

/// Interactive location picker screen with pure Flutter Live Tile Map.
/// Fully compatible with localhost, Chrome Web, and all platforms without iframe or WebGL dependencies.
class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? title;

  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.title,
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  static const double _defaultLat = 18.5204303;
  static const double _defaultLng = 73.8567437;

  late double _currentLat;
  late double _currentLng;
  int _currentZoom = 15; // 3..19

  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingGps = false;
  bool _isResolvingAddress = false;
  bool _isSearching = false;
  GeoAddress? _resolvedAddress;
  String? _selectedPresetLabel;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLatitude ?? _defaultLat;
    _currentLng = widget.initialLongitude ?? _defaultLng;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _findMatchingPresetOrResolve(_currentLat, _currentLng);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _findMatchingPresetOrResolve(double lat, double lng) {
    for (final p in _popularPresets) {
      if ((p.latitude - lat).abs() < 0.01 && (p.longitude - lng).abs() < 0.01) {
        _selectedPresetLabel = p.label;
        _resolvedAddress = GeoAddress(
          addressLine: p.addressLine,
          area: p.area,
          city: p.city,
          state: 'Maharashtra',
          postalCode: p.postalCode,
        );
        return;
      }
    }
    _resolveAddress(lat, lng);
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isResolvingAddress = true);
    try {
      final GeoAddress? addr = await DI.locationService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _resolvedAddress = addr ??
              GeoAddress(
                addressLine: 'Near selected location',
                area: _selectedPresetLabel ?? 'Selected Area',
                city: 'Pune',
                state: 'Maharashtra',
                postalCode: '411001',
              );
          _isResolvingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedAddress = GeoAddress(
            addressLine: 'Near selected location',
            area: _selectedPresetLabel ?? 'Selected Area',
            city: 'Pune',
            state: 'Maharashtra',
            postalCode: '411001',
          );
          _isResolvingAddress = false;
        });
      }
    }
  }

  Future<void> _moveToCurrentGps() async {
    setState(() => _isLoadingGps = true);
    final result = await DI.locationService.getCurrentPosition();
    if (!mounted) return;

    setState(() => _isLoadingGps = false);

    if (result.isSuccess && result.coordinates != null) {
      final coords = result.coordinates!;
      setState(() {
        _currentLat = coords.latitude;
        _currentLng = coords.longitude;
        _selectedPresetLabel = null;
        _currentZoom = 16;
      });
      _resolveAddress(coords.latitude, coords.longitude);
      if (kIsWeb) {
        moveWebMapCamera(coords.latitude, coords.longitude, zoom: 16);
      }
    } else {
      final msg = result.errorMessage ?? 'Unable to detect current GPS location. Please check browser permissions.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _selectPreset(_AreaPreset preset) {
    setState(() {
      _currentLat = preset.latitude;
      _currentLng = preset.longitude;
      _selectedPresetLabel = preset.label;
      _currentZoom = 15;
      _resolvedAddress = GeoAddress(
        addressLine: preset.addressLine,
        area: preset.area,
        city: preset.city,
        state: 'Maharashtra',
        postalCode: preset.postalCode,
      );
    });
    if (kIsWeb) {
      moveWebMapCamera(_currentLat, _currentLng, zoom: 16);
    }
  }

  Future<void> _handleSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. Check known preset names first
      for (final p in _popularPresets) {
        if (p.label.toLowerCase().contains(q.toLowerCase()) ||
            p.area.toLowerCase().contains(q.toLowerCase()) ||
            p.city.toLowerCase().contains(q.toLowerCase())) {
          _selectPreset(p);
          setState(() => _isSearching = false);
          return;
        }
      }

      // 2. Check if user typed coordinates (e.g. "18.5204, 73.8567")
      final coordParts = q.split(RegExp(r'[, ]+'));
      if (coordParts.length == 2) {
        final lat = double.tryParse(coordParts[0]);
        final lng = double.tryParse(coordParts[1]);
        if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          setState(() {
            _currentLat = lat;
            _currentLng = lng;
            _selectedPresetLabel = null;
            _currentZoom = 16;
          });
          _resolveAddress(lat, lng);
          if (kIsWeb) {
            moveWebMapCamera(lat, lng, zoom: 16);
          }
          setState(() => _isSearching = false);
          return;
        }
      }

      // 3. Search IndiaGeographyService districts & areas
      final qLower = q.toLowerCase();
      for (final entry in IndiaGeographyService.popularDistrictAreas.entries) {
        final distName = entry.key;
        if (distName.toLowerCase().contains(qLower)) {
          // Found district match
          final matchPreset = _popularPresets.firstWhere(
            (p) => p.city.toLowerCase() == distName.toLowerCase(),
            orElse: () => _AreaPreset(
              label: distName,
              city: distName,
              addressLine: '$distName Central',
              area: distName,
              postalCode: '400001',
              latitude: _currentLat,
              longitude: _currentLng,
            ),
          );
          _selectPreset(matchPreset);
          setState(() => _isSearching = false);
          return;
        }

        for (final area in entry.value) {
          if (area.toLowerCase().contains(qLower)) {
            final matchPreset = _popularPresets.firstWhere(
              (p) => p.label.toLowerCase() == area.toLowerCase() || p.city.toLowerCase() == distName.toLowerCase(),
              orElse: () => _AreaPreset(
                label: area,
                city: distName,
                addressLine: '$area, $distName',
                area: area,
                postalCode: '400001',
                latitude: _currentLat,
                longitude: _currentLng,
              ),
            );
            _selectPreset(matchPreset);
            setState(() => _isSearching = false);
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not find "$q". Try dragging the pin or choosing a Quick Jump chip.'),
            backgroundColor: AppColors.outline,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[MapSearch] Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _confirmSelection() {
    Navigator.of(context).pop(
      LocationPickerResult(
        latitude: _currentLat,
        longitude: _currentLng,
        address: _resolvedAddress ??
            GeoAddress(
              addressLine: 'Selected location',
              area: _selectedPresetLabel ?? 'Selected Locality',
              city: 'Pune',
              state: 'Maharashtra',
              postalCode: '411001',
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title ?? 'Pin Service Location on Live Map',
          style: AppTypography.titleMd.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoadingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.my_location, color: AppColors.primary),
            tooltip: 'Detect Current Location (GPS)',
            onPressed: _isLoadingGps ? null : _moveToCurrentGps,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar & Region Presets Bar
          _buildTopSearchAndPresets(),

          // 2. Interactive Live Map (Pure Flutter Slippy Tile Map with OpenStreetMap / CartoDB)
          Expanded(
            child: _buildPureFlutterMap(),
          ),

          // 3. Bottom Confirmation & Address Sheet
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildTopSearchAndPresets() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search TextField
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _handleSearch,
                    decoration: InputDecoration(
                      hintText: 'Search any city, locality or landmark across India...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.outline),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    elevation: 0,
                  ),
                  onPressed: _isSearching ? null : () => _handleSearch(_searchController.text),
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Find', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Quick Navigation Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Quick Jump: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
                const SizedBox(width: 4),
                ..._popularPresets.map((preset) {
                  final isSelected = _selectedPresetLabel == preset.label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('${preset.label} (${preset.city})'),
                      onPressed: () => _selectPreset(preset),
                      backgroundColor: isSelected ? const Color(0xFF004D40) : const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF004D40),
                      ),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF004D40) : AppColors.outlineVariant,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPureFlutterMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final centerTileX = MapProjection.lngToTileX(_currentLng, _currentZoom);
        final centerTileY = MapProjection.latToTileY(_currentLat, _currentZoom);

        final numTilesX = (width / 256.0).ceil() + 2;
        final numTilesY = (height / 256.0).ceil() + 2;

        final minTileX = (centerTileX - numTilesX / 2).floor();
        final maxTileX = (centerTileX + numTilesX / 2).ceil();
        final minTileY = (centerTileY - numTilesY / 2).floor();
        final maxTileY = (centerTileY + numTilesY / 2).ceil();

        final maxTilesAtZoom = 1 << _currentZoom;

        final List<Widget> tileWidgets = [];

        for (int tx = minTileX; tx <= maxTileX; tx++) {
          for (int ty = minTileY; ty <= maxTileY; ty++) {
            if (ty < 0 || ty >= maxTilesAtZoom) continue;

            final wrappedX = (tx % maxTilesAtZoom + maxTilesAtZoom) % maxTilesAtZoom;
            final pixelX = (tx - centerTileX) * 256.0 + width / 2.0;
            final pixelY = (ty - centerTileY) * 256.0 + height / 2.0;

            final tileUrl = 'https://tile.openstreetmap.org/$_currentZoom/$wrappedX/$ty.png';

            tileWidgets.add(
              Positioned(
                left: pixelX,
                top: pixelY,
                width: 256,
                height: 256,
                child: Image.network(
                  tileUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) {
                    // Fallback to CartoDB tiles if OpenStreetMap is slow
                    return Image.network(
                      'https://a.basemaps.cartocdn.com/rastertiles/voyager/$_currentZoom/$wrappedX/$ty.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: Colors.black12, width: 0.5),
                        ),
                        child: const Center(
                          child: Icon(Icons.map_outlined, color: Colors.black26, size: 24),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }

        return Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              if (pointerSignal.scrollDelta.dy < 0) {
                if (_currentZoom < 19) setState(() => _currentZoom++);
              } else if (pointerSignal.scrollDelta.dy > 0) {
                if (_currentZoom > 3) setState(() => _currentZoom--);
              }
            }
          },
          child: GestureDetector(
            onPanUpdate: (details) {
              final newTileX = centerTileX - details.delta.dx / 256.0;
              final newTileY = centerTileY - details.delta.dy / 256.0;

              final newLng = MapProjection.tileXToLng(newTileX, _currentZoom);
              final newLat = MapProjection.tileYToLat(newTileY, _currentZoom);

              setState(() {
                _currentLat = newLat.clamp(-85.0, 85.0);
                _currentLng = ((newLng + 180.0) % 360.0) - 180.0;
                _selectedPresetLabel = null;
              });
            },
            onPanEnd: (_) {
              _resolveAddress(_currentLat, _currentLng);
            },
            onTapUp: (details) {
              final tapX = details.localPosition.dx;
              final tapY = details.localPosition.dy;

              final targetTileX = centerTileX + (tapX - width / 2.0) / 256.0;
              final targetTileY = centerTileY + (tapY - height / 2.0) / 256.0;

              final tapLng = MapProjection.tileXToLng(targetTileX, _currentZoom);
              final tapLat = MapProjection.tileYToLat(targetTileY, _currentZoom);

              setState(() {
                _currentLat = tapLat.clamp(-85.0, 85.0);
                _currentLng = ((tapLng + 180.0) % 360.0) - 180.0;
                _selectedPresetLabel = null;
              });
              _resolveAddress(_currentLat, _currentLng);
            },
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Container(color: const Color(0xFFE2E8F0)),
                // Live Map Tiles
                ...tileWidgets,

                // Top Guidance Banner
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 15, color: Color(0xFF004D40)),
                          SizedBox(width: 6),
                          Text(
                            'Drag map or tap anywhere to position pin',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Center Pin Marker
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 38),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF004D40),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Selected Location',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.location_on,
                          size: 42,
                          color: Color(0xFFE65100),
                        ),
                        Container(
                          width: 8,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Zoom Controls (+ and -)
                Positioned(
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      _buildFloatingButton(
                        icon: Icons.add,
                        tooltip: 'Zoom In',
                        onPressed: _currentZoom < 19 ? () => setState(() => _currentZoom++) : null,
                      ),
                      const SizedBox(height: 6),
                      _buildFloatingButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom Out',
                        onPressed: _currentZoom > 3 ? () => setState(() => _currentZoom--) : null,
                      ),
                    ],
                  ),
                ),

                // Live Floating GPS Button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF004D40),
                    elevation: 4,
                    onPressed: _isLoadingGps ? null : _moveToCurrentGps,
                    icon: _isLoadingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004D40)),
                          )
                        : const Icon(Icons.gps_fixed, size: 18, color: Color(0xFF004D40)),
                    label: const Text(
                      'My GPS Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF004D40)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: onPressed != null ? const Color(0xFF004D40) : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF80CBC4)),
                  ),
                  child: const Icon(Icons.pin_drop, color: Color(0xFF004D40), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PINNED SERVICE COORDINATES',
                            style: TextStyle(
                              color: AppColors.outline,
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF81C784)),
                            ),
                            child: Text(
                              '${_currentLat.toStringAsFixed(5)}°N, ${_currentLng.toStringAsFixed(5)}°E',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (_isResolvingAddress)
                        const Row(
                          children: [
                            SizedBox(
                              height: 13,
                              width: 13,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004D40)),
                            ),
                            SizedBox(width: 8),
                            Text('Resolving exact address details...', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                          ],
                        )
                      else
                        Text(
                          _resolvedAddress?.formattedAddress.isNotEmpty == true
                              ? _resolvedAddress!.formattedAddress
                              : 'Lat: ${_currentLat.toStringAsFixed(5)}, Lng: ${_currentLng.toStringAsFixed(5)}',
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '💡 Drag the map or tap any street to pinpoint your shop, workshop, or home entrance.',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                onPressed: _confirmSelection,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'Confirm This Pinned Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
