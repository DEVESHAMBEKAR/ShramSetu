import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_user_repository.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../features/customer/data/models/customer_profile.dart';
import '../../../../core/utils/phone_number_util.dart';
import '../../../../core/utils/uuid_util.dart';
import '../../../../core/services/firebase_phone_auth_service.dart';
import '../../../../core/services/local_storage_service.dart';

class SupabaseUserRepository implements IUserRepository {
  final SupabaseClient _client;

  SupabaseUserRepository(this._client);

  void _cacheCustomerProfile(CustomerProfile profile) {
    try {
      final jsonStr = jsonEncode(profile.toMap());
      if (profile.id.isNotEmpty) {
        LocalStorageService.setString('customer_profile_${profile.id}', jsonStr);
      }
      final clean = PhoneNumberUtil.cleanIndianPhone(profile.phone);
      if (clean.isNotEmpty) {
        LocalStorageService.setString('customer_profile_$clean', jsonStr);
        if (profile.isComplete) {
          LocalStorageService.setBool('customer_is_complete_$clean', true);
        }
      }
      if (profile.isComplete && profile.id.isNotEmpty) {
        LocalStorageService.setBool('customer_is_complete_${profile.id}', true);
      }
    } catch (_) {}
  }

  CustomerProfile? _getCachedCustomerProfile(String? id, [String? phone]) {
    try {
      String? jsonStr;
      if (id != null && id.isNotEmpty) {
        jsonStr = LocalStorageService.getString('customer_profile_$id');
      }
      if (jsonStr == null && phone != null && phone.isNotEmpty) {
        final clean = PhoneNumberUtil.cleanIndianPhone(phone);
        if (clean.isNotEmpty) {
          jsonStr = LocalStorageService.getString('customer_profile_$clean');
        }
      }
      if (jsonStr == null) {
        final activePhone = _getActiveUserPhone();
        if (activePhone != null && activePhone.isNotEmpty) {
          final clean = PhoneNumberUtil.cleanIndianPhone(activePhone);
          if (clean.isNotEmpty) {
            jsonStr = LocalStorageService.getString('customer_profile_$clean');
          }
        }
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return CustomerProfile.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  void _cacheCustomerAddress(String userId, String? phone, CustomerAddress address) {
    try {
      final jsonStr = jsonEncode(address.toMap());
      if (userId.isNotEmpty) {
        LocalStorageService.setString('customer_address_$userId', jsonStr);
      }
      if (phone != null && phone.isNotEmpty) {
        final clean = PhoneNumberUtil.cleanIndianPhone(phone);
        if (clean.isNotEmpty) {
          LocalStorageService.setString('customer_address_$clean', jsonStr);
        }
      }
    } catch (_) {}
  }

  CustomerAddress? _getCachedCustomerAddress(String? userId, [String? phone]) {
    try {
      String? jsonStr;
      if (userId != null && userId.isNotEmpty) {
        jsonStr = LocalStorageService.getString('customer_address_$userId');
      }
      if (jsonStr == null && phone != null && phone.isNotEmpty) {
        final clean = PhoneNumberUtil.cleanIndianPhone(phone);
        if (clean.isNotEmpty) {
          jsonStr = LocalStorageService.getString('customer_address_$clean');
        }
      }
      if (jsonStr == null) {
        final activePhone = _getActiveUserPhone();
        if (activePhone != null && activePhone.isNotEmpty) {
          final clean = PhoneNumberUtil.cleanIndianPhone(activePhone);
          if (clean.isNotEmpty) {
            jsonStr = LocalStorageService.getString('customer_address_$clean');
          }
        }
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return CustomerAddress.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  String? _getActiveUserPhone() {
    final sbPhone = _client.auth.currentUser?.phone;
    if (sbPhone != null && sbPhone.isNotEmpty) return sbPhone;
    if (FirebasePhoneAuthService.instance.isAvailable) {
      try {
        final fbUser = FirebasePhoneAuthService.instance.auth.currentUser;
        return fbUser?.phoneNumber ?? FirebasePhoneAuthService.instance.activePhoneNumber;
      } catch (_) {}
    }
    return null;
  }

  // ─────────────────────── Core Auth Methods ───────────────────────

  @override
  Future<String?> getUserRole(String userId) async {
    // 1. Authoritative check in public.users table first by ID
    try {
      final response = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (response != null && response['role'] != null) {
        final dbRole = response['role'].toString().trim().toUpperCase();
        if (dbRole.isNotEmpty) return dbRole;
      }
    } catch (_) {
      // If database query fails, fallback
    }

    // 2. Authoritative check in public.users table by active user phone
    try {
      final phone = _getActiveUserPhone();
      if (phone != null && phone.isNotEmpty) {
        final clean = PhoneNumberUtil.cleanIndianPhone(phone);
        if (clean.isNotEmpty) {
          final response = await _client
              .from('users')
              .select('role')
              .or('phone.eq.$clean,phone.eq.+91$clean,phone.eq.91$clean')
              .maybeSingle();
          if (response != null && response['role'] != null) {
            final dbRole = response['role'].toString().trim().toUpperCase();
            if (dbRole.isNotEmpty) return dbRole;
          }
        }
      }
    } catch (_) {}

    // 3. Auth session metadata fallback
    final currentUser = _client.auth.currentUser;
    if (currentUser != null && currentUser.id == userId) {
      final metaRole = (currentUser.appMetadata['role'] ?? currentUser.userMetadata?['role'])?.toString().toUpperCase();
      if (metaRole != null && metaRole.isNotEmpty) {
        return metaRole;
      }
      final email = currentUser.email?.toLowerCase() ?? '';
      if (email == 'admin@shramsetu.in' || email.contains('admin@')) {
        return 'ADMIN';
      }
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('id, full_name, phone, email, role, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        return response;
      }
    } catch (_) {}

    // Check by active user phone if id didn't match directly
    try {
      final phone = _getActiveUserPhone();
      if (phone != null && phone.isNotEmpty) {
        final clean = PhoneNumberUtil.cleanIndianPhone(phone);
        if (clean.isNotEmpty) {
          final response = await _client
              .from('users')
              .select('id, full_name, phone, email, role, avatar_url')
              .or('phone.eq.$clean,phone.eq.+91$clean,phone.eq.91$clean')
              .maybeSingle();
          if (response != null) {
            return response;
          }
        }
      }
    } catch (_) {}

    // Fallback to active auth session metadata
    final currentUser = _client.auth.currentUser;
    if (currentUser != null && (currentUser.id == userId || userId.isEmpty)) {
      return {
        'id': currentUser.id,
        'full_name': currentUser.userMetadata?['full_name'] ?? currentUser.userMetadata?['name'],
        'phone': currentUser.phone,
        'email': currentUser.email,
        'role': (currentUser.appMetadata['role'] ?? currentUser.userMetadata?['role'])?.toString().toUpperCase(),
        'avatar_url': currentUser.userMetadata?['avatar_url'],
      };
    }
    return null;
  }

  @override
  Future<void> upsertUserProfile({
    required String userId,
    required String role,
    required String phone,
    String? fullName,
    String? federationId,
  }) async {
    final safeUserId = UuidUtil.isValidUuid(userId) ? userId : UuidUtil.toDeterministicUuid(userId);
    final currentUser = _client.auth.currentUser;
    final effectiveEmail = currentUser?.email;
    final effectiveAvatar = currentUser?.userMetadata?['avatar_url'] ?? currentUser?.userMetadata?['picture'];
    final trimmedPhone = phone.trim();

    try {
      // Check if user record already exists
      final existing = await _client
          .from('users')
          .select('id, full_name, role, phone, email, avatar_url')
          .eq('id', safeUserId)
          .maybeSingle();

      if (existing != null) {
        final existingName = existing['full_name'] as String?;
        final updates = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (trimmedPhone.isNotEmpty) {
          updates['phone'] = trimmedPhone;
        }

        if (effectiveEmail != null && effectiveEmail.isNotEmpty) {
          updates['email'] = effectiveEmail;
        }

        if (effectiveAvatar != null && effectiveAvatar.toString().isNotEmpty) {
          updates['avatar_url'] = effectiveAvatar;
        }

        // Only update full_name if explicitly provided, or if previously missing/empty
        if (fullName != null && fullName.isNotEmpty) {
          updates['full_name'] = fullName;
        } else if (existingName == null || existingName.isEmpty) {
          updates['full_name'] = trimmedPhone.length >= 4
              ? 'User ${trimmedPhone.substring(trimmedPhone.length - 4)}'
              : (effectiveEmail != null ? effectiveEmail.split('@').first : 'User');
        }

        await _client.from('users').update(updates).eq('id', safeUserId);
      } else {
        final effectiveName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : (trimmedPhone.length >= 4
                ? 'User ${trimmedPhone.substring(trimmedPhone.length - 4)}'
                : (effectiveEmail != null ? effectiveEmail.split('@').first : 'User'));

        final insertData = <String, dynamic>{
          'id': safeUserId,
          'role': role,
          'full_name': effectiveName,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (trimmedPhone.isNotEmpty) {
          insertData['phone'] = trimmedPhone;
        }
        if (effectiveEmail != null && effectiveEmail.isNotEmpty) {
          insertData['email'] = effectiveEmail;
        }
        if (effectiveAvatar != null && effectiveAvatar.toString().isNotEmpty) {
          insertData['avatar_url'] = effectiveAvatar;
        }

        await _client.from('users').upsert(insertData, onConflict: 'id');
      }

      // Try updating federation_id separately if provided
      if (federationId != null && federationId.isNotEmpty) {
        try {
          await _client.from('users').update({'federation_id': federationId}).eq('id', safeUserId);
        } catch (_) {}
      }

      // If role is WORKER, ensure a worker profile row exists.
      if (role == 'WORKER') {
        final workerExists = await _client
            .from('workers')
            .select('id')
            .eq('id', safeUserId)
            .maybeSingle();

        if (workerExists == null) {
          await _client.from('workers').insert({
            'id': safeUserId,
            'worker_status': 'PENDING_VERIFICATION',
            if (federationId != null) 'federation_ref_id': federationId,
          });
        }
      }
    } catch (e) {
      debugPrint('[UserRepository] Primary upsert note: $e - attempting resilient fallback');
      // Resilient fallback: upsert with base columns
      try {
        final fallbackData = <String, dynamic>{
          'id': safeUserId,
          'role': role,
          'full_name': (fullName != null && fullName.isNotEmpty)
              ? fullName
              : (trimmedPhone.length >= 4 ? 'User ${trimmedPhone.substring(trimmedPhone.length - 4)}' : 'User'),
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (trimmedPhone.isNotEmpty) fallbackData['phone'] = trimmedPhone;
        if (effectiveEmail != null && effectiveEmail.isNotEmpty) fallbackData['email'] = effectiveEmail;
        if (effectiveAvatar != null) fallbackData['avatar_url'] = effectiveAvatar;

        await _client.from('users').upsert(fallbackData, onConflict: 'id');
      } catch (err) {
        debugPrint('[UserRepository] Fallback upsert error: $err');
      }
    }
  }

  // ─────────────────────── Customer Profile Methods ───────────────────────

  @override
  Future<CustomerProfile?> getCustomerProfile(String userId) async {
    try {
      var userRow = await _client
          .from('users')
          .select('id, full_name, phone, email, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      // If not found by ID, attempt resolution via active user phone
      if (userRow == null) {
        try {
          final phone = _getActiveUserPhone();
          if (phone != null && phone.isNotEmpty) {
            final clean = PhoneNumberUtil.cleanIndianPhone(phone);
            if (clean.isNotEmpty) {
              userRow = await _client
                  .from('users')
                  .select('id, full_name, phone, email, avatar_url')
                  .or('phone.eq.$clean,phone.eq.+91$clean,phone.eq.91$clean')
                  .maybeSingle();
            }
          }
        } catch (_) {}
      }

      if (userRow != null) {
        final effectiveUserId = userRow['id'] as String;
        final defaultAddr = await getDefaultAddress(effectiveUserId);
        String? fedId;
        String? fedName;

        if (defaultAddr != null) {
          final resolved = FederationModel.findFederationForLocation(
            district: defaultAddr.district,
            city: defaultAddr.city,
            state: defaultAddr.state,
            location: defaultAddr.area,
            address: defaultAddr.addressLine,
            pincode: defaultAddr.postalCode,
          );
          fedId = resolved?.id;
          fedName = resolved?.name;
          final currentDbFed = (userRow['federation_id'] ?? userRow['federation_ref_id']) as String?;
          if (currentDbFed != fedId) {
            try {
              await _client.from('users').update({
                'federation_id': fedId,
                'federation_ref_id': fedId,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', effectiveUserId);
            } catch (_) {}
          }
        } else {
          final rawFedId = (userRow['federation_id'] ?? userRow['federation_ref_id']) as String?;
          if (rawFedId != null && rawFedId.isNotEmpty) {
            final resolved = FederationModel.findFederationForLocation(federationId: rawFedId);
            fedId = resolved?.id;
            fedName = resolved?.name;
          }
        }

        final currentUser = _client.auth.currentUser;
        final rawEmail = userRow['email'] as String?;
        final rawName = (userRow['full_name'] as String?)?.trim() ?? '';
        final metaEmail = currentUser?.userMetadata?['email'] as String?;
        final metaName = (currentUser?.userMetadata?['full_name'] ?? currentUser?.userMetadata?['name']) as String?;

        final effectiveEmail = (rawEmail != null && rawEmail.isNotEmpty)
            ? rawEmail
            : ((metaEmail != null && metaEmail.isNotEmpty) ? metaEmail : currentUser?.email);

        final isPlaceholderName = rawName.isEmpty ||
            RegExp(r'^\+?\d{10,13}$').hasMatch(rawName) ||
            rawName.toLowerCase().startsWith('user ');

        final effectiveName = (!isPlaceholderName)
            ? rawName
            : ((metaName != null && metaName.trim().isNotEmpty && !RegExp(r'^\+?\d{10,13}$').hasMatch(metaName.trim()))
                ? metaName.trim()
                : rawName);

        final patchedMap = Map<String, dynamic>.from(userRow)
          ..['email'] = effectiveEmail
          ..['full_name'] = effectiveName
          ..['federation_id'] = fedId
          ..['federation_ref_id'] = fedId;

        final prof = CustomerProfile.fromMap(
          patchedMap,
          defaultAddress: defaultAddr,
          federationName: fedName,
        );
        _cacheCustomerProfile(prof);
        return prof;
      }
    } catch (e) {
      // Fall through to auth session check
    }

    final currentUser = _client.auth.currentUser;
    if (currentUser != null && (currentUser.id == userId || userId.isEmpty)) {
      final defaultAddr = await getDefaultAddress(currentUser.id);
      String? fedId;
      String? fedName;
      if (defaultAddr != null) {
        final resolved = FederationModel.findFederationForLocation(
          district: defaultAddr.district,
          city: defaultAddr.city,
          state: defaultAddr.state,
          location: defaultAddr.area,
          address: defaultAddr.addressLine,
          pincode: defaultAddr.postalCode,
        );
        fedId = resolved?.id;
        fedName = resolved?.name;
      }
      final metaName = (currentUser.userMetadata?['full_name'] ?? currentUser.userMetadata?['name'] ?? '').toString().trim();
      final metaEmail = (currentUser.userMetadata?['email'] as String?) ?? currentUser.email;
      final prof = CustomerProfile(
        id: currentUser.id,
        fullName: metaName,
        phone: currentUser.phone ?? '',
        email: metaEmail,
        avatarUrl: currentUser.userMetadata?['avatar_url']?.toString(),
        defaultAddress: defaultAddr,
        federationId: fedId,
        federationName: fedName,
      );
      _cacheCustomerProfile(prof);
      return prof;
    }
    return _getCachedCustomerProfile(userId, _getActiveUserPhone());
  }

  @override
  Future<CustomerProfile?> getCustomerProfileByPhone(String phone) async {
    try {
      final cleanPhone = PhoneNumberUtil.cleanIndianPhone(phone);
      if (cleanPhone.isEmpty) return null;
      // Check phone in all Indian formats (+91, plain 10-digit, 91 without plus)
      final userRow = await _client
          .from('users')
          .select('id, full_name, phone, email, avatar_url')
          .or('phone.eq.$cleanPhone,phone.eq.+91$cleanPhone,phone.eq.91$cleanPhone')
          .maybeSingle();

      if (userRow == null) {
        return _getCachedCustomerProfile(null, cleanPhone);
      }

      final userId = userRow['id'] as String;
      final defaultAddr = await getDefaultAddress(userId);
      String? fedId;
      String? fedName;

      if (defaultAddr != null) {
        final resolved = FederationModel.findFederationForLocation(
          district: defaultAddr.district,
          city: defaultAddr.city,
          state: defaultAddr.state,
          location: defaultAddr.area,
          address: defaultAddr.addressLine,
          pincode: defaultAddr.postalCode,
        );
        fedId = resolved?.id;
        fedName = resolved?.name;
      } else {
        final rawFed = (userRow['federation_id'] ?? userRow['federation_ref_id']) as String?;
        if (rawFed != null && rawFed.isNotEmpty) {
          final resolved = FederationModel.findFederationForLocation(federationId: rawFed);
          fedId = resolved?.id;
          fedName = resolved?.name;
        }
      }

      final patchedMap = Map<String, dynamic>.from(userRow)
        ..['federation_id'] = fedId
        ..['federation_ref_id'] = fedId;

      final prof = CustomerProfile.fromMap(
        patchedMap,
        defaultAddress: defaultAddr,
        federationName: fedName,
      );
      _cacheCustomerProfile(prof);
      return prof;
    } catch (e) {
      return _getCachedCustomerProfile(null, phone);
    }
  }

  @override
  Future<void> updateCustomerProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    String? federationId,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = (email != null && email.trim().isNotEmpty) ? email.trim() : null;

    // 1. Synchronize Supabase Auth user metadata & email
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser != null && (currentUser.id == userId || userId.isEmpty)) {
        await _client.auth.updateUser(
          UserAttributes(
            data: {
              if (cleanName.isNotEmpty) 'full_name': cleanName,
              if (cleanName.isNotEmpty) 'name': cleanName,
              if (cleanEmail != null) 'email': cleanEmail,
            },
          ),
        );
        if (cleanEmail != null && cleanEmail.isNotEmpty && cleanEmail != currentUser.email) {
          try {
            await _client.auth.updateUser(UserAttributes(email: cleanEmail));
          } catch (eAuthEmail) {
            debugPrint('[SupabaseUserRepo] auth.updateUser email note: $eAuthEmail');
          }
        }
      }
    } catch (e) {
      debugPrint('[SupabaseUserRepo] updateCustomerProfile auth.updateUser note: $e');
    }

    // 2. Synchronize public.users database row
    final rawUserId = (_client.auth.currentUser?.id != null && _client.auth.currentUser!.id.isNotEmpty)
        ? _client.auth.currentUser!.id
        : userId;
    final effectiveUserId = UuidUtil.isValidUuid(rawUserId) ? rawUserId : UuidUtil.toDeterministicUuid(rawUserId);

    final updates = <String, dynamic>{
      'full_name': cleanName,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (cleanEmail != null) {
      updates['email'] = cleanEmail;
    }
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }

    try {
      final res = await _client.from('users').update(updates).eq('id', effectiveUserId).select('id').maybeSingle();
      if (res == null) {
        // User record doesn't exist yet, insert with role CUSTOMER
        final insertPayload = Map<String, dynamic>.from(updates)
          ..['id'] = effectiveUserId
          ..['role'] = 'CUSTOMER'
          ..['created_at'] = DateTime.now().toIso8601String();
        if (phone != null && phone.trim().isNotEmpty) {
          final cleanPhone = PhoneNumberUtil.cleanIndianPhone(phone.trim());
          insertPayload['phone'] = cleanPhone.isNotEmpty ? cleanPhone : phone.trim();
        }
        await _client.from('users').upsert(insertPayload);
      }
    } catch (e) {
      debugPrint('[SupabaseUserRepo] updateCustomerProfile primary update error: $e');
      try {
        final fallbackPayload = <String, dynamic>{
          'id': effectiveUserId,
          'role': 'CUSTOMER',
          'full_name': cleanName,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (phone != null && phone.trim().isNotEmpty) {
          final cleanPhone = PhoneNumberUtil.cleanIndianPhone(phone.trim());
          fallbackPayload['phone'] = cleanPhone.isNotEmpty ? cleanPhone : phone.trim();
        }
        if (avatarUrl != null) fallbackPayload['avatar_url'] = avatarUrl;
        await _client.from('users').upsert(fallbackPayload);
      } catch (e2) {
        debugPrint('[SupabaseUserRepo] updateCustomerProfile fallback upsert note: $e2');
      }
    }

    // Attempt to update federation_id if provided (silent try-catch)
    final fid = (federationId != null && federationId.isNotEmpty) ? federationId : null;
    if (fid != null) {
      try {
        await _client.from('users').update({
          'federation_id': fid,
        }).eq('id', effectiveUserId);
      } catch (_) {}
    }

    // Cache updated profile locally so it survives sessions
    final activePhone = phone ?? _getActiveUserPhone();
    final cleanPhone = activePhone != null ? PhoneNumberUtil.cleanIndianPhone(activePhone) : '';
    final existingAddr = _getCachedCustomerAddress(effectiveUserId, cleanPhone);
    final cachedProf = CustomerProfile(
      id: effectiveUserId,
      fullName: cleanName,
      phone: cleanPhone.isNotEmpty ? cleanPhone : (phone ?? ''),
      email: cleanEmail,
      avatarUrl: avatarUrl,
      defaultAddress: existingAddr,
      federationId: fid,
    );
    _cacheCustomerProfile(cachedProf);
  }

  @override
  Future<String?> assignCustomerFederation({
    required String userId,
    String? district,
    String? city,
    String? state,
    String? area,
    String? addressLine,
    String? federationId,
  }) async {
    try {
      final targetFed = FederationModel.findFederationForLocation(
        federationId: federationId,
        district: district,
        city: city,
        state: state,
        location: area,
        address: addressLine,
      );

      await _client.from('users').update({
        'federation_id': targetFed?.id,
        'federation_ref_id': targetFed?.id,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return targetFed?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isProfileComplete(String userId) async {
    // 1. Fast check in persistent local cache
    final activePhone = _getActiveUserPhone();
    final cleanPhone = activePhone != null ? PhoneNumberUtil.cleanIndianPhone(activePhone) : '';
    if (cleanPhone.isNotEmpty && LocalStorageService.getBool('customer_is_complete_$cleanPhone') == true) {
      return true;
    }
    if (userId.isNotEmpty && LocalStorageService.getBool('customer_is_complete_$userId') == true) {
      return true;
    }

    try {
      final profile = await getCustomerProfile(userId);
      if (profile != null && profile.isComplete) {
        _cacheCustomerProfile(profile);
        return true;
      }

      // Resilient fallback: verify directly if users table has a real name
      // and addresses table has at least 1 saved address for this customer
      var userRow = await _client
          .from('users')
          .select('id, full_name')
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null && cleanPhone.isNotEmpty) {
        try {
          userRow = await _client
              .from('users')
              .select('id, full_name')
              .or('phone.eq.$cleanPhone,phone.eq.+91$cleanPhone,phone.eq.91$cleanPhone')
              .maybeSingle();
        } catch (_) {}
      }

      if (userRow != null) {
        final effectiveId = userRow['id'] as String;
        final name = (userRow['full_name'] as String?)?.trim() ?? '';
        final isRealName = name.isNotEmpty &&
            !name.toLowerCase().startsWith('user ') &&
            name.toLowerCase() != 'ananya' &&
            name.toLowerCase() != 'demo user' &&
            name.toLowerCase() != 'test user';
        if (isRealName) {
          final addrs = await _client
              .from('addresses')
              .select('id')
              .eq('user_id', effectiveId)
              .limit(1);
          if ((addrs as List).isNotEmpty) {
            if (cleanPhone.isNotEmpty) LocalStorageService.setBool('customer_is_complete_$cleanPhone', true);
            LocalStorageService.setBool('customer_is_complete_$effectiveId', true);
            return true;
          }
        }
      }

      // Check cached address and profile
      if (cleanPhone.isNotEmpty) {
        final cached = _getCachedCustomerProfile(userId, cleanPhone);
        if (cached != null && cached.isComplete) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[SupabaseUserRepo] isProfileComplete error: $e');
      if (cleanPhone.isNotEmpty) {
        final cached = _getCachedCustomerProfile(userId, cleanPhone);
        if (cached != null && cached.isComplete) {
          return true;
        }
      }
      return false;
    }
  }

  @override
  Future<CustomerAddress> createAddress({
    required String userId,
    required String addressLine,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    String? district,
    String? federationId,
    String? label,
    double? latitude,
    double? longitude,
  }) async {
    final rawUserId = (_client.auth.currentUser?.id != null && _client.auth.currentUser!.id.isNotEmpty)
        ? _client.auth.currentUser!.id
        : userId;
    final effectiveUserId = UuidUtil.isValidUuid(rawUserId) ? rawUserId : UuidUtil.toDeterministicUuid(rawUserId);

    // Ensure the customer record exists in public.users to satisfy foreign key constraint
    try {
      final userCheck = await _client.from('users').select('id').eq('id', effectiveUserId).maybeSingle();
      if (userCheck == null) {
        final curUser = _client.auth.currentUser;
        await _client.from('users').upsert({
          'id': effectiveUserId,
          'role': 'CUSTOMER',
          'phone': curUser?.phone,
          'email': curUser?.email,
          'full_name': curUser?.userMetadata?['full_name'] ?? curUser?.userMetadata?['name'] ?? 'Customer',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('[SupabaseUserRepo] ensure user in users table note: $e');
    }

    // Determine if this is the first address — if so, make it default.
    bool isFirst = true;
    try {
      final existing = await _client
          .from('addresses')
          .select('id')
          .eq('user_id', effectiveUserId)
          .limit(1);
      isFirst = (existing as List).isEmpty;
    } catch (_) {
      isFirst = true;
    }

    // Resolve federation from provided geographic location
    final effectiveDistrict = (district != null && district.trim().isNotEmpty) ? district.trim() : city.trim();
    final resolvedFed = FederationModel.findFederationForLocation(
      federationId: federationId,
      district: effectiveDistrict,
      city: city.trim(),
      state: state.trim(),
      location: area.trim(),
      address: addressLine.trim(),
      pincode: postalCode.trim(),
    );

    // Guaranteed base schema columns in public.addresses
    final basePayload = <String, dynamic>{
      'user_id': effectiveUserId,
      'label': label ?? 'Home',
      'address_line': addressLine.trim(),
      'area': area.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'postal_code': postalCode.trim(),
      'is_default': isFirst,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (latitude != null) basePayload['latitude'] = latitude;
    if (longitude != null) basePayload['longitude'] = longitude;

    Map<String, dynamic>? row;
    try {
      row = await _client.from('addresses').insert(basePayload).select().maybeSingle();
    } catch (e) {
      debugPrint('[SupabaseUserRepo] createAddress insert with select note: $e');
      try {
        await _client.from('addresses').insert(basePayload);
      } catch (e2) {
        debugPrint('[SupabaseUserRepo] createAddress blind insert note: $e2');
      }
    }

    // Synchronize user's federation in public.users if column exists (silent try-catch)
    if (resolvedFed?.id != null) {
      try {
        await _client.from('users').update({
          'federation_id': resolvedFed!.id,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', effectiveUserId);
      } catch (_) {}
    }

    CustomerAddress finalAddr;
    if (row != null) {
      final patchedRow = Map<String, dynamic>.from(row)
        ..putIfAbsent('district', () => effectiveDistrict)
        ..putIfAbsent('federation_id', () => resolvedFed?.id);
      finalAddr = CustomerAddress.fromMap(patchedRow);
    } else {
      // Reliable fallback: Return complete CustomerAddress model
      finalAddr = CustomerAddress(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        addressLine: addressLine.trim(),
        area: area.trim(),
        city: city.trim(),
        state: state.trim(),
        postalCode: postalCode.trim(),
        isDefault: isFirst,
        district: effectiveDistrict,
        federationId: resolvedFed?.id,
        latitude: latitude,
        longitude: longitude,
      );
    }

    // Persist to local cache so user never has to re-enter
    final activePhone = _getActiveUserPhone();
    final cleanPhone = activePhone != null ? PhoneNumberUtil.cleanIndianPhone(activePhone) : '';
    _cacheCustomerAddress(effectiveUserId, activePhone, finalAddr);
    if (cleanPhone.isNotEmpty) {
      LocalStorageService.setBool('customer_is_complete_$cleanPhone', true);
    }
    LocalStorageService.setBool('customer_is_complete_$effectiveUserId', true);
    return finalAddr;
  }

  @override
  Future<CustomerAddress?> getDefaultAddress(String userId) async {
    final safeUserId = UuidUtil.isValidUuid(userId) ? userId : UuidUtil.toDeterministicUuid(userId);
    try {
      final rows = await _client
          .from('addresses')
          .select()
          .eq('user_id', safeUserId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      if ((rows as List).isNotEmpty) {
        final addr = CustomerAddress.fromMap(rows.first);
        _cacheCustomerAddress(safeUserId, _getActiveUserPhone(), addr);
        return addr;
      }

      // If no address found by userId, try resolving real DB user id via active user phone
      try {
        final phone = _getActiveUserPhone();
        if (phone != null && phone.isNotEmpty) {
          final clean = PhoneNumberUtil.cleanIndianPhone(phone);
          if (clean.isNotEmpty) {
            final userRow = await _client
                .from('users')
                .select('id')
                .or('phone.eq.$clean,phone.eq.+91$clean,phone.eq.91$clean')
                .maybeSingle();
            if (userRow != null && userRow['id'] != null && userRow['id'] != safeUserId) {
              final altRows = await _client
                  .from('addresses')
                  .select()
                  .eq('user_id', userRow['id'] as String)
                  .order('is_default', ascending: false)
                  .order('created_at', ascending: false)
                  .limit(1);
              if ((altRows as List).isNotEmpty) {
                final addr = CustomerAddress.fromMap(altRows.first);
                _cacheCustomerAddress(safeUserId, clean, addr);
                return addr;
              }
            }
          }
        }
      } catch (_) {}

      return _getCachedCustomerAddress(safeUserId, _getActiveUserPhone());
    } catch (e) {
      debugPrint('[SupabaseUserRepo] getDefaultAddress error: $e');
      return _getCachedCustomerAddress(safeUserId, _getActiveUserPhone());
    }
  }

  @override
  Future<List<CustomerAddress>> getUserAddresses(String userId) async {
    try {
      final rows = await _client
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      if ((rows as List).isNotEmpty) {
        return (rows as List).map((r) => CustomerAddress.fromMap(r as Map<String, dynamic>)).toList();
      }

      // Check by active user phone if userId had no addresses
      try {
        final phone = _getActiveUserPhone();
        if (phone != null && phone.isNotEmpty) {
          final clean = PhoneNumberUtil.cleanIndianPhone(phone);
          if (clean.isNotEmpty) {
            final userRow = await _client
                .from('users')
                .select('id')
                .or('phone.eq.$clean,phone.eq.+91$clean,phone.eq.91$clean')
                .maybeSingle();
            if (userRow != null && userRow['id'] != null && userRow['id'] != userId) {
              final altRows = await _client
                  .from('addresses')
                  .select()
                  .eq('user_id', userRow['id'] as String)
                  .order('is_default', ascending: false)
                  .order('created_at', ascending: false);
              if ((altRows as List).isNotEmpty) {
                return (altRows as List).map((r) => CustomerAddress.fromMap(r as Map<String, dynamic>)).toList();
              }
            }
          }
        }
      } catch (_) {}

      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> setDefaultAddress({required String userId, required String addressId}) async {
    try {
      // 1. Unset all defaults for this user
      await _client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);

      // 2. Set the chosen address as default
      final updated = await _client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', addressId)
          .select()
          .maybeSingle();

      // Synchronize customer federation to match new default address
      if (updated != null) {
        final fedId = updated['federation_id'] as String?;
        if (fedId != null && fedId.isNotEmpty) {
          await _client.from('users').update({
            'federation_id': fedId,
            'federation_ref_id': fedId,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> deleteAddress({required String userId, required String addressId}) async {
    try {
      await _client
          .from('addresses')
          .delete()
          .eq('id', addressId)
          .eq('user_id', userId);
    } catch (_) {}
  }

  @override
  Future<void> updateAddress({
    required String userId,
    required String addressId,
    required String addressLine,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    String? district,
    String? federationId,
  }) async {
    try {
      final effectiveDistrict = (district != null && district.trim().isNotEmpty) ? district.trim() : city.trim();
      final resolvedFed = FederationModel.findFederationForLocation(
        federationId: federationId,
        district: effectiveDistrict,
        city: city.trim(),
        state: state.trim(),
        location: area.trim(),
        address: addressLine.trim(),
        pincode: postalCode.trim(),
      );

      final updatePayload = <String, dynamic>{
        'address_line': addressLine.trim(),
        'area': area.trim(),
        'city': city.trim(),
        'district': effectiveDistrict,
        'state': state.trim(),
        'postal_code': postalCode.trim(),
        'federation_id': resolvedFed?.id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final updated = await _client
          .from('addresses')
          .update(updatePayload)
          .eq('id', addressId)
          .eq('user_id', userId)
          .select()
          .maybeSingle();

      if (updated != null && updated['is_default'] == true) {
        await _client.from('users').update({
          'federation_id': resolvedFed?.id,
          'federation_ref_id': resolvedFed?.id,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }
    } catch (_) {}
  }
}
