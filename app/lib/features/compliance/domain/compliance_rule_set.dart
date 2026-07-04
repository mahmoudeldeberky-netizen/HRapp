import 'package:equatable/equatable.dart';

/// Machine-readable labor-law parameters for one country, one version,
/// one effective window. Mirrors `compliance_rule_sets.rules` in Postgres.
///
/// Laws are DATA: publishing a new decree creates a new version — no code
/// changes, no redeploys.
class ComplianceRuleSet extends Equatable {
  const ComplianceRuleSet({
    required this.countryCode,
    required this.version,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.annualLeave,
    required this.workingHours,
    required this.overtime,
    required this.taxBrackets,
    required this.socialInsurance,
    required this.endOfService,
    required this.termination,
  });

  final String countryCode;
  final int version;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;

  final AnnualLeaveRule annualLeave;
  final WorkingHoursRule workingHours;
  final OvertimeRule overtime;
  final List<TaxBracket> taxBrackets;
  final SocialInsuranceRule socialInsurance;
  final EndOfServiceRule endOfService;
  final TerminationRule termination;

  bool isEffectiveOn(DateTime date) =>
      !date.isBefore(effectiveFrom) &&
      (effectiveTo == null || !date.isAfter(effectiveTo!));

  factory ComplianceRuleSet.fromJson(Map<String, dynamic> json) {
    return ComplianceRuleSet(
      countryCode: json['country_code'] as String,
      version: json['version'] as int,
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      effectiveTo: json['effective_to'] == null
          ? null
          : DateTime.parse(json['effective_to'] as String),
      annualLeave:
          AnnualLeaveRule.fromJson(json['annual_leave'] as Map<String, dynamic>),
      workingHours:
          WorkingHoursRule.fromJson(json['working_hours'] as Map<String, dynamic>),
      overtime: OvertimeRule.fromJson(json['overtime'] as Map<String, dynamic>),
      taxBrackets: (json['income_tax_brackets'] as List<dynamic>)
          .map((b) => TaxBracket.fromJson(b as Map<String, dynamic>))
          .toList(),
      socialInsurance: SocialInsuranceRule.fromJson(
          json['social_insurance'] as Map<String, dynamic>),
      endOfService:
          EndOfServiceRule.fromJson(json['end_of_service'] as Map<String, dynamic>),
      termination:
          TerminationRule.fromJson(json['termination'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [countryCode, version, effectiveFrom, effectiveTo];
}

class AnnualLeaveRule extends Equatable {
  const AnnualLeaveRule({
    required this.baseDays,
    this.tiers = const [],
    this.probationMonthsBeforeEligible = 0,
  });

  final int baseDays;
  final List<LeaveTier> tiers;
  final int probationMonthsBeforeEligible;

  factory AnnualLeaveRule.fromJson(Map<String, dynamic> json) => AnnualLeaveRule(
        baseDays: json['base_days'] as int,
        tiers: (json['tiers'] as List<dynamic>? ?? [])
            .map((t) => LeaveTier.fromJson(t as Map<String, dynamic>))
            .toList(),
        probationMonthsBeforeEligible:
            json['probation_months_before_eligible'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [baseDays, tiers, probationMonthsBeforeEligible];
}

/// A tier upgrades entitlement when service years and/or age thresholds are met.
class LeaveTier extends Equatable {
  const LeaveTier({this.minServiceYears, this.minAge, required this.days});

  final int? minServiceYears;
  final int? minAge;
  final int days;

  factory LeaveTier.fromJson(Map<String, dynamic> json) => LeaveTier(
        minServiceYears: json['min_service_years'] as int?,
        minAge: json['min_age'] as int?,
        days: json['days'] as int,
      );

  @override
  List<Object?> get props => [minServiceYears, minAge, days];
}

class WorkingHoursRule extends Equatable {
  const WorkingHoursRule({required this.maxDaily, required this.maxWeekly});

  final double maxDaily;
  final double maxWeekly;

  factory WorkingHoursRule.fromJson(Map<String, dynamic> json) =>
      WorkingHoursRule(
        maxDaily: (json['max_daily'] as num).toDouble(),
        maxWeekly: (json['max_weekly'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [maxDaily, maxWeekly];
}

class OvertimeRule extends Equatable {
  const OvertimeRule({
    required this.dayMultiplier,
    required this.nightMultiplier,
    required this.holidayMultiplier,
  });

  final double dayMultiplier;
  final double nightMultiplier;
  final double holidayMultiplier;

  factory OvertimeRule.fromJson(Map<String, dynamic> json) => OvertimeRule(
        dayMultiplier: (json['day_multiplier'] as num).toDouble(),
        nightMultiplier: (json['night_multiplier'] as num).toDouble(),
        holidayMultiplier: (json['holiday_multiplier'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [dayMultiplier, nightMultiplier, holidayMultiplier];
}

/// Progressive bracket: `upTo == null` means the top (unbounded) bracket.
class TaxBracket extends Equatable {
  const TaxBracket({this.upTo, required this.rate});

  final double? upTo;
  final double rate;

  factory TaxBracket.fromJson(Map<String, dynamic> json) => TaxBracket(
        upTo: (json['up_to'] as num?)?.toDouble(),
        rate: (json['rate'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [upTo, rate];
}

class SocialInsuranceRule extends Equatable {
  const SocialInsuranceRule({
    required this.employeeRate,
    required this.employerRate,
    this.salaryCap,
  });

  final double employeeRate;
  final double employerRate;
  final double? salaryCap;

  factory SocialInsuranceRule.fromJson(Map<String, dynamic> json) =>
      SocialInsuranceRule(
        employeeRate: (json['employee_rate'] as num).toDouble(),
        employerRate: (json['employer_rate'] as num).toDouble(),
        salaryCap: (json['salary_cap'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [employeeRate, employerRate, salaryCap];
}

/// End-of-service gratuity (e.g. UAE/KSA): N days of wage per year of service,
/// with a different rate after [thresholdYears]. `type == 'none'` disables it.
class EndOfServiceRule extends Equatable {
  const EndOfServiceRule({
    required this.type,
    this.daysPerYearBeforeThreshold = 0,
    this.daysPerYearAfterThreshold = 0,
    this.thresholdYears = 5,
    this.maxTotalYearsOfWage,
  });

  final String type; // 'none' | 'gratuity_days_per_year'
  final double daysPerYearBeforeThreshold;
  final double daysPerYearAfterThreshold;
  final int thresholdYears;
  final double? maxTotalYearsOfWage;

  factory EndOfServiceRule.fromJson(Map<String, dynamic> json) =>
      EndOfServiceRule(
        type: json['type'] as String,
        daysPerYearBeforeThreshold:
            (json['days_per_year_before_threshold'] as num? ?? 0).toDouble(),
        daysPerYearAfterThreshold:
            (json['days_per_year_after_threshold'] as num? ?? 0).toDouble(),
        thresholdYears: json['threshold_years'] as int? ?? 5,
        maxTotalYearsOfWage: (json['max_total_years_of_wage'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [
        type,
        daysPerYearBeforeThreshold,
        daysPerYearAfterThreshold,
        thresholdYears,
        maxTotalYearsOfWage,
      ];
}

class TerminationRule extends Equatable {
  const TerminationRule({
    required this.noticeDaysLt10y,
    required this.noticeDaysGte10y,
  });

  final int noticeDaysLt10y;
  final int noticeDaysGte10y;

  factory TerminationRule.fromJson(Map<String, dynamic> json) => TerminationRule(
        noticeDaysLt10y: json['notice_days_lt_10y'] as int,
        noticeDaysGte10y: json['notice_days_gte_10y'] as int,
      );

  @override
  List<Object?> get props => [noticeDaysLt10y, noticeDaysGte10y];
}
