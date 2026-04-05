import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  CustomerInfo? _customerInfo;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCustomerInfo();
  }

  Future<void> _fetchCustomerInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = await Purchases.getCustomerInfo();
      if (mounted) {
        setState(() {
          _customerInfo = info;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load subscription info. Please try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCustomerPortal() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
      // Refresh customer info after returning from portal
      await _fetchCustomerInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open subscription portal.'),
          backgroundColor: Color(0xFFb71c1c),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
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
        await _fetchCustomerInfo();
      } else {
        setState(() => _loading = false);
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
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to restore purchases. Please try again later.'),
          backgroundColor: Color(0xFFb71c1c),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getDebugInfo() {
    if (_customerInfo == null) return 'No customer info';
    final allKeys = _customerInfo!.entitlements.all.keys.toList();
    final activeSubs = _customerInfo!.activeSubscriptions.toList();
    return 'Entitlement keys: $allKeys\nActive subs: $activeSubs\nApp UserID: ${_customerInfo!.originalAppUserId}';
  }

  String _getSubscriptionStatus() {
    if (_customerInfo == null) return 'Unknown';
    final entitlement =
        _customerInfo!.entitlements.all[AppConstants.proEntitlementId];
    if (entitlement == null) {
      // Debug: show what keys actually exist
      final allKeys = _customerInfo!.entitlements.all.keys.toList();
      return 'Inactive (no entitlement)\nDebug keys: $allKeys';
    }
    if (entitlement.isActive) {
      // Active subscription
      final willRenew = entitlement.willRenew ?? false;
      final expiry = entitlement.expirationDate;
      if (expiry != null) {
        final expiryDate = DateTime.tryParse(expiry);
        if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
          return 'Expired';
        }
      }
      return willRenew ? 'Active' : 'Active (Not Renewing)';
    }
    // Not active - check if it was active before (grace period, etc.)
    final expiry = entitlement.expirationDate;
    if (expiry != null) {
      final expiryDate = DateTime.tryParse(expiry);
      if (expiryDate != null && expiryDate.isAfter(DateTime.now())) {
        return 'Active'; // Still in grace period
      }
    }
    return 'Inactive';
  }

  String _getPlanName() {
    if (_customerInfo == null) return 'Unknown';
    final entitlement =
        _customerInfo!.entitlements.all[AppConstants.proEntitlementId];
    if (entitlement == null) return 'None';
    // productIdentifier might be empty in sandbox mode
    final id = entitlement.productIdentifier;
    if (id == null || id.isEmpty) {
      // Try to get from subscriptions
      final subs = _customerInfo!.activeSubscriptions;
      if (subs.isNotEmpty) {
        return subs.first;
      }
      return 'Pro';
    }
    return id;
  }

  String _getExpiryDate() {
    if (_customerInfo == null) return 'Unknown';
    final entitlement =
        _customerInfo!.entitlements.all[AppConstants.proEntitlementId];
    if (entitlement == null) return 'N/A';
    final expiry = entitlement.expirationDate;
    if (expiry == null || expiry.isEmpty) {
      // Sandbox/test purchases often don't have expiry
      return 'Lifetime';
    }
    final expiryDate = DateTime.tryParse(expiry);
    if (expiryDate == null) return 'N/A';
    return '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: AppTheme.onBackground, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Subscription',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBackground,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child:
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.onCard, fontSize: 14),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _fetchCustomerInfo,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Color(0xFF003300),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final status = _getSubscriptionStatus();
    final statusColor = status.startsWith('Active')
        ? AppTheme.primary
        : status.startsWith('Cancelled')
            ? AppTheme.error
            : AppTheme.onCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // PRO Badge
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Color(0xFF003300), size: 28),
                Text(
                  'PRO',
                  style: TextStyle(
                    color: Color(0xFF003300),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Status', value: status.split('\n').first, valueColor: statusColor),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.cardLight, height: 1),
                const SizedBox(height: 14),
                _InfoRow(label: 'Plan', value: _getPlanName()),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.cardLight, height: 1),
                const SizedBox(height: 14),
                _InfoRow(label: 'Renews on', value: _getExpiryDate()),
                // Debug info
                const SizedBox(height: 14),
                const Divider(color: AppTheme.cardLight, height: 1),
                const SizedBox(height: 14),
                Text(
                  'Debug: ${_getDebugInfo()}',
                  style: TextStyle(
                    color: AppTheme.onCard.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Note about cancellation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardLight),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.onCard, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Subscription changes (cancel, change plan) must be made through the RevenueCat portal.',
                    style: TextStyle(color: AppTheme.onCard, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Customer Portal button
          GestureDetector(
            onTap: _openCustomerPortal,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_rounded,
                        color: Color(0xFF003300), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Manage Subscription',
                      style: TextStyle(
                        color: Color(0xFF003300),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Restore Purchases button
          OutlinedButton(
            onPressed: _restorePurchases,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.onCard,
              side: const BorderSide(color: AppTheme.cardLight, width: 1.5),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Restore Purchases'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.onCard,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.onBackground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
