import { useCallback, useEffect, useState } from 'react';
import { Bot, Zap, ShieldAlert, Play, AlertTriangle, ClipboardList, ShieldCheck, BadgeCheck, Radar } from 'lucide-react';
import { Card, StatBig } from '@keystone/ui';
import type { AgentAction, AgentDecision } from '@keystone/domain/db/keystone';
import { fetchAgentJournal, runAgents } from '../../data/agents.ts';
import { supabase } from '../../lib/supabase.ts';

const AGENT: Record<string, { label: string; icon: typeof Bot }> = {
  relanceur_capa: { label: 'Relanceur CAPA', icon: ClipboardList },
  echeancier_crp: { label: 'Échéancier CRP', icon: ShieldCheck },
  habilitations: { label: 'Habilitations', icon: BadgeCheck },
  sentinelle: { label: 'Sentinelle', icon: Radar },
};
const DECISION: Record<AgentDecision, { label: string; color: string; bg: string }> = {
  auto: { label: 'Auto', color: '#2C6230', bg: 'var(--ks-low-100)' },
  proposed: { label: 'Proposé', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  escalated: { label: 'Escaladé', color: '#8E1E22', bg: 'var(--ks-critical-100)' },
};
const ACTION_LABEL: Record<string, string> = {
  escalade_retard: 'Escalade retard', relance_echeance: 'Relance échéance',
  controle_en_retard: 'Contrôle en retard', echeance_proche: 'Échéance proche',
  habilitation_expiree: 'Habilitation expirée', expiration_proche: 'Expiration proche',
};
const ago = (s: string) => {
  const m = Math.round((Date.now() - new Date(s).getTime()) / 60000);
  return m < 1 ? "à l'instant" : m < 60 ? `il y a ${m} min` : `il y a ${Math.round(m / 60)} h`;
};

export function Agents() {
  const [rows, setRows] = useState<AgentAction[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const load = useCallback(() => { fetchAgentJournal().then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }, []);
  useEffect(() => { load(); }, [load]);
  useEffect(() => {
    const sb = supabase; if (!sb) return;
    const ch = sb.channel('agents-live').on('postgres_changes', { event: '*', schema: 'keystone', table: 'agent_actions' }, () => load());
    ch.subscribe();
    return () => { void sb.removeChannel(ch); };
  }, [load]);

  async function run() {
    setBusy(true); setErr(null);
    try { const r = await runAgents(); setToast(`Agents exécutés · ${r.relanceur_capa + r.echeancier_crp + r.habilitations} actions`); load(); setTimeout(() => setToast(null), 4000); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }

  const list = rows ?? [];
  const escal = list.filter((a) => a.requires_human).length;

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Intelligence · Automatisation</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Agents autonomes</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE</span>
            <span className="ks-faint">modèle ASVC · supervision humaine unique · pg_cron quotidien (§11)</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--primary" onClick={run} disabled={busy} style={{ alignSelf: 'end' }}>
          {busy ? 'Exécution…' : <><Play size={15} /> Lancer les agents</>}
        </button>
      </header>

      {toast && <div style={{ marginBottom: 14, padding: '11px 16px', borderRadius: 'var(--ks-r-md)', background: 'var(--ks-low-100)', color: '#2C6230', fontSize: 13.5, display: 'flex', alignItems: 'center', gap: 8 }}><Bot size={16} /> {toast}</div>}
      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      <div className="kt-dash kt-dash--3 ks-reveal" style={{ marginBottom: 18 }}>
        <Card><StatBig label="Actions journalisées" icon={<Zap size={15} />} value={list.length} sub="50 dernières" /></Card>
        <Card><StatBig label="Escalades à arbitrer" icon={<ShieldAlert size={15} />} accent={escal ? 'var(--ks-critical)' : 'var(--ks-low)'} value={escal} sub="décision humaine requise" /></Card>
        <Card><StatBig label="Agents actifs" icon={<Bot size={15} />} accent="var(--ks-info)" value={3} sub="Relanceur · Échéancier · Habilitations" /></Card>
      </div>

      <div className="kt-section-h"><h2>Journal des agents</h2><span className="kt-count ks-sync"><span className="ks-sync__dot" /> temps réel</span></div>
      {rows && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Agent</th><th>Action</th><th>Cible</th><th>Décision</th><th>Supervision</th><th>Quand</th></tr></thead>
              <tbody>
                {list.map((a) => {
                  const A = AGENT[a.agent] ?? { label: a.agent, icon: Bot }; const Ai = A.icon; const d = DECISION[a.decision];
                  return (
                    <tr key={a.id}>
                      <td><span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontWeight: 600 }}><Ai size={15} color="var(--ks-ink-2)" /> {A.label}</span></td>
                      <td style={{ fontSize: 12.5 }}>{ACTION_LABEL[a.action_type] ?? a.action_type}</td>
                      <td style={{ fontSize: 12.5, maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{a.target_label}</td>
                      <td><span className="ks-wo-pill" style={{ color: d.color, background: d.bg }}>{d.label}</span></td>
                      <td>{a.requires_human ? <span className="ks-risk ks-risk--high">à arbitrer</span> : <span className="ks-faint" style={{ fontSize: 12 }}>—</span>}</td>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5, whiteSpace: 'nowrap' }}>{ago(a.created_at)}</td>
                    </tr>
                  );
                })}
                {list.length === 0 && <tr><td colSpan={6} className="ks-dim" style={{ textAlign: 'center', padding: 36 }}>Aucune action. Lancez les agents pour les voir travailler.</td></tr>}
              </tbody>
            </table>
          </div>
          <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12 }} className="ks-faint">
            <ShieldCheck size={13} style={{ verticalAlign: -2 }} /> Garde-fous §11 : aucun agent ne supprime, ne paie, ne publie ni ne modifie de permissions sans co-validation. Liste blanche d'actions, budget d'actions/heure, kill-switch par tenant. Les actions <b>escaladées</b> exigent une décision humaine.
          </div>
        </Card>
      )}
    </div>
  );
}
