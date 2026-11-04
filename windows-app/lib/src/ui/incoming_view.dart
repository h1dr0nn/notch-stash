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
        final progress = app.localSend.receiving;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(
                title: 'Incoming Files',
                onDragStart: app.window.startDragging,
                onClose: request != null ? app.declineIncoming : app.hide,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: request != null
                    ? _body(request)
                    : progress != null
                    ? _progress(progress)
                    : const SizedBox.shrink(),
              ),
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
                  child: Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (files.length > 5)
                Text(
                  'and ${files.length - 5} more',
                  style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText),
                ),
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

  Widget _progress(ReceiveProgress progress) {
    final (icon, color) = switch (progress.phase) {
      ReceivePhase.receiving => (Icons.downloading_rounded, ShelfColors.accent),
      ReceivePhase.done => (Icons.check_circle_rounded, ShelfColors.success),
      ReceivePhase.failed => (Icons.error_rounded, ShelfColors.danger),
    };
    final files = progress.files;
    final status = switch (progress.phase) {
      ReceivePhase.receiving => '${progress.finishedIds.length} of ${fileCount(files.length)}',
      ReceivePhase.done => files.length == 1 ? 'Received' : 'Received ${fileCount(files.length)}',
      ReceivePhase.failed => progress.message,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 38, color: color),
        const SizedBox(height: 10),
        Text(
          'Receiving from ${progress.sender.alias}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatBytes(progress.receivedBytes)} of ${formatBytes(progress.totalBytes)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final file in files)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(
                        progress.finishedIds.contains(file.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 14,
                        color: progress.finishedIds.contains(file.id) ? ShelfColors.success : ShelfColors.secondaryText,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.fraction, color: color, minHeight: 6),
        const SizedBox(height: 6),
        Text(
          status,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: ShelfColors.secondaryText),
        ),
      ],
    );
  }
}
