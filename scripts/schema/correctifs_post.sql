-- Correctifs du corpus dépendant de types créés par le corpus : rejoués avec les annexes (run_fixpoint.py).
-- Base de TEST seulement. Chaque correctif cite sa source. Statut : en attente de report dans l'annexe propriétaire.

-- C10 : keystone.wo_stage_status_ok, Annexe B §B.1.4 (A03), « encode le tableau ci-dessous », IMMUTABLE [Confirmé :
-- transcription littérale du tableau des 11 étapes].
CREATE OR REPLACE FUNCTION keystone.wo_stage_status_ok(p_stage keystone.wo_stage, p_status keystone.wo_status)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_stage
    WHEN 'emitted'     THEN p_status IN ('draft','cancelled')
    WHEN 'sent'        THEN p_status IN ('planned','cancelled')
    WHEN 'diagnosed'   THEN p_status IN ('planned','cancelled')
    WHEN 'scheduled'   THEN p_status IN ('assigned','cancelled')
    WHEN 'quoted'      THEN p_status IN ('assigned','cancelled')
    WHEN 'covered'     THEN p_status IN ('assigned','cancelled')
    WHEN 'committed'   THEN p_status IN ('assigned','on_hold','cancelled')
    WHEN 'in_progress' THEN p_status IN ('in_progress','on_hold','cancelled')
    WHEN 'reported'    THEN p_status IN ('done','cancelled')
    WHEN 'received'    THEN p_status IN ('done','verified','cancelled')
    WHEN 'closed'      THEN p_status IN ('verified')
    ELSE false END
$$;
-- Note : « Un OT annulé garde l'étape atteinte et prend status = 'cancelled' » (même paragraphe) : cancelled est
-- donc admis à toutes les étapes avant la clôture, y compris in_progress, reported et received, que le tableau omet.
-- Interprétation validée par Oss53pa (21/11/2026).

-- C11 : keystone.new_qr_token(), Annexe A (locations.qr_token) : « jeton opaque, 12 caractères base32 ».
-- Interprétation validée par Oss53pa (21/11/2026) : alphabet RFC 4648 (A à Z, 2 à 7), 60 bits d'aléa cryptographique (pgcrypto). VOLATILE.
CREATE OR REPLACE FUNCTION keystone.new_qr_token() RETURNS text LANGUAGE plpgsql VOLATILE AS $$
DECLARE
  a constant text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  b bytea := extensions.gen_random_bytes(12);
  r text := '';
BEGIN
  FOR i IN 0..11 LOOP r := r || substr(a, (get_byte(b, i) % 32) + 1, 1); END LOOP;
  RETURN r;
END $$;

-- C12 (avec la substitution S01) : secteur du client, Annexe M. La table client_sectors (Référentiels transverses) est
-- unique sur (tenant_id, code) : la référence se fait par le couple, un code n'étant unique qu'au sein d'un tenant [Confirmé].
ALTER TABLE keystone.clients
  ADD CONSTRAINT fk_clients_sector FOREIGN KEY (tenant_id, sector_code) REFERENCES keystone.client_sectors (tenant_id, code);

-- C14 (avec la substitution S02) : DA rattachée à l'OT (D31, Annexe B). work_orders et purchase_requests se référencent
-- mutuellement : la clé de work_orders est posée après la création des deux tables, sans changer sa règle [Confirmé].
ALTER TABLE keystone.work_orders
  ADD CONSTRAINT fk_wo_purchase_request FOREIGN KEY (purchase_request_id) REFERENCES keystone.purchase_requests (id) ON DELETE RESTRICT;

-- C16 (avec S05 et S06) : échéances dérivées, auparavant colonnes générées refusées (timestamptz + interval n'est pas
-- IMMUTABLE). Même valeur, recalculée à chaque écriture ; la colonne reste en lecture seule pour l'application.
CREATE OR REPLACE FUNCTION keystone.tg_derived_deadlines() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'operating_mode_changes' THEN NEW.revert_deadline := NEW.applied_at + interval '30 days';
  ELSIF TG_TABLE_NAME = 'privacy_breaches' THEN NEW.authority_due_at := NEW.aware_at + interval '72 hours';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_omc_revert_deadline BEFORE INSERT OR UPDATE ON atlas_core.operating_mode_changes
  FOR EACH ROW EXECUTE FUNCTION keystone.tg_derived_deadlines();
CREATE TRIGGER trg_breach_authority_due BEFORE INSERT OR UPDATE ON keystone.privacy_breaches
  FOR EACH ROW EXECUTE FUNCTION keystone.tg_derived_deadlines();

-- C17 : keystone.object_visible, Annexe A partie 4 §A.22 : « STABLE, SECURITY INVOKER ; vrai si la ligne de work_orders
-- ou assets est lisible sous la RLS de l'appelant » [Confirmé]. Toute autre entité : faux.
CREATE OR REPLACE FUNCTION keystone.object_visible(p_entity text, p_id uuid) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = keystone, pg_temp AS $$
BEGIN
  IF p_entity = 'work_orders' THEN RETURN EXISTS (SELECT 1 FROM keystone.work_orders WHERE id = p_id);
  ELSIF p_entity = 'assets' THEN RETURN EXISTS (SELECT 1 FROM keystone.assets WHERE id = p_id);
  END IF;
  RETURN false;
END $$;

-- C18 : keystone.vendor_docs_ok_rate, Annexe P : « jours où ok est vrai divisés par p_days, lus dans vendor_doc_daily_status »
-- [Confirmé]. Fenêtre : les p_days derniers jours jusqu'à hier inclus (la tâche nocturne écrit la veille).
CREATE OR REPLACE FUNCTION keystone.vendor_docs_ok_rate(p_vendor uuid, p_days integer) RETURNS numeric
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = keystone, pg_temp AS $$
  SELECT CASE WHEN p_days IS NULL OR p_days <= 0 THEN NULL ELSE
    (SELECT count(*) FROM keystone.vendor_doc_daily_status d
      WHERE d.tenant_id = keystone.current_tenant() AND d.vendor_id = p_vendor AND d.ok
        AND d.day BETWEEN current_date - p_days AND current_date - 1)::numeric / p_days END
$$;

-- C19 : keystone.log_presence_access, Annexe S : « écrit une ligne de journal par session et par site (au plus une par
-- 15 minutes) et renvoie vrai ». Interprétation : action 'layer_view', une ligne par utilisateur et site par 15 minutes
-- (pas d'identifiant de session dans presence_access_log). SECURITY DEFINER pour écrire le journal sans droit d'écriture
-- de l'appelant. Limite signalée : appelée depuis une politique de lecture, elle échoue en transaction en lecture seule.
CREATE OR REPLACE FUNCTION keystone.log_presence_access(p_site uuid) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE v_user uuid := auth.uid(); v_tenant uuid := keystone.current_tenant();
BEGIN
  IF v_user IS NULL OR v_tenant IS NULL OR p_site IS NULL THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM keystone.presence_access_log
                  WHERE tenant_id = v_tenant AND user_id = v_user AND site_id = p_site
                    AND action = 'layer_view' AND at > now() - interval '15 minutes') THEN
    INSERT INTO keystone.presence_access_log (tenant_id, user_id, site_id, action) VALUES (v_tenant, v_user, p_site, 'layer_view');
  END IF;
  RETURN true;
END $$;
REVOKE EXECUTE ON FUNCTION keystone.log_presence_access(uuid) FROM PUBLIC, anon;

-- C20 : keystone.audit_pseudonymize, appelée par keystone.tg_audit (Annexe A) mais jamais définie. Spécification :
-- CDC fonctionnel 08 partie 2 (« colonnes personnelles remplacées par un jeton psn:<uuid> (audit_pseudonymize) »),
-- tables audit_personal_fields et pseudonym_map (Annexe A) [Confirmé]. Une même valeur d'une même personne garde
-- le même jeton (contrainte unique de pseudonym_map) ; conservation bornée par retention_months ; l'effacement
-- (privacy_erase_subject) vide pseudonym_map.value sans toucher à la chaîne d'audit.
CREATE OR REPLACE FUNCTION keystone.audit_pseudonymize(p_tenant uuid, p_table name, p_row jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, extensions, pg_temp AS $$
DECLARE f record; v text; s uuid; h char(64); tok uuid; out jsonb := p_row;
BEGIN
  IF p_row IS NULL THEN RETURN NULL; END IF;
  FOR f IN SELECT column_name, subject_column, retention_months FROM keystone.audit_personal_fields WHERE table_name = p_table LOOP
    v := p_row ->> f.column_name;
    CONTINUE WHEN v IS NULL;
    s := nullif(p_row ->> f.subject_column, '')::uuid;
    CONTINUE WHEN s IS NULL;
    h := encode(extensions.digest(convert_to(v, 'UTF8'), 'sha256'), 'hex');
    INSERT INTO keystone.pseudonym_map (tenant_id, subject_id, table_name, column_name, value_sha256, value, retention_until)
    VALUES (p_tenant, s, p_table, f.column_name, h, v, (current_date + make_interval(months => f.retention_months))::date)
    ON CONFLICT (tenant_id, subject_id, table_name, column_name, value_sha256) DO NOTHING;
    SELECT token INTO tok FROM keystone.pseudonym_map
     WHERE tenant_id = p_tenant AND subject_id = s AND table_name = p_table AND column_name = f.column_name AND value_sha256 = h;
    out := jsonb_set(out, ARRAY[f.column_name], to_jsonb('psn:' || tok::text));
  END LOOP;
  RETURN out;
END $$;
REVOKE EXECUTE ON FUNCTION keystone.audit_pseudonymize(uuid, name, jsonb) FROM PUBLIC, anon, authenticated;

-- C21 : keystone.pr_link_work_order (Annexe E) n'exigeait aucune permission (SECURITY DEFINER, limitée au tenant).
-- Décision d'Oss53pa (22/11/2026) : purchase.request exigée de tout utilisateur connecté (cohérent avec D31) ;
-- les tâches de fond (sans utilisateur, service_role) restent autorisées. Corps inchangé par ailleurs.
CREATE OR REPLACE FUNCTION keystone.pr_link_work_order(p_request uuid, p_work_order uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN PERFORM keystone.assert_permission('purchase.request'); END IF;
  PERFORM set_config('keystone.pr_link', 'on', true);
  UPDATE keystone.purchase_requests SET work_order_id = p_work_order
   WHERE id = p_request AND tenant_id = keystone.current_tenant()
     AND (work_order_id IS NULL OR work_order_id = p_work_order OR p_work_order IS NULL);
  IF p_work_order IS NOT NULL THEN
    UPDATE keystone.work_orders SET purchase_request_id = p_request
     WHERE id = p_work_order AND tenant_id = keystone.current_tenant()
       AND purchase_request_id IS DISTINCT FROM p_request;     -- passe trg_wo_purchase_request_link (B.15.2)
  END IF;
  PERFORM set_config('keystone.pr_link', 'off', true);
END $$;

-- C22 : site_tz et sla_effective_due (SECURITY DEFINER) lisaient sans filtre de tenant : un identifiant connu suffisait
-- à lire le fuseau d'un site ou les pauses SLA d'un OT d'un autre client. Filtre ajouté pour tout utilisateur connecté ;
-- les tâches de fond (sans utilisateur) gardent la lecture complète. Calcul inchangé.
CREATE OR REPLACE FUNCTION keystone.site_tz(p_site uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = atlas_core, pg_temp AS $$
  SELECT time_zone FROM atlas_core.sites
   WHERE id = p_site AND (auth.uid() IS NULL OR tenant_id = keystone.current_tenant()) $$;
CREATE OR REPLACE FUNCTION keystone.sla_effective_due(p_due timestamptz, p_wo uuid, p_clock keystone.sla_clock) RETURNS timestamptz
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  -- échéance plus pauses de l'OT lié qui portent l'horloge (A07, sla_pauses de l'Annexe B)
  SELECT p_due + coalesce(sum(coalesce(sp.ended_at, now()) - sp.started_at), interval '0')
    FROM keystone.sla_pauses sp
   WHERE sp.work_order_id = p_wo AND p_clock = ANY (sp.clocks)
     AND (auth.uid() IS NULL OR sp.tenant_id = keystone.current_tenant()) $$;

-- C23 : consume_part (sortie de pièce) et wo_punch (pointage d'OT) écrivaient en se limitant au technicien appelant,
-- sans permission. Décision d'Oss53pa (22/11/2026) : wo.execute exigée (« pointer, exécuter, renseigner checklist et
-- pièces », Admin partie 2 §1.3) pour tout utilisateur connecté ; tâches de fond inchangées. Corps d'origine repris tel quel,
-- seul le contrôle est inséré en tête.
CREATE OR REPLACE FUNCTION keystone.consume_part(p_part uuid, p_qty numeric, p_wo uuid, p_meta jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'keystone', 'pg_temp'
AS $function$
DECLARE p keystone.spare_parts; w keystone.work_orders; r keystone.stock_reservations; v_mv uuid; v_val bigint;
BEGIN
  IF auth.uid() IS NOT NULL THEN PERFORM keystone.assert_permission('wo.execute'); END IF;
  SELECT * INTO w FROM keystone.work_orders WHERE id = p_wo AND tenant_id = keystone.current_tenant();
  IF NOT FOUND THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  IF w.status NOT IN ('in_progress','on_hold') THEN
    PERFORM keystone.raise_error('INVALID_TRANSITION'); END IF;
  SELECT * INTO p FROM keystone.spare_parts WHERE id = p_part AND tenant_id = w.tenant_id FOR UPDATE;
  PERFORM keystone.stock_owner_check(p.warehouse_id, w);                 -- STOCK_OWNER_MISMATCH
  SELECT * INTO r FROM keystone.stock_reservations
   WHERE part_id = p_part AND work_order_id = p_wo AND status = 'active' FOR UPDATE;
  -- disponible pour cet OT = disponible général plus son propre reliquat réservé
  IF p_qty > p.available_qty + coalesce(r.qty - r.consumed_qty, 0) THEN
    PERFORM keystone.raise_error('INSUFFICIENT_STOCK', jsonb_build_object('available', p.available_qty, 'requested', p_qty));
  END IF;
  v_val := keystone.round_half_even(p_qty * p.avg_unit_cost);
  INSERT INTO keystone.stock_movements(tenant_id, part_id, direction, qty, unit_cost, value, qty_after,
         avg_cost_after, work_order_id, reservation_id, reason, created_by)
  VALUES (w.tenant_id, p_part, 'out', -p_qty, p.avg_unit_cost, -v_val, p.qty - p_qty, p.avg_unit_cost,
          p_wo, r.id, 'wo_consumption', auth.uid()) RETURNING id INTO v_mv;
  UPDATE keystone.spare_parts SET qty = qty - p_qty WHERE id = p_part;
  IF r.id IS NOT NULL THEN
    UPDATE keystone.stock_reservations SET consumed_qty = least(qty, consumed_qty + p_qty),
           status = CASE WHEN consumed_qty + p_qty >= qty THEN 'consumed' ELSE status END,
           closed_at = CASE WHEN consumed_qty + p_qty >= qty THEN now() END
     WHERE id = r.id;
  END IF;
  INSERT INTO keystone.work_order_lines(tenant_id, work_order_id, kind, phase, label, qty, unit, unit_cost,
         amount, currency, part_id, stock_movement_id)
  VALUES (w.tenant_id, p_wo, 'part', 'actual', p.name, p_qty, p.unit, p.avg_unit_cost, v_val, p.currency, p_part, v_mv);
  PERFORM keystone.notify_if_below_min(p_part);   -- notification et suggestion de demande d'achat (RG-STK-04)
  RETURN v_mv;
END; $function$;
CREATE OR REPLACE FUNCTION keystone.wo_punch(p_wo uuid, p_action wo_punch_action, p_meta jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'keystone', 'pg_temp'
AS $function$
DECLARE w keystone.work_orders; r jsonb; v_person uuid; v_scan uuid; v_at timestamptz;
BEGIN
  IF auth.uid() IS NOT NULL THEN PERFORM keystone.assert_permission('wo.execute'); END IF;
  SELECT * INTO w FROM keystone.work_orders WHERE id = p_wo AND tenant_id = keystone.current_tenant() FOR UPDATE;
  IF NOT FOUND THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  v_person := keystone.current_person_id();
  IF v_person IS DISTINCT FROM w.assignee_id
     AND NOT EXISTS (SELECT 1 FROM keystone.work_order_team WHERE work_order_id = w.id AND person_id = v_person)
  THEN PERFORM keystone.raise_error('PERMISSION_DENIED'); END IF;

  -- Heure de terrain (A94) : occurred_at de l'appareil, bornée par l'heure de réception serveur
  v_at := keystone.field_time(w, p_meta);
  p_meta := p_meta || jsonb_build_object('field_at', v_at);   -- lu par T09, T14, T20

  -- Scan obligatoire à chaque pointage
  IF w.asset_id IS NOT NULL OR w.location_id IS NOT NULL THEN
    IF p_meta->>'scanned_identifier' IS NULL THEN PERFORM keystone.raise_error('SCAN_REQUIRED'); END IF;
    r := keystone.resolve_identifier(p_meta->>'scanned_identifier');
    IF NOT keystone.wo_scan_matches(w, r) THEN
      PERFORM keystone.raise_error('SCAN_MISMATCH', jsonb_build_object('scanned', r)); END IF;
    INSERT INTO keystone.wo_scan_log(tenant_id, work_order_id, action, identifier, resolved_kind, resolved_id,
           scanned_by, person_id, scanned_at, offline, device_session_id,
           briefing_ack_at, ppe_confirmed, briefing_version)
    VALUES (w.tenant_id, w.id, p_action, p_meta->>'scanned_identifier', r->>'kind', (r->>'id')::uuid,
           auth.uid(), v_person, v_at,
           coalesce((p_meta->>'offline')::boolean, false), (p_meta->>'device_session_id')::uuid,
           CASE WHEN p_action = 'start' AND (p_meta->>'briefing_ack')::boolean THEN v_at END,
           CASE WHEN p_action = 'start' THEN ARRAY(SELECT jsonb_array_elements_text(coalesce(p_meta->'ppe_confirmed','[]'))) END,
           CASE WHEN p_action = 'start' THEN p_meta->>'briefing_version' END)
    RETURNING id INTO v_scan;
  END IF;

  CASE p_action
    WHEN 'diagnose_start' THEN                    -- visite de diagnostic, statut planned
      IF w.status <> 'planned' THEN PERFORM keystone.raise_error('INVALID_PUNCH'); END IF;
      PERFORM keystone.wo_session_open(w, v_person, 'diagnosis', v_scan, v_at);
    WHEN 'diagnose_end' THEN
      PERFORM keystone.wo_session_close(w, v_person, 'diagnosis', v_scan, v_at);
    WHEN 'start' THEN
      IF w.status = 'assigned' AND w.stage = 'committed' THEN
        PERFORM keystone.wo_transition(p_wo, 'in_progress', 'in_progress', p_meta);
      ELSIF w.status = 'in_progress' AND w.rework_pending THEN   -- redémarrage après reprise T17
        PERFORM keystone.wo_guard_permit_required(w, p_meta);
        UPDATE keystone.work_orders SET rework_pending = false WHERE id = w.id;
      ELSIF w.status = 'draft' AND w.priority = 1 THEN          -- urgence P1, T20
        PERFORM keystone.wo_transition(p_wo, 'in_progress', 'in_progress', p_meta || '{"emergency":true}');
      ELSE PERFORM keystone.raise_error('INVALID_PUNCH'); END IF;
      PERFORM keystone.wo_session_open(w, v_person, 'intervention', v_scan, v_at);
    WHEN 'pause' THEN
      PERFORM keystone.wo_session_close(w, v_person, 'intervention', v_scan, v_at);
      IF NOT keystone.wo_has_open_session(w.id) THEN
        PERFORM keystone.wo_transition(p_wo, 'in_progress', 'on_hold', p_meta || '{"hold_reason":"technician_break"}');
      END IF;
    WHEN 'resume' THEN
      IF w.status = 'on_hold' THEN PERFORM keystone.wo_transition(p_wo, 'in_progress', 'in_progress', p_meta); END IF;
      PERFORM keystone.wo_session_open(w, v_person, 'intervention', v_scan, v_at);
    WHEN 'finish' THEN
      PERFORM keystone.wo_session_close(w, v_person, 'intervention', v_scan, v_at);
      IF NOT keystone.wo_has_open_session(w.id) THEN
        PERFORM keystone.wo_transition(p_wo, 'reported', 'done', p_meta);
      END IF;
  END CASE;

  -- Présence (Annexe S) : on_wo au start et au resume, break à la pause, on_duty à la fin
  PERFORM keystone.presence_write_from_punch(w, v_person, p_action, v_scan);
END; $function$;
