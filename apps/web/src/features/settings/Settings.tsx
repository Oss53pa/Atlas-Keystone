import { useEffect, useState } from 'react';
import { Building, GitBranch, Scale, Save, CheckCircle2, AlertTriangle, X, ChevronRight } from 'lucide-react';
import { Card, TabBar } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { CompanyProfile, ApprovalThreshold } from '@keystone/domain/db/keystone';
import { fetchCompany, saveCompany, fetchThresholds, saveThreshold, fetchWeights, saveWeights } from '../../data/documents.ts';

const fcfa = (n: number) => format(money(Math.round(n), 'XOF'));
const CRIT: { key: string; label: string }[] = [
  { key: 'quality', label: 'Qualité d’exécution' }, { key: 'timing', label: 'Respect des délais' }, { key: 'reliability', label: 'Fiabilité' },
  { key: 'cost', label: 'Maîtrise des coûts' }, { key: 'communication', label: 'Communication & reporting' }, { key: 'innovation', label: 'Force de proposition' },
];
const EMPTY: CompanyProfile = {
  legal_name: '', trade_name: null, legal_form: null, rccm: null, ncc: null, address: null, city: null, country: 'Côte d’Ivoire', phone: null,
  email: null, website: null, bank_name: null, bank_account: null, payment_terms_days: 30, purchase_terms: null, document_footer: null,
};

export function Settings() {
  const [tab, setTab] = useState('company');
  const [toast, setToast] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const ok = (m: string) => { setToast(m); setTimeout(() => setToast(null), 3500); };
  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Système · Paramétrage client</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Paramètres</h1>
          <div className="kt-hero__sub"><span className="ks-faint">identité légale des documents · circuits d’approbation · pondérations d’évaluation — par client, sans code</span></div>
        </div>
      </header>
      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}><AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span><button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button></div>}
      <div style={{ marginBottom: 16 }}>
        <TabBar tabs={[
          { id: 'company', label: 'Société & documents', icon: <Building size={15} /> },
          { id: 'approvals', label: 'Circuit d’approbation des achats', icon: <GitBranch size={15} /> },
          { id: 'weights', label: 'Évaluation prestataires', icon: <Scale size={15} /> },
        ]} active={tab} onChange={setTab} />
      </div>
      {tab === 'company' && <CompanyTab onOk={ok} onErr={setErr} />}
      {tab === 'approvals' && <ApprovalsTab onOk={ok} onErr={setErr} />}
      {tab === 'weights' && <WeightsTab onOk={ok} onErr={setErr} />}
    </div>
  );
}

function Field({ label, value, onChange, mono, wide }: { label: string; value: string | null; onChange: (v: string) => void; mono?: boolean; wide?: boolean }) {
  return (
    <label className="kx-lbl" style={wide ? { gridColumn: '1 / -1' } : undefined}>{label}
      <input className={`kx-in${mono ? ' ks-mono' : ''}`} value={value ?? ''} onChange={(e) => onChange(e.target.value)} />
    </label>
  );
}

function CompanyTab({ onOk, onErr }: { onOk: (m: string) => void; onErr: (m: string) => void }) {
  const [c, setC] = useState<CompanyProfile | null>(null);
  useEffect(() => { fetchCompany().then((x) => setC(x ?? EMPTY)).catch((e) => onErr(String(e))); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  if (!c) return null;
  const set = (k: keyof CompanyProfile) => (v: string) => setC({ ...c, [k]: v || null });
  return (
    <div className="kt-dash kt-dash--21 ks-reveal">
      <Card>
        <div className="kt-cardtitle">Identité légale</div>
        <div className="kt-cardsub">imprimée en en-tête des bons de commande, fiches d’intervention et quittances</div>
        <div className="kd-form">
          <Field label="Raison sociale" value={c.legal_name} onChange={(v) => setC({ ...c, legal_name: v })} />
          <Field label="Nom commercial" value={c.trade_name} onChange={set('trade_name')} />
          <Field label="Forme juridique" value={c.legal_form} onChange={set('legal_form')} />
          <Field label="RCCM" value={c.rccm} onChange={set('rccm')} mono />
          <Field label="N° compte contribuable (NCC)" value={c.ncc} onChange={set('ncc')} mono />
          <Field label="Ville" value={c.city} onChange={set('city')} />
          <Field label="Adresse" value={c.address} onChange={set('address')} wide />
          <Field label="Téléphone" value={c.phone} onChange={set('phone')} />
          <Field label="Email" value={c.email} onChange={set('email')} />
          <Field label="Banque" value={c.bank_name} onChange={set('bank_name')} />
          <Field label="RIB / IBAN" value={c.bank_account} onChange={set('bank_account')} mono />
        </div>
      </Card>
      <Card>
        <div className="kt-cardtitle">Conditions & pied de page</div>
        <label className="kx-lbl" style={{ marginTop: 12 }}>Délai de paiement fournisseurs (jours)
          <input className="kx-in" type="number" min={0} value={c.payment_terms_days} onChange={(e) => setC({ ...c, payment_terms_days: Number(e.target.value) })} />
        </label>
        <label className="kx-lbl" style={{ marginTop: 10 }}>Conditions générales d’achat (sur les BC)
          <textarea className="kt-field ki-input" rows={6} value={c.purchase_terms ?? ''} onChange={(e) => setC({ ...c, purchase_terms: e.target.value || null })} />
        </label>
        <div className="kd-form" style={{ marginTop: 10 }}>
          <label className="kx-lbl">Tolérance prix facture / BC (%)
            <input className="kx-in ks-mono" type="number" min={0} max={20} step={0.5} value={c.match_price_tolerance_pct ?? 2}
              onChange={(e) => setC({ ...c, match_price_tolerance_pct: Number(e.target.value) })} />
          </label>
          <label className="kx-lbl">Tolérance écart global (FCFA HT)
            <input className="kx-in ks-mono" type="number" min={0} step={1000} value={c.match_amount_tolerance ?? 10000}
              onChange={(e) => setC({ ...c, match_amount_tolerance: Number(e.target.value) })} />
          </label>
        </div>
        <label className="kx-lbl" style={{ marginTop: 10 }}>Pied de page des documents
          <input className="kx-in" value={c.document_footer ?? ''} onChange={(e) => setC({ ...c, document_footer: e.target.value || null })} />
        </label>
        <button className="ks-btn ks-btn--primary kx-wide" disabled={c.legal_name.trim().length < 2}
          onClick={() => saveCompany(c).then(() => onOk('Identité société enregistrée')).catch((e) => onErr(String(e)))}><Save size={15} /> Enregistrer</button>
      </Card>
    </div>
  );
}

function ApprovalsTab({ onOk, onErr }: { onOk: (m: string) => void; onErr: (m: string) => void }) {
  const [t, setT] = useState<ApprovalThreshold[] | null>(null);
  useEffect(() => { fetchThresholds().then(setT).catch((e) => onErr(String(e))); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  if (!t) return null;
  const b = t.find((x) => x.step === 'budget'); const d = t.find((x) => x.step === 'direction');
  const upd = (step: 'budget' | 'direction', patch: Partial<ApprovalThreshold>) => setT(t.map((x) => (x.step === step ? { ...x, ...patch } : x)));
  async function save() {
    try {
      // ordre d'enregistrement : on évite un état transitoire « direction ≤ budget »
      const ordered = (d && b && d.min_amount > b.min_amount && b.min_amount > 0) ? [d, b] : [b, d];
      for (const x of ordered) if (x) await saveThreshold(x.step, x.min_amount, x.approver_label);
      onOk('Circuit d’approbation enregistré — s’applique aux nouvelles validations');
    } catch (e) { onErr(e instanceof Error ? e.message : String(e)); }
  }
  return (
    <div className="kt-dash kt-dash--21 ks-reveal">
      <Card>
        <div className="kt-cardtitle">Paliers des demandes d’achat</div>
        <div className="kt-cardsub">montant total HT de la DA, en FCFA</div>
        <div className="kp-tiers">
          <div className="kp-tier"><div className="kp-tier__lvl">1</div><div><b>Validation technique</b><div className="ks-faint" style={{ fontSize: 12 }}>toujours requise</div></div></div>
          <ChevronRight size={16} className="ks-faint" />
          <div className="kp-tier">
            <div className="kp-tier__lvl">2</div>
            <div style={{ flex: 1 }}>
              <input className="kx-in" style={{ width: '100%' }} value={b?.approver_label ?? ''} onChange={(e) => upd('budget', { approver_label: e.target.value })} aria-label="Valideur palier 2" />
              <label className="kx-lbl" style={{ marginTop: 6 }}>à partir de<input className="kx-in ks-mono" type="number" min={0} step={50000} value={b?.min_amount ?? 0} onChange={(e) => upd('budget', { min_amount: Number(e.target.value) })} /></label>
            </div>
          </div>
          <ChevronRight size={16} className="ks-faint" />
          <div className="kp-tier">
            <div className="kp-tier__lvl">3</div>
            <div style={{ flex: 1 }}>
              <input className="kx-in" style={{ width: '100%' }} value={d?.approver_label ?? ''} onChange={(e) => upd('direction', { approver_label: e.target.value })} aria-label="Valideur palier 3" />
              <label className="kx-lbl" style={{ marginTop: 6 }}>à partir de<input className="kx-in ks-mono" type="number" min={0} step={100000} value={d?.min_amount ?? 0} onChange={(e) => upd('direction', { min_amount: Number(e.target.value) })} /></label>
            </div>
          </div>
        </div>
        <button className="ks-btn ks-btn--primary kx-wide" onClick={() => void save()}><Save size={15} /> Enregistrer le circuit</button>
      </Card>
      <Card>
        <div className="kt-cardtitle">Ce que ça donne</div>
        <div className="kt-cardsub">exemples de demandes d’achat</div>
        {[150000, 900000, 3200000, 12000000].map((amt) => {
          const lvl = 1 + (b && amt >= b.min_amount ? 1 : 0) + (d && amt >= d.min_amount ? 1 : 0);
          return (
            <div key={amt} className="kv-line"><span className="ks-mono">{fcfa(amt)}</span>
              <span style={{ fontSize: 12.5 }}>{['Technique', b?.approver_label ?? 'Budget', d?.approver_label ?? 'Direction'].slice(0, lvl).join(' → ')}</span></div>
          );
        })}
        <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 10, lineHeight: 1.5 }}>Le contrôle budgétaire (blocage en cas de dépassement) et la séparation des tâches (le demandeur ne valide jamais sa propre DA) restent actifs quels que soient les paliers.</div>
      </Card>
    </div>
  );
}

function WeightsTab({ onOk, onErr }: { onOk: (m: string) => void; onErr: (m: string) => void }) {
  const [w, setW] = useState<Record<string, number> | null>(null);
  useEffect(() => { fetchWeights().then(setW).catch((e) => onErr(String(e))); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  if (!w) return null;
  const total = Math.round(Object.values(w).reduce((s, v) => s + v, 0) * 100);
  return (
    <Card className="ks-reveal" style={{ maxWidth: 640 }}>
      <div className="kt-cardtitle">Pondération de la grille qualitative</div>
      <div className="kt-cardsub">la note globale d’un prestataire = 60 % SLA mesurés + 40 % de cette grille pondérée</div>
      {CRIT.map((c) => (
        <div key={c.key} className="kv-crit" style={{ padding: '10px 0' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}><label htmlFor={`w-${c.key}`} style={{ fontWeight: 600 }}>{c.label}</label><b className="ks-mono">{Math.round((w[c.key] ?? 0) * 100)} %</b></div>
          <input id={`w-${c.key}`} type="range" min={0} max={60} step={5} className="kv-range" style={{ ['--v' as string]: `${((w[c.key] ?? 0) * 100 / 60) * 100}%` }}
            value={Math.round((w[c.key] ?? 0) * 100)} onChange={(e) => setW({ ...w, [c.key]: Number(e.target.value) / 100 })} />
        </div>
      ))}
      <div className="kv-line kv-line--total"><span>Total</span><b className="ks-mono" style={{ color: total === 100 ? 'var(--ks-low)' : 'var(--ks-critical)' }}>{total} %</b></div>
      <button className="ks-btn ks-btn--primary kx-wide" disabled={total !== 100} onClick={() => saveWeights(w).then(() => onOk('Pondérations enregistrées — les notes sont recalculées')).catch((e) => onErr(String(e)))}>
        <Save size={15} /> {total === 100 ? 'Enregistrer' : `Ajustez pour atteindre 100 % (${total} %)`}
      </button>
    </Card>
  );
}
