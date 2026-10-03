import { useState } from 'react';
import { Lock, Mail, ArrowRight, AlertCircle } from 'lucide-react';
import { signIn } from '../../lib/auth.ts';

export function Login() {
  // Pré-remplissage démo lu depuis .env.local (non versionné) — aucun identifiant en dur dans le dépôt
  const demoEmail = (import.meta.env.VITE_DEMO_EMAIL as string | undefined) ?? '';
  const [email, setEmail] = useState(demoEmail);
  const [password, setPassword] = useState((import.meta.env.VITE_DEMO_PASSWORD as string | undefined) ?? '');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setErr(null);
    try { await signIn(email.trim(), password); }
    catch (x) { setErr(x instanceof Error ? x.message : String(x)); setBusy(false); }
  }

  return (
    <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 24 }}>
      <span className="kt-aurora kt-aurora--a" style={{ top: '8%', right: '14%' }} aria-hidden />
      <span className="kt-aurora kt-aurora--b" style={{ bottom: '10%', left: '12%' }} aria-hidden />
      <div className="ks-card ks-reveal" style={{ width: 'min(420px, 94vw)', padding: '36px 34px', position: 'relative', boxShadow: 'var(--ks-shadow-3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 28 }}>
          <span className="ks-rail__logo" style={{ width: 40, height: 40 }} aria-hidden>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M7 3h10l3 7-8 11-8-11 3-7Z" fill="currentColor" opacity=".9" /></svg>
          </span>
          <div>
            <div className="ks-brand" style={{ fontSize: 26, lineHeight: 1 }}>Atlas Keystone</div>
            <div className="ks-eyebrow" style={{ marginTop: 2 }}>Facility Management · HSSE</div>
          </div>
        </div>

        <h1 style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-.02em' }}>Connexion</h1>
        <p className="ks-dim" style={{ fontSize: 13.5, marginTop: 6, marginBottom: 24 }}>
          Accès sécurisé · isolation par tenant (RLS Postgres).
        </p>

        <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <label className="kt-field">
            <Mail size={16} />
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="vous@exemple.com" autoComplete="username" required />
          </label>
          <label className="kt-field">
            <Lock size={16} />
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Mot de passe" autoComplete="current-password" required />
          </label>

          {err && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--ks-critical)', fontSize: 12.5, background: 'var(--ks-critical-100)', padding: '8px 12px', borderRadius: 'var(--ks-r-sm)' }}>
              <AlertCircle size={15} /> {err}
            </div>
          )}

          <button className="ks-btn ks-btn--primary" disabled={busy} style={{ marginTop: 6, width: '100%' }}>
            {busy ? 'Connexion…' : <>Se connecter <ArrowRight size={16} /></>}
          </button>
        </form>

        {demoEmail && (
          <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 20, textAlign: 'center', lineHeight: 1.5 }}>
            Démo : <span className="ks-mono">{demoEmail}</span> · les identifiants sont pré-remplis.
          </div>
        )}
      </div>
    </div>
  );
}
