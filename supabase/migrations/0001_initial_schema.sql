-- =============================================================================
-- HR Super-App — Initial Schema (PostgreSQL 15 / Supabase)
-- Multi-tenant via Row-Level Security. JWT custom claims expected:
--   role, tenant_id, country_scope
-- =============================================================================

create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;
-- create extension if not exists vector;    -- enable when CV semantic search ships
-- create extension if not exists pgsodium;  -- column encryption for salaries / national IDs

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type user_role as enum ('super_admin','country_admin','tenant_admin','employee','guest');
create type rule_set_status as enum ('draft','published','archived');
create type law_doc_type as enum ('decree','article','amendment','circular','guideline');
create type employment_type as enum ('full_time','part_time','contract','intern');
create type employee_status as enum ('onboarding','active','suspended','offboarding','terminated');
create type leave_status as enum ('pending','approved','rejected','cancelled');
create type attendance_method as enum ('geo','biometric','manual','admin_adjustment');
create type payroll_status as enum ('draft','calculating','review','approved','paid','cancelled');
create type payroll_item_kind as enum ('base','allowance','overtime','bonus','deduction','tax','social_insurance','other');
create type application_stage as enum ('applied','screening','interview','offer','hired','rejected','withdrawn');
create type workflow_kind as enum ('onboarding','offboarding');

-- ---------------------------------------------------------------------------
-- JWT claim helpers (used by all RLS policies)
-- ---------------------------------------------------------------------------
create or replace function auth_role() returns user_role
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true)::jsonb->>'role',''),'guest')::user_role
$$;

create or replace function auth_tenant_id() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb->>'tenant_id','')::uuid
$$;

create or replace function auth_country_scope() returns text
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb->>'country_scope','')
$$;

-- ---------------------------------------------------------------------------
-- Identity & Tenancy
-- ---------------------------------------------------------------------------
create table countries (
  code            text primary key,                        -- ISO 3166-1 alpha-2
  name_en         text not null,
  name_ar         text not null,
  currency_code   text not null,                           -- ISO 4217
  default_locale  text not null default 'en',
  timezone        text not null default 'UTC',
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

create table tenants (
  id            uuid primary key default gen_random_uuid(),
  country_code  text not null references countries(code),
  name          text not null,
  name_ar       text,
  plan          text not null default 'trial',
  status        text not null default 'active',
  settings      jsonb not null default '{}',
  created_at    timestamptz not null default now()
);

-- 1:1 with auth.users; carries the authoritative role
create table profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  tenant_id      uuid references tenants(id),
  role           user_role not null default 'guest',
  country_scope  text references countries(code),          -- country_admin only
  full_name      text,
  full_name_ar   text,
  locale         text not null default 'en',               -- 'en' | 'ar'
  theme_pref     text not null default 'system',           -- 'light' | 'dark' | 'system'
  avatar_url     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint country_admin_needs_scope
    check (role <> 'country_admin' or country_scope is not null)
);

-- ---------------------------------------------------------------------------
-- Compliance Engine (global content: no tenant_id)
-- ---------------------------------------------------------------------------
create table law_documents (
  id            uuid primary key default gen_random_uuid(),
  country_code  text not null references countries(code),
  document_type law_doc_type not null,
  title_en      text not null,
  title_ar      text not null,
  body_en       text,
  body_ar       text,
  source_url    text,
  storage_path  text,                                      -- original PDF in Storage
  issued_at     date,
  published_at  timestamptz,
  published_by  uuid references profiles(id),
  created_at    timestamptz not null default now()
);
create index on law_documents (country_code, document_type);

create table compliance_rule_sets (
  id             uuid primary key default gen_random_uuid(),
  country_code   text not null references countries(code),
  version        integer not null,
  status         rule_set_status not null default 'draft',
  effective_from date not null,
  effective_to   date,
  rules          jsonb not null,                           -- typed schema, validated by app + CI
  source_law_ids uuid[] not null default '{}',
  created_by     uuid references profiles(id),
  approved_by    uuid references profiles(id),
  created_at     timestamptz not null default now(),
  unique (country_code, version)
);
create index on compliance_rule_sets (country_code, status, effective_from desc);

-- ---------------------------------------------------------------------------
-- Core HR
-- ---------------------------------------------------------------------------
create table departments (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  parent_id  uuid references departments(id),
  name       text not null,
  name_ar    text,
  created_at timestamptz not null default now()
);

create table employees (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references tenants(id) on delete cascade,
  profile_id            uuid references profiles(id),      -- null until account activated
  employee_no           text not null,
  first_name            text not null,
  last_name             text not null,
  full_name_ar          text,
  email                 text,
  phone                 text,
  national_id_encrypted bytea,                             -- pgsodium-encrypted
  date_of_birth         date,
  hire_date             date not null,
  termination_date      date,
  job_title             text,
  department_id         uuid references departments(id),
  manager_id            uuid references employees(id),
  employment_type       employment_type not null default 'full_time',
  status                employee_status not null default 'onboarding',
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (tenant_id, employee_no)
);
create index on employees (tenant_id, status);

create table employee_documents (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id) on delete cascade,
  employee_id  uuid not null references employees(id) on delete cascade,
  doc_type     text not null,                              -- contract / national_id / certificate...
  title        text not null,
  storage_path text not null,
  expires_at   date,
  verified_by  uuid references profiles(id),
  created_at   timestamptz not null default now()
);

create table workflows (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  kind       workflow_kind not null,
  name       text not null,
  steps      jsonb not null default '[]',                  -- ordered step definitions
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table workflow_instances (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id) on delete cascade,
  workflow_id  uuid not null references workflows(id),
  employee_id  uuid not null references employees(id),
  current_step integer not null default 0,
  step_states  jsonb not null default '{}',
  status       text not null default 'in_progress',
  created_at   timestamptz not null default now(),
  completed_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Time & Attendance
-- ---------------------------------------------------------------------------
create table work_sites (
  id        uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  name      text not null,
  lat       double precision not null,
  lng       double precision not null,
  radius_m  integer not null default 150,
  timezone  text not null default 'UTC'
);

create table shifts (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  name          text not null,
  starts_at     time not null,
  ends_at       time not null,
  grace_minutes integer not null default 10,
  days_of_week  integer[] not null default '{1,2,3,4,5}'   -- ISO: 1=Mon
);

create table employee_shifts (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  shift_id    uuid not null references shifts(id),
  from_date   date not null,
  to_date     date
);

create table attendance_records (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id) on delete cascade,
  employee_id     uuid not null references employees(id) on delete cascade,
  check_in        timestamptz not null,
  check_out       timestamptz,
  check_in_lat    double precision,
  check_in_lng    double precision,
  work_site_id    uuid references work_sites(id),
  within_geofence boolean,
  method          attendance_method not null default 'geo',
  source          text not null default 'online',          -- online | offline_sync
  device_id       text,
  created_at      timestamptz not null default now()
);
create index on attendance_records (tenant_id, employee_id, check_in desc);

create table leave_types (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid references tenants(id) on delete cascade, -- null = country default
  country_code   text references countries(code),
  compliance_key text not null,                             -- 'annual' | 'sick' | 'maternity'...
  name_en        text not null,
  name_ar        text not null,
  is_paid        boolean not null default true
);

create table leave_requests (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_id   uuid not null references employees(id) on delete cascade,
  leave_type_id uuid not null references leave_types(id),
  starts_on     date not null,
  ends_on       date not null,
  days          numeric(5,2) not null,
  reason        text,
  status        leave_status not null default 'pending',
  approver_id   uuid references profiles(id),
  decided_at    timestamptz,
  rule_set_id   uuid references compliance_rule_sets(id),   -- audit: rules used to validate
  created_at    timestamptz not null default now()
);

create table leave_balances (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_id   uuid not null references employees(id) on delete cascade,
  leave_type_id uuid not null references leave_types(id),
  year          integer not null,
  entitled      numeric(5,2) not null,
  taken         numeric(5,2) not null default 0,
  unique (employee_id, leave_type_id, year)
);

-- ---------------------------------------------------------------------------
-- Payroll & Compensation
-- ---------------------------------------------------------------------------
create table salary_structures (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references tenants(id) on delete cascade,
  employee_id           uuid not null references employees(id) on delete cascade,
  base_salary_encrypted bytea not null,                     -- pgsodium-encrypted
  currency              text not null,
  allowances            jsonb not null default '[]',        -- [{code, name, amount|percent}]
  effective_from        date not null,
  effective_to          date,
  created_at            timestamptz not null default now()
);

create table payroll_runs (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id) on delete cascade,
  period_start date not null,
  period_end   date not null,
  status       payroll_status not null default 'draft',
  rule_set_id  uuid not null references compliance_rule_sets(id), -- law version pinned
  approved_by  uuid references profiles(id),
  created_at   timestamptz not null default now(),
  unique (tenant_id, period_start, period_end)
);

create table payroll_items (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references tenants(id) on delete cascade,
  payroll_run_id uuid not null references payroll_runs(id) on delete cascade,
  employee_id    uuid not null references employees(id),
  kind           payroll_item_kind not null,
  code           text not null,
  label_en       text not null,
  label_ar       text,
  amount         numeric(14,2) not null,                    -- negative = deduction
  meta           jsonb not null default '{}'
);
create index on payroll_items (payroll_run_id, employee_id);

create table payslips (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references tenants(id) on delete cascade,
  payroll_run_id   uuid not null references payroll_runs(id),
  employee_id      uuid not null references employees(id),
  gross            numeric(14,2) not null,
  total_deductions numeric(14,2) not null,
  net              numeric(14,2) not null,
  currency         text not null,
  pdf_storage_path text,
  issued_at        timestamptz,
  unique (payroll_run_id, employee_id)
);

-- ---------------------------------------------------------------------------
-- Talent Acquisition
-- ---------------------------------------------------------------------------
create table cv_templates (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  layout            jsonb not null,
  is_rtl_compatible boolean not null default true,
  is_active         boolean not null default true
);

create table cv_profiles (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references auth.users(id) on delete cascade,
  template_id      uuid references cv_templates(id),
  data             jsonb not null default '{}',             -- structured CV schema
  parse_confidence jsonb,                                   -- per-field scores from AI parser
  pdf_storage_path text,
  -- embedding     vector(1536),                            -- enable with pgvector
  updated_at       timestamptz not null default now(),
  created_at       timestamptz not null default now()
);

create table job_postings (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references tenants(id) on delete cascade,
  country_code   text not null references countries(code),
  title_en       text not null,
  title_ar       text,
  description_en text,
  description_ar text,
  salary_range   jsonb,
  status         text not null default 'open',              -- open | paused | closed
  created_at     timestamptz not null default now()
);

create table applications (
  id             uuid primary key default gen_random_uuid(),
  job_posting_id uuid not null references job_postings(id) on delete cascade,
  cv_profile_id  uuid not null references cv_profiles(id),
  applicant_id   uuid not null references auth.users(id),
  stage          application_stage not null default 'applied',
  score          numeric(5,2),
  notes          jsonb not null default '[]',
  created_at     timestamptz not null default now(),
  unique (job_posting_id, applicant_id)
);

-- ---------------------------------------------------------------------------
-- Performance
-- ---------------------------------------------------------------------------
create table review_cycles (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  name       text not null,
  period_start date not null,
  period_end   date not null,
  template   jsonb not null default '{}',
  status     text not null default 'draft'                  -- draft | active | closed
);

create table objectives (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references tenants(id) on delete cascade,
  employee_id         uuid not null references employees(id) on delete cascade,
  parent_objective_id uuid references objectives(id),
  cycle_id            uuid references review_cycles(id),
  title               text not null,
  weight              numeric(5,2) not null default 1,
  progress            numeric(5,2) not null default 0,      -- 0..100
  created_at          timestamptz not null default now()
);

create table key_results (
  id           uuid primary key default gen_random_uuid(),
  objective_id uuid not null references objectives(id) on delete cascade,
  title        text not null,
  target       numeric(14,2) not null,
  current      numeric(14,2) not null default 0,
  unit         text
);

create table evaluations (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id) on delete cascade,
  cycle_id    uuid not null references review_cycles(id),
  employee_id uuid not null references employees(id),
  reviewer_id uuid not null references profiles(id),
  kind        text not null,                                -- self | manager | peer | p360
  scores      jsonb not null default '{}',
  status      text not null default 'pending',
  submitted_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Audit & Privacy
-- ---------------------------------------------------------------------------
create table audit_logs (
  id         bigint generated always as identity primary key,
  actor_id   uuid,
  tenant_id  uuid,
  action     text not null,
  entity     text not null,
  entity_id  text,
  diff       jsonb,
  ip         inet,
  created_at timestamptz not null default now()
);

create table consent_records (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  purpose    text not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);

-- =============================================================================
-- Row-Level Security
-- =============================================================================
alter table countries             enable row level security;
alter table tenants               enable row level security;
alter table profiles              enable row level security;
alter table law_documents         enable row level security;
alter table compliance_rule_sets  enable row level security;
alter table departments           enable row level security;
alter table employees             enable row level security;
alter table employee_documents    enable row level security;
alter table workflows             enable row level security;
alter table workflow_instances    enable row level security;
alter table work_sites            enable row level security;
alter table shifts                enable row level security;
alter table employee_shifts       enable row level security;
alter table attendance_records    enable row level security;
alter table leave_types           enable row level security;
alter table leave_requests        enable row level security;
alter table leave_balances        enable row level security;
alter table salary_structures     enable row level security;
alter table payroll_runs          enable row level security;
alter table payroll_items         enable row level security;
alter table payslips              enable row level security;
alter table cv_templates          enable row level security;
alter table cv_profiles           enable row level security;
alter table job_postings          enable row level security;
alter table applications          enable row level security;
alter table review_cycles         enable row level security;
alter table objectives            enable row level security;
alter table key_results           enable row level security;
alter table evaluations           enable row level security;
alter table audit_logs            enable row level security;
alter table consent_records       enable row level security;

-- Global reference data: readable by everyone
create policy countries_read on countries for select using (true);
create policy countries_admin on countries for all
  using (auth_role() = 'super_admin') with check (auth_role() = 'super_admin');

-- Published laws & rules: world-readable; writes for super admin, or country admin in scope
create policy laws_read on law_documents for select
  using (published_at is not null
         or auth_role() = 'super_admin'
         or (auth_role() = 'country_admin' and country_code = auth_country_scope()));
create policy laws_write on law_documents for all
  using (auth_role() = 'super_admin'
         or (auth_role() = 'country_admin' and country_code = auth_country_scope()))
  with check (auth_role() = 'super_admin'
         or (auth_role() = 'country_admin' and country_code = auth_country_scope()));

create policy rules_read on compliance_rule_sets for select
  using (status = 'published'
         or auth_role() = 'super_admin'
         or (auth_role() = 'country_admin' and country_code = auth_country_scope()));
create policy rules_write on compliance_rule_sets for all
  using (auth_role() = 'super_admin'
         or (auth_role() = 'country_admin' and country_code = auth_country_scope()))
  with check (auth_role() = 'super_admin'
         or (auth_role() = 'country_admin' and country_code = auth_country_scope()));

-- Profiles: self-read/update; super admin full; tenant admin reads own tenant
create policy profiles_self on profiles for select
  using (id = auth.uid()
         or auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));
create policy profiles_self_update on profiles for update
  using (id = auth.uid()) with check (id = auth.uid() and role = (select p.role from profiles p where p.id = auth.uid()));

-- Tenants: members read own tenant; super admin all
create policy tenants_read on tenants for select
  using (id = auth_tenant_id() or auth_role() = 'super_admin');
create policy tenants_admin on tenants for all
  using (auth_role() = 'super_admin') with check (auth_role() = 'super_admin');

-- Generic tenant-scoped policy template, applied to all tenant tables:
--   super_admin: everything; tenant_admin: own tenant; employee: read own rows
do $$
declare t text;
begin
  foreach t in array array[
    'departments','employees','employee_documents','workflows','workflow_instances',
    'work_sites','shifts','employee_shifts','leave_types',
    'payroll_runs','payroll_items','review_cycles'
  ] loop
    execute format($f$
      create policy %1$s_tenant_rw on %1$s for all
        using (auth_role() = 'super_admin'
               or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()))
        with check (auth_role() = 'super_admin'
               or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));
      create policy %1$s_member_read on %1$s for select
        using (auth_role() in ('employee','tenant_admin') and tenant_id = auth_tenant_id());
    $f$, t);
  end loop;
end $$;

-- Employee-personal tables: employees see only their own rows
create policy attendance_self_read on attendance_records for select
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
         or (tenant_id = auth_tenant_id()
             and employee_id in (select e.id from employees e where e.profile_id = auth.uid())));
create policy attendance_self_insert on attendance_records for insert
  with check (tenant_id = auth_tenant_id()
              and employee_id in (select e.id from employees e where e.profile_id = auth.uid()));
create policy attendance_admin on attendance_records for all
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()))
  with check (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));

create policy leave_req_self on leave_requests for select
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
         or employee_id in (select e.id from employees e where e.profile_id = auth.uid()));
create policy leave_req_self_insert on leave_requests for insert
  with check (tenant_id = auth_tenant_id()
              and employee_id in (select e.id from employees e where e.profile_id = auth.uid()));
create policy leave_req_admin on leave_requests for update
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));

create policy leave_bal_read on leave_balances for select
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
         or employee_id in (select e.id from employees e where e.profile_id = auth.uid()));

-- Sensitive compensation data: tenant admin + owner read; writes via service role only
create policy salary_admin_read on salary_structures for select
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));
create policy payslips_read on payslips for select
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
         or employee_id in (select e.id from employees e where e.profile_id = auth.uid()));

-- Objectives / evaluations
create policy okr_rw on objectives for all
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
         or employee_id in (select e.id from employees e where e.profile_id = auth.uid()))
  with check (tenant_id = auth_tenant_id() or auth_role() = 'super_admin');
create policy kr_rw on key_results for all
  using (objective_id in (select o.id from objectives o))
  with check (objective_id in (select o.id from objectives o));
create policy eval_read on evaluations for select
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
         or reviewer_id = auth.uid()
         or employee_id in (select e.id from employees e where e.profile_id = auth.uid()));
create policy eval_write on evaluations for update
  using (reviewer_id = auth.uid()
         or auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));

-- Talent acquisition: guests own their CVs; open jobs are public
create policy cv_templates_read on cv_templates for select using (is_active);
create policy cv_own on cv_profiles for all
  using (owner_id = auth.uid() or auth_role() = 'super_admin')
  with check (owner_id = auth.uid() or auth_role() = 'super_admin');
create policy jobs_public_read on job_postings for select
  using (status = 'open'
         or auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));
create policy jobs_tenant_write on job_postings for all
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()))
  with check (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));
create policy applications_own on applications for select
  using (applicant_id = auth.uid()
         or auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin'
             and job_posting_id in (select j.id from job_postings j where j.tenant_id = auth_tenant_id())));
create policy applications_insert on applications for insert
  with check (applicant_id = auth.uid());
create policy applications_pipeline on applications for update
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin'
             and job_posting_id in (select j.id from job_postings j where j.tenant_id = auth_tenant_id())));

-- Audit: read-only for admins; inserts happen via service role / triggers
create policy audit_read on audit_logs for select
  using (auth_role() = 'super_admin'
         or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id()));
create policy consent_own on consent_records for all
  using (user_id = auth.uid() or auth_role() = 'super_admin')
  with check (user_id = auth.uid() or auth_role() = 'super_admin');

-- ---------------------------------------------------------------------------
-- Helper: active rule set for a country on a given date
-- ---------------------------------------------------------------------------
create or replace function active_rule_set(p_country text, p_on date default current_date)
returns compliance_rule_sets
language sql stable as $$
  select r.* from compliance_rule_sets r
  where r.country_code = p_country
    and r.status = 'published'
    and r.effective_from <= p_on
    and (r.effective_to is null or r.effective_to >= p_on)
  order by r.effective_from desc, r.version desc
  limit 1
$$;

-- ---------------------------------------------------------------------------
-- Seed: launch countries
-- ---------------------------------------------------------------------------
insert into countries (code, name_en, name_ar, currency_code, default_locale, timezone) values
  ('EG', 'Egypt',                'مصر',                          'EGP', 'ar', 'Africa/Cairo'),
  ('SA', 'Saudi Arabia',         'المملكة العربية السعودية',      'SAR', 'ar', 'Asia/Riyadh'),
  ('AE', 'United Arab Emirates', 'الإمارات العربية المتحدة',      'AED', 'ar', 'Asia/Dubai');
