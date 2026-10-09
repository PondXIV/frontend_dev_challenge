import 'dart:async';

import 'package:get/get.dart';

import '../model/deal_model.dart';
import 'cart_service.dart';

class FlashSaleCountdownService extends GetxService {
  final CartService cartService;
  final DateTime Function() clock;
  final void Function(List<String> removedNames)? onExpiredItemsRemoved;

  FlashSaleCountdownService({
    required this.cartService,
    DateTime Function()? clock,
    this.onExpiredItemsRemoved,
  }) : clock = clock ?? DateTime.now;

  final now = DateTime.now().obs;
  final expiredDealIds = <int>{}.obs;
  final Map<int, DateTime> _deadlines = {};
  final Map<int, int> _watchers = {};
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    refreshNow();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refreshNow());
  }

  void register(DealModel deal) {
    final deadline = deal.flashSaleEndsAt;
    if (deadline == null) return;
    _deadlines[deal.id] = deadline;
    _watchers.update(deal.id, (count) => count + 1, ifAbsent: () => 1);
    if (!deadline.isAfter(clock())) _markExpired({deal.id});
  }

  void unregister(DealModel deal) {
    final remaining = (_watchers[deal.id] ?? 1) - 1;
    if (remaining <= 0) {
      _watchers.remove(deal.id);
      if (!expiredDealIds.contains(deal.id)) _deadlines.remove(deal.id);
    } else {
      _watchers[deal.id] = remaining;
    }
  }

  void refreshNow() {
    final currentTime = clock();
    now.value = currentTime;

    final newlyExpired = <int>{};
    for (final entry in _deadlines.entries) {
      if (!entry.value.isAfter(currentTime)) newlyExpired.add(entry.key);
    }
    for (final item in cartService.items) {
      final deadline = item.deal.flashSaleEndsAt;
      if (deadline != null && !deadline.isAfter(currentTime)) {
        newlyExpired.add(item.deal.id);
      }
    }
    _markExpired(newlyExpired);
  }

  void _markExpired(Set<int> dealIds) {
    final newlyExpired = dealIds.difference(expiredDealIds);
    if (newlyExpired.isEmpty) return;
    expiredDealIds.addAll(newlyExpired);
    final removedNames = cartService.removeExpiredFlashDeals(newlyExpired);
    if (removedNames.isNotEmpty) {
      final notify = onExpiredItemsRemoved;
      if (notify != null) {
        notify(removedNames);
      } else {
        Get.snackbar(
          'Flash sale ended',
          '${removedNames.join(', ')} ${removedNames.length == 1 ? 'was' : 'were'} removed from your bag.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
