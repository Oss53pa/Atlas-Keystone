import { Fragment, useEffect, useMemo, useState } from 'react';
import {
  Gauge, Zap, Droplets, RefreshCw, CheckCircle2, ShieldAlert, X, Scale, FileSearch, ReceiptText, Calculator, AlertTriangle,
  CornerDownRight, PencilLine, Save, Info, Send,
} from 'lucide-react';
import { Card, StatBig, TabBar, Sparkline } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { MeterRow, BalanceRow, BillCheckRow, RebillRow, Tariff, TariffBreakdown, UtilitiesSummary } from '@keystone/domain/db/keystone';
import {
  fetchMeters, fetchBalance, fetchBillCheck, fetchRebill, rebillPost, fetchTariffs, tariffCompute, recordReading, fetchUtilitiesSummary, saveBand, saveTariff,
} from '../../data/utilities.ts';

const fcfa = (n: number) => format(money(Math.round(n), 'XOF'));
const nf = (n: number | null | undefined, d = 0) => (n == null ? '—' : n.toLocaleString('fr-FR', { maximumFractionDigits: d }));
const monthLabel = (s: string) => new Date(s).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
const monthShort = (s: string) => new Date(s).toLocaleDateString('fr-FR', { month: 'short' }).replace('.', '');
const unitLabel = (u: string) => (u === 'm3' ? 'm³' : u);
const CARRIER = {
  electricity: { label: 'Électricité', icon: <Zap size={14} />, color: 'var(--ks-amber)' },
  water: { label: 'Eau', icon: <Droplets size={14} />, color: 'var(--ks-info)' },
} as const;
const ANOMALY: Record<string, { label: string; risk: 'critical' | 'high' | 'medium' }> = {
  SPIKE: { label: 'Pic de consommation', risk: 'high' }, DROP: { label: 'Chute anormale', risk: 'medium' },
  LATE_READING: { label: 'Relevé en retard', risk: 'medium' }, NO_READING: { label: 'Jamais relevé', risk: 'critical' },
};
const BAL: Record<BalanceRow['status'], { label: string; color: string }> = {
  ok: { label: 'Pertes normales', color: 'var(--ks-low)' }, watch: { label: 'À surveiller', color: 'var(--ks-amber-700)' },
  alert: { label: 'Pertes anormales', color: 'var(--ks-critical)' }, inconsistent: { label: 'Incohérent (Σ sous > général)', color: 'var(--ks-critical)' },
  no_data: { label: 'Sans relevé', color: 'var(--ks-ink-3)' },
};

export function Utilities() {
  const [tab, setTab] = useState('meters');
  const [sum, setSum] = useState<UtilitiesSummary | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [rev, setRev] = useState(0);
  const ok = (m: string) => { setToast(m); setTimeout(() => setToast(null), 4500); setRev((r) => r + 1); };
  const fail = (e: unknown) => setErr(e instanceof Error ? e.message : String(e));
  useEffect(() => { fetchUtilitiesSummary().then(setSum).catch(fail); }, [rev]);

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Pilotage · Fluides</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Compteurs &amp; tarifs</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">sous-comptage · pertes · contrôle des factures CIE / SODECI · refacturation aux preneurs sans marge</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={() => setRev((r) => r + 1)} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && (
        <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}>
          <ShieldAlert size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span>
          <button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button>
        </div>
      )}

      {sum && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Compteurs suivis" icon={<Gauge size={15} />} value={sum.meters} sub={`${sum.sub_meters} sous-compteurs`} /></Card>
          <Card><StatBig label="Pertes électricité" icon={<Zap size={15} />}
            accent={sum.elec_loss_pct == null ? undefined : sum.elec_loss_pct > 15 ? 'var(--ks-critical)' : sum.elec_loss_pct > 10 ? 'var(--ks-amber)' : 'var(--ks-low)'}
            value={sum.elec_loss_pct == null ? '—' : `${nf(sum.elec_loss_pct, 1)} %`} sub={sum.last_period ? `non compté · ${monthLabel(sum.last_period)}` : 'non compté'} /></Card>
          <Card><StatBig label="Factures en écart" icon={<FileSearch size={15} />} accent={sum.bill_alerts ? 'var(--ks-critical)' : 'var(--ks-low)'}
            value={sum.bill_alerts} sub={sum.bill_alerts ? `${fcfa(sum.bill_overcharge)} HT à réclamer` : 'conformes à la grille'} /></Card>
          <Card><StatBig label="Anomalies de relevé" icon={<AlertTriangle size={15} />} accent={sum.anomalies ? 'var(--ks-high)' : 'var(--ks-low)'}
            value={sum.anomalies} sub={`${sum.late_readings} relevé(s) en retard`} /></Card>
        </div>
      )}

      <div style={{ marginBottom: 16 }}>
        <TabBar tabs={[
          { id: 'meters', label: 'Compteurs', icon: <Gauge size={15} /> },
          { id: 'balance', label: 'Bilan de sous-comptage', icon: <Scale size={15} /> },
          { id: 'bills', label: 'Contrôle des factures', icon: <FileSearch size={15} /> },
          { id: 'rebill', label: 'Refacturation preneurs', icon: <ReceiptText size={15} /> },
          { id: 'tariffs', label: 'Grilles tarifaires', icon: <Calculator size={15} /> },
        ]} active={tab} onChange={setTab} />
      </div>

      {tab === 'meters' && <MetersTab rev={rev} onOk={ok} onErr={fail} />}
      {tab === 'balance' && <BalanceTab rev={rev} onErr={fail} />}
      {tab === 'bills' && <BillsTab rev={rev} onErr={fail} />}
      {tab === 'rebill' && <RebillTab rev={rev} onOk={ok} onErr={fail} />}
      {tab === 'tariffs' && <TariffsTab rev={rev} onOk={ok} onErr={fail} />}
    </div>
  );
}

/* ============================ Compteurs ============================ */
function MetersTab({ rev, onOk, onErr }: { rev: number; onOk: (m: string) => void; onErr: (e: unknown) => void }) {
  const [rows, setRows] = useState<MeterRow[] | null>(null);
  const [reading, setReading] = useState<string | null>(null);
  useEffect(() => { fetchMeters().then(setRows).catch(onErr); }, [rev]); // eslint-disable-line react-hooks/exhaustive-deps

  const groups = useMemo(() => {
    const mains = (rows ?? []).filter((m) => m.kind === 'main');
    return mains.map((m) => ({ main: m, subs: (rows ?? []).filter((s) => s.parent_id === m.id) }));
  }, [rows]);

  if (!rows) return null;
  if (rows.length === 0) return <Card><div className="ks-dim" style={{ textAlign: 'center', padding: 24 }}>Aucun compteur déclaré.</div></Card>;

  const row = (m: MeterRow, sub = false) => {
    const a = m.anomaly ? ANOMALY[m.anomaly] : null;
    return (
      <Fragment key={m.id}>
        <tr className={sub ? 'ku-sub' : 'ku-main'}>
          <td>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              {sub && <CornerDownRight size={13} className="ks-faint" />}
              <div style={{ minWidth: 0 }}>
                <div className="ks-mono ks-faint" style={{ fontSize: 11 }}>{m.code}{m.provider_contract ? ` · ${m.provider_contract}` : ''}</div>
                <div style={{ fontWeight: sub ? 600 : 700, fontSize: sub ? 13 : 14 }}>{m.name}</div>
                {!sub && <div className="ks-faint" style={{ fontSize: 11.5 }}>{m.tariff ?? 'sans contrat'}{m.subscribed_kva ? ` · ${nf(m.subscribed_kva)} kVA souscrits` : ''}</div>}
              </div>
            </div>
          </td>
          <td style={{ fontSize: 12.5 }}>
            {m.space_code ? <><span className="ks-mono">{m.space_code}</span><div className="ks-faint" style={{ fontSize: 11.5 }}>{m.lessee ?? 'lot vacant'}</div></>
              : <span className="ks-faint">{sub ? `Parties communes · ${m.usage ?? ''}` : m.site}</span>}
          </td>
          <td>
            <div className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{nf(m.last_index)}</div>
            <div className="ks-faint" style={{ fontSize: 11 }}>{m.last_read_at ? new Date(m.last_read_at).toLocaleDateString('fr-FR') : 'jamais'}</div>
          </td>
          <td>
            <div className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{nf(m.last_qty)} <span className="ks-faint" style={{ fontWeight: 400 }}>{unitLabel(m.unit)}</span></div>
            {m.variation_pct != null && (
              <div style={{ fontSize: 11, color: Math.abs(m.variation_pct) > 30 ? 'var(--ks-critical)' : 'var(--ks-ink-3)' }}>
                {m.variation_pct > 0 ? '+' : ''}{nf(m.variation_pct, 1)} % vs moy. 3 mois
              </div>
            )}
          </td>
          <td><Sparkline data={m.series} width={86} height={26} color={a ? 'var(--ks-critical)' : CARRIER[m.carrier].color} /></td>
          <td>{a ? <span className={`ks-risk ks-risk--${a.risk}`}>{a.label}</span> : <span className="ks-faint" style={{ fontSize: 12 }}>—</span>}</td>
          <td style={{ textAlign: 'right' }}>
            <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setReading(reading === m.id ? null : m.id)}><PencilLine size={13} /> Relever</button>
          </td>
        </tr>
        {reading === m.id && (
          <tr><td colSpan={7} style={{ background: 'var(--ks-surface-2)' }}>
            <ReadingForm meter={m} onCancel={() => setReading(null)} onErr={onErr}
              onDone={(msg) => { setReading(null); onOk(msg); }} />
          </td></tr>
        )}
      </Fragment>
    );
  };

  return (
    <div className="ks-reveal" style={{ display: 'grid', gap: 16 }}>
      {groups.map(({ main, subs }) => (
        <Card key={main.id} pad={false}>
          <div className="ku-head">
            <span className="ku-carrier" style={{ color: CARRIER[main.carrier].color }}>{CARRIER[main.carrier].icon} {CARRIER[main.carrier].label}</span>
            <span className="ks-faint" style={{ fontSize: 12.5 }}>{main.site} · {subs.length} sous-compteur(s)</span>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Compteur</th><th>Lot · preneur</th><th>Dernier index</th><th>Dernier mois</th><th>12 mois</th><th>Contrôle</th><th /></tr></thead>
              <tbody>
                {row(main)}
                {subs.map((s) => row(s, true))}
              </tbody>
            </table>
          </div>
        </Card>
      ))}
    </div>
  );
}

function ReadingForm({ meter, onCancel, onDone, onErr }: { meter: MeterRow; onCancel: () => void; onDone: (m: string) => void; onErr: (e: unknown) => void }) {
  const [day, setDay] = useState(new Date().toISOString().slice(0, 10));
  const [idx, setIdx] = useState<string>(meter.last_index != null ? String(meter.last_index) : '');
  const [reset, setReset] = useState(false);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const v = Number(idx);
  const back = !reset && meter.last_index != null && idx !== '' && v < meter.last_index;
  async function submit() {
    setBusy(true);
    try {
      const r = await recordReading(meter.id, day, v, reset, note.trim() || undefined);
      const q = r.qty == null ? '' : ` · ${nf(r.qty)} ${unitLabel(meter.unit)} depuis le relevé précédent`;
      onDone(`${meter.code} relevé${q}${r.flag === 'SPIKE' ? ' — ⚠ pic détecté' : r.flag === 'DROP' ? ' — ⚠ chute anormale' : ''}`);
    } catch (e) { onErr(e); } finally { setBusy(false); }
  }
  return (
    <div className="ku-reading">
      <label className="kx-lbl">Date du relevé<input className="kx-in" type="date" value={day} max={new Date().toISOString().slice(0, 10)} onChange={(e) => setDay(e.target.value)} /></label>
      <label className="kx-lbl">Index ({unitLabel(meter.unit)})<input className="kx-in ks-mono" type="number" min={0} value={idx} onChange={(e) => setIdx(e.target.value)}
        style={back ? { borderColor: 'var(--ks-critical)' } : undefined} /></label>
      <label className="kx-lbl" style={{ flex: 2 }}>Observation<input className="kx-in" value={note} onChange={(e) => setNote(e.target.value)} placeholder="ex. photo du cadran jointe, compteur scellé" /></label>
      <label className="ku-check"><input type="checkbox" checked={reset} onChange={(e) => setReset(e.target.checked)} /> compteur remplacé (index repart de 0)</label>
      <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
        <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={onCancel}>Annuler</button>
        <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy || idx === '' || back} onClick={() => void submit()}><Save size={13} /> Enregistrer</button>
      </div>
      {back && <div className="ku-warn">Index inférieur au dernier relevé ({nf(meter.last_index)}) — refusé, sauf remplacement du compteur.</div>}
    </div>
  );
}

/* ============================ Bilan de sous-comptage ============================ */
function BalanceTab({ rev, onErr }: { rev: number; onErr: (e: unknown) => void }) {
  const [rows, setRows] = useState<BalanceRow[] | null>(null);
  useEffect(() => { fetchBalance(6).then(setRows).catch(onErr); }, [rev]); // eslint-disable-line react-hooks/exhaustive-deps
  const mains = useMemo(() => {
    const m = new Map<string, BalanceRow[]>();
    for (const r of rows ?? []) m.set(r.main_id, [...(m.get(r.main_id) ?? []), r]);
    return [...m.values()].map((v) => v.sort((a, b) => a.period.localeCompare(b.period)));
  }, [rows]);
  if (!rows) return null;
  return (
    <div className="ks-reveal" style={{ display: 'grid', gap: 16 }}>
      {mains.map((series) => {
        const h = series[0];
        const c = CARRIER[h.carrier as 'electricity' | 'water'];
        const max = Math.max(...series.map((s) => Math.max(s.main_qty, s.sub_qty)), 1);
        const last = series[series.length - 1];
        return (
          <Card key={h.main_id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap', alignItems: 'flex-start' }}>
              <div>
                <div className="kt-cardtitle"><span style={{ color: c.color }}>{c.icon}</span> {c.label} — {h.site}</div>
                <div className="kt-cardsub">compteur général <span className="ks-mono">{h.main_code}</span> vs somme des sous-compteurs</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="ks-mono" style={{ fontSize: 22, fontWeight: 800, color: BAL[last.status].color }}>{nf(last.loss_pct, 1)} %</div>
                <div style={{ fontSize: 12, color: BAL[last.status].color, fontWeight: 600 }}>{BAL[last.status].label} · {monthLabel(last.period)}</div>
              </div>
            </div>
            <div className="ku-stack">
              {series.map((s) => (
                <div key={s.period} className="ku-stack__col" title={`${monthLabel(s.period)} — non compté ${nf(s.unmetered_qty)} ${unitLabel(s.unit)}`}>
                  <div className="ku-stack__val ks-mono" style={{ color: BAL[s.status].color }}>{nf(s.loss_pct, 1)} %</div>
                  <div className="ku-stack__track" style={{ height: `${(s.main_qty / max) * 100}%` }}>
                    <div style={{ flex: Math.max(0, s.unmetered_qty), background: s.status === 'alert' ? 'var(--ks-critical)' : s.status === 'watch' ? 'var(--ks-amber)' : 'var(--ks-line-strong)' }} />
                    <div style={{ flex: s.common_qty, background: 'var(--ks-info)', opacity: 0.55 }} />
                    <div style={{ flex: s.leased_qty, background: c.color }} />
                  </div>
                  <div className="ku-stack__lbl">{monthShort(s.period)}</div>
                </div>
              ))}
            </div>
            <div className="ku-legend">
              <span><i style={{ background: c.color }} /> Lots loués (refacturables)</span>
              <span><i style={{ background: 'var(--ks-info)', opacity: 0.55 }} /> Parties communes (charges)</span>
              <span><i style={{ background: 'var(--ks-line-strong)' }} /> Non compté / pertes</span>
            </div>
            <div style={{ overflowX: 'auto', marginTop: 10 }}>
              <table className="ks-table">
                <thead><tr><th>Mois</th><th>Général</th><th>Lots loués</th><th>Communs</th><th>Non compté</th><th>Statut</th></tr></thead>
                <tbody>
                  {[...series].reverse().map((s) => (
                    <tr key={s.period}>
                      <td style={{ textTransform: 'capitalize' }}>{monthLabel(s.period)}</td>
                      <td className="ks-mono">{nf(s.main_qty)}</td>
                      <td className="ks-mono">{nf(s.leased_qty)}</td>
                      <td className="ks-mono">{nf(s.common_qty)}</td>
                      <td className="ks-mono" style={{ fontWeight: 700, color: BAL[s.status].color }}>{nf(s.unmetered_qty)} · {nf(s.loss_pct, 1)} %</td>
                      <td style={{ fontSize: 12.5, color: BAL[s.status].color, fontWeight: 600 }}>{BAL[s.status].label}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        );
      })}
      {mains.length === 0 && <Card><div className="ks-dim" style={{ textAlign: 'center', padding: 24 }}>Aucun compteur général avec sous-compteurs relevés.</div></Card>}
      <div className="ks-faint" style={{ fontSize: 12, lineHeight: 1.6 }}>
        <Info size={12} style={{ verticalAlign: -1 }} /> Non compté = général − Σ sous-compteurs. Au-delà de 10 % : à surveiller ; au-delà de 15 % : pertes anormales
        (fuite, branchement non déclaré, sous-compteur défaillant). Un relevé manquant gonfle mécaniquement les pertes du mois.
      </div>
    </div>
  );
}

/* ============================ Contrôle des factures CIE / SODECI ============================ */
function BillsTab({ rev, onErr }: { rev: number; onErr: (e: unknown) => void }) {
  const [rows, setRows] = useState<BillCheckRow[] | null>(null);
  const [open, setOpen] = useState<string | null>(null);
  useEffect(() => { fetchBillCheck(12).then(setRows).catch(onErr); }, [rev]); // eslint-disable-line react-hooks/exhaustive-deps
  if (!rows) return null;
  const S = { ok: { label: 'Conforme', risk: 'low' }, watch: { label: 'Écart 4–8 %', risk: 'medium' }, alert: { label: 'Écart > 8 %', risk: 'critical' }, no_amount: { label: 'Montant absent', risk: 'info' } } as const;
  return (
    <Card pad={false} className="ks-reveal">
      <div style={{ overflowX: 'auto' }}>
        <table className="ks-table">
          <thead><tr><th>Période</th><th>Site · fluide</th><th>Quantité facturée</th><th>Montant facturé HT</th><th>Recalculé (grille)</th><th>Écart</th><th>Contrôle</th></tr></thead>
          <tbody>
            {rows.map((r) => {
              const key = `${r.site}-${r.carrier}-${r.period}`;
              const c = CARRIER[r.carrier as 'electricity' | 'water'];
              return (
                <Fragment key={key}>
                  <tr className="kq-row" onClick={() => setOpen(open === key ? null : key)}>
                    <td style={{ textTransform: 'capitalize' }}>{monthLabel(r.period)}</td>
                    <td><span style={{ color: c.color }}>{c.icon}</span> <b>{r.provider}</b> <span className="ks-faint" style={{ fontSize: 12 }}>· {r.site}</span></td>
                    <td className="ks-mono">{nf(r.invoiced_qty)} {unitLabel(r.breakdown?.unit ?? '')}</td>
                    <td className="ks-mono" style={{ fontWeight: 600 }}>{r.invoiced_ht == null ? '—' : fcfa(r.invoiced_ht)}</td>
                    <td className="ks-mono">{fcfa(r.computed_ht)}</td>
                    <td className="ks-mono" style={{ fontWeight: 700, color: r.status === 'alert' ? 'var(--ks-critical)' : r.status === 'watch' ? 'var(--ks-amber-700)' : 'var(--ks-low)' }}>
                      {r.variance == null ? '—' : `${r.variance > 0 ? '+' : ''}${fcfa(r.variance)}`}
                      {r.variance_pct != null && <div style={{ fontSize: 11 }}>{r.variance_pct > 0 ? '+' : ''}{nf(r.variance_pct, 1)} %</div>}
                    </td>
                    <td><span className={`ks-risk ks-risk--${S[r.status].risk}`}>{S[r.status].label}</span></td>
                  </tr>
                  {open === key && r.breakdown && (
                    <tr><td colSpan={7} style={{ background: 'var(--ks-surface-2)' }}><Breakdown b={r.breakdown} invoiced={r.invoiced_ht} /></td></tr>
                  )}
                </Fragment>
              );
            })}
            {rows.length === 0 && <tr><td colSpan={7} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucune facture CIE/SODECI saisie avec un compteur général sous contrat.</td></tr>}
          </tbody>
        </table>
      </div>
      <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12, lineHeight: 1.6 }} className="ks-faint">
        <Info size={12} style={{ verticalAlign: -1 }} /> Chaque facture saisie dans Énergie &amp; carbone est recalculée avec la grille du contrat (tranches, prime de puissance, redevances).
        Un écart &gt; 8 % justifie une réclamation auprès du fournisseur. Les grilles fournies sont indicatives : recalez-les sur une facture réelle dans « Grilles tarifaires ».
      </div>
    </Card>
  );
}

function Breakdown({ b, invoiced }: { b: TariffBreakdown; invoiced?: number | null }) {
  return (
    <div className="ku-breakdown">
      <div>
        {b.lines.map((l) => (
          <div key={l.label} className="kv-line"><span>{l.label} <span className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>{nf(l.qty)} × {nf(l.unit_price, 2)}</span></span><span className="ks-mono">{fcfa(l.amount)}</span></div>
        ))}
        {b.fixed > 0 && <div className="kv-line"><span>Abonnement / redevance fixe</span><span className="ks-mono">{fcfa(b.fixed)}</span></div>}
        {b.demand > 0 && <div className="kv-line"><span>Prime de puissance <span className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>{nf(b.kva)} kVA</span></span><span className="ks-mono">{fcfa(b.demand)}</span></div>}
        {b.levies.map((l) => <div key={l.label} className="kv-line"><span>{l.label} <span className="ks-faint">{nf(l.pct, 2)} %</span></span><span className="ks-mono">{fcfa(l.amount)}</span></div>)}
        <div className="kv-line kv-line--total"><span>Total HT recalculé</span><span className="ks-mono">{fcfa(b.ht)}</span></div>
        <div className="kv-line"><span className="ks-faint">TVA · TTC</span><span className="ks-mono ks-faint">{fcfa(b.vat)} · {fcfa(b.ttc)}</span></div>
      </div>
      <div className="ku-breakdown__side">
        <div className="ks-faint" style={{ fontSize: 11.5 }}>Coût moyen</div>
        <div className="ks-mono" style={{ fontSize: 20, fontWeight: 800 }}>{nf(b.avg_unit, 1)} <span style={{ fontSize: 12, fontWeight: 500 }}>FCFA/{unitLabel(b.unit)}</span></div>
        {invoiced != null && b.qty > 0 && <div className="ks-faint" style={{ fontSize: 12, marginTop: 4 }}>facturé : {nf(invoiced / b.qty, 1)} FCFA/{unitLabel(b.unit)}</div>}
        {b.indicative && <div className="ku-warn" style={{ marginTop: 10 }}>Grille indicative — {b.source}</div>}
      </div>
    </div>
  );
}

/* ============================ Refacturation ============================ */
function RebillTab({ rev, onOk, onErr }: { rev: number; onOk: (m: string) => void; onErr: (e: unknown) => void }) {
  const months = useMemo(() => Array.from({ length: 6 }, (_, i) => {
    const d = new Date(); d.setDate(1); d.setMonth(d.getMonth() - 1 - i);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
  }), []);
  const [period, setPeriod] = useState(months[0]);
  const [rows, setRows] = useState<RebillRow[] | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => { setRows(null); fetchRebill(period).then(setRows).catch(onErr); }, [period, rev]); // eslint-disable-line react-hooks/exhaustive-deps
  const pending = (rows ?? []).filter((r) => !r.posted);
  const tot = pending.reduce((s, r) => s + (r.amount_ht ?? 0), 0);
  async function post() {
    setBusy(true);
    try {
      const r = await rebillPost(period);
      onOk(`${r.posted} refacturation(s) versée(s) dans les échéanciers · ${fcfa(r.amount_ht)} HT${r.skipped ? ` · ${r.skipped} sans échéance ouverte` : ''}`);
    } catch (e) { onErr(e); } finally { setBusy(false); }
  }
  return (
    <div className="ks-reveal">
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'center', marginBottom: 12 }}>
        <div className="kx-chips">
          {months.map((m) => <button key={m} className={`kx-chip${period === m ? ' kx-chip--on' : ''}`} onClick={() => setPeriod(m)} style={{ textTransform: 'capitalize' }}>{monthLabel(m)}</button>)}
        </div>
        <button className="ks-btn ks-btn--primary" disabled={busy || pending.length === 0} onClick={() => void post()}>
          <Send size={15} /> {busy ? '…' : pending.length ? `Verser ${fcfa(tot)} HT dans les échéanciers` : 'Tout est versé'}
        </button>
      </div>
      <Card pad={false}>
        <div style={{ overflowX: 'auto' }}>
          <table className="ks-table">
            <thead><tr><th>Preneur · bail</th><th>Sous-compteur</th><th>Consommation</th><th>Coût moyen réel</th><th>Montant HT</th><th>TVA</th><th>Échéance</th></tr></thead>
            <tbody>
              {(rows ?? []).map((r) => (
                <tr key={r.meter_id}>
                  <td><div style={{ fontWeight: 600 }}>{r.lessee}</div><div className="ks-mono ks-faint" style={{ fontSize: 11 }}>{r.lease_ref} · {r.space_code}</div></td>
                  <td><span style={{ color: CARRIER[r.carrier as 'electricity' | 'water'].color }}>{CARRIER[r.carrier as 'electricity' | 'water'].icon}</span> <span className="ks-mono" style={{ fontSize: 12 }}>{r.meter_code}</span></td>
                  <td className="ks-mono">{nf(r.qty)} {unitLabel(r.unit)}</td>
                  <td className="ks-mono">{nf(r.unit_cost, 2)} <span className="ks-faint" style={{ fontSize: 11 }}>({r.cost_basis})</span></td>
                  <td className="ks-mono" style={{ fontWeight: 700 }}>{r.amount_ht == null ? '—' : fcfa(r.amount_ht)}</td>
                  <td className="ks-mono ks-faint">{r.vat_amount == null ? '—' : fcfa(r.vat_amount)}</td>
                  <td>{r.posted ? <span className="ks-pill" style={{ color: 'var(--ks-low)' }}><CheckCircle2 size={12} /> versée</span>
                    : <span className="ks-faint" style={{ fontSize: 12 }}>{r.schedule_due ? `avec l’échéance du ${new Date(r.schedule_due).toLocaleDateString('fr-FR')}` : 'aucune échéance ouverte'}</span>}</td>
                </tr>
              ))}
              {rows && rows.length === 0 && <tr><td colSpan={7} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucun sous-compteur de lot loué relevé sur ce mois.</td></tr>}
            </tbody>
          </table>
        </div>
        <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12, lineHeight: 1.6 }} className="ks-faint">
          <Info size={12} style={{ verticalAlign: -1 }} /> Prix = coût total HT du compteur général (facture fournisseur, ou à défaut la grille) ÷ quantité générale : les pertes et les parties communes
          ne sont pas imputées aux preneurs, et aucune marge n’est appliquée. Le montant s’ajoute aux charges de la prochaine échéance non réglée du bail.
        </div>
      </Card>
    </div>
  );
}

/* ============================ Grilles tarifaires & simulateur ============================ */
function TariffsTab({ rev, onOk, onErr }: { rev: number; onOk: (m: string) => void; onErr: (e: unknown) => void }) {
  const [rows, setRows] = useState<Tariff[] | null>(null);
  const [edit, setEdit] = useState<Record<string, number>>({});
  const [sim, setSim] = useState<{ id: string; qty: number; kva: number }>({ id: '', qty: 380000, kva: 1600 });
  const [out, setOut] = useState<TariffBreakdown | null>(null);
  useEffect(() => {
    fetchTariffs().then((t) => { setRows(t); setSim((s) => (s.id ? s : { ...s, id: t[0]?.id ?? '' })); }).catch(onErr);
  }, [rev]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!sim.id) return;
    const h = setTimeout(() => { tariffCompute(sim.id, sim.qty, sim.kva).then(setOut).catch(onErr); }, 250);
    return () => clearTimeout(h);
  }, [sim, rev]); // eslint-disable-line react-hooks/exhaustive-deps

  async function save(t: Tariff) {
    try {
      for (const b of t.bands ?? []) if (edit[b.id] != null && edit[b.id] !== b.unit_price) await saveBand(b.id, edit[b.id]);
      const patch: { fixed_monthly?: number; demand_charge?: number } = {};
      if (edit[`${t.id}:fixed`] != null) patch.fixed_monthly = edit[`${t.id}:fixed`];
      if (edit[`${t.id}:demand`] != null) patch.demand_charge = edit[`${t.id}:demand`];
      if (Object.keys(patch).length) await saveTariff(t.id, patch);
      setEdit({});
      onOk(`Grille ${t.code} mise à jour — les contrôles de factures sont recalculés`);
    } catch (e) { onErr(e); }
  }
  if (!rows) return null;
  const cur = rows.find((t) => t.id === sim.id);
  const SLOT: Record<string, string> = { offpeak: 'Heures creuses', full: 'Heures pleines', peak: 'Pointe', all: '' };

  return (
    <div className="kt-dash kt-dash--21 ks-reveal">
      <div style={{ display: 'grid', gap: 16, alignContent: 'start' }}>
        {rows.map((t) => {
          const c = CARRIER[t.carrier];
          const dirty = Object.keys(edit).some((k) => k.startsWith(`${t.id}:`) || (t.bands ?? []).some((b) => b.id === k));
          return (
            <Card key={t.id}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, alignItems: 'flex-start' }}>
                <div>
                  <div className="kt-cardtitle"><span style={{ color: c.color }}>{c.icon}</span> {t.provider} — {t.name}</div>
                  <div className="kt-cardsub"><span className="ks-mono">{t.code}</span> · en vigueur au {new Date(t.valid_from).toLocaleDateString('fr-FR')} · {t.meters} compteur(s) · TVA {t.vat_rate} %</div>
                </div>
                {t.is_indicative && <span className="ks-pill" style={{ color: 'var(--ks-amber-700)' }}>indicative</span>}
              </div>
              <table className="ks-table ku-bands">
                <thead><tr><th>Tranche</th><th style={{ textAlign: 'right' }}>FCFA / {unitLabel(t.unit)}</th></tr></thead>
                <tbody>
                  {(t.bands ?? []).map((b) => (
                    <tr key={b.id}>
                      <td style={{ fontSize: 12.5 }}>{b.label ?? (b.slot !== 'all' ? SLOT[b.slot] : `${nf(b.from_qty)} – ${b.to_qty == null ? '∞' : nf(b.to_qty)} ${unitLabel(t.unit)}`)}
                        {b.slot !== 'all' && t.default_profile && <span className="ks-faint"> · {nf((t.default_profile[b.slot] ?? 0) * 100)} % du volume</span>}</td>
                      <td style={{ textAlign: 'right' }}>
                        <input className="kx-in kx-in--price" type="number" min={0} step={0.5} value={edit[b.id] ?? b.unit_price} aria-label={`Prix ${b.label ?? b.slot}`}
                          onChange={(e) => setEdit({ ...edit, [b.id]: Number(e.target.value) })} style={{ height: 32, textAlign: 'right' }} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div className="kd-form" style={{ marginTop: 10 }}>
                <label className="kx-lbl">Abonnement fixe / mois (FCFA)
                  <input className="kx-in ks-mono" type="number" min={0} value={edit[`${t.id}:fixed`] ?? t.fixed_monthly} onChange={(e) => setEdit({ ...edit, [`${t.id}:fixed`]: Number(e.target.value) })} /></label>
                {t.carrier === 'electricity' && (
                  <label className="kx-lbl">Prime de puissance (FCFA / kVA / mois)
                    <input className="kx-in ks-mono" type="number" min={0} value={edit[`${t.id}:demand`] ?? t.demand_charge} onChange={(e) => setEdit({ ...edit, [`${t.id}:demand`]: Number(e.target.value) })} /></label>
                )}
              </div>
              {t.levies.length > 0 && <div className="ks-faint" style={{ fontSize: 12, marginTop: 8 }}>Redevances : {t.levies.map((l) => `${l.label} ${nf(l.pct, 2)} %`).join(' · ')}</div>}
              <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 4 }}>{t.source}</div>
              {dirty && <button className="ks-btn ks-btn--primary kx-wide" onClick={() => void save(t)}><Save size={15} /> Enregistrer la grille</button>}
            </Card>
          );
        })}
      </div>
      <Card>
        <div className="kt-cardtitle"><Calculator size={14} style={{ verticalAlign: -2 }} /> Simulateur de facture</div>
        <div className="kt-cardsub">pour vérifier une facture ou chiffrer un changement de puissance souscrite</div>
        <div className="kd-form" style={{ marginTop: 0 }}>
          <label className="kx-lbl" style={{ gridColumn: '1 / -1' }}>Grille
            <select className="kx-in" value={sim.id} onChange={(e) => {
              const t = rows.find((x) => x.id === e.target.value);
              setSim({ id: e.target.value, qty: t?.carrier === 'water' ? 2800 : 380000, kva: t?.carrier === 'water' ? 0 : sim.kva });
            }}>
              {rows.map((t) => <option key={t.id} value={t.id}>{t.provider} — {t.name}</option>)}
            </select>
          </label>
          <label className="kx-lbl">Consommation ({unitLabel(cur?.unit ?? '')})<input className="kx-in ks-mono" type="number" min={0} value={sim.qty} onChange={(e) => setSim({ ...sim, qty: Math.max(0, Number(e.target.value)) })} /></label>
          {cur?.carrier === 'electricity' && (
            <label className="kx-lbl">Puissance souscrite (kVA)<input className="kx-in ks-mono" type="number" min={0} value={sim.kva} onChange={(e) => setSim({ ...sim, kva: Math.max(0, Number(e.target.value)) })} /></label>
          )}
        </div>
        {out && <div style={{ marginTop: 14 }}><Breakdown b={out} /></div>}
      </Card>
    </div>
  );
}
