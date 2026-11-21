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
