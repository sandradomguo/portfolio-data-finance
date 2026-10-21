# NORDIA Distribution · pourquoi 8,4 % de croissance ont coûté 1,3 point de marge

Analyse SQL (PostgreSQL 16) de la performance commerciale d'un distributeur B2B de matériel électrique : 10 tables, 27 436 lignes de commande, exercices 2024 et 2025. Jeu de données fictif, construit pour l'exercice.

## La question

En 2025, le chiffre d'affaires de NORDIA progresse de 8,4 %, mais le taux de marge perd 1,3 point et le budget n'est pas tenu. La direction voulait comprendre pourquoi, et savoir où agir.

## Les chiffres clés

| Indicateur | 2024 | 2025 | Budget 2025 |
|---|---:|---:|---:|
| CA net HT | 29,49 M€ | 31,98 M€ | 33,13 M€ |
| Marge brute | 7,77 M€ | 8,00 M€ | 8,56 M€ |
| Taux de marge brute | 26,3 % | 25,0 % | 25,8 % |
| Remise moyenne | 10,0 % | 11,8 % | |
| DSO au 31/12 | | 82,9 jours | délai contractuel : 40,7 jours |

## Ce que montrent les requêtes

- **La croissance a été obtenue par la remise.** Sur 1,33 point de taux de marge perdu, 1,19 vient de la baisse de marge à l'intérieur de chaque segment, 0,14 seulement du mix (requête B1). La hausse des remises coûte 589 k€ de marge (B2).
- **Le manque au budget vient d'une région et d'une famille.** Auvergne-Rhône-Alpes manque surtout du volume ; Occitanie et Hauts-de-France dépassent leur budget de CA mais l'effet prix leur coûte 358 k€ de marge (Q20). Août finit à 77,8 % de son budget (Q32).
- **La trésorerie se dégrade.** 2,62 M€ d'encours, soit 30 % du total, ont plus de 90 jours de retard (Q23) ; 121 clients dépassent leur plafond d'encours (Q25).

## Quatre requêtes à lire en priorité

| Requête | Ce qu'elle fait | Technique |
|---|---|---|
| Q32 | Tableau de bord mensuel du comité, en une requête | CTE, jointure depuis le budget, fenêtre nommée pour les cumuls |
| Q20 | Écart de marge par région, en effet activité et effet prix/mix | Décomposition contrôlée : la somme des effets redonne l'écart |
| Q23 | Balance âgée au 31/12/2025 | Condition de date dans le ON du LEFT JOIN |
| Q17 | Classement ABC des 180 références | SUM() OVER avec ROWS UNBOUNDED PRECEDING |

## Recommandations

1. Encadrer la remise (grille par segment et famille, validation au-delà, objectifs commerciaux sur la marge) : 363 k€ de marge par point de remise récupéré.
2. Relance à J+5, blocage au-delà du plafond d'encours, provision des créances à plus de 90 jours : 1,9 M€ de trésorerie si le DSO revient à 65 jours.
3. Renégocier les 38 références de classe A (77 % des achats) : 184 k€ par point de baisse obtenu.

## Contenu du dossier

| Fichier | Contenu |
|---|---|
| `NORDIA_analyse_SQL.sql` | Les 32 requêtes et les analyses complémentaires, chacune suivie de son résultat et de ce que j'en retiens |
| `Note_synthese_NORDIA.pdf` | La note d'une page au comité de direction |
| `NORDIA_resultats.xlsx` | Toutes les sorties, un onglet par requête |
| `donnees_NORDIA.zip` | Les 10 tables en CSV et les scripts de création de la base |

Pour rejouer l'analyse : créer la base avec les scripts de `donnees_NORDIA.zip`, puis exécuter `NORDIA_analyse_SQL.sql` dans PostgreSQL 16 (pgAdmin ou psql).
