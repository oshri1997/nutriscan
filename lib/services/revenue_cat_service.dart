import 'package:purchases_flutter/purchases_flutter.dart';
import '../utils/constants.dart';

class RevenueCatService {
  /// The RevenueCat app user ID (anonymous or signed in) - async in v9+
  Future<String> get appUserId async => await Purchases.appUserID;

  /// Check if the user has an active Pro entitlement
  Future<bool> hasProAccess() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[AppConstants.proEntitlementId]?.isActive == true;
    } catch (e) {
      return false;
    }
  }

  /// Get current customer info including subscription status
  Future<CustomerInfo> getCustomerInfo() async {
    return Purchases.getCustomerInfo();
  }

  /// Purchase a package (subscription)
  /// [package] The package to purchase (from offerings)
  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      // PurchaseResult has customerInfo property
      return result.customerInfo.entitlements.all[AppConstants.proEntitlementId]?.isActive == true;
    } catch (e) {
      // In v9 there is no CancelledException - check error message
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancelled') || msg.contains('cancel')) {
        return false;
      }
      rethrow;
    }
  }

  /// Restore purchases - useful when user needs to restore subscription
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all[AppConstants.proEntitlementId]?.isActive == true;
    } catch (e) {
      rethrow;
    }
  }

  /// Get current offerings (available subscriptions)
  Future<Offerings> getOfferings() async {
    return Purchases.getOfferings();
  }

  /// Check if billing is available (Google Play on Android, App Store on iOS)
  Future<bool> isBillingAvailable() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current != null;
    } catch (e) {
      return false;
    }
  }

  /// Log out the current user (anonymous or signed in)
  /// This creates a new anonymous user
  Future<void> logOut() async {
    await Purchases.logOut();
  }

  /// Log in with a specific user ID (for linking to your own auth system)
  /// Returns the CustomerInfo from the login result
  Future<CustomerInfo> logIn(String appUserId) async {
    final result = await Purchases.logIn(appUserId);
    return result.customerInfo;
  }
}
