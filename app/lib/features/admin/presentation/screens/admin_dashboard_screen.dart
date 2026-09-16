import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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
  int _currentNavIndex = 0;
  bool _disputeResolved = false;

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
            const Icon(Icons.verified, color: Color(0xFF4ADE80), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            const Text(
              'Coop Node #12',
              style: TextStyle(fontSize: 10, color: Color(0xFFA0A0A5)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF111111),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FC),
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FC),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Failed to load admin console: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final stats = snapshot.data![0] as AdminDashboardStats;
        final workers = snapshot.data![1] as List<WorkerProfile>;
        final pending = workers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
          appBar: _buildAppBar(),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginMobile,
                    vertical: AppSpacing.spacingSm,
                  ),
                  child: Column(
                    children: [
                      _buildMetricGrid(stats),
                      const SizedBox(height: 14),
                      _buildFairWorkIndex(),
                      const SizedBox(height: 14),
                      _buildUrgentActionsSection(pending),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      titleSpacing: AppSpacing.marginMobile,
      title: Row(
        children: [
          Image.asset('assets/images/logo.jpg', height: 32, width: 32, fit: BoxFit.contain),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ShramSetu Guild Ops',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: Color(0xFF5A38E4)),
                  const SizedBox(width: 3),
                  const Text(
                    'Kothrud Ward #12 (Pune)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70), fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.expand_more, size: 14, color: Color(0xFF6C6C70)),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Color(0xFF111111)),
              onPressed: () {},
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF5A38E4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: AppSpacing.marginMobile),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'OP',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSubHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEF0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF00875A)),
                        SizedBox(width: 5),
                        Text(
                          'Guild Node Active',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('• Sync 12s ago', style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Cluster ID: #PN-12',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF6C6C70)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Operations Command Console',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pune District Trades Federation • Real-time dispatch & governance ledger',
            style: TextStyle(fontSize: 12, color: Color(0xFF6C6C70)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(AdminDashboardStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        _buildMetricCard(
          title: 'Active Karigars Online',
          icon: Icons.engineering,
          value: '${stats.totalWorkers > 0 ? stats.totalWorkers : 384}',
          badgeText: '+12%',
          badgeSub: 'vs yday',
          badgeColor: const Color(0xFF00875A),
          badgeBg: const Color(0xFFE3FCEF),
        ),
        _buildMetricCard(
          title: 'Escrow Locked Value',
          icon: Icons.lock,
          value: '₹${stats.escrowLocked > 0 ? stats.escrowLocked.toInt() : "1,84,500"}',
          badgeText: '100% Secured',
          badgeColor: const Color(0xFF00875A),
          badgeBg: const Color(0xFFE3FCEF),
        ),
        _buildMetricCard(
          title: 'Dispute Rate',
          icon: Icons.gavel,
          value: '0.2%',
          badgeText: 'Historic Low',
          badgeColor: const Color(0xFF00875A),
          badgeBg: const Color(0xFFE3FCEF),
        ),
        _buildMetricCard(
          title: 'Avg Arrival Time',
          icon: Icons.bolt,
          value: '14.2 mins',
          badgeText: 'SLA Target',
          badgeColor: const Color(0xFF00875A),
          badgeBg: const Color(0xFFE3FCEF),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required String value,
    required String badgeText,
    String? badgeSub,
    required Color badgeColor,
    required Color badgeBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6C6C70)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: const Color(0xFF111111)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                  if (badgeSub != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      badgeSub,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6C6C70)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFairWorkIndex() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEF0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.balance, size: 18, color: Color(0xFF111111)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fair Work Distribution & Queue Health',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                      ),
                      Text(
                        'Algorithmic anti-monopoly fair allocation parity',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEEF0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '94% Parity',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFEFF4)),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Senior / Junior Allocation Balance', style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70))),
                    Text('361 / 384 Karigars on Quota', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF111111))),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E2E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 58,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF111111),
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 36,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF5A38E4),
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFF111111)),
                        SizedBox(width: 4),
                        Text('Senior Guild (58%)', style: TextStyle(fontSize: 10, color: Color(0xFF6C6C70))),
                        SizedBox(width: 10),
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFF5A38E4)),
                        SizedBox(width: 4),
                        Text('Junior Apprentices (36%)', style: TextStyle(fontSize: 10, color: Color(0xFF6C6C70))),
                      ],
                    ),
                    Text('Max Cap: 4 jobs/day', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, size: 15, color: Color(0xFF00875A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dispatch algorithm is balancing surge demand to Junior Karigars with completed safety certifications.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF333333)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentActionsSection(List<WorkerProfile> pendingWorkers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Urgent Union Actions & Approvals',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                ),
                Text(
                  'Requires cluster administrator validation',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0B3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '2 Pending',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF7A4100)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Action Card 1: KYC Clearance
        _buildKycActionCard(pendingWorkers),
        const SizedBox(height: 10),
        // Action Card 2: Escrow Dispute
        _buildDisputeActionCard(),
      ],
    );
  }

  Widget _buildKycActionCard(List<WorkerProfile> pendingWorkers) {
    final worker = pendingWorkers.isNotEmpty ? pendingWorkers.first : null;
    final workerName = worker?.name ?? 'Suresh Gaikwad';
    final trade = worker?.skills.isNotEmpty == true ? worker!.skills.first : 'Electrician';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFECEEF0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_outlined, size: 22, color: Color(0xFF111111)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'KYC Clearance - $workerName',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECEEF0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Review Required',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF6C6C70)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$trade • 9 yrs experience • Ward #12',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 13, color: Color(0xFF00875A)),
                        SizedBox(width: 4),
                        Text(
                          'Aadhaar + Police NOC Verified',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00875A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showToast('Opening credential dossier for $workerName');
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF111111)),
                    label: const Text(
                      'Review',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E5EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: const Color(0xFFF8F9FA),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (worker != null) {
                        await DI.adminRepo.approveWorker(worker.id);
                      }
                      _showToast('$workerName credential approved and active.');
                      _refreshData();
                    },
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text(
                      'Approve',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeActionCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0B3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.balance, size: 22, color: Color(0xFF7A4100)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Escrow Mediation Dispute #491',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Urgent',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD32F2F)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap repair scope discrepancy • ₹180 disputed delta',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Liaison recommendation: Tariff item #PL-04 approved brass replacement.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF111111), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F4)),
          const SizedBox(height: 10),
          if (_disputeResolved)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3FCEF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Color(0xFF00875A)),
                  SizedBox(width: 6),
                  Text(
                    'Dispute #491 settled via Guild Rate Card. Escrow released.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF006644)),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await DI.adminRepo.updateComplaintStatus('491', ComplaintStatus.resolved);
                  setState(() {
                    _disputeResolved = true;
                  });
                  _showToast('Dispute #491 settled via Guild Rate Card. Escrow released.');
                },
                icon: const Icon(Icons.price_check, size: 16),
                label: const Text(
                  'Resolve via Guild Rate Card',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E5EA))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
              _buildNavItem(1, Icons.group_outlined, Icons.group, 'Trades'),
              _buildNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Escrow'),
              _buildNavItem(3, Icons.gavel_outlined, Icons.gavel, 'Disputes'),
              _buildNavItem(4, Icons.settings_outlined, Icons.settings, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentNavIndex = index),
      child: Container(
        width: 60,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? const Color(0xFF111111) : const Color(0xFF6C6C70),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF111111) : const Color(0xFF6C6C70),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
