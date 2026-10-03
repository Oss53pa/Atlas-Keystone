import { useEffect, useState } from 'react';
import { FileText, RefreshCw, Send, ShieldAlert, Wrench, ShieldCheck, Wallet, Sparkles, Ticket, Radar, CheckCircle2, AlertTriangle } from 'lucide-react';
import { Card, RingGauge } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { MonthlyReport } from '@keystone/domain/db/keystone';
import { fetchLatestReport, generateReport, publishReport } from '../../../data/report.ts';
import type { PanelProps } from '../shared.tsx';

const fcfa = (n: number) => format(money(Math.round(n), 'XOF'));
const num = (n: number | null | undefined, d = 0) => (n == null ? '—' : Number(n).toFixed(d));

function Section({ icon, title, children }: { icon: React.ReactNode; title: string; children: React.ReactNode }) {
  return (
    <Card className="ks-reveal">
      <div className="ks-card__title" style={{ fontSize: 13.5, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>{icon} {title}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>{children}</div>
    </Card>
  );
}
function Line({ k, v, accent }: { k: string; v: React.ReactNode; accent?: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 12, fontSize: 13 }}>
      <span className="ks-faint">{k}</span>
      <span className="ks-mono" style={{ fontWeight: 600, color: accent }}>{v}</span>
    </div>
  );
}

export function Report(_: PanelProps) {
  const [rep, setRep] = useState<MonthlyReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function load() { setLoading(true); fetchLatestReport().then((r) => { setRep(r); setLoading(false); }).catch((e) => { setErr(e instanceof Error ? e.message : String(e)); setLoading(false); }); }
  useEffect(load, []);

  async function regen() { setBusy('gen'); setErr(null); try { await generateReport(); load(); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); } }
  async function publish() { if (!rep) return; setBusy('pub'); setErr(null); try { await publishReport(rep.id); load(); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); } }

  if (loading) return <div className="ks-dim" style={{ padding: 40, textAlign: 'center' }}>Chargement du rapport…</div>;

  const p = rep?.payload;
  const published = rep?.status === 'published';

  return (
    <>
      <div className="kt-section-h" style={{ marginTop: 0 }}>
        <div>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}><FileText size={18} /> Rapport mensuel d'exploitation {rep && <span className="ks-mono ks-faint" style={{ fontWeight: 500 }}>· {rep.period}</span>}</h2>
          {rep && <div className="ks-faint" style={{ fontSize: 12, marginTop: 3 }}>Généré par l'agent Reporting le {new Date(rep.generated_at).toLocaleString('fr-FR', { day: '2-digit', month: 'long', hour: '2-digit', minute: '2-digit' })}</div>}
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          {rep && <span className="ks-wo-pill" style={published ? { color: '#2C6230', background: 'var(--ks-low-100)' } : { color: 'var(--ks-amber-700)', background: 'var(--ks-amber-100)' }}>{published ? 'Publié' : 'Brouillon'}</span>}
          <button className="ks-btn ks-btn--ghost ks-btn--sm" onClick={regen} disabled={busy === 'gen'}><RefreshCw size={14} /> {busy === 'gen' ? '…' : 'Régénérer'}</button>
          {rep && !published && <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={publish} disabled={busy === 'pub'}><Send size={14} /> {busy === 'pub' ? '…' : 'Publier'}</button>}
        </div>
      </div>

      {err && <Card style={{ marginBottom: 16 }}><div style={{ display: 'flex', gap: 8, color: 'var(--ks-critical)', fontSize: 13 }}><AlertTriangle size={16} /> {err}</div></Card>}

      {!rep && <Card><div style={{ textAlign: 'center', padding: 40 }}><FileText size={28} className="ks-faint" /><div className="ks-dim" style={{ marginTop: 10, fontSize: 14 }}>Aucun rapport. Lancez la génération.</div><button className="ks-btn ks-btn--primary" style={{ marginTop: 16 }} onClick={regen}>Générer le rapport mensuel</button></div></Card>}

      {p && (
        <>
          {/* Synthèse exécutive */}
          <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
            <Card><div style={{ display: 'flex', alignItems: 'center', gap: 14 }}><RingGauge value={p.maintenance.availability_pct} size={66} stroke={6} color="var(--ks-low)" /><div><div className="ks-stat__label">Disponibilité</div><div className="ks-faint" style={{ fontSize: 11.5 }}>parc critique</div></div></div></Card>
            <Card><div style={{ display: 'flex', alignItems: 'center', gap: 14 }}><RingGauge value={p.compliance.crp_conformity_pct} size={66} stroke={6} color={p.compliance.crp_conformity_pct >= 90 ? 'var(--ks-low)' : 'var(--ks-high)'} /><div><div className="ks-stat__label">Conformité CRP</div><div className="ks-faint" style={{ fontSize: 11.5 }}>{p.compliance.crp_overdue} en retard</div></div></div></Card>
            <Card><div style={{ display: 'flex', alignItems: 'center', gap: 14 }}><RingGauge value={p.maintenance.preventive_share_pct} size={66} stroke={6} color="var(--ks-amber)" /><div><div className="ks-stat__label">Préventif</div><div className="ks-faint" style={{ fontSize: 11.5 }}>{p.maintenance.wo_total} OT</div></div></div></Card>
            <Card><div style={{ display: 'flex', alignItems: 'center', gap: 14 }}><RingGauge value={p.softfm.realisation_pct} size={66} stroke={6} color="var(--ks-info)" /><div><div className="ks-stat__label">Soft FM</div><div className="ks-faint" style={{ fontSize: 11.5 }}>QC {p.softfm.qc_avg}/100</div></div></div></Card>
          </div>

          <div className="kt-dash kt-dash--4">
            <Section icon={<ShieldAlert size={15} color="var(--ks-critical)" />} title="Sécurité (HSSE)">
              <Line k="Accidents" v={p.hsse.accidents} accent={p.hsse.accidents ? 'var(--ks-critical)' : undefined} />
              <Line k="Presque-accidents" v={p.hsse.near_miss} />
              <Line k="Événements ouverts" v={p.hsse.events_open} />
              <Line k="CAPA ouvertes" v={p.hsse.capa_open} />
              <Line k="CAPA en retard" v={p.hsse.capa_overdue} accent={p.hsse.capa_overdue ? 'var(--ks-critical)' : undefined} />
            </Section>
            <Section icon={<Wrench size={15} color="var(--ks-amber-600)" />} title="Maintenance (EN 15341)">
              <Line k="MTBF" v={`${num(p.maintenance.mtbf_hours)} h`} />
              <Line k="MTTR" v={`${num(p.maintenance.mttr_hours, 2)} h`} />
              <Line k="Disponibilité" v={`${num(p.maintenance.availability_pct, 2)} %`} accent="var(--ks-low)" />
              <Line k="Respect SLA" v={`${num(p.maintenance.sla_compliance_pct, 1)} %`} />
              <Line k="Ordres de travail" v={p.maintenance.wo_total} />
            </Section>
            <Section icon={<ShieldCheck size={15} color="var(--ks-info)" />} title="Conformité réglementaire">
              <Line k="Contrôles suivis" v={p.compliance.crp_total} />
              <Line k="Taux de conformité" v={`${num(p.compliance.crp_conformity_pct, 1)} %`} accent={p.compliance.crp_conformity_pct >= 90 ? 'var(--ks-low)' : 'var(--ks-high)'} />
              <Line k="En dépassement" v={p.compliance.crp_overdue} accent={p.compliance.crp_overdue ? 'var(--ks-critical)' : undefined} />
            </Section>
            <Section icon={<Wallet size={15} color="var(--ks-low)" />} title="Budget">
              <Line k="OPEX disponible" v={fcfa(p.budget.opex_available)} accent="var(--ks-low)" />
              <Line k="CAPEX disponible" v={fcfa(p.budget.capex_available)} accent="var(--ks-low)" />
              <Line k="Payé prestataires" v={fcfa(p.payments.paid_total)} />
            </Section>
            <Section icon={<Sparkles size={15} color="var(--ks-info)" />} title="Soft FM">
              <Line k="Taux de réalisation" v={`${num(p.softfm.realisation_pct, 1)} %`} />
              <Line k="Score qualité moyen" v={`${p.softfm.qc_avg}/100`} />
              <Line k="Prestations manquées" v={p.softfm.missed} accent={p.softfm.missed ? 'var(--ks-high)' : undefined} />
            </Section>
            <Section icon={<Ticket size={15} color="var(--ks-info)" />} title="Tickets & occupants">
              <Line k="Tickets" v={p.tickets.total} />
              <Line k="Ouverts" v={p.tickets.open} />
              <Line k="Satisfaction" v={p.tickets.satisfaction != null ? `${p.tickets.satisfaction}/5` : '—'} accent="var(--ks-amber-700)" />
            </Section>
            <Section icon={<Radar size={15} color="var(--ks-amber-600)" />} title="Maintenance prédictive">
              <Line k="Prédictions ouvertes" v={p.predictive.open_predictions} accent={p.predictive.open_predictions ? 'var(--ks-amber-700)' : undefined} />
              <div className="ks-faint" style={{ fontSize: 11.5, lineHeight: 1.5 }}>Dérives de signature détectées par l'agent Sentinelle (PROPH3T).</div>
            </Section>
            <Card className="ks-reveal" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', background: 'var(--ks-amber-50)', borderColor: 'var(--ks-amber-100)' }}>
              <CheckCircle2 size={22} color="var(--ks-amber-700)" />
              <div style={{ fontSize: 12.5, fontWeight: 600, marginTop: 8, color: 'var(--ks-amber-700)' }}>Garde-fou §11</div>
              <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 4, lineHeight: 1.5 }}>Brouillon généré automatiquement. La <b>diffusion</b> exige une validation humaine (bouton Publier).</div>
            </Card>
          </div>
        </>
      )}
    </>
  );
}
