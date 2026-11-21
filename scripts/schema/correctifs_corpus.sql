-- Correctifs du corpus (lot 0) : objets employés par les annexes mais jamais créés.
-- Appliqués après supabase_stubs.sql et avant les annexes, sur une base de TEST seulement.
-- Chaque correctif renvoie à la cause du rapport docs/lot0/Rapport_ecarts_base_annexes.md §6.1 et à sa source.
-- Statut : en attente de report au Registre et dans l'annexe propriétaire par Oss53pa. Aucune valeur inventée :
-- valeurs prises dans le corpus [Confirmé] ou dans la base actuelle, issue des migrations 01 à 25 [Probable].

-- C00, cause 1 : schémas jamais créés par le corpus [Confirmé].
CREATE SCHEMA IF NOT EXISTS atlas_core;
CREATE SCHEMA IF NOT EXISTS atlas_public;
CREATE SCHEMA IF NOT EXISTS keystone;

-- C01, cause 2 : type de la déclinaison. Propriétaire et nom : Référentiels transverses §1 (atlas_core.operating_mode) ;
-- valeurs : Annexe CO, bloc 1 (commentaire « ('in_house','fm_provider') ») [Confirmé].
-- Décision d'Oss53pa (21/11/2026) : atlas_core.operating_mode fait foi ; l'Annexe CO, qui emploie keystone.operating_mode,
-- est à corriger. Alias par domaine en attendant, à supprimer ensuite.
CREATE TYPE atlas_core.operating_mode AS ENUM ('in_house', 'fm_provider');
CREATE DOMAIN keystone.operating_mode AS atlas_core.operating_mode;

-- C02, cause 3 : types attribués aux Annexes C, D, R par les Référentiels transverses (§1) sans CREATE TYPE dans le corpus.
-- [Confirmé] : valeurs écrites dans le corpus (Annexe C, matrices ; Référentiels transverses, tableau des propriétaires).
CREATE TYPE keystone.capa_status AS ENUM ('open','in_progress','done','verifying','closed','reopened','cancelled');           -- Annexe C, A43
CREATE TYPE keystone.event_status AS ENUM ('reported','triage','under_investigation','capa_defined','closed','rejected');       -- Annexe C
CREATE TYPE keystone.inspection_status AS ENUM ('scheduled','in_progress','completed','overdue','cancelled');                  -- Annexe C, A51
CREATE TYPE keystone.ticket_status AS ENUM ('new','triage','assigned','in_progress','resolved','closed','reopened','rejected','cancelled'); -- A53
CREATE TYPE keystone.control_result AS ENUM ('conform','conform_with_reserves','non_conform');                                -- Annexe R
-- [Probable] : renvoi à « valeurs de l'Annexe C » sans liste écrite ; valeurs de la base actuelle (migrations 01 à 25).
CREATE TYPE keystone.capa_type AS ENUM ('corrective','preventive');
CREATE TYPE keystone.control_hierarchy AS ENUM ('elimination','substitution','engineering','administrative','ppe');
CREATE TYPE keystone.identifier_type AS ENUM ('qr','barcode','nfc','rfid');
CREATE TYPE keystone.investigation_method AS ENUM ('five_why','ishikawa','bowtie','fault_tree');
CREATE TYPE keystone.permit_status AS ENUM ('draft','requested','approved','active','suspended','closed','cancelled');
-- hsse_event_type : ancien keystone.event_type plus good_practice (Référentiels transverses §1.3, A25) [Probable].
CREATE TYPE keystone.hsse_event_type AS ENUM ('near_miss','incident','accident','dangerous_situation','env_spill','security_event','good_practice');

-- C03, cause 3 : types dont les valeurs figurent en texte dans le corpus [Confirmé].
CREATE TYPE keystone.vendor_status AS ENUM ('prospect','active','under_watch','suspended','blacklisted');   -- Référentiels transverses, D14
CREATE TYPE keystone.sla_clock AS ENUM ('response','resolution','client');                                  -- Annexe B
CREATE TYPE keystone.presence_source AS ENUM ('gps','scan','beacon','work_order','manual');                 -- Annexe S

-- C15, cause 3 : rôle de base de l'IA, Annexe C (« le rôle de base proph3t_reader utilisé par PROPH3T ») [Confirmé].
DO $$ BEGIN CREATE ROLE proph3t_reader NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- C13, cause 3 : registre des schémas JSON, décrit en prose (Annexe M §M.2 : « keystone.json_schemas(id text PRIMARY KEY,
-- schema json NOT NULL, version integer NOT NULL) et lus par keystone.json_schema(p_id text) RETURNS json (STABLE) ») [Confirmé].
CREATE TABLE keystone.json_schemas (id text PRIMARY KEY, schema json NOT NULL, version integer NOT NULL);
CREATE FUNCTION keystone.json_schema(p_id text) RETURNS json LANGUAGE sql STABLE AS $$ SELECT schema FROM keystone.json_schemas WHERE id = p_id $$;

-- Restent sans définition, valeurs absentes du corpus : keystone.sla_pause_reason (liste tronquée en Annexe M),
-- keystone.risk_assessments (table employée par l'Annexe C partie 2), keystone.compute_meter_consumption_daily(),
-- keystone.processing_activities (renvoi PD1 §10.2). À compléter par Oss53pa dans l'annexe propriétaire.
