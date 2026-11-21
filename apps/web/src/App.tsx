import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import {
  Boxes, Wrench, Map, AlertTriangle, FileCheck2, ListChecks, Ticket, HardHat, FileText, ArrowRightLeft, ClipboardList,
  KeyRound, User, Truck, Receipt, Package, Gauge, ExternalLink, Maximize2, Minimize2, Printer,
} from 'lucide-react';
import { CommandPalette, type Command } from '@keystone/ui';
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
import { ModulePage, exportCsv } from './features/module/ModulePage.tsx';
import { Header } from './shell/Header.tsx';
import { Sommaire } from './shell/Sommaire.tsx';
import { Icon } from './shell/Icon.tsx';
import { useSession, signOut } from './lib/auth.ts';
import { useAal } from './lib/mfa.ts';
import { MfaChallenge } from './features/auth/MfaChallenge.tsx';
import { globalSearch } from './data/search.ts';
import { FocusProvider, type Focus } from './lib/focus.tsx';
import { isBackendConfigured } from './lib/supabase.ts';
import { SITES } from './data/demo.ts';
import { AK_MODULES } from './data/modules.ts';
import { chapters as buildChapters, findModule, PORTAL_HREF, type Declinaison } from './data/nav.ts';

const DECLINAISON: Declinaison = 'fm_provider';

/** Écrans opérationnels existants (données Supabase), rattachés aux modules de la refonte v4. */
function liveScreen(id: string, site: string): ReactNode | undefined {
  switch (id) {
    case 'control-tower': return <ControlTower site={site} />;
    case 'work-orders': return <WorkOrders />;
    case 'ref-maint': return <WoTemplates />;
    case 'planning': return <Preventive />;
    case 'assets': return <Assets />;
    case 'meters': return <Utilities />;
    case 'purchase-req': case 'orders': case 'stock': return <Procurement />;
    case 'suppliers': return <Contractors />;
    case 'crp': return <Crp />;
    case 'energy': return <EnergyCarbon />;
    case 'hsse-events': return <Hsse />;
    case 'permits': return <Permits />;
    case 'inspections': return <Inspections />;
    case 'environment': return <Waste />;
    case 'tickets': return <Tickets />;
    case 'softfm': return <SoftFm />;
    case 'spaces': return <SpaceManagement />;
    case 'leases': return <Leases />;
    case 'settings': return <SettingsScreen />;
    case 'agents': return <Agents />;
    case 'notifications': return <Notifications />;
    default: return undefined;
  }
}

/** Identifiants de module renvoyés par la recherche serveur (`global_search`) → modules v4. */
const LEGACY_MODULE: Record<string, string> = {
  hsse: 'hsse-events', contractors: 'suppliers', procurement: 'purchase-req', utilities: 'meters',
  'soft-fm': 'softfm', compliance: 'crp', preventive: 'planning', 'wo-templates': 'ref-maint', waste: 'environment', admin: 'agents',
};

const HIT: Record<string, { label: string; icon: ReactNode }> = {
  wo: { label: 'OT', icon: <Wrench size={17} /> }, asset: { label: 'Équipement', icon: <Boxes size={17} /> },
  ticket: { label: 'Ticket', icon: <Ticket size={17} /> }, hsse: { label: 'HSSE', icon: <AlertTriangle size={17} /> },
  nc: { label: 'Non-conformité', icon: <ListChecks size={17} /> }, permit: { label: 'Permis', icon: <FileCheck2 size={17} /> },
  contractor: { label: 'Prestataire', icon: <HardHat size={17} /> }, lessee: { label: 'Preneur', icon: <User size={17} /> },
  lease: { label: 'Bail', icon: <KeyRound size={17} /> }, pr: { label: 'DA', icon: <ClipboardList size={17} /> },
  po: { label: 'BC', icon: <Truck size={17} /> }, invoice: { label: 'Facture', icon: <Receipt size={17} /> },
  part: { label: 'Pièce', icon: <Package size={17} /> }, space: { label: 'Lot', icon: <Map size={17} /> },
  meter: { label: 'Compteur', icon: <Gauge size={17} /> },
};

const fmtDateFull = (d: Date) => d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
const fmtDay = (d: Date) => d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
const fmtTime = (d: Date) => d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
const fmtPeriod = (d: Date) => d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });

function initialPage(): string {
  const h = decodeURIComponent(window.location.hash.slice(1));
  return /^[a-z][a-z0-9-]{1,30}$/.test(h) ? h : 'control-tower';
}

export function App() {
  const { session, ready } = useSession();
  const { aal, refresh: refreshAal } = useAal(session);
  const chs = useMemo(() => buildChapters(DECLINAISON), []);
  const [page, setPage] = useState(() => (findModule(buildChapters(DECLINAISON), initialPage()) ? initialPage() : 'control-tower'));
  const [history, setHistory] = useState<string[]>([]);
  const pageRef = useRef(page);
  pageRef.current = page;
  const historyRef = useRef(history);
  historyRef.current = history;
  const [site, setSite] = useState(SITES[0]);
  const [sommaire, setSommaire] = useState(false);
  const [palette, setPalette] = useState(false);
  const [full, setFull] = useState(false);
  const [focus, setFocus] = useState<Focus | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

  const showToast = useCallback((m: string) => {
    setToast(m);
    window.setTimeout(() => setToast((t) => (t === m ? null : t)), 2800);
  }, []);

  const go = useCallback((id: string) => {
    if (id === 'print-center') { setSommaire(false); showToast('Centre d’impression : livré au lot 4'); return; }
    if (!findModule(chs, id)) return;
    setFocus(null);
    setSommaire(false);
    const cur = pageRef.current;
    if (cur !== id) { setHistory((h) => [...h.slice(-30), cur]); setPage(id); }
  }, [chs, showToast]);

  const back = useCallback(() => {
    const h = historyRef.current;
    const prev = h[h.length - 1];
    if (!prev) return;
    setFocus(null);
    setPage(prev);
    setHistory(h.slice(0, -1));
  }, []);

  useEffect(() => { window.history.replaceState(null, '', `#${page}`); }, [page]);
  useEffect(() => {
    const onHash = () => { const h = initialPage(); if (h !== pageRef.current) go(h); };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, [go]);
  useEffect(() => { const t = window.setInterval(() => setNow(new Date()), 30_000); return () => window.clearInterval(t); }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tg = (e.target as HTMLElement | null)?.tagName?.toLowerCase() ?? '';
      const typing = tg === 'input' || tg === 'textarea' || tg === 'select';
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); setPalette(false); setSommaire((s) => !s); return; }
      if (e.key === 'Escape') { setSommaire(false); return; }
      if ((e.key === 'f' || e.key === 'F') && !e.ctrlKey && !e.metaKey && !e.altKey && !typing) { e.preventDefault(); setFull((f) => !f); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const commands = useMemo<Command[]>(() => {
    const nav: Command[] = chs.flatMap((ch) =>
      ch.items.map((it) => ({
        id: `nav:${it.id}`, label: it.label, group: 'Aller à', hint: `${it.code} · ${ch.title}`,
        icon: <Icon name={it.icon} size={17} />, run: () => go(it.id),
      })),
    );
    const ctx: Command[] = SITES.filter((s) => s !== site).map((s) => ({
      id: `site:${s}`, label: `Basculer sur ${s}`, group: 'Périmètre', icon: <ArrowRightLeft size={17} />, run: () => setSite(s),
    }));
    return [...nav, ...ctx];
  }, [chs, go, site]);

  const onSearch = useCallback(async (q: string): Promise<Command[]> => {
    if (!isBackendConfigured) return [];
    const hits = await globalSearch(q);
    return hits.map((h) => {
      const k = HIT[h.kind] ?? { label: h.kind, icon: <FileText size={17} /> };
      const target = LEGACY_MODULE[h.module] ?? h.module;
      return {
        id: `s:${h.kind}:${h.id}`,
        label: h.ref ? `${h.ref} · ${h.title}` : h.title,
        group: 'Dans les données',
        hint: [k.label, h.subtitle].filter(Boolean).join(' · '),
        icon: k.icon,
        run: () => { go(target); setFocus({ kind: h.kind, id: h.id, nonce: Date.now() }); },
      };
    });
  }, [go]);

  if (isBackendConfigured && !ready) {
    return <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', color: 'var(--ink-3)' }}>Chargement…</div>;
  }
  if (isBackendConfigured && !session) return <Login />;
  if (isBackendConfigured && aal?.next === 'aal2' && aal.current !== 'aal2') {
    return <MfaChallenge email={session?.user?.email ?? ''} onDone={refreshAal} />;
  }

  const email = session?.user?.email ?? '';
  const name = email ? email.split('@')[0] : 'Awa Toko';
  const initials = (name.slice(0, 2) || 'AT').toUpperCase();

  const found = findModule(chs, page) ?? findModule(chs, 'control-tower')!;
  const def = AK_MODULES[page];
  const live = liveScreen(page, site);
  const portal = PORTAL_HREF[page];
  const eyebrow = `${found.chapter.title}, ${found.item.label}, ${fmtPeriod(now)}`;
  const title = def ? def.t : found.item.label;
  const primaryLabel = def?.a ?? 'Générer le rapport mensuel';
  const onPrimary = () => showToast(`${primaryLabel} : formulaire livré au lot 2 (moteur de formulaires)`);

  return (
    <div className="ak-root">
      {sommaire ? (
        <Sommaire
          chapters={chs}
          current={page}
          onGo={go}
          onClose={() => setSommaire(false)}
          user={{ name, initials, space: 'Exploitant' }}
          siteSub={site}
          today={fmtDay(now)}
        />
      ) : (
        <>
          {!full && (
            <Header
              onHome={() => go('control-tower')}
              onSommaire={() => setSommaire(true)}
              onBack={back}
              canBack={history.length > 0}
              site={site}
              onCycleSite={() => setSite((s) => SITES[(SITES.indexOf(s) + 1) % SITES.length])}
              dateFull={fmtDateFull(now)}
              time={fmtTime(now)}
              onSearch={() => setPalette(true)}
              bell={isBackendConfigured ? <NotificationBell onOpenCenter={() => go('notifications')} /> : undefined}
              onIncident={() => go('hsse-events')}
              user={{ initials, title: `${name}, Exploitant` }}
              onSignOut={isBackendConfigured ? () => void signOut() : undefined}
            />
          )}
          <main className="ak-body">
            <div className="ak-pagehead">
              <div style={{ minWidth: 0 }}>
                <div className="ak-eyebrow">{eyebrow}</div>
                <h1>{title}</h1>
                {portal && (
                  <a className="ak-btn-ink" href={portal.href} target="_blank" rel="noopener noreferrer" style={{ marginTop: 10, height: 36, textDecoration: 'none' }}>
                    {portal.label}<ExternalLink size={14} aria-hidden />
                  </a>
                )}
              </div>
              <div className="ak-pagehead__actions ak-noprint">
                <button className="ak-btn-text" onClick={() => setFull((f) => !f)} title="Pleine page (F)">
                  {full ? <Minimize2 size={14} aria-hidden /> : <Maximize2 size={14} aria-hidden />}
                  {full ? 'Quitter la pleine page' : 'Pleine page'}<kbd>F</kbd>
                </button>
                <button className="ak-btn-text" onClick={() => window.print()}>
                  <Printer size={14} aria-hidden /> Imprimer
                </button>
                {def && (
                  <button
                    className="ak-btn-text"
                    style={{ marginRight: 8 }}
                    onClick={() => {
                      const cols = def.c.map((c) => { const i = c.lastIndexOf(':'); return { label: c.slice(0, i), type: c.slice(i + 1) as never }; });
                      exportCsv(page, cols, def.r);
                      showToast('Export CSV généré');
                    }}
                  >
                    Exporter
                  </button>
                )}
                <button className="ak-btn-brand" onClick={onPrimary}>{primaryLabel}</button>
              </div>
            </div>

            <FocusProvider value={focus}>
              {def ? (
                <ModulePage key={page} id={page} def={def} live={live} liveFirst={isBackendConfigured} onPrimary={onPrimary} onToast={showToast} />
              ) : (
                <div className="ak-scroll ak-live" style={{ flex: 1, minHeight: 0 }}>{live}</div>
              )}
            </FocusProvider>
          </main>
        </>
      )}
      <CommandPalette open={palette} onClose={() => setPalette(false)} commands={commands} onSearch={onSearch} />
      {toast && <div className="ak-toast" role="status" aria-live="polite">{toast}</div>}
    </div>
  );
}
