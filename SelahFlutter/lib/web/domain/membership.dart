enum MembershipPlan { free, trial, monthly, pro }

enum MembershipStatus { none, trial, active, expired }

enum TrialState { notStarted, preparing, active, expired, unavailable }

enum MembershipSource { paid, grant, compensation, systemTrial }

MembershipSource _parseMembershipSource(String raw) {
  if (raw == 'system_trial') return MembershipSource.systemTrial;
  return MembershipSource.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => MembershipSource.paid,
  );
}

class PlanEntitlements {
  const PlanEntitlements({
    required this.maxSentences,
    required this.maxTtsCharacters,
    required this.maxTranscriptionMs,
    required this.maxPreparations,
  });

  final int maxSentences;
  final int maxTtsCharacters;
  final int maxTranscriptionMs;
  final int maxPreparations;

  factory PlanEntitlements.fromJson(Map<String, dynamic> json) =>
      PlanEntitlements(
        maxSentences: (json['maxSentences'] as num?)?.toInt() ?? 0,
        maxTtsCharacters: (json['maxTtsCharacters'] as num?)?.toInt() ?? 0,
        maxTranscriptionMs: (json['maxTranscriptionMs'] as num?)?.toInt() ?? 0,
        maxPreparations: (json['maxPreparations'] as num?)?.toInt() ?? 0,
      );
}

class MembershipUsageCounter {
  const MembershipUsageCounter({required this.used, required this.reserved});

  final int used;
  final int reserved;

  static MembershipUsageCounter? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final used = value['used'];
    final reserved = value['reserved'];
    if (used is! num || reserved is! num || used < 0 || reserved < 0) {
      return null;
    }
    return MembershipUsageCounter(
      used: used.toInt(),
      reserved: reserved.toInt(),
    );
  }
}

class MembershipUsage {
  const MembershipUsage({
    required this.sentence,
    required this.batch,
    required this.ttsCharacters,
    required this.transcriptionMs,
    required this.preparations,
  });

  final MembershipUsageCounter sentence;
  final MembershipUsageCounter batch;
  final MembershipUsageCounter ttsCharacters;
  final MembershipUsageCounter transcriptionMs;
  final MembershipUsageCounter preparations;

  static MembershipUsage? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final sentence = MembershipUsageCounter.tryParse(value['sentence']);
    final batch = MembershipUsageCounter.tryParse(value['batch']);
    final tts = MembershipUsageCounter.tryParse(value['ttsCharacters']);
    final transcription = MembershipUsageCounter.tryParse(
      value['transcriptionMs'],
    );
    final preparations = MembershipUsageCounter.tryParse(value['preparations']);
    if (sentence == null ||
        batch == null ||
        tts == null ||
        transcription == null ||
        preparations == null) {
      return null;
    }
    return MembershipUsage(
      sentence: sentence,
      batch: batch,
      ttsCharacters: tts,
      transcriptionMs: transcription,
      preparations: preparations,
    );
  }
}

/// The client uses these Pro entitlements for display; only the server grants
/// them. Self-service purchase stays disabled until the migration and a
/// verified payment adapter are live.
const proPlanSku = 'selah_membership_pro';
const proPriceFenCnyValue = 9990;
const proPriceFenCny = proPriceFenCnyValue;
const proPlanEntitlements = PlanEntitlements(
  maxSentences: 900,
  maxTtsCharacters: 90000,
  maxTranscriptionMs: 10800000,
  maxPreparations: 90,
);

class MembershipSummary {
  const MembershipSummary({
    required this.plan,
    required this.status,
    this.membershipModeEnabled = false,
    this.trialSignupsEnabled = false,
    this.membershipSalesEnabled = false,
    this.paymentProviderConfigured = false,
    this.proSalesEnabled = false,
    this.proPriceFenCny = proPriceFenCnyValue,
    this.proEntitlements = proPlanEntitlements,
    this.trialState = TrialState.notStarted,
    this.trialStartedAt,
    this.trialExpiresAt,
    this.periodStartsAt,
    this.periodEndsAt,
    this.membershipSource,
    this.nextPeriodStartsAt,
    this.nextPeriodSource,
    this.renewalMode = 'manual',
    this.entitlementVersion = 'monthly-v1',
    this.modelDisclosure = 'openai-gpt-4o-mini-v1',
    this.usage,
    this.usageStatus = 'not_applicable',
    required this.staticEntitlements,
  });

  final MembershipPlan plan;
  final MembershipStatus status;

  /// Mirrors the server-side global switch. When false, generation remains in
  /// the public free mode and the plan cards are informational only.
  final bool membershipModeEnabled;
  final bool trialSignupsEnabled;
  final bool membershipSalesEnabled;

  /// True only after a real provider adapter and verified webhook secret are
  /// configured. A pending order alone never means that payment is ready.
  final bool paymentProviderConfigured;

  /// Server-controlled.  It stays false until Pro SKU, entitlements, and a
  /// verified payment provider are live together.
  final bool proSalesEnabled;
  final int proPriceFenCny;
  final PlanEntitlements proEntitlements;
  final TrialState trialState;
  final DateTime? trialStartedAt;
  final DateTime? trialExpiresAt;
  final DateTime? periodStartsAt;
  final DateTime? periodEndsAt;
  final MembershipSource? membershipSource;
  final DateTime? nextPeriodStartsAt;
  final MembershipSource? nextPeriodSource;
  final String renewalMode;
  final String entitlementVersion;
  final String modelDisclosure;
  final MembershipUsage? usage;
  final String usageStatus;
  final PlanEntitlements staticEntitlements;

  MembershipSummary withoutUsage() => MembershipSummary(
    plan: plan,
    status: status,
    membershipModeEnabled: membershipModeEnabled,
    trialSignupsEnabled: trialSignupsEnabled,
    membershipSalesEnabled: membershipSalesEnabled,
    paymentProviderConfigured: paymentProviderConfigured,
    proSalesEnabled: proSalesEnabled,
    proPriceFenCny: proPriceFenCny,
    proEntitlements: proEntitlements,
    trialState: trialState,
    trialStartedAt: trialStartedAt,
    trialExpiresAt: trialExpiresAt,
    periodStartsAt: periodStartsAt,
    periodEndsAt: periodEndsAt,
    membershipSource: membershipSource,
    nextPeriodStartsAt: nextPeriodStartsAt,
    nextPeriodSource: nextPeriodSource,
    renewalMode: renewalMode,
    entitlementVersion: entitlementVersion,
    modelDisclosure: modelDisclosure,
    usageStatus: 'unavailable',
    staticEntitlements: staticEntitlements,
  );

  bool get isPaidActive =>
      (plan == MembershipPlan.monthly || plan == MembershipPlan.pro) &&
      status == MembershipStatus.active;

  bool get isTrialActive =>
      plan == MembershipPlan.trial && status == MembershipStatus.trial;

  bool get hasActiveEntitlements => isPaidActive || isTrialActive;

  bool get isPublicFreeMode => !membershipModeEnabled;

  factory MembershipSummary.empty() => const MembershipSummary(
    plan: MembershipPlan.free,
    status: MembershipStatus.none,
    membershipModeEnabled: false,
    trialSignupsEnabled: false,
    membershipSalesEnabled: false,
    paymentProviderConfigured: false,
    proSalesEnabled: false,
    trialState: TrialState.notStarted,
    staticEntitlements: PlanEntitlements(
      maxSentences: 0,
      maxTtsCharacters: 0,
      maxTranscriptionMs: 0,
      maxPreparations: 0,
    ),
  );

  factory MembershipSummary.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan']?.toString() ?? 'free';
    final rawStatus = json['status']?.toString() ?? 'none';
    final rawSource = json['membershipSource']?.toString();
    final rawNextSource = json['nextPeriodSource']?.toString();
    final rawTrialState =
        json['trialState']?.toString() ?? json['trial_state']?.toString();

    return MembershipSummary(
      plan: MembershipPlan.values.firstWhere(
        (e) => e.name == rawPlan,
        orElse: () => MembershipPlan.free,
      ),
      status: MembershipStatus.values.firstWhere(
        (e) => e.name == rawStatus,
        orElse: () => MembershipStatus.none,
      ),
      membershipModeEnabled:
          json['membershipModeEnabled'] == true ||
          json['membership_mode_enabled'] == true,
      trialSignupsEnabled:
          json['trialSignupsEnabled'] == true ||
          json['trial_signups_enabled'] == true,
      membershipSalesEnabled:
          json['membershipSalesEnabled'] == true ||
          json['membership_sales_enabled'] == true,
      paymentProviderConfigured:
          json['paymentProviderConfigured'] == true ||
          json['payment_provider_configured'] == true,
      proSalesEnabled:
          json['proSalesEnabled'] == true || json['pro_sales_enabled'] == true,
      proPriceFenCny:
          (json['proPriceFenCny'] as num?)?.toInt() ??
          (json['pro_price_fen_cny'] as num?)?.toInt() ??
          proPriceFenCnyValue,
      proEntitlements: json['proEntitlements'] is Map<String, dynamic>
          ? PlanEntitlements.fromJson(
              json['proEntitlements'] as Map<String, dynamic>,
            )
          : json['pro_entitlements'] is Map<String, dynamic>
          ? PlanEntitlements.fromJson(
              json['pro_entitlements'] as Map<String, dynamic>,
            )
          : proPlanEntitlements,
      trialState: TrialState.values.firstWhere(
        (item) => item.name == _trialStateName(rawTrialState, json),
        orElse: () => TrialState.unavailable,
      ),
      trialStartedAt: _date(json['trialStartedAt'] ?? json['trial_started_at']),
      trialExpiresAt: _date(json['trialExpiresAt'] ?? json['trial_expires_at']),
      periodStartsAt: json['periodStartsAt'] != null
          ? DateTime.tryParse(json['periodStartsAt'].toString())
          : null,
      periodEndsAt: json['periodEndsAt'] != null
          ? DateTime.tryParse(json['periodEndsAt'].toString())
          : null,
      membershipSource: rawSource != null
          ? _parseMembershipSource(rawSource)
          : null,
      nextPeriodStartsAt: json['nextPeriodStartsAt'] != null
          ? DateTime.tryParse(json['nextPeriodStartsAt'].toString())
          : null,
      nextPeriodSource: rawNextSource != null
          ? _parseMembershipSource(rawNextSource)
          : null,
      renewalMode: json['renewalMode']?.toString() ?? 'manual',
      entitlementVersion:
          json['entitlementVersion']?.toString() ?? 'monthly-v1',
      modelDisclosure:
          json['modelDisclosure']?.toString() ?? 'openai-gpt-4o-mini-v1',
      usage: MembershipUsage.tryParse(json['usage']),
      usageStatus: json['usageStatus']?.toString() ?? 'not_applicable',
      staticEntitlements: json['staticEntitlements'] is Map<String, dynamic>
          ? PlanEntitlements.fromJson(
              json['staticEntitlements'] as Map<String, dynamic>,
            )
          : const PlanEntitlements(
              maxSentences: 0,
              maxTtsCharacters: 0,
              maxTranscriptionMs: 0,
              maxPreparations: 0,
            ),
    );
  }
}

String _trialStateName(String? raw, Map<String, dynamic> json) {
  if (raw != null) {
    return switch (raw) {
      'not_started' => 'notStarted',
      'preparing' => 'preparing',
      'active' => 'active',
      'expired' => 'expired',
      'unavailable' => 'unavailable',
      _ => raw,
    };
  }
  final plan = json['plan']?.toString();
  if (plan != 'trial') return 'notStarted';
  final status = json['status']?.toString();
  if (status == 'expired') return 'expired';
  final started = json['trialStartedAt'] ?? json['periodStartsAt'];
  final expires = json['trialExpiresAt'] ?? json['periodEndsAt'];
  return started is String &&
          started.isNotEmpty &&
          expires is String &&
          expires.isNotEmpty
      ? 'active'
      : 'preparing';
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
