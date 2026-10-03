-- keystone_36_contractor_app — Espace prestataire (?prestataire) : identité + stockage des photos d'intervention
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

-- Qui suis-je ? Prestataire connecté (cloisonné) ou exploitant (mode aperçu autorisé)
CREATE OR REPLACE FUNCTION keystone.portal_me()
RETURNS json LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'contractor_id', keystone.current_contractor(),
    'contractor_name', (SELECT name FROM contractors WHERE id = keystone.current_contractor()),
    'is_contractor', keystone.current_contractor() IS NOT NULL,
    'tenant_id', keystone.current_tenant(),
    'full_name', (SELECT full_name FROM users WHERE id = auth.uid())
  );
$$;

-- Prestataires disponibles pour le mode aperçu (exploitant uniquement ; un prestataire ne voit que lui-même)
CREATE OR REPLACE FUNCTION keystone.portal_contractors()
RETURNS TABLE(id uuid, name text, open_wo int)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  SELECT c.id, c.name,
    (SELECT count(*) FROM work_orders w WHERE w.contractor_id = c.id AND w.deleted_at IS NULL
       AND w.status NOT IN ('done','verified','cancelled'))::int
  FROM contractors c
  WHERE c.deleted_at IS NULL
    AND (keystone.current_contractor() IS NULL OR c.id = keystone.current_contractor())
    AND EXISTS (SELECT 1 FROM work_orders w WHERE w.contractor_id = c.id)
  ORDER BY 3 DESC, c.name;
$$;

GRANT EXECUTE ON FUNCTION keystone.portal_me(), keystone.portal_contractors() TO authenticated;

-- Bucket privé des photos d'intervention : chemin = <tenant_id>/<wo_id>/<avant|apres>-<horodatage>.jpg
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('keystone-wo-photos', 'keystone-wo-photos', false, 8388608, ARRAY['image/jpeg','image/png','image/webp','image/heic'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS keystone_wo_photos_read ON storage.objects;
CREATE POLICY keystone_wo_photos_read ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'keystone-wo-photos' AND (storage.foldername(name))[1] = keystone.current_tenant()::text AND (storage.foldername(name))[2] IN (
    SELECT w.id::text FROM keystone.work_orders w
    WHERE keystone.current_contractor() IS NULL OR w.contractor_id = keystone.current_contractor()));
DROP POLICY IF EXISTS keystone_wo_photos_write ON storage.objects;
CREATE POLICY keystone_wo_photos_write ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'keystone-wo-photos' AND (storage.foldername(name))[1] = keystone.current_tenant()::text AND (storage.foldername(name))[2] IN (
    SELECT w.id::text FROM keystone.work_orders w
    WHERE keystone.current_contractor() IS NULL OR w.contractor_id = keystone.current_contractor()));

COMMIT;
