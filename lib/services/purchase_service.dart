import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'cloud_service.dart';

class PurchaseService extends ChangeNotifier {
  static const monthlyId = 'vadesi_premium_monthly';
  static const yearlyId = 'vadesi_premium_yearly';
  final CloudService cloud;
  PurchaseService(this.cloud);
  List<ProductDetails> products = [];
  bool loading = false;
  String? message;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _disposed = false;
  final Set<String> _processing = {};
  bool get supported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> initialize() async {
    if (!supported) return;
    _subscription = InAppPurchase.instance.purchaseStream.listen((purchases) {
      unawaited(_process(purchases));
    }, onError: (Object _) { message = 'Mağaza bağlantısı başarısız.'; _notify(); });
  }

  Future<void> loadProducts() async {
    if (!supported || !cloud.ready) {
      message = 'Satın alma bağlantısı henüz etkin değil.';
      _notify();
      return;
    }
    loading = true;
    _notify();
    try {
      if (!await InAppPurchase.instance.isAvailable()) throw StateError('Mağaza kullanılamıyor.');
      final response = await InAppPurchase.instance.queryProductDetails({monthlyId, yearlyId});
      products = response.productDetails;
      message = response.error?.message;
      if (products.isEmpty) message = 'Mağazada abonelik ürünleri henüz yayınlanmamış.';
    } catch (_) {
      message = 'Abonelikler alınamadı. Daha sonra tekrar deneyin.';
    } finally {
      loading = false;
      _notify();
    }
  }

  String _accountToken() {
    final digest = sha256.convert(utf8.encode(cloud.user!.uid)).toString();
    return '${digest.substring(0, 8)}-${digest.substring(8, 12)}-4${digest.substring(13, 16)}-a${digest.substring(17, 20)}-${digest.substring(20, 32)}';
  }

  Future<void> buy(ProductDetails product) async {
    if (cloud.user == null) throw StateError('Satın almadan önce hesabınıza giriş yapın.');
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product, applicationUserName: _accountToken()));
  }

  Future<void> restore() async {
    if (cloud.user == null) throw StateError('Önce hesabınıza giriş yapın.');
    await InAppPurchase.instance.restorePurchases();
    message = 'Mağazadaki satın almalar kontrol ediliyor.';
    _notify();
  }

  Future<void> _process(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        message = 'Mağaza onayı bekleniyor.';
      } else if (purchase.status == PurchaseStatus.error || purchase.status == PurchaseStatus.canceled) {
        message = purchase.status == PurchaseStatus.canceled ? 'Satın alma iptal edildi.' : 'Satın alma tamamlanamadı.';
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        final key = '${purchase.productID}:${purchase.purchaseID}';
        if (!_processing.add(key)) continue;
        try {
          if (cloud.user == null) throw StateError('Giriş yapıp satın almaları geri yükleyin.');
          await cloud.functions.httpsCallable('verifyPurchase').call({
            'store': defaultTargetPlatform == TargetPlatform.android ? 'google' : 'apple',
            'productId': purchase.productID,
            'transactionId': purchase.purchaseID,
            'verificationData': purchase.verificationData.serverVerificationData,
          });
          if (purchase.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(purchase);
          message = 'Satın alma sunucuda doğrulandı.';
        } catch (_) {
          message = 'Satın alma doğrulanamadı. Hesabınıza giriş yapıp “Satın almaları geri yükle” seçeneğini kullanın.';
        } finally {
          _processing.remove(key);
        }
      }
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
