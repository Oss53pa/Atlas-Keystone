#!/usr/bin/env python3
"""Exécute les instructions produites par annexes_to_sql.py sur un Postgres de TEST, en passes successives.

Usage : python3 -I scripts/schema/run_fixpoint.py <instructions.json> <dsn> <rapport.json>
Chaque instruction s'exécute seule (autocommit). Celles qui échouent sont rejouées à la passe suivante,
tant qu'une passe en fait réussir au moins une : l'ordre de lecture des annexes n'est pas l'ordre des
dépendances. Les échecs restants sont de vrais écarts du corpus (ou un bouchon Supabase manquant).
Ne jamais viser une base Supabase partagée : la cible doit être jetable.
"""
import json
import sys

import psycopg


def main(src: str, dsn: str, out: str) -> None:
    data = json.load(open(src, encoding='utf-8'))
    pending = list(range(len(data['statements'])))
    last_err: dict[int, str] = {}
    passes = 0
    with psycopg.connect(dsn, autocommit=True) as cx:
        while pending:
            passes += 1
            failed = []
            for i in pending:
                try:
                    cx.execute(data['statements'][i]['sql'])
                    last_err.pop(i, None)
                except psycopg.Error as e:
                    last_err[i] = (e.diag.message_primary or str(e)).strip()
                    failed.append(i)
            print(f'passe {passes} : {len(pending) - len(failed)} réussies, {len(failed)} en échec')
            if len(failed) == len(pending):
                break
            pending = failed
    res = [{'src': data['statements'][i]['src'], 'proposal': data['statements'][i].get('proposal', False),
            'error': last_err[i], 'sql': data['statements'][i]['sql'][:300]} for i in sorted(last_err)]
    json.dump({'passes': passes, 'total': len(data['statements']), 'failed': res, 'templates': data['templates']},
              open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{len(data["statements"])} instructions, {len(res)} en échec après {passes} passes -> {out}')


if __name__ == '__main__':
    main(*sys.argv[1:4])
