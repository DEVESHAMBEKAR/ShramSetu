import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Multi-federation data models for ShramSetu.
/// Supports state, district, city, and cooperative union partitioning.
class FederationModel {
  final String id;
  final String name;
  final String state;
  final String district;
  final String city;
  final String? registrationNo;
  final String? contactPhone;
  final String? contactEmail;
  final String? federationCode;
  final bool isActive;

  const FederationModel({
    required this.id,
    required this.name,
    required this.state,
    required this.district,
    required this.city,
    this.registrationNo,
    this.contactPhone,
    this.contactEmail,
    this.federationCode,
    this.isActive = true,
  });

  factory FederationModel.fromJson(Map<String, dynamic> json) {
    return FederationModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Labour Cooperative Federation',
      state: json['state'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      registrationNo: json['registration_no'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      federationCode: json['federation_code'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'state': state,
    'district': district,
    'city': city,
    if (registrationNo != null) 'registration_no': registrationNo,
    if (contactPhone != null) 'contact_phone': contactPhone,
    if (contactEmail != null) 'contact_email': contactEmail,
    if (federationCode != null) 'federation_code': federationCode,
    'is_active': isActive,
  };

  /// Initial default federations available in the cooperative network.
  static const List<FederationModel> defaultFederations = [
    FederationModel(
      id: '11111111-0000-0000-0000-000000000001',
      name: 'Pune District Labour Cooperative Federation',
      state: 'Maharashtra',
      district: 'Pune',
      city: 'Pune',
      registrationNo: 'MH-PUN-COOP-2018-88',
      contactPhone: '+91 20 2553 4401',
    ),
    FederationModel(
      id: '22222222-0000-0000-0000-000000000002',
      name: 'Nashik District Artisans Cooperative Union',
      state: 'Maharashtra',
      district: 'Nashik',
      city: 'Nashik',
      registrationNo: 'MH-NSK-COOP-2020-14',
      contactPhone: '+91 253 257 8820',
    ),
    FederationModel(
      id: '33333333-0000-0000-0000-000000000003',
      name: 'Mumbai Metropolitan Labour Federation',
      state: 'Maharashtra',
      district: 'Mumbai City',
      city: 'Mumbai',
      registrationNo: 'MH-MUM-COOP-2016-09',
      contactPhone: '+91 22 2261 1140',
    ),
    FederationModel(
      id: '44444444-0000-0000-0000-000000000004',
      name: 'Chhatrapati Sambhajinagar Labour Federation',
      state: 'Maharashtra',
      district: 'Chhatrapati Sambhajinagar',
      city: 'Chhatrapati Sambhajinagar',
      registrationNo: 'MH-CSN-COOP-2021-32',
      contactPhone: '+91 240 233 4560',
    ),
    FederationModel(
      id: '55555555-0000-0000-0000-000000000005',
      name: 'Nagpur District Shramik Cooperative Union',
      state: 'Maharashtra',
      district: 'Nagpur',
      city: 'Nagpur',
      registrationNo: 'MH-NGP-COOP-2019-55',
      contactPhone: '+91 712 256 7890',
    ),
  ];

  static List<FederationModel> _cachedPool = [];

  /// Formats an index into the standard canonical Federation UUID format:
  /// e.g. 1 -> 11111111-0000-0000-0000-000000000001
  ///      6 -> 66666666-0000-0000-0000-000000000006
  ///      7 -> 77777777-0000-0000-0000-000000000007
  static String formatFederationId(int index) {
    final hexChar = (index >= 1 && index <= 15) ? index.toRadixString(16) : null;
    final prefix = hexChar != null ? (hexChar * 8) : index.toRadixString(16).padLeft(8, '0');
    final suffix = index.toString().padLeft(12, '0');
    return '$prefix-0000-0000-0000-$suffix';
  }

  /// Generates the next sequential federation UUID following the canonical format.
  /// Inspects existing federations to find the next unused sequential index.
  static String generateNextFederationId([List<FederationModel>? existingFederations]) {
    final list = existingFederations ?? activePool;
    final Set<int> usedIndices = {};
    final pattern = RegExp(r'^[0-9a-fA-F]{8}-0000-0000-0000-(\d{12})$');
    for (final fed in list) {
      final match = pattern.firstMatch(fed.id);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null) {
          usedIndices.add(parsed);
        }
      } else if (fed.name.toLowerCase().contains('hyderabad')) {
        usedIndices.add(6);
      }
    }

    int nextIndex = 1;
    while (usedIndices.contains(nextIndex)) {
      nextIndex++;
    }
    if (nextIndex <= list.length && list.isNotEmpty) {
      nextIndex = list.length + 1;
      while (usedIndices.contains(nextIndex)) {
        nextIndex++;
      }
    }
    return formatFederationId(nextIndex);
  }

  /// Returns cached dynamic pool or defaults if not yet loaded.
  static List<FederationModel> get activePool =>
      _cachedPool.isNotEmpty ? _cachedPool : defaultFederations;

  static void invalidateCache() {
    _cachedPool.clear();
  }

  /// Fetches all federations from database merged with defaults.
  static Future<List<FederationModel>> fetchAllFederations({bool forceRefresh = true}) async {
    if (!forceRefresh && _cachedPool.isNotEmpty) {
      return _cachedPool;
    }
    try {
      final res = await Supabase.instance.client
          .from('federations')
          .select()
          .order('name');
      if (res.isNotEmpty) {
        final dbFeds = (res as List).map((r) => FederationModel.fromJson(r)).toList();
        final Map<String, FederationModel> mapById = {};
        final Map<String, FederationModel> mapByName = {};
        for (final f in defaultFederations) {
          mapById[f.id] = f;
          mapByName[f.name.toLowerCase().trim()] = f;
        }
        for (final f in dbFeds) {
          final normName = f.name.toLowerCase().trim();
          if (mapByName.containsKey(normName)) {
            final old = mapByName[normName]!;
            mapById.remove(old.id);
          }
          mapById[f.id] = f;
          mapByName[normName] = f;
        }
        _cachedPool = mapById.values.toList()..sort((a, b) => a.name.compareTo(b.name));
        return _cachedPool;
      }
    } catch (e) {
      debugPrint('[FederationModel] fetchAllFederations note: $e');
    }
    if (_cachedPool.isEmpty) {
      _cachedPool = List.from(defaultFederations);
    }
    return _cachedPool;
  }

  /// Checks if a cooperative federation exists for a given location, district, city, or pincode.
  /// Returns null if the area is currently outside all active cooperative federation zones.
  static FederationModel? findFederationForLocation({
    String? federationId,
    String? federationName,
    String? district,
    String? city,
    String? state,
    String? location,
    String? address,
    String? pincode,
    List<FederationModel>? federationsList,
  }) {
    final pool = (federationsList != null && federationsList.isNotEmpty)
        ? federationsList
        : (_cachedPool.isNotEmpty ? _cachedPool : defaultFederations);

    // 1. Direct match by ID
    if (federationId != null && federationId.trim().isNotEmpty) {
      final cleanId = federationId.trim().toLowerCase();
      for (final f in pool) {
        if (f.id.trim().toLowerCase() == cleanId) return f;
      }
      for (final f in defaultFederations) {
        if (f.id.trim().toLowerCase() == cleanId) return f;
      }
    }

    // 2. Direct match by Name
    if (federationName != null &&
        federationName.trim().isNotEmpty &&
        federationName.trim().toLowerCase() != 'cooperative federation' &&
        federationName.trim().toLowerCase() != 'labour cooperative federation') {
      final query = federationName.toLowerCase().trim();
      for (final f in pool) {
        if (f.name.toLowerCase().trim() == query) return f;
        if (f.name.toLowerCase().trim().contains(query) || query.contains(f.name.toLowerCase().trim())) return f;
      }
    }

    // 2b. Priority Locality Check: overrides default dropdown values (e.g. when district was defaulted to Pune)
    final locText = '${location ?? ''} ${address ?? ''}'.toLowerCase().trim();
    if (locText.isNotEmpty) {
      if (locText.contains('nagpur') || locText.contains('sitabuldi') || locText.contains('dharampeth') || locText.contains('sadar')) {
        return pool.firstWhere((f) => f.id == '55555555-0000-0000-0000-000000000005', orElse: () => defaultFederations[4]);
      }
      if (locText.contains('nashik') || locText.contains('satpur') || locText.contains('panchavati') || locText.contains('college road')) {
        return pool.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002', orElse: () => defaultFederations[1]);
      }
      if (locText.contains('mumbai') || locText.contains('thane') || locText.contains('navi mumbai') || locText.contains('andheri') || locText.contains('bandra') || locText.contains('dadar') || locText.contains('vashi') || locText.contains('mmr')) {
        return pool.firstWhere((f) => f.id == '33333333-0000-0000-0000-000000000003', orElse: () => defaultFederations[2]);
      }
      if (locText.contains('sambhajinagar') || locText.contains('aurangabad') || locText.contains('waluj') || locText.contains('cidco')) {
        return pool.firstWhere((f) => f.id == '44444444-0000-0000-0000-000000000004', orElse: () => defaultFederations[3]);
      }
      if (locText.contains('hyderabad') || locText.contains('secunderabad')) {
        for (final f in pool) {
          if (f.id == '66666666-0000-0000-0000-000000000006' || f.name.toLowerCase().contains('hyderabad')) {
            return f;
          }
        }
      }
    }

    // 3. Exact District or City match (authoritative over street keywords)
    final cleanDist = (district ?? '').trim().toLowerCase();
    final cleanCity = (city ?? '').trim().toLowerCase();
    if (cleanDist.length >= 3 || cleanCity.length >= 3) {
      for (final f in pool) {
        final fDist = f.district.toLowerCase().trim();
        final fCity = f.city.toLowerCase().trim();
        if (cleanDist.isNotEmpty && (cleanDist == fDist || cleanDist == fCity)) {
          return f;
        }
        if (cleanCity.isNotEmpty && (cleanCity == fCity || cleanCity == fDist)) {
          return f;
        }
      }
      for (final f in pool) {
        final fDist = f.district.toLowerCase().trim();
        final fCity = f.city.toLowerCase().trim();
        if (cleanDist.isNotEmpty && (fDist.contains(cleanDist) || cleanDist.contains(fDist))) {
          return f;
        }
        if (cleanCity.isNotEmpty && (fCity.contains(cleanCity) || cleanCity.contains(fCity))) {
          return f;
        }
      }
    }

    // 4. Pincode prefix check (authoritative postal routing)
    final cleanPin = (pincode ?? '').replaceAll(RegExp(r'\D'), '').trim();
    if (cleanPin.length == 6) {
      final p3 = int.tryParse(cleanPin.substring(0, 3)) ?? 0;
      if (p3 >= 411 && p3 <= 412) {
        return pool.firstWhere(
          (f) => f.id == '11111111-0000-0000-0000-000000000001',
          orElse: () => defaultFederations.first,
        );
      } else if (p3 >= 400 && p3 <= 401) {
        return pool.firstWhere(
          (f) => f.id == '33333333-0000-0000-0000-000000000003',
          orElse: () => defaultFederations[2],
        );
      } else if (p3 == 422 || p3 == 423) {
        return pool.firstWhere(
          (f) => f.id == '22222222-0000-0000-0000-000000000002',
          orElse: () => defaultFederations[1],
        );
      } else if (p3 == 431) {
        return pool.firstWhere(
          (f) => f.id == '44444444-0000-0000-0000-000000000004',
          orElse: () => defaultFederations[3],
        );
      } else if (p3 == 440 || p3 == 441) {
        return pool.firstWhere(
          (f) => f.id == '55555555-0000-0000-0000-000000000005',
          orElse: () => defaultFederations[4],
        );
      } else if (p3 >= 500 && p3 <= 501) {
        for (final f in pool) {
          if (f.id == '66666666-0000-0000-0000-000000000006' || f.name.toLowerCase().contains('hyderabad')) {
            return f;
          }
        }
      }

      // If a 6-digit pincode was given and does not match any active federation's prefix above:
      // It is outside all active cooperative unions! Return null so it does NOT falsely assign to Pune!
      return null;
    }

    // If an explicit district is provided and did not match any federation, do NOT fall through to street address keywords!
    if (cleanDist.isNotEmpty &&
        cleanDist != 'pune' &&
        cleanDist != 'mumbai' &&
        cleanDist != 'mumbai city' &&
        cleanDist != 'mumbai suburban' &&
        cleanDist != 'nashik' &&
        cleanDist != 'nagpur' &&
        cleanDist != 'chhatrapati sambhajinagar' &&
        cleanDist != 'aurangabad') {
      return null;
    }

    // 5. Locality matching (only if district was not a known unserviced district)
    if (locText.isNotEmpty) {
      if (locText.contains('hyderabad') || locText.contains('secunderabad')) {
        for (final f in pool) {
          if (f.id == '66666666-0000-0000-0000-000000000006' || f.name.toLowerCase().contains('hyderabad')) {
            return f;
          }
        }
      }
      if (locText.contains('nagpur') || locText.contains('sitabuldi') || locText.contains('dharampeth') || locText.contains('sadar')) {
        return pool.firstWhere((f) => f.id == '55555555-0000-0000-0000-000000000005', orElse: () => defaultFederations[4]);
      }
      if (locText.contains('nashik') || locText.contains('satpur') || locText.contains('panchavati') || locText.contains('college road')) {
        return pool.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002', orElse: () => defaultFederations[1]);
      }
      if (locText.contains('mumbai') || locText.contains('thane') || locText.contains('navi mumbai') || locText.contains('andheri') || locText.contains('bandra') || locText.contains('dadar') || locText.contains('vashi') || locText.contains('mmr')) {
        return pool.firstWhere((f) => f.id == '33333333-0000-0000-0000-000000000003', orElse: () => defaultFederations[2]);
      }
      if (locText.contains('sambhajinagar') || locText.contains('aurangabad') || locText.contains('waluj') || locText.contains('cidco')) {
        return pool.firstWhere((f) => f.id == '44444444-0000-0000-0000-000000000004', orElse: () => defaultFederations[3]);
      }
      if (locText.contains('pune') || locText.contains('kothrud') || locText.contains('hadapsar') || locText.contains('hinjewadi') || locText.contains('baner') || locText.contains('wakad') || locText.contains('pimpr') || locText.contains('narhe') || locText.contains('vadgaon') || locText.contains('deccan') || locText.contains('shivajinagar')) {
        return pool.firstWhere((f) => f.id == '11111111-0000-0000-0000-000000000001', orElse: () => defaultFederations.first);
      }
      for (final f in pool) {
        final fDist = f.district.toLowerCase().trim();
        final fCity = f.city.toLowerCase().trim();
        if (fDist.length >= 3 && locText.contains(fDist)) return f;
        if (fCity.length >= 3 && locText.contains(fCity)) return f;
      }
    }

    // No active cooperative union found for this area
    return null;
  }

  /// Convenience boolean check: returns true if area/pincode has an active federation.
  static bool isAreaCoveredByFederation({
    String? district,
    String? city,
    String? state,
    String? location,
    String? address,
    String? pincode,
    List<FederationModel>? federationsList,
  }) {
    return findFederationForLocation(
      district: district,
      city: city,
      state: state,
      location: location,
      address: address,
      pincode: pincode,
      federationsList: federationsList,
    ) != null;
  }

  /// Intelligently resolves a FederationModel based on federationId, federationName, district, city, serviceLocation, or address.
  /// Guarantees that any worker in the network is routed to their legitimate district cooperative union.
  static FederationModel resolveFederation({
    String? federationId,
    String? federationName,
    String? district,
    String? city,
    String? state,
    String? location,
    String? address,
    String? pincode,
    List<FederationModel>? federationsList,
  }) {
    final matched = findFederationForLocation(
      federationId: federationId,
      federationName: federationName,
      district: district,
      city: city,
      state: state,
      location: location,
      address: address,
      pincode: pincode,
      federationsList: federationsList,
    );
    if (matched != null) return matched;

    final pool = (federationsList != null && federationsList.isNotEmpty)
        ? federationsList
        : (_cachedPool.isNotEmpty ? _cachedPool : defaultFederations);

    // 1. Direct match by ID
    if (federationId != null && federationId.trim().isNotEmpty) {
      final cleanId = federationId.trim().toLowerCase();
      for (final f in pool) {
        if (f.id.trim().toLowerCase() == cleanId) return f;
      }
      for (final f in defaultFederations) {
        if (f.id.trim().toLowerCase() == cleanId) return f;
      }
    }

    // 2. Direct match by Exact/Partial Name
    if (federationName != null &&
        federationName.trim().isNotEmpty &&
        federationName.trim().toLowerCase() != 'cooperative federation' &&
        federationName.trim().toLowerCase() != 'labour cooperative federation') {
      final query = federationName.toLowerCase().trim();
      // 2a. Exact name match
      for (final f in pool) {
        if (f.name.toLowerCase().trim() == query) return f;
      }
      for (final f in defaultFederations) {
        if (f.name.toLowerCase().trim() == query) return f;
      }
      // 2b. District or city match inside federationName
      for (final f in pool) {
        if ((f.district.trim().length >= 3 && query.contains(f.district.toLowerCase().trim())) ||
            (f.city.trim().length >= 3 && query.contains(f.city.toLowerCase().trim()))) {
          return f;
        }
      }
      for (final f in pool) {
        final fNameLower = f.name.toLowerCase().trim();
        if (fNameLower.contains(query) || query.contains(fNameLower)) {
          return f;
        }
      }
    }

    // 3. Priority: Location / locality keyword matching first (more specific than default district field)
    final locText = (location ?? '').toLowerCase().trim();
    if (locText.isNotEmpty) {
      for (final f in pool) {
        if ((f.district.trim().length >= 3 && locText.contains(f.district.toLowerCase().trim())) ||
            (f.city.trim().length >= 3 && locText.contains(f.city.toLowerCase().trim()))) {
          return f;
        }
      }
      if (locText.contains('hyderabad') || locText.contains('hyd') || locText.contains('secunderabad') || locText.contains('gandhi bhawan')) {
        for (final f in pool) {
          if (f.id == '66666666-0000-0000-0000-000000000006' || f.name.toLowerCase().contains('hyderabad')) {
            return f;
          }
        }
      }
      if (locText.contains('nagpur') || locText.contains('ngp') || locText.contains('sitabuldi') || locText.contains('dharampeth') || locText.contains('sadar')) {
        return pool.firstWhere((f) => f.id == '55555555-0000-0000-0000-000000000005', orElse: () => defaultFederations.firstWhere((f) => f.id == '55555555-0000-0000-0000-000000000005'));
      }
      if (locText.contains('nashik') || locText.contains('nsk') || locText.contains('satpur') || locText.contains('panchavati') || locText.contains('college road')) {
        return pool.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002', orElse: () => defaultFederations.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002'));
      }
      if (locText.contains('mumbai') || locText.contains('thane') || locText.contains('navi mumbai') || locText.contains('andheri') || locText.contains('bandra') || locText.contains('dadar') || locText.contains('mmr') || locText.contains('vashi')) {
        return pool.firstWhere((f) => f.id == '33333333-0000-0000-0000-000000000003', orElse: () => defaultFederations.firstWhere((f) => f.id == '33333333-0000-0000-0000-000000000003'));
      }
      if (locText.contains('sambhajinagar') || locText.contains('aurangabad') || locText.contains('csn') || locText.contains('waluj') || locText.contains('cidco')) {
        return pool.firstWhere((f) => f.id == '44444444-0000-0000-0000-000000000004', orElse: () => defaultFederations.firstWhere((f) => f.id == '44444444-0000-0000-0000-000000000004'));
      }
      if (locText.contains('pune') || locText.contains('pun') || locText.contains('kothrud') || locText.contains('hadapsar') || locText.contains('hinjewadi') || locText.contains('baner') || locText.contains('wakad') || locText.contains('pimpr')) {
        return pool.firstWhere((f) => f.id == '11111111-0000-0000-0000-000000000001', orElse: () => defaultFederations.firstWhere((f) => f.id == '11111111-0000-0000-0000-000000000001'));
      }
    }

    // 4. Direct match by explicitly passed district or city
    final cleanDist = (district ?? '').trim().toLowerCase();
    final cleanCity = (city ?? '').trim().toLowerCase();
    if (cleanDist.length >= 3 || cleanCity.length >= 3) {
      for (final f in pool) {
        if (cleanDist.length >= 3 &&
            (f.district.toLowerCase().trim() == cleanDist || f.city.toLowerCase().trim() == cleanDist)) {
          return f;
        }
        if (cleanCity.length >= 3 &&
            (f.city.toLowerCase().trim() == cleanCity || f.district.toLowerCase().trim() == cleanCity)) {
          return f;
        }
      }
      for (final f in pool) {
        if (cleanDist.length >= 3 &&
            (cleanDist.contains(f.district.toLowerCase().trim()) || f.district.toLowerCase().trim().contains(cleanDist))) {
          return f;
        }
        if (cleanCity.length >= 3 &&
            (cleanCity.contains(f.city.toLowerCase().trim()) || f.city.toLowerCase().trim().contains(cleanCity))) {
          return f;
        }
      }
    }

    // 5. Match from geographic keywords across address
    final addrText = (address ?? '').toLowerCase().trim();
    if (addrText.isNotEmpty) {
      for (final f in pool) {
        if ((f.district.trim().length >= 3 && addrText.contains(f.district.toLowerCase().trim())) ||
            (f.city.trim().length >= 3 && addrText.contains(f.city.toLowerCase().trim()))) {
          return f;
        }
      }
      if (addrText.contains('hyderabad') || addrText.contains('hyd') || addrText.contains('secunderabad') || addrText.contains('gandhi bhawan')) {
        for (final f in pool) {
          if (f.id == '66666666-0000-0000-0000-000000000006' || f.name.toLowerCase().contains('hyderabad')) {
            return f;
          }
        }
      }
      if (addrText.contains('nagpur') || addrText.contains('ngp') || addrText.contains('sitabuldi') || addrText.contains('dharampeth')) {
        return pool.firstWhere((f) => f.id == '55555555-0000-0000-0000-000000000005', orElse: () => defaultFederations.firstWhere((f) => f.id == '55555555-0000-0000-0000-000000000005'));
      }
      if (addrText.contains('nashik') || addrText.contains('nsk') || addrText.contains('satpur') || addrText.contains('panchavati')) {
        return pool.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002', orElse: () => defaultFederations.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002'));
      }
      if (addrText.contains('mumbai') || addrText.contains('thane') || addrText.contains('navi mumbai') || addrText.contains('andheri') || addrText.contains('bandra') || addrText.contains('dadar') || addrText.contains('mmr')) {
        return pool.firstWhere((f) => f.id == '33333333-0000-0000-0000-000000000003', orElse: () => defaultFederations.firstWhere((f) => f.id == '33333333-0000-0000-0000-000000000003'));
      }
      if (addrText.contains('sambhajinagar') || addrText.contains('aurangabad') || addrText.contains('csn') || addrText.contains('waluj')) {
        return pool.firstWhere((f) => f.id == '44444444-0000-0000-0000-000000000004', orElse: () => defaultFederations.firstWhere((f) => f.id == '44444444-0000-0000-0000-000000000004'));
      }
      if (addrText.contains('pune') || addrText.contains('pun') || addrText.contains('kothrud') || addrText.contains('hadapsar') || addrText.contains('hinjewadi') || addrText.contains('baner') || addrText.contains('wakad') || addrText.contains('pimpr')) {
        return pool.firstWhere((f) => f.id == '11111111-0000-0000-0000-000000000001', orElse: () => defaultFederations.firstWhere((f) => f.id == '11111111-0000-0000-0000-000000000001'));
      }
    }

    // 6. Safe baseline default: Pune District Federation (never random pool.first)
    return pool.firstWhere(
      (f) => f.id == '11111111-0000-0000-0000-000000000001',
      orElse: () => defaultFederations.first,
    );
  }
}
