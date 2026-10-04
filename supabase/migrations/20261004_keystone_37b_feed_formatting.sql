-- keystone_37b_feed_formatting — lisibilité du fil d'attention
--   · quantités sans décimales parasites (trim_scale : 2.000 → 2)
--   · retards SLA au-delà de 48 h exprimés en jours (« SLA +115 j » plutôt que « SLA +2763 h »)
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

CREATE OR REPLACE FUNCTION keystone.fmt_overdue(p_hours numeric) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_hours > 48 THEN ceil(p_hours / 24)::int || ' j' ELSE ceil(p_hours)::int || ' h' END;
$$;
GRANT EXECUTE ON FUNCTION keystone.fmt_overdue(numeric) TO authenticated;

DO $$
DECLARE def text;
BEGIN
  def := pg_get_functiondef('keystone.attention_feed'::regproc);
  def := replace(def, $r$'SLA +' || CEIL(EXTRACT(epoch FROM (now() - w.sla_due)) / 3600)::int || ' h'$r$,
                      $r$'SLA +' || keystone.fmt_overdue(EXTRACT(epoch FROM (now() - w.sla_due)) / 3600)$r$);
  def := replace(def, $r$s.qty || ' / min ' || s.min_qty$r$, $r$trim_scale(s.qty) || ' / min ' || trim_scale(s.min_qty)$r$);
  IF position('fmt_overdue' in def) = 0 OR position('trim_scale' in def) = 0 THEN
    RAISE EXCEPTION 'attention_feed : motif introuvable, correctif non appliqué';
  END IF;
  EXECUTE def;
END $$;

COMMIT;
