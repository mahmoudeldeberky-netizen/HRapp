import 'package:hr_superapp/features/compliance/domain/compliance_rule_set.dart';

/// Multi-Country Compliance Engine — pure, deterministic, fully unit-testable.
///
/// The engine holds ZERO country-specific logic: every calculation is driven
/// by the [ComplianceRuleSet] published for the employee's country and
/// effective on the calculation date. Switching country = switching data.
class ComplianceEngine {
  const ComplianceEngine(this.rules);

  final ComplianceRuleSet rules;

  // ---------------------------------------------------------------------
  // Leave
  // ---------------------------------------------------------------------

  /// Annual-leave entitlement (days/year) for an employee, honoring
  /// service-years and age tiers plus the probation eligibility window.
  int annualLeaveEntitlement({
    required DateTime hireDate,
    DateTime? dateOfBirth,
    DateTime? asOf,
  }) {
    final on = asOf ?? DateTime.now();

    final monthsOfService = _monthsBetween(hireDate, on);
    if (monthsOfService < rules.annualLeave.probationMonthsBeforeEligible) {
      return 0;
    }

    final serviceYears = monthsOfService ~/ 12;
    final age = dateOfBirth == null ? null : _monthsBetween(dateOfBirth, on) ~/ 12;

    var days = rules.annualLeave.baseDays;
    for (final tier in rules.annualLeave.tiers) {
      final serviceOk =
          tier.minServiceYears == null || serviceYears >= tier.minServiceYears!;
      final ageOk = tier.minAge == null || (age != null && age >= tier.minAge!);
      // A tier applies when every threshold it declares is met.
      final declaresSomething = tier.minServiceYears != null || tier.minAge != null;
      if (declaresSomething && serviceOk && ageOk && tier.days > days) {
        days = tier.days;
      }
    }
    return days;
  }

  // ---------------------------------------------------------------------
  // Overtime
  // ---------------------------------------------------------------------

  /// Overtime pay for [hours] at the country's legal multiplier.
  /// [hourlyRate] is derived by payroll from the salary structure.
  double overtimePay({
    required double hours,
    required double hourlyRate,
    OvertimeKind kind = OvertimeKind.day,
  }) {
    final multiplier = switch (kind) {
      OvertimeKind.day => rules.overtime.dayMultiplier,
      OvertimeKind.night => rules.overtime.nightMultiplier,
      OvertimeKind.holiday => rules.overtime.holidayMultiplier,
    };
    return _round2(hours * hourlyRate * multiplier);
  }

  /// Hours beyond the legal daily maximum count as overtime.
  double dailyOvertimeHours(double workedHours) {
    final extra = workedHours - rules.workingHours.maxDaily;
    return extra > 0 ? extra : 0;
  }

  // ---------------------------------------------------------------------
  // Tax & Social Insurance
  // ---------------------------------------------------------------------

  /// Progressive income tax on [annualTaxableIncome] using the country's
  /// published brackets (marginal-rate method).
  double annualIncomeTax(double annualTaxableIncome) {
    var remaining = annualTaxableIncome;
    var previousCeiling = 0.0;
    var tax = 0.0;

    for (final bracket in rules.taxBrackets) {
      if (remaining <= 0) break;
      final ceiling = bracket.upTo;
      final slice = ceiling == null
          ? remaining
          : (ceiling - previousCeiling).clamp(0, remaining).toDouble();
      tax += slice * bracket.rate;
      remaining -= slice;
      if (ceiling != null) previousCeiling = ceiling;
    }
    return _round2(tax);
  }

  /// Employee-side social insurance for one month (respects the salary cap).
  double employeeSocialInsurance(double monthlyInsurableSalary) {
    final cap = rules.socialInsurance.salaryCap;
    final basis = cap == null
        ? monthlyInsurableSalary
        : monthlyInsurableSalary.clamp(0, cap).toDouble();
    return _round2(basis * rules.socialInsurance.employeeRate);
  }

  /// Employer-side social insurance for one month.
  double employerSocialInsurance(double monthlyInsurableSalary) {
    final cap = rules.socialInsurance.salaryCap;
    final basis = cap == null
        ? monthlyInsurableSalary
        : monthlyInsurableSalary.clamp(0, cap).toDouble();
    return _round2(basis * rules.socialInsurance.employerRate);
  }

  // ---------------------------------------------------------------------
  // End of Service & Termination
  // ---------------------------------------------------------------------

  /// End-of-service gratuity (0 where the country has none). Formula:
  /// N days of basic wage per service year, tiered around [thresholdYears],
  /// optionally capped at `maxTotalYearsOfWage` years of wage.
  double endOfServiceGratuity({
    required DateTime hireDate,
    required DateTime terminationDate,
    required double monthlyBasicWage,
  }) {
    final eos = rules.endOfService;
    if (eos.type == 'none') return 0;

    final totalYears = _monthsBetween(hireDate, terminationDate) / 12.0;
    final dailyWage = monthlyBasicWage / 30.0;

    final yearsBefore =
        totalYears.clamp(0, eos.thresholdYears.toDouble()).toDouble();
    final yearsAfter =
        (totalYears - eos.thresholdYears).clamp(0, double.infinity).toDouble();

    var gratuity = yearsBefore * eos.daysPerYearBeforeThreshold * dailyWage +
        yearsAfter * eos.daysPerYearAfterThreshold * dailyWage;

    final cap = eos.maxTotalYearsOfWage;
    if (cap != null) {
      gratuity = gratuity.clamp(0, cap * 12 * monthlyBasicWage).toDouble();
    }
    return _round2(gratuity);
  }

  /// Legal notice period (days) for termination, by seniority.
  int terminationNoticeDays({required DateTime hireDate, DateTime? asOf}) {
    final years = _monthsBetween(hireDate, asOf ?? DateTime.now()) / 12.0;
    return years >= 10
        ? rules.termination.noticeDaysGte10y
        : rules.termination.noticeDaysLt10y;
  }

  // ---------------------------------------------------------------------

  static int _monthsBetween(DateTime from, DateTime to) {
    var months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months--;
    return months < 0 ? 0 : months;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}

enum OvertimeKind { day, night, holiday }
