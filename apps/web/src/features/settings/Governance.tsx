import { useEffect, useMemo, useState } from 'react';
import {
  ShieldCheck, Smartphone, Trash2, Check, KeyRound, Search, Download, UserX, FileJson, Plus, Clock, BookOpen, FileSpreadsheet, AlertTriangle, Info, X,
} from 'lucide-react';
import { Card } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import { useSession } from '../../lib/auth.ts';
import { listTotp, enrollTotp, verifyTotp, unenrollTotp, useAal, type TotpFactor } from '../../lib/mfa.ts';
import {
  fetchMfaPolicy, saveMfaPolicy, searchSubjects, exportSubject, anonymizeSubject, myData, fetchPrivacyRequests, createPrivacyRequest, closePrivacyRequest,
  fetchPlan, savePlanRow, fetchEntries, fetchJournalSummary, downloadFile,
  type Subject, type PrivacyRequest, type PlanRow, type JournalSummary,
} from '../../data/governance.ts';

type Notify = { onOk: (m: string) => void; onErr: (m: string) => void };
const msg = (e: unknown) => (e instanceof Error ? e.message : String(e));
const fcfa = (n: number) => format(money(Math.round(n), 'XOF'));
const today = () => new Date().toISOString().slice(0, 10);

/* ============================ Sécurité : double authentification ============================ */
export function SecurityTab({ onOk, onErr }: Notify) {
  const { session } = useSession();
  const { aal, refresh } = useAal(session);
  const [factors, setFactors] = useState<TotpFactor[] | null>(null);
  const [enroll, setEnroll] = useState<{ id: string; qr: string; secret: string } | null>(null);
  const [code, setCode] = useState('');
  const [policy, setPolicy] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);

  const load = () => {
    listTotp().then(setFactors).catch((e) => onErr(msg(e)));
    fetchMfaPolicy().then(setPolicy).catch(() => setPolicy(false));
    refresh();
  };
  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps
  const verified = (factors ?? []).filter((f) => f.status === 'verified');

  async function start() {
    setBusy(true);
    try { setEnroll(await enrollTotp(`Keystone ${new Date().toLocaleDateString('fr-FR')}`)); setCode(''); }
    catch (e) { onErr(msg(e)); } finally { setBusy(false); }
  }
  async function confirm() {
    if (!enroll) return;
    setBusy(true);
    try { await verifyTotp(enroll.id, code); setEnroll(null); onOk('Double authentification activée — elle sera demandée à chaque connexion'); load(); }
    catch (e) { onErr(/invalid|expired/i.test(msg(e)) ? 'Code invalide — saisissez le code affiché actuellement par l’application.' : msg(e)); }
    finally { setBusy(false); }
  }
  async function remove(f: TotpFactor) {
    if (!window.confirm('Retirer ce facteur ? La connexion ne demandera plus de code.')) return;
    try { await unenrollTotp(f.id); onOk('Facteur retiré'); load(); } catch (e) { onErr(msg(e)); }
  }
  async function togglePolicy() {
    try { await saveMfaPolicy(!policy); onOk(!policy ? 'Double authentification désormais exigée pour les actions financières' : 'Exigence désactivée'); load(); }
    catch (e) { onErr(msg(e)); }
  }

  return (
    <div className="kt-dash kt-dash--21 ks-reveal">
      <Card>
        <div className="kt-cardtitle"><Smartphone size={14} style={{ verticalAlign: -2 }} /> Mon compte — double authentification</div>
        <div className="kt-cardsub">code à 6 chiffres d’une application d’authentification (Google Authenticator, Microsoft Authenticator, 1Password…)</div>
        <div className={`km-state${aal?.current === 'aal2' ? ' km-state--on' : ''}`}>
          <ShieldCheck size={18} />
          <div>
            <b>{aal?.current === 'aal2' ? 'Session renforcée (aal2)' : verified.length ? 'Facteur actif — session non renforcée' : 'Double authentification inactive'}</b>
            <div style={{ fontSize: 12 }}>{verified.length ? `${verified.length} facteur(s) vérifié(s) · demandé à la connexion` : 'mot de passe seul'}</div>
          </div>
        </div>

        {verified.map((f) => (
          <div key={f.id} className="kv-line" style={{ alignItems: 'center' }}>
            <span><KeyRound size={13} style={{ verticalAlign: -2 }} /> {f.friendly_name ?? 'Application TOTP'} <span className="ks-faint" style={{ fontSize: 11.5 }}>· depuis le {new Date(f.created_at).toLocaleDateString('fr-FR')}</span></span>
            <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => void remove(f)}><Trash2 size={13} /> Retirer</button>
          </div>
        ))}

        {!enroll && verified.length === 0 && (
          <button className="ks-btn ks-btn--primary kx-wide" disabled={busy} onClick={() => void start()}><ShieldCheck size={15} /> Activer la double authentification</button>
        )}
        {enroll && (
          <div className="km-enroll">
            <img src={enroll.qr} alt="QR code à scanner avec l’application d’authentification" width={168} height={168} />
            <div style={{ minWidth: 0 }}>
              <ol className="km-steps">
                <li>Scannez ce QR code avec votre application d’authentification.</li>
                <li>Ou saisissez la clé : <span className="ks-mono km-secret">{enroll.secret.replace(/(.{4})/g, '$1 ').trim()}</span></li>
                <li>Entrez le code affiché pour confirmer.</li>
              </ol>
              <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                <input className="kx-in ks-mono" inputMode="numeric" maxLength={6} value={code} placeholder="123456" aria-label="Code de confirmation"
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))} style={{ width: 120, letterSpacing: '.2em' }} />
                <button className="ks-btn ks-btn--primary" disabled={busy || code.length !== 6} onClick={() => void confirm()}><Check size={15} /> Confirmer</button>
                <button className="ks-btn ks-btn--quiet" onClick={() => setEnroll(null)}>Annuler</button>
              </div>
            </div>
          </div>
        )}
      </Card>

      <Card>
        <div className="kt-cardtitle">Politique de l’organisation</div>
        <div className="kt-cardsub">contrôlée en base de données, pas seulement à l’écran</div>
        <label className="km-toggle">
          <input type="checkbox" checked={!!policy} onChange={() => void togglePolicy()} disabled={policy == null} />
          <span><b>Exiger la double authentification pour les actions financières</b>
            <span className="ks-faint" style={{ display: 'block', fontSize: 12, marginTop: 3, lineHeight: 1.5 }}>
              Bon à payer et paiement des factures fournisseurs, encaissement des loyers, refacturation des fluides, modification des seuils d’approbation et du RIB.
            </span>
          </span>
        </label>
        <div className="ku-warn" style={{ marginTop: 12 }}>
          Changer cette politique exige vous-même une session renforcée : activez d’abord votre double authentification, puis reconnectez-vous.
        </div>
      </Card>
    </div>
  );
}

/* ============================ Données personnelles ============================ */
const KIND: Record<string, string> = { person: 'Fiche personne', user: 'Compte utilisateur', lessee_contact: 'Contact preneur', requester: 'Demandeur de ticket', contractor_contact: 'Contact prestataire' };
const TYPE: Record<PrivacyRequest['request_type'], string> = { access: 'Accès', rectification: 'Rectification', erasure: 'Effacement', opposition: 'Opposition', portability: 'Portabilité' };

export function PrivacyTab({ onOk, onErr }: Notify) {
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<Subject[] | null>(null);
  const [reqs, setReqs] = useState<PrivacyRequest[] | null>(null);
  const [erase, setErase] = useState<Subject | null>(null);
  const [reason, setReason] = useState('');
  const [newReq, setNewReq] = useState<Subject | null>(null);
  const [rt, setRt] = useState<PrivacyRequest['request_type']>('access');

  const loadReqs = () => fetchPrivacyRequests().then(setReqs).catch((e) => onErr(msg(e)));
  useEffect(() => { void loadReqs(); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (q.trim().length < 2) { setHits(null); return; }
    const h = setTimeout(() => { searchSubjects(q).then(setHits).catch((e) => onErr(msg(e))); }, 250);
    return () => clearTimeout(h);
  }, [q]); // eslint-disable-line react-hooks/exhaustive-deps

  async function doExport(s: Subject) {
    try {
      const data = await exportSubject(s);
      downloadFile(`donnees-personnelles-${s.label.replace(/[^\p{L}\p{N}]+/gu, '-').toLowerCase()}-${today()}.json`, JSON.stringify(data, null, 2), 'application/json');
      onOk(`Export de « ${s.label} » téléchargé (JSON)`);
    } catch (e) { onErr(msg(e)); }
  }
  async function doErase() {
    if (!erase) return;
    try {
      const r = await anonymizeSubject(erase, reason.trim());
      setErase(null); setReason(''); setQ(''); onOk(`« ${erase.label} » anonymisé (${r.tag}) — ${r.rows} ligne(s), inscrit au registre`); void loadReqs();
    } catch (e) { onErr(msg(e)); }
  }
  async function doCreate() {
    if (!newReq) return;
    try { await createPrivacyRequest({ subject: newReq, type: rt, channel: 'email', received_at: today(), due_days: 30 }); setNewReq(null); onOk('Demande inscrite au registre'); void loadReqs(); }
    catch (e) { onErr(msg(e)); }
  }
  async function mine() {
    try { downloadFile(`mes-donnees-${today()}.json`, JSON.stringify(await myData(), null, 2), 'application/json'); onOk('Vos données ont été téléchargées'); }
    catch (e) { onErr(msg(e)); }
  }

  return (
    <div className="kt-dash kt-dash--21 ks-reveal">
      <div style={{ display: 'grid', gap: 16, alignContent: 'start' }}>
        <Card>
          <div className="kt-cardtitle"><Search size={14} style={{ verticalAlign: -2 }} /> Retrouver une personne</div>
          <div className="kt-cardsub">fiches, comptes, contacts preneurs et prestataires, demandeurs de tickets — dans toute la base</div>
          <input className="kx-in" style={{ width: '100%' }} value={q} onChange={(e) => setQ(e.target.value)} placeholder="Nom, email ou téléphone…" aria-label="Rechercher une personne" />
          {hits && hits.length === 0 && <div className="ks-faint" style={{ fontSize: 12.5, marginTop: 10 }}>Aucune donnée personnelle trouvée.</div>}
          {(hits ?? []).map((s) => (
            <div key={`${s.kind}-${s.id ?? s.key}`} className="km-subject">
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 13.5 }}>{s.label || '—'}</div>
                <div className="ks-faint" style={{ fontSize: 11.5 }}>{KIND[s.kind]} · {s.detail}{s.records > 1 ? ` · ${s.records} enregistrements` : ''}</div>
              </div>
              <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setNewReq(s)}><Plus size={13} /> Demande</button>
              <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => void doExport(s)}><FileJson size={13} /> Exporter</button>
              {s.kind !== 'user' && <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => { setErase(s); setReason(''); }}><UserX size={13} /> Anonymiser</button>}
            </div>
          ))}
          {newReq && (
            <div className="kx-box" style={{ marginTop: 12 }}>
              <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 8 }}>Inscrire une demande pour « {newReq.label} »</div>
              <div className="kx-chips">
                {(Object.keys(TYPE) as PrivacyRequest['request_type'][]).map((t) => (
                  <button key={t} className={`kx-chip${rt === t ? ' kx-chip--on' : ''}`} onClick={() => setRt(t)}>{TYPE[t]}</button>
                ))}
              </div>
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 10 }}>
                <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setNewReq(null)}>Annuler</button>
                <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={() => void doCreate()}><Check size={13} /> Inscrire (échéance J+30)</button>
              </div>
            </div>
          )}
          {erase && (
            <div className="kx-box" style={{ marginTop: 12, borderColor: 'var(--ks-critical)' }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: '#8E1E22' }}><AlertTriangle size={14} style={{ verticalAlign: -2 }} /> Anonymiser « {erase.label} » — irréversible</div>
              <div className="ks-faint" style={{ fontSize: 12, lineHeight: 1.5, margin: '6px 0 10px' }}>
                Nom, téléphone et email sont remplacés par un code d’anonymisation. Baux, factures, OT et registres HSSE sont conservés (obligations légales de conservation).
              </div>
              <textarea className="kt-field ki-input" rows={2} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Motif (ex. demande d’effacement reçue par email le 03/10, identité vérifiée)" />
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 10 }}>
                <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setErase(null)}>Annuler</button>
                <button className="ks-btn ks-btn--primary ks-btn--sm" disabled={reason.trim().length < 10} onClick={() => void doErase()}><UserX size={13} /> Anonymiser définitivement</button>
              </div>
            </div>
          )}
        </Card>
        <Card>
          <div className="kt-cardtitle">Mes propres données</div>
          <div className="kt-cardsub">ce que Keystone conserve sur votre compte</div>
          <button className="ks-btn ks-btn--ghost" onClick={() => void mine()}><Download size={15} /> Télécharger mes données (JSON)</button>
        </Card>
      </div>

      <Card pad={false}>
        <div style={{ padding: '18px 20px 6px' }}>
          <div className="kt-cardtitle">Registre des demandes</div>
          <div className="kt-cardsub" style={{ marginBottom: 6 }}>accès, rectification, effacement, opposition, portabilité — avec échéance de réponse</div>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table className="ks-table">
            <thead><tr><th>Demande</th><th>Personne</th><th>Échéance</th><th>Statut</th></tr></thead>
            <tbody>
              {(reqs ?? []).map((r) => (
                <tr key={r.id}>
                  <td><div className="ks-mono" style={{ fontSize: 12, fontWeight: 600 }}>{r.ref}</div><div style={{ fontSize: 12 }}>{TYPE[r.request_type]}</div></td>
                  <td><div style={{ fontWeight: 600, fontSize: 13 }}>{r.subject_label}</div><div className="ks-faint" style={{ fontSize: 11 }}>{KIND[r.subject_kind]}</div></td>
                  <td>
                    <span className="ks-mono" style={{ fontSize: 12, color: r.overdue ? 'var(--ks-critical)' : undefined }}>{new Date(r.due_date).toLocaleDateString('fr-FR')}</span>
                    {r.status === 'open' && <div style={{ fontSize: 11, color: r.overdue ? 'var(--ks-critical)' : 'var(--ks-ink-3)' }}><Clock size={10} /> {r.overdue ? `dépassée de ${-r.days_left} j` : `J-${r.days_left}`}</div>}
                  </td>
                  <td>
                    {r.status === 'open' ? (
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => { const o = window.prompt('Réponse apportée (tracée au registre) :'); if (o) void closePrivacyRequest(r.id, 'done', o).then(loadReqs).catch((e) => onErr(msg(e))); }}><Check size={12} /> Traitée</button>
                        <button className="ks-icon-btn" aria-label="Rejeter" onClick={() => { const o = window.prompt('Motif du rejet (ex. identité non vérifiée) :'); if (o) void closePrivacyRequest(r.id, 'rejected', o).then(loadReqs).catch((e) => onErr(msg(e))); }}><X size={13} /></button>
                      </div>
                    ) : (
                      <><span className="ks-pill" style={{ color: r.status === 'done' ? 'var(--ks-low)' : 'var(--ks-ink-3)' }}>{r.status === 'done' ? 'Traitée' : 'Rejetée'}</span>
                        {r.outcome && <div className="ks-faint" style={{ fontSize: 11, marginTop: 4, maxWidth: 260 }}>{r.outcome}</div>}</>
                    )}
                  </td>
                </tr>
              ))}
              {reqs && reqs.length === 0 && <tr><td colSpan={4} className="ks-dim" style={{ textAlign: 'center', padding: 26 }}>Aucune demande enregistrée.</td></tr>}
            </tbody>
          </table>
        </div>
        <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12, lineHeight: 1.6 }} className="ks-faint">
          <Info size={12} style={{ verticalAlign: -1 }} /> Cadre : loi ivoirienne n° 2013-450 (autorité : ARTCI) — et équivalents des autres pays (Sénégal : CDP…).
          Le délai de réponse retenu (30 jours par défaut) est à confirmer avec votre conseil.
        </div>
      </Card>
    </div>
  );
}

/* ============================ Comptabilité SYSCOHADA ============================ */
const PLAN_GROUP: Record<string, string> = {
  purchase_goods: 'Achats', purchase_services: 'Achats', electricity: 'Achats', water: 'Achats', vat_deductible: 'Achats', suppliers: 'Tiers',
  customers: 'Tiers', rent_income: 'Ventes', charges_income: 'Ventes', vat_collected: 'Ventes', bank: 'Trésorerie', mobile_money: 'Trésorerie', cash: 'Trésorerie',
};
const JOURNAL: Record<string, string> = { AC: 'Achats', VT: 'Ventes (loyers & charges)', BQ: 'Banque & caisse' };

function monthBounds(offset: number) {
  const d = new Date(); d.setDate(1); d.setMonth(d.getMonth() - offset);
  const from = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
  const end = new Date(d.getFullYear(), d.getMonth() + 1, 0);
  return { from, to: `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, '0')}-${String(end.getDate()).padStart(2, '0')}`, label: d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' }) };
}

export function AccountingTab({ onOk, onErr }: Notify) {
  const [plan, setPlan] = useState<PlanRow[] | null>(null);
  const [edit, setEdit] = useState<Record<string, string>>({});
  const months = useMemo(() => Array.from({ length: 6 }, (_, i) => monthBounds(i)), []);
  const [m, setM] = useState(1);
  const [sum, setSum] = useState<JournalSummary[] | null>(null);
  const [busy, setBusy] = useState(false);
  const p = months[m];

  useEffect(() => { fetchPlan().then(setPlan).catch((e) => onErr(msg(e))); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { setSum(null); fetchJournalSummary(p.from, p.to).then(setSum).catch((e) => onErr(msg(e))); }, [m]); // eslint-disable-line react-hooks/exhaustive-deps

  async function savePlan() {
    try {
      for (const r of plan ?? []) if (edit[r.key] != null && edit[r.key] !== r.account) await savePlanRow(r.key, edit[r.key], r.label);
      setEdit({}); setPlan(await fetchPlan()); onOk('Plan de comptes enregistré');
    } catch (e) { onErr(msg(e)); }
  }
  async function exportCsv() {
    setBusy(true);
    try {
      const rows = await fetchEntries(p.from, p.to);
      const num = (n: number) => (n ? n.toFixed(0) : '0');
      const esc = (s: string | null) => `"${(s ?? '').replace(/"/g, '""')}"`;
      const lines = ['Journal;Date;Piece;Compte;CompteAuxiliaire;Libelle;Debit;Credit',
        ...rows.map((r) => [r.journal, r.entry_date.split('-').reverse().join('/'), esc(r.piece), r.account, esc(r.aux), esc(r.label), num(r.debit), num(r.credit)].join(';'))];
      downloadFile(`ecritures-syscohada-${p.from.slice(0, 7)}.csv`, '﻿' + lines.join('\r\n'), 'text/csv;charset=utf-8');
      onOk(`${rows.length} lignes d’écritures exportées (${p.label})`);
    } catch (e) { onErr(msg(e)); } finally { setBusy(false); }
  }
  const unbalanced = (sum ?? []).reduce((s, j) => s + j.unbalanced_pieces, 0);

  return (
    <div className="kt-dash kt-dash--21 ks-reveal">
      <Card>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'flex-start' }}>
          <div>
            <div className="kt-cardtitle"><FileSpreadsheet size={14} style={{ verticalAlign: -2 }} /> Export des écritures</div>
            <div className="kt-cardsub">journaux Achats, Ventes et Banque · comptes auxiliaires tiers · CSV importable dans le logiciel comptable</div>
          </div>
          <button className="ks-btn ks-btn--primary" disabled={busy || !sum || sum.length === 0} onClick={() => void exportCsv()}><Download size={15} /> {busy ? '…' : 'Exporter le CSV'}</button>
        </div>
        <div className="kx-chips" style={{ marginBottom: 14 }}>
          {months.map((x, i) => <button key={x.from} className={`kx-chip${m === i ? ' kx-chip--on' : ''}`} style={{ textTransform: 'capitalize' }} onClick={() => setM(i)}>{x.label}</button>)}
        </div>
        <table className="ks-table">
          <thead><tr><th>Journal</th><th>Pièces</th><th>Lignes</th><th style={{ textAlign: 'right' }}>Débit</th><th style={{ textAlign: 'right' }}>Crédit</th><th>Équilibre</th></tr></thead>
          <tbody>
            {(sum ?? []).map((j) => (
              <tr key={j.journal}>
                <td><span className="ks-mono" style={{ fontWeight: 700 }}>{j.journal}</span> <span className="ks-faint" style={{ fontSize: 12 }}>{JOURNAL[j.journal] ?? ''}</span></td>
                <td className="ks-mono">{j.pieces}</td>
                <td className="ks-mono">{j.entries}</td>
                <td className="ks-mono" style={{ textAlign: 'right' }}>{fcfa(j.debit)}</td>
                <td className="ks-mono" style={{ textAlign: 'right' }}>{fcfa(j.credit)}</td>
                <td>{j.unbalanced_pieces ? <span className="ks-risk ks-risk--critical">{j.unbalanced_pieces} pièce(s) déséquilibrée(s)</span> : <span className="ks-risk ks-risk--low">Équilibré</span>}</td>
              </tr>
            ))}
            {sum && sum.length === 0 && <tr><td colSpan={6} className="ks-dim" style={{ textAlign: 'center', padding: 24 }}>Aucune écriture sur la période.</td></tr>}
          </tbody>
        </table>
        <div className="ks-faint" style={{ fontSize: 12, lineHeight: 1.6, marginTop: 12 }}>
          <Info size={12} style={{ verticalAlign: -1 }} /> Achats : factures fournisseurs ayant reçu le bon à payer. Ventes : avis d’échéance des baux (loyer, charges, TVA). Banque : règlements fournisseurs et encaissements de loyers.
          {unbalanced > 0 && <b style={{ color: 'var(--ks-critical)' }}> Corrigez les pièces déséquilibrées avant import.</b>}
        </div>
      </Card>

      <Card>
        <div className="kt-cardtitle"><BookOpen size={14} style={{ verticalAlign: -2 }} /> Plan de comptes</div>
        <div className="kt-cardsub">SYSCOHADA révisé — valeurs par défaut indicatives, à valider avec votre expert-comptable</div>
        {(plan ?? []).map((r, i, arr) => (
          <div key={r.key}>
            {(i === 0 || PLAN_GROUP[arr[i - 1].key] !== PLAN_GROUP[r.key]) && <div className="km-group">{PLAN_GROUP[r.key]}</div>}
            <div className="km-acct">
              <input className="kx-in ks-mono" value={edit[r.key] ?? r.account} aria-label={`Compte ${r.label}`} inputMode="numeric"
                onChange={(e) => setEdit({ ...edit, [r.key]: e.target.value.replace(/\D/g, '').slice(0, 10) })} />
              <span style={{ fontSize: 12.5 }}>{r.label}{!r.is_default && <span className="ks-pill" style={{ marginLeft: 6, color: 'var(--ks-amber-700)' }}>personnalisé</span>}</span>
            </div>
          </div>
        ))}
        {Object.keys(edit).length > 0 && <button className="ks-btn ks-btn--primary kx-wide" onClick={() => void savePlan()}><Check size={15} /> Enregistrer le plan</button>}
      </Card>
    </div>
  );
}
