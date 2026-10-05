import { useEffect, useRef, useState } from 'react';
import { ShieldCheck, ArrowRight, AlertCircle, LogOut } from 'lucide-react';
import { verifyLogin } from '../../lib/mfa.ts';
import { signOut } from '../../lib/auth.ts';

/** Second facteur à la connexion : demandé dès que le compte possède un facteur TOTP vérifié. */
export function MfaChallenge({ email, onDone }: { email: string; onDone: () => void }) {
  const [code, setCode] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => { ref.current?.focus(); }, []);

  async function submit(e?: React.FormEvent) {
    e?.preventDefault();
    if (code.length !== 6) return;
    setBusy(true); setErr(null);
    try { await verifyLogin(code); onDone(); }
    catch (x) {
      const m = x instanceof Error ? x.message : String(x);
      setErr(/invalid|expired/i.test(m) ? 'Code invalide ou expiré — saisissez le code affiché actuellement.' : m);
      setCode(''); setBusy(false); ref.current?.focus();
    }
  }
  useEffect(() => { if (code.length === 6 && !busy) void submit(); }, [code]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 24 }}>
      <span className="kt-aurora kt-aurora--a" style={{ top: '8%', right: '14%' }} aria-hidden />
      <div className="ks-card ks-reveal" style={{ width: 'min(420px, 94vw)', padding: '36px 34px', position: 'relative', boxShadow: 'var(--ks-shadow-3)' }}>
        <div className="km-badge"><ShieldCheck size={22} /></div>
        <h1 style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-.02em', marginTop: 18 }}>Double authentification</h1>
        <p className="ks-dim" style={{ fontSize: 13.5, marginTop: 6, marginBottom: 22, lineHeight: 1.5 }}>
          Saisissez le code à 6 chiffres affiché par votre application d’authentification pour <b>{email}</b>.
        </p>
        <form onSubmit={submit}>
          <input ref={ref} className="km-code ks-mono" inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={code} aria-label="Code à 6 chiffres"
            onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))} placeholder="••••••" disabled={busy} />
          {err && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--ks-critical)', fontSize: 12.5, background: 'var(--ks-critical-100)', padding: '8px 12px', borderRadius: 'var(--ks-r-sm)', marginTop: 12 }}>
              <AlertCircle size={15} /> {err}
            </div>
          )}
          <button className="ks-btn ks-btn--primary" disabled={busy || code.length !== 6} style={{ marginTop: 16, width: '100%' }}>
            {busy ? 'Vérification…' : <>Valider <ArrowRight size={16} /></>}
          </button>
        </form>
        <button className="ks-btn ks-btn--quiet" style={{ marginTop: 10, width: '100%' }} onClick={() => void signOut()}><LogOut size={15} /> Changer de compte</button>
      </div>
    </div>
  );
}
