import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/search/search_deals_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/fake_api_service.dart';

void main() {
  late _SearchDealRepo repo;
  late SearchDealsController controller;

  setUp(() {
    repo = _SearchDealRepo();
    controller = SearchDealsController(dealRepo: repo);
  });

  test('late response from an older query cannot replace newer results',
      () async {
    controller.onQueryChanged('old');
    controller.onQueryChanged('new');

    repo.requests['new']!.complete([_deal(2)]);
    await Future<void>.delayed(Duration.zero);
    repo.requests['old']!.complete([_deal(1)]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.results.single.id, 2);
    expect(controller.isLoading.value, isFalse);
  });

  test('clearing the query invalidates an in-flight search', () async {
    controller.onQueryChanged('bakery');
    controller.onQueryChanged('  ');

    repo.requests['bakery']!.complete([_deal(1)]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.results, isEmpty);
    expect(controller.hasSearched.value, isFalse);
    expect(controller.isLoading.value, isFalse);
  });

  test('search failures are shown instead of leaving stale results', () async {
    controller.onQueryChanged('bakery');
    repo.requests['bakery']!.completeError(Exception('network failure'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.results, isEmpty);
    expect(controller.errorMessage.value, 'Search failed. Please try again.');
    expect(controller.isLoading.value, isFalse);
  });
}

class _SearchDealRepo extends DealRepo {
  _SearchDealRepo() : super(api: FakeApiService());

  final requests = <String, Completer<List<DealModel>>>{};

  @override
  Future<List<DealModel>> search(String query) {
    final request = Completer<List<DealModel>>();
    requests[query] = request;
    return request.future;
  }
}

DealModel _deal(int id) => DealModel(
      id: id,
      name: 'Deal $id',
      description: '',
      imageUrl: '',
      originalPrice: 10,
      price: 5,
      currencyCode: 'THB',
      quantityLeft: 1,
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
