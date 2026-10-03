import { useEffect, useMemo, useState } from 'react';
import { Zap, Leaf, Ruler, Wallet, RefreshCw, AlertTriangle, Info, Snowflake, Fuel, Droplets, TrendingDown, TrendingUp } from 'lucide-react';
import { Card, StatBig, BarChart, Donut, Legend, TabBar } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { EnergyMonthly, EnergySummary, EnergyTargetRow, EnergyTargetStatus } from '@keystone/domain/db/keystone';
import { fetchEnergyMonthly, fetchEnergySummary, fetchEnergyTargets } from '../../data/energy.ts';

const fcfa = (n: number) => format(money(n, 'XOF'));
const nf = (n: number, d = 0) => n.toLocaleString('fr-FR', { maximumFractionDigits: d });
const CARRIER: Record<string, { label: string; icon: React.ReactNode; color: string }> = {
  electricity: { label: 'Électricité', icon: <Zap size={14} />, color: 'var(--ks-amber)' },
  diesel: { label: 'Gazole (groupes)', icon: <Fuel size={14} />, color: 'var(--ks-high)' },
  water: { label: 'Eau', icon: <Droplets size={14} />, color: 'var(--ks-info)' },
  refrigerant_r134a: { label: 'Fuites R134a', icon: <Snowflake size={14} />, color: 'var(--ks-critical)' },
};
const TARGET: Record<EnergyTargetStatus, { label: string; risk: 'critical' | 'high' | 'medium' | 'low' | 'info' }> = {
  critical: { label: 'Critique', risk: 'critical' }, alert: { label: 'Alerte', risk: 'high' }, watch: { label: 'Attention', risk: 'medium' },
  compliant: { label: 'Conforme', risk: 'low' }, no_data: { label: 'Sans relevé', risk: 'info' },
};
const month = (s: string) => new Date(s).toLocaleDateString('fr-FR', { month: 'short' }).replace('.', '');
const delta = (cur: number, prev: number) => (prev > 0 ? Math.round(((cur - prev) / prev) * 1000) / 10 : null);

export function EnergyCarbon() {
  const [rows, setRows] = useState<EnergyMonthly[] | null>(null);
  const [sum, setSum] = useState<EnergySummary | null>(null);
  const [targets, setTargets] = useState<EnergyTargetRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [view, setView] = useState<'kwh' | 'co2'>('kwh');

  function load() {
    fetchEnergyMonthly(12).then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchEnergySummary().then(setSum).catch(() => {});
    fetchEnergyTargets().then(setTargets).catch(() => {});
  }
  useEffect(load, []);

  const months = useMemo(() => {
    const m = new Map<string, { kwh: number; co2: number; pending: boolean }>();
    for (const r of rows ?? []) {
      const e = m.get(r.period) ?? { kwh: 0, co2: 0, pending: false };
      e.kwh += r.kwh; e.co2 += r.kg_co2e; e.pending ||= !r.validated;
      m.set(r.period, e);
    }
    return [...m.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [rows]);

  const byCarrier = useMemo(() => {
    const m = new Map<string, number>();
    for (const r of rows ?? []) m.set(r.carrier, (m.get(r.carrier) ?? 0) + r.kg_co2e);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  }, [rows]);

  const dKwh = sum ? delta(sum.kwh_12m, sum.kwh_prev_12m) : null;
  const dCo2 = sum ? delta(sum.t_co2e_12m, sum.t_co2e_prev_12m) : null;
  const Trend = ({ d }: { d: number | null }) =>
    d == null ? null : (
      <span style={{ color: d <= 0 ? 'var(--ks-low)' : 'var(--ks-critical)', display: 'inline-flex', alignItems: 'center', gap: 3 }}>
        {d <= 0 ? <TrendingDown size={13} /> : <TrendingUp size={13} />} {d > 0 ? '+' : ''}{nf(d, 1)} % vs N-1
      </span>
    );

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Pilotage · Performance environnementale</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Énergie &amp; carbone</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">ISO 50001 · GHG Protocol scopes 1-2-3 · facteurs par pays</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      {sum && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Énergie finale 12 mois" icon={<Zap size={15} />} value={nf(sum.kwh_12m / 1000)} unit="MWh" sub={<Trend d={dKwh} />} /></Card>
          <Card><StatBig label="Empreinte carbone 12 mois" icon={<Leaf size={15} />} accent="var(--ks-low)" value={nf(sum.t_co2e_12m, 1)} unit="tCO₂e" sub={<Trend d={dCo2} />} /></Card>
          <Card><StatBig label="Intensité énergétique" icon={<Ruler size={15} />} value={sum.intensity_kwh_m2 != null ? nf(sum.intensity_kwh_m2) : '—'} unit="kWh/m²·an" sub={`EnPI sur ${nf(sum.surface_m2)} m² inventoriés`} /></Card>
          <Card><StatBig label="Facture énergie & eau" icon={<Wallet size={15} />} value={fcfa(sum.cost_12m)} sub={sum.to_validate ? `${sum.to_validate} relevé(s) à valider` : 'tous relevés validés'} /></Card>
        </div>
      )}

      <div className="kt-dash kt-dash--21 ks-reveal" style={{ marginBottom: 18 }}>
        <Card>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, marginBottom: 14 }}>
            <div>
              <div className="kt-cardtitle">{view === 'kwh' ? 'Consommation mensuelle' : 'Émissions mensuelles'}</div>
              <div className="kt-cardsub">{view === 'kwh' ? 'MWh énergie finale (électricité + gazole)' : 'tCO₂e tous scopes'} · mois hachurés = relevés à valider</div>
            </div>
            <TabBar tabs={[{ id: 'kwh', label: 'MWh' }, { id: 'co2', label: 'tCO₂e' }]} active={view} onChange={(v) => setView(v as 'kwh' | 'co2')} />
          </div>
          <BarChart
            height={190}
            data={months.map(([p, v]) => {
              const val = view === 'kwh' ? v.kwh / 1000 : v.co2 / 1000;
              return {
                label: month(p), value: val, display: nf(val, view === 'kwh' ? 0 : 1),
                color: v.pending ? 'repeating-linear-gradient(45deg, var(--ks-amber-100) 0 4px, var(--ks-amber) 4px 6px)' : view === 'kwh' ? 'var(--ks-amber)' : 'var(--ks-low)',
              };
            })}
          />
        </Card>

        <Card>
          <div className="kt-cardtitle">Répartition par scope</div>
          <div className="kt-cardsub">GHG Protocol · 12 mois glissants</div>
          {sum && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 20, marginTop: 16, flexWrap: 'wrap' }}>
              <Donut
                size={140} stroke={18}
                data={[
                  { label: 'Scope 1', value: sum.scope1_t, color: 'var(--ks-high)' },
                  { label: 'Scope 2', value: sum.scope2_t, color: 'var(--ks-amber)' },
                  { label: 'Scope 3', value: sum.scope3_t, color: 'var(--ks-info)' },
                ]}
                center={<span style={{ textAlign: 'center' }}><b className="ks-mono" style={{ fontSize: 18 }}>{nf(sum.t_co2e_12m, 0)}</b><br /><span className="ks-faint" style={{ fontSize: 10.5 }}>tCO₂e</span></span>}
              />
              <Legend items={[
                { label: 'Scope 1 · combustion + fuites', color: 'var(--ks-high)', value: `${nf(sum.scope1_t, 1)} t` },
                { label: 'Scope 2 · électricité réseau', color: 'var(--ks-amber)', value: `${nf(sum.scope2_t, 1)} t` },
                { label: 'Scope 3 · eau', color: 'var(--ks-info)', value: `${nf(sum.scope3_t, 1)} t` },
              ]} />
            </div>
          )}
          {sum && sum.refrigerant_t > 0 && (
            <div className="ke-callout">
              <Snowflake size={14} /> Les fuites de fluide frigorigène pèsent <b>{nf(sum.refrigerant_t, 1)} tCO₂e</b>, soit {nf((sum.refrigerant_t / Math.max(1, sum.t_co2e_12m)) * 100, 1)} % du bilan : chaque kg de R134a vaut 1,43 t de CO₂.
            </div>
          )}
        </Card>
      </div>

      <div className="kt-dash kt-dash--2 ks-reveal">
        <Card pad={false}>
          <div style={{ padding: '16px 20px 6px' }}><div className="kt-cardtitle">Objectifs mensuels</div><div className="kt-cardsub">dernier mois relevé · cible / alerte / critique</div></div>
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Site · flux</th><th>Réel</th><th>Écart cible</th><th>Statut</th></tr></thead>
              <tbody>
                {(targets ?? []).map((t) => {
                  const c = CARRIER[t.carrier];
                  const st = TARGET[t.status];
                  const pos = t.actual != null ? Math.min(100, (t.actual / t.critical) * 100) : 0;
                  return (
                    <tr key={t.site + t.carrier}>
                      <td><div style={{ fontWeight: 600, display: 'flex', gap: 6, alignItems: 'center' }}><span style={{ color: c?.color }}>{c?.icon}</span>{c?.label ?? t.carrier}</div><div className="ks-faint" style={{ fontSize: 12 }}>{t.site}</div></td>
                      <td style={{ minWidth: 140 }}>
                        <div className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{t.actual != null ? nf(t.actual) : '—'} <span className="ks-faint" style={{ fontWeight: 400 }}>{t.unit}</span></div>
                        <div className="ke-scale">
                          <span style={{ left: `${(t.target / t.critical) * 100}%` }} className="ke-scale__tick" title="cible" />
                          <span style={{ left: `${(t.alert / t.critical) * 100}%` }} className="ke-scale__tick ke-scale__tick--alert" title="alerte" />
                          <span style={{ left: `${pos}%` }} className="ke-scale__dot" />
                        </div>
                      </td>
                      <td className="ks-mono" style={{ fontSize: 12.5, color: (t.gap_pct ?? 0) > 0 ? 'var(--ks-critical)' : 'var(--ks-low)' }}>{t.gap_pct != null ? `${t.gap_pct > 0 ? '+' : ''}${nf(t.gap_pct, 1)} %` : '—'}</td>
                      <td><span className={`ks-risk ks-risk--${st.risk}`}>{st.label}</span></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>

        <Card>
          <div className="kt-cardtitle">Contributeurs d’émissions</div>
          <div className="kt-cardsub">par flux, 12 mois</div>
          <div style={{ marginTop: 10 }}>
            {byCarrier.map(([k, kg]) => {
              const c = CARRIER[k];
              const tot = byCarrier.reduce((s, [, v]) => s + v, 0) || 1;
              return (
                <div key={k} className="kt-energy-row">
                  <span style={{ color: c?.color, display: 'grid', placeItems: 'center', width: 28, height: 28, borderRadius: 8, background: 'var(--ks-surface-2)' }}>{c?.icon}</span>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}><b style={{ fontWeight: 600 }}>{c?.label ?? k}</b><span className="ks-mono">{nf(kg / 1000, 1)} t</span></div>
                    <div className="ka-life__track" style={{ marginTop: 6 }}><div style={{ width: `${(kg / tot) * 100}%`, background: c?.color ?? 'var(--ks-ink-2)' }} /></div>
                  </div>
                </div>
              );
            })}
          </div>
          {sum?.indicative_factors && (
            <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 14, display: 'flex', gap: 6, lineHeight: 1.5 }}>
              <Info size={13} style={{ flexShrink: 0, marginTop: 2 }} /> Certains facteurs d’émission sont indicatifs (mix réseau national). Remplacez-les par les facteurs officiels du pays dans le référentiel avant toute publication du bilan.
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
