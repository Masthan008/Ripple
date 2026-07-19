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
-- To configure 2FA Email OTP delivery in Supabase Dashboard:
-- 1. Go to Authentication -> Email Templates -> Magic Link (or Confirmation / OTP).
-- 2. Set Subject:
--    🔐 Your Ripple 2FA Code: {{ .Token }} | Security Check
-- 3. Set Body (HTML):
--    Use the custom dark glassmorphism template in supabase_email_templates.md
--    Or standard body:
--    Your Ripple 2FA Code is: {{ .Token }}
--    Magic Link: {{ .ConfirmationURL }}
-- 4. Set OTP expiry to 600 seconds (10 minutes) in Authentication -> Settings.
