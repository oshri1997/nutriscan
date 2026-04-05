import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;

  static const _features = [
    (Icons.all_inclusive_rounded, 'Unlimited AI Scans'),
    (Icons.insights_rounded, 'Advanced Macro Analytics'),
    (Icons.history_rounded, 'Full History & Trends'),
    (Icons.star_rounded, 'Favorite Meals & Templates'),
    (Icons.support_agent_rounded, 'Priority Support'),
  ];

  Future<void> _presentPaywall() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // presentPaywall() shows the RevenueCat pre-built paywall
      // It returns after the user dismisses the paywall
      await RevenueCatUI.presentPaywall();

      // After paywall is dismissed, check if user now has Pro
      final customerInfo = await Purchases.getCustomerInfo();
      final hasPro = customerInfo
              .entitlements.all[AppConstants.proEntitlementId]
              ?.isActive ==
          true;

      if (hasPro) {
        await context.read<UserProvider>().setPro(true);
        if (mounted) Navigator.pop(context);
      }
    } on PlatformException catch (e) {
      final msg = e.message?.toLowerCase() ?? '';
      if (!msg.contains('cancelled')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: const Color(0xFFb71c1c),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load paywall: $e'),
            backgroundColor: const Color(0xFFb71c1c),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restorePurchases() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final purchaserInfo = await Purchases.restorePurchases();
      final hasPro = purchaserInfo.entitlements
              .all[AppConstants.proEntitlementId]
              ?.isActive ==
          true;

      if (!mounted) return;

      if (hasPro) {
        await context.read<UserProvider>().setPro(true);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous purchases found to restore.'),
            backgroundColor: Color(0xFF003300),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore purchases: $e'),
          backgroundColor: const Color(0xFFb71c1c),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppTheme.onSurface),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // PRO Badge
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded,
                        color: Color(0xFF003300), size: 32),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color: Color(0xFF003300),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Upgrade to Pro',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text(
                'Unlock the full power of NutriSnap',
                style: TextStyle(color: AppTheme.onCard, fontSize: 14),
              ),
              const SizedBox(height: 28),

              // Feature list
              ..._buildFeatureList(),

              const Spacer(),

              // CTA Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: _loading ? null : _presentPaywall,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _loading
                          ? LinearGradient(colors: [
                              AppTheme.primary.withValues(alpha: 0.5),
                              AppTheme.secondary.withValues(alpha: 0.5),
                            ])
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF003300),
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Start Free Trial',
                              style: TextStyle(
                                color: Color(0xFF003300),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '3-day free trial, cancel anytime',
                style: TextStyle(fontSize: 12, color: AppTheme.onCard),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _launchUrl('https://www.nutrisnap.app/terms'),
                    child: const Text('Terms',
                        style: TextStyle(fontSize: 11, color: AppTheme.onCard)),
                  ),
                  TextButton(
                    onPressed: () => _launchUrl('https://www.nutrisnap.app/privacy'),
                    child: const Text('Privacy',
                        style: TextStyle(fontSize: 11, color: AppTheme.onCard)),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _restorePurchases,
                    child: const Text('Restore',
                        style: TextStyle(fontSize: 11, color: AppTheme.onCard)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeatureList() {
    return _features.map((f) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(f.$1, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              f.$2,
              style: const TextStyle(
                color: AppTheme.onBackground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
