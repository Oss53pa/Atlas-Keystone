-- Atlas Keystone · migrations 26c + 27 → 34b (structure + démo) · VERSION 5
-- Projet vgtmljfayiysuvrcmunt · schéma keystone uniquement · prérequis : migrations 26 + 26b (déjà appliquées)
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

-- ==================== 20261002_keystone_26c_sync_ref_counters.sql ====================
-- keystone_26c_sync_ref_counters — recale ref_counters sur les références déjà présentes
-- Les OT/tickets de démo d'origine portent des refs saisies en dur (WO-2026-000001…) sans incrément du compteur :
-- next_ref('WO') renvoyait alors une ref existante → violation uq_wo_ref. Idempotent (GREATEST).
INSERT INTO keystone.ref_counters(tenant_id, prefix, year, n)
SELECT tenant_id, split_part(ref, '-', 1), split_part(ref, '-', 2)::int, max(split_part(ref, '-', 3)::int)
FROM (
  SELECT tenant_id, ref FROM keystone.work_orders
  UNION ALL SELECT tenant_id, ref FROM keystone.service_requests
  UNION ALL SELECT tenant_id, ref FROM keystone.hsse_events
  UNION ALL SELECT tenant_id, ref FROM keystone.capa_actions
  UNION ALL SELECT tenant_id, ref FROM keystone.work_permits
) x
WHERE ref ~ '^[A-Z]+-[0-9]{4}-[0-9]+$'
GROUP BY 1, 2, 3
ON CONFLICT (tenant_id, prefix, year) DO UPDATE SET n = GREATEST(keystone.ref_counters.n, EXCLUDED.n);

-- ==================== 20261002_keystone_27_procurement_stock.sql ====================
-- keystone_27_procurement_stock — Achats & stocks (§6.15 / §7.13)
-- Porté depuis WiseFM (inventory, stock-alert-rules, purchase-requests, commandes, livraisons) et amélioré :
--   · couverture de stock RÉELLE = qty / consommation journalière moyenne 90 j (WiseFM : placeholder qty/2)
--   · niveaux d'alerte WiseFM conservés : critique ≤ 0,5×min · bas ≤ min · vigilance ≤ point de commande (déf. 1,5×min)
--   · DA générées automatiquement depuis les alertes, regroupées par fournisseur préféré (proposition, jamais d'achat auto)
--   · circuit de validation à paliers en FCFA : < 500 k → technique ; < 5 M → + budget ; ≥ 5 M → + direction
--   · contrôle budgétaire OK / LIMITE (> 80 % du disponible) / DÉPASSEMENT → interlock INSUFFICIENT_BUDGET
--   · séparation des tâches : le demandeur ne valide jamais sa propre DA (SEGREGATION_OF_DUTIES)
--   · bon de commande HT / TVA 18 % (UEMOA) / TTC ; réception avec contrôle qualité → entrée en stock atomique

-- ---------- Stock enrichi ----------
ALTER TABLE keystone.spare_parts
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'spare_part'
    CHECK (category IN ('spare_part','consumable','tool','safety','other')),
  ADD COLUMN IF NOT EXISTS unit text NOT NULL DEFAULT 'u',
  ADD COLUMN IF NOT EXISTS max_qty numeric,
  ADD COLUMN IF NOT EXISTS reorder_point numeric,
  ADD COLUMN IF NOT EXISTS is_critical boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS lead_time_days int NOT NULL DEFAULT 14,
  ADD COLUMN IF NOT EXISTS preferred_supplier_id uuid REFERENCES keystone.contractors(id);

ALTER TABLE keystone.contractors ADD COLUMN IF NOT EXISTS is_supplier boolean NOT NULL DEFAULT false;

-- ---------- Achats ----------
DO $$ BEGIN
  CREATE TYPE keystone.pr_status AS ENUM ('draft','submitted','tech_approved','budget_approved','approved','rejected','ordered');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE keystone.po_status AS ENUM ('sent','confirmed','partially_received','received','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS keystone.purchase_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  title text NOT NULL,
  justification text,
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','stock_alert','work_order','fmea')),
  urgency text NOT NULL DEFAULT 'normal' CHECK (urgency IN ('normal','urgent','critical')),
  status keystone.pr_status NOT NULL DEFAULT 'draft',
  supplier_id uuid REFERENCES keystone.contractors(id),
  budget_line_id uuid REFERENCES keystone.budget_lines(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  requested_by uuid,                       -- NULL = proposé par un agent
  tech_approved_by uuid, tech_approved_at timestamptz,
  budget_approved_by uuid, budget_approved_at timestamptz,
  direction_approved_by uuid, direction_approved_at timestamptz,
  rejected_reason text,
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.purchase_request_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  request_id uuid NOT NULL REFERENCES keystone.purchase_requests(id) ON DELETE CASCADE,
  part_id uuid REFERENCES keystone.spare_parts(id),
  label text NOT NULL,
  qty numeric NOT NULL CHECK (qty > 0),
  unit_price numeric NOT NULL CHECK (unit_price >= 0),
  line_total numeric GENERATED ALWAYS AS (qty * unit_price) STORED
);
CREATE TABLE IF NOT EXISTS keystone.purchase_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  request_id uuid NOT NULL REFERENCES keystone.purchase_requests(id),
  supplier_id uuid REFERENCES keystone.contractors(id),
  status keystone.po_status NOT NULL DEFAULT 'sent',
  amount_ht numeric NOT NULL,
  tax_rate numeric NOT NULL DEFAULT 18,
  amount_ttc numeric GENERATED ALWAYS AS (round(amount_ht * (1 + tax_rate / 100))) STORED,
  expected_at date,
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.purchase_order_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  order_id uuid NOT NULL REFERENCES keystone.purchase_orders(id) ON DELETE CASCADE,
  part_id uuid REFERENCES keystone.spare_parts(id),
  label text NOT NULL,
  qty_ordered numeric NOT NULL,
  qty_received numeric NOT NULL DEFAULT 0,
  qty_refused numeric NOT NULL DEFAULT 0,
  unit_price numeric NOT NULL
);
CREATE TABLE IF NOT EXISTS keystone.goods_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  order_id uuid NOT NULL REFERENCES keystone.purchase_orders(id),
  qc_result text NOT NULL CHECK (qc_result IN ('accepted','accepted_with_reserves','refused')),
  notes text,
  received_by uuid DEFAULT auth.uid(),
  received_at timestamptz NOT NULL DEFAULT now()
);

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['purchase_requests','purchase_request_lines','purchase_orders','purchase_order_lines','goods_receipts'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
    EXECUTE format('ALTER TABLE keystone.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE keystone.purchase_requests, keystone.purchase_orders;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------- Règles ----------
CREATE OR REPLACE FUNCTION keystone.pr_total(p_pr uuid) RETURNS numeric
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce(sum(line_total), 0) FROM purchase_request_lines WHERE request_id = p_pr;
$$;

-- Palier d'approbation (FCFA) : 1 = technique, 2 = + budget, 3 = + direction
CREATE OR REPLACE FUNCTION keystone.pr_approval_level(p_amount numeric) RETURNS int
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_amount < 500000 THEN 1 WHEN p_amount < 5000000 THEN 2 ELSE 3 END;
$$;

-- Contrôle budgétaire : OK / LIMIT (> 80 % du disponible) / OVER (> disponible) / NO_LINE
CREATE OR REPLACE FUNCTION keystone.pr_budget_check(p_pr uuid)
RETURNS json LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE r purchase_requests; v_total numeric; v_avail numeric;
BEGIN
  SELECT * INTO r FROM purchase_requests WHERE id = p_pr;
  v_total := pr_total(p_pr);
  IF r.budget_line_id IS NULL THEN RETURN json_build_object('status','NO_LINE','total',v_total,'available',NULL); END IF;
  v_avail := keystone.budget_line_available(r.budget_line_id);
  RETURN json_build_object(
    'status', CASE WHEN v_total > v_avail THEN 'OVER' WHEN v_total > 0.8 * v_avail THEN 'LIMIT' ELSE 'OK' END,
    'total', v_total, 'available', v_avail);
END $$;

-- Machine à états de la DA
CREATE OR REPLACE FUNCTION keystone.pr_transition(p_pr uuid, p_action text, p_comment text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE r purchase_requests; v_total numeric; v_level int; v_check json; v_next pr_status;
BEGIN
  SELECT * INTO r FROM purchase_requests WHERE id = p_pr FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  v_total := pr_total(p_pr);
  v_level := pr_approval_level(v_total);

  IF p_action IN ('approve_tech','approve_budget','approve_direction') AND r.requested_by IS NOT NULL AND r.requested_by = auth.uid() THEN
    RAISE EXCEPTION 'SEGREGATION_OF_DUTIES' USING DETAIL = 'Le demandeur ne peut pas valider sa propre demande d''achat.';
  END IF;

  IF p_action = 'submit' AND r.status = 'draft' THEN
    IF v_total <= 0 THEN RAISE EXCEPTION 'EMPTY_REQUEST'; END IF;
    v_next := 'submitted';
  ELSIF p_action = 'approve_tech' AND r.status = 'submitted' THEN
    UPDATE purchase_requests SET tech_approved_by = auth.uid(), tech_approved_at = now() WHERE id = p_pr;
    v_next := CASE WHEN v_level = 1 THEN 'approved' ELSE 'tech_approved' END;
  ELSIF p_action = 'approve_budget' AND r.status = 'tech_approved' THEN
    v_check := pr_budget_check(p_pr);
    IF v_check->>'status' = 'OVER' THEN
      RAISE EXCEPTION 'INSUFFICIENT_BUDGET' USING DETAIL = format('DA %s FCFA > disponible %s FCFA', v_total, v_check->>'available');
    END IF;
    UPDATE purchase_requests SET budget_approved_by = auth.uid(), budget_approved_at = now() WHERE id = p_pr;
    v_next := CASE WHEN v_level = 2 THEN 'approved' ELSE 'budget_approved' END;
  ELSIF p_action = 'approve_direction' AND r.status = 'budget_approved' THEN
    UPDATE purchase_requests SET direction_approved_by = auth.uid(), direction_approved_at = now() WHERE id = p_pr;
    v_next := 'approved';
  ELSIF p_action = 'reject' AND r.status IN ('submitted','tech_approved','budget_approved') THEN
    UPDATE purchase_requests SET rejected_reason = coalesce(p_comment, 'Rejetée') WHERE id = p_pr;
    v_next := 'rejected';
  ELSE
    RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = format('%s depuis %s', p_action, r.status);
  END IF;

  UPDATE purchase_requests SET status = v_next, updated_at = now() WHERE id = p_pr;
  RETURN json_build_object('status', v_next, 'level', v_level, 'total', v_total);
END $$;

-- DA approuvée → bon de commande (HT, TVA 18 %, TTC)
CREATE OR REPLACE FUNCTION keystone.pr_to_po(p_pr uuid)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE r purchase_requests; v_po uuid; v_ref text; v_lead int;
BEGIN
  SELECT * INTO r FROM purchase_requests WHERE id = p_pr FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF r.status <> 'approved' THEN RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = 'Seule une DA approuvée peut être commandée.'; END IF;
  SELECT coalesce(max(sp.lead_time_days), 14) INTO v_lead
    FROM purchase_request_lines l JOIN spare_parts sp ON sp.id = l.part_id WHERE l.request_id = p_pr;
  v_ref := keystone.next_ref('PO');
  INSERT INTO purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, currency)
  VALUES (r.tenant_id, v_ref, p_pr, r.supplier_id, pr_total(p_pr), current_date + v_lead, r.currency)
  RETURNING id INTO v_po;
  INSERT INTO purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price)
    SELECT r.tenant_id, v_po, part_id, label, qty, unit_price FROM purchase_request_lines WHERE request_id = p_pr;
  UPDATE purchase_requests SET status = 'ordered', updated_at = now() WHERE id = p_pr;
  RETURN json_build_object('po_id', v_po, 'ref', v_ref);
END $$;

-- Réception totale avec contrôle qualité → entrée en stock atomique (refusé ⇒ aucune entrée)
CREATE OR REPLACE FUNCTION keystone.po_receive(p_po uuid, p_qc text, p_notes text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE o purchase_orders; l record; v_in numeric := 0;
BEGIN
  SELECT * INTO o FROM purchase_orders WHERE id = p_po FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF o.status NOT IN ('sent','confirmed','partially_received') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF p_qc NOT IN ('accepted','accepted_with_reserves','refused') THEN RAISE EXCEPTION 'INVALID_QC'; END IF;
  INSERT INTO goods_receipts(tenant_id, order_id, qc_result, notes) VALUES (o.tenant_id, p_po, p_qc, p_notes);
  IF p_qc = 'refused' THEN
    UPDATE purchase_order_lines SET qty_refused = qty_ordered - qty_received WHERE order_id = p_po;
    RETURN json_build_object('status', o.status, 'stock_in', 0);
  END IF;
  FOR l IN SELECT * FROM purchase_order_lines WHERE order_id = p_po AND qty_received < qty_ordered LOOP
    UPDATE purchase_order_lines SET qty_received = qty_ordered WHERE id = l.id;
    IF l.part_id IS NOT NULL THEN
      UPDATE spare_parts SET qty = qty + (l.qty_ordered - l.qty_received), updated_at = now() WHERE id = l.part_id;
      INSERT INTO stock_movements(tenant_id, part_id, qty, direction, reason)
        VALUES (o.tenant_id, l.part_id, l.qty_ordered - l.qty_received, 'in', 'Réception ' || o.ref);
      v_in := v_in + (l.qty_ordered - l.qty_received);
    END IF;
  END LOOP;
  UPDATE purchase_orders SET status = 'received' WHERE id = p_po;
  RETURN json_build_object('status', 'received', 'stock_in', v_in);
END $$;

-- ---------- Lectures (RLS) ----------
CREATE OR REPLACE FUNCTION keystone.stock_board()
RETURNS TABLE(id uuid, ref text, name text, category text, unit text, warehouse text, qty numeric, min_qty numeric, max_qty numeric,
  reorder_point numeric, unit_cost numeric, stock_value numeric, is_critical boolean, lead_time_days int, supplier text,
  daily_use numeric, days_cover numeric, level text, suggested_qty numeric, on_order numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH s AS (
    SELECT sp.*, w.name AS wh, c.name AS sup,
      coalesce(sp.reorder_point, sp.min_qty * 1.5) AS rop,
      coalesce(sp.max_qty, sp.min_qty * 4) AS mx,
      (SELECT coalesce(sum(m.qty), 0) / 90.0 FROM stock_movements m
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

CREATE OR REPLACE FUNCTION keystone.pr_board()
RETURNS TABLE(id uuid, ref text, title text, source text, urgency text, status keystone.pr_status, supplier text, total numeric,
  level int, budget_status text, budget_available numeric, lines int, requested_by_agent boolean, rejected_reason text, created_at timestamptz,
  po_ref text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT r.id, r.ref, r.title, r.source, r.urgency, r.status, c.name, pr_total(r.id), pr_approval_level(pr_total(r.id)),
    pr_budget_check(r.id)->>'status', (pr_budget_check(r.id)->>'available')::numeric,
    (SELECT count(*) FROM purchase_request_lines l WHERE l.request_id = r.id)::int, r.requested_by IS NULL, r.rejected_reason, r.created_at,
    (SELECT po.ref FROM purchase_orders po WHERE po.request_id = r.id LIMIT 1)
  FROM purchase_requests r LEFT JOIN contractors c ON c.id = r.supplier_id
  ORDER BY CASE r.status WHEN 'submitted' THEN 0 WHEN 'tech_approved' THEN 1 WHEN 'budget_approved' THEN 2 WHEN 'approved' THEN 3 WHEN 'draft' THEN 4 ELSE 5 END,
    CASE r.urgency WHEN 'critical' THEN 0 WHEN 'urgent' THEN 1 ELSE 2 END, r.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.po_board()
RETURNS TABLE(id uuid, ref text, pr_ref text, supplier text, status keystone.po_status, amount_ht numeric, amount_ttc numeric,
  expected_at date, late boolean, qc_result text, created_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT o.id, o.ref, r.ref, c.name, o.status, o.amount_ht, o.amount_ttc, o.expected_at,
    o.status IN ('sent','confirmed','partially_received') AND o.expected_at < current_date,
    (SELECT g.qc_result FROM goods_receipts g WHERE g.order_id = o.id ORDER BY g.received_at DESC LIMIT 1), o.created_at
  FROM purchase_orders o JOIN purchase_requests r ON r.id = o.request_id LEFT JOIN contractors c ON c.id = o.supplier_id
  ORDER BY o.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.procurement_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'stock_value', (SELECT coalesce(sum(qty * coalesce(unit_cost, 0)), 0) FROM spare_parts WHERE deleted_at IS NULL),
    'parts', (SELECT count(*) FROM spare_parts WHERE deleted_at IS NULL),
    'alerts', (SELECT count(*) FROM stock_board() WHERE level <> 'ok'),
    'critical_alerts', (SELECT count(*) FROM stock_board() WHERE level = 'critical' OR (level <> 'ok' AND is_critical)),
    'pr_pending', (SELECT count(*) FROM purchase_requests WHERE status IN ('submitted','tech_approved','budget_approved')),
    'pr_pending_amount', (SELECT coalesce(sum(pr_total(id)), 0) FROM purchase_requests WHERE status IN ('submitted','tech_approved','budget_approved')),
    'po_open', (SELECT count(*) FROM purchase_orders WHERE status IN ('sent','confirmed','partially_received')),
    'po_late', (SELECT count(*) FROM purchase_orders WHERE status IN ('sent','confirmed','partially_received') AND expected_at < current_date)
  );
$$;

-- Agent réappro : propose des DA (brouillon) depuis les alertes, une par fournisseur préféré. Jamais de commande automatique.
CREATE OR REPLACE FUNCTION keystone.pr_from_stock_alerts()
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE g record; v_pr uuid; n int := 0;
BEGIN
  FOR g IN
    SELECT sp.preferred_supplier_id AS sup, bool_or(b.level = 'critical' OR b.is_critical) AS crit
    FROM stock_board() b JOIN spare_parts sp ON sp.id = b.id
    WHERE b.level <> 'ok' AND b.suggested_qty > 0
      AND NOT EXISTS (SELECT 1 FROM purchase_request_lines l JOIN purchase_requests r ON r.id = l.request_id
                      WHERE l.part_id = b.id AND r.status IN ('draft','submitted','tech_approved','budget_approved','approved'))
    GROUP BY sp.preferred_supplier_id
  LOOP
    INSERT INTO purchase_requests(tenant_id, ref, title, justification, source, urgency, supplier_id, requested_by)
    VALUES (keystone.current_tenant(), keystone.next_ref('PR'), 'Réapprovisionnement — alertes de stock',
            'Proposée par l''agent Réappro : articles sous le point de commande.', 'stock_alert',
            CASE WHEN g.crit THEN 'urgent' ELSE 'normal' END, g.sup, NULL)
    RETURNING id INTO v_pr;
    INSERT INTO purchase_request_lines(tenant_id, request_id, part_id, label, qty, unit_price)
      SELECT keystone.current_tenant(), v_pr, b.id, b.ref || ' · ' || b.name, b.suggested_qty, coalesce(b.unit_cost, 0)
      FROM stock_board() b JOIN spare_parts sp ON sp.id = b.id
      WHERE b.level <> 'ok' AND b.suggested_qty > 0 AND sp.preferred_supplier_id IS NOT DISTINCT FROM g.sup
        AND NOT EXISTS (SELECT 1 FROM purchase_request_lines l JOIN purchase_requests r ON r.id = l.request_id
                        WHERE l.part_id = b.id AND r.id <> v_pr AND r.status IN ('draft','submitted','tech_approved','budget_approved','approved'));
    n := n + 1;
  END LOOP;
  RETURN json_build_object('created', n);
END $$;

GRANT EXECUTE ON FUNCTION keystone.pr_total(uuid), keystone.pr_approval_level(numeric), keystone.pr_budget_check(uuid),
  keystone.pr_transition(uuid, text, text), keystone.pr_to_po(uuid), keystone.po_receive(uuid, text, text),
  keystone.stock_board(), keystone.pr_board(), keystone.po_board(), keystone.procurement_summary(), keystone.pr_from_stock_alerts()
  TO authenticated;
GRANT INSERT, UPDATE ON keystone.purchase_requests, keystone.purchase_request_lines, keystone.purchase_orders,
  keystone.purchase_order_lines, keystone.goods_receipts TO authenticated;
GRANT UPDATE ON keystone.spare_parts TO authenticated;
GRANT INSERT ON keystone.stock_movements TO authenticated;

-- ==================== 20261002_keystone_27b_procurement_seed.sql ====================
-- Seed démo achats & stocks (tenant New Heaven SA). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  wh uuid; s_froid uuid; s_elec uuid; s_ssi uuid; bl uuid; pr uuid; p record;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  SELECT id INTO wh FROM keystone.warehouses WHERE tenant_id = t ORDER BY created_at LIMIT 1;
  SELECT id INTO bl FROM keystone.budget_lines WHERE tenant_id = t LIMIT 1;

  INSERT INTO keystone.contractors(tenant_id, name, prequalified, rating, is_supplier)
  SELECT t, n, true, r, true FROM (VALUES ('Frigo Services CI', 4.4), ('Électro Distribution Abidjan', 4.1), ('Sécurité Feu Afrique', 4.6)) v(n, r)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.contractors WHERE tenant_id = t AND name = v.n);
  SELECT id INTO s_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO s_elec FROM keystone.contractors WHERE tenant_id = t AND name = 'Électro Distribution Abidjan';
  SELECT id INTO s_ssi FROM keystone.contractors WHERE tenant_id = t AND name = 'Sécurité Feu Afrique';

  UPDATE keystone.spare_parts SET is_critical = true, preferred_supplier_id = s_froid, lead_time_days = 45, max_qty = 3, category = 'spare_part'
    WHERE tenant_id = t AND ref = 'CRG-COMP-02';

  INSERT INTO keystone.spare_parts(tenant_id, warehouse_id, ref, name, category, unit, qty, min_qty, max_qty, reorder_point, unit_cost, currency,
                                   is_critical, lead_time_days, preferred_supplier_id)
  SELECT t, wh, v.ref, v.name, v.cat, v.unit, v.qty, v.mn, v.mx, v.rop, v.cost, 'XOF', v.crit, v.lead, v.sup
  FROM (VALUES
    ('FLT-G4-592', 'Filtre G4 592×592 (CTA)', 'consumable', 'u', 6, 12, 48, 18, 9500, false, 10, s_froid),
    ('R134A-13', 'Fluide R134a bouteille 13,6 kg', 'consumable', 'u', 1, 2, 6, 3, 145000, true, 21, s_froid),
    ('CRR-SPA-1250', 'Courroie SPA 1250', 'spare_part', 'u', 4, 4, 12, 6, 18500, false, 7, s_froid),
    ('BAT-GE-12V', 'Batterie démarrage GE 12 V 200 Ah', 'spare_part', 'u', 0, 2, 4, 2, 210000, true, 14, s_elec),
    ('FUS-HPC-63', 'Fusible HPC 63 A', 'spare_part', 'u', 22, 10, 40, 15, 4200, false, 5, s_elec),
    ('LED-T8-18', 'Tube LED T8 18 W', 'consumable', 'u', 35, 40, 160, 60, 3800, false, 10, s_elec),
    ('DET-OPT-FC', 'Détecteur optique de fumée', 'safety', 'u', 3, 8, 24, 12, 62000, true, 30, s_ssi),
    ('EPI-HARN', 'Harnais antichute EN 361', 'safety', 'u', 5, 4, 10, 5, 48000, false, 14, s_ssi),
    ('JNT-GM-35', 'Garniture mécanique Ø35 surpresseur', 'spare_part', 'u', 2, 1, 3, 1, 87000, false, 30, s_froid)
  ) v(ref, name, cat, unit, qty, mn, mx, rop, cost, crit, lead, sup)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.spare_parts WHERE tenant_id = t AND ref = v.ref);

  -- Consommations 90 j (sorties) pour calculer la couverture réelle
  IF NOT EXISTS (SELECT 1 FROM keystone.stock_movements WHERE tenant_id = t AND reason = 'seed-conso') THEN
    FOR p IN SELECT id, ref FROM keystone.spare_parts WHERE tenant_id = t LOOP
      INSERT INTO keystone.stock_movements(tenant_id, part_id, qty, direction, reason, at)
      SELECT t, p.id,
        CASE p.ref WHEN 'FLT-G4-592' THEN 4 WHEN 'LED-T8-18' THEN 9 WHEN 'FUS-HPC-63' THEN 2 WHEN 'CRR-SPA-1250' THEN 1
                   WHEN 'DET-OPT-FC' THEN 1 WHEN 'R134A-13' THEN 1 ELSE 0 END,
        'out', 'seed-conso', now() - (g * interval '15 days')
      FROM generate_series(1, 5) g
      WHERE p.ref IN ('FLT-G4-592','LED-T8-18','FUS-HPC-63','CRR-SPA-1250','DET-OPT-FC','R134A-13');
    END LOOP;
  END IF;

  -- Une DA manuelle soumise (palier 2 : technique + budget)
  IF NOT EXISTS (SELECT 1 FROM keystone.purchase_requests WHERE tenant_id = t AND title = 'Kit révision CTA galerie Nord') THEN
    INSERT INTO keystone.purchase_requests(tenant_id, ref, title, justification, source, urgency, status, supplier_id, budget_line_id)
    VALUES (t, keystone.next_ref('PR'), 'Kit révision CTA galerie Nord', 'Révision annuelle — plan de maintenance CTA-N1', 'manual', 'normal', 'submitted', s_froid, bl)
    RETURNING id INTO pr;
    INSERT INTO keystone.purchase_request_lines(tenant_id, request_id, label, qty, unit_price) VALUES
      (t, pr, 'Roulements ventilateur SKF 6308', 4, 38000), (t, pr, 'Courroies SPA 1250', 6, 18500), (t, pr, 'Main d''œuvre révision (forfait)', 1, 650000);
  END IF;
END $$;

-- ==================== 20261002_keystone_28_energy_carbon.sql ====================
-- keystone_28_energy_carbon — Énergie & carbone (ISO 50001 / GHG Protocol)
-- Porté depuis WiseFM (consumption, carbon-footprint, env-indicators) et amélioré :
--   · facteurs d'émission versionnés PAR PAYS (packs CI/SN/CM…) et sourcés — WiseFM : table figée France/ADEME
--   · scope 1 inclut les fuites de fluides frigorigènes (kg × PRG) ; scope 2 électricité réseau ; scope 3 eau/déchets
--   · intensité énergétique EnPI = kWh / m² (surfaces réelles du Space Management)
--   · objectifs mensuels avec statut WiseFM : ≥ critique → critique ; ≥ alerte → alerte ; ≤ cible → conforme ; sinon attention
--   · relevés validés (validated) seuls comptés dans le bilan officiel ; les autres apparaissent « à valider »

CREATE TABLE IF NOT EXISTS keystone.emission_factors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country text NOT NULL,                 -- ISO 3166 alpha-2, '*' = valeur générique
  carrier text NOT NULL,                 -- electricity | diesel | lpg | water | refrigerant_r134a | refrigerant_r410a | refrigerant_r404a | waste_dib
  scope int NOT NULL CHECK (scope IN (1, 2, 3)),
  unit text NOT NULL,                    -- kWh | L | m3 | kg | t
  kg_co2e_per_unit numeric NOT NULL,
  source text NOT NULL,
  is_indicative boolean NOT NULL DEFAULT true,
  valid_from date NOT NULL DEFAULT '2024-01-01',
  UNIQUE (country, carrier, valid_from)
);
GRANT SELECT ON keystone.emission_factors TO authenticated;

CREATE TABLE IF NOT EXISTS keystone.energy_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  carrier text NOT NULL,
  period date NOT NULL,                  -- 1er jour du mois
  quantity numeric NOT NULL CHECK (quantity >= 0),
  unit text NOT NULL,
  cost numeric,
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','invoice','sensor','import')),
  validated boolean NOT NULL DEFAULT false,
  validated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, site_id, carrier, period)
);
CREATE TABLE IF NOT EXISTS keystone.energy_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  carrier text NOT NULL,
  monthly_target numeric NOT NULL,
  alert_threshold numeric NOT NULL,
  critical_threshold numeric NOT NULL,
  CHECK (monthly_target <= alert_threshold AND alert_threshold <= critical_threshold),
  UNIQUE (tenant_id, site_id, carrier)
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['energy_readings','energy_targets'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT UPDATE (validated, validated_by) ON keystone.energy_readings TO authenticated;

-- Pays d'un site : colonne country si présente, sinon 'CI' (pack par défaut du tenant démo)
CREATE OR REPLACE FUNCTION keystone.site_country(p_site uuid) RETURNS text
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce((SELECT to_jsonb(s)->>'country' FROM sites s WHERE s.id = p_site), 'CI');
$$;

-- Facteur applicable : pays du site, sinon générique, à la date de la période
CREATE OR REPLACE FUNCTION keystone.emission_factor(p_country text, p_carrier text, p_at date)
RETURNS keystone.emission_factors LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT * FROM emission_factors
  WHERE carrier = p_carrier AND country IN (p_country, '*') AND valid_from <= p_at
  ORDER BY (country = p_country) DESC, valid_from DESC LIMIT 1;
$$;

CREATE OR REPLACE VIEW keystone.v_energy_emissions WITH (security_invoker = true) AS
  SELECT r.*, f.scope, f.kg_co2e_per_unit, f.source AS factor_source, f.is_indicative,
    r.quantity * coalesce(f.kg_co2e_per_unit, 0) AS kg_co2e,
    CASE WHEN r.carrier = 'electricity' THEN r.quantity
         WHEN r.carrier = 'diesel' THEN r.quantity * 9.96      -- PCI gazole ≈ 9,96 kWh/L
         WHEN r.carrier = 'lpg' THEN r.quantity * 7.08          -- PCI GPL ≈ 7,08 kWh/L
         ELSE 0 END AS kwh_final
  FROM keystone.energy_readings r
  LEFT JOIN LATERAL (SELECT * FROM keystone.emission_factor(keystone.site_country(r.site_id), r.carrier, r.period)) f ON true;
GRANT SELECT ON keystone.v_energy_emissions TO authenticated;

CREATE OR REPLACE FUNCTION keystone.energy_monthly(p_months int DEFAULT 12)
RETURNS TABLE(period date, carrier text, quantity numeric, unit text, kwh numeric, kg_co2e numeric, cost numeric, validated boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT e.period, e.carrier, sum(e.quantity), min(e.unit), sum(e.kwh_final), round(sum(e.kg_co2e)), sum(coalesce(e.cost, 0)), bool_and(e.validated)
  FROM v_energy_emissions e
  WHERE e.period >= date_trunc('month', current_date) - make_interval(months => p_months - 1)
  GROUP BY e.period, e.carrier ORDER BY e.period, e.carrier;
$$;

CREATE OR REPLACE FUNCTION keystone.energy_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH cur AS (SELECT * FROM v_energy_emissions WHERE period >= date_trunc('month', current_date) - interval '11 months'),
       prev AS (SELECT * FROM v_energy_emissions WHERE period >= date_trunc('month', current_date) - interval '23 months'
                                                  AND period < date_trunc('month', current_date) - interval '11 months'),
       surf AS (SELECT coalesce(sum(surface_m2), 0) AS m2 FROM space_units WHERE deleted_at IS NULL)
  SELECT json_build_object(
    'kwh_12m', (SELECT round(sum(kwh_final)) FROM cur),
    'kwh_prev_12m', (SELECT round(sum(kwh_final)) FROM prev),
    'cost_12m', (SELECT coalesce(sum(cost), 0) FROM cur),
    't_co2e_12m', (SELECT round(sum(kg_co2e) / 1000, 1) FROM cur),
    't_co2e_prev_12m', (SELECT round(sum(kg_co2e) / 1000, 1) FROM prev),
    'scope1_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE scope = 1), 0) / 1000, 1) FROM cur),
    'scope2_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE scope = 2), 0) / 1000, 1) FROM cur),
    'scope3_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE scope = 3), 0) / 1000, 1) FROM cur),
    'refrigerant_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE carrier LIKE 'refrigerant%'), 0) / 1000, 1) FROM cur),
    'surface_m2', (SELECT m2 FROM surf),
    'intensity_kwh_m2', (SELECT CASE WHEN surf.m2 > 0 THEN round((SELECT sum(kwh_final) FROM cur) / surf.m2, 1) END FROM surf),
    'to_validate', (SELECT count(*) FROM energy_readings WHERE NOT validated),
    'indicative_factors', (SELECT bool_or(is_indicative) FROM cur)
  );
$$;

-- Suivi des objectifs (dernier mois clos) avec la règle de statut WiseFM
CREATE OR REPLACE FUNCTION keystone.energy_targets_status()
RETURNS TABLE(site text, carrier text, unit text, period date, actual numeric, target numeric, alert numeric, critical numeric, status text, gap_pct numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT s.name, t.carrier, r.unit, r.period, r.quantity, t.monthly_target, t.alert_threshold, t.critical_threshold,
    CASE WHEN r.quantity IS NULL THEN 'no_data'
         WHEN r.quantity >= t.critical_threshold THEN 'critical'
         WHEN r.quantity >= t.alert_threshold THEN 'alert'
         WHEN r.quantity <= t.monthly_target THEN 'compliant'
         ELSE 'watch' END,
    round(100.0 * (r.quantity - t.monthly_target) / NULLIF(t.monthly_target, 0), 1)
  FROM energy_targets t
  JOIN sites s ON s.id = t.site_id
  LEFT JOIN LATERAL (SELECT * FROM energy_readings er WHERE er.site_id = t.site_id AND er.carrier = t.carrier
                     ORDER BY er.period DESC LIMIT 1) r ON true
  ORDER BY s.name, t.carrier;
$$;

CREATE OR REPLACE FUNCTION keystone.energy_validate(p_id uuid) RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  UPDATE energy_readings SET validated = true, validated_by = auth.uid() WHERE id = p_id;
$$;

GRANT EXECUTE ON FUNCTION keystone.site_country(uuid), keystone.emission_factor(text, text, date), keystone.energy_monthly(int),
  keystone.energy_summary(), keystone.energy_targets_status(), keystone.energy_validate(uuid) TO authenticated;

-- ---------- Référentiel de facteurs (INDICATIFS — à remplacer par les facteurs officiels de chaque pays) ----------
INSERT INTO keystone.emission_factors(country, carrier, scope, unit, kg_co2e_per_unit, source, is_indicative) VALUES
  ('*',  'diesel',            1, 'L',  2.51,  'ADEME Base Empreinte (gazole, combustion)', true),
  ('*',  'lpg',               1, 'L',  1.51,  'ADEME Base Empreinte (propane)', true),
  ('*',  'refrigerant_r134a', 1, 'kg', 1430,  'GIEC AR4 — PRG 100 ans', false),
  ('*',  'refrigerant_r410a', 1, 'kg', 2088,  'GIEC AR4 — PRG 100 ans', false),
  ('*',  'refrigerant_r404a', 1, 'kg', 3922,  'GIEC AR4 — PRG 100 ans', false),
  ('*',  'electricity',       2, 'kWh', 0.475, 'Moyenne mondiale (repli)', true),
  ('*',  'water',             3, 'm3', 0.132, 'ADEME (eau potable)', true),
  ('CI', 'electricity',       2, 'kWh', 0.43,  'Indicatif — mix réseau Côte d''Ivoire, à valider', true),
  ('SN', 'electricity',       2, 'kWh', 0.60,  'Indicatif — mix réseau Sénégal, à valider', true),
  ('CM', 'electricity',       2, 'kWh', 0.20,  'Indicatif — mix réseau Cameroun (hydro), à valider', true)
ON CONFLICT (country, carrier, valid_from) DO NOTHING;

-- ==================== 20261002_keystone_28b_energy_seed.sql ====================
-- Seed démo énergie (24 mois, 2 sites) — saisonnalité CVC et délestages. Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  s record; m int; p date; season numeric; scale numeric;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  FOR s IN SELECT id, name FROM keystone.sites WHERE tenant_id = t LOOP
    scale := CASE WHEN s.name ILIKE '%Yopougon%' THEN 1.0 ELSE 0.62 END;
    FOR m IN 0..23 LOOP
      p := (date_trunc('month', current_date) - make_interval(months => m + 1))::date;
      -- pic de chaleur mars–mai, creux juillet–septembre (saison des pluies)
      season := CASE extract(month FROM p)::int WHEN 3 THEN 1.18 WHEN 4 THEN 1.22 WHEN 5 THEN 1.15 WHEN 7 THEN 0.88 WHEN 8 THEN 0.86 WHEN 9 THEN 0.9 ELSE 1.0 END;
      INSERT INTO keystone.energy_readings(tenant_id, site_id, carrier, period, quantity, unit, cost, source, validated)
      VALUES
        (t, s.id, 'electricity', p, round(scale * 380000 * season * (1 - 0.04 * (m < 12)::int)), 'kWh',
            round(scale * 380000 * season * 92), 'invoice', m >= 2),
        (t, s.id, 'diesel', p, round(scale * CASE WHEN extract(month FROM p)::int IN (3,4,5) THEN 4200 ELSE 1600 END), 'L',
            round(scale * CASE WHEN extract(month FROM p)::int IN (3,4,5) THEN 4200 ELSE 1600 END * 715), 'manual', m >= 2),
        (t, s.id, 'water', p, round(scale * 2800 * (0.95 + 0.1 * random())), 'm3', round(scale * 2800 * 600), 'invoice', m >= 2)
      ON CONFLICT (tenant_id, site_id, carrier, period) DO NOTHING;
      IF m IN (4, 15) AND s.name ILIKE '%Yopougon%' THEN
        INSERT INTO keystone.energy_readings(tenant_id, site_id, carrier, period, quantity, unit, source, validated)
        VALUES (t, s.id, 'refrigerant_r134a', p, CASE m WHEN 4 THEN 18 ELSE 9 END, 'kg', 'manual', true)
        ON CONFLICT (tenant_id, site_id, carrier, period) DO NOTHING;
      END IF;
    END LOOP;
    INSERT INTO keystone.energy_targets(tenant_id, site_id, carrier, monthly_target, alert_threshold, critical_threshold)
    VALUES (t, s.id, 'electricity', round(scale * 360000), round(scale * 400000), round(scale * 440000)),
           (t, s.id, 'diesel', round(scale * 1500), round(scale * 2500), round(scale * 4000)),
           (t, s.id, 'water', round(scale * 2700), round(scale * 3000), round(scale * 3400))
    ON CONFLICT (tenant_id, site_id, carrier) DO NOTHING;
  END LOOP;
END $$;

-- ==================== 20261002_keystone_29_inspections_nc.sql ====================
-- keystone_29_inspections_nc — Rondes d'inspection & non-conformités (ISO 9001 §10.2 / ISO 45001 §10.2)
-- Porté depuis WiseFM (inspection-templates, inspections, non-conformities) et amélioré :
--   · points de contrôle typés : boolean | numeric (plage min/max + unité) | choice | text ; required ; critical
--   · score pondéré : un point critique compte ×3 (WiseFM : moyenne simple)
--   · chaque point en échec ouvre automatiquement une NC ; échéance selon gravité (critique 2 j · majeure 7 j · mineure 30 j)
--   · NC critique sur un équipement → OT correctif en BROUILLON (garde-fou : planification humaine)
--   · interlock ACTION_REQUIRED : une NC ne passe pas en validation sans action corrective ni cause racine
--   · planification : prochaine ronde due = dernière + fréquence du modèle

CREATE TABLE IF NOT EXISTS keystone.inspection_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  name text NOT NULL,
  domain text NOT NULL CHECK (domain IN ('technique','securite','proprete','environnement')),
  frequency_days int NOT NULL DEFAULT 7,
  location_id uuid REFERENCES keystone.locations(id),
  asset_id uuid REFERENCES keystone.assets(id),
  requires_signature boolean NOT NULL DEFAULT false,
  checkpoints jsonb NOT NULL,   -- [{key,label,type,min,max,unit,options,required,critical}]
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  template_id uuid NOT NULL REFERENCES keystone.inspection_templates(id),
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('in_progress','completed','validated')),
  inspector_id uuid DEFAULT auth.uid(),
  inspector_name text,
  answers jsonb NOT NULL DEFAULT '{}',
  score numeric,
  failed int NOT NULL DEFAULT 0,
  signed boolean NOT NULL DEFAULT false,
  completed_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.non_conformities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  title text NOT NULL,
  type text NOT NULL DEFAULT 'maintenance' CHECK (type IN ('security','quality','environmental','regulatory','maintenance')),
  severity text NOT NULL CHECK (severity IN ('minor','major','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','pending_validation','closed','rejected')),
  source text NOT NULL DEFAULT 'inspection' CHECK (source IN ('inspection','audit','incident','complaint','observation')),
  inspection_id uuid REFERENCES keystone.inspections(id),
  checkpoint_key text,
  location_id uuid REFERENCES keystone.locations(id),
  asset_id uuid REFERENCES keystone.assets(id),
  observed_value text,
  immediate_action text,
  root_cause text,
  corrective_action text,
  due_date date NOT NULL,
  work_order_id uuid REFERENCES keystone.work_orders(id),
  closed_by uuid,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['inspection_templates','inspections','non_conformities'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
    EXECUTE format('ALTER TABLE keystone.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE keystone.non_conformities, keystone.inspections;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
GRANT INSERT ON keystone.inspections, keystone.non_conformities TO authenticated;
GRANT UPDATE ON keystone.non_conformities TO authenticated;

-- Évalue une réponse : NULL = non renseignée, true = conforme, false = non conforme
CREATE OR REPLACE FUNCTION keystone.checkpoint_ok(p_cp jsonb, p_val jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  IF p_val IS NULL OR p_val = 'null'::jsonb OR p_val = '""'::jsonb THEN RETURN NULL; END IF;
  CASE p_cp->>'type'
    WHEN 'boolean' THEN RETURN (p_val #>> '{}')::boolean;
    WHEN 'numeric' THEN
      RETURN (p_cp->>'min' IS NULL OR (p_val #>> '{}')::numeric >= (p_cp->>'min')::numeric)
         AND (p_cp->>'max' IS NULL OR (p_val #>> '{}')::numeric <= (p_cp->>'max')::numeric);
    WHEN 'choice' THEN RETURN NOT ((p_cp->'fail_options') ? (p_val #>> '{}'));
    ELSE RETURN true;
  END CASE;
END $$;

-- Clôture d'une ronde : contrôle des champs requis, score pondéré, NC + OT automatiques
CREATE OR REPLACE FUNCTION keystone.inspection_submit(p_template uuid, p_answers jsonb, p_inspector text DEFAULT NULL, p_signed boolean DEFAULT false)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE
  t inspection_templates; cp jsonb; ok boolean; w int; num numeric := 0; den numeric := 0;
  v_insp uuid; v_ref text; v_failed int := 0; v_sev text; v_nc uuid; v_wo uuid; a assets; v_ncs int := 0; v_wos int := 0;
BEGIN
  SELECT * INTO t FROM inspection_templates WHERE id = p_template AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF t.requires_signature AND NOT p_signed THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;

  FOR cp IN SELECT * FROM jsonb_array_elements(t.checkpoints) LOOP
    ok := checkpoint_ok(cp, p_answers->(cp->>'key'));
    IF ok IS NULL THEN
      IF coalesce((cp->>'required')::boolean, true) THEN
        RAISE EXCEPTION 'MISSING_REQUIRED' USING DETAIL = cp->>'label';
      END IF;
      CONTINUE;
    END IF;
    w := CASE WHEN coalesce((cp->>'critical')::boolean, false) THEN 3 ELSE 1 END;
    den := den + w;
    IF ok THEN num := num + w; ELSE v_failed := v_failed + 1; END IF;
  END LOOP;

  v_ref := keystone.next_ref('INS');
  INSERT INTO inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, signed)
  VALUES (t.tenant_id, v_ref, t.id, p_inspector, p_answers, CASE WHEN den > 0 THEN round(100 * num / den, 1) END, v_failed, p_signed)
  RETURNING id INTO v_insp;

  IF t.asset_id IS NOT NULL THEN SELECT * INTO a FROM assets WHERE id = t.asset_id; END IF;

  FOR cp IN SELECT * FROM jsonb_array_elements(t.checkpoints) LOOP
    IF checkpoint_ok(cp, p_answers->(cp->>'key')) IS DISTINCT FROM false THEN CONTINUE; END IF;
    v_sev := CASE WHEN coalesce((cp->>'critical')::boolean, false) THEN 'critical'
                  WHEN cp->>'type' = 'numeric' THEN 'major' ELSE 'minor' END;
    INSERT INTO non_conformities(tenant_id, ref, title, type, severity, source, inspection_id, checkpoint_key, location_id, asset_id,
                                 observed_value, due_date)
    VALUES (t.tenant_id, keystone.next_ref('NC'), cp->>'label',
            CASE t.domain WHEN 'securite' THEN 'security' WHEN 'environnement' THEN 'environmental' WHEN 'proprete' THEN 'quality' ELSE 'maintenance' END,
            v_sev, 'inspection', v_insp, cp->>'key', t.location_id, t.asset_id,
            (p_answers->>(cp->>'key')) || coalesce(' ' || (cp->>'unit'), ''),
            current_date + CASE v_sev WHEN 'critical' THEN 2 WHEN 'major' THEN 7 ELSE 30 END)
    RETURNING id INTO v_nc;
    v_ncs := v_ncs + 1;
    IF v_sev = 'critical' AND a.id IS NOT NULL THEN
      INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description, currency)
      VALUES (t.tenant_id, a.legal_entity_id, keystone.next_ref('WO'), a.id, coalesce(t.location_id, a.location_id), 'corrective', 1, 'draft',
              'NC critique · ' || (cp->>'label'), 'Ouvert automatiquement par la ronde ' || v_ref, 'XOF')
      RETURNING id INTO v_wo;
      UPDATE non_conformities SET work_order_id = v_wo WHERE id = v_nc;
      v_wos := v_wos + 1;
    END IF;
  END LOOP;

  RETURN json_build_object('inspection_id', v_insp, 'ref', v_ref, 'score', CASE WHEN den > 0 THEN round(100 * num / den, 1) END,
                           'failed', v_failed, 'nc_created', v_ncs, 'wo_created', v_wos);
END $$;

CREATE OR REPLACE FUNCTION keystone.nc_transition(p_nc uuid, p_action text, p_root_cause text DEFAULT NULL, p_corrective text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE n non_conformities; v_next text;
BEGIN
  SELECT * INTO n FROM non_conformities WHERE id = p_nc FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  UPDATE non_conformities SET root_cause = coalesce(p_root_cause, root_cause), corrective_action = coalesce(p_corrective, corrective_action) WHERE id = p_nc;
  SELECT * INTO n FROM non_conformities WHERE id = p_nc;
  IF p_action = 'start' AND n.status = 'open' THEN v_next := 'in_progress';
  ELSIF p_action = 'submit' AND n.status IN ('open','in_progress') THEN
    IF coalesce(n.corrective_action, '') = '' OR coalesce(n.root_cause, '') = '' THEN
      RAISE EXCEPTION 'ACTION_REQUIRED' USING DETAIL = 'Cause racine et action corrective obligatoires avant validation.';
    END IF;
    v_next := 'pending_validation';
  ELSIF p_action = 'close' AND n.status = 'pending_validation' THEN
    UPDATE non_conformities SET closed_by = auth.uid(), closed_at = now() WHERE id = p_nc;
    v_next := 'closed';
  ELSIF p_action = 'reject' AND n.status = 'pending_validation' THEN v_next := 'in_progress';
  ELSE RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = format('%s depuis %s', p_action, n.status);
  END IF;
  UPDATE non_conformities SET status = v_next WHERE id = p_nc;
  RETURN json_build_object('status', v_next);
END $$;

CREATE OR REPLACE FUNCTION keystone.inspection_rounds()
RETURNS TABLE(template_id uuid, name text, domain text, frequency_days int, location text, asset_tag text, checkpoints jsonb,
  requires_signature boolean, last_done timestamptz, last_score numeric, next_due date, days_to_due int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT t.id, t.name, t.domain, t.frequency_days, l.name, a.tag, t.checkpoints, t.requires_signature, i.completed_at, i.score,
    coalesce((i.completed_at)::date + t.frequency_days, current_date),
    coalesce((i.completed_at)::date + t.frequency_days, current_date) - current_date
  FROM inspection_templates t
  LEFT JOIN locations l ON l.id = t.location_id
  LEFT JOIN assets a ON a.id = t.asset_id
  LEFT JOIN LATERAL (SELECT * FROM inspections x WHERE x.template_id = t.id ORDER BY x.completed_at DESC LIMIT 1) i ON true
  WHERE t.is_active
  ORDER BY 12, t.name;
$$;

CREATE OR REPLACE FUNCTION keystone.inspections_history(p_limit int DEFAULT 30)
RETURNS TABLE(id uuid, ref text, template text, domain text, inspector text, score numeric, failed int, completed_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT i.id, i.ref, t.name, t.domain, i.inspector_name, i.score, i.failed, i.completed_at
  FROM inspections i JOIN inspection_templates t ON t.id = i.template_id
  ORDER BY i.completed_at DESC LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION keystone.nc_board()
RETURNS TABLE(id uuid, ref text, title text, type text, severity text, status text, source text, location text, asset_tag text,
  observed_value text, root_cause text, corrective_action text, due_date date, overdue boolean, wo_ref text, inspection_ref text, created_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT n.id, n.ref, n.title, n.type, n.severity, n.status, n.source, l.name, a.tag, n.observed_value, n.root_cause, n.corrective_action,
    n.due_date, n.status NOT IN ('closed','rejected') AND n.due_date < current_date, w.ref, i.ref, n.created_at
  FROM non_conformities n
  LEFT JOIN locations l ON l.id = n.location_id
  LEFT JOIN assets a ON a.id = n.asset_id
  LEFT JOIN work_orders w ON w.id = n.work_order_id
  LEFT JOIN inspections i ON i.id = n.inspection_id
  ORDER BY n.status IN ('closed','rejected'), CASE n.severity WHEN 'critical' THEN 0 WHEN 'major' THEN 1 ELSE 2 END, n.due_date;
$$;

CREATE OR REPLACE FUNCTION keystone.quality_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'score_30d', (SELECT round(avg(score), 1) FROM inspections WHERE completed_at > now() - interval '30 days'),
    'rounds_30d', (SELECT count(*) FROM inspections WHERE completed_at > now() - interval '30 days'),
    'rounds_overdue', (SELECT count(*) FROM inspection_rounds() WHERE days_to_due < 0),
    'nc_open', (SELECT count(*) FROM non_conformities WHERE status NOT IN ('closed','rejected')),
    'nc_critical', (SELECT count(*) FROM non_conformities WHERE status NOT IN ('closed','rejected') AND severity = 'critical'),
    'nc_overdue', (SELECT count(*) FROM non_conformities WHERE status NOT IN ('closed','rejected') AND due_date < current_date),
    'nc_closed_on_time_pct', (SELECT round(100.0 * count(*) FILTER (WHERE closed_at::date <= due_date) / NULLIF(count(*), 0), 1)
                              FROM non_conformities WHERE status = 'closed')
  );
$$;

GRANT EXECUTE ON FUNCTION keystone.checkpoint_ok(jsonb, jsonb), keystone.inspection_submit(uuid, jsonb, text, boolean),
  keystone.nc_transition(uuid, text, text, text), keystone.inspection_rounds(), keystone.inspections_history(int),
  keystone.nc_board(), keystone.quality_summary() TO authenticated;

-- ==================== 20261002_keystone_29b_inspections_seed.sql ====================
-- Seed démo rondes & NC (tenant New Heaven SA). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  loc_cvc uuid; loc_gal uuid; gf02 uuid; ssi uuid; tpl_cvc uuid; tpl_ssi uuid; tpl_san uuid; i int; v_insp uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.inspection_templates WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO loc_cvc FROM keystone.locations WHERE tenant_id = t AND code = 'LOC-CVC';
  SELECT id INTO loc_gal FROM keystone.locations WHERE tenant_id = t AND code = 'LOC-GAL';
  SELECT id INTO gf02 FROM keystone.assets WHERE tenant_id = t AND tag = 'GF-02';
  SELECT id INTO ssi FROM keystone.assets WHERE tenant_id = t AND tag = 'SSI-01';

  INSERT INTO keystone.inspection_templates(tenant_id, name, domain, frequency_days, location_id, asset_id, requires_signature, checkpoints)
  VALUES (t, 'Ronde technique — production d''eau glacée', 'technique', 1, loc_cvc, gf02, false, '[
    {"key":"t_depart","label":"Température départ eau glacée","type":"numeric","min":5,"max":8,"unit":"°C","required":true,"critical":false},
    {"key":"hp","label":"Pression HP compresseur","type":"numeric","min":10,"max":16,"unit":"bar","required":true,"critical":true},
    {"key":"vib","label":"Absence de vibration / bruit anormal","type":"boolean","required":true,"critical":false},
    {"key":"fuite","label":"Aucune trace de fuite d''huile ou de fluide","type":"boolean","required":true,"critical":true},
    {"key":"etat","label":"État général du local","type":"choice","options":["Propre","À nettoyer","Encombré"],"fail_options":["Encombré"],"required":true,"critical":false},
    {"key":"obs","label":"Observations","type":"text","required":false,"critical":false}
  ]'::jsonb) RETURNING id INTO tpl_cvc;

  INSERT INTO keystone.inspection_templates(tenant_id, name, domain, frequency_days, location_id, asset_id, requires_signature, checkpoints)
  VALUES (t, 'Ronde sécurité incendie ERP', 'securite', 7, loc_gal, ssi, true, '[
    {"key":"ssi_veille","label":"Centrale SSI en veille, aucun dérangement","type":"boolean","required":true,"critical":true},
    {"key":"issues","label":"Issues de secours dégagées et balisées","type":"boolean","required":true,"critical":true},
    {"key":"baes","label":"BAES fonctionnels (test)","type":"boolean","required":true,"critical":false},
    {"key":"extinct","label":"Extincteurs présents et plombés","type":"boolean","required":true,"critical":false},
    {"key":"portes_cf","label":"Portes coupe-feu fermées","type":"boolean","required":true,"critical":false}
  ]'::jsonb) RETURNING id INTO tpl_ssi;

  INSERT INTO keystone.inspection_templates(tenant_id, name, domain, frequency_days, location_id, requires_signature, checkpoints)
  VALUES (t, 'Contrôle propreté sanitaires publics', 'proprete', 1, loc_gal, false, '[
    {"key":"sols","label":"Sols propres et secs","type":"boolean","required":true,"critical":false},
    {"key":"consommables","label":"Savon / papier approvisionnés","type":"boolean","required":true,"critical":false},
    {"key":"odeur","label":"Niveau d''odeur","type":"choice","options":["Aucune","Légère","Forte"],"fail_options":["Forte"],"required":true,"critical":false}
  ]'::jsonb) RETURNING id INTO tpl_san;

  -- Historique : 10 rondes CVC, 4 rondes SSI, 8 contrôles sanitaires
  FOR i IN 1..10 LOOP
    INSERT INTO keystone.inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, completed_at)
    VALUES (t, keystone.next_ref('INS'), tpl_cvc, CASE WHEN i % 2 = 0 THEN 'Aka K.' ELSE 'Diomandé S.' END,
            jsonb_build_object('t_depart', 6.5, 'hp', 13.2, 'vib', i <> 3, 'fuite', true, 'etat', 'Propre'),
            CASE WHEN i = 3 THEN 88.9 ELSE 100 END, (i = 3)::int, now() - make_interval(days => i + 1));
  END LOOP;
  FOR i IN 1..4 LOOP
    INSERT INTO keystone.inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, signed, completed_at)
    VALUES (t, keystone.next_ref('INS'), tpl_ssi, 'Toko A.', jsonb_build_object('ssi_veille', true, 'issues', i <> 2, 'baes', true, 'extinct', true, 'portes_cf', i <> 1),
            CASE i WHEN 1 THEN 88.9 WHEN 2 THEN 66.7 ELSE 100 END, (i <= 2)::int, true, now() - make_interval(days => 7 * i + 2))
    RETURNING id INTO v_insp;
    IF i = 2 THEN
      INSERT INTO keystone.non_conformities(tenant_id, ref, title, type, severity, status, source, inspection_id, checkpoint_key, location_id, asset_id,
                                            immediate_action, root_cause, corrective_action, due_date, closed_at, created_at)
      VALUES (t, keystone.next_ref('NC'), 'Issues de secours dégagées et balisées', 'security', 'critical', 'closed', 'inspection', v_insp, 'issues', loc_gal, ssi,
              'Palettes déplacées immédiatement', 'Livraisons stockées dans le dégagement par un preneur', 'Marquage au sol + rappel au règlement intérieur des preneurs',
              (now() - interval '14 days')::date, now() - interval '15 days', now() - interval '16 days');
    END IF;
    IF i = 1 THEN
      INSERT INTO keystone.non_conformities(tenant_id, ref, title, type, severity, status, source, inspection_id, checkpoint_key, location_id, asset_id, due_date, created_at)
      VALUES (t, keystone.next_ref('NC'), 'Portes coupe-feu fermées', 'security', 'minor', 'in_progress', 'inspection', v_insp, 'portes_cf', loc_gal, ssi,
              (now() - interval '9 days')::date + 30, now() - interval '9 days');
    END IF;
  END LOOP;
  FOR i IN 1..8 LOOP
    INSERT INTO keystone.inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, completed_at)
    VALUES (t, keystone.next_ref('INS'), tpl_san, 'CleanPro — équipe B', jsonb_build_object('sols', true, 'consommables', i NOT IN (2, 5), 'odeur', 'Aucune'),
            CASE WHEN i IN (2, 5) THEN 66.7 ELSE 100 END, (i IN (2, 5))::int, now() - make_interval(days => i));
  END LOOP;
  INSERT INTO keystone.non_conformities(tenant_id, ref, title, type, severity, status, source, location_id, due_date, created_at)
  VALUES (t, keystone.next_ref('NC'), 'Savon / papier approvisionnés', 'quality', 'minor', 'open', 'inspection', loc_gal, current_date + 25, now() - interval '5 days'),
         (t, keystone.next_ref('NC'), 'Fuite d''eau sous lavabo sanitaire H', 'maintenance', 'major', 'open', 'complaint', loc_gal, current_date - 2, now() - interval '9 days');
END $$;

-- ==================== 20261002_keystone_30_failure_library_pareto.sql ====================
-- keystone_30_failure_library_pareto — Bibliothèque de modes de défaillance + Pareto des pannes
-- Porté depuis WiseFM (failure-modes « predefinedFailureModes », failure-history + utils/pareto-analysis) et amélioré :
--   · bibliothèque en BASE (WiseFM : constante en dur dans l'écran) — 15 familles bâtiment × 4 modes
--   · cotation G/O/D SUGGÉRÉE par mode (à ajuster par l'analyste) + rattachement code ISO 14224
--   · fmea_from_library(actif, famille) : initialise l'AMDEC d'un actif en un clic (anti-doublon)
--   · Pareto 80/20 calculé en base sur les OT correctifs réels : fréquence | coût | durée d'arrêt

CREATE TABLE IF NOT EXISTS keystone.failure_mode_library (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family text NOT NULL,
  family_label text NOT NULL,
  mode text NOT NULL,
  consequences text NOT NULL,
  causes text NOT NULL,
  detection text NOT NULL,
  suggested_severity int NOT NULL CHECK (suggested_severity BETWEEN 1 AND 10),
  suggested_occurrence int NOT NULL CHECK (suggested_occurrence BETWEEN 1 AND 10),
  suggested_detection int NOT NULL CHECK (suggested_detection BETWEEN 1 AND 10),
  iso14224_code text,
  UNIQUE (family, mode)
);
GRANT SELECT ON keystone.failure_mode_library TO authenticated;

INSERT INTO keystone.failure_mode_library(family, family_label, mode, consequences, causes, detection,
  suggested_severity, suggested_occurrence, suggested_detection, iso14224_code) VALUES
  ('ECLAIRAGE', 'Éclairage', 'Ampoule / tube grillé', 'Zone non éclairée', 'Vieillissement, surtension', 'Inspection visuelle', 3, 6, 3, 'LOO'),
  ('ECLAIRAGE', 'Éclairage', 'Ballast HS', 'Lumière clignotante ou absente', 'Surchauffe, défaut composant', 'Clignotement, absence d’allumage', 3, 4, 3, 'FTS'),
  ('ECLAIRAGE', 'Éclairage', 'Court-circuit', 'Coupure circuit, disjoncteur déclenché', 'Humidité, fil dénudé, surcharge', 'Disjoncteur déclenché', 6, 3, 4, 'LOO'),
  ('ECLAIRAGE', 'Éclairage', 'Détecteur de présence HS', 'Lumière reste allumée / éteinte', 'Usure, défaut électronique', 'Test manuel', 2, 4, 5, NULL),
  ('CLIMATISATION', 'Climatisation / CVC', 'Compresseur en panne', 'Plus de froid, inconfort occupants', 'Usure, manque d’huile, surcharge', 'Alarme, absence de régulation', 7, 4, 4, 'FTS'),
  ('CLIMATISATION', 'Climatisation / CVC', 'Fuite de fluide frigorigène', 'Perte d’efficacité, arrêt, rejet F-Gas', 'Vieillissement, joint défectueux', 'Baisse de pression, détecteur de fuite', 6, 4, 6, 'ELU'),
  ('CLIMATISATION', 'Climatisation / CVC', 'Filtre colmaté', 'Débit d’air faible, surchauffe', 'Manque d’entretien, poussière (harmattan)', 'Pression différentielle, bruit', 4, 7, 4, 'LOO'),
  ('CLIMATISATION', 'Climatisation / CVC', 'Sonde de température HS', 'Mauvaise régulation', 'Défaut électronique, câble coupé', 'Température incohérente', 4, 3, 5, NULL),
  ('ASCENSEUR', 'Ascenseur', 'Blocage cabine', 'Personnes bloquées', 'Défaut capteur, panne moteur', 'Alarme, appel usager', 8, 4, 2, 'LOO'),
  ('ASCENSEUR', 'Ascenseur', 'Porte ne s’ouvre pas', 'Blocage accès, attente', 'Capteur encrassé, moteur HS', 'Signal défaut, test manuel', 6, 6, 4, 'FTS'),
  ('ASCENSEUR', 'Ascenseur', 'Défaut variateur', 'Arrêt brutal, secousses', 'Surtension, composant HS', 'Code erreur, bruit anormal', 6, 3, 4, NULL),
  ('ASCENSEUR', 'Ascenseur', 'Usure câble de traction', 'Risque de rupture, arrêt sécurité', 'Vieillissement, surcharge', 'Inspection visuelle, contrôle réglementaire', 10, 2, 4, 'SER'),
  ('ESCALATOR', 'Escalier mécanique', 'Arrêt brutal', 'Chute d’usagers, arrêt service', 'Corps étranger, sécurité activée', 'Alarme, arrêt immédiat', 9, 3, 2, 'LOO'),
  ('ESCALATOR', 'Escalier mécanique', 'Main courante bloquée / désynchronisée', 'Danger pour usagers', 'Usure, manque de graissage', 'Inspection, bruit', 7, 4, 4, NULL),
  ('ESCALATOR', 'Escalier mécanique', 'Bruit anormal', 'Usure mécanique', 'Roulement HS, pièce desserrée', 'Bruit, vibration', 4, 5, 4, 'VIB'),
  ('ESCALATOR', 'Escalier mécanique', 'Défaut capteur de sécurité', 'Non-arrêt en cas d’obstacle', 'Capteur sale ou défectueux', 'Test sécurité', 10, 2, 6, 'SER'),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Non-ouverture', 'Blocage accès, évacuation gênée', 'Capteur HS, moteur HS', 'Test manuel, alarme', 7, 4, 3, 'FTS'),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Ouverture intempestive', 'Perte sécurité, énergie', 'Capteur mal réglé, interférence', 'Observation, plainte usager', 4, 4, 5, NULL),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Bruit mécanique', 'Usure, risque de panne', 'Manque de graissage, pièce usée', 'Bruit, vibration', 3, 5, 4, 'VIB'),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Porte reste ouverte', 'Perte énergie, sûreté', 'Capteur défectueux, réglage', 'Observation, test', 4, 4, 4, NULL),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Déclenchement intempestif', 'Fausse alerte, évacuation', 'Détecteur poussiéreux, humidité', 'Historique alarmes', 5, 5, 3, NULL),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Non-déclenchement', 'Non-évacuation, danger vital', 'Batterie HS, détecteur HS', 'Test périodique, voyant défaut', 10, 2, 6, 'SER'),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Défaut de transmission d’alarme', 'Secours non informés', 'Liaison coupée, panne centrale', 'Test, voyant défaut centrale', 9, 2, 5, 'SER'),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Sirène / diffuseur HS', 'Alarme inaudible', 'Haut-parleur HS, fil coupé', 'Test sonore', 9, 2, 5, 'SER'),
  ('PLOMBERIE', 'Plomberie & pompage', 'Fuite visible', 'Inondation, dégâts matériels', 'Usure, joint HS, coup de bélier', 'Inspection visuelle, humidité', 5, 5, 3, 'ELU'),
  ('PLOMBERIE', 'Plomberie & pompage', 'Robinet / vanne bloqué', 'Inconfort, coupure d’eau', 'Calcaire, usure', 'Test manuel', 3, 4, 4, NULL),
  ('PLOMBERIE', 'Plomberie & pompage', 'Canalisation bouchée', 'Refoulement, inondation', 'Dépôt, objet, graisse', 'Écoulement lent, bruit', 5, 5, 4, NULL),
  ('PLOMBERIE', 'Plomberie & pompage', 'Chasse d’eau HS', 'Gaspillage d’eau, fuite', 'Mécanisme usé, flotteur HS', 'Bruit, écoulement continu', 2, 6, 4, 'ELU'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Non-démarrage', 'Black-out lors du délestage', 'Batteries HS, manque de carburant', 'Essai de démarrage, voyant défaut', 8, 5, 4, 'FTS'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Surchauffe', 'Arrêt sécurité en charge', 'Ventilation obstruée, manque d’huile / eau', 'Alarme, température élevée', 7, 3, 3, 'OHE'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Défaut alternateur', 'Pas de production électrique', 'Usure, surcharge', 'Test tension, voyant défaut', 8, 2, 4, 'LOO'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Fuite de carburant', 'Pollution, risque incendie', 'Joint HS, réservoir percé', 'Odeur, tache, inspection', 8, 3, 4, 'ELU'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Surchauffe / point chaud', 'Coupure, incendie', 'Surcharge, mauvais serrage', 'Thermographie infrarouge', 9, 3, 4, 'OHE'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Disjoncteur déclenché', 'Coupure partielle ou totale', 'Court-circuit, surcharge', 'Voyant, inspection', 5, 5, 2, 'LOO'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Court-circuit', 'Coupure, risque incendie', 'Fil dénudé, humidité', 'Disjoncteur, inspection', 8, 2, 4, 'LOO'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Défaut différentiel', 'Personnes non protégées', 'Usure, défaut composant', 'Test différentiel', 10, 2, 6, 'SER'),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Image noire', 'Perte de surveillance', 'Alimentation coupée, caméra HS', 'Test visuel, alarme logiciel', 5, 4, 3, 'LOO'),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Perte de signal', 'Zone non couverte', 'Câble débranché, switch HS', 'Test réseau, voyant', 5, 4, 3, 'LOO'),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Enregistrement HS', 'Perte de preuve, insécurité', 'Disque plein / HS, bug logiciel', 'Test de lecture', 6, 3, 6, NULL),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Optique sale', 'Image floue', 'Poussière, humidité', 'Inspection visuelle', 3, 6, 4, NULL),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Non-ouverture', 'Blocage accès parking', 'Capteur HS, moteur HS', 'Test manuel, alarme', 4, 5, 2, 'FTS'),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Blocage mécanique', 'Arrêt service', 'Choc véhicule, pièce cassée', 'Inspection, bruit', 4, 4, 2, NULL),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Détection absente', 'Risque de choc usager / véhicule', 'Boucle ou cellule défectueuse', 'Test sécurité', 8, 3, 5, 'SER'),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Ouverture intempestive', 'Perte de contrôle d’accès', 'Réglage, interférence', 'Observation, plainte', 3, 4, 5, NULL),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Extracteur HS', 'Accumulation de CO, danger', 'Usure moteur, surcharge', 'Alarme CO, test extracteur', 9, 3, 4, 'LOO'),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Capteur CO défaillant', 'Ventilation non déclenchée', 'Capteur encrassé ou HS', 'Test capteur', 9, 3, 6, 'SER'),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Bruit anormal', 'Usure mécanique', 'Roulement HS, pièce desserrée', 'Bruit, vibration', 4, 5, 4, 'VIB'),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Arrêt intempestif', 'Arrêt service, danger', 'Surcharge, coupure alimentation', 'Alarme, voyant', 7, 3, 3, 'LOO'),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'Chasse d’eau bloquée', 'Inconfort, gaspillage', 'Calcaire, mécanisme HS', 'Test manuel, bruit', 2, 6, 3, NULL),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'Fuite de robinet', 'Gaspillage, inondation', 'Joint HS, usure', 'Inspection, humidité', 3, 6, 3, 'ELU'),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'WC bouché', 'Refoulement, insalubrité', 'Dépôt, objet, manque d’entretien', 'Écoulement lent, odeur', 4, 6, 2, NULL),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'Sèche-mains HS', 'Inconfort usager', 'Moteur HS, alimentation coupée', 'Test manuel', 1, 5, 3, 'FTS'),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Perte de connexion réseau', 'Supervision GTB aveugle', 'Switch HS, câble coupé, panne FAI', 'Test réseau, voyant', 6, 4, 3, 'LOO'),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Panne serveur', 'Arrêt service, perte de données', 'Surcharge, composant HS', 'Alarme, test d’accès', 7, 3, 3, 'LOO'),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Virus / cyberattaque', 'Perte de données, sûreté', 'Protection insuffisante, hameçonnage', 'Antivirus, journaux, alertes', 8, 3, 5, NULL),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Sauvegarde non fonctionnelle', 'Perte de données', 'Mauvaise configuration, disque HS', 'Test de restauration', 8, 3, 7, NULL),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Blocage mécanique', 'Accumulation de déchets', 'Surcharge, objet dur', 'Inspection, bruit', 4, 4, 3, NULL),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Fuite de lixiviats', 'Insalubrité, odeur, pollution', 'Bac percé, joint HS', 'Inspection, odeur', 5, 4, 4, 'ELU'),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Non-démarrage', 'Arrêt service', 'Alimentation coupée, moteur HS', 'Test manuel, voyant', 4, 3, 2, 'FTS'),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Surcharge', 'Arrêt sécurité', 'Trop-plein, mauvais tri', 'Alarme, inspection', 3, 5, 3, NULL)
ON CONFLICT (family, mode) DO NOTHING;

CREATE OR REPLACE FUNCTION keystone.failure_library_families()
RETURNS TABLE(family text, family_label text, modes int, max_severity int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT family, min(family_label), count(*)::int, max(suggested_severity) FROM failure_mode_library GROUP BY family ORDER BY 2;
$$;

-- Initialise l'AMDEC d'un actif depuis une famille (ignore les composants déjà analysés)
CREATE OR REPLACE FUNCTION keystone.fmea_from_library(p_asset uuid, p_family text)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE a assets; n int;
BEGIN
  SELECT * INTO a FROM assets WHERE id = p_asset;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  INSERT INTO fmea_items(tenant_id, asset_id, failure_mode_id, component, effect, cause, detection_method, severity, occurrence, detection)
  SELECT a.tenant_id, a.id,
    (SELECT fm.id FROM failure_modes fm WHERE fm.code = l.iso14224_code AND (fm.tenant_id = a.tenant_id OR fm.is_global) LIMIT 1),
    l.mode, l.consequences, l.causes, l.detection, l.suggested_severity, l.suggested_occurrence, l.suggested_detection
  FROM failure_mode_library l
  WHERE l.family = p_family
    AND NOT EXISTS (SELECT 1 FROM fmea_items f WHERE f.asset_id = a.id AND f.component = l.mode);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN json_build_object('created', n);
END $$;

-- Pareto des pannes (OT correctifs, fenêtre glissante) — règle 80/20 et classe WiseFM
CREATE OR REPLACE FUNCTION keystone.failure_pareto(p_criterion text DEFAULT 'frequency', p_months int DEFAULT 12)
RETURNS TABLE(asset_id uuid, asset_tag text, asset_name text, failures int, cost numeric, downtime_h numeric,
  value numeric, pct numeric, cumulative_pct numeric, in_vital_few boolean, mtbf_h numeric, mttr_h numeric, availability_pct numeric, class text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH f AS (
    SELECT a.id, a.tag, a.name, count(w.id)::int AS n,
      coalesce(sum(coalesce(w.cost_labor, 0) + coalesce(w.cost_parts, 0)), 0) AS cost,
      coalesce(sum(w.downtime_hours), 0) AS dt,
      avg(EXTRACT(epoch FROM (w.actual_end - w.actual_start)) / 3600) FILTER (WHERE w.actual_end IS NOT NULL) AS mttr
    FROM work_orders w JOIN assets a ON a.id = w.asset_id
    WHERE w.type = 'corrective' AND w.deleted_at IS NULL
      AND w.created_at > now() - make_interval(months => p_months)
    GROUP BY a.id, a.tag, a.name
  ), v AS (
    SELECT f.*, (CASE p_criterion WHEN 'cost' THEN f.cost WHEN 'downtime' THEN f.dt ELSE f.n END)::numeric AS val FROM f
  ), r AS (
    SELECT v.*,
      100.0 * val / NULLIF(sum(val) OVER (), 0) AS p,
      100.0 * sum(val) OVER (ORDER BY val DESC, tag ROWS UNBOUNDED PRECEDING) / NULLIF(sum(val) OVER (), 0) AS cum,
      100.0 * (sum(val) OVER (ORDER BY val DESC, tag ROWS UNBOUNDED PRECEDING) - val) / NULLIF(sum(val) OVER (), 0) AS cum_before,
      8760.0 * p_months / 12 / NULLIF(n, 0) AS mtbf
    FROM v
  )
  SELECT r.id, r.tag, r.name, r.n, r.cost, r.dt, r.val, round(r.p, 1), round(r.cum, 1),
    coalesce(r.cum_before < 80, false),           -- « vital few » : jusqu'au 1er élément qui franchit 80 %
    round(r.mtbf, 0), round(r.mttr, 2),
    round(100 * r.mtbf / NULLIF(r.mtbf + coalesce(r.mttr, 0), 0), 2),
    CASE WHEN r.p > 20 OR r.n > 15 THEN 'critical' WHEN r.p > 10 OR r.n > 8 THEN 'major' ELSE 'minor' END
  FROM r ORDER BY r.val DESC, r.tag;
$$;

GRANT EXECUTE ON FUNCTION keystone.failure_library_families(), keystone.fmea_from_library(uuid, text),
  keystone.failure_pareto(text, int) TO authenticated;
GRANT INSERT ON keystone.fmea_items TO authenticated;

-- ==================== 20261002_keystone_30b_failure_history_seed.sql ====================
-- Seed démo : historique 12 mois d'OT correctifs (alimente Pareto, MTBF/MTTR, indice de santé). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  r record; i int; a record; d timestamptz;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.work_orders WHERE tenant_id = t AND description = 'seed-historique-pannes') THEN RETURN; END IF;
  -- (tag, nb pannes, durée intervention h, arrêt h, coût MO, coût pièces)
  FOR r IN SELECT * FROM (VALUES
    ('ASC-A3', 9, 3.5, 6, 85000, 120000),
    ('GE-01',  6, 5.0, 4, 140000, 380000),
    ('GF-02',  4, 6.0, 18, 210000, 950000),
    ('CTA-N1', 3, 2.0, 3, 45000, 37000),
    ('GF-01',  2, 4.0, 8, 160000, 240000),
    ('SUR-01', 1, 3.0, 2, 60000, 87000),
    ('TR-01',  1, 8.0, 5, 320000, 0)
  ) v(tag, n, dur, dt, lab, parts) LOOP
    SELECT id, legal_entity_id, location_id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    CONTINUE WHEN a.id IS NULL;
    FOR i IN 1..r.n LOOP
      d := now() - make_interval(days => (i * 330 / r.n)::int + 5);
      INSERT INTO keystone.work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description,
                                       actual_start, actual_end, downtime_hours, cost_labor, cost_parts, currency, created_at)
      VALUES (t, a.legal_entity_id, keystone.next_ref('WO'), a.id, a.location_id, 'corrective', 2, 'done',
              'Dépannage ' || r.tag, 'seed-historique-pannes', d, d + make_interval(mins => (r.dur * 60)::int),
              r.dt, r.lab, r.parts, 'XOF', d);
    END LOOP;
  END LOOP;
END $$;

-- ==================== 20261002_keystone_31_contractor_sla.sql ====================
-- keystone_31_contractor_sla — SLA contractuels mesurés & évaluation prestataires (EN 15221 / ISO 41001 §8.1)
-- Porté depuis WiseFM (suppliers-contracts, evaluations/sla-evaluation-module) et amélioré :
--   · SLA MESURÉS sur les OT réels du prestataire (WiseFM : saisie déclarative)
--       response_time = actual_start − created_at ; resolution_time = actual_end − created_at (heures, P90 ou moyenne)
--   · pénalités calculées en FCFA par unité de dépassement, PLAFONNÉES (% du montant mensuel du contrat)
--   · score global RÉELLEMENT pondéré (WiseFM : moyenne simple) = 60 % SLA (pondérés) + 40 % grille qualitative pondérée
--     grille WiseFM conservée : qualité, délais, communication, innovation, coût, fiabilité (0..100)
--   · alerte de préavis de renouvellement (renewal_notice_days) et reconduction tacite

ALTER TABLE keystone.maintenance_contracts
  ADD COLUMN IF NOT EXISTS renewal_notice_days int NOT NULL DEFAULT 90,
  ADD COLUMN IF NOT EXISTS auto_renewal boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS penalty_cap_pct numeric NOT NULL DEFAULT 10;

CREATE TABLE IF NOT EXISTS keystone.contract_slas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  contract_id uuid NOT NULL REFERENCES keystone.maintenance_contracts(id) ON DELETE CASCADE,
  metric text NOT NULL CHECK (metric IN ('response_time','resolution_time','first_time_fix','qc_score')),
  label text NOT NULL,
  target numeric NOT NULL,
  unit text NOT NULL,                          -- h | % | /100
  lower_is_better boolean NOT NULL DEFAULT true,
  weight numeric NOT NULL DEFAULT 1 CHECK (weight > 0),
  priority_scope int,                          -- NULL = tous les OT ; sinon OT de priorité ≤ valeur
  penalty_per_unit numeric NOT NULL DEFAULT 0, -- FCFA par unité de dépassement (h ou point)
  UNIQUE (contract_id, metric, priority_scope)
);
CREATE TABLE IF NOT EXISTS keystone.contractor_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  period date NOT NULL,                        -- 1er jour du mois évalué
  scores jsonb NOT NULL,                       -- {quality, timing, communication, innovation, cost, reliability} 0..100
  comment text,
  evaluated_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contractor_id, period)
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['contract_slas','contractor_evaluations'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT, UPDATE ON keystone.contractor_evaluations TO authenticated;

-- Pondération de la grille qualitative (somme = 1)
CREATE OR REPLACE FUNCTION keystone.qualitative_score(p jsonb) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT round(
      0.25 * coalesce((p->>'quality')::numeric, 0)
    + 0.20 * coalesce((p->>'timing')::numeric, 0)
    + 0.20 * coalesce((p->>'reliability')::numeric, 0)
    + 0.15 * coalesce((p->>'cost')::numeric, 0)
    + 0.10 * coalesce((p->>'communication')::numeric, 0)
    + 0.10 * coalesce((p->>'innovation')::numeric, 0), 1);
$$;

-- Mesure des SLA sur une fenêtre (par défaut : 90 derniers jours)
CREATE OR REPLACE FUNCTION keystone.sla_measures(p_days int DEFAULT 90)
RETURNS TABLE(contractor_id uuid, contractor text, contract_id uuid, sla_id uuid, label text, metric text, unit text, target numeric,
  achieved numeric, samples int, compliant boolean, attainment numeric, weight numeric, overrun numeric, penalty numeric,
  lower_is_better boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH m AS (
    SELECT c.id AS contractor_id, c.name, s.*,
      (SELECT CASE s.metric
          WHEN 'response_time' THEN avg(EXTRACT(epoch FROM (w.actual_start - w.created_at)) / 3600)
          WHEN 'resolution_time' THEN avg(EXTRACT(epoch FROM (w.actual_end - w.created_at)) / 3600)
          WHEN 'first_time_fix' THEN 100.0 * count(*) FILTER (WHERE NOT EXISTS (
              SELECT 1 FROM work_orders w2 WHERE w2.asset_id = w.asset_id AND w2.type = 'corrective'
                AND w2.created_at > w.actual_end AND w2.created_at < w.actual_end + interval '7 days')) / NULLIF(count(*), 0)
        END
       FROM work_orders w
       WHERE w.contractor_id = c.id AND w.deleted_at IS NULL AND w.actual_start IS NOT NULL
         AND w.created_at > now() - make_interval(days => p_days)
         AND (s.priority_scope IS NULL OR w.priority <= s.priority_scope)) AS achieved,
      (SELECT count(*) FROM work_orders w WHERE w.contractor_id = c.id AND w.deleted_at IS NULL AND w.actual_start IS NOT NULL
         AND w.created_at > now() - make_interval(days => p_days)
         AND (s.priority_scope IS NULL OR w.priority <= s.priority_scope))::int AS samples
    FROM contract_slas s
    JOIN maintenance_contracts k ON k.id = s.contract_id AND k.is_active AND k.deleted_at IS NULL
    JOIN contractors c ON c.id = k.contractor_id
  )
  SELECT m.contractor_id, m.name, m.contract_id, m.id, m.label, m.metric, m.unit, m.target, round(m.achieved, 2), m.samples,
    CASE WHEN m.achieved IS NULL THEN NULL WHEN m.lower_is_better THEN m.achieved <= m.target ELSE m.achieved >= m.target END,
    -- taux d'atteinte 0..100 (100 = cible tenue)
    CASE WHEN m.achieved IS NULL THEN NULL
         WHEN m.lower_is_better THEN round(LEAST(100, 100 * m.target / NULLIF(m.achieved, 0)), 1)
         ELSE round(LEAST(100, 100 * m.achieved / NULLIF(m.target, 0)), 1) END,
    m.weight,
    CASE WHEN m.achieved IS NULL THEN 0 WHEN m.lower_is_better THEN GREATEST(0, m.achieved - m.target) ELSE GREATEST(0, m.target - m.achieved) END,
    round(CASE WHEN m.achieved IS NULL THEN 0
               WHEN m.lower_is_better THEN GREATEST(0, m.achieved - m.target) ELSE GREATEST(0, m.target - m.achieved) END
          * m.penalty_per_unit * m.samples),
    m.lower_is_better
  FROM m ORDER BY m.name, m.label;
$$;

-- Fiche de performance consolidée par prestataire
CREATE OR REPLACE FUNCTION keystone.contractor_scorecards(p_days int DEFAULT 90)
RETURNS TABLE(contractor_id uuid, contractor text, scope text, contract_end date, days_to_end int, renewal_due boolean, auto_renewal boolean,
  sla_count int, sla_compliant int, sla_score numeric, qualitative numeric, global_score numeric, last_eval date,
  penalty_raw numeric, penalty_cap numeric, penalty numeric, grade text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH s AS (
    SELECT contractor_id, count(*)::int AS n, count(*) FILTER (WHERE compliant)::int AS ok,
      sum(attainment * weight) / NULLIF(sum(weight) FILTER (WHERE attainment IS NOT NULL), 0) AS sla_score,
      sum(penalty) AS pen
    FROM sla_measures(p_days) GROUP BY contractor_id
  ), e AS (
    SELECT DISTINCT ON (contractor_id) contractor_id, period, qualitative_score(scores) AS q
    FROM contractor_evaluations ORDER BY contractor_id, period DESC
  )
  SELECT c.id, c.name, k.scope, k.end_date, k.end_date - current_date,
    k.end_date - current_date <= k.renewal_notice_days, k.auto_renewal,
    coalesce(s.n, 0), coalesce(s.ok, 0), round(s.sla_score, 1), e.q,
    round(CASE WHEN s.sla_score IS NOT NULL AND e.q IS NOT NULL THEN 0.6 * s.sla_score + 0.4 * e.q
               ELSE coalesce(s.sla_score, e.q) END, 1),
    e.period, coalesce(s.pen, 0),
    round(coalesce(k.amount, 0) / 12 * k.penalty_cap_pct / 100),
    LEAST(coalesce(s.pen, 0), round(coalesce(k.amount, 0) / 12 * k.penalty_cap_pct / 100)),
    CASE WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) IS NULL THEN '—'
         WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) >= 90 THEN 'A'
         WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) >= 80 THEN 'B'
         WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) >= 60 THEN 'C' ELSE 'D' END
  FROM contractors c
  JOIN LATERAL (SELECT * FROM maintenance_contracts mc WHERE mc.contractor_id = c.id AND mc.is_active AND mc.deleted_at IS NULL
                ORDER BY mc.end_date DESC LIMIT 1) k ON true
  LEFT JOIN s ON s.contractor_id = c.id
  LEFT JOIN e ON e.contractor_id = c.id
  WHERE c.deleted_at IS NULL
  ORDER BY 12 NULLS LAST, c.name;
$$;

CREATE OR REPLACE FUNCTION keystone.evaluation_submit(p_contractor uuid, p_scores jsonb, p_comment text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE k text; v numeric; p date := date_trunc('month', current_date)::date;
BEGIN
  FOREACH k IN ARRAY ARRAY['quality','timing','communication','innovation','cost','reliability'] LOOP
    v := (p_scores->>k)::numeric;
    IF v IS NULL OR v < 0 OR v > 100 THEN RAISE EXCEPTION 'INVALID_SCORE' USING DETAIL = k; END IF;
  END LOOP;
  INSERT INTO contractor_evaluations(tenant_id, contractor_id, period, scores, comment)
  VALUES (keystone.current_tenant(), p_contractor, p, p_scores, p_comment)
  ON CONFLICT (contractor_id, period) DO UPDATE SET scores = EXCLUDED.scores, comment = EXCLUDED.comment, created_at = now();
  RETURN json_build_object('period', p, 'qualitative', qualitative_score(p_scores));
END $$;

GRANT EXECUTE ON FUNCTION keystone.qualitative_score(jsonb), keystone.sla_measures(int), keystone.contractor_scorecards(int),
  keystone.evaluation_submit(uuid, jsonb, text) TO authenticated;

-- ==================== 20261002_keystone_31b_contractor_sla_seed.sql ====================
-- Seed démo SLA prestataires : contrats + SLA + affectation de l'historique de pannes + évaluations. Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_froid uuid; c_elec uuid; k uuid; r record;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  SELECT id INTO c_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO c_elec FROM keystone.contractors WHERE tenant_id = t AND name ILIKE 'Élec%' ORDER BY created_at LIMIT 1;

  -- Contrats (si absents) : CVC + Électricité/levage
  FOR r IN SELECT * FROM (VALUES
    (c_froid, 'Maintenance CVC — groupes froids & CTA', 42000000, current_date + 75, 90, true),
    (c_elec, 'Maintenance électricité HT/BT, groupes électrogènes & ascenseurs', 36000000, current_date + 240, 90, false)
  ) v(cid, scope, amount, end_d, notice, auto) LOOP
    CONTINUE WHEN r.cid IS NULL;
    SELECT id INTO k FROM keystone.maintenance_contracts WHERE tenant_id = t AND contractor_id = r.cid AND is_active ORDER BY end_date DESC LIMIT 1;
    IF k IS NULL THEN
      INSERT INTO keystone.maintenance_contracts(tenant_id, contractor_id, scope, start_date, end_date, amount, currency, is_active, renewal_notice_days, auto_renewal)
      VALUES (t, r.cid, r.scope, r.end_d - 365, r.end_d, r.amount, 'XOF', true, r.notice, r.auto) RETURNING id INTO k;
    END IF;
    INSERT INTO keystone.contract_slas(tenant_id, contract_id, metric, label, target, unit, lower_is_better, weight, priority_scope, penalty_per_unit) VALUES
      (t, k, 'response_time', 'Délai d''intervention (P1-P2)', 4, 'h', true, 2, 2, 25000),
      (t, k, 'resolution_time', 'Délai de rétablissement', 24, 'h', true, 2, NULL, 10000),
      (t, k, 'first_time_fix', 'Réparation au 1er passage', 85, '%', false, 1, NULL, 0)
    ON CONFLICT (contract_id, metric, priority_scope) DO NOTHING;
    k := NULL;
  END LOOP;

  -- Affecte l'historique de pannes aux prestataires + délais réalistes (créé avant l'intervention)
  UPDATE keystone.work_orders w SET
    contractor_id = CASE WHEN a.tag IN ('GF-01','GF-02','CTA-N1','SUR-01') THEN c_froid ELSE c_elec END,
    created_at = w.actual_start - make_interval(mins => CASE WHEN a.tag IN ('GF-01','GF-02','CTA-N1','SUR-01') THEN 150 ELSE 330 END
                                                       + (abs(hashtext(w.ref)) % 120))
  FROM keystone.assets a
  WHERE a.id = w.asset_id AND w.tenant_id = t AND w.description = 'seed-historique-pannes' AND w.contractor_id IS NULL;

  INSERT INTO keystone.contractor_evaluations(tenant_id, contractor_id, period, scores, comment)
  SELECT t, x.cid, date_trunc('month', current_date - interval '1 month')::date, x.sc::jsonb, x.cm
  FROM (VALUES
    (c_froid, '{"quality":88,"timing":84,"communication":90,"innovation":70,"cost":76,"reliability":86}', 'Réactif, rapports d''intervention complets.'),
    (c_elec,  '{"quality":74,"timing":58,"communication":66,"innovation":55,"cost":80,"reliability":62}', 'Délais P1 non tenus sur l''ascenseur A3.')
  ) x(cid, sc, cm)
  WHERE x.cid IS NOT NULL
  ON CONFLICT (contractor_id, period) DO NOTHING;
END $$;

-- ==================== 20261002_keystone_32_preventive_afnor.sql ====================
-- keystone_32_preventive_afnor — Gammes préventives & niveaux de maintenance (NF X60-000 / EN 13306)
-- Porté depuis WiseFM (maintenance-levels CONDUITE/I..V, maintenance-ranges + tasks, range-applications, executions) et amélioré :
--   · niveau AFNOR porté PAR LA GAMME + garde-fou LEVEL_COMPETENCY :
--       niveau 1 → opérateur/conduite autorisé · 2-3 → technicien interne ou prestataire · 4 → équipe spécialisée (pas d'opérateur)
--       niveau 5 → constructeur / prestataire uniquement
--   · étapes séquencées avec point de contrôle optionnel (plage min/max) et critère d'acceptation
--   · échéancier calculé (dernière réalisation + intervalle), conformité préventive EN 15341 (réalisé ≤ échéance + tolérance)
--   · génération des OT à horizon (anti-doublon : un seul OT ouvert par gamme)
--   · charge prévisionnelle hebdomadaire (h) vs capacité des équipes

ALTER TABLE keystone.maintenance_plans
  ADD COLUMN IF NOT EXISTS afnor_level int CHECK (afnor_level BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS executor_kind text NOT NULL DEFAULT 'internal' CHECK (executor_kind IN ('operator','internal','contractor')),
  ADD COLUMN IF NOT EXISTS contractor_id uuid REFERENCES keystone.contractors(id),
  ADD COLUMN IF NOT EXISTS estimated_hours numeric NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS tolerance_days int NOT NULL DEFAULT 7,
  ADD COLUMN IF NOT EXISTS regulatory boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS keystone.plan_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  plan_id uuid NOT NULL REFERENCES keystone.maintenance_plans(id) ON DELETE CASCADE,
  seq int NOT NULL,
  label text NOT NULL,
  duration_min int NOT NULL DEFAULT 10,
  is_critical boolean NOT NULL DEFAULT false,
  acceptance text,
  checkpoint jsonb,                 -- {type:'numeric',min,max,unit} | {type:'boolean'}
  UNIQUE (plan_id, seq)
);
ALTER TABLE keystone.plan_steps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON keystone.plan_steps;
CREATE POLICY tenant_isolation ON keystone.plan_steps USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant());
GRANT SELECT ON keystone.plan_steps TO authenticated;

CREATE OR REPLACE FUNCTION keystone.afnor_level_label(p int) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p
    WHEN 1 THEN 'N1 · Réglages simples, sans démontage (opérateur)'
    WHEN 2 THEN 'N2 · Opérations simples, procédure (technicien habilité)'
    WHEN 3 THEN 'N3 · Diagnostic, réparation de composants (technicien qualifié)'
    WHEN 4 THEN 'N4 · Travaux importants (équipe spécialisée)'
    WHEN 5 THEN 'N5 · Rénovation, reconstruction (constructeur)'
  END;
$$;

-- Garde-fou : cohérence niveau AFNOR ↔ exécutant
CREATE OR REPLACE FUNCTION keystone.trg_plan_level_check() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.afnor_level IS NULL THEN RETURN NEW; END IF;
  IF NEW.afnor_level >= 2 AND NEW.executor_kind = 'operator' THEN
    RAISE EXCEPTION 'LEVEL_COMPETENCY' USING DETAIL = 'Un opérateur ne peut exécuter qu''un niveau 1 (NF X60-000).';
  END IF;
  IF NEW.afnor_level = 5 AND NEW.executor_kind <> 'contractor' THEN
    RAISE EXCEPTION 'LEVEL_COMPETENCY' USING DETAIL = 'Le niveau 5 relève du constructeur ou d''un prestataire spécialisé.';
  END IF;
  IF NEW.executor_kind = 'contractor' AND NEW.contractor_id IS NULL THEN
    RAISE EXCEPTION 'CONTRACTOR_REQUIRED';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS plan_level_check ON keystone.maintenance_plans;
CREATE TRIGGER plan_level_check BEFORE INSERT OR UPDATE ON keystone.maintenance_plans
  FOR EACH ROW EXECUTE FUNCTION keystone.trg_plan_level_check();

-- Intervalle en jours d'une gamme calendaire
CREATE OR REPLACE FUNCTION keystone.plan_interval_days(p keystone.maintenance_plans) RETURNS int LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE coalesce(p.interval_unit, 'day')
    WHEN 'day' THEN p.interval_value WHEN 'days' THEN p.interval_value
    WHEN 'week' THEN p.interval_value * 7 WHEN 'weeks' THEN p.interval_value * 7
    WHEN 'month' THEN p.interval_value * 30 WHEN 'months' THEN p.interval_value * 30
    WHEN 'year' THEN p.interval_value * 365 WHEN 'years' THEN p.interval_value * 365
    ELSE p.interval_value END;
$$;

CREATE OR REPLACE FUNCTION keystone.pm_board()
RETURNS TABLE(id uuid, name text, asset_tag text, asset_name text, afnor_level int, level_label text, executor_kind text, contractor text,
  interval_days int, estimated_hours numeric, steps int, critical_steps int, regulatory boolean,
  last_done date, next_due date, days_to_due int, status text, open_wo_ref text, done_12m int, on_time_12m int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH p AS (
    SELECT mp.*, keystone.plan_interval_days(mp) AS ivl,
      (SELECT max(w.actual_end)::date FROM work_orders w WHERE w.source_plan_id = mp.id AND w.status IN ('done','verified')) AS last_done
    FROM maintenance_plans mp
    WHERE mp.is_active AND mp.deleted_at IS NULL AND coalesce(mp.interval_value, 0) > 0
      AND coalesce(mp.trigger_type, 'calendar') NOT IN ('meter','predictive','conditional')
  )
  SELECT p.id, p.name, a.tag, a.name, p.afnor_level, keystone.afnor_level_label(p.afnor_level), p.executor_kind, c.name,
    p.ivl, p.estimated_hours,
    (SELECT count(*) FROM plan_steps s WHERE s.plan_id = p.id)::int,
    (SELECT count(*) FROM plan_steps s WHERE s.plan_id = p.id AND s.is_critical)::int,
    p.regulatory, p.last_done,
    coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl,
    coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl - current_date,
    CASE WHEN o.ref IS NOT NULL THEN 'scheduled'
         WHEN coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl + p.tolerance_days < current_date THEN 'overdue'
         WHEN coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl <= current_date + p.lead_time_days THEN 'due'
         ELSE 'ok' END,
    o.ref,
    (SELECT count(*) FROM work_orders w WHERE w.source_plan_id = p.id AND w.status IN ('done','verified') AND w.actual_end > now() - interval '12 months')::int,
    (SELECT count(*) FROM work_orders w WHERE w.source_plan_id = p.id AND w.status IN ('done','verified') AND w.actual_end > now() - interval '12 months'
       AND (w.planned_end IS NULL OR w.actual_end::date <= w.planned_end::date + p.tolerance_days))::int
  FROM p
  LEFT JOIN assets a ON a.id = p.asset_id
  LEFT JOIN contractors c ON c.id = p.contractor_id
  LEFT JOIN LATERAL (SELECT w.ref FROM work_orders w WHERE w.source_plan_id = p.id
                     AND w.status IN ('draft','planned','assigned','in_progress','on_hold') LIMIT 1) o ON true
  ORDER BY 16, p.name;
$$;

CREATE OR REPLACE FUNCTION keystone.pm_steps(p_plan uuid)
RETURNS TABLE(seq int, label text, duration_min int, is_critical boolean, acceptance text, checkpoint jsonb)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT seq, label, duration_min, is_critical, acceptance, checkpoint FROM plan_steps WHERE plan_id = p_plan ORDER BY seq;
$$;

-- Charge prévisionnelle (h) par semaine sur l'horizon, par type d'exécutant
CREATE OR REPLACE FUNCTION keystone.pm_workload(p_weeks int DEFAULT 8)
RETURNS TABLE(week date, internal_h numeric, contractor_h numeric, operator_h numeric, capacity_h numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH weeks AS (SELECT g::date AS w FROM generate_series(date_trunc('week', current_date::timestamp), date_trunc('week', current_date::timestamp) + make_interval(days => (p_weeks - 1) * 7), interval '7 days') g),
  occ AS (   -- occurrences de chaque gamme dans l'horizon
    SELECT b.executor_kind, b.estimated_hours, (b.next_due + k * b.interval_days) AS d
    FROM pm_board() b, generate_series(0, 60) k
    WHERE b.interval_days > 0 AND b.next_due + k * b.interval_days < date_trunc('week', current_date)::date + p_weeks * 7
  )
  SELECT weeks.w,
    coalesce(sum(o.estimated_hours) FILTER (WHERE o.executor_kind = 'internal'), 0),
    coalesce(sum(o.estimated_hours) FILTER (WHERE o.executor_kind = 'contractor'), 0),
    coalesce(sum(o.estimated_hours) FILTER (WHERE o.executor_kind = 'operator'), 0),
    -- capacité préventive interne : 35 % de 40 h par technicien actif (hypothèse paramétrable)
    round((SELECT count(*) FROM persons) * 40 * 0.35, 0)
  FROM weeks LEFT JOIN occ o ON date_trunc('week', greatest(o.d, current_date))::date = weeks.w
  GROUP BY weeks.w ORDER BY weeks.w;
$$;

-- Génère les OT préventifs des gammes dues dans l'horizon (planifiés, jamais affectés automatiquement)
CREATE OR REPLACE FUNCTION keystone.pm_generate_horizon(p_days int DEFAULT 14)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE b record; mp maintenance_plans; a assets; n int := 0; refs text[] := '{}'; v_ref text;
BEGIN
  FOR b IN SELECT * FROM pm_board() WHERE status IN ('due','overdue') OR (status = 'ok' AND days_to_due <= p_days) LOOP
    SELECT * INTO mp FROM maintenance_plans WHERE id = b.id;
    SELECT * INTO a FROM assets WHERE id = mp.asset_id;
    v_ref := keystone.next_ref('WO');
    INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description,
                            contractor_id, planned_start, planned_end, source_plan_id, currency)
    VALUES (mp.tenant_id, a.legal_entity_id, v_ref, a.id, a.location_id, (CASE WHEN mp.regulatory THEN 'regulatory' ELSE 'preventive' END)::keystone.wo_type,
            CASE WHEN b.status = 'overdue' THEN 2 ELSE 3 END, 'planned', mp.name,
            'Gamme ' || coalesce(keystone.afnor_level_label(mp.afnor_level), '') || ' · ' || b.steps || ' étapes',
            mp.contractor_id, b.next_due::timestamptz, b.next_due::timestamptz + make_interval(hours => ceil(mp.estimated_hours)::int), mp.id, 'XOF');
    UPDATE maintenance_plans SET last_generated_on = current_date WHERE id = mp.id;
    n := n + 1; refs := refs || v_ref;
  END LOOP;
  RETURN json_build_object('created', n, 'refs', refs);
END $$;

CREATE OR REPLACE FUNCTION keystone.pm_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'plans', count(*),
    'overdue', count(*) FILTER (WHERE status = 'overdue'),
    'due', count(*) FILTER (WHERE status = 'due'),
    'scheduled', count(*) FILTER (WHERE status = 'scheduled'),
    'compliance_pct', round(100.0 * sum(on_time_12m) / NULLIF(sum(done_12m), 0), 1),
    'hours_per_year', round(sum(estimated_hours * 365.0 / NULLIF(interval_days, 0)))
  ) FROM pm_board();
$$;

GRANT EXECUTE ON FUNCTION keystone.afnor_level_label(int), keystone.plan_interval_days(keystone.maintenance_plans), keystone.pm_board(),
  keystone.pm_steps(uuid), keystone.pm_workload(int), keystone.pm_generate_horizon(int), keystone.pm_summary() TO authenticated;

-- ==================== 20261002_keystone_32b_preventive_seed.sql ====================
-- Seed démo gammes préventives AFNOR (tenant New Heaven SA). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_froid uuid; c_elec uuid; r record; a uuid; p uuid; s record; i int;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  SELECT id INTO c_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO c_elec FROM keystone.contractors WHERE tenant_id = t AND name ILIKE 'Élec%' ORDER BY created_at LIMIT 1;

  FOR r IN SELECT * FROM (VALUES
    ('GF-02', 'Ronde de conduite groupe froid', 1, 'operator', NULL::uuid, 1, 'day', 0.5, false, 2),
    ('GF-02', 'Visite trimestrielle groupe froid (contrôle étanchéité F-Gas)', 3, 'contractor', c_froid, 3, 'month', 6, true, 70),
    ('CTA-N1', 'Changement filtres & courroies CTA', 2, 'internal', NULL, 1, 'month', 2, false, 40),
    ('GE-01', 'Essai mensuel en charge groupe électrogène', 2, 'internal', NULL, 1, 'month', 1.5, false, 38),
    ('GE-01', 'Révision annuelle moteur & alternateur', 4, 'contractor', c_elec, 12, 'month', 16, false, 300),
    ('TR-01', 'Thermographie IR TGBT & transformateur', 3, 'contractor', c_elec, 12, 'month', 4, true, 330),
    ('SSI-01', 'Vérification semestrielle SSI (APSAD R7)', 3, 'contractor', c_elec, 6, 'month', 8, true, 190),
    ('ASC-A3', 'Entretien mensuel ascenseur', 2, 'contractor', c_elec, 1, 'month', 2, true, 35),
    ('SUR-01', 'Contrôle surpresseur & garniture', 2, 'internal', NULL, 3, 'month', 1, false, 100)
  ) v(tag, name, lvl, exe, cid, ivl, unit, hrs, reg, last_ago) LOOP
    CONTINUE WHEN r.exe = 'contractor' AND r.cid IS NULL;
    SELECT id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    CONTINUE WHEN a IS NULL OR EXISTS (SELECT 1 FROM keystone.maintenance_plans WHERE tenant_id = t AND name = r.name);
    INSERT INTO keystone.maintenance_plans(tenant_id, asset_id, name, trigger_type, interval_value, interval_unit, lead_time_days, is_active,
                                           afnor_level, executor_kind, contractor_id, estimated_hours, regulatory, last_generated_on)
    VALUES (t, a, r.name, 'calendar', r.ivl, r.unit, 7, true, r.lvl, r.exe, r.cid, r.hrs, r.reg, current_date - r.last_ago)
    RETURNING id INTO p;
    i := 0;
    FOR s IN SELECT * FROM (VALUES
      ('Consignation / mise en sécurité selon procédure', 10, true, 'VAT réalisée, cadenas posé', NULL::jsonb),
      ('Relevé des paramètres de fonctionnement', 15, false, 'Valeurs dans la plage constructeur', '{"type":"numeric","min":5,"max":8,"unit":"°C"}'::jsonb),
      ('Inspection visuelle : fuites, corrosion, fixations', 15, false, 'Aucune anomalie', '{"type":"boolean"}'::jsonb),
      ('Opérations de la gamme (nettoyage, serrage, remplacement)', 45, false, 'Pièces d''usure remplacées si nécessaire', NULL),
      ('Essai fonctionnel et remise en service', 15, true, 'Fonctionnement nominal constaté', '{"type":"boolean"}'::jsonb)
    ) x(label, dur, crit, acc, cp) LOOP
      i := i + 1;
      CONTINUE WHEN r.lvl = 1 AND i IN (1, 4);       -- niveau 1 : ni consignation ni démontage
      INSERT INTO keystone.plan_steps(tenant_id, plan_id, seq, label, duration_min, is_critical, acceptance, checkpoint)
      VALUES (t, p, i, s.label, s.dur, s.crit, s.acc, s.cp);
    END LOOP;
  END LOOP;
END $$;

-- ==================== 20261002_keystone_33_waste_register.sql ====================
-- keystone_33_waste_register — Registre déchets & filières (ISO 14001 §8.1, traçabilité des déchets dangereux)
-- Porté depuis WiseFM (waste-providers, waste-records, waste-objectives) et amélioré :
--   · flux WiseFM : papier, plastique, DIB, dangereux, organique, verre, métal, DEEE
--   · interlock BSD_REQUIRED : un enlèvement de déchet dangereux (ou DEEE) exige un bordereau de suivi + un opérateur agréé
--   · interlock OPERATOR_NOT_APPROVED : l'opérateur doit avoir un agrément valide à la date d'enlèvement
--   · taux de valorisation = (recyclage + valorisation + réemploi) / total, par mois et par site
--   · empreinte carbone des déchets (facteurs indicatifs par flux/filière) → reportée en scope 3
--   · objectifs avec statut calculé (on_track / at_risk / achieved / failed) au lieu d'un statut saisi

ALTER TABLE keystone.contractors
  ADD COLUMN IF NOT EXISTS is_waste_operator boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS waste_approval_ref text,
  ADD COLUMN IF NOT EXISTS waste_approval_until date;

CREATE TABLE IF NOT EXISTS keystone.waste_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  stream text NOT NULL CHECK (stream IN ('paper','plastic','dib','dangerous','organic','glass','metal','electronic')),
  treatment text NOT NULL CHECK (treatment IN ('recycling','valorization','reuse','elimination')),
  quantity_kg numeric NOT NULL CHECK (quantity_kg > 0),
  operator_id uuid REFERENCES keystone.contractors(id),
  collected_on date NOT NULL,
  bsd_ref text,                          -- bordereau de suivi de déchets
  certificate_ref text,                  -- certificat de traitement / destruction
  source text NOT NULL DEFAULT 'weighbridge' CHECK (source IN ('manual','weighbridge','estimation','certificate')),
  cost numeric,
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  validated boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.waste_objectives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  kind text NOT NULL CHECK (kind IN ('valorization_rate','reduction','dangerous_max')),
  label text NOT NULL,
  target numeric NOT NULL,              -- % (taux, réduction vs N-1) ou kg/mois (dangerous_max)
  year int NOT NULL,
  UNIQUE (tenant_id, kind, year)
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['waste_records','waste_objectives'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT, UPDATE ON keystone.waste_records TO authenticated;

-- Garde-fous réglementaires à l'écriture
CREATE OR REPLACE FUNCTION keystone.trg_waste_check() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'keystone','public' AS $$
DECLARE op contractors;
BEGIN
  IF NEW.stream IN ('dangerous','electronic') THEN
    IF coalesce(NEW.bsd_ref, '') = '' THEN
      RAISE EXCEPTION 'BSD_REQUIRED' USING DETAIL = 'Bordereau de suivi obligatoire pour les déchets dangereux et DEEE.';
    END IF;
    IF NEW.treatment = 'reuse' AND NEW.stream = 'dangerous' THEN RAISE EXCEPTION 'INVALID_TREATMENT'; END IF;
  END IF;
  IF NEW.operator_id IS NOT NULL THEN
    SELECT * INTO op FROM contractors WHERE id = NEW.operator_id;
    IF NOT op.is_waste_operator OR op.waste_approval_until IS NULL OR op.waste_approval_until < NEW.collected_on THEN
      RAISE EXCEPTION 'OPERATOR_NOT_APPROVED' USING DETAIL = coalesce(op.name, '?') || ' : agrément déchets absent ou échu.';
    END IF;
  ELSIF NEW.stream IN ('dangerous','electronic') THEN
    RAISE EXCEPTION 'OPERATOR_NOT_APPROVED' USING DETAIL = 'Un opérateur agréé est obligatoire pour ce flux.';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS waste_check ON keystone.waste_records;
CREATE TRIGGER waste_check BEFORE INSERT OR UPDATE ON keystone.waste_records FOR EACH ROW EXECUTE FUNCTION keystone.trg_waste_check();

-- Facteurs carbone indicatifs (kgCO2e / kg) par flux × filière — à remplacer par des facteurs officiels
CREATE OR REPLACE FUNCTION keystone.waste_factor(p_stream text, p_treatment text) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_treatment IN ('recycling','reuse') THEN 0.03
    WHEN p_treatment = 'valorization' THEN CASE p_stream WHEN 'organic' THEN 0.05 ELSE 0.10 END
    ELSE CASE p_stream WHEN 'paper' THEN 0.924 WHEN 'plastic' THEN 2.89 WHEN 'glass' THEN 0.593 WHEN 'organic' THEN 0.52
                       WHEN 'dangerous' THEN 1.2 WHEN 'electronic' THEN 1.0 WHEN 'metal' THEN 0.05 ELSE 0.6 END
  END;
$$;

CREATE OR REPLACE FUNCTION keystone.waste_board(p_months int DEFAULT 12)
RETURNS TABLE(id uuid, collected_on date, site text, stream text, treatment text, quantity_kg numeric, operator text,
  bsd_ref text, certificate_ref text, source text, cost numeric, validated boolean, kg_co2e numeric, missing_certificate boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT w.id, w.collected_on, s.name, w.stream, w.treatment, w.quantity_kg, c.name, w.bsd_ref, w.certificate_ref, w.source, w.cost, w.validated,
    round(w.quantity_kg * keystone.waste_factor(w.stream, w.treatment), 1),
    w.stream IN ('dangerous','electronic') AND coalesce(w.certificate_ref, '') = '' AND w.collected_on < current_date - 30
  FROM waste_records w JOIN sites s ON s.id = w.site_id LEFT JOIN contractors c ON c.id = w.operator_id
  WHERE w.collected_on >= date_trunc('month', current_date) - make_interval(months => p_months - 1)
  ORDER BY w.collected_on DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.waste_monthly(p_months int DEFAULT 12)
RETURNS TABLE(period date, total_kg numeric, valorized_kg numeric, eliminated_kg numeric, dangerous_kg numeric, valorization_pct numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT date_trunc('month', collected_on)::date, sum(quantity_kg),
    sum(quantity_kg) FILTER (WHERE treatment <> 'elimination'),
    coalesce(sum(quantity_kg) FILTER (WHERE treatment = 'elimination'), 0),
    coalesce(sum(quantity_kg) FILTER (WHERE stream = 'dangerous'), 0),
    round(100.0 * coalesce(sum(quantity_kg) FILTER (WHERE treatment <> 'elimination'), 0) / NULLIF(sum(quantity_kg), 0), 1)
  FROM waste_records
  WHERE collected_on >= date_trunc('month', current_date) - make_interval(months => p_months - 1)
  GROUP BY 1 ORDER BY 1;
$$;

CREATE OR REPLACE FUNCTION keystone.waste_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH y AS (SELECT * FROM waste_records WHERE collected_on >= date_trunc('year', current_date)),
       p AS (SELECT * FROM waste_records WHERE collected_on >= date_trunc('year', current_date) - interval '1 year'
                                          AND collected_on < current_date - interval '1 year')
  SELECT json_build_object(
    'total_t_ytd', (SELECT round(sum(quantity_kg) / 1000, 1) FROM y),
    'total_t_prev_ytd', (SELECT round(sum(quantity_kg) / 1000, 1) FROM p),
    'valorization_pct', (SELECT round(100.0 * sum(quantity_kg) FILTER (WHERE treatment <> 'elimination') / NULLIF(sum(quantity_kg), 0), 1) FROM y),
    'dangerous_t_ytd', (SELECT round(coalesce(sum(quantity_kg) FILTER (WHERE stream = 'dangerous'), 0) / 1000, 2) FROM y),
    't_co2e_ytd', (SELECT round(sum(quantity_kg * keystone.waste_factor(stream, treatment)) / 1000, 1) FROM y),
    'cost_ytd', (SELECT coalesce(sum(cost), 0) FROM y),
    'missing_certificates', (SELECT count(*) FROM waste_records WHERE stream IN ('dangerous','electronic')
                              AND coalesce(certificate_ref, '') = '' AND collected_on < current_date - 30),
    'operators_expiring', (SELECT count(*) FROM contractors WHERE is_waste_operator AND waste_approval_until < current_date + 60)
  );
$$;

CREATE OR REPLACE FUNCTION keystone.waste_objectives_status()
RETURNS TABLE(kind text, label text, target numeric, actual numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH s AS (SELECT waste_summary() AS j),
       months AS (SELECT GREATEST(1, extract(month FROM current_date)::int) AS m)
  SELECT o.kind, o.label, o.target,
    CASE o.kind
      WHEN 'valorization_rate' THEN (s.j->>'valorization_pct')::numeric
      WHEN 'reduction' THEN round(100 * (1 - (s.j->>'total_t_ytd')::numeric / NULLIF((s.j->>'total_t_prev_ytd')::numeric, 0)), 1)
      WHEN 'dangerous_max' THEN round((s.j->>'dangerous_t_ytd')::numeric * 1000 / months.m, 0)
    END AS actual
  FROM waste_objectives o, s, months WHERE o.year = extract(year FROM current_date)::int;
$$;
-- statut calculé dans une vue d'ensemble (sens « plus haut = mieux » sauf dangerous_max)
CREATE OR REPLACE FUNCTION keystone.waste_objectives_board()
RETURNS TABLE(kind text, label text, target numeric, actual numeric, status text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT kind, label, target, actual,
    CASE WHEN actual IS NULL THEN 'no_data'
         WHEN kind = 'dangerous_max' THEN CASE WHEN actual <= target THEN 'on_track' WHEN actual <= target * 1.15 THEN 'at_risk' ELSE 'failed' END
         ELSE CASE WHEN actual >= target THEN 'achieved' WHEN actual >= target * 0.9 THEN 'on_track' WHEN actual >= target * 0.75 THEN 'at_risk' ELSE 'failed' END
    END
  FROM keystone.waste_objectives_status();
$$;

GRANT EXECUTE ON FUNCTION keystone.waste_factor(text, text), keystone.waste_board(int), keystone.waste_monthly(int), keystone.waste_summary(),
  keystone.waste_objectives_status(), keystone.waste_objectives_board() TO authenticated;

-- ==================== 20261002_keystone_33b_waste_seed.sql ====================
-- Seed démo registre déchets (24 mois, 2 sites, opérateurs agréés). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  op_rec uuid; op_dd uuid; s record; m int; d date; scale numeric;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.waste_records WHERE tenant_id = t) THEN RETURN; END IF;

  INSERT INTO keystone.contractors(tenant_id, name, prequalified, rating, is_waste_operator, waste_approval_ref, waste_approval_until)
  SELECT t, v.n, true, v.r, true, v.ref, v.until::date FROM (VALUES
    ('Recycl''Abidjan', 4.2, 'AGR-ANAGED-2024-117', (current_date + 400)::text),
    ('EcoTraitement Déchets Spéciaux', 4.5, 'AGR-CIAPOL-DD-0931', (current_date + 45)::text)
  ) v(n, r, ref, until)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.contractors WHERE tenant_id = t AND name = v.n);
  SELECT id INTO op_rec FROM keystone.contractors WHERE tenant_id = t AND name = 'Recycl''Abidjan';
  SELECT id INTO op_dd FROM keystone.contractors WHERE tenant_id = t AND name = 'EcoTraitement Déchets Spéciaux';

  FOR s IN SELECT id, name FROM keystone.sites WHERE tenant_id = t LOOP
    scale := CASE WHEN s.name ILIKE '%Yopougon%' THEN 1.0 ELSE 0.6 END;
    FOR m IN 0..23 LOOP
      d := (date_trunc('month', current_date) - make_interval(months => m))::date + 12;
      CONTINUE WHEN d > current_date;
      -- amélioration progressive du tri : la part valorisée augmente sur l'année récente
      INSERT INTO keystone.waste_records(tenant_id, site_id, stream, treatment, quantity_kg, operator_id, collected_on, source, cost, validated) VALUES
        (t, s.id, 'dib', CASE WHEN m < 12 THEN 'valorization' ELSE 'elimination' END, round(scale * 14000 * (1 + 0.05 * (m >= 12)::int)), op_rec, d, 'weighbridge', round(scale * 14000 * 45), true),
        (t, s.id, 'paper', 'recycling', round(scale * 3800), op_rec, d, 'weighbridge', round(scale * 3800 * 20), true),
        (t, s.id, 'plastic', CASE WHEN m < 12 THEN 'recycling' ELSE 'elimination' END, round(scale * 2100), op_rec, d, 'weighbridge', round(scale * 2100 * 30), true),
        (t, s.id, 'organic', 'valorization', round(scale * 5200), op_rec, d, 'estimation', round(scale * 5200 * 25), m >= 1),
        (t, s.id, 'glass', 'recycling', round(scale * 900), op_rec, d, 'weighbridge', round(scale * 900 * 15), true);
      IF m % 3 = 0 THEN
        INSERT INTO keystone.waste_records(tenant_id, site_id, stream, treatment, quantity_kg, operator_id, collected_on, bsd_ref, certificate_ref, source, cost, validated)
        VALUES (t, s.id, 'dangerous', 'elimination', round(scale * 420), op_dd, d, 'BSD-' || to_char(d, 'YYMM') || '-' || left(s.name, 3),
                CASE WHEN m = 0 THEN NULL ELSE 'CERT-' || to_char(d, 'YYMM') END, 'certificate', round(scale * 420 * 650), m > 0),
               (t, s.id, 'electronic', 'recycling', round(scale * 160), op_dd, d, 'BSD-E' || to_char(d, 'YYMM'),
                CASE WHEN m <= 1 THEN NULL ELSE 'CERT-E' || to_char(d, 'YYMM') END, 'certificate', round(scale * 160 * 300), true);
      END IF;
    END LOOP;
  END LOOP;

  INSERT INTO keystone.waste_objectives(tenant_id, kind, label, target, year) VALUES
    (t, 'valorization_rate', 'Taux de valorisation matière & énergie', 75, extract(year FROM current_date)::int),
    (t, 'reduction', 'Réduction du tonnage total vs N-1', 5, extract(year FROM current_date)::int),
    (t, 'dangerous_max', 'Déchets dangereux ≤ 200 kg / mois', 200, extract(year FROM current_date)::int)
  ON CONFLICT (tenant_id, kind, year) DO NOTHING;
END $$;

-- ==================== 20261002_keystone_34_contractor_portal.sql ====================
-- keystone_34_contractor_portal — Portail prestataire : devis, avenants, rapports d'intervention, chrono SLA
-- Porté depuis WiseFM (supplier-portal/types.ts : Quote, Variation, InterventionReport, Anomaly, SLATimer/PauseReason) et amélioré :
--   · cloisonnement EN BASE : policy restrictive — un prestataire connecté ne voit que ses lignes (current_contractor())
--   · devis : seul le client valide (SEGREGATION_OF_DUTIES si un prestataire tente de valider) ; approbation → coûts estimés de l'OT
--   · avenants : cumul > 20 % du devis approuvé ⇒ statut « escalated » (double validation) au lieu d'« approved »
--   · rapport : photos AVANT et APRÈS obligatoires sur un correctif (PHOTO_EVIDENCE_REQUIRED) ; validation = signature client
--   · anomalies majeures/critiques du rapport ⇒ OT correctif de suivi en BROUILLON, lié
--   · chrono SLA : seules les pauses JUSTIFIÉES et acceptées par le client sont déduites (WiseFM : toute pause déduite)

CREATE TABLE IF NOT EXISTS keystone.wo_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','approved','rejected')),
  notes text,
  valid_until date,
  decided_by uuid, decided_at timestamptz, rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.wo_quote_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  quote_id uuid NOT NULL REFERENCES keystone.wo_quotes(id) ON DELETE CASCADE,
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  kind text NOT NULL CHECK (kind IN ('labor','material','travel','other')),
  label text NOT NULL,
  qty numeric NOT NULL CHECK (qty > 0),
  unit_price numeric NOT NULL CHECK (unit_price >= 0),
  total numeric GENERATED ALWAYS AS (qty * unit_price) STORED
);
CREATE TABLE IF NOT EXISTS keystone.wo_variations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  reason text NOT NULL,
  extra_cost numeric NOT NULL DEFAULT 0,
  extra_hours numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','escalated','rejected')),
  decided_by uuid, decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.wo_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  summary text NOT NULL,
  photos_before text[] NOT NULL DEFAULT '{}',
  photos_after text[] NOT NULL DEFAULT '{}',
  technician_name text NOT NULL,
  technician_signed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','validated','rejected')),
  client_signed_by text, client_signed_at timestamptz, rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.wo_anomalies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  report_id uuid NOT NULL REFERENCES keystone.wo_reports(id) ON DELETE CASCADE,
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  severity text NOT NULL CHECK (severity IN ('minor','major','critical')),
  description text NOT NULL,
  follow_up_wo_id uuid REFERENCES keystone.work_orders(id)
);
CREATE TABLE IF NOT EXISTS keystone.wo_sla_pauses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  reason text NOT NULL CHECK (reason IN ('waiting_quote','waiting_permit','waiting_parts','client_delay','force_majeure')),
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  justified boolean               -- NULL = en attente d'arbitrage client
);

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['wo_quotes','wo_quote_items','wo_variations','wo_reports','wo_anomalies','wo_sla_pauses'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    -- Cloisonnement prestataire : restrictive ⇒ s'ajoute (ET) à l'isolation tenant
    EXECUTE format('DROP POLICY IF EXISTS contractor_scope ON keystone.%I', t);
    EXECUTE format('CREATE POLICY contractor_scope ON keystone.%I AS RESTRICTIVE USING (keystone.current_contractor() IS NULL OR contractor_id = keystone.current_contractor()) WITH CHECK (keystone.current_contractor() IS NULL OR contractor_id = keystone.current_contractor())', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON keystone.%I TO authenticated', t);
    EXECUTE format('ALTER TABLE keystone.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE keystone.wo_quotes, keystone.wo_reports, keystone.wo_variations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Le prestataire agit uniquement sur SES OT ; le client (current_contractor() NULL) peut agir pour le compte du prestataire affecté
CREATE OR REPLACE FUNCTION keystone.portal_wo(p_wo uuid) RETURNS keystone.work_orders
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.contractor_id IS NULL THEN RAISE EXCEPTION 'NO_CONTRACTOR' USING DETAIL = 'OT non confié à un prestataire.'; END IF;
  IF keystone.current_contractor() IS NOT NULL AND keystone.current_contractor() <> w.contractor_id THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;
  RETURN w;
END $$;

CREATE OR REPLACE FUNCTION keystone.quote_submit(p_wo uuid, p_items jsonb, p_notes text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; q uuid; v_ref text; it jsonb;
BEGIN
  w := portal_wo(p_wo);
  IF jsonb_array_length(coalesce(p_items, '[]')) = 0 THEN RAISE EXCEPTION 'EMPTY_QUOTE'; END IF;
  IF EXISTS (SELECT 1 FROM wo_quotes WHERE work_order_id = p_wo AND status = 'submitted') THEN RAISE EXCEPTION 'QUOTE_PENDING'; END IF;
  v_ref := keystone.next_ref('DV');
  INSERT INTO wo_quotes(tenant_id, ref, work_order_id, contractor_id, notes, valid_until)
  VALUES (w.tenant_id, v_ref, p_wo, w.contractor_id, p_notes, current_date + 30) RETURNING id INTO q;
  FOR it IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO wo_quote_items(tenant_id, quote_id, contractor_id, kind, label, qty, unit_price)
    VALUES (w.tenant_id, q, w.contractor_id, it->>'kind', it->>'label', (it->>'qty')::numeric, (it->>'unit_price')::numeric);
  END LOOP;
  RETURN json_build_object('quote_id', q, 'ref', v_ref, 'total', (SELECT sum(total) FROM wo_quote_items WHERE quote_id = q));
END $$;

CREATE OR REPLACE FUNCTION keystone.quote_decide(p_quote uuid, p_approve boolean, p_reason text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE q wo_quotes;
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN
    RAISE EXCEPTION 'SEGREGATION_OF_DUTIES' USING DETAIL = 'Un prestataire ne peut pas valider son propre devis.';
  END IF;
  SELECT * INTO q FROM wo_quotes WHERE id = p_quote FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF q.status <> 'submitted' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF p_approve AND q.valid_until < current_date THEN RAISE EXCEPTION 'QUOTE_EXPIRED'; END IF;
  UPDATE wo_quotes SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END, decided_by = auth.uid(), decided_at = now(),
    rejection_reason = CASE WHEN p_approve THEN NULL ELSE coalesce(p_reason, 'Rejeté') END
  WHERE id = p_quote;
  IF p_approve THEN
    UPDATE work_orders SET
      cost_labor = (SELECT coalesce(sum(total), 0) FROM wo_quote_items WHERE quote_id = p_quote AND kind IN ('labor','travel')),
      cost_parts = (SELECT coalesce(sum(total), 0) FROM wo_quote_items WHERE quote_id = p_quote AND kind IN ('material','other')),
      updated_at = now()
    WHERE id = q.work_order_id;
  END IF;
  RETURN json_build_object('status', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END);
END $$;

CREATE OR REPLACE FUNCTION keystone.variation_submit(p_wo uuid, p_reason text, p_cost numeric, p_hours numeric DEFAULT 0)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v uuid;
BEGIN
  w := portal_wo(p_wo);
  IF NOT EXISTS (SELECT 1 FROM wo_quotes WHERE work_order_id = p_wo AND status = 'approved') THEN
    RAISE EXCEPTION 'NO_APPROVED_QUOTE' USING DETAIL = 'Un avenant suppose un devis approuvé.';
  END IF;
  INSERT INTO wo_variations(tenant_id, work_order_id, contractor_id, reason, extra_cost, extra_hours)
  VALUES (w.tenant_id, p_wo, w.contractor_id, p_reason, p_cost, p_hours) RETURNING id INTO v;
  RETURN json_build_object('variation_id', v);
END $$;

CREATE OR REPLACE FUNCTION keystone.variation_decide(p_var uuid, p_approve boolean)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE v wo_variations; base numeric; cumul numeric; st text;
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'SEGREGATION_OF_DUTIES'; END IF;
  SELECT * INTO v FROM wo_variations WHERE id = p_var FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF v.status NOT IN ('pending','escalated') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF NOT p_approve THEN
    st := 'rejected';
  ELSE
    SELECT coalesce(sum(i.total), 0) INTO base FROM wo_quote_items i JOIN wo_quotes q ON q.id = i.quote_id
      WHERE q.work_order_id = v.work_order_id AND q.status = 'approved';
    SELECT coalesce(sum(extra_cost), 0) + v.extra_cost INTO cumul FROM wo_variations
      WHERE work_order_id = v.work_order_id AND status = 'approved' AND id <> v.id;
    -- 1re validation d'un avenant qui porte le cumul au-delà de 20 % ⇒ escalade (2e validation requise)
    IF v.status = 'pending' AND base > 0 AND cumul > 0.2 * base THEN st := 'escalated';
    ELSIF v.status = 'escalated' AND v.decided_by = auth.uid() THEN
      RAISE EXCEPTION 'SEGREGATION_OF_DUTIES' USING DETAIL = 'La seconde validation doit être faite par une autre personne.';
    ELSE st := 'approved';
    END IF;
  END IF;
  UPDATE wo_variations SET status = st, decided_by = auth.uid(), decided_at = now() WHERE id = p_var;
  IF st = 'approved' THEN
    UPDATE work_orders SET cost_labor = coalesce(cost_labor, 0) + v.extra_cost, updated_at = now() WHERE id = v.work_order_id;
  END IF;
  RETURN json_build_object('status', st);
END $$;

CREATE OR REPLACE FUNCTION keystone.report_submit(p_wo uuid, p_summary text, p_technician text, p_before text[], p_after text[], p_anomalies jsonb DEFAULT '[]')
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; r uuid; an jsonb;
BEGIN
  w := portal_wo(p_wo);
  IF w.type = 'corrective' AND (coalesce(array_length(p_before, 1), 0) = 0 OR coalesce(array_length(p_after, 1), 0) = 0) THEN
    RAISE EXCEPTION 'PHOTO_EVIDENCE_REQUIRED' USING DETAIL = 'Photos avant ET après obligatoires sur un OT correctif.';
  END IF;
  INSERT INTO wo_reports(tenant_id, work_order_id, contractor_id, summary, technician_name, photos_before, photos_after)
  VALUES (w.tenant_id, p_wo, w.contractor_id, p_summary, p_technician, coalesce(p_before, '{}'), coalesce(p_after, '{}')) RETURNING id INTO r;
  FOR an IN SELECT * FROM jsonb_array_elements(coalesce(p_anomalies, '[]')) LOOP
    INSERT INTO wo_anomalies(tenant_id, report_id, contractor_id, severity, description)
    VALUES (w.tenant_id, r, w.contractor_id, an->>'severity', an->>'description');
  END LOOP;
  -- fin d'éventuelle pause en cours
  UPDATE wo_sla_pauses SET ended_at = now() WHERE work_order_id = p_wo AND ended_at IS NULL;
  RETURN json_build_object('report_id', r);
END $$;

CREATE OR REPLACE FUNCTION keystone.report_validate(p_report uuid, p_signer text, p_approve boolean, p_reason text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE rp wo_reports; w work_orders; an record; v_wo uuid; n int := 0;
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'SEGREGATION_OF_DUTIES'; END IF;
  SELECT * INTO rp FROM wo_reports WHERE id = p_report FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF rp.status <> 'submitted' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF p_approve AND coalesce(trim(p_signer), '') = '' THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;
  UPDATE wo_reports SET status = CASE WHEN p_approve THEN 'validated' ELSE 'rejected' END,
    client_signed_by = CASE WHEN p_approve THEN p_signer END, client_signed_at = CASE WHEN p_approve THEN now() END,
    rejection_reason = CASE WHEN p_approve THEN NULL ELSE coalesce(p_reason, 'Rapport incomplet') END
  WHERE id = p_report;
  IF p_approve THEN
    SELECT * INTO w FROM work_orders WHERE id = rp.work_order_id;
    FOR an IN SELECT * FROM wo_anomalies WHERE report_id = p_report AND severity IN ('major','critical') AND follow_up_wo_id IS NULL LOOP
      INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description, contractor_id, currency)
      VALUES (w.tenant_id, w.legal_entity_id, keystone.next_ref('WO'), w.asset_id, w.location_id, 'corrective',
              CASE an.severity WHEN 'critical' THEN 1 ELSE 2 END, 'draft', 'Suite ' || w.ref || ' · ' || left(an.description, 80),
              'Anomalie relevée par le prestataire : ' || an.description, w.contractor_id, 'XOF')
      RETURNING id INTO v_wo;
      UPDATE wo_anomalies SET follow_up_wo_id = v_wo WHERE id = an.id;
      n := n + 1;
    END LOOP;
  END IF;
  RETURN json_build_object('status', CASE WHEN p_approve THEN 'validated' ELSE 'rejected' END, 'follow_ups', n);
END $$;

CREATE OR REPLACE FUNCTION keystone.sla_pause(p_wo uuid, p_reason text)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v uuid;
BEGIN
  w := portal_wo(p_wo);
  IF EXISTS (SELECT 1 FROM wo_sla_pauses WHERE work_order_id = p_wo AND ended_at IS NULL) THEN RAISE EXCEPTION 'ALREADY_PAUSED'; END IF;
  INSERT INTO wo_sla_pauses(tenant_id, work_order_id, contractor_id, reason, justified)
  VALUES (w.tenant_id, p_wo, w.contractor_id, p_reason, CASE WHEN p_reason IN ('waiting_permit','client_delay') THEN true END)  -- imputables au client : acceptées d'office
  RETURNING id INTO v;
  RETURN json_build_object('pause_id', v);
END $$;
CREATE OR REPLACE FUNCTION keystone.sla_resume(p_wo uuid) RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  UPDATE wo_sla_pauses SET ended_at = now() WHERE work_order_id = (keystone.portal_wo(p_wo)).id AND ended_at IS NULL;
$$;
CREATE OR REPLACE FUNCTION keystone.pause_arbitrate(p_pause uuid, p_justified boolean) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'SEGREGATION_OF_DUTIES'; END IF;
  UPDATE wo_sla_pauses SET justified = p_justified WHERE id = p_pause;
END $$;

-- Chrono SLA effectif (h) = écoulé − pauses justifiées
CREATE OR REPLACE FUNCTION keystone.wo_sla_clock(p_wo uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'elapsed_h', round(EXTRACT(epoch FROM (coalesce(w.actual_end, now()) - w.created_at)) / 3600, 1),
    'paused_h', round(coalesce((SELECT sum(EXTRACT(epoch FROM (coalesce(p.ended_at, now()) - p.started_at))) FROM wo_sla_pauses p
                                WHERE p.work_order_id = w.id AND p.justified), 0) / 3600, 1),
    'pending_h', round(coalesce((SELECT sum(EXTRACT(epoch FROM (coalesce(p.ended_at, now()) - p.started_at))) FROM wo_sla_pauses p
                                 WHERE p.work_order_id = w.id AND p.justified IS NULL), 0) / 3600, 1),
    'paused_now', EXISTS (SELECT 1 FROM wo_sla_pauses p WHERE p.work_order_id = w.id AND p.ended_at IS NULL),
    'sla_due', w.sla_due)
  FROM work_orders w WHERE w.id = p_wo;
$$;

-- Tableau du portail (filtré par RLS pour un prestataire connecté ; filtrable par prestataire pour le client)
CREATE OR REPLACE FUNCTION keystone.portal_board(p_contractor uuid DEFAULT NULL)
RETURNS TABLE(wo_id uuid, wo_ref text, title text, type text, status text, priority int, contractor_id uuid, contractor text,
  asset_tag text, location text, created_at timestamptz, sla_due timestamptz,
  quote_id uuid, quote_ref text, quote_status text, quote_total numeric,
  variations_pending int, variations_total numeric, report_id uuid, report_status text, anomalies int,
  elapsed_h numeric, paused_h numeric, pending_pause_h numeric, paused_now boolean, open_pause_id uuid, open_pause_reason text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT w.id, w.ref, w.title, w.type::text, w.status::text, w.priority, w.contractor_id, c.name, a.tag, l.name, w.created_at, w.sla_due,
    q.id, q.ref, q.status, (SELECT sum(total) FROM wo_quote_items i WHERE i.quote_id = q.id),
    (SELECT count(*) FROM wo_variations v WHERE v.work_order_id = w.id AND v.status IN ('pending','escalated'))::int,
    (SELECT coalesce(sum(extra_cost), 0) FROM wo_variations v WHERE v.work_order_id = w.id AND v.status = 'approved'),
    r.id, r.status, (SELECT count(*) FROM wo_anomalies an WHERE an.report_id = r.id)::int,
    (keystone.wo_sla_clock(w.id)->>'elapsed_h')::numeric, (keystone.wo_sla_clock(w.id)->>'paused_h')::numeric,
    (keystone.wo_sla_clock(w.id)->>'pending_h')::numeric, (keystone.wo_sla_clock(w.id)->>'paused_now')::boolean,
    op.id, op.reason
  FROM work_orders w
  JOIN contractors c ON c.id = w.contractor_id
  LEFT JOIN assets a ON a.id = w.asset_id
  LEFT JOIN locations l ON l.id = w.location_id
  LEFT JOIN LATERAL (SELECT * FROM wo_quotes x WHERE x.work_order_id = w.id ORDER BY x.created_at DESC LIMIT 1) q ON true
  LEFT JOIN LATERAL (SELECT * FROM wo_reports x WHERE x.work_order_id = w.id ORDER BY x.created_at DESC LIMIT 1) r ON true
  LEFT JOIN LATERAL (SELECT * FROM wo_sla_pauses x WHERE x.work_order_id = w.id AND x.ended_at IS NULL LIMIT 1) op ON true
  WHERE w.deleted_at IS NULL AND w.status NOT IN ('cancelled')
    AND (p_contractor IS NULL OR w.contractor_id = p_contractor)
    AND (keystone.current_contractor() IS NULL OR w.contractor_id = keystone.current_contractor())
    AND (w.status NOT IN ('done','verified') OR w.updated_at > now() - interval '30 days' OR r.status = 'submitted')
  ORDER BY (r.status = 'submitted' OR q.status = 'submitted') DESC NULLS LAST, w.priority, w.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.portal_detail(p_wo uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'quote_items', (SELECT json_agg(json_build_object('kind', i.kind, 'label', i.label, 'qty', i.qty, 'unit_price', i.unit_price, 'total', i.total) ORDER BY i.kind)
                    FROM wo_quote_items i JOIN wo_quotes q ON q.id = i.quote_id
                    WHERE q.work_order_id = p_wo AND q.created_at = (SELECT max(created_at) FROM wo_quotes WHERE work_order_id = p_wo)),
    'variations', (SELECT json_agg(json_build_object('id', v.id, 'reason', v.reason, 'extra_cost', v.extra_cost, 'extra_hours', v.extra_hours, 'status', v.status) ORDER BY v.created_at)
                   FROM wo_variations v WHERE v.work_order_id = p_wo),
    'report', (SELECT json_build_object('id', r.id, 'summary', r.summary, 'technician', r.technician_name, 'before', r.photos_before, 'after', r.photos_after,
                                        'status', r.status, 'client_signed_by', r.client_signed_by,
                                        'anomalies', (SELECT json_agg(json_build_object('severity', an.severity, 'description', an.description,
                                                       'follow_up', (SELECT ref FROM work_orders WHERE id = an.follow_up_wo_id))) FROM wo_anomalies an WHERE an.report_id = r.id))
               FROM wo_reports r WHERE r.work_order_id = p_wo ORDER BY r.created_at DESC LIMIT 1),
    'pauses', (SELECT json_agg(json_build_object('id', p.id, 'reason', p.reason, 'started_at', p.started_at, 'ended_at', p.ended_at, 'justified', p.justified) ORDER BY p.started_at)
               FROM wo_sla_pauses p WHERE p.work_order_id = p_wo)
  );
$$;

GRANT EXECUTE ON FUNCTION keystone.portal_wo(uuid), keystone.quote_submit(uuid, jsonb, text), keystone.quote_decide(uuid, boolean, text),
  keystone.variation_submit(uuid, text, numeric, numeric), keystone.variation_decide(uuid, boolean),
  keystone.report_submit(uuid, text, text, text[], text[], jsonb), keystone.report_validate(uuid, text, boolean, text),
  keystone.sla_pause(uuid, text), keystone.sla_resume(uuid), keystone.pause_arbitrate(uuid, boolean),
  keystone.wo_sla_clock(uuid), keystone.portal_board(uuid), keystone.portal_detail(uuid) TO authenticated;

-- ==================== 20261002_keystone_34b_contractor_portal_seed.sql ====================
-- Seed démo portail prestataire : 4 OT à différentes étapes du cycle. Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_froid uuid; c_elec uuid; r record; a record; w uuid; q uuid; rp uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.wo_quotes WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO c_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO c_elec FROM keystone.contractors WHERE tenant_id = t AND name ILIKE 'Élec%' ORDER BY created_at LIMIT 1;
  IF c_froid IS NULL OR c_elec IS NULL THEN RETURN; END IF;

  FOR r IN SELECT * FROM (VALUES
    (1, 'GF-02', c_froid, 'Remplacement roulements compresseur à vis', 'assigned', 'quote_submitted', 30),
    (2, 'CTA-N1', c_froid, 'Remplacement moteur ventilateur CTA', 'in_progress', 'quote_approved_variation', 52),
    (3, 'GE-01', c_elec, 'Batteries de démarrage HS — groupe électrogène', 'done', 'report_submitted', 20),
    (4, 'ASC-A3', c_elec, 'Porte palière niveau 2 bloquée', 'in_progress', 'paused', 9)
  ) v(n, tag, cid, title, st, stage, hours_ago) LOOP
    SELECT id, legal_entity_id, location_id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    CONTINUE WHEN a.id IS NULL;
    INSERT INTO keystone.work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, contractor_id,
                                     created_at, sla_due, actual_start, actual_end, currency)
    VALUES (t, a.legal_entity_id, keystone.next_ref('WO'), a.id, a.location_id, 'corrective', CASE WHEN r.n = 4 THEN 1 ELSE 2 END,
            r.st::keystone.wo_status, r.title, r.cid,
            now() - make_interval(hours => r.hours_ago), now() - make_interval(hours => r.hours_ago) + interval '24 hours',
            CASE WHEN r.st IN ('in_progress','done') THEN now() - make_interval(hours => r.hours_ago - 3) END,
            CASE WHEN r.st = 'done' THEN now() - interval '2 hours' END, 'XOF')
    RETURNING id INTO w;

    IF r.stage IN ('quote_submitted','quote_approved_variation','report_submitted') THEN
      INSERT INTO keystone.wo_quotes(tenant_id, ref, work_order_id, contractor_id, status, notes, valid_until, decided_at)
      VALUES (t, keystone.next_ref('DV'), w, r.cid, CASE WHEN r.stage = 'quote_submitted' THEN 'submitted' ELSE 'approved' END,
              'Intervention sous 48 h après accord.', current_date + 30, CASE WHEN r.stage <> 'quote_submitted' THEN now() - interval '1 day' END)
      RETURNING id INTO q;
      INSERT INTO keystone.wo_quote_items(tenant_id, quote_id, contractor_id, kind, label, qty, unit_price)
      SELECT t, q, r.cid, x.k, x.l, x.qty, x.pu FROM (VALUES
        (1, 'labor', 'Main d''œuvre technicien frigoriste', 8, 18500), (1, 'material', 'Jeu de roulements SKF compresseur', 1, 640000), (1, 'travel', 'Déplacement Abidjan', 1, 25000),
        (2, 'labor', 'Main d''œuvre (2 techniciens)', 6, 17000), (2, 'material', 'Moteur 7,5 kW IE3', 1, 980000),
        (3, 'labor', 'Main d''œuvre électricien', 2, 16000), (3, 'material', 'Batteries 12 V 200 Ah', 2, 210000)
      ) x(n, k, l, qty, pu) WHERE x.n = r.n;
    END IF;

    IF r.stage = 'quote_approved_variation' THEN
      INSERT INTO keystone.wo_variations(tenant_id, work_order_id, contractor_id, reason, extra_cost, extra_hours)
      VALUES (t, w, r.cid, 'Accouplement moteur fissuré découvert au démontage — remplacement nécessaire', 265000, 2);
    END IF;

    IF r.stage = 'report_submitted' THEN
      INSERT INTO keystone.wo_reports(tenant_id, work_order_id, contractor_id, summary, technician_name, photos_before, photos_after)
      VALUES (t, w, r.cid, 'Remplacement des deux batteries de démarrage, test de démarrage OK (3 essais). Chargeur contrôlé.',
              'Koné M.', ARRAY['avant-batteries-1', 'avant-borniers-2'], ARRAY['apres-batteries-1', 'apres-essai-2'])
      RETURNING id INTO rp;
      INSERT INTO keystone.wo_anomalies(tenant_id, report_id, contractor_id, severity, description) VALUES
        (t, rp, r.cid, 'major', 'Fuite légère de liquide de refroidissement sur la durite inférieure'),
        (t, rp, r.cid, 'minor', 'Étiquetage du tableau de commande effacé');
    END IF;

    IF r.stage = 'paused' THEN
      INSERT INTO keystone.wo_sla_pauses(tenant_id, work_order_id, contractor_id, reason, started_at, justified)
      VALUES (t, w, r.cid, 'waiting_parts', now() - interval '5 hours', NULL);
    END IF;
  END LOOP;
END $$;

COMMIT;
