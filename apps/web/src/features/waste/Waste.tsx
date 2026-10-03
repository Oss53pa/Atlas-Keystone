import { useEffect, useMemo, useState } from 'react';
import { Recycle, Trash2, Biohazard, FileWarning, RefreshCw, AlertTriangle, Target, Leaf } from 'lucide-react';
import { Card, StatBig, Donut, Legend } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { WasteRow, WasteMonthly, WasteSummary, WasteObjective, WasteStream, WasteTreatment } from '@keystone/domain/db/keystone';
import { fetchWaste, fetchWasteMonthly, fetchWasteSummary, fetchWasteObjectives } from '../../data/waste.ts';

const fcfa = (n: number) => format(money(n, 'XOF'));
const nf = (n: number, d = 0) => n.toLocaleString('fr-FR', { maximumFractionDigits: d });
const STREAM: Record<WasteStream, { label: string; color: string }> = {
  dib: { label: 'DIB (tout-venant)', color: '#8C8270' }, paper: { label: 'Papier / carton', color: '#C9821C' },
  plastic: { label: 'Plastique', color: '#355FD6' }, organic: { label: 'Biodéchets', color: '#3F8A45' },
  glass: { label: 'Verre', color: '#0F6E56' }, metal: { label: 'Métaux', color: '#6E6557' },
  dangerous: { label: 'Déchets dangereux', color: '#DC2F34' }, electronic: { label: 'DEEE', color: '#7A3FB0' },
};
const TREAT: Record<WasteTreatment, string> = { recycling: 'Recyclage', valorization: 'Valorisation', reuse: 'Réemploi', elimination: 'Élimination' };
const OBJ = {
  achieved: { label: 'Atteint', risk: 'low' }, on_track: { label: 'En bonne voie', risk: 'low' },
  at_risk: { label: 'À risque', risk: 'high' }, failed: { label: 'Hors objectif', risk: 'critical' }, no_data: { label: 'Sans données', risk: 'info' },
} as const;
const month = (s: string) => new Date(s).toLocaleDateString('fr-FR', { month: 'short' }).replace('.', '');

export function Waste() {
  const [rows, setRows] = useState<WasteRow[] | null>(null);
  const [monthly, setMonthly] = useState<WasteMonthly[] | null>(null);
  const [sum, setSum] = useState<WasteSummary | null>(null);
  const [objs, setObjs] = useState<WasteObjective[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [onlyRegulated, setOnlyRegulated] = useState(false);

  function load() {
    fetchWaste().then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchWasteMonthly().then(setMonthly).catch(() => {});
    fetchWasteSummary().then(setSum).catch(() => {});
    fetchWasteObjectives().then(setObjs).catch(() => {});
  }
  useEffect(load, []);

  const byStream = useMemo(() => {
    const m = new Map<WasteStream, number>();
    for (const r of rows ?? []) m.set(r.stream, (m.get(r.stream) ?? 0) + r.quantity_kg);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  }, [rows]);
  const peak = Math.max(1, ...(monthly ?? []).map((m) => m.total_kg));
  const shown = (rows ?? []).filter((r) => !onlyRegulated || r.stream === 'dangerous' || r.stream === 'electronic');

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Pilotage · Environnement</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Déchets &amp; filières</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">registre réglementaire · bordereaux BSD · opérateurs agréés · ISO 14001</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      {sum && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Tonnage depuis janvier" icon={<Trash2 size={15} />} value={nf(sum.total_t_ytd, 1)} unit="t" sub={sum.total_t_prev_ytd ? `N-1 même période : ${nf(sum.total_t_prev_ytd, 1)} t` : undefined} /></Card>
          <Card><StatBig label="Taux de valorisation" icon={<Recycle size={15} />} accent={(sum.valorization_pct ?? 0) >= 75 ? 'var(--ks-low)' : 'var(--ks-amber)'} value={sum.valorization_pct ?? '—'} unit="%" sub="recyclage + valorisation + réemploi" /></Card>
          <Card><StatBig label="Déchets dangereux" icon={<Biohazard size={15} />} accent="var(--ks-critical)" value={nf(sum.dangerous_t_ytd, 2)} unit="t" sub={`${fcfa(sum.cost_ytd)} de coût de traitement`} /></Card>
          <Card><StatBig label="Certificats manquants" icon={<FileWarning size={15} />} accent={sum.missing_certificates ? 'var(--ks-critical)' : 'var(--ks-low)'} value={sum.missing_certificates} sub={sum.operators_expiring ? `${sum.operators_expiring} agrément(s) opérateur à renouveler` : 'agréments opérateurs valides'} /></Card>
        </div>
      )}

      <div className="kt-dash kt-dash--21 ks-reveal" style={{ marginBottom: 18 }}>
        <Card>
          <div className="kt-cardtitle">Tonnage mensuel &amp; part valorisée</div>
          <div className="kt-cardsub">vert = valorisé · gris = éliminé · % = taux de valorisation du mois</div>
          <div className="kn-load" style={{ height: 200 }}>
            {(monthly ?? []).map((m) => (
              <div key={m.period} className="kn-load__col">
                <div className="kn-load__val ks-mono" style={{ color: (m.valorization_pct ?? 0) >= 75 ? 'var(--ks-low)' : 'var(--ks-ink-2)' }}>{m.valorization_pct != null ? `${Math.round(m.valorization_pct)} %` : ''}</div>
                <div className="kn-load__track">
                  <span className="ks-grow" style={{ height: `${(m.eliminated_kg / peak) * 100}%`, background: 'var(--ks-line-strong)' }} />
                  <span className="ks-grow" style={{ height: `${(m.valorized_kg / peak) * 100}%`, background: 'var(--ks-low)' }} />
                </div>
                <div className="kn-load__lbl">{month(m.period)}</div>
              </div>
            ))}
          </div>
        </Card>
        <Card>
          <div className="kt-cardtitle">Répartition par flux</div>
          <div className="kt-cardsub">12 mois · tonnes</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 18, marginTop: 14, flexWrap: 'wrap' }}>
            <Donut size={130} stroke={18}
              data={byStream.map(([k, v]) => ({ label: STREAM[k].label, value: v, color: STREAM[k].color }))}
              center={<span style={{ textAlign: 'center' }}><b className="ks-mono" style={{ fontSize: 17 }}>{nf(byStream.reduce((s, [, v]) => s + v, 0) / 1000, 0)}</b><br /><span className="ks-faint" style={{ fontSize: 10.5 }}>tonnes</span></span>} />
            <Legend items={byStream.slice(0, 6).map(([k, v]) => ({ label: STREAM[k].label, color: STREAM[k].color, value: `${nf(v / 1000, 1)} t` }))} />
          </div>
          {sum && <div className="ks-faint" style={{ fontSize: 12, marginTop: 14, display: 'flex', gap: 6 }}><Leaf size={13} /> Empreinte des déchets depuis janvier : <b className="ks-mono" style={{ color: 'var(--ks-ink)' }}>{nf(sum.t_co2e_ytd, 1)} tCO₂e</b> (scope 3, facteurs indicatifs)</div>}
        </Card>
      </div>

      {objs && objs.length > 0 && (
        <div className="kt-dash kt-dash--3 ks-reveal" style={{ marginBottom: 18 }}>
          {objs.map((o) => {
            const st = OBJ[o.status];
            const unit = o.kind === 'dangerous_max' ? ' kg/mois' : ' %';
            return (
              <Card key={o.kind}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                  <div className="ks-eyebrow" style={{ display: 'flex', gap: 6, alignItems: 'center' }}><Target size={12} /> Objectif {new Date().getFullYear()}</div>
                  <span className={`ks-risk ks-risk--${st.risk}`}>{st.label}</span>
                </div>
                <div style={{ fontWeight: 600, fontSize: 14, margin: '8px 0 6px' }}>{o.label}</div>
                <div className="ks-mono" style={{ fontSize: 22, fontWeight: 700 }}>{o.actual != null ? nf(o.actual, 1) : '—'}<span className="ks-faint" style={{ fontSize: 12, fontWeight: 500 }}>{unit} · cible {nf(o.target)}{unit}</span></div>
              </Card>
            );
          })}
        </div>
      )}

      <div className="kt-section-h">
        <h2>Registre des enlèvements</h2>
        <label className="ks-faint" style={{ fontSize: 12.5, display: 'inline-flex', gap: 6, alignItems: 'center', cursor: 'pointer' }}>
          <input type="checkbox" checked={onlyRegulated} onChange={(e) => setOnlyRegulated(e.target.checked)} /> Dangereux &amp; DEEE uniquement
        </label>
      </div>
      {rows && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Date</th><th>Flux</th><th>Filière</th><th>Quantité</th><th>Opérateur</th><th>BSD · certificat</th><th>CO₂e</th></tr></thead>
              <tbody>
                {shown.slice(0, 60).map((r) => (
                  <tr key={r.id}>
                    <td className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{new Date(r.collected_on).toLocaleDateString('fr-FR')}<div>{r.site}</div></td>
                    <td><span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontWeight: 600 }}><i className="kw-dot" style={{ background: STREAM[r.stream].color }} />{STREAM[r.stream].label}</span></td>
                    <td style={{ fontSize: 12.5, color: r.treatment === 'elimination' ? 'var(--ks-ink-2)' : 'var(--ks-low)' }}>{TREAT[r.treatment]}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{nf(r.quantity_kg)} kg{!r.validated && <div className="ks-faint" style={{ fontSize: 10.5, fontWeight: 400 }}>à valider · {r.source}</div>}</td>
                    <td style={{ fontSize: 12.5 }}>{r.operator ?? '—'}</td>
                    <td style={{ fontSize: 11.5 }}>
                      {r.bsd_ref ? <span className="ks-mono">{r.bsd_ref}</span> : <span className="ks-faint">—</span>}
                      {r.missing_certificate ? <div style={{ color: 'var(--ks-critical)', fontWeight: 600 }}>certificat manquant</div> : r.certificate_ref ? <div className="ks-mono ks-faint">{r.certificate_ref}</div> : null}
                    </td>
                    <td className="ks-mono ks-faint" style={{ fontSize: 12 }}>{nf(r.kg_co2e)} kg</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12 }} className="ks-faint">
            La base refuse tout enlèvement de déchet dangereux ou DEEE sans bordereau (<span className="ks-mono">BSD_REQUIRED</span>) ou confié à un opérateur dont l’agrément est échu (<span className="ks-mono">OPERATOR_NOT_APPROVED</span>).
          </div>
        </Card>
      )}
    </div>
  );
}
