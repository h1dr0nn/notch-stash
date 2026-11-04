import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatting.dart';
import '../localsend/receive_controller.dart';
import 'common.dart';
import 'theme.dart';

/// Asks whether to accept files another device offers.
class IncomingView extends StatelessWidget {
  const IncomingView({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.localSend,
      builder: (context, _) {
        final request = app.localSend.incoming;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(title: 'Incoming Files', onDragStart: app.window.startDragging, onClose: app.declineIncoming),
              const SizedBox(height: 8),
              Expanded(child: request == null ? const SizedBox.shrink() : _body(request)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(IncomingRequest request) {
    final files = request.files;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.downloading_rounded, size: 38, color: ShelfColors.accent),
        const SizedBox(height: 10),
        Text(
          '${request.sender.alias} wants to send you ${fileCount(files.length)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatBytes(request.totalSize)} · saved to ${app.settings.saveFolder}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final file in files.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
              if (files.length > 5)
                Text('and ${files.length - 5} more',
                    style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText)),
            ],
          ),
        ),
        Row(
          children: [
            OutlinedButton(onPressed: app.declineIncoming, child: const Text('Decline')),
            const Spacer(),
            FilledButton(onPressed: app.acceptIncoming, autofocus: true, child: const Text('Accept')),
          ],
        ),
      ],
    );
  }
}
