import { useEffect, useState } from 'react';
import { HardHat, Star, Smartphone, ShieldCheck, RefreshCw, AlertTriangle, CheckCircle2, Wallet, BadgeCheck } from 'lucide-react';
import { Card, StatBig, TabBar } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { ContractorRow, InvoiceRow, InvoiceStatus } from '@keystone/domain/db/keystone';
import { fetchContractors, fetchInvoices, approveInvoice, payInvoice } from '../../data/contractors.ts';
import { ContractorPerformance } from './ContractorPerformance.tsx';
import { ContractorPortal } from './ContractorPortal.tsx';

const fcfa = (n: number) => format(money(n, 'XOF'));
const INV: Record<InvoiceStatus, { label: string; color: string; bg: string }> = {
  draft: { label: 'Brouillon', color: 'var(--ks-ink-2)', bg: 'var(--ks-surface-3)' },
  submitted: { label: 'Soumise', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  approved: { label: 'Validée', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  paid: { label: 'Payée', color: '#2C6230', bg: 'var(--ks-low-100)' },
  rejected: { label: 'Rejetée', color: 'var(--ks-ink-3)', bg: 'var(--ks-surface-3)' },
};

export function Contractors() {
  const [cs, setCs] = useState<ContractorRow[] | null>(null);
  const [inv, setInv] = useState<InvoiceRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [tab, setTab] = useState('perf');

  function load() {
    fetchContractors().then(setCs).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchInvoices().then(setInv).catch(() => {});
  }
  useEffect(load, []);

  async function approve(id: string) {
    setBusy(id);
    try { await approveInvoice(id); load(); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }
  async function pay(id: string) {
    setBusy(id);
    try { const r = await payInvoice(id); setToast(`Paiement Mobile Money émis · réf ${r.provider_ref}`); load(); setTimeout(() => setToast(null), 4000); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }

  const contractors = cs ?? [];
  const invoices = inv ?? [];
  const totalPaid = contractors.reduce((s, c) => s + c.paid_amount, 0);
  const expiring = contractors.reduce((s, c) => s + c.certs_expiring, 0);

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Pilotage · Sous-traitance</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Prestataires</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">préqualification · habilitations · paiement Mobile Money (CinetPay)</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {toast && <div style={{ marginBottom: 14, padding: '11px 16px', borderRadius: 'var(--ks-r-md)', background: 'var(--ks-low-100)', color: '#2C6230', fontSize: 13.5, display: 'flex', alignItems: 'center', gap: 8 }}><CheckCircle2 size={16} /> {toast}</div>}
      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      <div className="kt-dash kt-dash--3 ks-reveal" style={{ marginBottom: 18 }}>
        <Card><StatBig label="Prestataires préqualifiés" icon={<HardHat size={15} />} value={contractors.filter((c) => c.prequalified).length} sub={`${contractors.length} au total`} /></Card>
        <Card><StatBig label="Habilitations à échéance" icon={<ShieldCheck size={15} />} accent={expiring ? 'var(--ks-high)' : 'var(--ks-low)'} value={expiring} sub="< 30 jours" /></Card>
        <Card><StatBig label="Payé (Mobile Money)" icon={<Wallet size={15} />} accent="var(--ks-low)" value={fcfa(totalPaid)} sub="décaissé via CinetPay" /></Card>
      </div>

      <div style={{ marginBottom: 16 }}>
        <TabBar
          tabs={[{ id: 'perf', label: 'Performance & SLA', icon: <Star size={15} /> }, { id: 'portal', label: 'Portail · interventions', icon: <ShieldCheck size={15} /> }, { id: 'list', label: 'Prestataires & factures', icon: <HardHat size={15} /> }]}
          active={tab} onChange={setTab}
        />
      </div>

      {tab === 'portal' && <ContractorPortal onToast={(m) => { setToast(m); setTimeout(() => setToast(null), 4500); }} />}

      {tab === 'perf' && <ContractorPerformance onToast={(m) => { setToast(m); setTimeout(() => setToast(null), 4000); }} />}

      {tab === 'list' && <>
      <div className="kt-section-h"><h2>Prestataires</h2></div>
      {cs && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Prestataire</th><th>Statut</th><th>Note</th><th>Mobile Money</th><th>Habilitations</th><th>Factures ouvertes</th><th>Payé</th></tr></thead>
              <tbody>
                {contractors.map((c) => (
                  <tr key={c.id}>
                    <td style={{ fontWeight: 600 }}>{c.name}</td>
                    <td>{c.prequalified ? <span className="ks-pill" style={{ color: 'var(--ks-low)' }}><BadgeCheck size={12} /> Préqualifié</span> : <span className="ks-pill" style={{ color: 'var(--ks-high)' }}>Non qualifié</span>}</td>
                    <td><span className="ks-mono" style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontWeight: 600 }}><Star size={13} color="var(--ks-amber)" /> {c.rating?.toFixed(1) ?? '—'}</span></td>
                    <td>{c.mobile_money ? <Smartphone size={15} color="var(--ks-low)" /> : <span className="ks-faint">—</span>}</td>
                    <td><span className="ks-mono">{c.certs_total}</span>{c.certs_expiring > 0 && <span className="ks-risk ks-risk--high" style={{ marginLeft: 8 }}>{c.certs_expiring} à renouveler</span>}</td>
                    <td className="ks-mono">{c.open_invoices}</td>
                    <td className="ks-mono">{fcfa(c.paid_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      <div className="kt-section-h"><h2>Factures</h2><span className="kt-count">validation → dépense → paiement</span></div>
      {inv && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Réf.</th><th>Prestataire</th><th>OT</th><th>Montant</th><th>Statut</th><th></th></tr></thead>
              <tbody>
                {invoices.map((i) => {
                  const st = INV[i.status];
                  return (
                    <tr key={i.id}>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{i.ref}</td>
                      <td style={{ fontWeight: 600 }}>{i.contractor_name}</td>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{i.wo_ref ?? '—'}</td>
                      <td className="ks-mono" style={{ fontWeight: 600 }}>{fcfa(i.amount)}</td>
                      <td><span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span></td>
                      <td style={{ textAlign: 'right' }}>
                        {i.status === 'submitted' && <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === i.id} onClick={() => approve(i.id)}>{busy === i.id ? '…' : 'Valider'}</button>}
                        {i.status === 'approved' && <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy === i.id} onClick={() => pay(i.id)}>{busy === i.id ? '…' : <><Smartphone size={13} /> Payer</>}</button>}
                        {i.status === 'paid' && <span className="ks-pill" style={{ color: 'var(--ks-low)' }}><CheckCircle2 size={12} /> Réglée</span>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}
      </>}
    </div>
  );
}
