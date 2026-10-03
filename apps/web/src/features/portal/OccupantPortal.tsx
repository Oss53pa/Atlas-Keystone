import { useEffect, useState } from 'react';
import { QrCode, MapPin, Send, CheckCircle2, Search, Clock, AlertTriangle, Wrench } from 'lucide-react';
import type { TicketStatus } from '@keystone/domain/db/keystone';
import { qrContext, createPublicTicket, trackTicket, type QrContext, type TicketTrack } from '../../data/portal.ts';

const CATEGORIES = ['Climatisation', 'Propreté', 'Électricité', 'Plomberie', 'Ascenseur', 'Éclairage', 'Sûreté', 'Autre'];

const STATUS_LABEL: Record<TicketStatus, string> = {
  new: 'Reçu', triaged: 'En cours de tri', assigned: 'Pris en charge', in_progress: 'En cours de traitement',
  resolved: 'Résolu', closed: 'Clôturé', rejected: 'Rejeté', reopened: 'Rouvert',
};
const STEPS: TicketStatus[] = ['new', 'assigned', 'in_progress', 'resolved'];

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '28px 18px 48px', position: 'relative' }}>
      <span className="kt-aurora kt-aurora--a" style={{ top: '4%', right: '8%' }} aria-hidden />
      <div style={{ display: 'flex', alignItems: 'center', gap: 11, marginBottom: 22 }}>
        <span className="ks-rail__logo" style={{ width: 38, height: 38 }} aria-hidden>
          <svg width="19" height="19" viewBox="0 0 24 24" fill="none"><path d="M7 3h10l3 7-8 11-8-11 3-7Z" fill="currentColor" opacity=".9" /></svg>
        </span>
        <div>
          <div className="ks-brand" style={{ fontSize: 24, lineHeight: 1 }}>Atlas Keystone</div>
          <div className="ks-eyebrow" style={{ marginTop: 1 }}>Signalement occupant</div>
        </div>
      </div>
      <div className="ks-card ks-reveal" style={{ width: 'min(460px, 96vw)', padding: '26px 24px', boxShadow: 'var(--ks-shadow-2)' }}>
        {children}
      </div>
      <p className="ks-faint" style={{ fontSize: 11, marginTop: 18, textAlign: 'center', maxWidth: 360 }}>
        Aucun compte requis · service de l'exploitant · vos coordonnées ne servent qu'au suivi de la demande.
      </p>
    </div>
  );
}

export function OccupantPortal() {
  const params = new URLSearchParams(window.location.search);
  const suivi = params.get('suivi');
  const qr = params.get('qr') ?? '';
  return suivi ? <TrackView refCode={suivi} /> : <ReportView qr={qr} />;
}

function ReportView({ qr }: { qr: string }) {
  const [ctx, setCtx] = useState<QrContext | null>(null);
  const [category, setCategory] = useState('Climatisation');
  const [description, setDescription] = useState('');
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [ref, setRef] = useState<string | null>(null);

  useEffect(() => {
    if (qr) qrContext(qr).then(setCtx).catch(() => setCtx({ found: false }));
  }, [qr]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setErr(null);
    try {
      const r = await createPublicTicket({ qr, category, description, name });
      setRef(r);
    } catch (x) {
      setErr(x instanceof Error ? x.message : String(x));
    } finally {
      setBusy(false);
    }
  }

  if (ref) {
    return (
      <Shell>
        <div style={{ textAlign: 'center', padding: '8px 0' }}>
          <div style={{ width: 60, height: 60, borderRadius: 18, margin: '0 auto 16px', display: 'grid', placeItems: 'center', background: 'var(--ks-low-100)', color: 'var(--ks-low)' }}>
            <CheckCircle2 size={32} />
          </div>
          <h1 style={{ fontSize: 22, fontWeight: 700 }}>Demande envoyée</h1>
          <p className="ks-dim" style={{ fontSize: 14, marginTop: 8 }}>Notre équipe d'exploitation a été notifiée.</p>
          <div style={{ margin: '20px 0', padding: '14px', borderRadius: 'var(--ks-r-md)', background: 'var(--ks-surface-3)' }}>
            <div className="ks-eyebrow">Votre référence de suivi</div>
            <div className="ks-mono" style={{ fontSize: 22, fontWeight: 600, marginTop: 4 }}>{ref.replace(/"/g, '')}</div>
          </div>
          <a className="ks-btn ks-btn--primary" style={{ width: '100%' }} href={`?suivi=${encodeURIComponent(ref.replace(/"/g, ''))}`}>
            <Search size={16} /> Suivre ma demande
          </a>
        </div>
      </Shell>
    );
  }

  return (
    <Shell>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
        <QrCode size={18} color="var(--ks-amber-600)" />
        <h1 style={{ fontSize: 20, fontWeight: 700 }}>Signaler un problème</h1>
      </div>

      {qr && ctx?.found && (
        <div style={{ margin: '12px 0 18px', padding: '12px 14px', borderRadius: 'var(--ks-r-md)', background: 'var(--ks-amber-50)', border: '1px solid var(--ks-amber-100)' }}>
          <div style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--ks-amber-700)' }}>{ctx.asset_name ?? ctx.location_name}</div>
          <div className="ks-dim" style={{ fontSize: 12, marginTop: 2, display: 'flex', alignItems: 'center', gap: 5 }}>
            <MapPin size={12} /> {ctx.location_name}{ctx.site_name ? ` · ${ctx.site_name}` : ''}
          </div>
        </div>
      )}
      {qr && ctx && !ctx.found && (
        <div className="ks-dim" style={{ fontSize: 12.5, margin: '10px 0' }}>Code non reconnu — votre signalement sera quand même transmis si possible.</div>
      )}

      <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 8 }}>
        <div>
          <label className="ks-eyebrow" style={{ display: 'block', marginBottom: 7 }}>Type de problème</label>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {CATEGORIES.map((c) => (
              <button type="button" key={c} onClick={() => setCategory(c)}
                className="ks-pill" style={{ height: 32, cursor: 'pointer', border: '1px solid', borderColor: category === c ? 'var(--ks-amber-600)' : 'var(--ks-line-2)', background: category === c ? 'var(--ks-amber-100)' : 'var(--ks-surface)', color: category === c ? 'var(--ks-amber-700)' : 'var(--ks-ink-2)' }}>
                {c}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="ks-eyebrow" style={{ display: 'block', marginBottom: 7 }}>Description</label>
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} required rows={3}
            placeholder="Décrivez le problème en quelques mots…"
            style={{ width: '100%', padding: '11px 14px', border: '1px solid var(--ks-line-2)', borderRadius: 'var(--ks-r-md)', font: 'inherit', fontSize: 14, resize: 'vertical', outline: 'none', background: 'var(--ks-surface)' }} />
        </div>

        <label className="kt-field"><input value={name} onChange={(e) => setName(e.target.value)} placeholder="Votre nom / boutique (optionnel)" /></label>

        {err && <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--ks-critical)', fontSize: 12.5, background: 'var(--ks-critical-100)', padding: '8px 12px', borderRadius: 'var(--ks-r-sm)' }}><AlertTriangle size={15} /> {err}</div>}

        <button className="ks-btn ks-btn--primary" disabled={busy} style={{ width: '100%', height: 50, marginTop: 4 }}>
          {busy ? 'Envoi…' : <>Envoyer le signalement <Send size={16} /></>}
        </button>
      </form>
    </Shell>
  );
}

function TrackView({ refCode }: { refCode: string }) {
  const [tk, setTk] = useState<TicketTrack | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { trackTicket(refCode).then(setTk).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }, [refCode]);

  const stepIndex = tk?.status ? Math.max(0, STEPS.indexOf(tk.status === 'closed' ? 'resolved' : tk.status)) : 0;

  return (
    <Shell>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
        <Search size={18} color="var(--ks-amber-600)" />
        <h1 style={{ fontSize: 20, fontWeight: 700 }}>Suivi de demande</h1>
      </div>
      <div className="ks-mono ks-faint" style={{ fontSize: 13, marginBottom: 18 }}>{refCode}</div>

      {err && <div className="ks-dim" style={{ fontSize: 13 }}>{err}</div>}
      {tk && !tk.found && <div className="ks-dim" style={{ fontSize: 13.5 }}>Référence introuvable. Vérifiez votre code de suivi.</div>}

      {tk?.found && (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
            <span className="ks-wo-pill" style={{ background: tk.status === 'resolved' || tk.status === 'closed' ? 'var(--ks-low-100)' : 'var(--ks-amber-100)', color: tk.status === 'resolved' || tk.status === 'closed' ? '#2C6230' : 'var(--ks-amber-700)' }}>
              {tk.status ? STATUS_LABEL[tk.status] : '—'}
            </span>
            <span className="ks-pill">{tk.category}</span>
            {tk.has_work_order && <span className="ks-pill" style={{ color: 'var(--ks-info)' }}><Wrench size={12} /> intervention planifiée</span>}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
            {STEPS.map((s, i) => {
              const done = i <= stepIndex;
              return (
                <div key={s} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '9px 0' }}>
                  <span style={{ width: 24, height: 24, borderRadius: '50%', display: 'grid', placeItems: 'center', flex: 'none', background: done ? 'var(--ks-low)' : 'var(--ks-surface-3)', color: done ? '#fff' : 'var(--ks-ink-3)' }}>
                    {done ? <CheckCircle2 size={15} /> : <Clock size={13} />}
                  </span>
                  <span style={{ fontSize: 14, fontWeight: done ? 600 : 500, color: done ? 'var(--ks-ink)' : 'var(--ks-ink-3)' }}>{STATUS_LABEL[s]}</span>
                </div>
              );
            })}
          </div>

          <p className="ks-faint" style={{ fontSize: 12, marginTop: 16 }}>
            Demande reçue le {tk.created_at ? new Date(tk.created_at).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', hour: '2-digit', minute: '2-digit' }) : '—'}.
          </p>
        </>
      )}
    </Shell>
  );
}
