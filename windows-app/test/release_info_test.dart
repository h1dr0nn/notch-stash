import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/release_info.dart';

Map<String, dynamic> _release({String tag = 'release-v0.6.1', List<Map<String, dynamic>>? assets}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/h1dr0nn/notch-stash/releases/tag/$tag',
  'assets':
      assets ??
      [
        {
          'name': 'NotchStash-0.6.1.dmg',
          'browser_download_url': 'https://example.com/NotchStash-0.6.1.dmg',
          'digest': 'sha256:aaaa',
        },
        {
          'name': 'NotchStash-Setup-0.6.1.exe',
          'browser_download_url': 'https://example.com/NotchStash-Setup-0.6.1.exe',
          'digest': 'sha256:ABCDEF',
        },
      ],
};

void main() {
  test('picks the Windows installer of the release version', () {
    final info = ReleaseInfo.fromGitHubJson(_release())!;
    expect(info.version.toString(), '0.6.1');
    expect(info.installerUrl.toString(), 'https://example.com/NotchStash-Setup-0.6.1.exe');
    expect(info.sha256, 'abcdef');
    expect(info.pageUrl.path, endsWith('release-v0.6.1'));
  });

  test('returns null without an installer for that version', () {
    final assets = [
      {'name': 'NotchStash-Setup-0.6.0.exe', 'browser_download_url': 'https://example.com/old.exe'},
    ];
    expect(ReleaseInfo.fromGitHubJson(_release(assets: assets)), isNull);
  });

  test('works without a digest', () {
    final assets = [
      {'name': 'NotchStash-Setup-0.6.1.exe', 'browser_download_url': 'https://example.com/a.exe'},
    ];
    expect(ReleaseInfo.fromGitHubJson(_release(assets: assets))!.sha256, isNull);
  });

  test('rejects unparsable tags and malformed JSON', () {
    expect(ReleaseInfo.fromGitHubJson(_release(tag: 'nightly')), isNull);
    expect(ReleaseInfo.fromGitHubJson({'tag_name': 'release-v1.0.0'}), isNull);
  });

  test('builds the installer address from the latest tag page', () {
    final info = ReleaseInfo.fromTagPage(
      Uri.parse('https://github.com/h1dr0nn/notch-stash/releases/tag/release-v0.6.2'),
    )!;
    expect(info.version.toString(), '0.6.2');
    expect(
      info.installerUrl.toString(),
      'https://github.com/h1dr0nn/notch-stash/releases/download/release-v0.6.2/NotchStash-Setup-0.6.2.exe',
    );
    expect(info.sha256, isNull);
  });

  test('ignores pages that are not a release tag', () {
    expect(ReleaseInfo.fromTagPage(Uri.parse('https://github.com/h1dr0nn/notch-stash/releases')), isNull);
    expect(ReleaseInfo.fromTagPage(Uri.parse('https://github.com/h1dr0nn/notch-stash/releases/tag/nightly')), isNull);
  });
}
