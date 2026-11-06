// The dsh-go-support skill: remote client troubleshooting and issue drafts
// from diagnostics explicitly supplied by the user.

import 'package:dsh_app/ui_config/ui_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundle ships SKILL.md only, managed and parseable', () async {
    final bundle = await loadUiSkillBundle(readAssetFromDisk, supportSkillName);
    expect(bundle.name, 'dsh-go-support');
    expect(bundle.files.keys, ['SKILL.md']);
    expect(bundle.skillMd.startsWith('---'), isTrue);
    expect(bundle.skillMd, contains('# dsh-go:managed'));
    expect(bundle.skillMd, contains('name: dsh-go-support'));
  });

  test('it covers remote client evidence, capability limits and explicit data sharing', () async {
    final bundle = await loadUiSkillBundle(readAssetFromDisk, supportSkillName);
    final skill = bundle.skillMd;
    for (final topic in ['SSH', 'DSH Remote', '无主机', '卡顿', '发热', '更新装不上', '插件', '通知', '桌宠']) {
      expect(skill, contains(topic), reason: topic);
    }
    expect(skill, contains('没有自动把手机诊断写入远程'));
    expect(skill, contains('不要假定主机上存在 `dsh-app/diagnostics.md`'));
    expect(skill, contains('不自动删除、上传或迁移旧 home 和凭据'));
    expect(skill, contains('不能自行上传或代发 issue'));
    expect(skill, contains('## 环境'));
    expect(skill, contains('复现步骤'));
    expect(skill, contains('隐私'));
  });
}
