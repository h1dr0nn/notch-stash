/// Dotted numeric version such as 0.6.1, comparable component by component.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.components);

  final List<int> components;

  /// Accepts "0.6.1", "v0.6.1", release tags such as "release-v0.6.1" and
  /// build versions such as "0.6.1+3" (the build number is ignored).
  static AppVersion? tryParse(String text) {
    var trimmed = text.trim();
    final tagMarker = trimmed.indexOf('-v');
    if (tagMarker >= 0) {
      trimmed = trimmed.substring(tagMarker + 2);
    } else if (trimmed.startsWith('v')) {
      trimmed = trimmed.substring(1);
    }
    final plus = trimmed.indexOf('+');
    if (plus >= 0) trimmed = trimmed.substring(0, plus);
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('.').map(int.tryParse).toList();
    if (parts.any((part) => part == null || part < 0)) return null;
    return AppVersion(parts.cast<int>());
  }

  @override
  int compareTo(AppVersion other) {
    final count = components.length > other.components.length
        ? components.length
        : other.components.length;
    for (var index = 0; index < count; index++) {
      final left = index < components.length ? components[index] : 0;
      final right = index < other.components.length ? other.components[index] : 0;
      if (left != right) return left < right ? -1 : 1;
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode {
    var end = components.length;
    while (end > 0 && components[end - 1] == 0) {
      end--;
    }
    return Object.hashAll(components.sublist(0, end));
  }

  @override
  String toString() => components.join('.');
}
