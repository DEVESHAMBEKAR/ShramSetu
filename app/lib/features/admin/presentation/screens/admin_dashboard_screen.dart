import 'package:flutter/material.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/admin_models.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _dataFuture = Future.wait([
        DI.adminRepo.getDashboardStats(),
        DI.adminRepo.getWorkers(),
      ]);
    });
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified, color: AppColors.tertiaryFixed, size: 20),
            const SizedBox(width: AppSpacing.spacingXs),
            Expanded(child: Text(message, style: AppTypography.bodySm.copyWith(color: AppColors.onPrimary))),
            Text('Coop Node #12', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryContainer)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ')));
        }

        final stats = snapshot.data![0] as AdminDashboardStats;
        final workers = snapshot.data![1] as List<WorkerProfile>;
        final pending = workers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.corporate_fare, color: AppColors.primary),
            const SizedBox(width: AppSpacing.spacingXs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('ShramSetu', style: AppTypography.headlineSm.copyWith(color: AppColors.primary)),
                    const SizedBox(width: AppSpacing.spacing2xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, size: 12, color: AppColors.secondary),
                          const SizedBox(width: 2),
                          Text('PUNE COOP', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                Text('Coop Federation', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications, color: AppColors.onSurfaceVariant), onPressed: () {}),
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.spacingMd),
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.person, size: 18, color: AppColors.onPrimary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildContextBanner(),
            _buildMetricGrid(stats),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildFairWorkIndex(),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildVerificationQueue(pending),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildLiveDispute(),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildWelfareSupport(),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildQuickActions(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
      }
    );
  }

  Widget _buildContextBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: AppRadius.radiusFull),
                child: Row(
                  children: [
                    const Icon(Icons.shield, size: 13, color: AppColors.tertiaryFixed),
                    const SizedBox(width: 4),
                    Text('Federation Admin Level 3', style: AppTypography.labelSm.copyWith(color: AppColors.primaryFixed)),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.tertiaryFixedDim, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Live Dispatch Feed', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryContainer)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Text('Cooperative Admin Console', style: AppTypography.headlineLgMobile.copyWith(color: AppColors.onPrimary)),
          Text('Pune District Trades Federation • Ward #12 Kothrud', style: AppTypography.bodySm.copyWith(color: AppColors.onPrimaryContainer)),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(AdminDashboardStats stats) {
    return Transform.translate(
      offset: const Offset(0, -AppSpacing.spacingSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.spacingXs,
          crossAxisSpacing: AppSpacing.spacingXs,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard('Active Workers', Icons.engineering, AppColors.secondary, '${stats.totalWorkers}', '94% on-duty', Icons.check_circle, AppColors.tertiaryContainer),
            _buildMetricCard('Jobs & Escrow', Icons.lock, AppColors.tertiaryContainer, '${stats.activeBookings} Jobs', '₹${stats.escrowLocked.toInt()} Locked', null, AppColors.onSurfaceVariant),
            _buildMetricCard('Pending Verification', Icons.assignment_ind, AppColors.secondary, '${stats.pendingVerifications} Karigars', '6 urgent batch', Icons.schedule, AppColors.error, valueColor: AppColors.secondary),
            _buildMetricCard('Welfare Pool', Icons.account_balance, AppColors.primary, '₹${stats.welfarePool / 100000} Lakhs', 'Reserve Healthy', null, AppColors.tertiary, badgeBg: AppColors.surfaceContainerHigh),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, IconData icon, Color iconColor, String value, String subtitle, IconData? subIcon, Color subColor, {Color? valueColor, Color? badgeBg}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTypography.headlineSm.copyWith(color: valueColor ?? AppColors.primary)),
              const SizedBox(height: 2),
              if (badgeBg != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: AppRadius.radiusSm),
                  child: Text(subtitle, style: AppTypography.labelSm.copyWith(color: subColor)),
                )
              else
                Row(
                  children: [
                    if (subIcon != null) ...[Icon(subIcon, size: 12, color: subColor), const SizedBox(width: 4)],
                    Text(subtitle, style: AppTypography.labelSm.copyWith(color: subColor)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFairWorkIndex() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(color: AppColors.secondaryFixed, shape: BoxShape.circle),
                      child: const Icon(Icons.balance, size: 18, color: AppColors.secondary),
                    ),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fair Work Distribution Index', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                        Text('Anti-monopoly allocation algorithm', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusFull),
                  child: Text('88% Parity', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppSpacing.spacingSm),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tier Parity (Min 2 Jobs/Day)', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      Text('125 / 142 Karigars', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spacingXs),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.radiusFull),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.88,
                      child: Container(decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: AppRadius.radiusFull)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Plumbers (91%)', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Electricians (85%)', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                      Text('Max Cap: 4 jobs/day', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.spacingXs),
              decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusLg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Algorithm actively routing emergency calls away from top-3 earners to junior members who completed Ward 12 cooperative safety training.',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationQueue(List<WorkerProfile> pending) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Priority Verification Queue', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
                  Text('${pending.length} candidates waiting for ward badge clearance', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              TextButton(
                onPressed: () {}, // Will navigate to verification list
                child: Row(
                  children: [
                    Text('View All (${pending.length})', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          ...pending.map((worker) => _buildWorkerVerificationCard(worker)),
        ],
      ),
    );
  }

  Future<void> _viewDocuments(WorkerProfile worker) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final docs = await DI.adminRepo.getWorkerDocuments(worker.id);
      Navigator.pop(context);
      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No documents found for this worker.')));
        return;
      }
      
      // Get signed URLs
      List<String> urls = [];
      for(var doc in docs) {
        final path = doc['storage_path'];
        final url = await DI.storageRepo.getSignedUrl(bucket: StorageBucket.workerDocuments, path: path, expiresIn: 3600);
        urls.add('\: ');
      }
      
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Documents for '),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: urls.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SelectableText(u, style: const TextStyle(fontSize: 12)),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))
          ]
        )
      );
    } catch(e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
    }
  }

  Widget _buildWorkerVerificationCard(WorkerProfile worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.radiusXl),
                child: const Icon(Icons.person, color: AppColors.outline),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(worker.name, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusSm),
                          child: Text('Awaiting Review', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    Text(worker.skills.first, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    Text('Guild: ${worker.guildId}', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Row(
            children: [
              _buildDocTag(Icons.done, 'Aadhaar Verified', AppColors.tertiaryContainer),
              const SizedBox(width: 4),
              _buildDocTag(Icons.done, 'Police NOC', AppColors.tertiaryContainer),
              const SizedBox(width: 4),
              _buildDocTag(Icons.verified, 'Trade Cert', AppColors.secondary),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Docs'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainer, foregroundColor: AppColors.primary, elevation: 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    () async { await DI.adminRepo.approveWorker(worker.id); _refreshData(); }();
                    _showToast('${worker.name} credentialed to ${worker.guildName}.');
                  },
                  icon: const Icon(Icons.task_alt, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, elevation: 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.flag, size: 16),
                  label: const Text('Inquiry'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainerHigh, foregroundColor: AppColors.error, elevation: 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusSm),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildLiveDispute() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Dispute & Escrow Mediation', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
                  Text('1 active case requiring guild resolution', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel, color: AppColors.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text('Order #SS-8941', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.secondaryFixed, borderRadius: AppRadius.radiusSm),
                      child: Text('Active Dispute', style: AppTypography.labelSm.copyWith(color: AppColors.onSecondaryFixedVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingSm),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Dispute Reason:', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text('Extra Pipe Fitting Charge', style: AppTypography.bodySm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Disputed Delta:', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text('₹120', style: AppTypography.currencyDisplay.copyWith(color: AppColors.secondary, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Guild Liaison:', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text('Ramesh Deshpande', style: AppTypography.labelMd.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Text(
                  'Plumber replaced an unlisted brass elbow fitting due to leakage risk. Customer requested guild tariff verification before releasing escrow amount.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('Call Liaison'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainerHigh, foregroundColor: AppColors.primary, elevation: 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.price_check, size: 16),
                        label: const Text('Validate Tariff (₹120)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, elevation: 1),
                      ),
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

  Widget _buildWelfareSupport() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guild Welfare & Mutual Aid', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
                  Text('Cooperative solidarity fund requests', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              const Icon(Icons.volunteer_activism, color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Column(
              children: [
                _buildWelfareItem(Icons.construction, AppColors.primary, 'Tool Loan Applications', '2 requests • Subsidized 4% APR', 'Review (2)', true),
                const SizedBox(height: AppSpacing.spacingSm),
                _buildWelfareItem(Icons.health_and_safety, AppColors.tertiaryContainer, 'Hospitalization Cover Claim', '1 claim • Ward #12 Cashless Pool', 'Assess Claim', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelfareItem(IconData icon, Color iconColor, String title, String subtitle, String btnText, bool isPrimaryBtn) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceContainerHighest, borderRadius: AppRadius.radiusLg),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: isPrimaryBtn ? AppColors.primary : AppColors.surfaceContainerHigh,
              foregroundColor: isPrimaryBtn ? AppColors.onPrimary : AppColors.primary,
              elevation: isPrimaryBtn ? 1 : 0,
            ),
            child: Text(btnText, style: AppTypography.labelSm),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _showToast('Fair Wage Audit PDF generated & archived.'),
              icon: const Icon(Icons.picture_as_pdf, size: 20),
              label: const Text('Export Monthly Fair Wage Audit PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl)),
            ),
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _showToast('Broadcast audio memo sent to 142 on-duty karigars.'),
              icon: const Icon(Icons.campaign, size: 20, color: AppColors.secondary),
              label: const Text('Broadcast Guild Notice to Workers', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainer, foregroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl)),
            ),
          ),
        ],
      ),
    );
  }
}

