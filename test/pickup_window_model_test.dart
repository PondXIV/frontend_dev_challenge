import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/pickup_window_model.dart';

void main() {
  test('label formats UTC instants as Bangkok pickup times', () {
    final window = PickupWindowModel(
      start: DateTime.parse('2026-10-07T23:00:00.000Z'),
      end: DateTime.parse('2026-10-08T02:30:00.000Z'),
    );

    expect(window.label, '06:00 – 09:30');
  });

  test('isToday compares pickup and current dates in Bangkok time', () {
    final nowMarket = DateTime.now().toUtc().add(const Duration(hours: 7));
    final todayAtSixMarket =
        DateTime.utc(nowMarket.year, nowMarket.month, nowMarket.day, 6);
    final window = PickupWindowModel(
      start: todayAtSixMarket.subtract(const Duration(hours: 7)),
      end: todayAtSixMarket.add(const Duration(hours: 3, minutes: 30)).subtract(
            const Duration(hours: 7),
          ),
    );

    expect(window.isToday, isTrue);
  });

  test('isToday compares the full market date, not only day of month', () {
    final nowMarket = DateTime.now().toUtc().add(const Duration(hours: 7));
    final yesterdayAtSixMarket =
        DateTime.utc(nowMarket.year, nowMarket.month, nowMarket.day - 1, 6);
    final window = PickupWindowModel(
      start: yesterdayAtSixMarket.subtract(const Duration(hours: 7)),
      end: yesterdayAtSixMarket
          .add(const Duration(hours: 3, minutes: 30))
          .subtract(
            const Duration(hours: 7),
          ),
    );

    expect(window.isToday, isFalse);
  });
}
