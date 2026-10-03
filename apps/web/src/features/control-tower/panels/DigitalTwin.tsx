import { useCallback, useEffect, useState } from 'react';
import { Users, Wrench, Footprints, Coffee, MapPin, Maximize2 } from 'lucide-react';
import { Card, StatBig, CountUp } from '@keystone/ui';
import type { LivePresence } from '@keystone/domain/db/keystone';
import { ROOMS, ASSET_PINS } from '../../../data/demo.ts';
import { fetchPresence } from '../../../data/cockpit.ts';
import { supabase } from '../../../lib/supabase.ts';
import { CardTitle, type PanelProps } from '../shared.tsx';

type St = LivePresence['status'];
const statusColor = (s: St) =>
  s === 'on_wo' ? 'var(--ks-info)' : s === 'on_duty' ? 'var(--ks-low)' : s === 'break' ? 'var(--ks-ink-3)' : 'var(--ks-ink-3)';
const statusLabel = (s: St) =>
  s === 'on_wo' ? 'Sur OT' : s === 'on_duty' ? 'En service' : s === 'break' ? 'Pause' : 'Hors ligne';

export function DigitalTwin(_: PanelProps) {
  const [people, setPeople] = useState<LivePresence[] | null>(null);
  const [flash, setFlash] = useState(false);

  const load = useCallback(() => { fetchPresence().then(setPeople).catch(() => {}); }, []);
  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    const sb = supabase;
    if (!sb) return;
    const ch = sb.channel('presence-live').on(
      'postgres_changes', { event: '*', schema: 'keystone', table: 'presence' },
      () => { setFlash(true); load(); setTimeout(() => setFlash(false), 1500); },
    );
    ch.subscribe();
    return () => { void sb.removeChannel(ch); };
  }, [load]);

  const list = people ?? [];
  const onWo = list.filter((t) => t.status === 'on_wo').length;
  const onDuty = list.filter((t) => t.status === 'on_duty').length;
  const onBreak = list.filter((t) => t.status === 'break').length;

  return (
    <>
      <div className="kt-dash kt-dash--4 ks-reveal">
        <Card><StatBig label="Intervenants actifs" icon={<Users size={15} />} value={<CountUp value={list.length} />} sub="présents sur site" /></Card>
        <Card><StatBig label="Sur ordre de travail" icon={<Wrench size={15} />} accent="var(--ks-info)" value={<CountUp value={onWo} />} sub="intervention en cours" /></Card>
        <Card><StatBig label="En service / ronde" icon={<Footprints size={15} />} accent="var(--ks-low)" value={<CountUp value={onDuty} />} sub="disponible" /></Card>
        <Card><StatBig label="En pause" icon={<Coffee size={15} />} accent="var(--ks-ink-3)" value={<CountUp value={onBreak} />} sub="indisponible" /></Card>
      </div>

      <Card className="ks-reveal" style={{ marginTop: 18, animationDelay: '120ms' }}>
        <CardTitle
          title="Jumeau numérique vivant — positions terrain"
          sub="Temps réel · Supabase Realtime · CDC §5.10 / §6.27"
          right={
            <span className="ks-sync" style={{ color: flash ? 'var(--ks-amber-700)' : 'var(--ks-info)' }}>
              <span className="ks-sync__dot" style={flash ? { background: 'var(--ks-amber)' } : { background: 'var(--ks-info)' }} />
              {flash ? 'mise à jour' : `${onWo} sur OT · live`}
            </span>
          }
        />
        <div style={{ display: 'grid', gridTemplateColumns: '1.85fr 1fr', gap: 24, alignItems: 'start', marginTop: 18 }}>
          <div>
            <div className="kt-plan" style={{ aspectRatio: '16 / 9' }}>
              <div className="kt-plan__grid" />
              <button className="ks-icon-btn" style={{ position: 'absolute', top: 10, right: 10, background: 'var(--ks-surface)', border: '1px solid var(--ks-line-2)' }} aria-label="Plein écran">
                <Maximize2 size={16} />
              </button>
              {ROOMS.map((r) => (
                <div className="kt-room" key={r.tag} style={{ left: `${r.x}%`, top: `${r.y}%`, width: `${r.w}%`, height: `${r.h}%` }}>
                  <span className="kt-room__tag">{r.tag}</span>
                </div>
              ))}
              {ASSET_PINS.map((p, i) => (
                <span className="kt-asset-pin" key={i} style={{ left: `${p.x}%`, top: `${p.y}%` }} title="Installation" />
              ))}
              {list.map((t) => (
                <span
                  key={t.person_id}
                  className="kt-tech"
                  style={{ left: `${t.x}%`, top: `${t.y}%`, background: statusColor(t.status), color: statusColor(t.status), transition: 'left .9s var(--ks-ease), top .9s var(--ks-ease)' }}
                  title={`${t.name} — ${t.task}`}
                />
              ))}
            </div>
            <div className="kt-legend">
              <span><i style={{ background: 'var(--ks-amber)' }} /> Installation</span>
              <span><i style={{ background: 'var(--ks-info)' }} /> Sur ordre de travail</span>
              <span><i style={{ background: 'var(--ks-low)' }} /> En service / ronde</span>
              <span><i style={{ background: 'var(--ks-ink-3)' }} /> Pause</span>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <div className="ks-eyebrow" style={{ marginBottom: 8 }}>Intervenants actifs</div>
            {list.map((t) => (
              <div key={t.person_id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 0', borderBottom: '1px solid var(--ks-line)' }}>
                <span style={{ position: 'relative', width: 32, height: 32, borderRadius: '50%', display: 'grid', placeItems: 'center', background: 'var(--ks-surface-3)', fontSize: 11, fontWeight: 700, color: 'var(--ks-ink-2)' }}>
                  {t.initials}
                  <span style={{ position: 'absolute', right: -1, bottom: -1, width: 9, height: 9, borderRadius: 9, background: statusColor(t.status), border: '2px solid var(--ks-surface)' }} />
                </span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600 }}>{t.name}</div>
                  <div className="ks-faint" style={{ fontSize: 11.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{t.task}</div>
                  <div style={{ fontSize: 11, marginTop: 2, display: 'inline-flex', alignItems: 'center', gap: 4, color: t.space_name ? 'var(--ks-info)' : 'var(--ks-ink-3)' }}>
                    <MapPin size={11} /> {t.space_name ?? 'hors zone délimitée'}
                  </div>
                </div>
                <span className="ks-pill" style={{ color: statusColor(t.status), height: 22 }}>{statusLabel(t.status)}</span>
              </div>
            ))}
            {list.length === 0 && <div className="ks-dim" style={{ padding: '20px 0', fontSize: 13 }}>Chargement des positions…</div>}
            <p className="ks-faint" style={{ fontSize: 11, marginTop: 14, lineHeight: 1.55 }}>
              <MapPin size={11} style={{ verticalAlign: -1 }} /> Suivi limité au temps de service · finalité dispatch &amp; sécurité du travailleur isolé · rétention courte · désactivable par tenant (OHADA). CDC §6.27.
            </p>
          </div>
        </div>
      </Card>
    </>
  );
}
