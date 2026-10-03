import { useEffect, useState } from 'react';
import { FileText, FilePlus2, ClipboardSignature, PauseCircle, Timer, X, Check, Camera, AlertOctagon, Wrench, ExternalLink } from 'lucide-react';
import { Card } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { PortalRow, PortalDetail } from '@keystone/domain/db/keystone';
import { fetchPortalBoard, fetchPortalDetail, quoteDecide, variationDecide, reportValidate, pauseArbitrate, signedPhotoUrls, isStoredPhoto } from '../../data/portal-contractor.ts';

const fcfa = (n: number) => format(money(n, 'XOF'));
const PAUSE: Record<string, string> = {
  waiting_quote: 'Attente validation devis', waiting_permit: 'Attente permis de travail', waiting_parts: 'Attente pièces',
  client_delay: 'Indisponibilité client', force_majeure: 'Force majeure',
};
const KIND: Record<string, string> = { labor: 'Main d’œuvre', material: 'Fournitures', travel: 'Déplacement', other: 'Autre' };
const SEV = { critical: 'critical', major: 'high', minor: 'medium' } as const;

/** Étape du cycle prestataire : devis → exécution → rapport → validé. */
function stage(r: PortalRow): { label: string; tone: string; action: boolean } {
  if (r.report_status === 'submitted') return { label: 'Rapport à valider', tone: 'var(--ks-amber-700)', action: true };
  if (r.quote_status === 'submitted') return { label: 'Devis à valider', tone: 'var(--ks-amber-700)', action: true };
  if (r.variations_pending > 0) return { label: 'Avenant à arbitrer', tone: 'var(--ks-amber-700)', action: true };
  if (r.paused_now && r.pending_pause_h > 0) return { label: 'Pause à arbitrer', tone: 'var(--ks-high)', action: true };
  if (r.report_status === 'validated') return { label: 'Clôturé · signé', tone: 'var(--ks-low)', action: false };
  if (r.paused_now) return { label: 'En pause', tone: 'var(--ks-ink-2)', action: false };
  return { label: 'En exécution', tone: 'var(--ks-info)', action: false };
}

export function ContractorPortal({ onToast }: { onToast: (m: string) => void }) {
  const [rows, setRows] = useState<PortalRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [sel, setSel] = useState<PortalRow | null>(null);

  function load() { fetchPortalBoard().then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }
  useEffect(load, []);
  const pending = (rows ?? []).filter((r) => stage(r).action).length;

  return (
    <div className="ks-reveal">
      {err && <div className="ks-mono ks-faint" style={{ fontSize: 12, marginBottom: 12 }}>{err}</div>}
      {rows && (
        <div className="ks-faint" style={{ fontSize: 12.5, marginBottom: 12 }}>
          {pending > 0 ? <><b style={{ color: 'var(--ks-amber-700)' }}>{pending}</b> élément(s) attendent votre arbitrage.</> : 'Rien à arbitrer.'}
          {' '}Le prestataire saisit devis, avenants, pauses et rapports depuis son propre accès : la base ne lui montre que ses OT.
          <a className="ks-btn ks-btn--ghost ks-btn--sm" style={{ marginLeft: 10 }} href="?prestataire" target="_blank" rel="noreferrer">
            <ExternalLink size={13} /> Ouvrir l’espace prestataire
          </a>
        </div>
      )}
      <Card pad={false}>
        <div style={{ overflowX: 'auto' }}>
          <table className="ks-table">
            <thead><tr><th>OT</th><th>Prestataire</th><th>Étape</th><th>Devis</th><th>Chrono SLA</th><th></th></tr></thead>
            <tbody>
              {(rows ?? []).map((r) => {
                const s = stage(r);
                const effective = Math.max(0, r.elapsed_h - r.paused_h);
                return (
                  <tr key={r.wo_id} style={{ cursor: 'pointer' }} onClick={() => setSel(r)}>
                    <td><div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{r.wo_ref} · {r.asset_tag ?? '—'}</div><div style={{ fontWeight: 600 }}>{r.title}</div></td>
                    <td style={{ fontSize: 12.5 }}>{r.contractor}</td>
                    <td><span style={{ color: s.tone, fontWeight: 600, fontSize: 12.5, display: 'inline-flex', alignItems: 'center', gap: 6 }}>{s.action && <span className="kv-sla__dot kv-sla__dot--ko" style={{ background: s.tone, boxShadow: 'none' }} />}{s.label}</span></td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{r.quote_total != null ? fcfa(r.quote_total + r.variations_total) : '—'}{r.variations_total > 0 && <div className="ks-faint" style={{ fontSize: 10.5 }}>dont avenants {fcfa(r.variations_total)}</div>}</td>
                    <td>
                      <span className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{effective.toFixed(1)} h</span>
                      {(r.paused_h > 0 || r.pending_pause_h > 0) && <div className="ks-faint" style={{ fontSize: 10.5 }}>−{r.paused_h} h justifiées{r.pending_pause_h > 0 ? ` · ${r.pending_pause_h} h en arbitrage` : ''}</div>}
                    </td>
                    <td style={{ textAlign: 'right' }}>{s.action && <span className="ks-btn ks-btn--ghost ks-btn--sm">Arbitrer</span>}</td>
                  </tr>
                );
              })}
              {rows && rows.length === 0 && <tr><td colSpan={6} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucun OT confié à un prestataire.</td></tr>}
            </tbody>
          </table>
        </div>
      </Card>
      {sel && <PortalDrawer row={sel} onClose={() => setSel(null)} onChanged={(m) => { onToast(m); load(); setSel(null); }} />}
    </div>
  );
}

function PortalDrawer({ row, onClose, onChanged }: { row: PortalRow; onClose: () => void; onChanged: (m: string) => void }) {
  const [d, setD] = useState<PortalDetail | null>(null);
  const [signer, setSigner] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [urls, setUrls] = useState<Record<string, string>>({});
  useEffect(() => { fetchPortalDetail(row.wo_id).then(setD).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }, [row.wo_id]);
  useEffect(() => { if (d?.report) signedPhotoUrls([...d.report.before, ...d.report.after]).then(setUrls).catch(() => {}); }, [d]);

  async function act(fn: () => Promise<string>) {
    setBusy(true); setErr(null);
    try { onChanged(await fn()); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }
  const quoteTotal = (d?.quote_items ?? []).reduce((s, i) => s + Number(i.total), 0);

  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={row.title}>
        <div className="ka-drawer__head">
          <div>
            <div className="ks-mono ks-faint" style={{ fontSize: 12 }}>{row.wo_ref} · {row.contractor}</div>
            <h2 style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 0' }}>{row.title}</h2>
          </div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>
        {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12.5, marginBottom: 12 }}>{err}</div>}

        {/* Devis */}
        <section className="kv-sec">
          <h3><FileText size={15} /> Devis {row.quote_ref && <span className="ks-mono ks-faint">{row.quote_ref}</span>}</h3>
          {!d?.quote_items && <div className="ks-faint" style={{ fontSize: 12.5 }}>Aucun devis transmis.</div>}
          {d?.quote_items?.map((i, k) => (
            <div key={k} className="kv-line"><span><span className="ks-faint">{KIND[i.kind]} · </span>{i.label} <span className="ks-faint">× {Number(i.qty)}</span></span><b className="ks-mono">{fcfa(Number(i.total))}</b></div>
          ))}
          {d?.quote_items && <div className="kv-line kv-line--total"><span>Total HT</span><b className="ks-mono">{fcfa(quoteTotal)}</b></div>}
          {row.quote_status === 'submitted' && row.quote_id && (
            <div className="kv-actions">
              <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy} onClick={() => act(async () => { await quoteDecide(row.quote_id!, false, 'Montant à revoir'); return `${row.quote_ref} rejeté`; })}>Rejeter</button>
              <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy} onClick={() => act(async () => { await quoteDecide(row.quote_id!, true); return `${row.quote_ref} approuvé · coûts de l’OT mis à jour`; })}><Check size={13} /> Approuver le devis</button>
            </div>
          )}
          {row.quote_status === 'approved' && <div className="ks-pill" style={{ color: 'var(--ks-low)', marginTop: 8 }}><Check size={12} /> Approuvé</div>}
        </section>

        {/* Avenants */}
        {d?.variations && (
          <section className="kv-sec">
            <h3><FilePlus2 size={15} /> Avenants</h3>
            {d.variations.map((v) => (
              <div key={v.id} className="kv-var">
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13 }}>{v.reason}</div>
                  <div className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>+{fcfa(Number(v.extra_cost))} · +{Number(v.extra_hours)} h{quoteTotal > 0 && ` · ${Math.round((Number(v.extra_cost) / quoteTotal) * 100)} % du devis`}</div>
                  {v.status === 'escalated' && <div style={{ fontSize: 11.5, color: 'var(--ks-high)', marginTop: 3 }}>Cumul &gt; 20 % du devis : seconde validation par une autre personne requise</div>}
                </div>
                {(v.status === 'pending' || v.status === 'escalated') ? (
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy} onClick={() => act(async () => { await variationDecide(v.id, false); return 'Avenant rejeté'; })}>Rejeter</button>
                    <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy} onClick={() => act(async () => { const r = await variationDecide(v.id, true); return r.status === 'escalated' ? 'Avenant escaladé : seconde validation requise' : 'Avenant approuvé'; })}><Check size={13} /> Valider</button>
                  </div>
                ) : <span className="ks-pill" style={{ color: v.status === 'approved' ? 'var(--ks-low)' : 'var(--ks-ink-3)' }}>{v.status === 'approved' ? 'Approuvé' : 'Rejeté'}</span>}
              </div>
            ))}
          </section>
        )}

        {/* Pauses SLA */}
        {d?.pauses && (
          <section className="kv-sec">
            <h3><Timer size={15} /> Chrono SLA</h3>
            <div className="ks-faint" style={{ fontSize: 12, marginBottom: 8 }}>Écoulé {row.elapsed_h} h · déduit {row.paused_h} h (pauses justifiées seulement)</div>
            {d.pauses.map((p) => (
              <div key={p.id} className="kv-var">
                <PauseCircle size={16} style={{ color: 'var(--ks-ink-3)', flexShrink: 0 }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13, fontWeight: 600 }}>{PAUSE[p.reason] ?? p.reason}</div>
                  <div className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>depuis {new Date(p.started_at).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}{p.ended_at ? ' · terminée' : ' · en cours'}</div>
                </div>
                {p.justified == null ? (
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy} onClick={() => act(async () => { await pauseArbitrate(p.id, false); return 'Pause refusée : le chrono SLA continue'; })}>Refuser</button>
                    <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy} onClick={() => act(async () => { await pauseArbitrate(p.id, true); return 'Pause acceptée : déduite du chrono SLA'; })}>Accepter</button>
                  </div>
                ) : <span className="ks-pill" style={{ color: p.justified ? 'var(--ks-low)' : 'var(--ks-critical)' }}>{p.justified ? 'Justifiée' : 'Refusée'}</span>}
              </div>
            ))}
          </section>
        )}

        {/* Rapport */}
        <section className="kv-sec">
          <h3><ClipboardSignature size={15} /> Rapport d’intervention</h3>
          {!d?.report && <div className="ks-faint" style={{ fontSize: 12.5 }}>Pas encore de rapport.</div>}
          {d?.report && (
            <>
              <div style={{ fontSize: 13, lineHeight: 1.55 }}>{d.report.summary}</div>
              <div className="ks-faint" style={{ fontSize: 12, marginTop: 4 }}>Technicien : {d.report.technician}</div>
              <div className="kv-photos">
                {(['before', 'after'] as const).map((k) => (
                  <div key={k}>
                    <div className="ks-eyebrow" style={{ marginBottom: 6 }}>{k === 'before' ? 'Avant' : 'Après'}</div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      {d.report![k].map((p) => (
                        <a key={p} className="kv-photo" title={p} href={urls[p]} target="_blank" rel="noreferrer">
                          {isStoredPhoto(p) && urls[p] ? <img src={urls[p]} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 9 }} /> : <Camera size={16} />}
                        </a>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
              {d.report.anomalies?.map((a, k) => (
                <div key={k} className="kv-var">
                  <AlertOctagon size={15} style={{ color: `var(--ks-${SEV[a.severity]})`, flexShrink: 0 }} />
                  <div style={{ flex: 1, fontSize: 13 }}>{a.description}</div>
                  {a.follow_up ? <span className="ks-pill"><Wrench size={11} /> {a.follow_up}</span> : <span className={`ks-risk ks-risk--${SEV[a.severity]}`}>{a.severity === 'critical' ? 'Critique' : a.severity === 'major' ? 'Majeure' : 'Mineure'}</span>}
                </div>
              ))}
              {d.report.status === 'submitted' && (
                <>
                  <input className="kt-field ki-input" style={{ width: '100%', marginTop: 12 }} placeholder="Nom du signataire client" value={signer} onChange={(e) => setSigner(e.target.value)} />
                  <div className="kv-actions">
                    <button className="ks-btn ks-btn--quiet ks-btn--sm" disabled={busy} onClick={() => act(async () => { await reportValidate(d.report!.id, '', false, 'Rapport incomplet'); return 'Rapport renvoyé au prestataire'; })}>Renvoyer</button>
                    <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={busy || !signer.trim()} onClick={() => act(async () => { const r = await reportValidate(d.report!.id, signer, true); return `Rapport signé${r.follow_ups ? ` · ${r.follow_ups} OT de suivi créé(s) pour les anomalies` : ''}`; })}>
                      <ClipboardSignature size={13} /> Signer &amp; valider
                    </button>
                  </div>
                  <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 6 }}>Les anomalies majeures ou critiques ouvriront chacune un OT correctif de suivi.</div>
                </>
              )}
              {d.report.status === 'validated' && <div className="ks-pill" style={{ color: 'var(--ks-low)', marginTop: 10 }}><Check size={12} /> Signé par {d.report.client_signed_by}</div>}
            </>
          )}
        </section>
      </aside>
    </div>
  );
}
