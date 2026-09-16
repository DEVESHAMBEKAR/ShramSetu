import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/booking_models.dart';
import 'booking_details_screen.dart';

class BookingDateTimeScreen extends StatefulWidget {
  const BookingDateTimeScreen({super.key});

  @override
  State<BookingDateTimeScreen> createState() => _BookingDateTimeScreenState();
}

class _BookingDateTimeScreenState extends State<BookingDateTimeScreen> {
  String? _selectedDate;
  String? _selectedTime;

  late final List<String> _dates;
  final List<String> _times = ['09:00 AM', '10:00 AM', '11:00 AM', '01:00 PM', '02:00 PM', '04:00 PM'];

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const List<String> _weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _dates = _generateDates();
    _selectedDate = _dates.isNotEmpty ? _dates.first : null;
  }

  static List<String> _generateDates() {
    final now = DateTime.now();
    final dates = <String>[];
    for (int i = 0; i < 5; i++) {
      final date = now.add(Duration(days: i));
      final month = _monthNames[date.month - 1];
      if (i == 0) {
        dates.add('Today, ${date.day} $month');
      } else if (i == 1) {
        dates.add('Tomorrow, ${date.day} $month');
      } else {
        final weekday = _weekdayNames[date.weekday - 1];
        dates.add('$weekday, ${date.day} $month');
      }
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        title: Text('Select Date & Time', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressStepper(),
                  const SizedBox(height: AppSpacing.spacingLg),
                  Text('Select Date', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.spacingSm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _dates.map((date) => _buildDateChip(date)).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacingLg),
                  Text('Select Time', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.spacingSm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: AppSpacing.spacingSm,
                      mainAxisSpacing: AppSpacing.spacingSm,
                    ),
                    itemCount: _times.length,
                    itemBuilder: (context, index) => _buildTimeChip(_times[index]),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep('Service', true),
          _buildLine(true),
          _buildStep('Worker', true),
          _buildLine(true),
          _buildStep('Time', true, current: true),
          _buildLine(false),
          _buildStep('Pay', false),
        ],
      ),
    );
  }

  Widget _buildStep(String label, bool completed, {bool current = false}) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: completed ? AppColors.tertiaryContainer : (current ? AppColors.primary : AppColors.surfaceContainerHigh),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: completed
              ? const Icon(Icons.check, size: 14, color: AppColors.onTertiaryContainer)
              : Text(
                  label == 'Pay' ? '4' : '3', // Hacky simple step count
                  style: AppTypography.labelSm.copyWith(color: current ? AppColors.onPrimary : AppColors.onSurfaceVariant),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(color: current || completed ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: current ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }

  Widget _buildLine(bool completed) {
    return Container(
      width: 30,
      height: 2,
      color: completed ? AppColors.tertiaryFixedDim : AppColors.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    );
  }

  Widget _buildDateChip(String date) {
    final isSelected = _selectedDate == date;
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.spacingSm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd, vertical: AppSpacing.spacingSm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant),
        ),
        child: Text(
          date,
          style: AppTypography.labelMd.copyWith(color: isSelected ? AppColors.onPrimary : AppColors.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time) {
    final isSelected = _selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = time),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusSm,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant),
        ),
        child: Text(
          time,
          style: AppTypography.labelMd.copyWith(color: isSelected ? AppColors.onPrimary : AppColors.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isReady = _selectedDate != null && _selectedTime != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: isReady
              ? () {
                  bookingFlowState.selectedDate = _selectedDate;
                  bookingFlowState.selectedTime = _selectedTime;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BookingDetailsScreen(),
                    ),
                  );
                }
              : null,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isReady ? AppColors.primary : AppColors.surfaceContainerHighest,
              borderRadius: AppRadius.radiusXl,
            ),
            alignment: Alignment.center,
            child: Text('Continue', style: AppTypography.labelLg.copyWith(color: isReady ? AppColors.onPrimary : AppColors.outline, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
