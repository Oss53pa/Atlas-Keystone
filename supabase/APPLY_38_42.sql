-- Atlas Keystone · migrations 38 (baux & portail locataire), 39 (notifications), 40 (exécution terrain), 41 (documents & paramétrage),
-- 42 (rapprochement BC / réception / facture, compteurs & grilles CIE-SODECI) + seeds
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


-- ==================== 20261004_keystone_41_documents_settings.sql ====================
-- keystone_41_documents_settings — Documents imprimables (BC, fiche d'intervention) + paramétrage par client
--   · identité légale de la société émettrice (RCCM, NCC, adresse, banque, conditions d'achat) → en-tête des documents
--   · paliers d'approbation des DA configurables (remplacent 500 k / 5 M écrits en dur) — mêmes règles, valeurs par client
--   · pondérations de l'évaluation prestataires configurables (somme contrôlée = 100 %)
--   · po_document() / wo_document() : données complètes et figées pour impression / PDF
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

CREATE TABLE IF NOT EXISTS keystone.company_profile (
  tenant_id uuid PRIMARY KEY DEFAULT keystone.current_tenant(),
  legal_name text NOT NULL,
  trade_name text,
  legal_form text,                         -- SA, SARL, SAS…
  rccm text, ncc text,                     -- registre du commerce, numéro de compte contribuable
  address text, city text, country text NOT NULL DEFAULT 'Côte d''Ivoire',
  phone text, email text, website text,
  bank_name text, bank_account text,       -- RIB affiché sur les documents (non secret)
  payment_terms_days int NOT NULL DEFAULT 30,
  purchase_terms text,                     -- conditions générales d'achat imprimées au dos / pied du BC
  document_footer text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.approval_thresholds (
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  doc_type text NOT NULL DEFAULT 'purchase_request',
  step text NOT NULL CHECK (step IN ('budget','direction')),
  min_amount numeric NOT NULL CHECK (min_amount >= 0),
  approver_label text NOT NULL,
  PRIMARY KEY (tenant_id, doc_type, step)
);
CREATE TABLE IF NOT EXISTS keystone.evaluation_weights (
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  criterion text NOT NULL CHECK (criterion IN ('quality','timing','reliability','cost','communication','innovation')),
  weight numeric NOT NULL CHECK (weight >= 0 AND weight <= 1),
  PRIMARY KEY (tenant_id, criterion)
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['company_profile','approval_thresholds','evaluation_weights'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('DROP POLICY IF EXISTS staff_write ON keystone.%I', t);
    EXECUTE format('CREATE POLICY staff_write ON keystone.%I AS RESTRICTIVE FOR UPDATE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL)', t);
    EXECUTE format('GRANT SELECT, UPDATE ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT ON keystone.company_profile TO authenticated;

-- Cohérence des paliers : le palier direction doit être au-dessus du palier budget
CREATE OR REPLACE FUNCTION keystone.trg_thresholds_check() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'keystone','public' AS $$
DECLARE b numeric; d numeric;
BEGIN
  SELECT min_amount INTO b FROM approval_thresholds WHERE tenant_id = NEW.tenant_id AND doc_type = NEW.doc_type AND step = 'budget';
  SELECT min_amount INTO d FROM approval_thresholds WHERE tenant_id = NEW.tenant_id AND doc_type = NEW.doc_type AND step = 'direction';
  IF NEW.step = 'budget' THEN b := NEW.min_amount; ELSE d := NEW.min_amount; END IF;
  IF b IS NOT NULL AND d IS NOT NULL AND d <= b THEN
    RAISE EXCEPTION 'INVALID_THRESHOLDS' USING DETAIL = 'Le seuil direction doit être supérieur au seuil budget.';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS thresholds_check ON keystone.approval_thresholds;
CREATE TRIGGER thresholds_check BEFORE INSERT OR UPDATE ON keystone.approval_thresholds FOR EACH ROW EXECUTE FUNCTION keystone.trg_thresholds_check();

-- Palier d'approbation lu dans le paramétrage du client (défauts 500 000 / 5 000 000 FCFA si non paramétré)
CREATE OR REPLACE FUNCTION keystone.pr_approval_level(p_amount numeric) RETURNS int
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT 1
    + (p_amount >= coalesce((SELECT min_amount FROM approval_thresholds WHERE tenant_id = keystone.current_tenant() AND doc_type = 'purchase_request' AND step = 'budget'), 500000))::int
    + (p_amount >= coalesce((SELECT min_amount FROM approval_thresholds WHERE tenant_id = keystone.current_tenant() AND doc_type = 'purchase_request' AND step = 'direction'), 5000000))::int;
$$;

-- Grille qualitative pondérée selon le paramétrage du client (défauts d'origine si non paramétré)
CREATE OR REPLACE FUNCTION keystone.qualitative_score(p jsonb) RETURNS numeric
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH d(criterion, w) AS (VALUES ('quality', 0.25), ('timing', 0.20), ('reliability', 0.20), ('cost', 0.15), ('communication', 0.10), ('innovation', 0.10)),
       w AS (SELECT d.criterion, coalesce(ew.weight, d.w) AS w FROM d
             LEFT JOIN evaluation_weights ew ON ew.criterion = d.criterion AND ew.tenant_id = keystone.current_tenant())
  SELECT round(sum(w.w * coalesce((p->>w.criterion)::numeric, 0)) / NULLIF(sum(w.w), 0), 1) FROM w;
$$;

-- Enregistre les pondérations en une fois (somme = 100 %)
CREATE OR REPLACE FUNCTION keystone.save_evaluation_weights(p_weights jsonb) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE k text; v numeric; total numeric := 0;
BEGIN
  IF keystone.current_lessee() IS NOT NULL OR keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  FOR k, v IN SELECT key, value::numeric FROM jsonb_each_text(p_weights) LOOP total := total + v; END LOOP;
  IF abs(total - 1) > 0.001 THEN RAISE EXCEPTION 'WEIGHTS_SUM' USING DETAIL = 'La somme des pondérations doit faire 100 % (actuellement ' || round(total * 100, 1) || ' %).'; END IF;
  FOR k, v IN SELECT key, value::numeric FROM jsonb_each_text(p_weights) LOOP
    INSERT INTO evaluation_weights(tenant_id, criterion, weight) VALUES (keystone.current_tenant(), k, v)
    ON CONFLICT (tenant_id, criterion) DO UPDATE SET weight = EXCLUDED.weight;
  END LOOP;
END $$;
GRANT INSERT ON keystone.evaluation_weights, keystone.approval_thresholds TO authenticated;

-- ===================== Documents =====================
CREATE OR REPLACE FUNCTION keystone.po_document(p_po uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'company', (SELECT row_to_json(c) FROM company_profile c WHERE c.tenant_id = o.tenant_id),
    'ref', o.ref, 'date', o.created_at, 'expected_at', o.expected_at, 'status', o.status, 'currency', o.currency,
    'pr_ref', r.ref, 'pr_title', r.title, 'urgency', r.urgency,
    'supplier', (SELECT json_build_object('name', s.name, 'tax_id', s.tax_id, 'phone', s.contact_phone, 'email', s.contact_email) FROM contractors s WHERE s.id = o.supplier_id),
    'lines', (SELECT json_agg(json_build_object('label', l.label, 'qty', l.qty_ordered, 'unit_price', l.unit_price, 'total', l.qty_ordered * l.unit_price,
                'unit', (SELECT unit FROM spare_parts sp WHERE sp.id = l.part_id)) ORDER BY l.label) FROM purchase_order_lines l WHERE l.order_id = o.id),
    'amount_ht', o.amount_ht, 'tax_rate', o.tax_rate, 'tax', o.amount_ttc - o.amount_ht, 'amount_ttc', o.amount_ttc,
    'approvals', json_build_object(
      'tech', (SELECT json_build_object('by', coalesce(u.full_name, u.email), 'at', r.tech_approved_at) FROM users u WHERE u.id = r.tech_approved_by),
      'budget', (SELECT json_build_object('by', coalesce(u.full_name, u.email), 'at', r.budget_approved_at) FROM users u WHERE u.id = r.budget_approved_by),
      'direction', (SELECT json_build_object('by', coalesce(u.full_name, u.email), 'at', r.direction_approved_at) FROM users u WHERE u.id = r.direction_approved_by)),
    'delivery', (SELECT s.name FROM sites s JOIN warehouses w ON w.site_id = s.id
                 JOIN spare_parts sp ON sp.warehouse_id = w.id JOIN purchase_order_lines l ON l.part_id = sp.id WHERE l.order_id = o.id LIMIT 1)
  ) FROM purchase_orders o JOIN purchase_requests r ON r.id = o.request_id WHERE o.id = p_po;
$$;

CREATE OR REPLACE FUNCTION keystone.wo_document(p_wo uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'company', (SELECT row_to_json(c) FROM company_profile c WHERE c.tenant_id = w.tenant_id),
    'ref', w.ref, 'title', w.title, 'description', w.description, 'type', w.type, 'status', w.status, 'priority', w.priority,
    'created_at', w.created_at, 'planned_start', w.planned_start, 'actual_start', w.actual_start, 'actual_end', w.actual_end, 'sla_due', w.sla_due,
    'site', (SELECT s.name FROM locations l JOIN sites s ON s.id = l.site_id WHERE l.id = w.location_id),
    'location', (SELECT name FROM locations WHERE id = w.location_id),
    'asset', (SELECT json_build_object('tag', a.tag, 'name', a.name, 'manufacturer', a.manufacturer, 'model', a.model, 'serial', a.serial_number) FROM assets a WHERE a.id = w.asset_id),
    'assignee', (SELECT trim(p.first_name || ' ' || p.last_name) FROM persons p WHERE p.id = w.assignee_id),
    'contractor', (SELECT name FROM contractors WHERE id = w.contractor_id),
    'safety', w.safety_instructions, 'checklist', w.checklist, 'notes', w.completion_notes, 'signed_by', w.signed_by,
    'verified_by', (SELECT coalesce(u.full_name, u.email) FROM users u WHERE u.id = w.verified_by), 'verified_at', w.verified_at,
    'permit', (SELECT json_build_object('ref', p.ref, 'type', p.type, 'status', p.status) FROM work_permits p WHERE p.work_order_id = w.id ORDER BY p.created_at DESC LIMIT 1),
    'lines', (SELECT json_agg(json_build_object('kind', l.kind, 'label', l.label, 'qty', l.qty, 'unit_cost', l.unit_cost, 'minutes', l.minutes) ORDER BY l.kind, l.created_at)
              FROM work_order_lines l WHERE l.work_order_id = w.id AND l.deleted_at IS NULL AND l.kind IN ('part','labor')),
    'time', (SELECT json_agg(json_build_object('kind', te.kind, 'at', te.at, 'distance', te.distance_to_site_m) ORDER BY te.at) FROM wo_time_entries te WHERE te.work_order_id = w.id),
    'cost_labor', w.cost_labor, 'cost_parts', w.cost_parts, 'downtime_hours', w.downtime_hours, 'currency', w.currency
  ) FROM work_orders w WHERE w.id = p_wo;
$$;

GRANT EXECUTE ON FUNCTION keystone.pr_approval_level(numeric), keystone.qualitative_score(jsonb), keystone.save_evaluation_weights(jsonb),
  keystone.po_document(uuid), keystone.wo_document(uuid) TO authenticated;

-- ===================== Valeurs initiales (démo New Heaven SA) =====================
DO $$ DECLARE t uuid := 'a0000000-0000-4000-8000-000000000001'; BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  INSERT INTO keystone.company_profile(tenant_id, legal_name, trade_name, legal_form, rccm, ncc, address, city, phone, email, bank_name, bank_account,
                                       payment_terms_days, purchase_terms, document_footer)
  VALUES (t, 'New Heaven SA', 'Cosmos — centres commerciaux', 'SA', 'CI-ABJ-2016-B-00000', '0000000 X', 'Boulevard principal, Yopougon', 'Abidjan',
          '+225 27 23 00 00 01', 'achats@cosmos-yopougon.demo', 'Banque (démo)', 'CI000 00000 000000000000 00', 30,
          'Toute livraison doit être accompagnée du bon de livraison rappelant la référence du présent bon de commande. La facture, adressée au service comptable, mentionne la référence du BC et du bon de réception. Les marchandises non conformes sont refusées à la réception. Paiement à 30 jours fin de mois après réception conforme et facture.',
          'Document généré par Atlas Keystone — données de démonstration.')
  ON CONFLICT (tenant_id) DO NOTHING;
  INSERT INTO keystone.approval_thresholds(tenant_id, doc_type, step, min_amount, approver_label) VALUES
    (t, 'purchase_request', 'budget', 500000, 'Contrôle de gestion'),
    (t, 'purchase_request', 'direction', 5000000, 'Direction générale')
  ON CONFLICT DO NOTHING;
  INSERT INTO keystone.evaluation_weights(tenant_id, criterion, weight) VALUES
    (t, 'quality', 0.25), (t, 'timing', 0.20), (t, 'reliability', 0.20), (t, 'cost', 0.15), (t, 'communication', 0.10), (t, 'innovation', 0.10)
  ON CONFLICT DO NOTHING;
END $$;

COMMIT;


-- ==================== 20261005_keystone_42_three_way_match_utilities.sql ====================
-- keystone_42_three_way_match_utilities — Rapprochement 3 voies & sous-comptage CIE / SODECI
-- A. Factures fournisseurs — rapprochement BC / réception / facture (« three-way match ») :
--   · chaque ligne facturée est confrontée à la ligne de BC (prix) ET à la quantité réellement réceptionnée
--     moins ce qui a déjà été facturé (aucune facturation au-delà du reçu)
--   · tolérances paramétrables par client (écart de prix en %, écart global en FCFA)
--   · doublons : même n° de facture fournisseur refusé en base ; même montant ± 7 j signalé (« doublon probable »)
--   · réception partielle ligne à ligne ; chaque réception relance automatiquement le rapprochement des factures du BC
--   · validation : bon à payer uniquement si rapproché ; forçage d'un écart = commentaire obligatoire ;
--     séparation des tâches : ni l'enregistreur de la facture ni le réceptionnaire ne peuvent la valider
-- B. Énergie — compteurs, sous-compteurs et grilles tarifaires :
--   · grilles CIE (électricité MT, tranches horaires + prime de puissance) et SODECI (eau, tranches progressives)
--     versionnées, INDICATIVES et modifiables — à recaler sur une facture réelle du site
--   · arborescence compteur général → sous-compteurs (lots loués, parties communes), relevés d'index
--   · bilan de sous-comptage : pertes / consommations non comptées, alerte au-delà de 10 % puis 15 %
--   · contrôle des factures CIE/SODECI : montant facturé vs montant recalculé avec la grille
--   · refacturation aux preneurs au coût moyen réel d'achat, SANS marge, versée dans l'échéancier du bail
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

-- ======================================================================
-- A. Rapprochement BC / réception / facture
-- ======================================================================
ALTER TABLE keystone.company_profile ADD COLUMN IF NOT EXISTS match_price_tolerance_pct numeric NOT NULL DEFAULT 2
  CHECK (match_price_tolerance_pct >= 0 AND match_price_tolerance_pct <= 20);
ALTER TABLE keystone.company_profile ADD COLUMN IF NOT EXISTS match_amount_tolerance numeric NOT NULL DEFAULT 10000
  CHECK (match_amount_tolerance >= 0);

CREATE TABLE IF NOT EXISTS keystone.supplier_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,                               -- référence interne FF-AAAA-####
  supplier_ref text NOT NULL,                      -- n° de facture du fournisseur
  order_id uuid NOT NULL REFERENCES keystone.purchase_orders(id),
  supplier_id uuid REFERENCES keystone.contractors(id),
  invoice_date date NOT NULL,
  due_date date NOT NULL,
  amount_ht numeric NOT NULL CHECK (amount_ht >= 0),
  tax_rate numeric NOT NULL DEFAULT 18,
  amount_ttc numeric GENERATED ALWAYS AS (round(amount_ht * (1 + tax_rate / 100))) STORED,
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  status text NOT NULL DEFAULT 'to_match' CHECK (status IN ('to_match','matched','discrepancy','approved','rejected','paid')),
  match jsonb,
  expected_ht numeric,
  variance_ht numeric,
  registered_by uuid DEFAULT auth.uid(),
  approved_by uuid, approved_at timestamptz, forced boolean NOT NULL DEFAULT false, decision_comment text,
  paid_at timestamptz, payment_ref text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_invoice_ref
  ON keystone.supplier_invoices (tenant_id, (coalesce(supplier_id, '00000000-0000-0000-0000-000000000000'::uuid)), (upper(btrim(supplier_ref))));
CREATE TABLE IF NOT EXISTS keystone.supplier_invoice_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  invoice_id uuid NOT NULL REFERENCES keystone.supplier_invoices(id) ON DELETE CASCADE,
  po_line_id uuid REFERENCES keystone.purchase_order_lines(id),   -- NULL = ligne non commandée
  label text NOT NULL,
  qty numeric NOT NULL CHECK (qty > 0),
  unit_price numeric NOT NULL CHECK (unit_price >= 0),
  line_total numeric GENERATED ALWAYS AS (qty * unit_price) STORED
);
ALTER TABLE keystone.goods_receipts ADD COLUMN IF NOT EXISTS lines jsonb;   -- détail d'une réception partielle

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['supplier_invoices','supplier_invoice_lines'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('DROP POLICY IF EXISTS staff_only ON keystone.%I', t);
    EXECUTE format('CREATE POLICY staff_only ON keystone.%I AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL)', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE keystone.supplier_invoices; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION keystone.staff_guard() RETURNS void
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
BEGIN
  IF keystone.current_lessee() IS NOT NULL OR keystone.current_contractor() IS NOT NULL THEN
    RAISE EXCEPTION 'FORBIDDEN' USING DETAIL = 'Action réservée à l''exploitant.';
  END IF;
END $$;

-- Rapprochement d'une facture : met à jour statut, attendu, écart et le détail (jsonb)
CREATE OR REPLACE FUNCTION keystone.invoice_match(p_inv uuid)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE i supplier_invoices; o purchase_orders; v_tol_pct numeric; v_tol_amt numeric;
        v_lines jsonb := '[]'::jsonb; v_issues jsonb := '[]'::jsonb; l record;
        v_expected numeric := 0; v_lines_ht numeric := 0; v_block boolean := false; v_status text; v_var numeric; v_dup record;
BEGIN
  SELECT * INTO i FROM supplier_invoices WHERE id = p_inv FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT * INTO o FROM purchase_orders WHERE id = i.order_id;
  SELECT coalesce(max(match_price_tolerance_pct), 2), coalesce(max(match_amount_tolerance), 10000)
    INTO v_tol_pct, v_tol_amt FROM company_profile;

  FOR l IN
    SELECT il.id, il.label, il.qty, il.unit_price, il.line_total, il.po_line_id,
           pol.qty_ordered, pol.qty_received, pol.qty_refused, pol.unit_price AS po_price, pol.order_id AS pol_order,
           coalesce((SELECT sum(x.qty) FROM supplier_invoice_lines x JOIN supplier_invoices xi ON xi.id = x.invoice_id
                     WHERE x.po_line_id = il.po_line_id AND xi.id <> i.id AND xi.status <> 'rejected'
                       AND (xi.created_at, xi.id) < (i.created_at, i.id)), 0) AS billed_before
    FROM supplier_invoice_lines il LEFT JOIN purchase_order_lines pol ON pol.id = il.po_line_id
    WHERE il.invoice_id = i.id ORDER BY il.label
  LOOP
    DECLARE v_code text := 'OK'; v_billable numeric; v_ok_qty numeric; v_pv numeric;
    BEGIN
      v_lines_ht := v_lines_ht + l.line_total;
      IF l.po_line_id IS NULL OR l.pol_order IS DISTINCT FROM i.order_id THEN
        v_code := 'UNORDERED'; v_block := true; v_billable := 0; v_ok_qty := 0; v_pv := NULL;
      ELSE
        v_billable := GREATEST(0, l.qty_received - l.billed_before);
        v_ok_qty := LEAST(l.qty, v_billable);
        v_pv := CASE WHEN l.po_price > 0 THEN round((l.unit_price - l.po_price) / l.po_price * 100, 2) END;
        v_expected := v_expected + v_ok_qty * l.po_price;
        IF l.qty_received = 0 THEN v_code := 'NOT_RECEIVED'; v_block := true;
        ELSIF l.qty > v_billable THEN v_code := 'QTY_OVER_RECEIVED'; v_block := true;
        ELSIF v_pv > v_tol_pct THEN v_code := 'PRICE_OVER'; v_block := true;
        ELSIF v_pv < -v_tol_pct THEN v_code := 'PRICE_UNDER';
        END IF;
      END IF;
      v_lines := v_lines || jsonb_build_object(
        'id', l.id, 'label', l.label, 'po_line_id', l.po_line_id, 'code', v_code,
        'ordered', l.qty_ordered, 'received', l.qty_received, 'refused', l.qty_refused, 'billed_before', l.billed_before,
        'billable', v_billable, 'invoiced', l.qty, 'po_price', l.po_price, 'unit_price', l.unit_price,
        'price_var_pct', v_pv, 'total', l.line_total);
    END;
  END LOOP;

  IF jsonb_array_length(v_lines) = 0 THEN
    v_issues := v_issues || jsonb_build_object('code', 'NO_LINES', 'label', 'Facture sans ligne'); v_block := true;
  END IF;
  IF o.status = 'cancelled' THEN
    v_issues := v_issues || jsonb_build_object('code', 'PO_CANCELLED', 'label', 'Bon de commande annulé'); v_block := true;
  END IF;
  IF i.supplier_id IS DISTINCT FROM o.supplier_id THEN
    v_issues := v_issues || jsonb_build_object('code', 'SUPPLIER_MISMATCH', 'label', 'Fournisseur différent de celui du BC'); v_block := true;
  END IF;
  IF abs(i.amount_ht - v_lines_ht) > 1 THEN
    v_issues := v_issues || jsonb_build_object('code', 'HEADER_MISMATCH',
      'label', format('Total HT déclaré (%s) ≠ somme des lignes (%s)', i.amount_ht, v_lines_ht)); v_block := true;
  END IF;
  SELECT x.ref, x.supplier_ref INTO v_dup FROM supplier_invoices x
   WHERE (x.created_at, x.id) < (i.created_at, i.id) AND x.status <> 'rejected' AND x.supplier_id IS NOT DISTINCT FROM i.supplier_id
     AND abs(x.amount_ht - i.amount_ht) <= 1 AND abs(x.invoice_date - i.invoice_date) <= 7 LIMIT 1;
  IF FOUND THEN
    v_issues := v_issues || jsonb_build_object('code', 'POSSIBLE_DUPLICATE',
      'label', format('Doublon probable de %s (n° fournisseur %s) : même montant à moins de 7 jours', v_dup.ref, v_dup.supplier_ref)); v_block := true;
  END IF;

  v_var := i.amount_ht - v_expected;
  IF abs(v_var) > v_tol_amt THEN
    v_issues := v_issues || jsonb_build_object('code', 'AMOUNT_VARIANCE',
      'label', format('Écart global de %s FCFA HT (tolérance %s)', round(v_var), v_tol_amt)); v_block := true;
  END IF;

  v_status := CASE WHEN i.status IN ('approved','rejected','paid') THEN i.status WHEN v_block THEN 'discrepancy' ELSE 'matched' END;
  UPDATE supplier_invoices SET status = v_status, expected_ht = v_expected, variance_ht = v_var,
    match = jsonb_build_object('lines', v_lines, 'issues', v_issues, 'tolerance_pct', v_tol_pct, 'tolerance_amount', v_tol_amt, 'at', now())
  WHERE id = i.id;

  RETURN json_build_object('status', v_status, 'expected_ht', v_expected, 'variance_ht', v_var, 'issues', v_issues, 'lines', v_lines);
END $$;

-- Notification « facture en écart » (trigger DEFINER, comme les autres déclencheurs du moteur de notifications)
CREATE OR REPLACE FUNCTION keystone.trg_notify_invoice() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF NEW.status = 'discrepancy' AND OLD.status IS DISTINCT FROM 'discrepancy' THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'invoice.discrepancy', jsonb_build_object(
      'entity_id', NEW.id, 'ref', NEW.ref, 'supplier_ref', NEW.supplier_ref,
      'po_ref', (SELECT ref FROM keystone.purchase_orders WHERE id = NEW.order_id),
      'variance', to_char(round(coalesce(NEW.variance_ht, 0)), 'FM999G999G999G990'),
      'issues', (SELECT string_agg(e->>'label', ' · ') FROM jsonb_array_elements(coalesce(NEW.match->'issues', '[]')) e)));
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_invoice ON keystone.supplier_invoices;
CREATE TRIGGER notify_invoice AFTER UPDATE OF status ON keystone.supplier_invoices FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_invoice();

-- Enregistrement d'une facture. p_lines NULL ⇒ pré-remplie sur le reçu non encore facturé, au prix du BC.
-- p_lines : [{ "po_line_id": uuid|null, "label": text, "qty": n, "unit_price": n }]
CREATE OR REPLACE FUNCTION keystone.invoice_register(p_po uuid, p_supplier_ref text, p_invoice_date date,
  p_lines jsonb DEFAULT NULL, p_amount_ht numeric DEFAULT NULL, p_tax_rate numeric DEFAULT 18, p_due_days int DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE o purchase_orders; v_id uuid; v_ref text; v_due int; v_sum numeric; e jsonb;
BEGIN
  PERFORM staff_guard();
  SELECT * INTO o FROM purchase_orders WHERE id = p_po;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF coalesce(btrim(p_supplier_ref), '') = '' THEN RAISE EXCEPTION 'SUPPLIER_REF_REQUIRED'; END IF;
  IF EXISTS (SELECT 1 FROM supplier_invoices WHERE supplier_id IS NOT DISTINCT FROM o.supplier_id
               AND upper(btrim(supplier_ref)) = upper(btrim(p_supplier_ref))) THEN
    RAISE EXCEPTION 'DUPLICATE_INVOICE' USING DETAIL = format('La facture %s de ce fournisseur est déjà enregistrée.', p_supplier_ref);
  END IF;
  SELECT coalesce(p_due_days, (SELECT payment_terms_days FROM company_profile LIMIT 1), 30) INTO v_due;
  v_ref := keystone.next_ref('FF');
  INSERT INTO supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, tax_rate, currency)
  VALUES (o.tenant_id, v_ref, btrim(p_supplier_ref), o.id, o.supplier_id, p_invoice_date, p_invoice_date + v_due, 0, coalesce(p_tax_rate, 18), o.currency)
  RETURNING id INTO v_id;

  IF p_lines IS NULL THEN
    INSERT INTO supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price)
    SELECT o.tenant_id, v_id, pol.id, pol.label, q.billable, pol.unit_price
    FROM purchase_order_lines pol
    CROSS JOIN LATERAL (SELECT pol.qty_received - coalesce((SELECT sum(x.qty) FROM supplier_invoice_lines x JOIN supplier_invoices xi ON xi.id = x.invoice_id
                         WHERE x.po_line_id = pol.id AND xi.status <> 'rejected' AND xi.id <> v_id), 0) AS billable) q
    WHERE pol.order_id = o.id AND q.billable > 0;
  ELSE
    FOR e IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
      INSERT INTO supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price)
      VALUES (o.tenant_id, v_id, nullif(e->>'po_line_id', '')::uuid,
              coalesce(nullif(e->>'label', ''), (SELECT label FROM purchase_order_lines WHERE id = nullif(e->>'po_line_id', '')::uuid), 'Ligne'),
              (e->>'qty')::numeric, (e->>'unit_price')::numeric);
    END LOOP;
  END IF;
  SELECT coalesce(sum(line_total), 0) INTO v_sum FROM supplier_invoice_lines WHERE invoice_id = v_id;
  IF v_sum = 0 AND p_amount_ht IS NULL THEN
    RAISE EXCEPTION 'NOTHING_TO_INVOICE' USING DETAIL = 'Aucune quantité réceptionnée non facturée sur ce BC.';
  END IF;
  UPDATE supplier_invoices SET amount_ht = coalesce(p_amount_ht, v_sum) WHERE id = v_id;
  RETURN (SELECT jsonb_build_object('id', v_id, 'ref', v_ref) || keystone.invoice_match(v_id)::jsonb)::json;
END $$;

-- Cycle de vie : approve (rapprochée) · force_approve (écart justifié) · reject · pay · rematch
CREATE OR REPLACE FUNCTION keystone.invoice_transition(p_inv uuid, p_action text, p_comment text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE i supplier_invoices; v_next text;
BEGIN
  PERFORM staff_guard();
  SELECT * INTO i FROM supplier_invoices WHERE id = p_inv FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;

  IF p_action IN ('approve','force_approve') THEN
    IF i.registered_by IS NOT NULL AND i.registered_by = auth.uid() THEN
      RAISE EXCEPTION 'SEGREGATION_OF_DUTIES' USING DETAIL = 'Celui qui enregistre une facture ne peut pas lui donner le bon à payer.';
    END IF;
    IF EXISTS (SELECT 1 FROM goods_receipts g WHERE g.order_id = i.order_id AND g.received_by = auth.uid()) THEN
      RAISE EXCEPTION 'SEGREGATION_OF_DUTIES' USING DETAIL = 'Le réceptionnaire des marchandises ne peut pas valider la facture correspondante.';
    END IF;
  END IF;

  IF p_action = 'rematch' AND i.status IN ('to_match','matched','discrepancy') THEN
    RETURN keystone.invoice_match(p_inv);
  ELSIF p_action = 'approve' AND i.status = 'matched' THEN
    PERFORM keystone.invoice_match(p_inv);        -- re-contrôle à l'instant de la validation
    IF (SELECT status FROM supplier_invoices WHERE id = p_inv) <> 'matched' THEN
      RAISE EXCEPTION 'MATCH_FAILED' USING DETAIL = 'Le rapprochement n''est plus conforme — voir les écarts.';
    END IF;
    UPDATE supplier_invoices SET approved_by = auth.uid(), approved_at = now(), decision_comment = p_comment WHERE id = p_inv;
    v_next := 'approved';
  ELSIF p_action = 'force_approve' AND i.status = 'discrepancy' THEN
    IF length(btrim(coalesce(p_comment, ''))) < 10 THEN
      RAISE EXCEPTION 'JUSTIFICATION_REQUIRED' USING DETAIL = 'Valider une facture en écart exige une justification (10 caractères minimum).';
    END IF;
    UPDATE supplier_invoices SET approved_by = auth.uid(), approved_at = now(), forced = true, decision_comment = p_comment WHERE id = p_inv;
    v_next := 'approved';
  ELSIF p_action = 'reject' AND i.status IN ('to_match','matched','discrepancy') THEN
    IF length(btrim(coalesce(p_comment, ''))) < 3 THEN RAISE EXCEPTION 'JUSTIFICATION_REQUIRED'; END IF;
    UPDATE supplier_invoices SET decision_comment = p_comment WHERE id = p_inv;
    v_next := 'rejected';
  ELSIF p_action = 'pay' AND i.status = 'approved' THEN
    UPDATE supplier_invoices SET paid_at = now(), payment_ref = p_comment WHERE id = p_inv;
    v_next := 'paid';
  ELSE
    RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = format('%s depuis %s', p_action, i.status);
  END IF;
  UPDATE supplier_invoices SET status = v_next WHERE id = p_inv;
  RETURN json_build_object('status', v_next);
END $$;

-- Réception partielle ligne à ligne : [{ "line_id": uuid, "qty": n, "refused": n }]
CREATE OR REPLACE FUNCTION keystone.po_receive_lines(p_po uuid, p_lines jsonb, p_qc text DEFAULT 'accepted', p_notes text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE o purchase_orders; e jsonb; l purchase_order_lines; v_q numeric; v_r numeric; v_in numeric := 0; v_left numeric; v_status po_status;
BEGIN
  PERFORM staff_guard();
  SELECT * INTO o FROM purchase_orders WHERE id = p_po FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF o.status NOT IN ('sent','confirmed','partially_received') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF p_qc NOT IN ('accepted','accepted_with_reserves','refused') THEN RAISE EXCEPTION 'INVALID_QC'; END IF;
  FOR e IN SELECT * FROM jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) LOOP
    SELECT * INTO l FROM purchase_order_lines WHERE id = (e->>'line_id')::uuid AND order_id = p_po FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND' USING DETAIL = 'Ligne hors de ce bon de commande.'; END IF;
    v_left := l.qty_ordered - l.qty_received - l.qty_refused;
    v_q := coalesce((e->>'qty')::numeric, 0); v_r := coalesce((e->>'refused')::numeric, 0);
    IF v_q < 0 OR v_r < 0 THEN RAISE EXCEPTION 'INVALID_QTY'; END IF;
    IF v_q + v_r > v_left THEN
      RAISE EXCEPTION 'OVER_RECEIPT' USING DETAIL = format('%s : %s reçus + %s refusés > %s restant à livrer', l.label, v_q, v_r, v_left);
    END IF;
    IF p_qc = 'refused' THEN v_r := v_r + v_q; v_q := 0; END IF;
    UPDATE purchase_order_lines SET qty_received = qty_received + v_q, qty_refused = qty_refused + v_r WHERE id = l.id;
    IF l.part_id IS NOT NULL AND v_q > 0 THEN
      UPDATE spare_parts SET qty = qty + v_q, updated_at = now() WHERE id = l.part_id;
      INSERT INTO stock_movements(tenant_id, part_id, qty, direction, reason) VALUES (o.tenant_id, l.part_id, v_q, 'in', 'Réception ' || o.ref);
    END IF;
    v_in := v_in + v_q;
  END LOOP;
  INSERT INTO goods_receipts(tenant_id, order_id, qc_result, notes, lines) VALUES (o.tenant_id, p_po, p_qc, p_notes, p_lines);
  SELECT CASE WHEN bool_and(qty_received + qty_refused >= qty_ordered) THEN 'received'::po_status ELSE 'partially_received'::po_status END
    INTO v_status FROM purchase_order_lines WHERE order_id = p_po;
  UPDATE purchase_orders SET status = v_status WHERE id = p_po;
  RETURN json_build_object('status', v_status, 'stock_in', v_in);
END $$;

-- Toute réception (totale ou partielle) relance le rapprochement des factures ouvertes du BC
CREATE OR REPLACE FUNCTION keystone.trg_po_line_rematch() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE r record;
BEGIN
  IF NEW.qty_received IS DISTINCT FROM OLD.qty_received OR NEW.qty_refused IS DISTINCT FROM OLD.qty_refused THEN
    FOR r IN SELECT DISTINCT si.id FROM supplier_invoices si JOIN supplier_invoice_lines il ON il.invoice_id = si.id
             WHERE il.po_line_id = NEW.id AND si.status IN ('to_match','matched','discrepancy') LOOP
      PERFORM keystone.invoice_match(r.id);
    END LOOP;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS po_line_rematch ON keystone.purchase_order_lines;
CREATE TRIGGER po_line_rematch AFTER UPDATE ON keystone.purchase_order_lines FOR EACH ROW EXECUTE FUNCTION keystone.trg_po_line_rematch();

CREATE OR REPLACE FUNCTION keystone.invoices_board()
RETURNS TABLE(id uuid, ref text, supplier_ref text, supplier text, po_id uuid, po_ref text, invoice_date date, due_date date,
  amount_ht numeric, amount_ttc numeric, expected_ht numeric, variance_ht numeric, status text, issues text[], issue_labels text[],
  forced boolean, overdue boolean, days_to_due int, approved_at timestamptz, paid_at timestamptz, decision_comment text, mine boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT i.id, i.ref, i.supplier_ref, c.name, o.id, o.ref, i.invoice_date, i.due_date, i.amount_ht, i.amount_ttc, i.expected_ht, i.variance_ht,
    i.status,
    ARRAY(SELECT DISTINCT x FROM (
      SELECT e->>'code' AS x FROM jsonb_array_elements(coalesce(i.match->'issues', '[]')) e
      UNION SELECT e->>'code' FROM jsonb_array_elements(coalesce(i.match->'lines', '[]')) e WHERE e->>'code' NOT IN ('OK','PRICE_UNDER')) z),
    ARRAY(SELECT e->>'label' FROM jsonb_array_elements(coalesce(i.match->'issues', '[]')) e),
    i.forced, i.status = 'approved' AND i.due_date < current_date, (i.due_date - current_date),
    i.approved_at, i.paid_at, i.decision_comment, i.registered_by = auth.uid()
  FROM supplier_invoices i JOIN purchase_orders o ON o.id = i.order_id LEFT JOIN contractors c ON c.id = i.supplier_id
  ORDER BY CASE i.status WHEN 'discrepancy' THEN 0 WHEN 'matched' THEN 1 WHEN 'to_match' THEN 2 WHEN 'approved' THEN 3 ELSE 4 END, i.due_date;
$$;

CREATE OR REPLACE FUNCTION keystone.invoice_detail(p_inv uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'id', i.id, 'ref', i.ref, 'supplier_ref', i.supplier_ref, 'supplier', c.name, 'po_ref', o.ref, 'po_status', o.status,
    'po_amount_ht', o.amount_ht, 'invoice_date', i.invoice_date, 'due_date', i.due_date, 'amount_ht', i.amount_ht, 'tax_rate', i.tax_rate,
    'amount_ttc', i.amount_ttc, 'expected_ht', i.expected_ht, 'variance_ht', i.variance_ht, 'status', i.status, 'forced', i.forced,
    'decision_comment', i.decision_comment, 'payment_ref', i.payment_ref, 'match', i.match,
    'receipts', (SELECT json_agg(json_build_object('at', g.received_at, 'qc', g.qc_result, 'notes', g.notes) ORDER BY g.received_at)
                 FROM goods_receipts g WHERE g.order_id = o.id),
    'approved_by', (SELECT coalesce(u.full_name, u.email) FROM users u WHERE u.id = i.approved_by), 'approved_at', i.approved_at)
  FROM supplier_invoices i JOIN purchase_orders o ON o.id = i.order_id LEFT JOIN contractors c ON c.id = i.supplier_id
  WHERE i.id = p_inv;
$$;

-- Lignes d'un BC avec reliquats (pour la saisie de réception partielle et de facture)
CREATE OR REPLACE FUNCTION keystone.po_lines_status(p_po uuid)
RETURNS TABLE(id uuid, label text, qty_ordered numeric, qty_received numeric, qty_refused numeric, qty_to_receive numeric,
  qty_invoiced numeric, qty_to_invoice numeric, unit_price numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT pol.id, pol.label, pol.qty_ordered, pol.qty_received, pol.qty_refused,
    GREATEST(0, pol.qty_ordered - pol.qty_received - pol.qty_refused),
    coalesce(inv.q, 0), GREATEST(0, pol.qty_received - coalesce(inv.q, 0)), pol.unit_price
  FROM purchase_order_lines pol
  LEFT JOIN LATERAL (SELECT sum(x.qty) AS q FROM supplier_invoice_lines x JOIN supplier_invoices xi ON xi.id = x.invoice_id
                     WHERE x.po_line_id = pol.id AND xi.status <> 'rejected') inv ON true
  WHERE pol.order_id = p_po ORDER BY pol.label;
$$;

-- Lignes de BC restant à facturer (tous BC) — utilisé par ap_summary
CREATE OR REPLACE FUNCTION keystone.po_lines_status_all()
RETURNS TABLE(order_id uuid, qty_to_invoice numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT pol.order_id, GREATEST(0, pol.qty_received - coalesce((SELECT sum(x.qty) FROM supplier_invoice_lines x
           JOIN supplier_invoices xi ON xi.id = x.invoice_id WHERE x.po_line_id = pol.id AND xi.status <> 'rejected'), 0))
  FROM purchase_order_lines pol;
$$;

CREATE OR REPLACE FUNCTION keystone.ap_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'to_review', (SELECT count(*) FROM supplier_invoices WHERE status IN ('to_match','matched')),
    'discrepancies', (SELECT count(*) FROM supplier_invoices WHERE status = 'discrepancy'),
    'discrepancy_amount', (SELECT coalesce(sum(abs(variance_ht)), 0) FROM supplier_invoices WHERE status = 'discrepancy'),
    'to_pay', (SELECT coalesce(sum(amount_ttc), 0) FROM supplier_invoices WHERE status = 'approved'),
    'overdue', (SELECT coalesce(sum(amount_ttc), 0) FROM supplier_invoices WHERE status = 'approved' AND due_date < current_date),
    'paid_month', (SELECT coalesce(sum(amount_ttc), 0) FROM supplier_invoices WHERE status = 'paid' AND paid_at >= date_trunc('month', now())),
    'auto_match_rate', (SELECT CASE WHEN count(*) = 0 THEN NULL ELSE round(100.0 * count(*) FILTER (WHERE NOT forced) / count(*)) END
                        FROM supplier_invoices WHERE status IN ('approved','paid')),
    'avoided', (SELECT coalesce(sum(GREATEST(0, variance_ht)), 0) FROM supplier_invoices WHERE status = 'rejected'),
    'po_to_invoice', (SELECT count(DISTINCT pol.order_id) FROM po_lines_status_all() pol WHERE pol.qty_to_invoice > 0)
  );
$$;

-- ======================================================================
-- B. Compteurs, sous-compteurs & grilles tarifaires
-- ======================================================================
CREATE TABLE IF NOT EXISTS keystone.utility_tariffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  code text NOT NULL,
  provider text NOT NULL,                       -- CIE, SODECI, Senelec, ENEO…
  country text NOT NULL DEFAULT 'CI',
  carrier text NOT NULL CHECK (carrier IN ('electricity','water')),
  name text NOT NULL,
  unit text NOT NULL,                           -- kWh | m3
  fixed_monthly numeric NOT NULL DEFAULT 0,     -- abonnement / redevance fixe
  demand_charge numeric NOT NULL DEFAULT 0,     -- prime de puissance, FCFA par kVA souscrit et par mois
  default_profile jsonb,                        -- répartition horaire par défaut {"offpeak":0.3,"full":0.55,"peak":0.15}
  levies jsonb NOT NULL DEFAULT '[]',           -- [{ "label": text, "pct": n }] appliqués sur le HT énergie + fixe
  vat_rate numeric NOT NULL DEFAULT 18,
  valid_from date NOT NULL DEFAULT '2025-01-01',
  is_indicative boolean NOT NULL DEFAULT true,
  source text NOT NULL,
  UNIQUE (tenant_id, code, valid_from)
);
CREATE TABLE IF NOT EXISTS keystone.utility_tariff_bands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  tariff_id uuid NOT NULL REFERENCES keystone.utility_tariffs(id) ON DELETE CASCADE,
  slot text NOT NULL DEFAULT 'all' CHECK (slot IN ('all','offpeak','full','peak')),
  from_qty numeric NOT NULL DEFAULT 0,
  to_qty numeric,                                -- NULL = sans plafond
  unit_price numeric NOT NULL CHECK (unit_price >= 0),
  label text
);
CREATE TABLE IF NOT EXISTS keystone.meters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  code text NOT NULL,
  name text NOT NULL,
  carrier text NOT NULL CHECK (carrier IN ('electricity','water')),
  unit text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('main','sub')),
  parent_id uuid REFERENCES keystone.meters(id),
  space_unit_id uuid REFERENCES keystone.space_units(id),   -- lot desservi (refacturation) ; NULL = parties communes
  usage text,                                    -- lot, CVC, éclairage, sanitaires…
  tariff_id uuid REFERENCES keystone.utility_tariffs(id),  -- compteur général : contrat fournisseur
  subscribed_kva numeric,
  multiplier numeric NOT NULL DEFAULT 1 CHECK (multiplier > 0),  -- rapport TC
  provider_contract text,                        -- n° de contrat / police CIE-SODECI
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  CHECK ((kind = 'main' AND parent_id IS NULL) OR (kind = 'sub' AND parent_id IS NOT NULL))
);
CREATE TABLE IF NOT EXISTS keystone.meter_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  meter_id uuid NOT NULL REFERENCES keystone.meters(id) ON DELETE CASCADE,
  read_at date NOT NULL,
  index_value numeric NOT NULL CHECK (index_value >= 0),
  is_reset boolean NOT NULL DEFAULT false,       -- remplacement / remise à zéro du compteur
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','photo','import','iot')),
  note text,
  read_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (meter_id, read_at)
);
CREATE TABLE IF NOT EXISTS keystone.utility_rebills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  period date NOT NULL,
  meter_id uuid NOT NULL REFERENCES keystone.meters(id),
  lease_id uuid NOT NULL REFERENCES keystone.leases(id),
  lessee_id uuid NOT NULL REFERENCES keystone.lessees(id),
  carrier text NOT NULL,
  qty numeric NOT NULL,
  unit_cost numeric NOT NULL,
  amount_ht numeric NOT NULL,
  vat_amount numeric NOT NULL,
  schedule_id uuid REFERENCES keystone.rent_schedules(id),
  posted_by uuid DEFAULT auth.uid(),
  posted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (meter_id, period)
);

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['utility_tariffs','utility_tariff_bands','meters','meter_readings','utility_rebills'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('DROP POLICY IF EXISTS staff_only ON keystone.%I', t);
    EXECUTE format('CREATE POLICY staff_only ON keystone.%I AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL)', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT, UPDATE ON keystone.utility_tariffs, keystone.utility_tariff_bands, keystone.meters TO authenticated;
GRANT DELETE ON keystone.utility_tariff_bands TO authenticated;

-- Calcul d'une facture théorique : tranches (progressives ou horaires), fixe, prime de puissance, taxes, TVA
CREATE OR REPLACE FUNCTION keystone.tariff_compute(p_tariff uuid, p_qty numeric, p_kva numeric DEFAULT NULL, p_profile jsonb DEFAULT NULL)
RETURNS json LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE t utility_tariffs; b record; v_lines jsonb := '[]'; v_energy numeric := 0; v_slot_qty numeric; v_q numeric;
        v_prof jsonb; v_fixed numeric; v_demand numeric; v_levies numeric := 0; v_lev jsonb := '[]'; e jsonb; v_ht numeric; v_base numeric;
BEGIN
  SELECT * INTO t FROM utility_tariffs WHERE id = p_tariff;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_prof := coalesce(p_profile, t.default_profile);
  FOR b IN SELECT * FROM utility_tariff_bands WHERE tariff_id = p_tariff ORDER BY slot, from_qty LOOP
    v_slot_qty := CASE WHEN b.slot = 'all' THEN p_qty ELSE p_qty * coalesce((v_prof->>b.slot)::numeric, 0) END;
    v_q := GREATEST(0, LEAST(v_slot_qty, coalesce(b.to_qty, v_slot_qty)) - b.from_qty);
    IF v_q > 0 THEN
      v_energy := v_energy + v_q * b.unit_price;
      v_lines := v_lines || jsonb_build_object('label', coalesce(b.label,
                   CASE b.slot WHEN 'offpeak' THEN 'Heures creuses' WHEN 'full' THEN 'Heures pleines' WHEN 'peak' THEN 'Heures de pointe'
                   ELSE format('Tranche %s – %s', b.from_qty, coalesce(b.to_qty::text, '∞')) END),
                 'qty', round(v_q, 2), 'unit_price', b.unit_price, 'amount', round(v_q * b.unit_price));
    END IF;
  END LOOP;
  v_fixed := t.fixed_monthly;
  v_demand := t.demand_charge * coalesce(p_kva, 0);
  v_base := v_energy + v_fixed + v_demand;
  FOR e IN SELECT * FROM jsonb_array_elements(t.levies) LOOP
    v_levies := v_levies + v_base * (e->>'pct')::numeric / 100;
    v_lev := v_lev || jsonb_build_object('label', e->>'label', 'pct', (e->>'pct')::numeric, 'amount', round(v_base * (e->>'pct')::numeric / 100));
  END LOOP;
  v_ht := round(v_base + v_levies);
  RETURN json_build_object('tariff', t.code, 'provider', t.provider, 'name', t.name, 'unit', t.unit, 'qty', p_qty, 'kva', p_kva,
    'lines', v_lines, 'energy', round(v_energy), 'fixed', round(v_fixed), 'demand', round(v_demand), 'levies', v_lev,
    'ht', v_ht, 'vat', round(v_ht * t.vat_rate / 100), 'ttc', v_ht + round(v_ht * t.vat_rate / 100),
    'avg_unit', CASE WHEN p_qty > 0 THEN round(v_ht / p_qty, 2) END, 'indicative', t.is_indicative, 'source', t.source);
END $$;

-- Consommations mensuelles par compteur (écart entre deux index successifs × multiplicateur)
CREATE OR REPLACE FUNCTION keystone.meter_consumption(p_months int DEFAULT 12)
RETURNS TABLE(meter_id uuid, period date, qty numeric, from_index numeric, to_index numeric, days int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH r AS (
    SELECT mr.meter_id, mr.read_at, mr.index_value, mr.is_reset, m.multiplier,
      lag(mr.read_at) OVER w AS prev_at, lag(mr.index_value) OVER w AS prev_idx
    FROM meter_readings mr JOIN meters m ON m.id = mr.meter_id
    WINDOW w AS (PARTITION BY mr.meter_id ORDER BY mr.read_at)
  )
  SELECT r.meter_id, date_trunc('month', r.prev_at)::date,
    round(CASE WHEN r.is_reset THEN r.index_value ELSE r.index_value - r.prev_idx END * r.multiplier, 2),
    r.prev_idx, r.index_value, (r.read_at - r.prev_at)
  FROM r
  WHERE r.prev_at IS NOT NULL AND r.prev_at >= (date_trunc('month', current_date) - make_interval(months => p_months))::date;
$$;

CREATE OR REPLACE FUNCTION keystone.meters_board()
RETURNS TABLE(id uuid, code text, name text, site text, carrier text, unit text, kind text, parent_id uuid, parent_code text,
  usage text, space_code text, lessee text, lease_id uuid, tariff text, subscribed_kva numeric, provider_contract text,
  last_read_at date, last_index numeric, last_qty numeric, avg_qty numeric, variation_pct numeric, days_since int, anomaly text, series numeric[])
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH c AS (SELECT * FROM meter_consumption(13)),
       lastp AS (SELECT DISTINCT ON (meter_id) meter_id, period, qty FROM c ORDER BY meter_id, period DESC),
       prev AS (SELECT c.meter_id, avg(c.qty) AS a FROM c JOIN lastp l ON l.meter_id = c.meter_id
                WHERE c.period < l.period AND c.period >= l.period - interval '3 months' GROUP BY c.meter_id),
       lr AS (SELECT DISTINCT ON (meter_id) meter_id, read_at, index_value FROM meter_readings ORDER BY meter_id, read_at DESC),
       occ AS (SELECT DISTINCT ON (ls.space_unit_id) ls.space_unit_id, l.id AS lease_id, coalesce(le.trade_name, le.company_name) AS lessee
               FROM lease_spaces ls JOIN leases l ON l.id = ls.lease_id JOIN lessees le ON le.id = l.lessee_id
               WHERE l.status IN ('active','notice') ORDER BY ls.space_unit_id, l.start_date DESC)
  SELECT m.id, m.code, m.name, s.name, m.carrier, m.unit, m.kind, m.parent_id, p.code, m.usage, su.code, occ.lessee, occ.lease_id,
    t.provider || ' · ' || t.name, m.subscribed_kva, m.provider_contract,
    lr.read_at, lr.index_value, lastp.qty, round(prev.a, 1),
    CASE WHEN prev.a > 0 THEN round((lastp.qty - prev.a) / prev.a * 100, 1) END,
    (current_date - lr.read_at),
    CASE WHEN lr.read_at IS NULL THEN 'NO_READING'
         WHEN current_date - lr.read_at > 40 THEN 'LATE_READING'
         WHEN prev.a > 0 AND lastp.qty > prev.a * 1.6 THEN 'SPIKE'
         WHEN prev.a > 0 AND lastp.qty < prev.a * 0.3 THEN 'DROP' END,
    ARRAY(SELECT c2.qty FROM c c2 WHERE c2.meter_id = m.id ORDER BY c2.period)
  FROM meters m JOIN sites s ON s.id = m.site_id
  LEFT JOIN meters p ON p.id = m.parent_id
  LEFT JOIN space_units su ON su.id = m.space_unit_id
  LEFT JOIN occ ON occ.space_unit_id = m.space_unit_id
  LEFT JOIN utility_tariffs t ON t.id = m.tariff_id
  LEFT JOIN lastp ON lastp.meter_id = m.id LEFT JOIN prev ON prev.meter_id = m.id LEFT JOIN lr ON lr.meter_id = m.id
  WHERE m.active
  ORDER BY s.name, m.carrier, coalesce(m.parent_id, m.id), m.kind, m.code;
$$;

-- Bilan de sous-comptage : général vs Σ sous-compteurs ⇒ pertes / non-compté
CREATE OR REPLACE FUNCTION keystone.submeter_balance(p_months int DEFAULT 6)
RETURNS TABLE(main_id uuid, main_code text, site text, carrier text, unit text, period date, main_qty numeric, sub_qty numeric,
  leased_qty numeric, common_qty numeric, unmetered_qty numeric, loss_pct numeric, status text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH c AS (SELECT * FROM meter_consumption(p_months))
  SELECT m.id, m.code, s.name, m.carrier, m.unit, cm.period, cm.qty,
    coalesce(sum(cs.qty), 0), coalesce(sum(cs.qty) FILTER (WHERE sm.space_unit_id IS NOT NULL), 0),
    coalesce(sum(cs.qty) FILTER (WHERE sm.space_unit_id IS NULL), 0),
    cm.qty - coalesce(sum(cs.qty), 0),
    CASE WHEN cm.qty > 0 THEN round((cm.qty - coalesce(sum(cs.qty), 0)) / cm.qty * 100, 1) END,
    CASE WHEN cm.qty <= 0 THEN 'no_data'
         WHEN coalesce(sum(cs.qty), 0) > cm.qty * 1.01 THEN 'inconsistent'
         WHEN (cm.qty - coalesce(sum(cs.qty), 0)) / cm.qty > 0.15 THEN 'alert'
         WHEN (cm.qty - coalesce(sum(cs.qty), 0)) / cm.qty > 0.10 THEN 'watch' ELSE 'ok' END
  FROM meters m JOIN sites s ON s.id = m.site_id
  JOIN c cm ON cm.meter_id = m.id
  LEFT JOIN meters sm ON sm.parent_id = m.id AND sm.active
  LEFT JOIN c cs ON cs.meter_id = sm.id AND cs.period = cm.period
  WHERE m.kind = 'main' AND m.active AND EXISTS (SELECT 1 FROM meters x WHERE x.parent_id = m.id AND x.active)
  GROUP BY m.id, m.code, s.name, m.carrier, m.unit, cm.period, cm.qty
  ORDER BY s.name, m.carrier, cm.period DESC;
$$;

-- Contrôle des factures CIE / SODECI saisies dans Énergie & carbone (energy_readings source = invoice)
CREATE OR REPLACE FUNCTION keystone.utility_bill_check(p_months int DEFAULT 12)
RETURNS TABLE(site text, carrier text, period date, provider text, invoiced_qty numeric, invoiced_ht numeric,
  computed_ht numeric, variance numeric, variance_pct numeric, status text, breakdown json)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT s.name, er.carrier, er.period, t.provider, er.quantity, er.cost, (x.j->>'ht')::numeric,
    er.cost - (x.j->>'ht')::numeric,
    CASE WHEN (x.j->>'ht')::numeric > 0 THEN round((er.cost - (x.j->>'ht')::numeric) / (x.j->>'ht')::numeric * 100, 1) END,
    CASE WHEN er.cost IS NULL THEN 'no_amount'
         WHEN abs(er.cost - (x.j->>'ht')::numeric) / NULLIF((x.j->>'ht')::numeric, 0) > 0.08 THEN 'alert'
         WHEN abs(er.cost - (x.j->>'ht')::numeric) / NULLIF((x.j->>'ht')::numeric, 0) > 0.04 THEN 'watch' ELSE 'ok' END,
    x.j
  FROM energy_readings er
  JOIN sites s ON s.id = er.site_id
  JOIN LATERAL (SELECT * FROM meters m WHERE m.site_id = er.site_id AND m.carrier = er.carrier AND m.kind = 'main' AND m.tariff_id IS NOT NULL
                ORDER BY m.code LIMIT 1) m ON true
  JOIN utility_tariffs t ON t.id = m.tariff_id
  CROSS JOIN LATERAL (SELECT keystone.tariff_compute(m.tariff_id, er.quantity, m.subscribed_kva) AS j) x
  WHERE er.carrier IN ('electricity','water') AND er.source = 'invoice'
    AND er.period >= (date_trunc('month', current_date) - make_interval(months => p_months))::date
  ORDER BY er.period DESC, s.name, er.carrier;
$$;

-- Refacturation d'un mois : sous-compteurs de lots loués × coût moyen réel (HT) du compteur général, sans marge
CREATE OR REPLACE FUNCTION keystone.rebill_preview(p_period date)
RETURNS TABLE(meter_id uuid, meter_code text, carrier text, unit text, space_code text, lease_id uuid, lease_ref text, lessee_id uuid, lessee text,
  qty numeric, unit_cost numeric, amount_ht numeric, vat_amount numeric, cost_basis text, posted boolean, schedule_due date)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH c AS (SELECT * FROM meter_consumption(24) WHERE period = date_trunc('month', p_period)::date),
       main AS (
         SELECT m.id, cm.qty,
           coalesce((SELECT er.cost FROM energy_readings er WHERE er.site_id = m.site_id AND er.carrier = m.carrier
                       AND er.period = date_trunc('month', p_period)::date AND er.cost IS NOT NULL),
                    (keystone.tariff_compute(m.tariff_id, cm.qty, m.subscribed_kva)->>'ht')::numeric) AS cost,
           CASE WHEN EXISTS (SELECT 1 FROM energy_readings er WHERE er.site_id = m.site_id AND er.carrier = m.carrier
                       AND er.period = date_trunc('month', p_period)::date AND er.cost IS NOT NULL) THEN 'facture' ELSE 'grille' END AS basis
         FROM meters m JOIN c cm ON cm.meter_id = m.id WHERE m.kind = 'main')
  SELECT sm.id, sm.code, sm.carrier, sm.unit, su.code, l.id, l.ref, le.id, coalesce(le.trade_name, le.company_name),
    cs.qty, round(mn.cost / NULLIF(mn.qty, 0), 2),
    round(cs.qty * mn.cost / NULLIF(mn.qty, 0)), round(cs.qty * mn.cost / NULLIF(mn.qty, 0) * l.vat_rate / 100),
    mn.basis,
    EXISTS (SELECT 1 FROM utility_rebills ur WHERE ur.meter_id = sm.id AND ur.period = date_trunc('month', p_period)::date),
    (SELECT min(rs.due_date) FROM rent_schedules rs WHERE rs.lease_id = l.id AND rs.due_date >= current_date)
  FROM meters sm
  JOIN main mn ON mn.id = sm.parent_id
  JOIN c cs ON cs.meter_id = sm.id
  JOIN space_units su ON su.id = sm.space_unit_id
  JOIN LATERAL (SELECT l.* FROM lease_spaces ls JOIN leases l ON l.id = ls.lease_id
                WHERE ls.space_unit_id = sm.space_unit_id AND l.status IN ('active','notice') ORDER BY l.start_date DESC LIMIT 1) l ON true
  JOIN lessees le ON le.id = l.lessee_id
  WHERE sm.kind = 'sub' AND sm.active AND cs.qty > 0
  ORDER BY sm.carrier, cs.qty DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.rebill_post(p_period date)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE r record; v_sched uuid; n int := 0; v_total numeric := 0; v_skipped int := 0;
BEGIN
  PERFORM staff_guard();
  FOR r IN SELECT * FROM rebill_preview(p_period) WHERE NOT posted LOOP
    v_sched := NULL;
    SELECT rs.id INTO v_sched FROM rent_schedules rs WHERE rs.lease_id = r.lease_id AND rs.due_date >= current_date
      AND rs.paid_amount = 0 ORDER BY rs.due_date LIMIT 1;
    IF v_sched IS NULL OR r.amount_ht IS NULL THEN v_skipped := v_skipped + 1; CONTINUE; END IF;
    INSERT INTO utility_rebills(tenant_id, period, meter_id, lease_id, lessee_id, carrier, qty, unit_cost, amount_ht, vat_amount, schedule_id)
    VALUES (keystone.current_tenant(), date_trunc('month', p_period)::date, r.meter_id, r.lease_id, r.lessee_id, r.carrier, r.qty, r.unit_cost,
            r.amount_ht, r.vat_amount, v_sched);
    UPDATE rent_schedules SET charges_amount = charges_amount + r.amount_ht, vat_amount = vat_amount + r.vat_amount WHERE id = v_sched;
    n := n + 1; v_total := v_total + r.amount_ht;
  END LOOP;
  RETURN json_build_object('posted', n, 'amount_ht', v_total, 'skipped', v_skipped);
END $$;

-- Relevé d'index : refus d'un index en recul (sauf remplacement), d'une date future, d'un doublon de date
CREATE OR REPLACE FUNCTION keystone.meter_record_reading(p_meter uuid, p_date date, p_index numeric, p_reset boolean DEFAULT false,
  p_note text DEFAULT NULL, p_source text DEFAULT 'manual')
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE m meters; prev meter_readings; nxt meter_readings; v_qty numeric; v_avg numeric; v_flag text;
BEGIN
  PERFORM staff_guard();
  SELECT * INTO m FROM meters WHERE id = p_meter;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF p_date > current_date THEN RAISE EXCEPTION 'FUTURE_DATE'; END IF;
  IF p_index < 0 THEN RAISE EXCEPTION 'INVALID_INDEX'; END IF;
  SELECT * INTO prev FROM meter_readings WHERE meter_id = p_meter AND read_at < p_date ORDER BY read_at DESC LIMIT 1;
  SELECT * INTO nxt FROM meter_readings WHERE meter_id = p_meter AND read_at > p_date ORDER BY read_at LIMIT 1;
  IF NOT p_reset AND prev.id IS NOT NULL AND p_index < prev.index_value THEN
    RAISE EXCEPTION 'INDEX_ROLLBACK' USING DETAIL = format('Index %s inférieur au relevé du %s (%s). Cochez « compteur remplacé » si c''est le cas.',
      p_index, to_char(prev.read_at, 'DD/MM/YYYY'), prev.index_value);
  END IF;
  IF nxt.id IS NOT NULL AND NOT nxt.is_reset AND p_index > nxt.index_value THEN
    RAISE EXCEPTION 'INDEX_ROLLBACK' USING DETAIL = format('Index %s supérieur au relevé suivant du %s (%s).', p_index, to_char(nxt.read_at, 'DD/MM/YYYY'), nxt.index_value);
  END IF;
  INSERT INTO meter_readings(tenant_id, meter_id, read_at, index_value, is_reset, note, source)
  VALUES (m.tenant_id, p_meter, p_date, p_index, p_reset, p_note, coalesce(p_source, 'manual'))
  ON CONFLICT (meter_id, read_at) DO UPDATE SET index_value = EXCLUDED.index_value, is_reset = EXCLUDED.is_reset, note = EXCLUDED.note;
  IF prev.id IS NOT NULL THEN
    v_qty := (CASE WHEN p_reset THEN p_index ELSE p_index - prev.index_value END) * m.multiplier;
    SELECT avg(qty) INTO v_avg FROM meter_consumption(6) WHERE meter_id = p_meter AND period < date_trunc('month', prev.read_at);
    v_flag := CASE WHEN v_avg > 0 AND v_qty > v_avg * 1.6 THEN 'SPIKE' WHEN v_avg > 0 AND v_qty < v_avg * 0.3 THEN 'DROP' END;
  END IF;
  RETURN json_build_object('qty', v_qty, 'avg', round(v_avg, 1), 'flag', v_flag);
END $$;

CREATE OR REPLACE FUNCTION keystone.tariffs_board()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce(json_agg(json_build_object(
    'id', t.id, 'code', t.code, 'provider', t.provider, 'country', t.country, 'carrier', t.carrier, 'name', t.name, 'unit', t.unit,
    'fixed_monthly', t.fixed_monthly, 'demand_charge', t.demand_charge, 'default_profile', t.default_profile, 'levies', t.levies,
    'vat_rate', t.vat_rate, 'valid_from', t.valid_from, 'is_indicative', t.is_indicative, 'source', t.source,
    'meters', (SELECT count(*) FROM meters m WHERE m.tariff_id = t.id),
    'bands', (SELECT json_agg(json_build_object('id', b.id, 'slot', b.slot, 'from_qty', b.from_qty, 'to_qty', b.to_qty, 'unit_price', b.unit_price, 'label', b.label)
                              ORDER BY b.slot, b.from_qty) FROM utility_tariff_bands b WHERE b.tariff_id = t.id)
  ) ORDER BY t.carrier, t.provider, t.code), '[]'::json)
  FROM utility_tariffs t;
$$;

CREATE OR REPLACE FUNCTION keystone.utilities_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH b AS (SELECT DISTINCT ON (main_id) * FROM submeter_balance(3) WHERE status <> 'no_data' ORDER BY main_id, period DESC),
       mb AS (SELECT * FROM meters_board())
  SELECT json_build_object(
    'meters', (SELECT count(*) FROM mb), 'sub_meters', (SELECT count(*) FROM mb WHERE kind = 'sub'),
    'anomalies', (SELECT count(*) FROM mb WHERE anomaly IS NOT NULL),
    'late_readings', (SELECT count(*) FROM mb WHERE anomaly IN ('LATE_READING','NO_READING')),
    'elec_loss_pct', (SELECT max(loss_pct) FROM b WHERE carrier = 'electricity'),
    'water_loss_pct', (SELECT max(loss_pct) FROM b WHERE carrier = 'water'),
    'bill_alerts', (SELECT count(*) FROM utility_bill_check(6) WHERE status = 'alert'),
    'bill_overcharge', (SELECT coalesce(sum(GREATEST(0, variance)) FILTER (WHERE status = 'alert'), 0) FROM utility_bill_check(6)),
    'last_period', (SELECT max(period) FROM b));
$$;

GRANT EXECUTE ON FUNCTION keystone.staff_guard(), keystone.invoice_match(uuid),
  keystone.invoice_register(uuid, text, date, jsonb, numeric, numeric, int), keystone.invoice_transition(uuid, text, text),
  keystone.po_receive_lines(uuid, jsonb, text, text), keystone.invoices_board(), keystone.invoice_detail(uuid), keystone.po_lines_status(uuid),
  keystone.po_lines_status_all(), keystone.ap_summary(),
  keystone.tariff_compute(uuid, numeric, numeric, jsonb), keystone.meter_consumption(int), keystone.meters_board(), keystone.submeter_balance(int),
  keystone.utility_bill_check(int), keystone.rebill_preview(date), keystone.rebill_post(date),
  keystone.meter_record_reading(uuid, date, numeric, boolean, text, text), keystone.tariffs_board(), keystone.utilities_summary()
  TO authenticated;
GRANT INSERT, UPDATE ON keystone.supplier_invoices, keystone.supplier_invoice_lines, keystone.meter_readings, keystone.utility_rebills TO authenticated;

-- Événement de notification
INSERT INTO keystone.notification_events(event_type, label, domain, default_severity, placeholders) VALUES
  ('invoice.discrepancy', 'Facture fournisseur en écart', 'Achats', 'warning', ARRAY['ref','supplier_ref','po_ref','variance','issues'])
ON CONFLICT (event_type) DO NOTHING;

COMMIT;


-- ==================== 20261005_keystone_42b_match_utilities_seed.sql ====================
-- Seed démo rapprochement 3 voies & sous-comptage (tenant démo). Idempotent.
-- Grilles CIE / SODECI : valeurs INDICATIVES de démonstration, à recaler sur une facture réelle du site.
BEGIN;
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  yop uuid; s record; s_froid uuid; s_elec uuid; s_ssi uuid;
  tf_mt uuid; tf_bt uuid; tf_eau uuid; m_main uuid; m_sub uuid; r record; k int; p date; idx numeric; q numeric; base numeric;
  pr uuid; po uuid; inv uuid; l1 uuid; l2 uuid; l3 uuid; v_spike numeric;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.meters WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO yop FROM keystone.sites WHERE tenant_id = t AND name ILIKE '%Yopougon%';

  -- ---------------- Tolérances de rapprochement ----------------
  INSERT INTO keystone.notification_rules(tenant_id, event_type, channel, audience, is_enabled)
  VALUES (t, 'invoice.discrepancy', 'in_app', 'staff', true), (t, 'invoice.discrepancy', 'email', 'staff', true)
  ON CONFLICT (tenant_id, event_type, channel, audience) DO NOTHING;
  INSERT INTO keystone.notification_templates(tenant_id, event_type, channel, locale, subject, body) VALUES
    (t, 'invoice.discrepancy', 'in_app', 'fr', 'Facture {{ref}} en écart', 'Facture {{supplier_ref}} (BC {{po_ref}}) bloquée au rapprochement : {{issues}}. Écart {{variance}} FCFA HT.'),
    (t, 'invoice.discrepancy', 'email', 'fr', 'Facture fournisseur {{supplier_ref}} bloquée au rapprochement', 'Bonjour,

La facture {{supplier_ref}} (réf. interne {{ref}}, BC {{po_ref}}) ne peut pas recevoir de bon à payer :
{{issues}}

Écart : {{variance}} FCFA HT.

Atlas Keystone'),
    (t, 'invoice.discrepancy', 'in_app', 'en', 'Invoice {{ref}} on hold', 'Invoice {{supplier_ref}} (PO {{po_ref}}) failed matching: {{issues}}. Variance {{variance}} XOF excl. VAT.')
  ON CONFLICT (tenant_id, event_type, channel, locale) DO NOTHING;
  UPDATE keystone.company_profile SET match_price_tolerance_pct = 2, match_amount_tolerance = 10000 WHERE tenant_id = t;

  -- ---------------- Grilles tarifaires (indicatives) ----------------
  INSERT INTO keystone.utility_tariffs(tenant_id, code, provider, country, carrier, name, unit, fixed_monthly, demand_charge, default_profile, levies, source)
  VALUES (t, 'CIE-MT-GEN', 'CIE', 'CI', 'electricity', 'Moyenne tension — usage général', 'kWh', 25000, 4500,
          '{"offpeak":0.30,"full":0.55,"peak":0.15}', '[{"label":"Redevances & taxes (indicatif)","pct":2}]',
          'Grille indicative Keystone (démo) — à recaler sur la dernière facture CIE du site')
  RETURNING id INTO tf_mt;
  INSERT INTO keystone.utility_tariff_bands(tenant_id, tariff_id, slot, unit_price, label) VALUES
    (t, tf_mt, 'offpeak', 55, 'Heures creuses (23 h – 7 h)'), (t, tf_mt, 'full', 78, 'Heures pleines (7 h – 19 h)'), (t, tf_mt, 'peak', 105, 'Heures de pointe (19 h – 23 h)');

  INSERT INTO keystone.utility_tariffs(tenant_id, code, provider, country, carrier, name, unit, fixed_monthly, levies, source)
  VALUES (t, 'CIE-BT-PRO', 'CIE', 'CI', 'electricity', 'Basse tension — professionnel', 'kWh', 8000,
          '[{"label":"Redevances & taxes (indicatif)","pct":2}]', 'Grille indicative Keystone (démo) — référence pour simulation des lots BT')
  RETURNING id INTO tf_bt;
  INSERT INTO keystone.utility_tariff_bands(tenant_id, tariff_id, slot, from_qty, to_qty, unit_price) VALUES
    (t, tf_bt, 'all', 0, 1000, 92), (t, tf_bt, 'all', 1000, NULL, 101);

  INSERT INTO keystone.utility_tariffs(tenant_id, code, provider, country, carrier, name, unit, fixed_monthly, levies, source)
  VALUES (t, 'SODECI-PRO', 'SODECI', 'CI', 'water', 'Eau — usage professionnel', 'm3', 10000,
          '[{"label":"Assainissement & FDE (indicatif)","pct":5}]', 'Grille indicative Keystone (démo) — à recaler sur la dernière facture SODECI du site')
  RETURNING id INTO tf_eau;
  INSERT INTO keystone.utility_tariff_bands(tenant_id, tariff_id, slot, from_qty, to_qty, unit_price) VALUES
    (t, tf_eau, 'all', 0, 500, 480), (t, tf_eau, 'all', 500, 2000, 560), (t, tf_eau, 'all', 2000, NULL, 620);

  -- ---------------- Compteurs généraux (tous sites) — index cohérents avec les factures saisies ----------------
  FOR s IN SELECT id, name FROM keystone.sites WHERE tenant_id = t LOOP
    FOR r IN SELECT * FROM (VALUES ('electricity', 'kWh', 'ELEC', tf_mt, 1000000::numeric), ('water', 'm3', 'EAU', tf_eau, 50000::numeric)) v(carrier, unit, pfx, tariff, start_idx) LOOP
      INSERT INTO keystone.meters(tenant_id, site_id, code, name, carrier, unit, kind, tariff_id, subscribed_kva, provider_contract, usage)
      VALUES (t, s.id, r.pfx || '-' || upper(left(regexp_replace((string_to_array(s.name, ' '))[array_length(string_to_array(s.name, ' '), 1)], '[^A-Za-z]', '', 'g'), 3)) || '-GEN',
              CASE r.carrier WHEN 'electricity' THEN 'Poste de livraison CIE — ' ELSE 'Compteur général SODECI — ' END || s.name,
              r.carrier, r.unit, 'main', r.tariff,
              CASE WHEN r.carrier = 'electricity' THEN CASE WHEN s.id = yop THEN 1600 ELSE 1000 END END,
              CASE r.carrier WHEN 'electricity' THEN 'CIE-MT-' ELSE 'SOD-' END || lpad((abs(hashtext(s.name)) % 1000000)::text, 6, '0'), 'Général')
      RETURNING id INTO m_main;
      idx := r.start_idx;
      FOR k IN 0..6 LOOP
        p := (date_trunc('month', current_date) - make_interval(months => 6 - k))::date;
        INSERT INTO keystone.meter_readings(tenant_id, meter_id, read_at, index_value, source) VALUES (t, m_main, p, idx, 'manual');
        IF k < 6 THEN
          SELECT quantity INTO q FROM keystone.energy_readings WHERE tenant_id = t AND site_id = s.id AND carrier = r.carrier AND period = p;
          idx := idx + coalesce(q, 0);
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  -- ---------------- Sous-compteurs du Cosmos Yopougon ----------------
  -- (code, nom, fluide, lot ou NULL = parties communes, usage, part du général)
  FOR r IN SELECT * FROM (VALUES
    ('ELEC-YOP-HYP', 'Hyper Cosmos', 'electricity', 'AGG-HYP', 'Lot', 0.300),
    ('ELEC-YOP-CINE', 'Ciné Lagune', 'electricity', 'A-R1-020', 'Lot', 0.075),
    ('ELEC-YOP-MODE', 'Mode Ivoire', 'electricity', 'A-RDC-001', 'Lot', 0.040),
    ('ELEC-YOP-POUL', 'Poulet Doré', 'electricity', 'A-R1-005', 'Lot', 0.035),
    ('ELEC-YOP-PAP', 'Pas à Pas', 'electricity', 'LOT-B12', 'Lot', 0.015),
    ('ELEC-YOP-PHAR', 'Pharmacie du Cosmos', 'electricity', 'A-RDC-022', 'Lot', 0.012),
    ('ELEC-YOP-BANQ', 'Banque Lagune', 'electricity', 'A-RDC-030', 'Lot', 0.010),
    ('ELEC-YOP-TEL', 'TélécomPlus', 'electricity', 'A-RDC-014', 'Lot', 0.006),
    ('ELEC-YOP-CVC', 'Centrale froid & CTA (parties communes)', 'electricity', NULL, 'CVC', 0.320),
    ('ELEC-YOP-ECL', 'Éclairage mail & parkings (parties communes)', 'electricity', NULL, 'Éclairage', 0.090),
    ('EAU-YOP-HYP', 'Hyper Cosmos', 'water', 'AGG-HYP', 'Lot', 0.340),
    ('EAU-YOP-POUL', 'Poulet Doré', 'water', 'A-R1-005', 'Lot', 0.070),
    ('EAU-YOP-CINE', 'Ciné Lagune', 'water', 'A-R1-020', 'Lot', 0.050),
    ('EAU-YOP-SAN', 'Sanitaires publics (parties communes)', 'water', NULL, 'Sanitaires', 0.300),
    ('EAU-YOP-EXT', 'Espaces verts & nettoyage (parties communes)', 'water', NULL, 'Extérieurs', 0.120)
  ) v(code, name, carrier, lot, usage, share) LOOP
    SELECT id INTO m_main FROM keystone.meters WHERE tenant_id = t AND site_id = yop AND carrier = r.carrier AND kind = 'main';
    INSERT INTO keystone.meters(tenant_id, site_id, code, name, carrier, unit, kind, parent_id, space_unit_id, usage)
    VALUES (t, yop, r.code, r.name, r.carrier, CASE r.carrier WHEN 'electricity' THEN 'kWh' ELSE 'm3' END, 'sub', m_main,
            (SELECT id FROM keystone.space_units WHERE tenant_id = t AND code = r.lot), r.usage)
    RETURNING id INTO m_sub;
    idx := round(1000 + abs(hashtext(r.code)) % 90000);
    FOR k IN 0..6 LOOP
      p := (date_trunc('month', current_date) - make_interval(months => 6 - k))::date;
      -- Banque Lagune : relevés interrompus depuis 2 mois (local en préavis, accès refusé)
      IF NOT (r.code = 'ELEC-YOP-BANQ' AND k >= 5) THEN
        INSERT INTO keystone.meter_readings(tenant_id, meter_id, read_at, index_value, source)
        VALUES (t, m_sub, p, idx, CASE WHEN k % 3 = 0 THEN 'photo' ELSE 'manual' END);
      END IF;
      IF k < 6 THEN
        SELECT quantity INTO q FROM keystone.energy_readings WHERE tenant_id = t AND site_id = yop AND carrier = r.carrier AND period = p;
        v_spike := 1;
        IF r.code = 'ELEC-YOP-POUL' AND k = 5 THEN v_spike := 2.3; END IF;        -- pic : friteuses supplémentaires, compresseur en défaut
        IF r.code = 'ELEC-YOP-CVC' AND k = 3 THEN v_spike := 0.75; END IF;        -- mois « fuite » : branchement non compté suspecté
        idx := idx + round(coalesce(q, 0) * r.share * v_spike * (0.97 + (abs(hashtext(r.code || k)) % 60) / 1000.0));
      END IF;
    END LOOP;
  END LOOP;

  -- Facture CIE du mois M-2 surfacturée (+15 %) — sera détectée par le contrôle de facture
  UPDATE keystone.energy_readings SET cost = round(cost * 1.15)
  WHERE tenant_id = t AND site_id = yop AND carrier = 'electricity' AND period = (date_trunc('month', current_date) - interval '2 months')::date;

  -- ---------------- Rapprochement 3 voies : BC, réceptions, factures ----------------
  SELECT id INTO s_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO s_elec FROM keystone.contractors WHERE tenant_id = t AND name = 'Électro Distribution Abidjan';
  SELECT id INTO s_ssi FROM keystone.contractors WHERE tenant_id = t AND name = 'Sécurité Feu Afrique';

  -- BC A — Électro : livré, facturé conforme, payé
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Relamping LED galerie Sud', 'manual', 'normal', 'ordered', s_elec) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_elec, 200 * 3500 + 12 * 28000, current_date - 40, now() - interval '55 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'LED-T8-18'), 'Tubes LED T8 18 W', 200, 3500) RETURNING id INTO l1;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Disjoncteurs 63 A courbe C', 12, 28000) RETURNING id INTO l2;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 200), jsonb_build_object('line_id', l2, 'qty', 12)), 'accepted', 'Livraison complète');
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FA-ED-2026-0912', po, s_elec, current_date - 35, current_date - 5, 1036000, now() - interval '35 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES
    (t, inv, l1, 'Tubes LED T8 18 W', 200, 3500), (t, inv, l2, 'Disjoncteurs 63 A courbe C', 12, 28000);
  PERFORM keystone.invoice_match(inv);
  UPDATE keystone.supplier_invoices SET status = 'paid', approved_at = now() - interval '20 days', paid_at = now() - interval '8 days', payment_ref = 'VIR-SGBCI-88412' WHERE id = inv;

  -- BC B — Frigo Services : livré ; facture avec courroies à 21 500 au lieu de 18 500 (+16 %) ⇒ écart de prix
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Révision CTA mail Est', 'manual', 'normal', 'ordered', s_froid) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_froid, 4 * 38000 + 6 * 18500 + 650000, current_date - 15, now() - interval '30 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Roulements ventilateur SKF 6308', 4, 38000) RETURNING id INTO l1;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'CRR-SPA-1250'), 'Courroies SPA 1250', 6, 18500) RETURNING id INTO l2;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Main d''œuvre révision (forfait)', 1, 650000) RETURNING id INTO l3;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 4), jsonb_build_object('line_id', l2, 'qty', 6), jsonb_build_object('line_id', l3, 'qty', 1)), 'accepted', 'PV de fin de travaux signé');
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FSC/0457/26', po, s_froid, current_date - 6, current_date + 24, 4 * 38000 + 6 * 21500 + 650000, now() - interval '6 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES
    (t, inv, l1, 'Roulements ventilateur SKF 6308', 4, 38000), (t, inv, l2, 'Courroies SPA 1250', 6, 21500), (t, inv, l3, 'Main d''œuvre révision (forfait)', 1, 650000);
  PERFORM keystone.invoice_match(inv);

  -- BC C — Sécurité Feu Afrique : 24 détecteurs reçus sur 40, mais facture des 40 ⇒ facturé > reçu
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Remplacement détecteurs SSI niveau R+1', 'manual', 'urgent', 'ordered', s_ssi) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_ssi, 40 * 24000 + 25 * 9500, current_date - 3, now() - interval '21 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'DET-OPT-FC'), 'Détecteurs optiques de fumée', 40, 24000) RETURNING id INTO l1;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Recharge extincteurs CO2 2 kg', 25, 9500) RETURNING id INTO l2;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 24), jsonb_build_object('line_id', l2, 'qty', 25)), 'accepted_with_reserves', 'Reliquat de 16 détecteurs annoncé sous 10 jours');
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'SFA-2026-118', po, s_ssi, current_date - 4, current_date + 26, 40 * 24000 + 25 * 9500, now() - interval '4 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES
    (t, inv, l1, 'Détecteurs optiques de fumée', 40, 24000), (t, inv, l2, 'Recharge extincteurs CO2 2 kg', 25, 9500);
  PERFORM keystone.invoice_match(inv);

  -- BC D — Électro : projecteurs livrés ; facture conforme à valider + une 2e facture même montant 3 jours après ⇒ doublon probable
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Projecteurs LED parking P2', 'manual', 'normal', 'ordered', s_elec) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_elec, 10 * 85000, current_date - 12, now() - interval '25 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Projecteurs LED 150 W IP66', 10, 85000) RETURNING id INTO l1;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 10)), 'accepted', NULL);
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FA-ED-2026-0951', po, s_elec, current_date - 9, current_date + 21, 850000, now() - interval '9 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES (t, inv, l1, 'Projecteurs LED 150 W IP66', 10, 85000);
  PERFORM keystone.invoice_match(inv);
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FA-ED-2026-0951-R', po, s_elec, current_date - 6, current_date + 24, 850000, now() - interval '6 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES (t, inv, l1, 'Projecteurs LED 150 W IP66', 10, 85000);
  PERFORM keystone.invoice_match(inv);

  -- BC E — Frigo Services : gaz frigorigène, facture validée, échue et non payée
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Appoint fluide R134a groupe froid n°2', 'manual', 'urgent', 'ordered', s_froid) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_froid, 3 * 145000, current_date - 50, now() - interval '60 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'R134A-13'), 'Bouteille R134a 13,6 kg', 3, 145000) RETURNING id INTO l1;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 3)), 'accepted', NULL);
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FSC/0398/26', po, s_froid, current_date - 45, current_date - 15, 435000, now() - interval '45 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES (t, inv, l1, 'Bouteille R134a 13,6 kg', 3, 145000);
  PERFORM keystone.invoice_match(inv);
  UPDATE keystone.supplier_invoices SET status = 'approved', approved_at = now() - interval '30 days' WHERE id = inv;
END $$;
COMMIT;

