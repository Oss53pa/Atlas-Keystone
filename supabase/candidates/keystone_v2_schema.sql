-- Schéma candidat Atlas Keystone, généré par scripts/schema/emit_candidate.py. NE PAS APPLIQUER EN L'ÉTAT.
-- 1464 instructions réussies sur 1504 ; 40 écarts restants : docs/lot0 §6.
-- Prérequis : extensions (pgcrypto, postgis, vector, pg_trgm, btree_gist, unaccent, pg_jsonschema),
-- puis scripts/schema/correctifs_corpus.sql.
BEGIN;
SET LOCAL search_path = keystone, atlas_core, public, extensions;

-- prelude
CREATE SCHEMA IF NOT EXISTS atlas_core;

-- prelude
CREATE SCHEMA IF NOT EXISTS atlas_public;

-- prelude
CREATE SCHEMA IF NOT EXISTS keystone;

-- Referentiels_Transverses#1
CREATE TYPE keystone.risk_level        AS ENUM ('low','medium','high','critical');

-- Referentiels_Transverses#1
CREATE TYPE keystone.asset_criticality AS ENUM ('low','medium','high','safety_critical');

-- Referentiels_Transverses#1
-- D06
CREATE TYPE keystone.employment_type   AS ENUM ('permanent','temporary','contractor','visitor');

-- Referentiels_Transverses#1
-- A52, persons.employment_type
CREATE TYPE keystone.vendor_role       AS ENUM ('service_provider','goods_supplier');

-- Referentiels_Transverses#2
CREATE OR REPLACE FUNCTION keystone.risk_band(p_score int) RETURNS keystone.risk_level
  LANGUAGE sql IMMUTABLE SET search_path = keystone, pg_temp AS $$
  SELECT CASE
    WHEN p_score BETWEEN 1  AND 4  THEN 'low'
    WHEN p_score BETWEEN 5  AND 9  THEN 'medium'
    WHEN p_score BETWEEN 10 AND 14 THEN 'high'
    WHEN p_score BETWEEN 15 AND 25 THEN 'critical'
  END::keystone.risk_level $$;

-- Referentiels_Transverses#3
CREATE TYPE keystone.wo_type   AS ENUM ('corrective','preventive','conditional','predictive','regulatory','service');

-- Referentiels_Transverses#3
-- 'service' : passages Soft FM (D11)
CREATE TYPE keystone.wo_status AS ENUM ('draft','planned','assigned','in_progress','on_hold','done','verified','cancelled');

-- Referentiels_Transverses#3
CREATE TYPE keystone.wo_stage  AS ENUM ('emitted','sent','diagnosed','scheduled','quoted','covered','committed',
                                         'in_progress','reported','received','closed');

-- Referentiels_Transverses#3
-- A03
CREATE TYPE keystone.wo_team_role    AS ENUM ('lead','member');

-- Referentiels_Transverses#4
CREATE TYPE keystone.event_severity  AS ENUM ('minor','moderate','serious','major','catastrophic');

-- Referentiels_Transverses#4
CREATE TYPE keystone.permit_section  AS ENUM ('hot_work','work_at_height','electrical','confined_space','excavation','lifting');

-- Referentiels_Transverses#4
-- D09
CREATE TYPE keystone.inspection_kind AS ENUM ('inspection','soft_fm_qc','hsse_round');

-- Referentiels_Transverses#5
CREATE TYPE keystone.space_unit_type AS ENUM ('tenant_lot','common_area','technical_room','office','circulation','parking','outdoor');

-- Referentiels_Transverses#6
-- types atlas_core.operating_mode et atlas_core.subscription_status : propriétaire Annexe CO
CREATE TYPE keystone.surface_code     AS ENUM ('console','field_app','vendor_portal','occupant_portal','client_portal');

-- Referentiels_Transverses#6
CREATE TYPE keystone.profile_kind     AS ENUM ('internal','vendor','occupant','client');

-- Referentiels_Transverses#6
CREATE TYPE keystone.user_status      AS ENUM ('invited','active','dormant','disabled');

-- Referentiels_Transverses#6
CREATE TYPE keystone.notification_channel  AS ENUM ('push','email','sms','whatsapp');

-- Referentiels_Transverses#6
CREATE TYPE keystone.notification_status   AS ENUM ('queued','sent','delivered','bounced','complained','failed','suppressed','digested');

-- Referentiels_Transverses#6
CREATE TYPE keystone.notification_category AS ENUM ('account_security','people_safety_regulatory','contractual','operational','digest');

-- Referentiels_Transverses#6
CREATE TYPE keystone.digest_frequency AS ENUM ('immediate','daily','weekly');

-- Referentiels_Transverses#6
CREATE TYPE keystone.setting_status   AS ENUM ('draft','pending_approval','effective','superseded','rejected');

-- Referentiels_Transverses#6
CREATE TYPE keystone.access_review_status AS ENUM ('open','closed');

-- Referentiels_Transverses#6
CREATE TYPE keystone.access_review_decision AS ENUM ('pending','confirmed','revoked','expired');

-- Referentiels_Transverses#6
CREATE TYPE keystone.template_status  AS ENUM ('draft','published','archived');

-- Referentiels_Transverses#6
CREATE TYPE keystone.suppression_reason AS ENUM ('hard_bounce','complaint','unsubscribe');

-- Referentiels_Transverses#6
CREATE TYPE keystone.onboarding_status AS ENUM ('not_started','in_progress','completed');

-- Referentiels_Transverses#6
CREATE DOMAIN keystone.notification_event_key AS text
  CHECK (VALUE ~ '^[a-z][a-z_]*\.[a-z][a-z_]*$');

-- AnnexeCO_Atlas_Core#1
-- keystone.operating_mode ('in_house','fm_provider') : défini dans les Référentiels transverses §1, renvoi.
-- atlas_core.subscription_status : propriétaire unique, la présente annexe ; les Référentiels transverses y renvoient.
CREATE TYPE atlas_core.subscription_status AS ENUM ('trial','active','past_due','grace','suspended','cancelled');

-- AnnexeCO_Atlas_Core#1
CREATE TYPE atlas_core.mode_change_status AS ENUM ('requested','analyzed','prepared','approved','applied',
                                         'reverted','closed','rejected','failed');

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.currencies (
  code       char(3) PRIMARY KEY,                    -- ISO 4217
  minor_unit int NOT NULL CHECK (minor_unit BETWEEN 0 AND 4),   -- XOF 0, XAF 0, EUR 2
  label      text NOT NULL
);

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.country_config (             -- existant (CDC v3 §4.1), colonnes lues par Keystone
  country_code     char(2) PRIMARY KEY,              -- ISO 3166-1 alpha-2
  currency         char(3) NOT NULL REFERENCES atlas_core.currencies(code),
  default_timezone text NOT NULL,                    -- IANA
  default_locale   text NOT NULL,                    -- fr-CI, fr-SN, fr-CM, fr-GA
  ui_languages     text[] NOT NULL DEFAULT '{fr}',
  zone             text NOT NULL CHECK (zone IN ('UEMOA','CEMAC','other')),
  privacy_authority text,                            -- ARTCI (CI), CDP (SN), autorités du Cameroun et du Gabon
  privacy_formalities jsonb NOT NULL DEFAULT '[]'::jsonb  -- référentiel : [{kind, label, legal_basis, required}]
);

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.tenants (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug             text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9-]{2,31}$'),   -- domaine de l'abonnement
  display_name     text NOT NULL,
  country_code     char(2) NOT NULL REFERENCES atlas_core.country_config(country_code), -- pays du siège
  default_currency char(3) NOT NULL REFERENCES atlas_core.currencies(code),           -- devise de consolidation
  operating_mode   keystone.operating_mode,                   -- projection de subscription_products (CO.3)
  status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active','purging','purged')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.legal_entities (             -- existant, colonnes lues par Keystone
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  name         text NOT NULL,
  country_code char(2) NOT NULL REFERENCES atlas_core.country_config(country_code),
  currency     char(3) NOT NULL REFERENCES atlas_core.currencies(code),
  rccm         text,                                 -- registre du commerce OHADA
  tax_id       text,
  is_active    boolean NOT NULL DEFAULT true
);

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.owner_admin (                -- l'acheteur, unique par tenant (RG-ABO-02)
  tenant_id  uuid PRIMARY KEY REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  user_id    uuid NOT NULL,                          -- auth.users.id
  full_name  text NOT NULL,
  email      text NOT NULL,
  since      timestamptz NOT NULL DEFAULT now()
);

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.owner_transfers (            -- évolution, à valider (transfert d'acheteur)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id),
  from_user_id uuid NOT NULL, to_user_id uuid NOT NULL,
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 10 AND 500),   -- motif saisi par l'acheteur (L10-33)
  requested_at timestamptz NOT NULL DEFAULT now(), accepted_at timestamptz, executed_by uuid,
  cancelled_at timestamptz, cancelled_by uuid,
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','accepted','executed','cancelled')),
  CONSTRAINT ck_owner_transfer_distinct CHECK (from_user_id <> to_user_id),
  CONSTRAINT ck_owner_transfer_cancel CHECK (status <> 'cancelled' OR cancelled_at IS NOT NULL)
);

-- AnnexeCO_Atlas_Core#1
CREATE UNIQUE INDEX uq_owner_transfer_open ON atlas_core.owner_transfers (tenant_id) WHERE status IN ('requested','accepted');

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.platform_maintenance_windows (   -- évolution, à valider (Lot 2, bandeau de maintenance)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL,
  announced_at timestamptz NOT NULL DEFAULT now(),
  products text[] NOT NULL DEFAULT '{keystone}',     -- valeurs de subscription_products.product_code
  surfaces text[] NOT NULL DEFAULT '{console,client_portal,vendor_portal,occupant_portal,field_app}',
  region text NOT NULL DEFAULT 'all' CHECK (region IN ('all','paris','frankfurt')),   -- A57
  impact text NOT NULL CHECK (impact IN ('read_only','unavailable','degraded')),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
  note_fr text CHECK (length(note_fr) <= 200), note_en text CHECK (length(note_en) <= 200),
  created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_maint_window CHECK (ends_at > starts_at AND ends_at - starts_at <= interval '4 hours'),
  CONSTRAINT ck_maint_notice CHECK (starts_at - announced_at >= interval '72 hours')   -- NF.4 : maintenance annoncée 72 h avant
);

-- AnnexeCO_Atlas_Core#1
CREATE INDEX ix_maint_windows_time ON atlas_core.platform_maintenance_windows (starts_at, ends_at) WHERE status IN ('scheduled','in_progress');

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.subscriptions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  is_current          boolean NOT NULL DEFAULT true,
  status              atlas_core.subscription_status NOT NULL,
  billing_cycle       text NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
  period_start        date NOT NULL,
  period_end          date NOT NULL,
  trial_ends_at       timestamptz,
  past_due_since      timestamptz,
  grace_started_at    timestamptz,
  grace_ends_at       timestamptz,                   -- grace_started_at + 30 jours (Q09)
  suspended_at        timestamptz,
  cancel_requested_at timestamptz,
  cancel_effective_at timestamptz,
  purge_due_at        timestamptz,                   -- début de grâce ou fin effective + 90 jours (Q09)
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_sub_period CHECK (period_end >= period_start),
  CONSTRAINT ck_sub_trial CHECK (status <> 'trial' OR trial_ends_at IS NOT NULL),
  CONSTRAINT ck_sub_grace CHECK (status <> 'grace' OR (grace_started_at IS NOT NULL AND grace_ends_at IS NOT NULL)),
  CONSTRAINT ck_sub_cancel CHECK (status <> 'cancelled' OR cancel_effective_at IS NOT NULL)
);

-- AnnexeCO_Atlas_Core#1
CREATE UNIQUE INDEX uq_subscription_current ON atlas_core.subscriptions (tenant_id) WHERE is_current;

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.subscription_products (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  subscription_id uuid NOT NULL REFERENCES atlas_core.subscriptions(id) ON DELETE RESTRICT,
  product_code    text NOT NULL CHECK (product_code IN ('keystone','trace','patrimoine','fna','trade','people')),
  operating_mode  keystone.operating_mode,                    -- obligatoire pour keystone
  options         text[] NOT NULL DEFAULT '{}',      -- 'parking' par exemple
  limits          jsonb NOT NULL DEFAULT '{}'::jsonb,-- plafonds contractuels, évolution, à valider
  status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','removed')),
  started_at      timestamptz NOT NULL DEFAULT now(),
  ended_at        timestamptz,
  CONSTRAINT ck_keystone_mode CHECK (product_code <> 'keystone' OR operating_mode IS NOT NULL),
  CONSTRAINT ck_mode_keystone_only CHECK (product_code = 'keystone' OR operating_mode IS NULL)
);

-- AnnexeCO_Atlas_Core#1
CREATE UNIQUE INDEX uq_subscription_product_active
  ON atlas_core.subscription_products (subscription_id, product_code) WHERE status = 'active';

-- AnnexeCO_Atlas_Core#1
CREATE TABLE atlas_core.platform_events (            -- outbox lue par les produits
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id   uuid NOT NULL,
  event       text NOT NULL CHECK (event IN ('tenant.created','subscription.status_changed','product.added',
                'product.removed','product.options_changed','operating_mode.change_requested',
                'operating_mode.change_approved','operating_mode.changed','operating_mode.reverted',
                'owner.transferred','legal_entity.created','legal_entity.updated','tenant.purge_scheduled')),
  payload     jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeCO_Atlas_Core#1
CREATE INDEX ix_platform_events_tenant ON atlas_core.platform_events (tenant_id, id);

-- AnnexeCO_Atlas_Core#3
-- 'full' | 'read_only' | 'export_only' | 'none'
CREATE OR REPLACE FUNCTION keystone.subscription_access_for(p_tenant uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = atlas_core, pg_temp AS $$
  SELECT coalesce((
    SELECT CASE
      WHEN NOT EXISTS (SELECT 1 FROM atlas_core.subscription_products p
                       WHERE p.subscription_id = s.id AND p.product_code = 'keystone' AND p.status = 'active')
        THEN 'none'
      WHEN s.status = 'trial' AND now() < s.trial_ends_at THEN 'full'
      WHEN s.status IN ('active','past_due') THEN 'full'
      WHEN s.status = 'grace' THEN 'read_only'
      WHEN s.status = 'cancelled' AND now() < s.cancel_effective_at + interval '30 days' THEN 'read_only'
      WHEN s.status IN ('suspended','cancelled') AND now() < s.purge_due_at THEN 'export_only'
      ELSE 'none' END
    FROM atlas_core.subscriptions s
    WHERE s.tenant_id = p_tenant AND s.is_current), 'none') $$;

-- AnnexeCO_Atlas_Core#4
CREATE TABLE keystone.platform_event_offsets (
  consumer   text PRIMARY KEY CHECK (consumer IN ('platform_events','spatial_events')),
  last_id    bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeCO_Atlas_Core#4
CREATE TABLE keystone.tenant_provisioning (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  trigger_event_id bigint NOT NULL,
  step        text NOT NULL CHECK (step IN ('settings','rbac','buyer_profile','calendars','reference_data',
                                            'surfaces','onboarding','invitation')),
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','done','failed')),
  attempts    int NOT NULL DEFAULT 0,
  last_error  text,
  started_at  timestamptz, finished_at timestamptz,
  CONSTRAINT uq_provisioning_step UNIQUE (tenant_id, trigger_event_id, step)
);

-- AnnexeCO_Atlas_Core#6
CREATE TYPE atlas_core.identity_protocol AS ENUM ('saml','oidc');

-- AnnexeCO_Atlas_Core#6
CREATE TYPE atlas_core.identity_provider_status AS ENUM ('draft','testing','active','disabled');

-- AnnexeCO_Atlas_Core#6
CREATE TABLE atlas_core.identity_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  protocol atlas_core.identity_protocol NOT NULL,
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 2 AND 60),   -- libellé du bouton de connexion
  status atlas_core.identity_provider_status NOT NULL DEFAULT 'draft',
  -- SAML 2.0 (Supabase Auth, auth.sso_providers)
  auth_sso_provider_id uuid,                         -- identifiant renvoyé par l'API d'administration de Supabase Auth
  saml_metadata_url text CHECK (saml_metadata_url IS NULL OR saml_metadata_url ~ '^https://'),
  saml_metadata_xml text CHECK (saml_metadata_xml IS NULL OR octet_length(saml_metadata_xml) <= 262144),
  saml_entity_id text, saml_certificate_expires_at timestamptz,
  -- OpenID Connect
  oidc_issuer text CHECK (oidc_issuer IS NULL OR oidc_issuer ~ '^https://'),
  oidc_client_id text,
  oidc_client_secret_ref uuid,                       -- secret dans Supabase Vault, jamais en clair
  -- attributs reçus
  attribute_map jsonb NOT NULL DEFAULT '{"email":"email","full_name":"name","groups":"groups"}',
  enforce_sso boolean NOT NULL DEFAULT false,        -- connexion par mot de passe refusée aux domaines vérifiés
  last_test_at timestamptz, last_test_result jsonb,  -- {"ok": bool, "error_code": text, "attributes_received": [noms seuls]}
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT ck_idp_saml CHECK (protocol <> 'saml' OR saml_metadata_url IS NOT NULL OR saml_metadata_xml IS NOT NULL),
  CONSTRAINT ck_idp_oidc CHECK (protocol <> 'oidc' OR (oidc_issuer IS NOT NULL AND oidc_client_id IS NOT NULL
                                                      AND oidc_client_secret_ref IS NOT NULL))
);

-- AnnexeCO_Atlas_Core#6
CREATE UNIQUE INDEX ux_idp_active ON atlas_core.identity_providers (tenant_id) WHERE status = 'active';

-- AnnexeCO_Atlas_Core#6
-- un fournisseur actif par tenant

CREATE TABLE atlas_core.identity_provider_domains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES atlas_core.identity_providers(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  domain text NOT NULL CHECK (domain ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'),
  verification_token text NOT NULL,                  -- enregistrement TXT « atlas-verify=<jeton> »
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeCO_Atlas_Core#6
CREATE UNIQUE INDEX ux_idp_domain ON atlas_core.identity_provider_domains (lower(domain));

-- AnnexeA_Socle#2
CREATE OR REPLACE FUNCTION keystone.tg_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  NEW.updated_by := auth.uid();
  RETURN NEW;
END $$;

-- AnnexeA_Socle#3
-- Tenant courant (jeton)
CREATE OR REPLACE FUNCTION keystone.current_tenant() RETURNS uuid
LANGUAGE sql STABLE AS $$ SELECT (auth.jwt() ->> 'tenant_id')::uuid $$;

-- AnnexeA_Socle#6
-- Définis une seule fois dans les Référentiels transverses §1.1 (renvoi, aucune création ici) :
--   keystone.asset_criticality (D06), keystone.identifier_type, keystone.employment_type (A52), keystone.risk_level
CREATE TYPE keystone.asset_status        AS ENUM ('operational','down','maintenance','decommissioned');

-- AnnexeA_Socle#6
CREATE TYPE keystone.asset_status_source AS ENUM ('manual','work_order','regulatory_control','iot_alert','import');

-- AnnexeA_Socle#6
CREATE TYPE keystone.maintenance_strategy AS ENUM ('time_based','condition_based','predictive','corrective');

-- AnnexeA_Socle#6
CREATE TYPE keystone.person_type         AS ENUM ('employee','contractor','visitor');

-- AnnexeA_Socle#6
CREATE TYPE keystone.person_status       AS ENUM ('proposed','active','inactive');

-- AnnexeA_Socle#6
CREATE TYPE keystone.site_ops_status     AS ENUM ('pre_opening','active','closed');

-- AnnexeA_Socle#6
CREATE TYPE keystone.duty_cycle          AS ENUM ('continuous','site_hours');

-- AnnexeA_Socle#6
-- évolution, à valider
CREATE TYPE atlas_core.spatial_status    AS ENUM ('draft','published','retired');

-- AnnexeA_Socle#6
CREATE TYPE keystone.calendar_day_kind   AS ENUM ('public_holiday','site_closure','special_opening');

-- AnnexeA_Socle#6
CREATE TYPE keystone.holiday_rule        AS ENUM ('fixed','easter_offset','hijri','one_off');

-- AnnexeA_Socle#6
CREATE TYPE keystone.import_batch_status AS ENUM ('uploaded','mapped','validated','committed','rolled_back','failed');

-- AnnexeA_Socle#6
CREATE TYPE keystone.import_row_status   AS ENUM ('valid','error','excluded','imported','rolled_back');

-- AnnexeA_Socle#6
CREATE TYPE keystone.export_status       AS ENUM ('requested','running','ready','expired','failed');

-- AnnexeA_Socle#6
CREATE TYPE keystone.audit_op            AS ENUM ('INSERT','UPDATE','DELETE','ERASE');

-- AnnexeA_Socle#7
-- Arrondi demi vers le pair à l'exposant de la devise ; renvoie des unités mineures
CREATE OR REPLACE FUNCTION keystone.money_round(p_amount numeric, p_exponent int DEFAULT 0)
RETURNS bigint LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE v numeric := p_amount * power(10::numeric, p_exponent); t numeric := trunc(v);
BEGIN
  IF abs(v - t) = 0.5 THEN
    RETURN (t + CASE WHEN mod(t, 2) = 0 THEN 0 ELSE sign(v) END)::bigint;
  END IF;
  RETURN round(v)::bigint;
END $$;

-- AnnexeA_Socle#7
-- Variante par devise
CREATE OR REPLACE FUNCTION keystone.money_round_ccy(p_amount numeric, p_currency char(3))
RETURNS bigint LANGUAGE sql STABLE STRICT AS $$
  SELECT keystone.money_round(p_amount, c.minor_unit)
  FROM atlas_core.currencies c WHERE c.code = p_currency $$;

-- AnnexeA_Socle#7
-- Répartition au plus fort reste ; p_weights dans l'ordre de tri stable de l'appelant
CREATE OR REPLACE FUNCTION keystone.money_allocate(p_total bigint, p_weights numeric[])
RETURNS bigint[] LANGUAGE plpgsql STABLE STRICT AS $$
DECLARE
  n int := coalesce(array_length(p_weights, 1), 0);
  s numeric := 0; v_abs bigint := abs(p_total); v_sign int := CASE WHEN p_total < 0 THEN -1 ELSE 1 END;
  res bigint[] := '{}'; rem numeric[] := '{}'; v_done bigint := 0; ord int[]; i int; exact numeric;
BEGIN
  IF n = 0 THEN PERFORM keystone.raise_error('ALLOCATION_ZERO_WEIGHT'); END IF;
  FOR i IN 1..n LOOP
    IF p_weights[i] < 0 THEN PERFORM keystone.raise_error('ALLOCATION_NEGATIVE_WEIGHT'); END IF;
    s := s + p_weights[i];
  END LOOP;
  IF s = 0 THEN PERFORM keystone.raise_error('ALLOCATION_ZERO_WEIGHT'); END IF;
  FOR i IN 1..n LOOP
    exact := v_abs * p_weights[i] / s;
    res[i] := floor(exact)::bigint;
    rem[i] := exact - floor(exact);
    v_done := v_done + res[i];
  END LOOP;
  SELECT array_agg(j ORDER BY rem[j] DESC, j ASC) INTO ord FROM generate_series(1, n) AS j;
  FOR i IN 1..(v_abs - v_done) LOOP
    res[ord[i]] := res[ord[i]] + 1;
  END LOOP;
  FOR i IN 1..n LOOP res[i] := res[i] * v_sign; END LOOP;
  RETURN res;
END $$;

-- AnnexeA_Socle#8
CREATE TABLE keystone.audit_trail (
  tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  seq         bigint NOT NULL CHECK (seq > 0),
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  actor_id    uuid,                                   -- auth.uid() ; nul pour le service
  actor_kind  text NOT NULL CHECK (actor_kind IN ('user','service','system')),
  op          audit_op NOT NULL,
  table_name  text NOT NULL,
  row_id      uuid,
  before      jsonb,                                  -- données personnelles remplacées par jeton (A.2.6)
  after       jsonb,
  prev_hash   char(64) NOT NULL CHECK (prev_hash ~ '^[0-9a-f]{64}$'),
  row_hash    char(64) NOT NULL CHECK (row_hash ~ '^[0-9a-f]{64}$'),
  PRIMARY KEY (tenant_id, seq),
  CONSTRAINT uq_audit_trail_id UNIQUE (id)
);

-- AnnexeA_Socle#8
CREATE INDEX ix_audit_trail_row   ON keystone.audit_trail (tenant_id, table_name, row_id);

-- AnnexeA_Socle#8
CREATE INDEX ix_audit_trail_actor ON keystone.audit_trail (tenant_id, actor_id, occurred_at DESC);

-- AnnexeA_Socle#8
CREATE INDEX ix_audit_trail_time  ON keystone.audit_trail USING brin (occurred_at);

-- AnnexeA_Socle#8
-- Tête de chaîne par tenant (écrite par tg_audit seulement)
CREATE TABLE keystone.audit_heads (
  tenant_id uuid PRIMARY KEY REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  last_seq  bigint NOT NULL DEFAULT 0,
  last_hash char(64) NOT NULL DEFAULT repeat('0', 64)
);

-- AnnexeA_Socle#8
-- Ancrage externe quotidien de l'empreinte de tête
CREATE TABLE keystone.audit_anchors (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  log_name     text NOT NULL CHECK (log_name IN ('audit_trail','access_log')),
  anchor_date  date NOT NULL,
  last_seq     bigint NOT NULL,
  head_hash    char(64) NOT NULL,
  provider     text NOT NULL,                         -- autorité d'horodatage RFC 3161
  tsa_token    bytea,                                 -- jeton d'horodatage signé
  external_ref text,
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','anchored','failed')),
  anchored_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_audit_anchor UNIQUE (tenant_id, log_name, anchor_date)
);

-- AnnexeA_Socle#8
-- Contrôles d'intégrité
CREATE TABLE keystone.audit_integrity_runs (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  log_name         text NOT NULL CHECK (log_name IN ('audit_trail','access_log')),
  started_at       timestamptz NOT NULL DEFAULT now(),
  finished_at      timestamptz,
  from_seq         bigint NOT NULL,
  to_seq           bigint NOT NULL,
  rows_checked     bigint NOT NULL DEFAULT 0,
  anchors_checked  int NOT NULL DEFAULT 0,
  status           text NOT NULL DEFAULT 'running' CHECK (status IN ('running','ok','broken','error')),
  first_broken_seq bigint,
  expected_hash    char(64),
  found_hash       char(64),
  error_message    text
);

-- AnnexeA_Socle#8
CREATE INDEX ix_integrity_runs ON keystone.audit_integrity_runs (tenant_id, log_name, started_at DESC);

-- AnnexeA_Socle#9
CREATE OR REPLACE FUNCTION keystone.canonical_json(j jsonb) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE r text;
BEGIN
  IF j IS NULL THEN RETURN 'null'; END IF;
  CASE jsonb_typeof(j)
    WHEN 'object' THEN
      SELECT '{' || coalesce(string_agg(to_json(k)::text || ':' || keystone.canonical_json(v), ',' ORDER BY k COLLATE "C"), '') || '}'
        INTO r FROM jsonb_each(j) AS e(k, v);
    WHEN 'array' THEN
      SELECT '[' || coalesce(string_agg(keystone.canonical_json(v), ',' ORDER BY o), '') || ']'
        INTO r FROM jsonb_array_elements(j) WITH ORDINALITY AS a(v, o);
    ELSE r := j::text;
  END CASE;
  RETURN r;
END $$;

-- AnnexeA_Socle#9
CREATE OR REPLACE FUNCTION keystone.audit_hash(p_seq bigint, p_tenant uuid, p_table text, p_op audit_op,
  p_actor uuid, p_at timestamptz, p_row uuid, p_before jsonb, p_after jsonb, p_prev char(64))
RETURNS char(64) LANGUAGE sql IMMUTABLE AS $$
  SELECT encode(sha256(convert_to(
    p_seq::text || '|' || p_tenant::text || '|' || p_table || '|' || p_op::text || '|' ||
    keystone.canonical_json(jsonb_build_object(
      'actor_id', p_actor, 'after', p_after, 'before', p_before,
      'occurred_at', to_char(p_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'row_id', p_row)) || '|' || p_prev, 'UTF8')), 'hex') $$;

-- AnnexeA_Socle#9
CREATE OR REPLACE FUNCTION keystone.tg_audit() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE
  v_old jsonb := CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END;
  v_new jsonb := CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END;
  v_tenant uuid := (coalesce(v_new, v_old) ->> 'tenant_id')::uuid;
  v_row uuid := (coalesce(v_new, v_old) ->> 'id')::uuid;
  v_seq bigint; v_prev char(64); v_at timestamptz := clock_timestamp();
  v_actor uuid := auth.uid();
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('audit:' || v_tenant::text));   -- A87
  INSERT INTO keystone.audit_heads(tenant_id) VALUES (v_tenant) ON CONFLICT (tenant_id) DO NOTHING;
  SELECT last_seq + 1, last_hash INTO v_seq, v_prev
    FROM keystone.audit_heads WHERE tenant_id = v_tenant FOR UPDATE;
  v_old := keystone.audit_pseudonymize(v_tenant, TG_TABLE_NAME, v_old);
  v_new := keystone.audit_pseudonymize(v_tenant, TG_TABLE_NAME, v_new);
  INSERT INTO keystone.audit_trail(tenant_id, seq, occurred_at, actor_id, actor_kind, op, table_name,
                                   row_id, before, after, prev_hash, row_hash)
  VALUES (v_tenant, v_seq, v_at, v_actor, CASE WHEN v_actor IS NULL THEN 'service' ELSE 'user' END,
          TG_OP::audit_op, TG_TABLE_NAME, v_row, v_old, v_new, v_prev,
          keystone.audit_hash(v_seq, v_tenant, TG_TABLE_NAME, TG_OP::audit_op, v_actor, v_at, v_row, v_old, v_new, v_prev));
  UPDATE keystone.audit_heads
     SET last_seq = v_seq,
         last_hash = (SELECT row_hash FROM keystone.audit_trail WHERE tenant_id = v_tenant AND seq = v_seq)
   WHERE tenant_id = v_tenant;
  RETURN NULL;
END $$;

-- AnnexeA_Socle#10
CREATE OR REPLACE FUNCTION keystone.tg_audit_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN PERFORM keystone.raise_error('AUDIT_IMMUTABLE'); END $$;

-- AnnexeA_Socle#10
CREATE TRIGGER audit_trail_no_update BEFORE UPDATE OR DELETE ON keystone.audit_trail
  FOR EACH ROW EXECUTE FUNCTION keystone.tg_audit_immutable();

-- AnnexeA_Socle#10
CREATE TRIGGER audit_trail_no_truncate BEFORE TRUNCATE ON keystone.audit_trail
  FOR EACH STATEMENT EXECUTE FUNCTION keystone.tg_audit_immutable();

-- AnnexeA_Socle#11
CREATE TABLE keystone.access_log (
  tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  seq         bigint NOT NULL CHECK (seq > 0),
  id          uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  actor_id    uuid,
  surface     text NOT NULL CHECK (surface IN ('console','client_portal','vendor_portal','occupant_portal','field_app','api')),
  event       text NOT NULL CHECK (event IN ('login_success','login_failure','logout','mfa_enrolled','mfa_removed',
                                             'mfa_failure','sensitive_read','export','session_revoked','profile_switched',
                                             'brand_fallback','permission_denied','role_matrix_saved','email_resent',
                                             'privacy_override')),   -- partie 4, A.16
  object_table text,
  object_id   uuid,
  purpose     text,                                   -- motif obligatoire pour sensitive_read
  ip          inet,
  user_agent  text,
  prev_hash   char(64) NOT NULL,
  row_hash    char(64) NOT NULL,
  PRIMARY KEY (tenant_id, seq),
  CONSTRAINT ck_access_purpose CHECK (event <> 'sensitive_read' OR purpose IS NOT NULL)
);

-- AnnexeA_Socle#11
CREATE TABLE keystone.access_log_heads (
  tenant_id uuid PRIMARY KEY REFERENCES atlas_core.tenants(id),
  last_seq bigint NOT NULL DEFAULT 0,
  last_hash char(64) NOT NULL DEFAULT repeat('0', 64),
  purged_until_seq bigint NOT NULL DEFAULT 0,
  hash_at_purge char(64) NOT NULL DEFAULT repeat('0', 64)
);

-- AnnexeA_Socle#11
CREATE INDEX ix_access_log_actor ON keystone.access_log (tenant_id, actor_id, occurred_at DESC);

-- AnnexeA_Socle#12
CREATE TABLE keystone.audit_personal_fields (      -- registre des colonnes personnelles
  table_name     text NOT NULL,
  column_name    text NOT NULL,
  subject_column text NOT NULL DEFAULT 'id',        -- colonne qui désigne la personne concernée
  category       text NOT NULL CHECK (category IN ('identity','contact','health','location','other')),
  retention_months int NOT NULL CHECK (retention_months > 0),
  PRIMARY KEY (table_name, column_name)
);

-- AnnexeA_Socle#12
CREATE TABLE keystone.pseudonym_map (
  token        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  subject_id   uuid NOT NULL,
  table_name   text NOT NULL,
  column_name  text NOT NULL,
  value_sha256 char(64) NOT NULL,                   -- sha256(tenant || valeur), recherche sans clair
  value        text,                                -- nul après effacement
  retention_until date NOT NULL,
  erased_at    timestamptz,
  erased_reason text,
  CONSTRAINT uq_pseudonym UNIQUE (tenant_id, subject_id, table_name, column_name, value_sha256),
  CONSTRAINT ck_erased CHECK ((erased_at IS NULL) = (value IS NOT NULL))
);

-- AnnexeA_Socle#12
CREATE INDEX ix_pseudonyms_subject ON keystone.pseudonym_map (tenant_id, subject_id);

-- AnnexeA_Socle#12
CREATE INDEX ix_pseudonyms_retention ON keystone.pseudonym_map (retention_until) WHERE erased_at IS NULL;

-- AnnexeA_Socle#13
CREATE TABLE atlas_core.sites (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id) ON DELETE RESTRICT,
  code            text NOT NULL CHECK (code ~ '^[A-Z0-9-]{2,12}$'),
  name            text NOT NULL,
  address         text,
  country_code    char(2) NOT NULL REFERENCES atlas_core.country_config(country_code),
  time_zone       text NOT NULL DEFAULT 'Africa/Abidjan',   -- IANA
  latitude        numeric(9,6) CHECK (latitude BETWEEN -90 AND 90),
  longitude       numeric(9,6) CHECK (longitude BETWEEN -180 AND 180),
  boundary        geometry(Polygon, 4326),
  declared_surface_m2 numeric(12,2) CHECK (declared_surface_m2 >= 0),   -- surface déclarée, jamais corrigée par la mesure
  status          atlas_core.spatial_status NOT NULL DEFAULT 'published',
  version         int NOT NULL DEFAULT 1,
  retired_at      timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT uq_core_sites_code UNIQUE (tenant_id, code)
);

-- AnnexeA_Socle#13
CREATE INDEX gx_core_sites_boundary ON atlas_core.sites USING gist (boundary);

-- AnnexeA_Socle#13
CREATE TABLE atlas_core.buildings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  code text NOT NULL, name text NOT NULL,
  footprint geometry(Polygon, 4326),
  status atlas_core.spatial_status NOT NULL DEFAULT 'published', version int NOT NULL DEFAULT 1, retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_core_buildings_code UNIQUE (tenant_id, site_id, code)
);

-- AnnexeA_Socle#13
CREATE TABLE atlas_core.levels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  building_id uuid NOT NULL REFERENCES atlas_core.buildings(id) ON DELETE RESTRICT,
  level int NOT NULL CHECK (level BETWEEN -10 AND 200),   -- -2, -1, 0, 1
  code text NOT NULL,                                      -- 02, S1 (convention, Space Management partie 5)
  name text NOT NULL,
  outline geometry(Polygon, 0),                            -- contour du niveau, repère local en mètres
  status atlas_core.spatial_status NOT NULL DEFAULT 'published', version int NOT NULL DEFAULT 1, retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_core_levels UNIQUE (tenant_id, building_id, level)
);

-- AnnexeA_Socle#13
CREATE TABLE atlas_core.spaces (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  level_id           uuid NOT NULL REFERENCES atlas_core.levels(id) ON DELETE RESTRICT,
  parent_space_id    uuid REFERENCES atlas_core.spaces(id) ON DELETE RESTRICT,
  code               text NOT NULL,                  -- code technique {SITE}-{BAT}-{NIV}-{NUM}
  commercial_code    text,                           -- cellules commerciales
  name               text,
  space_type         space_unit_type NOT NULL,
  is_aggregate_parent boolean NOT NULL DEFAULT false,
  polygon            jsonb CHECK (polygon IS NULL OR jsonb_array_length(polygon) >= 3),
  geom               geometry(Polygon, 4326),
  geom_local         geometry(Polygon, 0),
  surface_m2         numeric(12,2) CHECK (surface_m2 >= 0),
  surface_method     text CHECK (surface_method IN ('shoelace_scaled','geography','declared')),
  measure_convention text CHECK (measure_convention IN ('inner_face','centerline')),   -- convention de tracé
  source             text NOT NULL DEFAULT 'manual' CHECK (source IN ('import','manual')),
  source_ref         uuid,                           -- keystone.plan_imports.id, sans clé étrangère
  plan_ref           uuid,                           -- keystone.space_plans.id de tracé, sans clé étrangère
  is_verified        boolean NOT NULL DEFAULT false,
  verified_by        uuid, verified_at timestamptz,
  status             atlas_core.spatial_status NOT NULL DEFAULT 'draft',
  version            int NOT NULL DEFAULT 1,
  published_at       timestamptz, retired_at timestamptz,
  last_writer_product text NOT NULL DEFAULT 'keystone',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_spaces_no_self_parent CHECK (parent_space_id <> id)
);

-- AnnexeA_Socle#13
CREATE UNIQUE INDEX uq_core_spaces_code ON atlas_core.spaces (tenant_id, code) WHERE status <> 'retired';

-- AnnexeA_Socle#13
CREATE UNIQUE INDEX uq_core_spaces_ccode ON atlas_core.spaces (tenant_id, commercial_code)
  WHERE commercial_code IS NOT NULL AND status <> 'retired';

-- AnnexeA_Socle#13
CREATE INDEX ix_core_spaces_level ON atlas_core.spaces (tenant_id, level_id);

-- AnnexeA_Socle#13
CREATE INDEX gx_core_spaces_geom ON atlas_core.spaces USING gist (geom);

-- AnnexeA_Socle#13
CREATE INDEX gx_core_spaces_geom_local ON atlas_core.spaces USING gist (geom_local);

-- AnnexeA_Socle#13
CREATE TABLE atlas_core.space_lineage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id),
  operation text NOT NULL CHECK (operation IN ('split','merge','segment')),
  from_space_id uuid NOT NULL REFERENCES atlas_core.spaces(id),
  to_space_id uuid NOT NULL REFERENCES atlas_core.spaces(id),
  effective_at timestamptz NOT NULL, created_by uuid
);

-- AnnexeA_Socle#13
CREATE TABLE atlas_core.space_code_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id),
  space_id uuid NOT NULL REFERENCES atlas_core.spaces(id),
  code_kind text NOT NULL CHECK (code_kind IN ('technical','commercial')),
  old_code text NOT NULL, new_code text NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now(), changed_by uuid,
  reusable_after date                                 -- nul : jamais (cellules commerciales)
);

-- AnnexeA_Socle#13
CREATE INDEX ix_code_history_old ON atlas_core.space_code_history (tenant_id, old_code);

-- AnnexeA_Socle#13
-- Journal des changements publié aux produits (outbox)
CREATE TABLE atlas_core.spatial_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  object_kind text NOT NULL CHECK (object_kind IN ('site','building','level','space')),
  object_id uuid NOT NULL,
  event text NOT NULL CHECK (event IN ('created','published','updated','geometry_changed','renumbered','retired','split','merged')),
  version int NOT NULL,
  payload jsonb NOT NULL,
  product text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeA_Socle#13
CREATE INDEX ix_spatial_events_tenant ON atlas_core.spatial_events (tenant_id, id);

-- AnnexeA_Socle#15
CREATE TABLE keystone.zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  floor_id uuid NOT NULL REFERENCES atlas_core.levels(id) ON DELETE RESTRICT,
  code text NOT NULL CHECK (code ~ '^[A-Z0-9-]{1,16}$'),
  name text NOT NULL,
  risk_level risk_level NOT NULL DEFAULT 'low',
  is_restricted boolean NOT NULL DEFAULT false,
  outline geometry(Polygon, 0),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_zones_code UNIQUE (tenant_id, floor_id, code)
);

-- AnnexeA_Socle#15
CREATE INDEX ix_zones_floor ON keystone.zones (tenant_id, floor_id) WHERE deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#1
CREATE TABLE keystone.business_calendars (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  country_code char(2) NOT NULL REFERENCES atlas_core.country_config(country_code),
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,      -- nul : calendrier pays
  parent_calendar_id uuid REFERENCES keystone.business_calendars(id) ON DELETE RESTRICT,
  name text NOT NULL,
  sunday_holiday_rule text NOT NULL DEFAULT 'none' CHECK (sunday_holiday_rule IN ('none','next_monday')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_calendar_kind CHECK ((site_id IS NULL AND parent_calendar_id IS NULL)
                                  OR (site_id IS NOT NULL AND parent_calendar_id IS NOT NULL))
);

-- AnnexeA_Socle_Partie2#1
CREATE UNIQUE INDEX uq_calendar_country ON keystone.business_calendars (tenant_id, country_code)
  WHERE site_id IS NULL AND deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#1
CREATE UNIQUE INDEX uq_calendar_site ON keystone.business_calendars (tenant_id, site_id)
  WHERE site_id IS NOT NULL AND deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#1
-- Règles de fériés (génèrent les jours de chaque année)
CREATE TABLE keystone.holiday_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  calendar_id uuid NOT NULL REFERENCES keystone.business_calendars(id) ON DELETE CASCADE,
  label text NOT NULL,
  rule holiday_rule NOT NULL,
  fixed_month int CHECK (fixed_month BETWEEN 1 AND 12),
  fixed_day int CHECK (fixed_day BETWEEN 1 AND 31),
  easter_offset int CHECK (easter_offset BETWEEN -60 AND 60),
  hijri_month int CHECK (hijri_month BETWEEN 1 AND 12),
  hijri_day int CHECK (hijri_day BETWEEN 1 AND 30),
  hijri_day_offset int NOT NULL DEFAULT 0 CHECK (hijri_day_offset BETWEEN -1 AND 2),   -- « lendemain de »
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_rule_fields CHECK (
       (rule = 'fixed' AND fixed_month IS NOT NULL AND fixed_day IS NOT NULL)
    OR (rule = 'easter_offset' AND easter_offset IS NOT NULL)
    OR (rule = 'hijri' AND hijri_month IS NOT NULL AND hijri_day IS NOT NULL)
    OR (rule = 'one_off'))
);

-- AnnexeA_Socle_Partie2#1
CREATE TABLE keystone.business_calendar_days (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  calendar_id uuid NOT NULL REFERENCES keystone.business_calendars(id) ON DELETE CASCADE,
  holiday_rule_id uuid REFERENCES keystone.holiday_rules(id) ON DELETE SET NULL,
  day date NOT NULL,
  kind calendar_day_kind NOT NULL,
  label text NOT NULL,
  is_provisional boolean NOT NULL DEFAULT false,      -- fête musulmane non encore confirmée
  confirmed_at timestamptz, confirmed_by uuid,
  open_time time, close_time time,                    -- special_opening seulement
  is_cancelled boolean NOT NULL DEFAULT false,
  announcement_source text,                           -- référence de l'annonce officielle (communiqué, décret)
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT uq_calendar_day UNIQUE (calendar_id, day, kind, label),   -- garde d'écriture : CALENDAR_DAY_DUPLICATE
  CONSTRAINT ck_special_hours CHECK (kind <> 'special_opening' OR (open_time IS NOT NULL AND close_time > open_time)),
  CONSTRAINT ck_confirmed CHECK ((confirmed_at IS NULL) = (confirmed_by IS NULL))
);

-- AnnexeA_Socle_Partie2#1
CREATE INDEX ix_calendar_days ON keystone.business_calendar_days (calendar_id, day) WHERE NOT is_cancelled;

-- AnnexeA_Socle_Partie2#1
CREATE TABLE keystone.site_business_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  iso_weekday int NOT NULL CHECK (iso_weekday BETWEEN 1 AND 7),        -- 1 lundi, 7 dimanche
  open_time time NOT NULL,
  close_time time NOT NULL,                                             -- 24:00 accepté
  valid_from date NOT NULL DEFAULT current_date,
  valid_to date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_hours_order CHECK (close_time > open_time),
  CONSTRAINT ck_hours_validity CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT ex_hours_overlap EXCLUDE USING gist (                    -- une plage par jour et par période de validité
    site_id WITH =, iso_weekday WITH =,
    daterange(valid_from, coalesce(valid_to, 'infinity'::date), '[]') WITH &&)
);

-- AnnexeA_Socle_Partie2#1
CREATE INDEX ix_site_hours ON keystone.site_business_hours (site_id, iso_weekday);

-- AnnexeA_Socle_Partie2#2
-- Plage ouvrée d'un jour local, dans le fuseau du site ; NULL si jour non ouvré
-- (férié ou fermeture du calendrier du site ou de son pays, jour sans heures ouvrées).
-- Fonction unique lue par l'Annexe B (B.3.3).
CREATE OR REPLACE FUNCTION keystone.business_window(p_site uuid, p_day date) RETURNS tstzrange
LANGUAGE plpgsql STABLE AS $$
DECLARE v_tz text := keystone.site_tz(p_site); v_open time; v_close time;
BEGIN
  IF v_tz IS NULL THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  SELECT d.open_time, d.close_time INTO v_open, v_close
    FROM keystone.business_calendar_days d
   WHERE d.calendar_id IN (SELECT keystone.site_calendar_chain(p_site))
     AND d.day = p_day AND d.kind = 'special_opening' AND NOT d.is_cancelled
   ORDER BY d.calendar_id = (SELECT business_calendar_id FROM keystone.site_ext WHERE site_id = p_site) DESC
   LIMIT 1;
  IF NOT FOUND THEN
    IF EXISTS (SELECT 1 FROM keystone.business_calendar_days d
               WHERE d.calendar_id IN (SELECT keystone.site_calendar_chain(p_site))
                 AND d.day = p_day AND d.kind IN ('public_holiday','site_closure') AND NOT d.is_cancelled) THEN
      RETURN NULL;
    END IF;
    SELECT h.open_time, h.close_time INTO v_open, v_close
      FROM keystone.site_business_hours h
     WHERE h.site_id = p_site AND h.iso_weekday = extract(isodow FROM p_day)::int
       AND p_day BETWEEN h.valid_from AND coalesce(h.valid_to, 'infinity'::date);
    IF NOT FOUND THEN RETURN NULL; END IF;
  END IF;
  RETURN tstzrange((p_day + v_open) AT TIME ZONE v_tz, (p_day + v_close) AT TIME ZONE v_tz, '[)');
END $$;

-- AnnexeA_Socle_Partie2#2
-- Ajoute des minutes ouvrées à un instant
CREATE OR REPLACE FUNCTION keystone.add_business_hours(p_site uuid, p_ts timestamptz, p_minutes int)
RETURNS timestamptz LANGUAGE plpgsql STABLE AS $$
DECLARE v_tz text := keystone.site_tz(p_site); v_day date; v_left numeric := p_minutes;
        v_win tstzrange; v_from timestamptz; v_avail numeric; n int := 0;
BEGIN
  IF p_minutes IS NULL OR p_minutes < 0 THEN PERFORM keystone.raise_error('INVALID_ARGUMENT'); END IF;
  IF v_tz IS NULL THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  IF p_minutes = 0 THEN RETURN p_ts; END IF;
  v_day := (p_ts AT TIME ZONE v_tz)::date;
  LOOP
    v_win := keystone.business_window(p_site, v_day);
    IF v_win IS NOT NULL THEN
      v_from := greatest(lower(v_win), p_ts);
      IF v_from < upper(v_win) THEN
        v_avail := extract(epoch FROM (upper(v_win) - v_from)) / 60;
        IF v_avail >= v_left THEN RETURN v_from + v_left * interval '1 minute'; END IF;
        v_left := v_left - v_avail;
      END IF;
    END IF;
    v_day := v_day + 1; n := n + 1;
    IF n > 400 THEN PERFORM keystone.raise_error('CALENDAR_HORIZON_EXCEEDED'); END IF;
  END LOOP;
END $$;

-- AnnexeA_Socle_Partie2#2
-- Minutes ouvrées entre deux instants (0 si ts2 <= ts1)
CREATE OR REPLACE FUNCTION keystone.business_minutes_between(p_site uuid, p_ts1 timestamptz, p_ts2 timestamptz)
RETURNS int LANGUAGE plpgsql STABLE AS $$
DECLARE v_tz text := keystone.site_tz(p_site); v_day date; v_last date; v_total numeric := 0; v_win tstzrange;
BEGIN
  IF p_ts2 <= p_ts1 THEN RETURN 0; END IF;
  IF v_tz IS NULL THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  v_day := (p_ts1 AT TIME ZONE v_tz)::date; v_last := (p_ts2 AT TIME ZONE v_tz)::date;
  IF v_last - v_day > 1100 THEN PERFORM keystone.raise_error('INVALID_ARGUMENT'); END IF;
  WHILE v_day <= v_last LOOP
    v_win := keystone.business_window(p_site, v_day) * tstzrange(p_ts1, p_ts2, '[)');
    IF v_win IS NOT NULL AND NOT isempty(v_win) THEN
      v_total := v_total + extract(epoch FROM (upper(v_win) - lower(v_win))) / 60;
    END IF;
    v_day := v_day + 1;
  END LOOP;
  RETURN floor(v_total)::int;
END $$;

-- AnnexeA_Socle_Partie2#2
-- Heures ouvertes du site au format de la vue keystone.sites.opening_hours
CREATE OR REPLACE FUNCTION keystone.site_opening_hours_json(p_site uuid) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('day', iso_weekday, 'open', open_time, 'close', close_time)
                  ORDER BY iso_weekday, open_time), '[]'::jsonb)
  FROM keystone.site_business_hours
  WHERE site_id = p_site AND current_date BETWEEN valid_from AND coalesce(valid_to, 'infinity'::date) $$;

-- AnnexeA_Socle_Partie2#3
CREATE TABLE keystone.site_blackouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  label text NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  applies_to text NOT NULL DEFAULT 'shutdown' CHECK (applies_to IN ('shutdown','all_planned_work')),
  recurrence_rule text,                               -- RRULE RFC 5545, facultative
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_blackout_period CHECK (ends_at > starts_at)
);

-- AnnexeA_Socle_Partie2#3
CREATE INDEX ix_blackouts_site ON keystone.site_blackouts USING gist (site_id, tstzrange(starts_at, ends_at));

-- AnnexeA_Socle_Partie2#4
CREATE TABLE keystone.asset_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  parent_id uuid REFERENCES keystone.asset_categories(id) ON DELETE RESTRICT,
  code text NOT NULL CHECK (code ~ '^[A-Z0-9-]{2,16}$'),
  name text NOT NULL,
  iso14224_class text CHECK (iso14224_class IS NULL OR iso14224_class ~ '^(X-)?[A-Z0-9-]{2,24}$'),
  is_keystone_extension boolean GENERATED ALWAYS AS (coalesce(iso14224_class LIKE 'X-%', false)) STORED,
  is_safety_function boolean NOT NULL DEFAULT false,  -- fonction de sécurité (Annexe AM.4.2)
  downtime_hourly_cost bigint CHECK (downtime_hourly_cost >= 0),   -- coût horaire d'arrêt, coût du cycle de vie (AM)
  currency char(3) REFERENCES atlas_core.currencies(code),
  has_refrigerant boolean NOT NULL DEFAULT false,      -- famille à fluide frigorigène : section Énergie et fluides
  default_useful_life_years int CHECK (default_useful_life_years > 0),   -- proposée à la création
  default_strategy keystone.maintenance_strategy,      -- proposée à la création
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_asset_categories_code UNIQUE (tenant_id, code),
  CONSTRAINT ck_asset_categories_no_self CHECK (parent_id <> id)
);

-- AnnexeA_Socle_Partie2#4
CREATE INDEX ix_asset_categories_parent ON keystone.asset_categories (tenant_id, parent_id);

-- AnnexeA_Socle_Partie2#10
CREATE TABLE keystone.import_mappings (                -- correspondances réutilisables
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  target text NOT NULL CHECK (target IN ('assets','asset_components','locations','persons','asset_meters',
                                         'meter_readings','regulatory_controls','work_order_history')),
  name text NOT NULL,
  mapping jsonb NOT NULL,                              -- {"colonne du fichier": "champ cible"}
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_import_mappings UNIQUE (tenant_id, target, name)
);

-- AnnexeA_Socle_Partie3#1
CREATE TYPE keystone.asset_record_status  AS ENUM ('draft','submitted','validated','returned');

-- AnnexeA_Socle_Partie3#1
-- D29
CREATE TYPE keystone.asset_operating_mode AS ENUM ('continuous','intermittent','standby');

-- AnnexeA_Socle_Partie3#1
-- ISO 14224:2016
CREATE TYPE keystone.asset_environment    AS ENUM ('indoor_conditioned','indoor_unconditioned','outdoor_sheltered','outdoor_exposed');

-- AnnexeA_Socle_Partie3#1
CREATE TYPE keystone.redundancy_config    AS ENUM ('n','n_plus_1','n_plus_2','two_n');

-- AnnexeA_Socle_Partie3#1
CREATE TYPE keystone.asset_disposal_mode  AS ENUM ('sale','scrap','recycling','transfer','return_to_owner','donation');

-- AnnexeA_Socle_Partie3#1
CREATE TYPE keystone.attribute_data_type  AS ENUM ('number','integer','text','boolean','date','enum');

-- AnnexeA_Socle_Partie3#1
CREATE TYPE keystone.warranty_kind        AS ENUM ('parts','labor','parts_and_labor','extended');

-- AnnexeA_Socle_Partie3#2
CREATE TABLE keystone.asset_category_attributes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  category_id uuid NOT NULL REFERENCES keystone.asset_categories(id) ON DELETE CASCADE,
  code text NOT NULL CHECK (code ~ '^[a-z][a-z0-9_]{1,40}$'),     -- clé dans assets.specs
  label text NOT NULL,
  data_type keystone.attribute_data_type NOT NULL,
  unit text,                                        -- UCUM (kW, V, m3/h, kg) ; obligatoire pour number et integer
  enum_values text[],                               -- obligatoire pour enum
  min_value numeric, max_value numeric,
  is_required boolean NOT NULL DEFAULT false,       -- obligatoire à la validation de l'actif
  help_text text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_cat_attr UNIQUE (category_id, code),
  CONSTRAINT ck_cat_attr_unit CHECK (data_type NOT IN ('number','integer') OR unit IS NOT NULL),
  CONSTRAINT ck_cat_attr_enum CHECK ((data_type = 'enum') = (enum_values IS NOT NULL AND cardinality(enum_values) >= 2)),
  CONSTRAINT ck_cat_attr_range CHECK (min_value IS NULL OR max_value IS NULL OR min_value <= max_value)
);

-- AnnexeA_Socle_Partie3#2
CREATE INDEX ix_cat_attr ON keystone.asset_category_attributes (tenant_id, category_id) WHERE is_active;

-- AnnexeA_Socle_Partie3#4
CREATE TABLE keystone.refrigerants (                 -- table globale de plateforme, écrite par migration
  code text PRIMARY KEY CHECK (code ~ '^R-[0-9A-Z]{2,6}$'),   -- désignation ISO 817:2024, édition à vérifier (R-32, R-410A, R-22)
  family text NOT NULL CHECK (family IN ('HFC','HCFC','HFO','HFC_HFO_blend','natural')),
  safety_class text CHECK (safety_class IN ('A1','A2L','A2','A3','B1','B2L','B2','B3')),
  is_ozone_depleting boolean NOT NULL,              -- HCFC : Protocole de Montréal
  is_active boolean NOT NULL DEFAULT true
);

-- AnnexeA_Socle_Partie3#4
CREATE TABLE keystone.refrigerant_check_rules (      -- seuils de contrôle d'étanchéité par pays
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,   -- NULL : valeur éditeur
  country_code char(2) NOT NULL,
  basis text NOT NULL CHECK (basis IN ('co2e_t','charge_kg')),
  min_value numeric(12,3) NOT NULL CHECK (min_value >= 0),               -- seuil bas inclus
  frequency_months int NOT NULL CHECK (frequency_months > 0),
  frequency_with_detection_months int CHECK (frequency_with_detection_months > 0),
  regime_code text NOT NULL,                        -- régime du contrôle (regulatory_regimes, Annexe R)
  legal_source text NOT NULL,                       -- texte, article, date ; « à vérifier » tant que non confirmé
  valid_from date NOT NULL, valid_to date,
  CONSTRAINT uq_refrig_rule UNIQUE NULLS NOT DISTINCT (tenant_id, country_code, basis, min_value, valid_from)
);

-- AnnexeA_Socle_Partie3#7
CREATE TYPE keystone.asset_observation_kind AS ENUM ('anomaly','condition','safety','environment','information');

-- AnnexeA_Socle_Partie3#7
CREATE TYPE keystone.asset_acquisition_mode AS ENUM ('purchase','lease','finance_lease','donation','transfer','built');

-- AnnexeA_Socle_Partie3#8
CREATE TABLE keystone.error_codes (                   -- contenu chargé depuis le catalogue des messages, qui fait foi
  code        text PRIMARY KEY CHECK (code ~ '^[A-Z][A-Z0-9_]{2,63}$'),
  http_status int NOT NULL CHECK (http_status BETWEEN 400 AND 599),
  category    text NOT NULL CHECK (category IN ('validation','permission','not_found','conflict','state','subscription','technical')),
  alias_of    text REFERENCES keystone.error_codes(code),   -- A67 : alias renvoyé vers le code officiel
  owner_annex text NOT NULL
);

-- AnnexeA_Socle_Partie3#8
CREATE OR REPLACE FUNCTION keystone.raise_error(p_code text, p_detail jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE v_code text := p_code; v_status int;
BEGIN
  SELECT coalesce(alias_of, code), http_status INTO v_code, v_status FROM keystone.error_codes WHERE code = p_code;
  RAISE EXCEPTION USING ERRCODE = 'PT' || coalesce(v_status, 500)::text,
                        MESSAGE = coalesce(v_code, p_code),
                        DETAIL  = coalesce(p_detail, '{}'::jsonb)::text;
END $$;

-- AnnexeA_Socle_Partie3#9
CREATE OR REPLACE FUNCTION keystone.tg_check_document_ids() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE
  v_col text := TG_ARGV[0];
  v_row jsonb := to_jsonb(NEW);
  v_tenant uuid := (v_row ->> 'tenant_id')::uuid;
  v_ids uuid[]; v_missing uuid[];
BEGIN
  IF v_col IS NULL OR NOT (v_row ? v_col) THEN
    PERFORM keystone.raise_error('INVALID_ARGUMENT', jsonb_build_object('trigger', TG_NAME, 'column', v_col));
  END IF;
  IF jsonb_typeof(v_row -> v_col) IS DISTINCT FROM 'array' THEN RETURN NEW; END IF;   -- colonne nulle
  SELECT array_agg(DISTINCT e::uuid) INTO v_ids FROM jsonb_array_elements_text(v_row -> v_col) AS e;
  IF v_ids IS NULL THEN RETURN NEW; END IF;                                               -- tableau vide
  SELECT array_agg(i) INTO v_missing
    FROM unnest(v_ids) AS i
   WHERE NOT EXISTS (SELECT 1 FROM keystone.ged_documents d
                      WHERE d.id = i AND d.tenant_id = v_tenant AND d.deleted_at IS NULL);
  IF v_missing IS NOT NULL THEN
    PERFORM keystone.raise_error('DOCUMENT_NOT_FOUND',
      jsonb_build_object('field', v_col, 'table', TG_TABLE_NAME, 'document_ids', to_jsonb(v_missing)));
  END IF;
  RETURN NEW;
END $$;

-- AnnexeA_Socle_Partie4#1
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- AnnexeA_Socle_Partie4#4
CREATE TYPE keystone.bulk_operation_status AS ENUM ('previewed','completed','failed');

-- AnnexeA_Socle_Partie4#6
CREATE TYPE keystone.undo_status AS ENUM ('available','used','expired','failed');

-- AnnexeA_Socle_Partie4#6
-- propriétaire : présente section

CREATE TABLE keystone.undo_action_catalog (            -- catalogue de plateforme, chargé par migration
  action_key  text PRIMARY KEY CHECK (action_key ~ '^[a-z][a-z_]*\.[a-z][a-z_]*$'),
  inverse_rpc regprocedure NOT NULL,
  window_minutes smallint NOT NULL DEFAULT 10 CHECK (window_minutes BETWEEN 1 AND 10),
  label_key   text NOT NULL                              -- clé i18n du libellé de l'action (catalogue des messages §37.3)
);

-- AnnexeAdmin_RBAC_Notifications#1
CREATE TABLE keystone.users (                         -- profil applicatif ; credential dans Supabase Auth
  id               uuid PRIMARY KEY,                  -- = auth.users.id
  tenant_id        uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  full_name        text NOT NULL CHECK (length(full_name) BETWEEN 2 AND 160),
  email            text NOT NULL CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone_e164       text CHECK (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  status           keystone.user_status NOT NULL DEFAULT 'invited',
  is_buyer_admin   boolean NOT NULL DEFAULT false,
  locale           text NOT NULL DEFAULT 'fr' CHECK (locale IN ('fr','en')),
  timezone         text NOT NULL DEFAULT 'Africa/Abidjan',   -- IANA ; proposé depuis atlas_core.country_config
  email_invalid    boolean NOT NULL DEFAULT false,           -- rebond définitif ou plainte
  mfa_enrolled     boolean NOT NULL DEFAULT false,           -- reflet des facteurs Supabase Auth, mis à jour par webhook ; type du facteur : partie 3 §1.1
  processing_restricted boolean NOT NULL DEFAULT false,      -- limitation du traitement (Protection des données §6)
  invited_at       timestamptz, invitation_expires_at timestamptz,
  activated_at     timestamptz, last_sign_in_at timestamptz,
  dormant_at       timestamptz, disabled_at timestamptz, disabled_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_users_disabled CHECK (status <> 'disabled' OR disabled_at IS NOT NULL)
);

-- AnnexeAdmin_RBAC_Notifications#1
CREATE UNIQUE INDEX ux_users_email ON keystone.users (tenant_id, lower(email)) WHERE deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications#1
CREATE UNIQUE INDEX ux_users_buyer ON keystone.users (tenant_id) WHERE is_buyer_admin AND deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications#1
-- un acheteur-admin par tenant
CREATE INDEX ix_users_status_signin ON keystone.users (tenant_id, status, last_sign_in_at);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE TABLE keystone.roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  code         text NOT NULL CHECK (code ~ '^[a-z][a-z0-9_]{1,62}$'),
  label        text NOT NULL,
  surface      keystone.surface_code NOT NULL DEFAULT 'console',
  mode_scope   text NOT NULL DEFAULT 'both' CHECK (mode_scope IN ('both','in_house','fm_provider')),
  requires_mfa boolean NOT NULL DEFAULT false,        -- RG-RBAC-06
  is_system    boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  UNIQUE (tenant_id, code)
);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE TABLE keystone.permissions (                   -- catalogue de plateforme, lecture seule pour les tenants
  code         text PRIMARY KEY CHECK (code ~ '^[a-z][a-z_]*\.[a-z][a-z_]*$'),
  module       text NOT NULL,                         -- Partie 2 §1
  label        text NOT NULL,
  mode_scope   text NOT NULL DEFAULT 'both' CHECK (mode_scope IN ('both','in_house','fm_provider')),
  surface      keystone.surface_code NOT NULL DEFAULT 'console',
  is_sensitive boolean NOT NULL DEFAULT false,        -- attribution tracée et soumise à la revue des comptes
  status       text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated'))
);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE TABLE keystone.role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  role_id uuid NOT NULL REFERENCES keystone.roles(id) ON DELETE CASCADE,
  permission_code text NOT NULL REFERENCES keystone.permissions(code),
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  UNIQUE (role_id, permission_code)
);

-- AnnexeAdmin_RBAC_Notifications#4
CREATE TABLE keystone.tenant_surfaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  surface               keystone.surface_code NOT NULL,
  is_enabled            boolean NOT NULL DEFAULT true,
  session_idle_minutes  integer NOT NULL CHECK (session_idle_minutes BETWEEN 5 AND 43200),
  session_max_hours     integer NOT NULL CHECK (session_max_hours BETWEEN 1 AND 2160),
  mfa_policy            text NOT NULL DEFAULT 'role_based' CHECK (mfa_policy IN ('role_based','all','optional')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  UNIQUE (tenant_id, surface)
);

-- AnnexeAdmin_RBAC_Notifications#5
CREATE TABLE keystone.tenant_domains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  surface        keystone.surface_code NOT NULL,
  hostname       text NOT NULL CHECK (hostname ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$'),
  status         text NOT NULL DEFAULT 'pending_dns'
                 CHECK (status IN ('pending_dns','verifying','active','failed','disabled')),
  verification_token text NOT NULL,                   -- enregistrement TXT _keystone-verify
  certificate_status text NOT NULL DEFAULT 'none' CHECK (certificate_status IN ('none','pending','issued','renewal_failed')),
  verified_at    timestamptz, last_checked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeAdmin_RBAC_Notifications#5
CREATE UNIQUE INDEX ux_tenant_domains_host ON keystone.tenant_domains (lower(hostname)) WHERE deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications#6
CREATE TABLE keystone.tenant_branding (               -- A29 ; calcul : lot 1 §4.2 à §4.4
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  site_id          uuid REFERENCES atlas_core.sites(id) ON DELETE CASCADE, -- déclinaison par site (portail occupants), A66
  surface          keystone.surface_code,                                   -- NULL : toutes surfaces
  brand_name       text NOT NULL CHECK (length(brand_name) BETWEEN 2 AND 40),   -- nom affiché (shell, <title>)
  brand_color      char(7) CHECK (brand_color ~ '^#[0-9A-Fa-f]{6}$'),           -- couleur de marque saisie
  logo_light_path  text, logo_dark_path text,         -- SVG ou PNG transparent, 50 Ko au plus, PNG en double résolution
  favicon_path     text,                              -- icône d'onglet PNG 32 et 180 px
  welcome_image_path text,                            -- image d'accueil du portail occupants, 1600 par 600, 200 Ko au plus
  derived_vars     jsonb,                             -- quatre jeux (Clair, Sombre, Terrain clair, Terrain sombre) et ratios calculés
  algorithm_version text,                             -- version de deriveBrand() ayant produit derived_vars
  button_color     char(7) CHECK (button_color ~ '^#[0-9A-Fa-f]{6}$'),          -- bouton des emails
  button_contrast  numeric(4,2),                      -- ratio calculé, au moins 4,5 contre le blanc
  sender_name      text CHECK (length(sender_name) <= 60),
  reply_to_email   text,
  postal_address   text,
  privacy_policy_url text CHECK (privacy_policy_url ~ '^https://'),
  sending_subdomain text,                              -- ex. mail.<domaine du tenant> ; jamais le domaine principal
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_branding_contrast CHECK (button_color IS NULL OR button_contrast >= 4.5)
);

-- AnnexeAdmin_RBAC_Notifications#7
CREATE TABLE keystone.tenant_onboarding_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  step_code    text NOT NULL CHECK (step_code IN ('site','country_pack','modules','import','branding','invitations',
                                                  'first_client','first_service_contract','mobilization')),
  status       keystone.onboarding_status NOT NULL DEFAULT 'not_started',
  position     smallint NOT NULL,
  completed_at timestamptz, completed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, step_code)
);

-- AnnexeAdmin_RBAC_Notifications#8
CREATE TABLE keystone.setting_definitions (           -- catalogue de plateforme (Partie 2 §4)
  key          text PRIMARY KEY CHECK (key ~ '^[a-z][a-z_]*(\.[a-z][a-z_0-9]*)+$'),
  module       text NOT NULL,
  label        text NOT NULL,
  value_type   text NOT NULL CHECK (value_type IN ('boolean','integer','numeric','text','enum','minutes','days','money_xof','json')),
  default_value jsonb NOT NULL,
  min_value    numeric, max_value numeric,
  allowed      jsonb,                                 -- liste fermée pour 'enum'
  scope        text NOT NULL DEFAULT 'tenant' CHECK (scope IN ('tenant','site')),
  is_sensitive boolean NOT NULL DEFAULT false,        -- double validation (RG-ADM-04)
  mode_scope   text NOT NULL DEFAULT 'both' CHECK (mode_scope IN ('both','in_house','fm_provider'))
);

-- AnnexeAdmin_RBAC_Notifications#8
CREATE TABLE keystone.settings (                      -- valeur en vigueur
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  key        text NOT NULL REFERENCES keystone.setting_definitions(key),
  site_id    uuid REFERENCES atlas_core.sites(id) ON DELETE CASCADE,   -- A66
  value      jsonb NOT NULL,
  effective_from timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeAdmin_RBAC_Notifications#8
CREATE UNIQUE INDEX ux_settings_scope ON keystone.settings
  (tenant_id, key, COALESCE(site_id,'00000000-0000-0000-0000-000000000000'::uuid)) WHERE deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications#8
CREATE TABLE keystone.settings_history (              -- demandes et décisions, en ajout seul
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  key        text NOT NULL REFERENCES keystone.setting_definitions(key),
  site_id    uuid,
  old_value  jsonb, new_value jsonb NOT NULL,
  status     keystone.setting_status NOT NULL DEFAULT 'draft',
  effective_from timestamptz NOT NULL DEFAULT now(),
  reason     text,
  requested_by uuid NOT NULL, requested_at timestamptz NOT NULL DEFAULT now(),
  decided_by uuid, decided_at timestamptz, decision_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_settings_sod CHECK (decided_by IS NULL OR decided_by <> requested_by)
);

-- AnnexeAdmin_RBAC_Notifications#8
CREATE INDEX ix_settings_history_pending ON keystone.settings_history (tenant_id, status, effective_from);

-- AnnexeAdmin_RBAC_Notifications#9
CREATE TABLE keystone.account_access_reviews (        -- A14
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  period_label text NOT NULL,                         -- « 2026-T4 »
  status     keystone.access_review_status NOT NULL DEFAULT 'open',
  launched_by uuid NOT NULL, launched_at timestamptz NOT NULL DEFAULT now(),
  due_at     timestamptz NOT NULL,                    -- lancement plus admin.access_review.decision_days (défaut 15, RG-RBAC-07)
  closed_at  timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, period_label)
);

-- AnnexeAdmin_RBAC_Notifications#9
CREATE UNIQUE INDEX ux_access_review_open ON keystone.account_access_reviews (tenant_id) WHERE status = 'open';

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.notification_event_catalog (    -- A25, catalogue de plateforme (Partie 2 §3)
  event_key     keystone.notification_event_key PRIMARY KEY,
  module        text NOT NULL,
  label         text NOT NULL,
  category      keystone.notification_category NOT NULL,
  default_channels keystone.notification_channel[] NOT NULL CHECK (cardinality(default_channels) >= 1),
  email_template_code text,                           -- EML-XXX-000, NULL : EML-GEN-001 si l'utilisateur active l'email
  severity      text NOT NULL DEFAULT 'info' CHECK (severity IN ('info','action_required','alert','urgent')),
  mode_scope    text NOT NULL DEFAULT 'both' CHECK (mode_scope IN ('both','in_house','fm_provider')),
  is_active     boolean NOT NULL DEFAULT true,
  mandatory_relations text[] NOT NULL DEFAULT '{}',   -- relations pour lesquelles une clé opérationnelle reste obligatoire (ex. '{object_owner}')
  user_disableable boolean GENERATED ALWAYS AS (category IN ('operational','digest')) STORED
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.notification_rules (            -- matrice propre au tenant, surcharge du catalogue
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  event_key   keystone.notification_event_key NOT NULL REFERENCES keystone.notification_event_catalog(event_key),
  channels    keystone.notification_channel[] NOT NULL,
  recipients  jsonb NOT NULL,                         -- {"roles":["fm_manager"],"relations":["assignee","object_owner"]}
  escalation_after_minutes integer CHECK (escalation_after_minutes BETWEEN 5 AND 20160),
  escalation_to jsonb,                                -- {"roles":["direction"]}
  is_enabled  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  UNIQUE (tenant_id, event_key)
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id          uuid REFERENCES keystone.users(id),       -- NULL : destinataire externe (visiteur, déclarant public)
  recipient_address text,                                    -- email ou E.164 pour un destinataire externe
  event_key        keystone.notification_event_key NOT NULL REFERENCES keystone.notification_event_catalog(event_key),
  category         keystone.notification_category NOT NULL,
  channel          keystone.notification_channel NOT NULL,
  object_table     text, object_id uuid, object_version integer NOT NULL DEFAULT 1,
  payload          jsonb,                                    -- variables rendues ; purgé à 90 jours (NF, Protection des données)
  status           keystone.notification_status NOT NULL DEFAULT 'queued',
  idempotency_key  text NOT NULL,                            -- sha256(tenant|event|objet|version|destinataire|canal)
  template_code    text, template_version integer,
  provider_message_id text,
  language         text NOT NULL DEFAULT 'fr',
  digest_id        uuid,
  escalation_level smallint NOT NULL DEFAULT 0,
  resent_from      uuid REFERENCES keystone.notifications(id),
  attempts         smallint NOT NULL DEFAULT 0, last_error text,
  queued_at timestamptz NOT NULL DEFAULT now(), sent_at timestamptz, delivered_at timestamptz,
  read_at timestamptz, scheduled_for timestamptz,            -- report de plage de silence ou de résumé
  CONSTRAINT ck_notif_recipient CHECK (user_id IS NOT NULL OR recipient_address IS NOT NULL)
);

-- AnnexeAdmin_RBAC_Notifications#10
-- sans tg_audit (volume) ; renvoi tracé dans audit_trail
CREATE UNIQUE INDEX ux_notifications_idem ON keystone.notifications (tenant_id, idempotency_key);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE INDEX ix_notifications_inbox ON keystone.notifications (user_id, read_at, queued_at DESC);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE INDEX ix_notifications_queue ON keystone.notifications (status, scheduled_for) WHERE status = 'queued';

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id    uuid REFERENCES keystone.users(id) ON DELETE CASCADE,   -- NULL : préférence du tenant
  event_key  keystone.notification_event_key REFERENCES keystone.notification_event_catalog(event_key),
  category   keystone.notification_category,
  channel    keystone.notification_channel NOT NULL,
  is_enabled boolean NOT NULL DEFAULT true,
  digest     keystone.digest_frequency NOT NULL DEFAULT 'immediate',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_pref_target CHECK ((event_key IS NULL) <> (category IS NULL))
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.user_quiet_hours (              -- RG-NOT-07
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id    uuid NOT NULL REFERENCES keystone.users(id) ON DELETE CASCADE,
  start_local time NOT NULL, end_local time NOT NULL,  -- plage pouvant franchir minuit
  days       smallint[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}' CHECK (days <@ '{1,2,3,4,5,6,7}'),
  is_enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.push_subscriptions (            -- Web Push (Q08), évolution, à valider
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id   uuid NOT NULL REFERENCES keystone.users(id) ON DELETE CASCADE,
  surface   keystone.surface_code NOT NULL,
  endpoint  text NOT NULL, p256dh text NOT NULL, auth_secret text NOT NULL,
  user_agent text, created_at timestamptz NOT NULL DEFAULT now(), last_success_at timestamptz,
  UNIQUE (user_id, endpoint)
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid,                                    -- NULL : modèle de plateforme
  code       text NOT NULL CHECK (code ~ '^EML-[A-Z]{2,3}-[0-9]{3}$'),
  name       text NOT NULL, domain text NOT NULL,
  category   keystone.notification_category NOT NULL,
  status     keystone.template_status NOT NULL DEFAULT 'draft',
  platform_locked boolean NOT NULL DEFAULT false,     -- contenu de sécurité et réglementaire modifiable par la plateforme seule
  current_version integer,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  UNIQUE (tenant_id, code)
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.email_template_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES keystone.email_templates(id) ON DELETE RESTRICT,
  version    integer NOT NULL,
  language   text NOT NULL CHECK (language IN ('fr','en')),
  subject    text NOT NULL CHECK (length(subject) <= 70),
  preheader  text NOT NULL CHECK (length(preheader) BETWEEN 40 AND 90),
  title      text NOT NULL,
  blocks     jsonb NOT NULL,                          -- composants du lot Emails partie 1 §2, aucun HTML libre
  button     jsonb,                                   -- {"label":"Ouvrir l'OT","target":"wo_detail"} ; cible dans une liste fermée
  severity   text NOT NULL CHECK (severity IN ('info','action_required','alert','urgent')),
  variables  jsonb NOT NULL,                          -- [{"name","type","source","example"}]
  status     keystone.template_status NOT NULL DEFAULT 'draft',
  size_bytes integer, checks jsonb,                   -- résultat des contrôles de publication
  published_at timestamptz, published_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  UNIQUE (template_id, version, language)
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.email_suppressions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  email_lower text NOT NULL,
  reason     keystone.suppression_reason NOT NULL,
  category   keystone.notification_category,         -- désinscription par catégorie ; NULL : toutes
  source_notification_id uuid REFERENCES keystone.notifications(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  lifted_at timestamptz, lifted_by uuid, lift_reason text,
  CONSTRAINT ck_unsub_category CHECK (reason <> 'unsubscribe' OR category IN ('operational','digest'))
);

-- AnnexeAdmin_RBAC_Notifications#10
CREATE TABLE keystone.notification_digests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES keystone.users(id),
  frequency keystone.digest_frequency NOT NULL CHECK (frequency <> 'immediate'),
  period_start timestamptz NOT NULL, period_end timestamptz NOT NULL,
  notification_id uuid REFERENCES keystone.notifications(id),   -- email EML-RAP-001 ou 002 envoyé
  UNIQUE (user_id, frequency, period_start)
);

-- AnnexeAdmin_RBAC_Notifications#11
CREATE TABLE keystone.integration_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id   uuid REFERENCES keystone.users(id) ON DELETE CASCADE,   -- NULL : connexion du tenant
  provider  text NOT NULL CHECK (provider IN ('ical_feed','microsoft_365','google_workspace')),
  status    text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','revoked','error')),
  secret_ref uuid,                                    -- identifiant du secret dans le coffre (NF.3), jamais le jeton en clair
  feed_token_hash text,                               -- flux iCalendar en lecture, jeton haché
  scopes    text[] NOT NULL DEFAULT '{}',
  last_sync_at timestamptz, last_error text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeAdmin_RBAC_Notifications_Partie3#1
ALTER TABLE keystone.users
  ADD COLUMN mfa_factor_type text CHECK (mfa_factor_type IN ('totp','phone','webauthn')),  -- webauthn : évolution, à valider (Lot 4 §15)
  ADD COLUMN mfa_enrolled_at timestamptz,
  ADD CONSTRAINT ck_users_mfa_factor CHECK (mfa_enrolled = (mfa_factor_type IS NOT NULL));

-- AnnexeAdmin_RBAC_Notifications_Partie3#2
ALTER TABLE keystone.email_suppressions
  ADD COLUMN consent_reference text,
  ADD CONSTRAINT ck_lift_complaint CHECK (reason <> 'complaint' OR lifted_at IS NULL OR consent_reference IS NOT NULL);

-- AnnexeAdmin_RBAC_Notifications_Partie3#3
ALTER TABLE keystone.push_subscriptions
  ADD COLUMN device_label text NOT NULL DEFAULT 'Appareil',
  ADD COLUMN last_used_at timestamptz;

-- AnnexeNF_Non_Fonctionnel#1
CREATE TABLE atlas_public.public_email_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_hash   text NOT NULL,                 -- sha256(lower(email)) ; l'adresse en clair reste chez le fournisseur d'envoi
  offer        text NOT NULL CHECK (offer IN ('in_house','fm_provider')),
  event_key    text NOT NULL CHECK (event_key IN ('public.demo_requested','public.demo_requested_internal')),
  status       text NOT NULL CHECK (status IN ('queued','sent','delivered','bounced','complained','failed')),
  provider_message_id text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- AnnexeNF_Non_Fonctionnel#1
CREATE INDEX ix_public_email_idem ON atlas_public.public_email_log (email_hash, offer, created_at DESC);

-- AnnexeNF_Non_Fonctionnel#2
CREATE TABLE keystone.i18n_missing_keys (             -- table de plateforme, sans donnée de tenant
  key text NOT NULL, locale text NOT NULL CHECK (locale IN ('fr','en')),
  screen text NOT NULL, occurrences integer NOT NULL DEFAULT 1 CHECK (occurrences > 0),
  first_seen_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (key, locale, screen)
);

-- AnnexeG_GED#1
CREATE TYPE keystone.doc_status          AS ENUM ('active','retention_due','on_hold','disposed');

-- AnnexeG_GED#1
CREATE TYPE keystone.doc_confidentiality AS ENUM ('public','internal','confidential','restricted');

-- AnnexeG_GED#1
CREATE TYPE keystone.av_status           AS ENUM ('pending','clean','rejected','error');

-- AnnexeG_GED#1
CREATE TYPE keystone.doc_link_kind       AS ENUM ('attachment','share');

-- AnnexeG_GED#1
CREATE TYPE keystone.share_surface       AS ENUM ('client_portal','vendor_portal','occupant_portal');

-- AnnexeG_GED#1
CREATE TYPE keystone.share_target_kind   AS ENUM ('client','vendor','occupant_org','occupant_population');

-- AnnexeG_GED#1
CREATE TYPE keystone.retention_trigger   AS ENUM ('creation','object_closure','contract_end','asset_disposal',
                                         'person_departure','event_closure');

-- AnnexeG_GED#1
CREATE TYPE keystone.disposal_action     AS ENUM ('destroy','transfer','retain_permanently');

-- AnnexeG_GED#1
CREATE TYPE keystone.retention_rule_status AS ENUM ('to_confirm','validated','retired');

-- AnnexeG_GED#1
CREATE TYPE keystone.legal_hold_kind     AS ENUM ('litigation','claim','investigation','regulatory_request','hsse_event');

-- AnnexeG_GED#2
CREATE TABLE keystone.ged_retention_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,   -- NULL : règle éditeur
  code text NOT NULL, label text NOT NULL,
  country_code char(2),                             -- NULL : tous pays
  duration_months int CHECK (duration_months > 0),  -- NULL si retain_permanently
  trigger retention_trigger NOT NULL,
  final_action disposal_action NOT NULL,
  legal_basis text,                                 -- texte, article, date ; obligatoire pour validated
  source text NOT NULL CHECK (source IN ('register_a56','country_pack','tenant')),
  status retention_rule_status NOT NULL DEFAULT 'to_confirm',
  validated_by uuid, validated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ret_rule UNIQUE NULLS NOT DISTINCT (tenant_id, code, country_code),
  CONSTRAINT ck_ret_perm CHECK ((final_action = 'retain_permanently') = (duration_months IS NULL)),
  CONSTRAINT ck_ret_valid CHECK (status <> 'validated' OR (legal_basis IS NOT NULL AND validated_by IS NOT NULL))
);

-- AnnexeG_GED#2
CREATE TABLE keystone.ged_classification (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,   -- NULL : plan éditeur
  code text NOT NULL CHECK (code ~ '^[A-Z]{3}(\.[A-Z0-9]{2,6}){0,3}$'),   -- MNT.OT.RAP
  parent_id uuid REFERENCES keystone.ged_classification(id),
  label text NOT NULL, description text,
  default_confidentiality doc_confidentiality NOT NULL DEFAULT 'internal',
  retention_rule_id uuid REFERENCES keystone.ged_retention_rules(id),   -- obligatoire au niveau feuille
  is_vital boolean NOT NULL DEFAULT false,          -- document essentiel à la continuité (ISO 15489-1:2016 §7)
  is_leaf boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','retired')),
  CONSTRAINT uq_classif UNIQUE NULLS NOT DISTINCT (tenant_id, code),
  CONSTRAINT ck_leaf_rule CHECK (NOT is_leaf OR retention_rule_id IS NOT NULL)
);

-- AnnexeG_GED#3
CREATE TABLE keystone.ged_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                -- DOC-2026-000123
  site_id uuid REFERENCES atlas_core.sites(id),       -- NULL : document de portée tenant
  title text NOT NULL,
  doc_type text NOT NULL CHECK (doc_type IN ('notice','doe','plan','schematic','certificate','equipment_file',
                      'report','contract','procedure','policy','photo','invoice','minutes','other')),
  classification_id uuid NOT NULL REFERENCES keystone.ged_classification(id),
  confidentiality doc_confidentiality NOT NULL,
  retention_rule_id uuid NOT NULL REFERENCES keystone.ged_retention_rules(id),
  retention_trigger_date date,                      -- date de l'événement déclencheur
  retention_until date,                             -- calculée : trigger_date plus duration_months
  status doc_status NOT NULL DEFAULT 'active',
  is_vital boolean NOT NULL DEFAULT false,
  issuer_kind text CHECK (issuer_kind IN ('manufacturer','installer','internal','inspection_body')),
  manufacturer text, model text,                    -- documents d'actifs (Lot 17)
  offline_available boolean NOT NULL DEFAULT false,  -- copie dans l'application terrain (D03)
  owner_id uuid,
  submitted_by_client_id uuid,                      -- clients (Annexe M), clé posée par la migration M ; dépôt du client (G.4 ter)
  submission_note text CHECK (length(submission_note) <= 1000),
  current_version int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_doc_ref UNIQUE (tenant_id, ref)
);

-- AnnexeG_GED#3
CREATE INDEX ix_doc_retention ON keystone.ged_documents (tenant_id, retention_until) WHERE status = 'active';

-- AnnexeG_GED#3
CREATE INDEX ix_doc_search ON keystone.ged_documents USING gin (to_tsvector('french', title));

-- AnnexeG_GED#3
CREATE TABLE keystone.doc_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id) ON DELETE RESTRICT,
  version int NOT NULL CHECK (version >= 1),
  storage_path text,                                -- NULL après destruction (notice conservée)
  original_filename text NOT NULL,
  mime_type text NOT NULL, size_bytes bigint NOT NULL CHECK (size_bytes > 0),
  sha256 char(64) NOT NULL,                         -- intégrité (ISO 15489-1:2016 §5.2.2)
  av_status av_status NOT NULL DEFAULT 'pending',
  av_engine text, av_scanned_at timestamptz, rejection_cause text,
  change_note text,
  uploaded_by uuid NOT NULL, uploaded_at timestamptz NOT NULL DEFAULT now(),
  signature_token text, signed_by uuid, signed_at timestamptz,   -- signature électronique : évolution, à valider
  CONSTRAINT uq_doc_version UNIQUE (tenant_id, document_id, version),
  CONSTRAINT ck_rejected_cause CHECK (av_status <> 'rejected' OR rejection_cause IS NOT NULL)
);

-- AnnexeG_GED#4
CREATE TABLE keystone.doc_access_log (
  id bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id uuid NOT NULL, document_id uuid NOT NULL, version int,   -- référence logique sans clé : journal partitionné, conservé 12 mois après destruction éventuelle
  user_id uuid, surface text NOT NULL,              -- console, client_portal, vendor_portal, occupant_portal, field_app
  action text NOT NULL CHECK (action IN ('view','download','share','revoke','dispose')),
  at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, at, id)
) PARTITION BY RANGE (at);

-- AnnexeG_GED#6
CREATE TABLE keystone.doc_entity_types (             -- table de plateforme, sans donnée de tenant
  entity_type text PRIMARY KEY CHECK (entity_type ~ '^[a-z][a-z_]{2,40}$'),
  table_name text NOT NULL,                          -- table keystone.* de l'entité
  site_column text,                                  -- colonne portant le site ; NULL : entité de portée tenant
  read_permission text NOT NULL,                     -- code du catalogue Admin
  max_photos smallint CHECK (max_photos BETWEEN 1 AND 50)   -- NULL : aucune limite propre
);

-- AnnexeG_GED#6
INSERT INTO keystone.doc_entity_types VALUES
  ('asset','assets','site_id','asset.read',NULL), ('work_order','work_orders','site_id','wo.read',10),
  ('permit','work_permits','site_id','permit.request',NULL), ('regulatory_control','regulatory_controls','site_id','asset.read',NULL),
  ('hsse_event','hsse_events','site_id','event.read',NULL), ('capa_action','capa_actions','site_id','event.read',NULL),
  ('inspection','inspections','site_id','inspection.execute',NULL), ('ticket','tickets','site_id','ticket.read',5),
  ('service_contract','service_contracts',NULL,'service_contract.read',NULL),
  ('maintenance_contract','maintenance_contracts',NULL,'contract.manage',NULL),
  ('fitout_request','fitout_requests','site_id','fitout.manage',NULL), ('client','clients',NULL,'client.read',NULL),
  ('vendor','vendors',NULL,'vendor.read',NULL), ('mobilization_project','mobilization_projects','site_id','mobilization.read',NULL);

-- AnnexeG_GED#8
CREATE TABLE keystone.legal_holds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                -- GEL-2026-0012
  kind legal_hold_kind NOT NULL,
  reason text NOT NULL,
  source_type text, source_id uuid,                 -- hsse_events, litige, demande d'autorité
  placed_by uuid NOT NULL, placed_at timestamptz NOT NULL DEFAULT now(),
  released_by uuid, released_at timestamptz, release_reason text,
  CONSTRAINT uq_hold_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_hold_release CHECK (released_at IS NULL OR release_reason IS NOT NULL)
);

-- AnnexeG_GED#8
CREATE TABLE keystone.legal_hold_documents (
  hold_id uuid NOT NULL REFERENCES keystone.legal_holds(id) ON DELETE RESTRICT,
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id) ON DELETE RESTRICT,
  tenant_id uuid NOT NULL,
  added_by uuid NOT NULL, added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (hold_id, document_id)
);

-- AnnexeG_GED#8
CREATE TABLE keystone.disposal_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                -- PVD-2026-0004, procès-verbal de destruction
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id) ON DELETE RESTRICT,
  action disposal_action NOT NULL,
  retention_rule_id uuid NOT NULL REFERENCES keystone.ged_retention_rules(id),
  versions jsonb NOT NULL,                          -- [{version, sha256, size_bytes}] avant destruction
  retained_metadata jsonb NOT NULL,                 -- notice descriptive conservée
  transfer_destination text,                        -- si action = transfer
  proposed_at timestamptz NOT NULL, proposed_by text NOT NULL,    -- 'system' ou utilisateur
  approved_by uuid NOT NULL, approved_at timestamptz NOT NULL,
  executed_at timestamptz,
  certificate_document_id uuid REFERENCES keystone.ged_documents(id),   -- PV signé, conservé en série QUA
  CONSTRAINT uq_disposal_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_disposal_transfer CHECK (action <> 'transfer' OR transfer_destination IS NOT NULL)
);

-- AnnexeS_Space_Management#1
CREATE TYPE keystone.measure_convention AS ENUM ('inner_face','internal_dominant_face','centerline','outer_face');

-- AnnexeS_Space_Management#2
CREATE TABLE keystone.space_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  floor_id uuid REFERENCES atlas_core.levels(id),          -- NULL pour une carte de site extérieure
  version int NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','superseded')),
  superseded_by uuid REFERENCES keystone.space_plans(id), version_note text,
  activated_at timestamptz, activated_by uuid,
  source_format text NOT NULL CHECK (source_format IN ('raster','pdf','dxf','dwg','ifc','geojson','svg')),
  image_path text NOT NULL, width_px int, height_px int,
  scale_m_per_px numeric(10,5),                            -- échelle ; NULL = plan non calé
  georef jsonb,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_plan_version UNIQUE (tenant_id, floor_id, version) );

-- AnnexeS_Space_Management#2
CREATE UNIQUE INDEX uq_plan_active ON keystone.space_plans (floor_id) WHERE status = 'active';

-- AnnexeS_Space_Management#2
CREATE TABLE keystone.plan_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, plan_id uuid REFERENCES keystone.space_plans(id) ON DELETE SET NULL,
  file_path text NOT NULL,
  format text NOT NULL CHECK (format IN ('dxf','dwg','ifc','geojson','svg','pdf')),   -- DWG converti en DXF, PDF rastérisé par le worker
  layer_filter text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','parsing','review','applied','failed')),
  units_detected int NOT NULL DEFAULT 0, errors jsonb,       -- schéma 'plan_import_errors/v1' ci-dessous (SM-08)
  failure_message text,                                      -- échec du worker (status failed), clé de message
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT ck_import_errors CHECK (errors IS NULL
    OR jsonb_matches_schema(keystone.json_schema('plan_import_errors/v1'), errors)) );

-- AnnexeS_Space_Management#2
CREATE TABLE keystone.level_outlines (                     -- contours de mesure du niveau, par version de plan
  floor_id uuid NOT NULL REFERENCES atlas_core.levels(id), plan_id uuid NOT NULL REFERENCES keystone.space_plans(id),
  tenant_id uuid NOT NULL,
  outline_outer geometry(Polygon, 0) NOT NULL,             -- face extérieure des murs de façade
  outline_inner geometry(Polygon, 0) NOT NULL,             -- face intérieure dominante des murs de façade
  verified_by uuid, verified_at timestamptz,
  PRIMARY KEY (floor_id, plan_id),
  CONSTRAINT ck_outline_within CHECK (ST_Within(outline_inner, outline_outer)) );

-- AnnexeS_Space_Management#3
CREATE FUNCTION keystone.space_at_local_point(p_plan uuid, p_x numeric, p_y numeric) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE p keystone.space_plans; v uuid;
BEGIN
  SELECT * INTO p FROM keystone.space_plans WHERE id = p_plan AND tenant_id = keystone.current_tenant();
  IF p.scale_m_per_px IS NULL THEN
    PERFORM keystone.raise_error('PLAN_NOT_SCALED', jsonb_build_object('plan_id', p_plan));
  END IF;
  SELECT su.id INTO v FROM keystone.space_units su
   WHERE su.tenant_id = keystone.current_tenant() AND su.floor_id = p.floor_id AND su.is_verified
     AND su.spatial_status = 'published' AND NOT su.is_aggregate_parent
     AND ST_Contains(su.geom_local, ST_MakePoint(p_x * p.width_px * p.scale_m_per_px, p_y * p.height_px * p.scale_m_per_px))
   ORDER BY (su.parent_space_id IS NULL)   -- un segment l'emporte sur son parent
   LIMIT 1;
  RETURN v;
END $$;

-- AnnexeS_Space_Management#4
CREATE TYPE keystone.measurement_base AS ENUM
  ('en15221_gross','en15221_net','ipms1','ipms2','ipms3_office','boma_occupant','boma_rentable','rics_nia');

-- AnnexeS_Space_Management#4
CREATE TABLE keystone.area_classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, code text NOT NULL, label text NOT NULL,
  standard text NOT NULL CHECK (standard IN ('EN15221-6','IPMS','BOMA','RICS','internal')),
  ipms_component char(1) CHECK (ipms_component IN ('A','B','C','D','E','F','G','H')),
  -- A pénétrations verticales, B éléments structurels, C services techniques, D sanitaires, E circulations,
  -- F espaces d'agrément, G espaces de travail, H autres
  is_billable boolean NOT NULL DEFAULT false, sort_order int NOT NULL DEFAULT 0, is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT uq_area_class UNIQUE (tenant_id, code) );

-- AnnexeS_Space_Management#4
CREATE TABLE keystone.area_class_bases (
  area_class_id uuid NOT NULL REFERENCES keystone.area_classes(id) ON DELETE CASCADE,
  base keystone.measurement_base NOT NULL, included boolean NOT NULL,
  required_convention keystone.measure_convention NOT NULL,
  PRIMARY KEY (area_class_id, base) );

-- AnnexeS_Space_Management#4
CREATE TABLE keystone.measurement_surveys (           -- mesurage importé d'un géomètre ou d'un bureau de mesure
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, surveyor text NOT NULL, survey_date date NOT NULL,
  standard text NOT NULL, document_id uuid NOT NULL,   -- rapport en GED
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid );

-- AnnexeS_Space_Management#4
CREATE TABLE keystone.space_measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, space_unit_id uuid NOT NULL REFERENCES atlas_core.spaces(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES keystone.space_plans(id),
  base keystone.measurement_base NOT NULL,
  convention keystone.measure_convention NOT NULL,
  method text NOT NULL CHECK (method IN ('polygon','offset_polygon','survey')),
  geom_measure geometry(Polygon, 0),                 -- polygone décalé si la convention diffère de geom_local
  area_m2 numeric(12,2) NOT NULL CHECK (area_m2 >= 0),
  survey_id uuid REFERENCES keystone.measurement_surveys(id),
  verified_by uuid, verified_at timestamptz, computed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_space_measure UNIQUE (space_unit_id, plan_id, base),
  CONSTRAINT ck_measure_method CHECK ((method = 'survey') = (survey_id IS NOT NULL)) );

-- AnnexeS_Space_Management#4
CREATE TABLE keystone.floor_measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, floor_id uuid NOT NULL REFERENCES atlas_core.levels(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES keystone.space_plans(id),
  gross_m2 numeric(12,2), ipms1_m2 numeric(12,2), ipms2_m2 numeric(12,2),
  net_spaces_m2 numeric(12,2),                       -- somme des espaces en convention inner_face, hors parents agrégés
  wall_structure_m2 numeric(12,2),                   -- ipms2_m2 moins net_spaces_m2 moins vides non mesurés déclarés
  method text NOT NULL CHECK (method IN ('outline','survey')), survey_id uuid REFERENCES keystone.measurement_surveys(id),
  computed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_floor_measure UNIQUE (floor_id, plan_id) );

-- AnnexeS_Space_Management#5
CREATE TYPE keystone.atelier_status AS ENUM ('editing','submitted','validated','published','abandoned');

-- AnnexeS_Space_Management#5
CREATE TABLE keystone.atelier_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, floor_id uuid NOT NULL REFERENCES atlas_core.levels(id),
  base_plan_id uuid NOT NULL REFERENCES keystone.space_plans(id),   -- version en vigueur à l'ouverture
  status keystone.atelier_status NOT NULL DEFAULT 'editing',
  author_id uuid NOT NULL, contributors uuid[] NOT NULL DEFAULT '{}',
  lock_holder uuid, lock_expires_at timestamptz,          -- verrou d'édition de 30 minutes renouvelé à chaque action
  effective_at timestamptz,                               -- date d'effet, aujourd'hui ou future
  submitted_at timestamptz, validated_by uuid, validated_at timestamptz, published_at timestamptz,
  return_comment text, source_scenario_id uuid,
  created_at timestamptz NOT NULL DEFAULT now() );

-- AnnexeS_Space_Management#5
CREATE UNIQUE INDEX uq_atelier_open ON keystone.atelier_drafts (floor_id)
  WHERE status IN ('editing','submitted','validated');

-- AnnexeS_Space_Management#5
-- un brouillon par niveau (DRAFT_LOCKED)

CREATE TABLE keystone.atelier_draft_spaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES keystone.atelier_drafts(id) ON DELETE CASCADE,
  space_unit_id uuid REFERENCES atlas_core.spaces(id),   -- NULL pour un espace nouveau
  change text NOT NULL CHECK (change IN ('unchanged','new','modified','archived')),
  code text, commercial_code text, name text, type space_unit_type, parent_draft_space_id uuid,
  measure_convention keystone.measure_convention, geom_local geometry(Polygon, 0), attrs jsonb NOT NULL DEFAULT '{}' );

-- AnnexeS_Space_Management#5
CREATE INDEX gx_draft_space ON keystone.atelier_draft_spaces USING gist (geom_local);

-- AnnexeS_Space_Management#5
CREATE TABLE keystone.atelier_operations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  draft_id uuid NOT NULL REFERENCES keystone.atelier_drafts(id) ON DELETE CASCADE,
  seq int NOT NULL,
  op_type text NOT NULL CHECK (op_type IN ('trace','move_vertex','offset','fill_room','import_layer','segment','split',
    'merge','sector_create','sector_update','sector_assign','renumber','set_attribute','outline')),
  objects uuid[] NOT NULL, before jsonb NOT NULL, after jsonb NOT NULL,
  author_id uuid NOT NULL, at timestamptz NOT NULL DEFAULT now(), undone boolean NOT NULL DEFAULT false,
  CONSTRAINT uq_atelier_op UNIQUE (draft_id, seq) );

-- AnnexeS_Space_Management#5
CREATE TABLE keystone.atelier_queue (                     -- file de validation
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES keystone.atelier_drafts(id) ON DELETE CASCADE,
  code text NOT NULL, severity text NOT NULL CHECK (severity IN ('blocking','warning')),
  object_kind text NOT NULL, object_id uuid, message text NOT NULL,
  resolved_at timestamptz, resolved_by uuid, resolution_comment text );

-- AnnexeS_Space_Management#6
CREATE TABLE keystone.tenant_lot_prefixes (
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, prefix text NOT NULL CHECK (prefix ~ '^[A-Z]{1,3}$'),
  label text NOT NULL,                                    -- signification à confirmer par la cliente
  next_number int NOT NULL DEFAULT 1 CHECK (next_number >= 1),
  PRIMARY KEY (tenant_id, site_id, prefix) );

-- AnnexeS_Space_Management#7
CREATE TYPE keystone.zoning_exclusivity AS ENUM ('full_coverage','exclusive','overlap_allowed');

-- AnnexeS_Space_Management#7
CREATE TABLE keystone.zoning_types (
  tenant_id uuid NOT NULL, code text NOT NULL, label text NOT NULL, sector_label text NOT NULL,
  default_exclusivity keystone.zoning_exclusivity NOT NULL,
  exclusivity_locked boolean NOT NULL DEFAULT false,      -- vrai pour cleaning et fire_safety
  default_covered_types space_unit_type[] NOT NULL, multi_floor boolean NOT NULL,
  owner_kinds text[] NOT NULL, PRIMARY KEY (tenant_id, code) );

-- AnnexeS_Space_Management#7
CREATE TABLE keystone.zonings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, zoning_type text NOT NULL, name text NOT NULL,
  floor_ids uuid[] NOT NULL, exclusivity keystone.zoning_exclusivity NOT NULL, covered_types space_unit_type[] NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  draft_id uuid REFERENCES keystone.atelier_drafts(id), published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  FOREIGN KEY (tenant_id, zoning_type) REFERENCES keystone.zoning_types(tenant_id, code) );

-- AnnexeS_Space_Management#7
CREATE UNIQUE INDEX uq_zoning_published ON keystone.zonings (tenant_id, site_id, zoning_type) WHERE status = 'published';

-- AnnexeS_Space_Management_Partie2#2
CREATE TABLE keystone.presence_access_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, user_id uuid NOT NULL, site_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('layer_view','person_search','history_view')),
  target_person_id uuid, at timestamptz NOT NULL DEFAULT now() );

-- AnnexeS_Space_Management_Partie2#4
CREATE TYPE keystone.booking_status AS ENUM ('pending','confirmed','rejected','checked_in','released','completed','cancelled');

-- AnnexeS_Space_Management_Partie2#4
CREATE TABLE keystone.booking_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, name text NOT NULL,
  open_hours jsonb NOT NULL,                        -- défaut lundi à samedi, 07h00 à 21h00
  min_minutes int NOT NULL DEFAULT 30, max_minutes int NOT NULL DEFAULT 240,
  lead_minutes int NOT NULL DEFAULT 0, horizon_days int NOT NULL DEFAULT 30,
  quota int DEFAULT 5, recurrence_max int NOT NULL DEFAULT 26, cancel_minutes int NOT NULL DEFAULT 60,
  checkin_required boolean NOT NULL DEFAULT true, checkin_before int NOT NULL DEFAULT 10, checkin_after int NOT NULL DEFAULT 15,
  auto_release boolean NOT NULL DEFAULT true, buffer_minutes int NOT NULL DEFAULT 0,
  audience text[] NOT NULL DEFAULT '{internal}',    -- internal, occupants, occupant_orgs
  CONSTRAINT ck_policy_minutes CHECK (min_minutes > 0 AND max_minutes >= min_minutes) );

-- AnnexeS_Space_Management_Partie2#4
CREATE TABLE keystone.bookable_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  space_unit_id uuid NOT NULL REFERENCES atlas_core.spaces(id),    -- espace validé (SPACE_NOT_VERIFIED)
  category text NOT NULL CHECK (category IN ('meeting_room','flex_desk','event_space','common_area')),
  label text NOT NULL, capacity int NOT NULL CHECK (capacity > 0), equipment text[] NOT NULL DEFAULT '{}',
  desk_positions jsonb, policy_id uuid NOT NULL REFERENCES keystone.booking_policies(id),
  approval_required boolean NOT NULL DEFAULT false, approver_id uuid,
  audience_org_ids uuid[] NOT NULL DEFAULT '{}', is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid );

-- AnnexeS_Space_Management_Partie2#4
CREATE TABLE keystone.booking_series (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  resource_id uuid NOT NULL REFERENCES keystone.bookable_resources(id), rrule text NOT NULL, until date NOT NULL,
  consecutive_releases smallint NOT NULL DEFAULT 0, suspended_at timestamptz, booked_by uuid NOT NULL );

-- AnnexeS_Space_Management_Partie2#4
CREATE TABLE keystone.space_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  ref text NOT NULL,                                -- RES-AAAA-NNNNNN
  resource_id uuid NOT NULL REFERENCES keystone.bookable_resources(id), desk_code text NOT NULL DEFAULT '',
  space_unit_id uuid NOT NULL,                      -- copie, sert au conflit hiérarchique parent et segments
  period tstzrange NOT NULL, blocked_period tstzrange NOT NULL,   -- période plus battement
  title text, is_private boolean NOT NULL DEFAULT true, attendees int,
  booked_by uuid NOT NULL, booked_for uuid, occupant_org_id uuid, series_id uuid REFERENCES keystone.booking_series(id),
  status keystone.booking_status NOT NULL, checked_in_at timestamptz, released_at timestamptz,
  late_cancel boolean NOT NULL DEFAULT false, anonymized_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ex_booking EXCLUDE USING gist (resource_id WITH =, desk_code WITH =, blocked_period WITH &&)
    WHERE (status IN ('pending','confirmed','checked_in')) );

-- AnnexeS_Space_Management_Partie2#4
CREATE TABLE keystone.booking_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), booking_id uuid NOT NULL REFERENCES keystone.space_bookings(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('cleaning','room_setup','catering','audiovisual')),
  details jsonb NOT NULL, ticket_id uuid, work_order_id uuid, status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','created','cancelled')) );

-- AnnexeS_Space_Management_Partie2#7
CREATE TYPE keystone.move_status AS ENUM ('draft','submitted','approved','rejected','planned','in_progress','completed','closed','cancelled');

-- AnnexeS_Space_Management_Partie2#7
CREATE TABLE keystone.move_task_templates (
  tenant_id uuid NOT NULL, need text NOT NULL, wo_template_id uuid, target text NOT NULL
    CHECK (target IN ('work_order','service_visit','ticket','access_task')),
  is_blocking boolean NOT NULL, PRIMARY KEY (tenant_id, need) );

-- AnnexeS_Space_Management_Partie2#8
CREATE TABLE keystone.space_scenarios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  name text NOT NULL, floor_ids uuid[] NOT NULL, base_plan_ids uuid[] NOT NULL, horizon_date date NOT NULL,
  assumptions text, capex_estimate bigint CHECK (capex_estimate >= 0),    -- FCFA, Money.ts
  currency char(3) NOT NULL DEFAULT 'XOF' CHECK (currency IN ('XOF','XAF')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','approved','published','abandoned')),
  author_id uuid NOT NULL, approved_by uuid, created_at timestamptz NOT NULL DEFAULT now() );

-- AnnexeS_Space_Management_Partie2#8
CREATE TABLE keystone.scenario_space_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), scenario_id uuid NOT NULL REFERENCES keystone.space_scenarios(id) ON DELETE CASCADE,
  source_space_id uuid, change text NOT NULL CHECK (change IN ('unchanged','new','modified','removed')),
  code text, type space_unit_type, area_class_id uuid, capacity int, geom_local geometry(Polygon, 0) NOT NULL );

-- AnnexeS_Space_Management_Partie2#8
CREATE TABLE keystone.scenario_occupancies (
  scenario_id uuid NOT NULL REFERENCES keystone.space_scenarios(id) ON DELETE CASCADE,
  scenario_space_id uuid NOT NULL REFERENCES keystone.scenario_space_units(id) ON DELETE CASCADE,
  occupant_org_id uuid, status text NOT NULL, PRIMARY KEY (scenario_id, scenario_space_id) );

-- AnnexeS_Space_Management_Partie2#8
CREATE TABLE keystone.space_demand_forecasts (
  scenario_id uuid NOT NULL REFERENCES keystone.space_scenarios(id) ON DELETE CASCADE,
  occupant_org_id uuid NOT NULL, target_headcount int NOT NULL CHECK (target_headcount >= 0),
  m2_per_person numeric(6,2) NOT NULL CHECK (m2_per_person > 0),
  peak_presence_rate numeric(5,4) NOT NULL CHECK (peak_presence_rate BETWEEN 0 AND 1),
  special_needs jsonb NOT NULL DEFAULT '[]', PRIMARY KEY (scenario_id, occupant_org_id) );

-- AnnexeS_Space_Management_Partie2#9
CREATE TABLE keystone.space_utilization_hourly (
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, space_unit_id uuid NOT NULL, resource_id uuid,
  hour timestamptz NOT NULL, open_minutes smallint NOT NULL, booked_minutes smallint NOT NULL DEFAULT 0,
  occupied_minutes smallint NOT NULL DEFAULT 0,        -- check-in ou capteur
  peak_people smallint, desks_offered smallint, desks_checked_in smallint,
  PRIMARY KEY (space_unit_id, hour) );

-- AnnexeS_Space_Management_Partie2#10
CREATE TABLE keystone.utilization_recommendation_dismissals (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  rule_code text NOT NULL CHECK (rule_code IN ('low_utilization','saturation','booked_not_used','oversized','flex_underused')),
  resource_id uuid REFERENCES keystone.bookable_resources(id) ON DELETE CASCADE,
  space_unit_id uuid REFERENCES atlas_core.spaces(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 10 AND 500),
  dismissed_by uuid NOT NULL, dismissed_at timestamptz NOT NULL DEFAULT now(),
  snooze_until date NOT NULL,                              -- dismissed_at plus 8 semaines par défaut
  CONSTRAINT ck_urd_target CHECK (resource_id IS NOT NULL OR space_unit_id IS NOT NULL)
);

-- AnnexeS_Space_Management_Partie2#11
CREATE TABLE keystone.space_chargeback_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, site_id uuid NOT NULL, name text NOT NULL,
  period_kind text NOT NULL CHECK (period_kind IN ('month','quarter')),
  weight_surface numeric(5,4) NOT NULL DEFAULT 1, weight_usage numeric(5,4) NOT NULL DEFAULT 0,
  weight_flat numeric(5,4) NOT NULL DEFAULT 0,             -- A63 ; mixte seulement si settings chargeback.mixed_enabled
  usage_booking_share numeric(5,4) NOT NULL DEFAULT 0.5,   -- part des heures réservées dans l'usage, le reste en tickets
  cost_scope jsonb NOT NULL,                               -- budgets ou natures de dépenses (Annexe E)
  common_area_mode text NOT NULL CHECK (common_area_mode IN ('prorata','designated_org')),
  common_area_org_id uuid, area_class_ids uuid[] NOT NULL,
  is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT ck_weights CHECK (weight_surface + weight_usage + weight_flat = 1
     AND least(weight_surface, weight_usage, weight_flat) >= 0),
  CONSTRAINT ck_common CHECK (common_area_mode <> 'designated_org' OR common_area_org_id IS NOT NULL) );

-- AnnexeS_Space_Management_Partie2#11
CREATE TABLE keystone.space_chargebacks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, rule_id uuid NOT NULL REFERENCES keystone.space_chargeback_rules(id),
  period daterange NOT NULL, total_cost bigint NOT NULL CHECK (total_cost >= 0),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status text NOT NULL DEFAULT 'calculated' CHECK (status IN ('calculated','verified','published')),
  calculated_by uuid NOT NULL, calculated_at timestamptz NOT NULL DEFAULT now(),
  verified_by uuid, verified_at timestamptz, published_at timestamptz, outbox_message_id uuid,   -- integration_outbox.message_id
  CONSTRAINT uq_chargeback UNIQUE (rule_id, period),
  CONSTRAINT ck_verifier CHECK (verified_by IS NULL OR verified_by <> calculated_by) );

-- AnnexeP_Prestataires_Mobile#1
-- keystone.vendor_role (service_provider, goods_supplier) : défini dans les Référentiels transverses (D13)
-- keystone.vendor_status (prospect, active, under_watch, suspended, blacklisted) : défini dans les Référentiels transverses (D14)
CREATE TYPE keystone.vendor_origin       AS ENUM ('operator','occupant');

-- AnnexeP_Prestataires_Mobile#1
-- occupant : prestataire d'un occupant (travaux d'aménagement)
CREATE TYPE keystone.vendor_portal_role  AS ENUM ('admin','dispatcher','technician','sales','accountant');

-- AnnexeP_Prestataires_Mobile#1
CREATE TYPE keystone.vendor_user_status  AS ENUM ('invited','active','disabled');

-- AnnexeP_Prestataires_Mobile#1
CREATE TYPE keystone.vendor_contact_role AS ENUM ('main','on_call','billing','hsse','sales');

-- AnnexeP_Prestataires_Mobile#1
CREATE TYPE keystone.vendor_doc_status   AS ENUM ('pending','valid','expiring','expired','rejected');

-- AnnexeP_Prestataires_Mobile#1
CREATE TYPE keystone.bank_change_status  AS ENUM ('pending','first_approved','approved','rejected','cancelled');

-- AnnexeP_Prestataires_Mobile#1
CREATE TYPE keystone.payment_method      AS ENUM ('bank_transfer','mobile_money');

-- AnnexeP_Prestataires_Mobile#1
CREATE TYPE keystone.remuneration_mode   AS ENUM ('contract','purchase_order','mixed');

-- AnnexeP_Prestataires_Mobile#5
CREATE TABLE keystone.vendor_document_types (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL,                                    -- RC_INSURANCE, TAX_CERT, SOCIAL_CERT, RCCM, TRADE_LICENSE, SDS, PRODUCT_CERT, WARRANTY, REFERENCES
  label text NOT NULL,
  applies_to keystone.vendor_role[] NOT NULL,
  work_center_ids uuid[] NOT NULL DEFAULT '{}',          -- vide : tous domaines
  is_blocking boolean NOT NULL DEFAULT true,
  max_age_days integer CHECK (max_age_days > 0),         -- RCCM : 90 au référencement
  requires_validity boolean NOT NULL DEFAULT true,
  for_occupant_vendor boolean NOT NULL DEFAULT false,    -- exigée pour un prestataire d'occupant
  CONSTRAINT uq_vdoc_type UNIQUE (tenant_id, code)
);

-- AnnexeP_Prestataires_Mobile#16
CREATE TYPE keystone.evaluation_kind AS ENUM ('intervention');

-- AnnexeP_Prestataires_Mobile#17
CREATE TYPE keystone.vendor_review_status   AS ENUM ('draft','contradictory','to_validate','validated','archived');

-- AnnexeP_Prestataires_Mobile#17
CREATE TYPE keystone.review_trigger  AS ENUM ('annual','renewal','probation_end','on_demand');

-- AnnexeP_Prestataires_Mobile#17
CREATE TYPE keystone.review_decision AS ENUM ('maintain','maintain_under_watch','do_not_renew','suspend');

-- AnnexeP_Prestataires_Mobile#18
CREATE TYPE keystone.penalty_status AS ENUM ('calculated','notified','contested','validated','abandoned','imputed');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.competency_status AS ENUM ('pending','valid','expired','rejected');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.competency_source AS ENUM ('training','external','vendor_portal','import');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.requirement_scope AS ENUM ('asset_category','work_center','permit_worker','permit_approver','job_position','site_induction');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.session_status    AS ENUM ('planned','done','cancelled');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.training_result   AS ENUM ('passed','failed','absent');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.aspect_condition  AS ENUM ('normal','abnormal','emergency');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.life_cycle_stage  AS ENUM ('purchase','use','maintenance','end_of_life');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.aspect_status     AS ENUM ('identified','controlled','to_review');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.waste_hazard_class AS ENUM ('non_hazardous','hazardous','inert');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.bsd_status        AS ENUM ('issued','received','treated','discrepancy');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.env_indicator_kind AS ENUM ('energy_kwh','energy_intensity_kwh_m2','water_m3','water_m3_m2',
  'waste_total_t','waste_recovery_rate','ghg_scope1_t','ghg_scope2_t','ghg_scope3_t','significant_aspects_controlled_rate');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.value_source      AS ENUM ('computed','manual');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.report_status     AS ENUM ('draft','published');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.consultation_kind AS ENUM ('committee','consultation','toolbox_talk','survey');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.consultation_topic AS ENUM ('risk_assessment','incident_investigation','objectives','procedures','ppe','change','training','other');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.objective_status  AS ENUM ('active','achieved','missed','cancelled');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.hsse_review_status     AS ENUM ('planned','held','closed');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.management_scope  AS ENUM ('ohs','environment','both');

-- AnnexeK_Formation_Environnement#1
CREATE TYPE keystone.competency_category AS ENUM ('electrical','height','lifting','refrigerant','ssi','auditor',
  'pest_applicator','site_induction','other');

-- AnnexeK_Formation_Environnement#2
CREATE TABLE keystone.competencies (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL, label text NOT NULL,
  category keystone.competency_category NOT NULL,
  site_id uuid REFERENCES atlas_core.sites(id),        -- accueil sécurité d'un site
  validity_months int CHECK (validity_months > 0),   -- NULL : sans échéance
  is_regulatory boolean NOT NULL DEFAULT false,
  evidence_required boolean NOT NULL DEFAULT false,  -- vrai pour toute habilitation réglementaire (RG-FOR-04)
  country_code char(2),
  UNIQUE (tenant_id, code),
  CONSTRAINT ck_comp_ev CHECK (NOT is_regulatory OR evidence_required),
  CONSTRAINT ck_comp_site CHECK (category <> 'site_induction' OR site_id IS NOT NULL)
);

-- AnnexeK_Formation_Environnement#2
CREATE TABLE keystone.job_positions (                    -- référentiel des postes (géré dans Keystone, import Atlas People en évolution)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL, label text NOT NULL,
  atlas_people_ref text,                     -- identifiant du poste chez Atlas People, si l'intégration est retenue
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (tenant_id, code)
);

-- AnnexeK_Formation_Environnement#9
CREATE TYPE keystone.waste_outcome       AS ENUM ('recycling','energy_recovery','composting','landfill','incineration','other');

-- AnnexeK_Formation_Environnement#9
CREATE TYPE keystone.waste_record_status AS ENUM ('draft','validated','cancelled');

-- AnnexeK_Formation_Environnement#9
CREATE TABLE keystone.waste_streams (                    -- filières
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL,                       -- DIB, CART, VERRE, HUILE, DEEE (données de démonstration)
  label text NOT NULL,
  hazard_class keystone.waste_hazard_class NOT NULL,
  density_kg_m3 numeric(10,2) CHECK (density_kg_m3 > 0),  -- conversion d'un volume en masse
  default_outcome keystone.waste_outcome,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (tenant_id, code)
);

-- AnnexeK_Formation_Environnement#10
CREATE TABLE keystone.env_indicators (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  period_month date NOT NULL CHECK (period_month = date_trunc('month', period_month)::date),
  kind keystone.env_indicator_kind NOT NULL,
  value numeric(18,4), unit text NOT NULL,
  is_computable boolean NOT NULL DEFAULT true,
  source keystone.value_source NOT NULL, source_ref text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_envi UNIQUE (tenant_id, site_id, kind, period_month),
  CONSTRAINT ck_envi_manual CHECK (source = 'computed' OR source_ref IS NOT NULL)
);

-- AnnexeK_Formation_Environnement#10
CREATE TABLE keystone.env_reports (                      -- bilan figé
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid REFERENCES atlas_core.sites(id), legal_entity_id uuid NOT NULL,
  period_start date NOT NULL, period_end date NOT NULL,
  status keystone.report_status NOT NULL DEFAULT 'draft',
  snapshot jsonb, content_sha256 text, pdf_document_id uuid REFERENCES keystone.ged_documents(id),
  published_at timestamptz, published_by uuid
);

-- AnnexeK_Formation_Environnement#11
CREATE TABLE keystone.worker_consultations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid REFERENCES atlas_core.sites(id), legal_entity_id uuid NOT NULL,
  kind keystone.consultation_kind NOT NULL,
  topic keystone.consultation_topic NOT NULL,
  held_on date NOT NULL, title text NOT NULL,
  summary text NOT NULL, decisions text,
  linked_table text, linked_id uuid,         -- risque, investigation, objectif, procédure consultés
  minutes_document_id uuid REFERENCES keystone.ged_documents(id)
);

-- AnnexePL_Planning_Equipes#1
CREATE TYPE keystone.shift_kind          AS ENUM ('day','night','split','overtime');

-- AnnexePL_Planning_Equipes#1
CREATE TYPE keystone.shift_status        AS ENUM ('planned','published','cancelled');

-- AnnexePL_Planning_Equipes#1
-- aussi on_call.status
CREATE TYPE keystone.time_off_kind       AS ENUM ('leave','training','recovery','unavailable');

-- AnnexePL_Planning_Equipes#1
CREATE TYPE keystone.time_off_status     AS ENUM ('requested','approved','rejected','cancelled');

-- AnnexePL_Planning_Equipes#1
CREATE TYPE keystone.time_off_source     AS ENUM ('manual','atlas_people','training_session');

-- AnnexePL_Planning_Equipes#1
CREATE TYPE keystone.on_call_domain      AS ENUM ('technical','security','hsse','management');

-- AnnexePL_Planning_Equipes#1
CREATE TYPE keystone.on_call_trigger     AS ENUM ('wo_p1','ticket_p1','lone_worker','iot_critical','hsse_major','manual');

-- AnnexePL_Planning_Equipes#1
CREATE TYPE keystone.on_call_page_status AS ENUM ('paged','acknowledged','escalated','resolved','uncovered','cancelled');

-- AnnexePL_Planning_Equipes#5
CREATE TABLE keystone.shift_patterns (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,           -- NULL : modèle du tenant
  code text NOT NULL, label text NOT NULL,
  cycle_days int NOT NULL CHECK (cycle_days BETWEEN 1 AND 56),
  skip_closed_days boolean NOT NULL DEFAULT false,      -- vrai : aucun poste un jour sans plage ouvrée (business_window)
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT uq_pattern_code UNIQUE (tenant_id, code)
);

-- AnnexePL_Planning_Equipes#5
CREATE TABLE keystone.shift_pattern_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  pattern_id uuid NOT NULL REFERENCES keystone.shift_patterns(id) ON DELETE CASCADE,
  day_index int NOT NULL CHECK (day_index >= 0),        -- 0 : premier jour du cycle
  start_time time NOT NULL,                             -- heure locale du site
  duration_minutes int NOT NULL CHECK (duration_minutes BETWEEN 30 AND 1440),
  break_minutes int NOT NULL DEFAULT 0 CHECK (break_minutes BETWEEN 0 AND 240),
  kind keystone.shift_kind NOT NULL DEFAULT 'day',
  CONSTRAINT uq_slot UNIQUE (pattern_id, day_index, start_time)
);

-- AnnexePL_Planning_Equipes#8
CREATE TABLE keystone.on_call_escalation_policies (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE CASCADE,            -- NULL : politique du tenant
  trigger keystone.on_call_trigger NOT NULL,
  domain keystone.on_call_domain NOT NULL,
  ack_minutes smallint[] NOT NULL,                      -- délai de prise en charge aux niveaux 1, 2, 3
  final_roles text[] NOT NULL DEFAULT '{}',             -- codes de rôle de l'Annexe Admin, appelés après le niveau 3
  final_repeat_minutes smallint NOT NULL DEFAULT 10 CHECK (final_repeat_minutes BETWEEN 5 AND 60),
  final_repeat_max smallint NOT NULL DEFAULT 6 CHECK (final_repeat_max BETWEEN 1 AND 24),
  match_work_center boolean NOT NULL DEFAULT true,      -- cherche d'abord l'astreinte du centre de travail de l'objet
  is_enabled boolean NOT NULL DEFAULT true,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT ck_ack CHECK (cardinality(ack_minutes) = 3 AND 1 <= ALL (ack_minutes) AND 120 >= ALL (ack_minutes))
);

-- AnnexePL_Planning_Equipes#8
CREATE UNIQUE INDEX uq_esc_policy ON keystone.on_call_escalation_policies
  (tenant_id, coalesce(site_id, '00000000-0000-0000-0000-000000000000'::uuid), trigger) WHERE deleted_at IS NULL;

-- AnnexeB_GMAO#1
-- Référentiels transverses §1
-- wo_type   : corrective, preventive, conditional, predictive, regulatory, service ('service' : passage Soft FM, D11)
-- wo_status : draft, planned, assigned, in_progress, on_hold, done, verified, cancelled

-- wo_stage (A03), wo_team_role (A04), sla_clock (A06), sla_pause_reason (A07) : Référentiels transverses §1.2,
-- non recréés ici. Types propres à l'Annexe B :
-- Réponse du prestataire
CREATE TYPE keystone.contractor_ack_status AS ENUM ('pending','accepted','refused','expired');

-- AnnexeB_GMAO#1
-- Couverture de la dépense (étape 6, arbitrage A02)
CREATE TYPE keystone.wo_coverage_mode AS ENUM ('maintenance_contract','purchase_request','purchase_order','internal_budget');

-- AnnexeB_GMAO#1
-- Formulaire v4 : wo_billing_mode, wo_origin, wo_target_kind, wo_impact_level, wo_instruction_kind (B.15.1)
-- Facturation au client (fm_provider seulement)
CREATE TYPE keystone.wo_client_billing AS ENUM ('included','billable');

-- AnnexeB_GMAO#1
-- Motifs de mise en attente
CREATE TYPE keystone.wo_hold_reason AS ENUM (
  'occupant_access_denied',          -- accès refusé par l'occupant : pause SLA
  'awaiting_client',                 -- attente d'une décision ou d'un accès du client : pause SLA
  'awaiting_parts_client_validated', -- attente de pièce validée par le client : pause SLA
  'awaiting_parts_internal',         -- attente de pièce interne : pas de pause
  'awaiting_contractor',             -- attente du prestataire : pas de pause
  'permit_suspended',                -- suspension du permis lié (système) : pas de pause
  'technician_break',                -- pause du technicien par pointage : pas de pause
  'other');

-- AnnexeB_GMAO#1
-- pas de pause
-- Mode et résultat de réception (arbitrage A10)
CREATE TYPE keystone.wo_reception_mode AS ENUM ('onsite','remote');

-- AnnexeB_GMAO#1
CREATE TYPE keystone.wo_reception_outcome AS ENUM ('accepted','accepted_with_reserves','refused');

-- AnnexeB_GMAO#1
-- Pointages
CREATE TYPE keystone.wo_punch_action AS ENUM ('diagnose_start','diagnose_end','start','pause','resume','finish');

-- AnnexeB_GMAO#1
CREATE TYPE keystone.wo_session_kind AS ENUM ('diagnosis','intervention');

-- AnnexeB_GMAO_Partie2#5
CREATE TYPE keystone.sla_basis AS ENUM ('24x7','business_hours','business_days');

-- AnnexeB_GMAO_Partie2#5
CREATE TYPE keystone.sla_scope AS ENUM ('work_order','ticket');

-- AnnexeB_GMAO_Partie2#5
CREATE TABLE keystone.sla_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,   -- NULL : défaut de plateforme (seed A60)
  scope sla_scope NOT NULL,
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE CASCADE,       -- NULL : tout le tenant
  ticket_category_id uuid,                                              -- scope ticket : catégorie (Annexe D)
  priority smallint NOT NULL CHECK (priority BETWEEN 1 AND 4),
  response_minutes int NOT NULL CHECK (response_minutes > 0),          -- OT : prise en charge ; ticket : accusé de prise en compte
  response_basis sla_basis NOT NULL,
  resolution_minutes int CHECK (resolution_minutes > 0),               -- NULL pour le scope ticket si la résolution suit l'OT
  resolution_basis sla_basis,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT uq_sla_policy UNIQUE NULLS NOT DISTINCT (tenant_id, scope, site_id, ticket_category_id, priority),
  CONSTRAINT ck_sla_days CHECK ((response_basis <> 'business_days' OR response_minutes % 1440 = 0)
                            AND (resolution_basis IS DISTINCT FROM 'business_days' OR resolution_minutes % 1440 = 0)),
  CONSTRAINT ck_sla_resolution CHECK ((resolution_minutes IS NULL) = (resolution_basis IS NULL)) );

-- AnnexeB_GMAO_Partie2#6
CREATE OR REPLACE FUNCTION keystone.sla_add(p_site uuid, p_from timestamptz, p_minutes int, p_basis sla_basis)
RETURNS timestamptz LANGUAGE plpgsql STABLE AS $$
DECLARE v_tz text; v_day date; v_n int; v_i int := 0;
BEGIN
  IF p_basis = '24x7' THEN RETURN p_from + make_interval(mins => p_minutes); END IF;
  IF p_basis = 'business_hours' THEN RETURN keystone.add_business_hours(p_site, p_from, p_minutes); END IF;
  -- business_days : N jours ouvrés, même heure locale le N-ième jour ouvré suivant ;
  -- jour ouvré = jour local portant au moins une plage de site_open_intervals (Annexe A.4.4)
  SELECT timezone INTO v_tz FROM atlas_core.sites WHERE id = p_site;
  v_n := p_minutes / 1440; v_day := (p_from AT TIME ZONE v_tz)::date;
  WHILE v_n > 0 LOOP
    v_day := v_day + 1; v_i := v_i + 1;
    IF EXISTS (SELECT 1 FROM keystone.site_open_intervals(p_site, v_day)) THEN v_n := v_n - 1; END IF;
    IF v_i > 400 THEN PERFORM keystone.raise_error('CALENDAR_NO_BUSINESS_HOURS'); END IF;
  END LOOP;
  RETURN (v_day + (p_from AT TIME ZONE v_tz)::time) AT TIME ZONE v_tz;
END; $$;

-- AnnexeB_GMAO_Partie2#6
CREATE OR REPLACE FUNCTION keystone.sla_minutes(p_site uuid, p_from timestamptz, p_to timestamptz, p_basis sla_basis)
RETURNS int LANGUAGE plpgsql STABLE AS $$
DECLARE v_tz text;
BEGIN
  IF p_to <= p_from THEN RETURN 0; END IF;
  IF p_basis = '24x7' THEN RETURN floor(extract(epoch FROM p_to - p_from) / 60)::int; END IF;
  IF p_basis = 'business_hours' THEN RETURN keystone.business_minutes_between(p_site, p_from, p_to); END IF;
  -- business_days : 1 440 minutes par jour ouvré strictement postérieur au jour de départ et au plus égal au jour d'arrivée
  SELECT timezone INTO v_tz FROM atlas_core.sites WHERE id = p_site;
  RETURN 1440 * (SELECT count(*) FROM generate_series((p_from AT TIME ZONE v_tz)::date + 1,
                                                      (p_to AT TIME ZONE v_tz)::date, interval '1 day') g
                 WHERE EXISTS (SELECT 1 FROM keystone.site_open_intervals(p_site, g::date)))::int;
END; $$;

-- AnnexeB_GMAO_Partie2#9
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.plan_status AS ENUM ('draft','active','archived');

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.plan_kind AS ENUM ('maintenance','service');

-- AnnexeB_GMAO_Partie2#10
-- 'service' : plan de prestation Soft FM (D11)
CREATE TYPE keystone.plan_trigger AS ENUM ('calendar','meter','calendar_or_meter','predictive');

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.plan_due_basis AS ENUM ('actual','theoretical');

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.pm_task_type AS ENUM ('inspection','cleaning','measurement','lubrication','tightening',
                                  'replacement','test','adjustment','composite');

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.isolation_type AS ENUM ('none','electrical','electrical_locked','mechanical','hydraulic',
                                    'refrigerant','multiple');

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.nonconform_action AS ENUM ('reserve','corrective_wo','escalation','asset_locked');

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.subcontracting_rule AS ENUM ('none','proposed','mandatory');

-- AnnexeB_GMAO_Partie2#10
CREATE TYPE keystone.shutdown_scope AS ENUM ('none','partial','total');

-- AnnexeB_GMAO_Partie2#12
CREATE TABLE keystone.maintenance_levels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  level smallint NOT NULL CHECK (level BETWEEN 1 AND 5),       -- AFNOR FD X 60-000:2016
  label text NOT NULL, description text NOT NULL, examples text,
  typical_tools text, typical_docs text, typical_actor text NOT NULL,
  typical_place text NOT NULL CHECK (typical_place IN ('onsite','workshop','manufacturer')),
  min_competency_id uuid REFERENCES keystone.competencies(id),
  subcontracting_rule subcontracting_rule NOT NULL DEFAULT 'none',
  direction_approval_required boolean NOT NULL DEFAULT false,
  reinforced_validation boolean NOT NULL DEFAULT false,
  permit_if_hazardous boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_level UNIQUE (tenant_id, level) );

-- AnnexeB_GMAO_Partie3#2
CREATE TABLE keystone.planning_freezes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  period daterange NOT NULL,
  reason text NOT NULL,
  is_automatic boolean NOT NULL DEFAULT false,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  lifted_by uuid, lifted_at timestamptz, lift_reason text,
  CONSTRAINT ex_freeze_overlap EXCLUDE USING gist (site_id WITH =, period WITH &&) WHERE (lifted_at IS NULL) );

-- AnnexeB_GMAO_Partie3#3
CREATE TABLE keystone.planning_baselines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  week_start date NOT NULL CHECK (extract(isodow FROM week_start) = 1),
  version int NOT NULL DEFAULT 1,
  published_by uuid NOT NULL, published_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_baseline UNIQUE (tenant_id, site_id, week_start, version) );

-- AnnexeB_GMAO_Partie3#6
CREATE TYPE keystone.stock_direction AS ENUM ('in','out','return','adjust','transfer_out','transfer_in');

-- AnnexeB_GMAO_Partie3#8
CREATE TABLE keystone.stock_issue_refusals (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, part_id uuid NOT NULL, work_order_id uuid,
  requested_qty numeric(14,3) NOT NULL, available_qty numeric(14,3) NOT NULL,
  by_user uuid, at timestamptz NOT NULL DEFAULT now() );

-- AnnexeB_GMAO_Partie3#11
CREATE TYPE keystone.part_request_status AS ENUM ('sent','reserved','ordered','refused','delivered','cancelled');

-- AnnexeB_GMAO_Partie3#12
CREATE TYPE keystone.meter_kind AS ENUM ('hours','cycles','starts','energy_kwh','energy_kvarh','power_kw','water_m3',
                                'gas_m3','fuel_l','thermal_kwh','distance_km','other');

-- AnnexeB_GMAO_Partie3#16
CREATE TYPE keystone.maintenance_contract_status AS ENUM ('draft','active','renewing','expired','terminated');

-- AnnexeB_GMAO_Partie4#1
CREATE TYPE keystone.wo_billing_mode AS ENUM ('contract','purchase_request','internal');

-- AnnexeB_GMAO_Partie4#1
-- contract : sous contrat (contrat de maintenance, ou contrat de service du client en fm_provider), aucune DA
  -- purchase_request : hors contrat, demande d'achat approuvée exigée avant l'engagement (D31)
  -- internal : OT pour un bénéficiaire interne, sans contrat ni DA, imputation interne (A22)
CREATE TYPE keystone.wo_origin AS ENUM ('ticket','client_request','preventive','regulatory','inspection',
                                        'iot','prediction','ad_hoc');

-- AnnexeB_GMAO_Partie4#1
CREATE TYPE keystone.wo_target_kind AS ENUM ('asset','component','location','other');

-- AnnexeB_GMAO_Partie4#1
CREATE TYPE keystone.wo_impact_level AS ENUM ('none','minor','moderate','major');

-- AnnexeB_GMAO_Partie4#1
CREATE TYPE keystone.wo_instruction_kind AS ENUM ('general','special','access','conditions','step');

-- AnnexeAM_AMDEC_Fiabilite#1
CREATE TYPE keystone.iso14224_code_type AS ENUM ('equipment_class','equipment_type','failure_mode','failure_mechanism',
                                        'failure_cause','detection_method','maintenance_activity');

-- AnnexeAM_AMDEC_Fiabilite#1
-- equipment_type : D29, Lot 3 v4

CREATE TABLE keystone.iso14224_codes (
  code_type iso14224_code_type NOT NULL,
  code text NOT NULL,
  parent_code text,                             -- mécanismes et causes : code de rubrique (1.0, 2.0) ; equipment_type : code de la classe
  label_fr text NOT NULL, label_en text NOT NULL,
  is_extension boolean NOT NULL DEFAULT false,  -- classe hors norme, propre à Keystone (préfixe X-)
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (code_type, code),
  CONSTRAINT ck_iso_type_parent CHECK (code_type <> 'equipment_type' OR (parent_code IS NOT NULL AND code LIKE parent_code || '-%')) );

-- AnnexeAM_AMDEC_Fiabilite#1
CREATE TABLE keystone.iso14224_class_modes (     -- modes admis par classe d'équipement
  class_code text NOT NULL, mode_code text NOT NULL,
  PRIMARY KEY (class_code, mode_code) );

-- AnnexeAM_AMDEC_Fiabilite#2
CREATE TABLE keystone.fmea_scales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid,                                -- NULL : échelle de plateforme (seed AM.2)
  version int NOT NULL,
  axis text NOT NULL CHECK (axis IN ('severity','occurrence','detection')),
  level smallint NOT NULL CHECK (level BETWEEN 1 AND 10),
  label text NOT NULL, criterion text NOT NULL,
  lambda_min numeric(10,4), lambda_max numeric(10,4),     -- occurrence seulement
  CONSTRAINT uq_scale UNIQUE NULLS NOT DISTINCT (tenant_id, version, axis, level) );

-- AnnexeAM_AMDEC_Fiabilite#4
CREATE TABLE keystone.asset_management_policy (          -- ISO 55001:2024 §5.2
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  legal_entity_id uuid REFERENCES atlas_core.legal_entities(id),   -- NULL : tout le tenant
  version int NOT NULL,
  content text NOT NULL,                         -- engagements, principes, lien aux objectifs de l'organisation
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','superseded')),
  approved_by uuid, approved_at timestamptz,     -- direction (asset_mgmt.approve)
  effective_from date, review_due date,
  doc_id uuid,                                   -- Annexe G
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_amp UNIQUE NULLS NOT DISTINCT (tenant_id, legal_entity_id, version) );

-- AnnexeAM_AMDEC_Fiabilite#4
CREATE UNIQUE INDEX uq_amp_approved ON keystone.asset_management_policy (tenant_id, coalesce(legal_entity_id, tenant_id))
  WHERE status = 'approved';

-- AnnexeAM_AMDEC_Fiabilite#4
CREATE TABLE keystone.samp (                     -- plan stratégique de gestion d'actifs, §4.4 et §6.2
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  legal_entity_id uuid REFERENCES atlas_core.legal_entities(id),
  policy_id uuid NOT NULL REFERENCES keystone.asset_management_policy(id),
  period daterange NOT NULL,                     -- horizon, 5 ans par défaut
  scope text NOT NULL,                           -- périmètre du système de gestion d'actifs (§4.3)
  stakeholders_requirements text,                -- exigences des parties intéressées (§4.2)
  decision_criteria text NOT NULL,               -- critères de décision : criticité, risque, coût du cycle de vie
  risk_approach text,                            -- renvoi ISO 31000:2018, registre des risques (Annexe C, D28)
  climate_considerations text,                   -- contexte, effets du changement climatique sur les actifs (§4.1, §4.2)
  change_reason text,                            -- planification des changements (§6.3) : obligatoire à partir de la version 2
  version int NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','superseded')),
  approved_by uuid, approved_at timestamptz, review_due date,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_samp_sod CHECK (approved_by IS NULL OR approved_by <> created_by),
  CONSTRAINT ck_samp_change CHECK (version = 1 OR change_reason IS NOT NULL) );

-- AnnexeAM_AMDEC_Fiabilite#4
CREATE UNIQUE INDEX uq_samp_approved ON keystone.samp (tenant_id, coalesce(legal_entity_id, tenant_id))
  WHERE status = 'approved';

-- AnnexeAM_AMDEC_Fiabilite#5
CREATE TABLE keystone.am_decision_criteria (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  samp_id uuid NOT NULL REFERENCES keystone.samp(id) ON DELETE CASCADE,
  code text NOT NULL,                            -- ex. CRIT, LCC, RISK, ENERGY (données de démonstration)
  label text NOT NULL,
  applies_to text[] NOT NULL CHECK (applies_to <@ ARRAY['capex','maintenance_strategy','disposal','criticality']),
  weight numeric(5,4) NOT NULL CHECK (weight > 0 AND weight <= 1),
  source text NOT NULL,                          -- donnée ou calcul qui alimente le critère (ex. priority_score, eac)
  CONSTRAINT uq_amdc UNIQUE (samp_id, code) );

-- AnnexeAM_AMDEC_Fiabilite#7
CREATE TABLE keystone.capex_plans (              -- plan pluriannuel d'investissement, ISO 55001:2024 §6.2
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  samp_id uuid REFERENCES keystone.samp(id),
  legal_entity_id uuid REFERENCES atlas_core.legal_entities(id),
  site_id uuid REFERENCES atlas_core.sites(id),    -- NULL : toute l'entité
  client_id uuid,
  first_year smallint NOT NULL, horizon_years smallint NOT NULL DEFAULT 5 CHECK (horizon_years BETWEEN 1 AND 20),
  version int NOT NULL DEFAULT 1,
  currency char(3) NOT NULL,
  scenario_label text NOT NULL DEFAULT 'Scénario de référence',
  annual_budget_caps jsonb NOT NULL DEFAULT '{}',   -- {"2027": 150000000, ...} montants entiers en francs
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','submitted','approved','superseded')),
  submitted_by uuid, submitted_at timestamptz,
  approved_by uuid, approved_at timestamptz,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now() );

-- AnnexeC_HSSE#2
-- Définis une seule fois aux Référentiels transverses §1.3, cités ici sans création :
--   hsse_event_type (avec good_practice, A25), event_severity, event_status, investigation_method,
--   capa_type, capa_status, control_hierarchy, control_result, risk_level, permit_status,
--   inspection_kind, inspection_status, template_status.
-- keystone.record_origin ('planned','ad_hoc','flash','hoc') : énumération de l'Annexe W, partagée par
--   hsse_events, inspections et audits (colonne origin)
CREATE TYPE keystone.observation_kind AS ENUM ('unsafe_act','unsafe_condition','good_practice');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.hazard_category  AS ENUM ('slip_trip','fall_from_height','electrical','fire','traffic',
  'manual_handling','chemical','tools','housekeeping','security','environment','other');

-- AnnexeC_HSSE#2
-- pictogrammes ISO 7010
CREATE TYPE keystone.event_activity   AS ENUM ('operation','maintenance','works','cleaning','delivery','public','other');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.event_person_role AS ENUM ('victim','witness','involved','first_aider');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.care_level       AS ENUM ('none','first_aid','doctor','hospital');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.declaration_recipient AS ENUM
  ('social_security','labour_inspectorate','environment_authority','insurer','police','other');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.attachment_kind  AS ENUM ('photo','written_statement','report','video','other');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.ishikawa_category AS ENUM ('manpower','equipment','method','environment','material','measurement');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.fault_gate       AS ENUM ('and','or');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.timeline_source  AS ENUM ('witness','video','bms','document','observation','other');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.investigation_role AS ENUM ('lead','member','technical_expert');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.bowtie_node_type AS ENUM ('top_event','threat','consequence','barrier_prev','barrier_recov');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.barrier_status   AS ENUM ('effective','degraded','failed');

-- AnnexeC_HSSE#2
CREATE TYPE keystone.capa_source      AS ENUM ('event','investigation','audit','inspection','crp','risk','env','management_review','compliance','crisis_drill');

-- AnnexeC_HSSE#2
-- crisis_drill : Annexe U.18
CREATE TYPE keystone.worked_population AS ENUM ('internal','contractor');

-- AnnexeC_HSSE#2
-- A50
CREATE TYPE keystone.hours_source     AS ENUM ('manual','atlas_people','import');

-- AnnexeC_HSSE#3
-- keystone.severity_gravity(event_severity) et keystone.risk_band(int) : Référentiels transverses §1.1 (A49),
--   seules définitions du corpus ; « grav() » dans les règles désigne severity_gravity().

-- Cloisonnement par site : keystone.site_in_scope(p_site uuid) de l'Annexe A fait foi
--   (sites du profil actif, entités et sites accordés un par un) ; l'Annexe C ne la redéfinit pas.

-- Personne liée à l'utilisateur connecté : keystone.current_person_id() de l'Annexe A fait foi (A79) ;
--   l'Annexe C ne la redéfinit pas.

-- Refus explicite d'une permission manquante
CREATE FUNCTION keystone.assert_permission(p_code text) RETURNS void
LANGUAGE plpgsql STABLE SET search_path = keystone, pg_temp AS $$
BEGIN IF NOT keystone.has_permission(p_code) THEN
  PERFORM keystone.raise_error('PERMISSION_DENIED', jsonb_build_object('permission', p_code));
END IF; END; $$;

-- AnnexeC_HSSE#3
-- Paramètre numérique du tenant (table keystone.settings, Admin), valeur par défaut sinon
CREATE FUNCTION keystone.setting_num(p_key text, p_default numeric) RETURNS numeric
LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT (value #>> '{}')::numeric FROM keystone.settings
                   WHERE tenant_id = keystone.current_tenant() AND key = p_key), p_default) $$;

-- AnnexeC_HSSE#7
-- Écriture : chiffre, recalcule les agrégats anonymes de l'événement
CREATE FUNCTION keystone.set_event_person_health(
  p_event_person uuid, p_injury_nature text, p_body_part text,
  p_care_level keystone.care_level, p_lost_days int, p_certificate_ids uuid[] DEFAULT '{}')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE v_key text; v_evt uuid;
BEGIN
  PERFORM keystone.assert_permission('event.medical_read');
  SELECT ep.event_id INTO v_evt FROM keystone.event_persons ep
   WHERE ep.id = p_event_person AND ep.tenant_id = keystone.current_tenant() AND ep.role = 'victim';
  IF NOT FOUND THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'hsse_health_key_v1';
  INSERT INTO keystone.event_person_health AS h (tenant_id, event_person_id, event_id, injury_nature_enc,
    body_part_enc, care_level_enc, certificate_document_ids, lost_days, retain_until)
  VALUES (keystone.current_tenant(), p_event_person, v_evt, extensions.pgp_sym_encrypt(p_injury_nature, v_key),
    extensions.pgp_sym_encrypt(p_body_part, v_key), extensions.pgp_sym_encrypt(p_care_level::text, v_key),
    p_certificate_ids, p_lost_days, (now() + interval '40 years')::date)
  ON CONFLICT (event_person_id) DO UPDATE SET injury_nature_enc = EXCLUDED.injury_nature_enc,
    body_part_enc = EXCLUDED.body_part_enc, care_level_enc = EXCLUDED.care_level_enc,
    certificate_document_ids = EXCLUDED.certificate_document_ids, lost_days = EXCLUDED.lost_days;
  UPDATE keystone.hsse_events e SET
    injury_count   = (SELECT count(*) FROM keystone.event_persons WHERE event_id = v_evt AND role = 'victim'),
    lost_time_days = (SELECT COALESCE(sum(lost_days),0) FROM keystone.event_person_health WHERE event_id = v_evt)
  WHERE e.id = v_evt;
END; $$;

-- AnnexeC_HSSE#7
-- Lecture déchiffrée : permission vérifiée, chaque lecture tracée dans audit_trail (action 'health_read')
CREATE FUNCTION keystone.read_event_person_health(p_event uuid)
RETURNS TABLE (event_person_id uuid, injury_nature text, body_part text, care_level text,
               lost_days int, certificate_document_ids uuid[])
LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE v_key text;
BEGIN
  PERFORM keystone.assert_permission('event.medical_read');
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'hsse_health_key_v1';
  INSERT INTO keystone.audit_trail (tenant_id, actor, action, table_name, row_id)
  VALUES (keystone.current_tenant(), auth.uid(), 'health_read', 'event_person_health', p_event);
  RETURN QUERY SELECT h.event_person_id, extensions.pgp_sym_decrypt(h.injury_nature_enc, v_key),
    extensions.pgp_sym_decrypt(h.body_part_enc, v_key), extensions.pgp_sym_decrypt(h.care_level_enc, v_key),
    h.lost_days, h.certificate_document_ids
  FROM keystone.event_person_health h
  WHERE h.event_id = p_event AND h.tenant_id = keystone.current_tenant();
END; $$;

-- AnnexeC_HSSE#16
CREATE TABLE keystone.worked_hours (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  period_month date NOT NULL CHECK (period_month = date_trunc('month', period_month)::date),
  population keystone.worked_population NOT NULL,
  hours numeric(12,2) NOT NULL CHECK (hours >= 0),
  headcount int CHECK (headcount >= 0),
  source keystone.hours_source NOT NULL,
  source_ref text,                                     -- lot d'import Atlas People, déclaration du prestataire
  locked_at timestamptz,                               -- période verrouillée après publication du rapport mensuel
  CONSTRAINT uq_wh UNIQUE (tenant_id, site_id, period_month, population)
);

-- AnnexeC_HSSE#16
CREATE INDEX ix_wh_period ON keystone.worked_hours (tenant_id, period_month);

-- AnnexeC_HSSE_Partie2#1
CREATE TYPE keystone.work_unit_kind AS ENUM ('location','activity','job');

-- AnnexeC_HSSE_Partie2#1
CREATE TYPE keystone.risk_kind      AS ENUM ('threat','opportunity');

-- AnnexeC_HSSE_Partie2#1
-- opportunités SST, ISO 45001 §6.1.2.3
CREATE TYPE keystone.risk_category  AS ENUM ('ohs','environment','fm_operational','contractual','financial','security');

-- AnnexeC_HSSE_Partie2#1
CREATE TYPE keystone.risk_status    AS ENUM ('identified','in_treatment','controlled','to_review');

-- AnnexeC_HSSE_Partie2#1
CREATE TYPE keystone.duer_status    AS ENUM ('draft','published','superseded');

-- AnnexeC_HSSE_Partie2#1
CREATE TYPE keystone.risk_assessment_status AS ENUM ('draft','submitted','approved','rejected');

-- AnnexeC_HSSE_Partie2#1
CREATE TYPE keystone.risk_link_type AS ENUM ('event','audit_finding','inspection','asset','change');

-- AnnexeC_HSSE_Partie2#1
CREATE TYPE keystone.risk_scope_type AS ENUM ('site','zone','asset');

-- AnnexeC_HSSE_Partie2#2
-- Bibliothèque de dangers ; tenant_id NULL pour les lignes globales du seed (exception à id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), created_by uuid, -- auth.uid(), nul pour le service updated_by uuid, deleted_at timestamptz)
CREATE TABLE keystone.hazards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id),
  code text NOT NULL, name text NOT NULL, family keystone.hazard_category NOT NULL,
  description text, is_global boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_haz_global CHECK (is_global = (tenant_id IS NULL)),
  CONSTRAINT uq_haz_code UNIQUE NULLS NOT DISTINCT (tenant_id, code)
);

-- AnnexeC_HSSE_Partie2#2
-- Critères de risque par entité et catégorie (ISO 31000:2018 §6.3.4)
CREATE TABLE keystone.risk_criteria (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  category keystone.risk_category NOT NULL,
  treatment_threshold int NOT NULL DEFAULT 10 CHECK (treatment_threshold BETWEEN 1 AND 25),
  appetite_statement text,
  review_frequency_months int NOT NULL DEFAULT 12 CHECK (review_frequency_months BETWEEN 1 AND 36),
  approved_by uuid, approved_at timestamptz,
  UNIQUE (tenant_id, legal_entity_id, category)
);

-- AnnexeC_HSSE_Partie2#2
CREATE TABLE keystone.duer_versions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  country_code char(2) NOT NULL,
  ref text NOT NULL,                       -- DUER-2026-000004
  version int NOT NULL,
  status keystone.duer_status NOT NULL DEFAULT 'draft',
  snapshot jsonb,                          -- unités, risques ohs, maîtrises, plans de traitement, figés
  content_sha256 text,
  pdf_document_id uuid REFERENCES keystone.ged_documents(id),
  advist_signature_token text, signed_at timestamptz,   -- signature électronique Advist (C.27.3)
  published_at timestamptz, published_by uuid, superseded_at timestamptz,
  UNIQUE (tenant_id, legal_entity_id, version),
  CONSTRAINT ck_duer_pub CHECK (status = 'draft' OR (snapshot IS NOT NULL AND content_sha256 IS NOT NULL AND published_at IS NOT NULL))
);

-- AnnexeC_HSSE_Partie2#3
-- Version publiée immuable (RG-RSK-06)
CREATE FUNCTION keystone.tg_duer_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status IN ('published','superseded') THEN
    IF NEW.snapshot IS DISTINCT FROM OLD.snapshot OR NEW.content_sha256 IS DISTINCT FROM OLD.content_sha256
       OR NEW.pdf_document_id IS DISTINCT FROM OLD.pdf_document_id THEN PERFORM keystone.raise_error('DUER_IMMUTABLE'); END IF;
    IF NEW.status IS DISTINCT FROM OLD.status AND NOT (OLD.status = 'published' AND NEW.status = 'superseded')
      THEN PERFORM keystone.raise_error('DUER_IMMUTABLE'); END IF;
  END IF;
  RETURN NEW;
END; $$;

-- AnnexeC_HSSE_Partie2#3
CREATE TRIGGER duer_immutable BEFORE UPDATE ON keystone.duer_versions
  FOR EACH ROW EXECUTE FUNCTION keystone.tg_duer_immutable();

-- AnnexeC_HSSE_Partie2#5
CREATE TABLE keystone.risk_score_models (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  version int NOT NULL, weights jsonb NOT NULL, caps jsonb NOT NULL, window_days int NOT NULL DEFAULT 90,
  is_active boolean NOT NULL DEFAULT false, approved_by uuid, approved_at timestamptz,
  UNIQUE (tenant_id, version)
);

-- AnnexeC_HSSE_Partie2#5
CREATE UNIQUE INDEX uq_rsm_active ON keystone.risk_score_models (tenant_id) WHERE is_active;

-- AnnexeC_HSSE_Partie2#5
CREATE TABLE keystone.risk_scores (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  scope_type keystone.risk_scope_type NOT NULL, scope_id uuid NOT NULL,
  score numeric(6,2) NOT NULL CHECK (score BETWEEN 0 AND 100),
  model_version int NOT NULL,
  computed_at timestamptz NOT NULL DEFAULT now(),
  drivers jsonb NOT NULL                   -- {"driver":{"value":n,"cap":c,"weight":w,"contribution":x}}
);

-- AnnexeC_HSSE_Partie2#5
CREATE INDEX ix_rs_scope ON keystone.risk_scores (tenant_id, scope_type, scope_id, computed_at DESC);

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.permit_type AS ENUM
  ('hot_work','confined_space','electrical','work_at_height','excavation','lifting','general');

-- AnnexeC_HSSE_Partie2#6
-- six rubriques de D09 et le permis général ; le travail sous tension est un régime de la rubrique
  -- electrical (precautions.electrical.energized = true), pas une rubrique
-- keystone.permit_status : Référentiels transverses §1.3.
CREATE TYPE keystone.permit_level AS ENUM ('issuing_authority','zone_manager','hsse_approver','technical_manager','client_visa');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.approval_decision AS ENUM ('approved','returned');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.permit_signature_moment AS ENUM
  ('submit','approval','reception','briefing','suspension','resumption','extension','restitution','closure','client_visa');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.suspension_reason AS ENUM
  ('gas_alarm','evacuation','weather','non_compliance','co_activity','expired','emergency','other');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.watcher_kind AS ENUM ('fire_watch_during','fire_watch_after','confined_space_attendant');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.energy_type AS ENUM ('electrical','mechanical','hydraulic','pneumatic','thermal','chemical','gravity');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.zero_energy_method AS ENUM ('vat','start_test','purge','other');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.issuing_party AS ENUM ('operator','fm_provider','client');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.competency_check AS ENUM ('valid','missing','expired','pending');

-- AnnexeC_HSSE_Partie2#6
CREATE TYPE keystone.signature_method AS ENUM ('drawn','typed','advist');

-- AnnexeC_HSSE_Partie2#6
-- typed : signature par saisie du nom (Lot 4)
CREATE TYPE keystone.client_visa_decision AS ENUM ('granted','refused');

-- AnnexeC_HSSE_Partie2#8
CREATE TABLE keystone.permit_rubric_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id),    -- NULL : règle globale du seed, surchargée par tenant
  rubric keystone.permit_type NOT NULL,
  version int NOT NULL DEFAULT 1,
  form_schema jsonb NOT NULL,                          -- JSON Schema de precautions.<rubric>, champs « required » par moment
  required_levels keystone.permit_level[] NOT NULL,
  forces_isolation boolean NOT NULL DEFAULT false,
  locked_ppe text[] NOT NULL DEFAULT '{}',
  max_validity_hours int NOT NULL DEFAULT 12 CHECK (max_validity_hours BETWEEN 1 AND 168),
  max_extensions int NOT NULL DEFAULT 1 CHECK (max_extensions >= 0),
  lone_work_allowed boolean NOT NULL DEFAULT false,    -- travail isolé admis pour la rubrique
  min_workers int NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_prr UNIQUE NULLS NOT DISTINCT (tenant_id, rubric, version)
);

-- AnnexeC_HSSE_Partie2#11
CREATE TABLE keystone.lockboxes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  code text NOT NULL, label text, qr_code text NOT NULL,
  UNIQUE (tenant_id, code)
);

-- AnnexeC_HSSE_Partie2#13
CREATE TYPE keystone.prevention_plan_status AS ENUM ('draft','signed','expired','superseded');

-- AnnexeC_HSSE_Partie2#13
CREATE TYPE keystone.responsible_party AS ENUM ('company','vendor','both');

-- AnnexeE_Budgets_Achats#1
CREATE TABLE keystone.purchasing_settings (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  quotes_required_above bigint NOT NULL DEFAULT 2000000 CHECK (quotes_required_above >= 0),  -- trois devis au delà (D20)
  quotes_required_count smallint NOT NULL DEFAULT 3 CHECK (quotes_required_count BETWEEN 2 AND 10),
  no_po_cap bigint NOT NULL DEFAULT 100000 CHECK (no_po_cap >= 0),                           -- achat sans commande (D20)
  split_window_days smallint NOT NULL DEFAULT 30,                                            -- détection de fractionnement
  urgent_cap bigint NOT NULL DEFAULT 1000000 CHECK (urgent_cap >= 0),                        -- achat urgent avant approbation
  rfq_award_second_approver_above bigint NOT NULL DEFAULT 2000000,
  receiver_buyer_sod_above bigint NOT NULL DEFAULT 1000000,                                  -- réceptionnaire distinct de l'acheteur
  po_ack_window_hours smallint NOT NULL DEFAULT 48,
  rfq_min_window_hours smallint NOT NULL DEFAULT 48 CHECK (rfq_min_window_hours >= 0),   -- EV-L8-11
  tol_qty_pct numeric(7,4) NOT NULL DEFAULT 0,
  tol_price_pct numeric(7,4) NOT NULL DEFAULT 2,
  tol_total_pct numeric(7,4) NOT NULL DEFAULT 2,
  tol_service_pct numeric(7,4) NOT NULL DEFAULT 2,                                           -- rapprochement à deux voies
  vat_recoverable boolean NOT NULL DEFAULT true,                                              -- base de consommation : HT si vrai, TTC sinon
  budget_alert_pcts smallint[] NOT NULL DEFAULT '{80,100}',
  CONSTRAINT uq_purch_settings UNIQUE (tenant_id, legal_entity_id)
);

-- AnnexeE_Budgets_Achats#3
CREATE TYPE keystone.budget_kind     AS ENUM ('opex','capex');

-- AnnexeE_Budgets_Achats#3
CREATE TYPE keystone.budget_status   AS ENUM ('draft','approved','closed');

-- AnnexeE_Budgets_Achats#3
CREATE TYPE keystone.revision_kind   AS ENUM ('transfer','increase','decrease');

-- AnnexeE_Budgets_Achats#3
CREATE TYPE keystone.revision_status AS ENUM ('draft','submitted','approved','rejected','cancelled');

-- AnnexeE_Budgets_Achats#3
CREATE TABLE keystone.budget_categories (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL, label text NOT NULL,
  kind keystone.budget_kind NOT NULL,
  is_energy boolean NOT NULL DEFAULT false,            -- reçoit les coûts d'énergie (E.10)
  fna_account_hint text,                                -- indication de compte, le mapping fait foi côté Atlas FNA
  CONSTRAINT uq_budget_cat UNIQUE (tenant_id, code)
);

-- AnnexeE_Budgets_Achats#6
CREATE TYPE keystone.approval_object AS ENUM
  ('purchase_request','purchase_order_change','expense','budget_revision','rfq_award','catalog_price');

-- AnnexeE_Budgets_Achats#6
CREATE TABLE keystone.approval_levels (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  object_type keystone.approval_object NOT NULL,
  kind keystone.budget_kind,                             -- NULL : les deux natures
  site_id uuid REFERENCES atlas_core.sites(id),            -- NULL : tous sites
  level smallint NOT NULL CHECK (level BETWEEN 1 AND 5),
  min_amount bigint NOT NULL DEFAULT 0 CHECK (min_amount >= 0),
  role_id uuid NOT NULL REFERENCES keystone.roles(id),   -- rôle porteur de l'approbation
  is_over_budget_level boolean NOT NULL DEFAULT false,   -- exigé en dépassement de budget
  CONSTRAINT uq_approval_level UNIQUE (tenant_id, legal_entity_id, object_type, kind, site_id, level)
);

-- AnnexeE_Budgets_Achats#6
CREATE TABLE keystone.approval_delegations (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  delegator_id uuid NOT NULL, delegate_id uuid NOT NULL,
  object_types keystone.approval_object[] NOT NULL,
  max_amount bigint NOT NULL CHECK (max_amount >= 0),
  starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL,
  reason text NOT NULL, revoked_at timestamptz,
  CONSTRAINT ck_deleg_people CHECK (delegator_id <> delegate_id),
  CONSTRAINT ck_deleg_dates CHECK (ends_at > starts_at AND ends_at <= starts_at + interval '90 days')
);

-- AnnexeE_Budgets_Achats#6
CREATE INDEX ix_deleg_active ON keystone.approval_delegations (tenant_id, delegate_id, starts_at, ends_at) WHERE revoked_at IS NULL;

-- AnnexeE_Budgets_Achats#6
CREATE TABLE keystone.approval_steps (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  object_type keystone.approval_object NOT NULL, object_id uuid NOT NULL,
  level smallint NOT NULL, required_role_id uuid NOT NULL,
  decision text CHECK (decision IN ('approved','rejected','info_requested')),  -- info_requested : « Demander un complément » (EV-L8-04)
  decided_by uuid, decided_at timestamptz, reason text,
  delegation_id uuid REFERENCES keystone.approval_delegations(id),
  CONSTRAINT uq_approval_step UNIQUE (tenant_id, object_type, object_id, level)
);

-- AnnexeE_Budgets_Achats#7
CREATE TYPE keystone.pr_status     AS ENUM ('draft','submitted','approved','rejected','ordered','cancelled');

-- AnnexeE_Budgets_Achats#7
CREATE TYPE keystone.purchase_mode AS ENUM ('three_quotes','framework_contract','single_source','catalog','urgent');

-- AnnexeE_Budgets_Achats#8
CREATE TYPE keystone.rfq_status        AS ENUM ('draft','sent','closed','awarded','cancelled');

-- AnnexeE_Budgets_Achats#8
CREATE TYPE keystone.rfq_invite_status AS ENUM ('invited','viewed','declined','responded');

-- AnnexeE_Budgets_Achats#8
CREATE TYPE keystone.rfq_response_status AS ENUM ('draft','sent','withdrawn');

-- AnnexeE_Budgets_Achats#9
CREATE TYPE keystone.po_status      AS ENUM ('draft','sent','partially_received','received','closed','cancelled');

-- AnnexeE_Budgets_Achats#9
CREATE TYPE keystone.po_ack_status  AS ENUM ('pending','acknowledged','confirmed','change_proposed','refused');

-- AnnexeE_Budgets_Achats#12
CREATE TYPE keystone.expense_status AS ENUM ('draft','submitted','approved','partially_paid','paid','rejected','cancelled');

-- AnnexeE_Budgets_Achats#12
CREATE TYPE keystone.expense_source AS ENUM ('work_order','vendor_invoice','contract_installment','no_po','utility_invoice','manual');

-- AnnexeE_Budgets_Achats#12
CREATE TYPE keystone.expense_doc    AS ENUM ('invoice','credit_note','internal');

-- AnnexeE_Budgets_Achats#12
CREATE TYPE keystone.match_status   AS ENUM ('not_applicable','awaiting_invoice','awaiting_verification','matching','unmatched','matched','variance','variance_justified');

-- AnnexeE_Budgets_Achats#14
CREATE TABLE keystone.budget_period_closures (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  period date NOT NULL CHECK (date_trunc('month', period) = period),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closing','closed')),
  closed_by uuid, closed_at timestamptz, reopened_by uuid, reopened_at timestamptz, reopen_reason text,
  CONSTRAINT uq_period_closure UNIQUE (tenant_id, legal_entity_id, period)
);

-- AnnexeE_Budgets_Achats_Partie2#1
CREATE FUNCTION keystone.tg_budget_kind() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.kind <> (SELECT kind FROM keystone.budget_categories WHERE id = NEW.category_id) THEN
    PERFORM keystone.raise_error('BUDGET_KIND_MISMATCH', jsonb_build_object('category_id', NEW.category_id));
  END IF;
  RETURN NEW;
END; $$;

-- AnnexeE_Budgets_Achats_Partie2#2
CREATE UNIQUE INDEX uq_over_budget_level ON keystone.approval_levels (tenant_id, legal_entity_id, object_type)
  WHERE is_over_budget_level AND deleted_at IS NULL;

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE TYPE keystone.commitment_source AS ENUM ('po_line','work_order','maintenance_contract');

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE TYPE keystone.commitment_status AS ENUM ('open','consumed','released');

-- AnnexeE_Budgets_Achats_Partie2#5
CREATE FUNCTION keystone.pr_link_work_order(p_request uuid, p_work_order uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
BEGIN
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

-- AnnexeE_Budgets_Achats_Partie2#6
CREATE TABLE keystone.purchase_comments (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  object_type text NOT NULL CHECK (object_type IN ('purchase_request','rfq','purchase_order','goods_receipt','expense','budget')),
  object_id uuid NOT NULL,
  author_id uuid NOT NULL REFERENCES keystone.users(id),
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 2000),
  mentions uuid[] NOT NULL DEFAULT '{}',                 -- utilisateurs mentionnés
  attachment_ids uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(attachment_ids) <= 5)   -- tg_check_document_ids
);

-- AnnexeE_Budgets_Achats_Partie2#6
CREATE INDEX ix_pcom_object ON keystone.purchase_comments (tenant_id, object_type, object_id, created_at);

-- AnnexeC_HSSE_Partie3#1
-- keystone.inspection_kind : Référentiels transverses §1.3.
CREATE TYPE keystone.inspection_domain AS ENUM ('safety','hsse','cleaning','technical','security','environment');

-- AnnexeC_HSSE_Partie3#1
CREATE TYPE keystone.inspection_target_kind AS ENUM ('site','building','floor','location','asset');

-- AnnexeC_HSSE_Partie3#1
CREATE TYPE keystone.scoring_method AS ENUM ('conformity_pct','weighted_points','en13549_level');

-- AnnexeC_HSSE_Partie3#1
-- keystone.template_status : Référentiels transverses §1.3.
CREATE TYPE keystone.answer_type AS ENUM ('conformity','measure','yes_no','multi_choice','text');

-- AnnexeC_HSSE_Partie3#1
CREATE TYPE keystone.photo_rule AS ENUM ('optional','required_if_nc','always');

-- AnnexeC_HSSE_Partie3#1
CREATE TYPE keystone.nc_action AS ENUM ('none','corrective_wo','capa');

-- AnnexeC_HSSE_Partie3#1
-- keystone.inspection_status : Référentiels transverses §1.3.
CREATE TYPE keystone.inspection_result AS ENUM ('pass','fail');

-- AnnexeC_HSSE_Partie3#1
CREATE TYPE keystone.frequency_unit AS ENUM ('day','week','month','year');

-- AnnexeC_HSSE_Partie3#2
CREATE TABLE keystone.inspection_templates (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL,                       -- INS-SSI-MENS (données de démonstration)
  version int NOT NULL DEFAULT 1,
  name text NOT NULL,
  kind keystone.inspection_kind NOT NULL DEFAULT 'inspection',
  domain keystone.inspection_domain NOT NULL,
  target_kind keystone.inspection_target_kind NOT NULL,
  asset_category_id uuid REFERENCES keystone.asset_categories(id),
  scoring_method keystone.scoring_method NOT NULL,
  pass_threshold numeric(5,2) NOT NULL CHECK (pass_threshold BETWEEN 0 AND 100),
  qc_sampling_plan_id uuid,                 -- qc_sampling_plans, EN 13549:2001 (Annexe F), si en13549_level
  default_frequency_value int CHECK (default_frequency_value > 0),
  default_frequency_unit keystone.frequency_unit,
  status keystone.template_status NOT NULL DEFAULT 'draft',
  published_at timestamptz, published_by uuid,
  UNIQUE (tenant_id, code, version),
  CONSTRAINT ck_it_asset CHECK (target_kind <> 'asset' OR asset_category_id IS NOT NULL),
  CONSTRAINT ck_it_en CHECK (scoring_method <> 'en13549_level' OR qc_sampling_plan_id IS NOT NULL)
);

-- AnnexeC_HSSE_Partie3#3
CREATE TYPE keystone.audit_kind AS ENUM ('internal','external','certification');

-- AnnexeC_HSSE_Partie3#3
CREATE TYPE keystone.audit_status AS ENUM ('planned','in_progress','completed','closed','cancelled');

-- AnnexeC_HSSE_Partie3#3
CREATE TYPE keystone.audit_program_status AS ENUM ('draft','approved','closed');

-- AnnexeC_HSSE_Partie3#3
CREATE TYPE keystone.audit_team_role AS ENUM ('lead','auditor','technical_expert','observer');

-- AnnexeC_HSSE_Partie3#3
CREATE TYPE keystone.finding_severity AS ENUM ('nc_major','nc_minor','observation','opportunity');

-- AnnexeC_HSSE_Partie3#3
CREATE TYPE keystone.finding_status AS ENUM ('open','in_treatment','closed');

-- AnnexeC_HSSE_Partie3#3
CREATE TYPE keystone.audit_conclusion AS ENUM ('conform','conform_with_reserves','non_conform');

-- AnnexeC_HSSE_Partie3#4
CREATE TABLE keystone.audit_programs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  year int NOT NULL, title text NOT NULL,
  objectives text NOT NULL,
  risks_opportunities text,                -- risques et opportunités du programme (ISO 19011 §5.3)
  status keystone.audit_program_status NOT NULL DEFAULT 'draft',
  approved_by uuid, approved_at timestamptz,
  evaluation text, evaluated_at timestamptz, evaluated_by uuid,   -- évaluation du programme (§5.7)
  UNIQUE (tenant_id, legal_entity_id, year)
);

-- AnnexeC_HSSE_Partie3#5
CREATE TYPE keystone.compliance_status AS ENUM ('open','compliant','non_compliant','na');

-- AnnexeC_HSSE_Partie3#5
CREATE TYPE keystone.obligation_domain AS ENUM ('ohs','environment','fire','security','data_protection','other');

-- AnnexeC_HSSE_Partie3#5
CREATE TABLE keystone.compliance_frameworks (            -- global, géré par l'éditeur
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE, name text NOT NULL, edition text NOT NULL   -- ISO 45001:2018, ISO 14001:2026
);

-- AnnexeC_HSSE_Partie3#5
CREATE TABLE keystone.legal_obligations (                -- CDC v3 §6.11, enrichie
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id),      -- NULL : ligne d'un legal_framework_pack global
  country_code char(2) NOT NULL,
  framework_id uuid REFERENCES keystone.compliance_frameworks(id),
  domain keystone.obligation_domain NOT NULL,
  label text NOT NULL, obligation text NOT NULL,
  source_text text NOT NULL,                             -- texte légal
  source_article text,                                   -- article (constat m8)
  source_date date,                                      -- date du texte
  is_confirmed boolean NOT NULL DEFAULT false,           -- faux : « à confirmer » par un juriste
  confirmed_by uuid, confirmed_on date,
  CONSTRAINT ck_lo_conf CHECK (NOT is_confirmed OR (confirmed_by IS NOT NULL AND confirmed_on IS NOT NULL)),
  is_global boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_lo_global CHECK (is_global = (tenant_id IS NULL))
);

-- AnnexeC_HSSE_Partie3#5
CREATE TABLE keystone.obligation_control_map (           -- preuve de couverture (CDC v3)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  obligation_id uuid NOT NULL REFERENCES keystone.legal_obligations(id),
  control_table text NOT NULL, control_id uuid NOT NULL,
  UNIQUE (obligation_id, control_table, control_id)
);

-- AnnexeC_HSSE_Partie3#6
CREATE TYPE keystone.regulatory_watch_status AS ENUM ('proposed','accepted','rejected');

-- AnnexeC_HSSE_Partie4#1
CREATE TYPE keystone.medical_visit_kind AS ENUM ('hiring','periodic','pre_return','return_to_work','on_request','end_of_exposure');

-- AnnexeC_HSSE_Partie4#1
CREATE TYPE keystone.fitness_decision   AS ENUM ('fit','fit_with_restrictions','temporarily_unfit','unfit');

-- AnnexeC_HSSE_Partie4#1
CREATE TYPE keystone.exposure_family    AS ENUM ('noise','chemical','dust','vibration','heat','biological','radiation','other');

-- AnnexeC_HSSE_Partie4#1
CREATE TYPE keystone.disease_status     AS ENUM ('suspected','declared','recognised','rejected');

-- AnnexeC_HSSE_Partie4#4
-- Exemple d'écriture chiffrée, même schéma pour les trois tables
CREATE FUNCTION keystone.record_medical_visit(p_person uuid, p_kind keystone.medical_visit_kind,
  p_visit_date date, p_fitness keystone.fitness_decision, p_restrictions text DEFAULT NULL,
  p_practitioner text DEFAULT NULL, p_next_due date DEFAULT NULL, p_documents uuid[] DEFAULT '{}')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE v_key text; v_id uuid;
BEGIN
  PERFORM keystone.assert_permission('event.medical_read');
  IF NOT keystone.occupational_health_active() THEN PERFORM keystone.raise_error('HEALTH_MODULE_NOT_ACTIVATED'); END IF;
  IF NOT EXISTS (SELECT 1 FROM keystone.persons WHERE id = p_person AND tenant_id = keystone.current_tenant()) THEN
    PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  IF p_visit_date > current_date THEN
    PERFORM keystone.raise_error('INVALID_DATE', '{"field":"visit_date"}'::jsonb); END IF;
  IF p_next_due IS NOT NULL AND p_next_due <= p_visit_date THEN
    PERFORM keystone.raise_error('INVALID_DATE', '{"field":"next_due"}'::jsonb); END IF;
  IF p_fitness = 'fit_with_restrictions' AND nullif(btrim(p_restrictions), '') IS NULL THEN
    PERFORM keystone.raise_error('REQUIRED_FIELD', '{"field":"restrictions"}'::jsonb); END IF;
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'hsse_health_key_v1';
  IF v_key IS NULL THEN PERFORM keystone.raise_error('HEALTH_KEY_UNAVAILABLE'); END IF;
  INSERT INTO keystone.medical_visits (tenant_id, person_id, kind, visit_date, practitioner_enc, fitness_enc,
    restrictions_enc, next_due, document_ids, retain_until, created_by)
  VALUES (keystone.current_tenant(), p_person, p_kind, p_visit_date,
    extensions.pgp_sym_encrypt(p_practitioner, v_key), extensions.pgp_sym_encrypt(p_fitness::text, v_key),
    extensions.pgp_sym_encrypt(p_restrictions, v_key), p_next_due, p_documents,
    keystone.occupational_health_retain_until(p_person, p_visit_date), auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END; $$;

-- AnnexeR_Reglementaire_SSI#1
-- keystone.control_result : Référentiels transverses §1.3.
CREATE TYPE keystone.regulatory_status   AS ENUM ('compliant','due','overdue','non_compliant','suspended');

-- AnnexeR_Reglementaire_SSI#1
CREATE TYPE keystone.due_basis           AS ENUM ('actual','theoretical');

-- AnnexeR_Reglementaire_SSI#1
CREATE TYPE keystone.body_kind           AS ENUM ('accredited_body','manufacturer','internal');

-- AnnexeR_Reglementaire_SSI#1
CREATE TYPE keystone.reserve_status      AS ENUM ('open','in_treatment','lifted');

-- AnnexeR_Reglementaire_SSI#1
CREATE TYPE keystone.fire_system_type    AS ENUM ('detection','smoke_control','extinguishing','extinguishers','emergency_lighting','alarm');

-- AnnexeR_Reglementaire_SSI#1
CREATE TYPE keystone.ssi_inhibition_status AS ENUM ('requested','active','overrun','restored','cancelled');

-- AnnexeR_Reglementaire_SSI#1
CREATE TYPE keystone.drill_status        AS ENUM ('planned','done','analysed','cancelled');

-- AnnexeR_Reglementaire_SSI#2
-- NC-12-02 : ck_ib_accr porte l'obligation du numéro et de la validité d'agrément d'un organisme agréé ;
--   écriture sous RLS crp.manage (R.11) ; trigger tg_ib_required (BEFORE INSERT OR UPDATE) lève avant la contrainte
--   keystone.raise_error('REQUIRED_FIELD', {"field": "accreditation" ou "accreditation_valid_to"}) (A96).

CREATE TABLE keystone.regulatory_regimes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL,                       -- LIFT, SSI, ELEC, LIFTING, PRESSURE, EXTINGUISHER, SMOKE (données de démonstration)
  label text NOT NULL,
  country_code char(2) NOT NULL,
  default_frequency_months int NOT NULL CHECK (default_frequency_months > 0),
  due_basis keystone.due_basis NOT NULL DEFAULT 'actual',
  due_soon_days int NOT NULL DEFAULT 60 CHECK (due_soon_days > 0),   -- horizon « échéance proche », réglable par régime (A74)
  is_blocking boolean NOT NULL DEFAULT false,          -- non conforme : actif 'down'
  is_critical boolean NOT NULL DEFAULT false,           -- garde de site A.1.3, relance quotidienne au delà de l'échéance
  recheck_delay_days int CHECK (recheck_delay_days > 0),-- délai de contre-visite après non-conformité
  reopening_delay_days int NOT NULL DEFAULT 0 CHECK (reopening_delay_days >= 0),   -- A46, valeur par défaut, à confirmer
  legal_source text,                        -- texte, article, date ; « à confirmer » tant que non validé
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (tenant_id, country_code, code),
  CONSTRAINT ck_rr_recheck CHECK (NOT is_blocking OR recheck_delay_days IS NOT NULL)
);

-- AnnexeR_Reglementaire_SSI#3
CREATE TABLE keystone.site_regulatory_suspensions (     -- A46
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  suspended_at timestamptz NOT NULL, reason text NOT NULL, suspended_by uuid NOT NULL,
  resumed_at timestamptz, resumed_by uuid,
  CONSTRAINT ck_srs CHECK (resumed_at IS NULL OR resumed_at >= suspended_at)
);

-- AnnexeR_Reglementaire_SSI#3
CREATE UNIQUE INDEX uq_srs_open ON keystone.site_regulatory_suspensions (site_id) WHERE resumed_at IS NULL;

-- AnnexeR_Reglementaire_SSI#7
CREATE TABLE keystone.fire_drill_plans (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  year int NOT NULL, planned_date date NOT NULL,
  scenario text NOT NULL, is_unannounced boolean NOT NULL DEFAULT false,
  observers uuid[] NOT NULL DEFAULT '{}',
  sector_ids uuid[] NOT NULL DEFAULT '{}',   -- secteurs d'évacuation concernés (Annexe S)
  status keystone.drill_status NOT NULL DEFAULT 'planned',
  cancel_reason text
);

-- AnnexeD_Tickets_Portails#1
-- keystone.ticket_status : défini dans les Référentiels transverses §1.4 (9 valeurs, A53), non redéfini ici.
CREATE TYPE keystone.ticket_channel AS ENUM
  ('portal','scan','phone','email','public','client_portal','internal');

-- AnnexeD_Tickets_Portails#1
-- client_portal : saisie dans le portail client (Annexe CL.2) ; internal : créée depuis la console, la main courante
  -- ou une ronde (évolution, à valider)
CREATE TYPE keystone.ticket_requested_priority AS ENUM ('discomfort','urgent','blocking');

-- AnnexeD_Tickets_Portails#1
-- Gêne, Urgent, Bloquant
CREATE TYPE keystone.ticket_decision AS ENUM ('direct_resolution','convert_to_wo','reject');

-- AnnexeD_Tickets_Portails#1
-- RG-TCK-02
CREATE TYPE keystone.ticket_resolution_code AS ENUM
  ('repaired','adjusted','advice_given','out_of_scope','duplicate','abusive');

-- AnnexeD_Tickets_Portails#7
CREATE FUNCTION keystone.check_ticket_duplicate(p_location uuid, p_asset uuid, p_category uuid, p_follow boolean DEFAULT false)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE v_id uuid; v_client uuid;
BEGIN
  SELECT s.client_id INTO v_client FROM keystone.locations l JOIN keystone.sites s ON s.id = l.site_id
   WHERE l.id = p_location AND l.tenant_id = keystone.current_tenant();
  SELECT t.id INTO v_id FROM keystone.tickets t
   WHERE t.tenant_id = keystone.current_tenant() AND t.client_id IS NOT DISTINCT FROM v_client
     AND t.status IN ('new','triage','assigned','in_progress','reopened') AND t.deleted_at IS NULL
     AND t.created_at > now() - interval '24 hours'
     AND ((p_asset IS NOT NULL AND t.asset_id = p_asset)
          OR (t.location_id = p_location AND t.category_id = p_category))
   ORDER BY t.created_at LIMIT 1;
  IF v_id IS NULL THEN RETURN false; END IF;
  IF p_follow AND auth.uid() IS NOT NULL THEN
    INSERT INTO keystone.ticket_followers (tenant_id, ticket_id, user_id)
    VALUES (keystone.current_tenant(), v_id, auth.uid()) ON CONFLICT DO NOTHING;
  END IF;
  RETURN true;     -- jamais la référence, l'objet ni l'émetteur (RG-TCK-10, RG-OCC-04)
END $$;

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE TYPE keystone.occupant_org_kind   AS ENUM ('retail_tenant','office_tenant','internal_service','other');

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE TYPE keystone.occupant_org_status AS ENUM ('active','suspended','archived');

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE TYPE keystone.occupant_role       AS ENUM ('occupant_admin','requester','reader');

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE TYPE keystone.occupant_user_status AS ENUM ('invited','active','disabled');

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE TABLE keystone.occupant_organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,     -- RG-OCC-01
  code text NOT NULL, name text NOT NULL,
  kind keystone.occupant_org_kind NOT NULL,
  lease_ref text,                       -- référence de bail Atlas Patrimoine, lecture seule (I05)
  status keystone.occupant_org_status NOT NULL DEFAULT 'active',
  emergency_contacts jsonb NOT NULL DEFAULT '{}',   -- schéma D.17.1, visibles de la sûreté du site (Annexe U)
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_occupant_org UNIQUE (tenant_id, site_id, code),
  CONSTRAINT ck_occupant_emergency CHECK (jsonb_typeof(emergency_contacts) = 'object'
    AND emergency_contacts - ARRAY['primary_name','primary_phone','backup_name','backup_phone'] = '{}'::jsonb)
);

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE INDEX ix_occupant_org_site ON keystone.occupant_organizations (tenant_id, site_id, status);

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE TABLE keystone.occupant_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, occupant_org_id uuid NOT NULL REFERENCES keystone.occupant_organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,                                   -- auth.users, profil dans l'Admin (I06)
  role keystone.occupant_role NOT NULL DEFAULT 'reader',
  status keystone.occupant_user_status NOT NULL DEFAULT 'invited',
  invited_by uuid, invited_at timestamptz, activated_at timestamptz, disabled_at timestamptz,
  self_registered boolean NOT NULL DEFAULT false,
  privacy_consent_at timestamptz,                          -- acceptation de la politique de confidentialité (PO-02)
  privacy_policy_version text,                             -- version acceptée (Protection des données)
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_occupant_user UNIQUE (occupant_org_id, user_id),
  CONSTRAINT ck_occupant_consent CHECK (NOT self_registered OR (privacy_consent_at IS NOT NULL AND privacy_policy_version IS NOT NULL))
);

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE INDEX ix_occupant_user ON keystone.occupant_users (tenant_id, user_id, status);

-- AnnexeD_Tickets_Portails_Partie2#1
CREATE TABLE keystone.occupant_site_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE CASCADE,
  code_hash text NOT NULL,                                 -- argon2id du code, jamais le code en clair
  valid_until timestamptz NOT NULL, max_uses int NOT NULL CHECK (max_uses > 0),
  uses int NOT NULL DEFAULT 0 CHECK (uses >= 0), revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT ck_site_code_uses CHECK (uses <= max_uses)
);

-- AnnexeD_Tickets_Portails_Partie2#6
CREATE TYPE keystone.announcement_type   AS ENUM ('planned_works','shutdown','utility_cut','security','evacuation_drill','information');

-- AnnexeD_Tickets_Portails_Partie2#6
CREATE TYPE keystone.announcement_level  AS ENUM ('information','important','urgent');

-- AnnexeD_Tickets_Portails_Partie2#6
CREATE TYPE keystone.announcement_status AS ENUM ('draft','published','expired','withdrawn');

-- AnnexeP_Prestataires_Mobile_Partie2#5
CREATE TYPE keystone.lone_worker_status  AS ENUM ('raised','acknowledged','resolved','false_alarm','cancelled');

-- AnnexeP_Prestataires_Mobile_Partie2#5
CREATE TYPE keystone.lone_worker_trigger AS ENUM ('sos_button','missed_check_in','no_motion','fall_detected');

-- AnnexeTA_Travaux_Amenagement#1
CREATE TYPE keystone.fitout_status AS ENUM
  ('draft','submitted','under_review','info_requested','approved','rejected','withdrawn',
   'in_progress','suspended','completed','accepted','accepted_with_reserves','closed');

-- AnnexeTA_Travaux_Amenagement#1
CREATE TYPE keystone.fitout_work_type AS ENUM
  ('partitioning','finishes','electrical','hvac','plumbing','signage_facade','furniture','networks','other');

-- AnnexeTA_Travaux_Amenagement#1
CREATE TYPE keystone.fitout_common_impact AS ENUM
  ('electrical_connection','hvac_connection','fire_detection_change','slab_or_bearing_wall','none');

-- AnnexeTA_Travaux_Amenagement#1
CREATE TYPE keystone.fitout_visa_discipline AS ENUM ('technical','fire_safety','security','operations','inspection_body','client');

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_condition_templates (
  tenant_id uuid NOT NULL, code text NOT NULL, category text NOT NULL, text text NOT NULL,
  is_active boolean NOT NULL DEFAULT true, PRIMARY KEY (tenant_id, code) );

-- AnnexeM_Mode_Prestataire#1
CREATE FUNCTION keystone.assert_provider_mode() RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = keystone, atlas_core, pg_temp AS $$
BEGIN
  IF (SELECT operating_mode FROM atlas_core.tenants WHERE id = keystone.current_tenant()) <> 'fm_provider' THEN
    PERFORM keystone.raise_error('PROVIDER_MODE_REQUIRED', '{}'::jsonb);
  END IF;
END; $$;

-- AnnexeM_Mode_Prestataire#2
CREATE TYPE keystone.client_status AS ENUM ('prospect','active','suspended','churned');

-- AnnexeM_Mode_Prestataire#3
CREATE TYPE keystone.client_role        AS ENUM ('reader','requester','validator','approver','client_admin');

-- AnnexeM_Mode_Prestataire#3
CREATE TYPE keystone.client_user_status AS ENUM ('invited','active','disabled');

-- AnnexeM_Mode_Prestataire#4
CREATE TYPE keystone.pricing_model   AS ENUM ('fixed','time_and_material','per_m2','per_asset');

-- AnnexeM_Mode_Prestataire#4
CREATE TYPE keystone.billing_period  AS ENUM ('monthly','quarterly','yearly');

-- AnnexeM_Mode_Prestataire#4
CREATE TYPE keystone.contract_status AS ENUM ('draft','active','suspended','expired','terminated');

-- AnnexeM_Mode_Prestataire#4
CREATE TYPE keystone.portal_branding AS ENUM ('fm','client','co_branded');

-- AnnexeM_Mode_Prestataire#4
CREATE TYPE keystone.fitout_mgmt     AS ENUM ('none','fm_instructs','client_instructs');

-- AnnexeM_Mode_Prestataire#6
CREATE TYPE keystone.billable_kind   AS ENUM ('recurring','variable','penalty','adjustment');

-- AnnexeM_Mode_Prestataire#6
CREATE TYPE keystone.billable_status AS ENUM ('draft','validated','pushed','invoiced','paid','cancelled');

-- AnnexeM_Mode_Prestataire#7
CREATE TYPE keystone.mobilization_kind   AS ENUM ('takeover','site_opening','building_opening','vendor_contract_start','pre_opening');

-- AnnexeM_Mode_Prestataire#7
-- pre_opening : réception des ouvrages d'un site neuf avant ouverture, réserves et garanties (CDC v3 §6.19)
CREATE TYPE keystone.mobilization_status AS ENUM ('draft','in_progress','ready','go_live','closed','cancelled');

-- AnnexeM_Mode_Prestataire#7
CREATE TYPE keystone.mobilization_task_status AS ENUM ('todo','doing','done','na');

-- AnnexeM_Mode_Prestataire#7
CREATE TYPE keystone.mobilization_category AS ENUM
  ('asset_inventory','plans','condition_survey','staffing','contracts','regulatory','hse','access_keys','it_accounts','training','other');

-- AnnexeM_Mode_Prestataire#7
CREATE TABLE keystone.mobilization_templates (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  name text NOT NULL, kind keystone.mobilization_kind NOT NULL,
  items jsonb NOT NULL,                                  -- [{ "category", "label", "is_blocking", "offset_days", "evidence_required" }]
  CONSTRAINT ck_template_items CHECK (jsonb_typeof(items) = 'array')
);

-- AnnexeM_Mode_Prestataire#8
CREATE TYPE keystone.staff_transfer_decision AS ENUM ('pending','retained','not_retained');

-- AnnexeM_Mode_Prestataire#9
CREATE TYPE keystone.mobilization_reserve_status AS ENUM ('open','in_progress','lifted','accepted','cancelled');

-- AnnexeM_Mode_Prestataire#9
CREATE TYPE keystone.works_guarantee AS ENUM ('completion','biennial','decennial','none');

-- AnnexeM_Mode_Prestataire_Partie2#1
CREATE TYPE keystone.client_quote_status AS ENUM
  ('draft','submitted','awaiting_authority','approved','partially_approved','refused','expired','superseded','withdrawn');

-- AnnexeM_Mode_Prestataire_Partie2#2
CREATE TYPE keystone.acceptance_status AS ENUM
  ('pending','accepted','accepted_with_reserves','contested','tacitly_accepted');

-- AnnexeM_Mode_Prestataire_Partie2#2
CREATE TYPE keystone.dispute_status AS ENUM ('open','fm_answered','arbitration','closed');

-- AnnexeM_Mode_Prestataire_Partie2#3
CREATE TYPE keystone.trade_invoice_status AS ENUM ('issued','partially_paid','paid','overdue','cancelled','credited');

-- AnnexeCL_Portail_Client#3
CREATE TABLE keystone.client_portal_access_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, client_id uuid NOT NULL, client_user_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('login','view_plan','export','quote_decision','acceptance_decision','fitout_decision','permit_visa','role_change','capex_comment','document_deposit')),
  object_type text, object_id uuid,
  ip inet, user_agent text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeCL_Portail_Client#3
CREATE INDEX ix_cpal ON keystone.client_portal_access_log (tenant_id, client_id, occurred_at);

-- AnnexeIF_Interfaces#1
CREATE TYPE keystone.integration_target AS ENUM ('atlas_trade','atlas_fna','cinetpay','atlas_patrimoine','atlas_people','atlas_trace','advist');

-- AnnexeIF_Interfaces#1
-- advist : IF.7 bis, évolution, à valider

CREATE TABLE keystone.integration_endpoints (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  target keystone.integration_target NOT NULL,
  base_url text NOT NULL CHECK (base_url ~ '^https://'),
  outbound_secret_ids uuid[] NOT NULL,                  -- Vault, au plus deux secrets actifs (rotation)
  inbound_secret_ids uuid[] NOT NULL,
  external_tenant_ref text NOT NULL,                     -- identifiant du même abonné chez la cible
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','disabled')),
  paused_reason text,
  CONSTRAINT uq_endpoint UNIQUE (tenant_id, target)
);

-- AnnexeIF_Interfaces#1
CREATE TABLE keystone.integration_outbox (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, target keystone.integration_target NOT NULL,
  message_id uuid NOT NULL DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL,
  type text NOT NULL, ordering_key text NOT NULL,        -- agrégat : contrat, dépense, intention de paiement
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sending','delivered','failed','dead')),
  attempts smallint NOT NULL DEFAULT 0, next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_http_status smallint, last_error_code text, last_error text,
  created_at timestamptz NOT NULL DEFAULT now(), delivered_at timestamptz,
  replayed_by uuid, replayed_at timestamptz,             -- relance manuelle (L10-29)
  CONSTRAINT uq_outbox_idem UNIQUE (tenant_id, target, idempotency_key)
);

-- AnnexeIF_Interfaces#1
CREATE INDEX ix_outbox_due ON keystone.integration_outbox (next_attempt_at) WHERE status IN ('pending','failed');

-- AnnexeIF_Interfaces#1
CREATE TABLE keystone.integration_inbox (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, source keystone.integration_target NOT NULL,
  message_id text NOT NULL, idempotency_key text NOT NULL, type text NOT NULL,
  payload jsonb NOT NULL, signature_valid boolean NOT NULL,
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received','processed','rejected','dead')),
  result jsonb, error_code text,
  received_at timestamptz NOT NULL DEFAULT now(), processed_at timestamptz,
  CONSTRAINT uq_inbox_idem UNIQUE (tenant_id, source, idempotency_key)
);

-- AnnexeIF_Interfaces#1
CREATE TABLE keystone.integration_mappings (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  target keystone.integration_target NOT NULL,
  object_type text NOT NULL, keystone_id uuid NOT NULL, external_id text NOT NULL,
  external_version bigint,
  CONSTRAINT uq_mapping_k UNIQUE (tenant_id, target, object_type, keystone_id),
  CONSTRAINT uq_mapping_x UNIQUE (tenant_id, target, object_type, external_id)
);

-- AnnexeIF_Interfaces#2
CREATE TYPE keystone.payment_purpose AS ENUM ('parking','occupant_fee','deposit');

-- AnnexeIF_Interfaces#2
-- deposit : dépôts et acomptes (D08)
CREATE TYPE keystone.payment_status  AS ENUM ('created','pending','accepted','refused','cancelled','expired','error');

-- AnnexeIF_Interfaces#2
CREATE TABLE keystone.payment_handlers (
  object_type text PRIMARY KEY CHECK (object_type ~ '^[a-z_]{3,40}$'),
  purpose keystone.payment_purpose NOT NULL,
  owner_annex text NOT NULL,
  prepare_fn regprocedure NOT NULL,       -- (p_object_type text, p_object_id uuid) RETURNS jsonb :
                                          --   { "amount", "currency", "site_id", "legal_entity_id", "payer", "beneficiary",
                                          --     "description", "vat_rate", "vat_applicable", "object_ref" } ;
                                          --   lève l'erreur métier par raise_error si l'objet n'est pas payable
  on_accepted_fn regprocedure NOT NULL,   -- (p_intent uuid) RETURNS void : effet métier
  on_failed_fn regprocedure NOT NULL,     -- (p_intent uuid, p_status keystone.payment_status) RETURNS void
  revenue_key text NOT NULL,              -- clé de recette convertie par Atlas FNA (IF.3.1)
  enabled boolean NOT NULL DEFAULT true
);

-- AnnexeIF_Interfaces#3
CREATE TYPE keystone.payment_request_status AS ENUM ('open','paid','cancelled','expired');

-- AnnexeF_SoftFM#1
CREATE TABLE keystone.service_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, code text NOT NULL, label text NOT NULL,
  family text NOT NULL CHECK (family IN ('cleaning','green_spaces','pest_control','hygiene')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_service_type UNIQUE (tenant_id, code) );

-- AnnexeF_SoftFM#3
CREATE TABLE keystone.qc_elements (
  tenant_id uuid NOT NULL, code text NOT NULL, label text NOT NULL,
  family text NOT NULL DEFAULT 'cleaning' CHECK (family IN ('cleaning','green_spaces','pest_control','hygiene')),   -- famille de service_types
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (tenant_id, code) );

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.access_direction   AS ENUM ('in','out','denied');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.access_method      AS ENUM ('badge','qr','plate','manual');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.access_right_status AS ENUM ('pending','active','suspended','revoked','expired');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.access_right_origin AS ENUM ('position','visit','fitout','delivery','parking','contractor');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.patrol_status      AS ENUM ('planned','in_progress','completed','incomplete','missed');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.video_req_status   AS ENUM ('requested','approved','extracted','delivered','refused');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.security_severity  AS ENUM ('info','minor','major','critical');

-- AnnexeU_Surete_Accueil#1
-- Information, Mineur, Majeur, Critique
CREATE TYPE keystone.visit_status       AS ENUM ('expected','checked_in','checked_out','cancelled','no_show');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.id_doc_type        AS ENUM ('national_id','passport','residence_permit','driving_licence','professional_card','other');

-- AnnexeU_Surete_Accueil#1
CREATE TYPE keystone.parcel_status      AS ENUM ('received','notified','delivered','returned');

-- AnnexeU_Surete_Accueil#6
CREATE TABLE keystone.security_log_types (
  tenant_id uuid NOT NULL, code text NOT NULL, label text NOT NULL, default_severity keystone.security_severity NOT NULL,
  is_active boolean NOT NULL DEFAULT true, PRIMARY KEY (tenant_id, code) );

-- AnnexeU_Surete_Accueil#6
CREATE TABLE keystone.security_posts (
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  code text NOT NULL, label text NOT NULL, equipment jsonb NOT NULL DEFAULT '[]',   -- liste des clés et matériels du poste
  is_active boolean NOT NULL DEFAULT true, PRIMARY KEY (tenant_id, site_id, code) );

-- AnnexeU_Surete_Accueil#6
ALTER TABLE keystone.security_posts ADD CONSTRAINT ck_post_equipment
  CHECK (jsonb_matches_schema(keystone.json_schema('post_equipment/v1'), equipment));

-- AnnexeU_Surete_Accueil#10
CREATE TABLE keystone.reception_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  at timestamptz NOT NULL DEFAULT now(), kind text NOT NULL, note text NOT NULL, handled_by uuid NOT NULL );

-- AnnexeU_Surete_Accueil_Partie2#1
CREATE TYPE keystone.security_event_kind AS ENUM
  ('ppe_missing','intrusion','restricted_zone_entry','crowding','loitering','abandoned_object',
   'forced_door','door_held_open','perimeter_breach','tamper','technical_alarm','other');

-- AnnexeU_Surete_Accueil_Partie2#1
CREATE TYPE keystone.security_event_source AS ENUM ('vision','intrusion_system','access_control','iot','manual');

-- AnnexeU_Surete_Accueil_Partie2#1
CREATE TYPE keystone.security_event_status AS ENUM ('new','acknowledged','confirmed','false_positive','closed');

-- AnnexeU_Surete_Accueil_Partie2#2
CREATE TYPE keystone.crisis_scenario AS ENUM
  ('bomb_threat','intrusion','civil_unrest','power_outage','flood','cyber_attack','epidemic','chemical_spill','other');

-- AnnexeU_Surete_Accueil_Partie2#2
CREATE TYPE keystone.crisis_drill_format AS ENUM ('tabletop','functional','full_scale');

-- AnnexeU_Surete_Accueil_Partie2#2
-- ISO 22398:2013
CREATE TYPE keystone.crisis_drill_status AS ENUM ('planned','done','analysed','cancelled');

-- AnnexePK_Parking#1
CREATE TYPE keystone.parking_zone_kind    AS ENUM ('public','staff','reserved','pmr','loading');

-- AnnexePK_Parking#1
CREATE TYPE keystone.parking_space_status AS ENUM ('free','occupied','reserved','out_of_service');

-- AnnexePK_Parking#1
CREATE TYPE keystone.parking_sub_status   AS ENUM ('pending_payment','active','suspended','expired','cancelled');

-- AnnexePK_Parking#1
CREATE TYPE keystone.parking_session_status AS ENUM ('open','closed_unpaid','paid','closed_free','disputed');

-- AnnexePK_Parking#1
CREATE TYPE keystone.parking_resa_status  AS ENUM ('pending_payment','confirmed','checked_in','completed','no_show','cancelled');

-- AnnexePK_Parking#1
CREATE TYPE keystone.parking_violation_kind AS ENUM ('pmr_misuse','overstay','no_right','reserved_misuse','other');

-- AnnexePK_Parking#2
-- RG-PK-01
-- trigger : nombre de places actives de la zone <= capacity (PARKING_CAPACITY_EXCEEDED)

CREATE TABLE keystone.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  plate_normalized text NOT NULL CHECK (plate_normalized ~ '^[A-Z0-9]{4,12}$'),   -- sans espace ni tiret
  plate_display text NOT NULL,
  owner_kind text NOT NULL CHECK (owner_kind IN ('person','occupant_org','vendor','visitor')),
  owner_id uuid NOT NULL, vehicle_type text NOT NULL CHECK (vehicle_type IN ('car','motorbike','van','truck')),
  badge text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_vehicle UNIQUE (tenant_id, plate_normalized) );

-- AnnexePK_Parking#4
CREATE TABLE keystone.parking_tariffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, code text NOT NULL, label text NOT NULL,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  free_minutes int NOT NULL DEFAULT 0 CHECK (free_minutes >= 0),
  daily_cap bigint CHECK (daily_cap >= 0 AND daily_cap % 5 = 0),
  lost_ticket_fee bigint CHECK (lost_ticket_fee >= 0 AND lost_ticket_fee % 5 = 0),
  valid_from date NOT NULL, valid_to date, is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_parking_tariff UNIQUE (tenant_id, site_id, code, valid_from) );

-- AnnexePK_Parking#4
CREATE TABLE keystone.parking_tariff_bands (
  tariff_id uuid NOT NULL REFERENCES keystone.parking_tariffs(id) ON DELETE CASCADE,
  from_minute int NOT NULL CHECK (from_minute >= 0), to_minute int,          -- NULL = sans borne
  step_minutes int NOT NULL CHECK (step_minutes > 0),
  step_amount bigint NOT NULL CHECK (step_amount >= 0 AND step_amount % 5 = 0),
  PRIMARY KEY (tariff_id, from_minute),
  CONSTRAINT ck_band CHECK (to_minute IS NULL OR to_minute > from_minute) );

-- AnnexePK_Parking#4
CREATE TABLE keystone.parking_subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, code text NOT NULL, label text NOT NULL,
  zone_ids uuid[] NOT NULL, period_kind text NOT NULL CHECK (period_kind IN ('month','quarter','year')),
  price bigint NOT NULL CHECK (price >= 0 AND price % 5 = 0), currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  with_assigned_space boolean NOT NULL DEFAULT false, audience text[] NOT NULL,   -- staff, occupants, public
  is_active boolean NOT NULL DEFAULT true, CONSTRAINT uq_sub_plan UNIQUE (tenant_id, site_id, code) );

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_device_status   AS ENUM ('active','offline','disabled');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_protocol        AS ENUM ('mqtt','http','modbus','lorawan','bacnet');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_gateway_mode    AS ENUM ('local_connector','remote_endpoint');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_gateway_status  AS ENUM ('configured','connected','disconnected','disabled');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_point_status    AS ENUM ('mapped','unmapped','quarantined');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_alert_kind      AS ENUM ('threshold','device_offline','gateway_disconnected','meter_rejected');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_alert_status    AS ENUM ('open','acknowledged','resolved');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_threshold_action AS ENUM ('alert','conditional_wo');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_schedule        AS ENUM ('always','open_hours','closed_hours');

-- AnnexeI_IoT#1
CREATE TYPE keystone.iot_owner           AS ENUM ('tenant','client');

-- AnnexeI_IoT#2
CREATE TABLE keystone.iot_gateways (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  code text NOT NULL, label text NOT NULL,
  protocol iot_protocol NOT NULL,
  mode iot_gateway_mode NOT NULL,
  poll_interval_s int NOT NULL DEFAULT 60 CHECK (poll_interval_s BETWEEN 5 AND 3600),
  status iot_gateway_status NOT NULL DEFAULT 'configured',
  is_read_only boolean NOT NULL DEFAULT true CHECK (is_read_only),   -- A55
  connector_key_hash text,                          -- hachage argon2id, la clé n'est affichée qu'une fois
  key_created_at timestamptz, key_revoked_at timestamptz,
  last_sync_at timestamptz,
  owner iot_owner NOT NULL DEFAULT 'tenant',
  client_consent_document_id uuid REFERENCES keystone.ged_documents(id),   -- accord écrit du client
  disabled_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_gateway_code UNIQUE (tenant_id, code),
  CONSTRAINT ck_gw_disabled CHECK (status <> 'disabled' OR disabled_reason IS NOT NULL),
  CONSTRAINT ck_gw_consent CHECK (owner <> 'client' OR client_consent_document_id IS NOT NULL)
);

-- AnnexeI_IoT#2
CREATE TABLE keystone.iot_gateway_logs (
  id bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id uuid NOT NULL,
  gateway_id uuid NOT NULL,
  at timestamptz NOT NULL DEFAULT now(),
  event text NOT NULL CHECK (event IN ('connected','disconnected','read_error','unknown_point',
                                       'unit_mismatch','key_rejected','command_refused')),
  point_ref text, cause text,
  PRIMARY KEY (tenant_id, at, id)
) PARTITION BY RANGE (at);

-- AnnexeI_IoT#4
CREATE TABLE keystone.iot_readings (
  id bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id uuid NOT NULL,
  device_id uuid NOT NULL,
  metric text NOT NULL,
  value numeric(18,6) NOT NULL,
  unit text NOT NULL,
  at timestamptz NOT NULL,                          -- horodatage de mesure, UTC (RG-TEL-04)
  received_at timestamptz NOT NULL DEFAULT now(),   -- latence d'ingestion
  source text NOT NULL CHECK (source IN ('device','gateway')),
  quality text NOT NULL DEFAULT 'good' CHECK (quality IN ('good','suspect')),
  PRIMARY KEY (tenant_id, at, id)
) PARTITION BY RANGE (at);

-- AnnexeI_IoT#4
-- partition mensuelle
CREATE UNIQUE INDEX uq_reading_dedup ON keystone.iot_readings (tenant_id, device_id, metric, at);

-- AnnexeI_IoT#4
CREATE INDEX ix_readings_device ON keystone.iot_readings (tenant_id, device_id, metric, at DESC);

-- AnnexeI_IoT#4
CREATE TABLE keystone.iot_readings_hourly (
  tenant_id uuid NOT NULL, device_id uuid NOT NULL, metric text NOT NULL, unit text NOT NULL,
  hour timestamptz NOT NULL CHECK (date_trunc('hour', hour) = hour),
  min_value numeric(18,6), max_value numeric(18,6), avg_value numeric(18,6),
  last_value numeric(18,6),                         -- dernier index, pour les compteurs
  sample_count int NOT NULL, expected_count int NOT NULL,
  PRIMARY KEY (tenant_id, device_id, metric, unit, hour)   -- série : capteur, métrique, unité (RG-TEL-05)
) PARTITION BY RANGE (hour);

-- AnnexeI_IoT#4
CREATE TABLE keystone.iot_readings_daily (
  tenant_id uuid NOT NULL, device_id uuid NOT NULL, metric text NOT NULL, unit text NOT NULL,
  day date NOT NULL,                                -- jour dans le fuseau du site
  min_value numeric(18,6), max_value numeric(18,6), avg_value numeric(18,6), last_value numeric(18,6),
  sample_count int NOT NULL, expected_count int NOT NULL,
  PRIMARY KEY (tenant_id, device_id, metric, unit, day)
) PARTITION BY RANGE (day);

-- AnnexeI_IoT#5
CREATE TABLE keystone.telemetry_dashboards (             -- tableaux de télémétrie enregistrés (Lot 12 §30)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  owner_user_id uuid NOT NULL,
  name text NOT NULL,
  panels jsonb NOT NULL,                            -- [{device_id, metric, window, overlay_thresholds, x, y, w, h}], 12 au plus
  is_shared boolean NOT NULL DEFAULT false,         -- partagé au tenant : iot.manage
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT ck_tel_panels CHECK (jsonb_array_length(panels) BETWEEN 1 AND 12)
);

-- AnnexeI_IoT#5
CREATE UNIQUE INDEX uq_tel_dash_name ON keystone.telemetry_dashboards (tenant_id, owner_user_id, lower(name)) WHERE deleted_at IS NULL;

-- AnnexeEN_Energie#1
CREATE TYPE keystone.energy_fluid        AS ENUM ('electricity','water','natural_gas','lpg','diesel','chilled_water','other');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.energy_use_kind     AS ENUM ('hvac','lighting','refrigeration','vertical_transport','pumping',
                                         'common_areas','occupant','it','backup_generation','irrigation','other');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.normalization_var   AS ENUM ('cdd','hdd','footfall','occupancy','opening_hours','surface','custom');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.baseline_model      AS ENUM ('ratio','linear_regression','multivariate_regression');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.baseline_status     AS ENUM ('draft','approved','superseded');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.energy_review_status AS ENUM ('draft','in_review','approved');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.energy_target_status AS ENUM ('draft','active','achieved','missed','cancelled');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.energy_action_status AS ENUM ('planned','in_progress','done','verified','cancelled');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.energy_anomaly_status AS ENUM ('detected','in_analysis','confirmed','treated','dismissed');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.leak_alert_status   AS ENUM ('open','confirmed','dismissed','resolved');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.energy_invoice_status AS ENUM ('received','matched','gap_detected','approved','rejected');

-- AnnexeEN_Energie#1
CREATE TYPE keystone.rebilling_status    AS ENUM ('draft','validated','published','cancelled');

-- AnnexeEN_Energie#2
CREATE TABLE keystone.energy_scopes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  boundaries text NOT NULL,                         -- bâtiments, fluides, exclusions motivées (§4.3)
  exclusions text,
  policy_document_id uuid REFERENCES keystone.ged_documents(id),   -- politique énergétique (§5.2)
  energy_team jsonb NOT NULL DEFAULT '[]',          -- [{person_id, role}] (§5.3)
  valid_from date NOT NULL, valid_to date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_energy_scope UNIQUE (tenant_id, site_id, valid_from)   -- garde d'écriture : ENERGY_SCOPE_DUPLICATE
);

-- AnnexeEN_Energie#2
-- Lue par l'onglet Arrosage de Soft FM (Lot 15 SFM-EV) et par KPI-SFM-06 (référentiel KPI partie 2) ;
--   aucun compteur relié : état vide « Aucun compteur d'arrosage relié ».

CREATE TABLE keystone.energy_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  period_start date NOT NULL, period_end date NOT NULL,
  status energy_review_status NOT NULL DEFAULT 'draft',
  analysis jsonb NOT NULL DEFAULT '{}',             -- consommation par fluide et usage, tendances (calculées)
  significance_criteria text NOT NULL,              -- critère retenu, ex. usages couvrant 80 % de la consommation
  approved_by uuid, approved_at timestamptz,
  report_document_id uuid REFERENCES keystone.ged_documents(id),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_review_period CHECK (period_end > period_start),
  CONSTRAINT uq_energy_review UNIQUE (tenant_id, site_id, period_start)
);

-- AnnexeEN_Energie#3
CREATE TABLE keystone.normalization_factors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  variable normalization_var NOT NULL,
  custom_code text,                                  -- si variable = 'custom'
  period_month date NOT NULL CHECK (date_trunc('month', period_month) = period_month),
  value numeric(18,4) NOT NULL CHECK (value >= 0),
  unit text NOT NULL,                                -- 'DJ base 18 °C', 'visiteurs', 'h', 'm2'
  base_temperature_c numeric(4,1),                   -- pour cdd et hdd ; défaut 18,0, valeur par défaut, à confirmer
  source text NOT NULL CHECK (source IN ('manual','import','weather_service','space_module','counting_system')),
  source_ref text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_norm_factor UNIQUE NULLS NOT DISTINCT (tenant_id, site_id, variable, custom_code, period_month)
);

-- AnnexeEN_Energie#4
-- Trigger de validation au passage du tarif en vigueur : tranches contiguës, la première à 0,
-- une seule tranche ouverte ; sinon TRANCHE_GAP.

CREATE TABLE keystone.emission_factors (           -- définition unique du corpus (N2) ; l'Annexe K la lit
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,   -- NULL : valeur éditeur
  category text NOT NULL,                            -- énergie : nom du fluide ; fluide frigorigène : 'refrigerant:<code>' ; Annexe K : process, waste, travel...
  fluid keystone.energy_fluid,                       -- renseigné pour les facteurs énergie
  scope int CHECK (scope IN (1,2,3)),                -- périmètre ISO 14064-1 par défaut de la catégorie
  country_code char(2) NOT NULL,
  activity_unit text NOT NULL,                       -- 'kWh', 'l', 'm3', 'kg'
  kg_co2e_per_unit numeric(14,6) NOT NULL CHECK (kg_co2e_per_unit >= 0),
  source text NOT NULL, source_date date NOT NULL,   -- RG-ENE-06
  valid_from date NOT NULL, valid_to date,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_emission_factor UNIQUE NULLS NOT DISTINCT (tenant_id, category, country_code, valid_from),
  CONSTRAINT ck_ef_fluid CHECK (fluid IS NULL OR category = fluid::text),
  CONSTRAINT ck_ef_dates CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT ck_ef_refrigerant CHECK (category NOT LIKE 'refrigerant:%'
    OR (category ~ '^refrigerant:R-[0-9A-Z]{2,6}$' AND activity_unit = 'kg' AND fluid IS NULL AND scope = 1))
);

-- AnnexeEN_Energie#4
-- NC-12-06 : un facteur énergie par fluide, pays et date de début (écran Facteurs, Lot 12 §25)
CREATE UNIQUE INDEX uq_emission_factor_fluid ON keystone.emission_factors
  (COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid), fluid, country_code, valid_from)
  WHERE fluid IS NOT NULL;

-- AnnexeEN_Energie#8
CREATE TABLE keystone.energy_rebilling_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  period_month date NOT NULL CHECK (date_trunc('month', period_month) = period_month),
  target text NOT NULL CHECK (target IN ('atlas_patrimoine','atlas_trade')),
  status rebilling_status NOT NULL DEFAULT 'draft',
  validated_by uuid, validated_at timestamptz, published_at timestamptz,
  external_ref text,                                 -- accusé de réception de l'application cible
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_rebilling UNIQUE (tenant_id, site_id, period_month, target)
);

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.report_cadence      AS ENUM ('daily','weekly','monthly','quarterly','yearly');

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.report_format       AS ENUM ('pdf','xlsx');

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.report_run_status   AS ENUM ('planned','generated','draft','validated','distributed','failed');

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.stakeholder_category AS ENUM ('occupants','client','owner','authority','vendors','staff',
                                          'neighbourhood','insurer','other');

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.requirement_source  AS ENUM ('contract','regulation','sla','policy','expectation');

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.fm_objective_status AS ENUM ('draft','active','achieved','missed','cancelled');

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.fm_review_status       AS ENUM ('planned','in_preparation','held','minutes_approved');

-- AnnexeQ_Reporting#1
CREATE TYPE keystone.review_input_code   AS ENUM (
  'previous_actions_status',          -- a) état des actions des revues précédentes
  'issues_changes',                   -- b) changements des enjeux externes et internes (§4.1)
  'stakeholder_needs_changes',        -- changements des besoins et attentes des parties intéressées (§4.2)
  'fm_performance',                   -- c) performance FM : non-conformités et actions correctives, résultats de
                                      --    surveillance et de mesure, résultats d'audit, atteinte des objectifs
  'stakeholder_feedback',             -- retours des parties intéressées (satisfaction, réclamations)
  'resources_adequacy',               -- adéquation des ressources
  'risks_opportunities_effectiveness',-- efficacité des actions face aux risques et opportunités (§6.1)
  'improvement_opportunities',        -- d) opportunités d'amélioration continue
  'energy_performance');

-- AnnexeQ_Reporting#1
-- si le site porte un périmètre énergie (ISO 50001:2018 §9.3)
CREATE TYPE keystone.review_output_kind  AS ENUM ('improvement_opportunity','fm_system_change','resource_need',
                                         'objective_action','other_decision');

-- AnnexeQ_Reporting#2
CREATE TABLE keystone.dashboard_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  owner_user_id uuid,                               -- NULL : tableau partagé
  name text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('control_tower','maintenance','hsse','service','costs','energy',
                                     'purchasing','client','purpose','custom')),
  role_codes text[] NOT NULL DEFAULT '{}',          -- rôles dont la bibliothèque propose ce tableau, ordre d'affichage
  layout jsonb NOT NULL,                            -- [{kpi_code, widget, x, y, w, h, breakdown, compare, sparkline}]
  scope jsonb NOT NULL DEFAULT '{}',                -- {site_ids, client_id, period}
  refresh_seconds int NOT NULL DEFAULT 300 CHECK (refresh_seconds BETWEEN 30 AND 3600),   -- RG-TDC-03
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeQ_Reporting#2
CREATE UNIQUE INDEX uq_dashboard_default ON keystone.dashboard_configs (tenant_id, kind) WHERE is_default AND owner_user_id IS NULL;

-- AnnexeQ_Reporting#2
CREATE UNIQUE INDEX uq_dashboard_name_owner ON keystone.dashboard_configs (tenant_id, owner_user_id, lower(name))
  WHERE owner_user_id IS NOT NULL AND deleted_at IS NULL;

-- AnnexeQ_Reporting#2
CREATE UNIQUE INDEX uq_dashboard_name_shared ON keystone.dashboard_configs (tenant_id, lower(name))
  WHERE owner_user_id IS NULL AND deleted_at IS NULL;

-- AnnexeQ_Reporting#3
CREATE TABLE keystone.report_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,   -- NULL : modèle éditeur
  code text NOT NULL, version int NOT NULL DEFAULT 1,
  name text NOT NULL,
  domain text NOT NULL CHECK (domain IN ('maintenance','hsse','service','costs','energy','contract',
                                         'management_review','energy_review','executive')),
  sections jsonb NOT NULL,                          -- [{title, kpi_codes[], tables[], commentary_required}]
  client_compatible boolean NOT NULL DEFAULT false,   -- sans marge, coût interne, sous-traitant (RG-RAP-03)
  requires_review boolean NOT NULL DEFAULT false,
  author_mention text,                              -- mention d'auteur de la charte du tenant (RG-RAP-06)
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','retired')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT uq_report_template UNIQUE NULLS NOT DISTINCT (tenant_id, code, version)
);

-- AnnexeQ_Reporting#3
-- Trigger tg_template_client_check : client_compatible = true refusé si une section cite une famille
-- MRG, un KPI COU ou une table de coûts internes (TEMPLATE_NOT_CLIENT_SAFE).

CREATE TABLE keystone.report_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  template_id uuid NOT NULL REFERENCES keystone.report_templates(id),
  name text NOT NULL,
  cadence report_cadence NOT NULL,
  run_day int,                                      -- jour du mois ou de la semaine selon la cadence
  due_offset_days int NOT NULL DEFAULT 5,           -- échéance de diffusion après la fin de période
  scope jsonb NOT NULL,                             -- {site_ids, client_id}
  recipients uuid[] NOT NULL,                       -- utilisateurs internes
  format report_format NOT NULL DEFAULT 'pdf',
  owner_id uuid NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  next_run_at timestamptz, last_run_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeQ_Reporting#4
CREATE TABLE keystone.fm_context_issues (            -- §4.1
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid REFERENCES atlas_core.sites(id),        -- NULL : enjeu de l'organisation
  kind text NOT NULL CHECK (kind IN ('external','internal')),
  topic text NOT NULL CHECK (topic IN ('regulatory','economic','climate','technology','social','market',
                                       'organisation','resources','assets','other')),
  description text NOT NULL,
  effect text NOT NULL,                              -- effet sur la capacité à atteindre les résultats FM
  risk_or_opportunity text CHECK (risk_or_opportunity IN ('risk','opportunity','both')),
  risk_register_id uuid,                             -- registre des risques ISO 31000 (Annexe C, D12, D28) si risque
  review_due date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeQ_Reporting#4
CREATE TABLE keystone.fm_policies (                  -- §4.3 domaine, §5.2 politique
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  scope_statement text NOT NULL,                     -- domaine d'application du système FM
  policy_document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),   -- série QUA
  approved_by uuid NOT NULL, approved_at timestamptz NOT NULL,
  valid_from date NOT NULL, valid_to date,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeQ_Reporting#4
CREATE TABLE keystone.fm_objectives (                -- §6.2
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  code text NOT NULL, title text NOT NULL,
  site_id uuid REFERENCES atlas_core.sites(id),
  purpose text CHECK (purpose IN ('performance','occupant_experience','continuity','anticipation','costs')),
  kpi_code text NOT NULL,                            -- mesure de l'objectif (§6.2 : évaluation des résultats)
  baseline_value numeric, target_value numeric NOT NULL,
  due_date date NOT NULL,
  owner_id uuid NOT NULL,                            -- responsable
  resources text NOT NULL,                           -- ressources requises
  status fm_objective_status NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_fm_objective UNIQUE (tenant_id, code)
);

-- AnnexeQ_Reporting#4
CREATE TABLE keystone.fm_objective_actions (         -- §6.2 : ce qui sera fait
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  objective_id uuid NOT NULL REFERENCES keystone.fm_objectives(id) ON DELETE CASCADE,
  title text NOT NULL, owner_id uuid NOT NULL, due_date date NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','done','cancelled')),
  linked_table text, linked_id uuid                  -- OT, CAPA, energy_actions, projet
);

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.survey_kind       AS ENUM ('csat','nps','barometer');

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.survey_status     AS ENUM ('draft','active','closed');

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.survey_trigger    AS ENUM ('ticket_closure','campaign');

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.survey_channel    AS ENUM ('portal','email');

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.followup_status   AS ENUM ('to_handle','in_progress','handled');

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.headcount_status  AS ENUM ('declared','validated','rejected');

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.headcount_source  AS ENUM ('manual','import','occupant_portal','atlas_people');

-- AnnexeN_Satisfaction_Cout#1
CREATE TYPE keystone.cost_period_status AS ENUM ('open','closed');

-- AnnexeN_Satisfaction_Cout#2
CREATE TABLE keystone.surveys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  code text NOT NULL, title text NOT NULL,
  kind survey_kind NOT NULL,
  trigger survey_trigger NOT NULL,
  status survey_status NOT NULL DEFAULT 'draft',
  site_ids uuid[] NOT NULL DEFAULT '{}',            -- vide : tous les sites du périmètre
  ticket_categories text[],                         -- CSAT : catégories concernées, NULL : toutes
  low_score_threshold int NOT NULL DEFAULT 2,       -- note basse : inférieure ou égale au seuil
  significance_min int NOT NULL DEFAULT 10,         -- RG-SAT-04
  invitation_ttl_days int NOT NULL DEFAULT 14 CHECK (invitation_ttl_days BETWEEN 1 AND 90),
  campaign_cadence text CHECK (campaign_cadence IN ('quarterly','half_yearly','yearly')),
  opens_at timestamptz, closes_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_survey_code UNIQUE (tenant_id, code),
  CONSTRAINT ck_survey_trigger CHECK ((kind = 'csat') = (trigger = 'ticket_closure')),
  CONSTRAINT ck_survey_campaign CHECK (trigger <> 'campaign' OR campaign_cadence IS NOT NULL)
);

-- AnnexeN_Satisfaction_Cout#2
CREATE UNIQUE INDEX uq_survey_csat_active ON keystone.surveys (tenant_id) WHERE kind = 'csat' AND status = 'active'
  AND ticket_categories IS NULL;

-- AnnexeN_Satisfaction_Cout#2
CREATE TABLE keystone.survey_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  survey_id uuid NOT NULL REFERENCES keystone.surveys(id) ON DELETE CASCADE,
  rank int NOT NULL,
  label text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('score','text','choice')),
  scale_min int, scale_max int,                     -- csat 1 à 5, nps 0 à 10
  choices jsonb,
  is_main boolean NOT NULL DEFAULT false,           -- question qui porte la note de l'indicateur
  is_required boolean NOT NULL DEFAULT false,
  CONSTRAINT uq_question_rank UNIQUE (tenant_id, survey_id, rank),
  CONSTRAINT ck_question_scale CHECK (kind <> 'score' OR (scale_min IS NOT NULL AND scale_max > scale_min))
);

-- AnnexeN_Satisfaction_Cout#2
CREATE UNIQUE INDEX uq_question_main ON keystone.survey_questions (tenant_id, survey_id) WHERE is_main;

-- AnnexeN_Satisfaction_Cout#4
CREATE TABLE keystone.occupant_headcount (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  space_unit_id uuid REFERENCES atlas_core.spaces(id),      -- référentiel des espaces (D04, Annexe S)
  occupant_org_id uuid,                                        -- organisation occupante (Annexe S)
  period_month date NOT NULL CHECK (date_trunc('month', period_month) = period_month),
  headcount int NOT NULL CHECK (headcount >= 0),
  source headcount_source NOT NULL,
  status headcount_status NOT NULL DEFAULT 'declared',
  over_capacity boolean NOT NULL DEFAULT false,               -- headcount supérieur à la capacité de l'espace (Annexe S)
  declared_by uuid NOT NULL, declared_at timestamptz NOT NULL DEFAULT now(),
  validated_by uuid, validated_at timestamptz, rejection_reason text,
  import_batch_id uuid,                                        -- import_batches (Annexe A, A48)
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_hc_target CHECK (space_unit_id IS NOT NULL OR occupant_org_id IS NOT NULL),
  CONSTRAINT ck_hc_reject CHECK (status <> 'rejected' OR rejection_reason IS NOT NULL),
  CONSTRAINT uq_headcount UNIQUE NULLS NOT DISTINCT (tenant_id, site_id, space_unit_id, occupant_org_id, period_month)
);

-- AnnexeN_Satisfaction_Cout#4
CREATE INDEX ix_headcount_period ON keystone.occupant_headcount (tenant_id, site_id, period_month);

-- AnnexeN_Satisfaction_Cout#5
CREATE TABLE keystone.fm_cost_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  period_month date NOT NULL CHECK (date_trunc('month', period_month) = period_month),
  status cost_period_status NOT NULL DEFAULT 'open',
  operating_cost bigint, currency char(3),          -- figé à la clôture (KPI-COU-01, numérateur)
  reference_area_m2 numeric(14,2),                  -- IPMS 3 figée (D18)
  avg_headcount numeric(12,2),
  expenses_without_site int NOT NULL DEFAULT 0,     -- KPI-COU-06 à la clôture
  closed_by uuid, closed_at timestamptz,
  revision int NOT NULL DEFAULT 0,
  CONSTRAINT uq_cost_period UNIQUE (tenant_id, site_id, period_month),
  CONSTRAINT ck_cp_closed CHECK (status <> 'closed' OR (closed_by IS NOT NULL AND operating_cost IS NOT NULL AND currency IS NOT NULL))
);

-- AnnexeW_Workspace_AdHoc#1
CREATE TABLE keystone.user_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,                            -- auth.uid()
  profile_id uuid,                                  -- profil actif (Admin, user_profiles) ; NULL : tous profils
  key text NOT NULL CHECK (key ~ '^[a-z_]+(\.[a-z0-9_]+){1,3}$'),
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_pref UNIQUE NULLS NOT DISTINCT (tenant_id, user_id, profile_id, key),
  CONSTRAINT ck_pref_size CHECK (pg_column_size(value) <= 8192)
);

-- AnnexeW_Workspace_AdHoc#1
ALTER TABLE keystone.user_preferences ENABLE ROW LEVEL SECURITY;

-- AnnexeW_Workspace_AdHoc#1
CREATE POLICY user_pref_own ON keystone.user_preferences FOR ALL
  USING (tenant_id = keystone.current_tenant() AND user_id = auth.uid())
  WITH CHECK (tenant_id = keystone.current_tenant() AND user_id = auth.uid());

-- AnnexeW_Workspace_AdHoc#3
CREATE TYPE keystone.record_origin AS ENUM ('planned','ad_hoc','flash','hoc');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.ai_capability   AS ENUM ('predictive','anomaly','risk_narration','copilot','generation',
                                     'forecast','optimization','vision','transcription');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.ai_provider     AS ENUM ('ollama_local','claude_api');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.ai_data_class   AS ENUM ('public','internal','personal','health','victim_identity','financial');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.ai_model_status AS ENUM ('candidate','approved','deployed','retired');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.agent_code      AS ENUM ('sentinelle','relanceur_capa','auditeur','habilitations','veille_reglementaire',
                                     'reporting','coordinateur_crise','echeancier_crp','previsionniste_budget');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.agent_decision  AS ENUM ('auto','proposed','escalated','blocked');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.human_decision  AS ENUM ('accepted','modified','rejected','expired');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.prediction_status AS ENUM ('proposed','accepted','dismissed','expired');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.prediction_outcome AS ENUM ('confirmed','false_alarm','inconclusive');

-- AnnexeH_PROPH3T_Agents#1
CREATE TYPE keystone.anomaly_status  AS ENUM ('open','acknowledged','resolved','false_positive');

-- AnnexeH_PROPH3T_Agents#2
CREATE TABLE keystone.ai_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL, version text NOT NULL,       -- prd-rul, 1.4.0
  capability ai_capability NOT NULL,
  provider ai_provider NOT NULL,
  kind text NOT NULL CHECK (kind IN ('statistical','language','vision','optimization')),
  intended_use text NOT NULL, limitations text NOT NULL,
  training_data_summary text NOT NULL,             -- origine, période, exclusions
  impact_assessment_document_id uuid,              -- référence logique sans clé : document de l'éditeur, hors GED d'un tenant (ISO/IEC 42001:2023 §6.1.4)
  status ai_model_status NOT NULL DEFAULT 'candidate',
  approved_by uuid, approved_at timestamptz, deployed_at timestamptz, retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ai_model UNIQUE (code, version),
  CONSTRAINT ck_model_claude CHECK (provider <> 'claude_api' OR capability = 'vision'),  -- I04
  CONSTRAINT ck_model_transcription CHECK (capability <> 'transcription' OR provider = 'ollama_local')
);

-- AnnexeH_PROPH3T_Agents#3
CREATE TABLE keystone.ai_data_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  capability ai_capability NOT NULL,
  data_class ai_data_class NOT NULL,
  allowed_provider ai_provider NOT NULL,
  enabled_by uuid NOT NULL, enabled_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ai_route UNIQUE (tenant_id, capability, data_class, allowed_provider),
  CONSTRAINT ck_route_sensitive CHECK (data_class NOT IN ('health','victim_identity') OR allowed_provider = 'ollama_local'),
  CONSTRAINT ck_route_claude CHECK (allowed_provider <> 'claude_api' OR capability = 'vision')
);

-- AnnexeH_PROPH3T_Agents#4
CREATE TABLE keystone.agent_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  agent agent_code NOT NULL,
  is_enabled boolean NOT NULL DEFAULT false,
  service_user_id uuid NOT NULL,                   -- compte de service à droits minimaux, jamais service_role
  auto_actions text[] NOT NULL,                    -- liste blanche (H.4.1)
  hourly_action_budget int NOT NULL DEFAULT 50 CHECK (hourly_action_budget BETWEEN 1 AND 1000),
  proposal_ttl_hours int NOT NULL DEFAULT 168 CHECK (proposal_ttl_hours > 0),   -- au delà : expired
  model_id uuid REFERENCES keystone.ai_models(id),
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT uq_agent_def UNIQUE (tenant_id, agent)
);

-- AnnexeH_PROPH3T_Agents#4
CREATE TABLE keystone.agent_controls (
  tenant_id uuid PRIMARY KEY REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  kill_switch boolean NOT NULL DEFAULT false,      -- suspend tous les agents du tenant
  reason text, set_by uuid, set_at timestamptz,
  CONSTRAINT ck_kill_reason CHECK (NOT kill_switch OR reason IS NOT NULL)
);

-- AnnexeH_PROPH3T_Agents#5
CREATE TABLE keystone.agent_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  agent agent_code,                                -- NULL pour le copilote et la génération assistée
  capability ai_capability NOT NULL,
  model_id uuid REFERENCES keystone.ai_models(id),
  provider ai_provider NOT NULL,
  data_class ai_data_class NOT NULL,
  trigger_kind text NOT NULL CHECK (trigger_kind IN ('schedule','event','user_request')),
  trigger_ref text,
  site_id uuid REFERENCES atlas_core.sites(id),
  action_type text NOT NULL,                       -- élément de la liste blanche ou action proposée
  target_table text, target_id uuid,
  payload jsonb NOT NULL DEFAULT '{}',             -- objet proposé, jamais exécuté sans validation
  explanation jsonb NOT NULL,                      -- facteurs, graphes, raisonnement (RG-IA-04)
  sources jsonb NOT NULL DEFAULT '[]',             -- [{table, id, version}] ou [{document_id, version}]
  decision agent_decision NOT NULL,
  requires_human boolean NOT NULL,
  human_decision human_decision,
  human_decision_by uuid, human_decision_at timestamptz, human_reason text,
  executed_table text, executed_id uuid,           -- objet créé par le module, sous l'identité du validateur
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_run_explained CHECK (jsonb_typeof(explanation) = 'object' AND explanation <> '{}'::jsonb),
  CONSTRAINT ck_run_human CHECK (decision = 'auto' OR requires_human),
  CONSTRAINT ck_run_reason CHECK (human_decision IS DISTINCT FROM 'rejected' OR human_reason IS NOT NULL),
  CONSTRAINT ck_run_no_scoring CHECK (NOT (payload ?| ARRAY['severity','probability','risk_score','gravity']))
);

-- AnnexeH_PROPH3T_Agents#5
CREATE INDEX ix_runs_pending ON keystone.agent_runs (tenant_id, site_id, created_at DESC)
  WHERE requires_human AND human_decision IS NULL;

-- AnnexeH_PROPH3T_Agents#5
CREATE INDEX ix_runs_agent ON keystone.agent_runs (tenant_id, agent, created_at DESC);

-- AnnexeH_PROPH3T_Agents#5
-- Compatibilité CDC v3 §6.13 (lecture seule)
CREATE VIEW keystone.agent_actions AS
  SELECT id, tenant_id, agent::text AS agent, action_type, target_table, target_id, payload,
         decision::text AS decision, requires_human, human_decision_by, human_decision_at, created_at
  FROM keystone.agent_runs WHERE agent IS NOT NULL;

-- AnnexeH_PROPH3T_Agents#7
CREATE TABLE keystone.embeddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  source_table text NOT NULL, source_id uuid NOT NULL, source_version int,
  site_id uuid,                                    -- cloisonnement au moment de la recherche
  chunk_no int NOT NULL, content text NOT NULL,
  embedding vector(768) NOT NULL,                  -- nomic-embed-text, local
  data_class ai_data_class NOT NULL,
  indexed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_embedding UNIQUE (tenant_id, source_table, source_id, source_version, chunk_no),
  CONSTRAINT ck_embed_class CHECK (data_class NOT IN ('health','victim_identity'))
);

-- AnnexeH_PROPH3T_Agents#7
CREATE INDEX ix_embedding_vec ON keystone.embeddings USING hnsw (embedding vector_cosine_ops);

-- AnnexeH_PROPH3T_Agents#7
CREATE TABLE keystone.copilot_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL, profile_id uuid,          -- profil actif
  question text NOT NULL, answer text NOT NULL,
  sources jsonb NOT NULL DEFAULT '[]',
  agent_run_id uuid REFERENCES keystone.agent_runs(id),
  feedback text CHECK (feedback IN ('useful','not_useful','incorrect')),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#1 (proposition, lot 12)
ALTER TABLE keystone.users
  ADD COLUMN external_id    text,                    -- identifiant du compte chez le fournisseur (NameID, sub, externalId SCIM)
  ADD COLUMN provisioned_by text NOT NULL DEFAULT 'manual'
             CHECK (provisioned_by IN ('manual','sso_jit','scim'));

-- AnnexeAdmin_RBAC_Notifications_Partie4#1 (proposition, lot 12)
CREATE UNIQUE INDEX ux_users_external ON keystone.users (tenant_id, external_id) WHERE external_id IS NOT NULL AND deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications_Partie4#1 (proposition, lot 12)
-- ligne de sso_group_mappings qui a donné le rôle

CREATE TABLE keystone.sso_group_mappings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  group_ref text NOT NULL CHECK (char_length(group_ref) BETWEEN 1 AND 256),   -- nom ou identifiant du groupe reçu
  role_id uuid NOT NULL REFERENCES keystone.roles(id) ON DELETE RESTRICT,
  scope_all boolean NOT NULL DEFAULT false,          -- exige que le rôle soit compatible avec scope.all
  entity_ids uuid[] NOT NULL DEFAULT '{}',
  site_ids uuid[] NOT NULL DEFAULT '{}',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_sso_map_scope CHECK (scope_all OR cardinality(entity_ids) + cardinality(site_ids) > 0),
  CONSTRAINT uq_sso_map UNIQUE (tenant_id, group_ref, role_id)   -- garde d'écriture : SSO_GROUP_MAPPING_DUPLICATE
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#1 (proposition, lot 12)
CREATE INDEX ix_sso_map_group ON keystone.sso_group_mappings (tenant_id, lower(group_ref)) WHERE is_active AND deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications_Partie4#1 (proposition, lot 12)
ALTER TABLE keystone.sso_group_mappings ENABLE ROW LEVEL SECURITY;

-- AnnexeAdmin_RBAC_Notifications_Partie4#2 (proposition, lot 12)
CREATE TABLE keystone.scim_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  label text NOT NULL CHECK (char_length(label) BETWEEN 3 AND 60),
  token_prefix text NOT NULL CHECK (token_prefix ~ '^scim_[a-z0-9]{8}$'),   -- affiché ; le reste n'est montré qu'une fois
  token_hash bytea NOT NULL,                          -- SHA-256 du jeton complet (256 bits aléatoires)
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked','expired')),
  expires_at timestamptz NOT NULL CHECK (expires_at <= created_at + interval '12 months'),
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid NOT NULL,
  revoked_at timestamptz, revoked_by uuid, revoke_reason text,
  CONSTRAINT uq_scim_hash UNIQUE (token_hash)
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#2 (proposition, lot 12)
CREATE UNIQUE INDEX ux_scim_token_label ON keystone.scim_tokens (tenant_id, label) WHERE status = 'active';

-- AnnexeAdmin_RBAC_Notifications_Partie4#2 (proposition, lot 12)
CREATE TABLE keystone.scim_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  external_id text, display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 256),
  member_ids uuid[] NOT NULL DEFAULT '{}',            -- keystone.users.id
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT uq_scim_group UNIQUE (tenant_id, display_name)
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#2 (proposition, lot 12)
CREATE TABLE keystone.scim_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, token_id uuid REFERENCES keystone.scim_tokens(id) ON DELETE SET NULL,
  method text NOT NULL CHECK (method IN ('GET','POST','PUT','PATCH','DELETE')),
  resource text NOT NULL CHECK (resource IN ('Users','Groups','ServiceProviderConfig','ResourceTypes','Schemas')),
  resource_id uuid, http_status smallint NOT NULL, scim_type text, error_code text,
  changed_fields text[] NOT NULL DEFAULT '{}',        -- noms des attributs modifiés, jamais leurs valeurs
  at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#2 (proposition, lot 12)
CREATE INDEX ix_scim_events ON keystone.scim_events (tenant_id, at DESC);

-- AnnexeAdmin_RBAC_Notifications_Partie4#3 (proposition, lot 12)
CREATE TABLE keystone.guided_tours (                  -- catalogue de plateforme, chargé par migration depuis le Lot 19 §4
  code text PRIMARY KEY CHECK (code ~ '^[a-z][a-z0-9_]{2,40}$'),
  surface keystone.surface_code NOT NULL,
  role_codes text[] NOT NULL CHECK (cardinality(role_codes) >= 1),   -- codes de keystone.roles (Référentiels transverses §3)
  mode_scope text NOT NULL DEFAULT 'both' CHECK (mode_scope IN ('both','in_house','fm_provider')),
  version smallint NOT NULL DEFAULT 1,               -- une nouvelle version relance la visite aux comptes qui l'ont finie
  steps jsonb NOT NULL,                              -- [{"key","anchor","route","placement","requires_permission"}]
  checklist jsonb NOT NULL DEFAULT '[]',             -- [{"key","rule","route"}] : règles de §3.3
  is_active boolean NOT NULL DEFAULT true
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#4 (proposition, lot 12)
CREATE TABLE keystone.usage_event_catalog (           -- catalogue de plateforme, chargé par migration depuis le Lot 19 §8
  event_key text PRIMARY KEY CHECK (event_key ~ '^[a-z][a-z_]*\.[a-z][a-z_]*$'),   -- task.started, screen.viewed, ...
  kind text NOT NULL CHECK (kind IN ('screen','task_start','task_end','action','error')),
  screen_key text CHECK (screen_key IS NULL OR screen_key !~ '^(health|san_)'),      -- aucun écran de santé
  task_key text,                                      -- wo_quick_create_field, wo_create_console, ...
  target_seconds int CHECK (target_seconds IS NULL OR target_seconds BETWEEN 5 AND 3600),   -- objectif du parcours
  is_active boolean NOT NULL DEFAULT true
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#4 (proposition, lot 12)
CREATE TABLE keystone.usage_events (                  -- partitionnée par jour, conservation 90 jours (A56)
  tenant_id uuid NOT NULL,
  at timestamptz NOT NULL,
  session_ref uuid NOT NULL,                          -- aléatoire, navigateur, sans lien au compte
  surface keystone.surface_code NOT NULL,
  role_code text NOT NULL,                            -- rôle principal du profil, jamais l'utilisateur
  event_key text NOT NULL REFERENCES keystone.usage_event_catalog(event_key),
  task_run uuid,                                      -- relie task_start et task_end d'un même parcours
  duration_ms int CHECK (duration_ms IS NULL OR duration_ms BETWEEN 0 AND 86400000),
  outcome text CHECK (outcome IS NULL OR outcome IN ('success','error','abandoned')),
  error_code text,                                    -- code du catalogue des messages, jamais son texte
  device_class text NOT NULL CHECK (device_class IN ('mobile','tablet','desktop')),
  network text NOT NULL CHECK (network IN ('online','offline')),
  app_version text NOT NULL
) PARTITION BY RANGE (at);

-- AnnexeAdmin_RBAC_Notifications_Partie4#4 (proposition, lot 12)
CREATE TABLE keystone.usage_daily (                   -- agrégats, conservation 5 ans (A56)
  tenant_id uuid NOT NULL, day date NOT NULL, surface keystone.surface_code NOT NULL,
  role_code text NOT NULL, event_key text NOT NULL,
  sessions int NOT NULL, events int NOT NULL,
  successes int NOT NULL DEFAULT 0, errors int NOT NULL DEFAULT 0, abandons int NOT NULL DEFAULT 0,
  p50_ms int, p90_ms int, within_target int NOT NULL DEFAULT 0,
  offline_events int NOT NULL DEFAULT 0,
  PRIMARY KEY (tenant_id, day, surface, role_code, event_key)
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#4 (proposition, lot 12)
ALTER TABLE keystone.usage_daily ENABLE ROW LEVEL SECURITY;

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
CREATE TYPE keystone.api_token_status AS ENUM ('active','revoked','expired');

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
-- DUPLICATE_NAME
CREATE UNIQUE INDEX ux_service_account_name ON keystone.users (tenant_id, lower(btrim(full_name)))   -- DUPLICATE_NAME
  WHERE email LIKE 'api+%' AND deleted_at IS NULL;

-- AnnexeAP_API_Publique#2 (proposition, lot 12)
CREATE TABLE keystone.api_scopes (                    -- catalogue de plateforme
  code text PRIMARY KEY CHECK (code ~ '^[a-z_]+:(read|write)$'),
  label text NOT NULL,
  resources text[] NOT NULL,                          -- chemins couverts
  mode_scope text NOT NULL DEFAULT 'both' CHECK (mode_scope IN ('both','in_house','fm_provider'))
);

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
CREATE TYPE keystone.webhook_delivery_status AS ENUM ('pending','delivered','failed','abandoned');

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
-- propriétaire : présente annexe

CREATE TABLE keystone.api_events (                    -- journal des événements publics, conservation 30 jours
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  type text NOT NULL CHECK (type ~ '^[a-z_]+\.[a-z_]+$'),   -- work_order.created, ticket.status_changed, ...
  api_version text NOT NULL DEFAULT 'v1',
  site_id uuid,                                       -- filtrage par le périmètre du compte de service
  data jsonb NOT NULL,                                -- {"id","reference","changes":[noms de champs]} : charge minimale
  occurred_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
CREATE INDEX ix_api_events ON keystone.api_events (tenant_id, occurred_at DESC);

-- Protection_Donnees#1
CREATE TYPE keystone.privacy_request_type   AS ENUM ('access','rectification','erasure','restriction','portability','objection');

-- Protection_Donnees#1
CREATE TYPE keystone.privacy_request_status AS ENUM ('received','identity_pending','in_progress','transferred_to_controller',
                                                     'completed','partially_completed','rejected');

-- Protection_Donnees#1
CREATE TYPE keystone.breach_status   AS ENUM ('detected','qualified','contained','notified','closed');

-- Protection_Donnees#1
CREATE TYPE keystone.breach_severity AS ENUM ('low','moderate','high','critical');

-- Protection_Donnees#1
CREATE TYPE keystone.dpia_status     AS ENUM ('draft','in_review','approved','to_revise');

-- Protection_Donnees#2
CREATE TABLE keystone.processing_activities (         -- registre (art. 30), une ligne par traitement et par version
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  code         text NOT NULL CHECK (code ~ '^T[0-9]{2}$'),
  version      integer NOT NULL DEFAULT 1,
  name         text NOT NULL, purpose text NOT NULL,
  legal_basis  text NOT NULL,
  controller_role text NOT NULL CHECK (controller_role IN ('controller','processor','subprocessor')),
  data_subjects text[] NOT NULL, data_categories text[] NOT NULL,
  special_categories boolean NOT NULL DEFAULT false,
  recipients   text[] NOT NULL, retention text NOT NULL,
  transfers    text, security_measures text NOT NULL,
  source_tables text[] NOT NULL DEFAULT '{}',
  dpia_required boolean NOT NULL DEFAULT false,
  status       text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','validated','archived')),
  validated_by uuid, validated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  UNIQUE (tenant_id, code, version)
);

-- Protection_Donnees#2
CREATE TABLE keystone.subprocessors (                 -- catalogue de plateforme, lu par les tenants
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, service text NOT NULL, data_categories text[] NOT NULL,
  location text NOT NULL, safeguards text NOT NULL,
  status text NOT NULL CHECK (status IN ('active','planned','retired')),
  announced_at date, effective_from date, retired_at date
);

-- Protection_Donnees#2
CREATE TABLE keystone.privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  ref          text NOT NULL,                         -- DRP-2026-000007 (données de démonstration)
  type         keystone.privacy_request_type NOT NULL,
  status       keystone.privacy_request_status NOT NULL DEFAULT 'received',
  subject_user_id uuid REFERENCES keystone.users(id),
  subject_label text NOT NULL,                        -- nom déclaré, pseudonymisé à la clôture plus 5 ans
  contact_email text,
  received_at  timestamptz NOT NULL DEFAULT now(),
  due_at       timestamptz NOT NULL,                  -- received_at plus 1 mois ; extended_due_at si prolongation
  extended_due_at timestamptz, extension_reason text,
  identity_verified_at timestamptz, identity_method text,
  controller_client_id uuid,                          -- fm_provider : client responsable
  outcome      text, rejection_reason text,
  closed_at    timestamptz, handled_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_extension CHECK (extended_due_at IS NULL OR extended_due_at <= received_at + interval '3 months'),
  CONSTRAINT ck_rejection CHECK (status <> 'rejected' OR rejection_reason IS NOT NULL),
  UNIQUE (tenant_id, ref)
);

-- Protection_Donnees#2
CREATE INDEX ix_privacy_requests_due ON keystone.privacy_requests (tenant_id, status, due_at);

-- Protection_Donnees#2
CREATE TABLE keystone.privacy_request_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  request_id uuid NOT NULL REFERENCES keystone.privacy_requests(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('acknowledged','identity_requested','identity_verified','transferred','extended',
                                     'export_ready','erasure_done','partial_refusal','answered','closed')),
  detail jsonb, at timestamptz NOT NULL DEFAULT now(), by_user uuid
);

-- Protection_Donnees#2
CREATE TABLE keystone.privacy_breaches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  ref text NOT NULL, status keystone.breach_status NOT NULL DEFAULT 'detected',
  aware_at        timestamptz NOT NULL,               -- prise de connaissance
  authority_due_at timestamptz,
  nature          text[] NOT NULL CHECK (nature <@ ARRAY['confidentiality','integrity','availability']),
  description     text NOT NULL,
  data_categories text[] NOT NULL, special_categories boolean NOT NULL DEFAULT false,
  subjects_estimate integer, records_estimate integer,
  countries       text[] NOT NULL,                    -- pays des sites touchés (CI, SN, CM, GA)
  severity        keystone.breach_severity,
  risk_unlikely   boolean, risk_unlikely_reason text,
  containment     text, consequences text,
  authority_notified_at timestamptz, authority_reference text,
  subjects_notified_at timestamptz, subjects_notice text,
  processor_informed_controller_at timestamptz,
  closed_at timestamptz, lessons_learned text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_unlikely_reason CHECK (risk_unlikely IS NOT TRUE OR risk_unlikely_reason IS NOT NULL),
  CONSTRAINT ck_close CHECK (status <> 'closed' OR (lessons_learned IS NOT NULL AND
                             (authority_notified_at IS NOT NULL OR risk_unlikely IS TRUE))),
  UNIQUE (tenant_id, ref)
);

-- Protection_Donnees#2
CREATE TABLE keystone.dpia_assessments (               -- AIPD (art. 35), structure de la partie 2
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  activity_code text NOT NULL,                        -- T04, T08
  version integer NOT NULL DEFAULT 1,
  status keystone.dpia_status NOT NULL DEFAULT 'draft',
  description jsonb NOT NULL, necessity jsonb NOT NULL, risks jsonb NOT NULL, measures jsonb NOT NULL,
  residual_risk keystone.risk_level,
  reviewed_by uuid, approved_by uuid, approved_at timestamptz, next_review_at date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_dpia_sod CHECK (approved_by IS NULL OR approved_by <> reviewed_by),
  UNIQUE (tenant_id, activity_code, version)
);

-- Protection_Donnees#2
CREATE TABLE keystone.privacy_formalities (          -- L10-28, formalités par tenant et par pays
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  country_code char(2) NOT NULL REFERENCES atlas_core.country_config(country_code),
  authority    text NOT NULL,                         -- ARTCI, CDP, autorité du Cameroun, autorité du Gabon
  kind         text NOT NULL CHECK (kind IN ('declaration','authorization','transfer_authorization','other')),
  activity_codes text[] NOT NULL DEFAULT '{}',        -- traitements couverts (T01 à T23)
  reference    text, granted_at date, expires_at date,
  document_id  uuid REFERENCES keystone.ged_documents(id),
  status       text NOT NULL DEFAULT 'to_file' CHECK (status IN ('to_file','filed','granted','refused','expired')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_formality_granted CHECK (status <> 'granted' OR (reference IS NOT NULL AND granted_at IS NOT NULL))
);

-- Protection_Donnees#2
CREATE INDEX ix_privacy_formalities ON keystone.privacy_formalities (tenant_id, country_code, status);

-- Protection_Donnees#2
CREATE TABLE keystone.retention_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  rule_key text NOT NULL, table_name text NOT NULL, action text NOT NULL CHECK (action IN ('delete','pseudonymize')),
  rows_affected integer NOT NULL, held_rows integer NOT NULL DEFAULT 0,
  started_at timestamptz NOT NULL, finished_at timestamptz NOT NULL
);

-- correctif_post
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

-- correctif_post
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

-- correctif_post
-- C16 (avec S05 et S06) : échéances dérivées, auparavant colonnes générées refusées (timestamptz + interval n'est pas
-- IMMUTABLE). Même valeur, recalculée à chaque écriture ; la colonne reste en lecture seule pour l'application.
CREATE OR REPLACE FUNCTION keystone.tg_derived_deadlines() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'operating_mode_changes' THEN NEW.revert_deadline := NEW.applied_at + interval '30 days';
  ELSIF TG_TABLE_NAME = 'privacy_breaches' THEN NEW.authority_due_at := NEW.aware_at + interval '72 hours';
  END IF;
  RETURN NEW;
END $$;

-- correctif_post
CREATE TRIGGER trg_breach_authority_due BEFORE INSERT OR UPDATE ON keystone.privacy_breaches
  FOR EACH ROW EXECUTE FUNCTION keystone.tg_derived_deadlines();

-- Referentiels_Transverses#2
-- NULL hors de 1 à 25 ; la colonne appelante porte CHECK (score BETWEEN 1 AND 25)

CREATE OR REPLACE FUNCTION keystone.severity_gravity(p keystone.event_severity) RETURNS smallint
  LANGUAGE sql IMMUTABLE SET search_path = keystone, pg_temp AS $$
  SELECT CASE p WHEN 'minor' THEN 1 WHEN 'moderate' THEN 2 WHEN 'serious' THEN 3
                WHEN 'major' THEN 4 WHEN 'catastrophic' THEN 5 END::smallint $$;

-- Referentiels_Transverses#7
CREATE TABLE keystone.client_sectors (                -- L11-22, référentiel des secteurs de clients (fm_provider)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  code text NOT NULL CHECK (code ~ '^[a-z][a-z0-9_]{1,40}$'), label text NOT NULL,
  is_active boolean NOT NULL DEFAULT true, position smallint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  UNIQUE (tenant_id, code)
);

-- AnnexeCO_Atlas_Core#2
CREATE OR REPLACE FUNCTION keystone.current_operating_mode() RETURNS keystone.operating_mode
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = atlas_core, pg_temp AS $$
  SELECT p.operating_mode
  FROM atlas_core.subscription_products p
  JOIN atlas_core.subscriptions s ON s.id = p.subscription_id AND s.is_current
  WHERE p.tenant_id = keystone.current_tenant() AND p.product_code = 'keystone' AND p.status = 'active' $$;

-- AnnexeCO_Atlas_Core#2
CREATE OR REPLACE FUNCTION keystone.product_option(p_option text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = atlas_core, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM atlas_core.subscription_products p
                 JOIN atlas_core.subscriptions s ON s.id = p.subscription_id AND s.is_current
                 WHERE p.tenant_id = keystone.current_tenant() AND p.product_code = 'keystone'
                   AND p.status = 'active' AND p_option = ANY (p.options)) $$;

-- AnnexeCO_Atlas_Core#3
CREATE OR REPLACE FUNCTION keystone.subscription_access() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN keystone.subscription_access_for(keystone.current_tenant()) = 'export_only'
         AND NOT EXISTS (SELECT 1 FROM keystone.users u WHERE u.id = auth.uid() AND u.is_buyer_admin)
      THEN 'none'
    ELSE keystone.subscription_access_for(keystone.current_tenant()) END $$;

-- AnnexeA_Socle#3
-- Fuseau IANA du site
CREATE OR REPLACE FUNCTION keystone.site_tz(p_site uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = atlas_core, pg_temp AS $$
  SELECT time_zone FROM atlas_core.sites WHERE id = p_site $$;

-- AnnexeA_Socle#3
-- Tenant en écriture (abonnement actif, Annexe CO.4)
CREATE OR REPLACE FUNCTION keystone.tenant_writable() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, atlas_core, pg_temp AS $$
  SELECT keystone.subscription_access() = 'full' $$;

-- AnnexeA_Socle#10
REVOKE UPDATE, DELETE, TRUNCATE ON keystone.audit_trail, keystone.audit_heads,
  keystone.access_log, keystone.access_log_heads FROM PUBLIC, anon, authenticated, service_role;

-- AnnexeA_Socle#10
REVOKE INSERT ON keystone.audit_trail, keystone.access_log FROM PUBLIC, anon, authenticated, service_role;

-- AnnexeA_Socle#15
CREATE TABLE keystone.locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  floor_id uuid NOT NULL REFERENCES atlas_core.levels(id) ON DELETE RESTRICT,
  zone_id uuid REFERENCES keystone.zones(id) ON DELETE RESTRICT,
  space_id uuid REFERENCES atlas_core.spaces(id) ON DELETE RESTRICT,
  code text NOT NULL, name text NOT NULL,
  qr_code text NOT NULL DEFAULT keystone.new_qr_token(),   -- jeton opaque, 12 caractères base32
  printed_at timestamptz, printed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_locations_code UNIQUE (tenant_id, code),
  CONSTRAINT uq_locations_qr UNIQUE (tenant_id, qr_code)
);

-- AnnexeA_Socle#15
CREATE INDEX ix_locations_zone  ON keystone.locations (tenant_id, zone_id);

-- AnnexeA_Socle#15
CREATE INDEX ix_locations_space ON keystone.locations (tenant_id, space_id);

-- AnnexeA_Socle#15
CREATE INDEX ix_locations_site  ON keystone.locations (tenant_id, site_id) WHERE deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#4
-- Documents attendus par famille (lot 17, RG-DOC-04)
CREATE TABLE keystone.asset_category_required_docs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  category_id uuid NOT NULL REFERENCES keystone.asset_categories(id) ON DELETE CASCADE,
  classification_id uuid NOT NULL REFERENCES keystone.ged_classification(id) ON DELETE RESTRICT,  -- sous-série ACT.*
  is_mandatory boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_category_required_doc UNIQUE (category_id, classification_id)
);

-- AnnexeA_Socle_Partie4#4
-- propriétaire : présente section

CREATE TABLE keystone.bulk_action_catalog (           -- catalogue de plateforme, chargé par migration depuis Lot 1 partie 7 §19.7
  entity      text NOT NULL CHECK (entity ~ '^[a-z][a-z_]{2,40}$'),     -- work_order, asset, expense, regulatory_control, ...
  action      text NOT NULL CHECK (action ~ '^[a-z][a-z_]{2,40}$'),     -- set_field, assign, reassign, validate, ...
  field       text NOT NULL DEFAULT '',                                 -- '' hors set_field ; colonne modifiable sinon
  unit_rpc    regprocedure NOT NULL,                                    -- RPC unitaire appelée par ligne (wo_save, update_asset, ...)
  permission  text NOT NULL REFERENCES keystone.permissions(code),
  reason_required boolean NOT NULL DEFAULT false,                       -- copie de la règle du formulaire unitaire
  allowed_values jsonb,                                                 -- liste blanche (ex. priorités 2 à 4 pour un OT)
  mode_scope  text NOT NULL DEFAULT 'both' CHECK (mode_scope IN ('both','in_house','fm_provider')),
  undoable    boolean NOT NULL DEFAULT false,                           -- A.23 ; vrai pour set_field, assign, reassign
  PRIMARY KEY (entity, action, field)
);

-- AnnexeA_Socle_Partie4#4
-- lecture par tout utilisateur authentifié ; aucune écriture hors migration

CREATE TABLE keystone.bulk_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  entity text NOT NULL, action text NOT NULL, field text NOT NULL DEFAULT '',
  new_value jsonb,                                       -- NULL avec clear_value
  clear_value boolean NOT NULL DEFAULT false,            -- « Vider le champ »
  reason text CHECK (reason IS NULL OR char_length(reason) BETWEEN 10 AND 500),
  target_ids uuid[] NOT NULL CHECK (cardinality(target_ids) BETWEEN 1 AND 200),
  expected_versions jsonb NOT NULL DEFAULT '{}',         -- {"<id>": row_version, ou updated_at si la table n'a pas de row_version}
  previous_values jsonb NOT NULL DEFAULT '{}',           -- {"<id>": valeur lue à l'aperçu}, base de l'annulation (A.23)
  status keystone.bulk_operation_status NOT NULL DEFAULT 'previewed',
  ok_count int NOT NULL DEFAULT 0, unchanged_count int NOT NULL DEFAULT 0, refused_count int NOT NULL DEFAULT 0,
  results jsonb NOT NULL DEFAULT '[]',                   -- [{"id","outcome":"modified|unchanged|refused","error_code"}]
  executed_from uuid REFERENCES keystone.bulk_operations(id),   -- ligne d'exécution : aperçu d'origine
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid NOT NULL,
  completed_at timestamptz,
  FOREIGN KEY (entity, action, field) REFERENCES keystone.bulk_action_catalog (entity, action, field),
  CONSTRAINT ck_bulk_clear CHECK (NOT clear_value OR new_value IS NULL)
);

-- AnnexeA_Socle_Partie4#4
CREATE INDEX ix_bulk_ops_author ON keystone.bulk_operations (tenant_id, created_by, created_at DESC);

-- AnnexeA_Socle_Partie4#4
ALTER TABLE keystone.bulk_operations ENABLE ROW LEVEL SECURITY;

-- AnnexeA_Socle_Partie4#5
CREATE TABLE keystone.object_comments (               -- commentaires internes de la console, objets sans table propre
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  entity      text NOT NULL CHECK (entity IN ('work_order','asset')),
  object_id   uuid NOT NULL,
  site_id     uuid NOT NULL REFERENCES atlas_core.sites(id),   -- copie du site de l'objet, cloisonnement (A66)
  author_id   uuid NOT NULL REFERENCES keystone.users(id),
  body        text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 4000),
  mentions    uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(mentions) <= 20),     -- keystone.users.id retenus
  excluded_mentions uuid[] NOT NULL DEFAULT '{}',       -- mentionnés sans droit de lecture, non notifiés
  attachment_ids uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(attachment_ids) <= 5),   -- tg_check_document_ids (A.10.1)
  edited_at   timestamptz,
  reply_to_id uuid REFERENCES keystone.object_comments(id) ON DELETE SET NULL           -- un niveau de réponse
);

-- AnnexeA_Socle_Partie4#5
CREATE INDEX ix_ocom_object  ON keystone.object_comments (tenant_id, entity, object_id, created_at);

-- AnnexeA_Socle_Partie4#5
CREATE INDEX ix_ocom_mention ON keystone.object_comments USING gin (mentions);

-- AnnexeA_Socle_Partie4#5
ALTER TABLE keystone.object_comments ENABLE ROW LEVEL SECURITY;

-- AnnexeG_GED#4
CREATE TABLE keystone.doc_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id) ON DELETE CASCADE,
  link_kind doc_link_kind NOT NULL,
  -- rattachement : entité métier
  entity_type text REFERENCES keystone.doc_entity_types(entity_type),   -- singulier ; registre G.4 ter, créé avant doc_links
  entity_id uuid,
  link_context text NOT NULL DEFAULT 'general'
    CHECK (link_context IN ('general','before','after','evidence','report','signature')),   -- photos d'OT (G.4 ter)
  -- partage : surface et organisation tierce
  target_surface share_surface,
  target_kind share_target_kind,
  target_id uuid,                                   -- clients.id, vendors.id, occupant_org id ; NULL pour population
  target_site_id uuid REFERENCES atlas_core.sites(id),   -- population d'occupants d'un site
  can_download boolean NOT NULL DEFAULT true,
  version_pinned int,                               -- NULL : toujours la version courante
  expires_at timestamptz,
  shared_by uuid, shared_at timestamptz,
  revoked_by uuid, revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_link_attach CHECK (link_kind <> 'attachment' OR (entity_type IS NOT NULL AND entity_id IS NOT NULL)),
  CONSTRAINT ck_link_share CHECK (link_kind <> 'share' OR (target_surface IS NOT NULL AND target_kind IS NOT NULL
        AND (target_id IS NOT NULL OR (target_kind = 'occupant_population' AND target_site_id IS NOT NULL)))),
  CONSTRAINT ck_link_surface CHECK (link_kind <> 'share'
        OR (target_surface = 'client_portal' AND target_kind = 'client')
        OR (target_surface = 'vendor_portal' AND target_kind = 'vendor')
        OR (target_surface = 'occupant_portal' AND target_kind IN ('occupant_org','occupant_population')))
);

-- AnnexeG_GED#4
CREATE INDEX ix_doclink_entity ON keystone.doc_links (tenant_id, entity_type, entity_id) WHERE link_kind = 'attachment';

-- AnnexeG_GED#4
CREATE INDEX ix_doclink_share ON keystone.doc_links (tenant_id, target_kind, target_id) WHERE link_kind = 'share' AND revoked_at IS NULL;

-- AnnexeG_GED#4
CREATE UNIQUE INDEX uq_doclink_attach ON keystone.doc_links (tenant_id, document_id, entity_type, entity_id) WHERE link_kind = 'attachment';

-- AnnexeG_GED#7
CREATE VIEW keystone.v_entity_photos WITH (security_invoker = true) AS
  SELECT l.tenant_id, l.entity_type, l.entity_id, l.link_context, d.id AS document_id, d.ref,
         v.version, v.mime_type, v.uploaded_by, v.uploaded_at
  FROM keystone.doc_links l
  JOIN keystone.ged_documents d ON d.id = l.document_id AND d.doc_type = 'photo' AND d.status <> 'disposed'
  JOIN keystone.doc_versions v ON v.document_id = d.id AND v.version = d.current_version AND v.av_status = 'clean'
  WHERE l.link_kind = 'attachment';

-- AnnexeS_Space_Management_Partie2#5
CREATE TABLE keystone.loading_docks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  dock_code text NOT NULL, location_id uuid REFERENCES keystone.locations(id),
  max_vehicle text NOT NULL CHECK (max_vehicle IN ('van','rigid_truck','semi_trailer')),
  slot_minutes int NOT NULL DEFAULT 30 CHECK (slot_minutes IN (15,30,45,60,90,120)),
  open_hours jsonb NOT NULL, forbidden_slots jsonb NOT NULL DEFAULT '[]',   -- heures d'affluence
  monthly_quota_per_org int, is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT uq_dock UNIQUE (tenant_id, site_id, dock_code) );

-- AnnexeS_Space_Management_Partie2#7
CREATE TABLE keystone.move_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  ref text NOT NULL,                                -- DEM-AAAA-NNNNNN, next_ref('move', année)
  kind text NOT NULL CHECK (kind IN ('install','move','add','change')),
  title text NOT NULL, occupant_org_id uuid NOT NULL REFERENCES keystone.occupant_organizations(id),
  headcount int NOT NULL CHECK (headcount >= 0), wished_date date NOT NULL,
  needs text[] NOT NULL CHECK (cardinality(needs) >= 1),   -- electricity, network, telephony, furniture, cleaning, signage, keys_badges
  justification text NOT NULL, scenario_id uuid, status keystone.move_status NOT NULL DEFAULT 'draft',
  requested_by uuid NOT NULL, approved_by uuid, decision_reason text, cancel_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_move_ref UNIQUE (tenant_id, ref) );

-- AnnexeS_Space_Management_Partie2#7
CREATE TABLE keystone.move_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), move_id uuid NOT NULL REFERENCES keystone.move_requests(id) ON DELETE CASCADE,
  subject_kind text NOT NULL CHECK (subject_kind IN ('organization','person','desk')), subject_ref uuid,
  from_space_id uuid, from_desk text, to_space_id uuid NOT NULL, to_desk text, slot tstzrange,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done')) );

-- AnnexeS_Space_Management_Partie2#11
-- RG-IMI-02
CREATE TABLE keystone.space_chargeback_lines (
  chargeback_id uuid NOT NULL REFERENCES keystone.space_chargebacks(id) ON DELETE CASCADE,
  occupant_org_id uuid NOT NULL REFERENCES keystone.occupant_organizations(id),
  surface_m2 numeric(12,2) NOT NULL, booked_hours numeric(10,2) NOT NULL, tickets int NOT NULL,
  share numeric(12,10) NOT NULL, amount bigint NOT NULL CHECK (amount >= 0),
  detail jsonb NOT NULL, PRIMARY KEY (chargeback_id, occupant_org_id) );

-- AnnexeP_Prestataires_Mobile#2
CREATE TABLE keystone.vendors (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- PRS-0022 (services) ou FRN-0022 (biens seuls)
  roles keystone.vendor_role[] NOT NULL CHECK (cardinality(roles) BETWEEN 1 AND 2),
  origin keystone.vendor_origin NOT NULL DEFAULT 'operator',
  occupant_org_id uuid REFERENCES keystone.occupant_organizations(id) ON DELETE RESTRICT,
  name text NOT NULL, legal_name text NOT NULL,
  legal_form text NOT NULL CHECK (legal_form IN ('SA','SARL','SAS','SASU','EI','GIE','SNC','other')),
  tax_id text NOT NULL, rccm text NOT NULL,
  country char(2) NOT NULL DEFAULT 'CI', address text NOT NULL,
  status keystone.vendor_status NOT NULL DEFAULT 'prospect',
  status_since timestamptz NOT NULL DEFAULT now(),
  status_reason text,
  probation_end date,                                    -- obligatoire en under_watch
  improvement_plan text,
  is_prequalified boolean NOT NULL DEFAULT false,
  prequalified_at timestamptz, prequalified_by uuid,
  work_center_ids uuid[] NOT NULL DEFAULT '{}',          -- domaines (centres de travail)
  specialties text[] NOT NULL DEFAULT '{}',
  served_site_ids uuid[] NOT NULL DEFAULT '{}',
  capacity integer CHECK (capacity >= 0),                -- intervenants mobilisables
  daily_hours numeric(4,2) NOT NULL DEFAULT 8 CHECK (daily_hours > 0 AND daily_hours <= 24),
  tenant_share_pct numeric(5,2) NOT NULL DEFAULT 50 CHECK (tenant_share_pct BETWEEN 0 AND 100), -- part de capacité réservée au tenant (planning)
  guaranteed_response_minutes integer CHECK (guaranteed_response_minutes > 0),
  on_call_24h boolean NOT NULL DEFAULT false,
  remuneration_mode keystone.remuneration_mode,
  currency char(3) NOT NULL DEFAULT 'XOF' CHECK (currency IN ('XOF','XAF')),
  payment_terms_days integer NOT NULL DEFAULT 30 CHECK (payment_terms_days BETWEEN 0 AND 180),
  payment_method keystone.payment_method,
  bank_details_secret_id uuid,                           -- Supabase Vault ; jamais en clair en base
  bank_details_masked text,                              -- « CI93 **** **** 4410 » ou « +225 07 ** ** 12 »
  score numeric(5,2) CHECK (score BETWEEN 0 AND 100),
  score_significant boolean NOT NULL DEFAULT false,
  score_computed_at timestamptz,
  occupant_rating numeric(3,2) CHECK (occupant_rating BETWEEN 1 AND 5),  -- D21 : affichée à côté, hors score
  declared_frequency_rate numeric(8,2) CHECK (declared_frequency_rate >= 0), -- EV-PRS-01 : TF déclaré (A77), information, hors score
  site_rules_accepted_at timestamptz,                    -- EV-PRS-02 : engagement au règlement et aux consignes du site
  site_rules_accepted_by uuid REFERENCES keystone.users(id),
  CONSTRAINT uq_vendor_ref UNIQUE (tenant_id, ref),
  CONSTRAINT uq_vendor_tax UNIQUE (tenant_id, tax_id),
  CONSTRAINT uq_vendor_rccm UNIQUE (tenant_id, rccm),
  CONSTRAINT ck_vendor_occupant CHECK ((origin = 'occupant') = (occupant_org_id IS NOT NULL)),
  CONSTRAINT ck_vendor_watch CHECK (status <> 'under_watch' OR probation_end IS NOT NULL),
  CONSTRAINT ck_vendor_rules CHECK ((site_rules_accepted_at IS NULL) = (site_rules_accepted_by IS NULL))
);

-- AnnexeP_Prestataires_Mobile#2
CREATE INDEX ix_vendors_status ON keystone.vendors (tenant_id, status) WHERE deleted_at IS NULL;

-- AnnexeP_Prestataires_Mobile#2
CREATE INDEX ix_vendors_roles ON keystone.vendors USING gin (roles);

-- AnnexeP_Prestataires_Mobile#2
CREATE INDEX ix_vendors_sites ON keystone.vendors USING gin (served_site_ids);

-- AnnexeP_Prestataires_Mobile#2
CREATE INDEX ix_vendors_name_trgm ON keystone.vendors USING gin (name gin_trgm_ops);

-- AnnexeP_Prestataires_Mobile#4
CREATE TABLE keystone.vendor_contacts (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  full_name text NOT NULL, job_title text,
  phone text NOT NULL CHECK (phone ~ '^\+[0-9]{8,15}$'),  -- E.164
  email text NOT NULL CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  roles keystone.vendor_contact_role[] NOT NULL CHECK (cardinality(roles) >= 1)
);

-- AnnexeP_Prestataires_Mobile#4
CREATE INDEX ix_vendor_contacts ON keystone.vendor_contacts (tenant_id, vendor_id) WHERE deleted_at IS NULL;

-- AnnexeP_Prestataires_Mobile#5
CREATE TABLE keystone.vendor_documents (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  type_id uuid NOT NULL REFERENCES keystone.vendor_document_types(id),
  document_id uuid REFERENCES keystone.ged_documents(id),    -- GED (Annexe G)
  number text, issuer text,
  valid_from date, valid_until date,
  status keystone.vendor_doc_status NOT NULL DEFAULT 'pending',
  reviewed_by uuid, reviewed_at timestamptz, rejection_reason text,
  uploaded_via text NOT NULL DEFAULT 'console' CHECK (uploaded_via IN ('console','portal')),
  CONSTRAINT ck_vdoc_dates CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from)
);

-- AnnexeP_Prestataires_Mobile#5
CREATE INDEX ix_vdoc_expiry ON keystone.vendor_documents (tenant_id, valid_until)
  WHERE deleted_at IS NULL AND status IN ('valid','expiring');

-- AnnexeP_Prestataires_Mobile#5
CREATE INDEX ix_vdoc_vendor ON keystone.vendor_documents (tenant_id, vendor_id, type_id);

-- AnnexeP_Prestataires_Mobile#6
CREATE FUNCTION keystone.vendor_docs_ok(p_vendor uuid, p_on date DEFAULT current_date) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM keystone.vendor_document_types t
    JOIN keystone.vendors v ON v.id = p_vendor AND t.tenant_id = v.tenant_id
    WHERE t.is_blocking AND t.deleted_at IS NULL
      AND t.applies_to && v.roles
      AND (cardinality(t.work_center_ids) = 0 OR t.work_center_ids && v.work_center_ids)
      AND (v.origin = 'operator' OR t.for_occupant_vendor)
      AND NOT EXISTS (SELECT 1 FROM keystone.vendor_documents d
                      WHERE d.vendor_id = v.id AND d.type_id = t.id AND d.deleted_at IS NULL
                        AND d.status IN ('valid','expiring')
                        AND (NOT t.requires_validity OR d.valid_until >= p_on))) $$;

-- AnnexeP_Prestataires_Mobile#7
CREATE TABLE keystone.vendor_bank_changes (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL, requested_via text NOT NULL CHECK (requested_via IN ('console','portal')),
  new_method keystone.payment_method NOT NULL,
  new_details_secret_id uuid NOT NULL,                   -- Vault
  new_details_masked text NOT NULL,
  proof_document_id uuid REFERENCES keystone.ged_documents(id) NOT NULL REFERENCES keystone.ged_documents(id),  -- RIB ou attestation d'opérateur
  callback_done_by uuid, callback_done_at timestamptz,   -- contre-appel au contact principal, numéro antérieur
  first_approver uuid, first_approved_at timestamptz,
  second_approver uuid, second_approved_at timestamptz,
  status keystone.bank_change_status NOT NULL DEFAULT 'pending',
  rejection_reason text,
  effective_at timestamptz,
  CONSTRAINT ck_bank_sod CHECK (
    (first_approver IS NULL OR first_approver <> requested_by) AND
    (second_approver IS NULL OR (second_approver <> requested_by AND second_approver <> first_approver)))
);

-- AnnexeP_Prestataires_Mobile#7
CREATE UNIQUE INDEX uq_bank_change_open ON keystone.vendor_bank_changes (tenant_id, vendor_id)
  WHERE status IN ('pending','first_approved');

-- AnnexeP_Prestataires_Mobile#8
CREATE TABLE keystone.vendor_site_restrictions (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  reason text NOT NULL, starts_on date NOT NULL DEFAULT current_date, ends_on date,
  lifted_by uuid, lifted_at timestamptz,
  CONSTRAINT ck_vsr_dates CHECK (ends_on IS NULL OR ends_on >= starts_on)
);

-- AnnexeP_Prestataires_Mobile#8
CREATE INDEX ix_vsr_active ON keystone.vendor_site_restrictions (tenant_id, vendor_id, site_id) WHERE lifted_at IS NULL;

-- AnnexeP_Prestataires_Mobile#9
CREATE TABLE keystone.vendor_messages (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  object_type text NOT NULL CHECK (object_type IN
    ('work_order','rfq','purchase_order','shipment_notice','expense','penalty','review','document','prevention_plan')),
  object_id uuid NOT NULL,
  author_id uuid NOT NULL, author_side text NOT NULL CHECK (author_side IN ('operator','vendor')),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  attachment_ids uuid[] NOT NULL DEFAULT '{}',
  read_by_other_at timestamptz
);

-- AnnexeP_Prestataires_Mobile#9
CREATE INDEX ix_vmsg_object ON keystone.vendor_messages (tenant_id, object_type, object_id, created_at);

-- AnnexeP_Prestataires_Mobile#10
CREATE VIEW keystone.contractors WITH (security_invoker = true) AS
  SELECT id, tenant_id, ref, name, legal_name, tax_id, status, is_prequalified, score,
         capacity, on_call_24h, payment_terms_days, daily_hours, tenant_share_pct, probation_end,
         created_at, updated_at, deleted_at
  FROM keystone.vendors WHERE 'service_provider' = ANY (roles);

-- AnnexeP_Prestataires_Mobile#10
CREATE VIEW keystone.suppliers WITH (security_invoker = true) AS
  SELECT id, tenant_id, ref, name, legal_name, tax_id, legal_form, rccm, country, status,
         is_prequalified, payment_terms_days, created_at, updated_at, deleted_at
  FROM keystone.vendors WHERE 'goods_supplier' = ANY (roles);

-- AnnexeP_Prestataires_Mobile#10
CREATE VIEW keystone.contractor_documents WITH (security_invoker = true) AS
  SELECT d.id, d.tenant_id, d.vendor_id AS contractor_id, t.code AS kind, d.valid_from, d.valid_until, d.status
  FROM keystone.vendor_documents d JOIN keystone.vendor_document_types t ON t.id = d.type_id;

-- AnnexeP_Prestataires_Mobile#11
CREATE TABLE keystone.vendor_status_history (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  from_status keystone.vendor_status, to_status keystone.vendor_status NOT NULL,
  reason text, payload jsonb NOT NULL DEFAULT '{}', actor uuid NOT NULL
);

-- AnnexeP_Prestataires_Mobile#13
CREATE TABLE keystone.vendor_score_snapshots (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  month date NOT NULL CHECK (date_trunc('month', month) = month),
  score numeric(5,2), significant boolean NOT NULL,
  c_sla numeric(6,5), c_qua numeric(6,5), c_sec numeric(6,5), c_rea numeric(6,5), c_doc numeric(6,5),
  closed_wo_count integer NOT NULL, weights jsonb NOT NULL,
  CONSTRAINT uq_vss UNIQUE (tenant_id, vendor_id, month)
);

-- AnnexeP_Prestataires_Mobile#15
CREATE TABLE keystone.vendor_doc_daily_status (
  tenant_id uuid NOT NULL, vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  day date NOT NULL, ok boolean NOT NULL,                -- vendor_docs_ok(vendor_id, day), écrit par la tâche nocturne
  PRIMARY KEY (tenant_id, vendor_id, day)
);

-- AnnexeP_Prestataires_Mobile#17
CREATE TABLE keystone.contractor_reviews (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- REV-2026-000014
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  trigger keystone.review_trigger NOT NULL,
  period_start date NOT NULL, period_end date NOT NULL CHECK (period_end > period_start),
  contract_ids uuid[] NOT NULL DEFAULT '{}',             -- maintenance_contracts
  participants jsonb NOT NULL,                           -- [{ "name", "organisation": "operator"|"vendor", "job_title" }]
  performance_snapshot jsonb,                            -- figé à l'envoi
  strengths text, improvements text,
  decision keystone.review_decision, decision_rationale text, proposed_probation_end date,
  status keystone.vendor_review_status NOT NULL DEFAULT 'draft',
  sent_at timestamptz, contradictory_deadline date,
  vendor_observations jsonb,                             -- { "section_2": "...", ... }
  vendor_accepted_without_observation boolean,
  author_id uuid NOT NULL, validator_id uuid, validated_at timestamptz,
  operator_signature_id uuid REFERENCES keystone.ged_documents(id), vendor_signature_id uuid REFERENCES keystone.ged_documents(id),
  CONSTRAINT uq_review_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_review_sod CHECK (validator_id IS NULL OR validator_id <> author_id),
  CONSTRAINT ck_review_participants CHECK (jsonb_typeof(participants) = 'array')
);

-- AnnexeP_Prestataires_Mobile#17
CREATE TABLE keystone.contractor_review_scores (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  review_id uuid NOT NULL REFERENCES keystone.contractor_reviews(id) ON DELETE CASCADE,
  criterion text NOT NULL CHECK (criterion IN
    ('technical_competence','reporting_quality','communication','administrative_compliance','safety_environment','initiative')),
  score smallint NOT NULL CHECK (score BETWEEN 1 AND 5),
  justification text,
  CONSTRAINT uq_review_criterion UNIQUE (review_id, criterion),
  CONSTRAINT ck_review_justif CHECK (score > 2 OR justification IS NOT NULL)
);

-- AnnexeP_Prestataires_Mobile#20
CREATE TABLE keystone.vendor_rate_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  position smallint NOT NULL CHECK (position >= 1),
  label text NOT NULL CHECK (char_length(btrim(label)) BETWEEN 2 AND 160),
  unit text NOT NULL CHECK (unit IN ('hour','day','intervention','unit','m2','ml','month','lump_sum')),
  unit_price_ht bigint NOT NULL CHECK (unit_price_ht > 0),   -- I01
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  valid_from date NOT NULL DEFAULT current_date, valid_until date,
  CONSTRAINT ck_vrl_dates CHECK (valid_until IS NULL OR valid_until >= valid_from),
  CONSTRAINT uq_vrl_pos UNIQUE (tenant_id, vendor_id, position)
);

-- AnnexeP_Prestataires_Mobile#20
CREATE INDEX ix_vrl_vendor ON keystone.vendor_rate_lines (tenant_id, vendor_id) WHERE deleted_at IS NULL;

-- AnnexeP_Prestataires_Mobile#22
CREATE TABLE keystone.vendor_change_requests (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  field text NOT NULL CHECK (field IN ('legal_name','name','legal_form','tax_id','rccm','country','address')),
  old_value text, new_value text NOT NULL CHECK (char_length(btrim(new_value)) BETWEEN 1 AND 500),
  proof_document_id uuid REFERENCES keystone.ged_documents(id),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),
  requested_by uuid NOT NULL REFERENCES keystone.users(id),
  decided_by uuid, decided_at timestamptz, decision_reason text,
  CONSTRAINT ck_vcr_decision CHECK (status IN ('pending','cancelled') OR (decided_by IS NOT NULL AND decided_at IS NOT NULL)),
  CONSTRAINT ck_vcr_reject CHECK (status <> 'rejected' OR decision_reason IS NOT NULL)
);

-- AnnexeP_Prestataires_Mobile#22
CREATE UNIQUE INDEX uq_vcr_pending ON keystone.vendor_change_requests (tenant_id, vendor_id, field) WHERE status = 'pending';

-- AnnexeK_Formation_Environnement#3
CREATE OR REPLACE FUNCTION keystone.competency_gaps(p_person uuid, p_requirements uuid[],
    p_at date DEFAULT current_date,          -- date de fin de l'action contrôlée (fin du créneau, du permis)
    p_context text DEFAULT NULL,             -- wo_assignment, permit_worker, permit_approver, isolation, audit_lead
    p_object uuid DEFAULT NULL)              -- OT, permis ou audit ; écriture du refus si p_context est renseigné
RETURNS TABLE (competency_id uuid, state keystone.competency_check)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
BEGIN
  RETURN QUERY
  SELECT r.competency_id,
         CASE WHEN pc.status = 'valid' AND (pc.valid_until IS NULL OR pc.valid_until >= p_at) THEN 'valid'
              WHEN pc.status = 'pending' THEN 'pending'
              WHEN pc.status IN ('valid','expired') THEN 'expired'
              ELSE 'missing' END::keystone.competency_check
  FROM keystone.competency_requirements r
  LEFT JOIN LATERAL (SELECT status, valid_until FROM keystone.person_competencies
                     WHERE person_id = p_person AND competency_id = r.competency_id AND deleted_at IS NULL
                     ORDER BY granted_on DESC LIMIT 1) pc ON true
  WHERE r.id = ANY (p_requirements) AND r.is_blocking AND r.tenant_id = keystone.current_tenant();

  IF p_context IS NOT NULL THEN               -- une ligne par compétence en écart, idempotente par objet
    INSERT INTO keystone.competency_refusals (tenant_id, person_id, competency_id, context, object_id, state)
    SELECT keystone.current_tenant(), p_person, g.competency_id, p_context, p_object, g.state
    FROM keystone.competency_gaps(p_person, p_requirements, p_at) g
    WHERE g.state <> 'valid'
    ON CONFLICT (tenant_id, person_id, competency_id, context, object_id) DO NOTHING;
  END IF;
END $$;

-- AnnexeK_Formation_Environnement#4
CREATE TABLE keystone.training_sessions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  title text NOT NULL,
  competency_id uuid REFERENCES keystone.competencies(id),
  site_id uuid REFERENCES atlas_core.sites(id), location_id uuid REFERENCES keystone.locations(id),
  planned_at timestamptz NOT NULL, duration_hours numeric(5,1) NOT NULL CHECK (duration_hours > 0),
  provider text, trainer text,
  cost_amount bigint CHECK (cost_amount >= 0),          -- Money.ts
  currency char(3) CHECK (currency IN ('XOF','XAF')),
  status keystone.session_status NOT NULL DEFAULT 'planned',
  cancel_reason text,
  CONSTRAINT ck_ts_cost CHECK (cost_amount IS NULL OR currency IS NOT NULL)
);

-- AnnexeK_Formation_Environnement#5
CREATE TABLE keystone.training_media (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  session_id uuid REFERENCES keystone.training_sessions(id) ON DELETE CASCADE,
  competency_id uuid REFERENCES keystone.competencies(id),
  video_document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),
  captions_document_id uuid REFERENCES keystone.ged_documents(id),                -- sous-titres WebVTT
  transcript_document_id uuid REFERENCES keystone.ged_documents(id),              -- transcription textuelle
  CONSTRAINT ck_tm_target CHECK (session_id IS NOT NULL OR competency_id IS NOT NULL),
  CONSTRAINT ck_tm_a11y CHECK (captions_document_id IS NOT NULL AND transcript_document_id IS NOT NULL)   -- WCAG 2.2, 1.2.2 et 1.2.3
);

-- AnnexeK_Formation_Environnement#7
CREATE TABLE keystone.env_permits (                      -- autorisations environnementales (CDC v3 §6.8)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  kind text NOT NULL, authority text NOT NULL, reference text,
  holder text NOT NULL,                     -- titulaire : exploitant ou client
  valid_from date NOT NULL, valid_to date,
  obligation_id uuid REFERENCES keystone.legal_obligations(id),
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),
  renewed_from uuid REFERENCES keystone.env_permits(id),   -- autorisation renouvelée
  CONSTRAINT ck_envp CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

-- AnnexeK_Formation_Environnement#8
-- keystone.emission_factors : table unique de l'Annexe EN (énergie et hors énergie : category, scope,
--   activity_unit, kg_co2e_per_unit, pays, période, source datée) ;
--   l'Annexe K la lit et ne la redéfinit pas.
CREATE TABLE keystone.emissions (                        -- CDC v3 §6.8
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  scope int NOT NULL CHECK (scope IN (1,2,3)),
  category text NOT NULL,
  period_start date NOT NULL, period_end date NOT NULL,
  activity_value numeric(18,4) NOT NULL CHECK (activity_value >= 0),
  activity_unit text NOT NULL,
  factor_id uuid REFERENCES keystone.emission_factors(id),                -- Annexe EN
  co2e_t numeric(18,4),                     -- activity_value fois emission_factors.kg_co2e_per_unit divisé par 1000 ; NULL si facteur absent
  source keystone.value_source NOT NULL, source_ref text,
  CONSTRAINT ck_em_period CHECK (period_end >= period_start),
  CONSTRAINT uq_em UNIQUE (tenant_id, site_id, scope, category, period_start)
);

-- AnnexeB_GMAO_Partie3#16
CREATE TABLE keystone.maintenance_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  ref text NOT NULL,                            -- CTM-AAAA-NNNNNN
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE RESTRICT,
  title text NOT NULL, scope text NOT NULL,
  status maintenance_contract_status NOT NULL DEFAULT 'draft',
  start_date date NOT NULL, end_date date NOT NULL,
  renewal_mode text NOT NULL CHECK (renewal_mode IN ('tacit','express')),
  renewal_term_months int CHECK (renewal_term_months > 0),
  notice_days int NOT NULL DEFAULT 90 CHECK (notice_days >= 0),
  notice_deadline date GENERATED ALWAYS AS (end_date - notice_days) STORED,
  renewal_blocked boolean NOT NULL DEFAULT false, renewal_blocked_reason text,
  termination_notice_sent_on date,              -- dénonciation envoyée au prestataire
  termination_notice_document_id uuid REFERENCES keystone.ged_documents(id),   -- courrier de dénonciation (GED)
  signed_document_id uuid REFERENCES keystone.ged_documents(id),   -- contrat signé (GED), EV-PRS-08
  sla_terms jsonb NOT NULL,                     -- schéma M.2.3 (Annexe M), surcharge de sla_policies (B.3.2)
  penalty_terms jsonb,                          -- schéma M.2.4 (Annexe M), montants entiers en francs
  ack_delay jsonb,                              -- A102 : surcharge du paramètre wo.ack_delay, {"P1":120,"P2":240,"P3":1440,"P4":2880} en minutes ; NULL : paramètre du tenant
  amount bigint NOT NULL CHECK (amount >= 0),   -- montant annuel, unité de la devise
  currency char(3) NOT NULL,
  is_active boolean GENERATED ALWAYS AS (status IN ('active','renewing')) STORED,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_ctm_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_ctm_dates CHECK (end_date >= start_date),
  CONSTRAINT ck_ctm_blocked CHECK (NOT renewal_blocked OR renewal_blocked_reason IS NOT NULL),
  CONSTRAINT ck_ctm_notice CHECK (termination_notice_sent_on IS NULL OR termination_notice_document_id IS NOT NULL),
  CONSTRAINT ck_ctm_ack_delay CHECK (ack_delay IS NULL
    OR jsonb_matches_schema(keystone.json_schema('ack_delay/v1'), ack_delay)),   -- P1 à P4 requis, entiers 15 à 4 320 ; INVALID_TERMS
  CONSTRAINT ck_ctm_sla_schema CHECK (jsonb_matches_schema(keystone.json_schema('sla_terms/v1'), sla_terms)),
  CONSTRAINT ck_ctm_penalty_schema CHECK (penalty_terms IS NULL
    OR jsonb_matches_schema(keystone.json_schema('penalty_terms/v1'), penalty_terms)) );

-- AnnexeC_HSSE#3
-- Mois de rattachement dans le fuseau du site (keystone.site_tz, Annexe A, atlas_core.sites.time_zone)
CREATE FUNCTION keystone.site_local_month(p_site uuid, p_ts timestamptz) RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT date_trunc('month', p_ts AT TIME ZONE COALESCE(keystone.site_tz(p_site), 'Africa/Abidjan'))::date $$;

-- AnnexeC_HSSE_Partie2#2
CREATE TABLE keystone.work_units (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  site_id uuid REFERENCES atlas_core.sites(id),
  code text NOT NULL, label text NOT NULL,
  kind keystone.work_unit_kind NOT NULL,
  location_id uuid REFERENCES keystone.locations(id),
  description text, headcount int CHECK (headcount >= 0),
  last_reviewed_at timestamptz, next_review_due date NOT NULL,
  UNIQUE (tenant_id, legal_entity_id, code),
  CONSTRAINT ck_wu_location CHECK (kind <> 'location' OR location_id IS NOT NULL)
);

-- AnnexeE_Budgets_Achats#2
CREATE TABLE keystone.purchasing_category_thresholds (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  settings_id uuid NOT NULL REFERENCES keystone.purchasing_settings(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES keystone.budget_categories(id),
  quotes_required_above bigint CHECK (quotes_required_above >= 0),   -- NULL : valeur de l'entité
  no_po_cap bigint CHECK (no_po_cap >= 0),
  CONSTRAINT uq_purch_cat UNIQUE (settings_id, category_id)
);

-- AnnexeC_HSSE_Partie3#4
CREATE TABLE keystone.audits (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  program_id uuid REFERENCES keystone.audit_programs(id),
  site_id uuid REFERENCES atlas_core.sites(id),
  ref text NOT NULL,                        -- AUD-2026-000014
  title text NOT NULL,                      -- conteneur ad hoc : AUD-ADHOC-<code site>-2026-10
  kind keystone.audit_kind NOT NULL,
  origin keystone.record_origin NOT NULL DEFAULT 'planned',
  container_month date,                     -- audit conteneur ad hoc : premier jour du mois
  standard text NOT NULL,                   -- ISO 45001:2018, ISO 14001:2026, ISO 41001:2018, ISO 9001:2026, interne
  scope text NOT NULL, objectives text,
  external_auditor_name text,               -- audit externe ou de certification
  planned_date date NOT NULL, duration_h numeric(5,1) CHECK (duration_h > 0),
  summary text CHECK (char_length(summary) <= 4000),       -- synthèse du rapport, auditeur principal
  strengths text CHECK (char_length(strengths) <= 2000),   -- points forts du rapport
  row_version bigint NOT NULL DEFAULT 1,
  status keystone.audit_status NOT NULL DEFAULT 'planned',
  started_at timestamptz, collection_closed_at timestamptz,
  report_document_id uuid REFERENCES keystone.ged_documents(id), report_distributed_at timestamptz,
  conclusion keystone.audit_conclusion,
  cancel_reason text,
  CONSTRAINT uq_audit_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_audit_origin CHECK (origin IN ('planned','ad_hoc')),
  CONSTRAINT ck_audit_container CHECK ((origin = 'ad_hoc') = (container_month IS NOT NULL))
);

-- AnnexeC_HSSE_Partie3#4
CREATE UNIQUE INDEX uq_audit_container ON keystone.audits (tenant_id, site_id, container_month) WHERE origin = 'ad_hoc';

-- AnnexeC_HSSE_Partie3#6
CREATE TABLE keystone.regulatory_watch (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- VRG-AAAA-NNNNNN
  country_code char(2) NOT NULL,
  domain keystone.obligation_domain NOT NULL,
  source text NOT NULL,                                  -- journal officiel, ministère, autorité
  source_reference text NOT NULL,                        -- numéro du texte (décret, arrêté, loi)
  source_url text,
  title text NOT NULL,
  published_on date NOT NULL, effective_on date,
  summary text NOT NULL CHECK (char_length(summary) <= 4000),
  proposed_obligation jsonb,                             -- {label, obligation, source_article, framework_code}
  origin text NOT NULL CHECK (origin IN ('agent','manual')),
  agent_run_id uuid REFERENCES keystone.agent_runs(id),  -- agent Veille réglementaire (Annexe H.4.1)
  status keystone.regulatory_watch_status NOT NULL DEFAULT 'proposed',
  decided_by uuid, decided_at timestamptz, decision_reason text,
  obligation_id uuid REFERENCES keystone.legal_obligations(id),   -- obligation créée à l'acceptation
  CONSTRAINT uq_rw_ref UNIQUE (tenant_id, ref),
  CONSTRAINT uq_rw_text UNIQUE (tenant_id, country_code, source_reference),
  CONSTRAINT ck_rw_agent CHECK ((origin = 'agent') = (agent_run_id IS NOT NULL)),
  CONSTRAINT ck_rw_decided CHECK (status = 'proposed' OR (decided_by IS NOT NULL AND decided_at IS NOT NULL)),
  CONSTRAINT ck_rw_reject CHECK (status <> 'rejected' OR decision_reason IS NOT NULL),
  CONSTRAINT ck_rw_accept CHECK (status <> 'accepted' OR obligation_id IS NOT NULL)
);

-- AnnexeC_HSSE_Partie3#6
CREATE INDEX ix_rw_open ON keystone.regulatory_watch (tenant_id, country_code, published_on DESC) WHERE status = 'proposed';

-- AnnexeC_HSSE_Partie4#7
CREATE FUNCTION keystone.occupational_health_active() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM keystone.processing_activities pa
                 WHERE pa.tenant_id = keystone.current_tenant() AND pa.code = 'T08'
                   AND pa.status = 'validated' AND pa.deleted_at IS NULL)
     AND EXISTS (SELECT 1 FROM keystone.dpia_assessments d
                 WHERE d.tenant_id = keystone.current_tenant() AND d.activity_code = 'T08'
                   AND d.status = 'approved' AND d.approved_at IS NOT NULL);
$$;

-- AnnexeC_HSSE_Partie4#7
REVOKE ALL ON FUNCTION keystone.occupational_health_active() FROM PUBLIC, anon, proph3t_reader;

-- AnnexeR_Reglementaire_SSI#2
CREATE TABLE keystone.inspection_bodies (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  name text NOT NULL,
  kind keystone.body_kind NOT NULL,
  vendor_id uuid REFERENCES keystone.vendors(id),       -- fiche tiers unique (D13)
  accreditation text, accreditation_valid_to date,
  country_code char(2) NOT NULL,
  contact_email text, contact_phone text,
  is_archived boolean NOT NULL DEFAULT false,
  UNIQUE (tenant_id, name, country_code),
  CONSTRAINT ck_ib_accr CHECK (kind <> 'accredited_body' OR (accreditation IS NOT NULL AND accreditation_valid_to IS NOT NULL))
);

-- AnnexeD_Tickets_Portails_Partie2#5
CREATE TABLE keystone.public_report_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE CASCADE,
  location_id uuid NOT NULL REFERENCES keystone.locations(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,                 -- SHA-256 du jeton imprimé dans le QR
  is_enabled boolean NOT NULL DEFAULT true, revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_public_point UNIQUE (tenant_id, location_id)
);

-- AnnexeD_Tickets_Portails_Partie2#5
CREATE TABLE keystone.public_report_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, point_id uuid NOT NULL REFERENCES keystone.public_report_points(id) ON DELETE CASCADE,
  device_hash text NOT NULL,                       -- SHA-256 (adresse IP tronquée, agent, sel quotidien)
  outcome text NOT NULL CHECK (outcome IN ('created','duplicate','rate_limited','captcha_failed','rejected')),
  at timestamptz NOT NULL DEFAULT now() );

-- AnnexeD_Tickets_Portails_Partie2#5
CREATE INDEX ix_public_attempt ON keystone.public_report_attempts (point_id, device_hash, at);

-- AnnexeD_Tickets_Portails_Partie2#7
CREATE TABLE keystone.site_directory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('service','emergency','contact','document_link')),
  label text NOT NULL, description text, phone text, email text, opening_hours jsonb,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  audience text NOT NULL DEFAULT 'occupants' CHECK (audience IN ('occupants','public')),
  sort_order int NOT NULL DEFAULT 0, is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz );

-- AnnexeF_SoftFM#4
CREATE TABLE keystone.bait_stations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, code text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('rodent','crawling_insect','flying_insect')),
  location_id uuid NOT NULL REFERENCES keystone.locations(id),
  plan_id uuid REFERENCES keystone.space_plans(id), x numeric(8,5), y numeric(8,5),   -- position normalisée
  is_food_area boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','missing','removed')),
  installed_at date NOT NULL, removed_at date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_bait_station UNIQUE (tenant_id, site_id, code) );

-- AnnexeF_SoftFM#5
CREATE TABLE keystone.pest_quarterly_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, quarter daterange NOT NULL,
  figures jsonb NOT NULL,                          -- indicateurs calculés ci-dessus, figés à l'émission
  recommendations text NOT NULL, vendor_id uuid REFERENCES keystone.vendors(id),
  pdf_document_id uuid, issued_by uuid NOT NULL, issued_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_pest_report UNIQUE (tenant_id, site_id, quarter) );

-- AnnexeEN_Energie#4
CREATE TABLE keystone.energy_tariffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE RESTRICT,   -- fournisseur d'énergie (D13)
  code text NOT NULL, label text NOT NULL,
  fluid energy_fluid NOT NULL,
  country_code char(2) NOT NULL,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  billing_unit text NOT NULL,                        -- 'kWh', 'm3', 'l'
  fixed_charge_month bigint NOT NULL DEFAULT 0 CHECK (fixed_charge_month >= 0),   -- abonnement, FCFA
  tax_rate numeric(7,5) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate < 1),
  valid_from date NOT NULL, valid_to date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_tariff_code UNIQUE (tenant_id, code, valid_from),
  CONSTRAINT ck_tariff_dates CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- AnnexeEN_Energie#4
-- Contrainte d'exclusion (extension btree_gist) : deux versions d'un même code ne se chevauchent pas (ENERGY_TARIFF_OVERLAP)
ALTER TABLE keystone.energy_tariffs ADD CONSTRAINT ex_tariff_overlap
  EXCLUDE USING gist (tenant_id WITH =, code WITH =, daterange(valid_from, valid_to, '[)') WITH &&)
  WHERE (deleted_at IS NULL);

-- AnnexeEN_Energie#4
CREATE TABLE keystone.energy_tariff_tranches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  tariff_id uuid NOT NULL REFERENCES keystone.energy_tariffs(id) ON DELETE CASCADE,
  rank int NOT NULL CHECK (rank >= 1),
  lower_qty numeric(18,4) NOT NULL CHECK (lower_qty >= 0),   -- borne basse incluse, par mois de facturation
  upper_qty numeric(18,4),                                   -- borne haute exclue ; NULL : dernière tranche
  unit_price numeric(18,6) NOT NULL CHECK (unit_price >= 0), -- prix unitaire (taux), pas un montant
  CONSTRAINT uq_tranche UNIQUE (tenant_id, tariff_id, rank),
  CONSTRAINT ck_tranche_bounds CHECK (upper_qty IS NULL OR upper_qty > lower_qty)
);

-- AnnexeQ_Reporting#3
CREATE TABLE keystone.report_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  schedule_id uuid REFERENCES keystone.report_schedules(id) ON DELETE SET NULL,   -- NULL : à la demande
  template_id uuid NOT NULL REFERENCES keystone.report_templates(id),
  period_start date NOT NULL, period_end date NOT NULL,
  scope jsonb NOT NULL,
  status report_run_status NOT NULL DEFAULT 'planned',
  due_at timestamptz,
  kpi_snapshot jsonb NOT NULL DEFAULT '[]',         -- [{kpi_value_id, code, version, revision}] (RG-RAP-04)
  missing_data jsonb NOT NULL DEFAULT '[]',         -- indicateurs not_computable ou incomplete, en tête du rapport
  format report_format NOT NULL DEFAULT 'pdf',
  review_comment text,                              -- commentaire de validation
  commentaries jsonb NOT NULL DEFAULT '{}',         -- {section_key: texte} ; obligatoire si la section porte commentary_required
  document_id uuid REFERENCES keystone.ged_documents(id),   -- série RAP (Annexe G)
  agent_run_id uuid REFERENCES keystone.agent_runs(id),     -- brouillon de l'agent Reporting
  generated_at timestamptz, reviewed_by uuid, validated_by uuid, validated_at timestamptz,
  failed_at timestamptz,
  distributed_at timestamptz,
  attempts int NOT NULL DEFAULT 0, failure_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_run_failed CHECK (status <> 'failed' OR failure_reason IS NOT NULL),
  CONSTRAINT ck_run_validated CHECK (status <> 'validated' OR validated_by IS NOT NULL),
  CONSTRAINT ck_run_agent CHECK (agent_run_id IS NULL OR status <> 'distributed' OR validated_by IS NOT NULL)
);

-- AnnexeQ_Reporting#3
CREATE INDEX ix_report_runs_due ON keystone.report_runs (tenant_id, status, due_at);

-- AnnexeQ_Reporting#5
CREATE TABLE keystone.fm_management_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                 -- RDD-2026-01
  scope_site_ids uuid[] NOT NULL DEFAULT '{}',       -- vide : tout le système FM
  period_start date NOT NULL, period_end date NOT NULL,
  planned_at timestamptz NOT NULL, held_at timestamptz,
  chair_id uuid NOT NULL,                            -- direction
  participants uuid[] NOT NULL DEFAULT '{}',
  status fm_review_status NOT NULL DEFAULT 'planned',
  conclusions text,                                  -- pertinence, adéquation, efficacité du système FM
  minutes_document_id uuid REFERENCES keystone.ged_documents(id),
  minutes_approved_by uuid, minutes_approved_at timestamptz,
  report_run_id uuid REFERENCES keystone.report_runs(id),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_fm_review_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_review_held CHECK (status IN ('planned','in_preparation') OR (held_at IS NOT NULL AND conclusions IS NOT NULL))
);

-- AnnexeQ_Reporting#5
CREATE TABLE keystone.fm_review_inputs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  review_id uuid NOT NULL REFERENCES keystone.fm_management_reviews(id) ON DELETE CASCADE,
  input_code review_input_code NOT NULL,
  summary text,                                      -- synthèse rédigée par le préparateur
  data_refs jsonb NOT NULL DEFAULT '[]',             -- [{kpi_value_id}] [{table, id}] [{document_id}]
  assigned_to uuid,                                  -- préparateur désigné
  prepared_by uuid, prepared_at timestamptz,
  is_applicable boolean NOT NULL DEFAULT true,       -- energy_performance : false sans périmètre énergie
  CONSTRAINT uq_review_input UNIQUE (tenant_id, review_id, input_code),
  CONSTRAINT ck_input_prepared CHECK (prepared_at IS NULL OR summary IS NOT NULL)
);

-- AnnexeA_Socle#14
CREATE TABLE keystone.space_ext (
  space_id         uuid PRIMARY KEY REFERENCES atlas_core.spaces(id) ON DELETE RESTRICT,
  tenant_id        uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  location_id      uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  occupancy_status text NOT NULL DEFAULT 'vacant' CHECK (occupancy_status IN ('occupied','vacant','reserved','works')),
  occupant_kind    text CHECK (occupant_kind IN ('lease_tenant','internal','vacant')),
  occupant_ref     uuid,                                 -- bail Atlas Patrimoine, lecture
  is_public        boolean NOT NULL DEFAULT false,
  area_class_id    uuid REFERENCES keystone.area_classes(id) ON DELETE RESTRICT,   -- classe de surface (Annexe S.4)
  usage_label      text,                                 -- usage affiché (« Réserve », données de démonstration)
  capacity         int CHECK (capacity >= 0),            -- places ou postes
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid
);

-- AnnexeA_Socle_Partie2#9
CREATE TABLE keystone.persons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  type person_type NOT NULL,
  employment_type employment_type NOT NULL,            -- A52
  status person_status NOT NULL DEFAULT 'active',
  first_name text NOT NULL,
  last_name text NOT NULL,
  job_title text,
  user_id uuid REFERENCES keystone.users(id) ON DELETE SET NULL,
  vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE RESTRICT,   -- D13, remplace contractor_id
  badge_id text,
  phone text,
  email text CHECK (email IS NULL OR email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  proposed_by uuid, validated_by uuid, validated_at timestamptz,
  deactivated_at timestamptz, deactivated_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_person_employment CHECK (
       (type = 'employee'   AND employment_type IN ('permanent','temporary'))
    OR (type = 'contractor' AND employment_type = 'contractor')
    OR (type = 'visitor'    AND employment_type = 'visitor')),
  CONSTRAINT ck_person_vendor CHECK ((type = 'contractor') = (vendor_id IS NOT NULL)),
  CONSTRAINT ck_person_inactive CHECK (status <> 'inactive' OR deactivated_at IS NOT NULL),
  CONSTRAINT uq_persons_badge UNIQUE (tenant_id, badge_id)
);

-- AnnexeA_Socle_Partie2#9
CREATE INDEX ix_persons_vendor ON keystone.persons (tenant_id, vendor_id) WHERE deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#9
CREATE UNIQUE INDEX uq_persons_user ON keystone.persons (tenant_id, user_id)
  WHERE user_id IS NOT NULL AND status = 'active' AND deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#9
-- lu par current_person_id()
CREATE INDEX ix_persons_status ON keystone.persons (tenant_id, status);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_vendors_ref_prefix  ON keystone.vendors      (tenant_id, ref text_pattern_ops);

-- AnnexeS_Space_Management_Partie2#5
CREATE TABLE keystone.loading_dock_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  ref text NOT NULL,                                -- LIV-AAAA-NNNNNN
  dock_id uuid NOT NULL REFERENCES keystone.loading_docks(id),
  occupant_org_id uuid REFERENCES keystone.occupant_organizations(id), vendor_id uuid REFERENCES keystone.vendors(id),
  booked_by uuid NOT NULL, slot tstzrange NOT NULL,
  carrier_name text NOT NULL, vehicle_type text NOT NULL CHECK (vehicle_type IN ('van','rigid_truck','semi_trailer')),
  goods_type text NOT NULL CHECK (goods_type IN ('general','chilled','bulky','dangerous')),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','confirmed','checked_in','completed','no_show','cancelled')),
  access_code_hash text, approved_by uuid, checked_in_at timestamptz, checked_out_at timestamptz,
  cancelled_at timestamptz, cancelled_by uuid, cancel_reason text,
  CONSTRAINT ck_dock_cancel CHECK (status <> 'cancelled' OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL)),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_dock_holder CHECK (num_nonnulls(occupant_org_id, vendor_id) = 1),
  CONSTRAINT ex_dock_slot EXCLUDE USING gist (dock_id WITH =, slot WITH &&)
    WHERE (status IN ('requested','confirmed','checked_in')) );

-- AnnexeP_Prestataires_Mobile#3
CREATE TABLE keystone.vendor_users (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,                                 -- auth.users
  person_id uuid REFERENCES keystone.persons(id),        -- renseigné pour un technicien
  portal_role keystone.vendor_portal_role NOT NULL,
  status keystone.vendor_user_status NOT NULL DEFAULT 'invited',
  invited_at timestamptz NOT NULL DEFAULT now(), activated_at timestamptz,
  mfa_enrolled boolean NOT NULL DEFAULT false,
  last_seen_at timestamptz,
  CONSTRAINT uq_vendor_user UNIQUE (tenant_id, user_id),
  CONSTRAINT ck_vendor_tech_person CHECK (portal_role <> 'technician' OR person_id IS NOT NULL)
);

-- AnnexeP_Prestataires_Mobile#3
CREATE INDEX ix_vendor_users_vendor ON keystone.vendor_users (tenant_id, vendor_id) WHERE deleted_at IS NULL;

-- AnnexeP_Prestataires_Mobile#3
CREATE FUNCTION keystone.current_vendor() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT vu.vendor_id FROM keystone.vendor_users vu
  WHERE vu.user_id = auth.uid() AND vu.tenant_id = keystone.current_tenant()
    AND vu.status = 'active' AND vu.deleted_at IS NULL $$;

-- AnnexeP_Prestataires_Mobile#3
CREATE FUNCTION keystone.current_vendor_role() RETURNS keystone.vendor_portal_role
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT portal_role FROM keystone.vendor_users
  WHERE user_id = auth.uid() AND tenant_id = keystone.current_tenant() AND status = 'active' AND deleted_at IS NULL $$;

-- AnnexeP_Prestataires_Mobile#3
-- Fonctions dérivées de current_vendor(), aucune lecture directe de vendor_users
CREATE FUNCTION keystone.current_contractor() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT v.id FROM keystone.vendors v
  WHERE v.id = keystone.current_vendor() AND 'service_provider' = ANY (v.roles) $$;

-- AnnexeP_Prestataires_Mobile#3
CREATE FUNCTION keystone.current_supplier() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT v.id FROM keystone.vendors v
  WHERE v.id = keystone.current_vendor() AND 'goods_supplier' = ANY (v.roles) $$;

-- AnnexeP_Prestataires_Mobile#10
CREATE VIEW keystone.contractor_users WITH (security_invoker = true) AS
  SELECT vu.id, vu.tenant_id, vu.vendor_id AS contractor_id, vu.user_id, vu.portal_role AS role, vu.status
  FROM keystone.vendor_users vu JOIN keystone.vendors v ON v.id = vu.vendor_id
  WHERE 'service_provider' = ANY (v.roles);

-- AnnexeP_Prestataires_Mobile#17
CREATE TABLE keystone.contractor_review_actions (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  review_id uuid NOT NULL REFERENCES keystone.contractor_reviews(id) ON DELETE CASCADE,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  action text NOT NULL, owner_side text NOT NULL CHECK (owner_side IN ('operator','vendor')),
  owner_person_id uuid REFERENCES keystone.persons(id),
  due_date date NOT NULL, success_indicator text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  closed_at timestamptz, closing_note text
);

-- AnnexeP_Prestataires_Mobile#17
CREATE INDEX ix_review_actions_due ON keystone.contractor_review_actions (tenant_id, due_date) WHERE status IN ('open','in_progress');

-- AnnexeP_Prestataires_Mobile#19
CREATE POLICY vendor_docs_portal_select ON keystone.vendor_documents FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND deleted_at IS NULL AND vendor_id = keystone.current_vendor());

-- AnnexeP_Prestataires_Mobile#19
CREATE POLICY vendor_docs_portal_insert ON keystone.vendor_documents FOR INSERT
  WITH CHECK (tenant_id = keystone.current_tenant() AND vendor_id = keystone.current_vendor()
              AND keystone.current_vendor_role() = 'admin' AND status = 'pending' AND uploaded_via = 'portal');

-- AnnexeK_Formation_Environnement#2
CREATE TABLE keystone.person_competencies (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  person_id uuid NOT NULL REFERENCES keystone.persons(id) ON DELETE CASCADE,
  competency_id uuid NOT NULL REFERENCES keystone.competencies(id),
  granted_on date NOT NULL,
  valid_until date,                          -- défaut granted_on + validity_months (trigger)
  evidence_document_id uuid REFERENCES keystone.ged_documents(id),
  certificate_no text CHECK (char_length(btrim(certificate_no)) BETWEEN 1 AND 60),   -- numéro de titre d'habilitation (EV-PRS-04)
  delivered_by uuid REFERENCES keystone.persons(id),   -- animateur de l'accueil sécurité ou formateur interne (EV-PRS-05)
  status keystone.competency_status NOT NULL DEFAULT 'pending',
  source keystone.competency_source NOT NULL,
  proposed_by_vendor_id uuid REFERENCES keystone.vendors(id),
  validated_by uuid, validated_at timestamptz, rejection_reason text,
  CONSTRAINT ck_pc_dates CHECK (valid_until IS NULL OR valid_until >= granted_on),
  CONSTRAINT ck_pc_valid CHECK (status <> 'valid' OR validated_at IS NOT NULL)
);

-- AnnexeK_Formation_Environnement#2
CREATE INDEX ix_pc_expiry ON keystone.person_competencies (tenant_id, valid_until) WHERE status = 'valid';

-- AnnexeK_Formation_Environnement#2
CREATE UNIQUE INDEX uq_pc_current ON keystone.person_competencies (person_id, competency_id) WHERE status IN ('pending','valid');

-- AnnexeK_Formation_Environnement#2
-- persons.job_position_id uuid REFERENCES keystone.job_positions(id) : colonne à porter en Annexe A

CREATE TABLE keystone.competency_refusals (              -- source du refus d'affectation (KPI de formation)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  competency_id uuid NOT NULL REFERENCES keystone.competencies(id),
  context text NOT NULL CHECK (context IN ('wo_assignment','permit_worker','permit_approver','isolation','audit_lead')),
  object_id uuid NOT NULL,                   -- OT, permis ou audit refusé
  state keystone.competency_check NOT NULL,
  refused_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeK_Formation_Environnement#2
CREATE INDEX ix_crefusal ON keystone.competency_refusals (tenant_id, refused_at);

-- AnnexeK_Formation_Environnement#3
-- Index d'idempotence des refus :
CREATE UNIQUE INDEX uq_crefusal ON keystone.competency_refusals (tenant_id, person_id, competency_id, context, object_id);

-- AnnexeK_Formation_Environnement#4
CREATE TABLE keystone.training_records (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  session_id uuid NOT NULL REFERENCES keystone.training_sessions(id),
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  result keystone.training_result,
  completed_at date, certificate_document_id uuid REFERENCES keystone.ged_documents(id),
  UNIQUE (session_id, person_id)
);

-- AnnexeK_Formation_Environnement#6
CREATE TABLE keystone.env_aspects (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  location_id uuid REFERENCES keystone.locations(id),
  activity text NOT NULL,
  aspect text NOT NULL, impact text NOT NULL,
  condition keystone.aspect_condition NOT NULL DEFAULT 'normal',
  life_cycle_stage keystone.life_cycle_stage NOT NULL DEFAULT 'use',     -- perspective de cycle de vie
  severity int NOT NULL CHECK (severity BETWEEN 1 AND 5),
  frequency int NOT NULL CHECK (frequency BETWEEN 1 AND 5),
  score int GENERATED ALWAYS AS (severity * frequency) STORED,
  band keystone.risk_level GENERATED ALWAYS AS (keystone.risk_band(severity * frequency)) STORED,
  obligation_id uuid REFERENCES keystone.legal_obligations(id),          -- obligation de conformité liée
  stakeholder_concern boolean NOT NULL DEFAULT false,                   -- exigence d'une partie intéressée
  is_significant boolean NOT NULL,                                     -- trigger, règle ci-dessous
  control_measures text,
  status keystone.aspect_status NOT NULL DEFAULT 'identified',
  owner_id uuid REFERENCES keystone.persons(id),
  review_due date NOT NULL, review_reason text
);

-- AnnexeK_Formation_Environnement#6
CREATE INDEX ix_env_asp ON keystone.env_aspects (tenant_id, site_id, is_significant);

-- AnnexeK_Formation_Environnement#11
CREATE TABLE keystone.consultation_participants (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  consultation_id uuid NOT NULL REFERENCES keystone.worker_consultations(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  is_worker_representative boolean NOT NULL DEFAULT false,
  signed_at timestamptz,
  UNIQUE (consultation_id, person_id)
);

-- AnnexeK_Formation_Environnement#12
CREATE TABLE keystone.hsse_objectives (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL, site_id uuid REFERENCES atlas_core.sites(id),
  scope keystone.management_scope NOT NULL,
  code text NOT NULL, title text NOT NULL,
  kpi_code text NOT NULL,                    -- indicateur calculé (kpi_definitions, Annexe Q)
  baseline_value numeric(18,4), target_value numeric(18,4) NOT NULL, unit text NOT NULL,
  direction text NOT NULL CHECK (direction IN ('max','min')),
  due_date date NOT NULL, owner_id uuid NOT NULL REFERENCES keystone.persons(id),
  resources text, evaluation_method text NOT NULL,
  status keystone.objective_status NOT NULL DEFAULT 'active',
  cancel_reason text,
  CONSTRAINT ck_obj_cancel CHECK (status <> 'cancelled' OR cancel_reason IS NOT NULL),
  UNIQUE (tenant_id, code)
);

-- AnnexeK_Formation_Environnement#12
CREATE TABLE keystone.hsse_objective_measures (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  objective_id uuid NOT NULL REFERENCES keystone.hsse_objectives(id) ON DELETE CASCADE,
  measured_on date NOT NULL, value numeric(18,4) NOT NULL, source keystone.value_source NOT NULL,
  source_ref text CHECK (char_length(source_ref) <= 120),   -- justificatif d'une mesure manuelle (Lot 13 E10)
  UNIQUE (objective_id, measured_on)
);

-- AnnexeK_Formation_Environnement#13
CREATE TABLE keystone.management_reviews (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL,
  scope keystone.management_scope NOT NULL,
  period_start date NOT NULL, period_end date NOT NULL,
  planned_on date NOT NULL, held_on date,
  status keystone.hsse_review_status NOT NULL DEFAULT 'planned',
  inputs jsonb NOT NULL DEFAULT '{}',        -- une clé par entrée obligatoire, préremplie par prepare_management_review
  conclusions text,
  chaired_by uuid REFERENCES keystone.persons(id),
  minutes_document_id uuid REFERENCES keystone.ged_documents(id)
);

-- AnnexeK_Formation_Environnement#13
CREATE TABLE keystone.management_review_participants (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  review_id uuid NOT NULL REFERENCES keystone.management_reviews(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  UNIQUE (review_id, person_id)
);

-- AnnexePL_Planning_Equipes#7
CREATE TABLE keystone.time_off (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  person_id uuid NOT NULL REFERENCES keystone.persons(id) ON DELETE RESTRICT,
  kind keystone.time_off_kind NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status keystone.time_off_status NOT NULL DEFAULT 'requested',
  source keystone.time_off_source NOT NULL DEFAULT 'manual',
  external_ref text,                                    -- identifiant de l'absence chez Atlas People
  external_version bigint,
  note text CHECK (note IS NULL OR length(note) <= 280),   -- jamais de motif médical
  requested_by uuid,
  decided_by uuid, decided_at timestamptz, decision_reason text,
  cancelled_reason text,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT ck_timeoff_dates CHECK (ends_at > starts_at AND ends_at - starts_at <= interval '366 days'),
  CONSTRAINT ck_timeoff_decision CHECK (
       status NOT IN ('approved','rejected')
    OR source <> 'manual'
    OR (decided_by IS NOT NULL AND decided_at IS NOT NULL)),
  CONSTRAINT ck_timeoff_reject CHECK (status <> 'rejected' OR decision_reason IS NOT NULL),
  CONSTRAINT ck_timeoff_people CHECK ((source = 'atlas_people') = (external_ref IS NOT NULL)),
  CONSTRAINT uq_timeoff_ext UNIQUE (tenant_id, source, external_ref),
  CONSTRAINT ex_timeoff_overlap EXCLUDE USING gist (
    person_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
    WHERE (status IN ('requested','approved') AND deleted_at IS NULL)
);

-- AnnexePL_Planning_Equipes#7
CREATE INDEX ix_timeoff_person ON keystone.time_off USING gist (person_id, tstzrange(starts_at, ends_at, '[)'))
  WHERE status = 'approved' AND deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#7
CREATE INDEX ix_timeoff_pending ON keystone.time_off (tenant_id, status, starts_at) WHERE status = 'requested';

-- AnnexeB_GMAO_Partie2#11
CREATE TABLE keystone.work_centers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  code text NOT NULL, label text NOT NULL, description text,
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,       -- NULL : tous les sites
  workshop_location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  opening_hours jsonb NOT NULL,                 -- {"mon":[["07:00","19:00"]], ..., "on_call_24h": false}
  labor_rate bigint CHECK (labor_rate >= 0),    -- coût horaire, unité de la devise
  currency char(3),
  default_vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE SET NULL,
  manager_person_id uuid REFERENCES keystone.persons(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_wc_code UNIQUE (tenant_id, code),
  CONSTRAINT ck_wc_rate CHECK (labor_rate IS NULL OR currency IS NOT NULL) );

-- AnnexeB_GMAO_Partie2#11
CREATE TABLE keystone.work_center_categories (
  work_center_id uuid NOT NULL REFERENCES keystone.work_centers(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES keystone.asset_categories(id) ON DELETE RESTRICT,
  tenant_id uuid NOT NULL,
  PRIMARY KEY (work_center_id, category_id) );

-- AnnexeB_GMAO_Partie3#15
CREATE TABLE keystone.meter_reading_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  name text NOT NULL,
  recurrence jsonb NOT NULL,                    -- {"freq":"monthly","day":1} ou {"freq":"weekly","weekday":1}
  assignee_id uuid REFERENCES keystone.persons(id),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid );

-- AnnexeB_GMAO_Partie3#15
CREATE TABLE keystone.meter_reading_round_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  round_id uuid NOT NULL REFERENCES keystone.meter_reading_rounds(id) ON DELETE CASCADE,
  due_on date NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','done','missed')),
  started_at timestamptz, completed_at timestamptz, performed_by uuid,
  CONSTRAINT uq_round_run UNIQUE (round_id, due_on) );

-- AnnexeAM_AMDEC_Fiabilite#4
CREATE TABLE keystone.am_objectives (            -- objectifs de gestion d'actifs, ISO 55001:2024 §6.2
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  samp_id uuid NOT NULL REFERENCES keystone.samp(id) ON DELETE CASCADE,
  label text NOT NULL,
  kpi_code text NOT NULL,                        -- kpi_definitions.code (Annexe Q), ex. KPI-MNT-01
  scope_filter jsonb NOT NULL DEFAULT '{}',      -- site, catégorie, criticité
  baseline_value numeric(18,4), target_value numeric(18,4) NOT NULL,
  direction text NOT NULL CHECK (direction IN ('higher_is_better','lower_is_better')),
  due_date date NOT NULL,
  owner_person_id uuid NOT NULL REFERENCES keystone.persons(id),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','achieved','missed','cancelled')),
  cancel_reason text,
  CONSTRAINT ck_obj_cancel CHECK (status <> 'cancelled' OR cancel_reason IS NOT NULL) );

-- AnnexeAM_AMDEC_Fiabilite#5
CREATE TABLE keystone.asset_data_requirements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  samp_id uuid NOT NULL REFERENCES keystone.samp(id) ON DELETE CASCADE,
  object text NOT NULL,                          -- table ou objet (assets, asset_components, asset_meters, asset_downtimes)
  attribute text NOT NULL,                       -- colonne exigée
  scope_filter jsonb NOT NULL DEFAULT '{}',      -- criticité, catégorie, site
  quality_rule text NOT NULL CHECK (quality_rule IN ('present','valid_code','recent_90d','consistent')),
  owner_person_id uuid NOT NULL REFERENCES keystone.persons(id),
  target_pct numeric(5,2) NOT NULL DEFAULT 95 CHECK (target_pct BETWEEN 0 AND 100) );

-- AnnexeC_HSSE_Partie3#4
CREATE TABLE keystone.audit_team (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  audit_id uuid NOT NULL REFERENCES keystone.audits(id) ON DELETE CASCADE,
  person_id uuid REFERENCES keystone.persons(id), external_name text,
  role keystone.audit_team_role NOT NULL,
  performance_rating int CHECK (performance_rating BETWEEN 1 AND 5),   -- évaluation de l'auditeur (§7.6)
  evaluated_by uuid, evaluated_at timestamptz,
  CONSTRAINT ck_at_who CHECK (person_id IS NOT NULL OR external_name IS NOT NULL)
);

-- AnnexeC_HSSE_Partie3#4
CREATE UNIQUE INDEX uq_audit_lead ON keystone.audit_team (audit_id) WHERE role = 'lead';

-- AnnexeC_HSSE_Partie3#4
CREATE TABLE keystone.auditees (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  audit_id uuid NOT NULL REFERENCES keystone.audits(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  function text, process text,
  UNIQUE (audit_id, person_id)
);

-- AnnexeC_HSSE_Partie3#4
CREATE TABLE keystone.audit_schedule_slots (          -- programme horaire du plan d'audit (ISO 19011:2026 §6.3.2)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  audit_id uuid NOT NULL REFERENCES keystone.audits(id) ON DELETE CASCADE,
  position int NOT NULL CHECK (position >= 1),
  starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL,
  process text NOT NULL CHECK (char_length(btrim(process)) BETWEEN 2 AND 120),
  location_id uuid REFERENCES keystone.locations(id),
  auditee_id uuid REFERENCES keystone.persons(id),         -- personne de auditees du même audit (trigger)
  CONSTRAINT ck_ass_time CHECK (ends_at > starts_at),
  UNIQUE (audit_id, position)
);

-- AnnexeC_HSSE_Partie4#2
CREATE TABLE keystone.medical_visits (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  kind keystone.medical_visit_kind NOT NULL,
  visit_date date NOT NULL CHECK (visit_date <= current_date),
  practitioner_enc bytea,                  -- chiffré : médecin du travail ou service
  fitness_enc bytea NOT NULL,              -- chiffré : valeur de keystone.fitness_decision
  restrictions_enc bytea,                  -- chiffré : restrictions d'aptitude
  next_due date,                           -- prochaine visite, en clair pour le planning
  document_ids uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(document_ids) <= 10),   -- bucket privé « hsse-health » (C.28.1)
  retain_until date NOT NULL,
  key_version int NOT NULL DEFAULT 1,
  corrected_at timestamptz,                -- correction d'une saisie erronée (C.28.3)
  corrected_by uuid REFERENCES keystone.persons(id),
  correction_reason_enc bytea,             -- chiffré : motif de la correction
  replaced_by_id uuid REFERENCES keystone.medical_visits(id),
  CONSTRAINT ck_mv_next_due CHECK (next_due IS NULL OR next_due > visit_date),
  CONSTRAINT ck_mv_correction CHECK ((corrected_at IS NULL) = (corrected_by IS NULL)
    AND (corrected_at IS NULL) = (correction_reason_enc IS NULL))
);

-- AnnexeC_HSSE_Partie4#2
CREATE INDEX ix_mv_due ON keystone.medical_visits (tenant_id, next_due) WHERE deleted_at IS NULL AND corrected_at IS NULL;

-- AnnexeC_HSSE_Partie4#2
CREATE TRIGGER trg_mv_docs BEFORE INSERT OR UPDATE OF document_ids ON keystone.medical_visits
  FOR EACH ROW EXECUTE FUNCTION keystone.tg_check_document_ids('document_ids');

-- AnnexeC_HSSE_Partie4#2
-- Annexe A partie 3 §A.10.1

CREATE TABLE keystone.occupational_exposures (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  work_unit_id uuid REFERENCES keystone.work_units(id),       -- unité de travail du registre des risques
  family keystone.exposure_family NOT NULL,
  agent_enc bytea NOT NULL,                -- chiffré : agent précis (substance, source de bruit)
  value_enc bytea NOT NULL,                -- chiffré : valeur mesurée
  unit text NOT NULL,
  limit_value numeric(12,4),               -- valeur limite d'exposition applicable, en clair (référentiel pays)
  exceeds_limit boolean NOT NULL,          -- calculé par la RPC à l'écriture, en clair
  measured_at timestamptz NOT NULL,
  method text NOT NULL,                    -- prélèvement individuel, dosimètre, estimation
  retain_until date NOT NULL,
  key_version int NOT NULL DEFAULT 1,
  corrected_at timestamptz, corrected_by uuid REFERENCES keystone.persons(id), correction_reason_enc bytea,
  replaced_by_id uuid REFERENCES keystone.occupational_exposures(id),
  CONSTRAINT ck_oe_correction CHECK ((corrected_at IS NULL) = (corrected_by IS NULL)
    AND (corrected_at IS NULL) = (correction_reason_enc IS NULL))
);

-- AnnexeC_HSSE_Partie4#2
CREATE INDEX ix_oe_person ON keystone.occupational_exposures (tenant_id, person_id, measured_at DESC) WHERE corrected_at IS NULL;

-- AnnexeC_HSSE_Partie4#3
ALTER TABLE keystone.medical_visits ENABLE ROW LEVEL SECURITY;

-- AnnexeC_HSSE_Partie4#6
ALTER TABLE keystone.duer_versions
  ADD COLUMN signature_status text CHECK (signature_status IN ('requested','signed','refused','expired')),
  ADD COLUMN signature_requested_at timestamptz, ADD COLUMN signature_requested_by uuid,
  ADD COLUMN signer_person_id uuid REFERENCES keystone.persons(id),
  ADD COLUMN signed_by uuid,                              -- personne signataire confirmée par Advist
  ADD COLUMN rfc3161_ts text,                             -- jeton d'horodatage RFC 3161 renvoyé par Advist
  ADD CONSTRAINT ck_duer_signed CHECK (signature_status IS DISTINCT FROM 'signed'
    OR (advist_signature_token IS NOT NULL AND signed_at IS NOT NULL AND rfc3161_ts IS NOT NULL));

-- AnnexeR_Reglementaire_SSI#5
CREATE TABLE keystone.site_fire_settings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL UNIQUE REFERENCES atlas_core.sites(id),
  target_evac_time_sec int CHECK (target_evac_time_sec > 0),     -- cible à fixer avec la cliente par site
  min_drills_per_year int NOT NULL DEFAULT 1 CHECK (min_drills_per_year >= 0),
  ssi_manager_person_id uuid REFERENCES keystone.persons(id)
);

-- AnnexeP_Prestataires_Mobile_Partie2#4
CREATE TABLE keystone.device_sessions (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  user_id uuid NOT NULL, person_id uuid REFERENCES keystone.persons(id),
  device_label text NOT NULL,                            -- « Android, Chrome 130 »
  install_id uuid NOT NULL,                              -- généré à l'installation de la PWA
  webauthn_credential_id text,
  app_version text NOT NULL,
  last_sync_at timestamptz, last_seen_at timestamptz, last_ip inet,
  offline_max_hours integer NOT NULL DEFAULT 72 CHECK (offline_max_hours BETWEEN 8 AND 168),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked','wiped','expired')),
  revoked_by uuid, revoked_at timestamptz, revoke_reason text, wiped_at timestamptz,
  pending_mutations_at_revoke integer,
  key_escrow bytea,                                      -- clé de données locale chiffrée par une clé serveur, rendue après reconnexion complète (L7-02)
  current_site_id uuid REFERENCES atlas_core.sites(id),  -- site courant, facultatif (L7-03)
  CONSTRAINT uq_device_install UNIQUE (tenant_id, install_id)
);

-- AnnexeP_Prestataires_Mobile_Partie2#4
CREATE INDEX ix_device_user ON keystone.device_sessions (tenant_id, user_id) WHERE status = 'active';

-- AnnexeM_Mode_Prestataire#2
CREATE TABLE keystone.clients (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  code text NOT NULL, name text NOT NULL, legal_name text,
  sector_code text,  -- liste fermée (Lot 11 §13 évolution 22)
  tax_id text, rccm text, country char(2) NOT NULL DEFAULT 'CI',
  primary_contact_name text, primary_contact_email text, primary_contact_phone text,
  account_manager_id uuid REFERENCES keystone.persons(id),
  status keystone.client_status NOT NULL DEFAULT 'prospect',
  onboarded_on date, churned_on date, churn_reason text,
  trade_customer_id text,                                -- identifiant du client dans Atlas Trade (IF.2)
  logo_document_id uuid REFERENCES keystone.ged_documents(id) ON DELETE SET NULL,  -- L11-23 : PNG ou SVG, 1 Mo, affiché si client_logo_enabled
  CONSTRAINT uq_client_code UNIQUE (tenant_id, code)
);

-- AnnexeM_Mode_Prestataire#2
CREATE INDEX ix_clients_status ON keystone.clients (tenant_id, status) WHERE deleted_at IS NULL;

-- AnnexeM_Mode_Prestataire#3
CREATE TABLE keystone.client_users (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  client_id uuid NOT NULL REFERENCES keystone.clients(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  full_name text NOT NULL, email text NOT NULL,
  role keystone.client_role NOT NULL DEFAULT 'reader',
  approval_limit bigint NOT NULL DEFAULT 0 CHECK (approval_limit >= 0),
  mfa_required boolean NOT NULL DEFAULT true,
  status keystone.client_user_status NOT NULL DEFAULT 'invited',
  invited_by uuid NOT NULL, activated_at timestamptz, last_seen_at timestamptz,
  CONSTRAINT uq_client_user UNIQUE (tenant_id, user_id),
  CONSTRAINT ck_client_mfa CHECK (role NOT IN ('approver','client_admin') OR mfa_required)
);

-- AnnexeM_Mode_Prestataire#3
CREATE TABLE keystone.client_user_sites (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  client_user_id uuid NOT NULL REFERENCES keystone.client_users(id) ON DELETE CASCADE,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  CONSTRAINT uq_client_user_site UNIQUE (client_user_id, site_id)
);

-- AnnexeM_Mode_Prestataire#3
CREATE FUNCTION keystone.current_client() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT client_id FROM keystone.client_users
  WHERE user_id = auth.uid() AND tenant_id = keystone.current_tenant() AND status = 'active' AND deleted_at IS NULL $$;

-- AnnexeM_Mode_Prestataire#3
CREATE FUNCTION keystone.current_client_user() RETURNS keystone.client_users
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT * FROM keystone.client_users
  WHERE user_id = auth.uid() AND tenant_id = keystone.current_tenant() AND status = 'active' AND deleted_at IS NULL $$;

-- AnnexeM_Mode_Prestataire#4
CREATE TABLE keystone.service_contracts (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  client_id uuid NOT NULL REFERENCES keystone.clients(id) ON DELETE RESTRICT,
  ref text NOT NULL, title text NOT NULL, scope text,
  pricing_model keystone.pricing_model NOT NULL,
  base_amount bigint CHECK (base_amount >= 0),           -- forfait par période (fixed) ou taux (per_m2, per_asset)
  billing_period keystone.billing_period,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  vat_rate numeric(7,4) NOT NULL,                        -- country_config du client
  sla_terms jsonb NOT NULL DEFAULT '{}',                 -- schéma M.2.3
  penalty_terms jsonb,                                   -- schéma M.2.4
  markup_pct numeric(7,4) NOT NULL DEFAULT 0 CHECK (markup_pct >= 0),  -- coefficient contractuel des travaux variables
  labor_rates jsonb,                                     -- taux horaires de vente par qualification (évolution, à valider)
  quote_approval_threshold bigint NOT NULL DEFAULT 250000 CHECK (quote_approval_threshold >= 0),  -- D17
  client_po_required boolean NOT NULL DEFAULT false,
  client_acceptance_required boolean NOT NULL DEFAULT false,  -- D16
  client_acceptance_days smallint NOT NULL DEFAULT 5 CHECK (client_acceptance_days BETWEEN 1 AND 30),
  client_acceptance_tacit boolean NOT NULL DEFAULT true,
  penalty_detail_visible boolean NOT NULL DEFAULT true,
  client_logo_enabled boolean NOT NULL DEFAULT false,
  occupant_portal_branding keystone.portal_branding NOT NULL DEFAULT 'fm',
  fitout_management keystone.fitout_mgmt NOT NULL DEFAULT 'none',
  permit_client_visa text[] NOT NULL DEFAULT '{}' CHECK (permit_client_visa <@ ARRAY['hot_work','work_at_height','electrical','confined_space','excavation','lifting']),  -- D19 : rubriques à viser par le client
  client_space_layers_visible boolean NOT NULL DEFAULT true,
  client_reports_enabled boolean NOT NULL DEFAULT true,  -- publication des rapports au portail client (A90)
  client_security_kpis_visible boolean NOT NULL DEFAULT false,  -- v_client_security_kpis (Annexe U.10, CL.3, Lot 14 §9)
  energy_reporting_enabled boolean NOT NULL DEFAULT false,
  energy_recharge_enabled boolean NOT NULL DEFAULT false,
  start_date date NOT NULL, end_date date,
  renewal_mode text NOT NULL DEFAULT 'express' CHECK (renewal_mode IN ('tacit','express')),
  renewal_notice_days smallint CHECK (renewal_notice_days BETWEEN 0 AND 365),  -- L11-25 : préavis de dénonciation
  renewal_term_months smallint CHECK (renewal_term_months BETWEEN 1 AND 60),   -- durée de chaque reconduction tacite (évolution, à valider)
  status keystone.contract_status NOT NULL DEFAULT 'draft',
  signed_document_id uuid REFERENCES keystone.ged_documents(id),
  trade_contract_ref text,                               -- référence côté Atlas Trade (IF.2)
  CONSTRAINT uq_contract_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_contract_dates CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT ck_contract_tacit CHECK (renewal_mode <> 'tacit' OR (end_date IS NOT NULL AND renewal_notice_days IS NOT NULL AND renewal_term_months IS NOT NULL)),
  CONSTRAINT ck_contract_pricing CHECK (
    (pricing_model = 'time_and_material') OR (base_amount IS NOT NULL AND billing_period IS NOT NULL))
);

-- AnnexeM_Mode_Prestataire#4
CREATE INDEX ix_contract_client ON keystone.service_contracts (tenant_id, client_id);

-- AnnexeM_Mode_Prestataire#4
CREATE INDEX ix_contract_active ON keystone.service_contracts (tenant_id) WHERE status = 'active';

-- AnnexeM_Mode_Prestataire#5
CREATE TABLE keystone.service_contract_amendments (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  contract_id uuid NOT NULL REFERENCES keystone.service_contracts(id) ON DELETE CASCADE,
  number smallint NOT NULL,                              -- 1, 2, 3
  effective_date date NOT NULL,
  changes jsonb NOT NULL,                                -- { "base_amount": 4500000, "sla_terms": {...}, "scope_add": [...], "scope_remove": [...] }
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','signed','cancelled')),
  signed_document_id uuid REFERENCES keystone.ged_documents(id), signed_at timestamptz,
  CONSTRAINT uq_amendment UNIQUE (contract_id, number)
);

-- AnnexeM_Mode_Prestataire#7
CREATE TABLE keystone.mobilization_projects (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- MOB-2026-000003
  name text NOT NULL, kind keystone.mobilization_kind NOT NULL,
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE SET NULL,
  building_id uuid REFERENCES atlas_core.buildings(id),
  client_id uuid REFERENCES keystone.clients(id) ON DELETE SET NULL,
  service_contract_id uuid REFERENCES keystone.service_contracts(id) ON DELETE SET NULL,
  vendor_id uuid REFERENCES keystone.vendors(id),
  maintenance_contract_id uuid REFERENCES keystone.maintenance_contracts(id),
  template_id uuid REFERENCES keystone.mobilization_templates(id),
  project_manager_id uuid NOT NULL REFERENCES keystone.persons(id),
  status keystone.mobilization_status NOT NULL DEFAULT 'draft',
  start_date date, target_go_live date NOT NULL, actual_go_live date,
  readiness_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (readiness_pct BETWEEN 0 AND 100),
  visible_to_client boolean NOT NULL DEFAULT true,
  CONSTRAINT uq_mob_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_mob_takeover CHECK (kind <> 'takeover' OR (client_id IS NOT NULL AND service_contract_id IS NOT NULL AND site_id IS NOT NULL)),
  CONSTRAINT ck_mob_building CHECK (kind <> 'building_opening' OR building_id IS NOT NULL),
  CONSTRAINT ck_mob_vendor CHECK (kind <> 'vendor_contract_start' OR (vendor_id IS NOT NULL AND maintenance_contract_id IS NOT NULL)),
  CONSTRAINT ck_mob_site CHECK (kind NOT IN ('site_opening','pre_opening') OR site_id IS NOT NULL),
  works_handover_date date,                              -- pre_opening : date de réception des ouvrages, départ des garanties
  CONSTRAINT ck_mob_preopen CHECK (kind = 'pre_opening' OR works_handover_date IS NULL),
  CONSTRAINT ck_mob_dates CHECK (start_date IS NULL OR start_date <= target_go_live)
);

-- AnnexeM_Mode_Prestataire#7
CREATE INDEX ix_mob_status ON keystone.mobilization_projects (tenant_id, status) WHERE deleted_at IS NULL;

-- AnnexeM_Mode_Prestataire#8
CREATE TABLE keystone.mobilization_staff_transfers (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  project_id uuid NOT NULL REFERENCES keystone.mobilization_projects(id) ON DELETE CASCADE,
  full_name text NOT NULL, job_title text NOT NULL, previous_employer text,
  decision keystone.staff_transfer_decision NOT NULL DEFAULT 'pending',
  start_date date,
  person_id uuid REFERENCES keystone.persons(id),
  people_ref text,                                       -- référence Atlas People (IF.6)
  CONSTRAINT ck_transfer_start CHECK (decision <> 'retained' OR start_date IS NOT NULL)
);

-- AnnexeM_Mode_Prestataire#8
CREATE INDEX ix_transfer_project ON keystone.mobilization_staff_transfers (tenant_id, project_id);

-- AnnexeM_Mode_Prestataire_Partie2#3
CREATE TABLE keystone.client_invoices_cache (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  trade_invoice_id text NOT NULL,
  number text NOT NULL,
  document_type text NOT NULL CHECK (document_type IN ('invoice','credit_note')),
  credited_invoice_id text,
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  contract_id uuid REFERENCES keystone.service_contracts(id),
  period date,
  issue_date date NOT NULL, due_date date NOT NULL,
  amount_ht bigint NOT NULL, vat_amount bigint NOT NULL, amount_ttc bigint NOT NULL,
  penalties_ht bigint NOT NULL DEFAULT 0,                -- somme des lignes de pénalité, négative
  paid_amount bigint NOT NULL DEFAULT 0,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.trade_invoice_status NOT NULL,
  lines jsonb NOT NULL,                                  -- [{ "trade_line_id", "billable_item_id", "label", "amount_ht" }]
  pdf_object_key text,                                   -- lien signé à la demande
  trade_version bigint NOT NULL,                         -- version de l'événement, rejet des anciennes
  synced_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_trade_invoice UNIQUE (tenant_id, trade_invoice_id),
  CONSTRAINT ck_cache_ttc CHECK (amount_ttc = amount_ht + vat_amount)
);

-- AnnexeM_Mode_Prestataire_Partie2#3
CREATE INDEX ix_cache_client ON keystone.client_invoices_cache (tenant_id, client_id, issue_date);

-- AnnexeM_Mode_Prestataire_Partie2#4
CREATE TABLE keystone.governance_meetings (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  contract_id uuid REFERENCES keystone.service_contracts(id),
  kind text NOT NULL CHECK (kind IN ('monthly','quarterly','annual','extraordinary')),
  scheduled_at timestamptz NOT NULL,
  participants jsonb NOT NULL DEFAULT '[]',              -- [{ "name", "side": "fm"|"client", "role" }]
  agenda jsonb NOT NULL DEFAULT '[]',                    -- [{ "title", "proposed_by_side", "action_item_id" }]
  minutes_document_id uuid REFERENCES keystone.ged_documents(id),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','held','cancelled')),
  published_to_client boolean NOT NULL DEFAULT false
);

-- AnnexeM_Mode_Prestataire_Partie2#4
CREATE TABLE keystone.action_items (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  origin text NOT NULL CHECK (origin IN ('meeting','audit','reserve','dispute','review','other')),
  origin_id uuid,
  title text NOT NULL, description text,
  owner_side text NOT NULL CHECK (owner_side IN ('fm','client')),
  owner_person_id uuid REFERENCES keystone.persons(id),
  owner_client_user_id uuid REFERENCES keystone.client_users(id),
  due_date date NOT NULL,
  progress_pct smallint NOT NULL DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  visible_to_client boolean NOT NULL DEFAULT true,
  CONSTRAINT ck_action_owner CHECK ((owner_side = 'fm' AND owner_client_user_id IS NULL) OR (owner_side = 'client' AND owner_person_id IS NULL))
);

-- AnnexeM_Mode_Prestataire_Partie2#4
CREATE INDEX ix_action_due ON keystone.action_items (tenant_id, client_id, due_date) WHERE status IN ('open','in_progress');

-- AnnexeM_Mode_Prestataire_Partie2#4
CREATE TABLE keystone.client_messages (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  object_type text NOT NULL CHECK (object_type IN ('work_order','client_quote','action_item','client_dispute','service_contract','report_publication','mobilization')),
  object_id uuid NOT NULL,
  author_id uuid NOT NULL, author_side text NOT NULL CHECK (author_side IN ('fm','client')),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  attachment_ids uuid[] NOT NULL DEFAULT '{}',
  read_by_other_at timestamptz
);

-- AnnexeM_Mode_Prestataire_Partie2#4
CREATE INDEX ix_cmsg_object ON keystone.client_messages (tenant_id, object_type, object_id, created_at);

-- AnnexeCL_Portail_Client#2
CREATE TABLE keystone.report_publications (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  report_run_id uuid NOT NULL REFERENCES keystone.report_runs(id),
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  site_ids uuid[] NOT NULL DEFAULT '{}',                 -- vide : tous les sites du client
  title text NOT NULL, comment text,
  period_start date, period_end date,
  published_by uuid NOT NULL, published_at timestamptz NOT NULL DEFAULT now(),
  withdrawn_by uuid, withdrawn_at timestamptz, withdraw_reason text,
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id)                              -- PDF figé à la publication (GED)
);

-- AnnexeCL_Portail_Client#2
CREATE INDEX ix_pub_client ON keystone.report_publications (tenant_id, client_id, published_at) WHERE withdrawn_at IS NULL;

-- AnnexeIF_Interfaces#3
CREATE TABLE keystone.payment_requests (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- FRA-2026-000012
  kind text NOT NULL CHECK (kind IN ('occupant_fee','advance_payment')),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  occupant_org_id uuid REFERENCES keystone.occupant_organizations(id),
  payer_person_id uuid REFERENCES keystone.persons(id),
  label text NOT NULL,                                   -- badge supplémentaire, prestation à la demande, acompte de réservation
  related_object_type text, related_object_id uuid,      -- ticket, space_booking, service_contract
  amount bigint NOT NULL CHECK (amount > 0 AND amount % 5 = 0),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  vat_rate numeric(7,4) NOT NULL,                        -- country_config ; 0 pour un acompte
  beneficiary_kind text NOT NULL DEFAULT 'tenant' CHECK (beneficiary_kind IN ('tenant','client')),
  beneficiary_client_id uuid REFERENCES keystone.clients(id),
  due_date date,
  status keystone.payment_request_status NOT NULL DEFAULT 'open',
  paid_intent_id uuid,
  CONSTRAINT uq_payment_request_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_payreq_benef CHECK ((beneficiary_kind = 'client') = (beneficiary_client_id IS NOT NULL))
);

-- AnnexeIF_Interfaces#4
-- keystone.payment_purpose : défini en IF.4.0
-- keystone.payment_status : défini en IF.4.0

CREATE TABLE keystone.payment_intents (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  transaction_id text NOT NULL CHECK (transaction_id ~ '^KS[0-9A-Z]{10,20}$'),  -- unique, transmis à CinetPay
  purpose keystone.payment_purpose NOT NULL,
  object_type text NOT NULL REFERENCES keystone.payment_handlers(object_type),   -- registre IF.4.0
  object_id uuid NOT NULL,                               -- objet payé (Annexe PK, D, TA)
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  payer_occupant_org_id uuid, payer_person_id uuid, payer_phone text,
  beneficiary_kind text NOT NULL CHECK (beneficiary_kind IN ('tenant','client')),
  beneficiary_client_id uuid REFERENCES keystone.clients(id),
  amount bigint NOT NULL CHECK (amount > 0 AND amount % 5 = 0),   -- multiple de 5 exigé par CinetPay en XOF et XAF
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  description text NOT NULL CHECK (char_length(description) <= 255),
  channels text NOT NULL DEFAULT 'ALL' CHECK (channels IN ('ALL','MOBILE_MONEY','CREDIT_CARD','WALLET')),
  status keystone.payment_status NOT NULL DEFAULT 'created',
  payment_token text, payment_url text,
  payment_method text, operator_id text, paid_at timestamptz, fund_availability_date date,
  last_check_code text, last_check_message text, last_check_at timestamptz, check_count smallint NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  fna_export_status text NOT NULL DEFAULT 'none' CHECK (fna_export_status IN ('none','pending','sent','acknowledged','failed')),
  CONSTRAINT uq_payment_tx UNIQUE (tenant_id, transaction_id),
  CONSTRAINT ck_payment_beneficiary CHECK ((beneficiary_kind = 'client') = (beneficiary_client_id IS NOT NULL))
);

-- AnnexeIF_Interfaces#4
CREATE INDEX ix_payment_pending ON keystone.payment_intents (tenant_id, status, last_check_at) WHERE status IN ('created','pending');

-- AnnexeIF_Interfaces#4
CREATE TABLE keystone.payment_reconciliation_issues (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  payment_intent_id uuid REFERENCES keystone.payment_intents(id),
  business_date date NOT NULL,
  issue text NOT NULL CHECK (issue IN ('missing_in_keystone','missing_in_provider','amount_mismatch','status_mismatch')),
  provider_data jsonb, status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dismissed')),
  resolved_by uuid, resolution_note text
);

-- AnnexeU_Surete_Accueil#4
CREATE TABLE keystone.physical_access_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  period_start date NOT NULL, period_end date NOT NULL, due_date date NOT NULL,
  reviewer_id uuid NOT NULL REFERENCES keystone.persons(id),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  closed_at timestamptz, closed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid );

-- AnnexeU_Surete_Accueil#6
CREATE TABLE keystone.security_handover (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, post_code text NOT NULL,
  outgoing_agent_id uuid NOT NULL REFERENCES keystone.persons(id), incoming_agent_id uuid REFERENCES keystone.persons(id),
  planned_end timestamptz NOT NULL, instructions text, ongoing_events text,
  keys_equipment jsonb NOT NULL DEFAULT '[]',         -- [{"item":text,"state":"present|missing|faulty"}]
  outgoing_signed_at timestamptz, incoming_signed_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, site_id, post_code) REFERENCES keystone.security_posts(tenant_id, site_id, code),
  CONSTRAINT ck_handover_agents CHECK (incoming_agent_id IS NULL OR incoming_agent_id <> outgoing_agent_id),
  CONSTRAINT ck_handover_keys CHECK (jsonb_matches_schema(keystone.json_schema('handover_keys_equipment/v1'), keys_equipment)) );

-- AnnexeU_Surete_Accueil#8
CREATE TABLE keystone.visitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  full_name text NOT NULL, company text,
  contact text,                                     -- email ou téléphone pour l'envoi du code de visite
  host_person_id uuid REFERENCES keystone.persons(id),
  host_occupant_user_id uuid REFERENCES keystone.occupant_users(id),
  purge_after date NOT NULL,                        -- date de la dernière visite plus 90 jours (A56)
  legal_hold boolean NOT NULL DEFAULT false,        -- rattachement à un événement de sûreté ou HSSE ouvert
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_visitor_host CHECK (num_nonnulls(host_person_id, host_occupant_user_id) = 1) );

-- AnnexeU_Surete_Accueil#10
CREATE TABLE keystone.mail_parcels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, received_at timestamptz NOT NULL DEFAULT now(),
  carrier text NOT NULL, tracking_ref text,
  recipient_occupant_org_id uuid REFERENCES keystone.occupant_organizations(id),
  recipient_person_id uuid REFERENCES keystone.persons(id), recipient_label text,
  status keystone.parcel_status NOT NULL DEFAULT 'received',
  notified_at timestamptz, delivered_at timestamptz, signed_by text, signature_path text, returned_at timestamptz,
  signature_method keystone.signature_method,          -- Annexe C.7.1 ; drawn (tracé) ou typed (saisie du nom, Lot 15 E17)
  typed_name text,
  received_by uuid NOT NULL,
  CONSTRAINT ck_parcel_method CHECK (signature_method IS NULL OR signature_method IN ('drawn','typed')),
  CONSTRAINT ck_parcel_delivery CHECK (status <> 'delivered' OR (signed_by IS NOT NULL AND (
       (signature_method = 'drawn' AND signature_path IS NOT NULL)
    OR (signature_method = 'typed' AND typed_name IS NOT NULL)))) );

-- AnnexeU_Surete_Accueil_Partie2#2
CREATE TABLE keystone.crisis_drills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                       -- CRX-AAAA-NNNNNN
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  scenario keystone.crisis_scenario NOT NULL,
  scenario_detail text,
  format keystone.crisis_drill_format NOT NULL,
  is_unannounced boolean NOT NULL DEFAULT false,
  planned_date date NOT NULL,
  objectives text[] NOT NULL CHECK (cardinality(objectives) BETWEEN 1 AND 20),
  coordinator_id uuid NOT NULL REFERENCES keystone.persons(id),
  observer_ids uuid[] NOT NULL DEFAULT '{}',
  held_on date,
  started_at timestamptz, ended_at timestamptz,
  alert_to_response_sec int CHECK (alert_to_response_sec > 0),   -- délai entre l'alerte et la première action de réponse
  participants int CHECK (participants >= 0),
  external_services jsonb NOT NULL DEFAULT '[]',          -- [{"service":"police|firefighters|samu|other","involved":bool}]
  findings text,
  report_document_id uuid REFERENCES keystone.ged_documents(id),
  status keystone.crisis_drill_status NOT NULL DEFAULT 'planned',
  cancel_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_crisis_drill_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_crx_done CHECK (status NOT IN ('done','analysed') OR (held_on IS NOT NULL AND participants IS NOT NULL)),
  CONSTRAINT ck_crx_times CHECK (ended_at IS NULL OR started_at IS NULL OR ended_at > started_at),
  CONSTRAINT ck_crx_cancel CHECK ((status = 'cancelled') = (cancel_reason IS NOT NULL)),
  CONSTRAINT ck_crx_analysed CHECK (status <> 'analysed' OR findings IS NOT NULL)
);

-- AnnexeU_Surete_Accueil_Partie2#2
CREATE INDEX ix_crx_site ON keystone.crisis_drills (tenant_id, site_id, planned_date DESC) WHERE deleted_at IS NULL;

-- AnnexeU_Surete_Accueil_Partie2#2
ALTER TABLE keystone.crisis_drills ENABLE ROW LEVEL SECURITY;

-- AnnexeQ_Reporting#4
-- Règle : le changement climatique est un enjeu à examiner pour chaque système (ISO 41001:2018, édition en vigueur,
-- D27 ; amendements 1:2024 d'ISO 9001, ISO 14001, ISO 45001, ISO 50001 et ISO/IEC 27001 sur les §4.1 et §4.2) :
-- prepare_fm_management_review signale l'absence d'une ligne active de thème climate (avertissement CLIMATE_ISSUE_MISSING).

CREATE TABLE keystone.fm_stakeholders (              -- §4.2 a
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid REFERENCES atlas_core.sites(id),
  category stakeholder_category NOT NULL,
  name text NOT NULL,
  client_id uuid REFERENCES keystone.clients(id),    -- fm_provider
  vendor_id uuid REFERENCES keystone.vendors(id),
  occupant_org_id uuid,
  influence int CHECK (influence BETWEEN 1 AND 3), interest int CHECK (interest BETWEEN 1 AND 3),
  engagement_mode text,                              -- canal et fréquence d'échange
  owner_id uuid,
  review_due date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- correctif_post
-- C12 (avec la substitution S01) : secteur du client, Annexe M. La table client_sectors (Référentiels transverses) est
-- unique sur (tenant_id, code) : la référence se fait par le couple, un code n'étant unique qu'au sein d'un tenant [Confirmé].
ALTER TABLE keystone.clients
  ADD CONSTRAINT fk_clients_sector FOREIGN KEY (tenant_id, sector_code) REFERENCES keystone.client_sectors (tenant_id, code);

-- AnnexeA_Socle#3
-- Personne (persons) du compte connecté ; nom unique dans le corpus (A79)
CREATE OR REPLACE FUNCTION keystone.current_person_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT id FROM keystone.persons
  WHERE tenant_id = keystone.current_tenant() AND user_id = auth.uid()
    AND status = 'active' AND deleted_at IS NULL LIMIT 1 $$;

-- AnnexeA_Socle#14
CREATE TABLE keystone.site_ext (
  site_id              uuid PRIMARY KEY REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  tenant_id            uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ops_status           site_ops_status NOT NULL DEFAULT 'pre_opening',
  opened_on            date,
  closed_at            timestamptz,
  closed_reason        text,
  reopened_at          timestamptz,
  regulatory_suspended boolean NOT NULL DEFAULT false,   -- A46
  client_id            uuid REFERENCES keystone.clients(id) ON DELETE RESTRICT,  -- fm_provider (Annexe M)
  fire_class           text,
  atex_zone            text,
  business_calendar_id uuid REFERENCES keystone.business_calendars(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_site_closed CHECK (ops_status <> 'closed' OR (closed_at IS NOT NULL AND closed_reason IS NOT NULL))
);

-- AnnexeA_Socle#14
CREATE INDEX ix_site_ext_client ON keystone.site_ext (tenant_id, client_id);

-- AnnexeA_Socle_Partie2#2
-- Calendriers applicables au site : calendrier du site puis calendrier pays
CREATE OR REPLACE FUNCTION keystone.site_calendar_chain(p_site uuid) RETURNS SETOF uuid
LANGUAGE sql STABLE AS $$
  SELECT c.id FROM keystone.site_ext e JOIN keystone.business_calendars c ON c.id = e.business_calendar_id
   WHERE e.site_id = p_site
  UNION
  SELECT c.parent_calendar_id FROM keystone.site_ext e JOIN keystone.business_calendars c ON c.id = e.business_calendar_id
   WHERE e.site_id = p_site AND c.parent_calendar_id IS NOT NULL
  UNION
  SELECT c.id FROM atlas_core.sites s JOIN keystone.business_calendars c
    ON c.tenant_id = s.tenant_id AND c.country_code = s.country_code AND c.site_id IS NULL AND c.deleted_at IS NULL
   WHERE s.id = p_site $$;

-- AnnexeA_Socle_Partie2#5
CREATE TABLE keystone.assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,     -- recopié du lieu par trigger
  location_id uuid REFERENCES keystone.locations(id) ON DELETE RESTRICT,
  category_id uuid REFERENCES keystone.asset_categories(id) ON DELETE RESTRICT,
  parent_asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  work_center_id uuid REFERENCES keystone.work_centers(id) ON DELETE RESTRICT,   -- Annexe B
  workcenter text,                                     -- ancien libellé, lecture seule jusqu'à migration (lot 6 §1.3)
  record_status keystone.asset_record_status NOT NULL DEFAULT 'draft',   -- D29, distinct de status (A.5 bis)
  code text NOT NULL CHECK (code ~ '^[A-Z0-9][A-Z0-9-]{1,31}$'),
  name text NOT NULL,
  tag text,
  taxonomy_level smallint NOT NULL DEFAULT 6 CHECK (taxonomy_level BETWEEN 5 AND 8),   -- ISO 14224:2016
  iso14224_type_code text,                             -- type d'équipement de la classe (A.5 bis.2)
  manufacturer text, model text, serial_number text,
  serial_number_unavailable boolean NOT NULL DEFAULT false,
  manufacture_year smallint CHECK (manufacture_year BETWEEN 1900 AND 2100),
  client_asset_ref text,                               -- fm_provider : référence chez le client
  bim_guid text CHECK (bim_guid ~ '^[0-9A-Za-z_$]{22}$'),   -- GlobalId IFC
  photo_document_ids uuid[] NOT NULL DEFAULT '{}',     -- GED, tg_check_document_ids (partie 3, A.10.1)
  access_height_m numeric(5,2) CHECK (access_height_m >= 0),
  access_means text CHECK (access_means IN ('floor','ladder','scaffold','mewp','rope_access','roof','confined_space')),
  required_ppe text[] NOT NULL DEFAULT '{}',
  required_permit_sections keystone.permit_section[] NOT NULL DEFAULT '{}',
  access_windows jsonb,                                -- forme de work_centers.opening_hours ; NULL : heures du site
  key_reference text, access_notes text,
  operating_mode keystone.asset_operating_mode,
  operating_hours_per_year int CHECK (operating_hours_per_year BETWEEN 0 AND 8784),
  install_environment keystone.asset_environment,
  environment_stressors text[] NOT NULL DEFAULT '{}',
  redundancy_config keystone.redundancy_config NOT NULL DEFAULT 'n',
  required_function text, stop_impact text,
  energy_use_id uuid,                                  -- Annexe EN energy_uses, clé posée par la migration EN
  refrigerant_code text REFERENCES keystone.refrigerants(code),
  refrigerant_charge_kg numeric(10,3) CHECK (refrigerant_charge_kg > 0),
  refrigerant_gwp numeric(10,1),                       -- copié par trigger (A.5 bis.5), jamais saisi
  refrigerant_co2e_t numeric(12,3) GENERATED ALWAYS AS (round(refrigerant_charge_kg * refrigerant_gwp / 1000, 3)) STORED,
  leak_detection_installed boolean NOT NULL DEFAULT false,
  criticality asset_criticality NOT NULL DEFAULT 'medium',
  criticality_rationale text,
  redundancy_group text,
  maintenance_strategy maintenance_strategy,
  status asset_status NOT NULL DEFAULT 'operational',
  condition_rating smallint CHECK (condition_rating BETWEEN 1 AND 5),   -- A64
  condition_assessed_on date, condition_assessed_by uuid REFERENCES keystone.persons(id),
  duty_cycle duty_cycle NOT NULL DEFAULT 'site_hours',
  specs jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(specs) = 'object'),
  install_date date,
  commissioning_date date,
  warranty_until date,                                 -- tenu par trigger depuis asset_warranties
  purchase_date date,
  planned_replacement_year smallint,
  disposal_date date, disposal_reason text, disposal_mode keystone.asset_disposal_mode,
  supplier_id uuid REFERENCES keystone.vendors(id) ON DELETE RESTRICT,           -- D13
  installer_vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE RESTRICT,
  owner_kind text NOT NULL DEFAULT 'own' CHECK (owner_kind IN ('own','client')),
  owner_client_id uuid REFERENCES keystone.clients(id) ON DELETE RESTRICT,     -- Annexe M
  cost_center_code text,
  acquisition_value bigint CHECK (acquisition_value >= 0),
  book_value bigint CHECK (book_value >= 0),           -- lue depuis Atlas FNA, jamais saisie
  book_value_as_of date, fna_fixed_asset_ref text,
  replacement_value bigint CHECK (replacement_value >= 0),
  downtime_hourly_cost bigint CHECK (downtime_hourly_cost >= 0),   -- NULL : valeur de la famille
  currency char(3) REFERENCES atlas_core.currencies(code),
  depreciation_method text CHECK (depreciation_method IN ('linear','declining')),   -- lue depuis Atlas FNA
  useful_life_years int CHECK (useful_life_years > 0), -- durée de vie de conception
  is_regulated boolean NOT NULL DEFAULT false,
  is_safety_function boolean NOT NULL DEFAULT false,   -- copié de la famille à la création
  atex_zone text CHECK (atex_zone IN ('0','1','2','20','21','22')), ex_marking text,
  classified_installation_ref text,                    -- rubrique ICPE ou équivalent du pays
  conformity_markings text[] NOT NULL DEFAULT '{}',
  data_completeness_pct smallint CHECK (data_completeness_pct BETWEEN 0 AND 100),
  data_missing jsonb NOT NULL DEFAULT '[]'::jsonb,     -- [{section, field, kind}] (A.5 bis.7)
  submitted_at timestamptz, submitted_by uuid, validated_at timestamptz, validated_by uuid,
  returned_at timestamptz, returned_by uuid, return_reason text,
  label_printed_at timestamptz,                        -- première étiquette : code verrouillé
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_assets_code UNIQUE (tenant_id, code),
  CONSTRAINT ck_assets_owner CHECK ((owner_kind = 'client') = (owner_client_id IS NOT NULL)),
  CONSTRAINT ck_assets_refrigerant CHECK ((refrigerant_code IS NULL) = (refrigerant_charge_kg IS NULL)),
  CONSTRAINT ck_assets_validated CHECK (record_status <> 'validated' OR validated_at IS NOT NULL),
  CONSTRAINT ck_assets_returned CHECK (record_status <> 'returned' OR length(trim(return_reason)) >= 10),
  CONSTRAINT ck_assets_currency CHECK (num_nonnulls(acquisition_value, book_value, replacement_value) = 0 OR currency IS NOT NULL),
  CONSTRAINT ck_assets_capex CHECK (book_value IS NULL OR acquisition_value IS NULL OR book_value <= acquisition_value),
  CONSTRAINT ck_assets_no_self_parent CHECK (parent_asset_id <> id),
  CONSTRAINT ck_assets_rationale CHECK (criticality NOT IN ('high','safety_critical') OR length(trim(criticality_rationale)) >= 10),
  CONSTRAINT ck_assets_warranty CHECK (warranty_until IS NULL OR commissioning_date IS NULL OR warranty_until >= commissioning_date)
);

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_location    ON keystone.assets (tenant_id, location_id) WHERE deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_site        ON keystone.assets (tenant_id, site_id) WHERE deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_criticality ON keystone.assets (tenant_id, criticality);

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_parent      ON keystone.assets (tenant_id, parent_asset_id);

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_status      ON keystone.assets (tenant_id, status);

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_work_center ON keystone.assets (tenant_id, work_center_id);

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_redundancy  ON keystone.assets (tenant_id, site_id, redundancy_group) WHERE redundancy_group IS NOT NULL;

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_regulated   ON keystone.assets (tenant_id) WHERE is_regulated;

-- AnnexeA_Socle_Partie2#5
CREATE INDEX ix_assets_specs       ON keystone.assets USING gin (specs);

-- AnnexeA_Socle_Partie2#5
CREATE UNIQUE INDEX uq_assets_fna_ref ON keystone.assets (tenant_id, legal_entity_id, fna_fixed_asset_ref) WHERE fna_fixed_asset_ref IS NOT NULL AND deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#5
-- message fixed_asset.valued (Annexe IF)
CREATE INDEX ix_assets_record      ON keystone.assets (tenant_id, record_status) WHERE record_status <> 'validated';

-- AnnexeA_Socle_Partie2#5
CREATE UNIQUE INDEX uq_assets_serial ON keystone.assets (tenant_id, lower(manufacturer), serial_number)
  WHERE serial_number IS NOT NULL AND deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#5
-- DUPLICATE_IDENTIFIER
CREATE UNIQUE INDEX uq_assets_client_ref ON keystone.assets (tenant_id, owner_client_id, client_asset_ref)
  WHERE client_asset_ref IS NOT NULL AND deleted_at IS NULL;

-- AnnexeA_Socle_Partie2#5
-- DUPLICATE_CODE
CREATE UNIQUE INDEX uq_assets_bim  ON keystone.assets (tenant_id, bim_guid) WHERE bim_guid IS NOT NULL;

-- AnnexeA_Socle_Partie2#10
CREATE TABLE keystone.import_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  target text NOT NULL,
  mode text NOT NULL DEFAULT 'insert' CHECK (mode IN ('insert','update','history')),
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  mobilization_id uuid REFERENCES keystone.mobilization_projects(id) ON DELETE RESTRICT,   -- Annexe M.5
  file_path text NOT NULL,
  file_sha256 char(64) NOT NULL,
  file_format text NOT NULL CHECK (file_format IN ('csv','xlsx')),
  mapping_id uuid REFERENCES keystone.import_mappings(id) ON DELETE SET NULL,
  mapping jsonb,
  status import_batch_status NOT NULL DEFAULT 'uploaded',
  rows_read int NOT NULL DEFAULT 0, rows_valid int NOT NULL DEFAULT 0, rows_error int NOT NULL DEFAULT 0,
  rows_excluded int NOT NULL DEFAULT 0, rows_imported int NOT NULL DEFAULT 0,
  error_rate numeric(7,4) GENERATED ALWAYS AS (CASE WHEN rows_read > 0 THEN rows_error::numeric / rows_read END) STORED,
  confirmed_by uuid, confirmed_at timestamptz, committed_at timestamptz,
  rolled_back_by uuid, rolled_back_at timestamptz, rollback_reason text,
  failure_message text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_batch_rollback CHECK (status <> 'rolled_back' OR rollback_reason IS NOT NULL)
);

-- AnnexeA_Socle_Partie2#10
CREATE INDEX ix_import_batches ON keystone.import_batches (tenant_id, created_at DESC);

-- AnnexeA_Socle_Partie2#10
CREATE TABLE keystone.import_batch_rows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  batch_id uuid NOT NULL REFERENCES keystone.import_batches(id) ON DELETE CASCADE,
  line_no int NOT NULL CHECK (line_no > 0),
  payload jsonb NOT NULL,
  status import_row_status NOT NULL,
  errors jsonb NOT NULL DEFAULT '[]'::jsonb,          -- [{"field","code","message"}]
  target_id uuid,
  excluded_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_batch_line UNIQUE (batch_id, line_no)
);

-- AnnexeA_Socle_Partie2#10
CREATE INDEX ix_batch_rows_status ON keystone.import_batch_rows (batch_id, status);

-- AnnexeA_Socle_Partie2#10
CREATE INDEX ix_batch_rows_target ON keystone.import_batch_rows (tenant_id, target_id);

-- AnnexeA_Socle_Partie2#10
CREATE TABLE keystone.data_exports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  scope text NOT NULL CHECK (scope IN ('full','domain','client','audit')),
  domain text CHECK (domain IN ('assets','maintenance','hsse','regulatory','soft_fm','security','spaces','purchasing',
                                'budgets','vendors','occupants','documents','energy_iot','commercial','administration')),
  client_id uuid REFERENCES keystone.clients(id) ON DELETE RESTRICT,
  format text NOT NULL CHECK (format IN ('csv_zip','json_zip')),
  status export_status NOT NULL DEFAULT 'requested',
  requested_by uuid NOT NULL, requested_at timestamptz NOT NULL DEFAULT now(),
  ready_at timestamptz, file_path text, manifest_sha256 char(64), size_bytes bigint,
  expires_at timestamptz, download_count int NOT NULL DEFAULT 0, failure_message text,
  CONSTRAINT ck_export_scope CHECK ((scope = 'client') = (client_id IS NOT NULL) AND (scope <> 'domain' OR domain IS NOT NULL))
);

-- AnnexeA_Socle_Partie2#10
CREATE INDEX ix_data_exports ON keystone.data_exports (tenant_id, requested_at DESC);

-- AnnexeA_Socle_Partie3#3
CREATE TABLE keystone.asset_served_spaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  space_id uuid NOT NULL REFERENCES atlas_core.spaces(id) ON DELETE RESTRICT,
  service_role text NOT NULL DEFAULT 'primary' CHECK (service_role IN ('primary','backup')),
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_served_space UNIQUE (asset_id, space_id)
);

-- AnnexeA_Socle_Partie3#3
CREATE INDEX ix_served_space ON keystone.asset_served_spaces (tenant_id, space_id);

-- AnnexeA_Socle_Partie3#3
CREATE TABLE keystone.asset_record_events (          -- historique du cycle de la fiche (D29)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  from_status keystone.asset_record_status,
  to_status keystone.asset_record_status NOT NULL,
  completeness_pct smallint,
  comment text,                                      -- motif obligatoire pour returned
  actor uuid NOT NULL, occurred_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_record_event_reason CHECK (to_status <> 'returned' OR length(trim(comment)) >= 10)
);

-- AnnexeA_Socle_Partie3#3
CREATE INDEX ix_record_events ON keystone.asset_record_events (tenant_id, asset_id, occurred_at DESC);

-- AnnexeA_Socle_Partie3#5
CREATE OR REPLACE FUNCTION keystone.asset_validate(p_asset uuid, p_expected_updated_at timestamptz, p_comment text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE a keystone.assets; v_c jsonb;
BEGIN
  IF NOT keystone.has_permission('asset.validate') THEN
    PERFORM keystone.raise_error('PERMISSION_DENIED', jsonb_build_object('permission','asset.validate')); END IF;
  IF NOT keystone.tenant_writable() THEN PERFORM keystone.raise_error('SUBSCRIPTION_EXPIRED'); END IF;
  SELECT * INTO a FROM keystone.assets WHERE id = p_asset AND tenant_id = keystone.current_tenant() FOR UPDATE;
  IF NOT FOUND OR NOT keystone.site_in_scope(a.site_id) THEN
    PERFORM keystone.raise_error('NOT_FOUND', jsonb_build_object('id', p_asset)); END IF;
  IF a.updated_at IS DISTINCT FROM p_expected_updated_at THEN PERFORM keystone.raise_error('VERSION_CONFLICT'); END IF;
  IF a.record_status <> 'submitted' THEN
    PERFORM keystone.raise_error('INVALID_TRANSITION', jsonb_build_object('statut', a.record_status)); END IF;
  IF auth.uid() IN (a.created_by, a.submitted_by) THEN
    PERFORM keystone.raise_error('SEGREGATION_OF_DUTIES', jsonb_build_object('role','author')); END IF;
  v_c := keystone.asset_compute_completeness(p_asset);
  IF jsonb_array_length(v_c -> 'missing_required') > 0 THEN
    PERFORM keystone.raise_error('ASSET_DATA_INCOMPLETE', jsonb_build_object('missing', v_c -> 'missing_required')); END IF;
  IF a.criticality IN ('high','safety_critical') AND NOT EXISTS (SELECT 1 FROM keystone.asset_criticality_assessments c
       WHERE c.asset_id = a.id AND c.status = 'approved' AND c.result = a.criticality) THEN
    PERFORM keystone.raise_error('CRITICALITY_NOT_APPROVED', jsonb_build_object('field','criticality')); END IF;
  PERFORM set_config('keystone.record_change', 'on', true);
  UPDATE keystone.assets SET record_status = 'validated', validated_at = now(), validated_by = auth.uid()
   WHERE id = a.id;
  INSERT INTO keystone.asset_record_events (tenant_id, asset_id, from_status, to_status, completeness_pct, comment, actor)
  VALUES (a.tenant_id, a.id, 'submitted', 'validated', (v_c ->> 'score')::smallint, p_comment, auth.uid());
END $$;

-- AnnexeA_Socle_Partie3#6
CREATE VIEW keystone.v_assets_fleet WITH (security_barrier) AS          -- parc : planning, indicateurs, portails
  SELECT * FROM keystone.assets WHERE record_status = 'validated' AND deleted_at IS NULL;

-- AnnexeA_Socle_Partie3#6
CREATE VIEW keystone.v_asset_life WITH (security_barrier) AS
  SELECT a.tenant_id, a.id AS asset_id,
         round(greatest(0, a.useful_life_years - (current_date - a.commissioning_date) / 365.25), 1) AS remaining_life_years,
         coalesce(a.downtime_hourly_cost, c.downtime_hourly_cost) AS downtime_hourly_cost_effective
  FROM keystone.assets a LEFT JOIN keystone.asset_categories c ON c.id = a.category_id;

-- AnnexeA_Socle_Partie3#7
ALTER TABLE keystone.assets
  ADD COLUMN description text CHECK (length(description) <= 1000),
  ADD COLUMN bim_object_name text CHECK (length(bim_object_name) <= 120),   -- nom de l'objet dans la maquette
  ADD COLUMN acquisition_mode keystone.asset_acquisition_mode,
  ADD COLUMN purchase_order_id uuid,                    -- purchase_orders, clé posée par la migration E
  ADD COLUMN purchase_invoice_ref text CHECK (length(purchase_invoice_ref) <= 60),
  ADD COLUMN depreciation_years smallint CHECK (depreciation_years BETWEEN 1 AND 100),  -- Atlas FNA
  ADD COLUMN depreciation_start_date date,                                           -- Atlas FNA
  ADD COLUMN accumulated_depreciation bigint CHECK (accumulated_depreciation >= 0),  -- Atlas FNA
  ADD COLUMN fna_synced_at timestamptz,                 -- dernier message fixed_asset.valued appliqué
  ADD COLUMN disposal_buyer text CHECK (length(disposal_buyer) <= 120),
  ADD COLUMN disposal_price bigint CHECK (disposal_price >= 0),
  ADD COLUMN disposal_document_id uuid REFERENCES keystone.ged_documents(id) ON DELETE SET NULL,
  ADD COLUMN maintenance_team_id uuid,                  -- teams, clé posée par la migration PL
  ADD COLUMN shutdown_windows jsonb,                    -- forme de work_centers.opening_hours
  ADD COLUMN shutdown_max_minutes int CHECK (shutdown_max_minutes > 0),
  ADD CONSTRAINT ck_assets_disposal_sale CHECK (disposal_mode IS DISTINCT FROM 'sale' OR (disposal_buyer IS NOT NULL AND disposal_price IS NOT NULL)),
  ADD CONSTRAINT ck_assets_disposal_price CHECK (disposal_price IS NULL OR (disposal_mode = 'sale' AND currency IS NOT NULL)),
  ADD CONSTRAINT ck_assets_depreciation CHECK (accumulated_depreciation <= acquisition_value);

-- AnnexeA_Socle_Partie3#7
CREATE INDEX ix_assets_team ON keystone.assets (tenant_id, maintenance_team_id) WHERE maintenance_team_id IS NOT NULL;

-- AnnexeA_Socle_Partie3#7
CREATE TABLE keystone.asset_action_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  capa_action_id uuid NOT NULL,                         -- capa_actions, clé posée par la migration C
  link_reason text CHECK (length(link_reason) <= 200),
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_asset_action UNIQUE (asset_id, capa_action_id)
);

-- AnnexeA_Socle_Partie4#1
-- déjà requise par ix_vendors_name_trgm (Annexe P)
CREATE INDEX ix_assets_name_trgm    ON keystone.assets       USING gin (name gin_trgm_ops);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_assets_code_prefix  ON keystone.assets       (tenant_id, upper(code) text_pattern_ops);

-- AnnexeA_Socle_Partie4#2
ALTER TABLE keystone.site_ext
  ADD COLUMN privacy_override_reason text CHECK (privacy_override_reason IS NULL OR length(trim(privacy_override_reason)) BETWEEN 10 AND 1000),
  ADD COLUMN privacy_override_by uuid,                  -- users.id du référent
  ADD COLUMN privacy_override_at timestamptz,
  ADD CONSTRAINT ck_site_privacy_override CHECK (
        (privacy_override_reason IS NULL AND privacy_override_by IS NULL AND privacy_override_at IS NULL)
     OR (privacy_override_reason IS NOT NULL AND privacy_override_by IS NOT NULL AND privacy_override_at IS NOT NULL));

-- AnnexeA_Socle_Partie4#3
CREATE INDEX ix_assets_purchase_order ON keystone.assets (tenant_id, purchase_order_id) WHERE purchase_order_id IS NOT NULL;

-- AnnexeA_Socle_Partie4#3
CREATE INDEX ix_asset_action_capa    ON keystone.asset_action_links (tenant_id, capa_action_id);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE TABLE keystone.user_profiles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL,
  user_id          uuid NOT NULL REFERENCES keystone.users(id) ON DELETE CASCADE,
  kind             keystone.profile_kind NOT NULL,
  vendor_user_id   uuid REFERENCES keystone.vendor_users(id) ON DELETE CASCADE,    -- Annexe P (D13, A13)
  client_user_id   uuid REFERENCES keystone.client_users(id) ON DELETE CASCADE,    -- Annexe M
  occupant_user_id uuid REFERENCES keystone.occupant_users(id) ON DELETE CASCADE,  -- Annexe D
  label            text NOT NULL,                     -- « Équipe Keystone », « Fournisseur FRN-0021 » (données de démonstration)
  status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','disabled')),
  suspended_reason text,
  is_default       boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_profile_link CHECK (
    (kind = 'internal' AND vendor_user_id IS NULL AND client_user_id IS NULL AND occupant_user_id IS NULL) OR
    (kind = 'vendor'   AND vendor_user_id IS NOT NULL AND client_user_id IS NULL AND occupant_user_id IS NULL) OR
    (kind = 'client'   AND client_user_id IS NOT NULL AND vendor_user_id IS NULL AND occupant_user_id IS NULL) OR
    (kind = 'occupant' AND occupant_user_id IS NOT NULL AND vendor_user_id IS NULL AND client_user_id IS NULL))
);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE UNIQUE INDEX ux_profile_internal ON keystone.user_profiles (tenant_id, user_id) WHERE kind = 'internal' AND deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications#2
CREATE UNIQUE INDEX ux_profile_default  ON keystone.user_profiles (user_id) WHERE is_default AND deleted_at IS NULL;

-- AnnexeAdmin_RBAC_Notifications#2
CREATE TABLE keystone.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id    uuid NOT NULL REFERENCES keystone.users(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES keystone.user_profiles(id) ON DELETE CASCADE,
  role_id    uuid NOT NULL REFERENCES keystone.roles(id) ON DELETE RESTRICT,
  granted_at timestamptz NOT NULL DEFAULT now(), granted_by uuid,
  UNIQUE (profile_id, role_id)
);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE INDEX ix_user_roles_profile ON keystone.user_roles (profile_id);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE TABLE keystone.user_scope (                    -- périmètre d'un profil interne
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  user_id    uuid NOT NULL REFERENCES keystone.users(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES keystone.user_profiles(id) ON DELETE CASCADE,
  entity_id  uuid REFERENCES atlas_core.legal_entities(id),
  site_id    uuid REFERENCES atlas_core.sites(id),       -- A66
  CONSTRAINT ck_scope_one CHECK ((entity_id IS NULL) <> (site_id IS NULL)),
  UNIQUE (profile_id, entity_id, site_id)
);

-- AnnexeAdmin_RBAC_Notifications#2
CREATE TABLE keystone.session_profiles (              -- profil actif d'une session Supabase Auth
  session_id  uuid PRIMARY KEY,                       -- auth.sessions.id
  tenant_id   uuid NOT NULL, user_id uuid NOT NULL,
  profile_id  uuid NOT NULL REFERENCES keystone.user_profiles(id) ON DELETE CASCADE,
  surface     keystone.surface_code NOT NULL,
  switched_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeAdmin_RBAC_Notifications#3
CREATE OR REPLACE FUNCTION keystone.active_profile() RETURNS uuid   -- définition unique (Annexe A.0.4 y renvoie)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT p.id FROM keystone.user_profiles p
   WHERE p.id = (auth.jwt() ->> 'active_profile_id')::uuid
     AND p.user_id = auth.uid() AND p.tenant_id = keystone.current_tenant()
     AND p.status = 'active' AND p.deleted_at IS NULL $$;

-- AnnexeAdmin_RBAC_Notifications#9
CREATE TABLE keystone.account_access_review_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
  review_id   uuid NOT NULL REFERENCES keystone.account_access_reviews(id) ON DELETE CASCADE,
  profile_id  uuid NOT NULL REFERENCES keystone.user_profiles(id),
  user_id     uuid NOT NULL REFERENCES keystone.users(id),
  reviewer_id uuid NOT NULL REFERENCES keystone.users(id),
  snapshot    jsonb NOT NULL,                         -- rôles, permissions sensibles, périmètre, dernière connexion
  decision    keystone.access_review_decision NOT NULL DEFAULT 'pending',
  decided_at  timestamptz, reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_review_not_self CHECK (reviewer_id <> user_id),
  CONSTRAINT ck_review_reason CHECK (decision <> 'revoked' OR reason IS NOT NULL),
  UNIQUE (review_id, profile_id)
);

-- AnnexeAdmin_RBAC_Notifications#9
CREATE INDEX ix_review_items_reviewer ON keystone.account_access_review_items (reviewer_id, decision);

-- AnnexeG_GED#5
CREATE TABLE keystone.doc_qr_links (                 -- QR posé près de l'équipement (Lot 17 partie 3 §7.6)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id) ON DELETE CASCADE,
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE SET NULL,
  token text NOT NULL,                              -- 32 octets aléatoires, base64url, aucune donnée lisible
  pin_version int,                                  -- NULL : version courante
  label text,
  printed_at timestamptz, printed_by uuid,
  revoked_at timestamptz, revoked_by uuid, revoke_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_doc_qr_token UNIQUE (token),
  CONSTRAINT ck_doc_qr_revoke CHECK (revoked_at IS NULL OR revoke_reason IS NOT NULL)
);

-- AnnexeS_Space_Management#7
CREATE TABLE keystone.sectors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, zoning_id uuid NOT NULL REFERENCES keystone.zonings(id) ON DELETE CASCADE,
  code text NOT NULL, name text NOT NULL,
  definition_mode text NOT NULL CHECK (definition_mode IN ('selection','polygon')),
  owner_kind text CHECK (owner_kind IN ('team','vendor','work_center','person')), owner_id uuid,
  serving_asset_id uuid REFERENCES keystone.assets(id),   -- zonage CVC
  assembly_points jsonb CHECK (assembly_points IS NULL
     OR jsonb_matches_schema(keystone.json_schema('assembly_points'), assembly_points)),
     -- zonage évacuation (A76) : [{"code":"PR1","label":text,"lng":numeric,"lat":numeric,"capacity":int}]
  color text NOT NULL, pattern text,
  CONSTRAINT uq_sector UNIQUE (zoning_id, code) );

-- AnnexeS_Space_Management#7
CREATE TABLE keystone.sector_parts (                       -- polygone libre par niveau
  sector_id uuid NOT NULL REFERENCES keystone.sectors(id) ON DELETE CASCADE,
  floor_id uuid NOT NULL, geom_local geometry(MultiPolygon, 0) NOT NULL, PRIMARY KEY (sector_id, floor_id) );

-- AnnexeS_Space_Management#7
CREATE INDEX gx_sector_parts ON keystone.sector_parts USING gist (geom_local);

-- AnnexeS_Space_Management#7
CREATE TABLE keystone.sector_spaces (
  sector_id uuid NOT NULL REFERENCES keystone.sectors(id) ON DELETE CASCADE,
  space_unit_id uuid NOT NULL REFERENCES atlas_core.spaces(id),
  coverage_ratio numeric(5,4) NOT NULL DEFAULT 1 CHECK (coverage_ratio BETWEEN 0 AND 1),
  PRIMARY KEY (sector_id, space_unit_id) );

-- AnnexeS_Space_Management_Partie2#2
-- Position d'un actif sur un plan : propriétaire unique Annexe S (CDC v3 §6.27, A97)
CREATE TABLE keystone.asset_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES keystone.space_plans(id) ON DELETE CASCADE,
  x numeric(8,5) NOT NULL CHECK (x BETWEEN 0 AND 1),        -- coordonnées normalisées sur l'image du plan
  y numeric(8,5) NOT NULL CHECK (y BETWEEN 0 AND 1),
  space_unit_id uuid REFERENCES atlas_core.spaces(id) ON DELETE SET NULL,   -- résolu par space_at_local_point
  rotation_deg smallint NOT NULL DEFAULT 0 CHECK (rotation_deg BETWEEN 0 AND 359),  -- orientation du pictogramme
  status text NOT NULL DEFAULT 'placed' CHECK (status IN ('placed','to_reposition')),
  placed_by uuid, placed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_asset_position UNIQUE (tenant_id, asset_id, plan_id)          -- une position par actif et par plan
);

-- AnnexeS_Space_Management_Partie2#2
CREATE INDEX ix_asset_pos_plan ON keystone.asset_positions (tenant_id, plan_id) WHERE deleted_at IS NULL;

-- AnnexeS_Space_Management_Partie2#2
CREATE INDEX ix_asset_pos_reposition ON keystone.asset_positions (tenant_id, plan_id) WHERE status = 'to_reposition';

-- AnnexeS_Space_Management_Partie2#2
ALTER TABLE keystone.asset_positions ENABLE ROW LEVEL SECURITY;

-- AnnexeS_Space_Management_Partie2#7
CREATE TABLE keystone.move_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), move_id uuid NOT NULL REFERENCES keystone.move_requests(id) ON DELETE CASCADE,
  asset_id uuid REFERENCES keystone.assets(id), label text, qty int NOT NULL DEFAULT 1 CHECK (qty > 0),
  from_location_id uuid NOT NULL, to_location_id uuid NOT NULL, to_x numeric(8,5), to_y numeric(8,5),
  tag text NOT NULL, left_at timestamptz, arrived_at timestamptz,
  CONSTRAINT ck_item CHECK (asset_id IS NOT NULL OR label IS NOT NULL), CONSTRAINT uq_move_tag UNIQUE (move_id, tag) );

-- AnnexeK_Formation_Environnement#2
-- COMPETENCY_ALREADY_CURRENT

CREATE TABLE keystone.competency_requirements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  scope keystone.requirement_scope NOT NULL,
  asset_category_id uuid REFERENCES keystone.asset_categories(id),
  work_center_id uuid REFERENCES keystone.work_centers(id),
  permit_rubric keystone.permit_type,
  permit_level keystone.permit_level,        -- portée permit_approver : niveau du circuit
  permit_regime text CHECK (permit_regime IN ('energized')),   -- exigence propre au régime sous tension de electrical
  job_position_id uuid REFERENCES keystone.job_positions(id),
  site_id uuid REFERENCES atlas_core.sites(id),
  competency_id uuid NOT NULL REFERENCES keystone.competencies(id),
  is_blocking boolean NOT NULL DEFAULT true,
  CONSTRAINT ck_cr_scope CHECK (
       (scope = 'asset_category'  AND asset_category_id IS NOT NULL)
    OR (scope = 'work_center'     AND work_center_id IS NOT NULL)
    OR (scope = 'permit_worker'   AND permit_rubric IS NOT NULL)
    OR (scope = 'permit_approver' AND permit_rubric IS NOT NULL AND permit_level IS NOT NULL)
    OR (scope = 'job_position'    AND job_position_id IS NOT NULL)
    OR (scope = 'site_induction'  AND site_id IS NOT NULL))
);

-- AnnexeK_Formation_Environnement#2
CREATE INDEX ix_creq ON keystone.competency_requirements (tenant_id, scope);

-- AnnexeK_Formation_Environnement#10
CREATE TABLE keystone.env_targets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  kind keystone.env_indicator_kind NOT NULL, year int NOT NULL,
  target_value numeric(18,4) NOT NULL, direction text NOT NULL CHECK (direction IN ('max','min')),
  objective_id uuid REFERENCES keystone.hsse_objectives(id),
  UNIQUE (tenant_id, site_id, kind, year)
);

-- AnnexePL_Planning_Equipes#2
CREATE TABLE keystone.teams (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,           -- NULL : équipe multi-sites
  work_center_id uuid REFERENCES keystone.work_centers(id) ON DELETE RESTRICT,
  vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE RESTRICT,         -- équipe d'un prestataire
  code text NOT NULL CHECK (code ~ '^[A-Z0-9][A-Z0-9_-]{1,29}$'),
  name text NOT NULL CHECK (length(name) BETWEEN 2 AND 80),
  lead_person_id uuid REFERENCES keystone.persons(id) ON DELETE SET NULL,
  default_on_call_domain keystone.on_call_domain,
  is_active boolean NOT NULL DEFAULT true,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT uq_team_code UNIQUE (tenant_id, code)
);

-- AnnexePL_Planning_Equipes#2
CREATE INDEX ix_teams_site ON keystone.teams (tenant_id, site_id) WHERE deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#2
CREATE INDEX ix_teams_wc ON keystone.teams (tenant_id, work_center_id) WHERE deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#3
CREATE TABLE keystone.team_members (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  team_id uuid NOT NULL REFERENCES keystone.teams(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id) ON DELETE RESTRICT,
  role keystone.wo_team_role NOT NULL DEFAULT 'member',
  valid_from date NOT NULL DEFAULT current_date,
  valid_to date,
  CONSTRAINT ck_member_dates CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT ex_member_overlap EXCLUDE USING gist (
    team_id WITH =, person_id WITH =,
    daterange(valid_from, coalesce(valid_to, 'infinity'::date), '[]') WITH &&) WHERE (deleted_at IS NULL)
);

-- AnnexePL_Planning_Equipes#3
CREATE UNIQUE INDEX uq_team_lead_current ON keystone.team_members (team_id)
  WHERE role = 'lead' AND valid_to IS NULL AND deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#3
CREATE INDEX ix_tm_person ON keystone.team_members (tenant_id, person_id) WHERE deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#4
CREATE TABLE keystone.shifts (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  person_id uuid NOT NULL REFERENCES keystone.persons(id) ON DELETE RESTRICT,
  team_id uuid REFERENCES keystone.teams(id) ON DELETE SET NULL,
  work_center_id uuid REFERENCES keystone.work_centers(id) ON DELETE SET NULL,   -- défaut : centre de l'équipe
  pattern_id uuid REFERENCES keystone.shift_patterns(id) ON DELETE SET NULL,     -- poste généré par une rotation
  split_group_id uuid,                                  -- relie les deux segments d'un poste coupé
  kind keystone.shift_kind NOT NULL DEFAULT 'day',
  status keystone.shift_status NOT NULL DEFAULT 'planned',
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  break_minutes int NOT NULL DEFAULT 0 CHECK (break_minutes BETWEEN 0 AND 240),
  security_post_code text,                              -- poste de garde (Annexe U), agents de sûreté
  published_at timestamptz, published_by uuid,
  change_reason text,                                   -- obligatoire pour modifier un poste publié
  cancelled_reason text,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT ck_shift_dates CHECK (ends_at > starts_at AND ends_at - starts_at <= interval '24 hours'),
  CONSTRAINT ck_shift_break CHECK (break_minutes * interval '1 minute' < ends_at - starts_at),
  CONSTRAINT ck_shift_split CHECK ((kind = 'split') = (split_group_id IS NOT NULL)),
  CONSTRAINT ck_shift_published CHECK (status <> 'published' OR published_at IS NOT NULL),
  CONSTRAINT ck_shift_cancel CHECK (status <> 'cancelled' OR cancelled_reason IS NOT NULL),
  CONSTRAINT fk_shift_post FOREIGN KEY (tenant_id, site_id, security_post_code)
    REFERENCES keystone.security_posts(tenant_id, site_id, code),
  CONSTRAINT ex_shift_overlap EXCLUDE USING gist (
    person_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
    WHERE (status <> 'cancelled' AND deleted_at IS NULL)
);

-- AnnexePL_Planning_Equipes#4
CREATE INDEX ix_shifts_site_time ON keystone.shifts USING gist (site_id, tstzrange(starts_at, ends_at, '[)'))
  WHERE status = 'published' AND deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#4
CREATE INDEX ix_shifts_person ON keystone.shifts (tenant_id, person_id, starts_at) WHERE deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#6
CREATE TABLE keystone.on_call (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  domain keystone.on_call_domain NOT NULL DEFAULT 'technical',
  work_center_id uuid REFERENCES keystone.work_centers(id) ON DELETE RESTRICT,   -- NULL : tout le domaine
  wc_key uuid GENERATED ALWAYS AS (coalesce(work_center_id, '00000000-0000-0000-0000-000000000000'::uuid)) STORED,
  level smallint NOT NULL CHECK (level BETWEEN 1 AND 3),   -- 1 premier appel, 2 renfort, 3 encadrement
  person_id uuid NOT NULL REFERENCES keystone.persons(id) ON DELETE RESTRICT,
  team_id uuid REFERENCES keystone.teams(id) ON DELETE SET NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status keystone.shift_status NOT NULL DEFAULT 'planned',
  contact_phone text CHECK (contact_phone IS NULL OR contact_phone ~ '^\+[1-9][0-9]{7,14}$'),   -- E.164, défaut persons.phone
  published_at timestamptz, published_by uuid,
  change_reason text, cancelled_reason text,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT ck_oncall_dates CHECK (ends_at > starts_at AND ends_at - starts_at <= interval '14 days'),
  CONSTRAINT ck_oncall_cancel CHECK (status <> 'cancelled' OR cancelled_reason IS NOT NULL),
  CONSTRAINT ex_oncall_level EXCLUDE USING gist (
    site_id WITH =, domain WITH =, wc_key WITH =, level WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
    WHERE (status <> 'cancelled' AND deleted_at IS NULL),
  CONSTRAINT ex_oncall_person EXCLUDE USING gist (
    site_id WITH =, domain WITH =, person_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
    WHERE (status <> 'cancelled' AND deleted_at IS NULL)
);

-- AnnexePL_Planning_Equipes#6
CREATE INDEX ix_oncall_site_time ON keystone.on_call USING gist (site_id, tstzrange(starts_at, ends_at, '[)'))
  WHERE status = 'published' AND deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#6
CREATE INDEX ix_oncall_person ON keystone.on_call (tenant_id, person_id, starts_at) WHERE deleted_at IS NULL;

-- AnnexePL_Planning_Equipes#9
CREATE TABLE keystone.on_call_pages (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  policy_id uuid NOT NULL REFERENCES keystone.on_call_escalation_policies(id) ON DELETE RESTRICT,
  trigger keystone.on_call_trigger NOT NULL,
  object_table text NOT NULL CHECK (object_table IN ('work_orders','tickets','lone_worker_alerts','iot_alerts','hsse_events','on_call_pages')),
  object_id uuid NOT NULL,
  work_center_id uuid REFERENCES keystone.work_centers(id) ON DELETE SET NULL,
  level smallint NOT NULL CHECK (level BETWEEN 1 AND 4),   -- 4 : rôles finaux
  on_call_id uuid REFERENCES keystone.on_call(id) ON DELETE SET NULL,
  person_id uuid REFERENCES keystone.persons(id) ON DELETE SET NULL,       -- NULL au niveau 4 ou sans astreinte
  status keystone.on_call_page_status NOT NULL DEFAULT 'paged',
  paged_at timestamptz NOT NULL DEFAULT now(),
  ack_due_at timestamptz,
  repeat_count smallint NOT NULL DEFAULT 0,
  acknowledged_by uuid, acknowledged_at timestamptz,
  resolved_at timestamptz,
  note text,
  CONSTRAINT ck_page_ack CHECK (status <> 'acknowledged' OR (acknowledged_by IS NOT NULL AND acknowledged_at IS NOT NULL)),
  CONSTRAINT ck_page_person CHECK (level = 4 OR status = 'uncovered' OR person_id IS NOT NULL)
);

-- AnnexePL_Planning_Equipes#9
CREATE UNIQUE INDEX uq_page_open ON keystone.on_call_pages (tenant_id, object_table, object_id, level)
  WHERE status IN ('paged','acknowledged');

-- AnnexePL_Planning_Equipes#9
CREATE INDEX ix_page_due ON keystone.on_call_pages (ack_due_at) WHERE status = 'paged';

-- AnnexePL_Planning_Equipes#9
CREATE INDEX ix_page_object ON keystone.on_call_pages (tenant_id, object_table, object_id);

-- AnnexeB_GMAO_Partie2#13
CREATE TABLE keystone.maintenance_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  root_plan_id uuid REFERENCES keystone.maintenance_plans(id),  -- NULL pour la version 1 ; lignée des versions
  version int NOT NULL DEFAULT 1 CHECK (version >= 1),
  status plan_status NOT NULL DEFAULT 'draft',
  plan_kind plan_kind NOT NULL DEFAULT 'maintenance',
  code text NOT NULL,                           -- GAM-<famille>-<équipement>-<périodicité>, GAM-PROP-..., GAM-VRT-...
  name text NOT NULL,
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,           -- gamme propre à un actif
  category_id uuid REFERENCES keystone.asset_categories(id) ON DELETE RESTRICT, -- gamme de famille
  service_type_id uuid,                         -- plan de prestation : type de prestation (Annexe F)
  work_center_id uuid NOT NULL REFERENCES keystone.work_centers(id),
  maintenance_level_id uuid REFERENCES keystone.maintenance_levels(id),  -- calculé : maximum des opérations
  trigger_type plan_trigger NOT NULL,
  interval_value int CHECK (interval_value > 0),
  interval_unit text CHECK (interval_unit IN ('day','week','month','year')),
  meter_kind meter_kind,                        -- B.8
  meter_threshold numeric(18,4) CHECK (meter_threshold > 0),
  lead_time_days int NOT NULL DEFAULT 7 CHECK (lead_time_days >= 0),
  tolerance_days int NOT NULL CHECK (tolerance_days >= 1),
  due_basis plan_due_basis NOT NULL DEFAULT 'actual',
  coincidence_window_days int NOT NULL DEFAULT 15 CHECK (coincidence_window_days >= 0),
  requires_permit boolean NOT NULL DEFAULT false,
  permit_type permit_type,                      -- rubrique principale (D09, Annexe C)
  shutdown_scope shutdown_scope NOT NULL DEFAULT 'none',
  is_regulatory boolean NOT NULL DEFAULT false,
  regulatory_regime text,                       -- regulatory_controls.regime (Annexe C)
  doc_links uuid[] NOT NULL DEFAULT '{}',       -- Annexe G
  season_months smallint[] CHECK (season_months <@ ARRAY[1,2,3,4,5,6,7,8,9,10,11,12]::smallint[]),  -- saisonnalité (espaces verts) ; NULL : toute l'année
  photos_required text NOT NULL DEFAULT 'none' CHECK (photos_required IN ('none','before','after','both')),
  vendor_id uuid REFERENCES keystone.vendors(id),        -- plan de prestation exécuté par un prestataire (D13)
  team_id uuid REFERENCES keystone.teams(id),            -- ou par une équipe permanente (Annexe PL)
  window_start time, window_end time,                    -- fenêtre d'exécution en heure locale du site (évolution, à valider)
  CONSTRAINT ck_plan_window CHECK ((window_start IS NULL) = (window_end IS NULL)),
  is_active boolean GENERATED ALWAYS AS (status = 'active') STORED,
  activated_by uuid, activated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_plan_code_version UNIQUE (tenant_id, code, version),
  CONSTRAINT ck_plan_target CHECK (plan_kind = 'service' OR asset_id IS NOT NULL OR category_id IS NOT NULL),
  CONSTRAINT ck_plan_service CHECK (plan_kind = 'maintenance' OR service_type_id IS NOT NULL),
  CONSTRAINT ck_plan_calendar CHECK (trigger_type NOT IN ('calendar','calendar_or_meter')
                                     OR (interval_value IS NOT NULL AND interval_unit IS NOT NULL)),
  CONSTRAINT ck_plan_meter CHECK (trigger_type NOT IN ('meter','calendar_or_meter')
                                  OR (meter_kind IS NOT NULL AND meter_threshold IS NOT NULL)),
  CONSTRAINT ck_plan_permit CHECK (NOT requires_permit OR permit_type IS NOT NULL),
  CONSTRAINT ck_plan_regulatory CHECK (NOT is_regulatory OR (regulatory_regime IS NOT NULL AND plan_kind = 'maintenance')) );

-- AnnexeB_GMAO_Partie2#13
CREATE UNIQUE INDEX uq_plan_active_version ON keystone.maintenance_plans (tenant_id, coalesce(root_plan_id, id))
  WHERE status = 'active';

-- AnnexeB_GMAO_Partie2#14
CREATE TABLE keystone.pm_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  plan_id uuid NOT NULL REFERENCES keystone.maintenance_plans(id) ON DELETE CASCADE,
  position int NOT NULL,
  label text NOT NULL,
  task_type pm_task_type NOT NULL,
  objective text NOT NULL,
  instructions text NOT NULL,                   -- mode opératoire, étapes numérotées
  maintenance_level_id uuid NOT NULL REFERENCES keystone.maintenance_levels(id),
  est_minutes int NOT NULL CHECK (est_minutes >= 0),
  est_minutes_per_m2 numeric(8,4) CHECK (est_minutes_per_m2 >= 0),   -- plan de prestation : durée par m² du secteur
  required_competency_id uuid REFERENCES keystone.competencies(id),
  requires_shutdown boolean NOT NULL DEFAULT false,
  isolation_type isolation_type NOT NULL DEFAULT 'none',   -- autre que none : consignation LOTO (loto.apply)
  tools text[] NOT NULL DEFAULT '{}',
  ppe text[] NOT NULL,                          -- gants, gants_isolants, lunettes, ecran_facial, casque, harnais,
                                                -- masque, protection_auditive, chaussures_securite, combinaison
  is_regulatory boolean NOT NULL DEFAULT false, regulatory_ref text,
  nonconform_instruction text NOT NULL,
  nonconform_action nonconform_action NOT NULL,
  included_plan_id uuid REFERENCES keystone.maintenance_plans(id),   -- opération composite
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_task_position UNIQUE (plan_id, position) DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT ck_task_composite CHECK ((task_type = 'composite') = (included_plan_id IS NOT NULL)),
  CONSTRAINT ck_task_self CHECK (included_plan_id IS DISTINCT FROM plan_id) );

-- AnnexeB_GMAO_Partie2#15
CREATE TABLE keystone.pm_task_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  pm_task_id uuid NOT NULL REFERENCES keystone.pm_tasks(id) ON DELETE CASCADE,
  position int NOT NULL,
  label text NOT NULL,
  measure_type text NOT NULL CHECK (measure_type IN ('numeric','boolean','choice','text')),
  expected_text text, expected_boolean boolean, expected_choices text[],
  min_value numeric(18,4), max_value numeric(18,4),
  unit text CHECK (unit IN ('K','°C','bar','Pa','A','V','kW','MΩ','mm/s','%','ppm','h','m³/h','lux','autre')),
  method text,
  default_to_adjust boolean NOT NULL DEFAULT false,   -- valeur générique à caler sur le constructeur
  is_blocking boolean NOT NULL DEFAULT false,
  CONSTRAINT ck_cp_bounds CHECK (min_value IS NULL OR max_value IS NULL OR min_value <= max_value),
  CONSTRAINT ck_cp_numeric CHECK (measure_type <> 'numeric' OR min_value IS NOT NULL OR max_value IS NOT NULL) );

-- AnnexeB_GMAO_Partie2#15
CREATE TABLE keystone.pm_task_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  pm_task_id uuid NOT NULL REFERENCES keystone.pm_tasks(id) ON DELETE CASCADE,
  part_ref text NOT NULL,                       -- référence article ; résolue vers spare_parts du magasin du site
  label text NOT NULL,
  qty numeric(12,3) NOT NULL CHECK (qty > 0), unit text );

-- AnnexeB_GMAO_Partie3#5
CREATE TABLE keystone.warehouses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  code text NOT NULL, name text NOT NULL,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  owner_client_id uuid REFERENCES keystone.clients(id),   -- figé après le premier mouvement (STOCK_OWNER_LOCKED)                         -- Q02 : NULL = stock de l'organisation ou de la société FM ;
                                                -- renseigné = stock propriété du client (fm_provider)
  manager_person_id uuid REFERENCES keystone.persons(id),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_wh_code UNIQUE (tenant_id, code) );

-- AnnexeB_GMAO_Partie3#5
CREATE TABLE keystone.spare_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  warehouse_id uuid NOT NULL REFERENCES keystone.warehouses(id) ON DELETE RESTRICT,
  ref text NOT NULL, name text NOT NULL, unit text NOT NULL DEFAULT 'u',
  category text, manufacturer_ref text, bin text,
  qty numeric(14,3) NOT NULL DEFAULT 0 CHECK (qty >= 0),                 -- RG-STK-07
  reserved_qty numeric(14,3) NOT NULL DEFAULT 0 CHECK (reserved_qty >= 0),
  available_qty numeric(14,3) GENERATED ALWAYS AS (qty - reserved_qty) STORED,
  min_qty numeric(14,3) NOT NULL DEFAULT 0 CHECK (min_qty >= 0),
  safety_qty numeric(14,3) NOT NULL DEFAULT 0 CHECK (safety_qty >= 0),
  max_qty numeric(14,3) CHECK (max_qty IS NULL OR max_qty >= min_qty),
  reorder_qty numeric(14,3) CHECK (reorder_qty > 0),
  avg_unit_cost bigint NOT NULL DEFAULT 0 CHECK (avg_unit_cost >= 0),    -- coût moyen pondéré, unité de la devise
  last_unit_cost bigint CHECK (last_unit_cost >= 0),
  currency char(3) NOT NULL,
  abc_class char(1) CHECK (abc_class IN ('A','B','C')),
  is_critical boolean NOT NULL DEFAULT false,   -- lié à un composant d'actif high ou safety_critical
  preferred_vendor_id uuid REFERENCES keystone.vendors(id),
  last_counted_on date,
  lead_time_days integer CHECK (lead_time_days > 0),   -- délai d'approvisionnement
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_part UNIQUE (tenant_id, warehouse_id, ref),
  CONSTRAINT ck_part_reserved CHECK (reserved_qty <= qty),
  CONSTRAINT ck_part_critical CHECK (NOT is_critical OR safety_qty > 0) );

-- AnnexeB_GMAO_Partie3#5
-- RG-STK-05
CREATE INDEX ix_parts_low ON keystone.spare_parts (tenant_id, warehouse_id) WHERE qty <= min_qty;

-- AnnexeB_GMAO_Partie3#9
CREATE TABLE keystone.stock_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  ref text NOT NULL,                            -- TRF-AAAA-NNNNNN
  from_warehouse_id uuid NOT NULL REFERENCES keystone.warehouses(id),
  to_warehouse_id uuid NOT NULL REFERENCES keystone.warehouses(id),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','shipped','received','cancelled')),
  reason text NOT NULL,
  shipped_by uuid, shipped_at timestamptz, received_by uuid, received_at timestamptz,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_trf_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_trf_distinct CHECK (from_warehouse_id <> to_warehouse_id) );

-- AnnexeB_GMAO_Partie3#9
-- TRANSFER_SAME_WAREHOUSE

CREATE TABLE keystone.stock_transfer_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  transfer_id uuid NOT NULL REFERENCES keystone.stock_transfers(id) ON DELETE CASCADE,
  from_part_id uuid NOT NULL REFERENCES keystone.spare_parts(id),
  to_part_id uuid REFERENCES keystone.spare_parts(id),   -- créé dans le magasin cible s'il n'existe pas (même ref)
  qty numeric(14,3) NOT NULL CHECK (qty > 0),
  received_qty numeric(14,3) CHECK (received_qty >= 0),
  unit_cost bigint );

-- AnnexeB_GMAO_Partie3#10
CREATE TABLE keystone.cycle_counts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  warehouse_id uuid NOT NULL REFERENCES keystone.warehouses(id),
  week_start date NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','counted','validated','cancelled')),
  kind text NOT NULL DEFAULT 'scheduled' CHECK (kind IN ('scheduled','ad_hoc')),
  blind boolean NOT NULL,                       -- settings['stock.blind_count'], défaut vrai : quantité attendue masquée au compteur
  counted_by uuid, counted_at timestamptz,      -- fin du comptage, heure de l'appareil bornée par le serveur (A94), EV-L8-43
  validated_by uuid, validated_at timestamptz,
  CONSTRAINT ck_cc_counted CHECK (status NOT IN ('counted','validated') OR counted_at IS NOT NULL),
  CONSTRAINT ck_cc_sod CHECK (validated_by IS NULL OR validated_by <> counted_by) );

-- AnnexeB_GMAO_Partie3#10
CREATE UNIQUE INDEX uq_cc_one_open ON keystone.cycle_counts (warehouse_id)
  WHERE status IN ('open','counted');

-- AnnexeB_GMAO_Partie3#10
-- un seul inventaire ouvert par magasin (A82), CYCLE_COUNT_ALREADY_OPEN
CREATE UNIQUE INDEX uq_cc_open ON keystone.cycle_counts (tenant_id, warehouse_id)
  WHERE kind = 'scheduled' AND status IN ('open','counted');

-- AnnexeB_GMAO_Partie3#10
-- un seul inventaire planifié ouvert par magasin (A82)

CREATE TABLE keystone.cycle_count_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  cycle_count_id uuid NOT NULL REFERENCES keystone.cycle_counts(id) ON DELETE CASCADE,
  part_id uuid NOT NULL REFERENCES keystone.spare_parts(id),
  expected_qty numeric(14,3) NOT NULL,          -- figé à l'ouverture
  counted_qty numeric(14,3) CHECK (counted_qty >= 0),
  variance_qty numeric(14,3) GENERATED ALWAYS AS (counted_qty - expected_qty) STORED,
  variance_value bigint,                        -- arrondi demi vers le pair de variance_qty fois avg_unit_cost
  recount_requested boolean NOT NULL DEFAULT false,
  reason text );

-- AnnexeB_GMAO_Partie3#16
-- INVALID_TERMS

CREATE TABLE keystone.maintenance_contract_scope (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  contract_id uuid NOT NULL REFERENCES keystone.maintenance_contracts(id) ON DELETE CASCADE,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid REFERENCES keystone.assets(id),
  category_id uuid REFERENCES keystone.asset_categories(id),
  CONSTRAINT ck_scope_one CHECK (num_nonnulls(asset_id, category_id) <= 1) );

-- AnnexeB_GMAO_Partie3#16
-- les deux NULL : tout le site
CREATE INDEX ix_scope_site ON keystone.maintenance_contract_scope (tenant_id, site_id);

-- AnnexeMO_Modeles_OT#1
CREATE TABLE keystone.wo_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  code text NOT NULL,                           -- MOT-<famille>-NNN, donnée de démonstration : MOT-CVC-004
  name text NOT NULL,
  wo_type wo_type NOT NULL DEFAULT 'corrective',   -- 'service' : intervention Soft FM ponctuelle (D11)
  default_priority smallint NOT NULL DEFAULT 3 CHECK (default_priority BETWEEN 1 AND 4),
  category_id uuid REFERENCES keystone.asset_categories(id) ON DELETE RESTRICT,  -- famille d'actifs visée
  work_center_id uuid REFERENCES keystone.work_centers(id) ON DELETE SET NULL,
  maintenance_level_id uuid REFERENCES keystone.maintenance_levels(id) ON DELETE SET NULL,
  est_minutes int NOT NULL CHECK (est_minutes > 0),             -- reprise dans work_orders.est_minutes (A05)
  required_competency_id uuid REFERENCES keystone.competencies(id),
  requires_permit boolean NOT NULL DEFAULT false,
  permit_type permit_type,                                       -- rubrique principale
  additional_permit_types permit_type[] NOT NULL DEFAULT '{}',   -- autres rubriques du permis général (D09)
  isolation_type isolation_type NOT NULL DEFAULT 'none',         -- Annexe B.5.1
  ppe text[] NOT NULL DEFAULT '{}',
  client_id uuid REFERENCES keystone.clients(id) ON DELETE RESTRICT,  -- fm_provider : réservé aux sites de ce client ; NULL : tous
  source_plan_id uuid REFERENCES keystone.maintenance_plans(id) ON DELETE SET NULL,  -- copie d'une gamme, sans lien vivant
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_tmpl_code UNIQUE (tenant_id, code),
  CONSTRAINT ck_tmpl_type CHECK (wo_type IN ('corrective','predictive','service')),     -- RG-MOD-04
  CONSTRAINT ck_tmpl_permit CHECK (requires_permit = false OR permit_type IS NOT NULL),
  CONSTRAINT ck_tmpl_permit_extra CHECK (requires_permit OR cardinality(additional_permit_types) = 0),
  CONSTRAINT ck_tmpl_isolation CHECK (isolation_type = 'none' OR requires_permit) );

-- AnnexeMO_Modeles_OT#1
CREATE INDEX ix_tmpl_active ON keystone.wo_templates (tenant_id, wo_type, category_id) WHERE is_active AND deleted_at IS NULL;

-- AnnexeMO_Modeles_OT#1
CREATE INDEX ix_tmpl_client ON keystone.wo_templates (tenant_id, client_id) WHERE client_id IS NOT NULL;

-- AnnexeMO_Modeles_OT#1
CREATE TABLE keystone.wo_template_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  template_id uuid NOT NULL REFERENCES keystone.wo_templates(id) ON DELETE CASCADE,
  position int NOT NULL,
  label text NOT NULL,
  instructions text,
  est_minutes int CHECK (est_minutes >= 0),
  CONSTRAINT uq_tmpl_task_pos UNIQUE (template_id, position) DEFERRABLE INITIALLY DEFERRED );

-- AnnexeMO_Modeles_OT#1
CREATE TABLE keystone.wo_template_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  template_id uuid NOT NULL REFERENCES keystone.wo_templates(id) ON DELETE CASCADE,
  part_ref text NOT NULL,                       -- référence article, résolue vers le magasin du site à la création d'OT
  label text NOT NULL,
  qty numeric(12,3) NOT NULL CHECK (qty > 0),
  unit text );

-- AnnexeAM_AMDEC_Fiabilite#3
CREATE TABLE keystone.asset_criticality_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  safety smallint NOT NULL CHECK (safety BETWEEN 1 AND 5),
  operations smallint NOT NULL CHECK (operations BETWEEN 1 AND 5),
  cost smallint NOT NULL CHECK (cost BETWEEN 1 AND 5),
  environment smallint NOT NULL CHECK (environment BETWEEN 1 AND 5),
  likelihood smallint NOT NULL CHECK (likelihood BETWEEN 1 AND 5),
  likelihood_suggested smallint,
  is_safety_function boolean NOT NULL DEFAULT false,      -- copie de la catégorie à l'évaluation
  consequence smallint GENERATED ALWAYS AS (greatest(safety, operations, cost, environment)) STORED,
  score smallint GENERATED ALWAYS AS (greatest(safety, operations, cost, environment) * likelihood) STORED,
  result asset_criticality NOT NULL,             -- calculé par assess_asset_criticality, contrôlé par trigger
  rationale text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','rejected','superseded')),
  rejection_reason text,
  assessed_by uuid NOT NULL, assessed_at timestamptz NOT NULL DEFAULT now(),
  approved_by uuid, approved_at timestamptz,
  valid_until date,
  CONSTRAINT ck_crit_rationale CHECK (result IN ('low','medium') OR rationale IS NOT NULL),
  CONSTRAINT ck_crit_sod CHECK (approved_by IS NULL OR approved_by <> assessed_by) );

-- AnnexeAM_AMDEC_Fiabilite#3
CREATE UNIQUE INDEX uq_crit_current ON keystone.asset_criticality_assessments (asset_id) WHERE status = 'approved';

-- AnnexeAM_AMDEC_Fiabilite#6
CREATE TABLE keystone.asset_lifecycle_costs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE CASCADE,
  category_id uuid REFERENCES keystone.asset_categories(id),
  scenario text NOT NULL,                        -- ex. « Conserver et réviser », « Remplacer en 2028 »
  horizon_years smallint NOT NULL CHECK (horizon_years BETWEEN 1 AND 50),
  discount_rate numeric(6,4) NOT NULL CHECK (discount_rate >= 0 AND discount_rate < 1),   -- taux réel annuel
  base_year smallint NOT NULL,
  currency char(3) NOT NULL,
  npv bigint,                                    -- coût global actualisé, arrondi au franc
  eac bigint,                                    -- annuité équivalente
  computed_at timestamptz,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','validated')),
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_lcc_target CHECK (num_nonnulls(asset_id, category_id) = 1) );

-- AnnexeAM_AMDEC_Fiabilite#6
CREATE TABLE keystone.asset_lifecycle_cost_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  lcc_id uuid NOT NULL REFERENCES keystone.asset_lifecycle_costs(id) ON DELETE CASCADE,
  year_index smallint NOT NULL CHECK (year_index >= 0),   -- 0 : année de base
  cost_category text NOT NULL CHECK (cost_category IN ('acquisition','installation','energy','operation',
                 'preventive_maintenance','corrective_maintenance','downtime','refurbishment','disposal','residual_value')),
  amount bigint NOT NULL,                        -- valeur non actualisée ; residual_value saisie positive, déduite
  source text NOT NULL CHECK (source IN ('manual','wo_history','energy_aggregates','downtime_history','asset_values')),
  note text );

-- AnnexeE_Budgets_Achats#4
CREATE TABLE keystone.budgets (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  site_id uuid REFERENCES atlas_core.sites(id),
  client_id uuid REFERENCES keystone.clients(id),        -- fm_provider : budget par site client
  service_contract_id uuid REFERENCES keystone.service_contracts(id),
  fiscal_year smallint NOT NULL CHECK (fiscal_year BETWEEN 2000 AND 2100),
  period_start date NOT NULL, period_end date NOT NULL,
  category_id uuid NOT NULL REFERENCES keystone.budget_categories(id),
  kind keystone.budget_kind NOT NULL,
  initial_amount bigint NOT NULL CHECK (initial_amount >= 0),
  revised_amount bigint NOT NULL CHECK (revised_amount >= 0),  -- initial plus révisions approuvées
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  committed bigint NOT NULL DEFAULT 0 CHECK (committed >= 0),  -- recalculé par le serveur
  spent bigint NOT NULL DEFAULT 0 CHECK (spent >= 0),          -- recalculé par le serveur
  manager_id uuid REFERENCES keystone.persons(id),       -- gestionnaire, destinataire de EML-BUD-001 (EV-L8-02)
  status keystone.budget_status NOT NULL DEFAULT 'draft',
  approved_by uuid, approved_at timestamptz,
  CONSTRAINT ck_budget_period CHECK (period_end >= period_start),
  CONSTRAINT uq_budget_line UNIQUE (tenant_id, legal_entity_id, site_id, category_id, kind, period_start)
);

-- AnnexeE_Budgets_Achats#4
CREATE INDEX ix_budget_site_period ON keystone.budgets (tenant_id, site_id, period_start) WHERE deleted_at IS NULL;

-- AnnexeE_Budgets_Achats#4
CREATE INDEX ix_budget_category ON keystone.budgets (tenant_id, category_id, fiscal_year);

-- AnnexeE_Budgets_Achats#5
CREATE TABLE keystone.budget_revisions (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- REVB-2026-000004
  kind keystone.revision_kind NOT NULL,
  from_budget_id uuid REFERENCES keystone.budgets(id),   -- transfer, decrease
  to_budget_id uuid REFERENCES keystone.budgets(id),     -- transfer, increase
  amount bigint NOT NULL CHECK (amount > 0),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  reason text NOT NULL,
  status keystone.revision_status NOT NULL DEFAULT 'draft',
  requested_by uuid NOT NULL, submitted_at timestamptz,
  decided_at timestamptz, rejection_reason text,
  CONSTRAINT uq_revision_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_revision_shape CHECK (
    (kind = 'transfer' AND from_budget_id IS NOT NULL AND to_budget_id IS NOT NULL AND from_budget_id <> to_budget_id) OR
    (kind = 'increase' AND from_budget_id IS NULL AND to_budget_id IS NOT NULL) OR
    (kind = 'decrease' AND from_budget_id IS NOT NULL AND to_budget_id IS NULL))
);

-- AnnexeE_Budgets_Achats#11
CREATE TABLE keystone.supplier_catalog_items (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  vendor_ref text NOT NULL, label text NOT NULL, unit text NOT NULL,
  unit_price_ht bigint NOT NULL CHECK (unit_price_ht >= 0),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  valid_from date NOT NULL, valid_until date,
  part_id uuid REFERENCES keystone.spare_parts(id),      -- renseigné par l'exploitant
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','approved','rejected','expired')),
  proposed_by uuid NOT NULL, approved_by uuid, approved_at timestamptz,
  previous_version_id uuid REFERENCES keystone.supplier_catalog_items(id),
  document_ids uuid[] NOT NULL DEFAULT '{}',              -- EV-L8-41 : pièces de la proposition, tg_check_document_ids
  CONSTRAINT ck_catalog_sod CHECK (approved_by IS NULL OR approved_by <> proposed_by)
);

-- AnnexeE_Budgets_Achats#11
CREATE UNIQUE INDEX uq_catalog_current ON keystone.supplier_catalog_items (tenant_id, vendor_id, vendor_ref)
  WHERE status = 'approved' AND deleted_at IS NULL;

-- AnnexeE_Budgets_Achats_Partie2#1
CREATE TRIGGER budgets_kind BEFORE INSERT OR UPDATE OF kind, category_id ON keystone.budgets
  FOR EACH ROW EXECUTE FUNCTION keystone.tg_budget_kind();

-- AnnexeC_HSSE_Partie3#2
CREATE TABLE keystone.inspection_plans (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  template_id uuid NOT NULL REFERENCES keystone.inspection_templates(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  location_id uuid REFERENCES keystone.locations(id), asset_id uuid REFERENCES keystone.assets(id),
  frequency_value int NOT NULL CHECK (frequency_value > 0), frequency_unit keystone.frequency_unit NOT NULL,
  inspector_id uuid REFERENCES keystone.persons(id),
  next_due date NOT NULL, is_active boolean NOT NULL DEFAULT true,
  row_version bigint NOT NULL DEFAULT 1
);

-- AnnexeR_Reglementaire_SSI#3
CREATE TABLE keystone.regulatory_controls (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  regime_id uuid NOT NULL REFERENCES keystone.regulatory_regimes(id),
  frequency_months int NOT NULL CHECK (frequency_months > 0),          -- défaut du régime
  due_basis keystone.due_basis NOT NULL,                               -- défaut du régime (évolution 80, lot 6)
  body_id uuid REFERENCES keystone.inspection_bodies(id),
  last_control_date date,
  last_result keystone.control_result,
  theoretical_due_date date,                -- échéance théorique, base 'theoretical'
  next_due_date date NOT NULL,
  report_document_id uuid REFERENCES keystone.ged_documents(id),                  -- dernier rapport (GED)
  report_valid_until date,
  recheck_due_date date,                    -- contre-visite exigée après non_conform
  status keystone.regulatory_status NOT NULL DEFAULT 'compliant',      -- calculé (R.3), jamais saisi
  is_overdue boolean NOT NULL DEFAULT false,                           -- calculé, visible même si non_compliant
  status_computed_at timestamptz,
  retired_at timestamptz, retired_reason text, retired_by uuid,        -- retrait motivé du registre
  CONSTRAINT ck_rc_retired CHECK (retired_at IS NULL OR retired_reason IS NOT NULL),
  CONSTRAINT ck_rc_target CHECK (asset_id IS NOT NULL OR site_id IS NOT NULL)
);

-- AnnexeR_Reglementaire_SSI#3
CREATE UNIQUE INDEX uq_rc_asset_regime ON keystone.regulatory_controls (tenant_id, asset_id, regime_id)
  WHERE deleted_at IS NULL AND retired_at IS NULL;

-- AnnexeR_Reglementaire_SSI#3
-- DUPLICATE_CONTROL
CREATE INDEX ix_rc_due    ON keystone.regulatory_controls (tenant_id, site_id, next_due_date) WHERE deleted_at IS NULL;

-- AnnexeR_Reglementaire_SSI#3
CREATE INDEX ix_rc_status ON keystone.regulatory_controls (tenant_id, status);

-- AnnexeR_Reglementaire_SSI#3
CREATE INDEX ix_rc_regime ON keystone.regulatory_controls (tenant_id, regime_id, next_due_date);

-- AnnexeR_Reglementaire_SSI#3
CREATE TABLE keystone.regulatory_derogations (          -- report au delà de l'échéance (RG-CRP-09)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  control_id uuid NOT NULL REFERENCES keystone.regulatory_controls(id),
  planned_date date NOT NULL, reason text NOT NULL,
  document_id uuid REFERENCES keystone.ged_documents(id),                         -- pièce justificative (GED)
  approved_by uuid NOT NULL, approved_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeR_Reglementaire_SSI#5
CREATE TABLE keystone.fire_systems (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid NOT NULL REFERENCES keystone.assets(id),          -- actif réglementé (RG-SSI-01)
  system_type keystone.fire_system_type NOT NULL,
  label text NOT NULL
);

-- AnnexeR_Reglementaire_SSI#5
CREATE TABLE keystone.fire_system_sectors (             -- lien vers les compartiments du zonage incendie (Annexe S)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  fire_system_id uuid NOT NULL REFERENCES keystone.fire_systems(id) ON DELETE CASCADE,
  sector_id uuid NOT NULL REFERENCES keystone.sectors(id),
  UNIQUE (fire_system_id, sector_id)
);

-- AnnexeR_Reglementaire_SSI#5
CREATE TABLE keystone.fire_registers (                  -- vérifications périodiques
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  fire_system_id uuid NOT NULL REFERENCES keystone.fire_systems(id),
  regulatory_control_id uuid REFERENCES keystone.regulatory_controls(id),
  check_type text NOT NULL, done_at timestamptz NOT NULL,
  result keystone.control_result NOT NULL,
  body_id uuid REFERENCES keystone.inspection_bodies(id),
  report_document_id uuid REFERENCES keystone.ged_documents(id), recorded_by uuid NOT NULL
);

-- AnnexeR_Reglementaire_SSI#5
CREATE INDEX ix_fire_reg_system ON keystone.fire_registers (tenant_id, fire_system_id, done_at DESC);

-- AnnexeD_Tickets_Portails#2
CREATE TABLE keystone.ticket_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  code text NOT NULL, label text NOT NULL, icon text,
  default_priority smallint NOT NULL DEFAULT 3 CHECK (default_priority BETWEEN 1 AND 4),
  routing_zoning_type text,            -- code de zoning_types (Annexe S) : 'cleaning', 'hvac', 'maintenance' ; NULL = file générale
  default_team_id uuid REFERENCES keystone.teams(id) ON DELETE SET NULL,   -- teams : Annexe PL (A92)
  is_public boolean NOT NULL DEFAULT false,          -- proposée dans la déclaration publique par QR
  is_active boolean NOT NULL DEFAULT true, sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_ticket_category UNIQUE (tenant_id, code)
);

-- AnnexeD_Tickets_Portails#4
CREATE TABLE keystone.ticket_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, code text NOT NULL, label text NOT NULL, body text NOT NULL,
  category_id uuid REFERENCES keystone.ticket_categories(id) ON DELETE SET NULL,
  is_internal boolean NOT NULL DEFAULT false, is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_ticket_template UNIQUE (tenant_id, code) );

-- AnnexeP_Prestataires_Mobile_Partie2#1
CREATE TABLE keystone.sync_mutations (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  client_mutation_id uuid NOT NULL,                      -- généré par l'appareil, clé d'idempotence
  device_session_id uuid NOT NULL REFERENCES keystone.device_sessions(id),
  user_id uuid NOT NULL,
  object_type text NOT NULL, object_id uuid NOT NULL,
  operation text NOT NULL CHECK (operation IN ('insert','update','transition','delete')),
  base_version bigint,                                   -- version serveur lue par l'appareil
  payload jsonb NOT NULL,
  occurred_at timestamptz NOT NULL,                      -- horloge de l'appareil
  received_at timestamptz NOT NULL DEFAULT now(),
  outcome text NOT NULL CHECK (outcome IN ('applied','rejected','conflict','duplicate')),
  error_code text, error_detail text,
  CONSTRAINT uq_sync_mutation UNIQUE (tenant_id, client_mutation_id)
);

-- AnnexeP_Prestataires_Mobile_Partie2#1
CREATE INDEX ix_sync_mut_session ON keystone.sync_mutations (tenant_id, device_session_id, received_at);

-- AnnexeP_Prestataires_Mobile_Partie2#3
CREATE TABLE keystone.sync_conflicts (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  mutation_id uuid NOT NULL REFERENCES keystone.sync_mutations(id),
  object_type text NOT NULL, object_id uuid NOT NULL, site_id uuid,
  server_version bigint NOT NULL, server_snapshot jsonb NOT NULL, device_payload jsonb NOT NULL,
  reason_code text NOT NULL CHECK (reason_code ~ '^[A-Z][A-Z0-9_]{2,63}$'),   -- tout code du catalogue des messages (A81), contrôlé à l'écriture
                                                         -- par l'existence de `reason_code` dans `keystone.error_codes` (Annexe A §A.10.0) ; exemples : VERSION_CONFLICT,
                                                         -- INVALID_TRANSITION, REPORT_INCOMPLETE, BLOCKING_CHECKPOINT_OPEN, SCAN_REQUIRED
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved_server','resolved_device','resolved_merged','dismissed')),
  resolver_id uuid, resolved_at timestamptz, resolution_note text,
  CONSTRAINT ck_conflict_resolution CHECK (status = 'open' OR (resolver_id IS NOT NULL AND resolution_note IS NOT NULL))
);

-- AnnexeP_Prestataires_Mobile_Partie2#3
CREATE INDEX ix_sync_conflicts_open ON keystone.sync_conflicts (tenant_id, site_id, created_at) WHERE status = 'open';

-- AnnexeTA_Travaux_Amenagement#2
CREATE TABLE keystone.fitout_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                           -- TRV-AAAA-NNNNNN, next_ref('fitout', année)
  occupant_org_id uuid NOT NULL REFERENCES keystone.occupant_organizations(id) ON DELETE RESTRICT,
  client_id uuid REFERENCES keystone.clients(id),              -- fm_provider
  instructing_party text NOT NULL CHECK (instructing_party IN ('operator','fm_company','client')),
  status keystone.fitout_status NOT NULL DEFAULT 'draft',
  work_types keystone.fitout_work_type[] NOT NULL CHECK (cardinality(work_types) >= 1),
  description text NOT NULL,
  common_impacts keystone.fitout_common_impact[] NOT NULL,
  reinforced_review boolean GENERATED ALWAYS AS (NOT (common_impacts = ARRAY['none']::keystone.fitout_common_impact[])) STORED,
  planned_start date NOT NULL, planned_end date NOT NULL,
  work_hours jsonb NOT NULL,                                   -- plages horaires autorisées demandées
  nuisance_slots jsonb NOT NULL DEFAULT '[]',                  -- travaux bruyants ou poussiéreux
  required_permit_rubrics text[] NOT NULL DEFAULT '{}',        -- hot_work, work_at_height, electrical, confined_space, lifting
  site_manager_name text NOT NULL, site_manager_phone text NOT NULL, max_headcount int NOT NULL CHECK (max_headcount > 0),
  rules_acknowledged_at timestamptz, signed_by uuid,           -- règlement de travaux du site, signature de l'administrateur occupant
  entered_by_operator boolean NOT NULL DEFAULT false,          -- demande saisie par l'exploitant pour l'occupant (L9-27)
  info_due_date date,                                          -- échéance de réponse à un complément (L9-08)
  last_info_reminder_at timestamptz,
  instructor_id uuid, approver_id uuid,
  submitted_at timestamptz, decided_at timestamptz, decision_reason text,
  started_at timestamptz, completed_at timestamptz, accepted_at timestamptz, closed_at timestamptz,
  suspended_reason text, withdrawn_reason text,
  authorization_document_id uuid,                              -- autorisation PDF générée (GED)
  as_built_document_ids uuid[] NOT NULL DEFAULT '{}',          -- dossier des ouvrages exécutés
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_fitout_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_fitout_dates CHECK (planned_end >= planned_start),
  CONSTRAINT ck_fitout_none CHECK (NOT ('none' = ANY(common_impacts)) OR cardinality(common_impacts) = 1),
  CONSTRAINT ck_fitout_approver CHECK (NOT reinforced_review OR approver_id IS NULL OR approver_id <> instructor_id)   -- RG-OCC-09
);

-- AnnexeTA_Travaux_Amenagement#2
CREATE INDEX ix_fitout_site ON keystone.fitout_requests (tenant_id, site_id, status, planned_start);

-- AnnexeTA_Travaux_Amenagement#2
CREATE INDEX ix_fitout_org  ON keystone.fitout_requests (tenant_id, occupant_org_id);

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_request_spaces (
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  space_unit_id uuid NOT NULL REFERENCES atlas_core.spaces(id),
  PRIMARY KEY (fitout_request_id, space_unit_id) );

-- AnnexeTA_Travaux_Amenagement#3
-- trigger : chaque espace est occupé par l'organisation de la demande à planned_start (FITOUT_SPACE_NOT_OCCUPIED)

CREATE TABLE keystone.fitout_contractors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),     -- vendors.origin = 'occupant' (Annexe P.1.2)
  scope text NOT NULL, site_lead_name text NOT NULL, site_lead_phone text NOT NULL,
  max_headcount int NOT NULL CHECK (max_headcount > 0),
  clearance_status text NOT NULL DEFAULT 'pending' CHECK (clearance_status IN ('pending','cleared','refused')),
  insurance_valid_until date, tax_certificate_valid_until date,
  prevention_plan_id uuid,                                     -- Annexe C
  cleared_by uuid, cleared_at timestamptz, clearance_reason text,
  CONSTRAINT ck_clearance_reason CHECK (clearance_status <> 'refused' OR clearance_reason IS NOT NULL),
  CONSTRAINT uq_fitout_contractor UNIQUE (fitout_request_id, vendor_id) );

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('layout_plans','technical_notice','insurance_certificate','detailed_schedule',
       'structural_opinion','condition_evidence','reserve_evidence','as_built','other')),
  document_id uuid NOT NULL,                                   -- GED (Annexe G), PDF ou DWG pour les plans
  fitout_contractor_id uuid REFERENCES keystone.fitout_contractors(id),
  valid_until date, uploaded_by uuid NOT NULL, uploaded_at timestamptz NOT NULL DEFAULT now() );

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_visas (                           -- évolution, à valider
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  discipline keystone.fitout_visa_discipline NOT NULL,
  reviewer_id uuid, assigned_by uuid, assigned_at timestamptz,
  decision text CHECK (decision IN ('favourable','favourable_with_conditions','unfavourable')),
  comment text, decided_at timestamptz,
  CONSTRAINT uq_fitout_visa UNIQUE (fitout_request_id, discipline) );

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_conditions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('fire_safety','working_hours','common_area_protection','waste','connections','other')),
  text text NOT NULL, due_date date, evidence_expected text,
  status text NOT NULL DEFAULT 'to_provide' CHECK (status IN ('to_provide','provided','validated')),
  template_code text, validated_by uuid, validated_at timestamptz,
  visa_id uuid REFERENCES keystone.fitout_visas(id),                -- L9-05
  fitout_contractor_id uuid REFERENCES keystone.fitout_contractors(id),
  evidence_refused_reason text );

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('site_visit','acceptance')),
  inspector_id uuid NOT NULL, at timestamptz NOT NULL,
  checklist jsonb NOT NULL,     -- fire_protection_restored, connections_compliant, common_areas_clean, safety_signage, waste_removed
  photo_paths text[] NOT NULL DEFAULT '{}', outcome text CHECK (outcome IN ('compliant','reserves','non_compliant')),
  inspector_signature_id uuid, occupant_signature_id uuid,
  inspection_id uuid,            -- inspection générale (Annexe C) si utilisée
  CONSTRAINT ck_fitout_checklist CHECK (jsonb_matches_schema(keystone.json_schema('fitout_checklist_' || kind), checklist)) );

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_reserves (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  fitout_inspection_id uuid NOT NULL REFERENCES keystone.fitout_inspections(id),
  description text NOT NULL, location_id uuid, is_blocking boolean NOT NULL, due_date date NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','declared_lifted','lifted','reopened')),
  declared_at timestamptz, declared_by uuid, evidence_document_id uuid, validated_by uuid, validated_at timestamptz,
  photo_paths text[] NOT NULL DEFAULT '{}', reopen_reason text,
  CONSTRAINT ck_reserve_reopen CHECK (status <> 'reopened' OR reopen_reason IS NOT NULL) );

-- AnnexeTA_Travaux_Amenagement#3
CREATE TABLE keystone.fitout_status_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fitout_request_id uuid NOT NULL REFERENCES keystone.fitout_requests(id) ON DELETE CASCADE,
  from_status keystone.fitout_status, to_status keystone.fitout_status NOT NULL,
  reason text, meta jsonb NOT NULL DEFAULT '{}',      -- pièces attendues d'un complément, données d'une décision (L9-07)
  actor_id uuid, actor_kind text NOT NULL CHECK (actor_kind IN ('occupant','operator','client','vendor','system')),
  at timestamptz NOT NULL DEFAULT now() );

-- AnnexeTA_Travaux_Amenagement#4
CREATE TABLE keystone.fitout_deposits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, fitout_request_id uuid NOT NULL UNIQUE REFERENCES keystone.fitout_requests(id),
  amount bigint NOT NULL CHECK (amount > 0 AND amount % 5 = 0),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status text NOT NULL DEFAULT 'required' CHECK (status IN ('required','received','partially_retained','retained','refunded')),
  payment_intent_id uuid REFERENCES keystone.payment_intents(id),   -- CinetPay (D08, Annexe IF.4, purpose deposit) ou NULL si reçu hors ligne
  received_mode text CHECK (received_mode IN ('cinetpay','bank_transfer','other')), received_at timestamptz,
  received_ref text, receipt_document_id uuid,                  -- réception hors ligne (L9-18)
  beneficiary_kind text NOT NULL DEFAULT 'tenant' CHECK (beneficiary_kind IN ('tenant','client')),   -- aligné sur l'Annexe IF ; client : Q-L9-07
  amount_mode text NOT NULL CHECK (amount_mode IN ('site_flat','per_m2','per_request')),
  retained_amount bigint NOT NULL DEFAULT 0 CHECK (retained_amount >= 0),
  retention_reasons jsonb NOT NULL DEFAULT '[]',   -- [{kind: reserve|damage|other, reserve_id, amount, justification, document_id}]
  decided_by uuid, decided_at timestamptz, refunded_at timestamptz, outbox_message_ids uuid[] NOT NULL DEFAULT '{}',   -- integration_outbox.message_id
  CONSTRAINT ck_retention CHECK (retained_amount <= amount) );

-- AnnexeTA_Travaux_Amenagement#5
CREATE VIEW keystone.v_vendor_fitout WITH (security_barrier) AS                  -- L9-26, portail fournisseurs
SELECT r.id, r.ref, r.site_id, r.status, r.planned_start, r.planned_end, r.work_hours, r.nuisance_slots,
       r.occupant_org_id, o.name AS occupant_name,                                    -- L9-32
       (SELECT coalesce(array_agg(coalesce(sp.name, sp.code) ORDER BY sp.code), '{}') FROM keystone.fitout_request_spaces fs
          JOIN atlas_core.spaces sp ON sp.id = fs.space_unit_id
         WHERE fs.fitout_request_id = r.id) AS space_names,                          -- L9-32
       c.id AS contractor_line_id, c.scope, c.site_lead_name, c.site_lead_phone, c.max_headcount,
       c.clearance_status, c.clearance_reason, c.prevention_plan_id
  FROM keystone.fitout_contractors c JOIN keystone.fitout_requests r ON r.id = c.fitout_request_id
  JOIN keystone.occupant_organizations o ON o.id = r.occupant_org_id
 WHERE c.vendor_id = keystone.current_vendor() AND r.tenant_id = keystone.current_tenant() AND r.deleted_at IS NULL;

-- AnnexeM_Mode_Prestataire#3
-- Fonction de cloisonnement par site, utilisée par toutes les politiques et vues du portail client
CREATE FUNCTION keystone.client_can_see_site(p_site uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM keystone.site_ext s
    JOIN keystone.client_users cu ON cu.client_id = s.client_id
    WHERE s.site_id = p_site AND cu.user_id = auth.uid() AND cu.tenant_id = keystone.current_tenant()
      AND cu.status = 'active' AND cu.deleted_at IS NULL
      AND (NOT EXISTS (SELECT 1 FROM keystone.client_user_sites x WHERE x.client_user_id = cu.id AND x.deleted_at IS NULL)
           OR EXISTS (SELECT 1 FROM keystone.client_user_sites x WHERE x.client_user_id = cu.id AND x.site_id = p_site AND x.deleted_at IS NULL))) $$;

-- AnnexeM_Mode_Prestataire#4
CREATE TABLE keystone.service_contract_scope (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  contract_id uuid NOT NULL REFERENCES keystone.service_contracts(id) ON DELETE CASCADE,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid REFERENCES keystone.assets(id),          -- NULL : tout le site ; renseigné : périmètre per_asset
  from_date date NOT NULL, to_date date,
  CONSTRAINT ck_scope_dates CHECK (to_date IS NULL OR to_date >= from_date)
);

-- AnnexeM_Mode_Prestataire#4
CREATE INDEX ix_scope_contract ON keystone.service_contract_scope (tenant_id, contract_id, from_date);

-- AnnexeF_SoftFM#3
-- livrés : floor, walls_partitions, glazing, sanitary_fixtures, furniture_surfaces, bins,
-- contact_points (poignées, boutons, rampes), consumables (savon, papier), odour, signage_clean

CREATE TABLE keystone.qc_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, sector_id uuid NOT NULL REFERENCES keystone.sectors(id),
  version smallint NOT NULL DEFAULT 1,
  aql numeric(4,1) NOT NULL DEFAULT 4.0 CHECK (aql IN (4.0, 6.5)),   -- NQA en non-conformités pour 100 unités
  inspection_level text NOT NULL DEFAULT 'II' CHECK (inspection_level = 'II'),
  element_codes text[] NOT NULL CHECK (cardinality(element_codes) >= 1),
  control_frequency text NOT NULL DEFAULT 'monthly' CHECK (control_frequency IN ('weekly','fortnightly','monthly')),
  valid_from date NOT NULL, valid_to date,
  frozen_at timestamptz,                         -- figé au premier tirage : toute modification crée une version
  previous_version_id uuid REFERENCES keystone.qc_profiles(id),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','superseded')),
  approved_by uuid, approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_qc_profile UNIQUE (tenant_id, sector_id, version) );

-- AnnexeU_Surete_Accueil#2
CREATE TABLE keystone.access_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  sector_id uuid REFERENCES keystone.sectors(id) ON DELETE SET NULL,     -- secteur d'accès du zonage « accès contrôlé » (Annexe S)
  code text NOT NULL, name text NOT NULL, is_restricted boolean NOT NULL DEFAULT false,    -- RG-ACC-01
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_access_zone UNIQUE (tenant_id, site_id, code) );

-- AnnexeU_Surete_Accueil#5
CREATE TABLE keystone.checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  location_id uuid NOT NULL REFERENCES keystone.locations(id), sector_id uuid REFERENCES keystone.sectors(id),
  code text NOT NULL, qr_value text NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'), is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_checkpoint_code UNIQUE (tenant_id, site_id, code), CONSTRAINT uq_checkpoint_qr UNIQUE (tenant_id, qr_value) );

-- AnnexeU_Surete_Accueil#5
CREATE TABLE keystone.patrol_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  sector_id uuid REFERENCES keystone.sectors(id),          -- périmètre de ronde (zonage « sûreté et rondes »)
  code text NOT NULL, name text NOT NULL, is_closing_round boolean NOT NULL DEFAULT false,
  expected_minutes int NOT NULL CHECK (expected_minutes > 0),
  recurrence jsonb NOT NULL CHECK (jsonb_matches_schema(keystone.json_schema('patrol_recurrence'), recurrence)),
     -- {"freq":"daily|weekly","byday":["MO",...],"times":["22:00","02:00"]}
  version int NOT NULL DEFAULT 1,                          -- un changement de circuit crée une version
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_patrol_route UNIQUE (tenant_id, site_id, code) );

-- AnnexeU_Surete_Accueil#5
CREATE TABLE keystone.patrol_route_checkpoints (
  route_id uuid NOT NULL REFERENCES keystone.patrol_routes(id) ON DELETE CASCADE,
  checkpoint_id uuid NOT NULL REFERENCES keystone.checkpoints(id) ON DELETE RESTRICT,
  seq smallint NOT NULL CHECK (seq > 0), PRIMARY KEY (route_id, checkpoint_id), UNIQUE (route_id, seq) );

-- AnnexeU_Surete_Accueil#5
CREATE TABLE keystone.patrols (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, route_id uuid NOT NULL REFERENCES keystone.patrol_routes(id),
  agent_id uuid REFERENCES keystone.persons(id),
  planned_start timestamptz NOT NULL, planned_end timestamptz NOT NULL,
  status keystone.patrol_status NOT NULL DEFAULT 'planned',
  route_version int NOT NULL,                              -- version du circuit à la génération
  ssi_inhibition_id uuid,                                  -- ronde compensatoire d'une inhibition SSI (Annexe R)
  started_at timestamptz, closed_at timestamptz, expected_count smallint, scanned_count smallint, justified_count smallint,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT uq_patrol_slot UNIQUE (route_id, planned_start) );

-- AnnexeU_Surete_Accueil#5
-- génération idempotente
CREATE TABLE keystone.patrol_scans (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, patrol_id uuid NOT NULL REFERENCES keystone.patrols(id) ON DELETE CASCADE,
  checkpoint_id uuid NOT NULL REFERENCES keystone.checkpoints(id),
  outcome text NOT NULL DEFAULT 'scanned' CHECK (outcome IN ('scanned','inaccessible')),
  inaccessible_reason text, local_at timestamptz NOT NULL, synced_at timestamptz NOT NULL DEFAULT now(),
  clock_review boolean GENERATED ALWAYS AS (synced_at - local_at > interval '24 hours') STORED,   -- A94
  CONSTRAINT uq_patrol_scan UNIQUE (patrol_id, checkpoint_id),              -- E2 : second scan ignoré
  CONSTRAINT ck_inaccessible CHECK (outcome <> 'inaccessible' OR inaccessible_reason IS NOT NULL) );

-- AnnexeU_Surete_Accueil#5
CREATE INDEX ix_patrol_scan ON keystone.patrol_scans (tenant_id, patrol_id, local_at);

-- AnnexeU_Surete_Accueil#6
-- livrés : shift_start, shift_end, patrol, intrusion, theft, damage, incident, suspicious_person, found_object,
-- technical_alarm, fire_alarm, emergency_services, call_received, instruction, correction, access_denied, other

CREATE TABLE keystone.security_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  seq bigint NOT NULL,                                -- séquence par site, sous verrou consultatif
  at timestamptz NOT NULL,                            -- heure des faits
  local_recorded_at timestamptz NOT NULL,             -- heure de saisie sur l'appareil
  recorded_at timestamptz NOT NULL DEFAULT now(),     -- heure serveur (synchronisation)
  kind text NOT NULL, severity keystone.security_severity NOT NULL,
  location_id uuid NOT NULL REFERENCES keystone.locations(id), checkpoint_id uuid REFERENCES keystone.checkpoints(id),
  description text NOT NULL CHECK (char_length(description) BETWEEN 5 AND 4000),
  alerted_services jsonb NOT NULL DEFAULT '[]',      -- [{"service":"police|firefighters|samu|site_manager|fm_manager","called_at":ts}]
  backdate_reason text,
  corrects_entry_id bigint REFERENCES keystone.security_log(id),
  video_ref text,                                     -- référence d'enregistrement du système vidéo, jamais d'image
  attachment_ids uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(attachment_ids) <= 10),   -- photos (A100), images seulement
  handover_id uuid REFERENCES keystone.security_handover(id),
  hsse_event_id uuid, ticket_id uuid,
  related_entry_id bigint REFERENCES keystone.security_log(id),   -- entrée instruction liée à son origine
  agent_id uuid NOT NULL REFERENCES keystone.persons(id),
  prev_hash bytea, entry_hash bytea NOT NULL,
  CONSTRAINT uq_security_seq UNIQUE (tenant_id, site_id, seq),
  CONSTRAINT ck_correction CHECK ((kind = 'correction') = (corrects_entry_id IS NOT NULL)),
  CONSTRAINT ck_backdate CHECK (at >= local_recorded_at - interval '12 hours'),
  CONSTRAINT ck_backdate_reason CHECK (at >= local_recorded_at - interval '15 minutes' OR backdate_reason IS NOT NULL) );

-- AnnexeU_Surete_Accueil#6
CREATE INDEX ix_security_log ON keystone.security_log (tenant_id, site_id, at DESC);

-- AnnexeU_Surete_Accueil#6
CREATE INDEX ix_security_log_text ON keystone.security_log USING gin (to_tsvector('french', description));

-- AnnexeU_Surete_Accueil#6
CREATE TABLE keystone.security_log_persons (
  log_id bigint NOT NULL REFERENCES keystone.security_log(id),
  seq smallint NOT NULL, quality text NOT NULL CHECK (quality IN ('agent','occupant','visitor','third_party')),
  name text,                                          -- facultatif, minimisation (RG-MCS-03)
  PRIMARY KEY (log_id, seq) );

-- AnnexeU_Surete_Accueil#7
CREATE TABLE keystone.video_requisitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, ref text NOT NULL,    -- RQV-AAAA-NNNNNN
  security_log_id bigint REFERENCES keystone.security_log(id),
  camera_asset_id uuid NOT NULL REFERENCES keystone.assets(id),
  period tstzrange NOT NULL, reason text NOT NULL,
  requester_kind text NOT NULL CHECK (requester_kind IN ('authority','insurer','internal','occupant')),
  requester_name text NOT NULL, requester_reference text,
  status keystone.video_req_status NOT NULL DEFAULT 'requested',
  request_document_id uuid,                         -- demande écrite de l'autorité ou de l'assureur (GED)
  approved_by uuid, approved_at timestamptz,
  extracted_by uuid, extracted_at timestamptz, extraction_ref text,
  extract_sha256 text CHECK (extract_sha256 ~ '^[0-9a-f]{64}$'),
  delivered_to text, delivered_at timestamptz, delivery_proof_document_id uuid,   -- signature de remise (GED)
  refusal_reason text, created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_video_req UNIQUE (tenant_id, ref),
  CONSTRAINT ck_refusal CHECK (status <> 'refused' OR refusal_reason IS NOT NULL),
  CONSTRAINT ck_approver CHECK (approved_by IS NULL OR approved_by <> created_by),
  CONSTRAINT ck_extracted CHECK (status NOT IN ('extracted','delivered') OR (extraction_ref IS NOT NULL AND extract_sha256 IS NOT NULL)),
  CONSTRAINT ck_delivery CHECK (status <> 'delivered' OR (delivered_to IS NOT NULL AND delivery_proof_document_id IS NOT NULL)) );

-- AnnexeU_Surete_Accueil#8
-- RG-VIS-01

CREATE TABLE keystone.visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, visitor_id uuid NOT NULL REFERENCES keystone.visitors(id) ON DELETE CASCADE,
  access_zone_id uuid NOT NULL REFERENCES keystone.access_zones(id),     -- A33, ex zone_id
  escort_person_id uuid REFERENCES keystone.persons(id),
  expected_at timestamptz NOT NULL, expected_end timestamptz NOT NULL,
  status keystone.visit_status NOT NULL DEFAULT 'expected',
  code_hash text,                                   -- SHA-256 du code de visite envoyé (EML-SUR-001)
  preregistered_by uuid, is_spontaneous boolean NOT NULL DEFAULT false, host_confirmed_at timestamptz,
  host_confirm_channel text CHECK (host_confirm_channel IN ('host_app','phone_by_agent')),
  arrived_at timestamptz,                           -- présentation à l'accueil (KPI-SUR-15)
  id_doc_type keystone.id_doc_type,                 -- type seulement, jamais de numéro (A33, RG-VIS-02)
  id_checked_at timestamptz, id_checked_by uuid,
  badge text, badge_returned boolean, checked_in_at timestamptz, checked_out_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_visit_period CHECK (expected_end > expected_at),
  CONSTRAINT ck_visit_checkin CHECK (status <> 'checked_in' OR (checked_in_at IS NOT NULL AND id_checked_at IS NOT NULL)) );

-- AnnexeU_Surete_Accueil#8
CREATE INDEX ix_visit_day ON keystone.visits (tenant_id, site_id, status, expected_at);

-- AnnexeU_Surete_Accueil#9
CREATE TABLE keystone.visitor_denylist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  display_name text NOT NULL,                       -- nom tel que saisi
  name_normalized text NOT NULL,                    -- minuscules, sans accents ni espaces multiples
  company text, company_normalized text,
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 5 AND 300),   -- texte court, sans donnée sensible
  decided_by uuid NOT NULL, decided_at timestamptz NOT NULL DEFAULT now(),
  valid_until date NOT NULL, security_log_id bigint REFERENCES keystone.security_log(id),
  lifted_at timestamptz, lifted_by uuid, lift_reason text,
  CONSTRAINT ck_denylist_duration CHECK (valid_until <= (decided_at::date + 365)),
  CONSTRAINT ck_denylist_lift CHECK (lifted_at IS NULL OR (lifted_by IS NOT NULL AND lift_reason IS NOT NULL)) );

-- AnnexePK_Parking#2
CREATE TABLE keystone.parking_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  code text NOT NULL, name text NOT NULL, kind keystone.parking_zone_kind NOT NULL,
  space_unit_id uuid REFERENCES atlas_core.spaces(id),        -- espace de type parking (Annexe S)
  access_zone_id uuid REFERENCES keystone.access_zones(id),        -- barrière ou contrôle (Annexe U)
  capacity int NOT NULL CHECK (capacity >= 0),
  is_paid boolean NOT NULL DEFAULT false, tariff_id uuid,           -- PK.4
  max_stay_minutes int CHECK (max_stay_minutes > 0),                -- base du dépassement overstay (E18)
  opening_hours jsonb, is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_parking_zone UNIQUE (tenant_id, site_id, code) );

-- AnnexePK_Parking#2
CREATE TABLE keystone.parking_spaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, zone_id uuid NOT NULL REFERENCES keystone.parking_zones(id) ON DELETE CASCADE,
  code text NOT NULL, is_pmr boolean NOT NULL DEFAULT false, is_ev_charging boolean NOT NULL DEFAULT false,
  status keystone.parking_space_status NOT NULL DEFAULT 'free',
  assigned_subscription_id uuid,                                    -- place attribuée à un abonnement nominatif
  plan_id uuid, x numeric(8,5), y numeric(8,5),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_parking_space UNIQUE (zone_id, code) );

-- AnnexePK_Parking#3
CREATE TABLE keystone.parking_access_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, zone_id uuid NOT NULL REFERENCES keystone.parking_zones(id),
  vehicle_id uuid REFERENCES keystone.vehicles(id), plate_normalized text,
  direction keystone.access_direction NOT NULL,                     -- in, out, denied (Annexe U)
  method text NOT NULL CHECK (method IN ('plate_reading','badge','ticket','manual','qr')),
  denial_reason text, reading_confidence numeric(4,3), image_ref text,   -- référence du système de lecture, jamais d'image
  recorded_by uuid, at timestamptz NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now() );

-- AnnexePK_Parking#3
CREATE INDEX ix_parking_access ON keystone.parking_access_logs (tenant_id, zone_id, at DESC);

-- AnnexePK_Parking#3
CREATE TABLE keystone.parking_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, zone_id uuid NOT NULL REFERENCES keystone.parking_zones(id),
  space_id uuid REFERENCES keystone.parking_spaces(id),
  vehicle_id uuid REFERENCES keystone.vehicles(id), plate_normalized text, ticket_code text,
  subscription_id uuid, reservation_id uuid,
  entry_at timestamptz NOT NULL, exit_at timestamptz,
  status keystone.parking_session_status NOT NULL DEFAULT 'open',
  tariff_id uuid, amount bigint CHECK (amount >= 0),               -- calculé à la sortie (PK.4)
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  payment_intent_id uuid REFERENCES keystone.payment_intents(id),   -- Annexe IF.4
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_session_subject CHECK (num_nonnulls(vehicle_id, plate_normalized, ticket_code) >= 1),
  CONSTRAINT ck_session_exit CHECK (exit_at IS NULL OR exit_at >= entry_at) );

-- AnnexePK_Parking#3
CREATE UNIQUE INDEX uq_open_session ON keystone.parking_sessions (tenant_id, site_id, plate_normalized)
  WHERE status = 'open' AND plate_normalized IS NOT NULL;

-- AnnexePK_Parking#5
CREATE TABLE keystone.parking_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, ref text NOT NULL,     -- ABP-AAAA-NNNNNN
  plan_id uuid NOT NULL REFERENCES keystone.parking_subscription_plans(id),
  holder_user_id uuid NOT NULL, occupant_org_id uuid REFERENCES keystone.occupant_organizations(id),
  vehicle_ids uuid[] NOT NULL CHECK (cardinality(vehicle_ids) BETWEEN 1 AND 3),
  assigned_space_id uuid REFERENCES keystone.parking_spaces(id),
  valid_from date NOT NULL, valid_to date NOT NULL,
  amount bigint NOT NULL CHECK (amount >= 0), currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.parking_sub_status NOT NULL DEFAULT 'pending_payment',
  payment_intent_id uuid REFERENCES keystone.payment_intents(id), auto_renew boolean NOT NULL DEFAULT false, cancelled_at timestamptz, cancel_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_parking_sub UNIQUE (tenant_id, ref),
  CONSTRAINT ck_sub_period CHECK (valid_to >= valid_from) );

-- AnnexePK_Parking#5
-- abonnement sans bénéficiaire impossible

CREATE TABLE keystone.parking_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, ref text NOT NULL,     -- RPK-AAAA-NNNNNN
  zone_id uuid NOT NULL REFERENCES keystone.parking_zones(id), space_id uuid REFERENCES keystone.parking_spaces(id),
  booked_by uuid NOT NULL, vehicle_id uuid REFERENCES keystone.vehicles(id), plate_normalized text,
  slot tstzrange NOT NULL, amount bigint NOT NULL DEFAULT 0 CHECK (amount >= 0),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.parking_resa_status NOT NULL, payment_intent_id uuid REFERENCES keystone.payment_intents(id), access_code_hash text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_parking_resa UNIQUE (tenant_id, ref),
  CONSTRAINT ex_parking_resa EXCLUDE USING gist (space_id WITH =, slot WITH &&)
    WHERE (status IN ('pending_payment','confirmed','checked_in') AND space_id IS NOT NULL) );

-- AnnexePK_Parking#7
CREATE TABLE keystone.parking_violations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL, zone_id uuid NOT NULL REFERENCES keystone.parking_zones(id),
  space_id uuid, vehicle_id uuid, plate_normalized text, kind keystone.parking_violation_kind NOT NULL,
  detected_at timestamptz NOT NULL, detected_by uuid, photo_path text,
  security_log_id bigint REFERENCES keystone.security_log(id),        -- entrée de main courante (Annexe U)
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','notified','closed')), note text );

-- AnnexeEN_Energie#2
CREATE TABLE keystone.energy_uses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  code text NOT NULL,                               -- UE-CVC, UE-ECL
  label text NOT NULL,
  kind energy_use_kind NOT NULL,
  fluid energy_fluid NOT NULL,
  is_significant boolean NOT NULL DEFAULT false,    -- UES (§6.3 c)
  significance_basis text,                          -- obligatoire si is_significant
  share_of_consumption numeric(7,4),                -- part de la consommation à la dernière revue, 0 à 1
  relevant_variables normalization_var[] NOT NULL DEFAULT '{}',
  sector_id uuid REFERENCES keystone.sectors(id) ON DELETE RESTRICT,   -- secteur arrosé (Annexe S, Lot 15 E12), usage irrigation seulement
  influencing_persons jsonb NOT NULL DEFAULT '[]',  -- personnes dont le travail influe sur l'UES (§6.3 c)
  last_review_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_energy_use UNIQUE (tenant_id, site_id, code),
  CONSTRAINT ck_ues_basis CHECK (NOT is_significant OR significance_basis IS NOT NULL),
  CONSTRAINT ck_ues_share CHECK (share_of_consumption IS NULL OR share_of_consumption BETWEEN 0 AND 1),
  CONSTRAINT ck_ues_sector CHECK (sector_id IS NULL OR (kind = 'irrigation' AND fluid = 'water'))
);

-- AnnexeEN_Energie#2
CREATE TABLE keystone.energy_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  review_id uuid NOT NULL REFERENCES keystone.energy_reviews(id) ON DELETE CASCADE,
  use_id uuid REFERENCES keystone.energy_uses(id),
  description text NOT NULL,
  est_saving_kwh numeric(18,4) CHECK (est_saving_kwh >= 0),
  est_saving_amount bigint CHECK (est_saving_amount >= 0),     -- FCFA, Money.ts
  est_capex bigint CHECK (est_capex >= 0),
  currency char(3),
  priority int NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 4),
  status text NOT NULL DEFAULT 'identified' CHECK (status IN ('identified','retained','rejected','converted')),
  rejection_reason text,
  action_id uuid,                                   -- energy_actions si convertie
  CONSTRAINT ck_opp_currency CHECK ((est_saving_amount IS NULL AND est_capex IS NULL) OR currency IS NOT NULL),
  CONSTRAINT ck_opp_reject CHECK (status <> 'rejected' OR rejection_reason IS NOT NULL)
);

-- AnnexeEN_Energie#3
-- Surface : alimentée chaque mois depuis v_site_reference_area (Annexe S), source = 'space_module'.
-- Fréquentation : saisie ou import d'un système de comptage, source = 'counting_system'.

CREATE TABLE keystone.energy_baselines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  use_id uuid REFERENCES keystone.energy_uses(id),   -- NULL : site entier
  enpi_code text NOT NULL,                           -- code KPI-ENE du référentiel
  period_start date NOT NULL, period_end date NOT NULL,   -- période de référence, 12 mois minimum
  model baseline_model NOT NULL,
  variables normalization_var[] NOT NULL DEFAULT '{}',
  coefficients jsonb NOT NULL,                       -- {intercept, cdd, footfall...}
  baseline_value numeric(18,4) NOT NULL,             -- valeur de l'IPE sur la période de référence
  r_squared numeric(6,5), cv_rmse numeric(8,5),      -- qualité du modèle de régression
  status baseline_status NOT NULL DEFAULT 'draft',
  revision_reason text,                              -- §6.5 : condition de révision constatée
  supersedes_id uuid REFERENCES keystone.energy_baselines(id),
  approved_by uuid, approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_baseline_len CHECK (period_end >= period_start + interval '12 months'),
  CONSTRAINT ck_baseline_vars CHECK (model = 'ratio' OR cardinality(variables) >= 1),
  CONSTRAINT ck_baseline_rev CHECK (supersedes_id IS NULL OR revision_reason IS NOT NULL)
);

-- AnnexeEN_Energie#3
CREATE UNIQUE INDEX uq_baseline_approved ON keystone.energy_baselines (tenant_id, site_id, COALESCE(use_id, '00000000-0000-0000-0000-000000000000'::uuid), enpi_code)
  WHERE status = 'approved';

-- AnnexeEN_Energie#3
CREATE TABLE keystone.energy_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  use_id uuid REFERENCES keystone.energy_uses(id),
  fm_objective_id uuid,                              -- objectif FM parent (Annexe Q, fm_objectives, §6.2)
  enpi_code text NOT NULL,
  baseline_id uuid NOT NULL REFERENCES keystone.energy_baselines(id),
  improvement_pct numeric(6,3) NOT NULL CHECK (improvement_pct > 0 AND improvement_pct < 100),
  target_value numeric(18,4) NOT NULL,               -- baseline_value fois (1 moins improvement_pct / 100)
  due_date date NOT NULL,
  owner_id uuid REFERENCES keystone.persons(id),
  status energy_target_status NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeEN_Energie#3
CREATE TABLE keystone.energy_action_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  target_id uuid NOT NULL REFERENCES keystone.energy_targets(id) ON DELETE CASCADE,
  title text NOT NULL, owner_id uuid REFERENCES keystone.persons(id),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz
);

-- AnnexeW_Workspace_AdHoc#2
CREATE TABLE keystone.saved_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  screen text NOT NULL CHECK (screen ~ '^[a-z_]+$'),                    -- même clé <ecran> que user_preferences
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 3 AND 60),
  team_id uuid REFERENCES keystone.teams(id) ON DELETE CASCADE,          -- Annexe PL ; NULL : tout le tenant
  surface keystone.surface_code NOT NULL DEFAULT 'console',
  definition jsonb NOT NULL CHECK (pg_column_size(definition) <= 8192), -- même schéma que table.<ecran>.views
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  deleted_at timestamptz,
  CONSTRAINT uq_saved_view UNIQUE NULLS NOT DISTINCT (tenant_id, screen, team_id, name)
);

-- AnnexeW_Workspace_AdHoc#2
CREATE INDEX ix_saved_views_screen ON keystone.saved_views (tenant_id, screen) WHERE deleted_at IS NULL;

-- AnnexeW_Workspace_AdHoc#2
ALTER TABLE keystone.saved_views ENABLE ROW LEVEL SECURITY;

-- AnnexeW_Workspace_AdHoc#2
CREATE POLICY saved_views_read ON keystone.saved_views FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL
  AND (team_id IS NULL OR created_by = auth.uid()
       OR team_id IN (SELECT tm.team_id FROM keystone.team_members tm WHERE tm.person_id = keystone.current_person_id()
                        AND tm.deleted_at IS NULL AND (tm.valid_to IS NULL OR tm.valid_to >= current_date))));

-- AnnexeAdmin_RBAC_Notifications_Partie4#1 (proposition, lot 12)
ALTER TABLE keystone.user_roles
  ADD COLUMN source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','sso','scim')),
  ADD COLUMN mapping_id uuid;

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
-- propriétaire : présente annexe

CREATE TABLE keystone.api_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (char_length(name) BETWEEN 3 AND 60),
  token_prefix text NOT NULL CHECK (token_prefix ~ '^kst_(live|test)_[a-z0-9]{8}$'),
  token_hash bytea NOT NULL UNIQUE,                  -- SHA-256 du jeton complet (256 bits aléatoires), montré une seule fois
  service_profile_id uuid NOT NULL REFERENCES keystone.user_profiles(id) ON DELETE RESTRICT,   -- compte de service
  scopes text[] NOT NULL CHECK (cardinality(scopes) BETWEEN 1 AND 30),
  ip_allowlist cidr[] NOT NULL DEFAULT '{}',          -- vide : toute adresse
  status keystone.api_token_status NOT NULL DEFAULT 'active',
  expires_at timestamptz NOT NULL CHECK (expires_at <= created_at + interval '12 months'),
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid NOT NULL,
  revoked_at timestamptz, revoked_by uuid, revoke_reason text,
  CONSTRAINT ck_api_token_revoked CHECK (status <> 'revoked' OR (revoked_at IS NOT NULL AND revoke_reason IS NOT NULL))
);

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
CREATE INDEX ix_api_tokens_tenant ON keystone.api_tokens (tenant_id, status);

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
CREATE UNIQUE INDEX ux_api_token_name ON keystone.api_tokens (tenant_id, lower(btrim(name))) WHERE status = 'active';

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
-- comptes de service, index déclaré par la présente annexe
ALTER TABLE keystone.api_tokens ENABLE ROW LEVEL SECURITY;

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
-- aucune politique d'écriture : create_api_token, revoke_api_token ; tg_audit attaché (token_hash exclu de la copie au journal)

CREATE TABLE keystone.api_usage_hourly (              -- compteurs, conservation 13 mois
  token_id uuid NOT NULL REFERENCES keystone.api_tokens(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL, hour timestamptz NOT NULL,
  requests int NOT NULL DEFAULT 0, errors_4xx int NOT NULL DEFAULT 0, errors_5xx int NOT NULL DEFAULT 0,
  rate_limited int NOT NULL DEFAULT 0, p95_ms int,
  PRIMARY KEY (token_id, hour)
);

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
CREATE TABLE keystone.webhook_endpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  url text NOT NULL CHECK (url ~ '^https://[^/?#]+(:(443|8443))?(/.*)?$' AND char_length(url) <= 2048),
  description text CHECK (description IS NULL OR char_length(description) <= 200),
  event_types text[] NOT NULL CHECK (cardinality(event_types) >= 1),
  service_profile_id uuid NOT NULL REFERENCES keystone.user_profiles(id) ON DELETE RESTRICT,   -- périmètre des événements
  secret_ref uuid NOT NULL,                           -- Supabase Vault ; secret « whsec_ » de 256 bits
  previous_secret_ref uuid, previous_secret_expires_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','disabled')),
  disabled_reason text, consecutive_failures int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid, deleted_at timestamptz
);

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
CREATE TABLE keystone.webhook_deliveries (            -- conservation 30 jours
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  endpoint_id uuid NOT NULL REFERENCES keystone.webhook_endpoints(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES keystone.api_events(id) ON DELETE CASCADE,
  attempt smallint NOT NULL DEFAULT 1 CHECK (attempt BETWEEN 1 AND 8),
  status keystone.webhook_delivery_status NOT NULL DEFAULT 'pending',
  http_status smallint, duration_ms int,
  response_excerpt text CHECK (response_excerpt IS NULL OR char_length(response_excerpt) <= 500),
  next_attempt_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_delivery UNIQUE (endpoint_id, event_id, attempt)
);

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
CREATE INDEX ix_deliveries_due ON keystone.webhook_deliveries (next_attempt_at) WHERE status = 'pending';

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
ALTER TABLE keystone.webhook_endpoints ENABLE ROW LEVEL SECURITY;

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
ALTER TABLE keystone.webhook_deliveries ENABLE ROW LEVEL SECURITY;

-- AnnexeA_Socle#3
-- Permission RBAC du profil actif
CREATE OR REPLACE FUNCTION keystone.has_permission(p_code text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1
    FROM keystone.user_roles ur
    JOIN keystone.role_permissions rp ON rp.role_id = ur.role_id
    JOIN keystone.users u ON u.id = ur.user_id AND u.status = 'active'
    WHERE ur.profile_id = keystone.active_profile()
      AND rp.permission_code = p_code) $$;

-- AnnexeA_Socle#3
-- Entités juridiques du périmètre du profil actif
CREATE OR REPLACE FUNCTION keystone.user_entities() RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT entity_id FROM keystone.user_scope
  WHERE profile_id = keystone.active_profile() AND entity_id IS NOT NULL $$;

-- AnnexeA_Socle#3
-- Sites du périmètre : sites des entités du périmètre, plus sites accordés un par un
CREATE OR REPLACE FUNCTION keystone.user_sites() RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, atlas_core, pg_temp AS $$
  SELECT s.id FROM atlas_core.sites s
  WHERE s.tenant_id = keystone.current_tenant()
    AND ( keystone.has_permission('scope.all')
       OR s.legal_entity_id IN (SELECT keystone.user_entities())
       OR s.id IN (SELECT site_id FROM keystone.user_scope
                   WHERE profile_id = keystone.active_profile() AND site_id IS NOT NULL)) $$;

-- AnnexeA_Socle#3
-- Site dans le périmètre (forme booléenne, utilisée par les politiques RLS de toutes les annexes)
CREATE OR REPLACE FUNCTION keystone.site_in_scope(p_site uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, atlas_core, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM keystone.user_sites() AS u(id) WHERE u.id = p_site) $$;

-- AnnexeA_Socle#4
CREATE OR REPLACE FUNCTION keystone.current_occupant_org() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT ou.occupant_org_id
  FROM keystone.user_profiles p
  JOIN keystone.occupant_users ou ON ou.id = p.occupant_user_id AND ou.status = 'active'
                                 AND ou.tenant_id = keystone.current_tenant() AND ou.user_id = auth.uid()
  JOIN keystone.occupant_organizations o ON o.id = ou.occupant_org_id AND o.status = 'active' AND o.deleted_at IS NULL
  WHERE p.id = keystone.active_profile() AND p.kind = 'occupant' $$;

-- AnnexeA_Socle#14
CREATE VIEW keystone.sites WITH (security_barrier) AS
SELECT s.id, s.tenant_id, s.legal_entity_id, s.code, s.name, s.address, s.country_code, s.time_zone,
       s.latitude, s.longitude, s.boundary, s.declared_surface_m2, s.status AS spatial_status,
       coalesce(e.ops_status, 'pre_opening') AS status, e.opened_on, e.closed_at, e.closed_reason,
       coalesce(e.regulatory_suspended, false) AS regulatory_suspended, e.client_id, e.fire_class, e.atex_zone,
       e.business_calendar_id, keystone.site_opening_hours_json(s.id) AS opening_hours
FROM atlas_core.sites s
LEFT JOIN keystone.site_ext e ON e.site_id = s.id
WHERE s.tenant_id = keystone.current_tenant() AND s.status <> 'draft' AND keystone.site_in_scope(s.id);

-- AnnexeA_Socle#14
CREATE VIEW keystone.buildings WITH (security_barrier) AS
SELECT b.id, b.tenant_id, b.site_id, b.code, b.name, b.footprint, b.status AS spatial_status
FROM atlas_core.buildings b
WHERE b.tenant_id = keystone.current_tenant() AND b.status <> 'draft' AND keystone.site_in_scope(b.site_id);

-- AnnexeA_Socle#14
CREATE VIEW keystone.floors WITH (security_barrier) AS            -- nom conservé pour le corpus
SELECT l.id, l.tenant_id, l.building_id, b.site_id, l.level, l.code, l.name, l.outline, l.status AS spatial_status
FROM atlas_core.levels l JOIN atlas_core.buildings b ON b.id = l.building_id
WHERE l.tenant_id = keystone.current_tenant() AND l.status <> 'draft' AND keystone.site_in_scope(b.site_id);

-- AnnexeA_Socle#14
CREATE VIEW keystone.space_units WITH (security_barrier) AS       -- nom conservé (Annexe S, CDC v3 §6.27)
SELECT sp.id, sp.tenant_id, sp.level_id AS floor_id, b.site_id, sp.plan_ref AS plan_id, sp.parent_space_id, sp.code, sp.commercial_code,
       sp.name, sp.space_type AS type, sp.is_aggregate_parent, sp.polygon, sp.geom, sp.geom_local,
       sp.surface_m2, sp.surface_method, sp.measure_convention, sp.source, sp.source_ref AS import_id,
       sp.is_verified, sp.verified_by, sp.verified_at, sp.status AS spatial_status, sp.version,
       e.location_id, coalesce(e.occupancy_status, 'vacant') AS status, e.occupant_kind, e.occupant_ref,
       coalesce(e.is_public, false) AS is_public, e.area_class_id, e.usage_label, e.capacity
FROM atlas_core.spaces sp
JOIN atlas_core.levels l ON l.id = sp.level_id
JOIN atlas_core.buildings b ON b.id = l.building_id
LEFT JOIN keystone.space_ext e ON e.space_id = sp.id
WHERE sp.tenant_id = keystone.current_tenant() AND sp.status <> 'draft' AND keystone.site_in_scope(b.site_id);

-- AnnexeA_Socle_Partie2#7
CREATE TABLE keystone.asset_components (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  parent_component_id uuid REFERENCES keystone.asset_components(id) ON DELETE RESTRICT,
  code text NOT NULL,                                  -- préfixe verrouillé (code de l'actif) plus suffixe
  name text NOT NULL,
  position text,
  ref text,
  qty numeric(14,3) NOT NULL DEFAULT 1 CHECK (qty > 0),
  is_replaceable boolean NOT NULL DEFAULT true,
  spare_part_id uuid REFERENCES keystone.spare_parts(id) ON DELETE SET NULL,
  criticality asset_criticality NOT NULL DEFAULT 'medium',
  iso14224_class text,
  taxonomy_level smallint NOT NULL DEFAULT 8 CHECK (taxonomy_level BETWEEN 7 AND 9),   -- sous-unité, élément maintenable, pièce
  expected_life_months int CHECK (expected_life_months > 0),
  label_printed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_components_code UNIQUE (tenant_id, asset_id, code),
  CONSTRAINT ck_components_no_self CHECK (parent_component_id <> id)
);

-- AnnexeA_Socle_Partie2#7
CREATE INDEX ix_components_asset  ON keystone.asset_components (tenant_id, asset_id);

-- AnnexeA_Socle_Partie2#7
CREATE INDEX ix_components_parent ON keystone.asset_components (tenant_id, parent_component_id);

-- AnnexeA_Socle_Partie2#8
CREATE TABLE keystone.asset_identifiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE RESTRICT,
  type identifier_type NOT NULL,
  value text NOT NULL CHECK (length(value) BETWEEN 3 AND 128),
  printed_at timestamptz, printed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_identifier UNIQUE (tenant_id, type, value),
  CONSTRAINT ck_identifier_target CHECK (num_nonnulls(asset_id, component_id) = 1)
);

-- AnnexeA_Socle_Partie2#8
CREATE INDEX ix_identifiers_value ON keystone.asset_identifiers (tenant_id, value);

-- AnnexeA_Socle_Partie3#3
CREATE TABLE keystone.asset_warranties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE CASCADE,
  kind keystone.warranty_kind NOT NULL,
  vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE RESTRICT,     -- garant
  start_date date NOT NULL, end_date date NOT NULL,
  conditions text,                                  -- exclusions, entretien exigé, plafond
  claim_contact text,
  document_id uuid REFERENCES keystone.ged_documents(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_warranty_dates CHECK (end_date >= start_date)
);

-- AnnexeA_Socle_Partie3#3
CREATE INDEX ix_warranty_asset ON keystone.asset_warranties (tenant_id, asset_id, end_date) WHERE deleted_at IS NULL;

-- AnnexeA_Socle_Partie3#3
CREATE TABLE keystone.asset_spare_parts (            -- pièces de rechange recommandées, liées au stock (Annexe B)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE CASCADE,
  spare_part_id uuid NOT NULL REFERENCES keystone.spare_parts(id) ON DELETE RESTRICT,
  recommended_qty numeric(14,3) NOT NULL DEFAULT 1 CHECK (recommended_qty > 0),
  is_critical_spare boolean NOT NULL DEFAULT false,  -- pièce dont l'absence prolonge un arrêt
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT uq_asset_spare UNIQUE NULLS NOT DISTINCT (asset_id, component_id, spare_part_id)   -- DUPLICATE_ENTRY
);

-- AnnexeA_Socle_Partie4#4
CREATE POLICY bulk_ops_read ON keystone.bulk_operations FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND (created_by = auth.uid() OR keystone.has_permission('audit_trail.read')));

-- AnnexeA_Socle_Partie4#6
CREATE TABLE keystone.undo_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,                                 -- auteur de l'action, seul à pouvoir la défaire
  profile_id uuid NOT NULL REFERENCES keystone.user_profiles(id) ON DELETE CASCADE,
  action_key text NOT NULL REFERENCES keystone.undo_action_catalog(action_key),
  entity text NOT NULL, object_ids uuid[] NOT NULL CHECK (cardinality(object_ids) BETWEEN 1 AND 200),
  inverse_payload jsonb NOT NULL,                        -- {"<id>": valeurs d'avant l'action}
  versions_after jsonb NOT NULL,                         -- {"<id>": row_version ou updated_at après l'action}
  bulk_operation_id uuid REFERENCES keystone.bulk_operations(id),
  status keystone.undo_status NOT NULL DEFAULT 'available',
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  used_at timestamptz, result jsonb
);

-- AnnexeA_Socle_Partie4#6
CREATE INDEX ix_undo_user ON keystone.undo_tokens (tenant_id, user_id, created_at DESC) WHERE status = 'available';

-- AnnexeA_Socle_Partie4#6
ALTER TABLE keystone.undo_tokens ENABLE ROW LEVEL SECURITY;

-- AnnexeA_Socle_Partie4#6
CREATE POLICY undo_own ON keystone.undo_tokens FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND user_id = auth.uid());

-- AnnexeAdmin_RBAC_Notifications#12
CREATE POLICY user_profiles_select ON keystone.user_profiles FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL AND (
    user_id = auth.uid()
    OR keystone.has_permission('user.manage')
    OR (kind = 'vendor'   AND vendor_user_id IN (SELECT id FROM keystone.vendor_users
                          WHERE vendor_id = keystone.current_vendor())
                          AND keystone.has_permission('vendor_portal.admin'))
    OR (kind = 'client'   AND client_user_id IN (SELECT id FROM keystone.client_users WHERE client_id = keystone.current_client())
                          AND keystone.has_permission('client_portal.admin'))
    OR (kind = 'occupant' AND occupant_user_id IN (SELECT id FROM keystone.occupant_users WHERE occupant_org_id = keystone.current_occupant_org())
                          AND keystone.has_permission('occupant_portal.admin'))));

-- AnnexeG_GED#5
-- keystone.asset_category_required_docs : définie en Annexe A partie 2 (propriétaire de la catégorie d'actif), lue ici
CREATE VIEW keystone.v_asset_missing_docs WITH (security_barrier) AS   -- alerte de l'onglet Documents, KPI-GED-01
  SELECT a.tenant_id, a.id AS asset_id, a.site_id, r.classification_id, r.is_mandatory
  FROM keystone.assets a
  JOIN keystone.asset_category_required_docs r ON r.category_id = a.category_id AND r.tenant_id = a.tenant_id
  WHERE a.deleted_at IS NULL AND a.site_id IN (SELECT keystone.user_sites())
    AND NOT EXISTS (SELECT 1 FROM keystone.doc_links l JOIN keystone.ged_documents d ON d.id = l.document_id
                    WHERE l.link_kind = 'attachment' AND l.entity_type = 'asset' AND l.entity_id = a.id
                      AND d.classification_id = r.classification_id AND d.status = 'active');

-- AnnexeS_Space_Management#8
CREATE FUNCTION keystone.sectors_of_location(p_location uuid, p_zoning_type text) RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT ss.sector_id
    FROM keystone.space_units su
    JOIN keystone.sector_spaces ss ON ss.space_unit_id = su.id
    JOIN keystone.sectors s ON s.id = ss.sector_id
    JOIN keystone.zonings z ON z.id = s.zoning_id AND z.status = 'published' AND z.zoning_type = p_zoning_type
   WHERE su.location_id = p_location AND su.tenant_id = keystone.current_tenant() AND su.spatial_status = 'published' $$;

-- AnnexeS_Space_Management_Partie2#2
CREATE POLICY asset_pos_select ON keystone.asset_positions FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL AND EXISTS (
    SELECT 1 FROM keystone.assets a WHERE a.id = asset_id AND keystone.site_in_scope(a.site_id)));

-- AnnexePL_Planning_Equipes#10
CREATE OR REPLACE FUNCTION keystone.person_in_scope(p_person uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT keystone.has_permission('scope.all')
      OR EXISTS (SELECT 1 FROM keystone.team_members m JOIN keystone.teams t ON t.id = m.team_id
                 WHERE m.person_id = p_person AND m.deleted_at IS NULL
                   AND (m.valid_to IS NULL OR m.valid_to >= current_date - 90)
                   AND (t.site_id IS NULL OR keystone.site_in_scope(t.site_id)))
      OR EXISTS (SELECT 1 FROM keystone.shifts s
                 WHERE s.person_id = p_person AND s.deleted_at IS NULL
                   AND s.starts_at BETWEEN now() - interval '90 days' AND now() + interval '180 days'
                   AND keystone.site_in_scope(s.site_id)) $$;

-- AnnexeB_GMAO_Partie3#12
CREATE TABLE keystone.asset_meters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  code text NOT NULL,
  label text NOT NULL,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,       -- compteur d'actif
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE SET NULL,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL, -- compteur de lieu (énergie, eau)
  space_unit_id uuid,                                                    -- Annexe S, sous-comptage par espace
  parent_id uuid REFERENCES keystone.asset_meters(id),                   -- arbre de comptage (sous-comptage)
  kind meter_kind NOT NULL,
  unit text NOT NULL,
  purpose text[] NOT NULL CHECK (purpose <@ ARRAY['maintenance','energy','environment','rebilling']),
  usage energy_use_kind,                        -- usage énergétique principal (énumération de l'Annexe EN) ; NULL hors énergie
  fluid energy_fluid,                           -- Annexe EN ; obligatoire si purpose contient energy
  vendor_id uuid REFERENCES keystone.vendors(id),           -- concessionnaire ou fournisseur d'énergie (Annexe EN)
  is_billing_meter boolean NOT NULL DEFAULT false,          -- compteur de facturation du fournisseur
  occupant_org_id uuid,                                     -- Annexe D, refacturation à un occupant
  tariff_id uuid,                                           -- Annexe EN, energy_tariffs
  photo_required boolean NOT NULL DEFAULT false,            -- photo de l'afficheur exigée à chaque relevé manuel
  is_cumulative boolean NOT NULL DEFAULT true,  -- index cumulé (faux : valeur instantanée)
  multiplier numeric(12,6) NOT NULL DEFAULT 1 CHECK (multiplier > 0),   -- rapport de transformation
  rollover_value numeric(18,4),                 -- valeur de passage à zéro d'un totalisateur
  outlier_factor numeric(6,2) NOT NULL DEFAULT 5 CHECK (outlier_factor > 1),
  iot_device_id uuid,                           -- Annexe I
  auto_reading_interval_min int CHECK (auto_reading_interval_min >= 1),  -- fréquence d'écriture des relevés IoT (Annexe I)
  last_value numeric(18,4), last_read_at timestamptz,
  avg_daily_usage numeric(18,4),                -- recalculé par job, base 90 jours
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_meter_code UNIQUE (tenant_id, code),
  CONSTRAINT ck_meter_target CHECK (asset_id IS NOT NULL OR location_id IS NOT NULL OR space_unit_id IS NOT NULL),
  CONSTRAINT ck_meter_self CHECK (parent_id IS DISTINCT FROM id),
  CONSTRAINT ck_meter_fluid CHECK (NOT ('energy' = ANY (purpose)) OR fluid IS NOT NULL) );

-- AnnexeB_GMAO_Partie3#13
CREATE TABLE keystone.meter_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  meter_id uuid NOT NULL REFERENCES keystone.asset_meters(id) ON DELETE RESTRICT,
  value numeric(18,4) NOT NULL,                 -- valeur lue sur l'afficheur
  value_normalized numeric(18,4) NOT NULL,      -- value fois multiplier
  delta numeric(18,4),                          -- consommation depuis le relevé valide précédent
  read_at timestamptz NOT NULL,                 -- occurred_at de l'appareil borné (A94)
  received_at timestamptz NOT NULL DEFAULT now(),
  clock_review boolean GENERATED ALWAYS AS (received_at - read_at > interval '24 hours') STORED,
  source text NOT NULL CHECK (source IN ('manual','iot','gtb','import','round')),
  device_id uuid,                               -- capteur source (Annexe I)
  round_id uuid, work_order_id uuid,
  reset_declared boolean NOT NULL DEFAULT false, reset_reason text,   -- remplacement ou remise à zéro
  rollover boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'valid' CHECK (status IN ('valid','to_review','rejected')),
  review_code text CHECK (review_code IN ('METER_INDEX_DECREASING','METER_READING_OUTLIER')),
  reviewed_by uuid, reviewed_at timestamptz,
  photo_path text, recorded_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  review_reason text,
  CONSTRAINT ck_reading_reset CHECK (NOT reset_declared OR reset_reason IS NOT NULL) );

-- AnnexeB_GMAO_Partie3#13
CREATE UNIQUE INDEX uq_reading_minute ON keystone.meter_readings (meter_id, date_trunc('minute', read_at AT TIME ZONE 'UTC'));

-- AnnexeB_GMAO_Partie3#13
-- DUPLICATE_READING
CREATE INDEX ix_reading_meter ON keystone.meter_readings (tenant_id, meter_id, read_at DESC);

-- AnnexeB_GMAO_Partie3#15
CREATE TABLE keystone.meter_reading_round_items (
  round_id uuid NOT NULL REFERENCES keystone.meter_reading_rounds(id) ON DELETE CASCADE,
  meter_id uuid NOT NULL REFERENCES keystone.asset_meters(id),
  tenant_id uuid NOT NULL, position int NOT NULL,
  PRIMARY KEY (round_id, meter_id) );

-- AnnexeB_GMAO_Partie3#15
CREATE TABLE keystone.meter_reading_round_run_items (       -- L7-11 et L17-19 (une seule table)
  run_id uuid NOT NULL REFERENCES keystone.meter_reading_round_runs(id) ON DELETE CASCADE,
  meter_id uuid NOT NULL REFERENCES keystone.asset_meters(id),
  tenant_id uuid NOT NULL,
  reading_id uuid REFERENCES keystone.meter_readings(id),
  skip_reason text, skipped_at timestamptz,
  PRIMARY KEY (run_id, meter_id),
  CONSTRAINT ck_item_skip CHECK (skipped_at IS NULL OR skip_reason IS NOT NULL) );

-- AnnexeMO_Modeles_OT#2
CREATE POLICY wo_templates_select ON keystone.wo_templates FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND deleted_at IS NULL
         AND (keystone.has_permission('plan.manage') OR keystone.has_permission('wo.create')));

-- AnnexeMO_Modeles_OT#2
-- Le filtrage par client se fait dans la RPC de création et dans la vue de sélection :
CREATE VIEW keystone.v_wo_templates_for_site WITH (security_barrier) AS
  SELECT t.*, e.site_id
  FROM keystone.wo_templates t
  JOIN keystone.site_ext e ON e.tenant_id = t.tenant_id        -- extension du site atlas_core (A66)
  WHERE t.is_active AND t.deleted_at IS NULL
    AND e.site_id IN (SELECT keystone.user_sites())
    AND (t.client_id IS NULL OR t.client_id = e.client_id);

-- AnnexeAM_AMDEC_Fiabilite#2
CREATE TABLE keystone.fmea_studies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                             -- AMD-AAAA-NNNNNN
  title text NOT NULL,
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE RESTRICT,
  category_id uuid REFERENCES keystone.asset_categories(id) ON DELETE RESTRICT,
  scale_version int NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','validated','revised','archived')),
  version int NOT NULL DEFAULT 1,
  team_person_ids uuid[] NOT NULL DEFAULT '{}',
  validated_by uuid, validated_at timestamptz,
  reviewed_on date, next_review date,
  review_trigger text CHECK (review_trigger IN ('annual','major_event','new_failure_mode','manual')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_fmea_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_fmea_scope CHECK (num_nonnulls(asset_id, category_id) = 1
                                  AND (component_id IS NULL OR asset_id IS NOT NULL)),
  CONSTRAINT ck_fmea_validator CHECK (validated_by IS NULL OR validated_by <> created_by) );

-- AnnexeAM_AMDEC_Fiabilite#2
CREATE TABLE keystone.fmea_modes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  study_id uuid NOT NULL REFERENCES keystone.fmea_studies(id) ON DELETE CASCADE,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE SET NULL,
  function text NOT NULL,                        -- fonction assurée
  iso14224_code text NOT NULL,                   -- mode de défaillance, iso14224_codes (failure_mode)
  failure_mode text NOT NULL,                    -- libellé métier
  mechanism_code text, cause_code text,          -- iso14224_codes (failure_mechanism, failure_cause)
  cause text,
  effect_local text NOT NULL, effect_system text, effect_end text NOT NULL,
  prevention_controls text, detection_controls text,
  detection_method_code text,                    -- iso14224_codes (detection_method)
  severity smallint NOT NULL CHECK (severity BETWEEN 1 AND 10),
  occurrence smallint NOT NULL CHECK (occurrence BETWEEN 1 AND 10),
  detection smallint NOT NULL CHECK (detection BETWEEN 1 AND 10),
  rpn smallint GENERATED ALWAYS AS (severity * occurrence * detection) STORED,
  action_priority text NOT NULL CHECK (action_priority IN ('high','medium','low')),   -- tg_fmea_action_priority (AM.2.4)
  occurrence_suggested smallint, occurrence_suggested_lambda numeric(10,4), occurrence_suggested_at timestamptz,
  recommended_action text, action_owner_id uuid, action_due date,
  action_status text CHECK (action_status IN ('open','in_progress','done','cancelled')),
  adjusted_plan_id uuid REFERENCES keystone.maintenance_plans(id),   -- nouvelle version de gamme créée
  severity_after smallint CHECK (severity_after BETWEEN 1 AND 10),
  occurrence_after smallint CHECK (occurrence_after BETWEEN 1 AND 10),
  detection_after smallint CHECK (detection_after BETWEEN 1 AND 10),
  rpn_after smallint GENERATED ALWAYS AS (severity_after * occurrence_after * detection_after) STORED,
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','field_proposal','ai_proposal')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_fmea_action CHECK (action_priority = 'low' OR recommended_action IS NOT NULL
                                   OR action_status IS NULL) );

-- AnnexeAM_AMDEC_Fiabilite#2
CREATE INDEX ix_fmea_rpn ON keystone.fmea_modes (tenant_id, rpn DESC);

-- AnnexeAM_AMDEC_Fiabilite#2
CREATE INDEX ix_fmea_component ON keystone.fmea_modes (tenant_id, component_id);

-- AnnexeAM_AMDEC_Fiabilite#2
CREATE INDEX ix_fmea_code ON keystone.fmea_modes (tenant_id, iso14224_code);

-- AnnexeAM_AMDEC_Fiabilite#2
CREATE TABLE keystone.fmea_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  study_id uuid NOT NULL REFERENCES keystone.fmea_studies(id) ON DELETE CASCADE,
  trigger text NOT NULL CHECK (trigger IN ('annual','major_event','new_failure_mode','manual')),
  trigger_ref uuid,                              -- hsse_events.id, asset_downtimes.id, work_orders.id
  due_on date NOT NULL, done_on date, done_by uuid, summary text );

-- AnnexeAM_AMDEC_Fiabilite#7
CREATE TABLE keystone.capex_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  ref text NOT NULL,                             -- CPX-AAAA-NNNNNN
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  client_id uuid,                                -- fm_provider : client du site
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  component_id uuid REFERENCES keystone.asset_components(id),
  action text NOT NULL CHECK (action IN ('refurbish','replace','upgrade','decommission')),
  domain text NOT NULL,                          -- famille FM (CVC, électricité, levage)
  target_year smallint NOT NULL,
  est_amount bigint NOT NULL CHECK (est_amount >= 0),   -- estimation présentée, unité de la devise
  currency char(3) NOT NULL,
  justification text NOT NULL,
  condition_factor smallint CHECK (condition_factor BETWEEN 1 AND 5),
  end_of_life_factor smallint CHECK (end_of_life_factor BETWEEN 1 AND 5),
  reliability_factor smallint CHECK (reliability_factor BETWEEN 1 AND 5),
  criticality_weight smallint NOT NULL CHECK (criticality_weight BETWEEN 1 AND 4),
  priority_score numeric(5,2),                   -- calculé, AM.6.3
  priority_class text CHECK (priority_class IN ('P1','P2','P3','P4')),
  lcc_id uuid REFERENCES keystone.asset_lifecycle_costs(id),
  fmea_mode_id uuid REFERENCES keystone.fmea_modes(id),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','proposed','approved','rejected','planned','done')),
  decided_by uuid, decided_at timestamptz, decision_reason text,
  published_to_client boolean NOT NULL DEFAULT false, published_at timestamptz, published_by uuid,
  client_comment text CHECK (char_length(client_comment) <= 2000),
  client_comment_by uuid, client_comment_at timestamptz,   -- utilisateur du portail client (PC-05)
  factor_override_reason text,                   -- facteur saisi à la place de la valeur calculée
  completed_ref_kind text CHECK (completed_ref_kind IN ('work_order','purchase_order','project')), completed_ref uuid,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_cpx_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_cpx_publish CHECK (NOT published_to_client OR client_id IS NOT NULL),
  CONSTRAINT ck_cpx_decision CHECK (status NOT IN ('approved','rejected') OR decision_reason IS NOT NULL) );

-- AnnexeAM_AMDEC_Fiabilite#7
CREATE TABLE keystone.capex_plan_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  plan_id uuid NOT NULL REFERENCES keystone.capex_plans(id) ON DELETE CASCADE,
  recommendation_id uuid NOT NULL REFERENCES keystone.capex_recommendations(id),
  year smallint NOT NULL,
  amount bigint NOT NULL CHECK (amount >= 0),
  CONSTRAINT uq_cpl UNIQUE (plan_id, recommendation_id, year) );

-- AnnexeC_HSSE_Partie2#4
-- INSERT, UPDATE : aucune politique pour authenticated ; écriture par upsert_risk et review_risk, mêmes conditions par catégorie, refus PERMISSION_DENIED.

-- DUER publié : tout utilisateur interne du périmètre de l'entité (consultation des travailleurs, ISO 45001:2018 §5.4)
CREATE POLICY duer_versions_read ON keystone.duer_versions FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL
  AND legal_entity_id IN (SELECT s.legal_entity_id FROM atlas_core.sites s
                          WHERE s.id IN (SELECT keystone.user_sites()))
  AND ( keystone.has_permission('risk.manage')
     OR (status = 'published'
         AND EXISTS (SELECT 1 FROM keystone.user_profiles p
                     WHERE p.id = keystone.active_profile() AND p.kind = 'internal'
                       AND p.status = 'active'))));

-- AnnexeC_HSSE_Partie2#13
CREATE TABLE keystone.prevention_plans (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),          -- y compris type occupant_contractor (Annexe TA)
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  occupant_org_id uuid REFERENCES keystone.occupant_organizations(id),   -- entreprise d'un occupant (Annexe D)
  fitout_request_id uuid REFERENCES keystone.fitout_requests(id),        -- travaux d'aménagement (Annexe TA)
  ref text NOT NULL,                                   -- PDP-2026-000012
  scope text NOT NULL,
  emergency_instructions text NOT NULL,
  joint_inspection_on date NOT NULL,
  joint_inspection_participants jsonb NOT NULL,        -- [{"person_id"} ou {"name","company"}]
  valid_from date NOT NULL, valid_until date NOT NULL,
  status keystone.prevention_plan_status NOT NULL DEFAULT 'draft',
  company_signature_sha256 text, company_signed_by uuid, company_signed_at timestamptz,   -- empreinte de la signature (tracé, saisie ou Advist)
  vendor_signature_sha256 text, vendor_signed_by uuid, vendor_signed_at timestamptz,
  revision_of uuid REFERENCES keystone.prevention_plans(id),
  CONSTRAINT uq_pdp_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_pdp_dates CHECK (valid_until >= valid_from AND valid_until <= valid_from + interval '12 months'),
  CONSTRAINT ck_pdp_occ CHECK (fitout_request_id IS NULL OR occupant_org_id IS NOT NULL),
  CONSTRAINT ck_pdp_signed CHECK (status <> 'signed' OR (company_signed_at IS NOT NULL AND vendor_signed_at IS NOT NULL))
);

-- AnnexeC_HSSE_Partie2#13
CREATE INDEX ix_pdp_valid ON keystone.prevention_plans (tenant_id, vendor_id, site_id, valid_until) WHERE status = 'signed';

-- AnnexeC_HSSE_Partie2#13
CREATE TABLE keystone.prevention_plan_risks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  plan_id uuid NOT NULL REFERENCES keystone.prevention_plans(id) ON DELETE CASCADE,
  position int NOT NULL, risk text NOT NULL, measure text NOT NULL,
  responsible_party keystone.responsible_party NOT NULL,
  responsible_person_id uuid REFERENCES keystone.persons(id)
);

-- AnnexeC_HSSE_Partie2#13
CREATE FUNCTION keystone.prevention_plan_valid(p_vendor uuid, p_site uuid, p_date date) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM keystone.prevention_plans
    WHERE tenant_id = keystone.current_tenant() AND vendor_id = p_vendor AND site_id = p_site
      AND status = 'signed' AND p_date BETWEEN valid_from AND valid_until AND deleted_at IS NULL) $$;

-- AnnexeC_HSSE_Partie4#3
CREATE POLICY mv_select ON keystone.medical_visits FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND keystone.has_permission('event.medical_read')
  AND EXISTS (SELECT 1 FROM keystone.persons p WHERE p.id = person_id AND p.tenant_id = keystone.current_tenant()));

-- AnnexeU_Surete_Accueil#2
CREATE TABLE keystone.access_rights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, access_zone_id uuid NOT NULL REFERENCES keystone.access_zones(id) ON DELETE CASCADE,
  person_id uuid REFERENCES keystone.persons(id) ON DELETE CASCADE,
  visit_id uuid REFERENCES keystone.visits(id) ON DELETE CASCADE,
  occupant_org_id uuid REFERENCES keystone.occupant_organizations(id) ON DELETE CASCADE,
  vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE CASCADE,
  origin keystone.access_right_origin NOT NULL, origin_ref_id uuid,     -- dossier TA, créneau de quai, abonnement PK
  valid_from timestamptz NOT NULL, valid_to timestamptz,
  status keystone.access_right_status NOT NULL DEFAULT 'pending',
  suspended_reason text, revoked_at timestamptz, revoked_reason text, last_reviewed_at timestamptz,
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_right_holder CHECK (num_nonnulls(person_id, visit_id, occupant_org_id, vendor_id) = 1),
  CONSTRAINT ck_right_period CHECK (valid_to IS NULL OR valid_to > valid_from) );

-- AnnexeU_Surete_Accueil#2
CREATE INDEX ix_access_right_lookup ON keystone.access_rights (tenant_id, access_zone_id, status, valid_from, valid_to);

-- AnnexeU_Surete_Accueil#3
CREATE TABLE keystone.access_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  access_zone_id uuid NOT NULL REFERENCES keystone.access_zones(id) ON DELETE RESTRICT,
  person_id uuid REFERENCES keystone.persons(id), visit_id uuid REFERENCES keystone.visits(id),
  vehicle_id uuid,                                  -- Annexe PK
  direction keystone.access_direction NOT NULL, method keystone.access_method NOT NULL,
  denial_reason text,                               -- code métier du refus, sans détail personnel
  manual_reason text,                               -- obligatoire si method = manual (mode dégradé)
  right_id uuid REFERENCES keystone.access_rights(id), recorded_by uuid, source text NOT NULL DEFAULT 'console'
    CHECK (source IN ('console','terrain','gateway','trace')),
  at timestamptz NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(),
  recording_gap boolean GENERATED ALWAYS AS (recorded_at - at > interval '15 minutes') STORED,   -- écart signalé au détail d'un passage, seuil de la main courante
  CONSTRAINT ck_event_subject CHECK (num_nonnulls(person_id, visit_id, vehicle_id) >= 1),
  CONSTRAINT ck_event_denied CHECK (direction <> 'denied' OR denial_reason IS NOT NULL),
  CONSTRAINT ck_event_manual CHECK (method <> 'manual' OR manual_reason IS NOT NULL) );

-- AnnexeU_Surete_Accueil#3
CREATE INDEX ix_access_event ON keystone.access_events (tenant_id, site_id, at DESC);

-- AnnexeU_Surete_Accueil#4
CREATE TABLE keystone.physical_access_review_items (
  review_id uuid NOT NULL REFERENCES keystone.physical_access_reviews(id) ON DELETE CASCADE,
  right_id uuid NOT NULL REFERENCES keystone.access_rights(id) ON DELETE CASCADE,
  decision text CHECK (decision IN ('confirm','suspend','revoke')), comment text,
  decided_by uuid, decided_at timestamptz, PRIMARY KEY (review_id, right_id) );

-- AnnexeU_Surete_Accueil#11
CREATE VIEW keystone.v_persons_on_site WITH (security_invoker = true) AS      -- registre d'évacuation
SELECT DISTINCT ON (e.site_id, coalesce(e.person_id, e.visit_id)) e.site_id, e.person_id, e.visit_id,
       e.access_zone_id, e.at AS last_in_at
  FROM keystone.access_events e
 WHERE e.at::date = current_date AND e.direction IN ('in','out')
 ORDER BY e.site_id, coalesce(e.person_id, e.visit_id), e.at DESC;

-- AnnexeU_Surete_Accueil_Partie2#2
CREATE POLICY crx_select ON keystone.crisis_drills FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL AND keystone.site_in_scope(site_id)
  AND (keystone.has_permission('crisis_drill.manage') OR keystone.has_permission('security.kpi_read')
       OR (is_unannounced = false OR status <> 'planned') AND keystone.has_permission('security.log')));

-- AnnexeI_IoT#3
CREATE TABLE keystone.iot_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  name text NOT NULL,
  device_type text NOT NULL,                        -- temperature, vibration, energy, water_flow, presence, people_count
  vendor text, protocol iot_protocol NOT NULL,
  external_id text NOT NULL,                        -- identifiant côté appareil ou passerelle
  gateway_id uuid REFERENCES keystone.iot_gateways(id) ON DELETE SET NULL,
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE SET NULL,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  meter_id uuid REFERENCES keystone.asset_meters(id) ON DELETE SET NULL,      -- D10
  meter_metric text,                                -- métrique qui porte l'index du compteur
  space_unit_id uuid REFERENCES atlas_core.spaces(id) ON DELETE SET NULL,  -- référentiel des espaces (D04, Annexe S)
  level_id uuid REFERENCES atlas_core.levels(id), plan_x numeric(7,6), plan_y numeric(7,6),   -- position 0 à 1
  status iot_device_status NOT NULL DEFAULT 'active',
  heartbeat_interval_s int NOT NULL DEFAULT 300 CHECK (heartbeat_interval_s BETWEEN 10 AND 86400),
  last_seen_at timestamptz,
  device_key_hash text,                             -- clé propre à l'appareil (RG-CAP-04)
  key_created_at timestamptz, key_revoked_at timestamptz,
  last_calibrated_at date, calibration_due date,
  battery_pct numeric(5,2) CHECK (battery_pct BETWEEN 0 AND 100),
  owner iot_owner NOT NULL DEFAULT 'tenant',
  disabled_reason text,
  config jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_device_external UNIQUE (tenant_id, external_id),
  CONSTRAINT ck_device_meter CHECK ((meter_id IS NULL) = (meter_metric IS NULL)),
  CONSTRAINT ck_device_disabled CHECK (status <> 'disabled' OR disabled_reason IS NOT NULL),
  CONSTRAINT ck_device_pos CHECK ((plan_x IS NULL AND plan_y IS NULL)
                                  OR (level_id IS NOT NULL AND plan_x BETWEEN 0 AND 1 AND plan_y BETWEEN 0 AND 1))
);

-- AnnexeI_IoT#3
CREATE UNIQUE INDEX uq_device_meter ON keystone.iot_devices (tenant_id, meter_id) WHERE meter_id IS NOT NULL AND deleted_at IS NULL;

-- AnnexeI_IoT#3
CREATE INDEX ix_device_asset ON keystone.iot_devices (tenant_id, asset_id);

-- AnnexeI_IoT#3
CREATE INDEX ix_device_status ON keystone.iot_devices (tenant_id, site_id, status);

-- AnnexeI_IoT#3
CREATE INDEX ix_device_space ON keystone.iot_devices (tenant_id, space_unit_id) WHERE space_unit_id IS NOT NULL;

-- AnnexeI_IoT#3
CREATE TABLE keystone.iot_device_status_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, device_id uuid NOT NULL REFERENCES keystone.iot_devices(id) ON DELETE CASCADE,
  status iot_device_status NOT NULL,
  from_at timestamptz NOT NULL, to_at timestamptz,  -- to_at NULL : statut courant
  CONSTRAINT ck_status_log CHECK (to_at IS NULL OR to_at > from_at)
);

-- AnnexeI_IoT#3
CREATE INDEX ix_status_log ON keystone.iot_device_status_log (tenant_id, device_id, from_at DESC);

-- AnnexeI_IoT#4
-- Compatibilité CDC v3 §6.13 (lecture seule) : sensor_streams devient une vue
CREATE VIEW keystone.sensor_streams AS
  SELECT r.id::text AS id, r.tenant_id, d.asset_id, r.metric, r.value, r.at, r.source
  FROM keystone.iot_readings r JOIN keystone.iot_devices d ON d.id = r.device_id;

-- AnnexeEN_Energie#2
-- Rattachement des compteurs aux usages (plan de collecte, §6.6) ; asset_meters reste en Annexe B
CREATE TABLE keystone.energy_use_meters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  use_id uuid NOT NULL REFERENCES keystone.energy_uses(id) ON DELETE CASCADE,
  meter_id uuid NOT NULL REFERENCES keystone.asset_meters(id) ON DELETE RESTRICT,
  allocation_pct numeric(5,2) NOT NULL DEFAULT 100 CHECK (allocation_pct > 0 AND allocation_pct <= 100),
  CONSTRAINT uq_use_meter UNIQUE (tenant_id, use_id, meter_id)
);

-- AnnexeEN_Energie#2
-- Trigger tg_meter_allocation : somme de allocation_pct d'un compteur sur tous les usages <= 100,
-- sinon ENERGY_ALLOCATION_EXCEEDED.
-- Lien compteur d'arrosage et secteur (Lot 15 E12) : compteur d'eau rattaché par energy_use_meters à un usage
--   kind = 'irrigation' dont sector_id désigne le secteur arrosé. Trigger tg_ues_sector (BEFORE INSERT OR UPDATE
--   OF sector_id) : secteur d'un zonage du même site, sinon OBJECT_SITE_MISMATCH (Annexe A) ; compteur rattaché à
--   un usage irrigation de kind water_m3 (Annexe B.8.1), sinon INVALID_ARGUMENT (champ meter_id).
CREATE VIEW keystone.v_irrigation_meters WITH (security_invoker = true) AS
  SELECT u.tenant_id, u.site_id, u.sector_id, s.code AS sector_code, s.name AS sector_name,
         um.meter_id, m.code AS meter_code, m.label AS meter_label, um.allocation_pct
  FROM keystone.energy_uses u
  JOIN keystone.energy_use_meters um ON um.use_id = u.id
  JOIN keystone.asset_meters m ON m.id = um.meter_id
  LEFT JOIN keystone.sectors s ON s.id = u.sector_id
  WHERE u.kind = 'irrigation' AND u.deleted_at IS NULL AND m.is_active;

-- AnnexeEN_Energie#5
CREATE TABLE keystone.energy_daily_values (
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  meter_id uuid NOT NULL REFERENCES keystone.asset_meters(id) ON DELETE RESTRICT,
  day date NOT NULL,
  kwh_equiv numeric(18,4),                           -- conversion paramétrée par fluide ; eau : NULL
  cost bigint,                                       -- FCFA, NULL si aucun tarif (RG-ENE-03)
  currency char(3) CHECK (currency IN ('XOF','XAF')),
  tariff_id uuid REFERENCES keystone.energy_tariffs(id),
  co2e_kg numeric(18,4),                             -- NULL si aucun facteur (RG-ENE-06)
  emission_factor_id uuid REFERENCES keystone.emission_factors(id),
  computed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, meter_id, day),
  CONSTRAINT ck_edv_money CHECK (cost IS NULL OR currency IS NOT NULL)
) PARTITION BY RANGE (day);

-- AnnexeEN_Energie#8
CREATE TABLE keystone.energy_rebilling_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  run_id uuid NOT NULL REFERENCES keystone.energy_rebilling_runs(id) ON DELETE CASCADE,
  meter_id uuid REFERENCES keystone.asset_meters(id),         -- compteur privatif
  occupant_org_id uuid,                                       -- organisation occupante (Annexe S)
  client_id uuid REFERENCES keystone.clients(id),             -- fm_provider
  fluid energy_fluid NOT NULL,
  quantity numeric(18,4) NOT NULL CHECK (quantity >= 0),
  unit text NOT NULL,
  allocation_key text NOT NULL CHECK (allocation_key IN ('private_meter','surface_share','fixed_share')),
  share_pct numeric(7,4),                                     -- clé de répartition des communs
  measured_share numeric(5,4) NOT NULL,                       -- part des jours non interpolés de la période
  amount_ht bigint CHECK (amount_ht >= 0),                    -- quantité valorisée au tarif d'achat, NULL sans tarif
  currency char(3) CHECK (currency IN ('XOF','XAF')),
  CONSTRAINT ck_rebill_target CHECK (occupant_org_id IS NOT NULL OR client_id IS NOT NULL),
  CONSTRAINT ck_rebill_money CHECK (amount_ht IS NULL OR currency IS NOT NULL)
);

-- AnnexeAdmin_RBAC_Notifications_Partie4#1 (proposition, lot 12)
CREATE POLICY sso_map_read ON keystone.sso_group_mappings FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND keystone.has_permission('sso.manage'));

-- AnnexeAdmin_RBAC_Notifications_Partie4#4 (proposition, lot 12)
CREATE POLICY usage_daily_read ON keystone.usage_daily FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND keystone.has_permission('usage.read'));

-- AnnexeAP_API_Publique#1 (proposition, lot 12)
CREATE POLICY api_tokens_read ON keystone.api_tokens FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND keystone.has_permission('api.manage'));

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
CREATE POLICY wh_endpoints_read ON keystone.webhook_endpoints FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND keystone.has_permission('webhook.manage'));

-- AnnexeAP_API_Publique#3 (proposition, lot 12)
CREATE POLICY wh_deliveries_read ON keystone.webhook_deliveries FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND keystone.has_permission('webhook.manage'));

-- AnnexeP_Prestataires_Mobile#12
CREATE FUNCTION keystone.vendor_assignable(p_vendor uuid, p_site uuid, p_on date DEFAULT current_date,
                                           p_fitout_request uuid DEFAULT NULL)
RETURNS text  -- NULL si affectable, sinon le code d'erreur
LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN v.status NOT IN ('active','under_watch') OR v.deleted_at IS NOT NULL THEN 'CONTRACTOR_NOT_ASSIGNABLE'
    WHEN NOT ('service_provider' = ANY (v.roles)) THEN 'VENDOR_ROLE_MISMATCH'
    WHEN v.origin = 'occupant' AND NOT EXISTS (SELECT 1 FROM keystone.fitout_requests f
         WHERE f.id = p_fitout_request AND f.occupant_org_id = v.occupant_org_id) THEN 'CONTRACTOR_NOT_ASSIGNABLE'
    WHEN EXISTS (SELECT 1 FROM keystone.vendor_site_restrictions r WHERE r.vendor_id = v.id AND r.site_id = p_site
                 AND r.lifted_at IS NULL AND r.starts_on <= p_on AND (r.ends_on IS NULL OR r.ends_on >= p_on))
         THEN 'CONTRACTOR_SITE_RESTRICTED'
    WHEN NOT keystone.vendor_docs_ok(v.id, p_on) THEN 'CONTRACTOR_DOC_EXPIRED'
    WHEN NOT keystone.prevention_plan_valid(v.id, p_site, p_on) THEN 'PREVENTION_PLAN_REQUIRED'   -- Annexe C, prevention_plans.vendor_id
    ELSE NULL END
  FROM keystone.vendors v WHERE v.id = p_vendor $$;

-- AnnexeB_GMAO_Partie2#15
CREATE TABLE keystone.pm_task_failure_modes (
  pm_task_id uuid NOT NULL REFERENCES keystone.pm_tasks(id) ON DELETE CASCADE,
  fmea_mode_id uuid NOT NULL REFERENCES keystone.fmea_modes(id) ON DELETE RESTRICT,   -- Annexe AM
  tenant_id uuid NOT NULL,
  PRIMARY KEY (pm_task_id, fmea_mode_id) );

-- AnnexeB_GMAO_Partie2#16
CREATE TABLE keystone.maintenance_plan_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  plan_root_id uuid NOT NULL REFERENCES keystone.maintenance_plans(id) ON DELETE RESTRICT,  -- lignée ; version active résolue
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE CASCADE,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE CASCADE,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE CASCADE,   -- plan de prestation
  sector_id uuid REFERENCES keystone.sectors(id),                         -- plan de prestation (Annexe S)
  regulatory_control_id uuid,                   -- gamme réglementaire : contrôle de l'actif (Annexe C.5)
  meter_id uuid REFERENCES keystone.asset_meters(id),   -- déclencheur compteur
  first_due_date date NOT NULL,
  next_due_date date,
  last_done_on date, last_done_meter_value numeric(18,4),
  threshold_crossed_at timestamptz,            -- posé par record_meter_reading (B.8) ou seuil IoT rattaché
  last_generated_on date,
  vendor_id uuid REFERENCES keystone.vendors(id),   -- prestataire désigné pour ce périmètre
  client_contract_id uuid,                      -- fm_provider : contrat de service couvrant (Annexe M)
  -- Couverture héritée par les OT générés (A95)
  coverage_mode wo_coverage_mode,
  maintenance_contract_id uuid REFERENCES keystone.maintenance_contracts(id),
  budget_id uuid REFERENCES keystone.budgets(id), -- Annexe E
  client_billing wo_client_billing NOT NULL DEFAULT 'included',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_mpa_meter_base CHECK (meter_id IS NULL OR last_done_meter_value IS NOT NULL),   -- L17-20
  CONSTRAINT ck_mpa_target CHECK (num_nonnulls(asset_id, location_id, sector_id) = 1
                                  AND (component_id IS NULL OR asset_id IS NOT NULL)) );

-- AnnexeB_GMAO_Partie2#16
CREATE UNIQUE INDEX uq_mpa_target ON keystone.maintenance_plan_assets
  (tenant_id, plan_root_id, coalesce(component_id, asset_id, location_id, sector_id)) WHERE deleted_at IS NULL;

-- AnnexeB_GMAO_Partie2#16
CREATE INDEX ix_mpa_due ON keystone.maintenance_plan_assets (tenant_id, next_due_date) WHERE is_active;

-- AnnexeB_GMAO_Partie2#16
CREATE INDEX ix_mpa_crossed ON keystone.maintenance_plan_assets (tenant_id) WHERE threshold_crossed_at IS NOT NULL;

-- AnnexeI_IoT#2
CREATE TABLE keystone.iot_gateway_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  gateway_id uuid NOT NULL REFERENCES keystone.iot_gateways(id) ON DELETE CASCADE,
  point_ref text NOT NULL,                          -- objet BACnet, registre Modbus, sujet MQTT
  label text,
  device_id uuid REFERENCES keystone.iot_devices(id) ON DELETE SET NULL,
  metric text,
  unit text,
  scale_factor numeric(18,8) NOT NULL DEFAULT 1,
  value_offset numeric(18,8) NOT NULL DEFAULT 0,    -- valeur = brute fois scale_factor plus value_offset
  status iot_point_status NOT NULL DEFAULT 'unmapped',
  quarantine_reason text,
  CONSTRAINT uq_gw_point UNIQUE (tenant_id, gateway_id, point_ref),
  CONSTRAINT uq_point_target UNIQUE (tenant_id, device_id, metric),   -- RG-GTB-02, NULL non contraints
  CONSTRAINT ck_point_mapped CHECK (status <> 'mapped' OR (device_id IS NOT NULL AND metric IS NOT NULL AND unit IS NOT NULL)),
  CONSTRAINT ck_point_quar CHECK (status <> 'quarantined' OR quarantine_reason IS NOT NULL)
);

-- AnnexeI_IoT#6
CREATE TABLE keystone.iot_thresholds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  device_id uuid NOT NULL REFERENCES keystone.iot_devices(id) ON DELETE CASCADE,
  metric text NOT NULL,
  op text NOT NULL CHECK (op IN ('>','>=','<','<=')),
  threshold numeric(18,6) NOT NULL,
  severity risk_level NOT NULL,
  action iot_threshold_action NOT NULL,
  cooldown_min int NOT NULL DEFAULT 30 CHECK (cooldown_min BETWEEN 1 AND 10080),
  min_duration_min int NOT NULL DEFAULT 0 CHECK (min_duration_min >= 0),   -- franchissement soutenu
  schedule iot_schedule NOT NULL DEFAULT 'always',  -- selon sites.opening_hours
  escalate_after_min int CHECK (escalate_after_min > 0),   -- obligatoire si severity = 'critical'
  auto_resolve_after_min int CHECK (auto_resolve_after_min > 0),
  wo_priority int CHECK (wo_priority BETWEEN 1 AND 4),
  plan_asset_id uuid REFERENCES keystone.maintenance_plan_assets(id) ON DELETE SET NULL,  -- gamme conditionnelle (B.5.8, L17-21)
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_thr_escalate CHECK (severity <> 'critical' OR escalate_after_min IS NOT NULL),
  CONSTRAINT ck_thr_wo CHECK (action <> 'conditional_wo' OR wo_priority IS NOT NULL OR plan_asset_id IS NOT NULL)
);

-- AnnexeI_IoT#6
CREATE INDEX ix_thr_device ON keystone.iot_thresholds (tenant_id, device_id, metric) WHERE is_active;

-- AnnexeB_GMAO#2
CREATE TABLE keystone.work_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,   -- A66
  client_id uuid,                               -- fm_provider : copie de keystone.site_ext.client_id par trigger ; NULL en in_house
  ref text NOT NULL,                            -- OT-AAAA-NNNNNN, next_ref('wo', année), séquence par tenant et année
  type wo_type NOT NULL,                        -- 'service' : passage Soft FM (D11)
  priority smallint NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 4),
  status wo_status NOT NULL DEFAULT 'draft',
  stage wo_stage NOT NULL DEFAULT 'emitted',
  title text NOT NULL,
  description text,
  -- Objet de l'intervention
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE RESTRICT,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  sector_id uuid,                               -- Annexe S, secteur (Soft FM)
  target_kind wo_target_kind NOT NULL DEFAULT 'asset',  -- asset, component, location, other (B.15.2)
  target_description text, target_reference text,      -- cible « Autre » : description et numéro de série ou référence
  -- Origine et signalement (B.15)
  origin wo_origin NOT NULL DEFAULT 'ad_hoc',
  source_ticket_id uuid,                        -- Annexe D
  detected_at timestamptz, reported_by text, symptoms text,
  source_plan_id uuid REFERENCES keystone.maintenance_plans(id) ON DELETE SET NULL,
  plan_asset_id uuid REFERENCES keystone.maintenance_plan_assets(id) ON DELETE SET NULL,
  plan_version int,
  due_date date,                                -- échéance de gamme, ou échéance réglementaire
  source_prediction_id uuid,                    -- Annexe H
  source_inspection_id uuid,                    -- Annexe C, non-conformité d'inspection
  regulatory_control_id uuid,                   -- Annexe R, contrôle de l'OT regulatory (colonne « OT lié » de l'échéancier)
  template_id uuid REFERENCES keystone.wo_templates(id) ON DELETE SET NULL,   -- Annexe MO
  move_request_id uuid,                         -- Annexe S, déménagement
  rework_of_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,  -- OT de reprise (référentiel KPI, KPI-MNT-14)
  -- Affectation
  desired_at timestamptz,                       -- date et heure souhaitées, sans effet SLA
  vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE RESTRICT,       -- D13, rôle service_provider
  supervisor_id uuid REFERENCES keystone.persons(id) ON DELETE RESTRICT,   -- superviseur interne, exigé avec vendor_id (T01)
  contractor_assigned_at timestamptz,           -- horloge du critère Réactivité du prestataire
  contractor_ack_status contractor_ack_status,
  contractor_ack_due timestamptz,
  contractor_ack_at timestamptz,
  contractor_ack_reason text,
  assignee_id uuid REFERENCES keystone.persons(id) ON DELETE RESTRICT,
  work_center_id uuid REFERENCES keystone.work_centers(id) ON DELETE SET NULL,
  maintenance_level_id uuid REFERENCES keystone.maintenance_levels(id) ON DELETE SET NULL,
  -- Diagnostic ISO 14224 (étape 3), codes de keystone.iso14224_codes (Annexe AM)
  failure_mode_code text,
  failure_mechanism_code text,
  failure_cause_code text,
  detection_method_code text,
  diagnosis_cause text, diagnosis_effect text, diagnosis_finding text, diagnosis_internal_note text,
  impact_operation wo_impact_level, impact_safety wo_impact_level, impact_note text,
  diagnosis_proposed_date date,
  diagnosed_at timestamptz, diagnosed_by uuid,
  -- Planification (étape 4)
  planned_start timestamptz, planned_end timestamptz,
  est_minutes int CHECK (est_minutes >= 0),
  shutdown_required boolean NOT NULL DEFAULT false,
  shutdown_start timestamptz, shutdown_end timestamptz,
  scheduled_at timestamptz,
  -- Chiffrage et couverture (étapes 5 et 6), montants en bigint (I01)
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF','EUR','USD','GNF','CDF','MGA')),
  est_cost_parts bigint NOT NULL DEFAULT 0 CHECK (est_cost_parts >= 0),
  est_cost_labor bigint NOT NULL DEFAULT 0 CHECK (est_cost_labor >= 0),
  est_cost_subcontract bigint NOT NULL DEFAULT 0 CHECK (est_cost_subcontract >= 0),
  quoted_at timestamptz,
  requires_permit boolean NOT NULL DEFAULT false,      -- posé par wo_required_permits (B.15.3)
  safety_instructions text, required_ppe text[] NOT NULL DEFAULT '{}',
  billing_mode wo_billing_mode,                 -- type de facturation, exigé à T01 (B.15.5)
  service_contract_id uuid REFERENCES keystone.service_contracts(id) ON DELETE RESTRICT,   -- fm_provider
  purchase_request_id uuid,   -- Annexe E, D31
  internal_beneficiary_id uuid REFERENCES keystone.persons(id) ON DELETE RESTRICT,
  coverage_mode wo_coverage_mode,
  maintenance_contract_id uuid REFERENCES keystone.maintenance_contracts(id) ON DELETE RESTRICT,
  purchase_order_id uuid,                       -- Annexe E
  budget_line_id uuid,                          -- Annexe E
  client_billing wo_client_billing,             -- fm_provider seulement
  client_quote_id uuid,                         -- Annexe M, devis courant
  client_po_ref text,
  covered_at timestamptz,
  -- Engagement (étape 7)
  direction_approved_by uuid, direction_approved_at timestamptz, direction_approval_reason text,
  committed_at timestamptz,
  -- Urgence P1 (A09)
  emergency_dispatch boolean NOT NULL DEFAULT false,
  regularization_due timestamptz,               -- 2 jours ouvrés après actual_end
  regularized_at timestamptz,
  -- Exécution (étape 8)
  actual_start timestamptz, actual_end timestamptz,
  hold_reason wo_hold_reason, hold_note text,
  rework_pending boolean NOT NULL DEFAULT false,
  rework_count smallint NOT NULL DEFAULT 0,
  -- Coûts réels, bigint
  cost_labor bigint NOT NULL DEFAULT 0 CHECK (cost_labor >= 0),
  cost_parts bigint NOT NULL DEFAULT 0 CHECK (cost_parts >= 0),
  cost_subcontract bigint NOT NULL DEFAULT 0 CHECK (cost_subcontract >= 0),
  cost_total bigint GENERATED ALWAYS AS (cost_labor + cost_parts + cost_subcontract) STORED,
  -- SLA (B.3)
  sla_start_at timestamptz,
  sla_response_due timestamptz, sla_resolution_due timestamptz, client_sla_due timestamptz,
  responded_at timestamptz,                     -- prise en charge
  restored_at timestamptz,                      -- remise en service (fin de l'horloge de rétablissement)
  sla_response_met boolean, sla_resolution_met boolean, client_sla_met boolean,
  sla_paused boolean NOT NULL DEFAULT false,
  -- Réception (étape 10)
  received_by uuid, received_at timestamptz,
  reception_mode wo_reception_mode, reception_outcome wo_reception_outcome,
  second_verifier_id uuid, second_verified_at timestamptz,
  verified_by uuid, verified_at timestamptz,
  -- Clôture administrative (étape 11, A01)
  closed_by uuid, closed_at timestamptz,
  cancelled_reason text,
  qc_inspection_id uuid,                        -- Annexe C, inspections.kind = 'soft_fm_qc' (A59)
  row_version bigint NOT NULL DEFAULT 1,        -- synchronisation hors ligne (Annexe P.2)
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_wo_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_wo_dates CHECK (planned_end IS NULL OR planned_start IS NULL OR planned_end >= planned_start),
  CONSTRAINT ck_wo_shutdown CHECK (NOT shutdown_required OR (shutdown_start IS NOT NULL AND shutdown_end > shutdown_start)),
  CONSTRAINT ck_wo_component CHECK (component_id IS NULL OR asset_id IS NOT NULL),
  CONSTRAINT ck_wo_stage_status CHECK (keystone.wo_stage_status_ok(stage, status)),
  CONSTRAINT ck_wo_second_verifier CHECK (second_verifier_id IS NULL OR second_verifier_id <> received_by),
  CONSTRAINT ck_wo_billing_mode CHECK (client_billing IS NULL OR client_id IS NOT NULL)
);

-- AnnexeB_GMAO#2
-- Anti-doublon du générateur : un OT non annulé par application et par échéance
CREATE UNIQUE INDEX uq_wo_plan_due ON keystone.work_orders (tenant_id, plan_asset_id, due_date)
  WHERE plan_asset_id IS NOT NULL AND status <> 'cancelled' AND deleted_at IS NULL;

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_open ON keystone.work_orders (tenant_id, site_id, stage)
  WHERE status NOT IN ('verified','cancelled') AND deleted_at IS NULL;

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_sla ON keystone.work_orders (tenant_id, sla_resolution_due) WHERE restored_at IS NULL AND status <> 'cancelled';

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_client_sla ON keystone.work_orders (tenant_id, client_id, client_sla_due) WHERE client_id IS NOT NULL;

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_asset ON keystone.work_orders (tenant_id, asset_id, created_at DESC);

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_assignee ON keystone.work_orders (tenant_id, assignee_id) WHERE status IN ('assigned','in_progress','on_hold');

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_vendor ON keystone.work_orders (tenant_id, vendor_id, stage);

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_planned ON keystone.work_orders (tenant_id, site_id, planned_start);

-- AnnexeB_GMAO#2
CREATE INDEX ix_wo_regularization ON keystone.work_orders (tenant_id, regularization_due) WHERE emergency_dispatch AND regularized_at IS NULL;

-- AnnexeB_GMAO#3
CREATE TABLE keystone.wo_transitions_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  from_stage wo_stage, to_stage wo_stage NOT NULL,
  from_status wo_status, to_status wo_status NOT NULL,
  transition_code text NOT NULL,               -- T01 à T21, matrice B.1.5
  reason text, meta jsonb NOT NULL DEFAULT '{}',
  actor_user_id uuid, actor_kind text NOT NULL CHECK (actor_kind IN ('user','vendor_user','client_user','system')),
  at timestamptz NOT NULL DEFAULT now() );

-- AnnexeB_GMAO#3
CREATE INDEX ix_wotl_wo ON keystone.wo_transitions_log (tenant_id, work_order_id, at);

-- AnnexeB_GMAO#4
CREATE VIEW keystone.v_vendor_work_orders WITH (security_barrier) AS
  SELECT id, tenant_id, ref, type, priority, stage, status, title, description, asset_id, component_id,
         location_id, site_id, planned_start, planned_end, est_minutes, shutdown_required, shutdown_start,
         shutdown_end, contractor_ack_status, contractor_ack_due, assignee_id, failure_mode_code,
         diagnosis_cause, diagnosis_effect, diagnosis_finding, est_cost_parts, est_cost_labor,
         est_cost_subcontract, sla_response_due, sla_resolution_due, requires_permit, actual_start, actual_end,
         origin, target_kind, target_description, target_reference, detected_at, symptoms, safety_instructions,
         required_ppe, impact_operation, impact_safety, desired_at, supervisor_id
  FROM keystone.work_orders
  WHERE vendor_id = keystone.current_vendor() AND deleted_at IS NULL;

-- AnnexeB_GMAO#6
CREATE TABLE keystone.wo_scan_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  action wo_punch_action NOT NULL,
  identifier text NOT NULL,                 -- valeur QR, code-barres, NFC
  resolved_kind text NOT NULL CHECK (resolved_kind IN ('asset','component','location')),
  resolved_id uuid NOT NULL,
  scanned_by uuid NOT NULL, person_id uuid,
  scanned_at timestamptz NOT NULL,          -- occurred_at de l'appareil borné (A94), hors ligne compris
  received_at timestamptz NOT NULL DEFAULT now(),
  clock_review boolean GENERATED ALWAYS AS (received_at - scanned_at > interval '24 hours') STORED,  -- écart signalé à la revue
  offline boolean NOT NULL DEFAULT false,
  device_session_id uuid,                   -- Annexe P
  briefing_ack_at timestamptz,              -- prise de connaissance des consignes (Lot 7 T-06 bis), pointage start seulement
  ppe_confirmed text[],                     -- EPI cochés, vocabulaire de pm_tasks.ppe
  briefing_version text,                    -- empreinte des consignes, EPI et instructions lus
  CONSTRAINT ck_scan_briefing CHECK (action = 'start' OR (briefing_ack_at IS NULL AND ppe_confirmed IS NULL AND briefing_version IS NULL)) );

-- AnnexeB_GMAO#6
CREATE INDEX ix_wo_scan ON keystone.wo_scan_log (tenant_id, work_order_id, scanned_at);

-- AnnexeB_GMAO#6
CREATE TABLE keystone.wo_work_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  kind wo_session_kind NOT NULL DEFAULT 'intervention',
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  started_at timestamptz NOT NULL, ended_at timestamptz,
  duration_min int GENERATED ALWAYS AS
     (CASE WHEN ended_at IS NULL THEN NULL ELSE floor(extract(epoch FROM ended_at - started_at) / 60)::int END) STORED,
  start_scan_id uuid REFERENCES keystone.wo_scan_log(id), end_scan_id uuid REFERENCES keystone.wo_scan_log(id),
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT ck_session_order CHECK (ended_at IS NULL OR ended_at >= started_at) );

-- AnnexeB_GMAO#6
CREATE UNIQUE INDEX uq_session_open ON keystone.wo_work_sessions (work_order_id, person_id) WHERE ended_at IS NULL;

-- AnnexeB_GMAO#7
CREATE OR REPLACE FUNCTION keystone.wo_punch(p_wo uuid, p_action wo_punch_action, p_meta jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE w keystone.work_orders; r jsonb; v_person uuid; v_scan uuid; v_at timestamptz;
BEGIN
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
END; $$;

-- AnnexeB_GMAO_Partie2#1
CREATE TABLE keystone.work_order_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('labor','part','subcontract','task','note')),
  phase text NOT NULL DEFAULT 'actual' CHECK (phase IN ('estimate','actual')),   -- chiffrage ou réalisé
  position int,
  label text NOT NULL,
  qty numeric(12,3) CHECK (qty >= 0),
  unit text,
  unit_cost bigint CHECK (unit_cost >= 0),        -- coût unitaire interne, unité de la devise
  amount bigint CHECK (amount >= 0),              -- arrondi demi vers le pair de qty fois unit_cost (I02)
  currency char(3),
  person_id uuid REFERENCES keystone.persons(id),
  part_id uuid REFERENCES keystone.spare_parts(id),
  vendor_id uuid REFERENCES keystone.vendors(id),
  minutes int CHECK (minutes >= 0),
  pm_task_id uuid REFERENCES keystone.pm_tasks(id),      -- opération copiée de la gamme
  task_done boolean, task_not_done_reason text,
  stock_movement_id uuid,                          -- sortie liée (B.7)
  review_status text NOT NULL DEFAULT 'valid' CHECK (review_status IN ('valid','to_review','rejected')),
  review_code text,                                -- INSUFFICIENT_STOCK pour une consommation rejouée hors ligne
  reviewed_by uuid, reviewed_at timestamptz, review_reason text,
  row_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_wol_amount CHECK (kind NOT IN ('labor','part','subcontract') OR (amount IS NOT NULL AND currency IS NOT NULL)),
  CONSTRAINT ck_wol_task CHECK (task_done IS NOT FALSE OR task_not_done_reason IS NOT NULL) );

-- AnnexeB_GMAO_Partie2#1
CREATE INDEX ix_wol_wo ON keystone.work_order_lines (tenant_id, work_order_id, kind, phase);

-- AnnexeB_GMAO_Partie2#2
CREATE TABLE keystone.work_order_team (
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id) ON DELETE RESTRICT,
  tenant_id uuid NOT NULL,
  role keystone.wo_team_role NOT NULL,            -- Référentiels transverses §1.2 (A04)
  planned_minutes int CHECK (planned_minutes >= 0),
  row_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  PRIMARY KEY (work_order_id, person_id) );

-- AnnexeB_GMAO_Partie2#2
CREATE UNIQUE INDEX uq_wot_lead ON keystone.work_order_team (work_order_id) WHERE role = 'lead';

-- AnnexeB_GMAO_Partie2#3
CREATE TABLE keystone.wo_checkpoint_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  work_order_line_id uuid REFERENCES keystone.work_order_lines(id) ON DELETE CASCADE,
  pm_task_checkpoint_id uuid REFERENCES keystone.pm_task_checkpoints(id) ON DELETE SET NULL,
  -- copie figée du point de contrôle à la génération
  label text NOT NULL,
  measure_type text NOT NULL CHECK (measure_type IN ('numeric','boolean','choice','text')),
  expected_text text, expected_boolean boolean, expected_choices text[],
  min_value numeric(18,4), max_value numeric(18,4), unit text, method text,
  is_blocking boolean NOT NULL DEFAULT false,
  -- saisie terrain
  value_numeric numeric(18,4), value_boolean boolean, value_text text,
  is_conform boolean,                       -- calculé par trigger
  comment text,                             -- obligatoire si non conforme
  photo_path text,
  decision text CHECK (decision IN ('reserve','corrective_wo','escalation','asset_locked','accepted_by_manager')),
  decision_by uuid, decision_at timestamptz,
  measured_by uuid, measured_at timestamptz,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT ck_wcr_comment CHECK (is_conform IS NOT FALSE OR comment IS NOT NULL) );

-- AnnexeB_GMAO_Partie2#3
CREATE INDEX ix_wcr_wo ON keystone.wo_checkpoint_results (tenant_id, work_order_id);

-- AnnexeB_GMAO_Partie2#3
CREATE INDEX ix_wcr_nonconform ON keystone.wo_checkpoint_results (tenant_id) WHERE is_conform = false;

-- AnnexeB_GMAO_Partie2#4
CREATE TABLE keystone.wo_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  work_order_id uuid NOT NULL UNIQUE REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','submitted')),
  summary text CHECK (summary IS NULL OR char_length(summary) >= 20),
  outcome text CHECK (outcome IN ('repaired','temporarily_repaired','not_repaired')),
  cause_code text,                          -- ISO 14224:2016, cause de défaillance (Annexe AM)
  maintenance_activity_code text,           -- ISO 14224:2016, activité de maintenance (Annexe AM)
  recommendation text,
  follow_up_wo_id uuid REFERENCES keystone.work_orders(id),
  safety_reserve boolean NOT NULL DEFAULT false, safety_reserve_text text, hsse_event_id uuid,
  -- photos avant et après : aucune colonne, lues par keystone.v_entity_photos (Annexe G.4 ter), entity_type 'work_order', link_context 'before' ou 'after'
  signed_by uuid, signature_path text, signed_at timestamptz,
  site_rep_name text, site_rep_signature_path text,
  client_pdf_path text, internal_pdf_path text,
  submitted_at timestamptz,
  row_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_report_followup CHECK (outcome IS NULL OR outcome = 'repaired' OR recommendation IS NOT NULL) );

-- AnnexeB_GMAO_Partie2#9
CREATE TABLE keystone.asset_downtimes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE SET NULL,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  started_at timestamptz NOT NULL,              -- détection de la défaillance, ou début de l'arrêt planifié
  ended_at timestamptz,                         -- remise en service
  is_planned boolean NOT NULL,                  -- arrêt planifié (OT avec shutdown) ou non planifié (défaillance)
  impact text NOT NULL DEFAULT 'total' CHECK (impact IN ('total','partial')),
  capacity_loss_pct numeric(5,2) NOT NULL DEFAULT 100 CHECK (capacity_loss_pct > 0 AND capacity_loss_pct <= 100),
  failure_mode_code text,                       -- ISO 14224:2016 (Annexe AM, iso14224_codes type failure_mode)
  failure_cause_code text,                      -- ISO 14224:2016 (type failure_cause)
  failure_mechanism_code text,                  -- ISO 14224:2016 (type failure_mechanism)
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,
  ticket_id uuid,
  source text NOT NULL CHECK (source IN ('wo','ticket','asset_status','iot','manual')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','validated')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT ck_dt_order CHECK (ended_at IS NULL OR ended_at > started_at),
  CONSTRAINT ck_dt_partial CHECK (impact = 'partial' OR capacity_loss_pct = 100),
  CONSTRAINT ex_dt_overlap EXCLUDE USING gist
    (asset_id WITH =, tstzrange(started_at, coalesce(ended_at, 'infinity')) WITH &&) );

-- AnnexeB_GMAO_Partie2#9
CREATE INDEX ix_dt_asset ON keystone.asset_downtimes (tenant_id, asset_id, started_at);

-- AnnexeB_GMAO_Partie2#9
CREATE INDEX ix_dt_open ON keystone.asset_downtimes (tenant_id) WHERE ended_at IS NULL;

-- AnnexeB_GMAO_Partie2#16
CREATE TABLE keystone.maintenance_plan_skips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  plan_asset_id uuid NOT NULL REFERENCES keystone.maintenance_plan_assets(id) ON DELETE CASCADE,
  due_date date NOT NULL,
  reason text NOT NULL CHECK (reason IN ('covered_by_including_plan','neutralized_other_trigger','out_of_season')),
  covered_by_wo_id uuid REFERENCES keystone.work_orders(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_skip UNIQUE (plan_asset_id, due_date) );

-- AnnexeB_GMAO_Partie3#1
CREATE TABLE keystone.wo_reschedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  old_start timestamptz, new_start timestamptz NOT NULL,
  old_end timestamptz, new_end timestamptz,
  reason text NOT NULL CHECK (reason IN ('asset_unavailable','part_missing','resource_unavailable','weather',
                                         'occupant_or_client_request','corrective_priority','other')),
  comment text,
  out_of_tolerance boolean NOT NULL DEFAULT false,
  regulatory_derogation boolean NOT NULL DEFAULT false, derogation_justification text,
  after_publication boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_resched_comment CHECK (reason <> 'other' OR comment IS NOT NULL),
  CONSTRAINT ck_resched_derog CHECK (NOT regulatory_derogation OR derogation_justification IS NOT NULL) );

-- AnnexeB_GMAO_Partie3#1
CREATE INDEX ix_resched_wo ON keystone.wo_reschedules (tenant_id, work_order_id, created_at);

-- AnnexeB_GMAO_Partie3#3
CREATE TABLE keystone.planning_baseline_items (
  baseline_id uuid NOT NULL REFERENCES keystone.planning_baselines(id) ON DELETE CASCADE,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  tenant_id uuid NOT NULL,
  planned_start timestamptz, planned_end timestamptz,
  assignee_id uuid, vendor_id uuid, team_person_ids uuid[] NOT NULL DEFAULT '{}',
  changed_after_publication boolean NOT NULL DEFAULT false,
  PRIMARY KEY (baseline_id, work_order_id) );

-- AnnexeB_GMAO_Partie3#6
CREATE TABLE keystone.stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  part_id uuid NOT NULL REFERENCES keystone.spare_parts(id) ON DELETE RESTRICT,
  direction stock_direction NOT NULL,
  qty numeric(14,3) NOT NULL CHECK (qty <> 0),            -- signé : positif en entrée, négatif en sortie
  unit_cost bigint NOT NULL CHECK (unit_cost >= 0),       -- coût d'entrée, ou coût moyen à la sortie
  value bigint NOT NULL,                                  -- arrondi demi vers le pair de qty fois unit_cost, signé
  qty_after numeric(14,3) NOT NULL, avg_cost_after bigint NOT NULL,
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE RESTRICT,
  reservation_id uuid, goods_receipt_line_id uuid, transfer_line_id uuid, cycle_count_line_id uuid,
  reason text,
  at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT ck_mv_out_wo CHECK (direction <> 'out' OR work_order_id IS NOT NULL),     -- RG-STK-02
  CONSTRAINT ck_mv_adjust_reason CHECK (direction <> 'adjust' OR reason IS NOT NULL) );

-- AnnexeB_GMAO_Partie3#6
-- RG-STK-03
CREATE INDEX ix_mv_part ON keystone.stock_movements (tenant_id, part_id, at);

-- AnnexeB_GMAO_Partie3#6
CREATE INDEX ix_mv_wo ON keystone.stock_movements (tenant_id, work_order_id);

-- AnnexeB_GMAO_Partie3#7
CREATE TABLE keystone.stock_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  part_id uuid NOT NULL REFERENCES keystone.spare_parts(id) ON DELETE RESTRICT,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  qty numeric(14,3) NOT NULL CHECK (qty > 0),
  consumed_qty numeric(14,3) NOT NULL DEFAULT 0 CHECK (consumed_qty >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','consumed','released')),
  needed_by timestamptz,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  CONSTRAINT ck_res_consumed CHECK (consumed_qty <= qty) );

-- AnnexeB_GMAO_Partie3#7
CREATE INDEX ix_res_part ON keystone.stock_reservations (tenant_id, part_id) WHERE status = 'active';

-- AnnexeB_GMAO_Partie3#8
CREATE OR REPLACE FUNCTION keystone.consume_part(p_part uuid, p_qty numeric, p_wo uuid, p_meta jsonb DEFAULT '{}')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE p keystone.spare_parts; w keystone.work_orders; r keystone.stock_reservations; v_mv uuid; v_val bigint;
BEGIN
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
END; $$;

-- AnnexeB_GMAO_Partie3#11
CREATE TABLE keystone.part_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  part_id uuid REFERENCES keystone.spare_parts(id),
  free_label text,
  qty numeric(14,3) NOT NULL CHECK (qty > 0),
  urgency text NOT NULL CHECK (urgency IN ('now','next_visit')),
  note text, photo_document_id uuid,
  status part_request_status NOT NULL DEFAULT 'sent',
  answered_by uuid, answered_at timestamptz, answer_note text,
  reservation_id uuid REFERENCES keystone.stock_reservations(id),
  purchase_request_id uuid,                     -- Annexe E, demande d'achat draft rattachée à l'OT
  row_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_pr_target CHECK (part_id IS NOT NULL OR free_label IS NOT NULL) );

-- AnnexeB_GMAO_Partie3#11
CREATE UNIQUE INDEX uq_pr_open ON keystone.part_requests (work_order_id, part_id) WHERE status = 'sent';

-- AnnexeB_GMAO_Partie4#2
ALTER TABLE keystone.work_orders
  ADD CONSTRAINT ck_wo_target CHECK (
       (target_kind = 'asset'     AND asset_id IS NOT NULL AND component_id IS NULL)
    OR (target_kind = 'component' AND asset_id IS NOT NULL AND component_id IS NOT NULL)
    OR (target_kind = 'location'  AND asset_id IS NULL AND location_id IS NOT NULL)
    OR (target_kind = 'other'     AND asset_id IS NULL AND location_id IS NOT NULL
                                  AND char_length(btrim(target_description)) >= 3)),
  ADD CONSTRAINT ck_wo_billing_links CHECK (
        (billing_mode = 'internal' OR internal_beneficiary_id IS NULL)
    AND (billing_mode = 'purchase_request' OR purchase_request_id IS NULL)
    AND (billing_mode = 'contract' OR (maintenance_contract_id IS NULL AND service_contract_id IS NULL))),
  ADD CONSTRAINT ck_wo_coverage_billing CHECK (coverage_mode IS NULL OR billing_mode IS NULL OR
        (billing_mode = 'contract'         AND coverage_mode IN ('maintenance_contract','internal_budget'))
     OR (billing_mode = 'purchase_request' AND coverage_mode IN ('purchase_request','purchase_order'))
     OR (billing_mode = 'internal'         AND coverage_mode = 'internal_budget')),
  ADD CONSTRAINT ck_wo_detected CHECK (detected_at IS NULL OR detected_at <= created_at),
  ADD CONSTRAINT ck_wo_texts CHECK (char_length(coalesce(symptoms,'')) <= 2000
                                AND char_length(coalesce(safety_instructions,'')) <= 2000
                                AND char_length(coalesce(target_description,'')) <= 500);

-- AnnexeB_GMAO_Partie4#2
CREATE INDEX ix_wo_purchase_request ON keystone.work_orders (tenant_id, purchase_request_id) WHERE purchase_request_id IS NOT NULL;

-- AnnexeB_GMAO_Partie4#2
CREATE INDEX ix_wo_origin ON keystone.work_orders (tenant_id, site_id, origin, created_at DESC);

-- AnnexeB_GMAO_Partie4#2
CREATE INDEX ix_wo_supervisor ON keystone.work_orders (tenant_id, supervisor_id) WHERE supervisor_id IS NOT NULL;

-- AnnexeB_GMAO_Partie4#3
CREATE TABLE keystone.wo_instructions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  kind wo_instruction_kind NOT NULL,
  position int NOT NULL CHECK (position >= 1),
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 2 AND 500),
  row_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid,
  CONSTRAINT uq_wo_instruction_pos UNIQUE (work_order_id, kind, position) DEFERRABLE INITIALLY DEFERRED );

-- AnnexeB_GMAO_Partie4#3
CREATE TABLE keystone.wo_required_tools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  position int NOT NULL CHECK (position >= 1),
  label text NOT NULL CHECK (char_length(btrim(label)) BETWEEN 2 AND 120),
  row_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid );

-- AnnexeB_GMAO_Partie4#3
CREATE UNIQUE INDEX uq_wo_tool_label ON keystone.wo_required_tools (work_order_id, lower(btrim(label)));

-- AnnexeB_GMAO_Partie4#3
-- garde d'écriture : DUPLICATE_ENTRY

CREATE TABLE keystone.wo_required_competencies (
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  competency_id uuid NOT NULL REFERENCES keystone.competencies(id) ON DELETE RESTRICT,   -- Annexe K
  tenant_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  PRIMARY KEY (work_order_id, competency_id) );

-- AnnexeC_HSSE_Partie2#2
-- Analyse de risque de tâche (CDC v3 §6.4)
CREATE TABLE keystone.risk_assessments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  title text NOT NULL, task_description text NOT NULL,
  location_id uuid REFERENCES keystone.locations(id), asset_id uuid REFERENCES keystone.assets(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  assessed_by uuid NOT NULL REFERENCES keystone.persons(id),
  status keystone.risk_assessment_status NOT NULL DEFAULT 'draft',
  generated_by_ai boolean NOT NULL DEFAULT false,
  approved_by uuid, approved_at timestamptz, rejection_reason text
);

-- AnnexeC_HSSE_Partie2#2
CREATE TABLE keystone.risk_assessment_lines (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  assessment_id uuid NOT NULL REFERENCES keystone.risk_assessments(id) ON DELETE CASCADE,
  position int NOT NULL, step text NOT NULL,
  hazard_id uuid REFERENCES keystone.hazards(id), hazard_text text,
  likelihood int CHECK (likelihood BETWEEN 1 AND 5),     -- NULL tant qu'un humain n'a pas coté (A44)
  severity   int CHECK (severity BETWEEN 1 AND 5),
  controls text, control_level keystone.control_hierarchy,
  residual_likelihood int CHECK (residual_likelihood BETWEEN 1 AND 5),
  residual_severity   int CHECK (residual_severity BETWEEN 1 AND 5),
  rated_by uuid,
  CONSTRAINT ck_ral_rated CHECK ((likelihood IS NULL AND severity IS NULL) OR rated_by IS NOT NULL)
);

-- AnnexeC_HSSE_Partie2#7
CREATE TABLE keystone.work_permits (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  ref text NOT NULL,                                   -- PTW-2026-000071
  type keystone.permit_type NOT NULL,
  additional_types keystone.permit_type[] NOT NULL DEFAULT '{}',
  status keystone.permit_status NOT NULL DEFAULT 'draft',
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,
  fitout_request_id uuid REFERENCES keystone.fitout_requests(id) ON DELETE SET NULL,   -- Annexe TA
  risk_assessment_id uuid REFERENCES keystone.risk_assessments(id),
  location_id uuid NOT NULL REFERENCES keystone.locations(id),
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE SET NULL,
  vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE SET NULL,
  work_description text NOT NULL,
  requester_id uuid NOT NULL REFERENCES keystone.persons(id),
  receiver_id uuid REFERENCES keystone.persons(id),    -- chef de l'équipe qui exécute
  issuing_party keystone.issuing_party NOT NULL,       -- D19
  lone_work boolean NOT NULL DEFAULT false,            -- travail isolé demandé
  client_visa_required boolean NOT NULL DEFAULT false,
  client_visa_by uuid, client_visa_at timestamptz,
  client_visa_decision keystone.client_visa_decision, client_visa_comment text,
  valid_from timestamptz NOT NULL, valid_to timestamptz NOT NULL,
  precautions jsonb NOT NULL DEFAULT '{}',             -- une clé par rubrique plus "socle", schéma C.7.4
  requires_isolation boolean NOT NULL DEFAULT false,
  qr_token text NOT NULL UNIQUE DEFAULT encode(extensions.gen_random_bytes(24), 'base64'),
  reissued_from uuid REFERENCES keystone.work_permits(id),
  submitted_at timestamptz, approved_by uuid, approved_at timestamptz,
  activated_at timestamptz,
  suspended_at timestamptz, suspension_reason keystone.suspension_reason, suspension_note text,
  extension_count int NOT NULL DEFAULT 0,
  closed_by uuid, closed_at timestamptz, cancel_reason text,
  CONSTRAINT uq_ptw_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_ptw_validity CHECK (valid_to > valid_from),
  CONSTRAINT ck_ptw_rubrics CHECK (NOT (type = ANY (additional_types))),
  CONSTRAINT ck_ptw_visa CHECK (NOT client_visa_required OR issuing_party = 'fm_provider')
);

-- AnnexeC_HSSE_Partie2#7
CREATE INDEX ix_ptw_active ON keystone.work_permits (tenant_id, site_id) WHERE status IN ('active','suspended');

-- AnnexeC_HSSE_Partie2#7
CREATE INDEX ix_ptw_wo     ON keystone.work_permits (tenant_id, work_order_id);

-- AnnexeC_HSSE_Partie2#7
CREATE INDEX ix_ptw_valid  ON keystone.work_permits (valid_to) WHERE status = 'active';

-- AnnexeC_HSSE_Partie2#7
CREATE FUNCTION keystone.permit_rubrics(p keystone.work_permits) RETURNS keystone.permit_type[]
LANGUAGE sql IMMUTABLE AS $$ SELECT ARRAY[p.type] || p.additional_types $$;

-- AnnexeC_HSSE_Partie2#9
CREATE TABLE keystone.permit_approvals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE CASCADE,
  level keystone.permit_level NOT NULL, level_order int NOT NULL,
  required_role text, required_competency_id uuid REFERENCES keystone.competencies(id),
  approver_id uuid REFERENCES keystone.persons(id),
  decision keystone.approval_decision, decided_at timestamptz, comment text,
  UNIQUE (permit_id, level)
);

-- AnnexeC_HSSE_Partie2#9
CREATE TABLE keystone.permit_signatures (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE CASCADE,
  moment keystone.permit_signature_moment NOT NULL,
  rubric keystone.permit_type,                         -- signature propre à une rubrique
  signer_person_id uuid NOT NULL REFERENCES keystone.persons(id),
  signer_role text NOT NULL,
  signed_at timestamptz NOT NULL DEFAULT now(),
  method keystone.signature_method NOT NULL DEFAULT 'drawn',
  typed_name text,                                     -- nom saisi par le signataire si method = 'typed'
  signature_sha256 text NOT NULL,                      -- empreinte du contenu signé
  advist_token text, rfc3161_ts text,                  -- signature électronique Advist, horodatage (CDC v3 §6.10)
  offline_captured_at timestamptz,                     -- signature capturée hors ligne, revalidée au serveur
  CONSTRAINT ck_psig_typed CHECK (method <> 'typed' OR typed_name IS NOT NULL)
);

-- AnnexeC_HSSE_Partie2#9
CREATE INDEX ix_psig ON keystone.permit_signatures (tenant_id, permit_id, moment);

-- AnnexeC_HSSE_Partie2#9
CREATE TABLE keystone.permit_workers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  function text,
  competency_status keystone.competency_check NOT NULL DEFAULT 'missing',  -- recalculé à chaque contrôle
  checked_at timestamptz,
  briefed_at timestamptz, briefing_signature_id uuid REFERENCES keystone.permit_signatures(id),
  UNIQUE (permit_id, person_id)
);

-- AnnexeC_HSSE_Partie2#9
CREATE TABLE keystone.permit_watchers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE CASCADE,
  kind keystone.watcher_kind NOT NULL,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  planned_minutes int CHECK (planned_minutes > 0),
  works_ended_at timestamptz,                          -- fin des travaux (surveillance après travaux)
  started_at timestamptz, ended_at timestamptz,
  observation text, signature_id uuid REFERENCES keystone.permit_signatures(id),
  CONSTRAINT ck_pw_end CHECK (ended_at IS NULL OR started_at IS NOT NULL)
);

-- AnnexeC_HSSE_Partie2#9
CREATE TABLE keystone.permit_extensions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE CASCADE,
  previous_valid_to timestamptz NOT NULL, new_valid_to timestamptz NOT NULL,
  reason text NOT NULL, approved_by uuid NOT NULL, approved_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_pe CHECK (new_valid_to > previous_valid_to)
);

-- AnnexeC_HSSE_Partie2#9
CREATE TABLE keystone.permit_gas_tests (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE CASCADE,
  measured_at timestamptz NOT NULL, measure_point text NOT NULL, device_ref text NOT NULL,
  operator_id uuid NOT NULL REFERENCES keystone.persons(id),
  o2_pct numeric(4,1) NOT NULL, lel_pct numeric(4,1) NOT NULL,
  h2s_ppm numeric(6,1) NOT NULL, co_ppm numeric(6,1) NOT NULL,
  is_within_limits boolean NOT NULL                     -- calculé par trigger contre les seuils du tenant
);

-- AnnexeC_HSSE_Partie2#9
CREATE INDEX ix_pgt ON keystone.permit_gas_tests (permit_id, measured_at DESC);

-- AnnexeC_HSSE_Partie2#9
CREATE TABLE keystone.confined_space_entries (         -- A15
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  entered_at timestamptz NOT NULL, exited_at timestamptz,
  gas_test_id uuid NOT NULL REFERENCES keystone.permit_gas_tests(id),
  attendant_id uuid NOT NULL REFERENCES keystone.persons(id),
  CONSTRAINT ck_cse CHECK (exited_at IS NULL OR exited_at >= entered_at),
  CONSTRAINT ck_cse_att CHECK (attendant_id <> person_id)
);

-- AnnexeC_HSSE_Partie2#9
CREATE INDEX ix_cse_open ON keystone.confined_space_entries (permit_id) WHERE exited_at IS NULL;

-- AnnexeC_HSSE_Partie2#10
CREATE FUNCTION keystone.gas_tests_valid(p_permit uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT COALESCE((
    SELECT t.is_within_limits AND t.measured_at >= now() - make_interval(mins =>
             COALESCE((wp.precautions #>> '{confined_space,remeasure_minutes}')::int, 30))
    FROM keystone.permit_gas_tests t JOIN keystone.work_permits wp ON wp.id = t.permit_id
    WHERE t.permit_id = p_permit ORDER BY t.measured_at DESC LIMIT 1), false) $$;

-- AnnexeC_HSSE_Partie2#11
CREATE TABLE keystone.permit_isolations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE RESTRICT,
  asset_id uuid REFERENCES keystone.assets(id),
  energy_type keystone.energy_type NOT NULL,
  isolation_point text NOT NULL,
  lock_id text NOT NULL,
  lockbox_id uuid REFERENCES keystone.lockboxes(id),
  applied_by uuid, applied_at timestamptz,
  zero_energy_verified boolean NOT NULL DEFAULT false,
  verification_method keystone.zero_energy_method,
  verified_by uuid, verified_at timestamptz,
  removed_by uuid, removed_at timestamptz,
  transferred_to_permit_id uuid REFERENCES keystone.work_permits(id),   -- RG-LOTO-02
  CONSTRAINT ck_iso_verif CHECK (NOT zero_energy_verified OR (verified_by IS NOT NULL AND verification_method IS NOT NULL)),
  CONSTRAINT ck_iso_sod CHECK (verified_by IS NULL OR verified_by <> applied_by)
);

-- AnnexeC_HSSE_Partie2#11
CREATE TABLE keystone.permit_personal_locks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id) ON DELETE RESTRICT,
  lockbox_id uuid NOT NULL REFERENCES keystone.lockboxes(id),
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  lock_ref text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now(), removed_at timestamptz,
  applied_signature_id uuid REFERENCES keystone.permit_signatures(id),
  removed_signature_id uuid REFERENCES keystone.permit_signatures(id)
);

-- AnnexeC_HSSE_Partie2#11
CREATE UNIQUE INDEX uq_ppl_open ON keystone.permit_personal_locks (permit_id, person_id) WHERE removed_at IS NULL;

-- AnnexeC_HSSE_Partie2#12
CREATE OR REPLACE FUNCTION keystone.permit_activate(p_permit uuid, p_meta jsonb DEFAULT '{}')
RETURNS keystone.work_permits LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE p keystone.work_permits; r keystone.permit_type; v_from keystone.permit_status;
        v_wind numeric := (p_meta->>'wind_kmh')::numeric;
BEGIN
  PERFORM keystone.assert_permission('permit.activate');
  SELECT * INTO p FROM keystone.work_permits WHERE id = p_permit AND tenant_id = keystone.current_tenant() FOR UPDATE;
  IF NOT FOUND OR NOT keystone.site_in_scope(p.site_id) THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  IF p.status NOT IN ('approved','suspended') THEN PERFORM keystone.raise_error('NOT_APPROVED'); END IF;
  IF now() < p.valid_from OR now() > p.valid_to THEN PERFORM keystone.raise_error('OUT_OF_VALIDITY'); END IF;
  v_from := p.status;

  IF NOT keystone.permit_reception_signed(p.id) THEN PERFORM keystone.raise_error('RECEPTION_NOT_SIGNED'); END IF;
  IF p.client_visa_required AND p.client_visa_decision IS DISTINCT FROM 'granted' THEN PERFORM keystone.raise_error('CLIENT_VISA_REQUIRED'); END IF;
  IF p.vendor_id IS NOT NULL AND NOT keystone.prevention_plan_valid(p.vendor_id, p.site_id, current_date)
    THEN PERFORM keystone.raise_error('PREVENTION_PLAN_REQUIRED'); END IF;
  IF EXISTS (SELECT 1 FROM keystone.permit_worker_gaps(p.id)) THEN PERFORM keystone.raise_error('WORKER_NOT_QUALIFIED'); END IF;
  IF p.lone_work AND NOT EXISTS (SELECT 1 FROM keystone.lone_worker_sessions s JOIN keystone.permit_workers w
       ON w.person_id = s.person_id WHERE w.permit_id = p.id AND s.ended_at IS NULL)
    THEN PERFORM keystone.raise_error('LONE_WORKER_SESSION_REQUIRED'); END IF;
  IF p.requires_isolation AND (
       NOT EXISTS (SELECT 1 FROM keystone.permit_isolations WHERE permit_id = p.id)
    OR EXISTS (SELECT 1 FROM keystone.permit_isolations WHERE permit_id = p.id
               AND (applied_at IS NULL OR NOT zero_energy_verified OR removed_at IS NOT NULL)))
    THEN PERFORM keystone.raise_error('ISOLATION_NOT_VERIFIED'); END IF;

  FOREACH r IN ARRAY keystone.permit_rubrics(p) LOOP
    IF NOT keystone.permit_form_valid(p.id, r, 'activation') THEN PERFORM keystone.raise_error('PERMIT_INCOMPLETE'); END IF;
    CASE r
    WHEN 'confined_space' THEN
      IF NOT keystone.gas_tests_valid(p.id) THEN PERFORM keystone.raise_error('GAS_TEST_REQUIRED'); END IF;
      IF NOT keystone.watcher_present(p.id, 'confined_space_attendant') THEN PERFORM keystone.raise_error('WATCHER_REQUIRED'); END IF;
    WHEN 'hot_work' THEN
      IF NOT keystone.watcher_present(p.id, 'fire_watch_during') THEN PERFORM keystone.raise_error('WATCHER_REQUIRED'); END IF;
      IF (p.precautions #>> '{hot_work,ssi_inhibition}')::boolean AND NOT EXISTS (
           SELECT 1 FROM keystone.ssi_inhibitions WHERE permit_id = p.id AND status = 'active')
        THEN PERFORM keystone.raise_error('SSI_INHIBITION_NOT_CONFIRMED'); END IF;
    WHEN 'electrical' THEN
      IF COALESCE((p.precautions #>> '{electrical,energized}')::boolean, false) THEN      -- régime sous tension
        IF (SELECT count(*) FROM keystone.permit_workers WHERE permit_id = p.id) < 2
          THEN PERFORM keystone.raise_error('ENERGIZED_TWO_PERSONS'); END IF;
      ELSIF (p.precautions #>> '{electrical,vat_done_at}') IS NULL
        THEN PERFORM keystone.raise_error('ISOLATION_NOT_VERIFIED'); END IF;
    WHEN 'work_at_height' THEN
      IF (p.precautions #>> '{work_at_height,harness_checked_on}')::date < current_date - interval '12 months'
        THEN PERFORM keystone.raise_error('EQUIPMENT_CHECK_EXPIRED'); END IF;
      IF v_wind IS NULL OR v_wind > (p.precautions #>> '{work_at_height,max_wind_kmh}')::numeric
        THEN PERFORM keystone.raise_error('WIND_LIMIT_EXCEEDED'); END IF;
    WHEN 'lifting' THEN
      IF NOT keystone.crp_asset_ok((p.precautions #>> '{lifting,machine_asset_id}')::uuid)   -- Annexe R
        THEN PERFORM keystone.raise_error('EQUIPMENT_CHECK_EXPIRED'); END IF;
      IF v_wind IS NULL OR v_wind > (p.precautions #>> '{lifting,max_wind_kmh}')::numeric
        THEN PERFORM keystone.raise_error('WIND_LIMIT_EXCEEDED'); END IF;
    ELSE NULL;
    END CASE;
  END LOOP;

  UPDATE keystone.work_permits SET status = 'active', activated_at = now(), suspended_at = NULL,
    suspension_reason = NULL, updated_by = auth.uid()
  WHERE id = p.id RETURNING * INTO p;
  PERFORM keystone.sign_permit(p.id, CASE WHEN v_from = 'suspended' THEN 'resumption' ELSE 'reception' END);
  RETURN p;
END; $$;

-- AnnexeE_Budgets_Achats#7
CREATE TABLE keystone.purchase_requests (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- DA-2026-000057
  title text NOT NULL CHECK (char_length(title) BETWEEN 5 AND 120),   -- EV-L8-06
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  requester_id uuid NOT NULL REFERENCES keystone.persons(id),
  budget_id uuid REFERENCES keystone.budgets(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  kind keystone.budget_kind NOT NULL,
  purchase_mode keystone.purchase_mode NOT NULL,
  single_source_reason text,
  framework_contract_id uuid REFERENCES keystone.maintenance_contracts(id),
  rfq_id uuid,                                           -- consultation jointe (E.5)
  quote_document_ids uuid[] NOT NULL DEFAULT '{}',       -- devis joints hors consultation
  derogation_reason text,                                -- dérogation aux trois devis
  justification text NOT NULL,
  needed_by date,
  est_amount bigint NOT NULL DEFAULT 0 CHECK (est_amount >= 0),  -- somme des lignes, calculée
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.pr_status NOT NULL DEFAULT 'draft',
  submitted_at timestamptz, decided_at timestamptz, rejection_reason text,
  is_after_the_fact boolean NOT NULL DEFAULT false,      -- urgent : approbation a posteriori
  CONSTRAINT uq_pr_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_pr_single CHECK (purchase_mode <> 'single_source' OR single_source_reason IS NOT NULL),
  CONSTRAINT ck_pr_framework CHECK (purchase_mode <> 'framework_contract' OR framework_contract_id IS NOT NULL)
);

-- AnnexeE_Budgets_Achats#7
CREATE INDEX ix_pr_status ON keystone.purchase_requests (tenant_id, status, site_id);

-- AnnexeE_Budgets_Achats#7
CREATE TABLE keystone.purchase_request_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  request_id uuid NOT NULL REFERENCES keystone.purchase_requests(id) ON DELETE CASCADE,
  line_no smallint NOT NULL,
  part_id uuid REFERENCES keystone.spare_parts(id),
  catalog_item_id uuid REFERENCES keystone.supplier_catalog_items(id),
  label text NOT NULL, qty numeric(14,3) NOT NULL CHECK (qty > 0), unit text NOT NULL,
  est_unit_price bigint NOT NULL CHECK (est_unit_price >= 0),
  line_total bigint NOT NULL,                            -- arrondi_demi_pair(qty * est_unit_price)
  asset_id uuid REFERENCES keystone.assets(id),          -- capex : actif visé
  CONSTRAINT uq_pr_line UNIQUE (request_id, line_no)
);

-- AnnexeE_Budgets_Achats#8
CREATE TABLE keystone.rfqs (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- CONS-2026-000012
  title text NOT NULL,
  origin text NOT NULL CHECK (origin IN ('work_order','purchase_request','annual_contract')),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  purchase_request_id uuid REFERENCES keystone.purchase_requests(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  work_center_id uuid,
  target_role keystone.vendor_role NOT NULL,
  scope text NOT NULL, scope_document_ids uuid[] NOT NULL DEFAULT '{}',
  deadline timestamptz NOT NULL,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.rfq_status NOT NULL DEFAULT 'draft',
  awarded_response_id uuid, award_reason text,
  awarded_by uuid, awarded_at timestamptz, second_approver uuid, second_approved_at timestamptz,
  CONSTRAINT uq_rfq_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_rfq_award_sod CHECK (second_approver IS NULL OR (second_approver <> awarded_by AND second_approver <> created_by))
);

-- AnnexeE_Budgets_Achats#8
CREATE TABLE keystone.rfq_criteria (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  rfq_id uuid NOT NULL REFERENCES keystone.rfqs(id) ON DELETE CASCADE,
  criterion text NOT NULL CHECK (criterion IN ('price','lead_time','technical','vendor_score','other')),
  label text NOT NULL, weight smallint NOT NULL CHECK (weight BETWEEN 0 AND 100)
);

-- AnnexeE_Budgets_Achats#8
CREATE TABLE keystone.rfq_invitations (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  rfq_id uuid NOT NULL REFERENCES keystone.rfqs(id) ON DELETE CASCADE,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  status keystone.rfq_invite_status NOT NULL DEFAULT 'invited',
  viewed_at timestamptz, decline_reason text,
  CONSTRAINT uq_rfq_invite UNIQUE (rfq_id, vendor_id)
);

-- AnnexeE_Budgets_Achats#8
CREATE TABLE keystone.rfq_responses (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  invitation_id uuid NOT NULL REFERENCES keystone.rfq_invitations(id) ON DELETE CASCADE,
  version smallint NOT NULL DEFAULT 1,
  amount_ht bigint NOT NULL CHECK (amount_ht >= 0),      -- égal à la somme des lignes
  delivery_fees bigint NOT NULL DEFAULT 0 CHECK (delivery_fees >= 0),
  lead_time_days integer NOT NULL CHECK (lead_time_days >= 0),
  valid_until date NOT NULL,
  technical_memo text, document_ids uuid[] NOT NULL DEFAULT '{}',
  reservations text,
  technical_score numeric(5,2) CHECK (technical_score BETWEEN 0 AND 100),  -- saisi par l'exploitant après la date limite
  weighted_score numeric(5,2),                           -- calculé
  status keystone.rfq_response_status NOT NULL DEFAULT 'draft',
  sent_at timestamptz,
  CONSTRAINT uq_rfq_resp_version UNIQUE (invitation_id, version)
);

-- AnnexeE_Budgets_Achats#8
CREATE TABLE keystone.rfq_response_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  response_id uuid NOT NULL REFERENCES keystone.rfq_responses(id) ON DELETE CASCADE,
  request_line_id uuid REFERENCES keystone.purchase_request_lines(id),
  label text NOT NULL, offered_ref text, brand text, is_equivalent boolean NOT NULL DEFAULT false,
  qty numeric(14,3) NOT NULL CHECK (qty > 0), unit text NOT NULL,
  unit_price_ht bigint NOT NULL CHECK (unit_price_ht >= 0),
  line_total_ht bigint NOT NULL,
  lead_time_days integer,
  sds_document_id uuid REFERENCES keystone.ged_documents(id)                                   -- fiche de données de sécurité, produit chimique
);

-- AnnexeE_Budgets_Achats#9
CREATE TABLE keystone.purchase_orders (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- BC-2026-000318
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  request_id uuid REFERENCES keystone.purchase_requests(id),
  rfq_id uuid REFERENCES keystone.rfqs(id),
  framework_contract_id uuid REFERENCES keystone.maintenance_contracts(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  warehouse_id uuid REFERENCES keystone.warehouses(id),
  delivery_instructions text, desired_date date,
  buyer_id uuid NOT NULL,
  document_id uuid REFERENCES keystone.ged_documents(id),                                      -- PDF de commande versé en GED à l'émission, QR de réception (EV-L8-28, 29)
  amount_ht bigint NOT NULL DEFAULT 0, vat_amount bigint NOT NULL DEFAULT 0, amount_ttc bigint NOT NULL DEFAULT 0,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.po_status NOT NULL DEFAULT 'draft',
  sent_at timestamptz,
  supplier_ack_status keystone.po_ack_status NOT NULL DEFAULT 'pending',
  supplier_ack_due timestamptz, supplier_ack_at timestamptz, supplier_refusal_reason text,
  cancelled_reason text,
  CONSTRAINT uq_po_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_po_ttc CHECK (amount_ttc = amount_ht + vat_amount)
);

-- AnnexeE_Budgets_Achats#9
CREATE INDEX ix_po_status ON keystone.purchase_orders (tenant_id, status, vendor_id);

-- AnnexeE_Budgets_Achats#9
CREATE TABLE keystone.po_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  po_id uuid NOT NULL REFERENCES keystone.purchase_orders(id) ON DELETE CASCADE,
  line_no smallint NOT NULL,
  request_line_id uuid REFERENCES keystone.purchase_request_lines(id),
  part_id uuid REFERENCES keystone.spare_parts(id),
  catalog_item_id uuid REFERENCES keystone.supplier_catalog_items(id),
  label text NOT NULL, qty numeric(14,3) NOT NULL CHECK (qty > 0), unit text NOT NULL,
  unit_price_ht bigint NOT NULL CHECK (unit_price_ht >= 0),
  vat_rate numeric(7,4) NOT NULL DEFAULT 18 CHECK (vat_rate BETWEEN 0 AND 100),
  line_total_ht bigint NOT NULL,                         -- arrondi_demi_pair(qty * unit_price_ht)
  budget_id uuid NOT NULL REFERENCES keystone.budgets(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),  -- imputation à un OT
  asset_id uuid REFERENCES keystone.assets(id),          -- capex
  confirmed_qty numeric(14,3), confirmed_date date,
  received_qty numeric(14,3) NOT NULL DEFAULT 0,         -- maintenu par les réceptions
  refused_qty numeric(14,3) NOT NULL DEFAULT 0,
  invoiced_qty numeric(14,3) NOT NULL DEFAULT 0,         -- maintenu par les dépenses
  CONSTRAINT uq_po_line UNIQUE (po_id, line_no)
);

-- AnnexeE_Budgets_Achats#9
CREATE TABLE keystone.po_change_proposals (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  po_id uuid NOT NULL REFERENCES keystone.purchase_orders(id) ON DELETE CASCADE,
  proposed_by uuid NOT NULL, proposed_side text NOT NULL CHECK (proposed_side IN ('vendor','operator')),
  lines jsonb NOT NULL,                                  -- [{ "po_line_id", "qty", "date", "unit_price_ht" }]
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','accepted','refused','withdrawn')),
  decided_by uuid, decided_at timestamptz, decision_reason text
);

-- AnnexeE_Budgets_Achats#10
CREATE TABLE keystone.shipment_notices (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- AEX-2026-000044
  po_id uuid NOT NULL REFERENCES keystone.purchase_orders(id),
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  shipped_on date NOT NULL, expected_at timestamptz NOT NULL,
  loading_dock_booking_id uuid REFERENCES keystone.loading_dock_bookings(id),  -- Annexe S (A21)
  carrier text, tracking_no text,
  delivery_note_document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),
  status text NOT NULL DEFAULT 'declared' CHECK (status IN ('declared','delivered','cancelled')),
  CONSTRAINT uq_asn_ref UNIQUE (tenant_id, ref)
);

-- AnnexeE_Budgets_Achats#10
CREATE TABLE keystone.shipment_notice_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  notice_id uuid NOT NULL REFERENCES keystone.shipment_notices(id) ON DELETE CASCADE,
  po_line_id uuid NOT NULL REFERENCES keystone.po_lines(id),
  qty_shipped numeric(14,3) NOT NULL CHECK (qty_shipped > 0),
  lot_no text, expiry_date date
);

-- AnnexeE_Budgets_Achats#10
CREATE TABLE keystone.goods_receipts (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- REC-2026-000102
  po_id uuid NOT NULL REFERENCES keystone.purchase_orders(id),
  shipment_notice_id uuid REFERENCES keystone.shipment_notices(id),
  warehouse_id uuid REFERENCES keystone.warehouses(id),
  received_at timestamptz NOT NULL DEFAULT now(),
  received_by uuid NOT NULL,
  delivery_note_document_id uuid REFERENCES keystone.ged_documents(id),
  has_reserves boolean NOT NULL DEFAULT false,
  vendor_reserve_response jsonb,                         -- { "comment", "document_ids", "proposal": "replacement"|"credit_note"|"take_back" }
  reserve_decision text CHECK (reserve_decision IN ('replacement','credit_note','take_back')),  -- EV-L8-17
  reserve_decided_by uuid, reserve_decided_at timestamptz,
  CONSTRAINT uq_gr_ref UNIQUE (tenant_id, ref)
);

-- AnnexeE_Budgets_Achats#10
CREATE TABLE keystone.goods_receipt_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  receipt_id uuid NOT NULL REFERENCES keystone.goods_receipts(id) ON DELETE CASCADE,
  po_line_id uuid NOT NULL REFERENCES keystone.po_lines(id),
  qty_received numeric(14,3) NOT NULL CHECK (qty_received >= 0),
  qty_refused numeric(14,3) NOT NULL DEFAULT 0 CHECK (qty_refused >= 0),
  refusal_reason text, photo_document_ids uuid[] NOT NULL DEFAULT '{}',
  lot_no text, expiry_date date,
  CONSTRAINT ck_grl_reason CHECK (qty_refused = 0 OR refusal_reason IS NOT NULL)
);

-- AnnexeE_Budgets_Achats#12
CREATE TABLE keystone.expenses (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- DEP-2026-000123
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  site_id uuid REFERENCES atlas_core.sites(id),            -- obligatoire avant clôture de période
  budget_id uuid REFERENCES keystone.budgets(id),
  category_id uuid NOT NULL REFERENCES keystone.budget_categories(id),  -- poste, égal à celui du budget s'il est renseigné
  source keystone.expense_source NOT NULL,
  document_type keystone.expense_doc NOT NULL DEFAULT 'invoice',
  credited_expense_id uuid REFERENCES keystone.expenses(id),
  credit_reason text,                                    -- obligatoire pour un avoir (EV-L8-22)
  vendor_id uuid REFERENCES keystone.vendors(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  po_id uuid REFERENCES keystone.purchase_orders(id),
  maintenance_contract_id uuid REFERENCES keystone.maintenance_contracts(id),
  contract_period date,                                  -- échéance d'un contrat périodique
  service_contract_id uuid REFERENCES keystone.service_contracts(id),  -- fm_provider : imputation à un contrat client
  supplier_invoice_ref text, invoice_date date, due_date date,
  estimated_amount_ht bigint CHECK (estimated_amount_ht >= 0),  -- référence de rapprochement d'un OT
  amount_ht bigint NOT NULL DEFAULT 0 CHECK (amount_ht >= 0),
  vat_amount bigint NOT NULL DEFAULT 0 CHECK (vat_amount >= 0),
  amount_ttc bigint NOT NULL DEFAULT 0,
  penalties_imputed bigint NOT NULL DEFAULT 0 CHECK (penalties_imputed >= 0),
  net_payable bigint NOT NULL DEFAULT 0,                 -- amount_ttc moins penalties_imputed
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  kind keystone.budget_kind NOT NULL,
  is_capitalized boolean NOT NULL DEFAULT false, asset_id uuid REFERENCES keystone.assets(id),
  accounting_date date,                                  -- période d'imputation
  late_posting boolean NOT NULL DEFAULT false,
  invoice_document_id uuid REFERENCES keystone.ged_documents(id),
  status keystone.expense_status NOT NULL DEFAULT 'draft',
  match_status keystone.match_status NOT NULL DEFAULT 'not_applicable',
  match_detail jsonb,                                    -- écarts par ligne et par contrôle
  variance_justification text, variance_accepted_by uuid,
  submitted_at timestamptz, approved_by uuid, approved_at timestamptz, rejection_reason text,
  paid_amount bigint NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),  -- cumul des paiements reçus d'Atlas FNA
  paid_at timestamptz, payment_ref text,                 -- dernier paiement
  payment_channel text CHECK (payment_channel IN ('bank_transfer','mobile_money')),  -- valeur de payment.executed (EV-L8-21)
  split_checked_by uuid, split_checked_at timestamptz,   -- contrôle de fractionnement (EV-L8-25)
  fna_export_status text NOT NULL DEFAULT 'none' CHECK (fna_export_status IN ('none','pending','sent','acknowledged','failed')),
  fna_entry_ref text,
  consumption_qty numeric(14,3), consumption_unit text,  -- facture d'énergie ou d'eau
  CONSTRAINT uq_expense_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_expense_ttc CHECK (amount_ttc = amount_ht + vat_amount),
  CONSTRAINT ck_expense_net CHECK (net_payable = amount_ttc - penalties_imputed),
  CONSTRAINT ck_expense_paid CHECK (paid_amount <= net_payable OR document_type = 'credit_note'),
  CONSTRAINT ck_credit_note CHECK ((document_type = 'credit_note') = (credited_expense_id IS NOT NULL)),
  CONSTRAINT ck_credit_reason CHECK (document_type <> 'credit_note' OR credit_reason IS NOT NULL),
  CONSTRAINT ck_capex_asset CHECK (NOT is_capitalized OR (kind = 'capex' AND asset_id IS NOT NULL))
);

-- AnnexeE_Budgets_Achats#12
CREATE UNIQUE INDEX uq_expense_invoice ON keystone.expenses (tenant_id, vendor_id, document_type, supplier_invoice_ref)
  WHERE supplier_invoice_ref IS NOT NULL AND deleted_at IS NULL;

-- AnnexeE_Budgets_Achats#12
CREATE UNIQUE INDEX uq_expense_wo_vendor ON keystone.expenses (tenant_id, work_order_id, vendor_id)
  WHERE source = 'work_order' AND document_type = 'invoice' AND status <> 'cancelled' AND deleted_at IS NULL;

-- AnnexeE_Budgets_Achats#12
CREATE UNIQUE INDEX uq_expense_contract_period ON keystone.expenses (tenant_id, maintenance_contract_id, contract_period)
  WHERE source = 'contract_installment' AND document_type = 'invoice' AND status <> 'cancelled';

-- AnnexeE_Budgets_Achats#12
CREATE INDEX ix_expense_status ON keystone.expenses (tenant_id, status, match_status);

-- AnnexeE_Budgets_Achats#12
CREATE INDEX ix_expense_no_site ON keystone.expenses (tenant_id, accounting_date) WHERE site_id IS NULL AND deleted_at IS NULL;

-- AnnexeE_Budgets_Achats#12
CREATE TABLE keystone.expense_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  expense_id uuid NOT NULL REFERENCES keystone.expenses(id) ON DELETE CASCADE,
  line_no smallint NOT NULL,
  po_line_id uuid REFERENCES keystone.po_lines(id),
  label text NOT NULL, qty numeric(14,3) NOT NULL CHECK (qty > 0),
  unit_price_ht bigint NOT NULL CHECK (unit_price_ht >= 0),
  vat_rate numeric(7,4) NOT NULL,
  line_total_ht bigint NOT NULL,
  CONSTRAINT uq_expense_line UNIQUE (expense_id, line_no)
);

-- AnnexeE_Budgets_Achats#13
CREATE TABLE keystone.expense_payments (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  expense_id uuid NOT NULL REFERENCES keystone.expenses(id),
  fna_payment_ref text NOT NULL,
  amount bigint NOT NULL CHECK (amount > 0),
  paid_at timestamptz NOT NULL,
  channel text NOT NULL CHECK (channel IN ('bank_transfer','mobile_money')),
  CONSTRAINT uq_expense_payment UNIQUE (tenant_id, fna_payment_ref)
);

-- AnnexeE_Budgets_Achats#14
CREATE VIEW keystone.v_expenses_without_site WITH (security_invoker = true) AS
  SELECT id, tenant_id, ref, legal_entity_id, vendor_id, amount_ttc, currency, accounting_date, status
  FROM keystone.expenses WHERE site_id IS NULL AND deleted_at IS NULL AND status NOT IN ('rejected','cancelled');

-- AnnexeE_Budgets_Achats_Partie2#3
CREATE TABLE keystone.rfq_deadline_changes (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  rfq_id uuid NOT NULL REFERENCES keystone.rfqs(id) ON DELETE CASCADE,
  old_deadline timestamptz NOT NULL, new_deadline timestamptz NOT NULL CHECK (new_deadline > old_deadline),
  reason text NOT NULL
);

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE TABLE keystone.budget_commitments (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  budget_id uuid NOT NULL REFERENCES keystone.budgets(id) ON DELETE RESTRICT,
  source_type keystone.commitment_source NOT NULL,
  po_line_id uuid REFERENCES keystone.po_lines(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  maintenance_contract_id uuid REFERENCES keystone.maintenance_contracts(id),
  contract_period date,                                  -- échéance couverte d'un contrat périodique
  vendor_id uuid REFERENCES keystone.vendors(id),
  amount bigint NOT NULL CHECK (amount > 0),             -- base de consommation prévue (HT si TVA récupérable, TTC sinon)
  consumed_amount bigint NOT NULL DEFAULT 0 CHECK (consumed_amount >= 0),
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.commitment_status NOT NULL DEFAULT 'open',
  committed_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz, release_reason text,
  CONSTRAINT ck_cmt_source CHECK (
       (source_type = 'po_line' AND po_line_id IS NOT NULL AND work_order_id IS NULL AND maintenance_contract_id IS NULL)
    OR (source_type = 'work_order' AND work_order_id IS NOT NULL AND po_line_id IS NULL AND maintenance_contract_id IS NULL)
    OR (source_type = 'maintenance_contract' AND maintenance_contract_id IS NOT NULL AND contract_period IS NOT NULL
        AND po_line_id IS NULL AND work_order_id IS NULL)),
  CONSTRAINT ck_cmt_consumed CHECK (consumed_amount <= amount),
  CONSTRAINT ck_cmt_closed CHECK ((status = 'open') = (closed_at IS NULL)),
  CONSTRAINT ck_cmt_release CHECK (status <> 'released' OR release_reason IS NOT NULL)
);

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE UNIQUE INDEX uq_cmt_po_line ON keystone.budget_commitments (tenant_id, po_line_id) WHERE source_type = 'po_line';

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE UNIQUE INDEX uq_cmt_wo ON keystone.budget_commitments (tenant_id, work_order_id, budget_id) WHERE source_type = 'work_order';

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE UNIQUE INDEX uq_cmt_contract ON keystone.budget_commitments (tenant_id, maintenance_contract_id, contract_period)
  WHERE source_type = 'maintenance_contract';

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE INDEX ix_cmt_budget_open ON keystone.budget_commitments (tenant_id, budget_id) WHERE status = 'open';

-- AnnexeE_Budgets_Achats_Partie2#4
ALTER TABLE keystone.budget_commitments ENABLE ROW LEVEL SECURITY;

-- AnnexeE_Budgets_Achats_Partie2#4
CREATE POLICY cmt_select ON keystone.budget_commitments FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND EXISTS (SELECT 1 FROM keystone.budgets b
    WHERE b.id = budget_id AND keystone.has_permission('budget.read')
      AND (b.site_id IS NULL OR keystone.site_in_scope(b.site_id))));

-- AnnexeC_HSSE_Partie3#2
CREATE TABLE keystone.inspections (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  ref text NOT NULL,                        -- INSP-2026-000512
  kind keystone.inspection_kind NOT NULL,
  origin keystone.record_origin NOT NULL,   -- 'planned' ou 'ad_hoc' (Annexe W)
  template_id uuid REFERENCES keystone.inspection_templates(id),
  template_version int,
  plan_id uuid REFERENCES keystone.inspection_plans(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),   -- passage Soft FM contrôlé (OT kind service, D11, A59)
  location_id uuid REFERENCES keystone.locations(id), asset_id uuid REFERENCES keystone.assets(id),
  inspector_id uuid NOT NULL REFERENCES keystone.persons(id),
  escort_id uuid REFERENCES keystone.persons(id),
  status keystone.inspection_status NOT NULL,
  due_date date,
  started_at timestamptz, completed_at timestamptz,
  was_overdue boolean NOT NULL DEFAULT false,
  delay_days int CHECK (delay_days >= 0),
  score numeric(5,2) CHECK (score BETWEEN 0 AND 100),
  quality_level text,                       -- niveau EN 13549 atteint, calculé par l'Annexe F
  result keystone.inspection_result,
  summary text,
  signed_by uuid, signed_at timestamptz, escort_signed_at timestamptz,
  cancel_reason text,
  CONSTRAINT uq_insp_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_insp_origin CHECK (origin IN ('planned','ad_hoc')),
  CONSTRAINT ck_insp_tpl CHECK (template_id IS NULL OR template_version IS NOT NULL),
  CONSTRAINT ck_insp_qc CHECK (kind <> 'soft_fm_qc' OR template_id IS NOT NULL),   -- un lot couvre plusieurs passages
  CONSTRAINT ck_insp_done CHECK (status <> 'completed' OR (result IS NOT NULL AND signed_at IS NOT NULL))
);

-- AnnexeC_HSSE_Partie3#2
CREATE INDEX ix_insp_due ON keystone.inspections (tenant_id, site_id, due_date) WHERE status IN ('scheduled','overdue');

-- AnnexeC_HSSE_Partie3#2
CREATE UNIQUE INDEX uq_insp_plan_due ON keystone.inspections (plan_id, due_date) WHERE plan_id IS NOT NULL;

-- AnnexeR_Reglementaire_SSI#3
CREATE TABLE keystone.regulatory_control_results (     -- historique de chaque contrôle réalisé
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  control_id uuid NOT NULL REFERENCES keystone.regulatory_controls(id) ON DELETE RESTRICT,
  control_date date NOT NULL CHECK (control_date <= current_date),
  result keystone.control_result NOT NULL,
  body_id uuid REFERENCES keystone.inspection_bodies(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  report_document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),
  report_valid_until date,
  is_recheck boolean NOT NULL DEFAULT false,
  recorded_by uuid NOT NULL
);

-- AnnexeR_Reglementaire_SSI#4
CREATE FUNCTION keystone.assert_regulatory_wo_closable(p_wo uuid, p_to text) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE w keystone.work_orders;
BEGIN
  SELECT * INTO w FROM keystone.work_orders WHERE id = p_wo AND tenant_id = keystone.current_tenant();
  IF w.type <> 'regulatory' OR p_to NOT IN ('verified','closed') THEN RETURN; END IF;
  IF auth.role() = 'service_role' OR (auth.jwt() ->> 'agent_id') IS NOT NULL THEN
    PERFORM keystone.raise_error('HUMAN_CLOSURE_REQUIRED'); END IF;
  IF NOT EXISTS (SELECT 1 FROM keystone.regulatory_control_results r WHERE r.work_order_id = p_wo) THEN
    PERFORM keystone.raise_error('REPORT_REQUIRED'); END IF;
  IF p_to = 'verified' AND w.second_verifier_id IS NULL THEN
    PERFORM keystone.raise_error('SECOND_VERIFICATION_REQUIRED'); END IF;
END; $$;

-- AnnexeR_Reglementaire_SSI#6
CREATE TABLE keystone.ssi_inhibitions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  permit_id uuid NOT NULL REFERENCES keystone.work_permits(id),   -- RG-SSI-03 : toujours rattachée à un permis
  sector_id uuid NOT NULL REFERENCES keystone.sectors(id),       -- compartiment du zonage incendie
  fire_system_id uuid REFERENCES keystone.fire_systems(id),
  detector_refs text[] NOT NULL CHECK (cardinality(detector_refs) > 0),
  planned_start timestamptz NOT NULL, planned_end timestamptz NOT NULL,
  status keystone.ssi_inhibition_status NOT NULL DEFAULT 'requested',
  requested_by uuid NOT NULL,
  confirmed_by uuid, activated_at timestamptz,
  compensatory_measures jsonb,               -- {"patrol_route_id":..,"watch_person_id":..,"interval_min":..}
  restored_by uuid, restored_at timestamptz, restore_test_ok boolean,
  cancel_reason text,
  CONSTRAINT ck_ssi_period CHECK (planned_end > planned_start),
  CONSTRAINT ck_ssi_active CHECK (status NOT IN ('active','overrun') OR (activated_at IS NOT NULL AND compensatory_measures IS NOT NULL)),
  CONSTRAINT ck_ssi_restored CHECK (status <> 'restored' OR (restored_at IS NOT NULL AND restore_test_ok))
);

-- AnnexeR_Reglementaire_SSI#6
CREATE INDEX ix_ssi_live ON keystone.ssi_inhibitions (tenant_id, site_id) WHERE status IN ('active','overrun');

-- AnnexeD_Tickets_Portails#3
CREATE TABLE keystone.tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                          -- TCK-AAAA-NNNNNN, next_ref('ticket', année)
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,   -- déduit du lieu, base des RLS
  channel keystone.ticket_channel NOT NULL,
  category_id uuid NOT NULL REFERENCES keystone.ticket_categories(id) ON DELETE RESTRICT,
  priority smallint NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 4),
  requested_priority keystone.ticket_requested_priority,      -- urgence ressentie, NULL en canal public
  priority_reason text,                                       -- obligatoire si priorité retenue différente de l'urgence ressentie
  status keystone.ticket_status NOT NULL DEFAULT 'new',
  title varchar(120) NOT NULL,
  description varchar(1000) NOT NULL CHECK (char_length(description) >= 10),
  location_id uuid NOT NULL REFERENCES keystone.locations(id) ON DELETE RESTRICT,   -- RG-TCK-01
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE SET NULL,
  reporter_id uuid,                                           -- auth.users ; NULL en canal public
  occupant_org_id uuid REFERENCES keystone.occupant_organizations(id) ON DELETE RESTRICT,
  org_visible boolean NOT NULL DEFAULT true,                  -- visible des membres de l'organisation avec org_read
  public_contact_email text,                                  -- canal public seulement, purgé à clôture plus 30 jours
  onsite_contact jsonb,                                       -- {"name": text, "phone": text}
  callback_requested boolean NOT NULL DEFAULT false,
  client_id uuid REFERENCES keystone.clients(id) ON DELETE RESTRICT,   -- fm_provider, déduit du site
  assignee_id uuid REFERENCES keystone.persons(id) ON DELETE SET NULL,
  team_id uuid REFERENCES keystone.teams(id) ON DELETE SET NULL,     -- Annexe PL (A92)
  decision keystone.ticket_decision,                          -- posée à la qualification
  decision_at timestamptz, decision_by uuid,
  reject_reason text,
  sla_policy_id uuid REFERENCES keystone.sla_policies(id) ON DELETE SET NULL,   -- Annexe B, A60
  sla_ack_due timestamptz NOT NULL,                           -- A60, accusé de prise en compte (passage à triage)
  first_ack_at timestamptz,
  sla_response_due timestamptz NOT NULL,                      -- A06, prise en charge (passage à assigned)
  sla_resolution_due timestamptz NOT NULL,                    -- A06, rétablissement (passage à resolved)
  client_sla_due timestamptz,                                 -- A06, contrat client, base des pénalités (fm_provider)
  first_assigned_at timestamptz,
  converted_wo_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,   -- OT en cours
  resolution_note text, resolution_code keystone.ticket_resolution_code,
  resolved_at timestamptz, closed_at timestamptz,
  close_mode text CHECK (close_mode IN ('confirmed','auto','staff')),
  cancelled_at timestamptz,
  reopen_count smallint NOT NULL DEFAULT 0,
  satisfaction_score smallint CHECK (satisfaction_score BETWEEN 1 AND 5),   -- copie de survey_responses.score
  public_email_purge_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_ticket_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_ticket_public CHECK (channel <> 'public' OR (reporter_id IS NULL AND requested_priority IS NULL)),
  CONSTRAINT ck_ticket_public_email CHECK (public_contact_email IS NULL OR channel = 'public'),
  CONSTRAINT ck_ticket_reject CHECK (status <> 'rejected' OR reject_reason IS NOT NULL),
  CONSTRAINT ck_ticket_resolution CHECK (status NOT IN ('resolved','closed') OR decision = 'reject'
       OR (resolution_note IS NOT NULL AND resolution_code IS NOT NULL))
);

-- AnnexeD_Tickets_Portails#3
CREATE INDEX ix_ticket_queue    ON keystone.tickets (tenant_id, site_id, status, sla_resolution_due) WHERE deleted_at IS NULL;

-- AnnexeD_Tickets_Portails#3
CREATE INDEX ix_ticket_reporter ON keystone.tickets (tenant_id, reporter_id) WHERE reporter_id IS NOT NULL;

-- AnnexeD_Tickets_Portails#3
CREATE INDEX ix_ticket_org      ON keystone.tickets (tenant_id, occupant_org_id) WHERE occupant_org_id IS NOT NULL;

-- AnnexeD_Tickets_Portails#3
CREATE INDEX ix_ticket_client   ON keystone.tickets (tenant_id, client_id, site_id) WHERE client_id IS NOT NULL;

-- AnnexeD_Tickets_Portails#3
CREATE INDEX ix_ticket_dup      ON keystone.tickets (tenant_id, location_id, category_id, created_at)
  WHERE status IN ('new','triage','assigned','in_progress','reopened');

-- AnnexeD_Tickets_Portails#3
CREATE INDEX ix_ticket_wo       ON keystone.tickets (converted_wo_id) WHERE converted_wo_id IS NOT NULL;

-- AnnexeD_Tickets_Portails#4
CREATE TABLE keystone.ticket_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, ticket_id uuid NOT NULL REFERENCES keystone.tickets(id) ON DELETE CASCADE,
  author_id uuid NOT NULL, body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  is_internal boolean NOT NULL DEFAULT false,          -- jamais visible hors console (RG-TCK-07)
  template_id uuid REFERENCES keystone.ticket_templates(id) ON DELETE SET NULL,
  is_reminder boolean NOT NULL DEFAULT false,          -- relance du client ou de l'occupant (PC-07), jamais interne
  mentions uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(mentions) <= 20),  -- proposition, à valider par la cliente (Annexe A partie 4 §A.22) ; commentaire is_internal seulement
  at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_ticket_comment_reminder CHECK (NOT (is_reminder AND is_internal)),
  CONSTRAINT ck_ticket_comment_mentions CHECK (is_internal OR cardinality(mentions) = 0) );

-- AnnexeD_Tickets_Portails#4
CREATE INDEX ix_ticket_comment ON keystone.ticket_comments (tenant_id, ticket_id, at);

-- AnnexeD_Tickets_Portails#4
CREATE INDEX ix_ticket_reminder ON keystone.ticket_comments (tenant_id, ticket_id, at DESC) WHERE is_reminder;

-- AnnexeD_Tickets_Portails#4
CREATE TABLE keystone.ticket_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, ticket_id uuid NOT NULL REFERENCES keystone.tickets(id) ON DELETE CASCADE,
  comment_id uuid REFERENCES keystone.ticket_comments(id) ON DELETE CASCADE,
  file_path text NOT NULL,
  mime_type text NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp','application/pdf')),
  size_bytes int NOT NULL CHECK (size_bytes BETWEEN 1 AND 10485760),     -- 10 Mo
  exif_stripped boolean NOT NULL DEFAULT false, is_internal boolean NOT NULL DEFAULT false,
  uploaded_by uuid, at timestamptz NOT NULL DEFAULT now() );

-- AnnexeD_Tickets_Portails#4
-- trigger : 5 pièces au plus par ticket hors console, 1 en canal public (FILE_LIMIT_EXCEEDED)

CREATE TABLE keystone.ticket_followers (
  tenant_id uuid NOT NULL, ticket_id uuid NOT NULL REFERENCES keystone.tickets(id) ON DELETE CASCADE,
  user_id uuid NOT NULL, added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ticket_id, user_id) );

-- AnnexeD_Tickets_Portails#4
CREATE TABLE keystone.ticket_status_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, ticket_id uuid NOT NULL REFERENCES keystone.tickets(id) ON DELETE CASCADE,
  from_status keystone.ticket_status, to_status keystone.ticket_status NOT NULL,
  reason text, actor_id uuid,
  actor_kind text NOT NULL CHECK (actor_kind IN ('staff','reporter','client','system')),
  at timestamptz NOT NULL DEFAULT now() );

-- AnnexeD_Tickets_Portails#4
CREATE INDEX ix_ticket_hist ON keystone.ticket_status_history (tenant_id, ticket_id, at);

-- AnnexeD_Tickets_Portails#4
CREATE TABLE keystone.ticket_work_orders (
  tenant_id uuid NOT NULL, ticket_id uuid NOT NULL REFERENCES keystone.tickets(id) ON DELETE CASCADE,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('origin','rework')), linked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ticket_id, work_order_id) );

-- AnnexeD_Tickets_Portails#5
-- keystone.client_can_see_site(p_site) : définie en Annexe M, utilisée telle quelle.

CREATE FUNCTION keystone.is_ticket_reporter_or_client(p_ticket uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM keystone.tickets t
    WHERE t.id = p_ticket AND t.tenant_id = keystone.current_tenant()
      AND (t.reporter_id = auth.uid()
           OR (t.client_id = keystone.current_client()
               AND keystone.has_permission('client_portal.validate')
               AND keystone.client_can_see_site(t.site_id)))) $$;

-- AnnexeD_Tickets_Portails#6
CREATE FUNCTION keystone.ticket_transition(p_ticket uuid, p_to keystone.ticket_status, p_meta jsonb DEFAULT '{}')
RETURNS keystone.tickets LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE t keystone.tickets;
BEGIN
  SELECT * INTO t FROM keystone.tickets WHERE id = p_ticket AND tenant_id = keystone.current_tenant()
    AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  IF NOT keystone.ticket_transition_allowed(t.status, p_to, t.channel) THEN PERFORM keystone.raise_error('INVALID_TRANSITION'); END IF;
  CASE p_to
    WHEN 'triage' THEN PERFORM keystone.require_permission('ticket.assign');
    WHEN 'assigned' THEN PERFORM keystone.require_permission('ticket.assign');
      IF t.decision IS NULL AND (p_meta->>'decision') IS NULL THEN PERFORM keystone.raise_error('DECISION_REQUIRED'); END IF;
      IF (p_meta->>'assignee_id') IS NULL AND (p_meta->>'team_id') IS NULL THEN PERFORM keystone.raise_error('ASSIGNEE_REQUIRED'); END IF;
      PERFORM keystone.assert_priority_reason(t, p_meta);            -- PRIORITY_REASON_REQUIRED
    WHEN 'in_progress' THEN
      IF NOT (keystone.has_permission('ticket.resolve') OR t.assignee_id = keystone.current_person_id()) THEN
        PERFORM keystone.raise_error('PERMISSION_DENIED'); END IF;
    WHEN 'resolved' THEN PERFORM keystone.require_permission('ticket.resolve');
      IF EXISTS (SELECT 1 FROM keystone.work_orders w WHERE w.id = t.converted_wo_id
                  AND w.status <> 'verified' AND w.stage <> 'closed') THEN PERFORM keystone.raise_error('WO_NOT_VERIFIED'); END IF;
      IF coalesce(p_meta->>'resolution_note','') = '' OR (p_meta->>'resolution_code') IS NULL THEN
        PERFORM keystone.raise_error('RESOLUTION_REQUIRED'); END IF;
    WHEN 'closed' THEN
      IF NOT (keystone.has_permission('ticket.resolve') OR keystone.is_ticket_reporter_or_client(t.id)) THEN
        PERFORM keystone.raise_error('PERMISSION_DENIED'); END IF;
    WHEN 'reopened' THEN
      IF NOT (keystone.has_permission('ticket.assign') OR keystone.is_ticket_reporter_or_client(t.id)) THEN
        PERFORM keystone.raise_error('PERMISSION_DENIED'); END IF;
      IF coalesce(p_meta->>'reason','') = '' THEN PERFORM keystone.raise_error('REASON_REQUIRED'); END IF;
      IF now() > t.resolved_at + make_interval(days => keystone.setting_int('ticket.reopen_days', 7)) THEN
        PERFORM keystone.raise_error('REOPEN_WINDOW_EXPIRED', jsonb_build_object('days', keystone.setting_int('ticket.reopen_days', 7))); END IF;
    WHEN 'rejected' THEN PERFORM keystone.require_permission('ticket.assign');
      IF coalesce(p_meta->>'reason','') = '' THEN PERFORM keystone.raise_error('REASON_REQUIRED'); END IF;
    WHEN 'cancelled' THEN
      IF t.reporter_id IS DISTINCT FROM auth.uid() THEN PERFORM keystone.raise_error('PERMISSION_DENIED'); END IF;
  END CASE;
  -- effets : colonnes d'horodatage, ticket_status_history, notifications, invitation d'enquête à la clôture
  RETURN keystone.ticket_apply_transition(t, p_to, p_meta);
END $$;

-- AnnexeD_Tickets_Portails#8
ALTER TABLE keystone.tickets ENABLE ROW LEVEL SECURITY;

-- AnnexeD_Tickets_Portails#8
CREATE POLICY tickets_select ON keystone.tickets FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL AND (
       (keystone.has_permission('ticket.read')
          AND (keystone.has_permission('scope.all') OR site_id IN (SELECT keystone.user_sites())))
    OR reporter_id = auth.uid()
    OR (occupant_org_id = keystone.current_occupant_org() AND org_visible
        AND keystone.has_permission('occupant_portal.org_read'))
  ));

-- AnnexeD_Tickets_Portails#8
-- Politiques du portail client, Annexe CL.2 (reprises ici, la définition de CL.2 fait foi) :
CREATE POLICY tickets_client_select ON keystone.tickets FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND deleted_at IS NULL
         AND keystone.current_client() IS NOT NULL AND keystone.client_can_see_site(site_id));

-- AnnexeD_Tickets_Portails#8
CREATE POLICY tickets_client_insert ON keystone.tickets FOR INSERT
  WITH CHECK (tenant_id = keystone.current_tenant() AND keystone.has_permission('client_portal.request')
              AND keystone.client_can_see_site(site_id) AND channel = 'client_portal');

-- AnnexeD_Tickets_Portails#9
CREATE FUNCTION keystone.client_ticket_last_reminder(p_ticket uuid) RETURNS timestamptz
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
  SELECT max(c.at) FROM keystone.ticket_comments c
   WHERE c.ticket_id = p_ticket AND c.tenant_id = keystone.current_tenant() AND c.is_reminder $$;

-- AnnexeD_Tickets_Portails_Partie2#3
CREATE VIEW keystone.v_occupant_tickets WITH (security_invoker = true) AS
SELECT t.id, t.ref, t.site_id, t.title, t.description, t.category_id, t.location_id, t.asset_id,
       t.requested_priority, t.priority, t.priority_reason, t.status, t.reject_reason,
       t.resolution_note, t.created_at, t.updated_at, t.resolved_at, t.closed_at,
       t.reporter_id = auth.uid() AS is_mine,
       false AS is_follower,
       CASE WHEN t.reporter_id = auth.uid() THEN NULL ELSE t.reporter_id END AS org_reporter_id
  FROM keystone.tickets t
 WHERE t.tenant_id = keystone.current_tenant() AND t.deleted_at IS NULL
   AND (t.reporter_id = auth.uid()
        OR (t.occupant_org_id = keystone.current_occupant_org() AND t.org_visible
            AND keystone.has_permission('occupant_portal.org_read')))
UNION ALL
SELECT t.id, t.ref, t.site_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, t.status, NULL,
       CASE WHEN t.status IN ('resolved','closed') THEN t.resolution_note END,
       t.created_at, t.updated_at, t.resolved_at, t.closed_at, false, true, NULL
  FROM keystone.tickets t JOIN keystone.ticket_followers f ON f.ticket_id = t.id AND f.user_id = auth.uid()
 WHERE t.tenant_id = keystone.current_tenant() AND t.reporter_id IS DISTINCT FROM auth.uid();

-- AnnexeD_Tickets_Portails_Partie2#4
CREATE VIEW keystone.v_occupant_work_orders WITH (security_invoker = true) AS
SELECT tw.ticket_id, w.planned_start, w.planned_end, w.shutdown_start, w.shutdown_end,
       w.stage, 'Équipe technique'::text AS performed_by_label,
       (SELECT min(s.scanned_at) FROM keystone.wo_scan_log s
         WHERE s.work_order_id = w.id AND s.action = 'start') AS presence_confirmed_at,
       w.actual_end
  FROM keystone.ticket_work_orders tw
  JOIN keystone.work_orders w ON w.id = tw.work_order_id
  JOIN keystone.v_occupant_tickets vt ON vt.id = tw.ticket_id AND NOT vt.is_follower;

-- AnnexeD_Tickets_Portails_Partie2#6
CREATE TABLE keystone.site_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE CASCADE,
  title varchar(80) NOT NULL, body text NOT NULL,
  type keystone.announcement_type NOT NULL, level keystone.announcement_level NOT NULL,
  valid_from timestamptz NOT NULL, valid_to timestamptz NOT NULL,
  status keystone.announcement_status NOT NULL DEFAULT 'draft',
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','planning')),
  source_work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,
  ack_required boolean NOT NULL DEFAULT false,
  attachment_document_id uuid,                     -- GED, Annexe G
  published_at timestamptz, published_by uuid, withdrawn_at timestamptz, withdrawn_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_announcement_period CHECK (valid_to > valid_from),
  CONSTRAINT ck_announcement_ack CHECK (NOT ack_required OR level IN ('important','urgent'))
);

-- AnnexeD_Tickets_Portails_Partie2#6
CREATE TABLE keystone.announcement_targets (
  announcement_id uuid NOT NULL REFERENCES keystone.site_announcements(id) ON DELETE CASCADE,
  target_kind text NOT NULL CHECK (target_kind IN ('site','building','floor','occupant_org')),
  target_id uuid NOT NULL, PRIMARY KEY (announcement_id, target_kind, target_id) );

-- AnnexeD_Tickets_Portails_Partie2#6
CREATE TABLE keystone.announcement_reads (
  announcement_id uuid NOT NULL REFERENCES keystone.site_announcements(id) ON DELETE CASCADE,
  user_id uuid NOT NULL, read_at timestamptz NOT NULL DEFAULT now(), acknowledged_at timestamptz,
  PRIMARY KEY (announcement_id, user_id) );

-- AnnexeD_Tickets_Portails_Partie2#6
CREATE INDEX ix_announcement_live ON keystone.site_announcements (tenant_id, site_id, status, valid_from, valid_to);

-- AnnexeP_Prestataires_Mobile_Partie2#5
CREATE TABLE keystone.lone_worker_sessions (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  started_at timestamptz NOT NULL DEFAULT now(), ended_at timestamptz,
  location_id uuid REFERENCES atlas_core.spaces(id),
  check_in_interval_minutes integer NOT NULL DEFAULT 30 CHECK (check_in_interval_minutes BETWEEN 5 AND 120),
  motion_detection boolean NOT NULL DEFAULT false,       -- paramètre lone_worker.motion_detection, défaut faux (L7-24)
  last_check_in_at timestamptz NOT NULL DEFAULT now()
);

-- AnnexeP_Prestataires_Mobile_Partie2#5
CREATE INDEX ix_lws_open ON keystone.lone_worker_sessions (tenant_id, last_check_in_at) WHERE ended_at IS NULL;

-- AnnexeP_Prestataires_Mobile_Partie2#5
CREATE UNIQUE INDEX uq_lws_person_open ON keystone.lone_worker_sessions (tenant_id, person_id) WHERE ended_at IS NULL;

-- AnnexeP_Prestataires_Mobile_Partie2#5
CREATE TABLE keystone.lone_worker_alerts (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  session_id uuid REFERENCES keystone.lone_worker_sessions(id),
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  device_session_id uuid REFERENCES keystone.device_sessions(id),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  location_id uuid REFERENCES atlas_core.spaces(id),
  trigger keystone.lone_worker_trigger NOT NULL,
  raised_at timestamptz NOT NULL DEFAULT now(),
  position jsonb,                                        -- { "space_unit_id", "x", "y", "accuracy_m" } ou coordonnées GNSS
  status keystone.lone_worker_status NOT NULL DEFAULT 'raised',
  acknowledged_by uuid, acknowledged_at timestamptz,
  resolved_by uuid, resolved_at timestamptz, resolution_note text,
  escalation_level smallint NOT NULL DEFAULT 0 CHECK (escalation_level BETWEEN 0 AND 3)
);

-- AnnexeP_Prestataires_Mobile_Partie2#5
CREATE INDEX ix_lwa_open ON keystone.lone_worker_alerts (tenant_id, site_id, raised_at) WHERE status IN ('raised','acknowledged');

-- AnnexeTA_Travaux_Amenagement#5
CREATE VIEW keystone.v_fitout_queue WITH (security_invoker = true) AS              -- L9-01
SELECT r.id, r.ref, r.site_id, r.occupant_org_id, r.status, r.instructing_party, r.reinforced_review,
       r.planned_start, r.planned_end, r.info_due_date,
       (SELECT count(*) FROM keystone.fitout_visas v WHERE v.fitout_request_id = r.id AND v.decision IS NULL) AS visas_pending,
       (SELECT count(*) FROM keystone.fitout_visas v WHERE v.fitout_request_id = r.id AND v.decision = 'unfavourable') AS visas_unfavourable,
       (SELECT count(*) FROM keystone.fitout_contractors c WHERE c.fitout_request_id = r.id AND c.clearance_status = 'pending') AS contractors_pending,
       (SELECT bool_and(p.status = 'active') FROM keystone.work_permits p
         WHERE p.fitout_request_id = r.id AND current_date BETWEEN p.valid_from::date AND p.valid_to::date) AS permits_today_ok,
       d.status AS deposit_status
  FROM keystone.fitout_requests r LEFT JOIN keystone.fitout_deposits d ON d.fitout_request_id = r.id
 WHERE r.status <> 'draft' AND r.deleted_at IS NULL;

-- AnnexeM_Mode_Prestataire#7
CREATE TABLE keystone.mobilization_tasks (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  project_id uuid NOT NULL REFERENCES keystone.mobilization_projects(id) ON DELETE CASCADE,
  category keystone.mobilization_category NOT NULL,
  label text NOT NULL,
  is_blocking boolean NOT NULL DEFAULT false,
  evidence_required boolean NOT NULL DEFAULT false,
  responsible_id uuid REFERENCES keystone.persons(id),
  due_date date,
  status keystone.mobilization_task_status NOT NULL DEFAULT 'todo',
  evidence_document_ids uuid[] NOT NULL DEFAULT '{}',
  na_reason text,
  completed_by uuid, completed_at timestamptz,
  work_order_id uuid REFERENCES keystone.work_orders(id),   -- OT créé pour réaliser la tâche (Lot 11 §13 évolution 19)
  CONSTRAINT ck_task_na CHECK (status <> 'na' OR na_reason IS NOT NULL),
  CONSTRAINT ck_task_evidence CHECK (status <> 'done' OR NOT (is_blocking OR evidence_required) OR cardinality(evidence_document_ids) >= 1)
);

-- AnnexeM_Mode_Prestataire#7
CREATE INDEX ix_mobtask_project ON keystone.mobilization_tasks (tenant_id, project_id, status);

-- AnnexeM_Mode_Prestataire#9
-- completion : garantie de parfait achèvement (1 an) ; biennial : bon fonctionnement (2 ans) ;
-- decennial : décennale (10 ans) ; durées légales par pays à confirmer (Côte d'Ivoire, Sénégal, Cameroun, Gabon)

CREATE TABLE keystone.mobilization_reserves (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- RSV-AAAA-NNNNNN
  project_id uuid NOT NULL REFERENCES keystone.mobilization_projects(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  location_id uuid REFERENCES keystone.locations(id),
  asset_id uuid REFERENCES keystone.assets(id),
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),   -- entreprise responsable de la levée
  lot_label text,                                        -- lot de construction (gros œuvre, CVC, électricité)
  description text NOT NULL CHECK (char_length(description) BETWEEN 5 AND 2000),
  photo_document_ids uuid[] NOT NULL DEFAULT '{}',
  severity keystone.risk_level NOT NULL,                 -- critical : bloque l'ouverture
  is_blocking boolean GENERATED ALWAYS AS (severity = 'critical') STORED,
  guarantee keystone.works_guarantee NOT NULL DEFAULT 'completion',
  status keystone.mobilization_reserve_status NOT NULL DEFAULT 'open',
  raised_on date NOT NULL DEFAULT current_date,
  lift_due date NOT NULL,
  lifted_on date, lifted_by uuid, lift_evidence_document_ids uuid[] NOT NULL DEFAULT '{}',
  accepted_by uuid, accepted_at timestamptz,
  work_order_id uuid REFERENCES keystone.work_orders(id),   -- OT de levée si l'exploitant intervient
  cancel_reason text,
  CONSTRAINT uq_mres_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_mres_due CHECK (lift_due >= raised_on),
  CONSTRAINT ck_mres_lifted CHECK (status NOT IN ('lifted','accepted') OR (lifted_on IS NOT NULL AND cardinality(lift_evidence_document_ids) >= 1)),
  CONSTRAINT ck_mres_accept CHECK (status <> 'accepted' OR (accepted_by IS NOT NULL AND accepted_by IS DISTINCT FROM lifted_by)),
  CONSTRAINT ck_mres_cancel CHECK ((status = 'cancelled') = (cancel_reason IS NOT NULL))
);

-- AnnexeM_Mode_Prestataire#9
CREATE INDEX ix_mres_project ON keystone.mobilization_reserves (tenant_id, project_id, status);

-- AnnexeM_Mode_Prestataire#9
CREATE INDEX ix_mres_vendor ON keystone.mobilization_reserves (tenant_id, vendor_id) WHERE status IN ('open','in_progress');

-- AnnexeM_Mode_Prestataire#10
CREATE VIEW keystone.v_mobilization_reserves WITH (security_invoker = true) AS
SELECT r.id, r.ref, r.project_id, p.ref AS project_ref, r.site_id, r.location_id, r.asset_id,
       r.vendor_id, v.name AS vendor_name, r.lot_label, r.description, r.severity, r.is_blocking,
       r.guarantee, r.status, r.raised_on, r.lift_due, r.lifted_on, r.accepted_at, r.work_order_id,
       (r.status IN ('open','in_progress') AND r.lift_due < current_date) AS is_overdue,
       CASE r.guarantee WHEN 'completion' THEN p.works_handover_date + interval '1 year'
                        WHEN 'biennial'   THEN p.works_handover_date + interval '2 years'
                        WHEN 'decennial'  THEN p.works_handover_date + interval '10 years' END::date AS guarantee_end,
       cardinality(r.photo_document_ids) AS photos_count
  FROM keystone.mobilization_reserves r
  JOIN keystone.mobilization_projects p ON p.id = r.project_id
  JOIN keystone.vendors v ON v.id = r.vendor_id
 WHERE r.deleted_at IS NULL;

-- AnnexeM_Mode_Prestataire_Partie2#1
CREATE TABLE keystone.client_quotes (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- DEV-2026-000031
  version smallint NOT NULL DEFAULT 1,
  supersedes_id uuid REFERENCES keystone.client_quotes(id),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contract_id uuid NOT NULL REFERENCES keystone.service_contracts(id),
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid REFERENCES keystone.assets(id),
  title text NOT NULL, reason text NOT NULL,
  lead_time_days integer CHECK (lead_time_days >= 0),
  valid_until date NOT NULL,
  refusal_consequence text,
  amount_ht bigint NOT NULL DEFAULT 0,                   -- lignes retenues
  vat_amount bigint NOT NULL DEFAULT 0, amount_ttc bigint NOT NULL DEFAULT 0,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  threshold_at_submission bigint,                        -- seuil du contrat figé à la soumission
  client_po_ref text,
  status keystone.client_quote_status NOT NULL DEFAULT 'draft',
  submitted_at timestamptz, decided_at timestamptz, refusal_reason text, revision_request text,
  validity_suspended_at timestamptz,                     -- en attente d'habilitation
  document_ids uuid[] NOT NULL DEFAULT '{}',
  CONSTRAINT uq_quote_version UNIQUE (tenant_id, ref, version),
  CONSTRAINT ck_quote_ttc CHECK (amount_ttc = amount_ht + vat_amount)
);

-- AnnexeM_Mode_Prestataire_Partie2#1
CREATE INDEX ix_quote_status ON keystone.client_quotes (tenant_id, client_id, status);

-- AnnexeM_Mode_Prestataire_Partie2#1
CREATE TABLE keystone.client_quote_lines (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  quote_id uuid NOT NULL REFERENCES keystone.client_quotes(id) ON DELETE CASCADE,
  line_no smallint NOT NULL,
  label text NOT NULL, qty numeric(14,3) NOT NULL CHECK (qty > 0), unit text NOT NULL,
  unit_price_ht bigint NOT NULL CHECK (unit_price_ht >= 0),   -- prix de vente
  line_total_ht bigint NOT NULL,                          -- arrondi_demi_pair(qty * unit_price_ht)
  is_optional boolean NOT NULL DEFAULT false,
  retained boolean NOT NULL DEFAULT true,                 -- décidé par le client pour une ligne optionnelle
  CONSTRAINT uq_quote_line UNIQUE (quote_id, line_no)
);

-- AnnexeM_Mode_Prestataire_Partie2#1
CREATE TABLE keystone.client_quote_approvals (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  quote_id uuid NOT NULL REFERENCES keystone.client_quotes(id) ON DELETE CASCADE,
  level smallint NOT NULL CHECK (level IN (1,2)),
  client_user_id uuid NOT NULL REFERENCES keystone.client_users(id),
  decision text NOT NULL CHECK (decision IN ('approved','refused','revision_requested')),
  approved_amount_ht bigint,
  comment text, signature_id uuid NOT NULL REFERENCES keystone.ged_documents(id),
  decided_at timestamptz NOT NULL DEFAULT now(), ip inet,
  CONSTRAINT uq_quote_level UNIQUE (quote_id, level)
);

-- AnnexeM_Mode_Prestataire_Partie2#2
CREATE TABLE keystone.client_acceptances (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contract_id uuid NOT NULL REFERENCES keystone.service_contracts(id),
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  round smallint NOT NULL DEFAULT 1,                     -- nouvelle réception après reprise : round + 1
  status keystone.acceptance_status NOT NULL DEFAULT 'pending',
  due_at timestamptz NOT NULL,                           -- réception FM plus client_acceptance_days jours ouvrés
  decided_by uuid REFERENCES keystone.client_users(id),
  decided_at timestamptz, comment text, signature_id uuid REFERENCES keystone.ged_documents(id),
  CONSTRAINT uq_acceptance_round UNIQUE (tenant_id, work_order_id, round),
  CONSTRAINT ck_acceptance_decider CHECK (status IN ('pending','tacitly_accepted') OR decided_by IS NOT NULL)
);

-- AnnexeM_Mode_Prestataire_Partie2#2
CREATE TABLE keystone.client_acceptance_reserves (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  acceptance_id uuid NOT NULL REFERENCES keystone.client_acceptances(id) ON DELETE CASCADE,
  description text NOT NULL,
  criticity text NOT NULL CHECK (criticity IN ('minor','major','blocking')),
  photo_document_ids uuid[] NOT NULL DEFAULT '{}',
  rework_work_order_id uuid REFERENCES keystone.work_orders(id),  -- OT de reprise
  lifted_at timestamptz
);

-- AnnexeM_Mode_Prestataire_Partie2#2
CREATE TABLE keystone.client_disputes (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  acceptance_id uuid NOT NULL REFERENCES keystone.client_acceptances(id),
  reason text NOT NULL, document_ids uuid[] NOT NULL DEFAULT '{}',
  fm_due_at timestamptz NOT NULL,                        -- 2 jours ouvrés
  fm_response text CHECK (fm_response IN ('accepted','maintained')),
  fm_justification text, fm_document_ids uuid[] NOT NULL DEFAULT '{}', fm_answered_by uuid, fm_answered_at timestamptz,
  client_followup text CHECK (client_followup IN ('accepted','accepted_with_reserves','arbitration')),
  arbitration_action_item_id uuid REFERENCES keystone.action_items(id),
  arbitration_due date,                                  -- 30 jours maximum
  arbitration_decision text CHECK (arbitration_decision IN ('accept','rework')),
  status keystone.dispute_status NOT NULL DEFAULT 'open',
  CONSTRAINT ck_dispute_justif CHECK (fm_response <> 'maintained' OR fm_justification IS NOT NULL)
);

-- AnnexeM_Mode_Prestataire_Partie2#5
CREATE POLICY quotes_client_select ON keystone.client_quotes FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND deleted_at IS NULL
         AND client_id = keystone.current_client() AND status <> 'draft'
         AND keystone.client_can_see_site(site_id));

-- AnnexeF_SoftFM#3
CREATE TABLE keystone.qc_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  inspection_id uuid NOT NULL UNIQUE REFERENCES keystone.inspections(id) ON DELETE RESTRICT,   -- kind = 'soft_fm_qc' (A59)
  profile_id uuid NOT NULL REFERENCES keystone.qc_profiles(id),
  sector_id uuid NOT NULL REFERENCES keystone.sectors(id),
  period daterange NOT NULL,
  method text NOT NULL DEFAULT 'EN13549:2001' CHECK (method = 'EN13549:2001'),
  lot_size int NOT NULL CHECK (lot_size >= 2),          -- N, espaces du secteur au tirage
  code_letter char(1) NOT NULL, sample_size int NOT NULL CHECK (sample_size >= 1),   -- n effectif
  aql numeric(4,1) NOT NULL, accept_number int NOT NULL, reject_number int NOT NULL,
  sample_seed text NOT NULL,                             -- graine du tirage, rejouable
  elements_inspected int, nonconformities int,
  score numeric(5,2) CHECK (score BETWEEN 0 AND 100),    -- informatif, F.3 formule
  lot_accepted boolean,                                  -- NULL tant que le lot n'est pas clos
  sampled_at timestamptz NOT NULL DEFAULT now(), closed_at timestamptz,
  inspector_id uuid NOT NULL REFERENCES keystone.persons(id),
  CONSTRAINT ck_qc_plan CHECK (reject_number = accept_number + 1) );

-- AnnexeF_SoftFM#3
CREATE INDEX ix_qc_sector ON keystone.qc_scores (tenant_id, sector_id, closed_at);

-- AnnexeF_SoftFM#3
-- passages couverts par le lot : work_orders.qc_inspection_id = qc_scores.inspection_id (Annexe B, A59)

CREATE TABLE keystone.qc_samples (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qc_score_id uuid NOT NULL REFERENCES keystone.qc_scores(id) ON DELETE CASCADE,
  space_unit_id uuid NOT NULL REFERENCES atlas_core.spaces(id),
  draw_rank int NOT NULL, inspected_at timestamptz,
  replaced_reason text,                                 -- espace inaccessible : remplacé par le suivant du tirage
  CONSTRAINT uq_qc_sample UNIQUE (qc_score_id, space_unit_id) );

-- AnnexeF_SoftFM#3
CREATE TABLE keystone.qc_sample_findings (
  qc_sample_id uuid NOT NULL REFERENCES keystone.qc_samples(id) ON DELETE CASCADE,
  element_code text NOT NULL, applicable boolean NOT NULL DEFAULT true,
  conforming boolean,                                   -- NULL tant que non contrôlé
  defect_note text, photo_path text, inspection_answer_id uuid,   -- réponse d'inspection (Annexe C)
  PRIMARY KEY (qc_sample_id, element_code),
  CONSTRAINT ck_finding CHECK (applicable OR conforming IS NULL) );

-- AnnexeF_SoftFM#3
CREATE TABLE keystone.qc_reworks (
  qc_score_id uuid NOT NULL REFERENCES keystone.qc_scores(id),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  due_at timestamptz NOT NULL, completed_on_time boolean,
  PRIMARY KEY (qc_score_id, work_order_id) );

-- AnnexeF_SoftFM#4
CREATE TABLE keystone.pest_interventions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  location_id uuid NOT NULL REFERENCES keystone.locations(id),
  vendor_id uuid REFERENCES keystone.vendors(id), operator_person_id uuid NOT NULL REFERENCES keystone.persons(id),
  intervention_kind text NOT NULL CHECK (intervention_kind IN ('preventive','curative','phytosanitary')),
  target text NOT NULL,                                   -- espèce ou famille ciblée
  product text NOT NULL, reg_number text NOT NULL CHECK (char_length(reg_number) >= 3),   -- numéro d'homologation
  active_substance text, quantity numeric(12,3) NOT NULL CHECK (quantity > 0),
  unit text NOT NULL CHECK (unit IN ('g','kg','ml','l','unit')), method text NOT NULL,
  reentry_delay_hours smallint, notes text, at timestamptz NOT NULL,
  validated_by uuid, validated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid );

-- AnnexeF_SoftFM#4
CREATE INDEX ix_pest_site ON keystone.pest_interventions (tenant_id, site_id, at);

-- AnnexeU_Surete_Accueil#5
CREATE TABLE keystone.patrol_anomalies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, patrol_id uuid NOT NULL REFERENCES keystone.patrols(id) ON DELETE CASCADE,
  checkpoint_id uuid REFERENCES keystone.checkpoints(id), location_id uuid NOT NULL,
  description text NOT NULL, is_technical boolean NOT NULL DEFAULT false, photo_paths text[] NOT NULL DEFAULT '{}',
  security_log_id bigint NOT NULL,                  -- entrée de main courante créée (RG-RON-03)
  ticket_id uuid REFERENCES keystone.tickets(id),   -- demande proposée si technique (RG-RON-04)
  at timestamptz NOT NULL DEFAULT now(), created_by uuid );

-- AnnexeU_Surete_Accueil#11
CREATE VIEW keystone.v_security_kpis_daily WITH (security_invoker = true) AS   -- source de KPI-SUR-01 à 18
SELECT s.site_id, s.day,
       count(*) FILTER (WHERE l.severity = 'info')     AS events_info,
       count(*) FILTER (WHERE l.severity = 'minor')    AS events_minor,
       count(*) FILTER (WHERE l.severity = 'major')    AS events_major,
       count(*) FILTER (WHERE l.severity = 'critical') AS events_critical,
       (SELECT count(*) FROM keystone.patrols p WHERE p.site_id = s.site_id AND p.planned_end::date = s.day) AS patrols_planned,
       (SELECT count(*) FROM keystone.patrols p WHERE p.site_id = s.site_id AND p.planned_end::date = s.day AND p.status = 'completed') AS patrols_completed,
       (SELECT count(*) FROM keystone.patrol_anomalies a JOIN keystone.patrols p ON p.id = a.patrol_id
         WHERE p.site_id = s.site_id AND a.at::date = s.day) AS patrol_anomalies,
       (SELECT count(*) FROM keystone.access_events e WHERE e.site_id = s.site_id AND e.at::date = s.day AND e.direction = 'denied') AS access_denied,
       (SELECT count(*) FROM keystone.visits v WHERE v.site_id = s.site_id AND v.checked_in_at::date = s.day) AS visitors
  FROM (SELECT site_id, generate_series(current_date - 400, current_date, interval '1 day')::date AS day
          FROM keystone.security_posts GROUP BY site_id) s
  LEFT JOIN keystone.security_log l ON l.site_id = s.site_id AND l.at::date = s.day
 GROUP BY s.site_id, s.day;

-- AnnexeU_Surete_Accueil#11
CREATE VIEW keystone.v_client_security_kpis WITH (security_barrier) AS        -- reprise par l'Annexe CL.3
SELECT d.site_id, date_trunc('month', d.day)::date AS month,
       sum(events_info) AS events_info, sum(events_minor) AS events_minor,
       sum(events_major) AS events_major, sum(events_critical) AS events_critical,
       sum(patrols_planned) AS patrols_planned, sum(patrols_completed) AS patrols_completed,
       round(100.0 * sum(patrols_completed) / NULLIF(sum(patrols_planned), 0), 1) AS patrol_completion_rate,
       sum(patrol_anomalies) AS patrol_anomalies, sum(access_denied) AS access_denied,
       round(avg(visitors), 1) AS visitors_per_day_avg, max(visitors) AS visitors_per_day_max
  FROM keystone.v_security_kpis_daily d
 WHERE keystone.current_client() IS NOT NULL AND keystone.client_can_see_site(d.site_id)
   AND EXISTS (SELECT 1 FROM keystone.service_contracts c JOIN keystone.service_contract_scope cs ON cs.contract_id = c.id
                WHERE cs.site_id = d.site_id AND c.status = 'active' AND c.client_security_kpis_visible)   -- Annexe M
 GROUP BY d.site_id, date_trunc('month', d.day);

-- AnnexeI_IoT#6
CREATE TABLE keystone.iot_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  kind iot_alert_kind NOT NULL,
  device_id uuid REFERENCES keystone.iot_devices(id) ON DELETE SET NULL,
  gateway_id uuid REFERENCES keystone.iot_gateways(id) ON DELETE SET NULL,
  threshold_id uuid REFERENCES keystone.iot_thresholds(id) ON DELETE SET NULL,
  metric text, value numeric(18,6), reading_at timestamptz,
  severity risk_level NOT NULL,
  status iot_alert_status NOT NULL DEFAULT 'open',
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,
  escalation_level int NOT NULL DEFAULT 0, escalated_at timestamptz,
  acked_by uuid, acked_at timestamptz,
  resolved_by uuid, resolved_at timestamptz, auto_resolved boolean NOT NULL DEFAULT false,
  resolution_note text,
  meter_reading_id uuid REFERENCES keystone.meter_readings(id),   -- alerte meter_rejected : relevé en revue (B.8.3)
  at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_alert_source CHECK (device_id IS NOT NULL OR gateway_id IS NOT NULL)
);

-- AnnexeI_IoT#6
CREATE INDEX ix_alerts_open ON keystone.iot_alerts (tenant_id, site_id, severity) WHERE status <> 'resolved';

-- AnnexeI_IoT#6
CREATE UNIQUE INDEX uq_alert_offline_open ON keystone.iot_alerts (tenant_id, device_id)
  WHERE kind = 'device_offline' AND status <> 'resolved';

-- AnnexeEN_Energie#3
CREATE TABLE keystone.energy_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  plan_id uuid NOT NULL REFERENCES keystone.energy_action_plans(id) ON DELETE CASCADE,
  title text NOT NULL, description text,
  owner_id uuid REFERENCES keystone.persons(id),
  due_date date NOT NULL,
  est_saving_kwh numeric(18,4), est_cost bigint, currency char(3),
  verification_method text NOT NULL,                 -- ISO 50015 : période, variables, frontière de mesure
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,
  status energy_action_status NOT NULL DEFAULT 'planned',
  verified_saving_kwh numeric(18,4),                 -- gain mesuré après action, jamais déclaré
  verified_by uuid, verified_at timestamptz,
  verification_document_id uuid REFERENCES keystone.ged_documents(id),   -- pièce de mesure du gain (NC-12-05)
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_action_verify CHECK (status <> 'verified' OR (verified_saving_kwh IS NOT NULL AND verified_at IS NOT NULL)),
  CONSTRAINT ck_action_currency CHECK (est_cost IS NULL OR currency IS NOT NULL)
);

-- AnnexeEN_Energie#6
CREATE TABLE keystone.energy_anomalies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                 -- ANE-2026-000123
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  meter_id uuid REFERENCES keystone.asset_meters(id),
  use_id uuid REFERENCES keystone.energy_uses(id),
  kind text NOT NULL CHECK (kind IN ('overconsumption','tree_gap','night_base_load','off_hours','agent_proposal')),
  period_start date NOT NULL, period_end date NOT NULL,
  observed numeric(18,4) NOT NULL, expected numeric(18,4) NOT NULL,
  deviation_pct numeric(9,4) NOT NULL,
  is_normalized boolean NOT NULL,                    -- false : comparaison brute signalée (RG-ENE-04)
  extra_cost_month bigint, extra_cost_year_hypothesis bigint, currency char(3),   -- RG-ENE-05
  hypotheses jsonb NOT NULL DEFAULT '[]',
  origin text NOT NULL CHECK (origin IN ('rule','agent')),
  agent_run_id uuid,                                 -- Annexe H, si origin = 'agent'
  status energy_anomaly_status NOT NULL DEFAULT 'detected',
  due_at timestamptz NOT NULL,                       -- détection plus délai de traitement paramétré
  dismiss_reason text,
  action_kind text CHECK (action_kind IN ('work_order','bms_schedule_change','new_plan','energy_action')),
  work_order_id uuid REFERENCES keystone.work_orders(id),
  energy_action_id uuid REFERENCES keystone.energy_actions(id),
  measured_gain_kwh numeric(18,4),                   -- période suivante, jamais affirmé sans mesure
  decided_by uuid, decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ane_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_ane_dismiss CHECK (status <> 'dismissed' OR dismiss_reason IS NOT NULL),
  CONSTRAINT ck_ane_agent CHECK (origin <> 'agent' OR agent_run_id IS NOT NULL)
);

-- AnnexeEN_Energie#6
CREATE INDEX ix_ane_open ON keystone.energy_anomalies (tenant_id, site_id) WHERE status IN ('detected','in_analysis','confirmed');

-- AnnexeEN_Energie#6
CREATE TABLE keystone.leak_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  meter_id uuid NOT NULL REFERENCES keystone.asset_meters(id),
  first_night date NOT NULL, nights_count int NOT NULL CHECK (nights_count >= 1),
  night_flow_m3h numeric(12,4) NOT NULL, normal_night_flow_m3h numeric(12,4) NOT NULL,
  est_volume_m3 numeric(14,3) NOT NULL,              -- estimation (RG-ENE-08)
  status leak_alert_status NOT NULL DEFAULT 'open',
  dismiss_reason text,
  work_order_id uuid REFERENCES keystone.work_orders(id),
  decided_by uuid, decided_at timestamptz, resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_leak_dismiss CHECK (status <> 'dismissed' OR dismiss_reason IS NOT NULL)
);

-- AnnexeEN_Energie#6
CREATE UNIQUE INDEX uq_leak_open ON keystone.leak_alerts (tenant_id, meter_id) WHERE status IN ('open','confirmed');

-- AnnexeEN_Energie#7
CREATE TABLE keystone.energy_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  billing_meter_id uuid NOT NULL REFERENCES keystone.asset_meters(id),   -- is_billing_meter = true (Annexe B)
  invoice_ref text NOT NULL,
  period_start date NOT NULL, period_end date NOT NULL,
  billed_quantity numeric(18,4) NOT NULL CHECK (billed_quantity >= 0),
  billed_amount_ht bigint NOT NULL CHECK (billed_amount_ht >= 0),
  billed_vat bigint NOT NULL DEFAULT 0 CHECK (billed_vat >= 0),
  billed_amount bigint NOT NULL,                     -- TTC
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  metered_quantity numeric(18,4),                    -- somme energy_daily du compteur ; NULL si jours non mesurés
  computed_amount bigint,                            -- TTC recalculé au tarif en vigueur
  quantity_gap_pct numeric(9,4), amount_gap_pct numeric(9,4),
  status energy_invoice_status NOT NULL DEFAULT 'received',
  gap_justification text,
  rejection_reason text,
  expense_id uuid REFERENCES keystone.expenses(id),  -- dépense créée à l'approbation (Annexe E)
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),   -- pièce obligatoire (Lot 12 §38, question 5 ; NC-12-04)
  approved_by uuid, approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_energy_invoice UNIQUE (tenant_id, vendor_id, invoice_ref),
  CONSTRAINT ck_einv_period CHECK (period_end > period_start),
  CONSTRAINT ck_einv_ttc CHECK (billed_amount = billed_amount_ht + billed_vat),
  CONSTRAINT ck_einv_reject CHECK (status <> 'rejected' OR rejection_reason IS NOT NULL),
  CONSTRAINT ck_einv_approved CHECK (status <> 'approved' OR expense_id IS NOT NULL)
);

-- AnnexeN_Satisfaction_Cout#3
CREATE TABLE keystone.survey_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  survey_id uuid NOT NULL REFERENCES keystone.surveys(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  ticket_id uuid REFERENCES keystone.tickets(id),   -- CSAT
  recipient_user_id uuid,                           -- compte du portail occupants ou client
  recipient_email text,                             -- déclarant sans compte qui a donné un email de suivi
  channel survey_channel NOT NULL,
  token_hash char(64) NOT NULL,                     -- SHA-256 du jeton du lien signé
  sent_at timestamptz, expires_at timestamptz NOT NULL,
  responded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_inv_recipient CHECK (recipient_user_id IS NOT NULL OR recipient_email IS NOT NULL),
  CONSTRAINT uq_inv_token UNIQUE (token_hash)
);

-- AnnexeN_Satisfaction_Cout#3
CREATE UNIQUE INDEX uq_inv_ticket ON keystone.survey_invitations (tenant_id, ticket_id) WHERE ticket_id IS NOT NULL;

-- AnnexeN_Satisfaction_Cout#3
CREATE TABLE keystone.survey_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  survey_id uuid NOT NULL REFERENCES keystone.surveys(id) ON DELETE RESTRICT,
  invitation_id uuid REFERENCES keystone.survey_invitations(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  ticket_id uuid REFERENCES keystone.tickets(id),
  occupant_org_id uuid,                             -- organisation occupante (Annexe S), si connue
  respondent_user_id uuid,                          -- NULL si réponse par lien email
  score int NOT NULL,                               -- réponse à la question principale
  answers jsonb NOT NULL DEFAULT '{}',              -- {question_id: valeur}
  comment text,
  comment_masked boolean NOT NULL DEFAULT false,    -- RG-SAT-07 : données personnelles ou de santé détectées
  submitted_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_response_invitation UNIQUE (invitation_id)
);

-- AnnexeN_Satisfaction_Cout#3
CREATE UNIQUE INDEX uq_response_ticket ON keystone.survey_responses (tenant_id, ticket_id) WHERE ticket_id IS NOT NULL;

-- AnnexeN_Satisfaction_Cout#3
-- RG-SAT-01
CREATE INDEX ix_survey_resp ON keystone.survey_responses (tenant_id, survey_id, submitted_at);

-- AnnexeN_Satisfaction_Cout#3
CREATE INDEX ix_survey_resp_site ON keystone.survey_responses (tenant_id, site_id, submitted_at);

-- AnnexeN_Satisfaction_Cout#3
CREATE TABLE keystone.survey_followups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  response_id uuid NOT NULL REFERENCES keystone.survey_responses(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  status followup_status NOT NULL DEFAULT 'to_handle',
  assigned_to uuid,                                 -- responsable qualité par défaut du site
  due_at timestamptz NOT NULL,                      -- création plus 3 jours ouvrés (A08), paramètre
  action_kind text CHECK (action_kind IN ('contact','work_order','rework_order','capa','none')),
  linked_table text, linked_id uuid,
  resolution_note text,
  resolved_by uuid, resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_followup UNIQUE (tenant_id, response_id),
  CONSTRAINT ck_followup_done CHECK (status <> 'handled' OR (action_kind IS NOT NULL AND resolution_note IS NOT NULL)),
  CONSTRAINT ck_followup_link CHECK (action_kind NOT IN ('work_order','rework_order','capa') OR linked_id IS NOT NULL)
);

-- AnnexeH_PROPH3T_Agents#6
CREATE TABLE keystone.predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  asset_id uuid NOT NULL REFERENCES keystone.assets(id),
  kind text NOT NULL CHECK (kind IN ('failure','drift','rul')),
  horizon_days int CHECK (horizon_days > 0),
  probability numeric(5,4) CHECK (probability BETWEEN 0 AND 1),
  rul_estimate interval,                           -- durée de vie résiduelle (v3 §6.13)
  confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
  recommended_action text NOT NULL,
  explanation jsonb NOT NULL, sources jsonb NOT NULL DEFAULT '[]',
  model_id uuid NOT NULL REFERENCES keystone.ai_models(id),
  agent_run_id uuid NOT NULL REFERENCES keystone.agent_runs(id),
  status prediction_status NOT NULL DEFAULT 'proposed',
  dismiss_reason text,
  work_order_id uuid REFERENCES keystone.work_orders(id),
  outcome prediction_outcome, outcome_at timestamptz,   -- constat à l'intervention (KPI-IA-01)
  decided_by uuid, decided_at timestamptz, expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_pred_kind CHECK (kind <> 'rul' OR rul_estimate IS NOT NULL),
  CONSTRAINT ck_pred_prob CHECK (kind = 'rul' OR probability IS NOT NULL),
  CONSTRAINT ck_pred_dismiss CHECK (status <> 'dismissed' OR dismiss_reason IS NOT NULL),
  CONSTRAINT ck_pred_wo CHECK (status <> 'accepted' OR work_order_id IS NOT NULL)
);

-- AnnexeH_PROPH3T_Agents#6
CREATE INDEX ix_pred_open ON keystone.predictions (tenant_id, site_id) WHERE status = 'proposed';

-- AnnexeH_PROPH3T_Agents#6
CREATE TABLE keystone.anomalies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  domain text NOT NULL CHECK (domain IN ('iot','energy','maintenance')),
  asset_id uuid REFERENCES keystone.assets(id),
  device_id uuid REFERENCES keystone.iot_devices(id),
  metric text,
  detected_at timestamptz NOT NULL,
  severity risk_level NOT NULL,
  anomaly_score numeric(6,4),                      -- sortie du modèle statistique, pas un indicateur
  horizon_days int,
  explanation jsonb NOT NULL,
  model_id uuid NOT NULL REFERENCES keystone.ai_models(id),
  agent_run_id uuid NOT NULL REFERENCES keystone.agent_runs(id),
  energy_anomaly_id uuid REFERENCES keystone.energy_anomalies(id),   -- domain energy : proposition en Annexe EN
  status anomaly_status NOT NULL DEFAULT 'open',
  handled_without_failure boolean,                 -- KPI-IA-02, renseigné à l'échéance de l'horizon
  resolved_by uuid, resolved_at timestamptz, resolution_note text,
  CONSTRAINT ck_ano_energy CHECK (domain <> 'energy' OR energy_anomaly_id IS NOT NULL),
  CONSTRAINT ck_ano_fp CHECK (status <> 'false_positive' OR resolution_note IS NOT NULL)
);

-- correctif_post
-- C14 (avec la substitution S02) : DA rattachée à l'OT (D31, Annexe B). work_orders et purchase_requests se référencent
-- mutuellement : la clé de work_orders est posée après la création des deux tables, sans changer sa règle [Confirmé].
ALTER TABLE keystone.work_orders
  ADD CONSTRAINT fk_wo_purchase_request FOREIGN KEY (purchase_request_id) REFERENCES keystone.purchase_requests (id) ON DELETE RESTRICT;

-- AnnexeA_Socle_Partie2#6
CREATE TABLE keystone.asset_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  from_status asset_status,
  to_status asset_status NOT NULL,
  source asset_status_source NOT NULL,
  reason text,
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE RESTRICT,
  regulatory_control_id uuid REFERENCES keystone.regulatory_controls(id) ON DELETE RESTRICT,
  changed_by uuid,
  changed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_status_reason CHECK (to_status = 'operational' OR source <> 'manual' OR reason IS NOT NULL)
);

-- AnnexeA_Socle_Partie2#6
CREATE INDEX ix_asset_status_history ON keystone.asset_status_history (tenant_id, asset_id, changed_at DESC);

-- AnnexeA_Socle_Partie3#7
CREATE TABLE keystone.asset_observations (            -- ajout seul
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE RESTRICT,
  component_id uuid REFERENCES keystone.asset_components(id) ON DELETE SET NULL,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),            -- recopié de l'actif
  kind keystone.asset_observation_kind NOT NULL,
  body text NOT NULL CHECK (length(trim(body)) BETWEEN 5 AND 2000),
  condition_rating smallint CHECK (condition_rating BETWEEN 1 AND 5), -- état proposé (A64), n'écrase pas assets
  photo_document_ids uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(photo_document_ids) <= 6),
  observed_at timestamptz NOT NULL,                     -- heure de l'appareil (A94)
  received_at timestamptz NOT NULL DEFAULT now(),
  clock_review boolean GENERATED ALWAYS AS (received_at - observed_at > interval '24 hours') STORED,
  author_person_id uuid NOT NULL REFERENCES keystone.persons(id),
  source text NOT NULL CHECK (source IN ('console','field_app')),
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,
  capa_action_id uuid,                                  -- capa_actions, clé posée par la migration C
  withdrawn_at timestamptz, withdrawn_by uuid, withdrawn_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), created_by uuid,
  CONSTRAINT ck_obs_time CHECK (observed_at <= received_at + interval '5 minutes'),
  CONSTRAINT ck_obs_withdrawn CHECK (withdrawn_at IS NULL OR length(trim(withdrawn_reason)) >= 10)
);

-- AnnexeA_Socle_Partie3#7
CREATE INDEX ix_obs_asset ON keystone.asset_observations (tenant_id, asset_id, observed_at DESC);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_wo_title_trgm       ON keystone.work_orders  USING gin (title gin_trgm_ops);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_wo_ref_prefix       ON keystone.work_orders  (tenant_id, ref text_pattern_ops);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_tickets_title_trgm  ON keystone.tickets      USING gin (title gin_trgm_ops);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_tickets_ref_prefix  ON keystone.tickets      (tenant_id, ref text_pattern_ops);

-- AnnexeA_Socle_Partie4#3
ALTER TABLE keystone.assets
  ADD CONSTRAINT fk_assets_purchase_order FOREIGN KEY (purchase_order_id)
      REFERENCES keystone.purchase_orders(id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_assets_maintenance_team FOREIGN KEY (maintenance_team_id)
      REFERENCES keystone.teams(id) ON DELETE SET NULL;

-- AnnexeA_Socle_Partie4#3
CREATE INDEX ix_obs_capa             ON keystone.asset_observations (tenant_id, capa_action_id) WHERE capa_action_id IS NOT NULL;

-- AnnexeS_Space_Management_Partie2#1
CREATE TABLE keystone.space_occupancies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, space_unit_id uuid NOT NULL REFERENCES atlas_core.spaces(id) ON DELETE RESTRICT,
  occupant_kind text NOT NULL CHECK (occupant_kind IN ('internal','tenant','vacant')),
  occupant_org_id uuid REFERENCES keystone.occupant_organizations(id) ON DELETE RESTRICT,   -- Annexe D
  lease_ref text,                                    -- lot ou bail Atlas Patrimoine, lecture
  status text NOT NULL CHECK (status IN ('occupied','vacant','reserved','works')),
  valid_from date NOT NULL, valid_to date,
  work_order_id uuid REFERENCES keystone.work_orders(id), fitout_request_id uuid,   -- statut works
  reason text, source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','patrimoine','move','atelier')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_occ_org CHECK ((status = 'occupied') = (occupant_org_id IS NOT NULL)),
  CONSTRAINT ck_occ_dates CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT ck_occ_reserved CHECK (status NOT IN ('reserved','works') OR valid_to IS NOT NULL),
  CONSTRAINT ex_occ_overlap EXCLUDE USING gist (space_unit_id WITH =,
     daterange(valid_from, coalesce(valid_to, 'infinity'::date), '[]') WITH &&) WHERE (deleted_at IS NULL) );

-- AnnexeS_Space_Management_Partie2#1
CREATE INDEX ix_occ_org ON keystone.space_occupancies (tenant_id, occupant_org_id, valid_from);

-- AnnexeS_Space_Management_Partie2#2
-- aucune politique d'écriture : place_asset et unplace_asset seules ; triggers tg_set_updated_at, tg_audit

CREATE TABLE keystone.presence (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL, site_id uuid NOT NULL,
  person_id uuid NOT NULL REFERENCES keystone.persons(id), vendor_id uuid REFERENCES keystone.vendors(id),
  plan_id uuid REFERENCES keystone.space_plans(id), location_id uuid REFERENCES keystone.locations(id),
  space_unit_id uuid, x numeric(8,5), y numeric(8,5), accuracy_m numeric(8,2),
  source presence_source NOT NULL,                    -- gps, scan, beacon, work_order, manual
  status text NOT NULL CHECK (status IN ('on_duty','on_wo','break')),
  work_order_id uuid REFERENCES keystone.work_orders(id), asset_id uuid,
  at timestamptz NOT NULL DEFAULT now() );

-- AnnexeS_Space_Management_Partie2#2
CREATE INDEX ix_presence_live ON keystone.presence (tenant_id, site_id, at DESC);

-- AnnexeS_Space_Management_Partie2#2
CREATE INDEX ix_presence_person ON keystone.presence (tenant_id, person_id, at DESC);

-- AnnexeS_Space_Management_Partie2#6
CREATE VIEW keystone.v_dock_bookings WITH (security_invoker = true) AS
SELECT b.id, b.tenant_id, b.site_id, b.ref, b.dock_id, d.dock_code, d.max_vehicle, b.slot, b.status,
       b.occupant_org_id, o.name AS occupant_org_name, b.vendor_id, v.name AS vendor_name,
       b.booked_by, b.carrier_name, b.vehicle_type, b.goods_type, b.approved_by,
       b.checked_in_at, b.checked_out_at, b.cancelled_at, b.cancelled_by, b.cancel_reason,
       sn.id AS shipment_notice_id, sn.ref AS shipment_notice_ref, po.ref AS purchase_order_ref
  FROM keystone.loading_dock_bookings b
  JOIN keystone.loading_docks d ON d.id = b.dock_id
  LEFT JOIN keystone.occupant_organizations o ON o.id = b.occupant_org_id
  LEFT JOIN keystone.vendors v ON v.id = b.vendor_id
  LEFT JOIN keystone.shipment_notices sn ON sn.loading_dock_booking_id = b.id
  LEFT JOIN keystone.purchase_orders po ON po.id = sn.po_id;

-- AnnexeS_Space_Management_Partie2#7
CREATE TABLE keystone.move_work_orders (
  move_id uuid NOT NULL REFERENCES keystone.move_requests(id) ON DELETE CASCADE,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id), is_blocking boolean NOT NULL,
  PRIMARY KEY (move_id, work_order_id) );

-- AnnexeP_Prestataires_Mobile#16
CREATE TABLE keystone.contractor_evaluations (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  kind keystone.evaluation_kind NOT NULL DEFAULT 'intervention',
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  assignee_person_id uuid REFERENCES keystone.persons(id),
  punctuality_minutes integer,                           -- scan de début moins début planifié, calculé
  quality_score smallint NOT NULL CHECK (quality_score BETWEEN 1 AND 5),
  cleanliness_score smallint NOT NULL CHECK (cleanliness_score BETWEEN 1 AND 5),
  report_score smallint NOT NULL CHECK (report_score BETWEEN 1 AND 5),
  safety_compliant boolean NOT NULL,
  site_rules_compliant boolean NOT NULL,
  justification text,
  comment text CHECK (char_length(comment) <= 500),
  photo_document_ids uuid[] NOT NULL DEFAULT '{}' CHECK (cardinality(photo_document_ids) <= 3),
  contractor_reply text CHECK (char_length(contractor_reply) <= 1000),
  contractor_reply_at timestamptz,
  evaluator_id uuid NOT NULL,
  corrected_by uuid, corrected_at timestamptz, correction_reason text,   -- EV-EVA-01
  CONSTRAINT uq_eval_wo UNIQUE (tenant_id, work_order_id),
  CONSTRAINT ck_eval_correction CHECK ((corrected_at IS NULL) = (correction_reason IS NULL)),
  CONSTRAINT ck_eval_justif CHECK (
    (LEAST(quality_score, cleanliness_score, report_score) > 2 AND safety_compliant) OR justification IS NOT NULL)
);

-- AnnexeP_Prestataires_Mobile#18
CREATE TABLE keystone.contractor_penalties (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  ref text NOT NULL,                                     -- PEN-2026-000031
  vendor_id uuid NOT NULL REFERENCES keystone.vendors(id),
  maintenance_contract_id uuid NOT NULL REFERENCES keystone.maintenance_contracts(id),
  period date NOT NULL CHECK (date_trunc('month', period) = period),
  breaches jsonb NOT NULL,                               -- [{ "work_order_id", "priority", "due_at", "done_at", "delay_minutes", "rule_code", "amount" }]
  gross_amount bigint NOT NULL CHECK (gross_amount >= 0),
  cap_applied boolean NOT NULL DEFAULT false,
  amount bigint NOT NULL CHECK (amount >= 0),            -- après franchise et plafond
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  status keystone.penalty_status NOT NULL DEFAULT 'calculated',
  notified_by uuid, notified_at timestamptz, contest_deadline date,
  contest_reason text, contest_document_ids uuid[] NOT NULL DEFAULT '{}',
  contest_category text CHECK (contest_category IN ('force_majeure','site_caused','calculation_error','other')),  -- EV-PF-02
  decided_by uuid, decided_at timestamptz, decision_reason text,
  imputed_expense_id uuid REFERENCES keystone.expenses(id),
  CONSTRAINT uq_penalty_ref UNIQUE (tenant_id, ref),
  CONSTRAINT uq_penalty_period UNIQUE (tenant_id, maintenance_contract_id, period),
  CONSTRAINT ck_penalty_contest CHECK (status <> 'contested' OR (contest_category IS NOT NULL AND contest_reason IS NOT NULL))
);

-- AnnexeP_Prestataires_Mobile#21
CREATE FUNCTION keystone.penalty_transition(p_penalty uuid, p_to keystone.penalty_status, p_reason text DEFAULT NULL)
RETURNS keystone.contractor_penalties LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE p keystone.contractor_penalties;
BEGIN
  IF NOT keystone.has_permission('vendor.penalty') THEN PERFORM keystone.raise_error('PERMISSION_DENIED', jsonb_build_object('permission','vendor.penalty')); END IF;
  SELECT * INTO p FROM keystone.contractor_penalties
   WHERE id = p_penalty AND tenant_id = keystone.current_tenant() AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN PERFORM keystone.raise_error('NOT_FOUND', jsonb_build_object('id', p_penalty)); END IF;
  IF NOT ((p.status = 'calculated' AND p_to = 'notified')
       OR (p.status IN ('notified','contested') AND p_to IN ('validated','abandoned'))) THEN
    PERFORM keystone.raise_error('INVALID_TRANSITION', jsonb_build_object('from', p.status, 'to', p_to)); END IF;
  IF p_to IN ('validated','abandoned') THEN
    IF char_length(btrim(coalesce(p_reason,''))) < 10 THEN PERFORM keystone.raise_error('REASON_REQUIRED'); END IF;
    IF p.notified_by = auth.uid() THEN PERFORM keystone.raise_error('SEGREGATION_OF_DUTIES', jsonb_build_object('role','notified_by')); END IF;
    UPDATE keystone.contractor_penalties SET status = p_to, decided_by = auth.uid(), decided_at = now(),
           decision_reason = p_reason WHERE id = p.id RETURNING * INTO p;
  ELSE
    UPDATE keystone.contractor_penalties SET status = 'notified', notified_by = auth.uid(), notified_at = now(),
           contest_deadline = current_date + keystone.setting_int('vendor.penalty_contest_days', 15)
     WHERE id = p.id RETURNING * INTO p;
  END IF;
  -- effets : audit_trail ; notified : EML-PRS-008 aux rôles admin et accountant du prestataire ;
  -- validated, abandoned : notification penalty.decided au prestataire
  RETURN p;
END $$;

-- AnnexeK_Formation_Environnement#9
CREATE TABLE keystone.waste_records (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  location_id uuid REFERENCES keystone.locations(id),
  stream_code text NOT NULL,
  is_hazardous boolean NOT NULL,            -- copié de la filière à la saisie, figé
  quantity numeric(14,3) NOT NULL CHECK (quantity > 0),
  unit text NOT NULL CHECK (unit IN ('kg','t','m3','l','unit')),
  quantity_kg numeric(14,3),                -- converti pour les indicateurs (densité de la filière si volume)
  recorded_at timestamptz NOT NULL,         -- date et heure de l'enlèvement ou de la pesée
  hauler_vendor_id uuid REFERENCES keystone.vendors(id),
  tracking_slip_ref text,                   -- numéro du BSD, copié de waste_tracking_slips.slip_no
  outcome keystone.waste_outcome,
  recovered boolean GENERATED ALWAYS AS (outcome IN ('recycling','energy_recovery','composting')) STORED,
  status keystone.waste_record_status NOT NULL DEFAULT 'draft',
  work_order_id uuid REFERENCES keystone.work_orders(id),           -- passage Soft FM (OT kind service, D11)
  cost_amount bigint CHECK (cost_amount >= 0),                       -- coût d'enlèvement, Money.ts (Lot 15 E15)
  revenue_amount bigint CHECK (revenue_amount >= 0),                 -- recette de valorisation
  currency char(3) CHECK (currency IN ('XOF','XAF')),
  CONSTRAINT ck_waste_money CHECK ((cost_amount IS NULL AND revenue_amount IS NULL) OR currency IS NOT NULL),
  validated_at timestamptz, validated_by uuid, cancel_reason text,
  CONSTRAINT fk_waste_stream FOREIGN KEY (tenant_id, stream_code) REFERENCES keystone.waste_streams (tenant_id, code),
  CONSTRAINT ck_waste_bsd CHECK (status <> 'validated' OR NOT is_hazardous OR tracking_slip_ref IS NOT NULL),
  CONSTRAINT ck_waste_valid CHECK (status <> 'validated' OR (validated_at IS NOT NULL AND outcome IS NOT NULL))
);

-- AnnexeK_Formation_Environnement#9
CREATE INDEX ix_waste_period ON keystone.waste_records (tenant_id, site_id, recorded_at) WHERE status = 'validated';

-- AnnexeK_Formation_Environnement#9
CREATE TABLE keystone.waste_tracking_slips (             -- bordereau de suivi des déchets (BSD)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  waste_id uuid NOT NULL REFERENCES keystone.waste_records(id) ON DELETE RESTRICT,
  slip_no text NOT NULL,
  carrier text NOT NULL, carrier_vendor_id uuid REFERENCES keystone.vendors(id),
  destination text NOT NULL,
  issued_at timestamptz NOT NULL, received_at timestamptz, treated_at timestamptz,
  status keystone.bsd_status NOT NULL DEFAULT 'issued',
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),
  discrepancy_note text,
  UNIQUE (tenant_id, slip_no)
);

-- AnnexeC_HSSE#4
CREATE TABLE keystone.hsse_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id) ON DELETE RESTRICT,
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                   -- EVT-2026-000123
  type keystone.hsse_event_type NOT NULL,
  origin keystone.record_origin NOT NULL DEFAULT 'planned',
  observation_kind keystone.observation_kind,          -- carte d'observation (HOC)
  hazard_category keystone.hazard_category,
  occurred_at timestamptz NOT NULL,
  reported_at timestamptz NOT NULL DEFAULT now(),
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  asset_id uuid REFERENCES keystone.assets(id) ON DELETE SET NULL,
  activity keystone.event_activity,
  conditions text[] NOT NULL DEFAULT '{}'
    CHECK (conditions <@ ARRAY['night','rain','poor_lighting','slippery_floor','crowd']),
  vendor_id uuid REFERENCES keystone.vendors(id) ON DELETE SET NULL,      -- prestataire impliqué (D13)
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE SET NULL,
  permit_id uuid REFERENCES keystone.work_permits(id) ON DELETE SET NULL,
  security_log_id bigint REFERENCES keystone.security_log(id) ON DELETE SET NULL,   -- main courante (Annexe U)
  title text NOT NULL, description text NOT NULL CHECK (char_length(description) >= 10),
  dialogue_held boolean,                               -- acte dangereux : dialogue de sécurité tenu
  severity_actual keystone.event_severity,
  severity_potential keystone.event_severity,
  probability int CHECK (probability BETWEEN 1 AND 5),
  risk_score int CHECK (risk_score BETWEEN 1 AND 25),   -- dérivé par trigger, jamais saisi
  risk_band keystone.risk_level,                       -- dérivé par trigger
  is_strong_signal boolean NOT NULL DEFAULT false,     -- dérivé : near_miss de gravité potentielle au moins major
  status keystone.event_status NOT NULL DEFAULT 'reported',
  immediate_actions text,                              -- texte libre des mesures prises (« Autre »)
  immediate_measures text[] NOT NULL DEFAULT '{}'       -- cases du flash et de la section G (C.27.1)
    CHECK (immediate_measures <@ ARRAY['emergency_services_called','area_secured','energy_isolated','spill_contained','other']),
  emergency_services_called boolean GENERATED ALWAYS AS ('emergency_services_called' = ANY (immediate_measures)) STORED,
  is_anonymous boolean NOT NULL DEFAULT false,
  reporter_id uuid REFERENCES keystone.persons(id),    -- NULL si anonyme
  injury_count int NOT NULL DEFAULT 0 CHECK (injury_count >= 0),       -- agrégat sans identité
  lost_time_days int NOT NULL DEFAULT 0 CHECK (lost_time_days >= 0),   -- agrégat sans identité
  is_recordable boolean NOT NULL DEFAULT false,
  victim_population keystone.worked_population,        -- dérivée des victimes (C.4.2), base des taux par population
  damage_amount bigint CHECK (damage_amount >= 0),     -- Money.ts
  currency char(3) CHECK (currency IN ('XOF','XAF')),
  downtime_minutes int CHECK (downtime_minutes >= 0),
  downtime_scope text,
  env_details jsonb,                                   -- env_spill : substance, quantity, unit, medium, contained, waste_disposal
  report_due timestamptz,                              -- rapport complet attendu (trigger)
  investigation_due date,                              -- échéance d'investigation (trigger)
  rejection_reason text, closure_reason text,
  triaged_at timestamptz, closed_at timestamptz, closed_by uuid,
  CONSTRAINT uq_evt_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_evt_anon CHECK (is_anonymous = false OR reporter_id IS NULL),
  CONSTRAINT ck_evt_dates CHECK (occurred_at <= reported_at),
  CONSTRAINT ck_evt_damage_cur CHECK (damage_amount IS NULL OR currency IS NOT NULL),
  CONSTRAINT ck_evt_hoc CHECK (origin <> 'hoc' OR observation_kind IS NOT NULL),
  CONSTRAINT ck_evt_gp CHECK ((type = 'good_practice') = (observation_kind IS NOT DISTINCT FROM 'good_practice')),
  CONSTRAINT ck_evt_env CHECK (type <> 'env_spill' OR status = 'reported' OR env_details IS NOT NULL)
);

-- AnnexeC_HSSE#4
CREATE INDEX ix_evt_status   ON keystone.hsse_events (tenant_id, site_id, status) WHERE deleted_at IS NULL;

-- AnnexeC_HSSE#4
CREATE INDEX ix_evt_occurred ON keystone.hsse_events (tenant_id, site_id, occurred_at DESC);

-- AnnexeC_HSSE#4
CREATE INDEX ix_evt_open     ON keystone.hsse_events (tenant_id, risk_score DESC) WHERE status NOT IN ('closed','rejected');

-- AnnexeC_HSSE#4
CREATE INDEX ix_evt_vendor   ON keystone.hsse_events (tenant_id, vendor_id) WHERE vendor_id IS NOT NULL;

-- AnnexeC_HSSE#4
CREATE INDEX ix_evt_wo       ON keystone.hsse_events (tenant_id, work_order_id) WHERE work_order_id IS NOT NULL;

-- AnnexeC_HSSE#5
CREATE TABLE keystone.event_persons (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id) ON DELETE CASCADE,
  person_id uuid REFERENCES keystone.persons(id),
  external_identity jsonb,                 -- visiteur ou public : {"full_name","phone","kind":"visitor|public"}
  role keystone.event_person_role NOT NULL,
  CONSTRAINT ck_evp_identity CHECK (person_id IS NOT NULL OR external_identity IS NOT NULL)
);

-- AnnexeC_HSSE#5
CREATE INDEX ix_evp_event ON keystone.event_persons (tenant_id, event_id);

-- AnnexeC_HSSE#5
CREATE TABLE keystone.event_attachments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES keystone.ged_documents(id),               -- GED (Annexe G), stockage privé, propriétaire = compte de service si anonyme
  kind keystone.attachment_kind NOT NULL,
  exif_stripped boolean NOT NULL DEFAULT false
);

-- AnnexeC_HSSE#5
CREATE TABLE keystone.event_declarations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id) ON DELETE CASCADE,
  recipient keystone.declaration_recipient NOT NULL,
  recipient_name text,
  due_at timestamptz NOT NULL,             -- reported_at + délai du pack pays (défaut 48 h accident du travail, à confirmer)
  sent_at timestamptz, reference text, proof_document_id uuid REFERENCES keystone.ged_documents(id),
  CONSTRAINT ck_decl_proof CHECK (sent_at IS NULL OR proof_document_id IS NOT NULL)
);

-- AnnexeC_HSSE#5
CREATE INDEX ix_decl_due ON keystone.event_declarations (tenant_id, due_at) WHERE sent_at IS NULL;

-- AnnexeC_HSSE#6
CREATE TABLE keystone.event_person_health (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_person_id uuid NOT NULL UNIQUE REFERENCES keystone.event_persons(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id) ON DELETE CASCADE,
  injury_nature_enc bytea,                 -- chiffré : contusion, plaie, fracture, brûlure, entorse, intoxication, autre
  body_part_enc bytea,                     -- chiffré : siège de la lésion
  care_level_enc bytea,                    -- chiffré : valeur de keystone.care_level
  certificate_document_ids uuid[] NOT NULL DEFAULT '{}',   -- bucket privé « hsse-health », référence logique (C.0.1)
  lost_days int NOT NULL DEFAULT 0 CHECK (lost_days >= 0),
  retain_until date NOT NULL,              -- created_at + 40 ans (A56), puis anonymisation
  key_version int NOT NULL DEFAULT 1
);

-- AnnexeC_HSSE#6
ALTER TABLE keystone.event_person_health ENABLE ROW LEVEL SECURITY;

-- AnnexeC_HSSE#6
CREATE POLICY eph_select ON keystone.event_person_health FOR SELECT
  USING (tenant_id = keystone.current_tenant() AND keystone.has_permission('event.medical_read'));

-- AnnexeC_HSSE#6
-- Aucune politique INSERT, UPDATE, DELETE : écriture par RPC seulement.
REVOKE ALL ON keystone.event_person_health FROM proph3t_reader, anon;

-- AnnexeC_HSSE#8
CREATE POLICY evt_select ON keystone.hsse_events FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL AND keystone.site_in_scope(site_id)
  AND (keystone.has_permission('event.read') OR reporter_id = keystone.current_person_id()));

-- AnnexeC_HSSE#8
-- INSERT, UPDATE : aucune politique pour authenticated ; écriture par les RPC C.1.6 seulement.
-- DELETE : aucune politique ; un événement erroné passe 'rejected'.

-- Portail fournisseurs : ses événements, sans santé, sans déclarant, sans personnes
CREATE VIEW keystone.vendor_hsse_events_v WITH (security_barrier) AS
  SELECT id, ref, site_id, type, occurred_at, severity_actual, severity_potential, status
  FROM keystone.hsse_events
  WHERE tenant_id = keystone.current_tenant() AND vendor_id = keystone.current_vendor() AND deleted_at IS NULL;

-- AnnexeC_HSSE#8
-- Critère Sécurité du score prestataire (Annexe P) : HOC et bonnes pratiques exclues
CREATE VIEW keystone.vendor_safety_events_v AS
  SELECT tenant_id, vendor_id, id AS event_id, occurred_at, keystone.severity_gravity(severity_actual) AS gravity
  FROM keystone.hsse_events
  WHERE vendor_id IS NOT NULL AND origin <> 'hoc' AND type <> 'good_practice'
    AND status <> 'rejected' AND deleted_at IS NULL;

-- AnnexeC_HSSE#10
CREATE FUNCTION keystone.investigation_required(e keystone.hsse_events) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(keystone.severity_gravity(e.severity_potential), 0) >= 3 OR e.type IN ('accident','env_spill') $$;

-- AnnexeC_HSSE#10
CREATE OR REPLACE FUNCTION keystone.event_transition(p_event uuid, p_to keystone.event_status, p_meta jsonb DEFAULT '{}')
RETURNS keystone.hsse_events LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE e keystone.hsse_events; v_req boolean; v_reason text := nullif(btrim(p_meta->>'reason'), '');
BEGIN
  SELECT * INTO e FROM keystone.hsse_events
   WHERE id = p_event AND tenant_id = keystone.current_tenant() AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND OR NOT keystone.site_in_scope(e.site_id) THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  v_req := keystone.investigation_required(e);

  IF e.status = 'reported' AND p_to = 'triage' THEN
    PERFORM keystone.assert_permission('event.investigate');
    e.triaged_at := now();

  ELSIF e.status = 'triage' AND p_to = 'under_investigation' THEN
    PERFORM keystone.assert_permission('event.investigate');
    IF NOT EXISTS (SELECT 1 FROM keystone.investigations WHERE event_id = e.id AND deleted_at IS NULL)
      THEN PERFORM keystone.raise_error('INVESTIGATION_REQUIRED'); END IF;

  ELSIF e.status = 'triage' AND p_to = 'rejected' THEN
    PERFORM keystone.assert_permission('event.close');
    IF v_reason IS NULL THEN PERFORM keystone.raise_error('REASON_REQUIRED'); END IF;
    e.rejection_reason := v_reason;

  ELSIF e.status = 'triage' AND p_to = 'capa_defined' THEN
    PERFORM keystone.assert_permission('event.investigate');
    IF v_req THEN PERFORM keystone.raise_error('INVESTIGATION_REQUIRED'); END IF;
    IF e.work_order_id IS NULL AND NOT EXISTS (SELECT 1 FROM keystone.capa_actions
         WHERE event_id = e.id AND status <> 'cancelled' AND deleted_at IS NULL)
      THEN PERFORM keystone.raise_error('ACTION_REQUIRED'); END IF;

  ELSIF e.status = 'triage' AND p_to = 'closed' THEN
    PERFORM keystone.assert_permission('event.close');
    IF v_req THEN PERFORM keystone.raise_error('INVESTIGATION_REQUIRED'); END IF;
    IF e.type NOT IN ('good_practice','dangerous_situation') THEN PERFORM keystone.raise_error('INVALID_TRANSITION'); END IF;
    IF v_reason IS NULL THEN PERFORM keystone.raise_error('REASON_REQUIRED'); END IF;
    e.closure_reason := v_reason;

  ELSIF e.status = 'under_investigation' AND p_to = 'capa_defined' THEN
    PERFORM keystone.assert_permission('event.investigate');
    IF EXISTS (SELECT 1 FROM keystone.investigations WHERE event_id = e.id AND deleted_at IS NULL AND completed_at IS NULL)
      THEN PERFORM keystone.raise_error('INVESTIGATION_REQUIRED'); END IF;
    IF v_req AND EXISTS (SELECT 1 FROM keystone.investigations WHERE event_id = e.id AND deleted_at IS NULL AND approved_at IS NULL)
      THEN PERFORM keystone.raise_error('REPORT_NOT_APPROVED'); END IF;
    IF EXISTS (SELECT 1 FROM keystone.root_causes rc JOIN keystone.investigations i ON i.id = rc.investigation_id
               WHERE i.event_id = e.id AND rc.is_root AND NOT EXISTS (
                 SELECT 1 FROM keystone.capa_actions c WHERE c.root_cause_id = rc.id AND c.status <> 'cancelled'))
      THEN PERFORM keystone.raise_error('ROOT_CAUSE_WITHOUT_CAPA'); END IF;

  ELSIF e.status = 'capa_defined' AND p_to = 'closed' THEN
    PERFORM keystone.assert_permission('event.close');
    IF EXISTS (SELECT 1 FROM keystone.capa_actions WHERE event_id = e.id AND deleted_at IS NULL
               AND status NOT IN ('closed','cancelled')) THEN PERFORM keystone.raise_error('CAPA_OPEN'); END IF;
    e.closure_reason := v_reason;

  ELSE PERFORM keystone.raise_error('INVALID_TRANSITION'); END IF;

  IF p_to = 'closed' THEN e.closed_at := now(); e.closed_by := auth.uid(); END IF;
  UPDATE keystone.hsse_events SET status = p_to, triaged_at = e.triaged_at, rejection_reason = e.rejection_reason,
    closure_reason = e.closure_reason, closed_at = e.closed_at, closed_by = e.closed_by, updated_by = auth.uid()
  WHERE id = e.id RETURNING * INTO e;
  RETURN e;
END; $$;

-- AnnexeC_HSSE#11
CREATE TABLE keystone.investigations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id) ON DELETE CASCADE,
  method keystone.investigation_method NOT NULL,
  lead_id uuid NOT NULL REFERENCES keystone.persons(id),
  due_date date,
  summary text, lessons_learned text,
  completed_at timestamptz,
  approved_by uuid, approved_at timestamptz,
  returned_reason text,
  CONSTRAINT uq_inv_method UNIQUE (event_id, method),
  CONSTRAINT ck_inv_complete CHECK (completed_at IS NULL OR (summary IS NOT NULL AND lessons_learned IS NOT NULL)),
  CONSTRAINT ck_inv_approve CHECK (approved_at IS NULL OR completed_at IS NOT NULL)
);

-- AnnexeC_HSSE#11
CREATE INDEX ix_inv_event ON keystone.investigations (tenant_id, event_id);

-- AnnexeC_HSSE#11
CREATE TABLE keystone.investigation_members (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  investigation_id uuid NOT NULL REFERENCES keystone.investigations(id) ON DELETE CASCADE,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  role keystone.investigation_role NOT NULL DEFAULT 'member',
  UNIQUE (investigation_id, person_id)
);

-- AnnexeC_HSSE#11
CREATE TABLE keystone.investigation_timeline (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  investigation_id uuid NOT NULL REFERENCES keystone.investigations(id) ON DELETE CASCADE,
  occurred_at timestamptz NOT NULL, fact text NOT NULL,
  source keystone.timeline_source NOT NULL, position int NOT NULL
);

-- AnnexeC_HSSE#11
CREATE TABLE keystone.witness_statements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  investigation_id uuid NOT NULL REFERENCES keystone.investigations(id) ON DELETE CASCADE,
  event_person_id uuid NOT NULL REFERENCES keystone.event_persons(id),
  interviewed_at timestamptz NOT NULL, interviewer_id uuid NOT NULL REFERENCES keystone.persons(id),
  statement text NOT NULL, audio_document_id uuid REFERENCES keystone.ged_documents(id),
  witness_signed_at timestamptz, signature_hash text
);

-- AnnexeC_HSSE#11
CREATE TABLE keystone.root_causes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  investigation_id uuid NOT NULL REFERENCES keystone.investigations(id) ON DELETE CASCADE,
  category keystone.ishikawa_category,               -- Ishikawa 6M
  statement text NOT NULL,
  is_root boolean NOT NULL DEFAULT false,
  parent_cause_id uuid REFERENCES keystone.root_causes(id) ON DELETE CASCADE,   -- chaîne 5 pourquoi, arbre
  gate_type keystone.fault_gate,                     -- arbre des causes : porte ET ou OU vers les antécédents
  position int NOT NULL DEFAULT 0
);

-- AnnexeC_HSSE#11
CREATE INDEX ix_rc_inv ON keystone.root_causes (tenant_id, investigation_id);

-- AnnexeC_HSSE#11
CREATE TABLE keystone.safety_alerts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id),
  investigation_id uuid REFERENCES keystone.investigations(id),
  title text NOT NULL, message text NOT NULL,            -- sans nom de victime ni donnée de santé
  audience jsonb NOT NULL,                               -- {"site_ids":[],"role_codes":[],"vendor_ids":[]}
  attachment_document_id uuid REFERENCES keystone.ged_documents(id),
  sent_at timestamptz, sent_by uuid
);

-- AnnexeC_HSSE#12
CREATE POLICY ws_select ON keystone.witness_statements FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND (keystone.has_permission('event.close')
  OR EXISTS (SELECT 1 FROM keystone.investigation_members m
             WHERE m.investigation_id = witness_statements.investigation_id AND m.person_id = keystone.current_person_id())));

-- AnnexeC_HSSE#13
CREATE TABLE keystone.capa_actions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  site_id uuid REFERENCES atlas_core.sites(id),
  ref text NOT NULL,                                   -- CAPA-2026-000123
  type keystone.capa_type NOT NULL,
  source keystone.capa_source NOT NULL,
  source_id uuid,                                      -- événement, investigation, constat, inspection, contrôle, risque, aspect, revue
  event_id uuid REFERENCES keystone.hsse_events(id),   -- renseigné par trigger pour source event ou investigation
  root_cause_id uuid REFERENCES keystone.root_causes(id) ON DELETE SET NULL,
  vendor_id uuid REFERENCES keystone.vendors(id),      -- prestataire concerné, visible au portail fournisseurs
  title text NOT NULL, description text,
  control_level keystone.control_hierarchy NOT NULL,
  responsible_id uuid NOT NULL REFERENCES keystone.persons(id),
  due_date date NOT NULL,
  priority int NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 4),
  status keystone.capa_status NOT NULL DEFAULT 'open',
  completed_at timestamptz,
  effectiveness_due date,
  verification_method text NOT NULL,
  verified_effective boolean, verified_by uuid, verified_at timestamptz,
  closed_at timestamptz,                            -- posé au passage closed (KPI-CAP-02)
  cancel_reason text, cancel_approved_by uuid, cancel_approved_at timestamptz,
  CONSTRAINT uq_capa_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_capa_cancel CHECK (status <> 'cancelled'
    OR (cancel_reason IS NOT NULL AND cancel_approved_by IS NOT NULL AND cancel_approved_at IS NOT NULL))
);

-- AnnexeC_HSSE#13
CREATE INDEX ix_capa_status  ON keystone.capa_actions (tenant_id, status) WHERE deleted_at IS NULL;

-- AnnexeC_HSSE#13
CREATE INDEX ix_capa_due     ON keystone.capa_actions (tenant_id, due_date) WHERE status NOT IN ('closed','cancelled');

-- AnnexeC_HSSE#13
CREATE INDEX ix_capa_eff_due ON keystone.capa_actions (tenant_id, effectiveness_due) WHERE status = 'verifying';

-- AnnexeC_HSSE#13
CREATE INDEX ix_capa_event   ON keystone.capa_actions (tenant_id, event_id) WHERE event_id IS NOT NULL;

-- AnnexeC_HSSE#13
CREATE INDEX ix_capa_source  ON keystone.capa_actions (tenant_id, source, source_id);

-- AnnexeC_HSSE#14
CREATE OR REPLACE FUNCTION keystone.capa_transition(p_capa uuid, p_to keystone.capa_status, p_meta jsonb DEFAULT '{}')
RETURNS keystone.capa_actions LANGUAGE plpgsql SECURITY DEFINER SET search_path = keystone, pg_temp AS $$
DECLARE c keystone.capa_actions; v_me uuid := keystone.current_person_id();
        v_reason text := nullif(btrim(p_meta->>'reason'), '');
BEGIN
  SELECT * INTO c FROM keystone.capa_actions WHERE id = p_capa AND tenant_id = keystone.current_tenant() FOR UPDATE;
  IF NOT FOUND THEN PERFORM keystone.raise_error('NOT_FOUND'); END IF;
  IF p_to = 'closed' AND c.status <> 'verifying' THEN PERFORM keystone.raise_error('MUST_VERIFY_FIRST'); END IF;
  IF NOT keystone.capa_can_transition(c.status, p_to) THEN
    PERFORM keystone.raise_error('INVALID_TRANSITION', jsonb_build_object('from', c.status, 'to', p_to)); END IF;

  IF p_to IN ('in_progress','done') AND v_me IS DISTINCT FROM c.responsible_id THEN
    PERFORM keystone.assert_permission('capa.assign'); END IF;
  IF p_to = 'done' THEN
    c.completed_at := now();
    c.effectiveness_due := COALESCE((p_meta->>'effectiveness_due')::date, (now() + interval '30 days')::date);
  END IF;
  IF p_to IN ('verifying','closed','reopened') THEN PERFORM keystone.assert_permission('capa.verify'); END IF;
  IF p_to IN ('closed','reopened') THEN
    IF v_me = c.responsible_id THEN PERFORM keystone.raise_error('SEGREGATION_OF_DUTIES'); END IF;
    IF p_to = 'closed' AND (p_meta->>'verified_effective')::boolean IS DISTINCT FROM true THEN
      PERFORM keystone.raise_error('NOT_EFFECTIVE'); END IF;
    c.verified_effective := (p_to = 'closed'); c.verified_by := auth.uid(); c.verified_at := now();
  END IF;
  IF p_to = 'cancelled' THEN
    PERFORM keystone.assert_permission('capa.close');
    IF v_reason IS NULL THEN PERFORM keystone.raise_error('REASON_REQUIRED'); END IF;
    IF v_me = c.responsible_id THEN PERFORM keystone.raise_error('SEGREGATION_OF_DUTIES'); END IF;
    c.cancel_reason := v_reason; c.cancel_approved_by := auth.uid(); c.cancel_approved_at := now();
  END IF;

  UPDATE keystone.capa_actions SET status = p_to, completed_at = c.completed_at,
    effectiveness_due = c.effectiveness_due, verified_effective = c.verified_effective,
    verified_by = c.verified_by, verified_at = c.verified_at, cancel_reason = c.cancel_reason,
    cancel_approved_by = c.cancel_approved_by, cancel_approved_at = c.cancel_approved_at, updated_by = auth.uid()
  WHERE id = p_capa RETURNING * INTO c;
  RETURN c;
END; $$;

-- AnnexeC_HSSE#17
CREATE VIEW keystone.hsse_rates_monthly_v AS
WITH acc AS (
  SELECT e.tenant_id, e.site_id, keystone.site_local_month(e.site_id, e.occurred_at) AS period_month,
         e.victim_population AS population,
         count(*) FILTER (WHERE e.lost_time_days > 0) AS lost_time_accidents,
         COALESCE(sum(e.lost_time_days), 0)           AS lost_days,
         count(*) FILTER (WHERE e.is_recordable)      AS recordable
  FROM keystone.hsse_events e
  WHERE e.type = 'accident' AND e.status <> 'rejected' AND e.deleted_at IS NULL
    AND e.victim_population IS NOT NULL
  GROUP BY 1, 2, 3, 4)
SELECT h.tenant_id, h.site_id, h.period_month, h.population, h.hours,
       COALESCE(a.lost_time_accidents, 0) AS lost_time_accidents, COALESCE(a.lost_days, 0) AS lost_days,
       CASE WHEN h.hours > 0 THEN COALESCE(a.lost_time_accidents, 0) * 1000000.0 / h.hours END AS tf,
       CASE WHEN h.hours > 0 THEN COALESCE(a.lost_days, 0) * 1000.0 / h.hours END AS tg,
       CASE WHEN h.hours > 0 THEN COALESCE(a.recordable, 0) * 200000.0 / h.hours END AS trir
FROM keystone.worked_hours h
LEFT JOIN acc a USING (tenant_id, site_id, period_month, population)
WHERE h.deleted_at IS NULL;

-- AnnexeC_HSSE_Partie2#2
CREATE TABLE keystone.risk_register (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid NOT NULL REFERENCES atlas_core.legal_entities(id),
  ref text NOT NULL,                       -- RSK-2026-000042
  work_unit_id uuid NOT NULL REFERENCES keystone.work_units(id),
  source_assessment_line_id uuid REFERENCES keystone.risk_assessment_lines(id),   -- risque créé depuis une analyse de tâche
  site_id uuid REFERENCES atlas_core.sites(id),
  location_id uuid REFERENCES keystone.locations(id),
  asset_id uuid REFERENCES keystone.assets(id),
  hazard_id uuid REFERENCES keystone.hazards(id),
  kind keystone.risk_kind NOT NULL DEFAULT 'threat',
  category keystone.risk_category NOT NULL DEFAULT 'ohs',
  description text NOT NULL, situation text,
  likelihood int NOT NULL CHECK (likelihood BETWEEN 1 AND 5),
  severity   int NOT NULL CHECK (severity BETWEEN 1 AND 5),
  inherent_score int GENERATED ALWAYS AS (likelihood * severity) STORED,
  residual_likelihood int CHECK (residual_likelihood BETWEEN 1 AND 5),
  residual_severity   int CHECK (residual_severity BETWEEN 1 AND 5),
  residual_score int GENERATED ALWAYS AS (residual_likelihood * residual_severity) STORED,
  level keystone.risk_level GENERATED ALWAYS AS
    (keystone.risk_band(COALESCE(residual_likelihood * residual_severity, likelihood * severity))) STORED,
  status keystone.risk_status NOT NULL DEFAULT 'identified',
  owner_id uuid NOT NULL REFERENCES keystone.persons(id),
  review_due date NOT NULL,
  review_reason text,                      -- motif de remise « à revoir »
  rated_by uuid NOT NULL,                  -- utilisateur humain auteur de la cotation (A44)
  rated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_rr_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_rr_residual CHECK ((residual_likelihood IS NULL) = (residual_severity IS NULL))
);

-- AnnexeC_HSSE_Partie2#2
CREATE INDEX ix_rr_level  ON keystone.risk_register (tenant_id, legal_entity_id, level) WHERE deleted_at IS NULL;

-- AnnexeC_HSSE_Partie2#2
CREATE INDEX ix_rr_review ON keystone.risk_register (tenant_id, review_due) WHERE status <> 'to_review';

-- AnnexeC_HSSE_Partie2#2
CREATE INDEX ix_rr_unit   ON keystone.risk_register (tenant_id, work_unit_id);

-- AnnexeC_HSSE_Partie2#2
CREATE TABLE keystone.controls (                       -- moyens de maîtrise (CDC v3 §6.4)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  risk_id uuid NOT NULL REFERENCES keystone.risk_register(id) ON DELETE CASCADE,
  hierarchy keystone.control_hierarchy NOT NULL,
  description text NOT NULL,
  is_implemented boolean NOT NULL DEFAULT false,
  effectiveness int CHECK (effectiveness BETWEEN 1 AND 5),
  capa_id uuid REFERENCES keystone.capa_actions(id)
);

-- AnnexeC_HSSE_Partie2#2
CREATE TABLE keystone.risk_links (                     -- déclencheurs de revue (RG-RSK-04)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  risk_id uuid NOT NULL REFERENCES keystone.risk_register(id) ON DELETE CASCADE,
  link_type keystone.risk_link_type NOT NULL, object_id uuid NOT NULL,
  UNIQUE (risk_id, link_type, object_id)
);

-- AnnexeC_HSSE_Partie2#2
CREATE TABLE keystone.risk_rating_history (            -- historique des cotations du registre
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  risk_id uuid NOT NULL REFERENCES keystone.risk_register(id) ON DELETE CASCADE,
  likelihood int NOT NULL, severity int NOT NULL,
  residual_likelihood int, residual_severity int,
  level keystone.risk_level NOT NULL, rated_by uuid NOT NULL, rated_at timestamptz NOT NULL, reason text
);

-- AnnexeC_HSSE_Partie2#4
CREATE POLICY risk_register_read ON keystone.risk_register FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL
  AND ( (kind = 'threat' AND category IN ('ohs','environment')
         AND (keystone.has_permission('risk.manage') OR owner_id = keystone.current_person_id()))
     OR ((kind = 'opportunity' OR category NOT IN ('ohs','environment'))
         AND keystone.has_permission('risk.manage_business'))));

-- AnnexeC_HSSE_Partie3#5
CREATE TABLE keystone.compliance_requirements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  legal_entity_id uuid REFERENCES atlas_core.legal_entities(id),
  site_id uuid REFERENCES atlas_core.sites(id),
  framework_id uuid REFERENCES keystone.compliance_frameworks(id),
  obligation_id uuid REFERENCES keystone.legal_obligations(id),
  country_code char(2),
  clause text, requirement text NOT NULL,
  is_applicable boolean NOT NULL DEFAULT true,
  status keystone.compliance_status NOT NULL DEFAULT 'open',
  evidence_document_id uuid REFERENCES keystone.ged_documents(id),
  capa_id uuid REFERENCES keystone.capa_actions(id),
  CONSTRAINT ck_cr_src CHECK (framework_id IS NOT NULL OR obligation_id IS NOT NULL),
  CONSTRAINT ck_cr_na CHECK (is_applicable OR status = 'na')
);

-- AnnexeC_HSSE_Partie3#5
CREATE TABLE keystone.compliance_evaluations (           -- évaluation de la conformité, ISO 45001 et ISO 14001 §9.1.2
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  requirement_id uuid NOT NULL REFERENCES keystone.compliance_requirements(id),
  evaluated_on date NOT NULL, evaluator_id uuid NOT NULL REFERENCES keystone.persons(id),
  result keystone.compliance_status NOT NULL CHECK (result <> 'open'),
  evidence_document_id uuid REFERENCES keystone.ged_documents(id), comment text,
  next_evaluation_due date NOT NULL
);

-- AnnexeC_HSSE_Partie3#7
CREATE TABLE keystone.lessons_learned (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id) ON DELETE RESTRICT,
  investigation_id uuid REFERENCES keystone.investigations(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  title text NOT NULL CHECK (char_length(title) <= 200),
  content text NOT NULL,                                 -- copie de investigations.lessons_learned, rédigée sans nom
  hazard_category keystone.hazard_category,
  is_shared_tenant_wide boolean NOT NULL DEFAULT false,  -- diffusion à tous les sites du tenant
  published_by uuid, published_at timestamptz,
  CONSTRAINT uq_lesson_event UNIQUE (tenant_id, event_id),
  CONSTRAINT ck_lesson_pub CHECK ((published_at IS NULL) = (published_by IS NULL))
);

-- AnnexeC_HSSE_Partie3#7
CREATE INDEX ix_lessons_site ON keystone.lessons_learned (tenant_id, site_id, published_at DESC);

-- AnnexeC_HSSE_Partie4#2
CREATE TABLE keystone.occupational_diseases (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  person_id uuid NOT NULL REFERENCES keystone.persons(id),
  label_enc bytea NOT NULL,                -- chiffré : intitulé de la maladie
  social_security_ref_enc bytea,           -- chiffré : référence de déclaration (CNPS en Côte d'Ivoire)
  status keystone.disease_status NOT NULL DEFAULT 'suspected',
  declared_on date, recognised_on date, rejected_on date,
  related_event_id uuid REFERENCES keystone.hsse_events(id),
  related_exposure_ids uuid[] NOT NULL DEFAULT '{}',          -- référence logique vers occupational_exposures
  retain_until date NOT NULL,
  key_version int NOT NULL DEFAULT 1,
  corrected_at timestamptz, corrected_by uuid REFERENCES keystone.persons(id), correction_reason_enc bytea,
  replaced_by_id uuid REFERENCES keystone.occupational_diseases(id),
  CONSTRAINT ck_od_dates CHECK (recognised_on IS NULL OR (declared_on IS NOT NULL AND recognised_on >= declared_on)),
  CONSTRAINT ck_od_rejected CHECK (rejected_on IS NULL OR status = 'rejected'),
  CONSTRAINT ck_od_correction CHECK ((corrected_at IS NULL) = (corrected_by IS NULL)
    AND (corrected_at IS NULL) = (correction_reason_enc IS NULL))
);

-- AnnexeC_HSSE_Partie4#3
-- Même politique sur occupational_exposures (avec keystone.site_in_scope(site_id)) et occupational_diseases.
-- Aucune politique INSERT, UPDATE, DELETE : écriture par les RPC C.21 seulement.
REVOKE ALL ON keystone.medical_visits, keystone.occupational_exposures, keystone.occupational_diseases
  FROM proph3t_reader, anon;

-- AnnexeC_HSSE_Partie4#5
CREATE TABLE keystone.event_containment_measures (     -- section G, une ligne par mesure conservatoire
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  event_id uuid NOT NULL REFERENCES keystone.hsse_events(id) ON DELETE CASCADE,
  position int NOT NULL CHECK (position >= 1),
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 3 AND 500),
  done_at timestamptz NOT NULL,                          -- heure de l'appareil, bornée par le serveur (A94)
  responsible_person_id uuid REFERENCES keystone.persons(id),
  responsible_label text CHECK (char_length(responsible_label) <= 120),   -- service extérieur (pompiers, SAMU), jamais une victime
  CONSTRAINT ck_ecm_who CHECK (responsible_person_id IS NOT NULL OR responsible_label IS NOT NULL),
  CONSTRAINT uq_ecm_pos UNIQUE (event_id, position) DEFERRABLE INITIALLY DEFERRED
);

-- AnnexeC_HSSE_Partie4#5
CREATE INDEX ix_ecm_event ON keystone.event_containment_measures (tenant_id, event_id);

-- AnnexeC_HSSE_Partie4#5
ALTER TABLE keystone.event_containment_measures ENABLE ROW LEVEL SECURITY;

-- AnnexeC_HSSE_Partie4#5
CREATE POLICY ecm_select ON keystone.event_containment_measures FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND EXISTS (SELECT 1 FROM keystone.hsse_events e WHERE e.id = event_id));

-- AnnexeC_HSSE_Partie4#5
-- evt_select s'applique par la sous-requête ; aucune politique INSERT, UPDATE, DELETE.
REVOKE ALL ON keystone.event_containment_measures FROM anon;

-- AnnexeR_Reglementaire_SSI#3
CREATE TABLE keystone.control_reserves (                -- CDC v3 §6.17
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  control_id uuid NOT NULL REFERENCES keystone.regulatory_controls(id) ON DELETE RESTRICT,
  result_id uuid NOT NULL REFERENCES keystone.regulatory_control_results(id),
  ref text NOT NULL,                        -- numéro de la réserve dans le rapport
  severity keystone.risk_level NOT NULL,
  description text NOT NULL,
  capa_id uuid REFERENCES keystone.capa_actions(id),
  responsible_id uuid NOT NULL REFERENCES keystone.persons(id),
  due_date date NOT NULL,                   -- échéance de levée (KPI-REG-03), reprise par la CAPA
  status keystone.reserve_status NOT NULL DEFAULT 'open',
  lifted_at timestamptz, lifted_by uuid
);

-- AnnexeR_Reglementaire_SSI#3
CREATE INDEX ix_cres_open ON keystone.control_reserves (tenant_id, control_id) WHERE status <> 'lifted';

-- AnnexeR_Reglementaire_SSI#7
CREATE TABLE keystone.fire_drills (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  plan_id uuid REFERENCES keystone.fire_drill_plans(id),
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id),
  held_on date NOT NULL, scenario text NOT NULL,
  evac_time_sec int NOT NULL CHECK (evac_time_sec > 0),
  target_evac_time_sec int,                  -- copiée de site_fire_settings au moment de l'exercice
  within_target boolean GENERATED ALWAYS AS (evac_time_sec <= target_evac_time_sec) STORED,
  participants int NOT NULL CHECK (participants >= 0),
  started_at timestamptz, ended_at timestamptz,   -- chronométrage ; evac_time_sec = ended_at moins started_at si saisis
  findings text,
  capa_id uuid REFERENCES keystone.capa_actions(id),
  status keystone.drill_status NOT NULL DEFAULT 'done'
);

-- AnnexeR_Reglementaire_SSI#7
CREATE TABLE keystone.fire_drill_assembly_results (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  drill_id uuid NOT NULL REFERENCES keystone.fire_drills(id) ON DELETE CASCADE,
  sector_id uuid NOT NULL REFERENCES keystone.sectors(id),       -- secteur du zonage évacuation (Annexe S)
  assembly_point_key text NOT NULL,          -- clé du point dans sectors.assembly_points (A76, aucune table dédiée)
  headcount int NOT NULL CHECK (headcount >= 0), evac_time_sec int CHECK (evac_time_sec > 0)
);

-- AnnexeD_Tickets_Portails_Partie2#2
CREATE VIEW keystone.occupant_org_spaces WITH (security_invoker = true) AS
  SELECT so.tenant_id, so.occupant_org_id, so.space_unit_id, so.valid_from, so.valid_to
    FROM keystone.space_occupancies so          -- Annexe S, source unique (A31)
   WHERE so.occupant_org_id IS NOT NULL AND so.deleted_at IS NULL;

-- AnnexeM_Mode_Prestataire#6
CREATE TABLE keystone.billable_items (
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  contract_id uuid NOT NULL REFERENCES keystone.service_contracts(id) ON DELETE RESTRICT,
  client_id uuid NOT NULL REFERENCES keystone.clients(id),
  site_id uuid REFERENCES atlas_core.sites(id),
  work_order_id uuid REFERENCES keystone.work_orders(id) ON DELETE RESTRICT,
  client_quote_id uuid REFERENCES keystone.client_quotes(id),
  kind keystone.billable_kind NOT NULL,
  label text NOT NULL,
  period date NOT NULL CHECK (date_trunc('month', period) = period),
  quantity numeric(14,3) NOT NULL DEFAULT 1,
  unit_price bigint,
  amount_ht bigint NOT NULL,                             -- signé : une pénalité est négative
  vat_rate numeric(7,4) NOT NULL,
  currency char(3) NOT NULL CHECK (currency IN ('XOF','XAF')),
  calc_detail jsonb NOT NULL DEFAULT '{}',               -- base, taux, termes appliqués, manquements
  status keystone.billable_status NOT NULL DEFAULT 'draft',
  validated_by uuid, validated_at timestamptz,
  idempotency_key text NOT NULL,                         -- clé de remise à Atlas Trade (IF.2)
  trade_invoice_id text, trade_invoice_ref text, trade_line_id text,
  pushed_at timestamptz, invoiced_at timestamptz, paid_at timestamptz,
  cancel_reason text, adjusts_item_id uuid REFERENCES keystone.billable_items(id),
  CONSTRAINT uq_billable_idem UNIQUE (tenant_id, idempotency_key),
  CONSTRAINT ck_penalty_sign CHECK (kind <> 'penalty' OR amount_ht <= 0),
  CONSTRAINT ck_nonpenalty_sign CHECK (kind IN ('penalty','adjustment') OR amount_ht >= 0),
  CONSTRAINT ck_variable_wo CHECK (kind <> 'variable' OR work_order_id IS NOT NULL)
);

-- AnnexeM_Mode_Prestataire#6
CREATE UNIQUE INDEX uq_billable_recurring ON keystone.billable_items (tenant_id, contract_id, period)
  WHERE kind = 'recurring' AND status <> 'cancelled';

-- AnnexeM_Mode_Prestataire#6
CREATE UNIQUE INDEX uq_billable_variable ON keystone.billable_items (tenant_id, work_order_id)
  WHERE kind = 'variable' AND status <> 'cancelled';

-- AnnexeM_Mode_Prestataire#6
CREATE UNIQUE INDEX uq_billable_penalty ON keystone.billable_items (tenant_id, contract_id, period)
  WHERE kind = 'penalty' AND status <> 'cancelled';

-- AnnexeM_Mode_Prestataire#6
CREATE INDEX ix_billable_status ON keystone.billable_items (tenant_id, status, period);

-- AnnexeF_SoftFM#2
CREATE VIEW keystone.service_visits WITH (security_invoker = true) AS
SELECT w.id, w.tenant_id, w.site_id, st.family AS service_family, w.location_id, mpa.sector_id,
       w.vendor_id, w.planned_start AS planned_at, w.actual_end AS done_at,
       (CASE
         WHEN qs.lot_accepted IS TRUE  THEN 'qc_passed'
         WHEN qs.lot_accepted IS FALSE THEN 'qc_failed'
         WHEN w.stage IN ('reported','received','closed') THEN 'done'
         WHEN w.stage = 'in_progress' THEN 'in_progress'
         WHEN w.actual_start IS NULL AND w.sla_resolution_due < now() THEN 'missed'
         ELSE 'planned' END)::text AS status          -- texte, aucune énumération dédiée
  FROM keystone.work_orders w
  JOIN keystone.maintenance_plans mp ON mp.id = w.source_plan_id
  JOIN keystone.service_types st ON st.id = mp.service_type_id
  LEFT JOIN keystone.maintenance_plan_assets mpa ON mpa.id = w.plan_asset_id
  LEFT JOIN keystone.qc_scores qs ON qs.inspection_id = w.qc_inspection_id
 WHERE w.type = 'service';

-- AnnexeF_SoftFM#4
CREATE TABLE keystone.bait_station_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL, station_id uuid NOT NULL REFERENCES keystone.bait_stations(id),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),     -- passage type = 'service'
  checked_at timestamptz NOT NULL DEFAULT now(),
  state text NOT NULL CHECK (state IN ('ok','damaged','missing','moved')),
  consumption_pct smallint CHECK (consumption_pct BETWEEN 0 AND 100),
  captures smallint NOT NULL DEFAULT 0 CHECK (captures >= 0),
  bait_renewed boolean NOT NULL DEFAULT false,
  pest_intervention_id uuid REFERENCES keystone.pest_interventions(id),   -- appât renouvelé : produit tracé
  CONSTRAINT uq_station_check UNIQUE (station_id, work_order_id),
  CONSTRAINT ck_bait_product CHECK (NOT bait_renewed OR pest_intervention_id IS NOT NULL) );

-- AnnexeF_SoftFM#6
CREATE VIEW keystone.v_softfm_waste WITH (security_invoker = true) AS
SELECT wr.id, wr.tenant_id, wr.site_id, wr.location_id, wr.stream_code, wr.is_hazardous,
       wr.quantity, wr.unit, wr.quantity_kg, wr.recorded_at, wr.hauler_vendor_id, wr.tracking_slip_ref,
       wr.outcome, wr.recovered, wr.status, wr.work_order_id, wr.validated_at, wr.cancel_reason
  FROM keystone.waste_records wr;

-- AnnexeU_Surete_Accueil_Partie2#1
-- type keystone.security_severity : défini en partie 1 (U.1)

CREATE TABLE keystone.security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  ref text NOT NULL,                                       -- SEV-AAAA-NNNNNN, next_ref('SEV', année)
  site_id uuid NOT NULL REFERENCES atlas_core.sites(id) ON DELETE RESTRICT,
  kind keystone.security_event_kind NOT NULL,
  source keystone.security_event_source NOT NULL,
  external_id text,                                        -- identifiant de l'événement dans le système source
  severity keystone.security_severity NOT NULL,            -- proposée par la règle de source, modifiable à la qualification
  detected_at timestamptz NOT NULL,                        -- horodatage du système source (A94 pour la saisie mobile)
  received_at timestamptz NOT NULL DEFAULT now(),
  access_zone_id uuid REFERENCES keystone.access_zones(id) ON DELETE SET NULL,
  location_id uuid REFERENCES keystone.locations(id) ON DELETE SET NULL,
  iot_device_id uuid REFERENCES keystone.iot_devices(id) ON DELETE SET NULL,
  prediction_id uuid REFERENCES keystone.predictions(id) ON DELETE SET NULL,   -- source vision (Annexe H)
  confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),                  -- source vision seulement
  video_ref text,                                          -- référence d'enregistrement du système vidéo, jamais d'image
  description text CHECK (description IS NULL OR char_length(description) <= 2000),
  status keystone.security_event_status NOT NULL DEFAULT 'new',
  acknowledged_by uuid, acknowledged_at timestamptz,
  qualified_by uuid, qualified_at timestamptz, qualification_note text,
  security_log_id bigint REFERENCES keystone.security_log(id),   -- entrée créée à la confirmation
  hsse_event_id uuid REFERENCES keystone.hsse_events(id),        -- événement HSSE créé depuis l'entrée (Annexe C)
  closed_by uuid, closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT uq_security_event_ref UNIQUE (tenant_id, ref),
  CONSTRAINT ck_sev_vision CHECK ((source = 'vision') = (prediction_id IS NOT NULL)),
  CONSTRAINT ck_sev_confidence CHECK (source = 'vision' OR confidence IS NULL),
  CONSTRAINT ck_sev_manual CHECK (source <> 'manual' OR description IS NOT NULL),
  CONSTRAINT ck_sev_ack CHECK (status = 'new' OR (acknowledged_by IS NOT NULL AND acknowledged_at IS NOT NULL)),
  CONSTRAINT ck_sev_confirmed CHECK (status NOT IN ('confirmed','closed') OR security_log_id IS NOT NULL
                                     OR status = 'closed' AND qualification_note IS NOT NULL),
  CONSTRAINT ck_sev_false CHECK (status <> 'false_positive' OR qualification_note IS NOT NULL)
);

-- AnnexeU_Surete_Accueil_Partie2#1
CREATE UNIQUE INDEX uq_sev_external ON keystone.security_events (tenant_id, source, external_id)
  WHERE external_id IS NOT NULL;

-- AnnexeU_Surete_Accueil_Partie2#1
-- idempotence de l'ingestion
CREATE INDEX ix_sev_open ON keystone.security_events (tenant_id, site_id, detected_at DESC)
  WHERE status IN ('new','acknowledged');

-- AnnexeU_Surete_Accueil_Partie2#1
CREATE INDEX ix_sev_site_day ON keystone.security_events (tenant_id, site_id, detected_at);

-- AnnexeU_Surete_Accueil_Partie2#1
ALTER TABLE keystone.security_events ENABLE ROW LEVEL SECURITY;

-- AnnexeU_Surete_Accueil_Partie2#1
CREATE POLICY sev_select ON keystone.security_events FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND deleted_at IS NULL AND keystone.site_in_scope(site_id)
  AND (keystone.has_permission('security.log') OR keystone.has_permission('security.kpi_read')));

-- AnnexeU_Surete_Accueil_Partie2#2
CREATE TABLE keystone.crisis_drill_findings (             -- résultat par objectif et écarts
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  drill_id uuid NOT NULL REFERENCES keystone.crisis_drills(id) ON DELETE CASCADE,
  objective_index smallint NOT NULL CHECK (objective_index >= 1),
  met boolean NOT NULL,
  observation text,
  capa_id uuid REFERENCES keystone.capa_actions(id),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid,
  CONSTRAINT uq_crx_finding UNIQUE (drill_id, objective_index),
  CONSTRAINT ck_crx_unmet CHECK (met OR capa_id IS NOT NULL OR observation IS NOT NULL)
);

-- AnnexeU_Surete_Accueil_Partie2#2
ALTER TABLE keystone.crisis_drill_findings ENABLE ROW LEVEL SECURITY;

-- AnnexeU_Surete_Accueil_Partie2#2
CREATE POLICY crx_find_select ON keystone.crisis_drill_findings FOR SELECT USING (
  tenant_id = keystone.current_tenant() AND EXISTS (SELECT 1 FROM keystone.crisis_drills d WHERE d.id = drill_id));

-- AnnexeQ_Reporting#4
CREATE TABLE keystone.fm_requirements (              -- §4.2 b et c, §4.3
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  stakeholder_id uuid NOT NULL REFERENCES keystone.fm_stakeholders(id) ON DELETE RESTRICT,
  requirement text NOT NULL,
  source requirement_source NOT NULL,
  is_compliance_obligation boolean NOT NULL DEFAULT false,
  compliance_requirement_id uuid REFERENCES keystone.compliance_requirements(id),   -- Annexe C
  service_contract_id uuid REFERENCES keystone.service_contracts(id),              -- fm_provider
  decision text NOT NULL CHECK (decision IN ('adopted','not_adopted')),            -- §4.2 c
  decision_reason text,
  kpi_code text,                                     -- indicateur qui en rend compte
  review_due date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid, updated_by uuid, deleted_at timestamptz,
  CONSTRAINT ck_req_reason CHECK (decision = 'adopted' OR decision_reason IS NOT NULL),
  CONSTRAINT ck_req_compliance CHECK (NOT is_compliance_obligation OR compliance_requirement_id IS NOT NULL)
);

-- AnnexeQ_Reporting#5
CREATE TABLE keystone.fm_review_outputs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
  review_id uuid NOT NULL REFERENCES keystone.fm_management_reviews(id) ON DELETE CASCADE,
  kind review_output_kind NOT NULL,
  decision text NOT NULL,
  no_change boolean NOT NULL DEFAULT false,          -- décision motivée « aucun changement nécessaire »
  owner_id uuid, due_date date,
  capa_id uuid REFERENCES keystone.capa_actions(id), -- décision tracée vers une CAPA
  fm_objective_id uuid REFERENCES keystone.fm_objectives(id),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  CONSTRAINT ck_output_owner CHECK (kind = 'other_decision' OR no_change OR (owner_id IS NOT NULL AND due_date IS NOT NULL))
);

-- AnnexeN_Satisfaction_Cout#5
CREATE VIEW keystone.v_headcount_missing WITH (security_barrier) AS   -- espaces occupés sans effectif validé
  SELECT o.tenant_id, b.site_id, o.space_unit_id, o.occupant_org_id, m.month AS period_month
  FROM keystone.space_occupancies o
  JOIN atlas_core.spaces sp ON sp.id = o.space_unit_id
  JOIN atlas_core.levels lv ON lv.id = sp.level_id
  JOIN atlas_core.buildings b ON b.id = lv.building_id
  CROSS JOIN LATERAL generate_series(date_trunc('month', o.valid_from)::date,
                                     date_trunc('month', coalesce(o.valid_to, current_date))::date,
                                     interval '1 month') AS m(month)
  WHERE o.status = 'occupied' AND o.deleted_at IS NULL AND b.site_id IN (SELECT keystone.user_sites())
    AND NOT EXISTS (SELECT 1 FROM keystone.occupant_headcount h
                    WHERE h.tenant_id = o.tenant_id AND h.period_month = m.month AND h.status = 'validated'
                      AND (h.space_unit_id = o.space_unit_id OR h.occupant_org_id = o.occupant_org_id));

-- AnnexeA_Socle_Partie3#6
CREATE VIEW keystone.v_asset_stop_impact WITH (security_barrier) AS     -- occupants touchés par un arrêt
  SELECT s.tenant_id, s.asset_id, s.space_id, s.service_role, o.occupant_org_id, o.status AS occupancy_status
  FROM keystone.asset_served_spaces s
  LEFT JOIN keystone.space_occupancies o ON o.space_unit_id = s.space_id AND o.deleted_at IS NULL
   AND o.valid_from <= current_date AND (o.valid_to IS NULL OR o.valid_to >= current_date);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_events_title_trgm   ON keystone.hsse_events  USING gin (title gin_trgm_ops);

-- AnnexeA_Socle_Partie4#1
CREATE INDEX ix_events_ref_prefix   ON keystone.hsse_events  (tenant_id, ref text_pattern_ops);

-- AnnexeA_Socle_Partie4#3
ALTER TABLE keystone.asset_observations
  ADD CONSTRAINT fk_obs_capa FOREIGN KEY (capa_action_id)
      REFERENCES keystone.capa_actions(id) ON DELETE SET NULL;

-- AnnexeA_Socle_Partie4#3
ALTER TABLE keystone.asset_action_links
  ADD CONSTRAINT fk_asset_action_capa FOREIGN KEY (capa_action_id)
      REFERENCES keystone.capa_actions(id) ON DELETE CASCADE;

-- AnnexeK_Formation_Environnement#13
CREATE TABLE keystone.management_review_decisions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  review_id uuid NOT NULL REFERENCES keystone.management_reviews(id) ON DELETE CASCADE,
  decision text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('improvement','resource','change','objective','other')),
  owner_id uuid NOT NULL REFERENCES keystone.persons(id), due_date date NOT NULL,
  capa_id uuid REFERENCES keystone.capa_actions(id),          -- CAPA source management_review
  objective_id uuid REFERENCES keystone.hsse_objectives(id)
);

-- AnnexeC_HSSE#8
-- Portail client (fm_provider) : événements de ses sites, sans donnée personnelle ;
--   avancement des CAPA en comptages seulement (aucun titre, aucun responsable, aucune description)
CREATE VIEW keystone.client_hsse_events_v WITH (security_barrier) AS
  SELECT e.id, e.ref, e.site_id, e.type, e.occurred_at, e.severity_actual, e.status,
    (SELECT count(*) FROM keystone.capa_actions c WHERE c.event_id = e.id AND c.deleted_at IS NULL
       AND c.status <> 'cancelled')                                                AS capa_count,
    (SELECT count(*) FROM keystone.capa_actions c WHERE c.event_id = e.id AND c.deleted_at IS NULL
       AND c.status = 'closed')                                                    AS capa_closed_count,
    (SELECT count(*) FROM keystone.capa_actions c WHERE c.event_id = e.id AND c.deleted_at IS NULL
       AND c.status IN ('open','in_progress','reopened') AND c.due_date < current_date) AS capa_overdue_count
  FROM keystone.hsse_events e
  WHERE e.tenant_id = keystone.current_tenant() AND keystone.client_can_see_site(e.site_id)   -- droits fins par site (D15, Annexe CL)
    AND e.deleted_at IS NULL AND e.type <> 'good_practice';

-- AnnexeC_HSSE#9
-- Liste console des événements (Formulaires HSSE §10.2) ; aucune colonne de santé, déclarant masqué si anonyme
CREATE VIEW keystone.v_hsse_event_list WITH (security_invoker = true) AS
SELECT e.id, e.tenant_id, e.ref, e.status, e.type, e.title, e.occurred_at, e.reported_at, e.severity_actual,
       e.risk_score, e.risk_band, e.is_strong_signal, e.site_id, e.location_id, e.origin, e.injury_count,
       e.lost_time_days, e.is_recordable, e.vendor_id, e.investigation_due, e.report_due, e.activity,
       e.work_order_id, e.asset_id, e.is_anonymous,
       CASE WHEN e.is_anonymous THEN NULL ELSE e.reporter_id END AS reporter_id,
       (SELECT count(*) FROM keystone.capa_actions c WHERE c.event_id = e.id AND c.deleted_at IS NULL
          AND c.status NOT IN ('closed','cancelled'))                                       AS open_capa_count,
       (SELECT count(*) FROM keystone.capa_actions c WHERE c.event_id = e.id AND c.deleted_at IS NULL
          AND c.status IN ('open','in_progress','reopened') AND c.due_date < current_date)  AS overdue_capa_count,
       (SELECT count(*) FROM keystone.event_declarations d WHERE d.event_id = e.id AND d.sent_at IS NULL) AS pending_declaration_count,
       (SELECT min(d.due_at) FROM keystone.event_declarations d WHERE d.event_id = e.id AND d.sent_at IS NULL) AS next_declaration_due,
       CASE WHEN NOT EXISTS (SELECT 1 FROM keystone.investigations i WHERE i.event_id = e.id) THEN 'none'
            WHEN EXISTS (SELECT 1 FROM keystone.investigations i WHERE i.event_id = e.id AND i.completed_at IS NULL) THEN 'in_progress'
            WHEN EXISTS (SELECT 1 FROM keystone.investigations i WHERE i.event_id = e.id AND i.approved_at IS NULL) THEN 'completed'
            ELSE 'approved' END                                                              AS investigation_state
FROM keystone.hsse_events e
WHERE e.deleted_at IS NULL;

-- AnnexeC_HSSE#11
CREATE TABLE keystone.bowtie_nodes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  investigation_id uuid NOT NULL REFERENCES keystone.investigations(id) ON DELETE CASCADE,
  node_type keystone.bowtie_node_type NOT NULL,
  label text NOT NULL,
  linked_threat_id uuid REFERENCES keystone.bowtie_nodes(id),
  barrier_status keystone.barrier_status,
  capa_id uuid REFERENCES keystone.capa_actions(id),
  CONSTRAINT ck_bt_barrier CHECK (node_type IN ('barrier_prev','barrier_recov') OR barrier_status IS NULL)
);

-- AnnexeC_HSSE_Partie3#2
CREATE TABLE keystone.inspection_template_items (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  template_id uuid NOT NULL REFERENCES keystone.inspection_templates(id) ON DELETE CASCADE,
  section_label text NOT NULL, position int NOT NULL,
  label text NOT NULL, help text,
  answer_type keystone.answer_type NOT NULL,
  weight int CHECK (weight BETWEEN 1 AND 5),
  is_critical boolean NOT NULL DEFAULT false,
  photo_rule keystone.photo_rule NOT NULL DEFAULT 'optional',
  default_nc_action keystone.nc_action NOT NULL DEFAULT 'none',
  requirement_id uuid REFERENCES keystone.compliance_requirements(id),
  pm_task_checkpoint_id uuid REFERENCES keystone.pm_task_checkpoints(id),   -- Annexe B, point de contrôle de gamme
  expected_value numeric(14,4), min_value numeric(14,4), max_value numeric(14,4), unit text,
  choices jsonb,
  CONSTRAINT ck_iti_measure CHECK (answer_type <> 'measure' OR unit IS NOT NULL),
  CONSTRAINT ck_iti_bounds CHECK (min_value IS NULL OR max_value IS NULL OR min_value <= max_value)
);

-- AnnexeC_HSSE_Partie3#2
CREATE INDEX ix_iti ON keystone.inspection_template_items (template_id, position);

-- AnnexeC_HSSE_Partie3#2
CREATE TABLE keystone.inspection_answers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  inspection_id uuid NOT NULL REFERENCES keystone.inspections(id) ON DELETE CASCADE,
  item_id uuid REFERENCES keystone.inspection_template_items(id),
  adhoc_label text,                         -- question saisie au fil d'une inspection ad hoc sans modèle
  value_text text, value_numeric numeric(14,4), value_bool boolean,
  is_conform boolean,                       -- NULL si « Sans objet »
  na_reason text, comment text,
  photo_document_ids uuid[] NOT NULL DEFAULT '{}',   -- référence logique, trigger tg_check_document_ids (C.0.1)
  created_work_order_id uuid REFERENCES keystone.work_orders(id),
  created_capa_id uuid REFERENCES keystone.capa_actions(id),
  no_action_reason text,
  answered_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_ia_q CHECK (item_id IS NOT NULL OR adhoc_label IS NOT NULL),
  CONSTRAINT ck_ia_na CHECK (is_conform IS NOT NULL OR na_reason IS NOT NULL),
  CONSTRAINT ck_ia_nc CHECK (is_conform IS DISTINCT FROM false OR comment IS NOT NULL),
  UNIQUE NULLS DISTINCT (inspection_id, item_id)
);

-- AnnexeC_HSSE_Partie3#4
CREATE TABLE keystone.audit_criteria (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  audit_id uuid NOT NULL REFERENCES keystone.audits(id) ON DELETE CASCADE,
  requirement_id uuid NOT NULL REFERENCES keystone.compliance_requirements(id),
  UNIQUE (audit_id, requirement_id)
);

-- AnnexeC_HSSE_Partie3#4
CREATE TABLE keystone.audit_findings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
tenant_id   uuid NOT NULL REFERENCES atlas_core.tenants(id) ON DELETE RESTRICT,
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid,          -- auth.uid(), nul pour le service
updated_by  uuid,
deleted_at  timestamptz,
  audit_id uuid NOT NULL REFERENCES keystone.audits(id) ON DELETE CASCADE,
  origin keystone.record_origin NOT NULL DEFAULT 'planned',
  severity keystone.finding_severity NOT NULL,
  requirement_id uuid REFERENCES keystone.compliance_requirements(id),
  statement text NOT NULL,
  evidence text,                            -- preuve objective (§6.4.7), pièces par doc_links (Annexe G)
  location_id uuid REFERENCES keystone.locations(id), process text,
  auditee_id uuid REFERENCES keystone.persons(id),
  capa_id uuid REFERENCES keystone.capa_actions(id),
  status keystone.finding_status NOT NULL DEFAULT 'open',
  closed_at timestamptz,
  CONSTRAINT ck_af_nc CHECK (severity NOT IN ('nc_major','nc_minor') OR (requirement_id IS NOT NULL AND evidence IS NOT NULL))
);

-- AnnexeC_HSSE_Partie3#4
CREATE INDEX ix_af_open ON keystone.audit_findings (tenant_id, status) WHERE status <> 'closed';

-- AnnexeC_HSSE#15
CREATE VIEW keystone.v_capa_list WITH (security_invoker = true) AS
SELECT c.*, (c.status IN ('open','in_progress','reopened') AND c.due_date < current_date) AS is_overdue,
       COALESCE(ev.ref, au.ref, ins.ref, rr.ref) AS source_ref, e.ref AS event_ref, rc.statement AS root_cause_statement
FROM keystone.capa_actions c
LEFT JOIN keystone.hsse_events e   ON e.id = c.event_id
LEFT JOIN keystone.hsse_events ev  ON c.source = 'event' AND ev.id = c.source_id
LEFT JOIN keystone.audit_findings af ON c.source = 'audit' AND af.id = c.source_id
LEFT JOIN keystone.audits au       ON au.id = af.audit_id
LEFT JOIN keystone.inspections ins ON c.source = 'inspection' AND ins.id = c.source_id
LEFT JOIN keystone.risk_register rr ON c.source = 'risk' AND rr.id = c.source_id
LEFT JOIN keystone.root_causes rc  ON rc.id = c.root_cause_id
WHERE c.deleted_at IS NULL;

COMMIT;
