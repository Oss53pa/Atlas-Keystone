import { useMemo, useState, type ReactElement } from 'react';
import { LayoutDashboard, Wrench, ShieldAlert, ShieldCheck, Wallet, Leaf, Map, FileText, Clock } from 'lucide-react';
import { Pill, TabBar, type TabDef } from '@keystone/ui';
import { ATTENTION } from '../../data/demo.ts';
import { useClock, type PanelProps } from './shared.tsx';
import { Overview } from './panels/Overview.tsx';
import { Maintenance } from './panels/Maintenance.tsx';
import { Hsse } from './panels/Hsse.tsx';
import { Compliance } from './panels/Compliance.tsx';
import { Budget } from './panels/Budget.tsx';
import { Energy } from './panels/Energy.tsx';
import { DigitalTwin } from './panels/DigitalTwin.tsx';
import { Report } from './panels/Report.tsx';

const TABS: TabDef[] = [
  { id: 'overview', label: 'Vue d’ensemble', icon: <LayoutDashboard size={16} /> },
  { id: 'twin', label: 'Jumeau numérique', icon: <Map size={16} /> },
  { id: 'maintenance', label: 'Maintenance', icon: <Wrench size={16} /> },
  { id: 'hsse', label: 'HSSE', icon: <ShieldAlert size={16} /> },
  { id: 'compliance', label: 'Conformité & CRP', icon: <ShieldCheck size={16} /> },
  { id: 'budget', label: 'Budget', icon: <Wallet size={16} /> },
  { id: 'energy', label: 'Énergie & Environnement', icon: <Leaf size={16} /> },
  { id: 'report', label: 'Rapport mensuel', icon: <FileText size={16} /> },
];

const PANELS: Record<string, (p: PanelProps) => ReactElement> = {
  overview: Overview,
  twin: DigitalTwin,
  maintenance: Maintenance,
  hsse: Hsse,
  compliance: Compliance,
  budget: Budget,
  energy: Energy,
  report: Report,
};

export function ControlTower({ site }: { site: string }) {
  const now = useClock();
  const [tab, setTab] = useState('overview');

  const attention = useMemo(
    () => (site === 'Tous les sites' ? ATTENTION : ATTENTION.filter((a) => a.site === site)),
    [site],
  );
  const criticalCount = attention.filter((a) => a.level === 'critical').length;
  const all = site === 'Tous les sites';

  const time = now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  const date = now.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

  const Panel = PANELS[tab] ?? Overview;

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ position: 'relative', marginBottom: 16 }}>
        <span className="kt-aurora kt-aurora--a" aria-hidden />
        <span className="kt-aurora kt-aurora--b" aria-hidden />
        <div className="ks-reveal" style={{ position: 'relative' }}>
          <div className="ks-eyebrow">Tour de contrôle exploitant</div>
          <h1 className="kt-hero__title">Bonjour, Awa.</h1>
          <div className="kt-hero__sub">
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              <Clock size={14} /> <span className="ks-mono">{time}</span> · {date}
            </span>
            <Pill color={criticalCount ? 'var(--ks-critical)' : 'var(--ks-low)'}>
              {criticalCount ? `${criticalCount} alertes critiques` : 'Aucune alerte critique'}
            </Pill>
            <span className="ks-faint">· {all ? 'Périmètre : tous les sites' : `Périmètre : ${site}`}</span>
          </div>
        </div>
      </header>

      <TabBar tabs={TABS} active={tab} onChange={setTab} />

      <div key={tab} className="ks-reveal">
        <Panel site={site} />
      </div>
    </div>
  );
}
