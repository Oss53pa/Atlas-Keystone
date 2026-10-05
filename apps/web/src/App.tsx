import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Radar, Boxes, Wrench, ShieldCheck, Map, Sparkles, Car, AlertTriangle,
  FileCheck2, ClipboardCheck, Ticket, Wallet, ShoppingCart, HardHat, Settings, Construction,
  Plus, FileText, ArrowRightLeft, Leaf, ListChecks, CalendarCheck2, Recycle, KeyRound, Store, BellRing, ClipboardList, Smartphone, SlidersHorizontal, Gauge, Package, Receipt, Truck, User,
} from 'lucide-react';
import { AppShell, CommandPalette, type Command, type Density, type NavGroup } from '@keystone/ui';
import { ControlTower } from './features/control-tower/ControlTower.tsx';
import { WorkOrders } from './features/gmao/WorkOrders.tsx';
import { Hsse } from './features/hsse/Hsse.tsx';
import { Permits } from './features/hsse/Permits.tsx';
import { Tickets } from './features/tickets/Tickets.tsx';
import { SpaceManagement } from './features/space/SpaceManagement.tsx';
import { SoftFm } from './features/softfm/SoftFm.tsx';
import { Contractors } from './features/contractors/Contractors.tsx';
import { Crp } from './features/crp/Crp.tsx';
import { Assets } from './features/assets/Assets.tsx';
import { Procurement } from './features/procurement/Procurement.tsx';
import { EnergyCarbon } from './features/energy/EnergyCarbon.tsx';
import { Utilities } from './features/utilities/Utilities.tsx';
import { Inspections } from './features/inspections/Inspections.tsx';
import { Preventive } from './features/preventive/Preventive.tsx';
import { Waste } from './features/waste/Waste.tsx';
import { Leases } from './features/leases/Leases.tsx';
import { Notifications } from './features/notifications/Notifications.tsx';
import { WoTemplates } from './features/wo-templates/WoTemplates.tsx';
import { Settings as SettingsScreen } from './features/settings/Settings.tsx';
import { NotificationBell } from './features/notifications/NotificationBell.tsx';
import { Agents } from './features/admin/Agents.tsx';
import { Login } from './features/auth/Login.tsx';
import { useSession, signOut } from './lib/auth.ts';
import { useAal } from './lib/mfa.ts';
import { MfaChallenge } from './features/auth/MfaChallenge.tsx';
import { globalSearch } from './data/search.ts';
import { isBackendConfigured } from './lib/supabase.ts';
import { SITES } from './data/demo.ts';

const I = (Icon: typeof Radar) => <Icon size={18} strokeWidth={1.9} />;

const GROUPS: NavGroup[] = [
  { label: 'Pilotage', items: [{ id: 'control-tower', label: 'Tour de contrôle', icon: I(Radar) }] },
  {
    label: 'Hard FM',
    items: [
      { id: 'assets', label: 'Actifs & composants', icon: I(Boxes) },
      { id: 'work-orders', label: 'GMAO · Ordres de travail', icon: I(Wrench) },
      { id: 'preventive', label: 'Préventif & gammes', icon: I(CalendarCheck2) },
      { id: 'wo-templates', label: 'Modèles d’OT', icon: I(ClipboardList) },
      { id: 'crp', label: 'Contrôles réglementaires', icon: I(ShieldCheck), badge: 3 },
      { id: 'spaces', label: 'Espaces & plans', icon: I(Map) },
      { id: 'leases', label: 'Baux & loyers', icon: I(KeyRound) },
    ],
  },
  {
    label: 'Soft FM',
    items: [
      { id: 'soft-fm', label: 'Services généraux', icon: I(Sparkles) },
      { id: 'parking', label: 'Parking', icon: I(Car) },
    ],
  },
  {
    label: 'HSSE',
    items: [
      { id: 'hsse', label: 'Incidents & CAPA', icon: I(AlertTriangle), badge: 2 },
      { id: 'permits', label: 'Permis & consignation', icon: I(FileCheck2) },
      { id: 'inspections', label: 'Inspections & NC', icon: I(ListChecks) },
      { id: 'compliance', label: 'Audits & conformité', icon: I(ClipboardCheck) },
    ],
  },
  {
    label: 'Pilotage & support',
    items: [
      { id: 'tickets', label: 'Tickets & helpdesk', icon: I(Ticket) },
      { id: 'budgets', label: 'Budgets OPEX/CAPEX', icon: I(Wallet) },
      { id: 'procurement', label: 'Achats & stocks', icon: I(ShoppingCart) },
      { id: 'energy', label: 'Énergie & carbone', icon: I(Leaf) },
      { id: 'utilities', label: 'Compteurs & tarifs', icon: I(Gauge) },
      { id: 'waste', label: 'Déchets & filières', icon: I(Recycle) },
      { id: 'contractors', label: 'Prestataires', icon: I(HardHat) },
    ],
  },
  {
    label: 'Système',
    items: [
      { id: 'notifications', label: 'Notifications', icon: I(BellRing) },
      { id: 'settings', label: 'Paramètres', icon: I(SlidersHorizontal) },
      { id: 'admin', label: 'Agents autonomes', icon: I(Settings) },
    ],
  },
];

const HIT: Record<string, { label: string; icon: React.ReactNode }> = {
  wo: { label: 'OT', icon: <Wrench size={17} /> }, asset: { label: 'Équipement', icon: <Boxes size={17} /> },
  ticket: { label: 'Ticket', icon: <Ticket size={17} /> }, hsse: { label: 'HSSE', icon: <AlertTriangle size={17} /> },
  nc: { label: 'Non-conformité', icon: <ListChecks size={17} /> }, permit: { label: 'Permis', icon: <FileCheck2 size={17} /> },
  contractor: { label: 'Prestataire', icon: <HardHat size={17} /> }, lessee: { label: 'Preneur', icon: <User size={17} /> },
  lease: { label: 'Bail', icon: <KeyRound size={17} /> }, pr: { label: 'DA', icon: <ClipboardList size={17} /> },
  po: { label: 'BC', icon: <Truck size={17} /> }, invoice: { label: 'Facture', icon: <Receipt size={17} /> },
  part: { label: 'Pièce', icon: <Package size={17} /> }, space: { label: 'Lot', icon: <Map size={17} /> },
  meter: { label: 'Compteur', icon: <Gauge size={17} /> },
};

function findLabel(id: string): string {
  for (const g of GROUPS) for (const it of g.items) if (it.id === id) return it.label;
  return id;
}

export function App() {
  const { session, ready } = useSession();
  const { aal, refresh: refreshAal } = useAal(session);
  const [active, setActive] = useState('control-tower');
  const [density, setDensity] = useState<Density>('office');
  const [site, setSite] = useState(SITES[0]);
  const [palette, setPalette] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setPalette((p) => !p);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const commands = useMemo<Command[]>(() => {
    const nav: Command[] = GROUPS.flatMap((g) =>
      g.items.map((it) => ({
        id: `nav:${it.id}`,
        label: it.label,
        group: 'Aller à',
        hint: g.label,
        icon: it.icon,
        run: () => setActive(it.id),
      })),
    );
    const actions: Command[] = [
      { id: 'a:incident', label: 'Signaler un incident / presque-accident', group: 'Actions', icon: <AlertTriangle size={17} />, run: () => setActive('hsse') },
      { id: 'a:wo', label: 'Créer un ordre de travail', group: 'Actions', icon: <Plus size={17} />, run: () => setActive('work-orders') },
      { id: 'a:permit', label: 'Demander un permis de travail', group: 'Actions', icon: <FileCheck2 size={17} />, run: () => setActive('permits') },
      { id: 'a:report', label: 'Générer le rapport mensuel', group: 'Actions', icon: <FileText size={17} />, run: () => setActive('control-tower') },
      { id: 'a:round', label: 'Lancer une ronde d’inspection', group: 'Actions', icon: <ListChecks size={17} />, run: () => setActive('inspections') },
      { id: 'a:pm', label: 'Générer les OT préventifs à 14 jours', group: 'Actions', icon: <CalendarCheck2 size={17} />, run: () => setActive('preventive') },
      { id: 'a:reappro', label: 'Proposer les réapprovisionnements de stock', group: 'Actions', icon: <ShoppingCart size={17} />, run: () => setActive('procurement') },
      { id: 'a:amdec', label: 'Analyser la criticité (AMDEC)', group: 'Actions', icon: <Boxes size={17} />, run: () => setActive('assets') },
      { id: 'a:rent', label: 'Encaisser un loyer / voir les impayés', group: 'Actions', icon: <KeyRound size={17} />, run: () => setActive('leases') },
      { id: 'a:invoice', label: 'Rapprocher une facture fournisseur (BC / réception / facture)', group: 'Actions', icon: <ShoppingCart size={17} />, run: () => setActive('procurement') },
      { id: 'a:meter', label: 'Relever un compteur / contrôler une facture CIE-SODECI', group: 'Actions', icon: <Gauge size={17} />, run: () => setActive('utilities') },
      { id: 'a:tech', label: 'Ouvrir l’app technicien (terrain)', group: 'Actions', icon: <Smartphone size={17} />, run: () => window.open('?technicien', '_blank', 'noopener') },
      { id: 'a:tenant', label: 'Ouvrir le portail locataire', group: 'Actions', icon: <Store size={17} />, run: () => window.open('?locataire', '_blank', 'noopener') },
      { id: 'a:portal', label: 'Ouvrir l’espace prestataire', group: 'Actions', icon: <HardHat size={17} />, run: () => window.open('?prestataire', '_blank', 'noopener') },
    ];
    const ctx: Command[] = SITES.filter((s) => s !== site).map((s) => ({
      id: `site:${s}`,
      label: `Basculer sur ${s}`,
      group: 'Périmètre',
      icon: <ArrowRightLeft size={17} />,
      run: () => setSite(s),
    }));
    return [...nav, ...actions, ...ctx];
  }, [site]);

  const onSearch = useCallback(async (q: string): Promise<Command[]> => {
    if (!isBackendConfigured) return [];
    const hits = await globalSearch(q);
    return hits.map((h) => {
      const k = HIT[h.kind] ?? { label: h.kind, icon: <FileText size={17} /> };
      return {
        id: `s:${h.kind}:${h.id}`,
        label: h.ref ? `${h.ref} · ${h.title}` : h.title,
        group: 'Dans les données',
        hint: [k.label, h.subtitle].filter(Boolean).join(' · '),
        icon: k.icon,
        run: () => setActive(h.module),
      };
    });
  }, []);

  if (isBackendConfigured && !ready) {
    return <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', color: 'var(--ks-ink-3)' }}>Chargement…</div>;
  }
  if (isBackendConfigured && !session) {
    return <Login />;
  }
  if (isBackendConfigured && aal?.next === 'aal2' && aal.current !== 'aal2') {
    return <MfaChallenge email={session?.user?.email ?? ''} onDone={refreshAal} />;
  }

  const email = session?.user?.email ?? '';
  const name = email ? email.split('@')[0] : 'Awa Toko';
  const initials = (name.slice(0, 2) || 'AT').toUpperCase();

  return (
    <>
      <AppShell
        groups={GROUPS}
        activeId={active}
        onNavigate={setActive}
        density={density}
        onDensity={setDensity}
        site={site}
        sites={SITES}
        onSite={setSite}
        user={{ name, initials, role: 'Exploitant · Admin' }}
        onCommand={() => setPalette(true)}
        onSignOut={isBackendConfigured ? () => void signOut() : undefined}
        bell={isBackendConfigured ? <NotificationBell onOpenCenter={() => setActive('notifications')} /> : undefined}
      >
        {active === 'control-tower' ? (
          <ControlTower site={site} />
        ) : active === 'work-orders' ? (
          <WorkOrders />
        ) : active === 'hsse' ? (
          <Hsse />
        ) : active === 'permits' ? (
          <Permits />
        ) : active === 'tickets' ? (
          <Tickets />
        ) : active === 'spaces' ? (
          <SpaceManagement />
        ) : active === 'soft-fm' ? (
          <SoftFm />
        ) : active === 'contractors' ? (
          <Contractors />
        ) : active === 'settings' ? (
          <SettingsScreen />
        ) : active === 'wo-templates' ? (
          <WoTemplates />
        ) : active === 'notifications' ? (
          <Notifications />
        ) : active === 'leases' ? (
          <Leases />
        ) : active === 'preventive' ? (
          <Preventive />
        ) : active === 'waste' ? (
          <Waste />
        ) : active === 'inspections' ? (
          <Inspections />
        ) : active === 'utilities' ? (
          <Utilities />
        ) : active === 'energy' ? (
          <EnergyCarbon />
        ) : active === 'procurement' ? (
          <Procurement />
        ) : active === 'assets' ? (
          <Assets />
        ) : active === 'compliance' || active === 'crp' ? (
          <Crp />
        ) : active === 'admin' ? (
          <Agents />
        ) : (
          <ModulePlaceholder title={findLabel(active)} />
        )}
      </AppShell>
      <CommandPalette open={palette} onClose={() => setPalette(false)} commands={commands} onSearch={onSearch} />
    </>
  );
}

function ModulePlaceholder({ title }: { title: string }) {
  return (
    <div className="ks-container" style={{ textAlign: 'center', paddingTop: 90 }}>
      <div
        style={{
          width: 64, height: 64, borderRadius: 18, margin: '0 auto 20px', display: 'grid', placeItems: 'center',
          background: 'var(--ks-amber-50)', color: 'var(--ks-amber-700)', border: '1px solid var(--ks-amber-100)',
        }}
      >
        <Construction size={28} strokeWidth={1.8} />
      </div>
      <h1 style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-.02em' }}>{title}</h1>
      <p className="ks-dim" style={{ maxWidth: 460, margin: '12px auto 0', fontSize: 14 }}>
        Module du périmètre Lot 0+. La Tour de contrôle est l’écran phare livré en premier — sélectionnez-la pour la
        démonstration du design system Keystone UI.
      </p>
    </div>
  );
}
