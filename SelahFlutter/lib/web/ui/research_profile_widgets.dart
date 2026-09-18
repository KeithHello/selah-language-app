import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
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
  bool _consent = false;

  String copy(String key) => _profileCopy(widget.uiLocale, key);

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy('title'), style: SelahTypography.headlineMedium()),
        const SizedBox(height: 6),
        Text(copy('purpose'), style: SelahTypography.bodySmall(color: SelahColors.textSecondary)),
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
        const SizedBox(height: SelahSpacing.sm),
        _select(
          label: copy('ageGroup'),
          value: _age,
          items: _values(widget.uiLocale, 'ageGroup'),
          onChanged: (value) => setState(() => _age = value),
        ),
        if (widget.showIdentityFields) ...[
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
              decoration: InputDecoration(labelText: copy('genderDescription')),
              onChanged: (value) => _genderDescription = value,
            ),
          ],
        ],
        const SizedBox(height: SelahSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: (value) => setState(() => _consent = value == true),
          title: Text(copy('consent')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: SelahSpacing.xs),
        Row(
          children: [
            TextButton(
              onPressed: c.saving ? null : () async {
                await c.skip();
                widget.onDone?.call();
              },
              child: Text(copy('skip')),
            ),
            const Spacer(),
            FilledButton(
              onPressed: c.saving ? null : () async {
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
                    consent: _consent,
                  );
                  widget.onDone?.call();
                } catch (_) {
                  if (mounted) setState(() {});
                }
              },
              child: Text(copy('save')),
            ),
          ],
        ),
        if (c.error != null) ...[
          const SizedBox(height: SelahSpacing.xs),
          Text(c.error!, style: SelahTypography.bodySmall(color: SelahColors.danger)),
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
  const ResearchProfileEntry({required this.controller, required this.uiLocale, super.key});

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
        if (controller.promptState == ResearchProfilePromptState.withdrawn ||
            controller.promptState == ResearchProfilePromptState.answered ||
            controller.promptState == ResearchProfilePromptState.skipped) {
          return ResearchProfileSummary(controller: controller, uiLocale: uiLocale);
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
                Text(copy('inviteTitle'), style: SelahTypography.headlineMedium()),
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
  const ResearchProfileSummary({required this.controller, required this.uiLocale, super.key});

  final ResearchProfileController controller;
  final String uiLocale;

  @override
  Widget build(BuildContext context) {
    String copy(String key) => _profileCopy(uiLocale, key);
    final answered = controller.profile.hasMeaningfulAnswer || controller.profile.hasAnyAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(answered ? copy('saved') : copy('notSaved'), style: SelahTypography.bodyMedium()),
        const SizedBox(height: 7),
        Text(copy('purpose'), style: SelahTypography.bodySmall(color: SelahColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => showModalBottomSheet<void>(
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
              onPressed: controller.saving ? null : () => controller.withdraw(),
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
    'learningGoal' => const ['work', 'daily', 'travel', 'exam', 'other', 'prefer_not_say'],
    'englishLevel' => const ['starter', 'reading_stronger', 'conversational', 'not_sure', 'prefer_not_say'],
    // The under-14 path stays hidden until the server advertises an approved
    // child-data policy; the stable enum remains in the shared contract.
    'ageGroup' => const ['age_14_17', 'age_18_24', 'age_25_34', 'age_35_44', 'age_45_plus', 'prefer_not_say'],
    'lifeStage' => const ['student', 'employee', 'self_employed', 'other', 'prefer_not_say'],
    'gender' => const ['male', 'female', 'self_described', 'prefer_not_say'],
    _ => const <String>[],
  };
  return values
      .map((value) => DropdownMenuItem(value: value, child: Text(_profileLabel(locale, value))))
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
  final language = locale == 'ja' ? 'ja' : locale == 'zh-Hant' ? 'zh-Hant' : 'zh-Hans';
  return _profileLabels[language]?[value] ?? _profileLabels['zh-Hans']![value] ?? value;
}

String _profileCopy(String locale, String key) {
  final language = locale == 'ja' ? 'ja' : locale == 'zh-Hant' ? 'zh-Hant' : 'zh-Hans';
  return _profileCopies[language]?[key] ?? _profileCopies['zh-Hans']![key]!;
}

const _profileCopies = <String, Map<String, String>>{
  'zh-Hans': {
    'title': '可选资料',
    'purpose': '用于用户研究与改进学习体验，填写完全自愿，不影响试用或会员权益。',
    'learningGoal': '学习目标',
    'englishLevel': '英语自评',
    'ageGroup': '年龄段',
    'lifeStage': '身份',
    'gender': '性别',
    'genderDescription': '请描述你的性别',
    'consent': '我同意将这些资料用于用户研究。',
    'skip': '跳过',
    'save': '保存资料',
    'saved': '资料已保存，你可以随时修改或撤回。',
    'notSaved': '还没有填写资料。',
    'edit': '修改',
    'withdraw': '撤回并清除资料',
    'loginHint': '登录后可以自愿填写用于用户研究的资料。',
    'inviteTitle': '愿意告诉我们一点你的学习情况吗？',
    'inviteBody': '填写完全自愿，只用于用户研究与改进学习体验，不影响试用或会员权益。',
    'inviteOpen': '填写资料',
  },
  'zh-Hant': {
    'title': '可選資料',
    'purpose': '用於使用者研究與改善學習體驗，填寫完全自願，不影響試用或會員權益。',
    'learningGoal': '學習目標',
    'englishLevel': '英語自評',
    'ageGroup': '年齡段',
    'lifeStage': '身分',
    'gender': '性別',
    'genderDescription': '請描述你的性別',
    'consent': '我同意將這些資料用於使用者研究。',
    'skip': '略過',
    'save': '儲存資料',
    'saved': '資料已儲存，你可以隨時修改或撤回。',
    'notSaved': '尚未填寫資料。',
    'edit': '修改',
    'withdraw': '撤回並清除資料',
    'loginHint': '登入後可以自願填寫用於使用者研究的資料。',
    'inviteTitle': '願意告訴我們一點你的學習情況嗎？',
    'inviteBody': '填寫完全自願，只用於使用者研究與改善學習體驗，不影響試用或會員權益。',
    'inviteOpen': '填寫資料',
  },
  'ja': {
    'title': '任意のプロフィール',
    'purpose': 'ユーザー調査と学習体験の改善に使います。回答は任意で、トライアルや会員権益には影響しません。',
    'learningGoal': '学習目的',
    'englishLevel': '英語の自己評価',
    'ageGroup': '年齢層',
    'lifeStage': '立場',
    'gender': '性別',
    'genderDescription': '性別を入力',
    'consent': 'この資料をユーザー調査に使うことに同意します。',
    'skip': 'スキップ',
    'save': '保存',
    'saved': '保存しました。いつでも変更または撤回できます。',
    'notSaved': 'まだ入力していません。',
    'edit': '編集',
    'withdraw': '撤回して削除',
    'loginHint': 'ログインすると、ユーザー調査用の資料を任意で入力できます。',
    'inviteTitle': '学習について少し教えてください。',
    'inviteBody': '回答は任意で、ユーザー調査と学習体験の改善にのみ使います。トライアルや会員権益には影響しません。',
    'inviteOpen': '入力する',
  },
};

const _profileLabels = <String, Map<String, String>>{
  'zh-Hans': {
    'work': '工作', 'daily': '日常交流', 'travel': '旅行', 'exam': '考试', 'other': '其他',
    'starter': '刚开始', 'reading_stronger': '阅读更有把握', 'conversational': '可以交流', 'not_sure': '不确定',
    'under_14': '14 岁以下', 'age_14_17': '14～17 岁', 'age_18_24': '18～24 岁', 'age_25_34': '25～34 岁', 'age_35_44': '35～44 岁', 'age_45_plus': '45 岁以上',
    'student': '学生', 'employee': '上班族', 'self_employed': '自由职业',
    'male': '男', 'female': '女', 'self_described': '自行描述', 'prefer_not_say': '不愿透露',
  },
  'zh-Hant': {
    'work': '工作', 'daily': '日常交流', 'travel': '旅行', 'exam': '考試', 'other': '其他',
    'starter': '剛開始', 'reading_stronger': '閱讀較有把握', 'conversational': '可以交流', 'not_sure': '不確定',
    'under_14': '未滿 14 歲', 'age_14_17': '14～17 歲', 'age_18_24': '18～24 歲', 'age_25_34': '25～34 歲', 'age_35_44': '35～44 歲', 'age_45_plus': '45 歲以上',
    'student': '學生', 'employee': '上班族', 'self_employed': '自由工作者',
    'male': '男性', 'female': '女性', 'self_described': '自行描述', 'prefer_not_say': '不願透露',
  },
  'ja': {
    'work': '仕事', 'daily': '日常会話', 'travel': '旅行', 'exam': '試験', 'other': 'その他',
    'starter': '始めたばかり', 'reading_stronger': '読む方が得意', 'conversational': '会話できる', 'not_sure': 'わからない',
    'under_14': '14歳未満', 'age_14_17': '14～17歳', 'age_18_24': '18～24歳', 'age_25_34': '25～34歳', 'age_35_44': '35～44歳', 'age_45_plus': '45歳以上',
    'student': '学生', 'employee': '会社員', 'self_employed': '自営業',
    'male': '男性', 'female': '女性', 'self_described': '自由記述', 'prefer_not_say': '回答しない',
  },
};
