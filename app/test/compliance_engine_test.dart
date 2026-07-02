import 'package:flutter_test/flutter_test.dart';

import 'package:hr_superapp/features/compliance/application/compliance_engine.dart';
import 'package:hr_superapp/features/compliance/domain/compliance_rule_set.dart';

/// The engine must be 100% data-driven: these fixtures mimic published
/// rule-sets for two different legal frameworks and assert that calculations
/// change with the data only.
void main() {
  final egyptLikeRules = ComplianceRuleSet.fromJson({
    'country_code': 'EG',
    'version': 1,
    'effective_from': '2025-01-01',
    'annual_leave': {
      'base_days': 21,
      'tiers': [
        {'min_service_years': 10, 'days': 30},
        {'min_age': 50, 'days': 30},
      ],
      'probation_months_before_eligible': 6,
    },
    'working_hours': {'max_daily': 8, 'max_weekly': 48},
    'overtime': {
      'day_multiplier': 1.35,
      'night_multiplier': 1.70,
      'holiday_multiplier': 2.0,
    },
    'income_tax_brackets': [
      {'up_to': 40000, 'rate': 0.0},
      {'up_to': 55000, 'rate': 0.10},
      {'up_to': 70000, 'rate': 0.15},
      {'up_to': null, 'rate': 0.20},
    ],
    'social_insurance': {
      'employee_rate': 0.11,
      'employer_rate': 0.1875,
      'salary_cap': 14500,
    },
    'end_of_service': {'type': 'none'},
    'termination': {'notice_days_lt_10y': 60, 'notice_days_gte_10y': 90},
  });

  final gulfLikeRules = ComplianceRuleSet.fromJson({
    'country_code': 'AE',
    'version': 1,
    'effective_from': '2025-01-01',
    'annual_leave': {'base_days': 30},
    'working_hours': {'max_daily': 8, 'max_weekly': 48},
    'overtime': {
      'day_multiplier': 1.25,
      'night_multiplier': 1.50,
      'holiday_multiplier': 1.50,
    },
    'income_tax_brackets': [
      {'up_to': null, 'rate': 0.0},
    ],
    'social_insurance': {'employee_rate': 0.05, 'employer_rate': 0.125},
    'end_of_service': {
      'type': 'gratuity_days_per_year',
      'days_per_year_before_threshold': 21,
      'days_per_year_after_threshold': 30,
      'threshold_years': 5,
      'max_total_years_of_wage': 2,
    },
    'termination': {'notice_days_lt_10y': 30, 'notice_days_gte_10y': 30},
  });

  group('annual leave entitlement', () {
    final engine = ComplianceEngine(egyptLikeRules);

    test('zero during probation window', () {
      expect(
        engine.annualLeaveEntitlement(
          hireDate: DateTime(2025, 1, 1),
          asOf: DateTime(2025, 4, 1),
        ),
        0,
      );
    });

    test('base days after probation', () {
      expect(
        engine.annualLeaveEntitlement(
          hireDate: DateTime(2024, 1, 1),
          asOf: DateTime(2025, 6, 1),
        ),
        21,
      );
    });

    test('tier upgrade at 10 service years', () {
      expect(
        engine.annualLeaveEntitlement(
          hireDate: DateTime(2010, 1, 1),
          asOf: DateTime(2025, 6, 1),
        ),
        30,
      );
    });

    test('tier upgrade at age 50', () {
      expect(
        engine.annualLeaveEntitlement(
          hireDate: DateTime(2024, 1, 1),
          dateOfBirth: DateTime(1970, 1, 1),
          asOf: DateTime(2025, 6, 1),
        ),
        30,
      );
    });
  });

  group('overtime', () {
    test('uses country multiplier from data', () {
      expect(
        ComplianceEngine(egyptLikeRules)
            .overtimePay(hours: 10, hourlyRate: 100),
        1350.0,
      );
      expect(
        ComplianceEngine(gulfLikeRules).overtimePay(hours: 10, hourlyRate: 100),
        1250.0,
      );
    });

    test('daily overtime threshold', () {
      expect(ComplianceEngine(egyptLikeRules).dailyOvertimeHours(10), 2);
      expect(ComplianceEngine(egyptLikeRules).dailyOvertimeHours(7), 0);
    });
  });

  group('progressive income tax', () {
    final engine = ComplianceEngine(egyptLikeRules);

    test('below first bracket is tax-free', () {
      expect(engine.annualIncomeTax(30000), 0);
    });

    test('marginal rates across brackets', () {
      // 40k @0 + 15k @10% + 15k @15% + 30k @20% = 0 + 1500 + 2250 + 6000
      expect(engine.annualIncomeTax(100000), 9750.0);
    });

    test('tax-free country has zero tax', () {
      expect(ComplianceEngine(gulfLikeRules).annualIncomeTax(500000), 0);
    });
  });

  group('social insurance', () {
    final engine = ComplianceEngine(egyptLikeRules);

    test('respects salary cap', () {
      expect(engine.employeeSocialInsurance(20000), 14500 * 0.11);
      expect(engine.employerSocialInsurance(10000), 1875.0);
    });
  });

  group('end of service gratuity', () {
    test('zero where the law defines none', () {
      expect(
        ComplianceEngine(egyptLikeRules).endOfServiceGratuity(
          hireDate: DateTime(2015, 1, 1),
          terminationDate: DateTime(2025, 1, 1),
          monthlyBasicWage: 10000,
        ),
        0,
      );
    });

    test('tiered gratuity: 21 days/yr for 5 yrs then 30 days/yr', () {
      final gratuity = ComplianceEngine(gulfLikeRules).endOfServiceGratuity(
        hireDate: DateTime(2018, 1, 1),
        terminationDate: DateTime(2025, 1, 1), // 7 years
        monthlyBasicWage: 9000, // daily wage = 300
      );
      // 5y * 21d * 300 + 2y * 30d * 300 = 31500 + 18000
      expect(gratuity, 49500.0);
    });
  });

  group('termination notice', () {
    final engine = ComplianceEngine(egyptLikeRules);

    test('by seniority threshold', () {
      expect(
        engine.terminationNoticeDays(
            hireDate: DateTime(2020, 1, 1), asOf: DateTime(2025, 1, 1)),
        60,
      );
      expect(
        engine.terminationNoticeDays(
            hireDate: DateTime(2010, 1, 1), asOf: DateTime(2025, 1, 1)),
        90,
      );
    });
  });
}
