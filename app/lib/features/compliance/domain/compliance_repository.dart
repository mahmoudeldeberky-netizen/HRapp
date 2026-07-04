import 'package:hr_superapp/features/compliance/domain/compliance_rule_set.dart';

/// Domain contract for fetching country rule-sets and law documents.
abstract interface class ComplianceRepository {
  /// Published rule-set effective on [on] for [countryCode].
  /// Implementations must serve the local cache when offline.
  Future<ComplianceRuleSet?> activeRuleSet(String countryCode, {DateTime? on});

  /// Live updates when a new version is published (Realtime channel).
  Stream<ComplianceRuleSet> watchPublishedRuleSets(String countryCode);
}
