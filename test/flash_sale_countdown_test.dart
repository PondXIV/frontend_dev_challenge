import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/shared_widget/flash_sale_countdown_text.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/model/reservation_model.dart';
import 'package:rescu/repository/order_repo.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/flash_sale_countdown_service.dart';
import 'package:rescu/service/fake_api_service.dart';

void main() {
  late DateTime now;
  late CartService cartService;
  late FlashSaleCountdownService countdownService;
  final removalNotices = <List<String>>[];

  setUp(() {
    removalNotices.clear();
    now = DateTime.now().toUtc();
    cartService = CartService(orderRepo: _OrderRepo());
    Get.put<CartService>(cartService);
    countdownService = FlashSaleCountdownService(
      cartService: cartService,
      clock: () => now,
      onExpiredItemsRemoved: removalNotices.add,
    );
    Get.put<FlashSaleCountdownService>(countdownService);
  });

  tearDown(() {
    Get.reset();
  });

  test('does not add an already expired flash sale to the bag', () async {
    await cartService
        .add(_deal(DateTime.now().subtract(const Duration(seconds: 1))));

    expect(cartService.items, isEmpty);
  });

  testWidgets('formats countdowns below and above one hour and ticks', (
    tester,
  ) async {
    final deal = _deal(now.add(const Duration(hours: 1, seconds: 2)));
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: FlashSaleCountdownText(deal: deal)),
      ),
    );

    expect(find.text('01:00:02'), findsOneWidget);

    now = now.add(const Duration(seconds: 3));
    countdownService.refreshNow();
    await tester.pump();

    expect(find.text('59:59'), findsOneWidget);
  });

  testWidgets('marks the countdown expired and removes its cart line', (
    tester,
  ) async {
    final deal = _deal(now.add(const Duration(seconds: 2)));
    await cartService.add(deal);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: FlashSaleCountdownText(deal: deal)),
      ),
    );

    now = now.add(const Duration(seconds: 3));
    countdownService.refreshNow();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Expired'), findsOneWidget);
    expect(cartService.items, isEmpty);
    expect(removalNotices, [
      ['Flash deal'],
    ]);
  });
}

class _OrderRepo extends OrderRepo {
  _OrderRepo() : super(api: FakeApiService());

  @override
  Future<ReservationModel> reserve(int dealId, {int quantity = 1}) async =>
      ReservationModel(
        id: 'res_$dealId',
        dealId: dealId,
        quantity: quantity,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );

  @override
  Future<void> releaseReservation(String reservationId) async {}
}

DealModel _deal(DateTime flashSaleEndsAt) => DealModel(
      id: 42,
      name: 'Flash deal',
      description: '',
      imageUrl: '',
      originalPrice: 10,
      price: 5,
      currencyCode: 'THB',
      quantityLeft: 2,
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
      flashSaleEndsAt: flashSaleEndsAt,
    );
