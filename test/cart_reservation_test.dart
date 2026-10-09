import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/cart/cart_controller.dart';
import 'package:rescu/model/cart_item_model.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/order_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/model/reservation_model.dart';
import 'package:rescu/repository/order_repo.dart';
import 'package:rescu/service/api_exception.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/fake_api_service.dart';

void main() {
  late _OrderRepo repo;
  late CartService cart;
  late List<String> notices;

  setUp(() {
    repo = _OrderRepo();
    notices = [];
    cart = CartService(
      orderRepo: repo,
      onNotice: (title, message) => notices.add('$title: $message'),
    );
  });

  tearDown(() {
    cart.onClose();
  });

  test('adds optimistically, then attaches the successful reservation',
      () async {
    final add = cart.add(_deal());

    expect(cart.items.single.quantity, 1);
    expect(cart.items.single.isReserving, isTrue);
    expect(cart.itemCount.value, 1);

    repo.reservations.single.complete(_reservation());
    await add;

    expect(cart.items.single.isReserving, isFalse);
    expect(cart.items.single.reservations.single.id, 'res_42');
    expect(cart.items.single.reservations.single.expiresAt, isA<DateTime>());
  });

  test('does not reserve a deal with no stock', () async {
    await cart.add(_deal(quantityLeft: 0));

    expect(cart.items, isEmpty);
    expect(repo.reservations, isEmpty);
  });

  test('rolls back optimistic line and shows a friendly message on failure',
      () async {
    final add = cart.add(_deal());
    repo.reservations.single.completeError(
      const ApiException('conflict', statusCode: 409),
    );
    await add;

    expect(cart.items, isEmpty);
    expect(cart.itemCount.value, 0);
    expect(
        notices.single, contains('Someone else may have taken the last one'));
  });

  test('decrement releases one hold and remove releases remaining holds',
      () async {
    final firstAdd = cart.add(_deal());
    repo.reservations[0].complete(_reservation(id: 'res_1'));
    await firstAdd;
    final secondAdd = cart.add(_deal());
    repo.reservations[1].complete(_reservation(id: 'res_2'));
    await secondAdd;

    cart.decrement(42);
    expect(cart.items.single.quantity, 1);
    expect(repo.releasedIds, ['res_2']);

    cart.remove(42);
    expect(cart.items, isEmpty);
    expect(repo.releasedIds, ['res_2', 'res_1']);
  });

  test(
      'releases a reservation that arrives after its optimistic line was removed',
      () async {
    final add = cart.add(_deal());
    cart.remove(42);
    repo.reservations.single.complete(_reservation(id: 'res_removed'));
    await add;

    expect(cart.items, isEmpty);
    expect(repo.releasedIds, ['res_removed']);
  });

  test('expiry removes the expired unit and notifies the user', () async {
    final firstAdd = cart.add(_deal());
    repo.reservations[0].complete(
      _reservation(
        id: 'res_expired',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      ),
    );
    await firstAdd;

    cart.expireReservations();

    expect(cart.items, isEmpty);
    expect(notices.single, contains('Add it again to reserve stock'));
  });

  test('410 checkout clears stale holds and tells user to rebuild bag',
      () async {
    final add = cart.add(_deal());
    repo.reservations.single.complete(_reservation());
    await add;
    repo.checkoutError = const ApiException('expired', statusCode: 410);
    final controller = CartController(cartService: cart, orderRepo: repo);

    await controller.checkout();

    expect(cart.items, isEmpty);
    expect(repo.releasedIds, ['res_42']);
    expect(notices.single, contains('Please add the items again'));
    expect(cart.isCheckoutLocked.value, isFalse);
  });

  test('checkout payload uses the reservation id and reserved quantity',
      () async {
    final api = _RecordingApi();
    final orderRepo = OrderRepo(api: api);
    await orderRepo.checkout([
      CartItemModel(
        deal: _deal(),
        reservations: [_reservation(id: 'res_payload')],
      ),
    ]);

    expect(api.checkoutItems, [
      {
        'dealId': 42,
        'quantity': 1,
        'reservationId': 'res_payload',
      },
    ]);
  });
}

class _OrderRepo extends OrderRepo {
  _OrderRepo() : super(api: FakeApiService());

  final reservations = <Completer<ReservationModel>>[];
  final releasedIds = <String>[];
  Object? checkoutError;

  @override
  Future<ReservationModel> reserve(int dealId, {int quantity = 1}) {
    final reservation = Completer<ReservationModel>();
    reservations.add(reservation);
    return reservation.future;
  }

  @override
  Future<void> releaseReservation(String reservationId) async {
    releasedIds.add(reservationId);
  }

  @override
  Future<OrderModel> checkout(List<CartItemModel> items) async {
    final error = checkoutError;
    if (error != null) throw error;
    return _order();
  }
}

class _RecordingApi extends FakeApiService {
  List<Map<String, dynamic>>? checkoutItems;

  @override
  Future<Map<String, dynamic>> checkout(
      List<Map<String, dynamic>> items) async {
    checkoutItems = items;
    return {
      'id': 1,
      'dealId': 42,
      'dealName': 'Test order',
      'storeName': 'Store',
      'imageUrl': '',
      'status': 'CONFIRMED',
      'quantity': 1,
      'total': 5,
      'currencyCode': 'THB',
      'pickupStart': DateTime.now().toUtc().toIso8601String(),
      'pickupEnd': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 2))
          .toIso8601String(),
    };
  }
}

ReservationModel _reservation({
  String id = 'res_42',
  DateTime? expiresAt,
}) =>
    ReservationModel(
      id: id,
      dealId: 42,
      quantity: 1,
      expiresAt:
          expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

DealModel _deal({int quantityLeft = 4}) => DealModel(
      id: 42,
      name: 'Surprise bag',
      description: '',
      imageUrl: '',
      originalPrice: 10,
      price: 5,
      currencyCode: 'THB',
      quantityLeft: quantityLeft,
      storeId: 1,
      storeName: 'Store',
      storeAddress: '',
      lat: 0,
      lng: 0,
      rating: null,
      tags: const [],
      pickupWindow: PickupWindowModel(
        start: DateTime.utc(2026),
        end: DateTime.utc(2026, 1, 1, 1),
      ),
      flashSaleEndsAt: null,
    );

OrderModel _order() => OrderModel(
      id: 1,
      dealId: 42,
      dealName: 'Order',
      storeName: 'Store',
      imageUrl: '',
      status: 'CONFIRMED',
      quantity: 1,
      total: 5,
      currencyCode: 'THB',
      pickupStart: DateTime.now().toUtc(),
      pickupEnd: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
