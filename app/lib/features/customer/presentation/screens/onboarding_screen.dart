import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedRole = 'customer'; // 'customer' or 'worker'
  String _selectedLanguage = 'en'; // 'en', 'hi', 'mr'

  void _handleContinue() {
    if (_selectedRole == 'customer') {
      Navigator.of(context).pushReplacementNamed('/login/customer');
    } else {
      Navigator.of(context).pushReplacementNamed('/login/worker');
    }
  }

  String get _buttonText {
    switch (_selectedLanguage) {
      case 'hi':
        return 'आगे बढ़ें (Continue)';
      case 'mr':
        return 'पुढे सुरू ठेवा (Continue)';
      default:
        return 'Continue / Next';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spacingSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    _buildHeroBanner(),
                    const SizedBox(height: 16),
                    _buildTitle(),
                    const SizedBox(height: 14),
                    _buildRoleSegmentedControl(),
                    const SizedBox(height: 14),
                    _buildLanguageCards(),
                    const SizedBox(height: 14),
                    _buildFeaturesStrip(),
                    const SizedBox(height: 12),
                    _buildAudioPill(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildBottomCta(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.handshake_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShramSetu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'National Workers & Trade Cooperative',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF00875A)),
              SizedBox(width: 5),
              Text(
                'Pune • Live',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 136,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        image: const DecorationImage(
          image: NetworkImage(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDj_q9BXU6qHaTPda1q03V9Tf3_1exNxkPuWc6hnMf22zLFEF7s_kxSJjAtTI8p_lIwHALrj09KNrGAyl4V7p1KZ0QQOFuOElfYfWfvE7QsKi_grlzO2YGPKinOT7hjLb0puxZ5Oed7B6-NtatqH46OqeVl3vpFUMmTVOn13T1ecQh3zRXh0X-jzDHS8h4XT4f2X2gRMHmWp77Lz_RS7XmmF2FBa-IwM6_qJHjrJVzLz5cyfoV-4MW4zQ',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                const Icon(Icons.verified, size: 16, color: Color(0xFF4ADE80)),
                const SizedBox(width: 6),
                const Text(
                  '100% Union Backed • Direct Karigar Payouts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Language',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'आपली भाषा निवडा • अपनी भाषा चुनें. Select your preferred language to customize your booking experience.',
          style: TextStyle(fontSize: 12, color: Color(0xFF71717A), height: 1.35),
        ),
      ],
    );
  }

  Widget _buildRoleSegmentedControl() {
    final isCustomer = _selectedRole == 'customer';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECECEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRole = 'customer'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 42,
                decoration: BoxDecoration(
                  color: isCustomer ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isCustomer
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.home_repair_service,
                      size: 16,
                      color: isCustomer ? const Color(0xFF111111) : const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'I need services',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCustomer ? FontWeight.w800 : FontWeight.w600,
                        color: isCustomer ? const Color(0xFF111111) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRole = 'worker'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 42,
                decoration: BoxDecoration(
                  color: !isCustomer ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isCustomer
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.engineering,
                      size: 16,
                      color: !isCustomer ? const Color(0xFF111111) : const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'I am a Karigar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: !isCustomer ? FontWeight.w800 : FontWeight.w600,
                        color: !isCustomer ? const Color(0xFF111111) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCards() {
    return Column(
      children: [
        _buildLanguageCard(
          code: 'en',
          prefix: 'En',
          title: 'English',
          badge: 'Recommended',
          subtitle: 'Standard interface & verified billings',
        ),
        const SizedBox(height: 8),
        _buildLanguageCard(
          code: 'hi',
          prefix: 'हिं',
          title: 'हिंदी',
          badge: 'राष्ट्रभाषा',
          subtitle: 'कुशल कारीगर और पारदर्शी सेवा गारंटी',
        ),
        const SizedBox(height: 8),
        _buildLanguageCard(
          code: 'mr',
          prefix: 'म',
          title: 'मराठी',
          badge: 'स्थानिक भाषा • पुणे',
          subtitle: 'पुणे व महाराष्ट्र कामगार सहकारी मंच',
          badgeColor: const Color(0xFF92400E),
          badgeBg: const Color(0xFFFEF3C7),
        ),
      ],
    );
  }

  Widget _buildLanguageCard({
    required String code,
    required String prefix,
    required String title,
    required String badge,
    required String subtitle,
    Color? badgeColor,
    Color? badgeBg,
  }) {
    final isSelected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEAEAEA)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    prefix,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg ?? const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor ?? const Color(0xFF111111),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF111111) : Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF111111) : const Color(0xFFD4D4D8),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesStrip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _FeatureItem(icon: Icons.payments, title: 'Direct Bank Pay', sub: '0% Middleman Cut', color: Color(0xFF00875A)),
          _FeatureItem(icon: Icons.verified_user, title: 'Govt ITI & KYC', sub: '100% Background Check', color: Color(0xFF2563EB)),
          _FeatureItem(icon: Icons.shield, title: 'Co-op Escrow', sub: 'Guaranteed Quality', color: Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _buildAudioPill() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_up, size: 15, color: Color(0xFF5A38E4)),
            SizedBox(width: 6),
            Text(
              'Listen in audio (ऐका / आवाज में सुनें)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF111111)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCta() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEAEAEA))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _buttonText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'By continuing, you agree to ShramSetu\'s Fair Work Terms & Privacy Policy.',
            style: TextStyle(fontSize: 10, color: Color(0xFF71717A)),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
        ),
        Text(
          sub,
          style: const TextStyle(fontSize: 9, color: Color(0xFF71717A)),
        ),
      ],
    );
  }
}
