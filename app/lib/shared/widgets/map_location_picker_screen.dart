import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/config/dependency_injection.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';

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

class _PuneAreaPreset {
  final String label;
  final String addressLine;
  final String area;
  final String postalCode;
  final double latitude;
  final double longitude;

  const _PuneAreaPreset({
    required this.label,
    required this.addressLine,
    required this.area,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
  });
}

const List<_PuneAreaPreset> _punePresets = [
  _PuneAreaPreset(
    label: 'Deccan',
    addressLine: '45 Deccan Gymkhana Road',
    area: 'Deccan Gymkhana',
    postalCode: '411004',
    latitude: 18.5173,
    longitude: 73.8415,
  ),
  _PuneAreaPreset(
    label: 'Kothrud',
    addressLine: '12 Mayur Colony, Paud Road',
    area: 'Kothrud',
    postalCode: '411038',
    latitude: 18.5074,
    longitude: 73.8077,
  ),
  _PuneAreaPreset(
    label: 'Baner',
    addressLine: 'Survey 44, Pan Card Club Road',
    area: 'Baner',
    postalCode: '411045',
    latitude: 18.5590,
    longitude: 73.7868,
  ),
  _PuneAreaPreset(
    label: 'Bavdhan',
    addressLine: 'NDA Road, Near Chandani Chowk',
    area: 'Bavdhan',
    postalCode: '411021',
    latitude: 18.5147,
    longitude: 73.7744,
  ),
  _PuneAreaPreset(
    label: 'Hinjewadi',
    addressLine: 'Phase 1, Rajiv Gandhi Infotech Park',
    area: 'Hinjewadi',
    postalCode: '411057',
    latitude: 18.5913,
    longitude: 73.7389,
  ),
  _PuneAreaPreset(
    label: 'Wakad',
    addressLine: 'Datta Mandir Road',
    area: 'Wakad',
    postalCode: '411057',
    latitude: 18.5987,
    longitude: 73.7660,
  ),
  _PuneAreaPreset(
    label: 'Viman Nagar',
    addressLine: 'Symbiosis Road, Clover Park',
    area: 'Viman Nagar',
    postalCode: '411014',
    latitude: 18.5679,
    longitude: 73.9143,
  ),
  _PuneAreaPreset(
    label: 'Hadapsar',
    addressLine: 'Magarpatta City Main Road',
    area: 'Hadapsar',
    postalCode: '411028',
    latitude: 18.5089,
    longitude: 73.9259,
  ),
  _PuneAreaPreset(
    label: 'Shivajinagar',
    addressLine: 'FC Road, Near Deccan College',
    area: 'Shivajinagar',
    postalCode: '411005',
    latitude: 18.5314,
    longitude: 73.8446,
  ),
];

/// Interactive location picker screen with Google Maps and graceful fallback for Web.
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
  // Default to Pune coordinates (18.5204, 73.8567) if not provided
  static const double _defaultLat = 18.5204303;
  static const double _defaultLng = 73.8567437;

  late double _currentLat;
  late double _currentLng;
  GoogleMapController? _mapController;

  bool _isLoadingGps = false;
  bool _isResolvingAddress = false;
  // On web, Google Maps JS SDK requires an external API key script in index.html.
  // Default to the crash-proof interactive selector on web to avoid runtime JS TypeError.
  bool _mapFailedToLoad = kIsWeb;
  GeoAddress? _resolvedAddress;
  String? _selectedPresetLabel;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLatitude ?? _defaultLat;
    _currentLng = widget.initialLongitude ?? _defaultLng;

    // Set default preset match or resolve address
    _findMatchingPresetOrResolve(_currentLat, _currentLng);
  }

  void _findMatchingPresetOrResolve(double lat, double lng) {
    for (final p in _punePresets) {
      if ((p.latitude - lat).abs() < 0.01 && (p.longitude - lng).abs() < 0.01) {
        _selectedPresetLabel = p.label;
        _resolvedAddress = GeoAddress(
          addressLine: p.addressLine,
          area: p.area,
          city: 'Pune',
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
      final addr = await DI.locationService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _resolvedAddress = addr ??
              GeoAddress(
                addressLine: 'Near selected location',
                area: 'Pune Urban',
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
            area: 'Pune Urban',
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
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(coords.latitude, coords.longitude),
            zoom: 16.5,
          ),
        ),
      );

      _resolveAddress(coords.latitude, coords.longitude);
    } else {
      final msg = result.errorMessage ?? 'Unable to detect current GPS location.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _selectPreset(_PuneAreaPreset preset) {
    setState(() {
      _currentLat = preset.latitude;
      _currentLng = preset.longitude;
      _selectedPresetLabel = preset.label;
      _resolvedAddress = GeoAddress(
        addressLine: preset.addressLine,
        area: preset.area,
        city: 'Pune',
        state: 'Maharashtra',
        postalCode: preset.postalCode,
      );
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(preset.latitude, preset.longitude),
          zoom: 15.5,
        ),
      ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    _currentLat = position.target.latitude;
    _currentLng = position.target.longitude;
  }

  void _onCameraIdle() {
    _resolveAddress(_currentLat, _currentLng);
  }

  void _confirmSelection() {
    Navigator.of(context).pop(
      LocationPickerResult(
        latitude: _currentLat,
        longitude: _currentLng,
        address: _resolvedAddress ??
            GeoAddress(
              addressLine: 'Selected location',
              area: _selectedPresetLabel ?? 'Pune',
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
          widget.title ?? 'Select Service Location',
          style: AppTypography.titleMd.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        actions: [
          // On mobile, allow toggling between map and grid view
          if (!kIsWeb)
            IconButton(
              icon: Icon(_mapFailedToLoad ? Icons.map_outlined : Icons.view_agenda_outlined, color: AppColors.primary),
              tooltip: _mapFailedToLoad ? 'Show Native Map' : 'Show Location Presets',
              onPressed: () => setState(() => _mapFailedToLoad = !_mapFailedToLoad),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Google Map (Mobile) or Interactive Visual Fallback (Web)
          if (!_mapFailedToLoad)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentLat, _currentLng),
                zoom: 15.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
            )
          else
            _buildInteractiveLocationView(),

          // 2. Fixed Center Pin Marker (Only in native map view)
          if (!_mapFailedToLoad)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadius.radiusFull,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        'Set Location Here',
                        style: AppTypography.labelSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_on,
                      size: 44,
                      color: AppColors.secondary,
                    ),
                    Container(
                      width: 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: AppRadius.radiusFull,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Floating Action: GPS Target Button (Only in native map view)
          if (!_mapFailedToLoad)
            Positioned(
              right: AppSpacing.marginMobile,
              bottom: 220,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 3,
                onPressed: _isLoadingGps ? null : _moveToCurrentGps,
                child: _isLoadingGps
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),

          // 4. Bottom Confirmation Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveLocationView() {
    return Container(
      color: AppColors.surfaceContainerLowest,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 260),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual simulated map card with current pin
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surfaceContainerLow,
                    AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: AppRadius.radiusXl,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Stylized map grid lines
                  CustomPaint(
                    size: const Size(double.infinity, 140),
                    painter: _MapGridPainter(),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.radiusFull,
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Text(
                          _selectedPresetLabel ?? 'Pinned Location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(Icons.location_on, size: 38, color: AppColors.secondary),
                      Container(
                        width: 8,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: AppRadius.radiusFull,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Text(
                        '${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live GPS button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white,
                ),
                onPressed: _isLoadingGps ? null : _moveToCurrentGps,
                icon: _isLoadingGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  _isLoadingGps ? 'Detecting Browser GPS...' : 'Detect Exact Current Location (GPS)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Area Quick-Chips Title
            Row(
              children: [
                const Icon(Icons.apartment, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'POPULAR PUNE REGIONS',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quick Selection Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _punePresets.map((preset) {
                final isSelected = _selectedPresetLabel == preset.label;
                return ChoiceChip(
                  label: Text(preset.label),
                  selected: isSelected,
                  onSelected: (_) => _selectPreset(preset),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.primary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.radiusLg,
                  ),
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECTED LOCATION',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.outline,
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_isResolvingAddress)
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
                        )
                      else
                        Text(
                          _resolvedAddress?.formattedAddress.isNotEmpty == true
                              ? _resolvedAddress!.formattedAddress
                              : 'Lat: ${_currentLat.toStringAsFixed(5)}, Lng: ${_currentLng.toStringAsFixed(5)}',
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Tap any region chip or click "Detect Exact Current Location" to update.'
                  : 'Move the map or drag the pin to pinpoint your service entrance.',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  elevation: 0,
                ),
                onPressed: _confirmSelection,
                icon: const Icon(Icons.check, size: 18),
                label: Text(
                  'Confirm This Location',
                  style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
