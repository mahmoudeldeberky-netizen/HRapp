# HR Super-App — Global, Multi-Country HR Platform

**تطبيق الموارد البشرية الشامل** — منصة عالمية متعددة الدول لإدارة الموارد البشرية

A production-grade, cross-platform (Android + iOS) HR Super-App serving HR professionals,
companies, and employees across countries, dynamically adapting to each country's labor
laws, official decrees, and regulations.

## Repository Layout

| Path | Description |
|---|---|
| `docs/01-architecture.md` | System architecture blueprint (Clean Architecture, multi-tenancy, diagrams) |
| `docs/02-database-schema.md` | Full database schema, ERD, and relationships |
| `docs/03-tech-stack.md` | Definitive tech stack with justifications |
| `docs/04-roadmap.md` | Agile development roadmap (phases, sprints, milestones) |
| `supabase/migrations/` | PostgreSQL schema migrations with Row-Level Security (multi-tenancy) |
| `app/` | Flutter application (Clean Architecture, Riverpod, AR/EN, RTL, dark mode) |

## Headline Decisions

- **Frontend:** Flutter 3.x — single codebase, native performance, first-class RTL/Arabic support.
- **Backend:** Supabase (PostgreSQL + Auth + Realtime + Storage + Edge Functions) — multi-tenant via Row-Level Security.
- **State Management:** Riverpod 2 (compile-safe DI + reactive state).
- **Compliance Engine:** Data-driven rules (versioned JSON rule-sets per country, effective-dated) — no redeploys needed when laws change.
- **RBAC:** 5 roles (Super Admin, Country Admin, Tenant Admin, Employee, Guest) enforced in three layers: database RLS, API, and UI route guards.
- **Offline:** Drift (SQLite) local cache for laws, profiles, payslips, and attendance queueing.

## Quick Start (App)

```bash
cd app
flutter pub get
flutter gen-l10n
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Quick Start (Database)

```bash
supabase db push   # applies supabase/migrations/*.sql
```

---

## نظرة عامة (بالعربية)

منصة موارد بشرية متكاملة تدعم أندرويد و iOS، مبنية بلغة Flutter مع خلفية Supabase.
تتكيف المنصة تلقائيًا مع قوانين العمل والمراسيم الرسمية لكل دولة عبر **محرك الامتثال الديناميكي**،
وتدعم اللغتين العربية والإنجليزية (مع دعم كامل للكتابة من اليمين لليسار) والوضعين الداكن والفاتح.

الأدوار المدعومة: المشرف العام، مشرف الدولة، مدير الشركة (HR)، الموظف، والزائر (الباحث عن عمل).
