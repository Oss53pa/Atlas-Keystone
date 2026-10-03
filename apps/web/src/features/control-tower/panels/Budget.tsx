import { useEffect, useState } from 'react';
import { Wallet, TrendingUp, AlertTriangle } from 'lucide-react';
import { Card, StatBig, ProgressRows, TrendChart, Legend, BarChart } from '@keystone/ui';
import { money, format, budgetPosition, add, type Money } from '@keystone/domain';
import type { BudgetOverview } from '@keystone/domain/db/keystone';
import { BUDGET } from '../../../data/dashboards.ts';
import { fetchBudgetOverview } from '../../../data/budget.ts';
import { CardTitle, type PanelProps } from '../shared.tsx';

const fcfa = (n: number) => format(money(n, 'XOF'));
const fcfaM = (m: Money) => format(m);

function BudgetBar({ title, b }: { title: string; b: { budget: number; committed: number; spent: number } }) {
  const pos = budgetPosition(money(b.budget, 'XOF'), money(b.committed, 'XOF'), money(b.spent, 'XOF'));
  const seg = (v: number) => `${(v / b.budget) * 100}%`;
  return (
    <Card>
      <CardTitle title={title} sub={`Enveloppe ${fcfa(b.budget)}`} right={<span className="ks-mono ks-pill">{(pos.executionRate * 100).toFixed(0)} % exéc.</span>} />
      <div style={{ display: 'flex', height: 16, borderRadius: 6, overflow: 'hidden', marginTop: 18, background: 'var(--ks-surface-3)' }}>
        <span className="ks-grow-x" style={{ width: seg(b.spent), background: 'var(--ks-high)' }} title="Réalisé" />
        <span className="ks-grow-x" style={{ width: seg(b.committed), background: 'var(--ks-amber)', animationDelay: '80ms' }} title="Engagé" />
      </div>
      <div style={{ marginTop: 16 }}>
        <Legend items={[
          { label: 'Réalisé', color: 'var(--ks-high)', value: fcfa(b.spent) },
          { label: 'Engagé', color: 'var(--ks-amber)', value: fcfa(b.committed) },
          { label: 'Disponible', color: 'var(--ks-low)', value: fcfaM(pos.available) },
        ]} />
      </div>
    </Card>
  );
}

export function Budget(_: PanelProps) {
  const [live, setLive] = useState<BudgetOverview | null>(null);
  useEffect(() => { fetchBudgetOverview().then(setLive).catch(() => {}); }, []);

  const opex = live?.opex ?? BUDGET.opex;
  const capex = live?.capex ?? BUDGET.capex;
  const isLive = !!live?.opex;

  const totalBudget = opex.budget + capex.budget;
  const totalCommitted = opex.committed + capex.committed;
  const totalSpent = opex.spent + capex.spent;
  const available = add(
    budgetPosition(money(opex.budget, 'XOF'), money(opex.committed, 'XOF'), money(opex.spent, 'XOF')).available,
    budgetPosition(money(capex.budget, 'XOF'), money(capex.committed, 'XOF'), money(capex.spent, 'XOF')).available,
  );

  return (
    <>
      {isLive && (
        <div className="ks-eyebrow ks-reveal" style={{ marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
          <span className="ks-sync" style={{ fontSize: 11 }}><span className="ks-sync__dot" /> LIVE</span> budgets calculés en base · Money.ts (XOF)
        </div>
      )}
      <div className="kt-dash kt-dash--4 ks-reveal">
        <Card><StatBig label="Budget total" icon={<Wallet size={15} />} value={fcfa(totalBudget)} sub="OPEX + CAPEX · exercice 2026" /></Card>
        <Card><StatBig label="Engagé" accent="var(--ks-amber)" value={fcfa(totalCommitted)} sub="réservé (commitments)" /></Card>
        <Card><StatBig label="Réalisé" accent="var(--ks-high)" value={fcfa(totalSpent)} sub="dépenses encourues" /></Card>
        <Card><StatBig label="Disponible" accent="var(--ks-low)" value={fcfaM(available)} sub="Budget − Engagé − Réalisé" /></Card>
      </div>

      <div className="kt-dash kt-dash--2" style={{ marginTop: 18 }}>
        <div className="ks-reveal" style={{ animationDelay: '120ms' }}><BudgetBar title="OPEX" b={opex} /></div>
        <div className="ks-reveal" style={{ animationDelay: '180ms' }}><BudgetBar title="CAPEX" b={capex} /></div>
      </div>

      <div className="kt-dash kt-dash--21" style={{ marginTop: 18 }}>
        <Card className="ks-reveal" style={{ animationDelay: '240ms' }}>
          <CardTitle title="Consommation par poste" sub="% d’exécution budgétaire" />
          <div style={{ marginTop: 18 }}>
            <ProgressRows max={100} rows={BUDGET.cascade.map((c) => ({ label: c.label, value: c.value, color: c.color, right: <span className="ks-mono">{c.value} %</span> }))} />
          </div>
        </Card>
        <Card className="ks-reveal" style={{ animationDelay: '320ms' }}>
          <CardTitle title="Prévision d’exécution" sub="réalisé + projection (PROPH3T)" right={<span className="ks-pill" style={{ color: 'var(--ks-high)' }}><TrendingUp size={13} /> 101 % projeté</span>} />
          <div style={{ marginTop: 12 }}>
            <TrendChart series={BUDGET.forecast} projectionFrom={BUDGET.forecastProjFrom} height={130} color="var(--ks-info)" />
          </div>
          <div style={{ marginTop: 8 }}>
            {BUDGET.overruns.map((o) => (
              <div key={o.label} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0', borderTop: '1px solid var(--ks-line)', fontSize: 13 }}>
                <AlertTriangle size={14} color="var(--ks-high)" />
                <span style={{ flex: 1 }}>{o.label}</span>
                <span className="ks-risk ks-risk--high">{o.delta}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <Card className="ks-reveal" style={{ marginTop: 18, animationDelay: '380ms' }}>
        <CardTitle title="Cycle achats" sub="Demande d’achat → bon de commande → réception" />
        <div style={{ marginTop: 16 }}><BarChart data={BUDGET.purchase} height={130} /></div>
      </Card>
    </>
  );
}
