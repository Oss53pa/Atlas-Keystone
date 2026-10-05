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
SET LOCAL lock_timeout = '15s';

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
ALTER TABLE keystone.lessees ENABLE ROW LEVEL SECURITY;
COMMIT;

-- Transaction courte : le verrou exclusif sur la table est relâché aussitôt (les policies Storage des photos d'OT
-- lisent keystone.users / work_orders ; un verrou tenu toute la migration provoquait un interblocage avec l'API Storage).
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

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
