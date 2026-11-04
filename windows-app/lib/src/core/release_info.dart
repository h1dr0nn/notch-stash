import 'app_version.dart';

/// The newest published release and the Windows installer attached to it.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.installerUrl, required this.pageUrl, this.sha256});

  final AppVersion version;
  final Uri installerUrl;
  final Uri pageUrl;

  /// Lower-case hex digest GitHub publishes for the asset, when present.
  final String? sha256;

  static String installerName(AppVersion version) => 'NotchStash-Setup-$version.exe';

  /// Builds the release from the tag page that github.com/…/releases/latest redirects to, for when the
  /// API is rate limited. The installer has a predictable download address; no checksum is available.
  static ReleaseInfo? fromTagPage(Uri tagPage) {
    final segments = tagPage.pathSegments;
    final tagIndex = segments.indexOf('tag');
    if (tagIndex < 1 || tagIndex + 1 >= segments.length || segments[tagIndex - 1] != 'releases') return null;
    final tag = segments[tagIndex + 1];
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;
    final repository = segments.sublist(0, tagIndex - 1).join('/');
    return ReleaseInfo(
      version: version,
      installerUrl: Uri.parse('https://github.com/$repository/releases/download/$tag/${installerName(version)}'),
      pageUrl: tagPage,
    );
  }

  /// Reads a GitHub `releases/latest` response; null when it has no usable version or installer.
  static ReleaseInfo? fromGitHubJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    final page = json['html_url'];
    final assets = json['assets'];
    if (tag is! String || page is! String || assets is! List) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;
    final name = installerName(version);
    for (final asset in assets) {
      if (asset is! Map || asset['name'] != name) continue;
      final url = asset['browser_download_url'];
      if (url is! String) return null;
      final digest = asset['digest'];
      return ReleaseInfo(
        version: version,
        installerUrl: Uri.parse(url),
        pageUrl: Uri.parse(page),
        sha256: digest is String && digest.startsWith('sha256:') ? digest.substring(7).toLowerCase() : null,
      );
    }
    return null;
  }
}
