/**
 * Logos d'exécution Atlas Studio (kit de marque, apps/web/public/brand/).
 * Fichiers servis tels quels : jamais redessinés ni recolorés.
 * Seule la hauteur est fixée, la largeur suit le ratio du fichier.
 */
export const BRAND_ALT = 'Atlas Keystone — an Atlas Studio company';

const BASE = '/brand';

export function BrandLogo({
  variant = 'horizontal',
  height,
  className,
}: {
  variant?: 'horizontal' | 'vertical';
  height: number;
  className?: string;
}) {
  return (
    <img
      className={className}
      src={`${BASE}/atlas-keystone_logo_${variant}_noir.svg`}
      alt={BRAND_ALT}
      height={height}
      style={{ height, width: 'auto', display: 'block' }}
    />
  );
}

/** Icône d'application (symbole + nom), pour les espaces trop étroits pour le logo horizontal. */
export function BrandIcon({ size, className }: { size: number; className?: string }) {
  return (
    <img
      className={className}
      src={`${BASE}/icones/atlas-keystone_icon.svg`}
      alt={BRAND_ALT}
      height={size}
      style={{ height: size, width: 'auto', display: 'block' }}
    />
  );
}
