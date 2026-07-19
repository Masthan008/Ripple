-- ── Supabase Cloud Storage Schema for Chat Backups ──
-- Run this in the Supabase SQL Editor to configure bucket permissions.

-- 1. Create the 'documents' bucket for backup archives (if not exists)
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do nothing;

-- 2. Enable public read access to download backups
create policy "Public Access to Backups"
on storage.objects for select
using ( bucket_id = 'documents' );

-- 3. Allow authenticated users to upload backup files
create policy "Authenticated User Upload Backups"
on storage.objects for insert
with check (
  bucket_id = 'documents' 
  and auth.role() = 'authenticated'
);

-- 4. Allow users to replace/upsert their backup files
create policy "User Update Backups"
on storage.objects for update
using (
  bucket_id = 'documents'
  and auth.role() = 'authenticated'
);

-- 5. Allow users to delete their own backup files
create policy "User Delete Backups"
on storage.objects for delete
using (
  bucket_id = 'documents'
  and auth.uid()::text = (storage.foldername(name))[1]
);
