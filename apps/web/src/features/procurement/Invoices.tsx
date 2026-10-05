import { useEffect, useMemo, useState } from 'react';
import {
  FileCheck2, FileWarning, Receipt, Banknote, X, Check, ShieldAlert, RefreshCw, Plus, Ban, CircleDollarSign, PackageCheck, Scale, Info,
} from 'lucide-react';
import { Card, StatBig } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type {
  SupplierInvoiceRow, SupplierInvoiceStatus, SupplierInvoiceDetail, MatchCode, PoLineStatus, ApSummary, PurchaseOrderRow,
} from '@keystone/domain/db/keystone';
import {
  fetchSupplierInvoices, fetchSupplierInvoice, fetchApSummary, fetchPoLines, invoiceRegister, invoiceTransition, poReceiveLines,
} from '../../data/procurement.ts';

const fcfa = (n: number) => format(money(Math.round(n), 'XOF'));
const nf = (n: number | null | undefined, d = 0) => (n == null ? '—' : n.toLocaleString('fr-FR', { maximumFractionDigits: d }));
const date = (s: string | null) => (s ? new Date(s).toLocaleDateString('fr-FR') : '—');

const STATUS: Record<SupplierInvoiceStatus, { label: string; color: string; bg: string }> = {
  to_match: { label: 'À rapprocher', color: 'var(--ks-ink-2)', bg: 'var(--ks-surface-3)' },
  matched: { label: 'Rapprochée · à valider', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  discrepancy: { label: 'Écart bloquant', color: '#8E1E22', bg: 'var(--ks-critical-100)' },
  approved: { label: 'Bon à payer', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  rejected: { label: 'Rejetée', color: 'var(--ks-ink-3)', bg: 'var(--ks-surface-3)' },
  paid: { label: 'Payée', color: '#2C6230', bg: 'var(--ks-low-100)' },
};
const CODE: Record<string, { label: string; tone: 'ok' | 'warn' | 'bad' }> = {
  OK: { label: 'Conforme', tone: 'ok' },
  PRICE_UNDER: { label: 'Prix inférieur au BC', tone: 'warn' },
  PRICE_OVER: { label: 'Prix supérieur au BC', tone: 'bad' },
  QTY_OVER_RECEIVED: { label: 'Facturé > reçu', tone: 'bad' },
  NOT_RECEIVED: { label: 'Rien de réceptionné', tone: 'bad' },
  UNORDERED: { label: 'Ligne non commandée', tone: 'bad' },
  POSSIBLE_DUPLICATE: { label: 'Doublon probable', tone: 'bad' },
  AMOUNT_VARIANCE: { label: 'Écart global', tone: 'bad' },
  HEADER_MISMATCH: { label: 'Total ≠ lignes', tone: 'bad' },
  SUPPLIER_MISMATCH: { label: 'Fournisseur ≠ BC', tone: 'bad' },
  PO_CANCELLED: { label: 'BC annulé', tone: 'bad' },
  NO_LINES: { label: 'Sans ligne', tone: 'bad' },
};
const FILTERS: { id: string; label: string; test: (r: SupplierInvoiceRow) => boolean }[] = [
  { id: 'open', label: 'À traiter', test: (r) => ['to_match', 'matched', 'discrepancy'].includes(r.status) },
  { id: 'discrepancy', label: 'Écarts', test: (r) => r.status === 'discrepancy' },
  { id: 'approved', label: 'Bons à payer', test: (r) => r.status === 'approved' },
  { id: 'closed', label: 'Payées & rejetées', test: (r) => r.status === 'paid' || r.status === 'rejected' },
  { id: 'all', label: 'Toutes', test: () => true },
];

export function Invoices({ orders, onToast, onError, onChanged }: {
  orders: PurchaseOrderRow[]; onToast: (m: string) => void; onError: (m: string) => void; onChanged: () => void;
}) {
  const [rows, setRows] = useState<SupplierInvoiceRow[] | null>(null);
  const [sum, setSum] = useState<ApSummary | null>(null);
  const [filter, setFilter] = useState('open');
  const [open, setOpen] = useState<string | null>(null);
  const [registering, setRegistering] = useState(false);

  function load() {
    fetchSupplierInvoices().then(setRows).catch((e) => onError(e instanceof Error ? e.message : String(e)));
    fetchApSummary().then(setSum).catch(() => {});
  }
  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps
  const refresh = () => { load(); onChanged(); };

  const f = FILTERS.find((x) => x.id === filter)!;
  const list = (rows ?? []).filter(f.test);

  return (
    <div className="ks-reveal">
      {sum && (
        <div className="kt-dash kt-dash--4" style={{ marginBottom: 16 }}>
          <Card><StatBig label="Écarts bloquants" icon={<FileWarning size={15} />} accent={sum.discrepancies ? 'var(--ks-critical)' : 'var(--ks-low)'}
            value={sum.discrepancies} sub={sum.discrepancies ? `${fcfa(sum.discrepancy_amount)} HT en litige` : 'aucun litige'} /></Card>
          <Card><StatBig label="À valider" icon={<FileCheck2 size={15} />} value={sum.to_review} sub={`${sum.po_to_invoice} BC reçus non facturés`} /></Card>
          <Card><StatBig label="Bons à payer" icon={<Banknote size={15} />} accent={sum.overdue ? 'var(--ks-high)' : undefined}
            value={fcfa(sum.to_pay)} sub={sum.overdue ? `dont ${fcfa(sum.overdue)} échus` : 'aucune échéance dépassée'} /></Card>
          <Card><StatBig label="Rapprochement automatique" icon={<Scale size={15} />} accent="var(--ks-low)"
            value={sum.auto_match_rate == null ? '—' : `${sum.auto_match_rate} %`} sub={`${fcfa(sum.paid_month)} payés ce mois`} /></Card>
        </div>
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 12 }}>
        <div className="kx-chips">
          {FILTERS.map((x) => (
            <button key={x.id} className={`kx-chip${filter === x.id ? ' kx-chip--on' : ''}`} onClick={() => setFilter(x.id)}>
              {x.label}{rows ? ` · ${rows.filter(x.test).length}` : ''}
            </button>
          ))}
        </div>
        <button className="ks-btn ks-btn--primary" onClick={() => setRegistering(true)}><Plus size={15} /> Saisir une facture</button>
      </div>

      <Card pad={false}>
        <div style={{ overflowX: 'auto' }}>
          <table className="ks-table">
            <thead><tr><th>Facture</th><th>Fournisseur · BC</th><th>HT facturé</th><th>Attendu (reçu × prix BC)</th><th>Écart</th><th>Échéance</th><th>Statut</th></tr></thead>
            <tbody>
              {list.map((r) => {
                const st = STATUS[r.status];
                const v = r.variance_ht ?? 0;
                return (
                  <tr key={r.id} className="kq-row" onClick={() => setOpen(r.id)}>
                    <td>
                      <div className="ks-mono" style={{ fontWeight: 600, fontSize: 12.5 }}>{r.supplier_ref}</div>
                      <div className="ks-mono ks-faint" style={{ fontSize: 11 }}>{r.ref} · {date(r.invoice_date)}</div>
                    </td>
                    <td><div style={{ fontWeight: 600 }}>{r.supplier ?? '—'}</div><div className="ks-mono ks-faint" style={{ fontSize: 11 }}>{r.po_ref}</div></td>
                    <td className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{fcfa(r.amount_ht)}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{r.expected_ht == null ? '—' : fcfa(r.expected_ht)}</td>
                    <td>
                      <span className="ks-mono" style={{ fontSize: 12.5, fontWeight: 700, color: Math.abs(v) < 1 ? 'var(--ks-low)' : v > 0 ? 'var(--ks-critical)' : 'var(--ks-amber-700)' }}>
                        {Math.abs(v) < 1 ? '0' : `${v > 0 ? '+' : ''}${fcfa(v)}`}
                      </span>
                      {r.issues.length > 0 && (
                        <div className="kq-codes">{r.issues.map((c) => <span key={c} className={`kq-code kq-code--${CODE[c]?.tone ?? 'bad'}`}>{CODE[c]?.label ?? c}</span>)}</div>
                      )}
                    </td>
                    <td>
                      <span className="ks-mono" style={{ fontSize: 12, color: r.overdue ? 'var(--ks-critical)' : undefined }}>{date(r.due_date)}</span>
                      {r.status === 'approved' && <div style={{ fontSize: 11, color: r.overdue ? 'var(--ks-critical)' : 'var(--ks-ink-3)' }}>{r.overdue ? `échue depuis ${-r.days_to_due} j` : `dans ${r.days_to_due} j`}</div>}
                    </td>
                    <td>
                      <span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span>
                      {r.forced && <div className="ks-faint" style={{ fontSize: 11, marginTop: 4 }}>validée sur dérogation</div>}
                    </td>
                  </tr>
                );
              })}
              {rows && list.length === 0 && <tr><td colSpan={7} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucune facture dans ce filtre.</td></tr>}
            </tbody>
          </table>
        </div>
        <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12, lineHeight: 1.6 }} className="ks-faint">
          <Info size={12} style={{ verticalAlign: -1 }} /> Une facture n’obtient le bon à payer que si chaque ligne est couverte par le BC (prix) <b>et</b> par la réception (quantité reçue non encore facturée).
          Chaque réception relance le rapprochement. L’enregistreur d’une facture et le réceptionnaire ne peuvent pas la valider.
        </div>
      </Card>

      {open && <InvoiceDrawer id={open} onClose={() => setOpen(null)} onDone={(m) => { onToast(m); refresh(); }} onError={onError} />}
      {registering && (
        <RegisterInvoice orders={orders} onClose={() => setRegistering(false)} onError={onError}
          onDone={(m, id) => { setRegistering(false); onToast(m); refresh(); setOpen(id); }} />
      )}
    </div>
  );
}

/* ---------------- Détail : la confrontation BC / réception / facture ---------------- */
function InvoiceDrawer({ id, onClose, onDone, onError }: { id: string; onClose: () => void; onDone: (m: string) => void; onError: (m: string) => void }) {
  const [d, setD] = useState<SupplierInvoiceDetail | null>(null);
  const [mode, setMode] = useState<null | 'force' | 'reject' | 'pay'>(null);
  const [comment, setComment] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => { fetchSupplierInvoice(id).then(setD).catch((e) => onError(String(e))); }, [id]); // eslint-disable-line react-hooks/exhaustive-deps

  async function act(action: 'approve' | 'force_approve' | 'reject' | 'pay' | 'rematch', msg: string, c?: string) {
    setBusy(true);
    try {
      await invoiceTransition(id, action, c);
      if (action === 'rematch') { setD(await fetchSupplierInvoice(id)); onDone(msg); } else { onDone(msg); onClose(); }
    } catch (e) { onError(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }

  if (!d) return null;
  const st = STATUS[d.status];
  const lines = d.match?.lines ?? [];
  const issues = d.match?.issues ?? [];
  const v = d.variance_ht ?? 0;
  const open = ['to_match', 'matched', 'discrepancy'].includes(d.status);

  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer kq-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={`Facture ${d.supplier_ref}`}>
        <div className="ka-drawer__head">
          <div>
            <div className="ks-eyebrow">{d.ref} · BC {d.po_ref}</div>
            <h2 style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 2px' }}>{d.supplier_ref}</h2>
            <div className="ks-faint" style={{ fontSize: 13 }}>{d.supplier ?? '—'} · facture du {date(d.invoice_date)} · échéance {date(d.due_date)}</div>
          </div>
          <button className="ks-icon-btn" onClick={onClose} aria-label="Fermer"><X size={16} /></button>
        </div>

        <div className="kq-three">
          <div><span>Commandé (BC)</span><b className="ks-mono">{fcfa(d.po_amount_ht)}</b></div>
          <div><span>Attendu (reçu non facturé)</span><b className="ks-mono">{d.expected_ht == null ? '—' : fcfa(d.expected_ht)}</b></div>
          <div><span>Facturé HT</span><b className="ks-mono">{fcfa(d.amount_ht)}</b></div>
          <div className={Math.abs(v) < 1 ? 'kq-three--ok' : 'kq-three--bad'}><span>Écart</span><b className="ks-mono">{Math.abs(v) < 1 ? '0' : `${v > 0 ? '+' : ''}${fcfa(v)}`}</b></div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '10px 0 16px', flexWrap: 'wrap' }}>
          <span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span>
          <span className="ks-faint" style={{ fontSize: 12 }}>TTC {fcfa(d.amount_ttc)} · TVA {d.tax_rate} % · tolérances : prix ± {d.match?.tolerance_pct ?? 2} %, global ± {fcfa(d.match?.tolerance_amount ?? 10000)}</span>
        </div>

        {issues.length > 0 && (
          <div className="kq-issues">
            {issues.map((i) => <div key={i.code + i.label}><ShieldAlert size={14} /> {i.label}</div>)}
          </div>
        )}

        <div className="kt-cardtitle" style={{ marginTop: 6 }}>Ligne à ligne</div>
        <div style={{ overflowX: 'auto', margin: '6px -4px 0' }}>
          <table className="ks-table kq-match">
            <thead><tr><th>Article</th><th>Cdé</th><th>Reçu</th><th>Déjà fact.</th><th>Facturé</th><th>Prix BC</th><th>Prix fact.</th><th>Contrôle</th></tr></thead>
            <tbody>
              {lines.map((l) => {
                const c = CODE[l.code as MatchCode] ?? CODE.OK;
                const qtyBad = l.code === 'QTY_OVER_RECEIVED' || l.code === 'NOT_RECEIVED';
                const priceBad = l.code === 'PRICE_OVER';
                return (
                  <tr key={l.id}>
                    <td style={{ fontWeight: 600, fontSize: 12.5 }}>{l.label}</td>
                    <td className="ks-mono">{nf(l.ordered)}</td>
                    <td className="ks-mono">{nf(l.received)}{l.refused ? <span className="ks-faint"> (−{nf(l.refused)})</span> : null}</td>
                    <td className="ks-mono ks-faint">{nf(l.billed_before)}</td>
                    <td className={`ks-mono${qtyBad ? ' kq-bad' : ''}`}>{nf(l.invoiced)}</td>
                    <td className="ks-mono">{l.po_price == null ? '—' : nf(l.po_price)}</td>
                    <td className={`ks-mono${priceBad ? ' kq-bad' : ''}`}>
                      {nf(l.unit_price)}
                      {l.price_var_pct != null && Math.abs(l.price_var_pct) > 0.01 && <div style={{ fontSize: 10.5 }}>{l.price_var_pct > 0 ? '+' : ''}{nf(l.price_var_pct, 1)} %</div>}
                    </td>
                    <td><span className={`kq-code kq-code--${c.tone}`}>{c.label}</span></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="kt-cardtitle" style={{ marginTop: 18 }}>Réceptions du BC</div>
        {(d.receipts ?? []).length === 0 && <div className="ks-faint" style={{ fontSize: 12.5 }}>Aucune réception enregistrée.</div>}
        {(d.receipts ?? []).map((r) => (
          <div key={r.at} className="kv-line">
            <span><PackageCheck size={13} style={{ verticalAlign: -2 }} /> {new Date(r.at).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })}</span>
            <span className="ks-faint" style={{ textAlign: 'right' }}>{r.qc === 'accepted' ? 'conforme' : r.qc === 'refused' ? 'refusée' : 'avec réserves'}{r.notes ? ` · ${r.notes}` : ''}</span>
          </div>
        ))}

        {d.decision_comment && <div className="kq-note"><b>Décision :</b> {d.decision_comment}{d.approved_by ? ` — ${d.approved_by}` : ''}</div>}
        {d.payment_ref && <div className="kq-note"><b>Paiement :</b> <span className="ks-mono">{d.payment_ref}</span></div>}

        {mode && (
          <div className="kx-box" style={{ marginTop: 16 }}>
            <label className="kx-lbl">
              {mode === 'force' ? 'Justification de la dérogation (obligatoire, tracée)' : mode === 'reject' ? 'Motif du rejet (transmis au fournisseur)' : 'Référence du paiement (virement, chèque, Mobile Money)'}
              <textarea className="kt-field ki-input" rows={mode === 'pay' ? 1 : 3} value={comment} onChange={(e) => setComment(e.target.value)}
                placeholder={mode === 'force' ? 'ex. Hausse du prix des courroies acceptée — avenant tarifaire du 12/09 signé par la direction technique' : mode === 'reject' ? 'ex. Quantités facturées supérieures aux quantités livrées' : 'ex. VIR-SGBCI-90311'} />
            </label>
            <div style={{ display: 'flex', gap: 8, marginTop: 10, justifyContent: 'flex-end' }}>
              <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => { setMode(null); setComment(''); }}>Annuler</button>
              <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy || (mode === 'force' && comment.trim().length < 10) || (mode === 'reject' && comment.trim().length < 3)}
                onClick={() => void act(mode === 'force' ? 'force_approve' : mode === 'reject' ? 'reject' : 'pay',
                  mode === 'force' ? `${d.supplier_ref} validée sur dérogation` : mode === 'reject' ? `${d.supplier_ref} rejetée` : `${d.supplier_ref} marquée payée`, comment.trim())}>
                <Check size={13} /> Confirmer
              </button>
            </div>
          </div>
        )}

        {!mode && (
          <div className="kq-actions">
            {open && <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy} onClick={() => void act('rematch', 'Rapprochement relancé')}><RefreshCw size={13} /> Relancer</button>}
            {open && <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy} onClick={() => setMode('reject')}><Ban size={13} /> Rejeter</button>}
            {d.status === 'discrepancy' && <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy} onClick={() => setMode('force')}><ShieldAlert size={13} /> Valider sur dérogation</button>}
            {d.status === 'matched' && <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy} onClick={() => void act('approve', `${d.supplier_ref} : bon à payer`)}><Check size={13} /> Bon à payer</button>}
            {d.status === 'approved' && <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy} onClick={() => setMode('pay')}><CircleDollarSign size={13} /> Marquer payée</button>}
          </div>
        )}
      </aside>
    </div>
  );
}

/* ---------------- Saisie d'une facture, pré-remplie sur le reçu non facturé ---------------- */
function RegisterInvoice({ orders, onClose, onDone, onError }: {
  orders: PurchaseOrderRow[]; onClose: () => void; onDone: (m: string, id: string) => void; onError: (m: string) => void;
}) {
  const eligible = orders.filter((o) => o.status !== 'cancelled');
  const [po, setPo] = useState(eligible[0]?.id ?? '');
  const [lines, setLines] = useState<(PoLineStatus & { inv_qty: number; inv_price: number })[] | null>(null);
  const [ref, setRef] = useState('');
  const [day, setDay] = useState(new Date().toISOString().slice(0, 10));
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!po) return;
    setLines(null);
    fetchPoLines(po).then((ls) => setLines(ls.map((l) => ({ ...l, inv_qty: l.qty_to_invoice, inv_price: l.unit_price })))).catch((e) => onError(String(e)));
  }, [po]); // eslint-disable-line react-hooks/exhaustive-deps

  const total = useMemo(() => (lines ?? []).reduce((s, l) => s + l.inv_qty * l.inv_price, 0), [lines]);
  const expected = useMemo(() => (lines ?? []).reduce((s, l) => s + Math.min(l.inv_qty, l.qty_to_invoice) * l.unit_price, 0), [lines]);
  const upd = (id: string, patch: Partial<{ inv_qty: number; inv_price: number }>) => setLines((ls) => (ls ?? []).map((l) => (l.id === id ? { ...l, ...patch } : l)));

  async function submit() {
    setBusy(true);
    try {
      const payload = (lines ?? []).filter((l) => l.inv_qty > 0).map((l) => ({ po_line_id: l.id, label: l.label, qty: l.inv_qty, unit_price: l.inv_price }));
      const r = await invoiceRegister(po, ref.trim(), day, payload);
      onDone(r.status === 'matched' ? `${r.ref} enregistrée · rapprochée sans écart` : `${r.ref} enregistrée · écart détecté, bon à payer bloqué`, r.id);
    } catch (e) { onError(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }

  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer kq-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Saisir une facture fournisseur">
        <div className="ka-drawer__head">
          <div>
            <div className="ks-eyebrow">Comptabilité fournisseurs</div>
            <h2 style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 2px' }}>Saisir une facture</h2>
            <div className="ks-faint" style={{ fontSize: 13 }}>pré-remplie avec ce qui a été reçu et pas encore facturé — corrigez selon le document du fournisseur</div>
          </div>
          <button className="ks-icon-btn" onClick={onClose} aria-label="Fermer"><X size={16} /></button>
        </div>
        <div className="kd-form" style={{ marginTop: 0 }}>
          <label className="kx-lbl" style={{ gridColumn: '1 / -1' }}>Bon de commande
            <select className="kx-in" value={po} onChange={(e) => setPo(e.target.value)}>
              {eligible.map((o) => <option key={o.id} value={o.id}>{o.ref} — {o.supplier ?? '?'} · {fcfa(o.amount_ht)} HT</option>)}
            </select>
          </label>
          <label className="kx-lbl">N° de facture du fournisseur<input className="kx-in ks-mono" value={ref} onChange={(e) => setRef(e.target.value)} placeholder="ex. FA-2026-1043" /></label>
          <label className="kx-lbl">Date de facture<input className="kx-in" type="date" value={day} onChange={(e) => setDay(e.target.value)} /></label>
        </div>

        <div className="kt-cardtitle" style={{ marginTop: 16 }}>Lignes facturées</div>
        {lines && lines.length === 0 && <div className="ks-faint" style={{ fontSize: 12.5 }}>Ce BC n’a pas de ligne.</div>}
        {(lines ?? []).map((l) => {
          const over = l.inv_qty > l.qty_to_invoice;
          const pricey = l.unit_price > 0 && (l.inv_price - l.unit_price) / l.unit_price > 0.02;
          return (
            <div key={l.id} className="kq-line">
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 13 }}>{l.label}</div>
                <div className="ks-faint" style={{ fontSize: 11.5 }}>cdé {nf(l.qty_ordered)} · reçu {nf(l.qty_received)} · déjà facturé {nf(l.qty_invoiced)} · <b>facturable {nf(l.qty_to_invoice)}</b> à {nf(l.unit_price)}</div>
              </div>
              <input className={`kx-in kx-in--num${over ? ' kq-in--bad' : ''}`} type="number" min={0} value={l.inv_qty} aria-label={`Quantité facturée ${l.label}`}
                onChange={(e) => upd(l.id, { inv_qty: Math.max(0, Number(e.target.value)) })} />
              <input className={`kx-in kx-in--price${pricey ? ' kq-in--bad' : ''}`} type="number" min={0} value={l.inv_price} aria-label={`Prix unitaire facturé ${l.label}`}
                onChange={(e) => upd(l.id, { inv_price: Math.max(0, Number(e.target.value)) })} />
            </div>
          );
        })}
        <div className="kv-line kv-line--total"><span>Total HT facturé</span><span className="ks-mono">{fcfa(total)}</span></div>
        <div className="kv-line"><span className="ks-faint">Attendu au regard du reçu et du BC</span><span className="ks-mono" style={{ color: Math.abs(total - expected) > 10000 ? 'var(--ks-critical)' : 'var(--ks-low)' }}>{fcfa(expected)}</span></div>
        <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || !po || ref.trim().length < 2 || total <= 0} onClick={() => void submit()}>
          <Receipt size={15} /> {busy ? '…' : 'Enregistrer et rapprocher'}
        </button>
      </aside>
    </div>
  );
}

/* ---------------- Réception partielle ligne à ligne ---------------- */
export function ReceiveDrawer({ order, onClose, onDone, onError }: {
  order: PurchaseOrderRow; onClose: () => void; onDone: (m: string) => void; onError: (m: string) => void;
}) {
  const [lines, setLines] = useState<(PoLineStatus & { rx: number; rf: number })[] | null>(null);
  const [qc, setQc] = useState<'accepted' | 'accepted_with_reserves'>('accepted');
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    fetchPoLines(order.id).then((ls) => setLines(ls.map((l) => ({ ...l, rx: l.qty_to_receive, rf: 0 })))).catch((e) => onError(String(e)));
  }, [order.id]); // eslint-disable-line react-hooks/exhaustive-deps
  const upd = (id: string, patch: Partial<{ rx: number; rf: number }>) => setLines((ls) => (ls ?? []).map((l) => (l.id === id ? { ...l, ...patch } : l)));
  const any = (lines ?? []).some((l) => l.rx + l.rf > 0);

  async function submit() {
    setBusy(true);
    try {
      const r = await poReceiveLines(order.id, (lines ?? []).filter((l) => l.rx + l.rf > 0).map((l) => ({ line_id: l.id, qty: l.rx, refused: l.rf })), qc, notes.trim() || undefined);
      onDone(`${order.ref} : ${r.status === 'received' ? 'réception soldée' : 'réception partielle'} · +${r.stock_in} en stock · factures du BC re-rapprochées`);
      onClose();
    } catch (e) { onError(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }

  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer kq-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={`Réceptionner ${order.ref}`}>
        <div className="ka-drawer__head">
          <div>
            <div className="ks-eyebrow">Réception · contrôle qualité</div>
            <h2 style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 2px' }}>{order.ref}</h2>
            <div className="ks-faint" style={{ fontSize: 13 }}>{order.supplier ?? '—'} — saisissez ce qui est réellement livré ; le reliquat reste attendu</div>
          </div>
          <button className="ks-icon-btn" onClick={onClose} aria-label="Fermer"><X size={16} /></button>
        </div>
        {(lines ?? []).map((l) => (
          <div key={l.id} className="kq-line">
            <div style={{ minWidth: 0, flex: 1 }}>
              <div style={{ fontWeight: 600, fontSize: 13 }}>{l.label}</div>
              <div className="ks-faint" style={{ fontSize: 11.5 }}>cdé {nf(l.qty_ordered)} · déjà reçu {nf(l.qty_received)}{l.qty_refused ? ` · refusé ${nf(l.qty_refused)}` : ''} · <b>reste {nf(l.qty_to_receive)}</b></div>
            </div>
            <label className="kx-lbl" style={{ flex: '0 0 auto' }}>reçu<input className="kx-in kx-in--num" type="number" min={0} max={l.qty_to_receive} value={l.rx} disabled={l.qty_to_receive === 0}
              onChange={(e) => upd(l.id, { rx: Math.max(0, Math.min(l.qty_to_receive - l.rf, Number(e.target.value))) })} /></label>
            <label className="kx-lbl" style={{ flex: '0 0 auto' }}>refusé<input className="kx-in kx-in--num" type="number" min={0} value={l.rf} disabled={l.qty_to_receive === 0}
              onChange={(e) => upd(l.id, { rf: Math.max(0, Math.min(l.qty_to_receive - l.rx, Number(e.target.value))) })} /></label>
          </div>
        ))}
        <div className="kx-chips" style={{ marginTop: 14 }}>
          <button className={`kx-chip${qc === 'accepted' ? ' kx-chip--on' : ''}`} onClick={() => setQc('accepted')}>Conforme</button>
          <button className={`kx-chip${qc === 'accepted_with_reserves' ? ' kx-chip--on' : ''}`} onClick={() => setQc('accepted_with_reserves')}>Avec réserves</button>
        </div>
        <label className="kx-lbl" style={{ marginTop: 10 }}>Observations (bon de livraison, réserves)
          <input className="kx-in" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="ex. BL n° 4471 — 2 cartons abîmés" />
        </label>
        <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || !any} onClick={() => void submit()}><PackageCheck size={15} /> {busy ? '…' : 'Valider la réception'}</button>
      </aside>
    </div>
  );
}
