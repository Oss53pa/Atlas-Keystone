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
