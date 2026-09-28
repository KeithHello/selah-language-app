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

class MembershipFeatureUsage {
  const MembershipFeatureUsage({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  final int used;
  final int limit;
  final int remaining;
}

class MembershipUsage {
  const MembershipUsage({
    required this.asOf,
    required this.sentences,
    required this.ttsCharacters,
    required this.transcriptionMs,
    required this.preparations,
  });

  final DateTime? asOf;
  final MembershipFeatureUsage sentences;
  final MembershipFeatureUsage ttsCharacters;
  final MembershipFeatureUsage transcriptionMs;
  final MembershipFeatureUsage preparations;
}

class MembershipFuturePeriod {
  const MembershipFuturePeriod({
    required this.id,
    required this.plan,
    required this.source,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final MembershipPlan plan;
  final MembershipSource source;
  final DateTime startsAt;
  final DateTime endsAt;
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
    this.futurePeriods = const [],
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
  final PlanEntitlements staticEntitlements;
  final MembershipUsage? usage;
  final List<MembershipFuturePeriod> futurePeriods;

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
    final usage = _membershipUsage(json['usage']);
    final futurePeriods = _membershipFuturePeriods(json['futurePeriods']);

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
      usage: usage,
      futurePeriods: futurePeriods,
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

MembershipUsage? _membershipUsage(Object? value) {
  final json = _jsonMap(value);
  if (json == null) return null;
  final sentences = _membershipFeatureUsage(json['sentences']);
  final ttsCharacters = _membershipFeatureUsage(json['ttsCharacters']);
  final transcriptionMs = _membershipFeatureUsage(json['transcriptionMs']);
  final preparations = _membershipFeatureUsage(json['preparations']);
  if (sentences == null ||
      ttsCharacters == null ||
      transcriptionMs == null ||
      preparations == null) {
    return null;
  }
  return MembershipUsage(
    asOf: _date(json['asOf']),
    sentences: sentences,
    ttsCharacters: ttsCharacters,
    transcriptionMs: transcriptionMs,
    preparations: preparations,
  );
}

MembershipFeatureUsage? _membershipFeatureUsage(Object? value) {
  final json = _jsonMap(value);
  if (json == null) return null;
  final used = _nonNegativeInt(json['used']);
  final limit = _nonNegativeInt(json['limit']);
  final remaining = _nonNegativeInt(json['remaining']);
  if (used == null || limit == null || remaining == null) return null;
  return MembershipFeatureUsage(used: used, limit: limit, remaining: remaining);
}

List<MembershipFuturePeriod> _membershipFuturePeriods(Object? value) {
  if (value is! List) return const [];
  return value
      .map(_membershipFuturePeriod)
      .whereType<MembershipFuturePeriod>()
      .toList();
}

MembershipFuturePeriod? _membershipFuturePeriod(Object? value) {
  final json = _jsonMap(value);
  if (json == null) return null;
  final id = json['id']?.toString();
  final rawPlan = json['plan']?.toString();
  final rawSource = json['source']?.toString();
  final startsAt = _date(json['startsAt'] ?? json['starts_at']);
  final endsAt = _date(json['endsAt'] ?? json['expires_at']);
  if (id == null ||
      id.isEmpty ||
      rawPlan == null ||
      rawSource == null ||
      startsAt == null ||
      endsAt == null) {
    return null;
  }
  final plan = MembershipPlan.values.where((item) => item.name == rawPlan);
  final knownSource =
      rawSource == 'system_trial' ||
      MembershipSource.values.any((item) => item.name == rawSource);
  if (plan.isEmpty || plan.single == MembershipPlan.free || !knownSource) {
    return null;
  }
  return MembershipFuturePeriod(
    id: id,
    plan: plan.single,
    source: _parseMembershipSource(rawSource),
    startsAt: startsAt,
    endsAt: endsAt,
  );
}

Map<String, dynamic>? _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int? _nonNegativeInt(Object? value) {
  if (value is! num) return null;
  final integer = value.toInt();
  if (integer < 0 || integer != value) return null;
  return integer;
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
