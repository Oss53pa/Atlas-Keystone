import { useEffect, useMemo, useState } from 'react';
import { Award, CalendarClock, Scale, X, Check, Gavel, Repeat } from 'lucide-react';
import { Card, RingGauge } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { ContractorScorecard, SlaMeasure, EvalCriterion } from '@keystone/domain/db/keystone';
import { fetchScorecards, fetchSlaMeasures, submitEvaluation } from '../../data/contractors.ts';

const fcfa = (n: number) => format(money(n, 'XOF'));
const GRADE: Record<string, { color: string; bg: string }> = {
  A: { color: '#2C6230', bg: 'var(--ks-low-100)' }, B: { color: '#0F6E56', bg: '#E1F5EE' },
  C: { color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' }, D: { color: '#8E1E22', bg: 'var(--ks-critical-100)' },
  '—': { color: 'var(--ks-ink-3)', bg: 'var(--ks-surface-3)' },
};
/** Même pondération que keystone.qualitative_score(). */
const CRITERIA: { key: EvalCriterion; label: string; w: number }[] = [
  { key: 'quality', label: 'Qualité d’exécution', w: 0.25 }, { key: 'timing', label: 'Respect des délais', w: 0.2 },
  { key: 'reliability', label: 'Fiabilité', w: 0.2 }, { key: 'cost', label: 'Maîtrise des coûts', w: 0.15 },
  { key: 'communication', label: 'Communication & reporting', w: 0.1 }, { key: 'innovation', label: 'Force de proposition', w: 0.1 },
];
const scoreColor = (s: number | null) => (s == null ? 'var(--ks-ink-3)' : s >= 80 ? 'var(--ks-low)' : s >= 60 ? 'var(--ks-amber)' : 'var(--ks-critical)');

export function ContractorPerformance({ onToast }: { onToast: (m: string) => void }) {
  const [cards, setCards] = useState<ContractorScorecard[] | null>(null);
  const [slas, setSlas] = useState<SlaMeasure[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [evalFor, setEvalFor] = useState<ContractorScorecard | null>(null);

  function load() {
    fetchScorecards().then(setCards).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchSlaMeasures().then(setSlas).catch(() => {});
  }
  useEffect(load, []);

  return (
    <div className="ks-reveal">
      {err && <div className="ks-mono ks-faint" style={{ fontSize: 12, marginBottom: 12 }}>{err}</div>}
      <div className="kv-cards">
        {(cards ?? []).map((c) => {
          const g = GRADE[c.grade];
          const mine = slas.filter((s) => s.contractor_id === c.contractor_id);
          return (
            <Card key={c.contractor_id}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 14, alignItems: 'flex-start' }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: 16 }}>{c.contractor}</div>
                  <div className="ks-faint" style={{ fontSize: 12.5, marginTop: 2 }}>{c.scope ?? '—'}</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <RingGauge value={c.global_score ?? 0} size={60} stroke={6} color={scoreColor(c.global_score)} label={c.global_score != null ? String(Math.round(c.global_score)) : '—'} />
                  <span className="kv-grade" style={{ color: g.color, background: g.bg }}>{c.grade}</span>
                </div>
              </div>

              <div className="kv-split">
                <div><span className="ks-faint">SLA mesurés (60 %)</span><b className="ks-mono" style={{ color: scoreColor(c.sla_score) }}>{c.sla_score ?? '—'}</b></div>
                <div><span className="ks-faint">Grille qualitative (40 %)</span><b className="ks-mono" style={{ color: scoreColor(c.qualitative) }}>{c.qualitative ?? '—'}</b></div>
                <div><span className="ks-faint">SLA tenus</span><b className="ks-mono">{c.sla_compliant}/{c.sla_count}</b></div>
              </div>

              {mine.map((s) => (
                <div key={s.sla_id} className="kv-sla">
                  <span className={`kv-sla__dot${s.compliant === false ? ' kv-sla__dot--ko' : s.compliant ? ' kv-sla__dot--ok' : ''}`} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>{s.label}</div>
                    <div className="ks-faint" style={{ fontSize: 11.5 }}>{s.samples} OT mesurés · poids {s.weight}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div className="ks-mono" style={{ fontSize: 13, fontWeight: 600, color: s.compliant === false ? 'var(--ks-critical)' : undefined }}>
                      {s.achieved != null ? `${s.achieved} ${s.unit}` : '—'}
                    </div>
                    <div className="ks-mono ks-faint" style={{ fontSize: 11 }}>cible {s.lower_is_better ? '≤' : '≥'} {s.target} {s.unit}</div>
                  </div>
                </div>
              ))}

              <div className="kv-foot">
                {c.penalty_raw > 0 ? (
                  <span style={{ color: 'var(--ks-critical)', fontSize: 12.5, display: 'inline-flex', gap: 6, alignItems: 'center' }}>
                    <Gavel size={13} /> Pénalités {fcfa(c.penalty)}
                    {c.penalty < c.penalty_raw && <span className="ks-faint">(plafond atteint, brut {fcfa(c.penalty_raw)})</span>}
                  </span>
                ) : <span className="ks-faint" style={{ fontSize: 12.5 }}>Aucune pénalité sur 90 j</span>}
                {c.renewal_due && (
                  <span className="ks-risk ks-risk--high" style={{ display: 'inline-flex', gap: 4, alignItems: 'center' }}>
                    {c.auto_renewal ? <Repeat size={11} /> : <CalendarClock size={11} />} {c.auto_renewal ? 'Reconduction tacite' : 'Fin de contrat'} dans {c.days_to_end} j
                  </span>
                )}
                <button className="ks-btn ks-btn--ghost ks-btn--sm" style={{ marginLeft: 'auto' }} onClick={() => setEvalFor(c)}><Award size={13} /> Évaluer le mois</button>
              </div>
            </Card>
          );
        })}
        {cards && cards.length === 0 && <Card><div className="ks-dim" style={{ textAlign: 'center', padding: 24 }}>Aucun prestataire sous contrat actif.</div></Card>}
      </div>
      <div className="ks-faint" style={{ fontSize: 12, marginTop: 12, lineHeight: 1.6 }}>
        <Scale size={12} style={{ verticalAlign: -1 }} /> SLA mesurés automatiquement sur les OT du prestataire (90 j). Les pénalités sont plafonnées par contrat (% du montant mensuel).
        Note : A ≥ 90 · B ≥ 80 · C ≥ 60 · D en dessous.
      </div>

      {evalFor && (
        <EvalDrawer c={evalFor} onClose={() => setEvalFor(null)} onDone={(q) => { setEvalFor(null); onToast(`Évaluation enregistrée · grille qualitative ${q}/100`); load(); }} />
      )}
    </div>
  );
}

function EvalDrawer({ c, onClose, onDone }: { c: ContractorScorecard; onClose: () => void; onDone: (q: number) => void }) {
  const [sc, setSc] = useState<Record<EvalCriterion, number>>({ quality: 75, timing: 75, communication: 75, innovation: 60, cost: 75, reliability: 75 });
  const [comment, setComment] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const q = useMemo(() => Math.round(CRITERIA.reduce((s, k) => s + k.w * sc[k.key], 0) * 10) / 10, [sc]);
  const global = c.sla_score != null ? Math.round((0.6 * c.sla_score + 0.4 * q) * 10) / 10 : q;
  async function go() {
    setBusy(true); setErr(null);
    try { const r = await submitEvaluation(c.contractor_id, sc, comment || undefined); onDone(Number(r.qualitative)); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }
  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={`Évaluer ${c.contractor}`}>
        <div className="ka-drawer__head">
          <div>
            <div className="ks-eyebrow">Évaluation mensuelle</div>
            <h2 style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 0' }}>{c.contractor}</h2>
          </div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>
        <div className="ka-drawer__health">
          <RingGauge value={global} size={80} stroke={7} color={scoreColor(global)} label={String(Math.round(global))} />
          <div style={{ fontSize: 13, lineHeight: 1.6 }}>
            <div>Grille pondérée : <b className="ks-mono">{q}</b></div>
            <div>SLA mesurés : <b className="ks-mono">{c.sla_score ?? '—'}</b></div>
            <div className="ks-faint" style={{ fontSize: 11.5 }}>global = 60 % SLA + 40 % grille</div>
          </div>
        </div>
        {CRITERIA.map((k) => (
          <div key={k.key} className="kv-crit">
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}>
              <label htmlFor={`c-${k.key}`} style={{ fontWeight: 600 }}>{k.label} <span className="ks-faint" style={{ fontWeight: 400 }}>· {Math.round(k.w * 100)} %</span></label>
              <b className="ks-mono" style={{ color: scoreColor(sc[k.key]) }}>{sc[k.key]}</b>
            </div>
            <input id={`c-${k.key}`} type="range" min={0} max={100} step={1} value={sc[k.key]} className="kv-range"
              style={{ ['--v' as string]: `${sc[k.key]}%` }} onChange={(e) => setSc((s) => ({ ...s, [k.key]: Number(e.target.value) }))} />
          </div>
        ))}
        <textarea className="kt-field ki-input" rows={3} style={{ width: '100%', marginTop: 8 }} placeholder="Commentaire (facultatif)" value={comment} onChange={(e) => setComment(e.target.value)} />
        {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12.5, marginTop: 10 }}>{err}</div>}
        <button className="ks-btn ks-btn--primary" style={{ width: '100%', justifyContent: 'center', marginTop: 16 }} disabled={busy} onClick={go}>
          <Check size={15} /> {busy ? '…' : 'Enregistrer l’évaluation'}
        </button>
      </aside>
    </div>
  );
}
