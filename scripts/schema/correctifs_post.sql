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
