import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../repository/order_repo.dart';
import '../util/log_service.dart';

/// App-wide cart with optimistic stock reservations.
class CartService extends GetxService {
  final OrderRepo orderRepo;
  final void Function(String title, String message)? onNotice;

  CartService({required this.orderRepo, this.onNotice});

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  final now = DateTime.now().toUtc().obs;
  final isCheckoutLocked = false.obs;

  final Map<int, CartItemModel> _linesByDeal = {};
  Timer? _reservationTimer;
  int _nextPendingId = 0;

  Future<void> add(DealModel deal) async {
    if (isCheckoutLocked.value) return;
    final flashSaleEndsAt = deal.flashSaleEndsAt;
    if (flashSaleEndsAt != null && !flashSaleEndsAt.isAfter(DateTime.now())) {
      LogService.log('cart: flash sale ended for deal ${deal.id}');
      return;
    }

    final line = _linesByDeal[deal.id];
    if ((line?.quantity ?? 0) >= deal.quantityLeft) {
      LogService.log('cart: cannot add more of deal ${deal.id}');
      return;
    }

    final cartLine = line ?? CartItemModel(deal: deal, quantity: 0);
    if (line == null) {
      _linesByDeal[deal.id] = cartLine;
      items.add(cartLine);
    }

    final pendingId = ++_nextPendingId;
    cartLine.pendingReservationIds.add(pendingId);
    cartLine.pendingReservations.value++;
    cartLine.quantity++;
    items.refresh();
    _recount();

    try {
      final reservation = await orderRepo.reserve(deal.id);
      final currentLine = _linesByDeal[deal.id];
      if (currentLine != null &&
          currentLine == cartLine &&
          currentLine.pendingReservationIds.remove(pendingId)) {
        currentLine.pendingReservations.value--;
        currentLine.reservations.add(reservation);
        _ensureReservationTimer();
        items.refresh();
      } else {
        await _releaseReservation(reservation.id);
      }
    } catch (error) {
      LogService.error('reserve deal ${deal.id} failed', error);
      final currentLine = _linesByDeal[deal.id];
      if (currentLine != null &&
          currentLine == cartLine &&
          currentLine.pendingReservationIds.remove(pendingId)) {
        currentLine.pendingReservations.value--;
        currentLine.quantity--;
        if (currentLine.quantity <= 0) {
          _removeLine(currentLine);
        } else {
          items.refresh();
        }
        _recount();
        _showNotice(
          'Could not add item',
          'Someone else may have taken the last one. Please try again.',
        );
      }
    }
  }

  void decrement(int dealId) {
    if (isCheckoutLocked.value) return;
    final line = _linesByDeal[dealId];
    if (line == null) return;

    if (line.pendingReservationIds.isNotEmpty) {
      line.pendingReservationIds.remove(line.pendingReservationIds.last);
      line.pendingReservations.value--;
    } else if (line.reservations.isNotEmpty) {
      final reservation = line.reservations.removeLast();
      unawaited(_releaseReservation(reservation.id));
    } else {
      return;
    }

    line.quantity--;
    if (line.quantity <= 0) {
      _removeLine(line);
    } else {
      items.refresh();
    }
    _recount();
    _stopTimerIfIdle();
  }

  void remove(int dealId) {
    if (isCheckoutLocked.value) return;
    final line = _linesByDeal[dealId];
    if (line == null) return;
    _removeLine(line);
    for (final reservation in line.reservations) {
      unawaited(_releaseReservation(reservation.id));
    }
    line.reservations.clear();
    _recount();
    _stopTimerIfIdle();
  }

  List<String> removeExpiredFlashDeals(Set<int> dealIds) {
    final removedItems = items
        .where((item) => dealIds.contains(item.deal.id))
        .toList(growable: false);
    for (final line in removedItems) {
      _removeLine(line);
      for (final reservation in line.reservations) {
        unawaited(_releaseReservation(reservation.id));
      }
      line.reservations.clear();
    }
    _recount();
    _stopTimerIfIdle();
    return removedItems.map((item) => item.deal.name).toList(growable: false);
  }

  void clear({bool releaseReservations = true}) {
    final reservations = [
      for (final line in items)
        if (releaseReservations) ...line.reservations,
    ];
    items.clear();
    _linesByDeal.clear();
    _recount();
    _stopTimerIfIdle();
    for (final reservation in reservations) {
      unawaited(_releaseReservation(reservation.id));
    }
  }

  List<CartItemModel>? beginCheckout() {
    if (isCheckoutLocked.value || items.isEmpty) return null;
    expireReservations();
    if (items.isEmpty || items.any((line) => line.isReserving)) return null;
    isCheckoutLocked.value = true;
    return items.toList(growable: false);
  }

  void endCheckout() {
    isCheckoutLocked.value = false;
  }

  void handleExpiredCheckout() {
    clear();
    _showNotice(
      'Reservation expired',
      'Your bag could not be checked out because an item hold expired. Please add the items again.',
    );
  }

  num get total => items.fold(0, (sum, item) => sum + item.lineTotal);

  Future<void> _releaseReservation(String reservationId) async {
    try {
      await orderRepo.releaseReservation(reservationId);
    } catch (error) {
      LogService.error('release reservation $reservationId failed', error);
      _showNotice(
        'Could not release item hold',
        'The item was removed from your bag, but its stock hold could not be released yet.',
      );
    }
  }

  void expireReservations() {
    now.value = DateTime.now().toUtc();
    final expiredNames = <String>[];
    for (final line in items.toList(growable: false)) {
      final expired = line.reservations
          .where((reservation) => !reservation.expiresAt.isAfter(now.value))
          .toList(growable: false);
      if (expired.isEmpty) continue;

      line.reservations.removeWhere(
        (reservation) => !reservation.expiresAt.isAfter(now.value),
      );
      line.quantity -= expired.length;
      expiredNames.add(line.deal.name);
      if (line.quantity <= 0) {
        _removeLine(line);
      } else {
        items.refresh();
      }
    }

    _recount();
    if (expiredNames.isNotEmpty) {
      _showNotice(
        'Item hold expired',
        '${expiredNames.join(', ')} ${expiredNames.length == 1 ? 'was' : 'were'} removed from your bag. Add it again to reserve stock.',
      );
    }
    _stopTimerIfIdle();
  }

  void _ensureReservationTimer() {
    _reservationTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => expireReservations(),
    );
  }

  void _stopTimerIfIdle() {
    if (items.every((line) => line.reservations.isEmpty)) {
      _reservationTimer?.cancel();
      _reservationTimer = null;
    }
  }

  void _removeLine(CartItemModel line) {
    _linesByDeal.remove(line.deal.id);
    items.remove(line);
  }

  void _recount() {
    itemCount.value = items.fold(0, (sum, item) => sum + item.quantity);
  }

  void _showNotice(String title, String message) {
    final notify = onNotice;
    if (notify != null) {
      notify(title, message);
    } else if (Get.context != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  void onClose() {
    _reservationTimer?.cancel();
    for (final line in items) {
      for (final reservation in line.reservations) {
        unawaited(_releaseReservation(reservation.id));
      }
    }
    super.onClose();
  }
}
