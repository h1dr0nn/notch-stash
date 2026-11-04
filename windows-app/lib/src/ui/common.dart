import 'package:flutter/material.dart';

import '../core/formatting.dart';
import 'theme.dart';

/// Header row of every view: a draggable title area and trailing buttons.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    required this.onDragStart,
    required this.onClose,
    this.actions = const [],
  });

  final String title;
  final VoidCallback onDragStart;
  final VoidCallback onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onDragStart(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ShelfColors.primaryText,
                  ),
                ),
              ),
            ),
          ),
          ...actions,
          const SizedBox(width: 4),
          CloseCircleButton(onPressed: onClose, size: 16, tooltip: 'Close'),
        ],
      ),
    );
  }
}

/// Small round × button.
class CloseCircleButton extends StatelessWidget {
  const CloseCircleButton({super.key, required this.onPressed, required this.tooltip, this.size = 14});

  final VoidCallback onPressed;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: Icon(Icons.cancel, size: size, color: ShelfColors.secondaryText),
        ),
      ),
    );
  }
}

/// Centred title and sentence-case hint, used for empty and error states.
class HintMessage extends StatelessWidget {
  const HintMessage({super.key, required this.title, required this.detail, this.leading});

  final String title;
  final String detail;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(height: 10)],
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: ShelfColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text that keeps the start and end of a long name, cutting the middle, within [maxLines].
class MiddleEllipsisText extends StatelessWidget {
  const MiddleEllipsisText(this.text, {super.key, required this.style, this.maxLines = 2, this.textAlign = TextAlign.center});

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final direction = Directionality.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      bool fits(String candidate) {
        final painter = TextPainter(
          text: TextSpan(text: candidate, style: style),
          maxLines: maxLines,
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: constraints.maxWidth);
        final exceeded = painter.didExceedMaxLines;
        painter.dispose();
        return !exceeded;
      }

      final shown = constraints.maxWidth.isFinite ? middleEllipsis(text, fits) : text;
      return Text(shown, maxLines: maxLines, textAlign: textAlign, style: style, overflow: TextOverflow.clip);
    });
  }
}

/// Rounded rectangle with a dashed outline, for the empty drop zone.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, this.radius = 12, this.dash = 6, this.gap = 4});

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.75);
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
