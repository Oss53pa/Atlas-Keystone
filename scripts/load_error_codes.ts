// Chargeur de keystone.error_codes depuis le catalogue des messages (A96, Catalogue partie 6 §35 bis).
//
// Usage :
//   node --experimental-strip-types scripts/load_error_codes.ts <dossier 04_Design_ecrans> <sortie.sql> <sortie.json> [fichiers .sql à contrôler…]
//
// Règles de §35 bis :
//  - source : chaque ligne des tables « Code | Déclenchement | HTTP | Catégorie » des parties 1 à 4,
//    et de la partie 6 §36.1, §37.1, §38.1 et §39.1 ; codes Supabase Auth (minuscules) et variables exclus ;
//  - chargées : catégories validation, permission, not_found, conflict, state, subscription, technical, HTTP 400 à 599 ;
//    non chargées : avertissement, attente, signal, local, enveloppe ;
//  - colonnes : code, http_status, category, alias_of (« (alias `X`) », une ligne par alias, A67),
//    owner_annex (annexe citée dans « Déclenchement », sinon celle du titre de section) ;
//  - échec sur : code en double, catégorie hors liste, statut hors 400 à 599 pour une catégorie chargée,
//    code levé par une migration (raise_error('X') absent du catalogue ;
//  - clés i18n errors.<CODE>.message, .surfaces, .action produites depuis les mêmes lignes.
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const LOADED = new Set(['validation', 'permission', 'not_found', 'conflict', 'state', 'subscription', 'technical']);
const NOT_LOADED = new Set(['avertissement', 'attente', 'signal', 'local', 'enveloppe']);
const PART6_SECTIONS = /^###\s+(36|37|38|39)\.1\b/;

interface Row { code: string; http: number | null; category: string; aliasOf: string | null; owner: string; message: string; surfaces: string; action: string; file: string; line: number }

function cells(line: string): string[] {
  return line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
}

/** Texte affichable : contenu du premier « … » de premier niveau (guillemets imbriqués gardés), sinon la cellule. */
export function displayText(cell: string): string {
  const start = cell.indexOf('«');
  if (start < 0) return cell.trim();
  let depth = 0;
  for (let i = start; i < cell.length; i++) {
    if (cell[i] === '«') depth++;
    else if (cell[i] === '»' && --depth === 0) return cell.slice(start + 1, i).trim();
  }
  return cell.slice(start + 1).trim();
}

function annexOf(text: string): string | null {
  const m = /Annexe\s+([A-Z]{1,2}[a-z]*|Admin|CO|NF|AP)\b/.exec(text);
  return m ? `Annexe ${m[1]}` : null;
}

function parseFile(path: string, part6: boolean): Row[] {
  const rows: Row[] = [];
  const lines = readFileSync(path, 'utf-8').split('\n');
  let section = '';
  let inPart6Section = !part6;
  let header: string[] | null = null;
  lines.forEach((raw, idx) => {
    if (/^##\s/.test(raw)) { section = raw; if (part6) inPart6Section = false; }
    if (part6 && /^###\s/.test(raw)) inPart6Section = PART6_SECTIONS.test(raw);
    if (!raw.trim().startsWith('|')) { header = null; return; }
    const c = cells(raw);
    if (!header) {
      if (c[0] === 'Code' && c[1]?.startsWith('Déclenchement') && c[2] === 'HTTP' && c[3] === 'Catégorie') header = c;
      return;
    }
    if (/^-+$/.test(c[0].replace(/[:\s]/g, ''))) return; // ligne de séparation
    if (!inPart6Section) return;
    const codeCell = c[0];
    const main = /^`([A-Za-z0-9_]+)`/.exec(codeCell);
    if (!main || main[1] !== main[1].toUpperCase()) return; // codes Supabase Auth en minuscules : exclus
    const iM = header.indexOf('Message'), iS = header.indexOf('Surfaces'), iA = header.indexOf('Action');
    const httpRaw = c[2];
    const http = /^\d{3}$/.test(httpRaw) ? Number(httpRaw) : null;
    const owner = annexOf(c[1]) ?? annexOf(section) ?? 'Catalogue';
    const base = { http, category: c[3].toLowerCase(), owner, message: iM >= 0 ? c[iM] ?? '' : '', surfaces: iS >= 0 ? c[iS] ?? '' : '', action: iA >= 0 ? c[iA] ?? '' : '', file: path, line: idx + 1 };
    rows.push({ code: main[1], aliasOf: null, ...base });
    for (const a of codeCell.matchAll(/alias\s+`([A-Z0-9_]+)`/g)) rows.push({ code: a[1], aliasOf: main[1], ...base });
  });
  return rows;
}

function main() {
  const [dir, outSql, outJson, ...sqlFiles] = process.argv.slice(2);
  if (!dir || !outSql || !outJson) throw new Error('Usage : load_error_codes.ts <dossier> <sortie.sql> <sortie.json> [fichiers.sql…]');
  const files = readdirSync(dir).filter((f) => /^CDC_Design_Catalogue_Messages_Partie[1-4]\.md$/.test(f)).sort();
  const rows = files.flatMap((f) => parseFile(join(dir, f), false));
  rows.push(...parseFile(join(dir, 'CDC_Design_Catalogue_Messages_Partie6.md'), true));

  const errors: string[] = [];
  const seen = new Map<string, Row>();
  const loaded: Row[] = [];
  for (const r of rows) {
    if (!LOADED.has(r.category) && !NOT_LOADED.has(r.category)) { errors.push(`${r.code} : catégorie hors liste « ${r.category} » (${r.file}:${r.line})`); continue; }
    if (!LOADED.has(r.category)) continue;
    if (r.http === null || r.http < 400 || r.http > 599) { errors.push(`${r.code} : statut ${r.http ?? 'absent'} hors 400 à 599 (${r.file}:${r.line})`); continue; }
    const prev = seen.get(r.code);
    if (prev) { errors.push(`${r.code} : en double (${prev.file}:${prev.line} et ${r.file}:${r.line})`); continue; }
    seen.set(r.code, r); loaded.push(r);
  }
  const allCodes = new Set(rows.map((r) => r.code));
  for (const f of sqlFiles) {
    for (const m of readFileSync(f, 'utf-8').matchAll(/raise_error\(\s*'([A-Z0-9_]+)'/g)) {
      if (!allCodes.has(m[1])) errors.push(`${m[1]} : levé par ${f} mais absent du catalogue`);
    }
  }
  if (errors.length) {
    console.error(`${errors.length} erreur(s) :\n` + [...new Set(errors)].join('\n'));
    process.exitCode = 1;
  }
  const q = (s: string | null) => (s === null ? 'NULL' : `'${s.replace(/'/g, "''")}'`);
  const official = loaded.filter((r) => !r.aliasOf);
  const aliases = loaded.filter((r) => r.aliasOf);
  const values = (rs: Row[]) => rs.map((r) => `  (${q(r.code)}, ${r.http}, ${q(r.category)}, ${q(r.aliasOf)}, ${q(r.owner)})`).join(',\n');
  const ins = (rs: Row[]) => rs.length ? `INSERT INTO keystone.error_codes (code, http_status, category, alias_of, owner_annex) VALUES\n${values(rs)}\nON CONFLICT (code) DO UPDATE SET http_status = EXCLUDED.http_status, category = EXCLUDED.category,\n  alias_of = EXCLUDED.alias_of, owner_annex = EXCLUDED.owner_annex;\n` : '';
  writeFileSync(outSql, `-- Généré par scripts/load_error_codes.ts depuis le catalogue des messages (A96). Ne pas modifier à la main.\n-- ${official.length} codes officiels, ${aliases.length} alias.\n${ins(official)}${ins(aliases)}`);
  const i18n: Record<string, { text: string; http: number | null; message: string; surfaces: string; action: string }> = {};
  for (const r of rows) if (!r.aliasOf && /^[A-Z]/.test(r.code)) i18n[r.code] = { text: displayText(r.message), http: r.http, message: r.message, surfaces: r.surfaces, action: r.action };
  const aliasMap = Object.fromEntries(rows.filter((r) => r.aliasOf).map((r) => [r.code, r.aliasOf]));
  writeFileSync(outJson, JSON.stringify({ errors: i18n, aliases: aliasMap }, null, 1));
  console.log(`${rows.length} lignes lues, ${official.length} codes chargés, ${aliases.length} alias, ${Object.keys(i18n).length} clés i18n.`);
}

if (process.argv[1]?.endsWith('load_error_codes.ts')) main();
