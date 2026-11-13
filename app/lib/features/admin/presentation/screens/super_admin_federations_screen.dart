import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/services/audit_log_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../core/services/india_geography_service.dart';

/// Super Admin — Federation CRUD management and Admin Provisioning screen.
/// Only Super Admins can create federations and provision Federation Admins with logins.
class SuperAdminFederationsScreen extends StatefulWidget {
  const SuperAdminFederationsScreen({super.key});

  @override
  State<SuperAdminFederationsScreen> createState() => _SuperAdminFederationsScreenState();
}

class _SuperAdminFederationsScreenState extends State<SuperAdminFederationsScreen> {
  bool _isLoading = true;
  String? _error;
  List<FederationModel> _federations = [];
  List<Map<String, dynamic>> _allAdmins = [];
  Map<String, List<Map<String, dynamic>>> _federationAdminsMap = {};
  int _selectedView = 0; // 0: Cooperatives, 1: Federation Admins Directory

  // Filter & Sort State
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStateFilter;
  String? _selectedDistrictFilter;
  String _selectedSortOption = 'state_asc'; // state_asc, state_desc, district_asc, district_desc, name_asc, name_desc

  static const Map<String, String> _sortLabels = {
    'state_asc': 'State (A → Z)',
    'state_desc': 'State (Z → A)',
    'district_asc': 'District (A → Z)',
    'district_desc': 'District (Z → A)',
    'name_asc': 'Name (A → Z)',
    'name_desc': 'Name (Z → A)',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  FederationModel? _getFederationForAdmin(Map<String, dynamic> admin) {
    final fedId = (admin['federation_id'] ?? '').toString().trim().toLowerCase();
    final fedName = (admin['federation_name'] ?? '').toString().trim().toLowerCase();
    for (final f in _federations) {
      if (fedId.isNotEmpty && f.id.trim().toLowerCase() == fedId) return f;
      if (fedName.isNotEmpty && f.name.trim().toLowerCase() == fedName) return f;
    }
    return null;
  }

  /// List of distinct states that currently have registered federations
  List<String> get _registeredStates {
    final set = <String>{};
    for (final f in _federations) {
      if (f.state.trim().isNotEmpty) set.add(f.state.trim());
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  /// List of distinct districts for the currently selected state (or across all if none selected)
  List<String> get _registeredDistricts {
    final set = <String>{};
    for (final f in _federations) {
      if (_selectedStateFilter == null ||
          f.state.trim().toLowerCase() == _selectedStateFilter!.trim().toLowerCase()) {
        if (f.district.trim().isNotEmpty) set.add(f.district.trim());
      }
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  /// Count of federations in a given state
  int _getFederationCountForState(String state) {
    return _federations.where((f) => f.state.trim().toLowerCase() == state.trim().toLowerCase()).length;
  }

  /// Count of federations in a given district
  int _getFederationCountForDistrict(String district) {
    return _federations.where((f) {
      final districtMatch = f.district.trim().toLowerCase() == district.trim().toLowerCase();
      if (_selectedStateFilter == null) return districtMatch;
      return districtMatch && f.state.trim().toLowerCase() == _selectedStateFilter!.trim().toLowerCase();
    }).length;
  }

  List<FederationModel> get _filteredFederations {
    final list = _federations.where((f) {
      // State filter
      if (_selectedStateFilter != null && _selectedStateFilter!.isNotEmpty) {
        if (f.state.trim().toLowerCase() != _selectedStateFilter!.trim().toLowerCase()) {
          return false;
        }
      }
      // District filter
      if (_selectedDistrictFilter != null && _selectedDistrictFilter!.isNotEmpty) {
        if (f.district.trim().toLowerCase() != _selectedDistrictFilter!.trim().toLowerCase()) {
          return false;
        }
      }
      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = f.name.toLowerCase().contains(q);
        final matchState = f.state.toLowerCase().contains(q);
        final matchDistrict = f.district.toLowerCase().contains(q);
        final matchCity = f.city.toLowerCase().contains(q);
        final matchReg = (f.registrationNo ?? '').toLowerCase().contains(q);
        final matchCode = (f.federationCode ?? '').toLowerCase().contains(q);
        if (!matchName && !matchState && !matchDistrict && !matchCity && !matchReg && !matchCode) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sorting based on states, districts, and names
    list.sort((a, b) {
      switch (_selectedSortOption) {
        case 'state_asc':
          final s = a.state.toLowerCase().compareTo(b.state.toLowerCase());
          if (s != 0) return s;
          final d = a.district.toLowerCase().compareTo(b.district.toLowerCase());
          if (d != 0) return d;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'state_desc':
          final s = b.state.toLowerCase().compareTo(a.state.toLowerCase());
          if (s != 0) return s;
          final d = a.district.toLowerCase().compareTo(b.district.toLowerCase());
          if (d != 0) return d;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'district_asc':
          final d = a.district.toLowerCase().compareTo(b.district.toLowerCase());
          if (d != 0) return d;
          final s = a.state.toLowerCase().compareTo(b.state.toLowerCase());
          if (s != 0) return s;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'district_desc':
          final d = b.district.toLowerCase().compareTo(a.district.toLowerCase());
          if (d != 0) return d;
          final s = a.state.toLowerCase().compareTo(b.state.toLowerCase());
          if (s != 0) return s;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name_desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'name_asc':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return list;
  }

  List<Map<String, dynamic>> get _filteredAdmins {
    final list = _allAdmins.where((admin) {
      final fed = _getFederationForAdmin(admin);

      // State filter
      if (_selectedStateFilter != null && _selectedStateFilter!.isNotEmpty) {
        if (fed == null || fed.state.trim().toLowerCase() != _selectedStateFilter!.trim().toLowerCase()) {
          return false;
        }
      }

      // District filter
      if (_selectedDistrictFilter != null && _selectedDistrictFilter!.isNotEmpty) {
        if (fed == null || fed.district.trim().toLowerCase() != _selectedDistrictFilter!.trim().toLowerCase()) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final name = (admin['full_name'] ?? '').toString().toLowerCase();
        final email = (admin['email'] ?? '').toString().toLowerCase();
        final phone = (admin['phone'] ?? '').toString().toLowerCase();
        final fedName = (admin['federation_name'] ?? '').toString().toLowerCase();
        final matchFed = fed != null && (fed.state.toLowerCase().contains(q) || fed.district.toLowerCase().contains(q));
        if (!name.contains(q) && !email.contains(q) && !phone.contains(q) && !fedName.contains(q) && !matchFed) {
          return false;
        }
      }

      return true;
    }).toList();

    list.sort((a, b) {
      final fedA = _getFederationForAdmin(a);
      final fedB = _getFederationForAdmin(b);
      final nameA = (a['full_name'] ?? '').toString().toLowerCase();
      final nameB = (b['full_name'] ?? '').toString().toLowerCase();

      switch (_selectedSortOption) {
        case 'state_asc':
          final stateA = fedA?.state.toLowerCase() ?? '';
          final stateB = fedB?.state.toLowerCase() ?? '';
          final s = stateA.compareTo(stateB);
          if (s != 0) return s;
          return nameA.compareTo(nameB);
        case 'state_desc':
          final stateA = fedA?.state.toLowerCase() ?? '';
          final stateB = fedB?.state.toLowerCase() ?? '';
          final s = stateB.compareTo(stateA);
          if (s != 0) return s;
          return nameA.compareTo(nameB);
        case 'district_asc':
          final distA = fedA?.district.toLowerCase() ?? '';
          final distB = fedB?.district.toLowerCase() ?? '';
          final d = distA.compareTo(distB);
          if (d != 0) return d;
          return nameA.compareTo(nameB);
        case 'district_desc':
          final distA = fedA?.district.toLowerCase() ?? '';
          final distB = fedB?.district.toLowerCase() ?? '';
          final d = distB.compareTo(distA);
          if (d != 0) return d;
          return nameA.compareTo(nameB);
        case 'name_desc':
          return nameB.compareTo(nameA);
        case 'name_asc':
        default:
          return nameA.compareTo(nameB);
      }
    });

    return list;
  }

  bool get _isFilterActive =>
      _selectedStateFilter != null ||
      _selectedDistrictFilter != null ||
      _searchQuery.trim().isNotEmpty ||
      _selectedSortOption != 'state_asc';

  void _resetFilters() {
    setState(() {
      _selectedStateFilter = null;
      _selectedDistrictFilter = null;
      _searchController.clear();
      _searchQuery = '';
      _selectedSortOption = 'state_asc';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFederations();
  }

  Future<void> _loadFederations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _federations = await FederationModel.fetchAllFederations(forceRefresh: true);

      // Load assigned federation admins
      try {
        _allAdmins = await DI.adminRepo.getFederationAdmins();
        _federationAdminsMap = {};
        for (final admin in _allAdmins) {
          final fedId = admin['federation_id']?.toString().trim().toLowerCase() ?? '';
          if (fedId.isNotEmpty) {
            _federationAdminsMap.putIfAbsent(fedId, () => []).add(admin);
          }
          final fedName = admin['federation_name']?.toString().trim().toLowerCase() ?? '';
          if (fedName.isNotEmpty) {
            _federationAdminsMap.putIfAbsent(fedName, () => []).add(admin);
          }
        }
      } catch (e) {
        debugPrint('[SuperAdminFederations] loadAdmins error: $e');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _federations = List.from(FederationModel.defaultFederations);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PROVISION FEDERATION ADMIN DIALOG
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _showProvisionAdminDialog({FederationModel? preselectedFederation}) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: _generateRandomPassword());
    bool obscurePassword = false;
    bool isSubmitting = false;

    // Geographic datasets
    final List<String> countries = ['India'];
    String selectedCountry = 'India';

    // All 36 States & UTs of India from IndiaGeographyService
    final List<String> states = IndiaGeographyService.states;

    String selectedState = preselectedFederation?.state ?? (states.contains('Maharashtra') ? 'Maharashtra' : states.first);

    // Official districts for selected state
    List<String> getDistrictsForState(String state) {
      final dists = IndiaGeographyService.getDistricts(state);
      if (dists.isNotEmpty) return dists;
      return ['Pune', 'Nashik', 'Mumbai City', 'Nagpur', 'Chhatrapati Sambhajinagar'];
    }

    List<String> currentDistricts = getDistrictsForState(selectedState);
    String selectedDistrict = preselectedFederation?.district ?? (currentDistricts.isNotEmpty ? currentDistricts.first : 'Pune');

    // Federations for selected state and district
    List<FederationModel> getFederationsForDistrict(String state, String district) {
      final list = _federations.where((f) => f.state == state && f.district.toLowerCase() == district.toLowerCase()).toList();
      if (list.isEmpty) {
        return _federations.where((f) => f.state == state).toList();
      }
      return list;
    }

    List<FederationModel> matchingFederations = getFederationsForDistrict(selectedState, selectedDistrict);
    FederationModel? selectedFederation = preselectedFederation ?? (matchingFederations.isNotEmpty ? matchingFederations.first : null);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF374151))),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_add_alt_1, color: AppColors.secondaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Provision Federation Admin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Issue official login credentials & geographic scope', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Geographic Routing
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.public, color: AppColors.secondaryContainer, size: 14),
                              SizedBox(width: 6),
                              Text('Geographic Cooperative Assignment', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Country
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCountry,
                                  dropdownColor: const Color(0xFF1F2937),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(
                                    labelText: 'Country',
                                    labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedCountry = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // State
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedState,
                                  dropdownColor: const Color(0xFF1F2937),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(
                                    labelText: 'State *',
                                    labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedState = val;
                                        currentDistricts = getDistrictsForState(selectedState);
                                        selectedDistrict = currentDistricts.isNotEmpty ? currentDistricts.first : '';
                                        matchingFederations = getFederationsForDistrict(selectedState, selectedDistrict);
                                        selectedFederation = matchingFederations.isNotEmpty ? matchingFederations.first : null;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // District Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: currentDistricts.contains(selectedDistrict) ? selectedDistrict : (currentDistricts.isNotEmpty ? currentDistricts.first : null),
                            dropdownColor: const Color(0xFF1F2937),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: currentDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedDistrict = val;
                                  matchingFederations = getFederationsForDistrict(selectedState, selectedDistrict);
                                  selectedFederation = matchingFederations.isNotEmpty ? matchingFederations.first : null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          // Federation Dropdown
                          DropdownButtonFormField<FederationModel>(
                            initialValue: matchingFederations.contains(selectedFederation) ? selectedFederation : (matchingFederations.isNotEmpty ? matchingFederations.first : null),
                            dropdownColor: const Color(0xFF1F2937),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'Assigned Cooperative Federation *',
                              labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: matchingFederations.map((f) {
                              return DropdownMenuItem(
                                value: f,
                                child: Text('${f.name} (${f.registrationNo ?? f.city})', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() => selectedFederation = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Admin Official Credentials
                    const Text('Official Account Details', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Official Full Name *',
                        hintText: 'e.g. Devesh Ambekar',
                        labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                        prefixIcon: Icon(Icons.badge_outlined, color: Colors.white54, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Official Email (Login ID) *',
                        hintText: 'e.g. admin@punecoop.gov.in',
                        labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.white54, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. +91 98220 12345',
                        labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.white54, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Initial Password *',
                        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 18),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.white54, size: 18),
                              onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                              tooltip: 'Toggle Password Visibility',
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: AppColors.secondaryContainer, size: 18),
                              onPressed: () => setDialogState(() => passwordCtrl.text = _generateRandomPassword()),
                              tooltip: 'Generate New Password',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 14),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Role FEDERATION_ADMIN will be assigned with isolation to the selected cooperative.',
                              style: TextStyle(color: Colors.blueAccent, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final password = passwordCtrl.text.trim();
                        final name = nameCtrl.text.trim();

                        if (name.isEmpty || email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please fill all required fields: Name, Email, Password.')),
                          );
                          return;
                        }
                        if (!email.contains('@') || !email.contains('.')) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid official email.')),
                          );
                          return;
                        }
                        if (password.length < 6) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Password must be at least 6 characters.')),
                          );
                          return;
                        }
                        if (selectedFederation == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please select an assigned Cooperative Federation.')),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        try {
                          await DI.adminRepo.createFederationAdmin(
                            email: email,
                            password: password,
                            fullName: name,
                            phone: phoneCtrl.text.trim(),
                            federationId: selectedFederation!.id,
                          );

                          AuditLogService.logFederationAction(
                            action: 'PROVISION_ADMIN',
                            federationId: selectedFederation!.id,
                            newValue: {
                              'admin_name': name,
                              'admin_email': email,
                              'federation_name': selectedFederation!.name,
                              'district': selectedDistrict,
                              'state': selectedState,
                            },
                            reason: 'Super Admin provisioned new Federation Admin login',
                          );

                          if (ctx.mounted) Navigator.pop(ctx);

                          // Reload state
                          await _loadFederations();

                          if (mounted) {
                            _showProvisionSuccessModal(
                              email: email,
                              password: password,
                              name: name,
                              federationName: selectedFederation!.name,
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(backgroundColor: Colors.red, content: Text('Error provisioning admin: $e')),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 16),
                          SizedBox(width: 6),
                          Text('Issue Admin Login', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProvisionSuccessModal({
    required String email,
    required String password,
    required String name,
    required String federationName,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.green)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 10),
            Text('Admin Account Issued', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Federation Admin account successfully created for $name.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF374151)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCredentialRow('Official Email', email),
                  const SizedBox(height: 6),
                  _buildCredentialRow('Initial Password', password),
                  const SizedBox(height: 6),
                  _buildCredentialRow('Assigned Cooperative', federationName),
                  const SizedBox(height: 6),
                  _buildCredentialRow('Access Level', 'Federation Admin (Scoped)'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The administrator can now sign in at /login/admin using these credentials.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text('$label:', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500))),
        Expanded(child: SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  static String _generateRandomPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%*';
    final rand = Random.secure();
    return List.generate(10, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RESET / CHANGE PASSWORD DIALOG
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _showResetPasswordDialog(Map<String, dynamic> admin) async {
    final userId = admin['user_id']?.toString() ?? admin['id']?.toString() ?? '';
    final email = admin['email']?.toString() ?? '';
    final fullName = admin['full_name']?.toString() ?? 'Admin';
    final passwordCtrl = TextEditingController(text: _generateRandomPassword());
    bool obscurePassword = false;
    bool requirePasswordChange = true;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF374151)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_reset, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reset Admin Password',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set new credentials for $fullName',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(email, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('New Password *', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter at least 6 characters',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                      prefixIcon: const Icon(Icons.key, color: Colors.white54, size: 18),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.white54, size: 18),
                            onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                            tooltip: 'Toggle Password Visibility',
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.amber, size: 18),
                            onPressed: () => setDialogState(() => passwordCtrl.text = _generateRandomPassword()),
                            tooltip: 'Generate Strong Password',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: requirePasswordChange,
                      onChanged: (val) => setDialogState(() => requirePasswordChange = val ?? true),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.secondaryContainer,
                      title: const Text(
                        'Require password change upon next login',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'The administrator will be prompted to set their own password immediately after signing in.',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newPw = passwordCtrl.text.trim();
                        if (newPw.length < 6) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Password must be at least 6 characters.')),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          await DI.adminRepo.resetFederationAdminPassword(
                            userId: userId.isNotEmpty ? userId : email,
                            newPassword: newPw,
                            requirePasswordChange: requirePasswordChange,
                          );

                          AuditLogService.log(
                            action: 'RESET_ADMIN_PASSWORD',
                            entityType: 'USER',
                            entityId: userId,
                            reason: 'Super Admin reset federation admin password for $fullName',
                          );

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (mounted) {
                            _showPasswordResetSuccessModal(
                              email: email,
                              newPassword: newPw,
                              name: fullName,
                              requiresChange: requirePasswordChange,
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(backgroundColor: Colors.red, content: Text('Error resetting password: $e')),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 16),
                          SizedBox(width: 6),
                          Text('Set New Password', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPasswordResetSuccessModal({
    required String email,
    required String newPassword,
    required String name,
    required bool requiresChange,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.amber),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.amber, size: 24),
            SizedBox(width: 10),
            Text('Password Reset Complete', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New password successfully configured for $name.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF374151)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCredentialRow('Official Email', email),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 130, child: Text('New Password:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500))),
                      Expanded(child: SelectableText(newPassword, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold))),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: Colors.amber),
                        tooltip: 'Copy to Clipboard',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: newPassword));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Password copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildCredentialRow('Must Change', requiresChange ? 'Yes (Upon next sign-in)' : 'No'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please share this temporary password securely with the administrator.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CHANGE ADMIN / REASSIGN SCOPE DIALOG
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _showChangeAdminDialog({
    required Map<String, dynamic> admin,
    FederationModel? currentFederation,
  }) async {
    final userId = admin['user_id']?.toString() ?? admin['id']?.toString() ?? '';
    final email = admin['email']?.toString() ?? '';
    final initialName = admin['full_name']?.toString() ?? '';
    final initialPhone = admin['phone']?.toString() ?? '';
    final currentFedId = currentFederation?.id ?? admin['federation_id']?.toString() ?? '';

    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController(text: initialPhone);
    bool isSubmitting = false;

    // Geographic datasets
    final List<String> states = IndiaGeographyService.states;
    String selectedCountry = 'India';
    String selectedState = currentFederation?.state ?? (states.contains('Maharashtra') ? 'Maharashtra' : states.first);

    List<String> getDistrictsForState(String state) {
      final dists = IndiaGeographyService.getDistricts(state);
      if (dists.isNotEmpty) return dists;
      return ['Pune', 'Nashik', 'Mumbai City', 'Nagpur', 'Chhatrapati Sambhajinagar'];
    }

    List<String> currentDistricts = getDistrictsForState(selectedState);
    String selectedDistrict = currentFederation?.district ?? (currentDistricts.isNotEmpty ? currentDistricts.first : 'Pune');

    List<FederationModel> getFederationsForDistrict(String state, String district) {
      final list = _federations.where((f) => f.state == state && f.district.toLowerCase() == district.toLowerCase()).toList();
      if (list.isEmpty) {
        return _federations.where((f) => f.state == state).toList();
      }
      return list;
    }

    List<FederationModel> matchingFederations = getFederationsForDistrict(selectedState, selectedDistrict);
    FederationModel? selectedFederation = currentFederation ??
        _federations.where((f) => f.id == currentFedId).firstOrNull ??
        (matchingFederations.isNotEmpty ? matchingFederations.first : null);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF374151)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF38BDF8), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Change Admin Assignment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Update administrator profile and cooperative federation scope', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Details
                    const Text('Official Account Details', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Login ID', style: TextStyle(color: Colors.white54, fontSize: 9)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Official Full Name *',
                        labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                        prefixIcon: Icon(Icons.badge_outlined, color: Colors.white54, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.white54, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Geographic Cooperative Scope Reassignment
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.corporate_fare, color: Color(0xFF38BDF8), size: 14),
                              SizedBox(width: 6),
                              Text('Assigned Cooperative Federation Scope', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCountry,
                                  dropdownColor: const Color(0xFF1F2937),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(
                                    labelText: 'Country',
                                    labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: ['India'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedCountry = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedState,
                                  dropdownColor: const Color(0xFF1F2937),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(
                                    labelText: 'State *',
                                    labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedState = val;
                                        currentDistricts = getDistrictsForState(selectedState);
                                        selectedDistrict = currentDistricts.isNotEmpty ? currentDistricts.first : '';
                                        matchingFederations = getFederationsForDistrict(selectedState, selectedDistrict);
                                        selectedFederation = matchingFederations.isNotEmpty ? matchingFederations.first : null;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: currentDistricts.contains(selectedDistrict) ? selectedDistrict : (currentDistricts.isNotEmpty ? currentDistricts.first : null),
                            dropdownColor: const Color(0xFF1F2937),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: currentDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedDistrict = val;
                                  matchingFederations = getFederationsForDistrict(selectedState, selectedDistrict);
                                  selectedFederation = matchingFederations.isNotEmpty ? matchingFederations.first : null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<FederationModel>(
                            initialValue: matchingFederations.contains(selectedFederation) ? selectedFederation : (matchingFederations.isNotEmpty ? matchingFederations.first : null),
                            dropdownColor: const Color(0xFF1F2937),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'Assigned Cooperative Federation *',
                              labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: matchingFederations.map((f) {
                              return DropdownMenuItem(
                                value: f,
                                child: Text('${f.name} (${f.registrationNo ?? f.city})', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() => selectedFederation = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        final newPhone = phoneCtrl.text.trim();

                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter admin full name.')),
                          );
                          return;
                        }
                        if (selectedFederation == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please select an assigned Cooperative Federation.')),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          final targetId = userId.isNotEmpty ? userId : email;

                          // 1. If assigned cooperative changed, reassign
                          if (selectedFederation!.id != currentFedId) {
                            await DI.adminRepo.reassignFederationAdmin(
                              userId: targetId,
                              newFederationId: selectedFederation!.id,
                              oldFederationId: currentFedId.isNotEmpty ? currentFedId : null,
                            );

                            AuditLogService.logFederationAction(
                              action: 'REASSIGN_ADMIN',
                              federationId: selectedFederation!.id,
                              oldValue: {'old_federation_id': currentFedId},
                              newValue: {
                                'new_federation_id': selectedFederation!.id,
                                'federation_name': selectedFederation!.name,
                                'admin_email': email,
                                'admin_name': newName,
                              },
                              reason: 'Super Admin changed federation admin assignment',
                            );
                          }

                          // 2. If name or phone changed, update profile details
                          if (newName != initialName || newPhone != initialPhone) {
                            await DI.adminRepo.updateFederationAdminDetails(
                              userId: targetId,
                              fullName: newName,
                              phone: newPhone,
                            );
                          }

                          if (ctx.mounted) Navigator.pop(ctx);

                          await _loadFederations();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green,
                                content: Text('✓ $newName assigned to ${selectedFederation!.name}!'),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(backgroundColor: Colors.red, content: Text('Error updating admin: $e')),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 16),
                          SizedBox(width: 6),
                          Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REMOVE FROM AUTHORIZED ADMINS CONFIRMATION
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _showRemoveAdminConfirmation({
    required Map<String, dynamic> admin,
    required FederationModel federation,
  }) async {
    final userId = admin['user_id']?.toString() ?? admin['id']?.toString() ?? '';
    final email = admin['email']?.toString() ?? '';
    final fullName = admin['full_name']?.toString() ?? 'Admin';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEF4444)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Remove from Authorized', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Revoke administrator permissions', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Are you sure you want to remove $fullName ($email) from authorized administrators for ${federation.name}?\n\nThis will immediately revoke their administrative access to this cooperative.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final targetId = userId.isNotEmpty ? userId : email;
                          await DI.adminRepo.removeFederationAdmin(
                            userId: targetId,
                            federationId: federation.id,
                          );

                          AuditLogService.logFederationAction(
                            action: 'REMOVE_ADMIN',
                            federationId: federation.id,
                            oldValue: {
                              'user_id': targetId,
                              'admin_name': fullName,
                              'admin_email': email,
                              'federation_name': federation.name,
                            },
                            reason: 'Super Admin removed admin authorization from cooperative',
                          );

                          if (ctx.mounted) Navigator.pop(ctx);

                          await _loadFederations();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text('✓ $fullName removed from authorized administrators.'),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(backgroundColor: Colors.red, content: Text('Error removing admin: $e')),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Remove Authorization', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdminActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ADD FEDERATION DIALOG
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _showAddFederationDialog() async {
    final nameCtrl = TextEditingController();
    final regNoCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    String selectedState = 'Maharashtra';
    List<String> availableDistricts = IndiaGeographyService.getDistricts(selectedState);
    String selectedDistrict = availableDistricts.isNotEmpty ? availableDistricts.first : 'Pune';
    List<String> availableCities = IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
    String selectedCity = availableCities.isNotEmpty ? availableCities.first : selectedDistrict;
    bool isResolvingPincode = false;
    String? pincodeFeedback;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> handlePincode(String val) async {
            final clean = val.replaceAll(RegExp(r'\D'), '').trim();
            if (clean.length == 6) {
              setDialogState(() {
                isResolvingPincode = true;
                pincodeFeedback = 'Resolving postal area...';
              });
              final res = await IndiaGeographyService.lookupPincode(clean);
              if (res != null) {
                setDialogState(() {
                  selectedState = res.state;
                  availableDistricts = IndiaGeographyService.getDistricts(res.state);
                  selectedDistrict = availableDistricts.contains(res.district)
                      ? res.district
                      : (availableDistricts.isNotEmpty ? availableDistricts.first : res.district);
                  final areas = res.areas.isNotEmpty
                      ? res.areas
                      : IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
                  availableCities = areas;
                  selectedCity = areas.isNotEmpty ? areas.first : res.city;
                  isResolvingPincode = false;
                  pincodeFeedback = 'Detected: $selectedDistrict, $selectedState (${res.isFromNetwork ? "Live Post Office" : "Postal Directory"})';
                });
              } else {
                setDialogState(() {
                  isResolvingPincode = false;
                  pincodeFeedback = null;
                });
              }
            } else {
              if (pincodeFeedback != null) {
                setDialogState(() => pincodeFeedback = null);
              }
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            title: const Row(
              children: [
                Icon(Icons.corporate_fare, color: AppColors.secondaryContainer),
                SizedBox(width: 8),
                Text('Register New Federation', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Federation / Cooperative Name *',
                        hintText: 'e.g. Pune District Labour Cooperative Federation',
                        labelStyle: TextStyle(color: Colors.white60),
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // PIN Code & State Dropdown
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'PIN Code',
                              hintText: '411038',
                              counterText: '',
                              labelStyle: const TextStyle(color: Colors.white60),
                              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: isResolvingPincode
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryContainer)),
                                    )
                                  : (pincodeFeedback != null
                                      ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                                      : null),
                            ),
                            onChanged: handlePincode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: IndiaGeographyService.states.contains(selectedState)
                                ? selectedState
                                : IndiaGeographyService.states.first,
                            dropdownColor: const Color(0xFF1F2937),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'State *',
                              labelStyle: TextStyle(color: Colors.white60),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: IndiaGeographyService.states.map((st) {
                              return DropdownMenuItem(
                                value: st,
                                child: Text(st, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedState = val;
                                  availableDistricts = IndiaGeographyService.getDistricts(val);
                                  selectedDistrict = availableDistricts.isNotEmpty ? availableDistricts.first : 'Pune';
                                  availableCities = IndiaGeographyService.getAreasForDistrict(val, selectedDistrict);
                                  selectedCity = availableCities.isNotEmpty ? availableCities.first : selectedDistrict;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    if (pincodeFeedback != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        pincodeFeedback!,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF81C784), fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // District & City / HQ Dropdowns
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('fed_dist_${selectedState}_$selectedDistrict'),
                            initialValue: availableDistricts.contains(selectedDistrict)
                                ? selectedDistrict
                                : (availableDistricts.isNotEmpty ? availableDistricts.first : null),
                            dropdownColor: const Color(0xFF1F2937),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              labelStyle: TextStyle(color: Colors.white60),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableDistricts.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedDistrict = val;
                                  availableCities = IndiaGeographyService.getAreasForDistrict(selectedState, val);
                                  selectedCity = availableCities.isNotEmpty ? availableCities.first : val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('fed_city_${selectedDistrict}_$selectedCity'),
                            initialValue: availableCities.contains(selectedCity)
                                ? selectedCity
                                : (availableCities.isNotEmpty ? availableCities.first : null),
                            dropdownColor: const Color(0xFF1F2937),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'HQ / City / Area *',
                              labelStyle: TextStyle(color: Colors.white60),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableCities.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedCity = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: regNoCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Registration Number',
                        labelStyle: TextStyle(color: Colors.white60),
                        border: OutlineInputBorder(),
                        hintText: 'e.g. MH-COOP-2024-001',
                        hintStyle: TextStyle(color: Colors.white30),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
                        labelStyle: TextStyle(color: Colors.white60),
                        border: OutlineInputBorder(),
                        hintText: 'e.g. +91 98220 12345',
                        hintStyle: TextStyle(color: Colors.white30),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: Colors.black),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please enter federation name.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Register Federation'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final newId = FederationModel.generateNextFederationId(_federations);
      final newFed = FederationModel(
        id: newId,
        name: nameCtrl.text.trim(),
        state: selectedState,
        district: selectedDistrict,
        city: selectedCity.isNotEmpty ? selectedCity : selectedDistrict,
        registrationNo: regNoCtrl.text.trim().isNotEmpty ? regNoCtrl.text.trim() : null,
        contactPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
        isActive: true,
      );

      if (!AppConfig.useMockData) {
        try {
          final client = Supabase.instance.client;
          await client.from('federations').insert({
            'id': newId,
            'name': newFed.name,
            'state': newFed.state,
            'district': newFed.district,
            'city': newFed.city,
            'registration_no': newFed.registrationNo,
            'contact_phone': newFed.contactPhone,
            'is_active': true,
          });
        } catch (e) {
          debugPrint('[SuperAdminFederations] DB insert note: $e');
        }
      }

      AuditLogService.logFederationAction(
        action: 'CREATE',
        federationId: newId,
        newValue: newFed.toJson(),
        reason: 'New cooperative federation registered by Super Admin',
      );

      FederationModel.invalidateCache();
      setState(() {
        _federations.insert(0, newFed);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('✓ ${newFed.name} successfully registered!'),
          ),
        );
      }
    }
  }

  Future<void> _toggleFederationStatus(FederationModel fed) async {
    final newActive = !fed.isActive;
    FederationModel.invalidateCache();
    if (!AppConfig.useMockData) {
      try {
        final client = Supabase.instance.client;
        await client.from('federations').update({'is_active': newActive}).eq('id', fed.id);
      } catch (e) {
        debugPrint('[SuperAdminFederations] DB update note: $e');
      }
    }

    AuditLogService.logFederationAction(
      action: newActive ? 'ACTIVATE' : 'DEACTIVATE',
      federationId: fed.id,
      oldValue: {'is_active': fed.isActive},
      newValue: {'is_active': newActive},
      reason: 'Federation status toggled by Super Admin',
    );

    final idx = _federations.indexWhere((f) => f.id == fed.id);
    if (idx != -1) {
      setState(() {
        _federations[idx] = FederationModel(
          id: fed.id,
          name: fed.name,
          state: fed.state,
          district: fed.district,
          city: fed.city,
          registrationNo: fed.registrationNo,
          contactPhone: fed.contactPhone,
          contactEmail: fed.contactEmail,
          federationCode: fed.federationCode,
          isActive: newActive,
        );
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fed.name} is now ${newActive ? "Active" : "Inactive"}.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.secondaryContainer))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadFederations,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverToBoxAdapter(child: _buildFilterAndSortBar()),
                      if (_selectedView == 0) ...[
                        if (_filteredFederations.isEmpty)
                          SliverToBoxAdapter(child: _buildEmptyFilterState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildFederationCard(_filteredFederations[index]),
                                childCount: _filteredFederations.length,
                              ),
                            ),
                          ),
                      ] else ...[
                        if (_filteredAdmins.isEmpty)
                          SliverToBoxAdapter(child: _buildEmptyFilterState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildAdminDirectoryCard(_filteredAdmins[index]),
                                childCount: _filteredAdmins.length,
                              ),
                            ),
                          ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterAndSortBar() {
    final filteredCount = _selectedView == 0 ? _filteredFederations.length : _filteredAdmins.length;
    final totalCount = _selectedView == 0 ? _federations.length : _allAdmins.length;
    final entityLabel = _selectedView == 0 ? 'cooperatives' : 'admins';

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 0, AppSpacing.marginMobile, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Controls Row (Wrap for responsive behavior)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by name, district...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF161F30),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2E3B52)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6) : const Color(0xFF2E3B52),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),

              // State Filter Dropdown
              _buildStateDropdown(),

              // District Filter Dropdown
              _buildDistrictDropdown(),

              // Sort By Dropdown
              _buildSortDropdown(),

              // Reset Button (if filters active)
              if (_isFilterActive)
                InkWell(
                  onTap: _resetFilters,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_off, color: Colors.redAccent, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Reset',
                          style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Active Filters and Result Count row
          const SizedBox(height: 10),
          Row(
            children: [
              // Count badge
              Text(
                'Showing $filteredCount of $totalCount $entityLabel',
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),

              // Filter indicator chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedStateFilter != null) ...[
                        _buildFilterChip(
                          icon: Icons.map_outlined,
                          label: 'State: $_selectedStateFilter',
                          color: const Color(0xFF60A5FA),
                          onDeleted: () {
                            setState(() {
                              _selectedStateFilter = null;
                              _selectedDistrictFilter = null;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (_selectedDistrictFilter != null) ...[
                        _buildFilterChip(
                          icon: Icons.location_city_outlined,
                          label: 'District: $_selectedDistrictFilter',
                          color: const Color(0xFF34D399),
                          onDeleted: () {
                            setState(() => _selectedDistrictFilter = null);
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (_searchQuery.trim().isNotEmpty) ...[
                        _buildFilterChip(
                          icon: Icons.search,
                          label: '"${_searchQuery.trim()}"',
                          color: Colors.amber,
                          onDeleted: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                      // Sort badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_vert_rounded, color: Colors.white38, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Sort: ${_sortLabels[_selectedSortOption] ?? _selectedSortOption}',
                              style: const TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateDropdown() {
    final isSelected = _selectedStateFilter != null;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF2E3B52),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _registeredStates.contains(_selectedStateFilter) ? _selectedStateFilter : null,
          dropdownColor: const Color(0xFF1F2937),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
          isDense: true,
          hint: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, color: Color(0xFF60A5FA), size: 14),
              SizedBox(width: 6),
              Text('All States', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, color: Colors.white54, size: 14),
                  SizedBox(width: 6),
                  Text('All States', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ..._registeredStates.map((st) {
              final count = _getFederationCountForState(st);
              return DropdownMenuItem<String?>(
                value: st,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_outlined, color: Color(0xFF60A5FA), size: 13),
                    const SizedBox(width: 6),
                    Text(st, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedStateFilter = val;
              _selectedDistrictFilter = null; // Reset district when state changes
            });
          },
        ),
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    final isSelected = _selectedDistrictFilter != null;
    final districts = _registeredDistricts;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF2E3B52),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: districts.contains(_selectedDistrictFilter) ? _selectedDistrictFilter : null,
          dropdownColor: const Color(0xFF1F2937),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
          isDense: true,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_city_outlined, color: Color(0xFF34D399), size: 14),
              const SizedBox(width: 6),
              Text(
                _selectedStateFilter != null ? 'All in $_selectedStateFilter' : 'All Districts',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_city_outlined, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _selectedStateFilter != null ? 'All in $_selectedStateFilter' : 'All Districts',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ...districts.map((dist) {
              final count = _getFederationCountForDistrict(dist);
              return DropdownMenuItem<String?>(
                value: dist,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF34D399), size: 13),
                    const SizedBox(width: 6),
                    Text(dist, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() => _selectedDistrictFilter = val);
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    final isSortNonDefault = _selectedSortOption != 'state_asc';
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSortNonDefault ? Colors.amber.withValues(alpha: 0.6) : const Color(0xFF2E3B52),
          width: isSortNonDefault ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortLabels.containsKey(_selectedSortOption) ? _selectedSortOption : 'state_asc',
          dropdownColor: const Color(0xFF1F2937),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
          isDense: true,
          items: _sortLabels.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    entry.key.contains('state')
                        ? Icons.map_outlined
                        : entry.key.contains('district')
                            ? Icons.location_city_outlined
                            : Icons.badge_outlined,
                    color: Colors.amber,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedSortOption = val);
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onDeleted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: Icon(Icons.close, color: color.withValues(alpha: 0.8), size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.filter_list_off, size: 28, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedView == 0
                ? 'No cooperatives match the active filters'
                : 'No federation admins match the active filters',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedStateFilter != null || _selectedDistrictFilter != null
                ? 'No matches found in ${_selectedDistrictFilter ?? _selectedStateFilter}. Try choosing another region.'
                : 'Try adjusting your search keywords or clear the filters.',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Reset All Filters', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error!, style: AppTypography.bodyMd.copyWith(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadFederations,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 16, AppSpacing.marginMobile, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Federation Registry & Scoping',
                    style: AppTypography.titleLg.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_federations.length} cooperatives registered across India • ${_allAdmins.length} admins assigned',
                    style: AppTypography.labelSm.copyWith(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  // Provision Admin Button
                  InkWell(
                    onTap: () => _showProvisionAdminDialog(),
                    borderRadius: AppRadius.radiusSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusSm,
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_alt_1, color: Colors.amber, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Provision Admin',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Add Federation Button
                  InkWell(
                    onTap: _showAddFederationDialog,
                    borderRadius: AppRadius.radiusSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusSm,
                        border: Border.all(color: AppColors.secondaryContainer.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: AppColors.secondaryContainer, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Add Federation',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.secondaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Refresh Button
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    tooltip: 'Refresh Registry',
                    onPressed: _loadFederations,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // View Selector Pills (Cooperatives vs Federation Admins)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentTab(0, Icons.corporate_fare, 'Cooperatives (${_filteredFederations.length}${_isFilterActive ? ' / ${_federations.length}' : ''})'),
                const SizedBox(width: 6),
                _buildSegmentTab(1, Icons.admin_panel_settings, 'Federation Admins (${_filteredAdmins.length}${_isFilterActive ? ' / ${_allAdmins.length}' : ''})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, IconData icon, String title) {
    final isSelected = _selectedView == index;
    return InkWell(
      onTap: () => setState(() => _selectedView = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: const Color(0xFF3B82F6)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFederationCard(FederationModel federation) {
    final fedIdKey = federation.id.trim().toLowerCase();
    final fedNameKey = federation.name.trim().toLowerCase();
    final rawAdmins = _federationAdminsMap[fedIdKey] ??
        _federationAdminsMap[federation.id] ??
        _federationAdminsMap[fedNameKey] ??
        _allAdmins.where((a) {
          final aFedId = (a['federation_id'] ?? '').toString().trim().toLowerCase();
          final aFedName = (a['federation_name'] ?? '').toString().trim().toLowerCase();
          return (aFedId.isNotEmpty && aFedId == fedIdKey) ||
              (aFedName.isNotEmpty && (aFedName == fedNameKey || fedNameKey.contains(aFedName) || aFedName.contains(fedNameKey)));
        }).toList();

    // Deduplicate by user_id or email
    final seenKeys = <String>{};
    final assignedAdmins = rawAdmins.where((a) {
      final key = (a['user_id'] ?? a['email'] ?? a['id'] ?? '').toString().toLowerCase();
      if (key.isEmpty) return true;
      return seenKeys.add(key);
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: const Icon(Icons.corporate_fare, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      federation.name,
                      style: AppTypography.titleMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_outlined, size: 10, color: Color(0xFF60A5FA)),
                              const SizedBox(width: 4),
                              Text(federation.state, style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_city_outlined, size: 10, color: Color(0xFF34D399)),
                              const SizedBox(width: 4),
                              Text(federation.district, style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _toggleFederationStatus(federation),
                borderRadius: BorderRadius.circular(12),
                child: Tooltip(
                  message: 'Click to toggle active status',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: federation.isActive
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      federation.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: federation.isActive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildInfoChip(Icons.badge_outlined, 'Reg: ${federation.registrationNo ?? 'N/A'}'),
              _buildInfoChip(Icons.phone_outlined, federation.contactPhone ?? 'No Phone'),
              _buildInfoChip(Icons.location_city, federation.city),
            ],
          ),

          const SizedBox(height: 14),

          // Assigned Admins Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF25334D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 14, color: AppColors.secondaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          'Cooperative Admins (${assignedAdmins.length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _showProvisionAdminDialog(preselectedFederation: federation),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.secondaryContainer.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add, size: 12, color: AppColors.secondaryContainer),
                            SizedBox(width: 4),
                            Text('Assign Admin', style: TextStyle(color: AppColors.secondaryContainer, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (assignedAdmins.isNotEmpty)
                  ...assignedAdmins.map((adm) {
                    final email = adm['email'] ?? '';
                    final fullName = adm['full_name'] ?? 'Admin';
                    final phone = adm['phone'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue.withValues(alpha: 0.2),
                            child: Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                Text(email + (phone.isNotEmpty ? ' • $phone' : ''), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Authorized Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 10, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('Authorized', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              // Change Admin Pill
                              _buildAdminActionPill(
                                icon: Icons.swap_horiz_rounded,
                                label: 'Change',
                                color: const Color(0xFF38BDF8),
                                tooltip: 'Change Admin / Reassign Cooperative Scope',
                                onTap: () => _showChangeAdminDialog(admin: adm, currentFederation: federation),
                              ),

                              // Password Reset Pill
                              _buildAdminActionPill(
                                icon: Icons.key_rounded,
                                label: 'Password',
                                color: Colors.amber,
                                tooltip: 'Change / Reset Admin Password',
                                onTap: () => _showResetPasswordDialog(adm),
                              ),

                              // Remove from Authorized Pill
                              _buildAdminActionPill(
                                icon: Icons.person_remove_outlined,
                                label: 'Remove',
                                color: Colors.redAccent,
                                tooltip: 'Remove from Authorized Admins',
                                onTap: () => _showRemoveAdminConfirmation(admin: adm, federation: federation),
                              ),

                              // More Options Popup Menu
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 14, color: Colors.white54),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Admin Options',
                                color: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Color(0xFF374151)),
                                ),
                                onSelected: (val) {
                                  if (val == 'change') {
                                    _showChangeAdminDialog(admin: adm, currentFederation: federation);
                                  } else if (val == 'password') {
                                    _showResetPasswordDialog(adm);
                                  } else if (val == 'remove') {
                                    _showRemoveAdminConfirmation(admin: adm, federation: federation);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'change',
                                    height: 36,
                                    child: Row(
                                      children: [
                                        Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF38BDF8)),
                                        SizedBox(width: 8),
                                        Text('Change / Reassign Admin', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'password',
                                    height: 36,
                                    child: Row(
                                      children: [
                                        Icon(Icons.key_rounded, size: 15, color: Colors.amber),
                                        SizedBox(width: 8),
                                        Text('Change / Reset Password', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(height: 1),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    height: 36,
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove_outlined, size: 15, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Remove from Authorized', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'No dedicated administrator assigned to this cooperative yet.',
                            style: TextStyle(color: Colors.amber, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDirectoryCard(Map<String, dynamic> admin) {
    final name = admin['full_name'] ?? 'Admin';
    final email = admin['email'] ?? '';
    final phone = admin['phone'] ?? 'No Phone';
    final fedName = admin['federation_name'] ?? 'Assigned Federation';
    final scopeLevel = admin['scope_level'] ?? 'FEDERATION';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(scopeLevel, style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    SelectableText(email, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 12),
                    const Icon(Icons.phone_outlined, color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.corporate_fare, color: AppColors.secondaryContainer, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          fedName,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Builder(builder: (context) {
                        final fed = _getFederationForAdmin(admin);
                        if (fed == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${fed.district}, ${fed.state}',
                            style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 9, fontWeight: FontWeight.w500),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildAdminActionPill(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Change Scope',
                      color: const Color(0xFF38BDF8),
                      tooltip: 'Change Admin / Reassign Cooperative Scope',
                      onTap: () {
                        final fedId = admin['federation_id']?.toString() ?? '';
                        final fed = _federations.where((f) => f.id == fedId).firstOrNull;
                        _showChangeAdminDialog(admin: admin, currentFederation: fed);
                      },
                    ),
                    _buildAdminActionPill(
                      icon: Icons.key_rounded,
                      label: 'Reset Password',
                      color: Colors.amber,
                      tooltip: 'Change / Reset Admin Password',
                      onTap: () => _showResetPasswordDialog(admin),
                    ),
                    Builder(
                      builder: (ctx) {
                        final fedId = admin['federation_id']?.toString() ?? '';
                        final fed = _federations.where((f) => f.id == fedId).firstOrNull;
                        if (fed == null) return const SizedBox.shrink();
                        return _buildAdminActionPill(
                          icon: Icons.person_remove_outlined,
                          label: 'Remove from Authorized',
                          color: Colors.redAccent,
                          tooltip: 'Remove from Authorized Admins',
                          onTap: () => _showRemoveAdminConfirmation(admin: admin, federation: fed),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.labelSm.copyWith(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}
