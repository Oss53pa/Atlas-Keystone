import type { RiskLevel } from '@keystone/ui';
import { money, type Money } from '@keystone/domain';

export const SITES = ['Tous les sites', 'Cosmos Yopougon', 'Cosmos Angré'];

export interface AttentionItem {
  id: string;
  level: Exclude<RiskLevel, 'info'>;
  domain: string;
  title: string;
  site: string;
  asset?: string;
  riskScore: number;
  age: string;
}

export const ATTENTION: AttentionItem[] = [
  {
    id: 'CRP-2291',
    level: 'critical',
    domain: 'Conformité · CRP',
    title: 'Contrôle réglementaire ascenseur A3 en dépassement (organisme : Veritas)',
    site: 'Cosmos Yopougon',
    asset: 'ASC-A3',
    riskScore: 92,
    age: 'échéance +6 j',
  },
  {
    id: 'INC-0488',
    level: 'critical',
    domain: 'HSSE · Incident',
    title: 'Presque-accident — chute de hauteur signalée au niveau R+3, CAPA non vérifiée',
    site: 'Cosmos Angré',
    riskScore: 88,
    age: 'il y a 2 h',
  },
  {
    id: 'OT-10342',
    level: 'high',
    domain: 'Hard FM · GMAO',
    title: 'OT correctif GTC — groupe froid n°2 hors SLA, escalade responsable technique',
    site: 'Cosmos Yopougon',
    asset: 'GF-02',
    riskScore: 71,
    age: 'SLA +3 h',
  },
  {
    id: 'HAB-115',
    level: 'high',
    domain: 'HSSE · Habilitations',
    title: 'Habilitation électrique B2V de 2 intervenants prestataire expirée',
    site: 'Cosmos Angré',
    riskScore: 64,
    age: 'expirée hier',
  },
  {
    id: 'BUD-CX-07',
    level: 'medium',
    domain: 'Pilotage · Budget',
    title: 'Dépassement projeté ligne OPEX maintenance CVC (+8,2 %) sur l’exercice',
    site: 'Cosmos Yopougon',
    riskScore: 48,
    age: 'tendance 30 j',
  },
  {
    id: 'NRG-221',
    level: 'medium',
    domain: 'Environnement · Énergie',
    title: 'Anomalie de surconsommation détectée sur le sous-comptage galerie marchande',
    site: 'Cosmos Angré',
    riskScore: 41,
    age: 'il y a 40 min',
  },
];

export interface Kpi {
  label: string;
  value: string;
  unit?: string;
  trend: number[];
  delta: string;
  good: boolean;
  color: string;
}

const dispo: Money = money(38_400_000, 'XOF');
export const BUDGET_AVAILABLE = dispo;

export const KPIS: Kpi[] = [
  {
    label: 'TRIR (12 mois glissants)',
    value: '1,82',
    trend: [3.1, 2.9, 2.6, 2.4, 2.2, 2.0, 1.9, 1.82],
    delta: '−14 % vs T-1',
    good: true,
    color: 'var(--ks-low)',
  },
  {
    label: 'Part de préventif',
    value: '67',
    unit: '%',
    trend: [52, 55, 58, 60, 61, 64, 66, 67],
    delta: '+5 pts',
    good: true,
    color: 'var(--ks-amber)',
  },
  {
    label: 'Conformité CRP',
    value: '88',
    unit: '%',
    trend: [95, 94, 93, 92, 90, 89, 88, 88],
    delta: '3 contrôles dus',
    good: false,
    color: 'var(--ks-high)',
  },
  {
    label: 'Budget disponible',
    value: '38,4 M',
    unit: 'FCFA',
    trend: [62, 58, 53, 49, 46, 43, 40, 38],
    delta: 'exéc. 74 %',
    good: true,
    color: 'var(--ks-info)',
  },
];

export interface SiteHealth {
  name: string;
  city: string;
  assets: number;
  technique: number;
  surete: number;
  conformite: number;
  budget: number;
  status: RiskLevel;
}

export const SITE_HEALTH: SiteHealth[] = [
  {
    name: 'Cosmos Yopougon',
    city: 'Abidjan · CI',
    assets: 1412,
    technique: 82,
    surete: 91,
    conformite: 76,
    budget: 74,
    status: 'high',
  },
  {
    name: 'Cosmos Angré',
    city: 'Abidjan · CI · pré-ouverture',
    assets: 868,
    technique: 88,
    surete: 79,
    conformite: 84,
    budget: 69,
    status: 'medium',
  },
];

export interface EnergyAnomaly {
  zone: string;
  deviation: number; // % vs baseline
  series: number[];
  level: RiskLevel;
}
export const ENERGY: EnergyAnomaly[] = [
  { zone: 'Galerie marchande', deviation: 18, series: [40, 42, 41, 44, 52, 58, 61], level: 'high' },
  { zone: 'Groupe froid CVC', deviation: 9, series: [70, 72, 71, 73, 74, 78, 80], level: 'medium' },
  { zone: 'Parking niveau −1', deviation: -4, series: [30, 31, 30, 29, 28, 28, 27], level: 'low' },
  { zone: 'Éclairage façade', deviation: 2, series: [22, 23, 22, 23, 22, 23, 23], level: 'low' },
];

export interface Technician {
  id: string;
  name: string;
  initials: string;
  x: number; // %
  y: number; // %
  status: 'on_wo' | 'on_duty' | 'break';
  task: string;
}
export const TECHNICIANS: Technician[] = [
  { id: 'T1', name: 'K. Aka', initials: 'KA', x: 28, y: 40, status: 'on_wo', task: 'OT-10342 · Groupe froid' },
  { id: 'T2', name: 'M. Diomandé', initials: 'MD', x: 64, y: 30, status: 'on_wo', task: 'CRP ascenseur A3' },
  { id: 'T3', name: 'S. Koffi', initials: 'SK', x: 48, y: 68, status: 'on_duty', task: 'Ronde sûreté R+2' },
  { id: 'T4', name: 'A. Touré', initials: 'AT', x: 80, y: 60, status: 'break', task: 'Pause' },
];

export const ROOMS = [
  { x: 4, y: 6, w: 30, h: 40, tag: 'Local technique' },
  { x: 38, y: 6, w: 40, h: 26, tag: 'Galerie marchande' },
  { x: 38, y: 36, w: 24, h: 30, tag: 'Atrium' },
  { x: 66, y: 36, w: 30, h: 30, tag: 'Boutiques B12–B18' },
  { x: 4, y: 50, w: 30, h: 44, tag: 'Parking −1' },
  { x: 38, y: 70, w: 58, h: 24, tag: 'Circulation' },
];

export const ASSET_PINS = [
  { x: 14, y: 22 },
  { x: 20, y: 70 },
  { x: 70, y: 18 },
  { x: 88, y: 44 },
  { x: 52, y: 50 },
];
