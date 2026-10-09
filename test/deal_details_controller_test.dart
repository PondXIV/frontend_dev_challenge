import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/deal/deal_details_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/fake_api_service.dart';

void main() {
  test('loads a deal from its route ID when no deal argument is provided',
      () async {
    final repo = _DealRepo();
    final analytics = AnalyticsService();
    final controller = DealDetailsController(
      dealRepo: repo,
      cartService: CartService(),
      analytics: analytics,
      dealId: 42,
      source: 'push',
    );
    addTearDown(controller.onClose);

    controller.onInit();
    expect(controller.isLoading.value, isTrue);
    expect(repo.requestedIds, [42]);

    repo.response.complete(_deal(42));
    await Future<void>.delayed(Duration.zero);

    expect(controller.deal.value?.id, 42);
    expect(controller.quantityLeft, 3);
    expect(controller.isLoading.value, isFalse);
    expect(analytics.events.single.properties, {
      'deal_id': 42,
      'source': 'push',
    });
  });
}

class _DealRepo extends DealRepo {
  _DealRepo() : super(api: FakeApiService());

  final response = Completer<DealModel>();
  final requestedIds = <int>[];

  @override
  Future<DealModel> fetchById(int id) {
    requestedIds.add(id);
    return response.future;
  }
}

DealModel _deal(int id) => DealModel(
      id: id,
      name: 'Deal $id',
      description: 'Test deal',
      imageUrl: '',
      originalPrice: 10,
      price: 5,
      currencyCode: 'THB',
      quantityLeft: 3,
      storeId: 1,
      storeName: 'Store',
      storeAddress: 'Address',
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
