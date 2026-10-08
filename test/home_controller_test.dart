import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/home/home_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/paged_response_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/fake_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refresh invalidates an in-flight page request', () async {
    final repo = _PagedDealRepo();
    final controller = HomeController(dealRepo: repo);
    addTearDown(controller.onClose);

    final initialRefresh = controller.refreshDeals();
    repo.requests[0].complete(_page(1, [_deal(1), _deal(2)]));
    await initialRefresh;

    final previousLoadMore = controller.loadMore();
    final nextRefresh = controller.refreshDeals();
    repo.requests[2].complete(_page(1, [_deal(1), _deal(2)]));
    await nextRefresh;
    repo.requests[1].complete(_page(2, [_deal(3)]));
    await previousLoadMore;

    expect(controller.deals.map((deal) => deal.id), [1, 2]);

    final currentLoadMore = controller.loadMore();
    expect(repo.requestPages.last, 2);
    repo.requests[3].complete(_page(2, [_deal(3)]));
    await currentLoadMore;

    expect(controller.deals.map((deal) => deal.id), [1, 2, 3]);
    expect(controller.deals.map((deal) => deal.id).toSet().length, 3);
  });
}

class _PagedDealRepo extends DealRepo {
  _PagedDealRepo() : super(api: FakeApiService());

  final requests = <Completer<PagedResponseModel<DealModel>>>[];
  final requestPages = <int>[];

  @override
  Future<PagedResponseModel<DealModel>> fetchDeals({int page = 1}) {
    requestPages.add(page);
    final request = Completer<PagedResponseModel<DealModel>>();
    requests.add(request);
    return request.future;
  }
}

PagedResponseModel<DealModel> _page(int page, List<DealModel> items) =>
    PagedResponseModel(items: items, page: page, totalPages: 2);

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
