import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/localsend/models.dart';
import 'package:notch_stash/src/localsend/service.dart';
import 'package:notch_stash/src/ui/send_view.dart';
import 'package:notch_stash/src/ui/theme.dart';

void main() {
  final peer = Peer(
    fingerprint: 'f',
    alias: 'Pixel 9',
    deviceModel: 'Google',
    deviceType: 'mobile',
    ip: '192.168.1.7',
    port: 53317,
    scheme: 'https',
    lastSeen: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, TransferState? state, {VoidCallback? onSend}) => tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Material(
            child: PeerRow(peer: peer, state: state, onSend: onSend ?? () {}, onCancel: () {}),
          ),
        ),
      );

  testWidgets('shows the device and a Send button', (tester) async {
    var sent = 0;
    await pump(tester, null, onSend: () => sent++);
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.text('Google · 192.168.1.7'), findsOneWidget);
    expect(find.byIcon(Icons.smartphone), findsOneWidget);
    await tester.tap(find.text('Send'));
    expect(sent, 1);
  });

  testWidgets('shows each transfer state', (tester) async {
    await pump(tester, const TransferWaiting());
    expect(find.text('Waiting for approval…'), findsOneWidget);
    await pump(tester, const TransferSending(0.5));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await pump(tester, const TransferDone());
    expect(find.text('Sent'), findsOneWidget);
    for (final (state, label) in [
      (const TransferDeclined(), 'Declined'),
      (const TransferBusy(), 'Busy'),
      (const TransferFailed('Error 500'), 'Failed'),
    ]) {
      await pump(tester, state);
      expect(find.text(label), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    }
  });
}
