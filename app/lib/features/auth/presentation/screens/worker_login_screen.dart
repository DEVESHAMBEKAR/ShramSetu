import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import 'package:app/core/config/dependency_injection.dart';

class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Countdown timer state
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
        // Step 1: Send OTP
        final phone = _phoneController.text.trim();
        if (phone.length != 10) {
          throw Exception('Please enter a valid 10-digit number.');
        }
        await DI.authRepo.sendOtp(phone);
        setState(() {
          _isOtpSent = true;
          _isLoading = false;
        });
        _startCountdown();
        // Request focus on OTP field after a short delay to allow UI to build
        Future.delayed(const Duration(milliseconds: 100), () {
          _otpFocusNode.requestFocus();
        });
      } else {
        // Step 2: Verify OTP
        final otp = _otpController.text.trim();
        if (otp.length != 6) {
          throw Exception('Please enter the 6-digit OTP.');
        }
        final isValid = await DI.authRepo.verifyOtp(_phoneController.text.trim(), otp);
        if (isValid) {
          final user = await DI.authRepo.getCurrentUser();
          final userId = user?.id ?? 'mock_user_id';
          
          await DI.userRepo.upsertUserProfile(
            userId: userId,
            role: 'WORKER',
            phone: _phoneController.text.trim(),
          );

          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/worker/dashboard');
          }
        } else {
          throw Exception('Invalid OTP. Please try again. (Hint: use 123456 in mock mode)');
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNav(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBrandingHeader(),
                    _buildHeadingSection(),
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildMobileInputCard(),
                    if (_isOtpSent) _buildOtpVerificationCard(),
                    if (!_isOtpSent) const SizedBox(height: AppSpacing.spacingLg),
                    _buildTrustBadge(),
                    _buildActionCta(),
                    _buildAlternativeModeSwitch(),
                    const SizedBox(height: AppSpacing.spacing3xl),
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
        vertical: AppSpacing.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              if (_isOtpSent) {
                _handleEditPhone();
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              hoverColor: AppColors.surfaceContainer,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingSm,
              vertical: AppSpacing.spacing3xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: AppRadius.radiusFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.secondary),
                const SizedBox(width: AppSpacing.spacing2xs),
                Text(
                  _isOtpSent ? 'Step 2 of 2: OTP Verification' : 'Step 1 of 2: Mobile Verification',
                  style: AppTypography.labelSm.copyWith(
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
      padding: const EdgeInsets.only(top: AppSpacing.spacingXs, bottom: AppSpacing.spacingMd),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.radiusLg,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'श',
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.secondaryFixedDim,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ShramSetu',
                style: AppTypography.headlineMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'National Workers & Trade Cooperative',
                style: AppTypography.labelSm.copyWith(
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
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isOtpSent ? 'Verify your number' : 'Enter your mobile number',
            style: AppTypography.headlineLgMobile.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.spacing3xs),
          Text(
            'We will send a 6-digit one-time password (OTP) to securely authenticate your account and connect to verified cooperatives.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.onErrorContainer, size: 20),
          const SizedBox(width: AppSpacing.spacingXs),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodySm.copyWith(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileInputCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mobile Number',
            style: AppTypography.labelMd.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.spacing2xs),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusLg,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
            child: Row(
              children: [
                // Mock Indian Flag
                Container(
                  width: 20,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
                  ),
                  child: Column(
                    children: [
                      Expanded(child: Container(color: const Color(0xFFFF9933))),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: const Icon(Icons.circle_outlined, size: 4, color: Color(0xFF000080)),
                        ),
                      ),
                      Expanded(child: Container(color: const Color(0xFF138808))),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Text(
                  '+91',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    readOnly: _isOtpSent,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '90000 00000',
                    ),
                  ),
                ),
                if (_isOtpSent)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.tertiaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 16, color: AppColors.onTertiaryFixed),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingLg),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('OTP sent to ', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface)),
                  Text(
                    '+91 ${_phoneController.text}',
                    style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: _handleEditPhone,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: AppSpacing.spacing3xs),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Edit',
                  style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          _buildOtpInputBoxes(),
          const SizedBox(height: AppSpacing.spacingSm),
          _buildResendSection(),
        ],
      ),
    );
  }

  Widget _buildOtpInputBoxes() {
    return Stack(
      children: [
        // The hidden text field that captures input
        Opacity(
          opacity: 0.0,
          child: TextField(
            controller: _otpController,
            focusNode: _otpFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onChanged: (val) {
              setState(() {});
              if (val.length == 6) {
                // Auto-submit when 6 digits are entered
                _handlePrimaryAction();
              }
            },
          ),
        ),
        // The visual boxes
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final String text = _otpController.text;
              final bool isFocused = _otpFocusNode.hasFocus && text.length == index;
              final bool hasValue = text.length > index;
              final String char = hasValue ? text[index] : '';

              return Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: EdgeInsets.only(right: index < 5 ? AppSpacing.spacing2xs : 0),
                    decoration: BoxDecoration(
                      color: isFocused ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.radiusLg,
                      boxShadow: isFocused ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
                    ),
                    alignment: Alignment.center,
                    child: hasValue
                        ? Text(
                            char,
                            style: AppTypography.currencyDisplay.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : isFocused
                            ? _BlinkingCursor()
                            : const SizedBox.shrink(),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.outline),
                const SizedBox(width: AppSpacing.spacing3xs),
                Text(
                  _secondsRemaining > 0 ? 'Resend OTP in 00:${_secondsRemaining.toString().padLeft(2, '0')}s' : 'OTP expired. Please resend.',
                  style: AppTypography.labelSm.copyWith(
                    color: _secondsRemaining > 0 ? AppColors.outline : AppColors.secondary,
                  ),
                ),
              ],
            ),
            if (_secondsRemaining == 0)
              TextButton.icon(
                onPressed: () {
                  _startCountdown();
                  // In real app, call resend API
                },
                icon: const Icon(Icons.sms_outlined, size: 16),
                label: const Text('Resend via SMS'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacing3xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Didn\'t receive SMS?', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: AppSpacing.spacing3xs),
              decoration: BoxDecoration(
                color: AppColors.tertiaryFixed.withOpacity(0.3),
                borderRadius: AppRadius.radiusFull,
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_outlined, size: 16, color: AppColors.onTertiaryFixedVariant),
                  const SizedBox(width: AppSpacing.spacing3xs),
                  Text(
                    'Get on WhatsApp',
                    style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryFixedVariant, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.spacing4xs),
            child: Icon(Icons.lock_outline, size: 20, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cooperative Escrow Protected',
                  style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Protected under National Cooperative Data Charter. Your phone number is strictly encrypted and never shared with third-party telemarketers.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCta() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePrimaryAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
            elevation: 2,
          ),
          child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2))
            : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isOtpSent ? 'Verify & Continue' : 'Get OTP',
                  style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTypography.bodySm.copyWith(color: AppColors.outline),
            children: [
              const TextSpan(text: 'By proceeding, you agree to the\n'),
              TextSpan(
                text: 'ShramSetu Cooperative Terms',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  decoration: TextDecoration.underline,
                ),
              ),
              const TextSpan(text: ' & '),
              TextSpan(
                text: 'Worker Charter Privacy Policy',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  decoration: TextDecoration.underline,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativeModeSwitch() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.spacingXl),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd, vertical: AppSpacing.spacingXs),
          decoration: BoxDecoration(
            color: AppColors.secondaryFixed.withOpacity(0.3),
            borderRadius: AppRadius.radiusFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 16, color: AppColors.onSecondaryFixedVariant),
              const SizedBox(width: AppSpacing.spacing2xs),
              Text(
                'Are you looking for a worker?',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSecondaryFixedVariant),
              ),
              const SizedBox(width: AppSpacing.spacing4xs),
              GestureDetector(
                onTap: () => Navigator.of(context).pushReplacementNamed('/login/customer'),
                child: Text(
                  'Switch to Customer Sign-in →',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 24,
        color: AppColors.secondary,
      ),
    );
  }
}
