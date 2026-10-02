import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../data/models/worker_models.dart';
import '../screens/worker_profile_settings_screen.dart';

class WorkerTopAppBarActions extends StatefulWidget {
  final WorkerProfile? worker;
  final bool showAvatar;
  final VoidCallback? onLanguageChanged;

  const WorkerTopAppBarActions({
    super.key,
    this.worker,
    this.showAvatar = true,
    this.onLanguageChanged,
  });

  @override
  State<WorkerTopAppBarActions> createState() => _WorkerTopAppBarActionsState();
}

class _WorkerTopAppBarActionsState extends State<WorkerTopAppBarActions> {
  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spacingMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.language, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Language / भाषा निवडा',
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'Choose your preferred interface language',
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageOption(
                    modalContext: modalContext,
                    code: 'mr',
                    nativeTitle: 'मराठी (Marathi)',
                    subtitle: 'स्थानिक युनियन भाषा (Recommended)',
                    icon: 'म',
                  ),
                  const SizedBox(height: 8),
                  _buildLanguageOption(
                    modalContext: modalContext,
                    code: 'en',
                    nativeTitle: 'English',
                    subtitle: 'Default system interface',
                    icon: 'EN',
                  ),
                  const SizedBox(height: 8),
                  _buildLanguageOption(
                    modalContext: modalContext,
                    code: 'hi',
                    nativeTitle: 'हिंदी (Hindi)',
                    subtitle: 'राष्ट्रीय भाषा इंटरफेस',
                    icon: 'हिं',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext modalContext,
    required String code,
    required String nativeTitle,
    required String subtitle,
    required String icon,
  }) {
    final isSelected = LocaleController.instance.languageCode == code;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          LocaleController.instance.setLanguage(code);
          Navigator.pop(modalContext);
          widget.onLanguageChanged?.call();

          final message = code == 'mr'
              ? 'भाषा मराठी निवडली आहे (Language set to Marathi)'
              : code == 'hi'
                  ? 'भाषा हिंदी चुनी गई (Language set to Hindi)'
                  : 'Language switched to English';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : AppColors.outline,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportDesk(BuildContext context) {
    final worker = widget.worker;
    final guildName = worker?.guildName.isNotEmpty == true
        ? worker!.guildName
        : 'Pune District Labour Cooperative Federation';
    final guildId = worker?.guildId.isNotEmpty == true ? worker!.guildId : '101';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
            vertical: AppSpacing.spacingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.support_agent, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Worker Support & Guild Desk',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'कामगार सहाय्य व तक्रार निवारण कक्ष • Guild #$guildId',
                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  children: [
                    _buildSupportContactTile(
                      icon: Icons.phone_in_talk,
                      title: 'Union Cooperative Toll-Free Helpline',
                      subtitle: '1800-266-9090 (Toll-Free, 9 AM - 7 PM)',
                      badge: 'Toll-Free',
                      onTap: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calling Union Helpline: 1800-266-9090...'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 16),
                    _buildSupportContactTile(
                      icon: Icons.person_pin,
                      title: 'District Field Officer Desk',
                      subtitle: 'Shri Anant Deshmukh (+91 98231 45890)',
                      badge: 'Pune Lead',
                      onTap: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contacting Field Officer: +91 98231 45890'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 16),
                    _buildSupportContactTile(
                      icon: Icons.chat,
                      title: 'WhatsApp Federation Helpdesk',
                      subtitle: 'Quick chat for payout status & dispute support',
                      badge: 'WhatsApp',
                      onTap: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening WhatsApp Helpdesk for Pune Guild...'),
                            backgroundColor: AppColors.onTertiaryContainer,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Emergency SOS Safety / Grievance Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.error, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'On-Site Safety & Dispute SOS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            'Emergency response for safety risks or payment conflicts',
                            style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Emergency SOS dispatched to Pune District Federation!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('SOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  guildName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  void _openProfileSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WorkerProfileSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        final worker = widget.worker;
        final initials = worker?.name.isNotEmpty == true
            ? worker!.name
                .trim()
                .split(' ')
                .where((e) => e.isNotEmpty)
                .map((e) => e[0])
                .take(2)
                .join()
                .toUpperCase()
            : 'DA';

        final activeLang = LocaleController.instance.languageCode;
        final isMarathi = activeLang == 'mr';
        final isHindi = activeLang == 'hi';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Language Toggle Button (म/EN/हिं)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showLanguageSelector(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: isHindi ? 'हिं' : 'म',
                      style: TextStyle(
                        color: (isMarathi || isHindi) ? AppColors.onTertiaryContainer : AppColors.outline,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    TextSpan(
                      text: '/EN',
                      style: TextStyle(
                        color: activeLang == 'en' ? AppColors.primary : AppColors.outline,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 2. Support Agent Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showSupportDesk(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 34,
              height: 34,
              margin: EdgeInsets.only(
                right: widget.showAvatar ? 8 : AppSpacing.marginMobile,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.support_agent,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ),
        ),

        // 3. Avatar Button (Initials or Photo)
        if (widget.showAvatar)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openProfileSettings(context),
              borderRadius: BorderRadius.circular(17),
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: AppSpacing.marginMobile),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
        );
      },
    );
  }
}
