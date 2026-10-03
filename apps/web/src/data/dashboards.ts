/* Données de démonstration pour les dashboards de la Tour de contrôle (Cosmos). */

const C = {
  amber: 'var(--ks-amber)',
  info: 'var(--ks-info)',
  low: 'var(--ks-low)',
  high: 'var(--ks-high)',
  critical: 'var(--ks-critical)',
  ink3: 'var(--ks-ink-3)',
  blue: '#355FD6',
  teal: '#1D9E75',
  purple: '#6E62C8',
};

/* ----------------- Maintenance (Hard FM) ----------------- */
export const MAINT = {
  mtbf: 742, // h
  mttr: 4.6, // h
  availabilityPct: 99.4,
  preventiveShare: 67,
  woTotal: 318,
  slaBreaches: 5,
  woByStatus: [
    { label: 'Brouillon', value: 12, color: C.ink3 },
    { label: 'Planifié', value: 64, color: C.info },
    { label: 'Assigné', value: 41, color: C.purple },
    { label: 'En cours', value: 28, color: C.amber },
    { label: 'Terminé', value: 147, color: C.teal },
    { label: 'Vérifié', value: 26, color: C.low },
  ],
  mix: [
    { label: 'Préventif', value: 142, color: C.low },
    { label: 'Correctif', value: 96, color: C.high },
    { label: 'Conditionnel', value: 48, color: C.info },
    { label: 'Réglementaire', value: 32, color: C.amber },
  ],
  topAssetsCost: [
    { label: 'Groupe froid n°2', value: 4_850_000, sub: 'GF-02' },
    { label: 'Ascenseur A3', value: 3_120_000, sub: 'ASC-A3' },
    { label: 'CTA galerie', value: 2_540_000, sub: 'CTA-GAL' },
    { label: 'Groupe électrogène', value: 1_980_000, sub: 'GE-01' },
    { label: 'Pompe surpression', value: 1_240_000, sub: 'PMP-04' },
  ],
  backlogTrend: [54, 58, 61, 57, 49, 44, 41, 38],
  slaList: [
    { ref: 'OT-10342', title: 'Groupe froid n°2 — fuite fluide', over: '+3 h' },
    { ref: 'OT-10355', title: 'Porte automatique entrée Sud', over: '+1 h' },
    { ref: 'OT-10361', title: 'Éclairage parking −1 secteur B', over: '+2 h' },
  ],
};

/* ----------------- HSSE ----------------- */
export const HSSE = {
  trir: [3.1, 2.9, 2.6, 2.6, 2.4, 2.2, 2.1, 2.0, 1.95, 1.9, 1.85, 1.82],
  ltifr: [6.2, 5.8, 5.4, 5.1, 4.7, 4.3, 4.0, 3.8, 3.6, 3.4, 3.2, 3.1],
  months: ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
  daysWithoutLTI: 47,
  pyramid: [
    { label: 'Accidents avec arrêt', value: 2, color: C.critical },
    { label: 'Accidents sans arrêt', value: 9, color: C.high },
    { label: 'Presque-accidents', value: 38, color: C.amber },
    { label: 'Observations / situations', value: 214, color: C.low },
  ],
  incidentsByType: [
    { label: 'Accident', value: 11, color: C.critical },
    { label: 'Presque-acc.', value: 38, color: C.high },
    { label: 'Environ.', value: 7, color: C.teal },
    { label: 'Sûreté', value: 16, color: C.blue },
    { label: 'Incendie', value: 3, color: C.amber },
  ],
  capaByStatus: [
    { label: 'Ouverte', value: 14, color: C.info },
    { label: 'En cours', value: 21, color: C.amber },
    { label: 'Faite', value: 9, color: C.purple },
    { label: 'Vérifiée', value: 52, color: C.low },
    { label: 'En retard', value: 6, color: C.critical },
  ],
  riskByScope: [
    { label: 'Cosmos Yopougon', value: 58, color: C.high },
    { label: 'Cosmos Angré', value: 44, color: C.amber },
    { label: 'Parking −1', value: 36, color: C.amber },
    { label: 'Locaux techniques', value: 29, color: C.low },
  ],
};

/* ----------------- Conformité & CRP ----------------- */
export const COMPLIANCE = {
  crpRate: 88,
  due: 7,
  overdue: 3,
  crpByType: [
    { label: 'Ascenseurs', conform: 11, total: 14 },
    { label: 'SSI / désenfumage', conform: 8, total: 8 },
    { label: 'Installations élec.', conform: 22, total: 24 },
    { label: 'Levage', conform: 5, total: 6 },
    { label: 'Appareils à pression', conform: 4, total: 4 },
  ],
  reserves: [
    { label: 'Critiques', value: 2, color: C.critical },
    { label: 'Élevées', value: 5, color: C.high },
    { label: 'Moyennes', value: 11, color: C.amber },
  ],
  gedExpiring: [
    { title: 'Assurance décennale — lot CVC', days: 12 },
    { title: 'Habilitation B2V — prestataire Élec+', days: 0 },
    { title: 'Certificat conformité gaz', days: 28 },
    { title: 'Contrat maintenance ascenseurs', days: 45 },
  ],
  iso: [
    { label: 'ISO 45001:2018', value: 84, clauses: '9/11 clauses couvertes' },
    { label: 'ISO 14001:2015', value: 79, clauses: '7/9 clauses couvertes' },
  ],
};

/* ----------------- Budget (OPEX / CAPEX) ----------------- */
export const BUDGET = {
  // montants en francs CFA (unités majeures)
  opex: { budget: 145_000_000, committed: 31_000_000, spent: 76_000_000 },
  capex: { budget: 92_000_000, committed: 24_000_000, spent: 41_000_000 },
  cascade: [
    { label: 'Cosmos Yopougon · CVC', value: 74, color: C.high },
    { label: 'Cosmos Yopougon · Élec', value: 61, color: C.amber },
    { label: 'Cosmos Angré · Fit-out', value: 52, color: C.info },
    { label: 'Soft FM · Propreté', value: 68, color: C.amber },
    { label: 'Sûreté · Gardiennage', value: 80, color: C.high },
  ],
  forecast: [42, 48, 53, 60, 66, 72, 78, 84, 92, 101], // % cumulés, projection après index 6
  forecastProjFrom: 6,
  overruns: [
    { label: 'OPEX maintenance CVC', delta: '+8,2 %' },
    { label: 'Gardiennage renforcé', delta: '+4,1 %' },
  ],
  purchase: [
    { label: 'Demandes d’achat', value: 34, color: C.info },
    { label: 'Bons de commande', value: 21, color: C.amber },
    { label: 'Réceptionnés', value: 16, color: C.low },
  ],
};

/* ----------------- Énergie & Environnement ----------------- */
export const ENV = {
  energyTrend: [318, 332, 341, 355, 372, 389, 401, 388, 372, 360, 351, 366], // MWh
  months: ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
  ytdMwh: 4145,
  intensity: 142, // kWh/m²/an
  emissions: [
    { label: 'Scope 1', value: 180, color: C.high },
    { label: 'Scope 2', value: 620, color: C.amber },
    { label: 'Scope 3', value: 240, color: C.info },
  ],
  waste: [
    { label: 'Valorisés', value: 62, color: C.low },
    { label: 'Enfouis', value: 38, color: C.ink3 },
  ],
  recoveryRate: 62,
  waterM3: 8420,
};
