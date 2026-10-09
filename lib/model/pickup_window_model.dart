import 'package:intl/intl.dart';

/// A store's pickup window. The API sends instants as ISO-8601 UTC strings.
class PickupWindowModel {
  static const _marketUtcOffset = Duration(hours: 7);

  final DateTime start;
  final DateTime end;

  const PickupWindowModel({required this.start, required this.end});

  factory PickupWindowModel.fromJson(Map<String, dynamic> json) {
    return PickupWindowModel(
      start: DateTime.parse(json['start'] as String? ?? ''),
      end: DateTime.parse(json['end'] as String? ?? ''),
    );
  }

  DateTime _toMarketTime(DateTime value) => value.toUtc().add(_marketUtcOffset);

  /// Human readable label, e.g. "17:30 – 21:00".
  String get label {
    final marketStart = _toMarketTime(start);
    final marketEnd = _toMarketTime(end);
    return '${DateFormat('HH:mm').format(marketStart)} – '
        '${DateFormat('HH:mm').format(marketEnd)}';
  }

  /// Whether pickup starts today in Bangkok market time.
  bool get isToday {
    final nowMarket = _toMarketTime(DateTime.now());
    final startMarket = _toMarketTime(start);
    return startMarket.year == nowMarket.year &&
        startMarket.month == nowMarket.month &&
        startMarket.day == nowMarket.day;
  }

  /// Whether the store is currently accepting pickups.
  bool get isOpenNow {
    final nowMarket = _toMarketTime(DateTime.now());
    final startMarket = _toMarketTime(start);
    final endMarket = _toMarketTime(end);
    return !nowMarket.isBefore(startMarket) && nowMarket.isBefore(endMarket);
  }

  Duration get untilStart {
    final nowMarket = _toMarketTime(DateTime.now());
    final startMarket = _toMarketTime(start);
    return startMarket.difference(nowMarket);
  }
}
