import 'dart:async';

import 'package:get/get.dart';

import '../model/deal_model.dart';
import '../util/log_service.dart';
import 'fake_api_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// Session analytics events are visible on the debug screen and batched to the API.
class AnalyticsService extends GetxService {
  final FakeApiService api;

  AnalyticsService({required this.api});

  final events = <AnalyticsEvent>[].obs;
  final Set<int> _impressedDealIds = {};
  final List<_QueuedAnalyticsEvent> _pendingBatch = [];
  final Map<String, Timer> _visibilityTimers = {};
  final Map<String, _PendingImpression> _pendingImpressions = {};
  Timer? _batchTimer;
  DateTime? _retryAfter;
  bool _isSendingBatch = false;

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }

  void onDealVisibilityChanged({
    required DealModel deal,
    required String source,
    required int position,
    required double visibleFraction,
  }) {
    if (_impressedDealIds.contains(deal.id)) return;

    final key = '$source:${deal.id}';
    if (visibleFraction < 0.5) {
      _visibilityTimers.remove(key)?.cancel();
      _pendingImpressions.remove(key);
      return;
    }

    _pendingImpressions[key] = _PendingImpression(
      dealId: deal.id,
      source: source,
      position: position,
    );
    if (_visibilityTimers.containsKey(key)) return;

    _visibilityTimers[key] = Timer(const Duration(seconds: 1), () {
      _visibilityTimers.remove(key);
      final impression = _pendingImpressions.remove(key);
      if (impression == null || !_impressedDealIds.add(impression.dealId)) {
        return;
      }
      logEvent('deal_impression', {
        'deal_id': impression.dealId,
        'source': impression.source,
        'position': impression.position,
      });
      _enqueueBatchEvent(events.last);
    });
  }

  void _enqueueBatchEvent(AnalyticsEvent event) {
    _pendingBatch.add(_QueuedAnalyticsEvent(event, DateTime.now()));
    if (_pendingBatch.length >= 10) {
      unawaited(_sendBatch());
    } else {
      _scheduleBatchTimer();
    }
  }

  void _scheduleBatchTimer() {
    if (_pendingBatch.isEmpty || _batchTimer != null) return;
    var dueAt = _pendingBatch.first.queuedAt.add(const Duration(seconds: 15));
    final retryAfter = _retryAfter;
    if (retryAfter != null && retryAfter.isAfter(dueAt)) dueAt = retryAfter;
    var delay = dueAt.difference(DateTime.now());
    if (delay.isNegative) delay = Duration.zero;
    _batchTimer = Timer(delay, () {
      _batchTimer = null;
      unawaited(_sendBatch());
    });
  }

  Future<void> _sendBatch() async {
    if (_isSendingBatch || _pendingBatch.isEmpty) return;
    final retryAfter = _retryAfter;
    if (retryAfter != null && retryAfter.isAfter(DateTime.now())) {
      _scheduleBatchTimer();
      return;
    }
    _batchTimer?.cancel();
    _batchTimer = null;
    final count = _pendingBatch.length < 10 ? _pendingBatch.length : 10;
    final batch = _pendingBatch.take(count).toList(growable: false);
    _pendingBatch.removeRange(0, count);
    _isSendingBatch = true;
    var sent = false;
    try {
      await api.sendAnalyticsBatch(
        batch.map((queuedEvent) => queuedEvent.event.toJson()).toList(),
      );
      sent = true;
      _retryAfter = null;
    } catch (error) {
      LogService.error('send analytics batch failed', error);
      _pendingBatch.insertAll(0, batch);
      _retryAfter = DateTime.now().add(const Duration(seconds: 15));
    } finally {
      _isSendingBatch = false;
      if (sent && _pendingBatch.length >= 10) {
        unawaited(_sendBatch());
      } else {
        _scheduleBatchTimer();
      }
    }
  }

  @override
  void onClose() {
    _batchTimer?.cancel();
    for (final timer in _visibilityTimers.values) {
      timer.cancel();
    }
    _visibilityTimers.clear();
    _pendingImpressions.clear();
    super.onClose();
  }
}

class _QueuedAnalyticsEvent {
  final AnalyticsEvent event;
  final DateTime queuedAt;

  const _QueuedAnalyticsEvent(this.event, this.queuedAt);
}

class _PendingImpression {
  final int dealId;
  final String source;
  final int position;

  const _PendingImpression({
    required this.dealId,
    required this.source,
    required this.position,
  });
}
