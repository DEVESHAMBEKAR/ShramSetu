import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../core/services/india_geography_service.dart';
import '../../../worker/data/models/worker_models.dart';
import 'admin_worker_verification_detail_screen.dart';

class AdminWorkersScreen extends StatefulWidget {
  final bool? isSuperAdmin;
  const AdminWorkersScreen({super.key, this.isSuperAdmin});

  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  late Future<List<WorkerProfile>> _workersFuture;
  int _selectedFilterIndex = 1; // 0: All, 1: Pending, 2: Under Review, 3: Changes Required, 4: Approved, 5: Rejected, 6: Suspended
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Federation & Multi-Location Filtering & Sorting State
  bool _isSuperAdmin = false;
  String _scopedFederationName = '';
  List<String> _authorizedFedIds = [];
  List<FederationModel> _availableFederations = [];
  String? _selectedFederationId;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedArea;
  String _sortBy = 'recent'; // 'recent', 'oldest', 'name_asc', 'name_desc', 'federation', 'location', 'rating', 'experience'
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

      // 1. Authoritative check: match admin in getFederationAdmins() (matching AdminProfileScreen & AdminMainLayout)
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
      }

      // Load federations list
      List<FederationModel> feds = await FederationModel.fetchAllFederations();
      if (feds.isEmpty) {
        feds = List.from(FederationModel.defaultFederations);
      }

      if (!isGlobal && authIds.isNotEmpty && fedName.isEmpty) {
        final matched = feds.where((f) => authIds.contains(f.id)).firstOrNull;
        if (matched != null) {
          fedName = matched.name;
        } else if (scope != null) {
          final desc = await scope.getScopeDescription();
          if (desc.isNotEmpty && !desc.startsWith('No ') && !desc.startsWith('All ')) {
            fedName = desc;
          }
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
      _workersFuture = DI.adminRepo.getWorkers();
    });
  }

  Future<void> _openDetailScreen(WorkerProfile worker) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminWorkerVerificationDetailScreen(
          worker: worker,
          isSuperAdmin: _isSuperAdmin,
        ),
      ),
    );
    _refreshData();
  }

  Future<void> _approveWorker(WorkerProfile worker) async {
    if (!_isSuperAdmin) {
      String wFedId = worker.federationRefId ?? '';
      if (wFedId.isEmpty) {
        wFedId = FederationModel.resolveFederation(
          federationId: worker.federationRefId,
          federationName: worker.guildName,
          district: worker.district,
          city: worker.city,
          location: worker.serviceLocation,
          address: worker.address,
        ).id;
      }
      if (!_authorizedFedIds.contains(wFedId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Access Denied: You can only approve artisans allocated to your cooperative federation.'),
          ),
        );
        return;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.onTertiaryContainer),
            SizedBox(width: 8),
            Text('Approve Artisan'),
          ],
        ),
        content: Text(
          'Are you sure you want to approve ${worker.name}? Their trade credentials and documents will be marked as verified, granting them immediate access to receive customer jobs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.adminRepo.approveWorker(worker.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.onTertiaryContainer,
              content: Text('✓ ${worker.name} approved! Full access granted.'),
            ),
          );
        }
        _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve worker: $e')),
          );
        }
      }
    }
  }

  Future<void> _rejectWorker(WorkerProfile worker) async {
    if (!_isSuperAdmin) {
      String wFedId = worker.federationRefId ?? '';
      if (wFedId.isEmpty) {
        wFedId = FederationModel.resolveFederation(
          federationId: worker.federationRefId,
          federationName: worker.guildName,
          district: worker.district,
          city: worker.city,
          location: worker.serviceLocation,
          address: worker.address,
        ).id;
      }
      if (!_authorizedFedIds.contains(wFedId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Access Denied: You can only reject artisans allocated to your cooperative federation.'),
          ),
        );
        return;
      }
    }
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error),
            SizedBox(width: 8),
            Text('Reject Application'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject the application for ${worker.name}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.adminRepo.rejectWorker(worker.id, remarks: reasonController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Application for ${worker.name} marked as rejected.')),
          );
        }
        _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reject worker: $e')),
          );
        }
      }
    }
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
    return FutureBuilder<List<WorkerProfile>>(
      future: _workersFuture,
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
                  Text('Failed to load workers: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final rawWorkers = snapshot.data ?? [];
        // STRICT FEDERATION ACCESS ISOLATION AT THE ROOT:
        // A Federation Admin can ONLY view and count workers from their own assigned federation.
        final List<WorkerProfile> allWorkers;
        if (!_isSuperAdmin) {
          final scopedIds = _authorizedFedIds;
          if (scopedIds.isEmpty) {
            allWorkers = [];
          } else {
            allWorkers = rawWorkers.where((w) {
              String fedId = w.federationRefId ?? '';
              if (fedId.isEmpty) {
                fedId = FederationModel.resolveFederation(
                  federationId: w.federationRefId,
                  federationName: w.guildName,
                  district: w.district,
                  city: w.city,
                  location: w.serviceLocation,
                  address: w.address,
                ).id;
              }
              return scopedIds.contains(fedId);
            }).toList();
          }
        } else {
          allWorkers = rawWorkers;
        }

        final pendingWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();
        final underReviewWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.underReview).toList();
        final changesRequiredWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.changesRequired).toList();
        final approvedWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.approved).toList();
        final rejectedWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.rejected).toList();
        final suspendedWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.suspended).toList();

        List<WorkerProfile> filteredByStatus;
        switch (_selectedFilterIndex) {
          case 1:
            filteredByStatus = pendingWorkers;
            break;
          case 2:
            filteredByStatus = underReviewWorkers;
            break;
          case 3:
            filteredByStatus = changesRequiredWorkers;
            break;
          case 4:
            filteredByStatus = approvedWorkers;
            break;
          case 5:
            filteredByStatus = rejectedWorkers;
            break;
          case 6:
            filteredByStatus = suspendedWorkers;
            break;
          case 0:
          default:
            filteredByStatus = allWorkers;
            break;
        }

        // Apply Super Admin & Area filters
        var filteredList = filteredByStatus.where((w) {
          // Search query filter
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchesSearch = w.name.toLowerCase().contains(q) ||
                w.phone.toLowerCase().contains(q) ||
                w.id.toLowerCase().contains(q) ||
                (w.trade?.toLowerCase().contains(q) ?? false) ||
                (w.primarySkill?.toLowerCase().contains(q) ?? false) ||
                w.federationName.toLowerCase().contains(q) ||
                w.serviceLocation.toLowerCase().contains(q) ||
                (w.district?.toLowerCase().contains(q) ?? false);
            if (!matchesSearch) return false;
          }

          // Federation filter (for Super Admin)
          if (_selectedFederationId != null) {
            final fed = _availableFederations.firstWhere(
              (f) => f.id == _selectedFederationId,
              orElse: () => FederationModel.resolveFederation(federationId: _selectedFederationId),
            );
            final matchesFed = w.federationRefId == _selectedFederationId ||
                w.federationName.toLowerCase().contains(fed.name.toLowerCase()) ||
                w.guildName.toLowerCase().contains(fed.name.toLowerCase());
            if (!matchesFed) return false;
          }

          // State filter
          if (_selectedState != null) {
            final wState = w.state?.toLowerCase() ?? 'maharashtra';
            if (wState != _selectedState!.toLowerCase()) return false;
          }

          // District filter
          if (_selectedDistrict != null) {
            final wDist = w.district?.toLowerCase() ?? '';
            if (wDist != _selectedDistrict!.toLowerCase()) return false;
          }

          // Area filter
          if (_selectedArea != null) {
            final a = _selectedArea!.toLowerCase();
            final matchesArea = w.serviceLocation.toLowerCase().contains(a) ||
                (w.city?.toLowerCase().contains(a) ?? false) ||
                (w.address?.toLowerCase().contains(a) ?? false);
            if (!matchesArea) return false;
          }

          return true;
        }).toList();

        // STRICT FEDERATION ACCESS ISOLATION:
        // A Federation Admin can ONLY view worker applications from their own assigned federation.
        // Worker applications from another federation or unassigned workers are strictly hidden.
        if (!_isSuperAdmin) {
          final scopedIds = _authorizedFedIds;

          // If this admin has no assigned federation scope yet, show zero workers
          if (scopedIds.isEmpty) {
            filteredList = [];
          } else {
            filteredList = filteredList.where((w) {
              // Direct strict match on federationRefId only
              if (w.federationRefId == null || w.federationRefId!.isEmpty) {
                return false; // Exclude unassigned workers from federation admin view
              }
              return scopedIds.contains(w.federationRefId);
            }).toList();
          }
        }

        // Apply sorting
        filteredList.sort((a, b) {
          switch (_sortBy) {
            case 'oldest':
              final aDate = a.registeredAt ?? DateTime(0);
              final bDate = b.registeredAt ?? DateTime(0);
              return aDate.compareTo(bDate);
            case 'name_asc':
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            case 'name_desc':
              return b.name.toLowerCase().compareTo(a.name.toLowerCase());
            case 'federation':
              return a.federationName.toLowerCase().compareTo(b.federationName.toLowerCase());
            case 'location':
              final aLoc = (a.district ?? a.serviceLocation).toLowerCase();
              final bLoc = (b.district ?? b.serviceLocation).toLowerCase();
              return aLoc.compareTo(bLoc);
            case 'rating':
              return b.rating.compareTo(a.rating);
            case 'experience':
              final aExp = int.tryParse(a.experience.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final bExp = int.tryParse(b.experience.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              return bExp.compareTo(aExp);
            case 'recent':
            default:
              final aDate = a.registeredAt ?? DateTime(0);
              final bDate = b.registeredAt ?? DateTime(0);
              return bDate.compareTo(aDate);
          }
        });

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              _isSuperAdmin ? 'Artisan Verification (All Federations)' : 'Artisan Verification & Guild Desk',
              style: AppTypography.titleLg.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
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

              _buildFilterBar(
                allCount: allWorkers.length,
                pendingCount: pendingWorkers.length,
                underReviewCount: underReviewWorkers.length,
                changesRequiredCount: changesRequiredWorkers.length,
                approvedCount: approvedWorkers.length,
                rejectedCount: rejectedWorkers.length,
                suspendedCount: suspendedWorkers.length,
              ),

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
                            final worker = filteredList[index];
                            return _buildWorkerCard(worker);
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

  /// Banner displayed to Federation Admin confirming strict isolation
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
                  'Exclusive jurisdiction: You can only access and verify artisans registered under your cooperative federation.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF14532D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive multi-location & federation control bar for Super Admin
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
                    const Text('Super Admin Multi-Location & Federation Sorting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    Text(
                      'Cross-federation oversight • ${_availableFederations.length} federations available',
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
                    initialValue: _selectedFederationId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Cooperative Federation',
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
                    initialValue: _selectedState,
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
                    initialValue: _selectedDistrict,
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
                      initialValue: _selectedArea,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Area / Sub-locality',
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
                    initialValue: _sortBy,
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
                      DropdownMenuItem(value: 'name_desc', child: Text('Sort: Name (Z-A)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'federation', child: Text('Sort: Federation Name', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'location', child: Text('Sort: Location / District', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'rating', child: Text('Sort: Highest Rating', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'experience', child: Text('Sort: Most Experienced', style: TextStyle(fontSize: 12))),
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

  /// Active filter chips bar with quick clear
  Widget _buildActiveFilterChipsBar(int resultCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('$resultCount artisan${resultCount == 1 ? '' : 's'} matching:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Name, Phone, ID, Trade, Cooperative, Area...',
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

  Widget _buildFilterBar({
    required int allCount,
    required int pendingCount,
    required int underReviewCount,
    required int changesRequiredCount,
    required int approvedCount,
    required int rejectedCount,
    required int suspendedCount,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(0, 'All ($allCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(1, 'Pending ($pendingCount)', hasBadge: pendingCount > 0, badgeColor: const Color(0xFFFFB74D)),
            const SizedBox(width: 8),
            _buildFilterChip(2, 'Under Review ($underReviewCount)', hasBadge: underReviewCount > 0, badgeColor: const Color(0xFF64B5F6)),
            const SizedBox(width: 8),
            _buildFilterChip(3, 'Changes Required ($changesRequiredCount)', hasBadge: changesRequiredCount > 0, badgeColor: const Color(0xFFFFB74D)),
            const SizedBox(width: 8),
            _buildFilterChip(4, 'Approved ($approvedCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(5, 'Rejected ($rejectedCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(6, 'Suspended ($suspendedCount)'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, {bool hasBadge = false, Color? badgeColor}) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: hasBadge && badgeColor != null ? badgeColor : AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLow,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (hasBadge && badgeColor != null ? Colors.brown.shade900 : Colors.white)
            : AppColors.onSurfaceVariant,
      ),
      onSelected: (_) => setState(() => _selectedFilterIndex = index),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No artisans found';
    if (_searchQuery.isNotEmpty) {
      message = 'No artisans match "$_searchQuery"';
    } else if (_selectedFilterIndex == 1) {
      message = '🎉 No pending applications awaiting verification!';
    } else if (_selectedFilterIndex == 2) {
      message = 'No applications currently under review';
    } else if (_selectedFilterIndex == 3) {
      message = 'No change requests currently pending';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_turned_in_outlined, size: 54, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          const Text(
            'New registrations will appear here for federation officer review.',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _resetFilters,
              child: const Text('Clear All Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkerCard(WorkerProfile worker) {
    final status = worker.verificationStatus;
    final isPending = status == VerificationStatus.pending;
    final isUnderReview = status == VerificationStatus.underReview;

    return InkWell(
      onTap: () => _openDetailScreen(worker),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending || isUnderReview ? const Color(0xFFFFB74D) : AppColors.outlineVariant,
            width: isPending || isUnderReview ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryContainer,
                  backgroundImage: worker.profileImage.isNotEmpty ? NetworkImage(worker.profileImage) : null,
                  child: worker.profileImage.isEmpty
                      ? Text(
                          worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              worker.name,
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getVerifBgColor(worker.verificationStatus),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getVerifLabel(worker.verificationStatus),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getVerifTextColor(worker.verificationStatus),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${worker.trade?.isNotEmpty == true ? worker.trade! : (worker.skills.isNotEmpty ? worker.skills.join(", ") : "Artisan")} • ${worker.skillLevel?.isNotEmpty == true ? worker.skillLevel! : worker.experience}',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${worker.phone} • ${worker.serviceLocation}',
                        style: const TextStyle(fontSize: 11, color: AppColors.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (worker.verificationRemarks?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Remarks: ${worker.verificationRemarks}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Federation and Geographic Location Badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance, size: 14, color: Color(0xFF4338CA)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          worker.federationName.isNotEmpty ? worker.federationName : (worker.guildId != "None" ? worker.guildId : "Pune Federation"),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF312E81)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${worker.district ?? worker.serviceLocation}, ${worker.state ?? "Maharashtra"}${worker.pincode != null ? " • ${worker.pincode}" : ""}',
                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Jobs: ${worker.completedJobs}',
                        style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: AppColors.starRating),
                          const SizedBox(width: 2),
                          Text(
                            worker.rating > 0 ? worker.rating.toStringAsFixed(1) : 'New',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _openDetailScreen(worker),
                    icon: const Icon(Icons.folder_shared_outlined, size: 16),
                    label: const Text('View File & Review', style: TextStyle(fontSize: 12)),
                  ),
                ),
                if (isPending || isUnderReview) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _approveWorker(worker),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                    onPressed: () => _rejectWorker(worker),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getVerifLabel(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return 'VERIFIED ACTIVE';
      case VerificationStatus.underReview:
        return 'UNDER REVIEW';
      case VerificationStatus.changesRequired:
        return 'CHANGES REQ';
      case VerificationStatus.rejected:
        return 'REJECTED';
      case VerificationStatus.suspended:
        return 'SUSPENDED';
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        return 'PENDING';
    }
  }

  Color _getVerifBgColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.tertiaryContainer;
      case VerificationStatus.underReview:
        return const Color(0xFFBBDEFB);
      case VerificationStatus.changesRequired:
        return const Color(0xFFFFE082);
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        return const Color(0xFFFFE0B2);
      case VerificationStatus.rejected:
      case VerificationStatus.suspended:
        return AppColors.errorContainer;
    }
  }

  Color _getVerifTextColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.onTertiaryContainer;
      case VerificationStatus.underReview:
        return const Color(0xFF1565C0);
      case VerificationStatus.changesRequired:
        return const Color(0xFFE65100);
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        return const Color(0xFFE65100);
      case VerificationStatus.rejected:
      case VerificationStatus.suspended:
        return AppColors.onErrorContainer;
    }
  }
}
