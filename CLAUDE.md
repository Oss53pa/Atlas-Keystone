# Atlas-Keystone

## Règles de travail et de déploiement

Ces règles s'appliquent à toute session de travail sur ce dépôt, humaine ou assistée par Claude.

1. Travailler en local et regrouper les modifications. Ne pas pousser à chaque petite modification, on pousse un lot cohérent, une seule fois.
2. Ne pousser sur la branche de production, `main`, qu'un lot terminé, testé et validé par Oss53pa.
3. Ne jamais créer de branche qui déclenche un déploiement Vercel sans l'accord explicite d'Oss53pa. Ce dépôt n'est relié à aucun projet Vercel aujourd'hui, le relier demande aussi cet accord.
4. La base Supabase est partagée par toutes les applications Atlas Studio. Chaque modification de structure (migration, création ou suppression de table, de vue ou de fonction, `notify pgrst`) oblige l'API à relire la liste de toutes les tables : pendant environ une minute, toutes les applications du projet ralentissent (requêtes de 10 à 35 s relevées le 17.10.2026). Les modifications de structure se regroupent donc en un seul lot et s'appliquent en une fois, en dehors des heures d'utilisation : en semaine avant 7 h ou après 20 h (heure d'Abidjan, GMT), ou le week-end. Une correction urgente fait exception, en prévenant Oss53pa.
