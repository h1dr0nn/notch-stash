import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_controller.dart';
import '../localsend/models.dart';
import '../localsend/service.dart';
import 'common.dart';
import 'theme.dart';

/// Lists nearby LocalSend devices and sends the chosen files to one of them.
class SendView extends StatelessWidget {
  const SendView({super.key, required this.app});

  final AppController app;

  String get _summary {
    final paths = app.sendPaths;
    return paths.length == 1 ? 'Send ${p.basename(paths.first)}' : 'Send ${paths.length} files';
  }

  @override
  Widget build(BuildContext context) {
    final service = app.localSend;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(title: _summary, onDragStart: app.window.startDragging, onClose: app.closeCurrent),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Nearby Devices',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShelfColors.secondaryText),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: service.isRunning ? () => unawaited(service.scan()) : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 26),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _content(service)),
            if (service.isRunning) ...[const SizedBox(height: 10), _AddByAddress(service: service)],
          ],
        ),
      ),
    );
  }

  Widget _content(LocalSendService service) {
    if (!service.isRunning) {
      return const HintMessage(
        title: 'Nearby sharing is off',
        detail: 'Turn on Nearby Sharing in Settings to find devices.',
      );
    }
    final peers = service.peers;
    if (peers.isEmpty) {
      return const HintMessage(
        leading: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        title: 'Looking for devices…',
        detail:
            'Open Notch Stash on the other computer, or LocalSend on a phone. '
            'If nothing shows up, add it by IP address below, and allow Notch Stash through Windows Firewall.',
      );
    }
    return ListView.separated(
      itemCount: peers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final peer = peers[index];
        return PeerRow(
          peer: peer,
          state: service.transferFor(peer),
          onSend: () => service.send(app.sendPaths, peer),
          onCancel: () => service.cancelSend(peer),
        );
      },
    );
  }
}

/// One device with its Send button or transfer status.
class PeerRow extends StatelessWidget {
  const PeerRow({super.key, required this.peer, required this.state, required this.onSend, required this.onCancel});

  final Peer peer;
  final TransferState? state;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  static IconData iconFor(String? deviceType) => switch (deviceType) {
    'mobile' => Icons.smartphone,
    'desktop' => Icons.laptop,
    'web' => Icons.language,
    'server' || 'headless' => Icons.dns_outlined,
    _ => Icons.desktop_windows_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: ShelfColors.tile, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          SizedBox(width: 28, child: Icon(iconFor(peer.deviceType), size: 20, color: ShelfColors.accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  peer.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _status(),
        ],
      ),
    );
  }

  Widget _status() {
    final current = state;
    return switch (current) {
      null => FilledButton(
        onPressed: onSend,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: const Text('Send'),
      ),
      TransferWaiting() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Waiting for approval…', style: TextStyle(fontSize: 11, color: ShelfColors.secondaryText)),
          const SizedBox(width: 6),
          CloseCircleButton(onPressed: onCancel, tooltip: 'Cancel'),
        ],
      ),
      TransferSending(:final fraction) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          CloseCircleButton(onPressed: onCancel, tooltip: 'Cancel'),
        ],
      ),
      TransferDone() => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: ShelfColors.success),
          SizedBox(width: 4),
          Text('Sent', style: TextStyle(fontSize: 11, color: ShelfColors.success)),
        ],
      ),
      TransferDeclined() => _retry('Declined'),
      TransferBusy() => _retry('Busy'),
      TransferFailed(:final message) => Tooltip(message: message, child: _retry('Failed')),
    };
  }

  Widget _retry(String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText)),
      const SizedBox(width: 6),
      OutlinedButton(
        onPressed: onSend,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 26),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: const Text('Retry'),
      ),
    ],
  );
}

/// Adds a device on another subnet, which discovery cannot reach, by its IP address.
class _AddByAddress extends StatefulWidget {
  const _AddByAddress({required this.service});

  final LocalSendService service;

  @override
  State<_AddByAddress> createState() => _AddByAddressState();
}

class _AddByAddressState extends State<_AddByAddress> {
  final TextEditingController _address = TextEditingController();
  String? _status;
  bool _adding = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final target = _address.text.trim();
    if (target.isEmpty || _adding) return;
    setState(() {
      _adding = true;
      _status = 'Looking for a device at $target…';
    });
    final name = await widget.service.addDevice(target);
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (name != null) {
        _status = 'Added $name.';
        _address.clear();
      } else {
        _status = 'No Notch Stash or LocalSend answered at $target.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _address,
                onSubmitted: (_) => unawaited(_add()),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'IP Address',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _adding ? null : () => unawaited(_add()), child: const Text('Add')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _status ?? 'Not listed? Enter the other device\'s IP address. It is remembered for next time.',
          style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText),
        ),
      ],
    );
  }
}
