-- Recalage de la grille SODECI indicative de démo (tenant démo) : supprime de fausses alertes au contrôle des factures d'eau.
BEGIN;
UPDATE keystone.utility_tariff_bands b SET unit_price = v.p
FROM keystone.utility_tariffs t, (VALUES (0::numeric, 520::numeric), (500, 580), (2000, 600)) v(f, p)
WHERE b.tariff_id = t.id AND t.code = 'SODECI-PRO' AND t.tenant_id = 'a0000000-0000-4000-8000-000000000001' AND b.from_qty = v.f;
COMMIT;
