-- Atlas Keystone · migrations 38 (baux & portail locataire), 39 (notifications), 40 (exécution terrain) + seeds démo
-- À coller en une fois dans le SQL Editor (projet vgtmljfayiysuvrcmunt) · transactions successives, dans l'ordre

-- ==================== 20261004_keystone_38_leases_tenant_portal.sql ====================
-- keystone_38_leases_tenant_portal — Baux, loyers, charges & portail locataire
-- Gestion locative d'un centre commercial (droit OHADA, AUDCG — bail à usage professionnel) :
--   · locataires (« lessees », distincts du multi-tenant), baux multi-lots, historique des loyers
--   · échéancier mensuel loyer + provision de charges + TVA ; encaissements (Mobile Money simulé, virement, chèque…)
--   · indexation annuelle à taux fixe, ou révision sur indice (IPC / indice de référence) ; triennale possible
--   · impayés avec balance âgée 0-30 / 31-60 / 61-90 / > 90 j, relances tracées
--   · régularisation annuelle des charges récupérables au prorata des surfaces PONDÉRÉES (coefficient par bail)
--   · état locatif : GLA, occupation physique & financière, WALT, taux de recouvrement, loyer moyen au m²
--   · portail locataire : demandes (sur le circuit tickets existant), bail, échéancier & quittances, actualités, contacts
-- Sécurité : un utilisateur rattaché à un locataire (users.lessee_id) ne voit que ses données (policies restrictives
--   + garde dans chaque RPC). Un exploitant (lessee_id NULL) peut prévisualiser le portail de n'importe quel locataire.
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

-- ===================== Données =====================
CREATE TABLE IF NOT EXISTS keystone.lessees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  company_name text NOT NULL,
  trade_name text,
  rccm text, tax_id text,
  sector text,
  contact_name text, contact_phone text, contact_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','former','prospect')),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE keystone.users ADD COLUMN IF NOT EXISTS lessee_id uuid REFERENCES keystone.lessees(id);
ALTER TABLE keystone.service_requests ADD COLUMN IF NOT EXISTS lessee_id uuid REFERENCES keystone.lessees(id);

CREATE TABLE IF NOT EXISTS keystone.leases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  lessee_id uuid NOT NULL REFERENCES keystone.lessees(id),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  lease_type text NOT NULL DEFAULT 'commercial' CHECK (lease_type IN ('commercial','precaire','concession','bureau')),
  start_date date NOT NULL,
  end_date date,
  notice_months int NOT NULL DEFAULT 6,
  monthly_rent numeric NOT NULL CHECK (monthly_rent >= 0),
  charges_provision numeric NOT NULL DEFAULT 0,
  charges_weight numeric NOT NULL DEFAULT 1 CHECK (charges_weight > 0),   -- pondération de la quote-part de charges
  vat_rate numeric NOT NULL DEFAULT 18,
  deposit_amount numeric NOT NULL DEFAULT 0,
  payment_day int NOT NULL DEFAULT 5 CHECK (payment_day BETWEEN 1 AND 28),
  indexation_type text NOT NULL DEFAULT 'fixed' CHECK (indexation_type IN ('none','fixed','index')),
  indexation_rate numeric,                 -- % annuel (type fixed)
  indexation_period_months int NOT NULL DEFAULT 12,   -- 12 = annuelle, 36 = révision triennale
  index_base numeric,                      -- valeur d'indice à la dernière révision (type index)
  next_indexation_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','notice','terminated','expired')),
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  special_conditions text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, ref)
);
CREATE TABLE IF NOT EXISTS keystone.lease_spaces (
  lease_id uuid NOT NULL REFERENCES keystone.leases(id) ON DELETE CASCADE,
  space_unit_id uuid NOT NULL REFERENCES keystone.space_units(id),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  PRIMARY KEY (lease_id, space_unit_id)
);
CREATE TABLE IF NOT EXISTS keystone.lease_rent_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  lease_id uuid NOT NULL REFERENCES keystone.leases(id) ON DELETE CASCADE,
  effective_date date NOT NULL,
  old_rent numeric NOT NULL, new_rent numeric NOT NULL,
  reason text NOT NULL,                    -- indexation | revision | avenant
  index_value numeric,
  applied_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.rent_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  lease_id uuid NOT NULL REFERENCES keystone.leases(id) ON DELETE CASCADE,
  lessee_id uuid NOT NULL REFERENCES keystone.lessees(id),
  period_start date NOT NULL, period_end date NOT NULL, due_date date NOT NULL,
  rent_amount numeric NOT NULL, charges_amount numeric NOT NULL DEFAULT 0, vat_amount numeric NOT NULL DEFAULT 0,
  total_due numeric GENERATED ALWAYS AS (rent_amount + charges_amount + vat_amount) STORED,
  paid_amount numeric NOT NULL DEFAULT 0,
  reminders_sent int NOT NULL DEFAULT 0,
  last_reminder_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lease_id, period_start)
);
CREATE TABLE IF NOT EXISTS keystone.rent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  schedule_id uuid NOT NULL REFERENCES keystone.rent_schedules(id) ON DELETE CASCADE,
  lessee_id uuid NOT NULL REFERENCES keystone.lessees(id),
  amount numeric NOT NULL CHECK (amount > 0),
  method text NOT NULL CHECK (method IN ('mobile_money','transfer','cheque','cash','card')),
  provider_ref text,
  paid_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid DEFAULT auth.uid()
);
CREATE TABLE IF NOT EXISTS keystone.charge_pools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  year int NOT NULL,
  category text NOT NULL,                  -- nettoyage, sécurité, énergie parties communes, maintenance, assurance…
  amount numeric NOT NULL,                 -- dépense réelle récupérable de l'exercice
  UNIQUE (tenant_id, site_id, year, category)
);
CREATE TABLE IF NOT EXISTS keystone.center_news (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  kind text NOT NULL DEFAULT 'info' CHECK (kind IN ('info','event','maintenance','safety')),
  title text NOT NULL, body text,
  event_date date,
  published_at timestamptz NOT NULL DEFAULT now(),
  author_id uuid DEFAULT auth.uid()
);
CREATE TABLE IF NOT EXISTS keystone.site_contacts (
  site_id uuid PRIMARY KEY REFERENCES keystone.sites(id),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  emergency_phone text, management_email text, management_phone text, reception text
);

-- Identité locataire de l'utilisateur connecté (NULL = exploitant)
CREATE OR REPLACE FUNCTION keystone.current_lessee() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'keystone','public','extensions' AS $$
  SELECT lessee_id FROM keystone.users WHERE id = auth.uid() AND tenant_id = keystone.current_tenant()
$$;
GRANT EXECUTE ON FUNCTION keystone.current_lessee() TO authenticated;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['lessees','leases','lease_spaces','lease_rent_history','rent_schedules','rent_payments','charge_pools','center_news','site_contacts'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
-- Cloisonnement locataire (restrictive ⇒ s'ajoute à l'isolation tenant)
DROP POLICY IF EXISTS lessee_scope ON keystone.lessees;
CREATE POLICY lessee_scope ON keystone.lessees AS RESTRICTIVE USING (keystone.current_lessee() IS NULL OR id = keystone.current_lessee());
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['leases','rent_schedules','rent_payments'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS lessee_scope ON keystone.%I', t);
    EXECUTE format('CREATE POLICY lessee_scope ON keystone.%I AS RESTRICTIVE USING (keystone.current_lessee() IS NULL OR lessee_id = keystone.current_lessee())', t);
  END LOOP;
END $$;
DROP POLICY IF EXISTS lessee_scope ON keystone.lease_rent_history;
CREATE POLICY lessee_scope ON keystone.lease_rent_history AS RESTRICTIVE
  USING (keystone.current_lessee() IS NULL OR lease_id IN (SELECT id FROM keystone.leases WHERE lessee_id = keystone.current_lessee()));
DROP POLICY IF EXISTS lessee_scope ON keystone.lease_spaces;
CREATE POLICY lessee_scope ON keystone.lease_spaces AS RESTRICTIVE
  USING (keystone.current_lessee() IS NULL OR lease_id IN (SELECT id FROM keystone.leases WHERE lessee_id = keystone.current_lessee()));
-- Un locataire LIT ses données mais n'écrit JAMAIS directement les tables locatives / financières
-- (loyer, échéances, encaissements…) : seules les RPC exploitant le font.
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['lessees','leases','lease_spaces','lease_rent_history','rent_schedules','rent_payments','charge_pools','center_news','site_contacts'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS lessee_no_insert ON keystone.%I', t);
    EXECUTE format('CREATE POLICY lessee_no_insert ON keystone.%I AS RESTRICTIVE FOR INSERT WITH CHECK (keystone.current_lessee() IS NULL)', t);
    EXECUTE format('DROP POLICY IF EXISTS lessee_no_update ON keystone.%I', t);
    EXECUTE format('CREATE POLICY lessee_no_update ON keystone.%I AS RESTRICTIVE FOR UPDATE USING (keystone.current_lessee() IS NULL)', t);
  END LOOP;
END $$;
DROP POLICY IF EXISTS lessee_scope ON keystone.charge_pools;
CREATE POLICY lessee_scope ON keystone.charge_pools AS RESTRICTIVE USING (keystone.current_lessee() IS NULL);
DROP POLICY IF EXISTS lessee_scope ON keystone.service_requests;
CREATE POLICY lessee_scope ON keystone.service_requests AS RESTRICTIVE USING (keystone.current_lessee() IS NULL OR lessee_id = keystone.current_lessee());
GRANT INSERT, UPDATE ON keystone.center_news, keystone.lessees, keystone.leases, keystone.lease_spaces, keystone.site_contacts TO authenticated;

-- Garde : un locataire n'agit que sur lui-même ; un exploitant peut agir pour n'importe quel locataire du tenant
CREATE OR REPLACE FUNCTION keystone.lessee_guard(p_lessee uuid) RETURNS uuid
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE v uuid := coalesce(keystone.current_lessee(), p_lessee);
BEGIN
  IF v IS NULL THEN RAISE EXCEPTION 'LESSEE_REQUIRED'; END IF;
  IF keystone.current_lessee() IS NOT NULL AND p_lessee IS NOT NULL AND p_lessee <> keystone.current_lessee() THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF NOT EXISTS (SELECT 1 FROM lessees WHERE id = v) THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  RETURN v;
END $$;

-- ===================== Calculs =====================
CREATE OR REPLACE FUNCTION keystone.schedule_status(s keystone.rent_schedules) RETURNS text LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN s.paid_amount >= s.total_due THEN 'paid'
              WHEN s.due_date < current_date AND s.paid_amount > 0 THEN 'partial_overdue'
              WHEN s.due_date < current_date THEN 'overdue'
              WHEN s.paid_amount > 0 THEN 'partial'
              ELSE 'pending' END;
$$;

CREATE OR REPLACE FUNCTION keystone.lease_area(p_lease uuid) RETURNS numeric LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce(sum(su.surface_m2), 0) FROM lease_spaces ls JOIN space_units su ON su.id = ls.space_unit_id WHERE ls.lease_id = p_lease;
$$;

-- Génère les échéances mensuelles manquantes jusqu'à aujourd'hui + p_ahead mois (sans dépasser la fin de bail)
CREATE OR REPLACE FUNCTION keystone.lease_generate_schedule(p_lease uuid, p_ahead int DEFAULT 2)
RETURNS int LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE l leases; m date; n int := 0; v_end date;
BEGIN
  SELECT * INTO l FROM leases WHERE id = p_lease;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  v_end := LEAST(coalesce(l.end_date, 'infinity'::date), (date_trunc('month', current_date) + make_interval(months => p_ahead))::date);
  m := date_trunc('month', l.start_date)::date;
  WHILE m <= v_end LOOP
    INSERT INTO rent_schedules(tenant_id, lease_id, lessee_id, period_start, period_end, due_date, rent_amount, charges_amount, vat_amount)
    VALUES (l.tenant_id, l.id, l.lessee_id, m, (m + interval '1 month - 1 day')::date, make_date(extract(year FROM m)::int, extract(month FROM m)::int, l.payment_day),
            l.monthly_rent, l.charges_provision, round((l.monthly_rent + l.charges_provision) * l.vat_rate / 100))
    ON CONFLICT (lease_id, period_start) DO NOTHING;
    IF FOUND THEN n := n + 1; END IF;
    m := (m + interval '1 month')::date;
  END LOOP;
  RETURN n;
END $$;

CREATE OR REPLACE FUNCTION keystone.rent_generate_all(p_ahead int DEFAULT 2) RETURNS json
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE l record; n int := 0;
BEGIN
  FOR l IN SELECT id FROM leases WHERE status IN ('active','notice') LOOP n := n + lease_generate_schedule(l.id, p_ahead); END LOOP;
  RETURN json_build_object('created', n);
END $$;

-- État locatif (rent roll)
CREATE OR REPLACE FUNCTION keystone.rent_roll()
RETURNS TABLE(lease_id uuid, ref text, lessee_id uuid, lessee text, trade_name text, sector text, site text, spaces text, area_m2 numeric,
  monthly_rent numeric, rent_m2_month numeric, charges_provision numeric, start_date date, end_date date, months_left int,
  status text, next_indexation_date date, indexation_due boolean, arrears numeric, arrears_days int, open_tickets int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT l.id, l.ref, le.id, le.company_name, le.trade_name, le.sector, s.name,
    (SELECT string_agg(su.code, ', ' ORDER BY su.code) FROM lease_spaces ls JOIN space_units su ON su.id = ls.space_unit_id WHERE ls.lease_id = l.id),
    keystone.lease_area(l.id), l.monthly_rent,
    round(l.monthly_rent / NULLIF(keystone.lease_area(l.id), 0)), l.charges_provision, l.start_date, l.end_date,
    CASE WHEN l.end_date IS NULL THEN NULL ELSE ((extract(year FROM age(l.end_date, current_date)) * 12) + extract(month FROM age(l.end_date, current_date)))::int END,
    l.status, l.next_indexation_date, l.indexation_type <> 'none' AND l.next_indexation_date <= current_date,
    (SELECT coalesce(sum(rs.total_due - rs.paid_amount), 0) FROM rent_schedules rs WHERE rs.lease_id = l.id AND rs.due_date < current_date AND rs.paid_amount < rs.total_due),
    (SELECT (current_date - min(rs.due_date))::int FROM rent_schedules rs WHERE rs.lease_id = l.id AND rs.due_date < current_date AND rs.paid_amount < rs.total_due),
    (SELECT count(*) FROM service_requests sr WHERE sr.lessee_id = le.id AND sr.status NOT IN ('resolved','closed','rejected'))::int
  FROM leases l JOIN lessees le ON le.id = l.lessee_id JOIN sites s ON s.id = l.site_id
  WHERE l.status IN ('active','notice')
  ORDER BY l.monthly_rent DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.rent_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH gla AS (SELECT coalesce(sum(surface_m2), 0) AS m2 FROM space_units WHERE type = 'tenant_lot' AND deleted_at IS NULL),
       leased AS (SELECT coalesce(sum(su.surface_m2), 0) AS m2 FROM lease_spaces ls JOIN space_units su ON su.id = ls.space_unit_id
                  JOIN leases l ON l.id = ls.lease_id WHERE l.status IN ('active','notice')),
       act AS (SELECT * FROM leases WHERE status IN ('active','notice')),
       due12 AS (SELECT * FROM rent_schedules WHERE due_date < current_date AND due_date >= current_date - interval '12 months')
  SELECT json_build_object(
    'leases', (SELECT count(*) FROM act),
    'gla_m2', (SELECT m2 FROM gla),
    'leased_m2', (SELECT m2 FROM leased),
    'occupancy_pct', (SELECT round(100 * leased.m2 / NULLIF(gla.m2, 0), 1) FROM gla, leased),
    'monthly_rent', (SELECT coalesce(sum(monthly_rent), 0) FROM act),
    'annual_rent', (SELECT coalesce(sum(monthly_rent), 0) * 12 FROM act),
    'avg_rent_m2', (SELECT round(sum(monthly_rent) / NULLIF((SELECT m2 FROM leased), 0)) FROM act),
    'walt_years', (SELECT round(sum(monthly_rent * GREATEST(0, (end_date - current_date)) / 365.25) / NULLIF(sum(monthly_rent) FILTER (WHERE end_date IS NOT NULL), 0), 2)
                   FROM act WHERE end_date IS NOT NULL),
    'collection_pct', (SELECT round(100 * sum(LEAST(paid_amount, total_due)) / NULLIF(sum(total_due), 0), 1) FROM due12),
    'arrears_total', (SELECT coalesce(sum(total_due - paid_amount), 0) FROM rent_schedules WHERE due_date < current_date AND paid_amount < total_due),
    'arrears_lessees', (SELECT count(DISTINCT lessee_id) FROM rent_schedules WHERE due_date < current_date AND paid_amount < total_due),
    'expiring_12m', (SELECT count(*) FROM act WHERE end_date < current_date + interval '12 months'),
    'indexation_due', (SELECT count(*) FROM act WHERE indexation_type <> 'none' AND next_indexation_date <= current_date),
    'deposits', (SELECT coalesce(sum(deposit_amount), 0) FROM act)
  );
$$;

-- Impayés : balance âgée
CREATE OR REPLACE FUNCTION keystone.arrears_board()
RETURNS TABLE(schedule_id uuid, lease_ref text, lessee text, period date, due_date date, total_due numeric, paid numeric, balance numeric,
  days_late int, bucket text, reminders_sent int, last_reminder_at timestamptz, contact_phone text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT rs.id, l.ref, le.company_name, rs.period_start, rs.due_date, rs.total_due, rs.paid_amount, rs.total_due - rs.paid_amount,
    (current_date - rs.due_date)::int,
    CASE WHEN current_date - rs.due_date <= 30 THEN '0-30' WHEN current_date - rs.due_date <= 60 THEN '31-60'
         WHEN current_date - rs.due_date <= 90 THEN '61-90' ELSE '90+' END,
    rs.reminders_sent, rs.last_reminder_at, le.contact_phone
  FROM rent_schedules rs JOIN leases l ON l.id = rs.lease_id JOIN lessees le ON le.id = rs.lessee_id
  WHERE rs.due_date < current_date AND rs.paid_amount < rs.total_due
  ORDER BY rs.due_date;
$$;

-- Échéancier (fenêtre glissante) pour le back-office et le portail
CREATE OR REPLACE FUNCTION keystone.rent_schedule_board(p_lessee uuid DEFAULT NULL, p_months int DEFAULT 3)
RETURNS TABLE(schedule_id uuid, lease_ref text, lessee_id uuid, lessee text, period date, due_date date, rent numeric, charges numeric, vat numeric,
  total_due numeric, paid numeric, status text, last_payment_at timestamptz, last_method text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT rs.id, l.ref, le.id, le.company_name, rs.period_start, rs.due_date, rs.rent_amount, rs.charges_amount, rs.vat_amount, rs.total_due, rs.paid_amount,
    keystone.schedule_status(rs),
    (SELECT max(p.paid_at) FROM rent_payments p WHERE p.schedule_id = rs.id),
    (SELECT p.method FROM rent_payments p WHERE p.schedule_id = rs.id ORDER BY p.paid_at DESC LIMIT 1)
  FROM rent_schedules rs JOIN leases l ON l.id = rs.lease_id JOIN lessees le ON le.id = rs.lessee_id
  WHERE (p_lessee IS NULL OR rs.lessee_id = p_lessee)
    AND rs.period_start >= (date_trunc('month', current_date) - make_interval(months => p_months))::date
    AND rs.period_start <= (date_trunc('month', current_date) + interval '1 month')::date
  ORDER BY rs.period_start DESC, le.company_name;
$$;

-- Encaissement (Mobile Money simulé : référence fournisseur générée)
CREATE OR REPLACE FUNCTION keystone.rent_record_payment(p_schedule uuid, p_amount numeric, p_method text)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE s rent_schedules; v_ref text;
BEGIN
  IF keystone.current_lessee() IS NOT NULL THEN
    RAISE EXCEPTION 'FORBIDDEN' USING DETAIL = 'L''encaissement est enregistré par l''exploitant.';
  END IF;
  SELECT * INTO s FROM rent_schedules WHERE id = p_schedule FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'INVALID_AMOUNT'; END IF;
  IF p_amount > s.total_due - s.paid_amount THEN
    RAISE EXCEPTION 'OVERPAYMENT' USING DETAIL = format('Reste dû : %s FCFA', s.total_due - s.paid_amount);
  END IF;
  v_ref := CASE p_method WHEN 'mobile_money' THEN 'CP-' || upper(substr(md5(gen_random_uuid()::text), 1, 10)) ELSE NULL END;
  INSERT INTO rent_payments(tenant_id, schedule_id, lessee_id, amount, method, provider_ref)
  VALUES (s.tenant_id, s.id, s.lessee_id, p_amount, p_method, v_ref);
  UPDATE rent_schedules SET paid_amount = paid_amount + p_amount WHERE id = s.id;
  RETURN json_build_object('provider_ref', v_ref, 'balance', s.total_due - s.paid_amount - p_amount);
END $$;

CREATE OR REPLACE FUNCTION keystone.rent_send_reminder(p_schedule uuid)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE s rent_schedules;
BEGIN
  IF keystone.current_lessee() IS NOT NULL THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT * INTO s FROM rent_schedules WHERE id = p_schedule FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF s.paid_amount >= s.total_due THEN RAISE EXCEPTION 'ALREADY_PAID'; END IF;
  IF s.last_reminder_at > now() - interval '72 hours' THEN
    RAISE EXCEPTION 'REMINDER_TOO_SOON' USING DETAIL = 'Une relance a déjà été envoyée il y a moins de 72 h.';
  END IF;
  UPDATE rent_schedules SET reminders_sent = reminders_sent + 1, last_reminder_at = now() WHERE id = s.id;
  RETURN json_build_object('reminders_sent', s.reminders_sent + 1);
END $$;

-- Indexation / révision
CREATE OR REPLACE FUNCTION keystone.lease_apply_indexation(p_lease uuid, p_index_value numeric DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE l leases; v_new numeric;
BEGIN
  IF keystone.current_lessee() IS NOT NULL THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT * INTO l FROM leases WHERE id = p_lease FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF l.indexation_type = 'none' THEN RAISE EXCEPTION 'NO_INDEXATION'; END IF;
  IF l.next_indexation_date > current_date THEN RAISE EXCEPTION 'NOT_DUE' USING DETAIL = 'Prochaine révision le ' || to_char(l.next_indexation_date, 'DD/MM/YYYY'); END IF;
  IF l.indexation_type = 'fixed' THEN
    v_new := round(l.monthly_rent * (1 + coalesce(l.indexation_rate, 0) / 100));
  ELSE
    IF p_index_value IS NULL OR l.index_base IS NULL OR l.index_base <= 0 THEN RAISE EXCEPTION 'INDEX_REQUIRED'; END IF;
    v_new := round(l.monthly_rent * p_index_value / l.index_base);
  END IF;
  INSERT INTO lease_rent_history(tenant_id, lease_id, effective_date, old_rent, new_rent, reason, index_value)
  VALUES (l.tenant_id, l.id, l.next_indexation_date, l.monthly_rent, v_new, CASE WHEN l.indexation_period_months >= 36 THEN 'revision' ELSE 'indexation' END, p_index_value);
  UPDATE leases SET monthly_rent = v_new,
    index_base = CASE WHEN l.indexation_type = 'index' THEN p_index_value ELSE index_base END,
    next_indexation_date = (l.next_indexation_date + make_interval(months => l.indexation_period_months))::date
  WHERE id = l.id;
  -- les échéances futures non encore payées suivent le nouveau loyer
  UPDATE rent_schedules SET rent_amount = v_new, vat_amount = round((v_new + charges_amount) * l.vat_rate / 100)
  WHERE lease_id = l.id AND period_start >= l.next_indexation_date AND paid_amount = 0;
  RETURN json_build_object('old_rent', l.monthly_rent, 'new_rent', v_new, 'variation_pct', round(100 * (v_new - l.monthly_rent) / NULLIF(l.monthly_rent, 0), 2));
END $$;

-- Régularisation des charges de l'exercice : quote-part réelle (surface × pondération) − provisions appelées
CREATE OR REPLACE FUNCTION keystone.charges_regularization(p_year int)
RETURNS TABLE(lease_id uuid, lease_ref text, lessee text, site text, weighted_m2 numeric, share_pct numeric, real_charges numeric,
  provisions_billed numeric, balance numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH act AS (
    SELECT l.*, keystone.lease_area(l.id) * l.charges_weight AS wm2
    FROM leases l
    WHERE l.start_date <= make_date(p_year, 12, 31) AND (l.end_date IS NULL OR l.end_date >= make_date(p_year, 1, 1))
  ), tot AS (SELECT site_id, sum(wm2) AS wm2 FROM act GROUP BY site_id),
     pools AS (SELECT site_id, sum(amount) AS amount FROM charge_pools WHERE year = p_year GROUP BY site_id)
  SELECT a.id, a.ref, le.company_name, s.name, round(a.wm2, 1), round(100 * a.wm2 / NULLIF(t.wm2, 0), 2),
    round(coalesce(p.amount, 0) * a.wm2 / NULLIF(t.wm2, 0)),
    (SELECT coalesce(sum(rs.charges_amount), 0) FROM rent_schedules rs WHERE rs.lease_id = a.id AND extract(year FROM rs.period_start) = p_year),
    round(coalesce(p.amount, 0) * a.wm2 / NULLIF(t.wm2, 0))
      - (SELECT coalesce(sum(rs.charges_amount), 0) FROM rent_schedules rs WHERE rs.lease_id = a.id AND extract(year FROM rs.period_start) = p_year)
  FROM act a JOIN lessees le ON le.id = a.lessee_id JOIN sites s ON s.id = a.site_id
  JOIN tot t ON t.site_id = a.site_id LEFT JOIN pools p ON p.site_id = a.site_id
  ORDER BY 9 DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.charge_pools_board(p_year int)
RETURNS TABLE(site text, category text, amount numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT s.name, cp.category, cp.amount FROM charge_pools cp JOIN sites s ON s.id = cp.site_id WHERE cp.year = p_year ORDER BY s.name, cp.amount DESC;
$$;

-- Quittance (uniquement si l'échéance est soldée)
CREATE OR REPLACE FUNCTION keystone.rent_receipt(p_schedule uuid)
RETURNS json LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE s rent_schedules; l leases; le lessees; si sites;
BEGIN
  SELECT * INTO s FROM rent_schedules WHERE id = p_schedule;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  PERFORM keystone.lessee_guard(s.lessee_id);
  IF s.paid_amount < s.total_due THEN RAISE EXCEPTION 'NOT_PAID' USING DETAIL = 'Quittance disponible une fois l''échéance soldée.'; END IF;
  SELECT * INTO l FROM leases WHERE id = s.lease_id;
  SELECT * INTO le FROM lessees WHERE id = s.lessee_id;
  SELECT * INTO si FROM sites WHERE id = l.site_id;
  RETURN json_build_object(
    'number', 'Q-' || l.ref || '-' || to_char(s.period_start, 'YYYYMM'),
    'site', si.name, 'lessee', le.company_name, 'trade_name', le.trade_name, 'rccm', le.rccm,
    'lease_ref', l.ref, 'spaces', (SELECT string_agg(su.code || ' (' || su.surface_m2 || ' m²)', ', ') FROM lease_spaces ls JOIN space_units su ON su.id = ls.space_unit_id WHERE ls.lease_id = l.id),
    'period_start', s.period_start, 'period_end', s.period_end,
    'rent', s.rent_amount, 'charges', s.charges_amount, 'vat', s.vat_amount, 'vat_rate', l.vat_rate, 'total', s.total_due,
    'payments', (SELECT json_agg(json_build_object('amount', p.amount, 'method', p.method, 'ref', p.provider_ref, 'at', p.paid_at) ORDER BY p.paid_at) FROM rent_payments p WHERE p.schedule_id = s.id),
    'issued_at', now());
END $$;

-- ===================== Portail locataire =====================
CREATE OR REPLACE FUNCTION keystone.portal_lessees()
RETURNS TABLE(id uuid, name text, trade_name text, open_tickets int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT le.id, le.company_name, le.trade_name,
    (SELECT count(*) FROM service_requests sr WHERE sr.lessee_id = le.id AND sr.status NOT IN ('resolved','closed','rejected'))::int
  FROM lessees le
  WHERE le.status = 'active' AND (keystone.current_lessee() IS NULL OR le.id = keystone.current_lessee())
  ORDER BY le.company_name;
$$;

CREATE OR REPLACE FUNCTION keystone.lessee_home(p_lessee uuid DEFAULT NULL)
RETURNS json LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE v uuid; v_site uuid;
BEGIN
  v := keystone.lessee_guard(p_lessee);
  SELECT site_id INTO v_site FROM leases WHERE lessee_id = v AND status IN ('active','notice') ORDER BY start_date DESC LIMIT 1;
  RETURN json_build_object(
    'is_lessee', keystone.current_lessee() IS NOT NULL,
    'lessee', (SELECT json_build_object('id', id, 'name', company_name, 'trade_name', trade_name, 'contact', contact_name) FROM lessees WHERE id = v),
    'site', (SELECT name FROM sites WHERE id = v_site),
    'leases', (SELECT json_agg(json_build_object('id', l.id, 'ref', l.ref, 'start', l.start_date, 'end', l.end_date, 'rent', l.monthly_rent,
                 'charges', l.charges_provision, 'vat_rate', l.vat_rate, 'payment_day', l.payment_day, 'deposit', l.deposit_amount,
                 'next_indexation', l.next_indexation_date, 'indexation_type', l.indexation_type, 'indexation_rate', l.indexation_rate,
                 'spaces', (SELECT json_agg(json_build_object('code', su.code, 'name', su.name, 'm2', su.surface_m2)) FROM lease_spaces ls JOIN space_units su ON su.id = ls.space_unit_id WHERE ls.lease_id = l.id)))
               FROM leases l WHERE l.lessee_id = v AND l.status IN ('active','notice')),
    'balance', (SELECT coalesce(sum(total_due - paid_amount), 0) FROM rent_schedules WHERE lessee_id = v AND due_date < current_date AND paid_amount < total_due),
    'next_due', (SELECT json_build_object('id', id, 'due_date', due_date, 'amount', total_due - paid_amount)
                 FROM rent_schedules WHERE lessee_id = v AND paid_amount < total_due ORDER BY due_date LIMIT 1),
    'schedules', (SELECT json_agg(x ORDER BY x.period DESC) FROM (
                   SELECT rs.id, rs.period_start AS period, rs.due_date, rs.total_due, rs.paid_amount, keystone.schedule_status(rs) AS status
                   FROM rent_schedules rs WHERE rs.lessee_id = v AND rs.period_start <= current_date + interval '1 month'
                   ORDER BY rs.period_start DESC LIMIT 12) x),
    'tickets', (SELECT json_agg(t ORDER BY t.created_at DESC) FROM (
                 SELECT sr.id, sr.ref, sr.category, sr.description, sr.status, sr.priority, sr.created_at, sr.resolved_at, sr.satisfaction, sr.sla_due,
                   (SELECT json_build_object('body', m.body, 'at', m.at) FROM ticket_messages m WHERE m.ticket_id = sr.id AND NOT coalesce(m.is_internal, false) ORDER BY m.at DESC LIMIT 1) AS last_message,
                   (SELECT count(*) FROM ticket_messages m WHERE m.ticket_id = sr.id AND NOT coalesce(m.is_internal, false))::int AS messages
                 FROM service_requests sr WHERE sr.lessee_id = v AND sr.deleted_at IS NULL
                 ORDER BY sr.created_at DESC LIMIT 30) t),
    'news', (SELECT json_agg(n ORDER BY n.published_at DESC) FROM (
              SELECT id, kind, title, body, event_date, published_at FROM center_news WHERE site_id = v_site ORDER BY published_at DESC LIMIT 8) n),
    'contacts', (SELECT row_to_json(c) FROM (SELECT emergency_phone, management_email, management_phone, reception FROM site_contacts WHERE site_id = v_site) c)
  );
END $$;

-- Nouvelle demande depuis le portail : même circuit que les tickets (SLA, conversion OT, temps réel)
CREATE OR REPLACE FUNCTION keystone.lessee_create_ticket(p_lessee uuid, p_category text, p_description text, p_space_code text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE v uuid; le lessees; v_prio int; v_ref text; v_id uuid; v_loc uuid;
BEGIN
  v := keystone.lessee_guard(p_lessee);
  IF coalesce(length(trim(p_description)), 0) < 5 THEN RAISE EXCEPTION 'DESCRIPTION_REQUIRED'; END IF;
  SELECT * INTO le FROM lessees WHERE id = v;
  v_prio := CASE p_category WHEN 'securite' THEN 1 WHEN 'electricite' THEN 2 WHEN 'climatisation' THEN 2 WHEN 'plomberie' THEN 2 ELSE 3 END;
  SELECT su.location_id INTO v_loc FROM space_units su WHERE su.code = p_space_code LIMIT 1;
  v_ref := keystone.next_ref('TK');
  INSERT INTO service_requests(tenant_id, ref, channel, requester_kind, requester_name, requester_contact, requester_user_id, lessee_id,
                               location_id, category, description, priority, status, sla_due)
  VALUES (le.tenant_id, v_ref, 'tenant_portal', 'lessee', coalesce(le.trade_name, le.company_name), le.contact_phone, auth.uid(), v,
          v_loc, p_category, trim(p_description) || CASE WHEN p_space_code IS NOT NULL THEN ' [local ' || p_space_code || ']' ELSE '' END,
          v_prio, 'new', now() + keystone.ticket_sla(v_prio))
  RETURNING id INTO v_id;
  RETURN json_build_object('id', v_id, 'ref', v_ref, 'priority', v_prio);
END $$;

CREATE OR REPLACE FUNCTION keystone.lessee_ticket_comment(p_ticket uuid, p_body text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE t service_requests;
BEGIN
  SELECT * INTO t FROM service_requests WHERE id = p_ticket;
  IF NOT FOUND OR t.lessee_id IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  PERFORM keystone.lessee_guard(t.lessee_id);
  IF coalesce(length(trim(p_body)), 0) = 0 THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;
  INSERT INTO ticket_messages(tenant_id, ticket_id, author_id, body, is_internal) VALUES (t.tenant_id, t.id, auth.uid(), trim(p_body), false);
  UPDATE service_requests SET updated_at = now() WHERE id = t.id;
END $$;

CREATE OR REPLACE FUNCTION keystone.lessee_rate_ticket(p_ticket uuid, p_score int)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE t service_requests;
BEGIN
  SELECT * INTO t FROM service_requests WHERE id = p_ticket;
  IF NOT FOUND OR t.lessee_id IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  PERFORM keystone.lessee_guard(t.lessee_id);
  IF t.status NOT IN ('resolved','closed') THEN RAISE EXCEPTION 'NOT_RESOLVED'; END IF;
  IF p_score NOT BETWEEN 1 AND 5 THEN RAISE EXCEPTION 'INVALID_SCORE'; END IF;
  UPDATE service_requests SET satisfaction = p_score, updated_at = now() WHERE id = t.id;
END $$;

CREATE OR REPLACE FUNCTION keystone.news_board()
RETURNS TABLE(id uuid, site text, kind text, title text, body text, event_date date, published_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT n.id, s.name, n.kind, n.title, n.body, n.event_date, n.published_at FROM center_news n JOIN sites s ON s.id = n.site_id ORDER BY n.published_at DESC LIMIT 40;
$$;

GRANT EXECUTE ON FUNCTION keystone.lessee_guard(uuid), keystone.schedule_status(keystone.rent_schedules), keystone.lease_area(uuid),
  keystone.lease_generate_schedule(uuid, int), keystone.rent_generate_all(int), keystone.rent_roll(), keystone.rent_summary(), keystone.arrears_board(),
  keystone.rent_schedule_board(uuid, int), keystone.rent_record_payment(uuid, numeric, text), keystone.rent_send_reminder(uuid),
  keystone.lease_apply_indexation(uuid, numeric), keystone.charges_regularization(int), keystone.charge_pools_board(int), keystone.rent_receipt(uuid),
  keystone.portal_lessees(), keystone.lessee_home(uuid), keystone.lessee_create_ticket(uuid, text, text, text),
  keystone.lessee_ticket_comment(uuid, text), keystone.lessee_rate_ticket(uuid, int), keystone.news_board() TO authenticated;
GRANT INSERT, UPDATE ON keystone.rent_schedules, keystone.rent_payments, keystone.lease_rent_history TO authenticated;
GRANT INSERT ON keystone.ticket_messages TO authenticated;
GRANT UPDATE (satisfaction, updated_at) ON keystone.service_requests TO authenticated;
GRANT INSERT ON keystone.service_requests TO authenticated;

COMMIT;

-- ==================== 20261004_keystone_38b_leases_seed.sql ====================
-- Seed démo gestion locative — Cosmos Yopougon (enseignes FICTIVES). Idempotent.
BEGIN;
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  yop uuid; r record; le uuid; l uuid; su uuid; n int; tk uuid; mode_id uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.leases WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO yop FROM keystone.sites WHERE tenant_id = t AND name ILIKE '%Yopougon%';

  -- Lots locatifs individualisés (pris sur la surface agrégée de la galerie pour garder la surface totale constante)
  INSERT INTO keystone.space_units(tenant_id, code, name, type, surface_m2, status, occupant_kind, is_verified)
  SELECT t, v.code, v.name, 'tenant_lot', v.m2, 'occupied', 'tenant_locataire', true FROM (VALUES
    ('A-RDC-001', 'Lot A-RDC-001 — mail principal', 420),
    ('A-RDC-014', 'Lot A-RDC-014', 95),
    ('A-RDC-022', 'Lot A-RDC-022', 180),
    ('A-RDC-030', 'Lot A-RDC-030 — angle parvis', 150),
    ('A-R1-005', 'Lot A-R1-005 — food court', 260),
    ('A-R1-020', 'Lot A-R1-020 — pôle loisirs', 1200)
  ) v(code, name, m2)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.space_units WHERE tenant_id = t AND code = v.code);
  UPDATE keystone.space_units SET surface_m2 = 14500 - 2305 WHERE tenant_id = t AND code = 'AGG-GAL' AND surface_m2 = 14500;

  FOR r IN SELECT * FROM (VALUES
    -- société, enseigne, secteur, lot, loyer/mois, provision/mois, poids charges, début, fin, indexation, taux, période, prochaine, base indice, statut
    ('Mode Ivoire SARL', 'Mode Ivoire', 'Prêt-à-porter', 'A-RDC-001', 7560000, 1176000, 1.0, '2022-01-01', '2030-12-31', 'fixed', 3.0, 12, '2027-01-01', NULL::numeric, 'active'),
    ('Hyper Cosmos SA', 'Hyper Cosmos', 'Alimentaire', 'AGG-HYP', 39900000, 11400000, 0.5, '2019-03-01', '2034-02-28', 'index', NULL, 36, '2026-03-01', 100.0, 'active'),
    ('TélécomPlus CI', 'TélécomPlus', 'Téléphonie', 'A-RDC-014', 2375000, 285000, 1.0, '2024-06-01', '2027-05-31', 'fixed', 4.0, 12, '2026-06-01', NULL, 'active'),
    ('Pharmacie du Cosmos', 'Pharmacie du Cosmos', 'Santé', 'A-RDC-022', 2880000, 504000, 1.0, '2021-09-01', '2030-08-31', 'fixed', 3.0, 12, '2026-09-01', NULL, 'active'),
    ('Poulet Doré SARL', 'Poulet Doré', 'Restauration', 'A-R1-005', 3640000, 728000, 1.2, '2023-02-01', '2029-01-31', 'fixed', 3.5, 12, '2027-02-01', NULL, 'active'),
    ('Banque Lagune SA', 'Banque Lagune', 'Banque', 'A-RDC-030', 3300000, 420000, 1.0, '2020-01-01', '2026-12-31', 'fixed', 2.5, 12, '2027-01-01', NULL, 'notice'),
    ('Pas à Pas Chaussures', 'Pas à Pas', 'Chaussures', 'LOT-B12', 5100000, 952000, 1.0, '2022-07-01', '2031-06-30', 'fixed', 3.0, 12, '2027-07-01', NULL, 'active'),
    ('Ciné Lagune SAS', 'Ciné Lagune', 'Loisirs', 'A-R1-020', 7200000, 1800000, 0.7, '2025-04-01', '2037-03-31', 'fixed', 2.0, 12, '2027-04-01', NULL, 'active')
  ) v(co, trade, sector, lot, rent, prov, w, sd, ed, ix, rate, per, nxt, base, st)
  LOOP
    INSERT INTO keystone.lessees(tenant_id, company_name, trade_name, sector, rccm, contact_name, contact_phone, contact_email)
    VALUES (t, r.co, r.trade, r.sector, 'CI-ABJ-' || (2015 + length(r.co) % 9) || '-B-' || lpad((length(r.co) * 1373 % 99999)::text, 5, '0'),
            'Responsable ' || r.trade, '+225 07 00 00 ' || lpad((length(r.co) * 7 % 100)::text, 2, '0') || ' 00',
            lower(regexp_replace(r.trade, '[^A-Za-z]', '', 'g')) || '@exemple.ci')
    RETURNING id INTO le;
    IF r.trade = 'Mode Ivoire' THEN mode_id := le; END IF;
    INSERT INTO keystone.leases(tenant_id, ref, lessee_id, site_id, start_date, end_date, monthly_rent, charges_provision, charges_weight,
                                deposit_amount, indexation_type, indexation_rate, indexation_period_months, next_indexation_date, index_base, status)
    VALUES (t, 'BL-YOP-' || to_char(r.sd::date, 'YY') || '-' || lpad((SELECT count(*) + 1 FROM keystone.leases WHERE tenant_id = t)::text, 3, '0'),
            le, yop, r.sd::date, r.ed::date, r.rent, r.prov, r.w, r.rent * 3, r.ix, r.rate, r.per, r.nxt::date, r.base, r.st)
    RETURNING id INTO l;
    SELECT id INTO su FROM keystone.space_units WHERE tenant_id = t AND code = r.lot;
    INSERT INTO keystone.lease_spaces(lease_id, space_unit_id, tenant_id) VALUES (l, su, t);
    PERFORM keystone.lease_generate_schedule(l, 1);
  END LOOP;

  -- Historique : tout le passé est soldé, sauf les cas d'impayés de la démo
  UPDATE keystone.rent_schedules SET paid_amount = total_due WHERE tenant_id = t AND due_date < current_date;
  -- Poulet Doré : 3 derniers mois impayés (balance âgée 0-30 / 31-60 / 61-90)
  UPDATE keystone.rent_schedules rs SET paid_amount = 0, reminders_sent = CASE WHEN rs.due_date < current_date - 45 THEN 2 ELSE 1 END,
         last_reminder_at = now() - interval '6 days'
  FROM keystone.leases l JOIN keystone.lessees le ON le.id = l.lessee_id
  WHERE rs.lease_id = l.id AND le.trade_name = 'Poulet Doré' AND rs.due_date < current_date AND rs.due_date >= current_date - 92;
  -- Pas à Pas : dernier mois réglé à 50 %
  UPDATE keystone.rent_schedules rs SET paid_amount = round(rs.total_due / 2)
  FROM keystone.leases l JOIN keystone.lessees le ON le.id = l.lessee_id
  WHERE rs.lease_id = l.id AND le.trade_name = 'Pas à Pas' AND rs.due_date < current_date AND rs.due_date >= current_date - 31;
  -- Banque Lagune (préavis donné) : dernier mois impayé
  UPDATE keystone.rent_schedules rs SET paid_amount = 0
  FROM keystone.leases l JOIN keystone.lessees le ON le.id = l.lessee_id
  WHERE rs.lease_id = l.id AND le.trade_name = 'Banque Lagune' AND rs.due_date < current_date AND rs.due_date >= current_date - 31;

  -- Traces d'encaissement des 12 derniers mois (méthodes variées)
  INSERT INTO keystone.rent_payments(tenant_id, schedule_id, lessee_id, amount, method, provider_ref, paid_at)
  SELECT t, rs.id, rs.lessee_id, rs.paid_amount,
    (ARRAY['transfer','mobile_money','transfer','cheque'])[1 + abs(hashtext(rs.id::text)) % 4],
    CASE WHEN abs(hashtext(rs.id::text)) % 4 = 1 THEN 'CP-' || upper(substr(md5(rs.id::text), 1, 10)) END,
    rs.due_date + (abs(hashtext(rs.id::text)) % 9)
  FROM keystone.rent_schedules rs
  WHERE rs.tenant_id = t AND rs.paid_amount > 0 AND rs.due_date >= current_date - 365 AND rs.due_date < current_date;

  -- Charges récupérables réelles de l'exercice précédent
  INSERT INTO keystone.charge_pools(tenant_id, site_id, year, category, amount) VALUES
    (t, yop, extract(year FROM current_date)::int - 1, 'Nettoyage parties communes', 64000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Sécurité & gardiennage', 52000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Énergie parties communes', 71000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Maintenance technique', 26000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Assurance multirisque', 9000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Espaces verts & déchets', 6000000)
  ON CONFLICT DO NOTHING;

  INSERT INTO keystone.site_contacts(site_id, tenant_id, emergency_phone, management_email, management_phone, reception)
  VALUES (yop, t, '+225 27 23 00 00 00 (24 h/24)', 'gestion@cosmos-yopougon.demo', '+225 27 23 00 00 01', 'Accueil — RDC, hall principal, 8 h-21 h')
  ON CONFLICT (site_id) DO NOTHING;

  INSERT INTO keystone.center_news(tenant_id, site_id, kind, title, body, event_date, published_at) VALUES
    (t, yop, 'safety', 'Exercice d''évacuation incendie', 'Exercice obligatoire de 10 h à 11 h. Merci de faire évacuer vos clients et de rejoindre le point de rassemblement parking Nord.', current_date + 6, now() - interval '1 day'),
    (t, yop, 'maintenance', 'Maintenance ascenseur A3', 'Service réduit côté galerie Est de 6 h à 9 h. Utilisez l''ascenseur B ou les escaliers mécaniques.', current_date + 3, now() - interval '2 days'),
    (t, yop, 'event', 'Nuit du shopping', 'Ouverture prolongée jusqu''à 23 h, animations sur l''atrium. Inscription des enseignes participantes auprès de la gestion.', current_date + 15, now() - interval '4 days'),
    (t, yop, 'info', 'Nouveau parcours de livraison', 'Les livraisons se font désormais par le quai Sud entre 6 h et 10 h. Badge d''accès à retirer à l''accueil.', NULL, now() - interval '9 days');

  -- Demandes d'un locataire (circuit tickets existant)
  IF mode_id IS NOT NULL THEN
    INSERT INTO keystone.service_requests(tenant_id, ref, channel, requester_kind, requester_name, lessee_id, category, description, priority, status, sla_due, resolved_at, satisfaction, created_at)
    VALUES (t, keystone.next_ref('TK'), 'tenant_portal', 'lessee', 'Mode Ivoire', mode_id, 'climatisation', 'Climatisation insuffisante dans la cabine d''essayage [local A-RDC-001]', 2, 'resolved', now() - interval '9 days', now() - interval '10 days', 5, now() - interval '11 days')
    RETURNING id INTO tk;
    INSERT INTO keystone.service_requests(tenant_id, ref, channel, requester_kind, requester_name, lessee_id, category, description, priority, status, sla_due, created_at)
    VALUES (t, keystone.next_ref('TK'), 'tenant_portal', 'lessee', 'Mode Ivoire', mode_id, 'plomberie', 'Fuite sous l''évier de la réserve [local A-RDC-001]', 2, 'in_progress', now() + interval '3 hours', now() - interval '5 hours')
    RETURNING id INTO tk;
    INSERT INTO keystone.ticket_messages(tenant_id, ticket_id, body, is_internal, at)
    VALUES (t, tk, 'Technicien sur place, remplacement du joint en cours. Résolution estimée : 1 h.', false, now() - interval '40 minutes');
    INSERT INTO keystone.service_requests(tenant_id, ref, channel, requester_kind, requester_name, lessee_id, category, description, priority, status, sla_due, created_at)
    VALUES (t, keystone.next_ref('TK'), 'tenant_portal', 'lessee', 'Mode Ivoire', mode_id, 'eclairage', 'Deux spots de vitrine hors service [local A-RDC-001]', 3, 'new', now() + interval '2 days', now() - interval '20 minutes');
  END IF;
END $$;
COMMIT;

-- ==================== 20261004_keystone_39_notifications.sql ====================
-- keystone_39_notifications — Notifications multicanal (WhatsApp · SMS · email · in-app)
-- Prérequis : migration 38 (baux & portail locataire).
-- Chaîne : événement métier (trigger) → règles (événement × canal × audience) → modèle FR/EN rendu → boîte d'envoi (outbox)
--          → envoi : mode SIMULATION (dispatch en base, journalisé) ou LIVE (Edge Function notify-dispatch, secrets hors base).
-- Garde-fous :
--   · plages de non-dérangement pour SMS/WhatsApp (envoi différé), sauf gravité « critical » qui passe toujours
--   · anti-doublon : même événement × entité × canal × destinataire ignoré pendant 10 min
--   · aucun secret en base (clés API dans les secrets Supabase de l'Edge Function) ; outbox invisible aux locataires/prestataires
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

ALTER TABLE keystone.contractors ADD COLUMN IF NOT EXISTS contact_phone text, ADD COLUMN IF NOT EXISTS contact_email text;

CREATE TABLE IF NOT EXISTS keystone.notification_channels (
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  channel text NOT NULL CHECK (channel IN ('whatsapp','sms','email','in_app')),
  is_enabled boolean NOT NULL DEFAULT true,
  mode text NOT NULL DEFAULT 'simulation' CHECK (mode IN ('simulation','live')),
  provider text,                 -- whatsapp_cloud | orange_sms | twilio | resend | smtp | internal
  sender text,                   -- n° expéditeur / adresse d'envoi (non secret)
  PRIMARY KEY (tenant_id, channel)
);
CREATE TABLE IF NOT EXISTS keystone.notification_quiet_hours (
  tenant_id uuid PRIMARY KEY DEFAULT keystone.current_tenant(),
  start_local time NOT NULL DEFAULT '21:00',
  end_local time NOT NULL DEFAULT '07:00',
  timezone text NOT NULL DEFAULT 'Africa/Abidjan',
  applies_to text[] NOT NULL DEFAULT ARRAY['sms','whatsapp']
);
CREATE TABLE IF NOT EXISTS keystone.notification_events (
  event_type text PRIMARY KEY,
  label text NOT NULL,
  domain text NOT NULL,
  default_severity text NOT NULL DEFAULT 'info' CHECK (default_severity IN ('info','warning','high','critical')),
  placeholders text[] NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS keystone.notification_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  event_type text NOT NULL REFERENCES keystone.notification_events(event_type),
  channel text NOT NULL CHECK (channel IN ('whatsapp','sms','email','in_app')),
  audience text NOT NULL CHECK (audience IN ('lessee','contractor','staff','requester')),
  is_enabled boolean NOT NULL DEFAULT true,
  UNIQUE (tenant_id, event_type, channel, audience)
);
CREATE TABLE IF NOT EXISTS keystone.notification_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  event_type text NOT NULL REFERENCES keystone.notification_events(event_type),
  channel text NOT NULL CHECK (channel IN ('whatsapp','sms','email','in_app')),
  locale text NOT NULL DEFAULT 'fr' CHECK (locale IN ('fr','en')),
  subject text,
  body text NOT NULL,
  wa_template_name text,         -- modèle WhatsApp pré-approuvé (messages hors fenêtre de 24 h)
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, event_type, channel, locale)
);
CREATE TABLE IF NOT EXISTS keystone.notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  event_type text NOT NULL,
  severity text NOT NULL DEFAULT 'info',
  entity_ref text,
  entity_id uuid,
  channel text NOT NULL,
  audience text NOT NULL,
  recipient_label text,
  address text,                  -- téléphone E.164 / email / user_id (in_app)
  user_id uuid,
  subject text,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','deferred','sent','failed','suppressed')),
  status_reason text,
  scheduled_for timestamptz NOT NULL DEFAULT now(),
  attempts int NOT NULL DEFAULT 0,
  provider_ref text,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notification_outbox_due ON keystone.notification_outbox (status, scheduled_for);
CREATE INDEX IF NOT EXISTS notification_outbox_dedup ON keystone.notification_outbox (tenant_id, event_type, entity_id, channel, address, created_at);

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['notification_channels','notification_quiet_hours','notification_rules','notification_templates','notification_outbox'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    -- configuration et journal réservés à l'exploitant
    EXECUTE format('DROP POLICY IF EXISTS staff_only ON keystone.%I', t);
    EXECUTE format('CREATE POLICY staff_only ON keystone.%I AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL)', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT SELECT ON keystone.notification_events TO authenticated;
GRANT UPDATE (is_enabled, mode, provider, sender) ON keystone.notification_channels TO authenticated;
GRANT UPDATE (is_enabled) ON keystone.notification_rules TO authenticated;
GRANT UPDATE (subject, body, wa_template_name, updated_at) ON keystone.notification_templates TO authenticated;
GRANT UPDATE (start_local, end_local, applies_to) ON keystone.notification_quiet_hours TO authenticated;
ALTER TABLE keystone.notification_outbox REPLICA IDENTITY FULL;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE keystone.notification_outbox; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ===================== Moteur =====================
CREATE OR REPLACE FUNCTION keystone.render_template(p_text text, p_payload jsonb) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE k text; v text; out text := p_text;
BEGIN
  IF out IS NULL THEN RETURN NULL; END IF;
  FOR k, v IN SELECT key, value FROM jsonb_each_text(coalesce(p_payload, '{}')) LOOP
    out := replace(out, '{{' || k || '}}', coalesce(v, ''));
  END LOOP;
  RETURN regexp_replace(out, '\{\{[a-z_]+\}\}', '', 'g');   -- placeholders non fournis : retirés
END $$;

-- Prochain instant hors plage de non-dérangement (NULL si l'instant courant est déjà autorisé)
CREATE OR REPLACE FUNCTION keystone.quiet_until(p_tenant uuid, p_channel text, p_at timestamptz) RETURNS timestamptz
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE q notification_quiet_hours; loc timestamp; t time;
BEGIN
  SELECT * INTO q FROM notification_quiet_hours WHERE tenant_id = p_tenant;
  IF NOT FOUND OR NOT (p_channel = ANY (q.applies_to)) THEN RETURN NULL; END IF;
  loc := p_at AT TIME ZONE q.timezone;
  t := loc::time;
  IF q.start_local > q.end_local THEN               -- plage à cheval sur minuit (ex. 21:00 → 07:00)
    IF t >= q.start_local THEN RETURN ((loc::date + 1) + q.end_local) AT TIME ZONE q.timezone; END IF;
    IF t < q.end_local THEN RETURN (loc::date + q.end_local) AT TIME ZONE q.timezone; END IF;
  ELSIF t >= q.start_local AND t < q.end_local THEN
    RETURN (loc::date + q.end_local) AT TIME ZONE q.timezone;
  END IF;
  RETURN NULL;
END $$;

-- Destinataires d'une audience : (libellé, téléphone, email, user_id)
CREATE OR REPLACE FUNCTION keystone.notification_recipients(p_tenant uuid, p_audience text, p_payload jsonb)
RETURNS TABLE(label text, phone text, email text, user_id uuid)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce(le.trade_name, le.company_name), le.contact_phone, le.contact_email,
         (SELECT u.id FROM users u WHERE u.lessee_id = le.id LIMIT 1)
  FROM lessees le WHERE p_audience = 'lessee' AND le.id = (p_payload->>'lessee_id')::uuid AND le.tenant_id = p_tenant
  UNION ALL
  SELECT c.name, c.contact_phone, c.contact_email, (SELECT u.id FROM users u WHERE u.contractor_id = c.id LIMIT 1)
  FROM contractors c WHERE p_audience = 'contractor' AND c.id = (p_payload->>'contractor_id')::uuid AND c.tenant_id = p_tenant
  UNION ALL
  SELECT coalesce(u.full_name, trim(coalesce(pe.first_name, '') || ' ' || coalesce(pe.last_name, '')), u.email), pe.phone, coalesce(u.email, pe.email), u.id
  FROM users u LEFT JOIN persons pe ON pe.id = u.person_id
  WHERE p_audience = 'staff' AND u.tenant_id = p_tenant AND coalesce(u.is_active, true) AND u.lessee_id IS NULL AND u.contractor_id IS NULL
  UNION ALL
  SELECT coalesce(p_payload->>'requester_name', 'Demandeur'),
         CASE WHEN p_payload->>'requester_contact' ~ '^\+?[0-9 ]{8,}$' THEN p_payload->>'requester_contact' END,
         CASE WHEN p_payload->>'requester_contact' LIKE '%@%' THEN p_payload->>'requester_contact' END, NULL::uuid
  WHERE p_audience = 'requester' AND p_payload->>'requester_contact' IS NOT NULL;
$$;

-- Point d'entrée unique : publie un événement → lignes d'outbox
CREATE OR REPLACE FUNCTION keystone.notify_event(p_tenant uuid, p_event text, p_payload jsonb, p_severity text DEFAULT NULL)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE r record; rc record; ch notification_channels; tpl notification_templates; v_addr text; v_status text; v_reason text;
        v_when timestamptz; v_q timestamptz; n int := 0; v_sev text; v_eid uuid := nullif(p_payload->>'entity_id', '')::uuid;
BEGIN
  SELECT coalesce(p_severity, default_severity) INTO v_sev FROM notification_events WHERE event_type = p_event;
  IF v_sev IS NULL THEN RETURN 0; END IF;
  FOR r IN SELECT * FROM notification_rules WHERE tenant_id = p_tenant AND event_type = p_event AND is_enabled LOOP
    SELECT * INTO ch FROM notification_channels WHERE tenant_id = p_tenant AND channel = r.channel;
    CONTINUE WHEN NOT FOUND OR NOT ch.is_enabled;
    SELECT * INTO tpl FROM notification_templates WHERE tenant_id = p_tenant AND event_type = p_event AND channel = r.channel
      ORDER BY (locale = coalesce(p_payload->>'locale', 'fr')) DESC LIMIT 1;
    CONTINUE WHEN NOT FOUND;
    FOR rc IN SELECT * FROM keystone.notification_recipients(p_tenant, r.audience, p_payload) LOOP
      v_addr := CASE r.channel WHEN 'email' THEN rc.email WHEN 'in_app' THEN rc.user_id::text ELSE rc.phone END;
      v_status := 'queued'; v_reason := NULL; v_when := now();
      IF v_addr IS NULL THEN
        v_status := 'suppressed'; v_reason := 'Aucune coordonnée ' || r.channel || ' pour ce destinataire';
      ELSIF EXISTS (SELECT 1 FROM notification_outbox o WHERE o.tenant_id = p_tenant AND o.event_type = p_event
                      AND o.entity_id IS NOT DISTINCT FROM v_eid AND o.channel = r.channel AND o.address = v_addr
                      AND o.created_at > now() - interval '10 minutes') THEN
        v_status := 'suppressed'; v_reason := 'Doublon (< 10 min)';
      ELSIF v_sev <> 'critical' THEN
        v_q := keystone.quiet_until(p_tenant, r.channel, now());
        IF v_q IS NOT NULL THEN v_status := 'deferred'; v_reason := 'Plage de non-dérangement'; v_when := v_q; END IF;
      END IF;
      INSERT INTO notification_outbox(tenant_id, event_type, severity, entity_ref, entity_id, channel, audience, recipient_label, address, user_id,
                                      subject, body, status, status_reason, scheduled_for)
      VALUES (p_tenant, p_event, v_sev, p_payload->>'ref', v_eid, r.channel, r.audience, rc.label, v_addr, rc.user_id,
              keystone.render_template(tpl.subject, p_payload), keystone.render_template(tpl.body, p_payload), v_status, v_reason, v_when);
      n := n + 1;
    END LOOP;
  END LOOP;
  RETURN n;
END $$;

-- Envoi des messages dus : simulation en base (le mode live est traité par l'Edge Function notify-dispatch)
CREATE OR REPLACE FUNCTION keystone.notification_dispatch(p_limit int DEFAULT 200)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE o record; n_sent int := 0;
BEGIN
  FOR o IN
    SELECT ob.* FROM notification_outbox ob
    JOIN notification_channels ch ON ch.tenant_id = ob.tenant_id AND ch.channel = ob.channel
    WHERE ob.status IN ('queued','deferred') AND ob.scheduled_for <= now() AND (ch.mode = 'simulation' OR ob.channel = 'in_app')
    ORDER BY ob.scheduled_for LIMIT p_limit FOR UPDATE OF ob SKIP LOCKED
  LOOP
    IF o.channel = 'in_app' AND o.user_id IS NOT NULL THEN
      INSERT INTO notifications(tenant_id, user_id, kind, payload)
      VALUES (o.tenant_id, o.user_id, o.event_type, jsonb_build_object('title', o.subject, 'body', o.body, 'ref', o.entity_ref, 'severity', o.severity));
    END IF;
    UPDATE notification_outbox SET status = 'sent', sent_at = now(), attempts = attempts + 1,
      provider_ref = CASE WHEN channel = 'in_app' THEN 'in-app' ELSE 'SIM-' || upper(substr(md5(id::text || now()::text), 1, 8)) END
    WHERE id = o.id;
    n_sent := n_sent + 1;
  END LOOP;
  RETURN json_build_object('sent', n_sent);
END $$;

-- ===================== Branchements métier (triggers) =====================
CREATE OR REPLACE FUNCTION keystone.ticket_status_label(s text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE s WHEN 'new' THEN 'reçue' WHEN 'triaged' THEN 'prise en compte' WHEN 'assigned' THEN 'confiée à un technicien'
    WHEN 'in_progress' THEN 'en cours d''intervention' WHEN 'resolved' THEN 'résolue' WHEN 'closed' THEN 'clôturée'
    WHEN 'rejected' THEN 'non retenue' WHEN 'reopened' THEN 'réouverte' ELSE s END;
$$;

CREATE OR REPLACE FUNCTION keystone.trg_notify_ticket() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE p jsonb;
BEGIN
  p := jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'category', coalesce(NEW.category, 'demande'),
         'description', left(coalesce(NEW.description, ''), 140), 'lessee_id', NEW.lessee_id,
         'requester_name', NEW.requester_name, 'requester_contact', NEW.requester_contact,
         'status_label', keystone.ticket_status_label(NEW.status::text));
  IF TG_OP = 'INSERT' THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'ticket.created', p, CASE WHEN NEW.priority = 1 THEN 'high' END);
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM keystone.notify_event(NEW.tenant_id, CASE WHEN NEW.status IN ('resolved','closed') THEN 'ticket.resolved' ELSE 'ticket.status_changed' END, p);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_ticket ON keystone.service_requests;
CREATE TRIGGER notify_ticket AFTER INSERT OR UPDATE OF status ON keystone.service_requests FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_ticket();

CREATE OR REPLACE FUNCTION keystone.trg_notify_wo() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF NEW.priority = 1 AND NEW.type = 'corrective' AND NEW.description IS DISTINCT FROM 'seed-historique-pannes' THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'wo.critical', jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'title', NEW.title,
      'asset', (SELECT tag FROM assets WHERE id = NEW.asset_id), 'contractor_id', NEW.contractor_id), 'critical');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_wo ON keystone.work_orders;
CREATE TRIGGER notify_wo AFTER INSERT ON keystone.work_orders FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_wo();

CREATE OR REPLACE FUNCTION keystone.trg_notify_hsse() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF coalesce(NEW.risk_score, 0) >= 9 OR NEW.type IN ('accident','env_spill') THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'hsse.incident', jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'title', NEW.title,
      'location', (SELECT name FROM locations WHERE id = NEW.location_id)),
      CASE WHEN coalesce(NEW.risk_score, 0) >= 15 OR NEW.type = 'accident' THEN 'critical' ELSE 'high' END);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_hsse ON keystone.hsse_events;
CREATE TRIGGER notify_hsse AFTER INSERT ON keystone.hsse_events FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_hsse();

CREATE OR REPLACE FUNCTION keystone.trg_notify_nc() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF NEW.severity = 'critical' THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'nc.critical', jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'title', NEW.title,
      'due_date', to_char(NEW.due_date, 'DD/MM/YYYY')), 'high');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_nc ON keystone.non_conformities;
CREATE TRIGGER notify_nc AFTER INSERT ON keystone.non_conformities FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_nc();

CREATE OR REPLACE FUNCTION keystone.trg_notify_portal() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = NEW.work_order_id;
  PERFORM keystone.notify_event(NEW.tenant_id, CASE TG_TABLE_NAME WHEN 'wo_reports' THEN 'portal.report_submitted' ELSE 'portal.quote_submitted' END,
    jsonb_build_object('entity_id', NEW.id, 'ref', w.ref, 'title', w.title, 'contractor', (SELECT name FROM contractors WHERE id = NEW.contractor_id)));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_report ON keystone.wo_reports;
CREATE TRIGGER notify_report AFTER INSERT ON keystone.wo_reports FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_portal();
DROP TRIGGER IF EXISTS notify_quote ON keystone.wo_quotes;
CREATE TRIGGER notify_quote AFTER INSERT ON keystone.wo_quotes FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_portal();

CREATE OR REPLACE FUNCTION keystone.trg_notify_rent() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE l leases;
BEGIN
  SELECT * INTO l FROM leases WHERE id = NEW.lease_id;
  IF TG_TABLE_NAME = 'rent_schedules' THEN
    IF NEW.reminders_sent > OLD.reminders_sent THEN
      PERFORM keystone.notify_event(NEW.tenant_id, 'rent.reminder', jsonb_build_object('entity_id', NEW.id, 'ref', l.ref, 'lessee_id', NEW.lessee_id,
        'lessee', (SELECT coalesce(trade_name, company_name) FROM lessees WHERE id = NEW.lessee_id),
        'amount', to_char(NEW.total_due - NEW.paid_amount, 'FM999G999G999G990') || ' FCFA',
        'period', to_char(NEW.period_start, 'MM/YYYY'), 'due_date', to_char(NEW.due_date, 'DD/MM/YYYY'),
        'reminder_no', NEW.reminders_sent::text), CASE WHEN NEW.reminders_sent >= 3 THEN 'high' ELSE 'warning' END);
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_rent ON keystone.rent_schedules;
CREATE TRIGGER notify_rent AFTER UPDATE OF reminders_sent ON keystone.rent_schedules FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_rent();

CREATE OR REPLACE FUNCTION keystone.trg_notify_payment() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE s rent_schedules;
BEGIN
  SELECT * INTO s FROM rent_schedules WHERE id = NEW.schedule_id;
  PERFORM keystone.notify_event(NEW.tenant_id, 'rent.payment_received', jsonb_build_object('entity_id', NEW.id, 'lessee_id', NEW.lessee_id,
    'ref', (SELECT ref FROM leases WHERE id = s.lease_id),
    'lessee', (SELECT coalesce(trade_name, company_name) FROM lessees WHERE id = NEW.lessee_id),
    'amount', to_char(NEW.amount, 'FM999G999G999G990') || ' FCFA', 'period', to_char(s.period_start, 'MM/YYYY'),
    'payment_ref', coalesce(NEW.provider_ref, '')));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_payment ON keystone.rent_payments;
CREATE TRIGGER notify_payment AFTER INSERT ON keystone.rent_payments FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_payment();

-- ===================== Lecture / pilotage =====================
CREATE OR REPLACE FUNCTION keystone.notification_journal(p_limit int DEFAULT 80)
RETURNS TABLE(id uuid, event_type text, event_label text, severity text, entity_ref text, channel text, audience text, recipient_label text,
  address text, subject text, body text, status text, status_reason text, scheduled_for timestamptz, sent_at timestamptz, provider_ref text, created_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT o.id, o.event_type, e.label, o.severity, o.entity_ref, o.channel, o.audience, o.recipient_label,
    CASE WHEN o.channel = 'in_app' THEN 'notification in-app' ELSE o.address END,
    o.subject, o.body, o.status, o.status_reason, o.scheduled_for, o.sent_at, o.provider_ref, o.created_at
  FROM notification_outbox o LEFT JOIN notification_events e ON e.event_type = o.event_type
  ORDER BY o.created_at DESC LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION keystone.notification_stats()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'sent_24h', (SELECT count(*) FROM notification_outbox WHERE status = 'sent' AND sent_at > now() - interval '24 hours'),
    'queued', (SELECT count(*) FROM notification_outbox WHERE status = 'queued'),
    'deferred', (SELECT count(*) FROM notification_outbox WHERE status = 'deferred'),
    'suppressed_24h', (SELECT count(*) FROM notification_outbox WHERE status = 'suppressed' AND created_at > now() - interval '24 hours'),
    'failed_24h', (SELECT count(*) FROM notification_outbox WHERE status = 'failed' AND created_at > now() - interval '24 hours'),
    'by_channel', (SELECT json_object_agg(channel, c) FROM (SELECT channel, count(*) c FROM notification_outbox WHERE created_at > now() - interval '7 days' GROUP BY channel) x),
    'live_channels', (SELECT count(*) FROM notification_channels WHERE mode = 'live' AND is_enabled AND channel <> 'in_app')
  );
$$;

CREATE OR REPLACE FUNCTION keystone.notification_matrix()
RETURNS TABLE(rule_id uuid, event_type text, label text, domain text, default_severity text, channel text, audience text, is_enabled boolean, has_template boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT r.id, e.event_type, e.label, e.domain, e.default_severity, r.channel, r.audience, r.is_enabled,
    EXISTS (SELECT 1 FROM notification_templates t WHERE t.tenant_id = r.tenant_id AND t.event_type = r.event_type AND t.channel = r.channel)
  FROM notification_rules r JOIN notification_events e ON e.event_type = r.event_type
  ORDER BY e.domain, e.label, r.audience, r.channel;
$$;

-- Envoi d'un message de test vers l'utilisateur connecté (vérifie la chaîne de bout en bout)
CREATE OR REPLACE FUNCTION keystone.notification_test(p_channel text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE u users; pe persons; v_addr text; v_id uuid;
BEGIN
  IF keystone.current_lessee() IS NOT NULL OR keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT * INTO u FROM users WHERE id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT * INTO pe FROM persons WHERE id = u.person_id;
  v_addr := CASE p_channel WHEN 'email' THEN coalesce(u.email, pe.email) WHEN 'in_app' THEN u.id::text ELSE pe.phone END;
  INSERT INTO notification_outbox(tenant_id, event_type, severity, channel, audience, recipient_label, address, user_id, subject, body, status, status_reason)
  VALUES (u.tenant_id, 'system.test', 'info', p_channel, 'staff', coalesce(u.full_name, u.email), v_addr, u.id,
          'Test Atlas Keystone', 'Message de test du canal ' || p_channel || ' — si vous le lisez, la chaîne de notification fonctionne.',
          CASE WHEN v_addr IS NULL THEN 'suppressed' ELSE 'queued' END,
          CASE WHEN v_addr IS NULL THEN 'Aucune coordonnée ' || p_channel || ' sur votre fiche' END)
  RETURNING id INTO v_id;
  PERFORM keystone.notification_dispatch(50);
  RETURN (SELECT json_build_object('status', status, 'provider_ref', provider_ref, 'reason', status_reason) FROM notification_outbox WHERE id = v_id);
END $$;

GRANT EXECUTE ON FUNCTION keystone.render_template(text, jsonb), keystone.notification_journal(int), keystone.notification_stats(),
  keystone.notification_matrix(), keystone.notification_test(text), keystone.ticket_status_label(text) TO authenticated;
-- moteur et dispatch : SECURITY DEFINER multi-tenant ⇒ jamais appelables directement depuis l'API
REVOKE EXECUTE ON FUNCTION keystone.notify_event(uuid, text, jsonb, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION keystone.notification_dispatch(int) FROM PUBLIC, anon, authenticated;

-- Cloche in-app : flux personnel temps réel + marquage lu
ALTER TABLE keystone.notifications REPLICA IDENTITY FULL;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE keystone.notifications; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE OR REPLACE FUNCTION keystone.my_notifications(p_limit int DEFAULT 20)
RETURNS TABLE(id uuid, kind text, title text, body text, ref text, severity text, created_at timestamptz, read_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT n.id, n.kind, coalesce(n.payload->>'title', n.kind), n.payload->>'body', n.payload->>'ref', coalesce(n.payload->>'severity', 'info'), n.created_at, n.read_at
  FROM notifications n WHERE n.user_id = auth.uid() ORDER BY n.created_at DESC LIMIT p_limit;
$$;
CREATE OR REPLACE FUNCTION keystone.my_notifications_read() RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE n int;
BEGIN
  UPDATE notifications SET read_at = now() WHERE user_id = auth.uid() AND read_at IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
GRANT EXECUTE ON FUNCTION keystone.my_notifications(int), keystone.my_notifications_read() TO authenticated;

-- Envoi automatique toutes les 2 minutes (messages dus, y compris différés après la plage de non-dérangement)
DO $$ BEGIN
  PERFORM cron.unschedule('keystone-notify-dispatch');
EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule('keystone-notify-dispatch', '*/2 * * * *', $c$SELECT keystone.notification_dispatch(500)$c$);

COMMIT;

-- ==================== 20261004_keystone_39b_notifications_seed.sql ====================
-- Seed notifications : catalogue d'événements, canaux (simulation), non-dérangement, règles et modèles FR/EN. Idempotent.
BEGIN;
INSERT INTO keystone.notification_events(event_type, label, domain, default_severity, placeholders) VALUES
  ('ticket.created', 'Nouvelle demande', 'Helpdesk', 'info', ARRAY['ref','category','description','status_label']),
  ('ticket.status_changed', 'Évolution d''une demande', 'Helpdesk', 'info', ARRAY['ref','category','status_label']),
  ('ticket.resolved', 'Demande résolue', 'Helpdesk', 'info', ARRAY['ref','category']),
  ('wo.critical', 'OT critique (P1)', 'GMAO', 'critical', ARRAY['ref','title','asset']),
  ('hsse.incident', 'Incident HSSE à risque', 'HSSE', 'high', ARRAY['ref','title','location']),
  ('nc.critical', 'Non-conformité critique', 'Qualité', 'high', ARRAY['ref','title','due_date']),
  ('portal.quote_submitted', 'Devis prestataire reçu', 'Prestataires', 'info', ARRAY['ref','title','contractor']),
  ('portal.report_submitted', 'Rapport d''intervention à signer', 'Prestataires', 'info', ARRAY['ref','title','contractor']),
  ('rent.reminder', 'Relance de loyer impayé', 'Gestion locative', 'warning', ARRAY['ref','lessee','amount','period','due_date','reminder_no']),
  ('rent.payment_received', 'Accusé de paiement de loyer', 'Gestion locative', 'info', ARRAY['ref','lessee','amount','period','payment_ref']),
  ('system.test', 'Message de test', 'Système', 'info', ARRAY[]::text[])
ON CONFLICT (event_type) DO UPDATE SET label = EXCLUDED.label, domain = EXCLUDED.domain, default_severity = EXCLUDED.default_severity, placeholders = EXCLUDED.placeholders;

DO $$
DECLARE t uuid := 'a0000000-0000-4000-8000-000000000001'; u record;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);

  INSERT INTO keystone.notification_channels(tenant_id, channel, is_enabled, mode, provider, sender) VALUES
    (t, 'whatsapp', true, 'simulation', 'whatsapp_cloud', '+225 27 23 00 00 10'),
    (t, 'sms', true, 'simulation', 'orange_sms', 'COSMOS'),
    (t, 'email', true, 'simulation', 'resend', 'notifications@cosmos-yopougon.demo'),
    (t, 'in_app', true, 'live', 'internal', NULL)
  ON CONFLICT (tenant_id, channel) DO NOTHING;
  INSERT INTO keystone.notification_quiet_hours(tenant_id) VALUES (t) ON CONFLICT DO NOTHING;

  INSERT INTO keystone.notification_rules(tenant_id, event_type, channel, audience, is_enabled)
  SELECT t, v.e, v.c, v.a, v.enabled FROM (VALUES
    ('ticket.created', 'whatsapp', 'lessee', true), ('ticket.created', 'email', 'lessee', true), ('ticket.created', 'in_app', 'staff', true),
    ('ticket.status_changed', 'whatsapp', 'lessee', true),
    ('ticket.resolved', 'whatsapp', 'lessee', true), ('ticket.resolved', 'email', 'lessee', true), ('ticket.resolved', 'sms', 'requester', true),
    ('wo.critical', 'sms', 'staff', true), ('wo.critical', 'whatsapp', 'staff', true), ('wo.critical', 'in_app', 'staff', true), ('wo.critical', 'whatsapp', 'contractor', true),
    ('hsse.incident', 'sms', 'staff', true), ('hsse.incident', 'in_app', 'staff', true), ('hsse.incident', 'email', 'staff', true),
    ('nc.critical', 'in_app', 'staff', true), ('nc.critical', 'email', 'staff', true),
    ('portal.quote_submitted', 'in_app', 'staff', true),
    ('portal.report_submitted', 'in_app', 'staff', true), ('portal.report_submitted', 'email', 'staff', true),
    ('rent.reminder', 'whatsapp', 'lessee', true), ('rent.reminder', 'email', 'lessee', true), ('rent.reminder', 'sms', 'lessee', false),
    ('rent.payment_received', 'whatsapp', 'lessee', true), ('rent.payment_received', 'email', 'lessee', true)
  ) v(e, c, a, enabled)
  ON CONFLICT (tenant_id, event_type, channel, audience) DO NOTHING;

  INSERT INTO keystone.notification_templates(tenant_id, event_type, channel, locale, subject, body, wa_template_name)
  SELECT t, v.e, v.c, v.l, v.s, v.b, v.w FROM (VALUES
    ('ticket.created', 'whatsapp', 'fr', NULL, 'Bonjour, votre demande {{ref}} ({{category}}) est bien reçue par l''équipe technique du centre. Vous serez informé à chaque étape.', 'ks_ticket_received_fr'),
    ('ticket.created', 'whatsapp', 'en', NULL, 'Hello, your request {{ref}} ({{category}}) has been received by the centre''s technical team. We will keep you posted.', 'ks_ticket_received_en'),
    ('ticket.created', 'email', 'fr', 'Demande {{ref}} reçue', E'Bonjour,\n\nNous avons bien reçu votre demande {{ref}} ({{category}}) :\n« {{description}} »\n\nVous pouvez suivre son avancement depuis votre espace locataire.\n\nL''équipe de gestion', NULL),
    ('ticket.created', 'in_app', 'fr', 'Nouvelle demande {{ref}}', '{{category}} — {{description}}', NULL),
    ('ticket.status_changed', 'whatsapp', 'fr', NULL, 'Votre demande {{ref}} est maintenant {{status_label}}.', 'ks_ticket_update_fr'),
    ('ticket.resolved', 'whatsapp', 'fr', NULL, 'Bonne nouvelle : votre demande {{ref}} est résolue. Donnez-nous votre avis en 1 clic depuis votre espace locataire ⭐', 'ks_ticket_resolved_fr'),
    ('ticket.resolved', 'whatsapp', 'en', NULL, 'Good news: your request {{ref}} has been resolved. Rate us in one tap from your tenant space ⭐', 'ks_ticket_resolved_en'),
    ('ticket.resolved', 'email', 'fr', 'Demande {{ref}} résolue', E'Bonjour,\n\nVotre demande {{ref}} ({{category}}) est résolue.\nVotre avis nous aide à progresser : notez l''intervention depuis votre espace locataire.\n\nL''équipe de gestion', NULL),
    ('ticket.resolved', 'sms', 'fr', NULL, 'COSMOS : votre signalement {{ref}} est résolu. Merci de nous avoir alertés.', NULL),
    ('wo.critical', 'sms', 'fr', NULL, 'URGENT P1 {{ref}} : {{title}} ({{asset}}). Intervention immédiate requise.', NULL),
    ('wo.critical', 'whatsapp', 'fr', NULL, '🔴 OT critique {{ref}} — {{title}} · équipement {{asset}}. Merci d''accuser réception et d''intervenir immédiatement.', 'ks_wo_critical_fr'),
    ('wo.critical', 'in_app', 'fr', 'OT critique {{ref}}', '{{title}} · {{asset}}', NULL),
    ('hsse.incident', 'sms', 'fr', NULL, 'HSSE {{ref}} : {{title}} — {{location}}. Consultez Keystone.', NULL),
    ('hsse.incident', 'in_app', 'fr', 'Incident HSSE {{ref}}', '{{title}} — {{location}}', NULL),
    ('hsse.incident', 'email', 'fr', '[HSSE] Incident {{ref}} à risque', E'Un événement HSSE à risque vient d''être déclaré :\n{{title}} — {{location}}\n\nOuvrez Keystone pour l''analyse et les actions immédiates.', NULL),
    ('nc.critical', 'in_app', 'fr', 'NC critique {{ref}}', '{{title}} — échéance {{due_date}}', NULL),
    ('nc.critical', 'email', 'fr', '[Qualité] Non-conformité critique {{ref}}', E'Une non-conformité critique a été ouverte : {{title}}.\nÉchéance de traitement : {{due_date}}.', NULL),
    ('portal.quote_submitted', 'in_app', 'fr', 'Devis reçu · {{ref}}', '{{contractor}} — {{title}}', NULL),
    ('portal.report_submitted', 'in_app', 'fr', 'Rapport à signer · {{ref}}', '{{contractor}} — {{title}}', NULL),
    ('portal.report_submitted', 'email', 'fr', 'Rapport d''intervention à signer — {{ref}}', E'{{contractor}} a transmis son rapport pour {{ref}} ({{title}}).\nMerci de le valider et de le signer depuis l''onglet Portail des prestataires.', NULL),
    ('rent.reminder', 'whatsapp', 'fr', NULL, 'Bonjour {{lessee}}, sauf erreur de notre part, l''échéance {{period}} du bail {{ref}} ({{amount}}, due le {{due_date}}) reste impayée. Merci de régulariser ou de nous contacter. (Relance n°{{reminder_no}})', 'ks_rent_reminder_fr'),
    ('rent.reminder', 'whatsapp', 'en', NULL, 'Hello {{lessee}}, the {{period}} instalment of lease {{ref}} ({{amount}}, due {{due_date}}) is still unpaid. Please settle it or contact us. (Reminder #{{reminder_no}})', 'ks_rent_reminder_en'),
    ('rent.reminder', 'email', 'fr', 'Relance n°{{reminder_no}} — échéance {{period}} impayée', E'Madame, Monsieur,\n\nSauf erreur de notre part, l''échéance {{period}} du bail {{ref}}, d''un montant de {{amount}}, exigible le {{due_date}}, n''a pas été réglée.\nNous vous remercions de bien vouloir régulariser cette situation dans les meilleurs délais ou de prendre contact avec la gestion.\n\nSi le règlement a été effectué entre-temps, merci de ne pas tenir compte de ce message.\n\nLa gestion locative', NULL),
    ('rent.reminder', 'sms', 'fr', NULL, 'COSMOS : échéance {{period}} bail {{ref}} impayée ({{amount}}). Merci de régulariser.', NULL),
    ('rent.payment_received', 'whatsapp', 'fr', NULL, 'Merci {{lessee}} : nous avons bien reçu {{amount}} pour l''échéance {{period}} du bail {{ref}}. Votre quittance est disponible dans votre espace locataire.', 'ks_rent_paid_fr'),
    ('rent.payment_received', 'email', 'fr', 'Paiement reçu — échéance {{period}}', E'Bonjour,\n\nNous accusons réception de votre règlement de {{amount}} pour l''échéance {{period}} du bail {{ref}}.\nRéférence : {{payment_ref}}\nLa quittance est téléchargeable depuis votre espace locataire une fois l''échéance soldée.\n\nLa gestion locative', NULL)
  ) v(e, c, l, s, b, w)
  ON CONFLICT (tenant_id, event_type, channel, locale) DO NOTHING;

  -- Coordonnées démo (fictives) pour que les canaux SMS / WhatsApp aient des destinataires
  UPDATE keystone.persons SET phone = '+225 07 00 00 01 0' || (row_number)::text, email = lower(first_name) || '.' || lower(replace(last_name, 'é', 'e')) || '@cosmos-yopougon.demo'
  FROM (SELECT id AS pid, row_number() OVER (ORDER BY last_name) FROM keystone.persons WHERE tenant_id = t) x
  WHERE keystone.persons.id = x.pid AND keystone.persons.phone IS NULL;
  UPDATE keystone.users SET person_id = (SELECT id FROM keystone.persons WHERE tenant_id = t AND first_name = 'Awa' LIMIT 1)
  WHERE tenant_id = t AND email = 'admin@keystone.demo' AND person_id IS NULL;
  UPDATE keystone.contractors SET contact_phone = '+225 07 00 00 02 ' || lpad((abs(hashtext(name)) % 100)::text, 2, '0'),
         contact_email = 'contact@' || lower(regexp_replace(name, '[^A-Za-z]', '', 'g')) || '.demo'
  WHERE tenant_id = t AND contact_phone IS NULL;
END $$;
COMMIT;

-- ==================== 20261004_keystone_40_field_execution.sql ====================
-- keystone_40_field_execution — Exécution terrain des OT (technicien interne) + modèles d'OT
--   · modèles d'OT : procédure pas à pas (contrôle / mesure avec plage / photo / texte, étapes critiques),
--     consignes de sécurité, pièces requises, permis requis — instanciés sur un OT (checklist)
--   · pointage GPS arrivée/départ horodaté, distance au site (alerte « hors site » > 300 m)
--   · démarrage/clôture via wo_transition (les verrous existants PERMIT_REQUIRED, etc. s'appliquent)
--   · verrous terrain : CHECKLIST_INCOMPLETE (étapes obligatoires non renseignées), CRITICAL_STEP_FAILED
--   · sortie de pièces via consume_part (INSUFFICIENT_STOCK), coûts pièces + main d'œuvre (temps pointé × taux horaire)
--   · scan QR/étiquette → fiche équipement terrain (santé, OT ouverts, historique, risque AMDEC)
--   · correctif : la couverture de stock lit les sorties en valeur absolue (consume_part les enregistre en négatif)
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

ALTER TABLE keystone.persons ADD COLUMN IF NOT EXISTS hourly_rate numeric NOT NULL DEFAULT 4000;
ALTER TABLE keystone.work_orders
  ADD COLUMN IF NOT EXISTS template_id uuid,
  ADD COLUMN IF NOT EXISTS checklist jsonb NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS safety_instructions text,
  ADD COLUMN IF NOT EXISTS completion_notes text,
  ADD COLUMN IF NOT EXISTS signed_by text;

-- Pièces prévues par un modèle (distinctes des pièces réellement sorties) : extension additive de la contrainte
ALTER TABLE keystone.work_order_lines DROP CONSTRAINT IF EXISTS work_order_lines_kind_check;
ALTER TABLE keystone.work_order_lines ADD CONSTRAINT work_order_lines_kind_check CHECK (kind IN ('labor','part','task','note','planned_part'));

CREATE TABLE IF NOT EXISTS keystone.wo_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  name text NOT NULL,
  wo_type keystone.wo_type NOT NULL DEFAULT 'corrective',
  category_id uuid REFERENCES keystone.asset_categories(id),
  estimated_minutes int NOT NULL DEFAULT 60,
  requires_permit boolean NOT NULL DEFAULT false,
  safety_instructions text,
  steps jsonb NOT NULL DEFAULT '[]',          -- [{label, type: check|numeric|photo|text, min, max, unit, required, critical}]
  required_parts jsonb NOT NULL DEFAULT '[]', -- [{part_ref, qty}]
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  ALTER TABLE keystone.work_orders ADD CONSTRAINT work_orders_template_fk FOREIGN KEY (template_id) REFERENCES keystone.wo_templates(id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS keystone.wo_time_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  person_id uuid REFERENCES keystone.persons(id),
  kind text NOT NULL CHECK (kind IN ('check_in','check_out','pause','resume')),
  at timestamptz NOT NULL DEFAULT now(),
  lat numeric, lng numeric, accuracy_m numeric,
  distance_to_site_m numeric
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['wo_templates','wo_time_entries'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('DROP POLICY IF EXISTS staff_only ON keystone.%I', t);
    EXECUTE format('CREATE POLICY staff_only ON keystone.%I AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL)', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT, UPDATE ON keystone.wo_templates TO authenticated;

-- Distance (m) entre deux points GPS (haversine)
CREATE OR REPLACE FUNCTION keystone.geo_distance_m(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN lat1 IS NULL OR lat2 IS NULL THEN NULL ELSE
    round((2 * 6371000 * asin(sqrt(power(sin(radians(lat2 - lat1) / 2), 2)
      + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2))))::numeric) END;
$$;

-- Technicien courant (personne liée à l'utilisateur) ; un exploitant peut prévisualiser un technicien
CREATE OR REPLACE FUNCTION keystone.tech_person(p_person uuid DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE me uuid;
BEGIN
  IF keystone.current_lessee() IS NOT NULL OR keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT id INTO me FROM persons WHERE user_id = auth.uid() LIMIT 1;
  RETURN coalesce(p_person, me);
END $$;

-- Instancie un modèle sur un OT : checklist, consignes, permis, lignes de pièces prévues
CREATE OR REPLACE FUNCTION keystone.wo_apply_template(p_wo uuid, p_template uuid)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE t wo_templates; w work_orders; rp jsonb; v_part spare_parts; n int := 0;
BEGIN
  SELECT * INTO t FROM wo_templates WHERE id = p_template AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT * INTO w FROM work_orders WHERE id = p_wo FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status NOT IN ('draft','planned','assigned') THEN RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = 'Modèle applicable avant le démarrage uniquement.'; END IF;
  UPDATE work_orders SET template_id = t.id,
    checklist = (SELECT coalesce(jsonb_agg(s || jsonb_build_object('index', i - 1, 'value', NULL, 'ok', NULL, 'done_at', NULL)), '[]')
                 FROM jsonb_array_elements(t.steps) WITH ORDINALITY AS x(s, i)),
    safety_instructions = t.safety_instructions,
    requires_permit = w.requires_permit OR t.requires_permit, updated_at = now()
  WHERE id = p_wo;
  FOR rp IN SELECT * FROM jsonb_array_elements(t.required_parts) LOOP
    SELECT * INTO v_part FROM spare_parts WHERE ref = rp->>'part_ref' AND deleted_at IS NULL LIMIT 1;
    IF FOUND THEN
      INSERT INTO work_order_lines(tenant_id, work_order_id, kind, label, qty, unit_cost, currency, part_id)
      VALUES (w.tenant_id, w.id, 'planned_part', v_part.ref || ' · ' || v_part.name, (rp->>'qty')::numeric, v_part.unit_cost, 'XOF', v_part.id);
      n := n + 1;
    END IF;
  END LOOP;
  RETURN json_build_object('steps', jsonb_array_length(t.steps), 'planned_parts', n);
END $$;

-- Journée du technicien
CREATE OR REPLACE FUNCTION keystone.tech_my_day(p_person uuid DEFAULT NULL)
RETURNS TABLE(wo_id uuid, ref text, title text, type text, status text, priority int, asset_tag text, asset_name text, location text,
  planned_start timestamptz, sla_due timestamptz, requires_permit boolean, permit_active boolean, steps_total int, steps_done int,
  checked_in_at timestamptz, template text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT w.id, w.ref, w.title, w.type::text, w.status::text, w.priority, a.tag, a.name, l.name, w.planned_start, w.sla_due, w.requires_permit,
    EXISTS (SELECT 1 FROM work_permits p WHERE p.work_order_id = w.id AND p.status = 'active'),
    jsonb_array_length(w.checklist),
    (SELECT count(*) FROM jsonb_array_elements(w.checklist) c WHERE c->>'done_at' IS NOT NULL)::int,
    (SELECT max(te.at) FROM wo_time_entries te WHERE te.work_order_id = w.id AND te.kind = 'check_in'),
    (SELECT name FROM wo_templates t WHERE t.id = w.template_id)
  FROM work_orders w LEFT JOIN assets a ON a.id = w.asset_id LEFT JOIN locations l ON l.id = w.location_id
  WHERE w.deleted_at IS NULL AND w.contractor_id IS NULL
    AND w.assignee_id = keystone.tech_person(p_person)
    AND (w.status IN ('assigned','in_progress','on_hold') OR (w.status = 'done' AND w.actual_end > now() - interval '24 hours'))
  ORDER BY w.status = 'done', w.status = 'in_progress' DESC, w.priority, coalesce(w.sla_due, w.planned_start);
$$;

CREATE OR REPLACE FUNCTION keystone.tech_wo_detail(p_wo uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'id', w.id, 'ref', w.ref, 'title', w.title, 'description', w.description, 'status', w.status, 'priority', w.priority, 'type', w.type,
    'asset', (SELECT json_build_object('tag', a.tag, 'name', a.name, 'manufacturer', a.manufacturer, 'model', a.model) FROM assets a WHERE a.id = w.asset_id),
    'location', (SELECT name FROM locations WHERE id = w.location_id),
    'safety', w.safety_instructions, 'requires_permit', w.requires_permit,
    'permit_active', EXISTS (SELECT 1 FROM work_permits p WHERE p.work_order_id = w.id AND p.status = 'active'),
    'checklist', w.checklist, 'sla_due', w.sla_due, 'notes', w.completion_notes,
    'parts', (SELECT json_agg(json_build_object('id', ol.id, 'kind', ol.kind, 'label', ol.label, 'qty', ol.qty, 'unit_cost', ol.unit_cost, 'part_id', ol.part_id,
                'in_stock', (SELECT qty FROM spare_parts sp WHERE sp.id = ol.part_id)) ORDER BY ol.created_at)
              FROM work_order_lines ol WHERE ol.work_order_id = w.id AND ol.deleted_at IS NULL AND ol.kind IN ('part','planned_part')),
    'time', (SELECT json_agg(json_build_object('kind', te.kind, 'at', te.at, 'distance', te.distance_to_site_m) ORDER BY te.at) FROM wo_time_entries te WHERE te.work_order_id = w.id)
  ) FROM work_orders w WHERE w.id = p_wo;
$$;

-- Arrivée sur site : pointage GPS + démarrage (via wo_transition ⇒ verrou PERMIT_REQUIRED)
CREATE OR REPLACE FUNCTION keystone.tech_check_in(p_wo uuid, p_lat numeric DEFAULT NULL, p_lng numeric DEFAULT NULL, p_accuracy numeric DEFAULT NULL, p_person uuid DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v_dist numeric; s sites;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status = 'assigned' THEN PERFORM keystone.wo_transition(p_wo, 'in_progress');
  ELSIF w.status = 'on_hold' THEN PERFORM keystone.wo_transition(p_wo, 'in_progress');
  ELSIF w.status <> 'in_progress' THEN RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = 'OT ' || w.status;
  END IF;
  SELECT si.* INTO s FROM sites si JOIN locations l ON l.site_id = si.id WHERE l.id = w.location_id;
  v_dist := keystone.geo_distance_m(p_lat, p_lng, s.latitude, s.longitude);
  INSERT INTO wo_time_entries(tenant_id, work_order_id, person_id, kind, lat, lng, accuracy_m, distance_to_site_m)
  VALUES (w.tenant_id, w.id, keystone.tech_person(p_person), CASE WHEN w.status = 'on_hold' THEN 'resume' ELSE 'check_in' END, p_lat, p_lng, p_accuracy, v_dist);
  RETURN json_build_object('status', 'in_progress', 'distance_m', v_dist, 'off_site', v_dist > 300);
END $$;

CREATE OR REPLACE FUNCTION keystone.tech_hold(p_wo uuid, p_reason text, p_person uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders;
BEGIN
  IF coalesce(trim(p_reason), '') = '' THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  PERFORM keystone.wo_transition(p_wo, 'on_hold', jsonb_build_object('reason', p_reason));
  INSERT INTO wo_time_entries(tenant_id, work_order_id, person_id, kind) VALUES (w.tenant_id, w.id, keystone.tech_person(p_person), 'pause');
  UPDATE work_orders SET completion_notes = trim(both E'\n' FROM coalesce(completion_notes, '') || E'\n[Pause] ' || p_reason) WHERE id = p_wo;
END $$;

-- Renseigne une étape de checklist (mesure contrôlée contre sa plage)
CREATE OR REPLACE FUNCTION keystone.tech_check_step(p_wo uuid, p_index int, p_value jsonb)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; st jsonb; v_ok boolean;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status <> 'in_progress' THEN RAISE EXCEPTION 'NOT_STARTED' USING DETAIL = 'Pointez votre arrivée avant de renseigner la checklist.'; END IF;
  st := w.checklist -> p_index;
  IF st IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  v_ok := CASE st->>'type'
    WHEN 'check' THEN (p_value #>> '{}')::boolean
    WHEN 'numeric' THEN (st->>'min' IS NULL OR (p_value #>> '{}')::numeric >= (st->>'min')::numeric)
                    AND (st->>'max' IS NULL OR (p_value #>> '{}')::numeric <= (st->>'max')::numeric)
    ELSE coalesce(length(p_value #>> '{}'), 0) > 0 END;
  UPDATE work_orders SET checklist = jsonb_set(checklist, ARRAY[p_index::text],
      st || jsonb_build_object('value', p_value, 'ok', v_ok, 'done_at', now(), 'by', auth.uid())), updated_at = now()
  WHERE id = p_wo;
  RETURN json_build_object('ok', v_ok);
END $$;

-- Sortie de pièce pour l'OT (stock atomique) + coût pièces
CREATE OR REPLACE FUNCTION keystone.tech_use_part(p_wo uuid, p_part uuid, p_qty numeric)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; p spare_parts;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status NOT IN ('in_progress','on_hold') THEN RAISE EXCEPTION 'NOT_STARTED'; END IF;
  IF p_qty <= 0 THEN RAISE EXCEPTION 'INVALID_QTY'; END IF;
  SELECT * INTO p FROM spare_parts WHERE id = p_part;
  PERFORM keystone.consume_part(p_part, p_qty, p_wo);
  INSERT INTO work_order_lines(tenant_id, work_order_id, kind, label, qty, unit_cost, currency, part_id)
  VALUES (w.tenant_id, w.id, 'part', p.ref || ' · ' || p.name, p_qty, p.unit_cost, 'XOF', p.id);
  UPDATE work_orders SET cost_parts = (SELECT coalesce(sum(qty * coalesce(unit_cost, 0)), 0) FROM work_order_lines WHERE work_order_id = p_wo AND kind = 'part' AND deleted_at IS NULL)
  WHERE id = p_wo;
  RETURN json_build_object('remaining', p.qty - p_qty);
END $$;

-- Clôture terrain : verrous checklist, pointage départ, main d'œuvre, passage à « done »
CREATE OR REPLACE FUNCTION keystone.tech_complete(p_wo uuid, p_notes text, p_signed_by text, p_lat numeric DEFAULT NULL, p_lng numeric DEFAULT NULL, p_person uuid DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v_missing int; v_failed text; v_minutes int; v_person uuid; v_rate numeric; s sites;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status <> 'in_progress' THEN RAISE EXCEPTION 'NOT_STARTED'; END IF;
  SELECT count(*) INTO v_missing FROM jsonb_array_elements(w.checklist) c WHERE coalesce((c->>'required')::boolean, true) AND c->>'done_at' IS NULL;
  IF v_missing > 0 THEN RAISE EXCEPTION 'CHECKLIST_INCOMPLETE' USING DETAIL = v_missing || ' étape(s) obligatoire(s) non renseignée(s).'; END IF;
  SELECT c->>'label' INTO v_failed FROM jsonb_array_elements(w.checklist) c WHERE coalesce((c->>'critical')::boolean, false) AND (c->>'ok')::boolean = false LIMIT 1;
  IF v_failed IS NOT NULL THEN
    RAISE EXCEPTION 'CRITICAL_STEP_FAILED' USING DETAIL = 'Étape critique non conforme : « ' || v_failed || ' ». Mettez l''OT en pause et escaladez.';
  END IF;
  IF coalesce(trim(p_signed_by), '') = '' THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;

  v_person := keystone.tech_person(p_person);
  SELECT si.* INTO s FROM sites si JOIN locations l ON l.site_id = si.id WHERE l.id = w.location_id;
  INSERT INTO wo_time_entries(tenant_id, work_order_id, person_id, kind, lat, lng, distance_to_site_m)
  VALUES (w.tenant_id, w.id, v_person, 'check_out', p_lat, p_lng, keystone.geo_distance_m(p_lat, p_lng, s.latitude, s.longitude));
  -- temps pointé = Σ (sortie/pause − arrivée/reprise)
  SELECT coalesce(sum(EXTRACT(epoch FROM (nxt - at)) / 60), 0)::int INTO v_minutes FROM (
    SELECT kind, at, lead(at) OVER (ORDER BY at) AS nxt FROM wo_time_entries WHERE work_order_id = w.id
  ) x WHERE kind IN ('check_in','resume') AND nxt IS NOT NULL;
  SELECT coalesce(hourly_rate, 4000) INTO v_rate FROM persons WHERE id = v_person;
  IF v_minutes > 0 THEN
    INSERT INTO work_order_lines(tenant_id, work_order_id, kind, label, qty, unit_cost, currency, person_id, minutes)
    VALUES (w.tenant_id, w.id, 'labor', 'Main d''œuvre interne', round(v_minutes / 60.0, 2), coalesce(v_rate, 4000), 'XOF', v_person, v_minutes);
  END IF;
  UPDATE work_orders SET completion_notes = trim(both E'\n' FROM coalesce(completion_notes, '') || E'\n' || coalesce(p_notes, '')),
    signed_by = p_signed_by,
    cost_labor = coalesce(cost_labor, 0) + round(v_minutes / 60.0 * coalesce(v_rate, 4000))
  WHERE id = p_wo;
  PERFORM keystone.wo_transition(p_wo, 'done');
  RETURN json_build_object('minutes', v_minutes, 'labor_cost', round(v_minutes / 60.0 * coalesce(v_rate, 4000)));
END $$;

-- Scan d'une étiquette (QR / code-barres / tag) → fiche équipement terrain
CREATE OR REPLACE FUNCTION keystone.asset_scan(p_code text)
RETURNS json LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE v uuid;
BEGIN
  SELECT asset_id INTO v FROM asset_identifiers WHERE value = trim(p_code) LIMIT 1;
  IF v IS NULL THEN SELECT id INTO v FROM assets WHERE upper(tag) = upper(trim(p_code)) AND deleted_at IS NULL LIMIT 1; END IF;
  IF v IS NULL THEN RAISE EXCEPTION 'ASSET_NOT_FOUND' USING DETAIL = 'Aucun équipement pour le code « ' || p_code || ' ».'; END IF;
  RETURN (
    SELECT json_build_object(
      'asset', json_build_object('id', b.id, 'tag', b.tag, 'name', b.name, 'category', b.category, 'location', b.location, 'site', b.site,
               'criticality', b.criticality, 'status', b.status, 'manufacturer', b.manufacturer, 'model', b.model, 'health', b.health,
               'mtbf_h', b.mtbf_h, 'max_rpn', b.max_rpn, 'rul_days', b.prediction_rul_days, 'warranty_until', b.warranty_until),
      'open_wo', (SELECT json_agg(json_build_object('ref', w.ref, 'title', w.title, 'status', w.status, 'priority', w.priority) ORDER BY w.priority)
                  FROM work_orders w WHERE w.asset_id = v AND w.deleted_at IS NULL AND w.status NOT IN ('done','verified','cancelled')),
      'history', (SELECT json_agg(h) FROM (SELECT w.ref, w.title, w.type, w.actual_end FROM work_orders w
                  WHERE w.asset_id = v AND w.status IN ('done','verified') ORDER BY w.actual_end DESC NULLS LAST LIMIT 5) h),
      'top_risk', (SELECT json_build_object('component', f.component, 'rpn', f.rpn, 'effect', f.effect) FROM fmea_items f
                   WHERE f.asset_id = v AND f.action_status <> 'done' ORDER BY f.rpn DESC LIMIT 1))
    FROM keystone.assets_board() b WHERE b.id = v);
END $$;

-- Signalement terrain depuis un scan : OT correctif en brouillon (planification humaine)
CREATE OR REPLACE FUNCTION keystone.tech_report_issue(p_asset uuid, p_title text, p_priority int DEFAULT 3)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE a assets; v_ref text; v_id uuid;
BEGIN
  PERFORM keystone.tech_person(NULL);
  IF coalesce(length(trim(p_title)), 0) < 5 THEN RAISE EXCEPTION 'DESCRIPTION_REQUIRED'; END IF;
  SELECT * INTO a FROM assets WHERE id = p_asset;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  v_ref := keystone.next_ref('WO');
  INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description, currency, created_by)
  VALUES (a.tenant_id, a.legal_entity_id, v_ref, a.id, a.location_id, 'corrective', LEAST(4, GREATEST(1, p_priority)), 'draft', trim(p_title),
          'Signalé sur le terrain (scan ' || a.tag || ')', 'XOF', auth.uid())
  RETURNING id INTO v_id;
  RETURN json_build_object('id', v_id, 'ref', v_ref);
END $$;

CREATE OR REPLACE FUNCTION keystone.tech_people()
RETURNS TABLE(id uuid, name text, open_wo int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT p.id, trim(p.first_name || ' ' || p.last_name),
    (SELECT count(*) FROM work_orders w WHERE w.assignee_id = p.id AND w.status IN ('assigned','in_progress','on_hold') AND w.deleted_at IS NULL)::int
  FROM persons p WHERE p.type = 'employee' AND p.deleted_at IS NULL ORDER BY 3 DESC, 2;
$$;

CREATE OR REPLACE FUNCTION keystone.wo_templates_board()
RETURNS TABLE(id uuid, name text, wo_type text, category text, estimated_minutes int, requires_permit boolean, steps jsonb, required_parts jsonb,
  safety_instructions text, is_active boolean, uses int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT t.id, t.name, t.wo_type::text, c.name, t.estimated_minutes, t.requires_permit, t.steps, t.required_parts, t.safety_instructions, t.is_active,
    (SELECT count(*) FROM work_orders w WHERE w.template_id = t.id)::int
  FROM wo_templates t LEFT JOIN asset_categories c ON c.id = t.category_id ORDER BY t.is_active DESC, t.name;
$$;

-- Correctif couverture de stock : consume_part enregistre les sorties en négatif ⇒ valeur absolue
CREATE OR REPLACE FUNCTION keystone.stock_board()
RETURNS TABLE(id uuid, ref text, name text, category text, unit text, warehouse text, qty numeric, min_qty numeric, max_qty numeric,
  reorder_point numeric, unit_cost numeric, stock_value numeric, is_critical boolean, lead_time_days int, supplier text,
  daily_use numeric, days_cover numeric, level text, suggested_qty numeric, on_order numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH s AS (
    SELECT sp.*, w.name AS wh, c.name AS sup,
      coalesce(sp.reorder_point, sp.min_qty * 1.5) AS rop,
      coalesce(sp.max_qty, sp.min_qty * 4) AS mx,
      (SELECT coalesce(sum(abs(m.qty)), 0) / 90.0 FROM stock_movements m
         WHERE m.part_id = sp.id AND m.direction = 'out' AND m.at > now() - interval '90 days') AS use_d,
      (SELECT coalesce(sum(pol.qty_ordered - pol.qty_received), 0) FROM purchase_order_lines pol
         JOIN purchase_orders po ON po.id = pol.order_id
         WHERE pol.part_id = sp.id AND po.status IN ('sent','confirmed','partially_received')) AS ordered
    FROM spare_parts sp
    LEFT JOIN warehouses w ON w.id = sp.warehouse_id
    LEFT JOIN contractors c ON c.id = sp.preferred_supplier_id
    WHERE sp.deleted_at IS NULL
  )
  SELECT s.id, s.ref, s.name, s.category, s.unit, s.wh, s.qty, s.min_qty, s.mx, s.rop, s.unit_cost, s.qty * coalesce(s.unit_cost, 0),
    s.is_critical, s.lead_time_days, s.sup, round(s.use_d, 3),
    CASE WHEN s.use_d > 0 THEN round(s.qty / s.use_d, 0) ELSE NULL END,
    CASE WHEN s.qty <= 0.5 * s.min_qty THEN 'critical' WHEN s.qty <= s.min_qty THEN 'low' WHEN s.qty <= s.rop THEN 'warning' ELSE 'ok' END,
    GREATEST(0, s.mx - s.qty - s.ordered), s.ordered
  FROM s
  ORDER BY CASE WHEN s.qty <= 0.5 * s.min_qty THEN 0 WHEN s.qty <= s.min_qty THEN 1 WHEN s.qty <= s.rop THEN 2 ELSE 3 END, s.is_critical DESC, s.name;
$$;

GRANT EXECUTE ON FUNCTION keystone.geo_distance_m(numeric, numeric, numeric, numeric), keystone.tech_person(uuid),
  keystone.wo_apply_template(uuid, uuid), keystone.tech_my_day(uuid), keystone.tech_wo_detail(uuid),
  keystone.tech_check_in(uuid, numeric, numeric, numeric, uuid), keystone.tech_hold(uuid, text, uuid), keystone.tech_check_step(uuid, int, jsonb),
  keystone.tech_use_part(uuid, uuid, numeric), keystone.tech_complete(uuid, text, text, numeric, numeric, uuid),
  keystone.asset_scan(text), keystone.tech_report_issue(uuid, text, int), keystone.tech_people(), keystone.wo_templates_board()
  TO authenticated;

COMMIT;

-- ==================== 20261004_keystone_40b_field_seed.sql ====================
-- Seed démo exécution terrain : coordonnées des sites, modèles d'OT, OT du jour affectés aux techniciens. Idempotent.
BEGIN;
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_cvc uuid; tpl_filtre uuid; tpl_fuite uuid; tpl_gf uuid; tpl_led uuid;
  aka uuid; dio uuid; kof uuid; awa uuid; r record; a record; w uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  -- Coordonnées approximatives (pointage GPS : distance au site)
  UPDATE keystone.sites SET latitude = 5.3399, longitude = -4.0730 WHERE tenant_id = t AND name ILIKE '%Yopougon%' AND latitude IS NULL;
  UPDATE keystone.sites SET latitude = 5.3946, longitude = -3.9891 WHERE tenant_id = t AND name ILIKE '%Angré%' AND latitude IS NULL;
  -- Seul le numéro de l'OT existant fait foi : on recale les compteurs (idempotent) avant de créer des OT
  INSERT INTO keystone.ref_counters(tenant_id, prefix, year, n)
  SELECT tenant_id, 'WO', split_part(ref, '-', 2)::int, max(split_part(ref, '-', 3)::int) FROM keystone.work_orders
  WHERE tenant_id = t AND ref ~ '^WO-[0-9]{4}-[0-9]+$' GROUP BY 1, 3
  ON CONFLICT (tenant_id, prefix, year) DO UPDATE SET n = GREATEST(keystone.ref_counters.n, EXCLUDED.n);

  IF EXISTS (SELECT 1 FROM keystone.wo_templates WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO c_cvc FROM keystone.asset_categories WHERE tenant_id = t AND name = 'CVC';

  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, category_id, estimated_minutes, requires_permit, safety_instructions, steps, required_parts)
  VALUES (t, 'Remplacement des filtres CTA', 'preventive', c_cvc, 45, false,
    'Arrêter la CTA depuis la GTB et condamner le sectionneur avant ouverture des caissons. Port des gants et du masque FFP2.',
    '[{"label":"CTA arrêtée et sectionneur condamné","type":"check","required":true,"critical":true},
      {"label":"Photo des filtres avant remplacement","type":"photo","required":true},
      {"label":"Pression différentielle avant (Pa)","type":"numeric","min":0,"max":450,"unit":"Pa","required":true},
      {"label":"Filtres G4 remplacés et datés","type":"check","required":true},
      {"label":"Pression différentielle après (Pa)","type":"numeric","min":40,"max":150,"unit":"Pa","required":true,"critical":true},
      {"label":"Remise en service, absence de vibration","type":"check","required":true}]',
    '[{"part_ref":"FLT-G4-592","qty":4}]')
  RETURNING id INTO tpl_filtre;
  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, estimated_minutes, safety_instructions, steps, required_parts)
  VALUES (t, 'Réparation fuite sanitaire', 'corrective', 40, 'Couper l''arrivée d''eau du local. Baliser la zone glissante.',
    '[{"label":"Vanne d''arrêt fermée","type":"check","required":true,"critical":true},
      {"label":"Photo avant intervention","type":"photo","required":true},
      {"label":"Remplacement du joint / flexible","type":"check","required":true},
      {"label":"Pression d''essai (bar)","type":"numeric","min":2,"max":4,"unit":"bar","required":true,"critical":true},
      {"label":"Photo après intervention","type":"photo","required":true},
      {"label":"Zone nettoyée et sèche","type":"check","required":true}]',
    '[]')
  RETURNING id INTO tpl_fuite;
  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, category_id, estimated_minutes, requires_permit, safety_instructions, steps, required_parts)
  VALUES (t, 'Diagnostic groupe froid en défaut', 'corrective', c_cvc, 90, true,
    'Consignation électrique obligatoire (permis + VAT). Fluide frigorigène : intervention par personnel attesté F-Gas uniquement.',
    '[{"label":"Permis actif et consignation vérifiée","type":"check","required":true,"critical":true},
      {"label":"Code défaut automate relevé","type":"text","required":true},
      {"label":"Haute pression (bar)","type":"numeric","min":10,"max":16,"unit":"bar","required":true,"critical":true},
      {"label":"Température départ eau glacée (°C)","type":"numeric","min":5,"max":8,"unit":"°C","required":true},
      {"label":"Recherche de fuite au détecteur : absence de fuite","type":"check","required":true,"critical":true},
      {"label":"Photo du tableau de commande","type":"photo","required":false}]',
    '[]')
  RETURNING id INTO tpl_gf;
  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, estimated_minutes, safety_instructions, steps, required_parts)
  VALUES (t, 'Remplacement d''éclairage', 'corrective', 20, 'Travail en hauteur : escabeau 3 marches maximum, sinon PIRL. Couper le circuit au tableau.',
    '[{"label":"Circuit coupé au tableau","type":"check","required":true,"critical":true},
      {"label":"Tubes / spots remplacés","type":"check","required":true},
      {"label":"Essai d''allumage concluant","type":"check","required":true}]',
    '[{"part_ref":"LED-T8-18","qty":2}]')
  RETURNING id INTO tpl_led;

  SELECT id INTO aka FROM keystone.persons WHERE tenant_id = t AND first_name = 'Kouassi';
  SELECT id INTO dio FROM keystone.persons WHERE tenant_id = t AND first_name = 'Moussa';
  SELECT id INTO kof FROM keystone.persons WHERE tenant_id = t AND first_name = 'Salif';
  SELECT id INTO awa FROM keystone.persons WHERE tenant_id = t AND first_name = 'Awa';

  -- OT du jour (affectés), avec modèle appliqué
  FOR r IN SELECT * FROM (VALUES
    ('CTA-N1', 'Remplacement filtres CTA galerie Nord', 'preventive', 3, 'filtre', aka, 2),
    ('SUR-01', 'Fuite sur flexible — sanitaires hommes R+1', 'corrective', 2, 'fuite', aka, 4),
    ('GF-01', 'Groupe froid n°1 en défaut haute pression', 'corrective', 1, 'gf', dio, 1),
    ('CTA-N1', 'Tubes LED HS — couloir de service', 'corrective', 3, 'led', kof, 6),
    ('SUR-01', 'Fuite robinet local technique', 'corrective', 3, 'fuite', awa, 3)
  ) v(tag, title, typ, prio, tpl, person, sla_h) LOOP
    CONTINUE WHEN r.person IS NULL;
    SELECT id, legal_entity_id, location_id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    INSERT INTO keystone.work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, assignee_id,
                                     planned_start, planned_end, sla_due, currency, description)
    VALUES (t, a.legal_entity_id, keystone.next_ref('WO'), a.id, a.location_id, r.typ::keystone.wo_type, r.prio, 'assigned', r.title, r.person,
            date_trunc('day', now()) + interval '8 hours', date_trunc('day', now()) + interval '17 hours', now() + make_interval(hours => r.sla_h), 'XOF',
            'seed-terrain')
    RETURNING id INTO w;
    PERFORM keystone.wo_apply_template(w, CASE r.tpl WHEN 'filtre' THEN tpl_filtre WHEN 'fuite' THEN tpl_fuite WHEN 'gf' THEN tpl_gf ELSE tpl_led END);
  END LOOP;
END $$;
COMMIT;
