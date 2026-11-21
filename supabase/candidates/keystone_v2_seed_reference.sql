-- Référentiels minimaux du socle (non appliqué). Devises : Registre I01 (XOF et XAF, exposant 0, ISO 4217).
-- Pays : les quatre pays cités par le corpus (Lot 1 §7.6) ; zone monétaire et fuseau sont des faits ;
-- la locale fr-<pays> est un choix par défaut, modifiable par le tenant.
INSERT INTO atlas_core.currencies (code, minor_unit, label) VALUES
  ('XOF', 0, 'Franc CFA (BCEAO)'),
  ('XAF', 0, 'Franc CFA (BEAC)')
ON CONFLICT (code) DO UPDATE SET minor_unit = EXCLUDED.minor_unit, label = EXCLUDED.label;
INSERT INTO atlas_core.country_config (country_code, currency, default_timezone, default_locale, zone) VALUES
  ('CI', 'XOF', 'Africa/Abidjan',   'fr-CI', 'UEMOA'),
  ('SN', 'XOF', 'Africa/Dakar',     'fr-SN', 'UEMOA'),
  ('CM', 'XAF', 'Africa/Douala',    'fr-CM', 'CEMAC'),
  ('GA', 'XAF', 'Africa/Libreville','fr-GA', 'CEMAC')
ON CONFLICT (country_code) DO NOTHING;
