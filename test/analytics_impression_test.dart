import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/fake_api_service.dart';

void main() {
  late _AnalyticsApi api;
  late AnalyticsService analytics;

  setUp(() {
    api = _AnalyticsApi();
    analytics = AnalyticsService(api: api);
  });

  tearDown(() {
    analytics.onClose();
  });

  testWidgets('requires one continuous visible second and logs only once',
      (tester) async {
    final deal = _deal(1);
    analytics.onDealVisibilityChanged(
      deal: deal,
      source: 'home_feed',
      position: 4,
      visibleFraction: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 600));
    analytics.onDealVisibilityChanged(
      deal: deal,
      source: 'home_feed',
      position: 4,
      visibleFraction: 0.49,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(analytics.events, isEmpty);

    analytics.onDealVisibilityChanged(
      deal: deal,
      source: 'home_feed',
      position: 4,
      visibleFraction: 0.75,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(analytics.events.single.name, 'deal_impression');
    expect(analytics.events.single.properties, {
      'deal_id': 1,
      'source': 'home_feed',
      'position': 4,
    });

    analytics.onDealVisibilityChanged(
      deal: deal,
      source: 'search',
      position: 0,
      visibleFraction: 1,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(analytics.events, hasLength(1));
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('sends impressions as a batch of ten', (tester) async {
    for (var id = 1; id <= 10; id++) {
      analytics.onDealVisibilityChanged(
        deal: _deal(id),
        source: 'flash_rail',
        position: id - 1,
        visibleFraction: 1,
      );
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(api.batches, hasLength(1));
    expect(api.batches.single, hasLength(10));
    expect(api.batches.single.first['name'], 'deal_impression');
  });

  testWidgets('flushes an unsent impression after fifteen seconds',
      (tester) async {
    analytics.onDealVisibilityChanged(
      deal: _deal(1),
      source: 'search',
      position: 0,
      visibleFraction: 1,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(api.batches, isEmpty);

    await tester.pump(const Duration(seconds: 15));

    expect(api.batches, hasLength(1));
    expect(api.batches.single, hasLength(1));
  });
}

class _AnalyticsApi extends FakeApiService {
  final batches = <List<Map<String, dynamic>>>[];

  @override
  Future<void> sendAnalyticsBatch(List<Map<String, dynamic>> events) async {
    batches.add(events);
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
