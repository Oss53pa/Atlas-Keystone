import { useEffect, useMemo, useState } from 'react';
import {
  Building2, Percent, Hourglass, Wallet, RefreshCw, AlertTriangle, CheckCircle2, X, Receipt, Send, TrendingUp, CalendarClock,
  Megaphone, ExternalLink, Banknote, Printer, Scale, FileSpreadsheet, Users,
} from 'lucide-react';
import { Card, StatBig, TabBar } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { RentRollRow, RentSummary, ArrearsRow, ScheduleRow, ChargeRegRow, RentReceipt, NewsItem, ScheduleStatus, ArrearsBucket } from '@keystone/domain/db/keystone';
import {
  fetchRentRoll, fetchRentSummary, fetchArrears, fetchSchedules, fetchChargesRegularization, fetchChargePools, fetchNews, recordRentPayment,
  sendRentReminder, applyIndexation, generateAllSchedules, fetchReceipt, publishNews, fetchSites, type PayMethod,
} from '../../data/leases.ts';

const fcfa = (n: number) => format(money(Math.round(n), 'XOF'));
const nf = (n: number, d = 0) => n.toLocaleString('fr-FR', { maximumFractionDigits: d });
const dd = (s: string | null) => (s ? new Date(s).toLocaleDateString('fr-FR') : '—');
const mon = (s: string) => new Date(s).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
const ST: Record<ScheduleStatus, { label: string; risk: 'low' | 'info' | 'medium' | 'high' | 'critical' }> = {
  paid: { label: 'Soldée', risk: 'low' }, pending: { label: 'À échoir', risk: 'info' }, partial: { label: 'Partielle', risk: 'medium' },
  partial_overdue: { label: 'Partielle échue', risk: 'high' }, overdue: { label: 'Impayée', risk: 'critical' },
};
const METHOD: Record<PayMethod, string> = { transfer: 'Virement', mobile_money: 'Mobile Money', cheque: 'Chèque', cash: 'Espèces', card: 'Carte' };
const BUCKETS: { id: ArrearsBucket; label: string; color: string }[] = [
  { id: '0-30', label: '0–30 j', color: 'var(--ks-amber)' }, { id: '31-60', label: '31–60 j', color: 'var(--ks-high)' },
  { id: '61-90', label: '61–90 j', color: 'var(--ks-critical)' }, { id: '90+', label: '> 90 j', color: '#8E1E22' },
];
const NEWS_KIND: Record<NewsItem['kind'], string> = { info: 'Information', event: 'Événement', maintenance: 'Travaux', safety: 'Sécurité' };

export function Leases() {
  const [tab, setTab] = useState('roll');
  const [sum, setSum] = useState<RentSummary | null>(null);
  const [roll, setRoll] = useState<RentRollRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [revise, setRevise] = useState<RentRollRow | null>(null);
  const [busy, setBusy] = useState(false);

  function load() {
    fetchRentSummary().then(setSum).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchRentRoll().then(setRoll).catch(() => {});
  }
  useEffect(load, []);
  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 5000); };

  async function generate() {
    setBusy(true); setErr(null);
    try { const r = await generateAllSchedules(2); flash(r.created ? `${r.created} échéance(s) générée(s)` : 'Échéancier déjà à jour'); load(); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Pilotage · Gestion locative</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Baux &amp; loyers</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">état locatif · échéancier · balance âgée · indexation · charges récupérables (OHADA)</span>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignSelf: 'end', flexWrap: 'wrap' }}>
          <a className="ks-btn ks-btn--ghost" href="?locataire" target="_blank" rel="noreferrer"><ExternalLink size={15} /> Portail locataire</a>
          <button className="ks-btn ks-btn--ghost" disabled={busy} onClick={generate}><CalendarClock size={15} /> Générer les échéances</button>
          <button className="ks-btn ks-btn--ghost" onClick={load}><RefreshCw size={15} /> Rafraîchir</button>
        </div>
      </header>

      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && (
        <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}>
          <AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span>
          <button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button>
        </div>
      )}

      {sum && (
        <>
          <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 12 }}>
            <Card><StatBig label="Taux d’occupation" icon={<Building2 size={15} />} accent={(sum.occupancy_pct ?? 0) >= 95 ? 'var(--ks-low)' : 'var(--ks-amber)'} value={sum.occupancy_pct ?? '—'} unit="%" sub={`${nf(sum.leased_m2)} / ${nf(sum.gla_m2)} m² GLA`} /></Card>
            <Card><StatBig label="Loyers annuels" icon={<Banknote size={15} />} value={fcfa(sum.annual_rent)} sub={`${sum.leases} baux · ${sum.avg_rent_m2 != null ? fcfa(sum.avg_rent_m2) : '—'}/m²·mois`} /></Card>
            <Card><StatBig label="WALT" icon={<Hourglass size={15} />} value={sum.walt_years ?? '—'} unit="ans" sub="durée résiduelle pondérée par les loyers" /></Card>
            <Card><StatBig label="Recouvrement 12 mois" icon={<Percent size={15} />} accent={(sum.collection_pct ?? 0) >= 97 ? 'var(--ks-low)' : 'var(--ks-high)'} value={sum.collection_pct ?? '—'} unit="%" sub={`impayés ${fcfa(sum.arrears_total)} · ${sum.arrears_lessees} locataire(s)`} /></Card>
          </div>
          <div className="kl-chips ks-reveal">
            <span className={`kl-chip${sum.indexation_due ? ' kl-chip--warn' : ''}`}><TrendingUp size={13} /> {sum.indexation_due} révision(s) de loyer à appliquer</span>
            <span className={`kl-chip${sum.expiring_12m ? ' kl-chip--warn' : ''}`}><CalendarClock size={13} /> {sum.expiring_12m} bail(aux) à échéance sous 12 mois</span>
            <span className="kl-chip"><Wallet size={13} /> Dépôts de garantie : {fcfa(sum.deposits)}</span>
          </div>
        </>
      )}

      <div style={{ margin: '16px 0' }}>
        <TabBar
          tabs={[
            { id: 'roll', label: 'État locatif', icon: <FileSpreadsheet size={15} /> },
            { id: 'schedule', label: 'Échéancier & encaissements', icon: <Receipt size={15} /> },
            { id: 'arrears', label: `Impayés${sum?.arrears_lessees ? ` · ${sum.arrears_lessees}` : ''}`, icon: <AlertTriangle size={15} /> },
            { id: 'charges', label: 'Charges récupérables', icon: <Scale size={15} /> },
            { id: 'news', label: 'Actualités du centre', icon: <Megaphone size={15} /> },
          ]}
          active={tab} onChange={setTab}
        />
      </div>

      {tab === 'roll' && roll && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Locataire · bail</th><th>Lots</th><th>Loyer mensuel</th><th>Fin de bail</th><th>Révision</th><th>Impayé</th><th></th></tr></thead>
              <tbody>
                {roll.map((r) => (
                  <tr key={r.lease_id}>
                    <td>
                      <div style={{ fontWeight: 700 }}>{r.trade_name ?? r.lessee}</div>
                      <div className="ks-faint" style={{ fontSize: 12 }}><span className="ks-mono">{r.ref}</span> · {r.sector ?? '—'}{r.status === 'notice' && <span className="ks-risk ks-risk--high" style={{ marginLeft: 6 }}>préavis</span>}</div>
                    </td>
                    <td style={{ fontSize: 12.5 }}><span className="ks-mono">{r.spaces}</span><div className="ks-faint">{nf(r.area_m2)} m²</div></td>
                    <td><div className="ks-mono" style={{ fontWeight: 700 }}>{fcfa(r.monthly_rent)}</div><div className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>{r.rent_m2_month != null ? `${fcfa(r.rent_m2_month)}/m²` : ''}</div></td>
                    <td>
                      <div className="ks-mono" style={{ fontSize: 12.5 }}>{dd(r.end_date)}</div>
                      {r.months_left != null && <div style={{ fontSize: 11.5, fontWeight: 600, color: r.months_left <= 12 ? 'var(--ks-high)' : 'var(--ks-ink-3)' }}>{r.months_left} mois restants</div>}
                    </td>
                    <td>
                      {r.indexation_due
                        ? <button className="ks-btn ks-btn--ghost ks-btn--sm" onClick={() => setRevise(r)}><TrendingUp size={13} /> Réviser</button>
                        : <span className="ks-faint ks-mono" style={{ fontSize: 12 }}>{dd(r.next_indexation_date)}</span>}
                    </td>
                    <td>{r.arrears > 0
                      ? <><div className="ks-mono" style={{ fontWeight: 700, color: 'var(--ks-critical)' }}>{fcfa(r.arrears)}</div><div className="ks-faint" style={{ fontSize: 11.5 }}>depuis {r.arrears_days} j</div></>
                      : <span className="ks-pill" style={{ color: 'var(--ks-low)' }}>À jour</span>}</td>
                    <td style={{ textAlign: 'right' }}>{r.open_tickets > 0 && <span className="ks-pill" title="Demandes ouvertes"><Users size={11} /> {r.open_tickets}</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {tab === 'schedule' && <SchedulePanel onToast={flash} onError={setErr} onChanged={load} />}
      {tab === 'arrears' && <ArrearsPanel onToast={flash} onError={setErr} onChanged={load} />}
      {tab === 'charges' && <ChargesPanel />}
      {tab === 'news' && <NewsPanel onToast={flash} onError={setErr} />}

      {revise && (
        <ReviseDialog row={revise} onClose={() => setRevise(null)}
          onDone={(m) => { setRevise(null); flash(m); load(); }} />
      )}
    </div>
  );
}

function ReviseDialog({ row, onClose, onDone }: { row: RentRollRow; onClose: () => void; onDone: (m: string) => void }) {
  const [index, setIndex] = useState('');
  const [needIndex, setNeedIndex] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function go() {
    setBusy(true); setErr(null);
    try {
      const r = await applyIndexation(row.lease_id, index ? Number(index) : undefined);
      onDone(`${row.trade_name ?? row.lessee} : loyer ${fcfa(Number(r.old_rent))} → ${fcfa(Number(r.new_rent))} (${Number(r.variation_pct) > 0 ? '+' : ''}${r.variation_pct} %)`);
    } catch (e) {
      const m = e instanceof Error ? e.message : String(e);
      if (m.includes('INDEX_REQUIRED')) { setNeedIndex(true); setErr('Bail indexé : saisissez la valeur actuelle de l’indice de référence.'); } else setErr(m);
    } finally { setBusy(false); }
  }
  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer" style={{ height: 'auto', alignSelf: 'center', borderRadius: 18, margin: 'auto' }} onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Révision du loyer">
        <div className="ka-drawer__head">
          <div><div className="ks-eyebrow">Révision du loyer</div><h2 style={{ fontSize: 20, fontWeight: 800, margin: '4px 0 0' }}>{row.trade_name ?? row.lessee}</h2></div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>
        <div className="kv-line"><span>Loyer actuel</span><b className="ks-mono">{fcfa(row.monthly_rent)}</b></div>
        <div className="kv-line"><span>Échéance de révision</span><b className="ks-mono">{dd(row.next_indexation_date)}</b></div>
        {needIndex && (
          <label className="kx-lbl" style={{ marginTop: 10 }}>Nouvel indice de référence (IPC / indice contractuel)
            <input className="kx-in" type="number" step="0.01" value={index} onChange={(e) => setIndex(e.target.value)} />
          </label>
        )}
        <div className="ks-faint" style={{ fontSize: 12, marginTop: 10, lineHeight: 1.5 }}>Les échéances futures non encore réglées passent au nouveau loyer. La révision est historisée.</div>
        {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12.5, marginTop: 10 }}>{err}</div>}
        <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || (needIndex && !index)} onClick={go}><TrendingUp size={15} /> {busy ? '…' : 'Appliquer la révision'}</button>
      </aside>
    </div>
  );
}

function SchedulePanel({ onToast, onError, onChanged }: { onToast: (m: string) => void; onError: (m: string) => void; onChanged: () => void }) {
  const [rows, setRows] = useState<ScheduleRow[] | null>(null);
  const [pay, setPay] = useState<ScheduleRow | null>(null);
  const [receipt, setReceipt] = useState<RentReceipt | null>(null);
  const [month, setMonth] = useState<string>('');
  function load() { fetchSchedules(undefined, 3).then((r) => { setRows(r); setMonth((m) => m || (r.find((x) => new Date(x.period) <= new Date())?.period ?? r[0]?.period ?? '')); }).catch((e) => onError(String(e))); }
  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps
  const months = useMemo(() => [...new Set((rows ?? []).map((r) => r.period))], [rows]);
  const shown = (rows ?? []).filter((r) => r.period === month);
  const totals = shown.reduce((a, r) => ({ due: a.due + r.total_due, paid: a.paid + r.paid }), { due: 0, paid: 0 });

  return (
    <div className="ks-reveal">
      <div className="kx-chips" style={{ marginBottom: 12 }}>
        {months.map((m) => <button key={m} className={`kx-chip${m === month ? ' kx-chip--on' : ''}`} onClick={() => setMonth(m)}>{mon(m)}</button>)}
      </div>
      {shown.length > 0 && (
        <div className="kl-progress">
          <div className="kl-progress__bar"><span style={{ width: `${Math.min(100, (totals.paid / Math.max(1, totals.due)) * 100)}%` }} /></div>
          <div className="ks-mono" style={{ fontSize: 12.5 }}>{fcfa(totals.paid)} encaissés sur {fcfa(totals.due)} ({nf((totals.paid / Math.max(1, totals.due)) * 100, 1)} %)</div>
        </div>
      )}
      <Card pad={false}>
        <div style={{ overflowX: 'auto' }}>
          <table className="ks-table">
            <thead><tr><th>Locataire</th><th>Échéance</th><th>Loyer + charges + TVA</th><th>Total</th><th>Encaissé</th><th>Statut</th><th></th></tr></thead>
            <tbody>
              {shown.map((r) => (
                <tr key={r.schedule_id}>
                  <td><div style={{ fontWeight: 600 }}>{r.lessee}</div><div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{r.lease_ref}</div></td>
                  <td className="ks-mono" style={{ fontSize: 12.5 }}>{dd(r.due_date)}</td>
                  <td className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{nf(r.rent)} + {nf(r.charges)} + {nf(r.vat)}</td>
                  <td className="ks-mono" style={{ fontWeight: 700 }}>{fcfa(r.total_due)}</td>
                  <td className="ks-mono" style={{ fontSize: 12.5 }}>{fcfa(r.paid)}{r.last_method && <div className="ks-faint" style={{ fontSize: 11 }}>{METHOD[r.last_method as PayMethod] ?? r.last_method}</div>}</td>
                  <td><span className={`ks-risk ks-risk--${ST[r.status].risk}`}>{ST[r.status].label}</span></td>
                  <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                    {r.status === 'paid'
                      ? <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => fetchReceipt(r.schedule_id).then(setReceipt).catch((e) => onError(String(e)))}><Receipt size={13} /> Quittance</button>
                      : <button className="ks-btn ks-btn--ghost ks-btn--sm" onClick={() => setPay(r)}><Banknote size={13} /> Encaisser</button>}
                  </td>
                </tr>
              ))}
              {shown.length === 0 && <tr><td colSpan={7} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucune échéance sur cette période.</td></tr>}
            </tbody>
          </table>
        </div>
      </Card>
      {pay && <PayDialog row={pay} onClose={() => setPay(null)} onDone={(m) => { setPay(null); onToast(m); load(); onChanged(); }} />}
      {receipt && <ReceiptView r={receipt} onClose={() => setReceipt(null)} />}
    </div>
  );
}

function PayDialog({ row, onClose, onDone }: { row: ScheduleRow; onClose: () => void; onDone: (m: string) => void }) {
  const rest = row.total_due - row.paid;
  const [amount, setAmount] = useState(rest);
  const [method, setMethod] = useState<PayMethod>('transfer');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function go() {
    setBusy(true); setErr(null);
    try {
      const r = await recordRentPayment(row.schedule_id, amount, method);
      onDone(`${row.lessee} : ${fcfa(amount)} encaissés${r.provider_ref ? ` · réf. ${r.provider_ref}` : ''}${Number(r.balance) > 0 ? ` · reste ${fcfa(Number(r.balance))}` : ' · échéance soldée'}`);
    } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }
  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Encaissement">
        <div className="ka-drawer__head">
          <div><div className="ks-eyebrow">Encaissement · {mon(row.period)}</div><h2 style={{ fontSize: 20, fontWeight: 800, margin: '4px 0 0' }}>{row.lessee}</h2></div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>
        <div className="kv-line"><span>Total de l’échéance</span><b className="ks-mono">{fcfa(row.total_due)}</b></div>
        <div className="kv-line"><span>Déjà encaissé</span><b className="ks-mono">{fcfa(row.paid)}</b></div>
        <div className="kv-line kv-line--total"><span>Reste dû</span><b className="ks-mono">{fcfa(rest)}</b></div>
        <label className="kx-lbl" style={{ marginTop: 12 }}>Montant encaissé (FCFA)
          <input className="kx-in" type="number" inputMode="numeric" min={1} max={rest} value={amount} onChange={(e) => setAmount(Number(e.target.value))} />
        </label>
        <div className="kx-chips" style={{ marginTop: 10 }} role="radiogroup" aria-label="Mode de paiement">
          {(Object.keys(METHOD) as PayMethod[]).map((m) => <button key={m} role="radio" aria-checked={method === m} className={`kx-chip${method === m ? ' kx-chip--on' : ''}`} onClick={() => setMethod(m)}>{METHOD[m]}</button>)}
        </div>
        {method === 'mobile_money' && <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 6 }}>Paiement Mobile Money simulé (CinetPay) : une référence de transaction est générée.</div>}
        {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12.5, marginTop: 10 }}>{err}</div>}
        <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || amount <= 0 || amount > rest} onClick={go}><Banknote size={15} /> {busy ? '…' : 'Enregistrer l’encaissement'}</button>
      </aside>
    </div>
  );
}

export function ReceiptView({ r, onClose }: { r: RentReceipt; onClose: () => void }) {
  return (
    <div className="ka-overlay kl-print-root" onClick={onClose}>
      <div className="kl-receipt" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={`Quittance ${r.number}`}>
        <div className="kl-receipt__actions kl-noprint">
          <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={() => window.print()}><Printer size={13} /> Imprimer / PDF</button>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={16} /></button>
        </div>
        <div className="kl-receipt__head">
          <div><div className="ks-brand" style={{ fontSize: 24 }}>{r.site}</div><div className="ks-eyebrow">Gestion locative</div></div>
          <div style={{ textAlign: 'right' }}><div style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-.02em' }}>Quittance de loyer</div><div className="ks-mono ks-faint" style={{ fontSize: 12 }}>{r.number}</div></div>
        </div>
        <p style={{ fontSize: 13.5, lineHeight: 1.7, margin: '18px 0' }}>
          Le bailleur reconnaît avoir reçu de <b>{r.lessee}</b>{r.trade_name && r.trade_name !== r.lessee ? ` (enseigne ${r.trade_name})` : ''}{r.rccm ? `, RCCM ${r.rccm}` : ''},
          au titre du bail <b className="ks-mono">{r.lease_ref}</b> portant sur {r.spaces}, la somme de <b>{fcfa(r.total)}</b> pour la période
          du {dd(r.period_start)} au {dd(r.period_end)}, et lui en donne quittance, sous réserve de tous droits.
        </p>
        <div className="kv-line"><span>Loyer HT</span><b className="ks-mono">{fcfa(r.rent)}</b></div>
        <div className="kv-line"><span>Provision sur charges</span><b className="ks-mono">{fcfa(r.charges)}</b></div>
        <div className="kv-line"><span>TVA {r.vat_rate} %</span><b className="ks-mono">{fcfa(r.vat)}</b></div>
        <div className="kv-line kv-line--total"><span>Total TTC réglé</span><b className="ks-mono">{fcfa(r.total)}</b></div>
        {r.payments && (
          <div className="ks-faint" style={{ fontSize: 12, marginTop: 12 }}>
            Règlement(s) : {r.payments.map((p) => `${fcfa(Number(p.amount))} le ${dd(p.at)} (${METHOD[p.method as PayMethod] ?? p.method}${p.ref ? ` · ${p.ref}` : ''})`).join(' ; ')}
          </div>
        )}
        <div className="ks-faint" style={{ fontSize: 11, marginTop: 22, borderTop: '1px solid var(--ks-line)', paddingTop: 10 }}>
          Émise le {dd(r.issued_at)}. Cette quittance annule tous reçus partiels relatifs à la même période. Document généré par Atlas Keystone.
        </div>
      </div>
    </div>
  );
}

function ArrearsPanel({ onToast, onError, onChanged }: { onToast: (m: string) => void; onError: (m: string) => void; onChanged: () => void }) {
  const [rows, setRows] = useState<ArrearsRow[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  function load() { fetchArrears().then(setRows).catch((e) => onError(String(e))); }
  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps
  const byBucket = BUCKETS.map((b) => ({ ...b, amount: (rows ?? []).filter((r) => r.bucket === b.id).reduce((s, r) => s + r.balance, 0) }));
  const total = byBucket.reduce((s, b) => s + b.amount, 0);
  async function remind(r: ArrearsRow) {
    setBusy(r.schedule_id);
    try { const x = await sendRentReminder(r.schedule_id); onToast(`Relance n°${x.reminders_sent} envoyée à ${r.lessee}`); load(); onChanged(); }
    catch (e) { onError(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }
  return (
    <div className="ks-reveal">
      <Card>
        <div className="kt-cardtitle">Balance âgée des impayés</div>
        <div className="kt-cardsub">{fcfa(total)} au total, par ancienneté de l’échéance</div>
        <div className="kl-aging">
          {byBucket.map((b) => (
            <div key={b.id} className="kl-aging__col">
              <div className="ks-mono" style={{ fontWeight: 700, fontSize: 14 }}>{fcfa(b.amount)}</div>
              <div className="kl-aging__bar"><span style={{ width: `${total ? (b.amount / total) * 100 : 0}%`, background: b.color }} /></div>
              <div className="ks-faint" style={{ fontSize: 12 }}>{b.label}</div>
            </div>
          ))}
        </div>
      </Card>
      <Card pad={false} style={{ marginTop: 14 }}>
        <div style={{ overflowX: 'auto' }}>
          <table className="ks-table">
            <thead><tr><th>Locataire</th><th>Période</th><th>Reste dû</th><th>Retard</th><th>Relances</th><th></th></tr></thead>
            <tbody>
              {(rows ?? []).map((r) => (
                <tr key={r.schedule_id}>
                  <td><div style={{ fontWeight: 600 }}>{r.lessee}</div><div className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>{r.lease_ref} · {r.contact_phone ?? ''}</div></td>
                  <td style={{ fontSize: 12.5 }}>{mon(r.period)}</td>
                  <td className="ks-mono" style={{ fontWeight: 700, color: 'var(--ks-critical)' }}>{fcfa(r.balance)}{r.paid > 0 && <div className="ks-faint" style={{ fontSize: 11, fontWeight: 400 }}>payé {fcfa(r.paid)}</div>}</td>
                  <td><span className={`ks-risk ks-risk--${r.days_late > 60 ? 'critical' : r.days_late > 30 ? 'high' : 'medium'}`}>{r.days_late} j</span></td>
                  <td style={{ fontSize: 12 }}>{r.reminders_sent}{r.last_reminder_at && <div className="ks-faint" style={{ fontSize: 11 }}>dernière {dd(r.last_reminder_at)}</div>}</td>
                  <td style={{ textAlign: 'right' }}><button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === r.schedule_id} onClick={() => remind(r)}><Send size={13} /> Relancer</button></td>
                </tr>
              ))}
              {rows && rows.length === 0 && <tr><td colSpan={6} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucun impayé. 🎉</td></tr>}
            </tbody>
          </table>
        </div>
        <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12 }} className="ks-faint">
          Une relance par échéance toutes les 72 h au maximum (contrôle en base). L’envoi WhatsApp / SMS sera branché avec le module notifications.
        </div>
      </Card>
    </div>
  );
}

function ChargesPanel() {
  const year = new Date().getFullYear() - 1;
  const [rows, setRows] = useState<ChargeRegRow[] | null>(null);
  const [pools, setPools] = useState<{ site: string; category: string; amount: number }[]>([]);
  useEffect(() => { fetchChargesRegularization(year).then(setRows).catch(() => {}); fetchChargePools(year).then(setPools).catch(() => {}); }, [year]);
  const poolTotal = pools.reduce((s, p) => s + p.amount, 0);
  const toCall = (rows ?? []).filter((r) => r.balance > 0).reduce((s, r) => s + r.balance, 0);
  const toRefund = (rows ?? []).filter((r) => r.balance < 0).reduce((s, r) => s - r.balance, 0);
  return (
    <div className="kt-dash kt-dash--12 ks-reveal">
      <Card>
        <div className="kt-cardtitle">Charges réelles {year}</div>
        <div className="kt-cardsub">dépenses récupérables de l’exercice</div>
        <div style={{ marginTop: 10 }}>
          {pools.map((p) => <div key={p.category} className="kv-line"><span>{p.category}</span><b className="ks-mono">{fcfa(p.amount)}</b></div>)}
          <div className="kv-line kv-line--total"><span>Total</span><b className="ks-mono">{fcfa(poolTotal)}</b></div>
        </div>
        <div className="kl-chips" style={{ marginTop: 14 }}>
          <span className="kl-chip kl-chip--warn">À appeler : {fcfa(toCall)}</span>
          <span className="kl-chip">À rembourser : {fcfa(toRefund)}</span>
        </div>
        <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 10, lineHeight: 1.5 }}>Quote-part = surface louée × coefficient de pondération du bail (ex. 0,5 pour une grande surface), au prorata de l’ensemble des baux de l’exercice.</div>
      </Card>
      <Card pad={false}>
        <div style={{ overflowX: 'auto' }}>
          <table className="ks-table">
            <thead><tr><th>Locataire</th><th>m² pondérés</th><th>Quote-part</th><th>Charges réelles</th><th>Provisions appelées</th><th>Solde</th></tr></thead>
            <tbody>
              {(rows ?? []).map((r) => (
                <tr key={r.lease_id}>
                  <td><div style={{ fontWeight: 600 }}>{r.lessee}</div><div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{r.lease_ref}</div></td>
                  <td className="ks-mono" style={{ fontSize: 12.5 }}>{nf(r.weighted_m2, 1)}</td>
                  <td className="ks-mono" style={{ fontSize: 12.5 }}>{nf(r.share_pct, 2)} %</td>
                  <td className="ks-mono" style={{ fontSize: 12.5 }}>{fcfa(r.real_charges)}</td>
                  <td className="ks-mono" style={{ fontSize: 12.5 }}>{fcfa(r.provisions_billed)}</td>
                  <td className="ks-mono" style={{ fontWeight: 700, color: r.balance > 0 ? 'var(--ks-high)' : 'var(--ks-low)' }}>
                    {r.balance > 0 ? '+' : ''}{fcfa(r.balance)}<div className="ks-faint" style={{ fontSize: 10.5, fontWeight: 400 }}>{r.balance > 0 ? 'complément à appeler' : 'trop-perçu à rembourser'}</div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}

function NewsPanel({ onToast, onError }: { onToast: (m: string) => void; onError: (m: string) => void }) {
  const [news, setNews] = useState<NewsItem[] | null>(null);
  const [sites, setSites] = useState<{ id: string; name: string }[]>([]);
  const [site, setSite] = useState('');
  const [kind, setKind] = useState<NewsItem['kind']>('info');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [date, setDate] = useState('');
  const [busy, setBusy] = useState(false);
  function load() { fetchNews().then(setNews).catch((e) => onError(String(e))); }
  useEffect(() => { load(); fetchSites().then((s) => { setSites(s); setSite(s[0]?.id ?? ''); }).catch(() => {}); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  async function publish() {
    setBusy(true);
    try { await publishNews(site, kind, title.trim(), body.trim(), date || undefined); onToast('Actualité publiée sur le portail locataire'); setTitle(''); setBody(''); setDate(''); load(); }
    catch (e) { onError(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }
  return (
    <div className="kt-dash kt-dash--12 ks-reveal">
      <Card>
        <div className="kt-cardtitle">Publier une actualité</div>
        <div className="kt-cardsub">visible immédiatement par les locataires du site</div>
        <select className="ka-select" style={{ width: '100%', height: 38, marginTop: 12 }} value={site} onChange={(e) => setSite(e.target.value)} aria-label="Site">
          {sites.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <div className="kx-chips" style={{ margin: '10px 0' }}>
          {(Object.keys(NEWS_KIND) as NewsItem['kind'][]).map((k) => <button key={k} className={`kx-chip${kind === k ? ' kx-chip--on' : ''}`} onClick={() => setKind(k)}>{NEWS_KIND[k]}</button>)}
        </div>
        <input className="kx-in" style={{ width: '100%' }} placeholder="Titre" value={title} onChange={(e) => setTitle(e.target.value)} />
        <textarea className="kt-field ki-input" rows={4} style={{ width: '100%', marginTop: 8 }} placeholder="Message aux locataires" value={body} onChange={(e) => setBody(e.target.value)} />
        <label className="kx-lbl" style={{ marginTop: 8 }}>Date de l’événement (facultatif)<input className="kx-in" type="date" value={date} onChange={(e) => setDate(e.target.value)} /></label>
        <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || !site || title.trim().length < 3} onClick={publish}><Megaphone size={15} /> Publier</button>
      </Card>
      <Card pad={false}>
        {(news ?? []).map((n) => (
          <div key={n.id} className="kl-news">
            <span className={`kl-news__kind kl-news__kind--${n.kind}`}>{NEWS_KIND[n.kind]}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 700 }}>{n.title}</div>
              {n.body && <div className="ks-dim" style={{ fontSize: 13, marginTop: 2, lineHeight: 1.5 }}>{n.body}</div>}
              <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 4 }}>{n.site} · publié le {dd(n.published_at)}{n.event_date ? ` · le ${dd(n.event_date)}` : ''}</div>
            </div>
          </div>
        ))}
      </Card>
    </div>
  );
}
