import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Called with a Google Play purchase; returns true once the server has
/// accepted it (only then is the purchase completed with Google).
typedef PurchaseHandler = Future<bool> Function(String productId, String purchaseToken);

/// Buying the subscription in the store. Abstract so tests run without Google Play.
abstract class Billing {
  /// Set by [AccountService]: sends each purchase to the server.
  PurchaseHandler? onPurchase;

  /// A problem with the last purchase, to show to the user.
  ValueListenable<String?> get message;

  /// The subscription's price as the store shows it ("€2.99"), or null if
  /// the store or the product is not available.
  Future<String?> price();

  /// Starts the store's purchase flow. [accountId] ties the purchase to the account.
  Future<void> buy(String accountId);

  /// Asks the store to send earlier purchases again (e.g. after reinstalling).
  Future<void> restore(String accountId);

  void dispose();
}

/// Google Play subscriptions through `in_app_purchase`.
///
/// The product id comes from `--dart-define=SUBSCRIPTION_PRODUCT_ID=...` and
/// must match the subscription created in Google Play Console.
class PlayBilling implements Billing {
  PlayBilling({String? productId})
      : productId = productId ?? const String.fromEnvironment('SUBSCRIPTION_PRODUCT_ID', defaultValue: 'social_stories_premium') {
    _subscription = _iap.purchaseStream.listen(_onPurchases, onError: (Object error) {
      _message.value = 'The purchase could not be completed. Please try again.';
    });
  }

  final String productId;
  final InAppPurchase _iap = InAppPurchase.instance;
  final ValueNotifier<String?> _message = ValueNotifier<String?>(null);
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  ProductDetails? _product;

  @override
  PurchaseHandler? onPurchase;

  @override
  ValueListenable<String?> get message => _message;

  Future<ProductDetails?> _loadProduct() async {
    if (_product != null) return _product;
    try {
      if (!await _iap.isAvailable()) return null;
      final response = await _iap.queryProductDetails({productId});
      _product = response.productDetails.isEmpty ? null : response.productDetails.first;
    } catch (error) {
      debugPrint('Could not load the subscription from the store: $error');
    }
    return _product;
  }

  @override
  Future<String?> price() async => (await _loadProduct())?.price;

  @override
  Future<void> buy(String accountId) async {
    _message.value = null;
    final product = await _loadProduct();
    if (product == null) {
      _message.value = 'The subscription is not available in the store right now.';
      return;
    }
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product, applicationUserName: accountId));
  }

  @override
  Future<void> restore(String accountId) => _iap.restorePurchases(applicationUserName: accountId);

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _message.value = 'Waiting for the payment to go through…';
        case PurchaseStatus.error:
          _message.value = 'The purchase could not be completed. Please try again.';
        case PurchaseStatus.canceled:
          _message.value = null;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final handler = onPurchase;
          if (handler == null || purchase.productID != productId) continue;
          final accepted = await handler(purchase.productID, purchase.verificationData.serverVerificationData);
          // Only acknowledge a purchase the server has recorded; Google refunds
          // purchases that are never acknowledged, so nothing is lost.
          if (accepted && purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
          _message.value = accepted ? null : 'The purchase went through, but the server could not confirm it yet.';
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _message.dispose();
  }
}

/// No store: tests, or platforms without Google Play.
class NoBilling implements Billing {
  final ValueNotifier<String?> _message = ValueNotifier<String?>(null);

  @override
  PurchaseHandler? onPurchase;

  @override
  ValueListenable<String?> get message => _message;

  @override
  Future<String?> price() async => null;

  @override
  Future<void> buy(String accountId) async {}

  @override
  Future<void> restore(String accountId) async {}

  @override
  void dispose() => _message.dispose();
}
