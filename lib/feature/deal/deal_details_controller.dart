import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;
  final DealModel? initialDeal;
  final int? dealId;
  final String source;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
    this.initialDeal,
    this.dealId,
    this.source = 'unknown',
  });

  final deal = Rxn<DealModel>();
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;
  Worker? _cartCountWorker;
  int? _requestedDealId;
  int _loadGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    if (initialDeal != null) {
      _setDeal(initialDeal!);
      isLoading.value = false;
    } else {
      if (dealId == null) {
        isLoading.value = false;
        errorMessage.value = 'Deal link is invalid.';
      } else {
        _requestedDealId = dealId;
        loadDeal(dealId!);
      }
    }
    // Whenever the cart changes, re-check this deal's remaining stock so the
    // details screen never shows stale availability.
    _cartCountWorker =
        ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  @override
  void onClose() {
    _loadGeneration++;
    _cartCountWorker?.dispose();
    super.onClose();
  }

  void retryLoad() {
    final id = _requestedDealId;
    if (id != null) loadDeal(id);
  }

  Future<void> loadDeal(int id) async {
    final generation = ++_loadGeneration;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final fetched = await dealRepo.fetchById(id);
      if (generation != _loadGeneration) return;
      _setDeal(fetched);
    } catch (e) {
      if (generation != _loadGeneration) return;
      LogService.error('load deal details failed', e);
      errorMessage.value = 'Could not load this deal. Please try again.';
    } finally {
      if (generation == _loadGeneration) isLoading.value = false;
    }
  }

  void _setDeal(DealModel value) {
    deal.value = value;
    _quantityLeft.value = value.quantityLeft;
    analytics.logEvent('deal_details_view', {
      'deal_id': value.id,
      'source': source,
    });
  }

  Future<void> _recheckAvailability() async {
    final currentDeal = deal.value;
    if (currentDeal == null) return;
    LogService.log('re-checking availability for deal ${currentDeal.id}');
    final fresh = await dealRepo.fetchById(currentDeal.id);
    _quantityLeft.value = fresh.quantityLeft;
  }

  void addToCart() {
    final currentDeal = deal.value;
    if (currentDeal == null) return;
    final flashSaleEndsAt = currentDeal.flashSaleEndsAt;
    if (flashSaleEndsAt != null && !flashSaleEndsAt.isAfter(DateTime.now())) {
      Get.snackbar(
        'Flash sale ended',
        '${currentDeal.name} is no longer available in the flash sale.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    unawaited(cartService.add(currentDeal));
    Get.snackbar(
      'Added to bag',
      '${currentDeal.name} — reserving stock now.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
