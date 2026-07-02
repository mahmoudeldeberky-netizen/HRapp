# 03 — Definitive Tech Stack & Justification

## Frontend: **Flutter 3.x** (over React Native)

| Criterion | Why Flutter wins for this product |
|---|---|
| Arabic / RTL | First-class, built-in RTL mirroring (`Directionality`, `EdgeInsetsDirectional`, full Material localization for `ar`). RN needs manual `I18nManager` handling and app restarts to flip direction. |
| Rendering consistency | Impeller renders identical pixels on Android & iOS — critical for data-dense HR dashboards, payslip layouts, and PDF-like previews. |
| Performance | AOT-compiled Dart, no JS bridge; smooth 60/120fps on tables, charts, and large employee lists. |
| Single codebase → 3 targets | Same code ships the mobile apps **and** the Flutter Web admin console (Super/Country Admin). |
| Offline & device APIs | Mature plugins: `drift` (SQLite), `local_auth` (FaceID/fingerprint), `geolocator` (geofencing), `flutter_secure_storage`. |

**State management: Riverpod 2** — compile-time-safe dependency injection + reactive
caches; providers map 1:1 to Clean Architecture use-cases and are trivially overridable in
tests. **Navigation: GoRouter** with redirect guards for RBAC. **Codegen:** `freezed` +
`json_serializable` for immutable domain models.

## Backend: **Supabase** (PostgreSQL 15 + GoTrue + Realtime + Storage + Edge Functions)

| Requirement | How Supabase satisfies it |
|---|---|
| Multi-tenancy + high security | Postgres **Row-Level Security** enforces tenant isolation *in the database* — the strongest isolation model short of DB-per-tenant, with far lower ops cost. |
| Real-time updates | Built-in Realtime (logical replication → WebSockets): law updates, attendance boards, application pipelines push live. |
| Relational integrity | Payroll/attendance/compliance are deeply relational with strict audit needs — Postgres (ACID, FKs, constraints) beats Firebase's document model decisively here. |
| Custom compute | Edge Functions (Deno/TypeScript) for payroll runs, CV parsing, decree OCR, webhooks. |
| Auth + RBAC | GoTrue JWTs with custom claims (`role`, `tenant_id`, `country_code`) consumed by RLS; MFA support for admin roles. |
| Extensibility | `pgvector` (CV semantic search), `pgsodium` (column encryption), `pg_cron` (scheduled accruals), PostGIS optional for geofencing analytics. |
| Exit strategy | It's plain Postgres — self-hostable, no proprietary lock-in (unlike Firebase). |

**Why not Firebase:** weak relational modeling, no server-enforced multi-tenant row
isolation comparable to RLS, painful aggregate queries (payroll), vendor lock-in.
**Why not bare Node+Postgres:** you'd rebuild auth, realtime, storage, and RLS tooling that
Supabase ships hardened; the team's velocity is better spent on the compliance engine.
When bespoke needs outgrow Edge Functions, add a **NestJS service** beside Supabase against
the same Postgres — the architecture allows it without migration.

## AI Layer

- **Claude API** (`claude-sonnet-5` for parsing quality / `claude-haiku-4-5` for high-volume
  extraction) with structured outputs for: CV parsing → typed JSON, decree text → draft
  rule-set JSON (always human-reviewed before publish).
- `pgvector` embeddings for semantic candidate search.

## Supporting Choices

| Concern | Choice |
|---|---|
| Local cache / offline | `drift` (typed SQLite, reactive queries) + optional SQLCipher |
| Localization | Flutter `gen-l10n` ARB files (`app_en.arb`, `app_ar.arb`) |
| PDF (payslips/CVs) | `pdf` + `printing` packages, RTL-aware templates |
| Push notifications | FCM + APNs via Supabase Edge Function fan-out |
| CI/CD | GitHub Actions → Fastlane → TestFlight / Play Internal; `supabase db push` for migrations |
| Crash/analytics | Sentry + PostHog (self-host option for data residency) |
| Testing | Unit (domain/engine, pure Dart), widget tests, integration via `patrol`; SQL policy tests with `pgTAP` |
