import 'package:atlas/services/set_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Duration now;
  late SetTimer timer;

  setUp(() {
    now = const Duration(minutes: 5);
    timer = SetTimer(now: () => now);
  });

  test('is idle until started and reports zero', () {
    expect(timer.isRunning, isFalse);
    expect(timer.elapsed, Duration.zero);
    expect(
      timer.stop(),
      isNull,
      reason: 'nothing to record for an unstarted set',
    );
  });

  test('start begins timing and stop returns the elapsed whole seconds', () {
    expect(timer.start(), isTrue);
    now += const Duration(seconds: 32, milliseconds: 100);
    expect(timer.isRunning, isTrue);
    expect(SetTimer.format(timer.elapsed), '00:32');
    expect(timer.stop(), 32);
    expect(timer.isRunning, isFalse);
  });

  test('a second start does not restart or stack the timing', () {
    timer.start();
    now += const Duration(seconds: 10);
    expect(timer.start(), isFalse);
    now += const Duration(seconds: 5);
    expect(timer.stop(), 15);
  });

  test('time spent in the background is counted exactly, not by ticks', () {
    timer.start();
    now += const Duration(minutes: 4, seconds: 7);
    expect(timer.stop(), 247);
  });

  test('cancel drops the timing without producing a duration', () {
    timer.start();
    now += const Duration(seconds: 20);
    timer.cancel();
    expect(timer.isRunning, isFalse);
    expect(timer.stop(), isNull);
  });

  test('each set is timed on its own', () {
    timer.start();
    now += const Duration(seconds: 30);
    expect(timer.stop(), 30);
    now += const Duration(seconds: 90); // rest
    timer.start();
    now += const Duration(seconds: 41);
    expect(timer.stop(), 41);
  });

  test('a clock that steps backwards never gives negative time', () {
    timer.start();
    now -= const Duration(seconds: 3);
    expect(timer.elapsed, Duration.zero);
  });

  test('format handles hours', () {
    expect(SetTimer.format(const Duration(seconds: 5)), '00:05');
    expect(SetTimer.format(const Duration(minutes: 12, seconds: 3)), '12:03');
    expect(
      SetTimer.format(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
