import { useEffect, useState } from 'react';
import { Lock, Unlock, FileCheck2, RefreshCw, AlertTriangle, ShieldCheck, Flame, Zap, Wind, ArrowUp, Hammer } from 'lucide-react';
import { Card, StatBig } from '@keystone/ui';
import type { PermitRow, PermitType, PermitStatus } from '@keystone/domain/db/keystone';
import { fetchPermits } from '../../data/hsse.ts';

const P_TYPE: Record<PermitType, { label: string; icon: typeof Flame }> = {
  hot_work: { label: 'Travail à chaud', icon: Flame },
  confined_space: { label: 'Espace confiné', icon: Wind },
  electrical: { label: 'Électrique', icon: Zap },
  work_at_height: { label: 'Travail en hauteur', icon: ArrowUp },
  excavation: { label: 'Fouille', icon: Hammer },
  lifting: { label: 'Levage', icon: ArrowUp },
  energized: { label: 'Sous tension', icon: Zap },
  general: { label: 'Général', icon: FileCheck2 },
};
const P_STATUS: Record<PermitStatus, { label: string; color: string; bg: string }> = {
  draft: { label: 'Brouillon', color: 'var(--ks-ink-2)', bg: 'var(--ks-surface-3)' },
  requested: { label: 'Demandé', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  approved: { label: 'Approuvé', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  active: { label: 'Actif', color: '#2C6230', bg: 'var(--ks-low-100)' },
  suspended: { label: 'Suspendu', color: '#8A3A07', bg: 'var(--ks-high-100)' },
  closed: { label: 'Clôturé', color: 'var(--ks-ink-2)', bg: 'var(--ks-surface-3)' },
  cancelled: { label: 'Annulé', color: 'var(--ks-ink-3)', bg: 'var(--ks-surface-3)' },
};

export function Permits() {
  const [rows, setRows] = useState<PermitRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true); setErr(null);
    try { setRows(await fetchPermits()); }
    catch (x) { setErr(x instanceof Error ? x.message : String(x)); }
    finally { setLoading(false); }
  }
  useEffect(() => { load(); }, []);

  const active = rows?.filter((r) => r.status === 'active').length ?? 0;
  const isolated = rows?.filter((r) => r.requires_isolation && r.isolations_verified).length ?? 0;
  const unsafe = rows?.filter((r) => r.requires_isolation && !r.isolations_verified).length ?? 0;

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">HSSE · Maîtrise opérationnelle</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Permis &amp; consignation</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">ISO 14118 · interlock LOTO zéro-énergie imposé en base</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      <div className="kt-dash kt-dash--3 ks-reveal" style={{ marginBottom: 18 }}>
        <Card><StatBig label="Permis actifs" icon={<FileCheck2 size={15} />} accent="var(--ks-low)" value={active} sub="travaux autorisés" /></Card>
        <Card><StatBig label="Consignations vérifiées" icon={<Lock size={15} />} accent="var(--ks-low)" value={isolated} sub="zéro énergie confirmé" /></Card>
        <Card><StatBig label="Consignations non vérifiées" icon={<Unlock size={15} />} accent={unsafe ? 'var(--ks-critical)' : 'var(--ks-low)'} value={unsafe} sub="activation bloquée" /></Card>
      </div>

      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}
      {loading && !err && <Card><div className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Chargement live…</div></Card>}

      {rows && !loading && !err && (
        <Card pad={false} className="ks-reveal" style={{ animationDelay: '120ms' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Réf.</th><th>Type</th><th>Statut</th><th>Actif</th><th>Consignation (LOTO)</th><th>Validité</th></tr></thead>
              <tbody>
                {rows.map((p) => {
                  const T = P_TYPE[p.type]; const Icon = T.icon; const st = P_STATUS[p.status];
                  return (
                    <tr key={p.id}>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5, whiteSpace: 'nowrap' }}>{p.ref}</td>
                      <td><span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontWeight: 600 }}><Icon size={15} color="var(--ks-ink-2)" /> {T.label}</span></td>
                      <td><span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span></td>
                      <td>{p.asset_tag ? <span className="ks-mono" style={{ fontSize: 12 }}>{p.asset_tag}</span> : <span className="ks-faint">—</span>}</td>
                      <td>
                        {!p.requires_isolation ? (
                          <span className="ks-faint" style={{ fontSize: 12 }}>non requise</span>
                        ) : p.isolations_verified ? (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: 'var(--ks-low)', fontWeight: 600, fontSize: 12.5 }}>
                            <Lock size={13} /> Zéro énergie vérifié <span className="ks-faint ks-mono">({p.isolations})</span>
                          </span>
                        ) : (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: 'var(--ks-critical)', fontWeight: 600, fontSize: 12.5 }}>
                            <Unlock size={13} /> Non vérifié — activation bloquée
                          </span>
                        )}
                      </td>
                      <td><span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{p.valid_to ? new Date(p.valid_to).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—'}</span></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12 }} className="ks-faint">
            <ShieldCheck size={13} style={{ verticalAlign: -2 }} /> Garde imposée en base (`permit_activate`) : un permis ne devient <b>actif</b> que si toutes les consignations sont posées et <b>vérifiées zéro-énergie</b> (sinon <span className="ks-mono">ISOLATION_NOT_VERIFIED</span>). Un OT à risque ne démarre qu'avec un permis actif (<span className="ks-mono">PERMIT_REQUIRED</span>).
          </div>
        </Card>
      )}
    </div>
  );
}
