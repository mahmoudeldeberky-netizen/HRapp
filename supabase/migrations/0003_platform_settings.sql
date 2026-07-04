-- =============================================================================
-- Platform settings — owner-editable configuration (no developer involvement)
--
-- Key/value store for everything the platform owner customizes at runtime:
-- role display names, feature toggles, branding, defaults. The mobile/web
-- clients read these at startup and react live via Realtime.
-- =============================================================================

create table platform_settings (
  key        text primary key,
  value      jsonb not null,
  updated_by uuid references profiles(id),
  updated_at timestamptz not null default now()
);

alter table platform_settings enable row level security;

-- Everyone can read (clients need role labels, toggles, branding);
-- only the Super Admin writes.
create policy settings_read on platform_settings for select using (true);
create policy settings_write on platform_settings for all
  using (auth_role() = 'super_admin')
  with check (auth_role() = 'super_admin');

-- Owner-editable role display names (the wire values in JWTs/RLS never change,
-- only what users see). Default per the owner's naming preference:
insert into platform_settings (key, value) values (
  'role_labels',
  '{
    "super_admin":   { "ar": "المشرف العام",       "en": "Super Admin" },
    "country_admin": { "ar": "سوبر أدمن الدولة",   "en": "Country Super Admin" },
    "tenant_admin":  { "ar": "مدير الشركة (HR)",   "en": "HR Manager" },
    "employee":      { "ar": "موظف",               "en": "Employee" },
    "guest":         { "ar": "زائر / باحث عن عمل", "en": "Guest / Job Seeker" }
  }'
);
