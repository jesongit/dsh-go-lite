// The open-source licences page: every bundled third-party notice is registered once,
// with the copyright line and licence THIRD_PARTY_NOTICES.md gives it.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dsh_app/ui/common/third_party_licenses.dart';
import 'package:dsh_app/ui/settings/font_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Package name → a line its entry must carry, also found in THIRD_PARTY_NOTICES.md.
const _expected = <String, String>{
  'PiPilot': 'Copyright (c) 2026 CikeSeven',
  'DeepSeek Harness': 'Copyright (c) 2026 DeepSeek',
  'DS Bot': 'Copyright 2026 Fei2411 and the DS Bot contributors',
  'ds-harness-remote': 'Copyright (c) 2026 DSH Remote contributors',
  'AndroidX WebKit': 'The Android Open Source Project',
  'flutter_webrtc': 'Copyright (c) 2015 Howard Yang',
  'WebRTC': 'Copyright (c) 2011, The WebRTC project authors',
  'AudioSwitch': 'Copyright 2020 Twilio, inc.',
  'Phosphor Icons': 'Copyright (c) 2023 Phosphor Icons',
  'Material Icons': 'Google',
  'discourse-emojis': 'Joffrey Jaffeux',
  'JetBrains Mono': 'Copyright 2020 The JetBrains Mono Project Authors',
};

const _mit = 'Permission is hereby granted, free of charge';
const _apache = 'Apache License\n                           Version 2.0, January 2004';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<LicenseEntryWithLineBreaks> entries;

  setUpAll(() async {
    LicenseRegistry.reset();
    registerThirdPartyLicenses();
    registerFontLicenses();
    entries = (await LicenseRegistry.licenses.toList()).cast<LicenseEntryWithLineBreaks>();
  });
  tearDownAll(LicenseRegistry.reset);

  String textOf(String package) => entries.singleWhere((e) => e.packages.contains(package)).text;

  test('WebRTC entry exposes the complete upstream asset without truncation', () {
    final file = File('assets/licenses/webrtc-150.7871.04.md');
    final bundle = file.readAsStringSync();
    expect(
      sha256.convert(file.readAsBytesSync()).toString(),
      'd1f9382c6878ac024155fd6d44a5977329108bb8b0a01cea40e4a2f1d7de252e',
    );
    expect(textOf('WebRTC'), endsWith(bundle));
    expect(RegExp(r'^# ', multiLine: true).allMatches(bundle).length, 30);
    expect(bundle, contains('# boringssl'));
    expect(bundle, contains('# zlib'));
  });

  test('each package is registered exactly once', () {
    final names = [for (final entry in entries) ...entry.packages];
    final repeated = {
      for (final name in names)
        if (names.where((n) => n == name).length > 1) name,
    };
    expect(repeated, isEmpty);
  });

  test('every bundled third-party notice is listed', () {
    final names = {for (final entry in entries) ...entry.packages};
    expect(names, _expected.keys.toSet());
  });

  test('copyright lines agree with THIRD_PARTY_NOTICES.md', () {
    final notices = File('../THIRD_PARTY_NOTICES.md').readAsStringSync();
    for (final MapEntry(key: package, value: line) in _expected.entries) {
      expect(textOf(package), contains(line), reason: package);
      expect(notices, contains(line), reason: package);
    }
  });

  test('each entry carries its own licence text', () {
    for (final package in ['PiPilot', 'DeepSeek Harness', 'ds-harness-remote', 'Phosphor Icons', 'discourse-emojis']) {
      expect(textOf(package), contains(_mit), reason: package);
      expect(textOf(package), isNot(contains('Apache License')), reason: package);
    }
    for (final package in ['DS Bot', 'AndroidX WebKit', 'flutter_webrtc', 'AudioSwitch', 'Material Icons']) {
      expect(textOf(package), contains(_apache), reason: package);
    }
    expect(textOf('flutter_webrtc'), contains(_mit));
    expect(textOf('WebRTC'), allOf(contains('Neither the name of Google'), contains('Additional IP Rights Grant')));
    expect(textOf('JetBrains Mono'), contains('SIL OPEN FONT LICENSE Version 1.1'));
  });
}
