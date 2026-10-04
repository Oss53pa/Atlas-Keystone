import { useEffect, useState, type ReactNode } from 'react';
import { Printer, X, AlertTriangle } from 'lucide-react';
import { money, format } from '@keystone/domain';
import type { CompanyProfile, PoDocument, WoDocument } from '@keystone/domain/db/keystone';
import { fetchPoDocument, fetchWoDocument } from '../../data/documents.ts';

const fcfa = (n: number | null | undefined) => format(money(Math.round(Number(n ?? 0)), 'XOF'));
const dd = (s: string | null | undefined) => (s ? new Date(s).toLocaleDateString('fr-FR') : '—');
const dt = (s: string | null | undefined) => (s ? new Date(s).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const WO_TYPE: Record<string, string> = { corrective: 'Correctif', preventive: 'Préventif', conditional: 'Conditionnel', predictive: 'Prédictif', regulatory: 'Réglementaire' };

/** Feuille A4 imprimable : en-tête société, titre, contenu, pied de page. Impression = PDF via le navigateur. */
function DocSheet({ company, title, number, subtitle, children, onClose }: {
  company: CompanyProfile | null; title: string; number: string; subtitle?: string; children: ReactNode; onClose: () => void;
}) {
  return (
    <div className="ka-overlay kd-print-root" onClick={onClose}>
      <div className="kd-sheet" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={`${title} ${number}`}>
        <div className="kd-actions kd-noprint">
          <span className="ks-faint" style={{ fontSize: 12, marginRight: 'auto' }}>Aperçu A4 — « Imprimer » puis « Enregistrer en PDF »</span>
          <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={() => window.print()}><Printer size={13} /> Imprimer / PDF</button>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={16} /></button>
        </div>
        <header className="kd-head">
          <div>
            <div className="kd-brand">{company?.trade_name ?? company?.legal_name ?? 'Société'}</div>
            <div className="kd-legal">
              {company?.legal_name}{company?.legal_form ? ` · ${company.legal_form}` : ''}<br />
              {[company?.address, company?.city, company?.country].filter(Boolean).join(', ')}<br />
              {company?.rccm && <>RCCM {company.rccm} · </>}{company?.ncc && <>NCC {company.ncc}</>}<br />
              {[company?.phone, company?.email].filter(Boolean).join(' · ')}
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="kd-title">{title}</div>
            <div className="kd-number">{number}</div>
            {subtitle && <div className="kd-sub">{subtitle}</div>}
          </div>
        </header>
        {children}
        <footer className="kd-foot">
          {company?.bank_name && <div>Coordonnées bancaires : {company.bank_name} — {company.bank_account}</div>}
          <div>{company?.document_footer ?? 'Document généré par Atlas Keystone.'}</div>
        </footer>
      </div>
    </div>
  );
}

function Loading({ err, onClose }: { err: string | null; onClose: () => void }) {
  return (
    <div className="ka-overlay" onClick={onClose}>
      <div className="kd-sheet" style={{ minHeight: 0, textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
        {err ? <><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></> : <span className="ks-faint">Préparation du document…</span>}
      </div>
    </div>
  );
}

export function PurchaseOrderDoc({ poId, onClose }: { poId: string; onClose: () => void }) {
  const [d, setD] = useState<PoDocument | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { fetchPoDocument(poId).then(setD).catch((e) => setErr(String(e))); }, [poId]);
  if (!d) return <Loading err={err} onClose={onClose} />;
  const appr = [['Validation technique', d.approvals.tech], ['Contrôle budgétaire', d.approvals.budget], ['Direction', d.approvals.direction]] as const;
  return (
    <DocSheet company={d.company} title="Bon de commande" number={d.ref} subtitle={`Émis le ${dd(d.date)}`} onClose={onClose}>
      <div className="kd-grid">
        <div className="kd-box"><div className="kd-label">Fournisseur</div><b>{d.supplier?.name ?? '—'}</b>
          {d.supplier?.tax_id && <div>NCC {d.supplier.tax_id}</div>}{d.supplier?.phone && <div>{d.supplier.phone}</div>}{d.supplier?.email && <div>{d.supplier.email}</div>}</div>
        <div className="kd-box"><div className="kd-label">Livraison</div><b>{d.delivery ?? d.company?.trade_name ?? '—'}</b>
          <div>Date souhaitée : {dd(d.expected_at)}</div><div>Réf. demande d’achat : {d.pr_ref}</div>{d.urgency !== 'normal' && <div style={{ fontWeight: 700 }}>Urgence : {d.urgency === 'critical' ? 'critique' : 'urgente'}</div>}</div>
      </div>
      <div className="kd-label" style={{ marginTop: 14 }}>Objet : {d.pr_title}</div>
      <table className="kd-table">
        <thead><tr><th>Désignation</th><th className="kd-num">Qté</th><th className="kd-num">P.U. HT</th><th className="kd-num">Total HT</th></tr></thead>
        <tbody>
          {(d.lines ?? []).map((l, i) => (
            <tr key={i}><td>{l.label}</td><td className="kd-num">{Number(l.qty)}{l.unit ? ` ${l.unit}` : ''}</td><td className="kd-num">{fcfa(l.unit_price)}</td><td className="kd-num">{fcfa(l.total)}</td></tr>
          ))}
        </tbody>
      </table>
      <div className="kd-totals">
        <div><span>Total HT</span><b>{fcfa(d.amount_ht)}</b></div>
        <div><span>TVA {Number(d.tax_rate)} %</span><b>{fcfa(d.tax)}</b></div>
        <div className="kd-totals__grand"><span>Total TTC</span><b>{fcfa(d.amount_ttc)}</b></div>
      </div>
      <div className="kd-label" style={{ marginTop: 16 }}>Circuit d’approbation</div>
      <div className="kd-signs">
        {appr.filter(([, a]) => a).map(([label, a]) => (
          <div key={label} className="kd-sign"><div className="kd-label">{label}</div><b>{a?.by ?? '—'}</b><div>{dt(a?.at)}</div></div>
        ))}
        <div className="kd-sign"><div className="kd-label">Bon pour accord fournisseur</div><div className="kd-sign__line" /></div>
      </div>
      {d.company?.purchase_terms && <div className="kd-terms"><b>Conditions d’achat.</b> {d.company.purchase_terms} Paiement à {d.company.payment_terms_days} jours.</div>}
    </DocSheet>
  );
}

export function WorkOrderDoc({ woId, onClose }: { woId: string; onClose: () => void }) {
  const [d, setD] = useState<WoDocument | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { fetchWoDocument(woId).then(setD).catch((e) => setErr(String(e))); }, [woId]);
  if (!d) return <Loading err={err} onClose={onClose} />;
  const parts = (d.lines ?? []).filter((l) => l.kind === 'part');
  const labor = (d.lines ?? []).filter((l) => l.kind === 'labor');
  const minutes = labor.reduce((s, l) => s + (l.minutes ?? 0), 0);
  const checkIn = d.time?.find((t) => t.kind === 'check_in');
  const checkOut = [...(d.time ?? [])].reverse().find((t) => t.kind === 'check_out');
  return (
    <DocSheet company={d.company} title="Fiche d’intervention" number={d.ref} subtitle={`${WO_TYPE[d.type] ?? d.type} · priorité P${d.priority}`} onClose={onClose}>
      <div className="kd-grid">
        <div className="kd-box"><div className="kd-label">Équipement</div>
          <b>{d.asset ? `${d.asset.tag} — ${d.asset.name}` : '—'}</b>
          {d.asset && <div>{[d.asset.manufacturer, d.asset.model, d.asset.serial && `S/N ${d.asset.serial}`].filter(Boolean).join(' · ')}</div>}
          <div>{d.site ?? ''}{d.location ? ` · ${d.location}` : ''}</div></div>
        <div className="kd-box"><div className="kd-label">Intervention</div>
          <div>Intervenant : <b>{d.contractor ?? d.assignee ?? '—'}</b></div>
          <div>Arrivée : {dt(checkIn?.at ?? d.actual_start)}{checkIn?.distance != null ? ` (${Math.round(Number(checkIn.distance))} m du site)` : ''}</div>
          <div>Départ : {dt(checkOut?.at ?? d.actual_end)}</div>
          {d.permit && <div>Permis : {d.permit.ref} ({d.permit.type})</div>}</div>
      </div>
      <div className="kd-label" style={{ marginTop: 14 }}>Objet</div>
      <div style={{ fontWeight: 700 }}>{d.title}</div>
      {d.description && <div className="kd-text">{d.description}</div>}
      {d.safety && <div className="kd-safety"><b>Consignes de sécurité :</b> {d.safety}</div>}

      {(d.checklist ?? []).length > 0 && (
        <>
          <div className="kd-label" style={{ marginTop: 14 }}>Points de contrôle</div>
          <table className="kd-table">
            <thead><tr><th style={{ width: 28 }}>#</th><th>Étape</th><th>Relevé</th><th style={{ width: 80 }}>Résultat</th></tr></thead>
            <tbody>
              {(d.checklist ?? []).map((s) => (
                <tr key={s.index}>
                  <td>{s.index + 1}</td>
                  <td>{s.label}{s.critical ? ' (critique)' : ''}</td>
                  <td>{s.type === 'numeric' ? `${s.value ?? '—'} ${s.unit ?? ''} (plage ${s.min ?? '−∞'}–${s.max ?? '+∞'})` : s.type === 'photo' ? (s.value ? 'photo jointe' : '—') : s.type === 'text' ? String(s.value ?? '—') : s.value === true ? 'fait' : s.value === false ? 'non fait' : '—'}</td>
                  <td style={{ fontWeight: 700 }}>{s.done_at ? (s.ok ? '✓ conforme' : '✗ non conforme') : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {parts.length > 0 && (
        <>
          <div className="kd-label" style={{ marginTop: 14 }}>Pièces utilisées</div>
          <table className="kd-table">
            <thead><tr><th>Pièce</th><th className="kd-num">Qté</th><th className="kd-num">P.U.</th><th className="kd-num">Total</th></tr></thead>
            <tbody>{parts.map((p, i) => <tr key={i}><td>{p.label}</td><td className="kd-num">{Number(p.qty)}</td><td className="kd-num">{fcfa(p.unit_cost)}</td><td className="kd-num">{fcfa(Number(p.qty) * Number(p.unit_cost ?? 0))}</td></tr>)}</tbody>
          </table>
        </>
      )}

      <div className="kd-totals">
        <div><span>Main d’œuvre{minutes ? ` (${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')})` : ''}</span><b>{fcfa(d.cost_labor)}</b></div>
        <div><span>Pièces</span><b>{fcfa(d.cost_parts)}</b></div>
        <div className="kd-totals__grand"><span>Coût de l’intervention</span><b>{fcfa(Number(d.cost_labor ?? 0) + Number(d.cost_parts ?? 0))}</b></div>
      </div>
      {d.notes && <><div className="kd-label" style={{ marginTop: 14 }}>Compte rendu</div><div className="kd-text" style={{ whiteSpace: 'pre-wrap' }}>{d.notes}</div></>}

      <div className="kd-signs">
        <div className="kd-sign"><div className="kd-label">Technicien</div><b>{d.signed_by ?? '—'}</b><div>{dt(d.actual_end)}</div></div>
        <div className="kd-sign"><div className="kd-label">Vérification (superviseur)</div><b>{d.verified_by ?? '—'}</b><div>{dt(d.verified_at)}</div>{!d.verified_by && <div className="kd-sign__line" />}</div>
      </div>
    </DocSheet>
  );
}
