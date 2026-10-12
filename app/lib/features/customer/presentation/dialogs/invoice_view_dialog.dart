import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/models/invoice_models.dart';

class InvoiceViewDialog extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoiceViewDialog({super.key, required this.invoice});

  static Future<void> show(BuildContext context, {required InvoiceModel invoice}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoiceViewDialog(invoice: invoice),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: AppRadius.radiusFull,
                  ),
                ),
              ),

              // Title bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Tax Invoice & Receipt',
                          style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Printable Invoice Sheet
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
                  children: [
                    _buildInvoicePaper(context),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share Receipt'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text: 'ShramSetu Receipt #${invoice.invoiceNumber}\n'
                                'Service: ${invoice.tradeName}\n'
                                'Artisan: ${invoice.artisanName}\n'
                                'Total Paid: ₹${invoice.totalAmount.toStringAsFixed(2)}\n'
                                'Status: ${invoice.paymentStatus.toUpperCase()}',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invoice summary copied to clipboard!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_done, size: 18),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoicePaper(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cooperative Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('ShramSetu', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: AppRadius.radiusSm),
                          child: const Text('SHRAMSETU PLUS UNION', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.federationName ?? 'Labour Cooperative Federation',
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    Text(
                      'Reg: ${invoice.federationRegNumber ?? 'MH-COOP-VERIFIED'}',
                      style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: invoice.isPaid ? AppColors.secondaryFixed : AppColors.errorContainer,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text(
                  invoice.paymentStatus.toUpperCase(),
                  style: TextStyle(
                    color: invoice.isPaid ? AppColors.secondary : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),

          // Invoice & Booking meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INVOICE NO', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9)),
                  Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('DATE & TIME', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9)),
                  Text(
                    '${invoice.issueDate.day}/${invoice.issueDate.month}/${invoice.issueDate.year} ${invoice.issueDate.hour.toString().padLeft(2, '0')}:${invoice.issueDate.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Parties Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BILLED TO (CUSTOMER)', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(invoice.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty)
                        Text(invoice.customerPhone!, style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(invoice.serviceAddress, style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(width: 1, height: 60, color: AppColors.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SERVICE PROVIDER (ARTISAN)', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(invoice.artisanName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(invoice.tradeName, style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
                      Text('Union Member Verified', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Line Items
          Text('SERVICE CHARGES BREAKDOWN', style: AppTypography.labelSm.copyWith(color: AppColors.outline, letterSpacing: 0.5, fontSize: 10)),
          const SizedBox(height: 8),
          _buildLineItem(
            '${invoice.tradeName} Professional Labor',
            '₹${invoice.baseAmount.toStringAsFixed(2)}',
          ),
          _buildLineItem(
            'Cooperative Worker Welfare Cess (3%)',
            '₹${invoice.welfareCessAmount.toStringAsFixed(2)}',
            subtitle: 'Direct contribution to partner emergency reserve & health fund',
          ),
          _buildLineItem(
            'Goods & Services Tax (18% GST)',
            '₹${invoice.gstAmount.toStringAsFixed(2)}',
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL AMOUNT PAID', style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary)),
              Text(
                '₹${invoice.totalAmount.toStringAsFixed(2)}',
                style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment & Escrow Status Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payment Mode:', style: AppTypography.bodySm.copyWith(fontSize: 11)),
                    Text(invoice.paymentMode.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
                if (invoice.razorpayPaymentId != null && invoice.razorpayPaymentId!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transaction Ref:', style: AppTypography.bodySm.copyWith(fontSize: 11)),
                      Text(invoice.razorpayPaymentId!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Escrow Protection:', style: AppTypography.bodySm.copyWith(fontSize: 11)),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(
                          invoice.escrowStatus,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Disclaimer
          Center(
            child: Text(
              'This is a computer-generated cooperative digital tax receipt issued by ShramSetu Federation Gateway in Razorpay TEST mode. 0% platform commissions deducted.',
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(String title, String amount, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          if (subtitle != null)
            Text(subtitle, style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9)),
        ],
      ),
    );
  }
}
