import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../core/services/india_geography_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/widgets/map_location_picker_screen.dart';
import '../../data/models/worker_models.dart';
import 'worker_under_verification_screen.dart';
import '../../../../shared/widgets/area_not_serviceable_screen.dart';
import '../../../../core/utils/phone_number_util.dart';
import '../../../../core/utils/distance_calculator.dart';

class AreaSuggestionItem {
  final String name;
  final double distanceKm;
  final bool is7to10Km;

  const AreaSuggestionItem({
    required this.name,
    required this.distanceKm,
    required this.is7to10Km,
  });
}

class WorkerRegistrationScreen extends StatefulWidget {
  final bool isResubmission;
  final String? changeRequestReason;

  const WorkerRegistrationScreen({
    super.key,
    this.isResubmission = false,
    this.changeRequestReason,
  });

  static const Map<String, List<String>> tradeSubSkills = {
    'Plumbing': [
      'Plumbing & Pipe Fitting',
      'Drainage & Sewage Line Cleaning',
      'Water Tank Cleaning & Installation',
      'Bathroom Fittings & Sanitary Fixtures',
      'Water Pump & Motor Repair',
      'Leak Detection & Commercial Plumbing',
    ],
    'Electrical': [
      'Electrical & Home Wiring',
      'Switchboard & MCB Fuse Installation',
      'Inverter & Battery Wiring',
      'Ceiling Fan & Light Fixture Installation',
      'Three-Phase Industrial Wiring',
      'Earthing & Power Surge Protection',
    ],
    'Carpentry': [
      'Carpentry & Woodwork',
      'Furniture Assembly & Repair',
      'Modular Kitchen & Wardrobe Fabrication',
      'Door, Window & Lock Fitting',
      'Wood Polishing & Varnishing',
      'Custom Cabinet & Shelf Making',
    ],
    'Masonry & Construction': [
      'Masonry & Civil Repair',
      'Tile, Marble & Granite Laying',
      'Wall Plastering & Bricklaying',
      'Concrete Flooring & Structural Repair',
      'Roof Sealing & Waterproofing Works',
    ],
    'Cleaning & Sanitation': [
      'Home Deep Cleaning',
      'Kitchen & Chimney Degreasing',
      'Bathroom Disinfection & Tile Scrubbing',
      'Sofa, Carpet & Mattress Shampooing',
      'Water Tank Deep Sanitation',
      'Post-Construction Cleanup',
    ],
    'Appliance Repair': [
      'Appliance Repair (AC / Fridge / Washing Machine)',
      'AC Servicing, Gas Refill & Installation',
      'Refrigerator & Deep Freezer Repair',
      'Washing Machine & Dryer Repair',
      'Microwave & Induction Hob Repair',
      'Water Purifier (RO) Servicing & Filter Replacement',
      'Geyser & Water Heater Repair',
    ],
    'Painting & Waterproofing': [
      'Painting & Wall Waterproofing',
      'Interior Emulsion & Texture Painting',
      'Exterior Weatherproof Coating',
      'Wall Putty, Primer & Crack Sealing',
      'Wood & Metal Enamel Painting',
      'Terrace & Balcony Waterproofing',
    ],
    'Welding & Fabrication': [
      'Welding & Metal Fabrication',
      'Safety Grill & Gate Fabrication',
      'Shed, Truss & Roof Structure Welding',
      'Aluminum Sliding Window Fabrication',
      'Stainless Steel Railing Work',
    ],
    'General Maintenance': [
      'General Maintenance & Handyman',
      'Minor Civil, Wall Drill & Hanging Services',
      'Locksmith & Key Duplication Service',
      'Curtain Rod & Blinds Installation',
      'Preventive Home Maintenance Inspection',
    ],
  };

  @override
  State<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Full Name, 2. Mobile Number & 3. Email Address
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // 4. DOB & 5. Gender
  final TextEditingController _dobController = TextEditingController();
  String _selectedGender = 'Male';

  // 6. Current Address, 7. City, 8. District, 9. PIN Code & Geographic Dropdowns
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();

  String _selectedState = 'Maharashtra';
  String _selectedDistrict = 'Pune';
  String _selectedCityOrArea = 'Kothrud';
  List<String> _availableDistricts = [];
  List<String> _availableAreas = [];
  bool _isResolvingPincode = false;
  String? _pincodeFeedback;

  // Geographic Coordinates & Location Method (Auto vs Pin on Map)
  double? _latitude;
  double? _longitude;
  bool _isAutoFetchingLocation = false;
  String? _locationStatusFeedback;
  String _locationMethod = 'NONE'; // 'AUTO', 'MAP', 'MANUAL'

  // Application Review Locking Gate: without approval cannot be changed
  bool _isLockedUnderReview = false;

  // 10. Trade, 11. Primary Skill, 12. Skill Level, 13. Experience, 14. Service Area, 15. Availability
  String? _selectedTrade;
  String? _selectedSkill;
  String? _selectedSkillLevel;
  int? _selectedExperienceYears;
  String _selectedArea = 'Kothrud, Pune';
  List<String> _selectedServiceAreas = ['Kothrud, Pune'];
  bool _isAvailable = true;

  /// Default district center coordinates for all 36 Maharashtra districts + Indian metros
  static const Map<String, (double, double)> _districtCoordinates = {
    // Maharashtra (All 36 Districts)
    'Pune': (18.5204, 73.8567),
    'Ahmednagar': (19.0948, 74.7480),
    'Ahilyanagar': (19.0948, 74.7480),
    'Nashik': (19.9975, 73.7898),
    'Nagpur': (21.1458, 79.0882),
    'Mumbai City': (18.9388, 72.8354),
    'Mumbai Suburban': (19.0760, 72.8777),
    'Thane': (19.2183, 72.9781),
    'Chhatrapati Sambhajinagar': (19.8762, 75.3433),
    'Aurangabad': (19.8762, 75.3433),
    'Kolhapur': (16.7050, 74.2433),
    'Solapur': (17.6599, 75.9064),
    'Amravati': (20.9374, 77.7796),
    'Akola': (20.7002, 77.0082),
    'Jalgaon': (21.0077, 75.5626),
    'Nanded': (19.1383, 77.3210),
    'Sangli': (16.8524, 74.5815),
    'Satara': (17.6805, 73.9934),
    'Latur': (18.4088, 76.5604),
    'Dhule': (20.9042, 74.7749),
    'Chandrapur': (19.9615, 79.2961),
    'Parbhani': (19.2686, 76.7744),
    'Jalna': (19.8347, 75.8816),
    'Beed': (18.9891, 75.7601),
    'Raigad': (18.5158, 73.1822),
    'Ratnagiri': (16.9902, 73.3120),
    'Sindhudurg': (16.1180, 73.6934),
    'Yavatmal': (20.3888, 78.1204),
    'Wardha': (20.7453, 78.6022),
    'Bhandara': (21.1685, 79.6558),
    'Gondia': (21.4624, 80.1961),
    'Gadchiroli': (20.1809, 79.9936),
    'Buldhana': (20.5293, 76.1843),
    'Washim': (20.1090, 77.1352),
    'Hingoli': (19.7173, 77.1485),
    'Nandurbar': (21.3683, 74.2394),
    'Osmanabad': (18.1861, 76.0419),
    'Dharashiv': (18.1861, 76.0419),
    'Palghar': (19.6967, 72.7699),

    // Other Major Metros
    'New Delhi': (28.6139, 77.2090),
    'South Delhi': (28.4817, 77.1873),
    'Bengaluru Urban': (12.9716, 77.5946),
    'Hyderabad': (17.3850, 78.4867),
    'Chennai': (13.0827, 80.2707),
    'Kolkata': (22.5726, 88.3639),
    'Ahmedabad': (23.0225, 72.5714),
    'Jaipur': (26.9124, 75.7873),
    'Lucknow': (26.8467, 80.9462),
  };

  /// Known coordinates for prominent localities across Maharashtra urban hubs
  static const Map<String, (double, double)> _knownAreaCoordinates = {
    // Pune Localities
    'Kothrud, Pune': (18.5074, 73.8077),
    'Kothrud': (18.5074, 73.8077),
    'Shivajinagar, Pune': (18.5314, 73.8446),
    'Shivajinagar': (18.5314, 73.8446),
    'Baner & Balewadi, Pune': (18.5590, 73.7868),
    'Baner': (18.5590, 73.7868),
    'Balewadi': (18.5726, 73.7717),
    'Wakad & Pimple Saudagar, Pune': (18.5987, 73.7660),
    'Wakad': (18.5987, 73.7660),
    'Pimple Saudagar': (18.5978, 73.7885),
    'Hinjewadi, Pune': (18.5913, 73.7389),
    'Hinjewadi': (18.5913, 73.7389),
    'Hadapsar, Pune': (18.5089, 73.9259),
    'Hadapsar': (18.5089, 73.9259),
    'Viman Nagar & Kalyani Nagar, Pune': (18.5679, 73.9143),
    'Viman Nagar': (18.5679, 73.9143),
    'Kalyani Nagar': (18.5463, 73.9034),
    'Swargate & Bibwewadi, Pune': (18.5018, 73.8586),
    'Swargate': (18.5018, 73.8586),
    'Bibwewadi': (18.4745, 73.8647),
    'Pimpri-Chinchwad, Pune': (18.6279, 73.7997),
    'Pimpri': (18.6279, 73.7997),
    'Chinchwad': (18.6358, 73.7937),
    'Katraj & Dhankawadi, Pune': (18.4575, 73.8565),
    'Katraj': (18.4575, 73.8565),
    'Dhankawadi': (18.4674, 73.8524),
    'Aundh & Pashan, Pune': (18.5580, 73.8075),
    'Aundh': (18.5580, 73.8075),
    'Pashan': (18.5413, 73.7925),
    'Kharadi & Wagholi, Pune': (18.5514, 73.9348),
    'Kharadi': (18.5514, 73.9348),
    'Wagholi': (18.5802, 73.9787),
    'Bavdhan': (18.5147, 73.7744),
    'Bavdhan, Pune': (18.5147, 73.7744),
    'Karve Nagar': (18.4913, 73.8193),
    'Karve Nagar, Pune': (18.4913, 73.8193),
    'Warje': (18.4815, 73.8021),
    'Warje, Pune': (18.4815, 73.8021),
    'Sinhagad Road': (18.4682, 73.8219),
    'Sinhagad Road, Pune': (18.4682, 73.8219),
    'Deccan Gymkhana': (18.5173, 73.8415),
    'Deccan Gymkhana, Pune': (18.5173, 73.8415),
    'Kondhwa': (18.4746, 73.8940),
    'Kondhwa, Pune': (18.4746, 73.8940),
    'Magarpatta': (18.5158, 73.9272),
    'Camp / Pune Cantonment': (18.5158, 73.8797),

    // Ahmednagar / Ahilyanagar Localities
    'Bhavani Nagar, Ahmednagar': (19.0948, 74.7480),
    'Bhavani Nagar': (19.0948, 74.7480),
    'Bhavani, Ahmednagar': (19.0948, 74.7480),
    'Savedi, Ahmednagar': (19.1205, 74.7315),
    'Savedi': (19.1205, 74.7315),
    'Pipeline Road, Ahmednagar': (19.1350, 74.7210),
    'Pipeline Road': (19.1350, 74.7210),
    'MIDC Ahmednagar': (19.1620, 74.7100),
    'Station Road, Ahmednagar': (19.0880, 74.7410),
    'Station Road': (19.0880, 74.7410),
    'Kotla, Ahmednagar': (19.0970, 74.7390),
    'Kotla': (19.0970, 74.7390),
    'Tophkhana, Ahmednagar': (19.1010, 74.7320),
    'Tophkhana': (19.1010, 74.7320),
    'Bhingar, Ahmednagar': (19.0790, 74.7640),
    'Bhingar': (19.0790, 74.7640),
    'Mukundnagar, Ahmednagar': (19.0850, 74.7520),
    'Mukundnagar': (19.0850, 74.7520),
    'Nagar City, Ahmednagar': (19.0950, 74.7450),
    'Nagar City': (19.0950, 74.7450),
    'Vilad Ghat, Ahmednagar': (19.1750, 74.6980),
    'Vilad Ghat': (19.1750, 74.6980),

    // Nashik Localities
    'Panchavati, Nashik': (20.0110, 73.7990),
    'Panchavati': (20.0110, 73.7990),
    'CIDCO, Nashik': (19.9730, 73.7540),
    'Cidco': (19.9730, 73.7540),
    'College Road, Nashik': (20.0050, 73.7630),
    'College Road': (20.0050, 73.7630),
    'Gangapur Road, Nashik': (20.0160, 73.7550),
    'Gangapur Road': (20.0160, 73.7550),
    'Indira Nagar, Nashik': (19.9650, 73.7780),
    'Indira Nagar': (19.9650, 73.7780),
    'Satpur, Nashik': (19.9920, 73.7250),
    'Satpur': (19.9920, 73.7250),
    'Ambad, Nashik': (19.9480, 73.7380),
    'Ambad': (19.9480, 73.7380),
    'Satpur & Ambad MIDC, Nashik': (19.9700, 73.7315),
    'Nashik Road, Nashik': (19.9540, 73.8340),
    'Nashik Road': (19.9540, 73.8340),
    'Deolali, Nashik': (19.9230, 73.8310),
    'Deolali': (19.9230, 73.8310),

    // Nagpur Localities
    'Dharampeth, Nagpur': (21.1440, 79.0620),
    'Dharampeth': (21.1440, 79.0620),
    'Sitabuldi, Nagpur': (21.1470, 79.0830),
    'Sitabuldi': (21.1470, 79.0830),
    'Dharampeth & Sitabuldi, Nagpur': (21.1455, 79.0725),
    'Sadar, Nagpur': (21.1620, 79.0820),
    'Sadar': (21.1620, 79.0820),
    'Civil Lines, Nagpur': (21.1550, 79.0710),
    'Civil Lines': (21.1550, 79.0710),
    'Sadar & Civil Lines, Nagpur': (21.1585, 79.0765),
    'Ramdaspeth, Nagpur': (21.1340, 79.0730),
    'Ramdaspeth': (21.1340, 79.0730),
    'Manish Nagar, Nagpur': (21.0920, 79.0820),
    'Manish Nagar': (21.0920, 79.0820),
    'Wardha Road': (21.0850, 79.0750),
    'IT Park, Nagpur': (21.1210, 79.0490),
    'IT Park': (21.1210, 79.0490),

    // Chhatrapati Sambhajinagar Localities
    'CIDCO, Chhatrapati Sambhajinagar': (19.8780, 75.3670),
    'Garkheda, Chhatrapati Sambhajinagar': (19.8650, 75.3480),
    'Garkheda': (19.8650, 75.3480),
    'Waluj MIDC, Chhatrapati Sambhajinagar': (19.8320, 75.2340),
    'Waluj': (19.8320, 75.2340),
    'Samarth Nagar, Chhatrapati Sambhajinagar': (19.8820, 75.3280),
    'Samarth Nagar': (19.8820, 75.3280),
    'Chikalthana MIDC': (19.8850, 75.3980),
    'Railway Station Area': (19.8620, 75.3190),

    // Mumbai City & Suburban Localities
    'Andheri East': (19.1136, 72.8697),
    'Andheri West': (19.1363, 72.8277),
    'Andheri & Juhu, Mumbai': (19.1200, 72.8350),
    'Bandra West': (19.0596, 72.8295),
    'Bandra East': (19.0607, 72.8515),
    'Bandra & Khar, Mumbai': (19.0650, 72.8350),
    'Dadar': (19.0178, 72.8478),
    'Dadar & Parel, Mumbai': (19.0100, 72.8440),
    'Parel': (19.0016, 72.8402),
    'Colaba': (18.9067, 72.8147),
    'Colaba & Fort, Mumbai': (18.9200, 72.8250),
    'Fort': (18.9322, 72.8335),
    'Worli': (19.0134, 72.8183),
    'Borivali West': (19.2307, 72.8567),
    'Ghatkopar': (19.0860, 72.9090),
    'Powai': (19.1176, 72.9060),
    'Mulund': (19.1726, 72.9565),
    'Chembur': (19.0622, 72.8997),

    // Thane & MMR Localities
    'Thane West': (19.2183, 72.9781),
    'Thane West, Thane': (19.2183, 72.9781),
    'Kalyan': (19.2403, 73.1305),
    'Dombivli': (19.2184, 73.0867),
    'Kalyan & Dombivli, Thane': (19.2290, 73.1080),
    'Mira Road': (19.2812, 72.8561),
    'Navi Mumbai & Vashi': (19.0771, 72.9986),
    'Vashi': (19.0771, 72.9986),

    // Kolhapur Localities
    'Rajarampuri, Kolhapur': (16.6920, 74.2440),
    'Rajarampuri': (16.6920, 74.2440),
    'Shahupuri, Kolhapur': (16.7020, 74.2380),
    'Shahupuri': (16.7020, 74.2380),
    'Rajarampuri & Shahupuri, Kolhapur': (16.6970, 74.2410),
    'Tarabai Park, Kolhapur': (16.7110, 74.2320),
    'Tarabai Park': (16.7110, 74.2320),
    'Nagala Park, Kolhapur': (16.7160, 74.2280),
    'Nagala Park': (16.7160, 74.2280),
    'Rankala, Kolhapur': (16.6890, 74.2150),
    'Rankala': (16.6890, 74.2150),

    // Solapur Localities
    'Jule Solapur, Solapur': (17.6320, 75.9180),
    'Jule Solapur': (17.6320, 75.9180),
    'Hotgi Road, Solapur': (17.6410, 75.9320),
    'Hotgi Road': (17.6410, 75.9320),
    'Saat Rasta, Solapur': (17.6680, 75.9080),
    'Saat Rasta': (17.6680, 75.9080),
    'Old Pune Naka, Solapur': (17.6740, 75.8950),
    'Old Pune Naka': (17.6740, 75.8950),
  };

  /// Smart coordinate resolver for any locality in any district
  static (double, double) _getCoordinatesForArea(String areaName, String districtName) {
    if (_knownAreaCoordinates.containsKey(areaName)) {
      return _knownAreaCoordinates[areaName]!;
    }
    final basePart = areaName.split(',').first.trim();
    if (_knownAreaCoordinates.containsKey(basePart)) {
      return _knownAreaCoordinates[basePart]!;
    }
    final uncombined = areaName.replaceAll('&', '').trim();
    if (_knownAreaCoordinates.containsKey(uncombined)) {
      return _knownAreaCoordinates[uncombined]!;
    }

    final distCoords = _districtCoordinates[districtName] ??
        _districtCoordinates[districtName.split(' ').first] ??
        const (18.5204, 73.8567);

    // Deterministic hash offset placing unknown localities within 2.5 to 8.5 km radius around district center
    final hash = areaName.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final angle = (hash % 360) * pi / 180.0;
    final radiusDeg = 0.025 + ((hash % 50) / 1000.0);
    final lat = distCoords.$1 + radiusDeg * sin(angle);
    final lng = distCoords.$2 + radiusDeg * cos(angle);
    return (lat, lng);
  }

  /// Automatically synchronizes service areas when district or city changes,
  /// strictly removing any areas from outside the selected district
  void _syncServiceAreasToDistrict(String district, String cityOrArea) {
    final base = cityOrArea.toLowerCase().contains(district.toLowerCase())
        ? cityOrArea
        : '$cityOrArea, $district';
    _selectedArea = base;

    final districtLower = district.toLowerCase();
    final remaining = _selectedServiceAreas.where((a) {
      final aLower = a.toLowerCase();
      return aLower.contains(districtLower);
    }).toList();

    if (remaining.isEmpty) {
      _selectedServiceAreas = [base];
    } else {
      if (!remaining.contains(base)) {
        remaining.insert(0, base);
      }
      _selectedServiceAreas = remaining.take(3).toList();
    }
  }

  /// Compute area proximity suggestions relative to the worker's base address/GPS location.
  /// Strictly capped at <= 10.0 km (excluding outer areas > 10 km) and strictly isolated to current district!
  List<AreaSuggestionItem> _getAreaSuggestions() {
    double baseLat;
    double baseLng;

    if (_latitude != null && _longitude != null) {
      baseLat = _latitude!;
      baseLng = _longitude!;
    } else {
      final baseArea = _selectedServiceAreas.isNotEmpty ? _selectedServiceAreas.first : _selectedArea;
      final coords = _getCoordinatesForArea(baseArea, _selectedDistrict);
      baseLat = coords.$1;
      baseLng = coords.$2;
    }

    final List<AreaSuggestionItem> list = [];
    final candidates = <String>{};

    // STRICT DISTRICT SCOPING:
    // Only candidates belonging to the worker's selected district are considered!
    for (final area in _availableAreas) {
      final formatted = area.contains(_selectedDistrict) ? area : '$area, $_selectedDistrict';
      candidates.add(formatted);
    }

    for (final area in _serviceAreasList) {
      if (area.toLowerCase().contains(_selectedDistrict.toLowerCase())) {
        candidates.add(area);
      }
    }

    for (final area in candidates) {
      if (_selectedServiceAreas.contains(area)) continue;

      // Avoid suggesting something already covered by a selected chip (e.g. 'Kothrud' vs 'Kothrud, Pune')
      final areaBase = area.split(',').first.trim().toLowerCase();
      final alreadySelected = _selectedServiceAreas.any((s) {
        final sBase = s.split(',').first.trim().toLowerCase();
        return sBase == areaBase;
      });
      if (alreadySelected) continue;

      final coords = _getCoordinatesForArea(area, _selectedDistrict);
      final dist = HaversineDistanceUtil.calculateDistance(baseLat, baseLng, coords.$1, coords.$2);

      // STRICT CEILING: ONLY suggest areas within 10.0 km!
      // Anything > 10.0 km is "outer than the artisan's serviceable cluster" and must be excluded.
      if (dist != null && dist >= 0.5 && dist <= 10.0) {
        final is7to10 = dist >= 7.0 && dist <= 10.0;
        list.add(AreaSuggestionItem(name: area, distanceKm: dist, is7to10Km: is7to10));
      }
    }

    // Sort: 7-10 km suggestions prioritized, then by distance ascending
    list.sort((a, b) {
      if (a.is7to10Km && !b.is7to10Km) return -1;
      if (!a.is7to10Km && b.is7to10Km) return 1;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return list;
  }

  void _addServiceArea(String area) {
    if (_isLockedUnderReview) return;
    final dLower = _selectedDistrict.toLowerCase();
    if (!area.toLowerCase().contains(dLower) &&
        !_availableAreas.any((a) => a.toLowerCase() == area.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add area outside of $_selectedDistrict district.'),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_selectedServiceAreas.contains(area)) return;
    if (_selectedServiceAreas.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 service areas allowed. Remove an existing area to add another.'),
          backgroundColor: Color(0xFFE65100),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _selectedServiceAreas.add(area);
      if (_selectedServiceAreas.length == 1) {
        _selectedArea = area;
        _autoRouteFederation(area);
      }
    });
  }

  void _removeServiceArea(String area) {
    if (_isLockedUnderReview) return;
    if (_selectedServiceAreas.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 1 primary service area must remain selected.'),
          backgroundColor: Color(0xFFC62828),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _selectedServiceAreas.remove(area);
      _selectedArea = _selectedServiceAreas.first;
      _autoRouteFederation(_selectedArea);
    });
  }

  // 18. Cooperative/Federation, 19. Membership ID
  String? _selectedFederationId;
  String _federationName = '';
  bool _userSelectedFederationManually = false;
  final TextEditingController _membershipIdController = TextEditingController();
  List<FederationModel> _availableFederations = List.from(FederationModel.defaultFederations);

  Future<void> _loadFederations() async {
    try {
      final feds = await FederationModel.fetchAllFederations();
      if (mounted && feds.isNotEmpty) {
        setState(() {
          _availableFederations = feds;
        });
        if (!_userSelectedFederationManually) {
          _autoRouteFederation(_selectedArea);
        }
      }
    } catch (e) {
      debugPrint('[WorkerRegistration] loadFederations error: $e');
    }
  }

  void _autoRouteFederation(String text) {
    if (text.trim().isEmpty) return;
    if (_userSelectedFederationManually && _selectedFederationId != null && _selectedFederationId!.isNotEmpty) {
      return;
    }
    final matched = FederationModel.findFederationForLocation(
      district: _districtController.text.trim().isNotEmpty ? _districtController.text.trim() : _selectedDistrict,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : _selectedCityOrArea,
      state: _selectedState,
      pincode: _pinCodeController.text.trim(),
      location: text,
      federationsList: _availableFederations,
    );
    if (matched != null) {
      setState(() {
        _selectedFederationId = matched.id;
        _federationName = matched.name;
        _selectedDistrict = matched.district;
        _districtController.text = matched.district;
        if (matched.city.isNotEmpty) {
          _selectedCityOrArea = matched.city;
          _cityController.text = matched.city;
        }
      });
    } else {
      setState(() {
        _selectedFederationId = null;
        _federationName = 'Cooperative Expansion Zone (${_selectedDistrict.isNotEmpty ? _selectedDistrict : "Waitlist"})';
      });
    }
  }

  // 20. Worker Declaration
  bool _agreedToCharter = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Uploaded documents state: docType -> PlatformFile
  final Map<String, PlatformFile> _uploadedFiles = {};
  final Set<String> _uploadingDocTypes = {};

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _skillLevels = ['Beginner', 'Intermediate', 'Expert'];
  final Map<String, String> _skillLevelLabels = {
    'Beginner': 'Beginner (1-2 yrs)',
    'Intermediate': 'Intermediate (3-5 yrs)',
    'Expert': 'Expert / Master Artisan (6+ yrs)',
  };
  final List<int> _experienceOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20];

  final List<String> _tradeCategories = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Masonry & Construction',
    'Cleaning & Sanitation',
    'Appliance Repair',
    'Painting & Waterproofing',
    'Welding & Fabrication',
    'General Maintenance',
  ];

  static Map<String, List<String>> get tradeSubSkills => WorkerRegistrationScreen.tradeSubSkills;

  final List<String> _serviceAreasList = [
    // Pune
    'Kothrud, Pune',
    'Shivajinagar, Pune',
    'Baner & Balewadi, Pune',
    'Bavdhan, Pune',
    'Karve Nagar, Pune',
    'Warje, Pune',
    'Deccan Gymkhana, Pune',
    'Sinhagad Road, Pune',
    'Swargate & Bibwewadi, Pune',
    'Aundh & Pashan, Pune',
    'Katraj & Dhankawadi, Pune',
    'Viman Nagar & Kalyani Nagar, Pune',
    'Kondhwa, Pune',
    'Camp / Cantonment, Pune',
    'Wakad & Pimple Saudagar, Pune',
    'Hinjewadi, Pune',
    'Hadapsar, Pune',
    'Pimpri-Chinchwad, Pune',
    'Kharadi & Wagholi, Pune',

    // Ahmednagar / Ahilyanagar
    'Savedi, Ahmednagar',
    'Bhavani Nagar, Ahmednagar',
    'Pipeline Road, Ahmednagar',
    'MIDC Ahmednagar, Ahmednagar',
    'Station Road, Ahmednagar',
    'Kotla, Ahmednagar',
    'Tophkhana, Ahmednagar',
    'Bhingar, Ahmednagar',
    'Mukundnagar, Ahmednagar',
    'Nagar City, Ahmednagar',
    'Vilad Ghat, Ahmednagar',

    // Nashik
    'CIDCO, Nashik',
    'Panchavati, Nashik',
    'College Road, Nashik',
    'Gangapur Road, Nashik',
    'Indira Nagar, Nashik',
    'Satpur & Ambad MIDC, Nashik',
    'Nashik Road, Nashik',
    'Deolali, Nashik',

    // Mumbai City & Suburban
    'Andheri & Juhu, Mumbai Suburban',
    'Bandra & Khar, Mumbai Suburban',
    'Dadar & Parel, Mumbai City',
    'Colaba & Fort, Mumbai City',
    'Ghatkopar & Powai, Mumbai Suburban',
    'Borivali & Kandivali, Mumbai Suburban',

    // Thane & MMR
    'Thane West, Thane',
    'Kalyan & Dombivli, Thane',
    'Navi Mumbai & Vashi, Thane',
    'Mira Road & Bhayandar, Thane',

    // Chhatrapati Sambhajinagar
    'CIDCO, Chhatrapati Sambhajinagar',
    'Garkheda, Chhatrapati Sambhajinagar',
    'Waluj MIDC, Chhatrapati Sambhajinagar',
    'Samarth Nagar, Chhatrapati Sambhajinagar',
    'Chikalthana MIDC, Chhatrapati Sambhajinagar',

    // Nagpur
    'Dharampeth & Sitabuldi, Nagpur',
    'Sadar & Civil Lines, Nagpur',
    'Ramdaspeth & Dhantoli, Nagpur',
    'Manish Nagar & Wardha Road, Nagpur',
    'IT Park, Nagpur',

    // Kolhapur
    'Rajarampuri & Shahupuri, Kolhapur',
    'Tarabai Park & Nagala Park, Kolhapur',
    'Rankala & Laxmipuri, Kolhapur',

    // Solapur
    'Jule Solapur & Hotgi Road, Solapur',
    'Saat Rasta & Old Pune Naka, Solapur',
  ];

  @override
  void initState() {
    super.initState();
    _availableDistricts = IndiaGeographyService.getDistricts(_selectedState);
    _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
    _districtController.text = _selectedDistrict;
    _cityController.text = _selectedCityOrArea;
    _syncServiceAreasToDistrict(_selectedDistrict, _selectedCityOrArea);
    final initialFed = FederationModel.findFederationForLocation(
      district: _selectedDistrict,
      city: _selectedCityOrArea,
      location: _selectedArea,
      federationsList: _availableFederations,
    );
    _selectedFederationId = initialFed?.id;
    _federationName = initialFed?.name ?? 'Cooperative Expansion Zone ($_selectedDistrict)';
    _loadInitialUserData();
    _loadFederations();
  }

  Future<void> _handlePincodeAutoDetect(String val) async {
    final clean = val.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.length == 6) {
      setState(() {
        _isResolvingPincode = true;
        _pincodeFeedback = 'Resolving location...';
      });
      final res = await IndiaGeographyService.lookupPincode(clean);
      if (res != null && mounted) {
        setState(() {
          _selectedState = res.state;
          _availableDistricts = IndiaGeographyService.getDistricts(res.state);
          _selectedDistrict = _availableDistricts.contains(res.district)
              ? res.district
              : (_availableDistricts.isNotEmpty ? _availableDistricts.first : res.district);
          _districtController.text = _selectedDistrict;

          final areas = res.areas.isNotEmpty
              ? res.areas
              : IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
          _availableAreas = areas;
          _selectedCityOrArea = areas.isNotEmpty ? areas.first : res.city;
          _cityController.text = _selectedCityOrArea;
          _syncServiceAreasToDistrict(_selectedDistrict, _selectedCityOrArea);
          _isResolvingPincode = false;
          _pincodeFeedback = 'Detected: $_selectedDistrict, $_selectedState (${res.isFromNetwork ? "Live Post Office" : "Postal Directory"})';
        });
        _autoRouteFederation(_selectedArea);
      } else if (mounted) {
        setState(() {
          _isResolvingPincode = false;
          _pincodeFeedback = null;
        });
      }
    } else {
      if (_pincodeFeedback != null) {
        setState(() => _pincodeFeedback = null);
      }
    }
  }

  Future<void> _autoFetchLiveLocation() async {
    setState(() {
      _isAutoFetchingLocation = true;
      _errorMessage = null;
      _locationStatusFeedback = 'Acquiring GPS coordinates & resolving address...';
    });

    try {
      final locResult = await DI.locationService.getCurrentPosition();
      if (!locResult.isSuccess || locResult.coordinates == null) {
        setState(() {
          _isAutoFetchingLocation = false;
          _locationStatusFeedback = locResult.errorMessage ?? 'Unable to detect GPS position. Try pinning on map or enter manually.';
        });
        return;
      }

      final lat = locResult.coordinates!.latitude;
      final lng = locResult.coordinates!.longitude;
      _latitude = lat;
      _longitude = lng;
      _locationMethod = 'AUTO';

      // 1. Try reverse geocoding via LocationService
      final geoAddr = await DI.locationService.reverseGeocode(lat, lng);

      if (geoAddr != null && mounted) {
        if (geoAddr.addressLine.isNotEmpty) {
          _addressController.text = geoAddr.addressLine;
        }

        if (geoAddr.postalCode.isNotEmpty) {
          _pinCodeController.text = geoAddr.postalCode;
          _handlePincodeAutoDetect(geoAddr.postalCode);
        }

        if (geoAddr.state.isNotEmpty) {
          final matchedState = IndiaGeographyService.states.firstWhere(
            (st) => st.toLowerCase() == geoAddr.state.toLowerCase(),
            orElse: () => _selectedState,
          );
          _selectedState = matchedState;
          _availableDistricts = IndiaGeographyService.getDistricts(_selectedState);
        }

        if (geoAddr.city.isNotEmpty) {
          final matchedDist = _availableDistricts.firstWhere(
            (d) => d.toLowerCase() == geoAddr.city.toLowerCase() || geoAddr.city.toLowerCase().contains(d.toLowerCase()),
            orElse: () => _availableDistricts.isNotEmpty ? _availableDistricts.first : _selectedDistrict,
          );
          _selectedDistrict = matchedDist;
          _districtController.text = matchedDist;
          _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
        }

        if (geoAddr.area.isNotEmpty) {
          _selectedCityOrArea = geoAddr.area;
          _cityController.text = geoAddr.area;
        } else if (geoAddr.city.isNotEmpty) {
          _selectedCityOrArea = geoAddr.city;
          _cityController.text = geoAddr.city;
        }

        _syncServiceAreasToDistrict(_selectedDistrict, _selectedCityOrArea);
        _autoRouteFederation(_selectedArea);

        setState(() {
          _isAutoFetchingLocation = false;
          _locationStatusFeedback = '📍 Auto-detected GPS (${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°): ${_selectedCityOrArea.isNotEmpty ? _selectedCityOrArea : _selectedDistrict}, $_selectedState • All entries auto-filled!';
        });
      } else if (mounted) {
        // Fallback: Bind coordinates and resolve via geography directory
        _districtController.text = _selectedDistrict;
        _cityController.text = _selectedCityOrArea;
        _syncServiceAreasToDistrict(_selectedDistrict, _selectedCityOrArea);
        _autoRouteFederation(_selectedArea);

        setState(() {
          _isAutoFetchingLocation = false;
          _locationStatusFeedback = '📍 GPS captured (${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°): Bound to artisan profile. Address entries auto-synced.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAutoFetchingLocation = false;
          _locationStatusFeedback = 'Location auto-fetch notice: $e. You can pin on map or enter manually.';
        });
      }
    }
  }

  Future<void> _openMapLocationPicker() async {
    final distCoords = _districtCoordinates[_selectedDistrict] ??
        _districtCoordinates[_selectedDistrict.split(' ').first] ??
        const (18.5204, 73.8567);
    final initialLat = _latitude ?? distCoords.$1;
    final initialLng = _longitude ?? distCoords.$2;

    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          title: 'Pin Artisan Service Location',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationMethod = 'MAP';

        if (result.address != null) {
          final addr = result.address!;
          if (addr.addressLine.isNotEmpty) {
            _addressController.text = addr.addressLine;
          }
          if (addr.postalCode.isNotEmpty) {
            _pinCodeController.text = addr.postalCode;
            _handlePincodeAutoDetect(addr.postalCode);
          }
          if (addr.state.isNotEmpty) {
            final matchedState = IndiaGeographyService.states.firstWhere(
              (st) => st.toLowerCase() == addr.state.toLowerCase(),
              orElse: () => _selectedState,
            );
            _selectedState = matchedState;
            _availableDistricts = IndiaGeographyService.getDistricts(_selectedState);
          }
          if (addr.city.isNotEmpty) {
            final matchedDist = _availableDistricts.firstWhere(
              (d) => d.toLowerCase() == addr.city.toLowerCase() || addr.city.toLowerCase().contains(d.toLowerCase()),
              orElse: () => _availableDistricts.isNotEmpty ? _availableDistricts.first : _selectedDistrict,
            );
            _selectedDistrict = matchedDist;
            _districtController.text = matchedDist;
            _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
          }
          if (addr.area.isNotEmpty) {
            _selectedCityOrArea = addr.area;
            _cityController.text = addr.area;
          }
          _syncServiceAreasToDistrict(_selectedDistrict, _selectedCityOrArea);
          _autoRouteFederation(_selectedArea);
        }

        _locationStatusFeedback = '🗺️ Pinned on Map (${result.latitude.toStringAsFixed(4)}°, ${result.longitude.toStringAsFixed(4)}°): All location entries updated!';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pinCodeController.dispose();
    _membershipIdController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUserData() async {
    try {
      final user = await DI.authRepo.getCurrentUser();
      if (user != null) {
        setState(() {
          final rawPhone = user.phone ?? '';
          final cleanedPhone = PhoneNumberUtil.cleanIndianPhone(rawPhone);
          _phoneController.text = cleanedPhone.isNotEmpty ? cleanedPhone : rawPhone;
          if (user.email != null && user.email!.isNotEmpty) {
            _emailController.text = user.email!;
          }
          final metaName = (user.userMetadata?['full_name'] ?? user.userMetadata?['name']) as String?;
          if (metaName != null && metaName.isNotEmpty && !metaName.startsWith('User ')) {
            _nameController.text = metaName;
          }
        });

        // Also check if user profile exists
        final dbUser = await DI.userRepo.getUserProfile(user.id);
        if (dbUser != null) {
          final dbName = (dbUser['full_name'] as String?)?.trim() ?? '';
          if (dbName.isNotEmpty && !dbName.startsWith('User ') && _nameController.text.isEmpty) {
            setState(() {
              _nameController.text = dbName;
            });
          }
          final dbEmail = (dbUser['email'] as String?)?.trim() ?? '';
          if (dbEmail.isNotEmpty && _emailController.text.isEmpty) {
            setState(() {
              _emailController.text = dbEmail;
            });
          }
        }

        // Check if existing worker record exists to prefill during edit/resubmission
        try {
          final worker = await DI.workerRepo.getWorkerProfile(user.id);
          if (worker.id.isNotEmpty && worker.name.isNotEmpty && !worker.name.startsWith('User ') && !worker.name.startsWith('Artisan (')) {
            // Strict review locking: without approval cannot be changed!
            if (!widget.isResubmission) {
              final status = worker.verificationStatus;
              if (status == VerificationStatus.approved) {
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/worker/dashboard');
                  return;
                }
              } else if (status == VerificationStatus.pending || status == VerificationStatus.underReview) {
                setState(() => _isLockedUnderReview = true);
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const WorkerUnderVerificationScreen()),
                  );
                  return;
                }
              }
            }

            setState(() {
              if (worker.latitude != null && worker.longitude != null) {
                _latitude = worker.latitude;
                _longitude = worker.longitude;
                _locationMethod = 'EXISTING';
                _locationStatusFeedback = '📍 Saved Coordinates: ${_latitude!.toStringAsFixed(4)}°N, ${_longitude!.toStringAsFixed(4)}°E';
              }
              if (_nameController.text.isEmpty) _nameController.text = worker.name;
              if (worker.email != null && worker.email!.isNotEmpty && _emailController.text.isEmpty) {
                _emailController.text = worker.email!;
              }
              if (worker.dob != null && worker.dob!.isNotEmpty) _dobController.text = worker.dob!;
              if (worker.gender != null && _genderOptions.contains(worker.gender)) _selectedGender = worker.gender!;
              if (worker.address != null && worker.address!.isNotEmpty) _addressController.text = worker.address!;
              if (worker.city != null && worker.city!.isNotEmpty) _cityController.text = worker.city!;
              if (worker.district != null && worker.district!.isNotEmpty) _districtController.text = worker.district!;
              if (worker.pinCode != null && worker.pinCode!.isNotEmpty) _pinCodeController.text = worker.pinCode!;
              if (worker.trade != null && _tradeCategories.contains(worker.trade)) {
                _selectedTrade = worker.trade!;
              }
              if (worker.primarySkill != null && worker.primarySkill!.isNotEmpty) {
                _selectedSkill = worker.primarySkill!;
              }
              // Only autofill skill level and experience during resubmission / edit.
              // For new registration, the user explicitly instructed: do not autofill skill level and experience!
              if (widget.isResubmission) {
                if (worker.skillLevel != null) {
                  if (_skillLevels.contains(worker.skillLevel)) {
                    _selectedSkillLevel = worker.skillLevel!;
                  } else if (worker.skillLevel!.toLowerCase().contains('begin')) {
                    _selectedSkillLevel = 'Beginner';
                  } else if (worker.skillLevel!.toLowerCase().contains('expert')) {
                    _selectedSkillLevel = 'Expert';
                  } else {
                    _selectedSkillLevel = 'Intermediate';
                  }
                }
                if (worker.experience.isNotEmpty) {
                  final match = RegExp(r'\d+').firstMatch(worker.experience);
                  if (match != null) {
                    final yrs = int.tryParse(match.group(0)!);
                    if (yrs != null && _experienceOptions.contains(yrs)) {
                      _selectedExperienceYears = yrs;
                    }
                  }
                }
              }
              if (worker.serviceAreas.isNotEmpty) {
                _selectedServiceAreas = List<String>.from(worker.serviceAreas);
                _selectedArea = _selectedServiceAreas.first;
              } else if (worker.serviceLocation.isNotEmpty) {
                _selectedArea = worker.serviceLocation;
                _selectedServiceAreas = [worker.serviceLocation];
              }
              if (worker.membershipId != null && worker.membershipId!.isNotEmpty) {
                _membershipIdController.text = worker.membershipId!;
              }
              _isAvailable = worker.isAvailable;
              final fed = FederationModel.resolveFederation(
                federationId: worker.federationRefId,
                federationName: worker.guildName,
                district: worker.district ?? _selectedDistrict,
                city: worker.city ?? _selectedCityOrArea,
                location: worker.serviceLocation,
                address: worker.address,
              );
              _selectedFederationId = fed.id;
              _federationName = fed.name;
            });
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18),
      helpText: 'Select Date of Birth (Must be 18+)',
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickAndUploadDocument(String docType) async {
    setState(() => _uploadingDocTypes.add(docType));
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        setState(() {
          _uploadedFiles[docType] = file;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_getDocumentLabel(docType)} attached: ${file.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingDocTypes.remove(docType));
      }
    }
  }

  String _getDocumentLabel(String docType) {
    switch (docType) {
      case 'IDENTITY':
        return 'Identity Proof (Aadhaar / Voter ID / PAN)';
      case 'ADDRESS':
        return 'Address Proof (Electricity Bill / Rent Agreement)';
      case 'SKILL_CERTIFICATE':
        return 'Trade / Skill Certificate (ITI / License)';
      default:
        return 'Document';
    }
  }

  Future<void> _submitRegistration() async {
    if (_isLockedUnderReview) {
      setState(() => _errorMessage = 'Application is locked under Federation Review. Changes are not permitted without administrator approval.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!widget.isResubmission && !_uploadedFiles.containsKey('IDENTITY')) {
      setState(() => _errorMessage = 'Please attach your Identity Proof (Aadhaar / Voter ID / PAN).');
      return;
    }

    if (!widget.isResubmission && !_uploadedFiles.containsKey('ADDRESS')) {
      setState(() => _errorMessage = 'Please attach your Address Proof (Electricity Bill / Rent Agreement).');
      return;
    }

    if (_selectedTrade == null || _selectedTrade!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your Worker Category / Trade.');
      return;
    }

    if (_selectedSkill == null || _selectedSkill!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your specific Primary Sub-Skill (Field 12).');
      return;
    }

    if (_selectedSkillLevel == null || _selectedSkillLevel!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your Skill Level (Field 13).');
      return;
    }

    if (_selectedExperienceYears == null) {
      setState(() => _errorMessage = 'Please select your Years of Experience (Field 14).');
      return;
    }

    final hasAreaFederation = FederationModel.isAreaCoveredByFederation(
      district: _districtController.text.trim(),
      city: _cityController.text.trim(),
      state: _selectedState,
      pincode: _pinCodeController.text.trim(),
      location: _selectedArea,
      address: _addressController.text.trim(),
      federationsList: _availableFederations,
    );

    if (hasAreaFederation && (_selectedFederationId == null || _selectedFederationId!.isEmpty)) {
      final matching = FederationModel.findFederationForLocation(
        district: _districtController.text.trim(),
        city: _cityController.text.trim(),
        state: _selectedState,
        pincode: _pinCodeController.text.trim(),
        location: _selectedArea,
        address: _addressController.text.trim(),
        federationsList: _availableFederations,
      );
      if (matching != null) {
        _selectedFederationId = matching.id;
        _federationName = matching.name;
      }
    }

    if (!_agreedToCharter) {
      setState(() => _errorMessage = 'Please agree to the ShramSetu Federation Artisan Charter.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = await DI.authRepo.getCurrentUser();
      final cleanName = _nameController.text.trim();
      final phone = PhoneNumberUtil.cleanIndianPhone(_phoneController.text.trim());
      final effectivePhone = phone.isNotEmpty ? phone : _phoneController.text.trim();
      final userId = user?.id ?? 'worker_$effectivePhone';

      // Resolve authoritative federation using identical ID from Super Admin & dynamic list
      final targetFed = (_selectedFederationId != null && _selectedFederationId!.isNotEmpty)
          ? _availableFederations.firstWhere(
              (f) => f.id == _selectedFederationId,
              orElse: () => FederationModel.resolveFederation(
                federationId: _selectedFederationId,
                federationName: _federationName,
                district: _districtController.text.trim(),
                city: _cityController.text.trim(),
                location: _selectedArea,
                address: _addressController.text.trim(),
                federationsList: _availableFederations,
              ),
            )
          : (hasAreaFederation
              ? FederationModel.resolveFederation(
                  district: _districtController.text.trim(),
                  city: _cityController.text.trim(),
                  location: _selectedArea,
                  address: _addressController.text.trim(),
                  federationsList: _availableFederations,
                )
              : null);

      // 1. Register worker profile in users and workers tables with 20 fields
      await DI.workerRepo.registerWorker(
        workerId: userId,
        fullName: cleanName,
        phone: effectivePhone,
        email: _emailController.text.trim(),
        skill: _selectedSkill!,
        experienceYears: _selectedExperienceYears ?? 1,
        serviceLocation: _selectedServiceAreas.isNotEmpty ? _selectedServiceAreas.first : _selectedArea,
        serviceAreas: _selectedServiceAreas,
        dob: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        gender: _selectedGender,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        pinCode: _pinCodeController.text.trim(),
        trade: _selectedTrade!,
        skillLevel: _selectedSkillLevel ?? 'Beginner',
        federationName: targetFed?.name ?? 'Cooperative Expansion Zone (${_districtController.text.trim()})',
        federationId: targetFed?.id,
        membershipId: _membershipIdController.text.trim().isNotEmpty ? _membershipIdController.text.trim() : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : 'Certified $_selectedSkill artisan serving $_selectedArea with $_selectedExperienceYears years of experience.',
        declarationAccepted: _agreedToCharter,
      );

      // Update worker geographic coordinates if captured via GPS or Map Pin
      if (_latitude != null && _longitude != null) {
        try {
          await DI.workerRepo.updateWorkerLocation(
            userId,
            latitude: _latitude!,
            longitude: _longitude!,
            locationTag: _selectedArea,
          );
        } catch (locErr) {
          debugPrint('[WorkerRegistration] updateWorkerLocation note: $locErr');
        }
      }

      // 2. Upload attached documents
      for (final entry in _uploadedFiles.entries) {
        final docType = entry.key;
        final file = entry.value;
        final fileBytes = await file.readAsBytes();
        final ext = file.extension?.toLowerCase() ?? 'jpg';
        final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '$userId/$docType-$timestamp.$ext';

        try {
          await DI.storageRepo.uploadFile(
            bucket: StorageBucket.workerDocuments,
            path: storagePath,
            fileBytes: fileBytes,
            mimeType: mimeType,
          );
        } catch (_) {}

        await DI.workerRepo.submitVerificationDocument(
          userId,
          docType,
          storagePath,
          file.name,
          mimeType,
          fileBytes.length,
        );
      }

      // 3. Mark for verification (submit initial or resubmit)
      if (widget.isResubmission) {
        await DI.workerRepo.resubmitForVerification(userId);
      } else {
        await DI.workerRepo.submitForVerification(userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.onTertiaryContainer,
            content: Text(widget.isResubmission
                ? 'Application updated and resubmitted for Federation Review!'
                : (hasAreaFederation
                    ? 'Registration and documents submitted for Federation Verification!'
                    : 'Registration saved in Founding Artisan Expansion Waitlist!')),
          ),
        );

        if (hasAreaFederation) {
          // Replace route directly to Under Verification screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WorkerUnderVerificationScreen()),
          );
        } else {
          // Replace route to AreaNotServiceableScreen (Expansion Waitlist)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AreaNotServiceableScreen(
                userRole: 'WORKER',
                reason: ServiceUnavailableReason.noFederation,
                district: _districtController.text.trim(),
                area: _selectedCityOrArea,
                city: _cityController.text.trim(),
                state: _selectedState,
                pincode: _pinCodeController.text.trim().isNotEmpty ? _pinCodeController.text.trim() : null,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: AppSpacing.marginMobile,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/logo.jpg', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShramSetu Federation',
                  style: AppTypography.titleMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'Artisan Enrollment & Registration',
                  style: TextStyle(fontSize: 11, color: AppColors.outline),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: AppColors.outline, size: 20),
            onPressed: () async {
              await DI.authRepo.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/onboarding');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spacingMd,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBanner(),
                  const SizedBox(height: 16),
                  if (_isLockedUnderReview) _buildLockedUnderReviewBanner(),
                  if (widget.changeRequestReason != null && widget.changeRequestReason!.isNotEmpty)
                    _buildChangesRequiredBanner(),
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 16),
                  _buildAddressSection(),
                  const SizedBox(height: 16),
                  _buildTradeDetailsSection(),
                  const SizedBox(height: 16),
                  _buildCooperativeSection(),
                  const SizedBox(height: 16),
                  _buildDocumentUploadSection(),
                  const SizedBox(height: 16),
                  _buildCharterAgreementSection(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedUnderReviewBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFFE65100), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Application Submitted & Locked Under Review',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFE65100)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your registration details and documents are currently under administrative review by the Cooperative Federation. To preserve audit and compliance integrity, entries cannot be modified without administrator approval or a formal revision request.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const WorkerUnderVerificationScreen()),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View Verification Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangesRequiredBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9800), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFFE65100), size: 22),
              SizedBox(width: 8),
              Text(
                'Changes Requested by Federation Officer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.changeRequestReason!,
            style: const TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
          ),
          const SizedBox(height: 4),
          const Text(
            'Please update the indicated information or upload corrected documents below and resubmit.',
            style: TextStyle(fontSize: 11, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.badge, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isResubmission ? 'Update & Resubmit Application' : 'Artisan Cooperative Registration',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Complete your 20-point trade registration and submit verification documents. Access to receiving customer jobs is activated after federation review.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '1. Basic Information',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            enabled: !_isLockedUnderReview,
            decoration: InputDecoration(
              labelText: '1. Full Legal Name *',
              hintText: 'e.g. Rahul Ananda Patil',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your full name as printed on your ID.';
              }
              if (val.trim().length < 3) {
                return 'Name must be at least 3 characters long.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            enabled: !_isLockedUnderReview,
            keyboardType: TextInputType.phone,
            inputFormatters: [IndianPhoneNumberFormatter()],
            decoration: InputDecoration(
              labelText: '2. Registered Mobile Number *',
              hintText: 'e.g. 9876543210',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              suffixIcon: const Icon(Icons.check_circle, color: AppColors.onTertiaryContainer, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) => PhoneNumberUtil.validateIndianMobile(val),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            enabled: !_isLockedUnderReview,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '3. Official Email Address *',
              hintText: 'e.g. artisan@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              suffixIcon: const Icon(Icons.mark_email_read_outlined, color: AppColors.onTertiaryContainer, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Official email address is required.';
              }
              if (!RegExp(r'^[\w\.-]+@[\w-]+\.\w{2,}$').hasMatch(val.trim())) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  enabled: !_isLockedUnderReview,
                  onTap: _isLockedUnderReview ? null : _selectDob,
                  decoration: InputDecoration(
                    labelText: '4. Date of Birth *',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month, size: 20),
                      onPressed: _isLockedUnderReview ? null : _selectDob,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Select date of birth.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _genderOptions.contains(_selectedGender) ? _selectedGender : _genderOptions.first,
                  decoration: InputDecoration(
                    labelText: '5. Gender *',
                    prefixIcon: const Icon(Icons.wc, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: _isLockedUnderReview
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedGender = val);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '2. Current Address & Geographic Location',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose Auto-Detect to fill all entries via GPS, or Pin on Map to pick your exact ward manually.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),

          // Dual Mode Chooser: Auto GPS vs. Pin on Map
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Auto GPS Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _locationMethod == 'AUTO'
                              ? AppColors.primary
                              : AppColors.surfaceContainerLow,
                          foregroundColor: _locationMethod == 'AUTO'
                              ? Colors.white
                              : AppColors.primary,
                          elevation: _locationMethod == 'AUTO' ? 1 : 0,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(
                            color: _locationMethod == 'AUTO'
                                ? AppColors.primary
                                : AppColors.outlineVariant,
                          ),
                        ),
                        onPressed: (_isAutoFetchingLocation || _isLockedUnderReview)
                            ? null
                            : _autoFetchLiveLocation,
                        icon: _isAutoFetchingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(
                          _isAutoFetchingLocation ? 'Detecting...' : 'Auto-Detect (GPS)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Pin on Map Button
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _locationMethod == 'MAP'
                              ? AppColors.tertiaryContainer
                              : Colors.white,
                          foregroundColor: _locationMethod == 'MAP'
                              ? AppColors.onTertiaryContainer
                              : AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(
                            color: _locationMethod == 'MAP'
                                ? AppColors.onTertiaryContainer
                                : AppColors.outlineVariant,
                            width: _locationMethod == 'MAP' ? 1.5 : 1,
                          ),
                        ),
                        onPressed: _isLockedUnderReview ? null : _openMapLocationPicker,
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text(
                          'Pin on Map',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_locationStatusFeedback != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationStatusFeedback!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${_latitude!.toStringAsFixed(5)}° N, ${_longitude!.toStringAsFixed(5)}° E',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: _isLockedUnderReview ? null : _openMapLocationPicker,
                        icon: const Icon(Icons.edit_location_alt, size: 14),
                        label: const Text('Adjust Pin', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Current Residential / Workshop Address
          TextFormField(
            controller: _addressController,
            enabled: !_isLockedUnderReview,
            decoration: InputDecoration(
              labelText: '6. Current Residential / Workshop Address *',
              hintText: 'e.g. Flat 301, Shanti Niwas, Paud Road',
              prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter current residential address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // PIN Code with Live Auto-Detection & State Dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _pinCodeController,
                  enabled: !_isLockedUnderReview,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '7. PIN Code *',
                    hintText: '411038',
                    counterText: '',
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 20),
                    suffixIcon: _isResolvingPincode
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : (_pincodeFeedback != null
                            ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20)
                            : null),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  onChanged: _handlePincodeAutoDetect,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter PIN.';
                    if (val.trim().length != 6) return '6 digits.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // State Dropdown (All 36 States & UTs of India)
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: IndiaGeographyService.states.contains(_selectedState)
                      ? _selectedState
                      : IndiaGeographyService.states.first,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '8. State *',
                    prefixIcon: const Icon(Icons.public, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: IndiaGeographyService.states.map((st) {
                    return DropdownMenuItem(
                      value: st,
                      child: Text(st, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isLockedUnderReview
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedState = val;
                              _availableDistricts = IndiaGeographyService.getDistricts(val);
                              _selectedDistrict = _availableDistricts.isNotEmpty ? _availableDistricts.first : 'Pune';
                              _districtController.text = _selectedDistrict;
                              _availableAreas = IndiaGeographyService.getAreasForDistrict(val, _selectedDistrict);
                              _selectedCityOrArea = _availableAreas.isNotEmpty ? _availableAreas.first : _selectedDistrict;
                              _cityController.text = _selectedCityOrArea;
                            });
                            _autoRouteFederation(_selectedDistrict);
                          }
                        },
                ),
              ),
            ],
          ),

          if (_pincodeFeedback != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF2E7D32), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _pincodeFeedback!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // District & City/Area Dropdowns
          Row(
            children: [
              // District Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('dist_${_selectedState}_$_selectedDistrict'),
                  initialValue: _availableDistricts.contains(_selectedDistrict)
                      ? _selectedDistrict
                      : (_availableDistricts.isNotEmpty ? _availableDistricts.first : null),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '9. District *',
                    prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _availableDistricts.map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isLockedUnderReview
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedDistrict = val;
                              _districtController.text = val;
                              _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, val);
                              _selectedCityOrArea = _availableAreas.isNotEmpty ? _availableAreas.first : val;
                              _cityController.text = _selectedCityOrArea;
                              _syncServiceAreasToDistrict(val, _selectedCityOrArea);
                            });
                            _autoRouteFederation(_selectedArea);
                          }
                        },
                ),
              ),
              const SizedBox(width: 12),
              // City / Area Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('area_${_selectedDistrict}_$_selectedCityOrArea'),
                  initialValue: _availableAreas.contains(_selectedCityOrArea)
                      ? _selectedCityOrArea
                      : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '10. City / Ward / Area *',
                    prefixIcon: const Icon(Icons.map_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _availableAreas.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text(a, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isLockedUnderReview
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCityOrArea = val;
                              _cityController.text = val;
                              _syncServiceAreasToDistrict(_selectedDistrict, val);
                            });
                            _autoRouteFederation(_selectedArea);
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTradeDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '3. Work & Skill Information',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('trade_$_selectedTrade'),
            initialValue: _selectedTrade,
            isExpanded: true,
            hint: const Text('Select Worker Category / Trade *', style: TextStyle(fontSize: 13, color: AppColors.outline)),
            decoration: InputDecoration(
              labelText: '11. Worker Category / Trade *',
              prefixIcon: const Icon(Icons.category_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) => val == null || val.isEmpty ? 'Please select a worker category.' : null,
            items: _tradeCategories.map((trade) {
              return DropdownMenuItem(value: trade, child: Text(trade));
            }).toList(),
            onChanged: _isLockedUnderReview
                ? null
                : (val) {
                    if (val != null) {
                      setState(() {
                        _selectedTrade = val;
                        _selectedSkill = null; // Do NOT autofill skill! Worker must select specific sub-skill!
                      });
                    }
                  },
          ),
          const SizedBox(height: 14),
          () {
            final List<String> currentSubSkills = _selectedTrade != null ? (tradeSubSkills[_selectedTrade] ?? []) : [];
            final bool hasCategory = _selectedTrade != null && _selectedTrade!.isNotEmpty;

            return DropdownButtonFormField<String>(
              key: ValueKey('skill_${_selectedTrade}_$_selectedSkill'),
              initialValue: (currentSubSkills.contains(_selectedSkill)) ? _selectedSkill : null,
              isExpanded: true,
              hint: Text(
                !hasCategory
                    ? 'Select Worker Category first'
                    : 'Select Specific Sub-Skill *',
                style: const TextStyle(fontSize: 13, color: AppColors.outline),
              ),
              decoration: InputDecoration(
                labelText: '12. Primary Sub-Skill *',
                prefixIcon: const Icon(Icons.construction, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: !hasCategory ? const Color(0xFFF3F4F6) : AppColors.surfaceContainerLowest,
              ),
              validator: (val) {
                if (!hasCategory) return 'Please select a worker category first.';
                if (val == null || val.isEmpty) return 'Please select your specific sub-skill.';
                return null;
              },
              items: currentSubSkills.map((skill) {
                return DropdownMenuItem(
                  value: skill,
                  child: Text(skill, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (!hasCategory || _isLockedUnderReview)
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedSkill = val);
                    },
            );
          }(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('skill_lvl_$_selectedSkillLevel'),
                  initialValue: _skillLevels.contains(_selectedSkillLevel) ? _selectedSkillLevel : null,
                  isExpanded: true,
                  hint: const Text('Select Skill Level *', style: TextStyle(fontSize: 12, color: AppColors.outline), overflow: TextOverflow.ellipsis),
                  decoration: InputDecoration(
                    labelText: '13. Skill Level *',
                    prefixIcon: const Icon(Icons.grade_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Please select your skill level.' : null,
                  items: _skillLevels.map((lvl) {
                    return DropdownMenuItem(
                      value: lvl,
                      child: Text(_skillLevelLabels[lvl] ?? lvl, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isLockedUnderReview
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedSkillLevel = val);
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('exp_yrs_$_selectedExperienceYears'),
                  initialValue: _experienceOptions.contains(_selectedExperienceYears) ? _selectedExperienceYears : null,
                  isExpanded: true,
                  hint: const Text('Select Experience *', style: TextStyle(fontSize: 12, color: AppColors.outline), overflow: TextOverflow.ellipsis),
                  decoration: InputDecoration(
                    labelText: '14. Years of Experience *',
                    prefixIcon: const Icon(Icons.history_toggle_off, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (val) => val == null ? 'Please select experience.' : null,
                  items: _experienceOptions.map((yrs) {
                    return DropdownMenuItem(
                      value: yrs,
                      child: Text(yrs >= 10 ? '$yrs+ Years' : (yrs == 1 ? '1 Year' : '$yrs Years'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isLockedUnderReview
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedExperienceYears = val);
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 15. Service Areas / Preferred Working Localities (Max 3)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedServiceAreas.isEmpty ? AppColors.error : AppColors.outlineVariant,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '15. Service Areas (Max 3) *',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _selectedServiceAreas.length >= 3
                            ? const Color(0xFFE8F5E9)
                            : AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedServiceAreas.length >= 3
                              ? const Color(0xFF81C784)
                              : AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${_selectedServiceAreas.length} / 3 Selected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedServiceAreas.length >= 3
                              ? const Color(0xFF2E7D32)
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose up to 3 localities where you can reliably travel for jobs. Once verified, changing areas requires an Admin ticket.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),

                // Selected Areas Active Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedServiceAreas.map((area) {
                    final isPrimary = _selectedServiceAreas.indexOf(area) == 0;
                    return Chip(
                      avatar: Icon(
                        isPrimary ? Icons.stars : Icons.place,
                        size: 16,
                        color: isPrimary ? const Color(0xFF2E7D32) : AppColors.primary,
                      ),
                      label: Text(
                        '$area${isPrimary ? ' (Base)' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                          color: isPrimary ? const Color(0xFF1B5E20) : AppColors.onSurface,
                        ),
                      ),
                      backgroundColor: isPrimary ? const Color(0xFFE8F5E9) : Colors.white,
                      deleteIcon: _isLockedUnderReview
                          ? null
                          : const Icon(Icons.cancel, size: 16, color: AppColors.outline),
                      onDeleted: (_isLockedUnderReview || _selectedServiceAreas.length <= 1)
                          ? null
                          : () => _removeServiceArea(area),
                      side: BorderSide(
                        color: isPrimary ? const Color(0xFF81C784) : AppColors.outlineVariant,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Suggestions Section (7-10 km & Nearby)
                if (_selectedServiceAreas.length < 3) ...[
                  () {
                    final suggestions = _getAreaSuggestions();
                    if (suggestions.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.near_me, size: 15, color: Color(0xFF1565C0)),
                            SizedBox(width: 6),
                            Text(
                              'Suggested Nearby Areas (7–10 km & Close):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: suggestions.take(8).map((sug) {
                            return ActionChip(
                              avatar: Icon(
                                sug.is7to10Km ? Icons.radar : Icons.add_circle_outline,
                                size: 14,
                                color: sug.is7to10Km ? const Color(0xFFE65100) : AppColors.primary,
                              ),
                              label: Text(
                                '${sug.name} (~${sug.distanceKm.toStringAsFixed(1)} km${sug.is7to10Km ? ' • 7-10 km' : ''})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sug.is7to10Km ? FontWeight.bold : FontWeight.normal,
                                  color: sug.is7to10Km ? const Color(0xFFBF360C) : AppColors.primary,
                                ),
                              ),
                              backgroundColor: sug.is7to10Km ? const Color(0xFFFFF3E0) : const Color(0xFFF0F4F8),
                              side: BorderSide(
                                color: sug.is7to10Km ? const Color(0xFFFFB74D) : AppColors.outlineVariant,
                              ),
                              onPressed: _isLockedUnderReview ? null : () => _addServiceArea(sug.name),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }(),

                  // Manual Dropdown Selector for ANY area in District
                  DropdownButtonFormField<String>(
                    key: ValueKey('manual_add_area_${_selectedDistrict}_${_selectedServiceAreas.length}'),
                    isExpanded: true,
                    hint: Text('Add another locality in $_selectedDistrict (up to 3)...', style: const TextStyle(fontSize: 12)),
                    decoration: InputDecoration(
                      labelText: 'Manually Choose Area from $_selectedDistrict',
                      prefixIcon: const Icon(Icons.add_location_alt_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: () {
                      final districtAreas = <String>{};
                      for (final a in _availableAreas) {
                        final formatted = a.contains(_selectedDistrict) ? a : '$a, $_selectedDistrict';
                        districtAreas.add(formatted);
                      }
                      for (final a in _serviceAreasList) {
                        if (a.toLowerCase().contains(_selectedDistrict.toLowerCase())) {
                          districtAreas.add(a);
                        }
                      }
                      return districtAreas
                          .where((a) => !_selectedServiceAreas.contains(a))
                          .map((area) {
                        return DropdownMenuItem(
                          value: area,
                          child: Text(area, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        );
                      }).toList();
                    }(),
                    onChanged: _isLockedUnderReview
                        ? null
                        : (val) {
                            if (val != null) {
                              _addServiceArea(val);
                            }
                          },
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Maximum 3 service areas selected. Tap "✕" on any chip above to change.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '16. Availability to Receive Jobs',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              subtitle: Text(
                _isAvailable ? 'Currently Available (accepting jobs once verified)' : 'Busy / Not accepting new jobs right now',
                style: const TextStyle(fontSize: 12, color: AppColors.outline),
              ),
              value: _isAvailable,
              activeThumbColor: AppColors.primary,
              onChanged: _isLockedUnderReview ? null : (val) => setState(() => _isAvailable = val),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bioController,
            enabled: !_isLockedUnderReview,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '17. Brief Profile Bio (Optional)',
              hintText: 'e.g. Licensed residential plumbing, pipe leak detection, pump servicing.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCooperativeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diversity_3_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '4. Cooperative / Federation Info',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('fed_select_$_selectedFederationId'),
            initialValue: _selectedFederationId,
            isExpanded: true,
            hint: const Text('Select your Cooperative Federation', style: TextStyle(fontSize: 13, color: AppColors.outline)),
            decoration: InputDecoration(
              labelText: '18. Registered Federation / Cooperative *',
              prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              final isCovered = FederationModel.isAreaCoveredByFederation(
                district: _districtController.text.trim(),
                city: _cityController.text.trim(),
                state: _selectedState,
                pincode: _pinCodeController.text.trim(),
                location: _selectedArea,
                federationsList: _availableFederations,
              );
              if (isCovered && (val == null || val.isEmpty)) {
                return 'Select a cooperative federation.';
              }
              return null;
            },
            items: [
              ..._availableFederations.map((fed) {
                return DropdownMenuItem<String>(
                  value: fed.id,
                  child: Text(
                    '${fed.name} (${fed.city.isNotEmpty ? fed.city : fed.district})',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: _isLockedUnderReview
                ? null
                : (val) {
                    if (val != null) {
                      final fed = _availableFederations.firstWhere(
                        (f) => f.id == val,
                        orElse: () => FederationModel.defaultFederations.first,
                      );
                      setState(() {
                        _userSelectedFederationManually = true;
                        _selectedFederationId = val;
                        _federationName = fed.name;
                        _selectedDistrict = fed.district;
                        _districtController.text = fed.district;
                        _selectedCityOrArea = fed.city;
                        _cityController.text = fed.city;
                      });
                    }
                  },
          ),
          if (_selectedFederationId == null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB300)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No Federation in $_selectedDistrict yet. Your application will be registered in the State Founding Artisan Waitlist and verified upon district expansion.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF795548), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _membershipIdController,
            enabled: !_isLockedUnderReview,
            decoration: InputDecoration(
              labelText: '19. Cooperative Membership ID (Optional)',
              hintText: 'e.g. FED-PUN-2024-9128',
              prefixIcon: const Icon(Icons.card_membership_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.file_copy_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '5. Verification Documents',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Documents are reviewed by the Federation Cooperative Administrator. Accepted formats: PDF, JPG, PNG (Max 10MB).',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildUploadTile(
            docType: 'IDENTITY',
            title: '20. Identity Proof *',
            subtitle: 'Aadhaar Card, Voter ID, or PAN Card',
            icon: Icons.badge_outlined,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildUploadTile(
            docType: 'ADDRESS',
            title: '21. Address Proof *',
            subtitle: 'Electricity Bill, Ration Card, or Rent Agreement',
            icon: Icons.home_outlined,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildUploadTile(
            docType: 'SKILL_CERTIFICATE',
            title: '22. Trade / Skill Certificate',
            subtitle: 'ITI Certificate, Trade Union ID, or Apprentice Certificate (Optional)',
            icon: Icons.school_outlined,
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTile({
    required String docType,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRequired,
  }) {
    final file = _uploadedFiles[docType];
    final isAttached = file != null;
    final isUploading = _uploadingDocTypes.contains(docType);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAttached ? const Color(0xFFF1F8E9) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAttached ? AppColors.onTertiaryContainer : AppColors.outlineVariant,
          width: isAttached ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAttached ? AppColors.tertiaryContainer : AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAttached ? Icons.check : icon,
              color: isAttached ? AppColors.onTertiaryContainer : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
                Text(
                  isAttached
                      ? '${file.name} • Attached'
                      : subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAttached ? AppColors.onTertiaryContainer : AppColors.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                side: BorderSide(
                  color: isAttached ? AppColors.onTertiaryContainer : AppColors.outlineVariant,
                ),
              ),
              onPressed: _isLockedUnderReview ? null : () => _pickAndUploadDocument(docType),
              icon: Icon(
                isAttached ? Icons.change_circle_outlined : Icons.upload_file,
                size: 16,
                color: isAttached ? AppColors.onTertiaryContainer : AppColors.primary,
              ),
              label: Text(
                isAttached ? 'Change' : 'Upload',
                style: TextStyle(
                  fontSize: 12,
                  color: isAttached ? AppColors.onTertiaryContainer : AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharterAgreementSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreedToCharter,
            activeColor: AppColors.primary,
            onChanged: _isLockedUnderReview ? null : (val) => setState(() => _agreedToCharter = val ?? false),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '23. I declare that the trade information, residential address, and uploaded proof documents are genuine. I agree to operate under the ShramSetu Federation Artisan Charter and understand that access is granted following admin verification.',
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool isLocked = _isLockedUnderReview;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLocked ? AppColors.surfaceContainerHigh : AppColors.primary,
          foregroundColor: isLocked ? AppColors.outline : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: isLocked ? 0 : 2,
        ),
        onPressed: (_isSubmitting || isLocked) ? null : _submitRegistration,
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Submitting for Federation Review...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : isLocked
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Application Locked Under Review (Awaiting Admin Approval)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Text(
                    widget.isResubmission
                        ? 'Resubmit Application for Federation Review'
                        : 'Submit Registration for Admin Verification',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
      ),
    );
  }
}
