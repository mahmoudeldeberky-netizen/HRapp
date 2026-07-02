# 04 — Agile Development Roadmap

Two-week sprints. Each phase ends with a releasable increment behind feature flags.

## Phase 0 — Foundations (Sprints 1–2, ~4 weeks)
- Monorepo, CI/CD (GitHub Actions, Fastlane lanes, Supabase migration pipeline).
- Flutter skeleton: Clean Architecture folders, Riverpod, GoRouter, theming (dark/light),
  localization (AR/EN + RTL), design system tokens & core components.
- Supabase project: schema migration `0001`, RLS policies, seed data (countries).
- Auth end-to-end: email/OTP login, JWT custom claims, `RoleGate`, route guards, biometric app-lock.
- **Exit criteria:** sign in on Android+iOS, role-based home screens render in AR/EN, dark/light.

## Phase 1 — Compliance Engine + Core HR (Sprints 3–5, ~6 weeks)
- Law library: decree upload (PDF), bilingual articles, search, offline replica.
- Rule-set authoring UI (Country Admin), versioning, review→publish workflow, effective dating.
- `ComplianceEngine`: annual-leave entitlement, working hours/overtime params, tax brackets,
  social insurance, EOS gratuity, termination notice — full unit-test matrix for the first
  3 launch countries (e.g., EG, SA, AE).
- Employee profiles, departments/org chart, document vault, onboarding/offboarding workflows.
- **Exit criteria:** switching country changes every calculation with zero code changes.

## Phase 2 — Time & Attendance + Leave (Sprints 6–8, ~6 weeks)
- Work sites & geofenced clock-in/out, biometric confirmation, offline attendance queue + sync.
- Shift patterns, assignment, roster view.
- Leave workflows: request → compliance validation (balance from engine) → approval chain →
  balance materialization; accrual job (`pg_cron`).
- Manager dashboards (live via Realtime).
- **Exit criteria:** pilot tenant runs a full month of attendance incl. offline scenarios.

## Phase 3 — Global Payroll (Sprints 9–12, ~8 weeks)
- Salary structures (effective-dated, encrypted), allowances/deductions catalog.
- Payroll run engine (Edge Function): gross→net using the country rule-set pinned to the
  period; idempotent, resumable, dual-approval.
- Payslip PDF generation (AR/EN, RTL), employee payslip vault (biometric-gated), multi-currency.
- Audit trails + reconciliation exports (bank file / GL CSV).
- **Exit criteria:** parallel-run against a real payroll for one tenant with 100% match.

## Phase 4 — Talent Acquisition (Sprints 13–15, ~6 weeks)
- CV Builder: ATS-friendly templates (RTL-compatible), live preview, PDF export — available
  to **guests** (top-of-funnel growth loop).
- AI CV Parser: upload → extraction → confidence-flagged review → `cv_profiles`; semantic
  candidate search (pgvector).
- Job postings, public application flow, pipeline board (Kanban), interview scheduling.
- **Exit criteria:** guest builds a CV and applies; recruiter moves them through the pipeline.

## Phase 5 — Performance Management (Sprints 16–17, ~4 weeks)
- OKR trees with alignment & weighting, KPI check-ins.
- Review cycles: templates, self/manager/peer (360°), automated launch & reminders,
  calibration view.
- **Exit criteria:** one full quarterly cycle executed by pilot tenants.

## Phase 6 — Hardening & Launch (Sprints 18–19, ~4 weeks)
- Pen test + fix cycle; GDPR tooling (export/erasure); load tests (10k-employee tenant).
- Store readiness: screenshots (AR/EN), privacy manifests, review submissions.
- Super Admin analytics: platform KPIs, subscription/billing management, feature flags.
- **Launch:** 3 countries, staged rollout; then a repeatable **"new country playbook"**
  (rule-set authoring + legal review + localization) targeting 1–2 new countries/month.

## Cross-Cutting (every sprint)
Definition of Done includes: unit+widget tests, RTL & dark-mode screenshots, RLS policy
tests for new tables, accessibility pass, updated ARB translations.
