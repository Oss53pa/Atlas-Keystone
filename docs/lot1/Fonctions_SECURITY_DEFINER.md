# Lot 1 : fonctions SECURITY DEFINER exécutables par authenticated

Inventaire de la base de test (conventions appliquées). Une fonction SECURITY DEFINER s’exécute avec les droits de son propriétaire : sans contrôle de permission ni de périmètre, elle contourne la RLS. Classement automatique, à valider.


## 1. Employée par une règle d’accès : garder

- `active_profile()`
- `client_can_see_site(uuid)`
- `current_client()`
- `current_occupant_org()`
- `current_person_id()`
- `current_vendor()`
- `current_vendor_role()`
- `has_permission(text)`
- `site_in_scope(uuid)`
- `user_sites()`

## 2. Contrôle une permission (asset.validate) : garder

- `asset_validate(uuid,timestamp with time zone,text)`

## 2. Contrôle une permission (capa.assign,capa.close,capa.verify) : garder

- `capa_transition(uuid,capa_status,jsonb)`

## 2. Contrôle une permission (client_portal.validate) : garder

- `is_ticket_reporter_or_client(uuid)`

## 2. Contrôle une permission (event.close,event.investigate) : garder

- `event_transition(uuid,event_status,jsonb)`

## 2. Contrôle une permission (event.medical_read) : garder

- `read_event_person_health(uuid)`
- `record_medical_visit(uuid,medical_visit_kind,date,fitness_decision,text,text,date,uuid[])`
- `set_event_person_health(uuid,text,text,care_level,integer,uuid[])`

## 2. Contrôle une permission (permit.activate) : garder

- `permit_activate(uuid,jsonb)`

## 2. Contrôle une permission (scope.all) : garder

- `person_in_scope(uuid)`

## 2. Contrôle une permission (ticket.assign,ticket.resolve) : garder

- `ticket_transition(uuid,ticket_status,jsonb)`

## 2. Contrôle une permission (vendor.penalty) : garder

- `penalty_transition(uuid,penalty_status,text)`

## 3. Lecture du contexte de l’appelant : garder

- `current_client_user()`
- `current_contractor()`
- `current_operating_mode()`
- `current_supplier()`
- `raise_error(text,jsonb)`
- `subscription_access_for(uuid)`
- `tenant_writable()`
- `user_entities()`

## 4. Limitée à l’appelant (profil, prestataire, client), sans permission : à confirmer

- `check_ticket_duplicate(uuid,uuid,uuid,boolean)`
- `consume_part(uuid,numeric,uuid,jsonb)`
- `log_presence_access(uuid)`
- `wo_punch(uuid,wo_punch_action,jsonb)`

## 5. Ni permission ni périmètre détectés : à décider

- `assert_provider_mode()`
- `assert_regulatory_wo_closable(uuid,text)`
- `client_ticket_last_reminder(uuid)`
- `competency_gaps(uuid,uuid[],date,text,uuid)`
- `occupational_health_active()`
- `pr_link_work_order(uuid,uuid)`
- `product_option(text)`
- `sectors_of_location(uuid,text)`
- `site_tz(uuid)`
- `sla_effective_due(timestamp with time zone,uuid,sla_clock)`
- `space_at_local_point(uuid,numeric,numeric)`

## Priorités
- `pr_link_work_order(uuid,uuid)` : **traité** (C21, décision d'Oss53pa du 22/11/2026). Elle était limitée au tenant (`current_tenant()`) mais sans permission ; `purchase.request` est désormais exigée de tout utilisateur connecté, tâches de fond autorisées. Vérifié : refus `PERMISSION_DENIED` sans la permission, accepté avec.
- `consume_part`, `wo_punch` écrivent, limitées à l'appelant (technicien) sans permission explicite : confirmer que le périmètre suffit (Annexe P).
- Les lectures sans contrôle (`client_ticket_last_reminder`, `competency_gaps`, `sectors_of_location`…) contournent la RLS : vérifier qu'elles filtrent par `current_tenant()` avant de les laisser à authenticated.
