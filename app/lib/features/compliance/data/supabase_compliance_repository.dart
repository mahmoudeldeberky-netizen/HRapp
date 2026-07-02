import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hr_superapp/features/compliance/domain/compliance_repository.dart';
import 'package:hr_superapp/features/compliance/domain/compliance_rule_set.dart';

/// Remote-first with offline fallback:
/// 1. Query Postgres for the effective published rule-set.
/// 2. On success, persist to the Drift cache.
/// 3. On network failure, serve the cached copy (read-only offline mode).
class SupabaseComplianceRepository implements ComplianceRepository {
  SupabaseComplianceRepository(this._client, {ComplianceCache? cache})
      : _cache = cache;

  final SupabaseClient _client;
  final ComplianceCache? _cache;

  @override
  Future<ComplianceRuleSet?> activeRuleSet(String countryCode, {DateTime? on}) async {
    final date = (on ?? DateTime.now()).toIso8601String().substring(0, 10);
    try {
      final row = await _client
          .from('compliance_rule_sets')
          .select('country_code, version, effective_from, effective_to, rules')
          .eq('country_code', countryCode)
          .eq('status', 'published')
          .lte('effective_from', date)
          .or('effective_to.is.null,effective_to.gte.$date')
          .order('effective_from', ascending: false)
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final ruleSet = ComplianceRuleSet.fromJson({
        ...(row['rules'] as Map<String, dynamic>),
        'country_code': row['country_code'],
        'version': row['version'],
        'effective_from': row['effective_from'],
        'effective_to': row['effective_to'],
      });
      await _cache?.save(ruleSet);
      return ruleSet;
    } catch (_) {
      // Offline / transient failure: fall back to the last cached version.
      return _cache?.load(countryCode);
    }
  }

  @override
  Stream<ComplianceRuleSet> watchPublishedRuleSets(String countryCode) {
    return _client
        .from('compliance_rule_sets')
        .stream(primaryKey: ['id'])
        .eq('country_code', countryCode)
        .map((rows) => rows.where((r) => r['status'] == 'published'))
        .where((rows) => rows.isNotEmpty)
        .map((rows) {
          final latest = rows.reduce((a, b) =>
              (a['version'] as int) >= (b['version'] as int) ? a : b);
          return ComplianceRuleSet.fromJson({
            ...(latest['rules'] as Map<String, dynamic>),
            'country_code': latest['country_code'],
            'version': latest['version'],
            'effective_from': latest['effective_from'],
            'effective_to': latest['effective_to'],
          });
        });
  }
}

/// Cache port implemented by the Drift (SQLite) layer.
abstract interface class ComplianceCache {
  Future<void> save(ComplianceRuleSet ruleSet);
  Future<ComplianceRuleSet?> load(String countryCode);
}
