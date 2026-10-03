import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_dialog.dart';
import '../../design/selah_sheet.dart';
import '../../design/selah_pressable.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../domain/research_profile.dart';
import '../research_profile_controller.dart';

class ResearchProfileForm extends StatefulWidget {
  const ResearchProfileForm({
    required this.controller,
    required this.uiLocale,
    this.initial = const ResearchProfile(),
    this.showIdentityFields = false,
    this.onDone,
    super.key,
  });

  final ResearchProfileController controller;
  final String uiLocale;
  final ResearchProfile initial;
  final bool showIdentityFields;
  final VoidCallback? onDone;

  @override
  State<ResearchProfileForm> createState() => _ResearchProfileFormState();
}

class _ResearchProfileFormState extends State<ResearchProfileForm> {
  late String? _goal = widget.initial.learningGoal;
  late String? _level = widget.initial.englishLevel;
  late String? _age = widget.initial.ageGroup;
  late String? _lifeStage = widget.initial.lifeStage;
  late String? _gender = widget.initial.gender;
  late String? _genderDescription = widget.initial.genderDescription;

  String copy(String key) => _profileCopy(widget.uiLocale, key);

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final errorCopy =
        _profileErrorCopy(widget.uiLocale, c.errorCode) ?? c.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy('purpose'), style: SelahTypography.bodyMedium()),
        const SizedBox(height: SelahSpacing.xs),
        Text(
          copy('purposeNote'),
          style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: SelahSpacing.md),
        _select(
          label: copy('learningGoal'),
          value: _goal,
          items: _values(widget.uiLocale, 'learningGoal'),
          onChanged: (value) => setState(() => _goal = value),
        ),
        const SizedBox(height: SelahSpacing.sm),
        _select(
          label: copy('englishLevel'),
          value: _level,
          items: _values(widget.uiLocale, 'englishLevel'),
          onChanged: (value) => setState(() => _level = value),
        ),
        if (widget.showIdentityFields) ...[
          const SizedBox(height: SelahSpacing.sm),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            maintainState: true,
            initiallyExpanded:
                widget.initial.ageGroup != null ||
                widget.initial.lifeStage != null ||
                widget.initial.gender != null,
            title: Text(copy('moreBackground')),
            subtitle: Text(
              copy('moreBackgroundSubtitle'),
              style: SelahTypography.bodySmall(
                color: SelahColors.textSecondary,
              ),
            ),
            children: [
              _select(
                label: copy('ageGroup'),
                value: _age,
                items: _values(widget.uiLocale, 'ageGroup'),
                onChanged: (value) => setState(() => _age = value),
              ),
              const SizedBox(height: SelahSpacing.sm),
              _select(
                label: copy('lifeStage'),
                value: _lifeStage,
                items: _values(widget.uiLocale, 'lifeStage'),
                onChanged: (value) => setState(() => _lifeStage = value),
              ),
              const SizedBox(height: SelahSpacing.sm),
              _select(
                label: copy('gender'),
                value: _gender,
                items: _values(widget.uiLocale, 'gender'),
                onChanged: (value) => setState(() => _gender = value),
              ),
              if (_gender == 'self_described') ...[
                const SizedBox(height: SelahSpacing.sm),
                TextField(
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: copy('genderDescription'),
                  ),
                  onChanged: (value) => _genderDescription = value,
                ),
              ],
            ],
          ),
        ],
        Text(
          copy('saveConsentNote'),
          style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: SelahSpacing.xs),
        Row(
          children: [
            TextButton(
              onPressed: c.saving
                  ? null
                  : () async {
                      await c.skip();
                      widget.onDone?.call();
                    },
              child: Text(copy('skip')),
            ),
            const Spacer(),
            SelahPressable(
              child: FilledButton(
                onPressed: c.saving
                    ? null
                    : () async {
                        try {
                          await c.save(
                            ResearchProfile(
                              learningGoal: _goal,
                              englishLevel: _level,
                              ageGroup: _age,
                              lifeStage: _lifeStage,
                              gender: _gender,
                              genderDescription: _genderDescription,
                            ),
                            consent: true,
                          );
                          widget.onDone?.call();
                        } catch (_) {
                          if (mounted) setState(() {});
                        }
                      },
                child: Text(copy('save')),
              ),
            ),
          ],
        ),
        if (errorCopy != null) ...[
          const SizedBox(height: SelahSpacing.xs),
          Text(
            errorCopy,
            style: SelahTypography.bodySmall(color: SelahColors.danger),
          ),
        ],
      ],
    );
  }

  Widget _select({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }
}

class ResearchProfileEntry extends StatelessWidget {
  const ResearchProfileEntry({
    required this.controller,
    required this.uiLocale,
    super.key,
  });

  final ResearchProfileController controller;
  final String uiLocale;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.available) {
          return Text(_profileCopy(uiLocale, 'loginHint'));
        }
        if (controller.loading && !controller.checked) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.loadError) {
          final message =
              _profileErrorCopy(uiLocale, controller.errorCode) ??
              controller.error ??
              _profileCopy(uiLocale, 'errorLoad');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: SelahTypography.bodySmall(color: SelahColors.danger),
              ),
              const SizedBox(height: SelahSpacing.xs),
              TextButton(
                onPressed: controller.loading
                    ? null
                    : () => unawaited(controller.load()),
                child: Text(_profileCopy(uiLocale, 'retry')),
              ),
            ],
          );
        }
        if (controller.promptState == ResearchProfilePromptState.withdrawn ||
            controller.promptState == ResearchProfilePromptState.answered ||
            controller.promptState == ResearchProfilePromptState.skipped) {
          return ResearchProfileSummary(
            controller: controller,
            uiLocale: uiLocale,
          );
        }
        return ResearchProfileForm(
          controller: controller,
          uiLocale: uiLocale,
          showIdentityFields: true,
        );
      },
    );
  }
}

class ResearchProfileInvite extends StatelessWidget {
  const ResearchProfileInvite({
    required this.controller,
    required this.uiLocale,
    required this.onOpen,
    super.key,
  });

  final ResearchProfileController controller;
  final String uiLocale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    String copy(String key) => _profileCopy(uiLocale, key);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SelahSpacing.md),
      decoration: BoxDecoration(
        color: SelahColors.lavender.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.lavender.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_search_outlined, color: SelahColors.lavender),
          const SizedBox(width: SelahSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy('inviteTitle'),
                  style: SelahTypography.headlineMedium(),
                ),
                const SizedBox(height: 4),
                Text(copy('inviteBody'), style: SelahTypography.bodySmall()),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: onOpen,
                      child: Text(copy('inviteOpen')),
                    ),
                    TextButton(
                      onPressed: controller.saving
                          ? null
                          : () => controller.skip(),
                      child: Text(copy('skip')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResearchProfileSummary extends StatelessWidget {
  const ResearchProfileSummary({
    required this.controller,
    required this.uiLocale,
    super.key,
  });

  final ResearchProfileController controller;
  final String uiLocale;

  @override
  Widget build(BuildContext context) {
    String copy(String key) => _profileCopy(uiLocale, key);
    final profile = controller.profile;
    final answered = profile.hasMeaningfulAnswer || profile.hasAnyAnswer;
    final answers = <Widget>[];
    void addAnswer(String label, String? value) {
      if (value == null || value == 'prefer_not_say') return;
      answers.add(
        Padding(
          padding: const EdgeInsets.only(bottom: SelahSpacing.xs),
          child: Text(
            '$label：${_profileLabel(uiLocale, value)}',
            style: SelahTypography.bodyMedium(),
          ),
        ),
      );
    }

    addAnswer(copy('learningGoal'), profile.learningGoal);
    addAnswer(copy('englishLevel'), profile.englishLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (answers.isNotEmpty) ...[
          ...answers,
        ] else ...[
          Text(
            answered ? copy('saved') : copy('notSaved'),
            style: SelahTypography.bodyMedium(),
          ),
          const SizedBox(height: 7),
        ],
        Text(
          copy('purpose'),
          style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => showSelahSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(SelahSpacing.md),
                  child: SingleChildScrollView(
                    child: ResearchProfileForm(
                      controller: controller,
                      uiLocale: uiLocale,
                      initial: controller.profile,
                      showIdentityFields: true,
                    ),
                  ),
                ),
              ),
              child: Text(copy('edit')),
            ),
            TextButton(
              onPressed: controller.saving
                  ? null
                  : () async {
                      final confirmed = await showSelahDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(copy('withdrawConfirmTitle')),
                          content: Text(copy('withdrawConfirmBody')),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text(copy('withdrawCancel')),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: Text(copy('withdrawConfirm')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await controller.withdraw();
                    },
              child: Text(copy('withdraw')),
            ),
          ],
        ),
      ],
    );
  }
}

List<DropdownMenuItem<String>> _values(String locale, String key) {
  final values = switch (key) {
    'learningGoal' => const [
      'work',
      'daily',
      'travel',
      'exam',
      'other',
      'prefer_not_say',
    ],
    'englishLevel' => const [
      'starter',
      'reading_stronger',
      'conversational',
      'not_sure',
      'prefer_not_say',
    ],
    // The under-14 path stays hidden until the server advertises an approved
    // child-data policy; the stable enum remains in the shared contract.
    'ageGroup' => const [
      'age_14_17',
      'age_18_24',
      'age_25_34',
      'age_35_44',
      'age_45_plus',
      'prefer_not_say',
    ],
    'lifeStage' => const [
      'student',
      'employee',
      'self_employed',
      'other',
      'prefer_not_say',
    ],
    'gender' => const ['male', 'female', 'self_described', 'prefer_not_say'],
    _ => const <String>[],
  };
  return values
      .map(
        (value) => DropdownMenuItem(
          value: value,
          child: Text(_profileLabel(locale, value)),
        ),
      )
      .toList();
}

/// Reuses the same validated, localized options for lightweight forms such as
/// the registration dialog without duplicating the research-profile contract.
List<String> researchProfileOptionValues(String key) => switch (key) {
  'ageGroup' => const [
    'age_14_17',
    'age_18_24',
    'age_25_34',
    'age_35_44',
    'age_45_plus',
    'prefer_not_say',
  ],
  'gender' => const ['male', 'female', 'self_described', 'prefer_not_say'],
  _ => const <String>[],
};

String researchProfileOptionLabel(String locale, String value) =>
    _profileLabel(locale, value);

String _profileLabel(String locale, String value) {
  final language = locale == 'ja'
      ? 'ja'
      : locale == 'zh-Hant'
      ? 'zh-Hant'
      : 'zh-Hans';
  return _profileLabels[language]?[value] ??
      _profileLabels['zh-Hans']![value] ??
      value;
}

String _profileCopy(String locale, String key) {
  final language = locale == 'ja'
      ? 'ja'
      : locale == 'zh-Hant'
      ? 'zh-Hant'
      : 'zh-Hans';
  return _profileCopies[language]?[key] ?? _profileCopies['zh-Hans']![key]!;
}

String? _profileErrorCopy(String locale, String? code) {
  final key = switch (code) {
    'profile_unavailable' => 'errorUnavailable',
    'load_failed' || 'network_unavailable' || 'unavailable' => 'errorLoad',
    'profile_consent_required' => 'errorConsentRequired',
    'profile_notice_changed' => 'errorNoticeChanged',
    'profile_conflict' => 'errorConflict',
    'profile_age_policy_required' => 'errorAgePolicy',
    'profile_invalid_input' => 'errorInvalid',
    'account_changed' => 'errorAccountChanged',
    'login_required' => 'loginHint',
    'save_failed' => 'errorSave',
    _ => null,
  };
  return key == null ? null : _profileCopy(locale, key);
}

const _profileCopies = <String, Map<String, String>>{
  'zh-Hans': {
    'purpose': '告诉我们你的学习目标与目前的英语感受，帮助我们了解你的需要，持续改进 Selah 的学习体验。',
    'purposeNote': '填写完全自愿。目前不会依据这些资料调整生成内容，也不影响试用或会员权益。',
    'learningGoal': '学习目标',
    'englishLevel': '英语自评',
    'ageGroup': '年龄段',
    'lifeStage': '身份',
    'gender': '性别',
    'genderDescription': '请描述你的性别',
    'moreBackground': '更多背景资料（可选）',
    'moreBackgroundSubtitle': '帮助我们了解不同学习者的需要。',
    'saveConsentNote':
        '点击「保存资料」即表示你自愿提交这些资料，并同意我们保存以用于用户研究与改进 Selah 服务。你可以随时撤回并清除。',
    'skip': '跳过',
    'save': '保存资料',
    'saved': '资料已保存，你可以随时修改或撤回。',
    'notSaved': '还没有填写资料。',
    'edit': '修改',
    'withdraw': '撤回并清除资料',
    'loginHint': '登录后可以自愿填写用于用户研究的资料。',
    'inviteTitle': '说说你的学习目标与英语感受',
    'inviteBody': '填写完全自愿，用于改进 Selah 的学习体验，不影响试用或会员权益。',
    'inviteOpen': '填写资料',
    'errorLoad': '这部分暂时读不到，学习不受影响。',
    'errorUnavailable': '这部分目前暂未开放，学习不受影响。',
    'errorSave': '暂时无法保存，请稍后重试；已填写的选择会保留。',
    'errorConsentRequired': '请阅读用途说明后重新保存，或选择暂时略过。',
    'errorNoticeChanged': '资料说明已更新，请重新阅读后再保存。',
    'errorConflict': '这些资料已在其他设备更新，请重新读取后再编辑。',
    'errorAgePolicy': '当前年龄段暂不能收集研究资料。',
    'errorInvalid': '资料格式无效，请检查后重试。',
    'errorAccountChanged': '账户已切换，请重新操作。',
    'retry': '重试',
    'withdrawConfirmTitle': '撤回并清除资料？',
    'withdrawConfirmBody': '清除后需要重新填写；这不会影响你的学习记录。',
    'withdrawConfirm': '清除资料',
    'withdrawCancel': '取消',
  },
  'zh-Hant': {
    'purpose': '告訴我們你的學習目標與目前的英語感受，幫助我們了解你的需要，持續改善 Selah 的學習體驗。',
    'purposeNote': '填寫完全自願。目前不會依這些資料調整生成的內容，也不影響試用或會員權益。',
    'learningGoal': '學習目標',
    'englishLevel': '英語自評',
    'ageGroup': '年齡段',
    'lifeStage': '身分',
    'gender': '性別',
    'genderDescription': '請描述你的性別',
    'moreBackground': '更多背景資料（可選）',
    'moreBackgroundSubtitle': '幫助我們了解不同學習者的需要。',
    'saveConsentNote':
        '點選「儲存資料」即表示你自願提交這些資料，並同意我們儲存以用於使用者研究與改善 Selah 服務。你可以隨時撤回並清除。',
    'skip': '略過',
    'save': '儲存資料',
    'saved': '資料已儲存，你可以隨時修改或撤回。',
    'notSaved': '尚未填寫資料。',
    'edit': '修改',
    'withdraw': '撤回並清除資料',
    'loginHint': '登入後可以自願填寫用於使用者研究的資料。',
    'inviteTitle': '說說你的學習目標與英語感受',
    'inviteBody': '填寫完全自願，用於改善 Selah 的學習體驗，不影響試用或會員權益。',
    'inviteOpen': '填寫資料',
    'errorLoad': '這部分暫時讀不到，學習不受影響。',
    'errorUnavailable': '這部分目前暫未開放，學習不受影響。',
    'errorSave': '暫時無法儲存，請稍後重試；已填寫的選擇會保留。',
    'errorConsentRequired': '請閱讀用途說明後重新儲存，或選擇暫時略過。',
    'errorNoticeChanged': '資料說明已更新，請重新閱讀後再儲存。',
    'errorConflict': '這些資料已在其他裝置更新，請重新讀取後再編輯。',
    'errorAgePolicy': '目前這個年齡段暫不能收集研究資料。',
    'errorInvalid': '資料格式無效，請檢查後重試。',
    'errorAccountChanged': '帳戶已切換，請重新操作。',
    'retry': '重試',
    'withdrawConfirmTitle': '撤回並清除資料？',
    'withdrawConfirmBody': '清除後需要重新填寫；這不會影響你的學習記錄。',
    'withdrawConfirm': '清除資料',
    'withdrawCancel': '取消',
  },
  'ja': {
    'purpose': '学習目標と今の英語の感覚を教えてください。あなたの必要を理解し、Selah の学習体験を改善するために使います。',
    'purposeNote': '回答は任意です。現在、この資料で生成内容を変えることはありません。トライアルや会員権益にも影響しません。',
    'learningGoal': '学習目的',
    'englishLevel': '英語の自己評価',
    'ageGroup': '年齢層',
    'lifeStage': '立場',
    'gender': '性別',
    'genderDescription': '性別を入力',
    'moreBackground': '追加の背景情報（任意）',
    'moreBackgroundSubtitle': 'さまざまな学習者のニーズを理解するために使います。',
    'saveConsentNote':
        '「保存」を押すと、これらの情報を自発的に送信し、保存してユーザー調査と Selah のサービス改善に利用することに同意したものとします。いつでも同意を撤回して削除できます。',
    'skip': 'スキップ',
    'save': '保存',
    'saved': '保存しました。いつでも変更または撤回できます。',
    'notSaved': 'まだ入力していません。',
    'edit': '編集',
    'withdraw': '撤回して削除',
    'loginHint': 'ログインすると、ユーザー調査用の資料を任意で入力できます。',
    'inviteTitle': '学習目標と英語の感覚を教えてください',
    'inviteBody': '回答は任意です。Selah の学習体験改善に使います。トライアルや会員権益には影響しません。',
    'inviteOpen': '入力する',
    'errorLoad': 'この部分は一時的に読み込めません。学習には影響しません。',
    'errorUnavailable': 'この部分は現在利用できません。学習には影響しません。',
    'errorSave': '一時的に保存できません。後でもう一度お試しください。入力内容は保持されます。',
    'errorConsentRequired': '利用目的を確認してから保存するか、スキップしてください。',
    'errorNoticeChanged': '資料の説明が更新されました。読み直してから保存してください。',
    'errorConflict': 'この資料は他の端末で更新されています。読み直してから編集してください。',
    'errorAgePolicy': '現在、この年齢層の研究資料は収集できません。',
    'errorInvalid': '資料の形式が無効です。確認してから再試行してください。',
    'errorAccountChanged': 'アカウントが切り替わりました。もう一度操作してください。',
    'retry': '再試行',
    'withdrawConfirmTitle': '同意を撤回して資料を削除しますか？',
    'withdrawConfirmBody': '削除すると再度入力が必要になります。学習記録には影響しません。',
    'withdrawConfirm': '資料を削除',
    'withdrawCancel': 'キャンセル',
  },
};

const _profileLabels = <String, Map<String, String>>{
  'zh-Hans': {
    'work': '工作',
    'daily': '日常交流',
    'travel': '旅行',
    'exam': '考试',
    'other': '其他',
    'starter': '刚开始',
    'reading_stronger': '阅读更有把握',
    'conversational': '可以交流',
    'not_sure': '不确定',
    'under_14': '14 岁以下',
    'age_14_17': '14～17 岁',
    'age_18_24': '18～24 岁',
    'age_25_34': '25～34 岁',
    'age_35_44': '35～44 岁',
    'age_45_plus': '45 岁以上',
    'student': '学生',
    'employee': '上班族',
    'self_employed': '自由职业',
    'male': '男',
    'female': '女',
    'self_described': '自行描述',
    'prefer_not_say': '不愿透露',
  },
  'zh-Hant': {
    'work': '工作',
    'daily': '日常交流',
    'travel': '旅行',
    'exam': '考試',
    'other': '其他',
    'starter': '剛開始',
    'reading_stronger': '閱讀較有把握',
    'conversational': '可以交流',
    'not_sure': '不確定',
    'under_14': '未滿 14 歲',
    'age_14_17': '14～17 歲',
    'age_18_24': '18～24 歲',
    'age_25_34': '25～34 歲',
    'age_35_44': '35～44 歲',
    'age_45_plus': '45 歲以上',
    'student': '學生',
    'employee': '上班族',
    'self_employed': '自由工作者',
    'male': '男性',
    'female': '女性',
    'self_described': '自行描述',
    'prefer_not_say': '不願透露',
  },
  'ja': {
    'work': '仕事',
    'daily': '日常会話',
    'travel': '旅行',
    'exam': '試験',
    'other': 'その他',
    'starter': '始めたばかり',
    'reading_stronger': '読む方が得意',
    'conversational': '会話できる',
    'not_sure': 'わからない',
    'under_14': '14歳未満',
    'age_14_17': '14～17歳',
    'age_18_24': '18～24歳',
    'age_25_34': '25～34歳',
    'age_35_44': '35～44歳',
    'age_45_plus': '45歳以上',
    'student': '学生',
    'employee': '会社員',
    'self_employed': '自営業',
    'male': '男性',
    'female': '女性',
    'self_described': '自由記述',
    'prefer_not_say': '回答しない',
  },
};
