import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/admin_models.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  late Future<List<PaymentRecord>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _paymentsFuture = DI.adminRepo.getPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentRecord>>(
      future: _paymentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error loading payments', style: AppTypography.bodyMd),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _refreshData, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final payments = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface.withValues(alpha: 0.9),
            elevation: 1,
            title: Text('Escrow & Payments', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
            ],
          ),
          body: payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments_outlined, size: 48, color: AppColors.outline),
                      const SizedBox(height: 8),
                      Text('No payments yet', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
                      padding: const EdgeInsets.all(AppSpacing.spacingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: AppRadius.radiusXl,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Txn: ${payment.razorpayOrderId?.substring(0, payment.razorpayOrderId!.length.clamp(0, 20)) ?? payment.id.substring(0, 8)}',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(payment.status.name),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Booking: ${payment.bookingId.substring(0, 8)}…', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                              Text('₹${payment.amount.toInt()}', style: AppTypography.titleLg.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.spacingSm),
                          Text('Customer: ${payment.customerName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text('Worker: ${payment.workerName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: AppSpacing.spacingSm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildEscrowBadge(payment.escrowStatus),
                              Text(payment.date.toString().substring(0, 16), style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = switch (status.toLowerCase()) {
      'paid' => AppColors.onTertiaryContainer,
      'failed' => Colors.red.shade700,
      'refunded' => AppColors.secondary,
      'cancelled' => Colors.grey,
      _ => AppColors.outline,
    };
    final bg = switch (status.toLowerCase()) {
      'paid' => AppColors.tertiaryContainer,
      'failed' => Colors.red.shade50,
      'refunded' => AppColors.secondaryFixed,
      _ => AppColors.surfaceContainerLow,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.radiusSm),
      child: Text(status.toUpperCase(), style: AppTypography.labelSm.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildEscrowBadge(EscrowStatus escrow) {
    final (label, color, bg) = switch (escrow) {
      EscrowStatus.held => ('🔒 Held in Escrow', AppColors.primary, AppColors.surfaceContainerLow),
      EscrowStatus.released => ('✅ Released', AppColors.onTertiaryContainer, AppColors.tertiaryContainer),
      EscrowStatus.releasePending => ('⏳ Release Pending', Colors.orange.shade800, Colors.orange.shade50),
      EscrowStatus.refunded => ('↩ Refunded', AppColors.secondary, AppColors.secondaryFixed),
      _ => ('⬜ Not Funded', AppColors.outline, AppColors.surfaceContainerLow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.radiusSm, border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: AppTypography.labelSm.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10)),
    );
  }
}
