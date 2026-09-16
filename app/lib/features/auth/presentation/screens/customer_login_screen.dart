import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../features/customer/data/models/customer_profile.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _secondsRemaining = 30;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _secondsRemaining = 30);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handlePrimaryAction() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      if (!_isOtpSent) {
        final phone = _phoneController.text.trim();
        if (phone.length < 10) {
          throw Exception('Please enter a valid 10-digit mobile number.');
        }
        await DI.authRepo.sendOtp(phone);
        setState(() {
          _isOtpSent = true;
          _isLoading = false;
        });
        _startCountdown();
        Future.delayed(const Duration(milliseconds: 100), () {
          _otpFocusNode.requestFocus();
        });
      } else {
        final otp = _otpController.text.trim();
        if (otp.length != 6) {
          throw Exception('Please enter the 6-digit OTP code.');
        }
        final phone = _phoneController.text.trim();
        final isValid = await DI.authRepo.verifyOtp(phone, otp);
        if (isValid) {
          final user = await DI.authRepo.getCurrentUser();
          final userId = user?.id ?? 'mock_user_id';

          // 1. Check if customer already exists (by userId or phone)
          CustomerProfile? profile = await DI.userRepo.getCustomerProfile(userId);
          profile ??= await DI.userRepo.getCustomerProfileByPhone(phone);

          final effectiveUserId = profile?.id ?? userId;

          // 2. If profile does not exist yet, initialize initial record.
          // If profile exists, ensure user profile record is maintained without wiping out their name.
          await DI.userRepo.upsertUserProfile(
            userId: effectiveUserId,
            role: 'CUSTOMER',
            phone: phone,
            fullName: (profile != null && profile.fullName.isNotEmpty) ? profile.fullName : null,
          );

          // 3. Determine if profile is already complete (has real name and address)
          final isComplete = (profile?.isComplete == true) || await DI.userRepo.isProfileComplete(effectiveUserId);

          if (mounted) {
            if (isComplete) {
              // Existing customer with complete profile -> go directly to home
              Navigator.of(context).pushReplacementNamed('/customer/home');
            } else {
              // New or incomplete profile -> complete onboarding
              Navigator.of(context).pushReplacementNamed('/customer/onboarding');
            }
          }
        }
 else {
          throw Exception('Invalid OTP. Please try again. (Hint: use 123456 in test mode)');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _handleEditPhone() {
    setState(() {
      _isOtpSent = false;
      _otpController.clear();
      _errorMessage = null;
    });
    _countdownTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNav(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spacingSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBrandingHeader(),
                    _buildHeadingSection(),
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildMobileInputCard(),
                    if (_isOtpSent) _buildOtpVerificationCard(),
                    const SizedBox(height: 12),
                    _buildEscrowProtectionCallout(),
                    const SizedBox(height: 20),
                    _buildActionCta(),
                    const SizedBox(height: 14),
                    _buildAlternativeModeSwitch(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              if (_isOtpSent) {
                _handleEditPhone();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  _isOtpSent ? 'Step 2 of 2: OTP Verification' : 'Step 1 of 2: Mobile Verification',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'ShramSetu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OFFICIAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                'National Workers & Trade Cooperative',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeadingSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isOtpSent ? 'Verify your number' : 'Enter your mobile number',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'We will send a 6-digit one-time password (OTP) to authenticate your account and connect to verified cooperatives.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileInputCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
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
          const Text(
            'MOBILE NUMBER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Indian Tricolor indicator
                Container(
                  width: 20,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: Container(color: AppColors.flagSaffron)),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: const Icon(Icons.circle, size: 3, color: AppColors.flagNavy),
                        ),
                      ),
                      Expanded(child: Container(color: AppColors.flagGreen)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: AppColors.outlineVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    readOnly: _isOtpSent,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '98231 45890',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.outline,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                if (_phoneController.text.length >= 10)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: AppColors.onTertiaryContainer),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('OTP sent to ', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  Text(
                    '+91 ${_phoneController.text}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _handleEditPhone,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildOtpInputBoxes(),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    _secondsRemaining > 0 ? 'Resend OTP in 00:${_secondsRemaining.toString().padLeft(2, '0')}s' : 'Code expired',
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _secondsRemaining == 0
                    ? () {
                        DI.authRepo.sendOtp(_phoneController.text.trim());
                        _startCountdown();
                      }
                    : null,
                child: Text(
                  'Resend via SMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _secondsRemaining == 0 ? AppColors.primary : AppColors.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Didn't receive SMS?", style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.tertiaryFixed.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chat, size: 13, color: AppColors.onTertiaryContainer),
                    SizedBox(width: 4),
                    Text(
                      'Get on WhatsApp',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onTertiaryContainer,
                      ),
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

  Widget _buildOtpInputBoxes() {
    return Stack(
      children: [
        Opacity(
          opacity: 0.0,
          child: TextField(
            controller: _otpController,
            focusNode: _otpFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (val) {
              setState(() {});
              if (val.length == 6) {
                _handlePrimaryAction();
              }
            },
          ),
        ),
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final text = _otpController.text;
              final isFocused = _otpFocusNode.hasFocus && text.length == index;
              final hasValue = text.length > index;
              final char = hasValue ? text[index] : '';

              return Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFocused ? AppColors.primary : AppColors.outlineVariant,
                    width: isFocused ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: hasValue
                    ? Text(
                        char,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )
                    : (isFocused
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEscrowProtectionCallout() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onTertiaryContainer.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield, size: 16, color: AppColors.onTertiaryContainer),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cooperative Escrow Protected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Protected under National Cooperative Data Charter. Your phone number is strictly encrypted with zero spam and never shared with 3rd parties.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onTertiaryContainer,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCta() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePrimaryAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isOtpSent ? 'Verify & Continue' : 'Send Verification OTP',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildAlternativeModeSwitch() {
    return Column(
      children: [
        const Text(
          'By proceeding, you agree to the ShramSetu Terms & Worker Charter Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.3),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacementNamed('/login/worker');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.handshake, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Are you a service partner? Switch to Partner Sign-in →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed('/login/admin');
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_outlined, size: 14, color: AppColors.secondary),
              SizedBox(width: 5),
              Text(
                'Federation Official? Admin Console Sign-in →',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
