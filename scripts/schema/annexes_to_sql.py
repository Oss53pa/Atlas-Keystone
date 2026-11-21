#!/usr/bin/env python3
"""Assemble le SQL des annexes back-end du cahier des charges et l'éprouve sur un Postgres de test.

Usage :
  python3 -I scripts/schema/annexes_to_sql.py <dossier 03_Annexes_back_end> <sortie.json> [correctifs_post.sql]
Le dossier frère 02_Cadrage_et_referentiels est lu pour les Référentiels transverses (§1.0 : types partagés),
exécutés avant les annexes (ordre de lecture de l'Index, étape 3).
Produit la liste ordonnée des instructions SQL (une entrée par instruction : annexe, n° de bloc, texte).
  - Ordre : celui de l'Index (§2 et §3) ; le lot 12 (proposition à valider) en dernier.
  - `<communes>` et la ligne « -- colonnes A.0.2 » sont remplacés par les colonnes communes de l'Annexe A (bloc 1).
  - Un bloc dont le code (hors commentaires et chaînes) porte un autre jeton `<x>` est un gabarit : non exécuté, compté.
  - Prélude ajouté : CREATE SCHEMA (absent du corpus au 14/11/2026, écart du rapport du lot 0).
Aucune instruction n'est réécrite au-delà de ces deux substitutions.
"""
import json
import pathlib
import re
import sys

ORDER = [
    'AnnexeCO_Atlas_Core', 'AnnexeA_Socle', 'AnnexeA_Socle_Partie2', 'AnnexeA_Socle_Partie3', 'AnnexeA_Socle_Partie4',
    'AnnexeAdmin_RBAC_Notifications', 'AnnexeAdmin_RBAC_Notifications_Partie2', 'AnnexeAdmin_RBAC_Notifications_Partie3',
    'AnnexeNF_Non_Fonctionnel', 'AnnexeG_GED', 'AnnexeS_Space_Management', 'AnnexeS_Space_Management_Partie2',
    'AnnexeP_Prestataires_Mobile', 'AnnexeK_Formation_Environnement', 'AnnexePL_Planning_Equipes', 'AnnexePL_Planning_Equipes_Partie2',
    'AnnexeB_GMAO', 'AnnexeB_GMAO_Partie2', 'AnnexeB_GMAO_Partie3', 'AnnexeB_GMAO_Partie4', 'AnnexeMO_Modeles_OT', 'AnnexeAM_AMDEC_Fiabilite',
    'AnnexeC_HSSE', 'AnnexeC_HSSE_Partie2', 'AnnexeE_Budgets_Achats', 'AnnexeE_Budgets_Achats_Partie2',
    'AnnexeC_HSSE_Partie3', 'AnnexeC_HSSE_Partie4', 'AnnexeR_Reglementaire_SSI',
    'AnnexeD_Tickets_Portails', 'AnnexeD_Tickets_Portails_Partie2', 'AnnexeP_Prestataires_Mobile_Partie2', 'AnnexeTA_Travaux_Amenagement',
    'AnnexeM_Mode_Prestataire', 'AnnexeM_Mode_Prestataire_Partie2', 'AnnexeCL_Portail_Client', 'AnnexeIF_Interfaces',
    'AnnexeF_SoftFM', 'AnnexeU_Surete_Accueil', 'AnnexeU_Surete_Accueil_Partie2', 'AnnexePK_Parking',
    'AnnexeI_IoT', 'AnnexeEN_Energie', 'AnnexeQ_Reporting', 'AnnexeN_Satisfaction_Cout', 'AnnexeW_Workspace_AdHoc', 'AnnexeH_PROPH3T_Agents',
    'AnnexeAdmin_RBAC_Notifications_Partie4', 'AnnexeAP_API_Publique',
]
PROPOSAL = {'AnnexeAdmin_RBAC_Notifications_Partie4', 'AnnexeAP_API_Publique'}
PRELUDE = ['CREATE SCHEMA IF NOT EXISTS atlas_core', 'CREATE SCHEMA IF NOT EXISTS atlas_public', 'CREATE SCHEMA IF NOT EXISTS keystone']
BLOCK = re.compile(r'^```sql\s*\n(.*?)^```', re.S | re.M)
TOKEN = re.compile(r'<([a-z_]+)>')
COLDEF = re.compile(r'^\s*[a-z_]+\s+(uuid|text|timestamptz|bigint|integer|boolean|jsonb|date)\b')
# Substitutions tracées (rapport du lot 0, §6) : (bloc, texte du corpus, remplacement, motif). Chaque substitution
# doit trouver son texte exactement une fois, sinon l'assemblage échoue : le corpus a changé, la revoir.
SUBSTITUTIONS = [
    ('AnnexeM_Mode_Prestataire#2',
     'sector_code text REFERENCES keystone.client_sectors(code),',
     'sector_code text,',
     'S01 : client_sectors est unique sur (tenant_id, code), pas sur code ; clé composite ajoutée par C12 (correctifs_post.sql)'),
    ('AnnexeB_GMAO#2',
     'purchase_request_id uuid REFERENCES keystone.purchase_requests(id) ON DELETE RESTRICT,',
     'purchase_request_id uuid,',
     'S02 : dépendance circulaire work_orders et purchase_requests (Annexe E) ; clé ajoutée après coup par C14'),
    ('AnnexeC_HSSE#4',
     'security_log_id uuid REFERENCES keystone.security_log(id)',
     'security_log_id bigint REFERENCES keystone.security_log(id)',
     'S03 : security_log.id est bigint (Annexe U, journal chaîné) ; colonne alignée [interprétation validée par Oss53pa le 21/11/2026]'),
    ('AnnexeCO_Atlas_Core#5',
     "revert_deadline  timestamptz GENERATED ALWAYS AS (applied_at + interval '30 days') STORED,",
     'revert_deadline  timestamptz,',
     'S05 : timestamptz + interval non IMMUTABLE, refusé en colonne générée ; même valeur posée par trigger (C16)'),
    ('Protection_Donnees#2',
     "authority_due_at timestamptz GENERATED ALWAYS AS (aware_at + interval '72 hours') STORED,",
     'authority_due_at timestamptz,',
     'S06 : idem, délai de notification de 72 h ; même valeur posée par trigger (C16)'),
    ('AnnexeAdmin_RBAC_Notifications#6',
     "(tenant_id, COALESCE(site_id,'00000000-0000-0000-0000-000000000000'::uuid), COALESCE(surface::text,'*'))",
     '(tenant_id, site_id, surface) NULLS NOT DISTINCT',
     'S07 : cast enum vers text non IMMUTABLE en index ; NULLS NOT DISTINCT (PG 15+) est l’équivalent exact du COALESCE sentinelle'),
    ('AnnexeAdmin_RBAC_Notifications#10',
     "(tenant_id, COALESCE(user_id,'00000000-0000-0000-0000-000000000000'::uuid), COALESCE(event_key,'*'), COALESCE(category::text,'*'), channel)",
     '(tenant_id, user_id, event_key, category, channel) NULLS NOT DISTINCT',
     'S08 : idem S07'),
    ('AnnexeAdmin_RBAC_Notifications#10',
     "(tenant_id, email_lower, COALESCE(category::text,'*'))",
     '(tenant_id, email_lower, category) NULLS NOT DISTINCT',
     'S09 : idem S07'),
    ('AnnexeQ_Reporting#5',
     'CONSTRAINT uq_review_ref UNIQUE (tenant_id, ref),',
     'CONSTRAINT uq_fm_review_ref UNIQUE (tenant_id, ref),',
     'S10 : nom de contrainte déjà pris par l’Annexe P (index de même nom dans le schéma) ; renommée, règle inchangée'),
    ('AnnexeB_GMAO_Partie4#3',
     "permit_type NOT IN ('general','energized')",
     "permit_type NOT IN ('general')",
     'S12 : energized n’est pas une valeur de permit_type (Annexe C : « régime de la rubrique electrical, pas une rubrique ») ; littéral refusé par Postgres, règle inchangée'),
    ('AnnexeN_Satisfaction_Cout#5',
     'CREATE VIEW keystone.v_expenses_without_site AS',
     'CREATE VIEW keystone.v_expenses_without_site WITH (security_invoker = true) AS',
     'S13 : décision d’Oss53pa (21/11/2026) : règle de l’Annexe N retenue, avec security_invoker pour respecter la RLS par tenant'),
]
# Instructions en double strictement identiques à une définition antérieure : non rejouées (bloc, début de l'instruction).
SKIP = [
    ('AnnexeCL_Portail_Client#1', 'CREATE POLICY tickets_client_insert', 'S11 : identique à l’Annexe D'),
    ('AnnexeCL_Portail_Client#1', 'CREATE POLICY tickets_client_select', 'S11 : identique à l’Annexe D'),
    ('AnnexeE_Budgets_Achats#14', 'CREATE VIEW keystone.v_expenses_without_site', 'S13 : définition de l’Annexe E écartée, décision d’Oss53pa'),
]


def code_only(sql: str) -> str:
    """Texte sans commentaires ni chaînes : un jeton <x> dans un commentaire ou une chaîne ne fait pas un gabarit."""
    sql = re.sub(r'\$([A-Za-z_]*)\$.*?\$\1\$', ' ', sql, flags=re.S)
    sql = re.sub(r"'(?:[^']|'')*'", "''", sql)
    sql = re.sub(r'/\*.*?\*/', ' ', sql, flags=re.S)
    return re.sub(r'--[^\n]*', ' ', sql)


def split_sql(sql: str) -> list[str]:
    """Découpe en instructions : respecte les chaînes '…', les identifiants "…", les corps $tag$…$tag$ et les commentaires."""
    out, buf, i, n = [], [], 0, len(sql)
    while i < n:
        c = sql[i]
        if sql.startswith('--', i):
            j = sql.find('\n', i); j = n if j < 0 else j
            buf.append(sql[i:j]); i = j; continue
        if sql.startswith('/*', i):
            j = sql.find('*/', i + 2); j = n if j < 0 else j + 2
            buf.append(sql[i:j]); i = j; continue
        if c in "'\"":
            j = i + 1
            while j < n:
                if sql[j] == c:
                    if j + 1 < n and sql[j + 1] == c: j += 2; continue
                    break
                j += 1
            buf.append(sql[i:j + 1]); i = j + 1; continue
        m = re.match(r'\$[A-Za-z_]*\$', sql[i:])
        if m:
            tag = m.group(0); j = sql.find(tag, i + len(tag)); j = n if j < 0 else j + len(tag)
            buf.append(sql[i:j]); i = j; continue
        if c == ';':
            s = ''.join(buf).strip()
            if s and not all(l.strip().startswith('--') or not l.strip() for l in s.splitlines()): out.append(s)
            buf = []; i += 1; continue
        buf.append(c); i += 1
    s = ''.join(buf).strip()
    if s and not all(l.strip().startswith('--') or not l.strip() for l in s.splitlines()): out.append(s)
    return out


def main(src: str, out: str, post: str | None = None) -> None:
    d = pathlib.Path(src)
    files = {p.stem.replace('CDC_Atlas_Keystone_', ''): p for p in d.glob('*.md')}
    missing = sorted(set(files) - set(ORDER))
    if missing:
        sys.exit(f'Annexes absentes de ORDER : {missing}')
    cad = d.parent / '02_Cadrage_et_referentiels'
    blocks = {'Referentiels_Transverses': BLOCK.findall((cad / 'CDC_Atlas_Keystone_Referentiels_Transverses.md').read_text(encoding='utf-8'))}
    # Protection des données (ordre de lecture, étape 4) : registre des traitements, droits des personnes.
    for part in ('Protection_Donnees', 'Protection_Donnees_Partie2'):
        f = cad / f'CDC_Atlas_Keystone_{part}.md'
        if f.exists():
            blocks[part] = BLOCK.findall(f.read_text(encoding='utf-8'))
    blocks.update({name: BLOCK.findall(files[name].read_text(encoding='utf-8')) for name in ORDER})
    communes = blocks['AnnexeA_Socle'][0].strip().rstrip(',')
    stmts = [{'src': 'prelude', 'sql': s} for s in PRELUDE]
    templates, n_blocks = [], 0
    for name in ['Referentiels_Transverses', *ORDER, 'Protection_Donnees', 'Protection_Donnees_Partie2']:
        if name not in blocks:
            continue
        for i, body in enumerate(blocks[name], 1):
            n_blocks += 1
            first = next((l for l in code_only(body).splitlines() if l.strip()), '')
            if (name == 'AnnexeA_Socle' and i == 1) or COLDEF.match(first):
                templates.append(f'{name}#{i}'); continue  # définition de convention (liste de colonnes), pas du SQL
            # <communes> dans un commentaire : rester sur une ligne, sinon les colonnes sortiraient du commentaire.
            body = re.sub(r'^([^\n]*--[^\n]*)<communes>', lambda m: m.group(1) + ' '.join(communes.split()), body, flags=re.M)
            body = body.replace('<communes>', communes)
            # Convention « -- colonnes A.0.2 » (89 tables) : commentaire tenant lieu des colonnes communes.
            body = re.sub(r'^[ \t]*-- colonnes A\.0\.2[^\n]*$', communes + ',', body, flags=re.M)
            if TOKEN.search(code_only(body)):
                # Gabarit : seules les instructions sans jeton s'exécutent (ex. la fonction d'un gabarit de trigger).
                templates.append(f'{name}#{i}')
                for s in split_sql(body):
                    if not TOKEN.search(code_only(s)):
                        stmts.append({'src': f'{name}#{i}', 'proposal': name in PROPOSAL, 'sql': s})
                continue
            for src_, old, new, _why in SUBSTITUTIONS:
                if src_ == f'{name}#{i}':
                    if body.count(old) != 1:
                        sys.exit(f'Substitution introuvable ou ambiguë dans {src_} : {old!r}')
                    body = body.replace(old, new)
            # S04 (décision d'Oss53pa du 21/11/2026) : current_tenant() dans keystone, jamais dans le schéma auth réservé à Supabase.
            body = body.replace('auth.current_tenant(', 'keystone.current_tenant(')
            # S14 (décision d'Oss53pa du 21/11/2026, C01) : atlas_core.operating_mode fait foi ; l'ancien nom keystone.operating_mode
            # est réécrit (un domaine alias perdrait les opérateurs de l'énumération, ex. from_mode <> to_mode).
            body = re.sub(r'keystone\.operating_mode\b', 'atlas_core.operating_mode', body)
            for s in split_sql(body):
                if any(src_ == f'{name}#{i}' and s.lstrip().startswith(start) for src_, start, _w in SKIP):
                    continue
                stmts.append({'src': f'{name}#{i}', 'proposal': name in PROPOSAL, 'sql': s})
    if post:  # correctifs dépendant de types du corpus, rejoués avec lui
        for s in split_sql(pathlib.Path(post).read_text(encoding='utf-8')):
            stmts.append({'src': 'correctif_post', 'sql': s})
    pathlib.Path(out).write_text(json.dumps({'statements': stmts, 'templates': templates}, ensure_ascii=False), encoding='utf-8')
    print(f'{n_blocks} blocs, {len(templates)} gabarits non exécutés, {len(stmts)} instructions -> {out}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
