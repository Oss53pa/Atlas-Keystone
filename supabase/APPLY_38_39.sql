-- Atlas Keystone · migrations 38 (baux & portail locataire) + 39 (notifications) avec seeds démo — coller en une fois dans le SQL Editor
-- Projet vgtmljfayiysuvrcmunt · quatre transactions successives, dans l'ordre

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
