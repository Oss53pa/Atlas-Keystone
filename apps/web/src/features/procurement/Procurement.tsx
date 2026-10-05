import { useEffect, useState } from 'react';
import {
  ShoppingCart, Package, AlertTriangle, Truck, RefreshCw, CheckCircle2, Bot, ClipboardList, Check, X, PackageCheck, Sparkles, ShieldAlert, Receipt, PackageOpen,
} from 'lucide-react';
import { Card, StatBig, TabBar } from '@keystone/ui';
import { PurchaseOrderDoc } from '../documents/Documents.tsx';
import { Invoices, ReceiveDrawer } from './Invoices.tsx';
import { money, format } from '@keystone/domain';
import type { StockRow, StockLevel, PurchaseRequestRow, PrStatus, PurchaseOrderRow, PoStatus, ProcurementSummary, BudgetCheck } from '@keystone/domain/db/keystone';
import {
  fetchStock, fetchPurchaseRequests, fetchPurchaseOrders, fetchProcurementSummary, prTransition, prToPo, poReceive, prFromStockAlerts, type PrAction,
} from '../../data/procurement.ts';

const fcfa = (n: number) => format(money(n, 'XOF'));
const LEVEL: Record<StockLevel, { label: string; risk: 'critical' | 'high' | 'medium' | 'low' }> = {
  critical: { label: 'Rupture imminente', risk: 'critical' },
  low: { label: 'Sous le minimum', risk: 'high' },
  warning: { label: 'À commander', risk: 'medium' },
  ok: { label: 'OK', risk: 'low' },
};
const PR: Record<PrStatus, { label: string; color: string; bg: string }> = {
  draft: { label: 'Brouillon', color: 'var(--ks-ink-2)', bg: 'var(--ks-surface-3)' },
  submitted: { label: 'À valider (technique)', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  tech_approved: { label: 'À valider (budget)', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  budget_approved: { label: 'À valider (direction)', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  approved: { label: 'Approuvée', color: '#2C6230', bg: 'var(--ks-low-100)' },
  rejected: { label: 'Rejetée', color: '#8E1E22', bg: 'var(--ks-critical-100)' },
  ordered: { label: 'Commandée', color: '#0F6E56', bg: '#E1F5EE' },
};
const PO: Record<PoStatus, string> = { sent: 'Envoyée', confirmed: 'Confirmée', partially_received: 'Réception partielle', received: 'Réceptionnée', cancelled: 'Annulée' };
const BUDGET: Record<BudgetCheck, { label: string; color: string }> = {
  OK: { label: 'Budget OK', color: 'var(--ks-low)' },
  LIMIT: { label: 'Budget limite (> 80 %)', color: 'var(--ks-amber-700)' },
  OVER: { label: 'Dépassement budgétaire', color: 'var(--ks-critical)' },
  NO_LINE: { label: 'Sans ligne budgétaire', color: 'var(--ks-ink-3)' },
};
const NEXT: Partial<Record<PrStatus, { action: PrAction; label: string }>> = {
  draft: { action: 'submit', label: 'Soumettre' },
  submitted: { action: 'approve_tech', label: 'Valider (technique)' },
  tech_approved: { action: 'approve_budget', label: 'Valider (budget)' },
  budget_approved: { action: 'approve_direction', label: 'Valider (direction)' },
};

/** Étapes du circuit selon le palier : 1 technique · 2 + budget · 3 + direction. */
function steps(level: number, status: PrStatus) {
  const chain = ['Demande', 'Technique', 'Budget', 'Direction'].slice(0, level + 1).concat('Commande');
  const reached: Record<PrStatus, number> = { draft: 0, submitted: 1, tech_approved: 2, budget_approved: 3, approved: level + 1, ordered: level + 2, rejected: -1 };
  return { chain, at: reached[status] };
}

export function Procurement() {
  const [tab, setTab] = useState('stock');
  const [stock, setStock] = useState<StockRow[] | null>(null);
  const [prs, setPrs] = useState<PurchaseRequestRow[] | null>(null);
  const [pos, setPos] = useState<PurchaseOrderRow[] | null>(null);
  const [sum, setSum] = useState<ProcurementSummary | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [poDoc, setPoDoc] = useState<string | null>(null);
  const [receiving, setReceiving] = useState<PurchaseOrderRow | null>(null);
  const notify = (m: string) => { setToast(m); setTimeout(() => setToast(null), 4500); };

  function load() {
    fetchStock().then(setStock).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchPurchaseRequests().then(setPrs).catch(() => {});
    fetchPurchaseOrders().then(setPos).catch(() => {});
    fetchProcurementSummary().then(setSum).catch(() => {});
  }
  useEffect(load, []);

  async function run(id: string, fn: () => Promise<string>) {
    setBusy(id); setErr(null);
    try {
      const msg = await fn();
      setToast(msg); setTimeout(() => setToast(null), 4500); load();
    } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }

  const alerts = (stock ?? []).filter((s) => s.level !== 'ok');

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Pilotage · Approvisionnement</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Achats &amp; stocks</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">couverture réelle · circuit DA à paliers · contrôle budgétaire · rapprochement BC / réception / facture</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
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
          <Card><StatBig label="Valeur du stock" icon={<Package size={15} />} value={fcfa(sum.stock_value)} sub={`${sum.parts} articles`} /></Card>
          <Card><StatBig label="Alertes de stock" icon={<AlertTriangle size={15} />} accent={sum.critical_alerts ? 'var(--ks-critical)' : sum.alerts ? 'var(--ks-amber)' : 'var(--ks-low)'} value={sum.alerts} sub={`${sum.critical_alerts} critique(s)`} /></Card>
          <Card><StatBig label="DA en validation" icon={<ClipboardList size={15} />} value={sum.pr_pending} sub={fcfa(sum.pr_pending_amount)} /></Card>
          <Card><StatBig label="Commandes ouvertes" icon={<Truck size={15} />} accent={sum.po_late ? 'var(--ks-high)' : undefined} value={sum.po_open} sub={sum.po_late ? `${sum.po_late} en retard` : 'aucun retard'} /></Card>
        </div>
      )}

      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <TabBar
          tabs={[
            { id: 'stock', label: 'Stocks', icon: <Package size={15} /> },
            { id: 'pr', label: `Demandes d’achat${prs ? ` · ${prs.length}` : ''}`, icon: <ClipboardList size={15} /> },
            { id: 'po', label: `Commandes${pos ? ` · ${pos.length}` : ''}`, icon: <Truck size={15} /> },
            { id: 'invoices', label: 'Factures · rapprochement', icon: <Receipt size={15} /> },
          ]}
          active={tab}
          onChange={setTab}
        />
        {tab === 'stock' && alerts.length > 0 && (
          <button className="ks-btn ks-btn--primary" disabled={busy === 'auto'}
            onClick={() => run('auto', async () => { const r = await prFromStockAlerts(); setTab('pr'); return r.created ? `${r.created} DA proposée(s) par l’agent Réappro — à soumettre` : 'Toutes les alertes sont déjà couvertes par une DA.'; })}>
            <Bot size={15} /> {busy === 'auto' ? '…' : 'Proposer les réappros'}
          </button>
        )}
      </div>

      {tab === 'stock' && stock && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Article</th><th>Niveau</th><th>Stock</th><th>Couverture</th><th>Fournisseur</th><th>En commande</th><th>Valeur</th></tr></thead>
              <tbody>
                {stock.map((s) => {
                  const l = LEVEL[s.level];
                  const coverShort = s.days_cover != null && s.days_cover < s.lead_time_days;
                  const pct = Math.min(100, (s.qty / Math.max(1, s.max_qty)) * 100);
                  return (
                    <tr key={s.id}>
                      <td>
                        <div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{s.ref}{s.is_critical && <span style={{ color: 'var(--ks-critical)', marginLeft: 6 }}>● critique</span>}</div>
                        <div style={{ fontWeight: 600 }}>{s.name}</div>
                      </td>
                      <td><span className={`ks-risk ks-risk--${l.risk}`}>{l.label}</span></td>
                      <td style={{ minWidth: 150 }}>
                        <div className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{s.qty} <span className="ks-faint" style={{ fontWeight: 400 }}>/ min {s.min_qty} · max {s.max_qty}</span></div>
                        <div className="kp-gauge">
                          <div className="kp-gauge__fill" style={{ width: `${pct}%`, background: s.level === 'ok' ? 'var(--ks-low)' : s.level === 'warning' ? 'var(--ks-amber)' : 'var(--ks-critical)' }} />
                          <div className="kp-gauge__mark" style={{ left: `${Math.min(100, (s.min_qty / Math.max(1, s.max_qty)) * 100)}%` }} title="minimum" />
                        </div>
                      </td>
                      <td>
                        {s.days_cover == null ? <span className="ks-faint" style={{ fontSize: 12 }}>pas de conso</span> : (
                          <span className="ks-mono" style={{ fontWeight: 600, color: coverShort ? 'var(--ks-critical)' : 'var(--ks-ink)' }}>{s.days_cover} j</span>
                        )}
                        <div className="ks-faint" style={{ fontSize: 11 }}>délai {s.lead_time_days} j</div>
                      </td>
                      <td style={{ fontSize: 12.5 }}>{s.supplier ?? '—'}</td>
                      <td className="ks-mono" style={{ fontSize: 12.5 }}>{s.on_order > 0 ? `+${s.on_order}` : '—'}</td>
                      <td className="ks-mono" style={{ fontSize: 12.5 }}>{fcfa(s.stock_value)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12 }} className="ks-faint">
            Couverture = stock ÷ consommation journalière moyenne sur 90 jours. En rouge quand elle est inférieure au délai fournisseur : la rupture arrivera avant la livraison.
          </div>
        </Card>
      )}

      {tab === 'pr' && prs && (
        <div className="kp-prs ks-reveal">
          {prs.length === 0 && <Card><div className="ks-dim" style={{ textAlign: 'center', padding: 24 }}>Aucune demande d’achat.</div></Card>}
          {prs.map((r) => {
            const st = PR[r.status];
            const { chain, at } = steps(r.level, r.status);
            const next = NEXT[r.status];
            const b = BUDGET[r.budget_status];
            return (
              <Card key={r.id}>
                <div className="kp-pr__head">
                  <div style={{ minWidth: 0 }}>
                    <div className="ks-mono ks-faint" style={{ fontSize: 11.5, display: 'flex', gap: 8, alignItems: 'center' }}>
                      {r.ref}
                      {r.requested_by_agent && <span className="ks-pill" style={{ color: 'var(--ks-info)' }}><Bot size={11} /> agent Réappro</span>}
                      {r.urgency !== 'normal' && <span className={`ks-risk ks-risk--${r.urgency === 'critical' ? 'critical' : 'high'}`}>{r.urgency === 'critical' ? 'Critique' : 'Urgent'}</span>}
                    </div>
                    <div style={{ fontWeight: 700, fontSize: 15, marginTop: 3 }}>{r.title}</div>
                    <div className="ks-faint" style={{ fontSize: 12.5 }}>{r.supplier ?? 'Fournisseur à définir'} · {r.lines} ligne(s) · palier {r.level}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div className="ks-mono" style={{ fontSize: 18, fontWeight: 700 }}>{fcfa(r.total)}</div>
                    <span className="ks-wo-pill" style={{ color: st.color, background: st.bg, marginTop: 6 }}>{st.label}</span>
                  </div>
                </div>

                <div className="kp-steps">
                  {chain.map((c, i) => (
                    <div key={c} className={`kp-step${r.status === 'rejected' ? ' kp-step--rej' : i < at ? ' kp-step--done' : i === at ? ' kp-step--now' : ''}`}>
                      <span className="kp-step__dot">{i < at && r.status !== 'rejected' ? <Check size={11} strokeWidth={3} /> : i + 1}</span>
                      <span className="kp-step__lbl">{c}</span>
                    </div>
                  ))}
                </div>

                <div className="kp-pr__foot">
                  <span style={{ fontSize: 12.5, color: b.color, fontWeight: 600 }}>
                    {b.label}{r.budget_available != null && <span className="ks-faint" style={{ fontWeight: 400 }}> · disponible {fcfa(r.budget_available)}</span>}
                  </span>
                  {r.rejected_reason && <span className="ks-faint" style={{ fontSize: 12.5 }}>Motif : {r.rejected_reason}</span>}
                  <div style={{ display: 'flex', gap: 8, marginLeft: 'auto' }}>
                    {next && r.status !== 'draft' && (
                      <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy === r.id}
                        onClick={() => run(r.id, async () => { await prTransition(r.id, 'reject', 'Rejetée par le valideur'); return `${r.ref} rejetée`; })}>
                        <X size={13} /> Rejeter
                      </button>
                    )}
                    {next && (
                      <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === r.id}
                        onClick={() => run(r.id, async () => { const x = await prTransition(r.id, next.action); return `${r.ref} → ${PR[x.status as PrStatus]?.label ?? x.status}`; })}>
                        <Check size={13} /> {busy === r.id ? '…' : next.label}
                      </button>
                    )}
                    {r.status === 'approved' && (
                      <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy === r.id}
                        onClick={() => run(r.id, async () => { const x = await prToPo(r.id); setTab('po'); return `Bon de commande ${x.ref} émis`; })}>
                        <ShoppingCart size={13} /> {busy === r.id ? '…' : 'Émettre le BC'}
                      </button>
                    )}
                    {r.po_ref && <span className="ks-pill"><Truck size={12} /> {r.po_ref}</span>}
                  </div>
                </div>
              </Card>
            );
          })}
          <div className="ks-faint" style={{ fontSize: 12, lineHeight: 1.6 }}>
            <Sparkles size={12} style={{ verticalAlign: -1 }} /> Paliers : &lt; 500 000 FCFA → validation technique · &lt; 5 M → + budget · ≥ 5 M → + direction.
            La validation budget est bloquée en base en cas de dépassement (<span className="ks-mono">INSUFFICIENT_BUDGET</span>), et un demandeur ne peut jamais valider sa propre DA.
          </div>
        </div>
      )}

      {tab === 'po' && pos && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>BC</th><th>Fournisseur</th><th>HT</th><th>TTC (18 %)</th><th>Livraison prévue</th><th>Statut</th><th></th></tr></thead>
              <tbody>
                {pos.map((o) => (
                  <tr key={o.id}>
                    <td><div className="ks-mono" style={{ fontWeight: 600, fontSize: 12.5 }}>{o.ref}</div><div className="ks-mono ks-faint" style={{ fontSize: 11 }}>{o.pr_ref}</div></td>
                    <td style={{ fontWeight: 600 }}>{o.supplier ?? '—'}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{fcfa(o.amount_ht)}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{fcfa(o.amount_ttc)}</td>
                    <td>
                      <span className="ks-mono" style={{ fontSize: 12, color: o.late ? 'var(--ks-critical)' : undefined }}>{o.expected_at ? new Date(o.expected_at).toLocaleDateString('fr-FR') : '—'}</span>
                      {o.late && <div style={{ fontSize: 11, color: 'var(--ks-critical)' }}>en retard</div>}
                    </td>
                    <td>
                      <span className="ks-pill" style={{ color: o.status === 'received' ? 'var(--ks-low)' : undefined }}>{PO[o.status]}</span>
                      {o.qc_result && <div className="ks-faint" style={{ fontSize: 11, marginTop: 4 }}>QC : {o.qc_result === 'accepted' ? 'conforme' : o.qc_result === 'refused' ? 'refusé' : 'avec réserves'}</div>}
                    </td>
                    <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                      <button className="ks-btn ks-btn--quiet ks-btn--sm" style={{ marginRight: 6 }} onClick={() => setPoDoc(o.id)}>BC PDF</button>
                      {o.status !== 'received' && o.status !== 'cancelled' && (
                        <>
                          <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy === o.id}
                            onClick={() => run(o.id, async () => { await poReceive(o.id, 'refused'); return `${o.ref} : livraison refusée au contrôle qualité`; })}>Refuser</button>
                          <button className="ks-btn ks-btn--quiet ks-btn--sm" style={{ marginLeft: 6 }} onClick={() => setReceiving(o)}><PackageOpen size={13} /> Partielle</button>
                          <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy === o.id} style={{ marginLeft: 6 }}
                            onClick={() => run(o.id, async () => { const r = await poReceive(o.id, 'accepted'); return `${o.ref} réceptionnée · +${r.stock_in} en stock`; })}>
                            <PackageCheck size={13} /> {busy === o.id ? '…' : 'Réceptionner'}
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                ))}
                {pos.length === 0 && <tr><td colSpan={7} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucune commande. Approuvez une DA puis émettez son bon de commande.</td></tr>}
              </tbody>
            </table>
          </div>
        </Card>
      )}
      {tab === 'invoices' && <Invoices orders={pos ?? []} onToast={notify} onError={setErr} onChanged={load} />}
      {receiving && <ReceiveDrawer order={receiving} onClose={() => setReceiving(null)} onDone={(m) => { notify(m); load(); }} onError={setErr} />}
      {poDoc && <PurchaseOrderDoc poId={poDoc} onClose={() => setPoDoc(null)} />}
    </div>
  );
}
