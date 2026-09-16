import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/models/demand_forecast_models.dart';

class AdminDemandForecastScreen extends StatefulWidget {
  const AdminDemandForecastScreen({super.key});

  @override
  State<AdminDemandForecastScreen> createState() => _AdminDemandForecastScreenState();
}

class _AdminDemandForecastScreenState extends State<AdminDemandForecastScreen> {
  String _selectedTrade = 'Plumbing';
  String _selectedLocation = 'Kothrud, Pune';
  int _selectedHorizon = DemandForecastConfig.defaultHorizonDays;
  String _selectedModel = 'primary_holt_winters';

  late Future<DemandForecastResult> _forecastFuture;
  late Future<Map<String, ForecastEvaluationMetrics>> _metricsFuture;

  final List<String> _trades = ['Plumbing', 'Electrical', 'Carpentry', 'Cleaning', 'All Trades'];
  final List<String> _locations = ['Kothrud, Pune', 'Baner, Pune', 'Bavdhan, Pune', 'All Pune'];
  final List<int> _horizons = [7, 14];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _forecastFuture = DI.demandForecastRepo.getOrGenerateForecast(
        serviceName: _selectedTrade,
        locationKey: _selectedLocation,
        horizonDays: _selectedHorizon,
        modelType: _selectedModel,
      );
      _metricsFuture = DI.demandForecastRepo.getModelComparison(
        locationKey: _selectedLocation,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Demand Forecasting', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text('Cooperative capacity planning & trade trend analytics', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadData,
            tooltip: 'Refresh Forecast',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Controls Filter Strip
            _buildFilterCard(),
            const SizedBox(height: 12),

            // 2. Main Forecast Payload Builder
            FutureBuilder<DemandForecastResult>(
              future: _forecastFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorCard(snapshot.error.toString());
                }

                final result = snapshot.data;
                if (result == null || (result.historicalPoints.isEmpty && result.forecasts.isEmpty)) {
                  return _buildEmptyCard();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Data Source Banner
                    _buildDataSourceBanner(result.isSynthetic),
                    const SizedBox(height: 12),

                    // B. Capacity Planning Insight Card
                    if (result.supplyInsight != null)
                      _buildCapacityInsightCard(result.supplyInsight!),
                    const SizedBox(height: 12),

                    // C. Historical vs Forecast Chart Card
                    _buildChartCard(result),
                    const SizedBox(height: 12),

                    // D. Forecast Tabular Breakdown Card
                    _buildForecastTableCard(result.forecasts),
                    const SizedBox(height: 12),

                    // E. Research Metrics & Baseline Comparison
                    _buildResearchMetricsCard(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trade Filter
          Text('Service Trade', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _trades.map((trade) {
                final isSelected = _selectedTrade == trade;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(trade, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.w600)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedTrade = trade);
                      _loadData();
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceContainerLow,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Location Filter
          Text('Cluster Location', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _locations.map((loc) {
                final isSelected = _selectedLocation == loc;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(loc, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.w600)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedLocation = loc);
                      _loadData();
                    },
                    selectedColor: AppColors.secondary,
                    backgroundColor: AppColors.surfaceContainerLow,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Horizon & Model Selector
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Forecast Horizon', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: _horizons.map((h) {
                        final isSelected = _selectedHorizon == h;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$h Days', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _selectedHorizon = h);
                              _loadData();
                            },
                            selectedColor: AppColors.primary,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Forecasting Algorithm', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedModel,
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: AppRadius.radiusSm, borderSide: BorderSide(color: AppColors.outlineVariant)),
                      ),
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'primary_holt_winters', child: Text('Holt-Winters Additive')),
                        DropdownMenuItem(value: 'moving_average', child: Text('7-Day Moving Average')),
                        DropdownMenuItem(value: 'seasonal_naive', child: Text('Seasonal Naive (t-7)')),
                        DropdownMenuItem(value: 'naive', child: Text('Naive Persistence')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedModel = val);
                          _loadData();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceBanner(bool isSynthetic) {
    if (isSynthetic) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warningContainer,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.onWarningContainer.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, size: 16, color: AppColors.onWarningContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Experimental Benchmark Mode: Evaluating on isolated synthetic dataset. Real marketplace bookings remain strictly protected.',
                style: AppTypography.bodySm.copyWith(color: AppColors.onWarningContainer, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.onTertiaryContainer.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, size: 16, color: AppColors.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live Marketplace Mode: Forecast derived from real realized customer bookings under RLS.',
              style: AppTypography.bodySm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityInsightCard(CooperativeSupplyInsight insight) {
    Color badgeColor;
    Color textColor;
    IconData badgeIcon;

    switch (insight.status) {
      case SupplyGapStatus.deficit:
        badgeColor = AppColors.warningContainer;
        textColor = AppColors.onWarningContainer;
        badgeIcon = Icons.warning_amber_rounded;
        break;
      case SupplyGapStatus.balanced:
        badgeColor = AppColors.tertiaryContainer;
        textColor = AppColors.onTertiaryContainer;
        badgeIcon = Icons.check_circle_outline;
        break;
      case SupplyGapStatus.surplus:
        badgeColor = AppColors.secondaryFixed;
        textColor = AppColors.secondary;
        badgeIcon = Icons.info_outline;
        break;
      case SupplyGapStatus.insufficientData:
        badgeColor = AppColors.surfaceContainerLow;
        textColor = AppColors.outline;
        badgeIcon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cooperative Capacity Planning', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeColor, borderRadius: AppRadius.radiusSm),
                child: Row(
                  children: [
                    Icon(badgeIcon, size: 12, color: textColor),
                    const SizedBox(width: 4),
                    Text(insight.status.label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Daily Projected Demand',
                  '${insight.forecastedDailyAverage.toStringAsFixed(1)} jobs/day',
                  Icons.trending_up,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Active Verified Artisans',
                  '${insight.activeWorkerSupply} workers',
                  Icons.engineering,
                  AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Capacity Ratio (S/D)',
                  insight.capacityRatio.toStringAsFixed(2),
                  Icons.balance,
                  textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusSm,
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight.recommendationText,
                    style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.outline), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildChartCard(DemandForecastResult result) {
    final historyRecent = result.historicalPoints.length > 14
        ? result.historicalPoints.sublist(result.historicalPoints.length - 14)
        : result.historicalPoints;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Demand Trend & Forecast Projection', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  Text('Past 14 Days Actuals vs Next $_selectedHorizon Days Projection', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                ],
              ),
              Row(
                children: [
                  _buildLegendItem('Actuals', AppColors.primary, isDashed: false),
                  const SizedBox(width: 8),
                  _buildLegendItem('Forecast', AppColors.secondary, isDashed: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: DemandForecastTrendPainter(
                history: historyRecent,
                forecasts: result.forecasts,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {required bool isDashed}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildForecastTableCard(List<DemandForecastItem> forecasts) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detailed Daily Projection Breakdown', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 28,
              dataRowMaxHeight: 36,
              horizontalMargin: 8,
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Day', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Expected Demand', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('95% Confidence Band', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ],
              rows: forecasts.map((item) {
                final dayName = _formatDayOfWeek(item.date.weekday);
                final dateStr = '${item.date.day}/${item.date.month}';
                final confBand = (item.lowerBound != null && item.upperBound != null)
                    ? '${item.lowerBound!.toStringAsFixed(1)} – ${item.upperBound!.toStringAsFixed(1)}'
                    : '± 1.5';

                return DataRow(cells: [
                  DataCell(Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  DataCell(Text(dayName, style: const TextStyle(fontSize: 11, color: AppColors.outline))),
                  DataCell(Text('${item.predictedDemand.toStringAsFixed(1)} jobs', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))),
                  DataCell(Text(confBand, style: const TextStyle(fontSize: 10, color: AppColors.outline))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchMetricsCard() {
    return FutureBuilder<Map<String, ForecastEvaluationMetrics>>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final metricsMap = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.spacingMd),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Research Baseline Evaluation', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusSm),
                    child: const Text('Chronological Test (7D)', style: TextStyle(fontSize: 9, color: AppColors.outline, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 30,
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 34,
                  horizontalMargin: 8,
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Algorithm Model', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('MAE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('RMSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Safe MAPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  ],
                  rows: metricsMap.entries.map((e) {
                    final isPrimary = e.key == 'primary_holt_winters';
                    final m = e.value;
                    return DataRow(
                      color: isPrimary ? WidgetStateProperty.all(AppColors.secondaryFixed.withValues(alpha: 0.3)) : null,
                      cells: [
                        DataCell(Text(m.modelName, style: TextStyle(fontSize: 10, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal))),
                        DataCell(Text(m.mae.toStringAsFixed(2), style: const TextStyle(fontSize: 10))),
                        DataCell(Text(m.rmse.toStringAsFixed(2), style: const TextStyle(fontSize: 10))),
                        DataCell(Text('${m.mape.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 8),
            Text('Forecast aggregation unavailable', style: AppTypography.titleMd),
            const SizedBox(height: 4),
            Text(error, style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 36, color: AppColors.outline),
            const SizedBox(height: 8),
            Text('Insufficient Historical Data', style: AppTypography.titleMd),
            const SizedBox(height: 4),
            Text('A minimum of 14 days of recorded bookings is required for reliable statistical forecasting.',
                style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _formatDayOfWeek(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}

/// Native Canvas Painter that visualizes historical actual demand followed by forecasted projection.
class DemandForecastTrendPainter extends CustomPainter {
  final List<DailyDemandPoint> history;
  final List<DemandForecastItem> forecasts;

  DemandForecastTrendPainter({
    required this.history,
    required this.forecasts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty && forecasts.isEmpty) return;

    final allValues = [
      ...history.map((e) => e.count),
      ...forecasts.map((e) => e.predictedDemand),
      ...forecasts.where((e) => e.upperBound != null).map((e) => e.upperBound!),
    ];

    final maxVal = (allValues.reduce(math.max) * 1.2).ceilToDouble().clamp(10.0, 100.0);
    final totalPoints = history.length + forecasts.length;
    if (totalPoints < 2) return;

    final double stepX = size.width / (totalPoints - 1);
    final double chartHeight = size.height - 30; // leave bottom space for labels

    // 1. Draw Grid Lines
    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight - (chartHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw Historical Actual Line
    final historyPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final historyPath = Path();
    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final y = chartHeight - (history[i].count / maxVal) * chartHeight;
      if (i == 0) {
        historyPath.moveTo(x, y);
      } else {
        historyPath.lineTo(x, y);
      }
    }
    canvas.drawPath(historyPath, historyPaint);

    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final y = chartHeight - (history[i].count / maxVal) * chartHeight;
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }

    // 3. Draw Forecast Confidence Band & Projection Line
    if (forecasts.isNotEmpty && history.isNotEmpty) {
      final startIndex = history.length - 1;
      final lastHistX = startIndex * stepX;
      final lastHistY = chartHeight - (history.last.count / maxVal) * chartHeight;

      // Draw Forecast Shaded Band if bounds exist
      final bandPath = Path();
      bandPath.moveTo(lastHistX, lastHistY);

      for (int j = 0; j < forecasts.length; j++) {
        final x = (startIndex + 1 + j) * stepX;
        final upper = forecasts[j].upperBound ?? (forecasts[j].predictedDemand * 1.2);
        final yUpper = chartHeight - (upper / maxVal) * chartHeight;
        bandPath.lineTo(x, yUpper);
      }
      for (int j = forecasts.length - 1; j >= 0; j--) {
        final x = (startIndex + 1 + j) * stepX;
        final lower = forecasts[j].lowerBound ?? (forecasts[j].predictedDemand * 0.8);
        final yLower = chartHeight - (math.max(0.0, lower) / maxVal) * chartHeight;
        bandPath.lineTo(x, yLower);
      }
      bandPath.close();

      final bandPaint = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(bandPath, bandPaint);

      // Draw Forecast Line (Secondary color)
      final forecastPaint = Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;

      final forecastPath = Path();
      forecastPath.moveTo(lastHistX, lastHistY);

      for (int j = 0; j < forecasts.length; j++) {
        final x = (startIndex + 1 + j) * stepX;
        final y = chartHeight - (forecasts[j].predictedDemand / maxVal) * chartHeight;
        forecastPath.lineTo(x, y);
      }
      canvas.drawPath(forecastPath, forecastPaint);

      final forecastDotPaint = Paint()
        ..color = AppColors.secondary
        ..style = PaintingStyle.fill;

      for (int j = 0; j < forecasts.length; j++) {
        final x = (startIndex + 1 + j) * stepX;
        final y = chartHeight - (forecasts[j].predictedDemand / maxVal) * chartHeight;
        canvas.drawCircle(Offset(x, y), 3.0, forecastDotPaint);
      }
    }

    // 4. Draw X-axis label points
    final textStyle = const TextStyle(color: AppColors.outline, fontSize: 8);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final labelIndices = [0, (history.length ~/ 2), history.length - 1, totalPoints - 1];
    for (final idx in labelIndices) {
      if (idx >= totalPoints) continue;
      final x = idx * stepX;
      final DateTime dt = idx < history.length
          ? history[idx].date
          : forecasts[idx - history.length].date;
      final label = '${dt.day}/${dt.month}';

      textPainter.text = TextSpan(text: label, style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, chartHeight + 8));
    }
  }

  @override
  bool shouldRepaint(covariant DemandForecastTrendPainter oldDelegate) => true;
}
