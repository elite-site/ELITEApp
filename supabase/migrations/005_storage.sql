-- ==============================================================================
-- Migration 005: Supabase Storage Buckets & Policies
-- ELITE College Event Management System
-- ==============================================================================

-- Create buckets if they do not exist
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES 
  ('event-images', 'event-images', true, false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('event-rules', 'event-rules', true, false, 20971520, ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('project-files', 'project-files', false, false, 52428800, NULL),
  ('project-images', 'project-images', true, false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('poll-images', 'poll-images', true, false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage RLS Policies on storage.objects

-- 1. Event Images (Public Read, Admin Write)
DROP POLICY IF EXISTS "Public can view event images" ON storage.objects;
CREATE POLICY "Public can view event images"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'event-images');

DROP POLICY IF EXISTS "Admins can upload event images" ON storage.objects;
CREATE POLICY "Admins can upload event images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'event-images' AND public.get_current_user_role() = 'admin');

-- 2. Event Rules PDFs (Public Read, Admin Write)
DROP POLICY IF EXISTS "Public can view event rules" ON storage.objects;
CREATE POLICY "Public can view event rules"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'event-rules');

DROP POLICY IF EXISTS "Admins can upload event rules" ON storage.objects;
CREATE POLICY "Admins can upload event rules"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'event-rules' AND public.get_current_user_role() = 'admin');

-- 3. Project Images (Public Read, Students & Admins Write)
DROP POLICY IF EXISTS "Public can view project images" ON storage.objects;
CREATE POLICY "Public can view project images"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'project-images');

DROP POLICY IF EXISTS "Students and admins can upload project images" ON storage.objects;
CREATE POLICY "Students and admins can upload project images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'project-images');

-- 4. Poll Images (Public Read, Admin Write)
DROP POLICY IF EXISTS "Public can view poll images" ON storage.objects;
CREATE POLICY "Public can view poll images"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'poll-images');

DROP POLICY IF EXISTS "Admins can upload poll images" ON storage.objects;
CREATE POLICY "Admins can upload poll images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'poll-images' AND public.get_current_user_role() = 'admin');
