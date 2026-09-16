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

/// Interactive location picker screen with Google Maps and graceful fallback.
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
  bool _mapFailedToLoad = false;
  GeoAddress? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLatitude ?? _defaultLat;
    _currentLng = widget.initialLongitude ?? _defaultLng;
    _resolveAddress(_currentLat, _currentLng);
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isResolvingAddress = true);
    try {
      final addr = await DI.locationService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _resolvedAddress = addr;
          _isResolvingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isResolvingAddress = false);
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
      final msg = result.errorMessage ?? 'Unable to detect current location.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        address: _resolvedAddress,
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
          IconButton(
            icon: Icon(_mapFailedToLoad ? Icons.map_outlined : Icons.view_agenda_outlined, color: AppColors.primary),
            tooltip: _mapFailedToLoad ? 'Show Map' : 'Show Fallback View',
            onPressed: () => setState(() => _mapFailedToLoad = !_mapFailedToLoad),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Google Map or Fallback View
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
            _buildMapFallbackView(),

          // 2. Fixed Center Pin Marker
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

          // 3. Floating Action: GPS Target Button
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
                        'SERVICE LOCATION',
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
              'Move the map or drag the pin to pinpoint your service entrance.',
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

  Widget _buildMapFallbackView() {
    return Container(
      color: AppColors.surfaceContainerLow,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Icon(Icons.map_outlined, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Map View Mode',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Coordinates: ${_currentLat.toStringAsFixed(5)}, ${_currentLng.toStringAsFixed(5)}',
                style: AppTypography.bodySm.copyWith(color: AppColors.outline),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLowest,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
                onPressed: _moveToCurrentGps,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Update with Current GPS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
