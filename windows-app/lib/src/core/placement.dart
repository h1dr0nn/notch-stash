import 'dart:ui';

/// Top-left corner for a window of [size] shown next to [cursor], kept inside [workArea].
///
/// The window sits below and slightly left of the pointer, flips above it when there
/// is no room below, and is clamped to the work area (the screen minus the taskbar).
Offset shelfOrigin({
  required Offset cursor,
  required Rect workArea,
  required Size size,
  double gap = 16,
}) {
  var x = cursor.dx - size.width / 2;
  var y = cursor.dy + gap;
  if (y + size.height > workArea.bottom) {
    y = cursor.dy - gap - size.height;
  }
  x = _clamp(x, workArea.left, workArea.right - size.width);
  y = _clamp(y, workArea.top, workArea.bottom - size.height);
  return Offset(x.roundToDouble(), y.roundToDouble());
}

/// Top-left corner that centres [size] in [workArea], clamped when it does not fit.
Offset centeredOrigin({required Rect workArea, required Size size}) {
  final x = workArea.left + (workArea.width - size.width) / 2;
  final y = workArea.top + (workArea.height - size.height) / 2;
  return Offset(
    _clamp(x, workArea.left, workArea.right - size.width).roundToDouble(),
    _clamp(y, workArea.top, workArea.bottom - size.height).roundToDouble(),
  );
}

/// The work area containing [point], or the nearest one when it lies outside all of them.
Rect? workAreaFor(Offset point, List<Rect> workAreas) {
  if (workAreas.isEmpty) return null;
  for (final area in workAreas) {
    if (area.contains(point)) return area;
  }
  Rect best = workAreas.first;
  var bestDistance = double.infinity;
  for (final area in workAreas) {
    final dx = point.dx < area.left ? area.left - point.dx : (point.dx > area.right ? point.dx - area.right : 0);
    final dy = point.dy < area.top ? area.top - point.dy : (point.dy > area.bottom ? point.dy - area.bottom : 0);
    final distance = dx * dx + dy * dy;
    if (distance < bestDistance) {
      bestDistance = distance.toDouble();
      best = area;
    }
  }
  return best;
}

double _clamp(double value, double min, double max) {
  if (max < min) return min;
  return value < min ? min : (value > max ? max : value);
}
