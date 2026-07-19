-- ── Supabase Cloud Storage Schema for Chat Backups & Custom Sounds ──
-- Run this in the Supabase SQL Editor to configure bucket permissions.

-- ═══════════════════════════════════════════════════════
-- 1. BUCKETS CREATION
-- ═══════════════════════════════════════════════════════

-- Create 'documents' bucket for backups
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do nothing;

-- Create 'nexatalk' bucket (configured in .env)
insert into storage.buckets (id, name, public)
values ('nexatalk', 'nexatalk', true)
on conflict (id) do nothing;

-- ═══════════════════════════════════════════════════════
-- 2. PUBLIC & ANONYMOUS POLICIES (Required since Ripple uses Firebase Auth)
-- ═══════════════════════════════════════════════════════

-- A. Policies for 'nexatalk' bucket
create policy "Public Select for Nexatalk"
on storage.objects for select
using ( bucket_id = 'nexatalk' );

create policy "Public Insert for Nexatalk Custom Sounds"
on storage.objects for insert
with check (
  bucket_id = 'nexatalk'
  and (storage.foldername(name))[1] = 'notification_sounds'
);

create policy "Public Update for Nexatalk Custom Sounds"
on storage.objects for update
using (
  bucket_id = 'nexatalk'
  and (storage.foldername(name))[1] = 'notification_sounds'
);

-- B. Policies for 'documents' bucket
create policy "Public Select for Documents"
on storage.objects for select
using ( bucket_id = 'documents' );

create policy "Public Insert for Documents Custom Sounds"
on storage.objects for insert
with check (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = 'notification_sounds'
);

create policy "Public Update for Documents Custom Sounds"
on storage.objects for update
using (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = 'notification_sounds'
);

-- ═══════════════════════════════════════════════════════
-- 3. SUPABASE AUTH & EMAIL OTP CONFIGURATION FOR 2FA
-- ═══════════════════════════════════════════════════════
-- To enable 2FA Email OTP delivery in Supabase Dashboard:
-- 1. Go to Authentication -> Providers -> Email.
-- 2. Ensure "Enable Email Provider" is turned ON.
-- 3. Enable "Confirm email" or "Enable Email OTP".
-- 4. Under Email Templates -> Magic Link / OTP:
--    Subject: Your Ripple 2FA Verification Code
--    Body: Your 6-digit security code is {{ .Token }}
-- 5. (Optional) Configure custom SMTP in Project Settings -> Auth -> Email Settings for custom domain delivery.
