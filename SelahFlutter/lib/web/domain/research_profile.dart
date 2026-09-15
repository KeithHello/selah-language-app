enum ResearchProfilePromptState { unseen, offered, skipped, answered, withdrawn }

enum ResearchProfileConsentState { none, granted, withdrawn }

class ResearchProfile {
  const ResearchProfile({
    this.learningGoal,
    this.englishLevel,
    this.ageGroup,
    this.lifeStage,
    this.gender,
    this.genderDescription,
  });

  final String? learningGoal;
  final String? englishLevel;
  final String? ageGroup;
  final String? lifeStage;
  final String? gender;
  final String? genderDescription;

  bool get hasAnyAnswer =>
      learningGoal != null ||
      englishLevel != null ||
      ageGroup != null ||
      lifeStage != null ||
      gender != null ||
      genderDescription != null;

  bool get hasMeaningfulAnswer => [
        learningGoal,
        englishLevel,
        ageGroup,
        lifeStage,
        gender,
      ].any((value) => value != null && value != 'prefer_not_say');

  ResearchProfile copyWith({
    String? learningGoal,
    String? englishLevel,
    String? ageGroup,
    String? lifeStage,
    String? gender,
    String? genderDescription,
  }) => ResearchProfile(
        learningGoal: learningGoal ?? this.learningGoal,
        englishLevel: englishLevel ?? this.englishLevel,
        ageGroup: ageGroup ?? this.ageGroup,
        lifeStage: lifeStage ?? this.lifeStage,
        gender: gender ?? this.gender,
        genderDescription: genderDescription ?? this.genderDescription,
      );

  Map<String, dynamic> toJson() => {
        'learningGoal': learningGoal,
        'englishLevel': englishLevel,
        'ageGroup': ageGroup,
        'lifeStage': lifeStage,
        'gender': gender,
        'genderDescription': genderDescription,
      };

  factory ResearchProfile.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    String? optional(Object? raw) {
      if (raw == null || raw == '') return null;
      if (raw is! String) throw const FormatException('研究资料格式无效。');
      return raw;
    }

    return ResearchProfile(
      learningGoal: optional(map['learningGoal'] ?? map['learning_goal']),
      englishLevel: optional(map['englishLevel'] ?? map['english_level']),
      ageGroup: optional(map['ageGroup'] ?? map['age_group']),
      lifeStage: optional(map['lifeStage'] ?? map['life_stage']),
      gender: optional(map['gender']),
      genderDescription:
          optional(map['genderDescription'] ?? map['gender_description']),
    );
  }
}

class ResearchProfileSnapshot {
  const ResearchProfileSnapshot({
    required this.profile,
    required this.promptState,
    required this.consentState,
    required this.noticeVersion,
    required this.revision,
    required this.canInvite,
  });

  final ResearchProfile profile;
  final ResearchProfilePromptState promptState;
  final ResearchProfileConsentState consentState;
  final String noticeVersion;
  final int revision;
  final bool canInvite;

  factory ResearchProfileSnapshot.empty() => const ResearchProfileSnapshot(
        profile: ResearchProfile(),
        promptState: ResearchProfilePromptState.unseen,
        consentState: ResearchProfileConsentState.none,
        noticeVersion: '2026-09-12-v1',
        revision: 0,
        canInvite: false,
      );

  factory ResearchProfileSnapshot.fromJson(Map<String, dynamic> json) {
    ResearchProfilePromptState prompt(Object? raw) =>
        ResearchProfilePromptState.values.firstWhere(
          (item) => item.name == raw,
          orElse: () => ResearchProfilePromptState.unseen,
        );
    ResearchProfileConsentState consent(Object? raw) =>
        ResearchProfileConsentState.values.firstWhere(
          (item) => item.name == raw,
          orElse: () => ResearchProfileConsentState.none,
        );
    final revision = json['revision'];
    return ResearchProfileSnapshot(
      profile: ResearchProfile.fromJson(json['profile']),
      promptState: prompt(json['promptState'] ?? json['prompt_state']),
      consentState: consent(json['consentState'] ?? json['consent_state']),
      noticeVersion: (json['noticeVersion'] ?? json['notice_version'] ??
              '2026-09-12-v1')
          .toString(),
      revision: revision is num ? revision.toInt() : 0,
      canInvite: json['canInvite'] == true || json['can_invite'] == true,
    );
  }
}
