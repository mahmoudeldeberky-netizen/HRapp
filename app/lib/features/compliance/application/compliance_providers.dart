import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hr_superapp/features/compliance/application/compliance_engine.dart';
import 'package:hr_superapp/features/compliance/data/supabase_compliance_repository.dart';
import 'package:hr_superapp/features/compliance/domain/compliance_repository.dart';

final complianceRepositoryProvider = Provider<ComplianceRepository>(
  (ref) => SupabaseComplianceRepository(Supabase.instance.client),
);

/// The country whose legal framework drives the whole app.
/// Set from the tenant's country (or the user's selection for guests).
final selectedCountryProvider = StateProvider<String?>((ref) => null);

/// Engine bound to the selected country's active rule-set.
/// Every module (leave, overtime, payroll, termination) consumes this —
/// switching country transparently switches all calculations.
final complianceEngineProvider = FutureProvider<ComplianceEngine?>((ref) async {
  final country = ref.watch(selectedCountryProvider);
  if (country == null) return null;

  final ruleSet =
      await ref.watch(complianceRepositoryProvider).activeRuleSet(country);
  return ruleSet == null ? null : ComplianceEngine(ruleSet);
});
