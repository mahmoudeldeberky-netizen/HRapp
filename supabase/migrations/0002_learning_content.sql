-- =============================================================================
-- Learning & Media Library — admin-curated explainer videos (YouTube links)
--
-- Scoping model:
--   tenant_id IS NULL  → global platform content (Super Admin, or Country Admin
--                        for their own country via country_code)
--   tenant_id set      → a company's private library (Tenant Admin)
-- =============================================================================

create table learning_videos (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid references tenants(id) on delete cascade,
  country_code     text references countries(code),
  title_ar         text not null,
  title_en         text,
  description_ar   text,
  description_en   text,
  provider         text not null default 'youtube',
  video_url        text not null,
  video_key        text,                       -- e.g. YouTube video id, extracted server-side
  category         text,                       -- 'laws' | 'payroll' | 'onboarding' | ...
  duration_seconds integer,
  sort_order       integer not null default 0,
  is_published     boolean not null default false,
  created_by       uuid references profiles(id),
  created_at       timestamptz not null default now()
);
create index on learning_videos (country_code, is_published, sort_order);
create index on learning_videos (tenant_id, is_published, sort_order);

alter table learning_videos enable row level security;

-- Read: published global content is visible to everyone (guests included);
-- published tenant content only to that tenant's members; authors see their drafts.
create policy videos_read on learning_videos for select
  using (
    (is_published and tenant_id is null)
    or (is_published and tenant_id = auth_tenant_id())
    or auth_role() = 'super_admin'
    or (auth_role() = 'country_admin' and tenant_id is null and country_code = auth_country_scope())
    or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
  );

-- Write: Super Admin everywhere; Country Admin for global content in their
-- country; Tenant Admin for their company's own library.
create policy videos_write on learning_videos for all
  using (
    auth_role() = 'super_admin'
    or (auth_role() = 'country_admin' and tenant_id is null and country_code = auth_country_scope())
    or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
  )
  with check (
    auth_role() = 'super_admin'
    or (auth_role() = 'country_admin' and tenant_id is null and country_code = auth_country_scope())
    or (auth_role() = 'tenant_admin' and tenant_id = auth_tenant_id())
  );
