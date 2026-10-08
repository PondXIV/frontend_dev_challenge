import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/order/widget/pickup_countdown.dart';

void main() {
  testWidgets('cancels its timer when disposed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PickupCountdown(
          pickupStart: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });
}
