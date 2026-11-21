#!/usr/bin/env python3
"""Écrit le schéma candidat : instructions réussies à l'essai, dans l'ordre réel de réussite (ordre des dépendances).

Usage : python3 -I scripts/schema/emit_candidate.py <instructions.json> <rapport.json> <sortie.sql>
Le fichier produit n'est PAS une migration : il se range hors de supabase/migrations et ne s'applique qu'après
zéro écart bloquant et accord d'Oss53pa (CLAUDE.md, règle 4). Les correctifs de correctifs_corpus.sql le précèdent.
"""
import json
import sys


def main(src: str, rep: str, out: str) -> None:
    st = json.load(open(src, encoding='utf-8'))['statements']
    r = json.load(open(rep, encoding='utf-8'))
    lines = ['-- Schéma candidat Atlas Keystone, généré par scripts/schema/emit_candidate.py. NE PAS APPLIQUER EN L\'ÉTAT.',
             f"-- {len(r['order'])} instructions réussies sur {r['total']} ; {len(r['failed'])} écarts restants : docs/lot0 §6.",
             '-- Prérequis : extensions (pgcrypto, postgis, vector, pg_trgm, btree_gist, unaccent, pg_jsonschema),',
             '-- puis scripts/schema/correctifs_corpus.sql.', 'BEGIN;', "SET LOCAL search_path = keystone, atlas_core, public, extensions;", '']
    for i in r['order']:
        s = st[i]
        lines.append(f"-- {s['src']}{' (proposition, lot 12)' if s.get('proposal') else ''}")
        lines.append(s['sql'].rstrip().rstrip(';') + ';')
        lines.append('')
    lines.append('COMMIT;')
    open(out, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print(f"{len(r['order'])} instructions -> {out}")


if __name__ == '__main__':
    main(*sys.argv[1:4])
