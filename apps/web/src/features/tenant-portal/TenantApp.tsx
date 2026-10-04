import { useEffect, useMemo, useState } from 'react';
import {
  Home, ClipboardList, FileText, Megaphone, LogOut, Eye, Wrench, Sparkles, Lightbulb, ShieldAlert, Thermometer, Droplets, Briefcase,
  HelpCircle, ChevronRight, Phone, Mail, MapPin, Star, Send, X, CheckCircle2, AlertTriangle, Receipt, CalendarDays, Store,
} from 'lucide-react';
import { money, format } from '@keystone/domain';
import type { LesseeHome, TicketStatus, RentReceipt, ScheduleStatus } from '@keystone/domain/db/keystone';
import { useSession, signOut } from '../../lib/auth.ts';
import { Login } from '../auth/Login.tsx';
import { ReceiptView } from '../leases/Leases.tsx';
import { fetchPortalLessees, fetchLesseeHome, lesseeCreateTicket, lesseeComment, lesseeRate, fetchReceipt } from '../../data/leases.ts';

const fcfa = (n: number) => format(money(Math.round(n), 'XOF'));
const dd = (s: string | null) => (s ? new Date(s).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }) : '—');
const ago = (s: string) => {
  const m = Math.round((Date.now() - new Date(s).getTime()) / 60000);
  return m < 60 ? `il y a ${Math.max(1, m)} min` : m < 1440 ? `il y a ${Math.round(m / 60)} h` : `le ${dd(s)}`;
};
const CATEGORIES = [
  { id: 'panne', label: 'Panne / réparation', icon: Wrench }, { id: 'nettoyage', label: 'Nettoyage', icon: Sparkles },
  { id: 'eclairage', label: 'Éclairage', icon: Lightbulb }, { id: 'securite', label: 'Sécurité', icon: ShieldAlert },
  { id: 'climatisation', label: 'Climatisation', icon: Thermometer }, { id: 'plomberie', label: 'Plomberie', icon: Droplets },
  { id: 'commercial', label: 'Demande commerciale', icon: Briefcase }, { id: 'autre', label: 'Autre', icon: HelpCircle },
];
const catLabel = (c: string | null) => CATEGORIES.find((x) => x.id === c)?.label ?? c ?? 'Demande';
const STEP: Record<TicketStatus, { label: string; pct: number; tone: 'wait' | 'run' | 'done' | 'off' }> = {
  new: { label: 'Reçue', pct: 15, tone: 'wait' }, triaged: { label: 'Prise en compte', pct: 30, tone: 'wait' },
  assigned: { label: 'Technicien affecté', pct: 50, tone: 'run' }, in_progress: { label: 'Intervention en cours', pct: 75, tone: 'run' },
  resolved: { label: 'Résolue', pct: 100, tone: 'done' }, closed: { label: 'Clôturée', pct: 100, tone: 'done' },
  rejected: { label: 'Non retenue', pct: 100, tone: 'off' }, reopened: { label: 'Réouverte', pct: 40, tone: 'run' },
};
const PAY: Record<ScheduleStatus, { label: string; cls: string }> = {
  paid: { label: 'Réglée', cls: 'ok' }, pending: { label: 'À venir', cls: 'wait' }, partial: { label: 'Partielle', cls: 'warn' },
  partial_overdue: { label: 'Partielle — échue', cls: 'late' }, overdue: { label: 'Impayée', cls: 'late' },
};
const NEWS: Record<string, string> = { info: 'Info', event: 'Événement', maintenance: 'Travaux', safety: 'Sécurité' };
type Tab = 'home' | 'requests' | 'lease' | 'news';

export function TenantApp() {
  const { session, ready } = useSession();
  if (!ready) return <div className="kx-center ks-faint">Chargement…</div>;
  if (!session) return <Login />;
  return <TenantSpace />;
}

function TenantSpace() {
  const [lessees, setLessees] = useState<{ id: string; name: string; trade_name: string | null; open_tickets: number }[]>([]);
  const [previewId, setPreviewId] = useState<string | null>(null);
  const [home, setHome] = useState<LesseeHome | null>(null);
  const [tab, setTab] = useState<Tab>('home');
  const [compose, setCompose] = useState<string | null | false>(false);  // false = fermé, null = choix catégorie, string = catégorie
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [receipt, setReceipt] = useState<RentReceipt | null>(null);

  useEffect(() => {
    fetchPortalLessees().then((ls) => { setLessees(ls); setPreviewId((p) => p ?? ls.find((l) => l.open_tickets > 0)?.id ?? ls[0]?.id ?? null); })
      .catch((e) => setErr(e instanceof Error ? e.message : String(e)));
  }, []);
  function load() {
    if (!previewId) return;  // un locataire connecté reçoit son propre id via portal_lessees()
    fetchLesseeHome(previewId ?? undefined).then(setHome).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
  }
  useEffect(load, [previewId]); // eslint-disable-line react-hooks/exhaustive-deps
  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 4500); };
  const scope = home?.is_lessee ? undefined : previewId ?? undefined;
  const lease = home?.leases?.[0];
  const open = (home?.tickets ?? []).filter((t) => !['resolved', 'closed', 'rejected'].includes(t.status));

  return (
    <div className="kz-shell">
      <header className="kx-top">
        <div className="kx-top__brand">
          <span className="ks-rail__logo" style={{ width: 34, height: 34 }} aria-hidden><Store size={17} /></span>
          <div style={{ minWidth: 0 }}>
            <div className="ks-eyebrow">{home?.site ?? 'Atlas Keystone'} · Espace locataire</div>
            <div className="kx-top__name">{home?.lessee.trade_name ?? home?.lessee.name ?? '—'}</div>
          </div>
        </div>
        <button className="ks-icon-btn" aria-label="Se déconnecter" onClick={() => void signOut()}><LogOut size={17} /></button>
      </header>

      {home && !home.is_lessee && (
        <div className="kx-preview">
          <Eye size={15} />
          <span>Aperçu exploitant — portail tel que le locataire le voit.</span>
          <select className="ka-select" value={previewId ?? ''} onChange={(e) => { setPreviewId(e.target.value); setHome(null); }} aria-label="Locataire à prévisualiser">
            {lessees.map((l) => <option key={l.id} value={l.id}>{l.trade_name ?? l.name}{l.open_tickets ? ` · ${l.open_tickets} demande(s)` : ''}</option>)}
          </select>
        </div>
      )}

      <main className="kx-main kz-main">
        {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
        {err && <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}><AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span></div>}
        {!home && !err && <div className="kx-empty ks-faint">Chargement…</div>}

        {home && tab === 'home' && (
          <div className="ks-reveal">
            <h1 className="kz-hello">Bonjour {home.lessee.contact?.replace(/^Responsable\s+/, '') ?? home.lessee.trade_name} 👋</h1>
            <div className="ks-faint" style={{ fontSize: 13, marginBottom: 16 }}>{lease?.spaces?.map((s) => `${s.code} · ${s.m2} m²`).join(' — ')}</div>

            <button className="kz-cta" onClick={() => setCompose(null)}>
              <span className="kz-cta__icon"><Wrench size={22} /></span>
              <span><b>Signaler un problème</b><span>Panne, nettoyage, sécurité… un technicien est prévenu immédiatement.</span></span>
              <ChevronRight size={20} />
            </button>

            <div className="kz-grid">
              <section className="kz-card">
                <div className="kz-card__head"><span>Mes demandes en cours</span><button className="kz-link" onClick={() => setTab('requests')}>Tout voir</button></div>
                {open.slice(0, 3).map((t) => (
                  <div key={t.id} className="kz-mini">
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}><b>{catLabel(t.category)}</b><span className={`kz-tag kz-tag--${STEP[t.status].tone}`}>{STEP[t.status].label}</span></div>
                    <div className="ks-faint kz-clip">{t.description}</div>
                    <div className="kz-bar"><span style={{ width: `${STEP[t.status].pct}%` }} /></div>
                  </div>
                ))}
                {open.length === 0 && <div className="ks-faint" style={{ fontSize: 13 }}>Aucune demande en cours.</div>}
              </section>

              {lease && (
                <section className="kz-card">
                  <div className="kz-card__head"><span>Mon bail</span><button className="kz-link" onClick={() => setTab('lease')}>Détails</button></div>
                  <div className="kv-line"><span>Bail</span><b className="ks-mono">{lease.ref}</b></div>
                  <div className="kv-line"><span>Fin</span><b>{dd(lease.end)}</b></div>
                  <div className="kv-line"><span>Loyer HT</span><b className="ks-mono">{fcfa(lease.rent)}/mois</b></div>
                  {home.next_due && <div className="kv-line"><span>Prochaine échéance</span><b>{dd(home.next_due.due_date)} · <span className="ks-mono">{fcfa(Number(home.next_due.amount))}</span></b></div>}
                  <div className={`kz-status kz-status--${home.balance > 0 ? 'late' : 'ok'}`}>
                    {home.balance > 0 ? <><AlertTriangle size={14} /> Solde échu : {fcfa(home.balance)}</> : <><CheckCircle2 size={14} /> Compte à jour</>}
                  </div>
                </section>
              )}
            </div>

            {(home.news ?? []).length > 0 && (
              <section className="kz-card" style={{ marginTop: 12 }}>
                <div className="kz-card__head"><span>Actualités du centre</span><button className="kz-link" onClick={() => setTab('news')}>Tout voir</button></div>
                {(home.news ?? []).slice(0, 3).map((n) => (
                  <div key={n.id} className="kz-newsrow"><span className={`kl-news__kind kl-news__kind--${n.kind}`}>{NEWS[n.kind]}</span><span style={{ flex: 1 }}>{n.title}</span>{n.event_date && <span className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>{dd(n.event_date)}</span>}</div>
                ))}
              </section>
            )}

            {home.contacts && (
              <section className="kz-card" style={{ marginTop: 12 }}>
                <div className="kz-card__head"><span>Contacts utiles</span></div>
                {home.contacts.emergency_phone && <a className="kz-contact kz-contact--sos" href={`tel:${home.contacts.emergency_phone.replace(/[^+\d]/g, '')}`}><Phone size={15} /> Urgences : {home.contacts.emergency_phone}</a>}
                {home.contacts.management_email && <a className="kz-contact" href={`mailto:${home.contacts.management_email}`}><Mail size={15} /> {home.contacts.management_email}</a>}
                {home.contacts.reception && <div className="kz-contact"><MapPin size={15} /> {home.contacts.reception}</div>}
              </section>
            )}
          </div>
        )}

        {home && tab === 'requests' && (
          <Requests home={home} onNew={() => setCompose(null)} onChanged={(m) => { flash(m); load(); }} onError={setErr} />
        )}

        {home && tab === 'lease' && lease && (
          <div className="ks-reveal">
            <h1 className="kz-title">Mon bail</h1>
            <section className="kz-card">
              <div className="kv-line"><span>Référence</span><b className="ks-mono">{lease.ref}</b></div>
              <div className="kv-line"><span>Locaux</span><b>{lease.spaces?.map((s) => `${s.code} (${s.m2} m²)`).join(', ')}</b></div>
              <div className="kv-line"><span>Durée</span><b>{dd(lease.start)} → {dd(lease.end)}</b></div>
              <div className="kv-line"><span>Loyer HT</span><b className="ks-mono">{fcfa(lease.rent)} / mois</b></div>
              <div className="kv-line"><span>Provision sur charges</span><b className="ks-mono">{fcfa(lease.charges)} / mois</b></div>
              <div className="kv-line"><span>TVA</span><b>{lease.vat_rate} %</b></div>
              <div className="kv-line"><span>Paiement</span><b>le {lease.payment_day} de chaque mois</b></div>
              <div className="kv-line"><span>Dépôt de garantie</span><b className="ks-mono">{fcfa(lease.deposit)}</b></div>
              <div className="kv-line"><span>Prochaine révision</span><b>{dd(lease.next_indexation)}{lease.indexation_type === 'fixed' && lease.indexation_rate ? ` · +${lease.indexation_rate} %` : lease.indexation_type === 'index' ? ' · sur indice' : ''}</b></div>
            </section>
            <h2 className="kz-sub">Échéancier &amp; quittances</h2>
            <section className="kz-card">
              {(home.schedules ?? []).map((s) => (
                <div key={s.id} className="kz-sched">
                  <CalendarDays size={15} className="ks-faint" />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 600, textTransform: 'capitalize' }}>{new Date(s.period).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })}</div>
                    <div className="ks-faint" style={{ fontSize: 12 }}>échéance {dd(s.due_date)} · <span className="ks-mono">{fcfa(Number(s.total_due))}</span></div>
                  </div>
                  <span className={`kz-tag kz-tag--${PAY[s.status].cls}`}>{PAY[s.status].label}</span>
                  {s.status === 'paid' && (
                    <button className="ks-icon-btn" aria-label="Télécharger la quittance" title="Quittance"
                      onClick={() => fetchReceipt(s.id).then(setReceipt).catch((e) => setErr(e instanceof Error ? e.message : String(e)))}>
                      <Receipt size={15} />
                    </button>
                  )}
                </div>
              ))}
            </section>
          </div>
        )}

        {home && tab === 'news' && (
          <div className="ks-reveal">
            <h1 className="kz-title">Actualités du centre</h1>
            {(home.news ?? []).map((n) => (
              <section key={n.id} className="kz-card" style={{ marginBottom: 10 }}>
                <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 6 }}>
                  <span className={`kl-news__kind kl-news__kind--${n.kind}`}>{NEWS[n.kind]}</span>
                  {n.event_date && <span className="ks-mono ks-faint" style={{ fontSize: 12 }}>{dd(n.event_date)}</span>}
                </div>
                <div style={{ fontWeight: 700, fontSize: 15 }}>{n.title}</div>
                {n.body && <div className="ks-dim" style={{ fontSize: 13.5, marginTop: 4, lineHeight: 1.55 }}>{n.body}</div>}
              </section>
            ))}
            {(home.news ?? []).length === 0 && <div className="kx-empty">Pas d’actualité pour le moment.</div>}
          </div>
        )}
      </main>

      <nav className="kz-nav" aria-label="Navigation">
        {([['home', 'Accueil', Home], ['requests', 'Demandes', ClipboardList], ['lease', 'Mon bail', FileText], ['news', 'Actualités', Megaphone]] as const).map(([id, label, Icon]) => (
          <button key={id} className={`kz-nav__btn${tab === id ? ' kz-nav__btn--on' : ''}`} onClick={() => setTab(id)} aria-current={tab === id ? 'page' : undefined}>
            <Icon size={20} /><span>{label}</span>{id === 'requests' && open.length > 0 && <i className="kz-nav__badge">{open.length}</i>}
          </button>
        ))}
      </nav>

      {compose !== false && home && (
        <NewRequest category={compose} spaces={lease?.spaces?.map((s) => s.code) ?? []}
          onPick={(c) => setCompose(c)} onClose={() => setCompose(false)}
          onSubmit={async (cat, desc, space) => {
            const r = await lesseeCreateTicket(scope, cat, desc, space);
            setCompose(false); setTab('requests');
            flash(`Demande ${r.ref} envoyée${r.priority === 1 ? ' — traitée en priorité' : ''}`); load();
          }} />
      )}
      {receipt && <ReceiptView r={receipt} onClose={() => setReceipt(null)} />}
    </div>
  );
}

function Requests({ home, onNew, onChanged, onError }: { home: LesseeHome; onNew: () => void; onChanged: (m: string) => void; onError: (m: string) => void }) {
  const [filter, setFilter] = useState<'all' | 'open' | 'done'>('open');
  const [reply, setReply] = useState<Record<string, string>>({});
  const list = useMemo(() => (home.tickets ?? []).filter((t) => {
    const done = ['resolved', 'closed', 'rejected'].includes(t.status);
    return filter === 'all' || (filter === 'done' ? done : !done);
  }), [home, filter]);
  const counts = { open: (home.tickets ?? []).filter((t) => !['resolved', 'closed', 'rejected'].includes(t.status)).length, all: (home.tickets ?? []).length };

  async function send(id: string) {
    const body = (reply[id] ?? '').trim();
    if (!body) return;
    try { await lesseeComment(id, body); setReply((r) => ({ ...r, [id]: '' })); onChanged('Message envoyé à l’équipe technique'); }
    catch (e) { onError(e instanceof Error ? e.message : String(e)); }
  }
  async function rate(id: string, s: number) {
    try { await lesseeRate(id, s); onChanged('Merci pour votre évaluation !'); } catch (e) { onError(e instanceof Error ? e.message : String(e)); }
  }

  return (
    <div className="ks-reveal">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
        <h1 className="kz-title" style={{ margin: 0 }}>Mes demandes</h1>
        <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={onNew}>+ Nouvelle demande</button>
      </div>
      <div className="kx-chips" style={{ marginBottom: 12 }}>
        <button className={`kx-chip${filter === 'open' ? ' kx-chip--on' : ''}`} onClick={() => setFilter('open')}>En cours ({counts.open})</button>
        <button className={`kx-chip${filter === 'done' ? ' kx-chip--on' : ''}`} onClick={() => setFilter('done')}>Traitées ({counts.all - counts.open})</button>
        <button className={`kx-chip${filter === 'all' ? ' kx-chip--on' : ''}`} onClick={() => setFilter('all')}>Toutes</button>
      </div>
      {list.map((t) => {
        const st = STEP[t.status];
        const late = t.sla_due && !['resolved', 'closed', 'rejected'].includes(t.status) && new Date(t.sla_due) < new Date();
        return (
          <section key={t.id} className="kz-card kz-ticket">
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
              <span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{t.ref} · {ago(t.created_at)}</span>
              <span className={`kz-tag kz-tag--${st.tone}`}>{st.label}</span>
            </div>
            <div style={{ fontWeight: 700, fontSize: 15, margin: '6px 0 2px' }}>{catLabel(t.category)}</div>
            <div className="ks-dim" style={{ fontSize: 13 }}>{t.description}</div>
            <div className="kz-bar" style={{ marginTop: 10 }}><span style={{ width: `${st.pct}%` }} /></div>
            {late && <div style={{ fontSize: 11.5, color: 'var(--ks-high)', marginTop: 6 }}>Délai de traitement dépassé — l’équipe est relancée automatiquement.</div>}
            {t.last_message && (
              <div className="kz-msg"><b>Dernière mise à jour · {ago(t.last_message.at)}</b><span>« {t.last_message.body} »</span></div>
            )}
            {['resolved', 'closed'].includes(t.status) ? (
              t.satisfaction ? (
                <div className="kz-stars" aria-label={`Note ${t.satisfaction} sur 5`}>{[1, 2, 3, 4, 5].map((s) => <Star key={s} size={16} fill={s <= (t.satisfaction ?? 0) ? 'var(--ks-amber)' : 'none'} color="var(--ks-amber)" />)}<span className="ks-faint" style={{ fontSize: 12, marginLeft: 6 }}>Vous avez noté {t.satisfaction}/5 — merci !</span></div>
              ) : (
                <div className="kz-stars"><span style={{ fontSize: 12.5, marginRight: 6 }}>Votre avis :</span>{[1, 2, 3, 4, 5].map((s) => (
                  <button key={s} className="kz-star" aria-label={`Noter ${s} sur 5`} onClick={() => rate(t.id, s)}><Star size={20} color="var(--ks-amber)" /></button>
                ))}</div>
              )
            ) : t.status !== 'rejected' && (
              <div className="kz-reply">
                <input className="kx-in kx-in--grow" placeholder="Ajouter une précision…" value={reply[t.id] ?? ''} onChange={(e) => setReply((r) => ({ ...r, [t.id]: e.target.value }))}
                  onKeyDown={(e) => { if (e.key === 'Enter') void send(t.id); }} />
                <button className="ks-icon-btn" aria-label="Envoyer" disabled={!(reply[t.id] ?? '').trim()} onClick={() => void send(t.id)}><Send size={15} /></button>
              </div>
            )}
          </section>
        );
      })}
      {list.length === 0 && <div className="kx-empty">Aucune demande dans cette liste.</div>}
    </div>
  );
}

function NewRequest({ category, spaces, onPick, onClose, onSubmit }: {
  category: string | null; spaces: string[]; onPick: (c: string) => void; onClose: () => void;
  onSubmit: (cat: string, desc: string, space?: string) => Promise<void>;
}) {
  const [desc, setDesc] = useState('');
  const [space, setSpace] = useState(spaces[0] ?? '');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const cat = CATEGORIES.find((c) => c.id === category);
  async function go() {
    if (!category) return;
    setBusy(true); setErr(null);
    try { await onSubmit(category, desc.trim(), space || undefined); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); setBusy(false); }
  }
  return (
    <div className="kx-sheet-wrap" onClick={onClose}>
      <section className="kx-sheet" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Nouvelle demande">
        <div className="kx-sheet__grab" aria-hidden />
        <div className="ka-drawer__head">
          <h2 style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-.02em', margin: 0 }}>{cat ? cat.label : 'Que souhaitez-vous signaler ?'}</h2>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>
        {!cat ? (
          <div className="kz-cats">
            {CATEGORIES.map((c) => (
              <button key={c.id} className="kz-cat" onClick={() => onPick(c.id)}><c.icon size={24} /><span>{c.label}</span></button>
            ))}
          </div>
        ) : (
          <>
            {spaces.length > 1 && (
              <select className="ka-select" style={{ width: '100%', height: 40, marginBottom: 10 }} value={space} onChange={(e) => setSpace(e.target.value)} aria-label="Local concerné">
                {spaces.map((s) => <option key={s} value={s}>Local {s}</option>)}
              </select>
            )}
            <textarea className="kt-field ki-input" rows={4} style={{ width: '100%' }} autoFocus
              placeholder="Décrivez le problème : où exactement, depuis quand, est-ce urgent ?" value={desc} onChange={(e) => setDesc(e.target.value)} />
            {category === 'securite' && <div className="kz-status kz-status--late" style={{ marginTop: 10 }}><AlertTriangle size={14} /> En cas de danger immédiat, appelez aussi le numéro d’urgence du centre.</div>}
            {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12.5, marginTop: 10 }}>{err}</div>}
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="ks-btn ks-btn--quiet kx-wide" style={{ flex: '0 0 auto', width: 'auto' }} onClick={() => onPick('')}>Changer</button>
              <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || desc.trim().length < 5} onClick={go}><Send size={15} /> {busy ? 'Envoi…' : 'Envoyer la demande'}</button>
            </div>
          </>
        )}
      </section>
    </div>
  );
}
