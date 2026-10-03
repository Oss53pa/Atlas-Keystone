import { useEffect, useState } from 'react';
import { Map, Maximize2, RefreshCw, CheckCircle2, Ruler, Building2, AlertTriangle } from 'lucide-react';
import { Card, StatBig } from '@keystone/ui';
import type { SpaceUnit, SpaceSummary, SpaceType } from '@keystone/domain/db/keystone';
import { fetchSpaceInventory, fetchSpaceSummary } from '../../data/space.ts';

const TYPE: Record<SpaceType, { label: string; color: string }> = {
  tenant_lot: { label: 'Lot locataire', color: '#355FD6' },
  common_area: { label: 'Partie commune', color: '#1D9E75' },
  technical_room: { label: 'Local technique', color: '#C9821C' },
  office: { label: 'Bureau', color: '#6E62C8' },
  circulation: { label: 'Circulation', color: '#9A9485' },
  parking: { label: 'Parking', color: '#6E6557' },
  outdoor: { label: 'Extérieur', color: '#639922' },
};
const STATUS: Record<string, { label: string; color: string }> = {
  occupied: { label: 'Occupé', color: 'var(--ks-low)' },
  vacant: { label: 'Vacant', color: 'var(--ks-high)' },
  reserved: { label: 'Réservé', color: 'var(--ks-amber)' },
  works: { label: 'Travaux', color: 'var(--ks-info)' },
};
const m2 = (n: number | null) => (n == null ? '—' : `${n.toLocaleString('fr-FR')} m²`);
const centroid = (poly: number[][]): [number, number] => {
  const n = poly.length;
  const c = poly.reduce((a, p) => [a[0] + p[0], a[1] + p[1]], [0, 0]);
  return [(c[0] / n) * 100, (c[1] / n) * 100];
};

export function SpaceManagement() {
  const [units, setUnits] = useState<SpaceUnit[] | null>(null);
  const [summary, setSummary] = useState<SpaceSummary | null>(null);
  const [sel, setSel] = useState<SpaceUnit | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function load() {
    fetchSpaceInventory().then(setUnits).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchSpaceSummary().then(setSummary).catch(() => {});
  }
  useEffect(load, []);

  const list = units ?? [];

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Hard FM · Space Management</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Espaces &amp; plans</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">surfaces EN 15221-6 · polygones sélectionnables · point-dans-espace (§6.27)</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      {summary && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Espaces inventoriés" icon={<Building2 size={15} />} value={summary.units} sub="lots, communs, techniques" /></Card>
          <Card><StatBig label="Surface totale" icon={<Ruler size={15} />} value={summary.surface_total.toLocaleString('fr-FR')} unit="m²" sub="norme EN 15221-6" /></Card>
          <Card><StatBig label="Taux d'occupation" accent="var(--ks-low)" value={summary.occupation_pct} unit="%" sub="par surface" /></Card>
          <Card><StatBig label="Espaces vacants" accent={summary.vacants ? 'var(--ks-high)' : 'var(--ks-low)'} value={summary.vacants} sub="à commercialiser" /></Card>
        </div>
      )}

      <div className="kt-dash kt-dash--21" style={{ alignItems: 'start' }}>
        <Card className="ks-reveal" style={{ animationDelay: '100ms' }}>
          <div className="ks-eyebrow" style={{ marginBottom: 12, display: 'flex', alignItems: 'center', gap: 8 }}><Map size={13} /> Plan RDC — Cosmos Yopougon · cliquez un espace</div>
          <div className="kt-plan" style={{ aspectRatio: '16 / 10' }}>
            <div className="kt-plan__grid" />
            <button className="ks-icon-btn" style={{ position: 'absolute', top: 10, right: 10, background: 'var(--ks-surface)', border: '1px solid var(--ks-line-2)', zIndex: 2 }} aria-label="Plein écran"><Maximize2 size={16} /></button>
            <svg viewBox="0 0 100 100" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
              {list.filter((u) => u.polygon).map((u) => {
                const t = TYPE[u.type]; const isSel = sel?.id === u.id;
                const pts = u.polygon!.map((p) => `${p[0] * 100},${p[1] * 100}`).join(' ');
                const [cx, cy] = centroid(u.polygon!);
                return (
                  <g key={u.id} style={{ cursor: 'pointer' }} onClick={() => setSel(u)}>
                    <polygon points={pts} fill={t.color} fillOpacity={isSel ? 0.42 : u.status === 'vacant' ? 0.08 : 0.2}
                      stroke={isSel ? 'var(--ks-amber)' : t.color} strokeWidth={isSel ? 1.1 : 0.5} strokeDasharray={u.status === 'vacant' ? '2 1.5' : undefined} />
                    <text x={cx} y={cy} textAnchor="middle" dominantBaseline="middle" fontSize="2.4" fontWeight="600" fill={t.color} style={{ pointerEvents: 'none' }}>{u.code}</text>
                  </g>
                );
              })}
            </svg>
          </div>
          <div className="kt-legend">
            {Object.entries(TYPE).slice(0, 5).map(([k, t]) => (
              <span key={k}><i style={{ background: t.color }} /> {t.label}</span>
            ))}
          </div>
        </Card>

        <Card className="ks-reveal" style={{ animationDelay: '160ms' }}>
          {sel ? (
            <div>
              <div className="ks-eyebrow" style={{ marginBottom: 6 }}>Espace sélectionné</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{sel.name}</div>
              <div className="ks-mono ks-faint" style={{ fontSize: 12, marginBottom: 16 }}>{sel.code}</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
                <Row k="Type"><span className="ks-pill" style={{ color: TYPE[sel.type].color }}>{TYPE[sel.type].label}</span></Row>
                <Row k="Surface"><span className="ks-mono" style={{ fontWeight: 600 }}>{m2(sel.surface_m2)}</span></Row>
                <Row k="Statut"><span className="ks-status" style={{ color: STATUS[sel.status]?.color }}><span className="ks-status__dot" /> {STATUS[sel.status]?.label ?? sel.status}</span></Row>
                <Row k="Occupation">{sel.occupant_kind ?? '—'}</Row>
                <Row k="Validé">{sel.is_verified ? <span style={{ color: 'var(--ks-low)', display: 'inline-flex', alignItems: 'center', gap: 5 }}><CheckCircle2 size={14} /> oui</span> : <span className="ks-faint">non vérifié</span>}</Row>
              </div>
              <p className="ks-faint" style={{ fontSize: 11, marginTop: 16, lineHeight: 1.5 }}>
                Polygone validé → sert à la résolution <b>point-dans-espace</b> (rattachement automatique des actifs et des techniciens à ce local).
              </p>
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '30px 10px' }}>
              <Map size={26} className="ks-faint" />
              <div className="ks-dim" style={{ fontSize: 13.5, marginTop: 10 }}>Cliquez un espace sur le plan pour voir sa fiche (surface, occupation, statut).</div>
            </div>
          )}
        </Card>
      </div>

      {units && (
        <Card pad={false} className="ks-reveal" style={{ marginTop: 18, animationDelay: '220ms' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Code</th><th>Espace</th><th>Type</th><th>Surface</th><th>Statut</th><th>Validé</th></tr></thead>
              <tbody>
                {list.map((u) => (
                  <tr key={u.id} style={{ cursor: 'pointer', background: sel?.id === u.id ? 'var(--ks-amber-50)' : undefined }} onClick={() => setSel(u)}>
                    <td className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{u.code}</td>
                    <td style={{ fontWeight: 600 }}>{u.name}</td>
                    <td><span className="ks-pill" style={{ color: TYPE[u.type].color }}>{TYPE[u.type].label}</span></td>
                    <td className="ks-mono">{m2(u.surface_m2)}</td>
                    <td><span className="ks-status" style={{ color: STATUS[u.status]?.color }}><span className="ks-status__dot" /> {STATUS[u.status]?.label ?? u.status}</span></td>
                    <td>{u.is_verified ? <CheckCircle2 size={15} color="var(--ks-low)" /> : <span className="ks-faint">—</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}

function Row({ k, children }: { k: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, fontSize: 13.5 }}>
      <span className="ks-faint">{k}</span>
      <span>{children}</span>
    </div>
  );
}
