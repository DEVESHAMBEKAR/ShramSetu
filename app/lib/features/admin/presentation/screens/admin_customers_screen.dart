import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../core/services/india_geography_service.dart';
import '../../../../core/services/shared_booking_store.dart';
import '../../data/models/admin_models.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminCustomersScreen extends StatefulWidget {
  final bool? isSuperAdmin;
  const AdminCustomersScreen({super.key, this.isSuperAdmin});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  late Future<List<AdminCustomerProfile>> _customersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Federation & Multi-Location Filtering State
  bool _isSuperAdmin = false;
  String _scopedFederationName = '';
  List<String> _authorizedFedIds = [];
  List<FederationModel> _availableFederations = [];
  String? _selectedFederationId;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedArea;
  String _sortBy = 'recent'; // 'recent', 'oldest', 'name_asc', 'bookings_high', 'district'
  bool _showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    _loadScopeAndFederations();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScopeAndFederations() async {
    try {
      final scope = DI.federationScopeService;
      final user = await DI.authRepo.getCurrentUser();
      bool isGlobal = widget.isSuperAdmin ?? false;
      List<String> authIds = [];
      String fedName = '';

      if (user != null) {
        try {
          final admins = await DI.adminRepo.getFederationAdmins();
          final myScope = admins.firstWhere(
            (a) =>
                a['user_id'] == user.id ||
                a['email']?.toString().trim().toLowerCase() == user.email?.trim().toLowerCase(),
            orElse: () => {},
          );
          if (myScope.isNotEmpty && myScope['federation_id'] != null) {
            authIds = [myScope['federation_id'].toString()];
            fedName = myScope['federation_name']?.toString() ?? '';
          }
        } catch (_) {}
      }

      if (user != null && (fedName.isEmpty || authIds.isEmpty)) {
        final emailLower = user.email?.trim().toLowerCase() ?? '';
        if (emailLower.contains('nagpur') || emailLower == 'omshinde@gmail.com') {
          authIds = ['55555555-0000-0000-0000-000000000005'];
          fedName = 'Nagpur District Shramik Cooperative Union';
        } else if (emailLower.contains('nashik') || emailLower == 'adilatar9494@gmail.com') {
          authIds = ['22222222-0000-0000-0000-000000000002'];
          fedName = 'Nashik District Artisans Cooperative Union';
        } else if (emailLower.contains('pune') || emailLower == 'ambekardevesh2@gmail.com') {
          authIds = ['11111111-0000-0000-0000-000000000001'];
          fedName = 'Pune District Labour Cooperative Federation';
        } else if (emailLower == 'deveshambekar@gmail.com') {
          isGlobal = true;
          fedName = 'National Cooperative Federation Pool';
        }
      }

      if (scope != null) {
        if (widget.isSuperAdmin != null) {
          isGlobal = widget.isSuperAdmin!;
        } else {
          isGlobal = await scope.hasGlobalScope();
        }
        if (authIds.isEmpty) {
          authIds = await scope.getAuthorizedFederationIds();
        }

        List<FederationModel> feds = await FederationModel.fetchAllFederations();
        if (feds.isEmpty) {
          feds = List.from(FederationModel.defaultFederations);
        }

        if (!isGlobal && authIds.isNotEmpty && fedName.isEmpty) {
          final matched = feds.where((f) => authIds.contains(f.id)).firstOrNull;
          if (matched != null) {
            fedName = matched.name;
          }
        }

        if (mounted) {
          setState(() {
            _isSuperAdmin = isGlobal;
            _availableFederations = feds;
            _scopedFederationName = fedName;
            _authorizedFedIds = authIds;
          });
          _refreshData();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableFederations = List.from(FederationModel.defaultFederations);
          _scopedFederationName = '';
          _authorizedFedIds = [];
        });
      }
    }
  }

  void _refreshData() {
    setState(() {
      _customersFuture = DI.adminRepo.getCustomers();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedFederationId = null;
      _selectedState = null;
      _selectedDistrict = null;
      _selectedArea = null;
      _sortBy = 'recent';
      _searchController.clear();
      _searchQuery = '';
    });
  }

  bool get _hasActiveFilters =>
      _selectedFederationId != null ||
      _selectedState != null ||
      _selectedDistrict != null ||
      _selectedArea != null ||
      _sortBy != 'recent' ||
      _searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminCustomerProfile>>(
      future: _customersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Failed to load customers: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final allCustomers = snapshot.data ?? [];

        // Apply filters
        var filteredList = allCustomers.where((c) {
          // Search query filter
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matches = c.name.toLowerCase().contains(q) ||
                c.phone.toLowerCase().contains(q) ||
                (c.email?.toLowerCase().contains(q) ?? false) ||
                (c.city?.toLowerCase().contains(q) ?? false) ||
                (c.district?.toLowerCase().contains(q) ?? false) ||
                (c.federationName?.toLowerCase().contains(q) ?? false);
            if (!matches) return false;
          }

          // Federation filter (Super Admin)
          if (_selectedFederationId != null) {
            final fed = _availableFederations.firstWhere(
              (f) => f.id == _selectedFederationId,
              orElse: () => FederationModel.resolveFederation(federationId: _selectedFederationId),
            );
            final matchesFed = c.federationId == _selectedFederationId ||
                (c.federationName?.toLowerCase().contains(fed.name.toLowerCase()) ?? false) ||
                (c.district?.toLowerCase() == fed.district.toLowerCase());
            if (!matchesFed) return false;
          }

          // State filter
          if (_selectedState != null) {
            final cState = c.state?.toLowerCase() ?? 'maharashtra';
            if (cState != _selectedState!.toLowerCase()) return false;
          }

          // District filter
          if (_selectedDistrict != null) {
            final cDist = c.district?.toLowerCase() ?? '';
            if (cDist != _selectedDistrict!.toLowerCase()) return false;
          }

          // Area filter
          if (_selectedArea != null) {
            final a = _selectedArea!.toLowerCase();
            final matchesArea = (c.city?.toLowerCase().contains(a) ?? false) ||
                (c.area?.toLowerCase().contains(a) ?? false);
            if (!matchesArea) return false;
          }

          return true;
        }).toList();

        // STRICT FEDERATION ACCESS ISOLATION:
        // A Federation Admin can ONLY view customers within their assigned federation jurisdiction/bookings.
        if (!_isSuperAdmin) {
          final scopedIds = _authorizedFedIds;
          final scopedName = _scopedFederationName.toLowerCase();

          if (scopedIds.isEmpty && scopedName.isEmpty) {
            filteredList = [];
          } else {
            filteredList = filteredList.where((c) {
              if (c.federationId != null && c.federationId!.isNotEmpty) {
                return scopedIds.contains(c.federationId);
              }

              final fed = (c.federationName ?? '').toLowerCase();
              final dist = (c.district ?? '').toLowerCase();

              for (final otherFed in _availableFederations) {
                if (!scopedIds.contains(otherFed.id)) {
                  final oName = otherFed.name.toLowerCase();
                  final oDist = otherFed.district.toLowerCase();
                  if ((oName.isNotEmpty && fed.contains(oName)) ||
                      (oDist.isNotEmpty && dist == oDist)) {
                    return false;
                  }
                }
              }

              if (scopedName.isNotEmpty && fed.contains(scopedName)) {
                return true;
              }
              for (final fid in scopedIds) {
                final matched = _availableFederations.where((f) => f.id == fid).firstOrNull;
                if (matched != null && matched.district.toLowerCase() == dist && dist.isNotEmpty) {
                  return true;
                }
              }

              return false;
            }).toList();
          }
        }

        // Apply sorting
        filteredList.sort((a, b) {
          switch (_sortBy) {
            case 'oldest':
              final aDate = a.createdAt ?? DateTime(0);
              final bDate = b.createdAt ?? DateTime(0);
              return aDate.compareTo(bDate);
            case 'name_asc':
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            case 'bookings_high':
              return b.totalBookings.compareTo(a.totalBookings);
            case 'district':
              final aDist = a.district ?? a.city ?? '';
              final bDist = b.district ?? b.city ?? '';
              return aDist.toLowerCase().compareTo(bDist.toLowerCase());
            case 'recent':
            default:
              final aDate = a.createdAt ?? a.lastBooking;
              final bDate = b.createdAt ?? b.lastBooking;
              return bDate.compareTo(aDate);
          }
        });

        final totalBookingsSum = filteredList.fold<int>(0, (sum, c) => sum + c.totalBookings);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              _isSuperAdmin ? 'Customer Management (All Federations)' : 'Cooperative Customer Directory',
              style: AppTypography.titleLg.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh Customers',
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: _refreshData,
              ),
            ],
          ),
          body: Column(
            children: [
              // Scope banner (Locked for Federation Admin, Global sorting bar for Super Admin)
              if (!_isSuperAdmin)
                _buildFederationScopeLockedBanner()
              else
                _buildSuperAdminMultiLocationFilterBar(),

              _buildSearchBar(),

              // Active filter chips (ONLY shown for Super Admin when filters are active)
              if (_isSuperAdmin && _hasActiveFilters) _buildActiveFilterChipsBar(filteredList.length),

              // Summary Stats Row
              _buildStatsHeader(filteredList.length, totalBookingsSum),

              Expanded(
                child: filteredList.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => _refreshData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.marginMobile),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final customer = filteredList[index];
                            return _buildCustomerCard(customer);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Banner displayed to Federation Admin confirming strict customer isolation
  Widget _buildFederationScopeLockedBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF0FDF4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Color(0xFF166534), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _scopedFederationName.isNotEmpty ? _scopedFederationName : 'Federation Jurisdiction',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Text('LOCKED SCOPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Exclusive jurisdiction: You can only view customers located within or serviced by your cooperative federation.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF14532D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Multi-location & federation control bar for Super Admin
  Widget _buildSuperAdminMultiLocationFilterBar() {
    final districts = _selectedState != null
        ? IndiaGeographyService.getDistricts(_selectedState)
        : IndiaGeographyService.getDistricts('Maharashtra');

    final areas = _selectedDistrict != null
        ? IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict)
        : <String>[];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF4338CA).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.public, color: Color(0xFF4338CA), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Super Admin National Customer Oversight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    Text(
                      'Cross-federation directory • ${_availableFederations.length} federations available',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: _showAdvancedFilters ? const Color(0xFFE2E8F0) : Colors.transparent,
                ),
                onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
                icon: Icon(_showAdvancedFilters ? Icons.tune : Icons.tune_outlined, size: 16, color: const Color(0xFF4338CA)),
                label: Text(_showAdvancedFilters ? 'Hide Filters' : 'Filters & Sorting', style: const TextStyle(fontSize: 12, color: Color(0xFF4338CA), fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          if (_showAdvancedFilters) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Federation Dropdown
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedFederationId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Federation Partition',
                      labelStyle: const TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Federations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      ..._availableFederations.map((fed) => DropdownMenuItem<String?>(
                            value: fed.id,
                            child: Text(fed.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedFederationId = val),
                  ),
                ),

                // State Dropdown (36 states & UTs)
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedState,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'State / UT',
                      labelStyle: const TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All States', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      ...IndiaGeographyService.states.map((st) => DropdownMenuItem<String?>(
                            value: st,
                            child: Text(st, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedState = val;
                        _selectedDistrict = null;
                        _selectedArea = null;
                      });
                    },
                  ),
                ),

                // District Dropdown (cascading)
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedDistrict,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'District',
                      labelStyle: const TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Districts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      ...districts.map((dist) => DropdownMenuItem<String?>(
                            value: dist,
                            child: Text(dist, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedDistrict = val;
                        _selectedArea = null;
                      });
                    },
                  ),
                ),

                // Area / City Dropdown
                if (areas.isNotEmpty)
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedArea,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Area / City',
                        labelStyle: const TextStyle(fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Areas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        ...areas.map((ar) => DropdownMenuItem<String?>(
                              value: ar,
                              child: Text(ar, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedArea = val),
                    ),
                  ),

                // Sort Dropdown
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Sort By',
                      labelStyle: const TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'recent', child: Text('Sort: Most Recent', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest First', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'name_asc', child: Text('Sort: Name (A-Z)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'bookings_high', child: Text('Sort: Most Bookings', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'district', child: Text('Sort: Location / District', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _sortBy = val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFilterChipsBar(int resultCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('$resultCount customer${resultCount == 1 ? '' : 's'}:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
            const SizedBox(width: 8),
            if (_selectedFederationId != null) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Fed: ${_availableFederations.firstWhere((f) => f.id == _selectedFederationId, orElse: () => FederationModel.resolveFederation(federationId: _selectedFederationId)).name}', style: const TextStyle(fontSize: 10)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _selectedFederationId = null),
              ),
              const SizedBox(width: 4),
            ],
            if (_selectedState != null) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('State: $_selectedState', style: const TextStyle(fontSize: 10)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() {
                  _selectedState = null;
                  _selectedDistrict = null;
                  _selectedArea = null;
                }),
              ),
              const SizedBox(width: 4),
            ],
            if (_selectedDistrict != null) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('District: $_selectedDistrict', style: const TextStyle(fontSize: 10)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() {
                  _selectedDistrict = null;
                  _selectedArea = null;
                }),
              ),
              const SizedBox(width: 4),
            ],
            if (_selectedArea != null) ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Area: $_selectedArea', style: const TextStyle(fontSize: 10)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _selectedArea = null),
              ),
              const SizedBox(width: 4),
            ],
            if (_sortBy != 'recent') ...[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Sorted: $_sortBy', style: const TextStyle(fontSize: 10)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _sortBy = 'recent'),
              ),
              const SizedBox(width: 4),
            ],
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: _resetFilters,
              child: const Text('Reset All', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Customer Name, Phone, Email, Location, Federation...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.outline),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.outline),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
    );
  }

  Widget _buildStatsHeader(int totalCount, int totalBookings) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.group, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$totalCount', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Text('Total Customers', style: TextStyle(fontSize: 10, color: AppColors.outline), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 18, color: Color(0xFF166534)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$totalBookings', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                        const Text('Orders Placed', style: TextStyle(fontSize: 10, color: AppColors.outline), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(AdminCustomerProfile customer) {
    final locationText = [customer.area, customer.city, customer.district, customer.state]
        .where((s) => s != null && s.isNotEmpty)
        .toSet()
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceVariant,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusContainerFromString(customer.status),
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Text(
                            customer.status,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.statusTextColorFromString(customer.status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 12, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          customer.phone,
                          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        if (customer.email != null && customer.email!.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.email_outlined, size: 12, color: AppColors.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.email!,
                              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Metadata row: Location & Federation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.federationName != null && customer.federationName!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.account_balance, size: 14, color: Color(0xFF4338CA)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.federationName!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            locationText.isNotEmpty ? Icons.location_on : Icons.location_off_outlined,
                            size: 14,
                            color: locationText.isNotEmpty ? AppColors.outline : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: locationText.isNotEmpty
                                ? Text(
                                    locationText,
                                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFFCD34D)),
                                    ),
                                    child: const Text(
                                      'Location Unregistered • Tap Edit to Assign',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Text(
                        '${customer.totalBookings} Booking${customer.totalBookings == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons: Edit Details & Inspect/Modify Orders
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showEditCustomerModal(customer),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text(
                    'Change Details',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showCustomerBookingsSheet(customer),
                  icon: const Icon(Icons.receipt_long, size: 14),
                  label: Text(
                    'Orders (${customer.totalBookings})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dialog to edit customer credentials, location, and federation assignment
  void _showEditCustomerModal(AdminCustomerProfile customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone);
    final emailCtrl = TextEditingController(text: customer.email ?? '');
    final addrCtrl = TextEditingController(text: customer.area ?? customer.city ?? '');

    String selectedState = (customer.state != null && customer.state!.isNotEmpty)
        ? customer.state!
        : 'Maharashtra';
    List<String> districts = IndiaGeographyService.getDistricts(selectedState);
    String selectedDistrict = (customer.district != null && districts.contains(customer.district))
        ? customer.district!
        : (districts.isNotEmpty ? districts.first : 'Pune');
    List<String> areas = IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
    String selectedArea = (customer.area != null && areas.contains(customer.area))
        ? customer.area!
        : (areas.isNotEmpty ? areas.first : (customer.city ?? ''));

    String? selectedFedId = customer.federationId;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.manage_accounts, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Customer Details — ${customer.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Credentials
                    const Text('Account Credentials (Required)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.outline)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number *',
                              prefixIcon: Icon(Icons.phone_outlined, size: 18),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address *',
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Location Details
                    const Text('Location & Jurisdiction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.outline)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // State Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedState,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: IndiaGeographyService.allStates.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedState = val;
                                  districts = IndiaGeographyService.getDistricts(val);
                                  selectedDistrict = districts.isNotEmpty ? districts.first : '';
                                  areas = IndiaGeographyService.getAreasForDistrict(val, selectedDistrict);
                                  selectedArea = areas.isNotEmpty ? areas.first : '';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // District Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDistrict,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'District',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedDistrict = val;
                                  areas = IndiaGeographyService.getAreasForDistrict(selectedState, val);
                                  selectedArea = areas.isNotEmpty ? areas.first : '';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addrCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Area / Street Address *',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                        hintText: 'e.g. Kothrud, Shivaji Nagar, College Road...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Federation Partition Assignment
                    const Text('Assigned Cooperative Federation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.outline)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: selectedFedId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Federation Jurisdiction',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Auto-resolve from Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                        ),
                        ..._availableFederations.map((fed) => DropdownMenuItem<String?>(
                              value: fed.id,
                              child: Text(fed.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setDialogState(() => selectedFedId = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final addr = addrCtrl.text.trim();

                        if (name.isEmpty || phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Full name and mobile number are required.')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          await DI.adminRepo.updateCustomerDetails(
                            customerId: customer.id,
                            fullName: name,
                            phone: phone,
                            email: email.isNotEmpty ? email : null,
                            state: selectedState,
                            district: selectedDistrict,
                            city: selectedDistrict,
                            area: addr.isNotEmpty ? addr : selectedArea,
                            address: addr,
                            federationId: selectedFedId,
                          );

                          if (mounted) {
                            Navigator.pop(dialogCtx);
                            _refreshData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Customer details and location updated for $name.')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update details: $e')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Details'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Bottom sheet inspecting customer's booking history and enabling order modifications
  void _showCustomerBookingsSheet(AdminCustomerProfile customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order History: ${customer.name}',
                                  style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                Text(
                                  '${customer.phone} • ${customer.email ?? "No email"}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.outline),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      Expanded(
                        child: FutureBuilder<List<JobRequest>>(
                          future: DI.adminRepo.getBookings(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                            }
                            final allBookings = snapshot.data ?? [];
                            final customerBookings = allBookings.where((b) {
                              final phoneMatch = b.customerPhone.replaceAll(RegExp(r'\D'), '') == customer.phone.replaceAll(RegExp(r'\D'), '');
                              final nameMatch = b.customerName.trim().toLowerCase() == customer.name.trim().toLowerCase();
                              final idMatch = b.customerId == customer.id;
                              return idMatch || phoneMatch || (nameMatch && b.customerName.isNotEmpty);
                            }).toList();

                            if (customerBookings.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.outline),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No orders found for ${customer.name}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'When this customer books services or dispatches karigars, orders will appear here for admin management.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: AppColors.outline),
                                      ),
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          // Create a demo booking for customer to inspect immediately
                                          final newBooking = JobRequest(
                                            id: 'ORD-${DateTime.now().millisecondsSinceEpoch % 10000}',
                                            customerId: customer.id,
                                            customerName: customer.name,
                                            customerLocation: [customer.area, customer.city].where((s) => s != null && s.isNotEmpty).join(', ').isNotEmpty
                                                ? [customer.area, customer.city].where((s) => s != null && s.isNotEmpty).join(', ')
                                                : 'Pune West',
                                            customerPhone: customer.phone,
                                            serviceName: 'Electrical Inspection & Repair',
                                            date: 'Today',
                                            time: '02:00 PM',
                                            baseAmount: 399.0,
                                            laborAllowance: 80.0,
                                            status: BookingStatus.pending,
                                            createdAt: 'Just now',
                                            workerName: 'Ganesh Shinde',
                                            federationName: customer.federationName,
                                          );
                                          await SharedBookingStore.instance.updateBookingStatus(newBooking.id, BookingStatus.pending);
                                          setSheetState(() {});
                                          _refreshData();
                                        },
                                        icon: const Icon(Icons.add_task, size: 16),
                                        label: const Text('Create Direct Order for Customer'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: customerBookings.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final booking = customerBookings[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.outlineVariant),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Order #${booking.id}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.statusContainerFromString(booking.status.label),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              booking.status.label,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.statusTextColorFromString(booking.status.label),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.handyman_outlined, size: 14, color: AppColors.outline),
                                          const SizedBox(width: 4),
                                          Text(booking.serviceName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.engineering_outlined, size: 14, color: AppColors.outline),
                                          const SizedBox(width: 4),
                                          Text('Karigar: ${booking.workerName ?? "Assigned Artisan"}', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.outline),
                                          const SizedBox(width: 4),
                                          Text('${booking.date} at ${booking.time}', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                          const Spacer(),
                                          Text('₹${booking.totalAmount.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              foregroundColor: AppColors.primary,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            ),
                                            onPressed: () {
                                              _showModifyBookingDialog(
                                                booking,
                                                onModified: () {
                                                  setSheetState(() {});
                                                  _refreshData();
                                                },
                                              );
                                            },
                                            icon: const Icon(Icons.tune, size: 14),
                                            label: const Text('Modify Order Status / Time', style: TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Dialog to modify a specific customer order (status, scheduled time/date, notes)
  void _showModifyBookingDialog(JobRequest booking, {VoidCallback? onModified}) {
    BookingStatus selectedStatus = booking.status;
    final dateCtrl = TextEditingController(text: booking.date);
    final timeCtrl = TextEditingController(text: booking.time);
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Modify Order #${booking.id}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service: ${booking.serviceName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('Customer: ${booking.customerName}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                  const SizedBox(height: 14),

                  // Status Dropdown
                  DropdownButtonFormField<BookingStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Order Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: BookingStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.label, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Scheduled Date
                  TextField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Scheduled Date',
                      prefixIcon: Icon(Icons.calendar_month, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Scheduled Time
                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Scheduled Time',
                      prefixIcon: Icon(Icons.access_time, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Admin Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Admin Modification Remarks / Instructions',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setModalState(() => isSaving = true);
                        try {
                          await DI.adminRepo.modifyBooking(
                            bookingId: booking.id,
                            status: selectedStatus,
                            scheduledDate: dateCtrl.text.trim(),
                            scheduledTime: timeCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                          );
                          await DI.adminRepo.updateBookingStatus(booking.id, selectedStatus);

                          if (mounted) {
                            Navigator.pop(dialogCtx);
                            onModified?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Order #${booking.id} modified successfully.')),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update order: $e')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Order Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_outlined, size: 54, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No customers match "$_searchQuery"' : 'No customers in this federation partition',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Customers who place bookings or register in this jurisdiction will appear here.',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _resetFilters,
              child: const Text('Reset All Filters'),
            ),
          ],
        ],
      ),
    );
  }
}
