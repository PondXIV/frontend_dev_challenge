import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  void add(DealModel deal) {
    final flashSaleEndsAt = deal.flashSaleEndsAt;
    if (flashSaleEndsAt != null &&
        !flashSaleEndsAt.isAfter(DateTime.now())) {
      LogService.log('cart: flash sale ended for deal ${deal.id}');
      return;
    }
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _recount();
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  List<String> removeExpiredFlashDeals(Set<int> dealIds) {
    final removedItems = items
        .where((item) => dealIds.contains(item.deal.id))
        .toList(growable: false);
    if (removedItems.isEmpty) return const [];
    items.removeWhere((item) => dealIds.contains(item.deal.id));
    _recount();
    return removedItems.map((item) => item.deal.name).toList(growable: false);
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
