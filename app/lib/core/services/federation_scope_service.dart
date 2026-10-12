import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/federation_models.dart';

/// FederationScopeService determines which federation(s) the current admin
/// is authorized to manage.
/// ONLY SUPER_ADMIN (e.g. deveshambekar@gmail.com) has global national scope
/// and access to cross-federation sorting.
/// FEDERATION_ADMIN is strictly locked to their assigned federation and
/// CANNOT view worker applications from other federations.
class FederationScopeService {
  final SupabaseClient? _client;

  FederationScopeService([this._client]);

  final Map<String, String> _cachedRoleByUserId = {};
  final Map<String, List<String>> _cachedFederationIdsByUserId = {};


  /// Returns current authenticated user's email if available.
  String? _getCurrentEmail() {
    final clientUser = _client?.auth.currentUser;
    if (clientUser?.email != null && clientUser!.email!.isNotEmpty) {
      return clientUser.email!.trim().toLowerCase();
    }
    return null;
  }

  /// Returns the effective admin role of the current user.
  /// ONLY explicitly confirmed SUPER_ADMIN receives 'SUPER_ADMIN'.
  /// All other admins are strictly 'FEDERATION_ADMIN'.
  Future<String> getAdminRole() async {
    final email = _getCurrentEmail();
    if (email == 'deveshambekar@gmail.com') {
      return 'SUPER_ADMIN';
    }
    if (email == 'ambekardevesh2@gmail.com' || email == 'omshinde@gmail.com') {
      return 'FEDERATION_ADMIN';
    }

    final userId = _client?.auth.currentUser?.id;
    if (userId != null && _cachedRoleByUserId.containsKey(userId)) {
      return _cachedRoleByUserId[userId]!;
    }

    final client = _client;
    if (userId != null && client != null) {
      try {
        final res = await client
            .from('users')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
        final dbRole = (res?['role'] as String?)?.toUpperCase();
        if (dbRole == 'SUPER_ADMIN') {
          _cachedRoleByUserId[userId] = 'SUPER_ADMIN';
          return 'SUPER_ADMIN';
        }
      } catch (e) {
        debugPrint('[FederationScope] Error getting role: $e');
      }
    }

    if (userId != null) {
      _cachedRoleByUserId[userId] = 'FEDERATION_ADMIN';
    }
    return 'FEDERATION_ADMIN';
  }

  /// Returns true ONLY if the current user has unrestricted (global) scope.
  /// ONLY SUPER_ADMIN has global scope.
  /// Federation admins ALWAYS return false.
  Future<bool> hasGlobalScope() async {
    final email = _getCurrentEmail();
    if (email == 'deveshambekar@gmail.com') return true;
    if (email == 'ambekardevesh2@gmail.com' || email == 'omshinde@gmail.com') return false;

    final role = await getAdminRole();
    if (role != 'SUPER_ADMIN') return false;

    final ids = await getAuthorizedFederationIds();
    return ids.isEmpty;
  }

  /// Returns the list of federation IDs the current admin is authorized for.
  /// Returns empty list for global scope (SUPER_ADMIN only).
  /// Returns specific federation IDs for FEDERATION_ADMIN based on admin_federation_scope.
  Future<List<String>> getAuthorizedFederationIds() async {
    final email = _getCurrentEmail();
    if (email == 'deveshambekar@gmail.com') {
      return [];
    }

    final userId = _client?.auth.currentUser?.id;
    if (userId != null && _cachedFederationIdsByUserId.containsKey(userId)) {
      return _cachedFederationIdsByUserId[userId]!;
    }

    final client = _client;

    // 1. Authoritative check: Query admin_federation_scope table in database
    if (userId != null && client != null) {
      try {
        final res = await client
            .from('admin_federation_scope')
            .select('federation_id')
            .eq('user_id', userId)
            .eq('is_active', true);

        final list = (res as List)
            .map((r) => r['federation_id']?.toString())
            .whereType<String>()
            .toList();

        if (list.isNotEmpty) {
          _cachedFederationIdsByUserId[userId] = list;
          return list;
        }
      } catch (e) {
        debugPrint('[FederationScope] Error loading scope from admin_federation_scope: $e');
      }
    }

    // 2. Secondary check: User auth metadata
    final user = _client?.auth.currentUser;
    final metaFedId = (user?.userMetadata?['federation_id'] ?? user?.appMetadata['federation_id'])?.toString();
    if (metaFedId != null && metaFedId.isNotEmpty) {
      final list = [metaFedId];
      if (userId != null) _cachedFederationIdsByUserId[userId] = list;
      return list;
    }

    // 3. Known email mapping fallbacks
    if (email == 'omshinde@gmail.com' || (email != null && email.contains('nagpur'))) {
      final list = ['55555555-0000-0000-0000-000000000005'];
      if (userId != null) _cachedFederationIdsByUserId[userId] = list;
      return list;
    }
    if (email == 'adilatar9494@gmail.com' || (email != null && email.contains('nashik'))) {
      final list = ['22222222-0000-0000-0000-000000000002'];
      if (userId != null) _cachedFederationIdsByUserId[userId] = list;
      return list;
    }
    if (email == 'ambekardevesh2@gmail.com' || (email != null && email.contains('pune'))) {
      final list = ['11111111-0000-0000-0000-000000000001'];
      if (userId != null) _cachedFederationIdsByUserId[userId] = list;
      return list;
    }

    // 4. Role check: Only SUPER_ADMIN gets global empty list
    final role = await getAdminRole();
    if (role == 'SUPER_ADMIN') {
      if (userId != null) _cachedFederationIdsByUserId[userId] = [];
      return [];
    }

    // 5. Offline unauthenticated mock default for unit tests
    if (_client == null) {
      return ['11111111-0000-0000-0000-000000000001'];
    }

    // 6. Authenticated federation admin with no scope assigned has ZERO access
    if (userId != null) _cachedFederationIdsByUserId[userId] = [];
    return [];
  }

  /// Clears the cached scope (call on login, logout or role change).
  void clearCache() {
    _cachedRoleByUserId.clear();
    _cachedFederationIdsByUserId.clear();
  }

  /// Returns a human-readable scope description for display.
  Future<String> getScopeDescription() async {
    if (await hasGlobalScope()) {
      return 'All Federations (National)';
    }
    final ids = await getAuthorizedFederationIds();
    if (ids.isEmpty) return 'No Federation Assigned';

    final pool = await FederationModel.fetchAllFederations();
    final matchedNames = <String>[];
    for (final id in ids) {
      final match = pool.where((f) => f.id == id).firstOrNull;
      if (match != null) {
        matchedNames.add(match.name);
      }
    }

    if (matchedNames.isNotEmpty) {
      return matchedNames.join(', ');
    }

    if (ids.contains('11111111-0000-0000-0000-000000000001')) {
      return 'Pune District Labour Cooperative Federation';
    }
    if (ids.contains('22222222-0000-0000-0000-000000000002')) {
      return 'Nashik District Artisans Cooperative Union';
    }
    if (ids.contains('33333333-0000-0000-0000-000000000003')) {
      return 'Mumbai Metropolitan Labour Federation';
    }
    if (ids.contains('44444444-0000-0000-0000-000000000004')) {
      return 'Chhatrapati Sambhajinagar Labour Federation';
    }
    if (ids.contains('55555555-0000-0000-0000-000000000005')) {
      return 'Nagpur District Shramik Cooperative Union';
    }
    return '${ids.length} Federations';
  }
}
