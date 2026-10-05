/** Types ciblés sur le schéma `keystone` (RPC de démo). Pas les 800 tables de la prod. */

export type WoStatus =
  | 'draft' | 'planned' | 'assigned' | 'in_progress' | 'on_hold' | 'done' | 'verified' | 'cancelled';
export type WoType = 'corrective' | 'preventive' | 'conditional' | 'predictive' | 'regulatory';

export interface WorkOrderRow {
  id: string;
  ref: string;
  title: string;
  type: WoType;
  status: WoStatus;
  priority: number;
  asset_tag: string | null;
  asset_name: string | null;
  location_name: string | null;
  requires_permit: boolean;
  sla_due: string | null;
  planned_start: string | null;
  cost_labor: number;
  cost_parts: number;
}

/** Maintenance prédictive (§10.1) — Sentinelle / PROPH3T. */
export interface PredictionRow {
  id: string; asset_tag: string | null; asset_name: string | null; kind: string | null;
  rul_days: number | null; confidence: number | null; drift_pct: number | null;
  recommended_action: string | null; wo_ref: string | null; wo_status: WoStatus | null; created_at: string;
}

/** Actifs & composants — indice de santé 0..100 explicable (migration 26). */
export type AssetCriticality = 'low' | 'medium' | 'high' | 'safety_critical';
export interface AssetRow {
  id: string; tag: string; name: string; category: string | null; location: string | null; site: string | null;
  criticality: AssetCriticality; status: string; workcenter: string | null; manufacturer: string | null; model: string | null;
  install_date: string | null; warranty_until: string | null; design_life_years: number | null; age_years: number | null;
  replacement_value: number | null; wo_open: number; wo_corrective_12m: number; mtbf_h: number | null; mttr_h: number | null;
  downtime_12m_h: number; cost_12m: number; max_rpn: number | null; fmea_count: number; prediction_rul_days: number | null;
  health: number; health_drivers: Record<string, number>;
}

/** AMDEC (IEC 60812) — RPN = G × O × D ; gravité ≥ 9 ⇒ critique. */
export type FmeaClass = 'critical' | 'high' | 'medium' | 'low';
export type FmeaActionStatus = 'none' | 'planned' | 'in_progress' | 'done';
export interface FmeaRow {
  id: string; asset_id: string; asset_tag: string; asset_name: string; component: string;
  failure_code: string | null; failure_label: string | null; function_lost: string | null; effect: string; cause: string;
  detection_method: string | null; severity: number; occurrence: number; detection: number; rpn: number; class: FmeaClass;
  action: string | null; action_status: FmeaActionStatus; rev_rpn: number | null; rev_class: FmeaClass | null; action_wo_ref: string | null;
}

/** Achats & stocks (migration 27) — circuit DA → BC → réception, TVA 18 % UEMOA. */
export type StockLevel = 'critical' | 'low' | 'warning' | 'ok';
export interface StockRow {
  id: string; ref: string; name: string; category: string; unit: string; warehouse: string | null;
  qty: number; min_qty: number; max_qty: number; reorder_point: number; unit_cost: number | null; stock_value: number;
  is_critical: boolean; lead_time_days: number; supplier: string | null; daily_use: number; days_cover: number | null;
  level: StockLevel; suggested_qty: number; on_order: number;
}
export type PrStatus = 'draft' | 'submitted' | 'tech_approved' | 'budget_approved' | 'approved' | 'rejected' | 'ordered';
export type BudgetCheck = 'OK' | 'LIMIT' | 'OVER' | 'NO_LINE';
export interface PurchaseRequestRow {
  id: string; ref: string; title: string; source: 'manual' | 'stock_alert' | 'work_order' | 'fmea'; urgency: 'normal' | 'urgent' | 'critical';
  status: PrStatus; supplier: string | null; total: number; level: 1 | 2 | 3; budget_status: BudgetCheck; budget_available: number | null;
  lines: number; requested_by_agent: boolean; rejected_reason: string | null; created_at: string; po_ref: string | null;
}
export type PoStatus = 'sent' | 'confirmed' | 'partially_received' | 'received' | 'cancelled';
export interface PurchaseOrderRow {
  id: string; ref: string; pr_ref: string; supplier: string | null; status: PoStatus; amount_ht: number; amount_ttc: number;
  expected_at: string | null; late: boolean; qc_result: 'accepted' | 'accepted_with_reserves' | 'refused' | null; created_at: string;
}
export interface ProcurementSummary {
  stock_value: number; parts: number; alerts: number; critical_alerts: number;
  pr_pending: number; pr_pending_amount: number; po_open: number; po_late: number;
}

/** Énergie & carbone (migration 28) — facteurs versionnés par pays, EnPI kWh/m². */
export interface EnergyMonthly {
  period: string; carrier: string; quantity: number; unit: string; kwh: number; kg_co2e: number; cost: number; validated: boolean;
}
export interface EnergySummary {
  kwh_12m: number; kwh_prev_12m: number; cost_12m: number; t_co2e_12m: number; t_co2e_prev_12m: number;
  scope1_t: number; scope2_t: number; scope3_t: number; refrigerant_t: number; surface_m2: number;
  intensity_kwh_m2: number | null; to_validate: number; indicative_factors: boolean;
}
export type EnergyTargetStatus = 'critical' | 'alert' | 'watch' | 'compliant' | 'no_data';
export interface EnergyTargetRow {
  site: string; carrier: string; unit: string | null; period: string | null; actual: number | null; target: number;
  alert: number; critical: number; status: EnergyTargetStatus; gap_pct: number | null;
}

/** Rondes d'inspection & non-conformités (migration 29) — score pondéré, NC automatiques. */
export type CheckpointType = 'boolean' | 'numeric' | 'choice' | 'text';
export interface Checkpoint {
  key: string; label: string; type: CheckpointType; min?: number; max?: number; unit?: string;
  options?: string[]; fail_options?: string[]; required?: boolean; critical?: boolean;
}
export interface InspectionRound {
  template_id: string; name: string; domain: 'technique' | 'securite' | 'proprete' | 'environnement'; frequency_days: number;
  location: string | null; asset_tag: string | null; checkpoints: Checkpoint[]; requires_signature: boolean;
  last_done: string | null; last_score: number | null; next_due: string; days_to_due: number;
}
export interface InspectionHistoryRow {
  id: string; ref: string; template: string; domain: string; inspector: string | null; score: number | null; failed: number; completed_at: string;
}
export type NcStatus = 'open' | 'in_progress' | 'pending_validation' | 'closed' | 'rejected';
export type NcSeverity = 'minor' | 'major' | 'critical';
export interface NcRow {
  id: string; ref: string; title: string; type: string; severity: NcSeverity; status: NcStatus; source: string;
  location: string | null; asset_tag: string | null; observed_value: string | null; root_cause: string | null;
  corrective_action: string | null; due_date: string; overdue: boolean; wo_ref: string | null; inspection_ref: string | null; created_at: string;
}
export interface QualitySummary {
  score_30d: number | null; rounds_30d: number; rounds_overdue: number; nc_open: number; nc_critical: number;
  nc_overdue: number; nc_closed_on_time_pct: number | null;
}
export interface InspectionResult { ref: string; score: number | null; failed: number; nc_created: number; wo_created: number }

/** Bibliothèque de modes de défaillance & Pareto des pannes (migration 30). */
export interface FailureFamily { family: string; family_label: string; modes: number; max_severity: number }
export type ParetoCriterion = 'frequency' | 'cost' | 'downtime';
export interface ParetoRow {
  asset_id: string; asset_tag: string; asset_name: string; failures: number; cost: number; downtime_h: number;
  value: number; pct: number; cumulative_pct: number; in_vital_few: boolean; mtbf_h: number | null; mttr_h: number | null;
  availability_pct: number | null; class: 'critical' | 'major' | 'minor';
}

/** SLA mesurés & évaluation prestataires (migration 31) — score = 60 % SLA + 40 % grille pondérée. */
export interface SlaMeasure {
  contractor_id: string; contractor: string; contract_id: string; sla_id: string; label: string; metric: string; unit: string;
  target: number; achieved: number | null; samples: number; compliant: boolean | null; attainment: number | null;
  weight: number; overrun: number; penalty: number; lower_is_better: boolean;
}
export interface ContractorScorecard {
  contractor_id: string; contractor: string; scope: string | null; contract_end: string | null; days_to_end: number | null;
  renewal_due: boolean; auto_renewal: boolean; sla_count: number; sla_compliant: number; sla_score: number | null;
  qualitative: number | null; global_score: number | null; last_eval: string | null;
  penalty_raw: number; penalty_cap: number; penalty: number; grade: 'A' | 'B' | 'C' | 'D' | '—';
}
export type EvalCriterion = 'quality' | 'timing' | 'communication' | 'innovation' | 'cost' | 'reliability';

/** Gammes préventives AFNOR NF X60-000 (migration 32). */
export type PmStatus = 'overdue' | 'due' | 'scheduled' | 'ok';
export interface PmPlanRow {
  id: string; name: string; asset_tag: string | null; asset_name: string | null; afnor_level: number | null; level_label: string | null;
  executor_kind: 'operator' | 'internal' | 'contractor'; contractor: string | null; interval_days: number; estimated_hours: number;
  steps: number; critical_steps: number; regulatory: boolean; last_done: string | null; next_due: string; days_to_due: number;
  status: PmStatus; open_wo_ref: string | null; done_12m: number; on_time_12m: number;
}
export interface PmStep {
  seq: number; label: string; duration_min: number; is_critical: boolean; acceptance: string | null;
  checkpoint: { type: string; min?: number; max?: number; unit?: string } | null;
}
export interface PmWorkloadRow { week: string; internal_h: number; contractor_h: number; operator_h: number; capacity_h: number }
export interface PmSummary { plans: number; overdue: number; due: number; scheduled: number; compliance_pct: number | null; hours_per_year: number }

/** Registre déchets (migration 33) — BSD obligatoire pour dangereux/DEEE. */
export type WasteStream = 'paper' | 'plastic' | 'dib' | 'dangerous' | 'organic' | 'glass' | 'metal' | 'electronic';
export type WasteTreatment = 'recycling' | 'valorization' | 'reuse' | 'elimination';
export interface WasteRow {
  id: string; collected_on: string; site: string; stream: WasteStream; treatment: WasteTreatment; quantity_kg: number; operator: string | null;
  bsd_ref: string | null; certificate_ref: string | null; source: string; cost: number | null; validated: boolean; kg_co2e: number; missing_certificate: boolean;
}
export interface WasteMonthly { period: string; total_kg: number; valorized_kg: number; eliminated_kg: number; dangerous_kg: number; valorization_pct: number | null }
export interface WasteSummary {
  total_t_ytd: number; total_t_prev_ytd: number; valorization_pct: number | null; dangerous_t_ytd: number; t_co2e_ytd: number;
  cost_ytd: number; missing_certificates: number; operators_expiring: number;
}
export interface WasteObjective { kind: string; label: string; target: number; actual: number | null; status: 'achieved' | 'on_track' | 'at_risk' | 'failed' | 'no_data' }

/** Portail prestataire (migration 34). */
export interface PortalRow {
  wo_id: string; wo_ref: string; title: string; type: string; status: WoStatus; priority: number; contractor_id: string; contractor: string;
  asset_tag: string | null; location: string | null; created_at: string; sla_due: string | null;
  quote_id: string | null; quote_ref: string | null; quote_status: 'submitted' | 'approved' | 'rejected' | null; quote_total: number | null;
  variations_pending: number; variations_total: number; report_id: string | null; report_status: 'submitted' | 'validated' | 'rejected' | null;
  anomalies: number; elapsed_h: number; paused_h: number; pending_pause_h: number; paused_now: boolean;
  open_pause_id: string | null; open_pause_reason: string | null;
}
export interface PortalDetail {
  quote_items: { kind: string; label: string; qty: number; unit_price: number; total: number }[] | null;
  variations: { id: string; reason: string; extra_cost: number; extra_hours: number; status: 'pending' | 'approved' | 'escalated' | 'rejected' }[] | null;
  report: {
    id: string; summary: string; technician: string; before: string[]; after: string[]; status: string; client_signed_by: string | null;
    anomalies: { severity: 'minor' | 'major' | 'critical'; description: string; follow_up: string | null }[] | null;
  } | null;
  pauses: { id: string; reason: string; started_at: string; ended_at: string | null; justified: boolean | null }[] | null;
}

/** Baux, loyers & portail locataire (migration 38). */
export interface RentRollRow {
  lease_id: string; ref: string; lessee_id: string; lessee: string; trade_name: string | null; sector: string | null; site: string;
  spaces: string | null; area_m2: number; monthly_rent: number; rent_m2_month: number | null; charges_provision: number;
  start_date: string; end_date: string | null; months_left: number | null; status: 'active' | 'notice' | string;
  next_indexation_date: string | null; indexation_due: boolean; arrears: number; arrears_days: number | null; open_tickets: number;
}
export interface RentSummary {
  leases: number; gla_m2: number; leased_m2: number; occupancy_pct: number | null; monthly_rent: number; annual_rent: number;
  avg_rent_m2: number | null; walt_years: number | null; collection_pct: number | null; arrears_total: number; arrears_lessees: number;
  expiring_12m: number; indexation_due: number; deposits: number;
}
export type ArrearsBucket = '0-30' | '31-60' | '61-90' | '90+';
export interface ArrearsRow {
  schedule_id: string; lease_ref: string; lessee: string; period: string; due_date: string; total_due: number; paid: number; balance: number;
  days_late: number; bucket: ArrearsBucket; reminders_sent: number; last_reminder_at: string | null; contact_phone: string | null;
}
export type ScheduleStatus = 'paid' | 'partial' | 'partial_overdue' | 'overdue' | 'pending';
export interface ScheduleRow {
  schedule_id: string; lease_ref: string; lessee_id: string; lessee: string; period: string; due_date: string; rent: number; charges: number;
  vat: number; total_due: number; paid: number; status: ScheduleStatus; last_payment_at: string | null; last_method: string | null;
}
export interface ChargeRegRow {
  lease_id: string; lease_ref: string; lessee: string; site: string; weighted_m2: number; share_pct: number; real_charges: number;
  provisions_billed: number; balance: number;
}
export interface RentReceipt {
  number: string; site: string; lessee: string; trade_name: string | null; rccm: string | null; lease_ref: string; spaces: string | null;
  period_start: string; period_end: string; rent: number; charges: number; vat: number; vat_rate: number; total: number;
  payments: { amount: number; method: string; ref: string | null; at: string }[] | null; issued_at: string;
}
export interface NewsItem { id: string; site?: string; kind: 'info' | 'event' | 'maintenance' | 'safety'; title: string; body: string | null; event_date: string | null; published_at: string }
export interface LesseeHome {
  is_lessee: boolean;
  lessee: { id: string; name: string; trade_name: string | null; contact: string | null };
  site: string | null;
  leases: {
    id: string; ref: string; start: string; end: string | null; rent: number; charges: number; vat_rate: number; payment_day: number; deposit: number;
    next_indexation: string | null; indexation_type: string; indexation_rate: number | null;
    spaces: { code: string; name: string | null; m2: number }[] | null;
  }[] | null;
  balance: number;
  next_due: { id: string; due_date: string; amount: number } | null;
  schedules: { id: string; period: string; due_date: string; total_due: number; paid_amount: number; status: ScheduleStatus }[] | null;
  tickets: {
    id: string; ref: string; category: string | null; description: string | null; status: TicketStatus; priority: number; created_at: string;
    resolved_at: string | null; satisfaction: number | null; sla_due: string | null; last_message: { body: string; at: string } | null; messages: number;
  }[] | null;
  news: NewsItem[] | null;
  contacts: { emergency_phone: string | null; management_email: string | null; management_phone: string | null; reception: string | null } | null;
}

/** Notifications multicanal (migration 39). */
export type NotifChannel = 'whatsapp' | 'sms' | 'email' | 'in_app';
export type NotifAudience = 'lessee' | 'contractor' | 'staff' | 'requester';
export type NotifStatus = 'queued' | 'deferred' | 'sent' | 'failed' | 'suppressed';
export interface NotifJournalRow {
  id: string; event_type: string; event_label: string | null; severity: string; entity_ref: string | null; channel: NotifChannel;
  audience: NotifAudience; recipient_label: string | null; address: string | null; subject: string | null; body: string;
  status: NotifStatus; status_reason: string | null; scheduled_for: string; sent_at: string | null; provider_ref: string | null; created_at: string;
}
export interface NotifStats {
  sent_24h: number; queued: number; deferred: number; suppressed_24h: number; failed_24h: number;
  by_channel: Partial<Record<NotifChannel, number>> | null; live_channels: number;
}
export interface NotifMatrixRow {
  rule_id: string; event_type: string; label: string; domain: string; default_severity: string; channel: NotifChannel;
  audience: NotifAudience; is_enabled: boolean; has_template: boolean;
}
export interface NotifChannelConfig { channel: NotifChannel; is_enabled: boolean; mode: 'simulation' | 'live'; provider: string | null; sender: string | null }
export interface NotifTemplate {
  id: string; event_type: string; channel: NotifChannel; locale: 'fr' | 'en'; subject: string | null; body: string; wa_template_name: string | null;
}
export interface QuietHours { start_local: string; end_local: string; timezone: string; applies_to: NotifChannel[] }
export interface MyNotification { id: string; kind: string; title: string; body: string | null; ref: string | null; severity: string; created_at: string; read_at: string | null }

/** Exécution terrain & modèles d'OT (migration 40). */
export type StepType = 'check' | 'numeric' | 'photo' | 'text';
export interface ChecklistStep {
  index: number; label: string; type: StepType; min?: number; max?: number; unit?: string; required?: boolean; critical?: boolean;
  value: unknown; ok: boolean | null; done_at: string | null;
}
export interface TechDayRow {
  wo_id: string; ref: string; title: string; type: string; status: WoStatus; priority: number; asset_tag: string | null; asset_name: string | null;
  location: string | null; planned_start: string | null; sla_due: string | null; requires_permit: boolean; permit_active: boolean;
  steps_total: number; steps_done: number; checked_in_at: string | null; template: string | null;
}
export interface TechWoDetail {
  id: string; ref: string; title: string; description: string | null; status: WoStatus; priority: number; type: string;
  asset: { tag: string; name: string; manufacturer: string | null; model: string | null } | null; location: string | null;
  safety: string | null; requires_permit: boolean; permit_active: boolean; checklist: ChecklistStep[]; sla_due: string | null; notes: string | null;
  parts: { id: string; kind: 'part' | 'planned_part'; label: string; qty: number; unit_cost: number | null; part_id: string | null; in_stock: number | null }[] | null;
  time: { kind: string; at: string; distance: number | null }[] | null;
}
export interface AssetScan {
  asset: { id: string; tag: string; name: string; category: string | null; location: string | null; site: string | null; criticality: string;
    status: string; manufacturer: string | null; model: string | null; health: number; mtbf_h: number | null; max_rpn: number | null;
    rul_days: number | null; warranty_until: string | null };
  open_wo: { ref: string; title: string; status: WoStatus; priority: number }[] | null;
  history: { ref: string; title: string; type: string; actual_end: string | null }[] | null;
  top_risk: { component: string; rpn: number; effect: string } | null;
}
export interface WoTemplateRow {
  id: string; name: string; wo_type: string; category: string | null; estimated_minutes: number; requires_permit: boolean;
  steps: Omit<ChecklistStep, 'index' | 'value' | 'ok' | 'done_at'>[]; required_parts: { part_ref: string; qty: number }[];
  safety_instructions: string | null; is_active: boolean; uses: number;
}

/** Documents imprimables & paramétrage société (migration 41). */
export interface CompanyProfile {
  tenant_id?: string; legal_name: string; trade_name: string | null; legal_form: string | null; rccm: string | null; ncc: string | null;
  address: string | null; city: string | null; country: string; phone: string | null; email: string | null; website: string | null;
  bank_name: string | null; bank_account: string | null; payment_terms_days: number; purchase_terms: string | null; document_footer: string | null;
  match_price_tolerance_pct?: number; match_amount_tolerance?: number;
}
export interface ApprovalThreshold { doc_type: string; step: 'budget' | 'direction'; min_amount: number; approver_label: string }
export interface PoDocument {
  company: CompanyProfile | null; ref: string; date: string; expected_at: string | null; status: string; currency: string;
  pr_ref: string; pr_title: string; urgency: string;
  supplier: { name: string; tax_id: string | null; phone: string | null; email: string | null } | null;
  lines: { label: string; qty: number; unit_price: number; total: number; unit: string | null }[] | null;
  amount_ht: number; tax_rate: number; tax: number; amount_ttc: number;
  approvals: Record<'tech' | 'budget' | 'direction', { by: string | null; at: string | null } | null>;
  delivery: string | null;
}
export interface WoDocument {
  company: CompanyProfile | null; ref: string; title: string; description: string | null; type: string; status: string; priority: number;
  created_at: string; planned_start: string | null; actual_start: string | null; actual_end: string | null; sla_due: string | null;
  site: string | null; location: string | null;
  asset: { tag: string; name: string; manufacturer: string | null; model: string | null; serial: string | null } | null;
  assignee: string | null; contractor: string | null; safety: string | null; checklist: ChecklistStep[] | null; notes: string | null;
  signed_by: string | null; verified_by: string | null; verified_at: string | null;
  permit: { ref: string; type: string; status: string } | null;
  lines: { kind: 'part' | 'labor'; label: string; qty: number; unit_cost: number | null; minutes: number | null }[] | null;
  time: { kind: string; at: string; distance: number | null }[] | null;
  cost_labor: number | null; cost_parts: number | null; downtime_hours: number | null; currency: string;
}

export interface DemoSummary {
  wo_total: number;
  wo_open: number;
  wo_overdue: number;
  assets: number;
  crp_overdue: number;
  capa_open: number;
  events_open: number;
}

/* ---------- Tour de contrôle (live, RLS) ---------- */
export interface AttentionLive {
  level: 'critical' | 'high' | 'medium' | 'low';
  domain: string; ref: string; title: string; scope: string; risk: number; detail: string;
}
export interface CockpitSummary {
  wo_open: number; wo_overdue: number; crp_overdue: number;
  capa_open: number; capa_overdue: number; events_open: number; permits_active: number; assets: number;
}

/** Rapport mensuel (agent Reporting §11). */
export interface MonthlyReportPayload {
  period: string; generated_at: string;
  hsse: { events_open: number; accidents: number; near_miss: number; capa_open: number; capa_overdue: number };
  maintenance: { mtbf_hours: number; mttr_hours: number; availability_pct: number; preventive_share_pct: number; sla_compliance_pct: number; wo_total: number };
  compliance: { crp_total: number; crp_overdue: number; crp_conformity_pct: number };
  budget: { opex_available: number; capex_available: number };
  softfm: { realisation_pct: number; qc_avg: number; missed: number };
  tickets: { total: number; open: number; satisfaction: number | null };
  predictive: { open_predictions: number };
  payments: { paid_total: number };
}
export interface MonthlyReport {
  id: string; period: string; status: 'draft' | 'published'; generated_at: string; payload: MonthlyReportPayload;
}

/** Agents autonomes (§11). */
export type AgentDecision = 'auto' | 'proposed' | 'escalated';
export interface AgentAction {
  id: string; agent: string; action_type: string; target_label: string | null;
  decision: AgentDecision; requires_human: boolean; created_at: string;
}
export interface AgentRunResult { relanceur_capa: number; echeancier_crp: number; habilitations: number }

/** CRP — Contrôles réglementaires périodiques (§6.17). */
export type CrpStatus = 'compliant' | 'due' | 'overdue' | 'non_conform';
export interface CrpRow {
  id: string; regime: string; asset_tag: string | null; controller_org: string | null; frequency_months: number;
  last_control_date: string | null; next_due_date: string | null; result: string | null; status: CrpStatus; days_to_due: number | null;
}
export interface CrpSummary {
  total: number; compliant: number; due: number; overdue: number; conformity_pct: number; reserves_open: number;
}

/** Prestataires & paiements (§6.16). */
export type InvoiceStatus = 'draft' | 'submitted' | 'approved' | 'paid' | 'rejected';
export interface ContractorRow {
  id: string; name: string; prequalified: boolean; rating: number | null; mobile_money: boolean;
  certs_total: number; certs_expiring: number; open_invoices: number; paid_amount: number;
}
export interface InvoiceRow {
  id: string; ref: string; contractor_name: string | null; wo_ref: string | null;
  amount: number; status: InvoiceStatus; submitted_at: string | null;
}

/** Soft FM (§6.25) — propreté EN 13549, 3D EN 16636. */
export type ServiceVisitStatus = 'planned' | 'in_progress' | 'done' | 'qc_passed' | 'qc_failed' | 'missed';
export interface SoftVisit {
  id: string; status: ServiceVisitStatus; scheduled_for: string | null; completed_at: string | null;
  qc_score: number | null; service_label: string | null; location_name: string | null;
}
export interface PestLog {
  id: string; intervention_type: string | null; product_used: string | null; dose: string | null;
  operator_name: string | null; at: string;
}
export interface SoftFmSummary {
  visits_total: number; realisation_pct: number; qc_avg: number; missed: number; qc_failed: number; pest_logs: number;
}

/** Space Management (§6.27) — surfaces EN 15221-6, polygones normalisés. */
export type SpaceType = 'tenant_lot' | 'common_area' | 'technical_room' | 'office' | 'circulation' | 'parking' | 'outdoor';
export interface SpaceUnit {
  id: string; code: string; name: string | null; type: SpaceType;
  surface_m2: number | null; status: string; occupant_kind: string | null; is_verified: boolean;
  polygon: number[][] | null;
}
export interface SpaceSummary {
  units: number; surface_total: number; surface_occupee: number; vacants: number; occupation_pct: number;
}

/** Tickets / Helpdesk (§6.14). */
export type TicketStatus = 'new' | 'triaged' | 'assigned' | 'in_progress' | 'resolved' | 'closed' | 'rejected' | 'reopened';
export interface TicketRow {
  id: string; ref: string; channel: string | null; requester_kind: string | null; requester_name: string | null;
  category: string | null; description: string | null; priority: number; status: TicketStatus;
  sla_due: string | null; satisfaction: number | null; work_order_id: string | null; created_at: string;
  asset_tag: string | null; location_name: string | null;
}

/** Budgets OPEX/CAPEX (§6.15) — Disponible = Budget − Engagé − Réalisé. */
export interface BudgetSide {
  budget: number; committed: number; spent: number; available: number; execution_pct: number;
}
export interface BudgetOverview {
  opex?: BudgetSide;
  capex?: BudgetSide;
}

/** Présence terrain temps réel (§6.27). x,y en % du plan (0..100). */
export interface LivePresence {
  person_id: string;
  name: string;
  initials: string;
  x: number;
  y: number;
  status: 'on_wo' | 'on_duty' | 'break' | 'offline' | null;
  task: string;
  at: string;
  space_code: string | null;
  space_name: string | null;
}

/** Posture & score de risque dynamique (§10.4) — déterministe, auditable. */
export interface Posture {
  technique: number; surete: number; conformite: number; budget: number;
  risk_score: number; drivers: Record<string, number>; formula_version: string;
}

/* ---------- HSSE (Annexe C) ---------- */
export type EventType = 'near_miss' | 'incident' | 'accident' | 'dangerous_situation' | 'env_spill' | 'security_event';
export type EventStatus = 'reported' | 'triage' | 'under_investigation' | 'capa_defined' | 'closed' | 'rejected';
export type EventSeverity = 'minor' | 'moderate' | 'serious' | 'major' | 'catastrophic';
export type CapaType = 'corrective' | 'preventive';
export type CapaStatus = 'open' | 'in_progress' | 'done' | 'verifying' | 'closed' | 'reopened' | 'cancelled';
export type ControlLevel = 'elimination' | 'substitution' | 'engineering' | 'administrative' | 'ppe';
export type PermitType = 'hot_work' | 'confined_space' | 'electrical' | 'work_at_height' | 'excavation' | 'lifting' | 'energized' | 'general';
export type PermitStatus = 'draft' | 'requested' | 'approved' | 'active' | 'suspended' | 'closed' | 'cancelled';

export interface HsseEventRow {
  id: string; ref: string; type: EventType; title: string; status: EventStatus;
  severity_potential: EventSeverity | null; risk_score: number | null; location_name: string | null;
  occurred_at: string; is_anonymous: boolean; has_investigation: boolean;
}
export interface CapaRow {
  id: string; ref: string; title: string; type: CapaType; status: CapaStatus;
  source: string; control_level: ControlLevel | null; due_date: string | null; priority: number; is_overdue: boolean;
}
export interface PermitRow {
  id: string; ref: string; type: PermitType; status: PermitStatus; asset_tag: string | null;
  requires_isolation: boolean; isolations: number; isolations_verified: boolean;
  valid_from: string | null; valid_to: string | null;
}
export interface HsseSummary {
  events_open: number; near_miss: number; accidents: number;
  capa_open: number; capa_overdue: number; permits_active: number;
}

/** KPI maintenance normalisés EN 15341 (calculés en base, déterministe). */
export interface MaintKpi {
  window_from: string;
  window_to: string;
  wo_total: number;
  wo_preventive: number;
  wo_corrective: number;
  preventive_share_pct: number;
  mttr_hours: number;
  mtbf_hours: number;
  availability_pct: number;
  sla_compliance_pct: number;
  sla_breaches: number;
}

/** Rapprochement BC / réception / facture fournisseur (migration 42). */
export type SupplierInvoiceStatus = 'to_match' | 'matched' | 'discrepancy' | 'approved' | 'rejected' | 'paid';
export type MatchCode = 'OK' | 'PRICE_UNDER' | 'PRICE_OVER' | 'QTY_OVER_RECEIVED' | 'NOT_RECEIVED' | 'UNORDERED';
export interface SupplierInvoiceRow {
  id: string; ref: string; supplier_ref: string; supplier: string | null; po_id: string; po_ref: string; invoice_date: string; due_date: string;
  amount_ht: number; amount_ttc: number; expected_ht: number | null; variance_ht: number | null; status: SupplierInvoiceStatus;
  issues: string[]; issue_labels: string[]; forced: boolean; overdue: boolean; days_to_due: number;
  approved_at: string | null; paid_at: string | null; decision_comment: string | null; mine: boolean;
}
export interface MatchLine {
  id: string; label: string; po_line_id: string | null; code: MatchCode; ordered: number | null; received: number | null; refused: number | null;
  billed_before: number | null; billable: number; invoiced: number; po_price: number | null; unit_price: number; price_var_pct: number | null; total: number;
}
export interface SupplierInvoiceDetail {
  id: string; ref: string; supplier_ref: string; supplier: string | null; po_ref: string; po_status: string; po_amount_ht: number;
  invoice_date: string; due_date: string; amount_ht: number; tax_rate: number; amount_ttc: number; expected_ht: number | null; variance_ht: number | null;
  status: SupplierInvoiceStatus; forced: boolean; decision_comment: string | null; payment_ref: string | null;
  match: { lines: MatchLine[]; issues: { code: string; label: string }[]; tolerance_pct: number; tolerance_amount: number; at: string } | null;
  receipts: { at: string; qc: string; notes: string | null }[] | null; approved_by: string | null; approved_at: string | null;
}
export interface PoLineStatus {
  id: string; label: string; qty_ordered: number; qty_received: number; qty_refused: number; qty_to_receive: number;
  qty_invoiced: number; qty_to_invoice: number; unit_price: number;
}
export interface ApSummary {
  to_review: number; discrepancies: number; discrepancy_amount: number; to_pay: number; overdue: number; paid_month: number;
  auto_match_rate: number | null; avoided: number; po_to_invoice: number;
}

/** Compteurs, sous-comptage & grilles CIE / SODECI (migration 42). */
export type MeterAnomaly = 'NO_READING' | 'LATE_READING' | 'SPIKE' | 'DROP';
export interface MeterRow {
  id: string; code: string; name: string; site: string; carrier: 'electricity' | 'water'; unit: string; kind: 'main' | 'sub';
  parent_id: string | null; parent_code: string | null; usage: string | null; space_code: string | null; lessee: string | null; lease_id: string | null;
  tariff: string | null; subscribed_kva: number | null; provider_contract: string | null;
  last_read_at: string | null; last_index: number | null; last_qty: number | null; avg_qty: number | null; variation_pct: number | null;
  days_since: number | null; anomaly: MeterAnomaly | null; series: number[];
}
export interface BalanceRow {
  main_id: string; main_code: string; site: string; carrier: string; unit: string; period: string; main_qty: number; sub_qty: number;
  leased_qty: number; common_qty: number; unmetered_qty: number; loss_pct: number | null; status: 'ok' | 'watch' | 'alert' | 'inconsistent' | 'no_data';
}
export interface TariffBreakdown {
  tariff: string; provider: string; name: string; unit: string; qty: number; kva: number | null;
  lines: { label: string; qty: number; unit_price: number; amount: number }[]; energy: number; fixed: number; demand: number;
  levies: { label: string; pct: number; amount: number }[]; ht: number; vat: number; ttc: number; avg_unit: number | null; indicative: boolean; source: string;
}
export interface BillCheckRow {
  site: string; carrier: string; period: string; provider: string; invoiced_qty: number; invoiced_ht: number | null; computed_ht: number;
  variance: number | null; variance_pct: number | null; status: 'ok' | 'watch' | 'alert' | 'no_amount'; breakdown: TariffBreakdown;
}
export interface RebillRow {
  meter_id: string; meter_code: string; carrier: string; unit: string; space_code: string; lease_id: string; lease_ref: string; lessee_id: string; lessee: string;
  qty: number; unit_cost: number | null; amount_ht: number | null; vat_amount: number | null; cost_basis: 'facture' | 'grille'; posted: boolean; schedule_due: string | null;
}
export interface TariffBand { id: string; slot: 'all' | 'offpeak' | 'full' | 'peak'; from_qty: number; to_qty: number | null; unit_price: number; label: string | null }
export interface Tariff {
  id: string; code: string; provider: string; country: string; carrier: 'electricity' | 'water'; name: string; unit: string;
  fixed_monthly: number; demand_charge: number; default_profile: Record<string, number> | null; levies: { label: string; pct: number }[];
  vat_rate: number; valid_from: string; is_indicative: boolean; source: string; meters: number; bands: TariffBand[] | null;
}
export interface UtilitiesSummary {
  meters: number; sub_meters: number; anomalies: number; late_readings: number; elec_loss_pct: number | null; water_loss_pct: number | null;
  bill_alerts: number; bill_overcharge: number; last_period: string | null;
}
