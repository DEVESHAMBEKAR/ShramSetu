import '../../../../core/config/dependency_injection.dart';
import '../../../../core/config/app_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/booking_models.dart';
import '../../../../shared/widgets/shramsetu_brand_mark.dart';
import '../../../../core/services/india_geography_service.dart';
import 'booking_confirmation_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  String _paymentMode = 'upi';
  bool _isSubmitting = false;
  String? _pendingBookingId;
  Razorpay? _razorpay;
  String? _customerAddressText;
  String? _customerAddressId;

  @override
  void initState() {
    super.initState();
    _loadCustomerAddress();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  Future<void> _loadCustomerAddress() async {
    // If address is already selected in booking flow state, honor it as the source of truth
    if (bookingFlowState.address != null && bookingFlowState.address!.isNotEmpty) {
      setState(() {
        _customerAddressText = bookingFlowState.address;
        _customerAddressId = bookingFlowState.addressId;
      });
      return;
    }

    try {
      final user = await DI.authRepo.getCurrentUser();
      String? userId = user?.id;
      if (userId == null && !AppConfig.useMockData) {
        try {
          userId = AppConfig.supabaseClient.auth.currentUser?.id;
        } catch (_) {}
      }
      if (userId != null) {
        final defAddr = await DI.userRepo.getDefaultAddress(userId);
        if (defAddr != null && mounted) {
          setState(() {
            _customerAddressId = defAddr.id;
            _customerAddressText = '${defAddr.addressLine}, ${defAddr.area.isNotEmpty ? "${defAddr.area}, " : ""}${defAddr.city} - ${defAddr.postalCode}';
            bookingFlowState.addressId = defAddr.id;
            bookingFlowState.address = _customerAddressText;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _showAddressSelectionModal() async {
    final user = await DI.authRepo.getCurrentUser();
    String? userId = user?.id;
    if (userId == null && !AppConfig.useMockData) {
      try {
        userId = AppConfig.supabaseClient.auth.currentUser?.id;
      } catch (_) {}
    }
    if (userId == null) return;

    final addresses = await DI.userRepo.getUserAddresses(userId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Service Address', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (addresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No saved addresses found. Please add a new service address below.', style: AppTypography.bodySm),
                    )
                  else
                    ...addresses.map((a) {
                      final isSelected = a.id == _customerAddressId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant),
                          borderRadius: AppRadius.radiusMd,
                          color: isSelected ? AppColors.surfaceContainerLow : Colors.white,
                        ),
                        child: ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.location_on_outlined,
                            color: isSelected ? AppColors.primary : AppColors.outline,
                          ),
                          title: Text(a.addressLine, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          subtitle: Text('${a.area.isNotEmpty ? "${a.area}, " : ""}${a.city} - ${a.postalCode}', style: AppTypography.bodySm),
                          onTap: () {
                            setState(() {
                              _customerAddressId = a.id;
                              _customerAddressText = '${a.addressLine}, ${a.area.isNotEmpty ? "${a.area}, " : ""}${a.city} - ${a.postalCode}';
                              bookingFlowState.addressId = a.id;
                              bookingFlowState.address = _customerAddressText;
                              bookingFlowState.latitude = a.latitude;
                              bookingFlowState.longitude = a.longitude;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New Address'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        _showAddNewAddressDialog(userId!);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddNewAddressDialog(String userId) {
    final lineCtrl = TextEditingController();
    final zipCtrl = TextEditingController();

    String selectedState = 'Maharashtra';
    String selectedDistrict = 'Pune';
    List<String> availableDistricts = IndiaGeographyService.getDistricts(selectedState);
    List<String> availableAreas = IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
    String selectedArea = availableAreas.isNotEmpty ? availableAreas.first : 'Kothrud';
    bool isResolvingPincode = false;
    String? pincodeFeedback;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) {
          Future<void> handlePincode(String val) async {
            final clean = val.replaceAll(RegExp(r'\D'), '').trim();
            if (clean.length == 6) {
              setDlgState(() {
                isResolvingPincode = true;
                pincodeFeedback = 'Resolving location...';
              });
              final res = await IndiaGeographyService.lookupPincode(clean);
              if (res != null) {
                setDlgState(() {
                  selectedState = res.state;
                  availableDistricts = IndiaGeographyService.getDistricts(res.state);
                  selectedDistrict = availableDistricts.contains(res.district)
                      ? res.district
                      : (availableDistricts.isNotEmpty ? availableDistricts.first : res.district);
                  final areas = res.areas.isNotEmpty
                      ? res.areas
                      : IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
                  availableAreas = areas;
                  selectedArea = areas.isNotEmpty ? areas.first : res.city;
                  isResolvingPincode = false;
                  pincodeFeedback = 'Detected: $selectedDistrict, $selectedState (${res.isFromNetwork ? "Live Post Office" : "Postal Directory"})';
                });
              } else {
                setDlgState(() {
                  isResolvingPincode = false;
                  pincodeFeedback = null;
                });
              }
            } else {
              if (pincodeFeedback != null) {
                setDlgState(() => pincodeFeedback = null);
              }
            }
          }

          return AlertDialog(
            title: const Text('New Service Address'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: lineCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Flat / Building / Street *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: zipCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: 'PIN Code *',
                              counterText: '',
                              border: const OutlineInputBorder(),
                              hintText: '411038',
                              isDense: true,
                              suffixIcon: isResolvingPincode
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
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
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'State *',
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
                                setDlgState(() {
                                  selectedState = val;
                                  availableDistricts = IndiaGeographyService.getDistricts(val);
                                  selectedDistrict = availableDistricts.isNotEmpty ? availableDistricts.first : 'Pune';
                                  availableAreas = IndiaGeographyService.getAreasForDistrict(val, selectedDistrict);
                                  selectedArea = availableAreas.isNotEmpty ? availableAreas.first : selectedDistrict;
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
                        style: const TextStyle(fontSize: 10, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('bk_dist_${selectedState}_$selectedDistrict'),
                            initialValue: availableDistricts.contains(selectedDistrict)
                                ? selectedDistrict
                                : (availableDistricts.isNotEmpty ? availableDistricts.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'District *',
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
                                setDlgState(() {
                                  selectedDistrict = val;
                                  availableAreas = IndiaGeographyService.getAreasForDistrict(selectedState, val);
                                  selectedArea = availableAreas.isNotEmpty ? availableAreas.first : val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('bk_area_${selectedDistrict}_$selectedArea'),
                            initialValue: availableAreas.contains(selectedArea)
                                ? selectedArea
                                : (availableAreas.isNotEmpty ? availableAreas.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Area / Locality *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableAreas.map((a) {
                              return DropdownMenuItem(
                                value: a,
                                child: Text(a, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => selectedArea = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (lineCtrl.text.trim().isEmpty || zipCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields.')));
                    return;
                  }
                  Navigator.pop(dlgCtx);
                  try {
                    final created = await DI.userRepo.createAddress(
                      userId: userId,
                      addressLine: lineCtrl.text.trim(),
                      area: selectedArea,
                      city: selectedDistrict,
                      state: selectedState,
                      postalCode: zipCtrl.text.trim(),
                    );
                    setState(() {
                      _customerAddressId = created.id;
                      _customerAddressText = created.displayString;
                      bookingFlowState.addressId = created.id;
                      bookingFlowState.address = created.displayString;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service address saved and selected.')));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save Address'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingBookingId == null) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      // CRITICAL: Verify payment server-side — never trust client callback alone
      final verified = await DI.paymentRepo.verifyPayment(
        bookingId: _pendingBookingId!,
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (!mounted) return;

      if (verified) {
        final bookingId = _pendingBookingId!;
        _pendingBookingId = null;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(bookingId: bookingId),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification failed. Please contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingBookingId = null;
    if (!mounted) return;
    final msg = response.message ?? 'Payment cancelled or failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: $msg'),
        backgroundColor: Colors.red,
      ),
    );
    setState(() => _isSubmitting = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallets (Paytm etc.) redirect externally — treat as pending
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redirecting to ${response.walletName}...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = bookingFlowState.selectedWorker!;
    
    // Transparent Gazette cooperative tariff breakdown
    final baseVisit = (worker.rate * 0.65).round();
    final laborAllowance = worker.rate - baseVisit;
    final cess = (worker.rate * 0.02).round().clamp(9, 99);
    final total = worker.rate + cess;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          color: AppColors.surfaceContainerLowest,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const TricolorStripe(height: 3.5),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const ShramSetuBrandMark(compact: true, showText: false, height: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Escrow Milestone Detail',
                                style: AppTypography.titleMd.copyWith(
                                  color: AppColors.primaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'श्रम व रोजगार मंत्रालय • DPI',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: AppColors.onPrimary, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Sovereign Gazette Reference Banner
          _buildSovereignGazetteBanner(worker),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              children: [
                // 1. Assigned Guild Artisan Card
                _buildAssignedGuildArtisanCard(worker),

                const SizedBox(height: 12),

                // 2. Sovereign Gazette Approved Tariff Schedule
                _buildGazetteApprovedTariffSchedule(baseVisit, laborAllowance, cess, total),

                const SizedBox(height: 12),

                // 3. Digital India Sovereign Escrow Guarantee Callout
                _buildDigitalIndiaSovereignEscrowCallout(total, worker.name.split(' ').first),

                const SizedBox(height: 12),

                // 4. Payment Modes Selection (Sovereign Gateway)
                _buildPaymentGatewaySelection(),

                const SizedBox(height: 12),

                // 5. Co-op Guarantee Badge Card
                _buildNationalShramikGuaranteeBadge(),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Bottom Escrow Action Dock
          _buildBottomEscrowAction(total, worker),
        ],
      ),
    );
  }

  Widget _buildSovereignGazetteBanner(dynamic worker) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, size: 16, color: AppColors.tertiaryFixed),
              const SizedBox(width: 6),
              Text(
                'Govt Order Reference: #MH-PN-2024-${worker.id.hashCode.abs() % 9000 + 1000}',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primaryFixed,
                  letterSpacing: 0.3,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Builder(
              builder: (context) {
                String? a;
                try {
                  a = worker?.area?.toString() ?? worker?.locationTag?.toString();
                } catch (_) {}
                final areaText = (a != null && a.isNotEmpty) ? a : 'Kothrud';
                return Text(
                  '$areaText Board',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.tertiaryFixedDim,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedGuildArtisanCard(dynamic worker) {
    final photoUrl = worker.profilePhotoUrl;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saffron top accent stripe
          Container(height: 5, color: AppColors.secondaryContainer),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.surfaceContainerLow,
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 28, color: AppColors.primaryContainer)
                              : null,
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.check_circle, size: 16, color: AppColors.civicVerifiedGreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name,
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryContainer,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.plumbing, size: 14, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Builder(
                                builder: (context) {
                                  String? a;
                                  try {
                                    a = worker?.area?.toString() ?? worker?.locationTag?.toString();
                                  } catch (_) {}
                                  final areaText = (a != null && a.isNotEmpty) ? a : 'Pune';
                                  final idHash = worker?.id != null ? worker.id.hashCode.abs() % 20 + 1 : 1;
                                  return Text(
                                    '$areaText Guild #$idHash',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ITI Trade Certified',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.security, size: 11, color: AppColors.civicVerifiedGreen),
                                    const SizedBox(width: 3),
                                    Text(
                                      'DigiLocker UID',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primaryContainer,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active Slot',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onTertiaryFixed,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${worker.id.hashCode.abs() % 9000 + 1000}',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingSm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Selected Trade Scope:', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text(
                            bookingFlowState.selectedCategory?.name ?? 'Emergency Repair & Service',
                            style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Allotted Window:', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text(
                                '${bookingFlowState.selectedDate ?? "Today"}, ${bookingFlowState.selectedTime ?? "11:30 AM - 12:30 PM"}',
                                style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primaryContainer),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _customerAddressText ?? 'No saved address set (Tap to choose)',
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 11,
                                color: _customerAddressText != null ? AppColors.onSurface : AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _showAddressSelectionModal,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                        ],
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

  Widget _buildGazetteApprovedTariffSchedule(int baseVisit, int laborAllowance, int cess, int total) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel, size: 18, color: AppColors.primaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    'Official Cooperative Tariff',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Gazette Approved',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTariffRow('Base Visit & Diagnostic', 'Standard District Co-op threshold', '₹$baseVisit.00'),
          const SizedBox(height: 8),
          _buildTariffRow('Guild Certified Labor Allowance', 'Tier-1 master artisan rates', '₹$laborAllowance.00'),
          const SizedBox(height: 8),
          _buildTariffRow(
            'Co-op Welfare Cess (2%)',
            'Direct to Karigar Insurance Fund',
            '₹$cess.00',
            icon: Icons.shield_outlined,
            isGreenSubtitle: true,
          ),
          const SizedBox(height: 8),
          _buildTariffRow(
            'Goods & Services Tax (GST)',
            'Exempted under National Charter',
            '₹0.00',
            valueColor: AppColors.civicVerifiedGreen,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Sovereign Escrow',
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Refundable upon unfulfilled slot',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹$total.00',
                  style: AppTypography.titleLg.copyWith(
                    color: AppColors.secondaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffRow(
    String title,
    String subtitle,
    String value, {
    IconData? icon,
    bool isGreenSubtitle = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 4),
                    Icon(icon, size: 14, color: AppColors.civicVerifiedGreen),
                  ],
                ],
              ),
              Text(
                subtitle,
                style: AppTypography.bodySm.copyWith(
                  color: isGreenSubtitle ? AppColors.civicVerifiedGreen : AppColors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: AppTypography.labelLg.copyWith(
            color: valueColor ?? AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDigitalIndiaSovereignEscrowCallout(int total, String workerFirstName) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, size: 24, color: AppColors.secondaryFixed),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digital India Sovereign Escrow',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Secured via NPCI & State Co-operative Vault',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryFixedDim,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_clock, size: 20, color: AppColors.tertiaryFixed),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.95),
                        fontSize: 11,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Your payment of '),
                        TextSpan(
                          text: '₹$total.00',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' stays in sovereign protection. $workerFirstName receives payout '),
                        const TextSpan(
                          text: 'ONLY',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' when you inspect satisfactory work and share your secret 4-digit Government Completion OTP.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assured_workload, size: 14, color: AppColors.primaryFixedDim),
                  const SizedBox(width: 4),
                  Text(
                    'RBI Escrow Compliant',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryFixedDim,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.pin, size: 14, color: AppColors.primaryFixedDim),
                  const SizedBox(width: 4),
                  Text(
                    'Zero Advance Cash to Worker',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryFixedDim,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentGatewaySelection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Sovereign Gateway',
                style: AppTypography.titleMd.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Instant Tokenization',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.civicVerifiedGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSovereignPaymentOption(
            value: 'upi',
            title: 'UPI Direct Instant Reserve',
            badge: 'NPCI',
            subtitle: 'BHIM UPI, Google Pay, PhonePe, Paytm',
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 8),
          _buildSovereignPaymentOption(
            value: 'netbanking',
            title: 'Public Sector Net Banking',
            subtitle: 'State Bank of India, Bank of Maharashtra, PNB',
            icon: Icons.account_balance,
          ),
          const SizedBox(height: 8),
          _buildSovereignPaymentOption(
            value: 'cash',
            title: 'Pay After Service (Cash on Sign-off)',
            subtitle: 'Direct to artisan upon OTP completion',
            icon: Icons.payments_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSovereignPaymentOption({
    required String value,
    required String title,
    String? badge,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _paymentMode == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _paymentMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.spacingSm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainerLow : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.outline,
                  width: isSelected ? 5.5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryContainer,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            badge,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              icon,
              color: isSelected ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNationalShramikGuaranteeBadge() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield, color: AppColors.tertiaryFixed, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'National Shramik Seva Guarantee',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryContainer,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Dispute escalation officer auto-assigned if artisan is delayed beyond 20 minutes.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomEscrowAction(int total, dynamic worker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: const Border(top: BorderSide(color: AppColors.surfaceContainerHigh, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size.fromHeight(50),
                elevation: 2,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      try {
                        final workerId = bookingFlowState.selectedWorker!.id;
                        final categoryId = bookingFlowState.selectedCategory?.id ?? 'c2';
                        final date = bookingFlowState.selectedDate ?? DateTime.now().toIso8601String().split('T').first;
                        final time = bookingFlowState.selectedTime ?? '10:00 AM';
                        final isCash = _paymentMode == 'cash';
                        final paymentMethod = isCash ? 'CASH' : 'RAZORPAY';

                        // Step 1: Create the booking record with decided area tariff and payment method
                        final newBookingId = await DI.customerRepo.createBooking(
                          workerId: workerId,
                          serviceId: categoryId,
                          scheduledDate: date,
                          scheduledTime: time,
                          amount: total.toDouble(),
                          addressId: _customerAddressId ?? bookingFlowState.addressId,
                          bookingType: bookingFlowState.bookingType,
                          paymentMethod: paymentMethod,
                        );

                        if (newBookingId == null) {
                          throw Exception('Failed to generate booking ID.');
                        }

                        _pendingBookingId = newBookingId;

                        if (isCash) {
                          // Cash on Service: No Razorpay checkout needed; route directly to confirmation
                          if (!mounted) return;
                          final bookingId = _pendingBookingId!;
                          _pendingBookingId = null;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => BookingConfirmationScreen(bookingId: bookingId),
                            ),
                            (route) => false,
                          );
                        } else if (kIsWeb) {
                          // Web: Razorpay SDK not supported — proceed directly to confirmation
                          if (!mounted) return;
                          final bookingId = _pendingBookingId!;
                          _pendingBookingId = null;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => BookingConfirmationScreen(bookingId: bookingId),
                            ),
                            (route) => false,
                          );
                        } else {
                          // Mobile: Step 2 — Create Razorpay order via Edge Function
                          final orderResult = await DI.paymentRepo.createPaymentOrder(newBookingId);

                          // Step 3: Open Razorpay checkout
                          final options = <String, dynamic>{
                            'key': orderResult.keyId,
                            'amount': orderResult.amountPaise,
                            'currency': orderResult.currency,
                            'order_id': orderResult.orderId,
                            'name': 'ShramSetu',
                            'description': 'Cooperative Escrow Payment',
                            'prefill': {'contact': '', 'email': ''},
                            'theme': {'color': '#001026'},
                          };
                          _razorpay!.open(options);
                        }
                      } catch (e) {
                        _pendingBookingId = null;
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to initiate booking: $e')),
                          );
                          setState(() => _isSubmitting = false);
                        }
                      }
                    },
              child: _isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _paymentMode == 'cash'
                              ? 'Confirming Cash Booking with Artisan...'
                              : 'Contacting Co-op Escrow Vault...',
                          style: AppTypography.labelMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _paymentMode == 'cash' ? Icons.payments_outlined : Icons.lock,
                          size: 18,
                          color: AppColors.tertiaryFixed,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _paymentMode == 'cash'
                                ? 'Confirm Booking (Pay ₹$total Cash to Partner)'
                                : 'Lock ₹$total in Sovereign Escrow (सुरक्षित एस्क्रॉ)',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 16, color: AppColors.onPrimary),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.policy, size: 13, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Compliant with Consumer Protection Act & National Trade Cooperative Guidelines.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
