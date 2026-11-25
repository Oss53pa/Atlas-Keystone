# Recette du schéma v2 sur base locale (24/11/2026)

## 1. Ce qui a été fait

Le schéma candidat n'avait jamais été appliqué dans cette session. Il l'est maintenant sur une base Postgres locale et jetable, sans aucune ressource payante (CLAUDE.md règle 5) et sans toucher la base Supabase partagée (règle 4).

```bash
bash scripts/schema/base_locale.sh keystone_test
```

Le script installe ce qui manque dans le conteneur (PostgreSQL 16, PostGIS 3.4 et pgvector 0.6 depuis l'archive Ubuntu, `psycopg` 3), démarre la grappe locale, recrée la base et applique l'ordre de `supabase/candidates/README.md`, puis les recettes.

| Étape | Résultat |
|---|---|
| `supabase_stubs.sql` | appliqué |
| `correctifs_corpus.sql` | appliqué |
| `keystone_v2_schema.sql` | appliqué, 0 erreur |
| `keystone_v2_error_codes.sql` | 623 codes |
| `keystone_v2_seed_reference.sql` | appliqué |
| `conventions_socle.sql` | appliqué |
| `rls_lecture.sql` | appliqué |
| `recette_socle.sql` | passe (2 refus attendus : intrusion inter-client, écriture de l'audit) |
| `recette_permissions.sql` | passe |
| `recette_profils.sql` | passe, 12 assertions sur 12 |

État de la base : **566 tables** (plus 7 tables partitionnées), **508 avec RLS**, **91 fonctions** dans `keystone`, **623 codes d'erreur**.

Réserve [Confirmé] : `pg_jsonschema` n'existe pas hors Supabase ; `supabase_stubs.sql` le remplace par une fonction qui accepte tout. Les contraintes `CHECK` de validation JSON ne sont donc pas éprouvées ici. PostGIS 3.4 et pgvector 0.6 de l'archive Ubuntu ne sont pas forcément les versions de Supabase.

Correctif apporté : `recette_profils.sql` s'arrêtait à la 2ᵉ assertion sous `-v ON_ERROR_STOP=1` (ses cas négatifs n'étaient pas encadrés, contrairement à `recette_socle.sql`). Les trois blocs attendus en échec sont désormais encadrés par `\set ON_ERROR_STOP off`.

## 2. Écart de cloisonnement : 53 tables lisibles sans filtre par client

[Confirmé] sur la base locale (`scripts/schema/recette_cloisonnement.sql`) : 53 tables ont `SELECT` accordé à `authenticated`, **aucune politique RLS** et **aucune colonne `tenant_id`**. Aucune table *portant* `tenant_id` n'est dépourvue de RLS : le cloisonnement direct est complet, c'est le cloisonnement **indirect** qui manque. Aucune table n'est lisible par `anon`.

### 2.1 Tables filles d'un parent cloisonné — 31 tables

Le parent porte `tenant_id` et sa politique d'isolation ; la fille n'a ni l'un ni l'autre. PostgREST exposant chaque table, un compte connecté du client B lit les lignes du client A en interrogeant la fille directement. Exemple : `announcement_reads` (qui a lu quelle annonce, et quand) et `fitout_reserves` (réserves de travaux, descriptions, photos, valideurs).

| Table | Parent(s) cloisonné(s) |
|---|---|
| `announcement_reads` | `site_announcements` |
| `announcement_targets` | `site_announcements` |
| `area_class_bases` | `area_classes` |
| `atelier_draft_spaces` | `atelier_drafts`, `spaces` |
| `atelier_operations` | `atelier_drafts` |
| `atelier_queue` | `atelier_drafts` |
| `booking_services` | `space_bookings` |
| `email_template_versions` | `email_templates` |
| `fitout_conditions` | `fitout_contractors`, `fitout_requests`, `fitout_visas` |
| `fitout_contractors` | `fitout_requests`, `vendors` |
| `fitout_documents` | `fitout_contractors`, `fitout_requests` |
| `fitout_inspections` | `fitout_requests` |
| `fitout_request_spaces` | `fitout_requests`, `spaces` |
| `fitout_reserves` | `fitout_inspections`, `fitout_requests` |
| `fitout_status_history` | `fitout_requests` |
| `fitout_visas` | `fitout_requests` |
| `move_items` | `assets`, `move_requests` |
| `move_lines` | `move_requests` |
| `move_work_orders` | `move_requests`, `work_orders` |
| `parking_tariff_bands` | `parking_tariffs` |
| `patrol_route_checkpoints` | `checkpoints`, `patrol_routes` |
| `physical_access_review_items` | `access_rights`, `physical_access_reviews` |
| `qc_reworks` | `qc_scores`, `work_orders` |
| `qc_samples` | `qc_scores`, `spaces` |
| `scenario_occupancies` | `scenario_space_units`, `space_scenarios` |
| `scenario_space_units` | `space_scenarios` |
| `sector_parts` | `sectors` |
| `sector_spaces` | `sectors`, `spaces` |
| `security_log_persons` | `security_log` |
| `space_chargeback_lines` | `occupant_organizations`, `space_chargebacks` |
| `space_demand_forecasts` | `space_scenarios` |

Correctif attendu, à valider par Oss53pa : politique `USING (EXISTS (SELECT 1 FROM <parent> p WHERE p.id = <fk> AND p.tenant_id = keystone.current_tenant()))`, ou `tenant_id` dénormalisé si la fiche du lot le prévoit. C'est une décision de schéma : elle appartient au prochain lot de structure, pas aux écrans.

### 2.2 Chaînes ouvertes — 2 tables

La fille n'a pas de RLS et son parent non plus :

- `bulk_action_catalog` → `permissions`
- `qc_sample_findings` → `qc_samples`

### 2.3 Tables sans clé étrangère, à arbitrer — 4 tables

- `audit_personal_fields` : champs du schéma marqués « donnée personnelle » : cartographie RGPD de toutes les applications Atlas Studio
- `i18n_missing_keys` : clés de traduction manquantes relevées à l'exécution : révèle les écrans et les parcours des autres clients
- `platform_event_offsets` : curseurs de consommation des flux d'événements : état interne de la plate-forme
- `subprocessors` : sous-traitants de la plate-forme : liste contractuelle, diffusion à décider (PD1)

### 2.4 Référentiels partagés — 16 tables, lecture ouverte probablement assumée

`ai_models`, `api_scopes`, `compliance_frameworks`, `doc_entity_types`, `error_codes`, `guided_tours`, `iso14224_class_modes`, `iso14224_codes`, `json_schemas`, `notification_event_catalog`, `payment_handlers`, `permissions`, `refrigerants`, `setting_definitions`, `undo_action_catalog`, `usage_event_catalog`.

À confirmer une fois pour toutes dans `docs/lot1/Socle_back_end.md` plutôt que table par table.

## 2.5 Écart de cloisonnement sur les vues — 12 vues sur 40, fuite **prouvée**

Les écrans lisent des vues, pas des tables. Or une vue appartient à `postgres` (superutilisateur) : sans
`security_invoker=true`, elle lit ses tables **avec les droits du propriétaire, donc sans leur RLS**. Le cloisonnement
doit alors venir d'un filtre écrit dans la vue. Sur les 40 vues lisibles par `authenticated` : 21 portent
`security_invoker=true`, 8 portent un filtre `current_tenant()` — et **12 n'ont ni l'un ni l'autre**.

Démonstration sur la base locale, deux clients et un actif chacun, jeton du client A :

```
A sur keystone.assets (table, RLS)  : rien
A sur keystone.v_assets_fleet (vue) : Groupe froid du client A | Groupe froid du client B
```

[Confirmé] La table refuse, la vue livre les deux clients. Les 12 vues concernées et les tables cloisonnées
qu'elles contournent :

| Vue | Tables RLS contournées |
|---|---|
| `agent_actions` | `agent_runs` |
| `hsse_rates_monthly_v` | `hsse_events`, `worked_hours` |
| `sensor_streams` | `iot_devices`, `iot_readings` |
| `v_asset_life` | `asset_categories`, `assets` |
| `v_asset_missing_docs` | `asset_category_required_docs`, `assets`, `doc_links`, `ged_documents` |
| `v_asset_stop_impact` | `asset_served_spaces`, `space_occupancies` |
| `v_assets_fleet` | `assets` |
| `v_client_security_kpis` | `service_contract_scope`, `service_contracts` |
| `v_headcount_missing` | `atlas_core.buildings`, `levels`, `occupant_headcount`, `space_occupancies`, `spaces` |
| `v_vendor_work_orders` | `work_orders` |
| `v_wo_templates_for_site` | `site_ext`, `wo_templates` |
| `vendor_safety_events_v` | `hsse_events` |

Deux aggravations : `hsse_rates_monthly_v` et `vendor_safety_events_v` exposent les événements HSSE, dont les données
de santé que la seconde passe des modules réservait à `event.medical_read` ; `v_vendor_work_orders` et
`v_client_security_kpis` filtrent par contrat ou par prestataire mais jamais par client.

Le modèle correct existe déjà dans le schéma : `keystone.sites` est une vue `security_barrier` avec
`WHERE s.tenant_id = current_tenant() AND site_in_scope(s.id)`, ce qui lui permet de lire `atlas_core` sans accorder
`USAGE` sur ce schéma au rôle `authenticated` (vérifié : `authenticated` n'a pas ce droit). Les 12 vues ci-dessus
doivent recevoir soit ce filtre, soit `security_invoker=true` quand la table lue est dans `keystone`. C'est une
décision de schéma, à grouper avec les 31 tables filles dans le même lot de structure.

## 2.6 Écriture inter-client par les vues — prouvée aussi

Les **40** vues ont `INSERT`, `UPDATE` et `DELETE` accordés à `authenticated`, **aucune** avec `WITH CHECK OPTION`,
dont **19** sans `security_invoker=true`. Pour ces 19, l'écriture passe avec les droits du propriétaire `postgres` :
ni la RLS de la table visée, ni le périmètre de la vue ne s'appliquent.

Démonstration sur la base locale, un actif du client B, jeton du client A :

```
lignes du client B modifiees par un jeton du client A : 1
lignes du client B supprimees : 1
```

[Confirmé] Un compte connecté du client A renomme puis supprime l'actif du client B par
`keystone.v_assets_fleet`. C'est plus grave que la lecture : c'est une écriture et une suppression chez un autre
client, sans trace d'intrusion puisque l'opération est légitime du point de vue des droits.

À décider par Oss53pa, dans le même lot de structure : retirer `INSERT`, `UPDATE`, `DELETE` des vues de lecture
(les écrans écrivent par les tables ou par des RPC), et n'accorder l'écriture qu'aux vues que le cahier des charges
désigne comme modifiables, avec `security_invoker=true` et `WITH CHECK OPTION`.

## 3. Écart de partitionnement : 7 tables n'acceptent aucune écriture

[Confirmé] : `keystone_v2_schema.sql` ne contient aucun `PARTITION OF` ni fonction de création de partition, et la base locale compte 0 partition. Un `INSERT` dans ces tables échoue donc avec « no partition of relation found for row » :

`doc_access_log`, `energy_daily_values`, `iot_gateway_logs`, `iot_readings`, `iot_readings_daily`, `iot_readings_hourly`, `usage_events`.

Conséquence directe sur les écrans : l'énergie, les relevés IoT et la trace d'usage alimentent le tableau de bord. Il manque soit les partitions, soit une fonction d'entretien qui les crée, soit une partition par défaut. L'annexe propriétaire est à compléter par Oss53pa avant de brancher ces écrans.

## 4. Reproduire

```bash
bash scripts/schema/base_locale.sh keystone_test
su postgres -c "psql -d keystone_test -f scripts/schema/recette_cloisonnement.sql"
```
