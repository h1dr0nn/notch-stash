import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../app_controller.dart';
import '../core/shelf_store.dart';
import '../platform/shell.dart';
import 'common.dart';
import 'file_icon.dart';
import 'theme.dart';

/// Marks drags that start on the shelf, so dropping them back on it does nothing.
const _localDragTag = 'notch-stash-shelf-item';

/// The shelf: header with actions, file tiles or the empty drop zone.
class ShelfView extends StatefulWidget {
  const ShelfView({super.key, required this.app});

  final AppController app;

  @override
  State<ShelfView> createState() => _ShelfViewState();
}

class _ShelfViewState extends State<ShelfView> {
  final Map<int, GlobalKey<DragItemWidgetState>> _dragKeys = {};
  bool _dropHover = false;

  AppController get app => widget.app;

  GlobalKey<DragItemWidgetState> _keyFor(ShelfItem item) =>
      _dragKeys.putIfAbsent(item.id, () => GlobalKey<DragItemWidgetState>());

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.store,
      builder: (context, _) {
        final items = app.store.items;
        final ids = items.map((item) => item.id).toSet();
        _dragKeys.removeWhere((id, _) => !ids.contains(id));
        return DropRegion(
          formats: const [Formats.fileUri],
          hitTestBehavior: HitTestBehavior.opaque,
          onDropOver: _onDropOver,
          onDropEnter: (_) => setState(() => _dropHover = true),
          onDropLeave: (_) => setState(() => _dropHover = false),
          onDropEnded: (_) => setState(() => _dropHover = false),
          onPerformDrop: _onPerformDrop,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelHeader(
                  title: 'Notch Shelf',
                  onDragStart: app.window.startDragging,
                  onClose: app.hide,
                  actions: items.isEmpty ? const [] : _actions(items),
                ),
                const SizedBox(height: 10),
                Expanded(child: items.isEmpty ? _placeholder() : _tiles(items)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _actions(List<ShelfItem> items) => [
        Tooltip(
          message: 'Send all files to a nearby device',
          child: TextButton(
            onPressed: () => app.openSend(items.map((item) => item.path).toList()),
            child: const Text('Send All…'),
          ),
        ),
        const SizedBox(width: 2),
        _DragAllButton(
          itemsProvider: () => [
            for (final item in app.store.items) ?_keyFor(item).currentState,
          ],
        ),
        const SizedBox(width: 2),
        TextButton(onPressed: app.store.removeAll, child: const Text('Clear All')),
      ];

  Widget _placeholder() {
    final color = _dropHover ? ShelfColors.accent : ShelfColors.secondaryText;
    return CustomPaint(
      painter: DashedBorderPainter(color: color),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.move_to_inbox_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            Text('Drop files here', style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _tiles(List<ShelfItem> items) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dropHover ? ShelfColors.accent : Colors.transparent, width: 1.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FileTile(
                  key: ValueKey(item.id),
                  dragKey: _keyFor(item),
                  item: item,
                  onRemove: () => app.store.remove([item.id]),
                  onMenu: () => app.showItemMenu(item),
                  onDragEnded: (delivered) => app.dragEnded([item.id], delivered: delivered),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DropOperation _onDropOver(DropOverEvent event) {
    final items = event.session.items;
    if (items.isEmpty || items.every((item) => item.localData == _localDragTag)) {
      return DropOperation.none;
    }
    if (!items.any((item) => item.canProvide(Formats.fileUri))) return DropOperation.none;
    final allowed = event.session.allowedOperations;
    if (allowed.contains(DropOperation.copy)) return DropOperation.copy;
    if (allowed.contains(DropOperation.link)) return DropOperation.link;
    return allowed.contains(DropOperation.move) ? DropOperation.move : DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    final reads = <Future<String?>>[];
    for (final item in event.session.items) {
      if (item.localData == _localDragTag) continue;
      final reader = item.dataReader;
      if (reader == null || !reader.canProvide(Formats.fileUri)) continue;
      final completer = Completer<String?>();
      final progress = reader.getValue<Uri>(
        Formats.fileUri,
        (uri) => completer.complete(uri?.toFilePath(windows: Platform.isWindows)),
        onError: (_) => completer.complete(null),
      );
      if (progress == null) continue;
      reads.add(completer.future);
    }
    final paths = await Future.wait(reads);
    app.addFiles(paths.whereType<String>());
  }
}

/// The accent "Drag All" pill: dragging it drags every file on the shelf.
class _DragAllButton extends StatelessWidget {
  const _DragAllButton({required this.itemsProvider});

  final List<DragItemWidgetState> Function() itemsProvider;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Drag every file at once',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: DraggableWidget(
          dragItemsProvider: (_) => itemsProvider(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ShelfColors.accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Drag All',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One file on the shelf: drag it out, right-click for actions, × to remove.
class FileTile extends StatefulWidget {
  const FileTile({
    super.key,
    required this.dragKey,
    required this.item,
    required this.onRemove,
    required this.onMenu,
    required this.onDragEnded,
  });

  final GlobalKey<DragItemWidgetState> dragKey;
  final ShelfItem item;
  final VoidCallback onRemove;
  final VoidCallback onMenu;
  final void Function(bool delivered) onDragEnded;

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  bool _hover = false;

  DragItem _dragItem(DragItemRequest request) {
    final item = widget.item;
    final session = request.session;
    void listener() {
      final operation = session.dragCompleted.value;
      if (operation == null) return;
      session.dragCompleted.removeListener(listener);
      widget.onDragEnded(operation == DropOperation.copy || operation == DropOperation.move);
    }

    session.dragCompleted.addListener(listener);
    return DragItem(localData: _localDragTag, suggestedName: item.name)
      ..add(Formats.fileUri(Uri.file(item.path, windows: Platform.isWindows)));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Tooltip(
      message: item.path,
      waitDuration: const Duration(seconds: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onSecondaryTapUp: (_) => widget.onMenu(),
          onDoubleTap: () => unawaited(Shell.open(item.path)),
          child: DragItemWidget(
            key: widget.dragKey,
            allowedOperations: () => const [DropOperation.copy, DropOperation.move],
            dragItemProvider: _dragItem,
            child: DraggableWidget(
              child: Container(
                width: 78,
                height: 86,
                decoration: BoxDecoration(
                  color: _hover ? ShelfColors.tileHover : ShelfColors.tile,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(3, 8, 3, 2),
                      child: Column(
                        children: [
                          FileIcon(path: item.path, size: 40),
                          const SizedBox(height: 4),
                          Expanded(
                            child: MiddleEllipsisText(
                              item.name,
                              style: const TextStyle(fontSize: 10.5, height: 1.15, color: ShelfColors.primaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: AnimatedOpacity(
                        opacity: _hover ? 1 : 0.55,
                        duration: const Duration(milliseconds: 120),
                        child: CloseCircleButton(onPressed: widget.onRemove, tooltip: 'Remove', size: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
