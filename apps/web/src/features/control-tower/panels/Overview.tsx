import { useCallback, useEffect, useState } from 'react';
import { ArrowUpRight, ArrowDownRight, ChevronRight, Activity, MapPin, Zap, ShieldCheck, AlertTriangle } from 'lucide-react';
import { Card, RiskBadge, RingGauge, Sparkline, Pill, Button } from '@keystone/ui';
import { KPIS, SITE_HEALTH, ENERGY, type AttentionItem } from '../../../data/demo.ts';
import { fetchAttention, fetchPosture } from '../../../data/cockpit.ts';
import { supabase } from '../../../lib/supabase.ts';
import type { Posture } from '@keystone/domain/db/keystone';
import { AttnRow, HealthCell, levelColor, postureColor, type PanelProps } from '../shared.tsx';

const TICKER = [
  { t: 'GTC : 3 groupes froids nominaux', c: 'var(--ks-low)' },
  { t: 'SSI Yopougon : essai hebdo conforme', c: 'var(--ks-low)' },
  { t: 'Ascenseur A3 : contrôle Veritas en dépassement', c: 'var(--ks-critical)' },
  { t: '4 intervenants sur le terrain', c: 'var(--ks-info)' },
  { t: 'Énergie galerie : +18 % vs baseline', c: 'var(--ks-high)' },
  { t: 'Préventif du jour : 12 OT planifiés', c: 'var(--ks-amber)' },
];

export function Overview(_: PanelProps) {
  const [attention, setAttention] = useState<AttentionItem[] | null>(null);
  const [attErr, setAttErr] = useState<string | null>(null);
  const [posture, setPosture] = useState<Posture | null>(null);
  const [flash, setFlash] = useState(false);

  const load = useCallback(() => {
    fetchPosture().then(setPosture).catch(() => {});
    fetchAttention()
      .then((live) =>
        setAttention(
          live.map((a, i) => ({
            id: `${a.domain}-${a.ref || i}`, level: a.level, domain: a.domain, title: a.title,
            site: a.scope || '—', asset: undefined, riskScore: a.risk, age: a.detail,
          })),
        ),
      )
      .catch((e) => setAttErr(e instanceof Error ? e.message : String(e)));
  }, []);

  useEffect(() => { load(); }, [load]);

  // Temps réel : tout changement en base rafraîchit le feed + la posture (Supabase Realtime)
  useEffect(() => {
    const sb = supabase;
    if (!sb) return;
    const ch = sb.channel('cockpit-live');
    for (const t of ['work_orders', 'hsse_events', 'capa_actions', 'regulatory_controls', 'work_permits']) {
      ch.on('postgres_changes', { event: '*', schema: 'keystone', table: t }, () => {
        setFlash(true);
        load();
        setTimeout(() => setFlash(false), 1800);
      });
    }
    ch.subscribe();
    return () => { void sb.removeChannel(ch); };
  }, [load]);

  const postureAxes: [string, number][] = posture
    ? [['Technique', posture.technique], ['Sûreté', posture.surete], ['Conformité', posture.conformite], ['Budget', posture.budget]]
    : [];

  return (
    <>
      {/* Posture + ticker */}
      <div className="kt-dash kt-dash--21 ks-reveal" style={{ marginBottom: 18 }}>
        <Card>
          <div className="kt-posture" style={{ justifyContent: 'space-around', minHeight: 108 }}>
            {postureAxes.map(([label, val]) => (
              <div className="kt-posture__item" key={label}>
                <RingGauge value={val} size={76} stroke={7} color={postureColor(val)} />
                <span className="kt-posture__lbl">{label}</span>
              </div>
            ))}
            {!posture && <span className="ks-dim" style={{ margin: 'auto' }}>Calcul du score…</span>}
          </div>
          {posture && (
            <div style={{ marginTop: 14, paddingTop: 12, borderTop: '1px solid var(--ks-line)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span className="ks-faint" style={{ fontSize: 11.5 }} title={`Drivers : ${JSON.stringify(posture.drivers)}`}>
                Score de risque dynamique · §10.4 · {posture.formula_version}
              </span>
              <span className="ks-mono" style={{ fontSize: 15, fontWeight: 600, color: posture.risk_score >= 60 ? 'var(--ks-critical)' : posture.risk_score >= 35 ? 'var(--ks-high)' : 'var(--ks-low)' }}>
                {posture.risk_score}<span className="ks-faint" style={{ fontSize: 11 }}>/100</span>
              </span>
            </div>
          )}
        </Card>
        <Card style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <div className="ks-eyebrow" style={{ marginBottom: 10 }}>Flux opérationnel live</div>
          <div className="kt-ticker" style={{ margin: 0 }} aria-hidden>
            <span className="kt-ticker__lead"><Activity size={13} /> LIVE</span>
            <div className="kt-ticker__track">
              {[...TICKER, ...TICKER].map((t, i) => (
                <span className="kt-ticker__item" key={i}>
                  <span className="ks-status__dot" style={{ width: 7, height: 7, borderRadius: 7, background: t.c }} />
                  {t.t}
                </span>
              ))}
            </div>
          </div>
        </Card>
      </div>

      {/* KPI strip */}
      <div className="kt-dash kt-dash--4">
        {KPIS.map((k, i) => (
          <Card key={k.label} hover className="ks-reveal" style={{ animationDelay: `${i * 60}ms` }}>
            <div className="ks-kpi">
              <div className="ks-kpi__label">{k.label}</div>
              <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 8 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
                  <span className="ks-kpi__value">{k.value}</span>
                  {k.unit && <span className="ks-kpi__unit">{k.unit}</span>}
                </div>
                <Sparkline data={k.trend} color={k.color} />
              </div>
              <div className="ks-kpi__foot">
                <span className={k.good ? 'ks-trend-up' : 'ks-trend-down'} style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontWeight: 600 }}>
                  {k.good ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
                  {k.delta}
                </span>
              </div>
            </div>
          </Card>
        ))}
      </div>

      {/* Attention + énergie */}
      <div className="kt-dash kt-dash--21" style={{ marginTop: 18 }}>
        <Card pad={false} className="ks-reveal" style={{ animationDelay: '240ms' }}>
          <div className="ks-card__head" style={{ padding: '18px 20px 12px' }}>
            <div>
              <div className="ks-card__title" style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                Ce qui exige mon attention maintenant
                <span className="ks-sync" style={{ fontSize: 11, color: flash ? 'var(--ks-amber-700)' : undefined }}>
                  <span className="ks-sync__dot" style={flash ? { background: 'var(--ks-amber)' } : undefined} />
                  {flash ? 'mise à jour' : 'LIVE'}
                </span>
              </div>
              <div className="ks-faint" style={{ fontSize: 12, marginTop: 2 }}>Consolidé tous domaines · trié par criticité × risque (RLS)</div>
            </div>
            <Button sm variant="quiet">Tout voir <ChevronRight size={15} /></Button>
          </div>
          <div className="ks-attn" style={{ padding: '0 12px 8px' }}>
            {attErr && (
              <div style={{ padding: '32px 20px', textAlign: 'center' }}>
                <AlertTriangle size={24} color="var(--ks-high)" />
                <div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{attErr}</div>
              </div>
            )}
            {!attErr && attention === null && <div className="ks-dim" style={{ padding: '40px', textAlign: 'center' }}>Chargement live…</div>}
            {attention?.map((a) => <AttnRow key={a.id} item={a} />)}
            {attention?.length === 0 && (
              <div style={{ padding: '46px 20px', textAlign: 'center' }}>
                <div style={{ width: 52, height: 52, borderRadius: 16, margin: '0 auto 14px', display: 'grid', placeItems: 'center', background: 'var(--ks-low-100)', color: 'var(--ks-low)' }}>
                  <ShieldCheck size={26} strokeWidth={1.8} />
                </div>
                <div style={{ fontSize: 15, fontWeight: 700 }}>Tout est sous contrôle</div>
                <div className="ks-dim" style={{ fontSize: 13, marginTop: 4 }}>Aucune alerte critique ou élevée sur ce périmètre.</div>
              </div>
            )}
          </div>
        </Card>

        <Card pad={false} className="ks-reveal" style={{ animationDelay: '320ms' }}>
          <div className="ks-card__head" style={{ padding: '18px 20px 8px' }}>
            <div className="ks-card__title" style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
              <Zap size={16} color="var(--ks-amber-600)" /> Anomalies énergétiques
            </div>
            <Pill>7 derniers jours</Pill>
          </div>
          <div style={{ padding: '4px 20px 14px' }}>
            {ENERGY.map((e) => (
              <div className="kt-energy-row" key={e.zone}>
                <span style={{ width: 8, height: 8, borderRadius: 9, background: levelColor(e.level) }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{e.zone}</div>
                </div>
                <Sparkline data={e.series} width={70} height={24} color={levelColor(e.level)} />
                <span className="ks-mono" style={{ fontSize: 13, fontWeight: 600, width: 52, textAlign: 'right', color: e.deviation > 0 ? 'var(--ks-high)' : 'var(--ks-low)' }}>
                  {e.deviation > 0 ? '+' : ''}{e.deviation}%
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Sites live */}
      <div className="kt-section-h">
        <h2>État live des sites</h2>
        <span className="kt-count ks-sync"><span className="ks-sync__dot" /> Temps réel · Supabase Realtime</span>
      </div>
      <div className="kt-grid kt-grid--sites">
        {SITE_HEALTH.map((s, i) => (
          <Card key={s.name} hover className="ks-reveal" style={{ animationDelay: `${i * 80}ms` }}>
            <div className="kt-sitecard">
              <div className="kt-sitecard__top">
                <div>
                  <div className="kt-sitecard__name">{s.name}</div>
                  <div className="kt-sitecard__meta"><MapPin size={12} style={{ verticalAlign: -1 }} /> {s.city} · {s.assets.toLocaleString('fr-FR')} actifs</div>
                </div>
                <RiskBadge level={s.status} />
              </div>
              <div className="kt-health">
                <HealthCell label="Technique" v={s.technique} />
                <HealthCell label="Sûreté" v={s.surete} />
                <HealthCell label="Conformité" v={s.conformite} />
                <HealthCell label="Budget" v={s.budget} />
              </div>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
