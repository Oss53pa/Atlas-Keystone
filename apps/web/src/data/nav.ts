// Atlas Keystone — sommaire de l'application (refonte v4) : 10 chapitres, 53 modules.
// Transposé de la maquette (`CH_ALL`, `TC`). Les clés de module sont celles de `AK_MODULES`.

export type Declinaison = 'fm_provider' | 'in_house';

/** Restriction de déclinaison : 'fm' = prestataire FM seulement, 'ih' = interne seulement. */
type Only = 'fm' | 'ih';

export interface NavModule {
  id: string;
  label: string;
  /** Nom d'icône Lucide (kebab-case). */
  icon: string;
  /** Code transaction (palette, raccourcis). */
  code: string;
  badge?: number;
  only?: Only;
}

export interface NavChapter {
  no: string;
  title: string;
  icon: string;
  items: NavModule[];
}

type Raw = [id: string, label: string, icon: string, badge?: number, only?: Only];

const TC: Record<string, string> = {
  'my-space': 'ESP', 'control-tower': 'TDC', dashboards: 'TBD', reports: 'RAP', 'sm-fm': 'SMF',
  assets: 'ACT', 'work-orders': 'OT', 'work-centers': 'CTW', 'ref-maint': 'REF', planning: 'PLM', amdec: 'AMD',
  'asset-mgmt': 'GAC', docs: 'DOC', meters: 'CPT', stock: 'STK', budgets: 'BUD', 'purchase-req': 'DA', orders: 'CMD',
  suppliers: 'PRE', 'supplier-eval': 'EVP', crp: 'CRP', fire: 'SSI', energy: 'NRJ', iot: 'IOT', 'hsse-events': 'EVT',
  permits: 'PTW', inspections: 'INS', risks: 'DUER', sst: 'SST', training: 'HAB', environment: 'ENV', visitors: 'VIS',
  rounds: 'RON', tickets: 'TKT', softfm: 'SFM', 'softfm-ops': 'SFO', parking: 'PRK', spaces: 'PAT', occupancy: 'OCC',
  bookings: 'RES', imputation: 'IMP', workshop: 'ATL', fitout: 'TRA', clients: 'CLI', quotes: 'DEV', billing: 'FAC',
  mobilisation: 'MOB', subscription: 'ABO', settings: 'PAR', audit: 'AUD', 'print-center': 'EDT', field: 'TER',
  'client-portal': 'PCL', 'suppliers-portal': 'PFO', 'occupants-portal': 'POC',
  // Écrans opérationnels existants conservés hors maquette (données réelles Supabase).
  leases: 'BAI', agents: 'AGT', notifications: 'NOT',
};

const RAW: [string, string, string, Raw[]][] = [
  ['01', 'Pilotage', 'radar', [['my-space', 'Mon espace', 'user-round'], ['control-tower', 'Tour de contrôle', 'radar'], ['dashboards', 'Tableaux de bord', 'layout-dashboard'], ['reports', 'Rapports et satisfaction', 'file-text'], ['sm-fm', 'Management FM et PROPH3T', 'sparkles']]],
  ['02', 'Maintenance', 'wrench', [['assets', 'Actifs et composants', 'cog'], ['work-orders', 'Ordres de travail', 'wrench', 4], ['work-centers', 'Centres de travail', 'users-round'], ['ref-maint', 'Référentiels et modèles d’OT', 'clipboard-list'], ['planning', 'Planning de maintenance', 'calendar-range'], ['amdec', 'AMDEC et criticité', 'gauge'], ['asset-mgmt', 'Plan pluriannuel d’actifs', 'line-chart'], ['docs', 'Documentation technique', 'book-open'], ['meters', 'Compteurs et relevés', 'activity']]],
  ['03', 'Achats et réglementaire', 'shield-check', [['stock', 'Pièces et stocks', 'package'], ['budgets', 'Budgets et approbations', 'wallet'], ['purchase-req', 'Demandes d’achat', 'shopping-cart'], ['orders', 'Commandes et factures', 'receipt'], ['suppliers', 'Prestataires et fournisseurs', 'hard-hat'], ['supplier-eval', 'Évaluation des prestataires', 'star'], ['crp', 'Contrôles réglementaires', 'shield-check', 3], ['fire', 'Sécurité incendie', 'flame']]],
  ['04', 'Énergie et IoT', 'zap', [['energy', 'Énergie et fluides', 'zap'], ['iot', 'IoT et télémétrie', 'radio']]],
  ['05', 'HSSE', 'alert-triangle', [['hsse-events', 'Événements HSSE et CAPA', 'alert-triangle', 2], ['permits', 'Permis et consignation', 'file-badge'], ['inspections', 'Inspections, audits, conformité', 'clipboard-check'], ['risks', 'Risques et DUER', 'list-checks'], ['sst', 'Pilotage SST', 'heart-pulse'], ['training', 'Formation et habilitations', 'graduation-cap', 1], ['environment', 'Environnement et déchets', 'recycle']]],
  ['06', 'Sûreté et services', 'badge-check', [['visitors', 'Visiteurs et droits d’accès', 'badge-check'], ['rounds', 'Rondes et main courante', 'footprints'], ['tickets', 'Tickets et helpdesk', 'inbox'], ['softfm', 'Soft FM, plans de prestation', 'sparkles'], ['softfm-ops', 'Espaces verts, courrier', 'sprout'], ['parking', 'Parking', 'car']]],
  ['07', 'Espaces et travaux', 'door-open', [['spaces', 'Patrimoine et plans', 'door-open'], ['occupancy', 'Inventaire et occupation', 'users'], ['bookings', 'Réservations et déménagements', 'calendar-check-2'], ['imputation', 'Imputation interne', 'split', 0, 'ih'], ['workshop', 'Atelier spatial', 'pen-tool'], ['fitout', 'Travaux d’aménagement', 'hammer'], ['leases', 'Baux et loyers', 'key-round']]],
  ['08', 'Commercial', 'briefcase', [['clients', 'Clients, contrats, avenants', 'briefcase', 0, 'fm'], ['quotes', 'Devis client et contestations', 'file-text', 0, 'fm'], ['billing', 'Facturation, SLA, marge', 'receipt', 0, 'fm'], ['mobilisation', 'Mobilisation', 'rocket']]],
  ['09', 'Administration', 'settings', [['subscription', 'Abonnement et utilisateurs', 'users-round'], ['settings', 'Sites, marque, paramètres', 'building-2'], ['audit', 'Audit et intégrations', 'scroll-text'], ['agents', 'Agents autonomes', 'bot'], ['notifications', 'Notifications', 'bell-ring'], ['print-center', 'Centre d’impression', 'printer']]],
  ['10', 'Surfaces', 'smartphone', [['field', 'Application terrain', 'smartphone'], ['client-portal', 'Portail client', 'monitor', 0, 'fm'], ['suppliers-portal', 'Portail fournisseurs', 'truck'], ['occupants-portal', 'Portail occupants', 'door-open']]],
];

export function chapters(decl: Declinaison): NavChapter[] {
  const fm = decl === 'fm_provider';
  return RAW.map(([no, t, icon, items]) => ({
    no,
    title: no === '08' && !fm ? 'Mobilisation' : t,
    icon,
    items: items
      .filter(([, , , , only]) => !only || (only === 'fm') === fm)
      .map(([id, label, ic, badge, only]) => ({ id, label, icon: ic, code: TC[id] ?? id.toUpperCase(), badge: badge || undefined, only })),
  }));
}

export function findModule(chs: NavChapter[], id: string): { chapter: NavChapter; item: NavModule } | null {
  for (const chapter of chs) for (const item of chapter.items) if (item.id === id) return { chapter, item };
  return null;
}

/** Surfaces externes : ouvertes dans un nouvel onglet (applications existantes du dépôt). */
export const PORTAL_HREF: Record<string, { href: string; label: string }> = {
  field: { href: '?technicien', label: 'Ouvrir l’application terrain' },
  'suppliers-portal': { href: '?prestataire', label: 'Ouvrir le portail' },
  'occupants-portal': { href: '?portail', label: 'Ouvrir le portail' },
  'client-portal': { href: '?locataire', label: 'Ouvrir le portail' },
};
