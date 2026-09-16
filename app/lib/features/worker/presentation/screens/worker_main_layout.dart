import 'package:flutter/material.dart';
import 'worker_dashboard_screen.dart';
import 'worker_job_requests_screen.dart';
import 'worker_earnings_screen.dart';
import 'worker_profile_settings_screen.dart';

class WorkerMainLayout extends StatefulWidget {
  const WorkerMainLayout({super.key});

  @override
  State<WorkerMainLayout> createState() => _WorkerMainLayoutState();
}

class _WorkerMainLayoutState extends State<WorkerMainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const WorkerDashboardScreen(),
    const WorkerJobRequestsScreen(),
    const WorkerEarningsScreen(),
    const WorkerProfileSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          border: const Border(
            top: BorderSide(color: Color(0xFFE5E5EA), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
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
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.assignment_outlined, Icons.assignment, 'Jobs'),
                _buildNavItem(2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Earnings'),
                _buildNavItem(3, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        width: 72,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF111111) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? Colors.white : const Color(0xFF6C6C70),
                size: 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF111111) : const Color(0xFF6C6C70),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
