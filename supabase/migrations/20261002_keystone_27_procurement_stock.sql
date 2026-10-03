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
