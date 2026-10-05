-- Atlas Keystone · migration 42 (rapprochement BC / réception / facture, compteurs & grilles CIE-SODECI) + seed
-- 38 à 41 sont déjà appliquées. À coller en une fois dans le SQL Editor (projet vgtmljfayiysuvrcmunt).

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

CREATE OR REPLACE FUNCTION keystone.supplier_invoices_board()
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
  keystone.po_receive_lines(uuid, jsonb, text, text), keystone.supplier_invoices_board(), keystone.invoice_detail(uuid), keystone.po_lines_status(uuid),
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

