import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/repositories/mock_admin_repository.dart';
import '../../data/models/admin_models.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  late MockAdminRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockAdminRepository();
    _repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final payments = _repository.payments;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Escrow & Payments', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Txn: ${payment.id}', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _getStatusColor(payment.status), borderRadius: AppRadius.radiusSm),
                      child: Text(payment.status.name.toUpperCase(), style: AppTypography.labelSm.copyWith(color: AppColors.onPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #${payment.bookingId}', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
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
                    Text(payment.date.toString().substring(0, 16), style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Text(payment.method, style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppColors.tertiaryFixed;
      case PaymentStatus.pending:
        return AppColors.secondary;
      case PaymentStatus.failed:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}
