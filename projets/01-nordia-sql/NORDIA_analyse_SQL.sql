/* ============================================================================
   NORDIA DISTRIBUTION - Pilotage de la performance commerciale en SQL
   Exercices 2024 et 2025 - PostgreSQL 16

   Auteure  : Sandra DOMGUO
   Base     : nordia (10 tables, 27 436 lignes de vente)
   Prérequis: 01_creation_base.sql puis 02_import_donnees.sql (création de v_ventes)

   Conventions retenues dans tout le fichier
   - CA net HT    = quantite x prix_unitaire_ht x (1 - taux_remise)
   - Coût d'achat = quantite x prix_achat_ht (table produits)
   - Marge brute  = CA net HT - coût d'achat ; taux de marge = marge / CA net
   - Périmètre    : commandes au statut 'Livrée' uniquement
   - Région       : celle du client (identique à celle du commercial, vérifié
                    sur les 7 867 commandes)
   - Montants arrondis à l'euro à l'affichage, jamais dans les calculs

   Sous chaque requête, un bloc "Résultat" reprend les chiffres obtenus et ce
   que j'en retiens. Les tris alphabétiques dépendent de la collation de la
   base (ici une collation française).

   Données fictives, générées pour l'exercice.
   ============================================================================ */


/* ============================================================================
   PARTIE 1 - Prendre en main la base et contrôler la donnée
   ============================================================================ */

-- Q1. Les 10 premiers clients par ordre alphabétique de raison sociale.
SELECT client_id,
       raison_sociale,
       segment,
       region
FROM   clients
ORDER  BY raison_sociale
LIMIT  10;
-- Résultat
--   De « Alpha Énergie SASU » (81) à « AlphaMaintenance SASU » (84).
--   Les raisons sociales ne sont pas saisies de façon homogène (« Alpha
--   Industrie » / « AlphaIndustrie ») : premier signe qu'un contrôle des
--   doublons s'impose (Q4).


-- Q2. Structure du portefeuille : nombre de clients et poids de chaque segment.
--     SUM(COUNT(*)) OVER () ramène le total général sur chaque ligne.
SELECT segment,
       COUNT(*)                                            AS nb_clients,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS poids_pct
FROM   clients
GROUP  BY segment
ORDER  BY nb_clients DESC;
-- Résultat
--   Artisan 214 (51,0 %) | PME 123 (29,3 %) | Grands comptes 53 (12,6 %)
--   | Collectivité 30 (7,1 %). La moitié des comptes sont des artisans.


-- Q3. Clients dont l'encours autorisé dépasse 200 000 €.
SELECT client_id,
       raison_sociale,
       segment,
       region,
       encours_autorise,
       delai_paiement_jours
FROM   clients
WHERE  encours_autorise > 200000
ORDER  BY encours_autorise DESC;
-- Résultat
--   30 clients, de 209 378 € à 387 638 €. Tous sont des grands comptes et tous
--   ont 60 jours de délai de paiement : les plus gros plafonds vont avec les
--   délais les plus longs. C'est là que se concentre le besoin en fonds de
--   roulement.


-- Q4. Contrôle qualité : raisons sociales présentes plusieurs fois.
--     J'ajoute le nombre de villes et de segments distincts : deux comptes
--     dans deux villes et deux segments différents ressemblent plus à des
--     homonymes qu'à un doublon de création. À trancher avec le SIREN.
SELECT raison_sociale,
       COUNT(*)                                             AS nb_comptes,
       STRING_AGG(client_id::text, ', ' ORDER BY client_id) AS identifiants,
       COUNT(DISTINCT ville)                                AS nb_villes,
       COUNT(DISTINCT segment)                              AS nb_segments
FROM   clients
GROUP  BY raison_sociale
HAVING COUNT(*) > 1
ORDER  BY nb_comptes DESC, raison_sociale;
-- Résultat
--   20 raisons sociales pour 42 comptes (18 en double, 2 en triple :
--   NovoTravaux SASU et Pro Solutions SARL).
--   Un seul cas a la même ville et le même segment : Jade Réseaux SA
--   (Versailles, PME, comptes 349 et 372). C'est le doublon le plus probable.
--   Pour les 19 autres, ville et segment diffèrent : je ne fusionne rien sans
--   vérification du SIREN.

-- Q4 bis. Poids de ces comptes dans le CA 2025 (le sujet est-il matériel ?).
WITH doublons AS (
    SELECT raison_sociale
    FROM   clients
    GROUP  BY raison_sociale
    HAVING COUNT(*) > 1
)
SELECT COUNT(DISTINCT v.client_id)                         AS comptes_concernes,
       ROUND(SUM(v.ca_net_ht))                             AS ca_2025,
       ROUND(100 * SUM(v.ca_net_ht) /
             (SELECT SUM(ca_net_ht) FROM v_ventes
              WHERE statut = 'Livrée' AND annee = 2025), 1) AS part_du_ca_pct
FROM   v_ventes v
JOIN   doublons d ON d.raison_sociale = v.raison_sociale
WHERE  v.statut = 'Livrée'
  AND  v.annee  = 2025;
-- Résultat
--   39 comptes actifs en 2025, 3 600 551 € de CA, soit 11,3 % du total.
--   Le sujet n'est pas anecdotique.

-- Q4 ter. Le doublon probable, une fois regroupé.
SELECT raison_sociale,
       STRING_AGG(DISTINCT client_id::text, ' + ') AS comptes,
       ROUND(SUM(ca_net_ht))                       AS ca_2025_consolide
FROM   v_ventes
WHERE  statut = 'Livrée'
  AND  annee  = 2025
  AND  client_id IN (349, 372)
GROUP  BY raison_sociale;
-- Résultat
--   170 936 € + 220 675 € = 391 611 €. Regroupé, Jade Réseaux SA devient le
--   premier client de NORDIA en 2025 (devant CléoIngénierie SA, 365 468 €),
--   alors qu'il n'apparaît qu'en 6e position dans le top 10 de la Q11.


-- Q5. Période couverte par les commandes et répartition par statut.
SELECT statut,
       COUNT(*)                                            AS nb_commandes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS part_pct,
       MIN(date_commande)                                  AS premiere_commande,
       MAX(date_commande)                                  AS derniere_commande
FROM   commandes
GROUP  BY statut
ORDER  BY nb_commandes DESC;
-- Résultat
--   Commandes du 01/01/2024 au 30/12/2025.
--   Livrée 7 082 (90,0 %) | En cours 473 (6,0 %) | Annulée 312 (4,0 %).
--   4 % d'annulations n'est pas alarmant pour du négoce B2B, mais le chiffre
--   mérite un suivi mensuel par canal.

-- Q5 bis. Ce que coûterait l'oubli du filtre sur le statut.
SELECT annee,
       ROUND(SUM(ca_net_ht))                                       AS ca_tous_statuts,
       ROUND(SUM(ca_net_ht) FILTER (WHERE statut = 'Livrée'))      AS ca_livre,
       ROUND(100 * (SUM(ca_net_ht) /
             SUM(ca_net_ht) FILTER (WHERE statut = 'Livrée') - 1), 1) AS surestimation_pct
FROM   v_ventes
GROUP  BY annee
ORDER  BY annee;
-- Résultat
--   Sans filtre, le CA serait surestimé de 11,4 % en 2024 et de 10,7 % en 2025
--   (35,4 M€ au lieu de 32,0 M€).


/* ============================================================================
   PARTIE 2 - Reconstituer le chiffre d'affaires (jointures écrites à la main)
   ============================================================================ */

-- Q6. CA net HT 2025, commandes livrées, sans la vue v_ventes.
SELECT ROUND(SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise)), 2) AS ca_net_ht_2025
FROM   lignes_commande l
JOIN   commandes c ON c.commande_id = l.commande_id
WHERE  c.statut = 'Livrée'
  AND  c.date_commande BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';
-- Résultat
--   31 975 711,63 €.


-- Q7. CA 2024 et 2025, variation en %. LAG ramène l'année précédente sur la ligne.
WITH ca_annuel AS (
    SELECT EXTRACT(YEAR FROM c.date_commande)::int                    AS annee,
           SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise)) AS ca
    FROM   lignes_commande l
    JOIN   commandes c ON c.commande_id = l.commande_id
    WHERE  c.statut = 'Livrée'
    GROUP  BY 1
)
SELECT annee,
       ROUND(ca)                                                AS ca_net_ht,
       ROUND(LAG(ca) OVER (ORDER BY annee))                     AS ca_n_moins_1,
       ROUND(100 * (ca / LAG(ca) OVER (ORDER BY annee) - 1), 1) AS variation_pct
FROM   ca_annuel
ORDER  BY annee;
-- Résultat
--   2024 : 29 486 717 € | 2025 : 31 975 712 € | +8,4 %.
--   La croissance est là. Reste à savoir à quel prix (partie 3).


-- Q8. CA net mensuel 2025 et nombre de commandes ; repérage du mois le plus
--     faible et du plus fort.
WITH mensuel AS (
    SELECT EXTRACT(MONTH FROM c.date_commande)::int                    AS mois,
           COUNT(DISTINCT c.commande_id)                               AS nb_commandes,
           SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise))  AS ca
    FROM   lignes_commande l
    JOIN   commandes c ON c.commande_id = l.commande_id
    WHERE  c.statut = 'Livrée'
      AND  c.date_commande BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    GROUP  BY 1
)
SELECT mois,
       nb_commandes,
       ROUND(ca) AS ca_net_ht,
       CASE WHEN ca = MAX(ca) OVER () THEN 'mois le plus fort'
            WHEN ca = MIN(ca) OVER () THEN 'mois le plus faible'
       END       AS repere
FROM   mensuel
ORDER  BY mois;
-- Résultat
--   Plus faible : août (1 563 008 €, 206 commandes).
--   Plus fort   : septembre (3 915 568 €, 406 commandes).
--   Un rapport de 1 à 2,5 qui n'a rien d'anormal : les chantiers s'arrêtent
--   l'été et repartent à la rentrée. Le même profil existe en 2024 (Q28).


-- Q9. CA net 2025 par famille de produits et poids dans le total.
SELECT p.famille,
       ROUND(SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise)))  AS ca_net_ht,
       ROUND(100 * SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise))
             / SUM(SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise))) OVER (), 1) AS poids_pct
FROM   lignes_commande l
JOIN   commandes c ON c.commande_id = l.commande_id
JOIN   produits  p ON p.produit_id  = l.produit_id
WHERE  c.statut = 'Livrée'
  AND  c.date_commande BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
GROUP  BY p.famille
ORDER  BY ca_net_ht DESC;
-- Résultat
--   Chauffage & Clim 51,7 % | Protection & Tableau 17,8 % | Outillage & EPI
--   15,3 % | Éclairage 10,9 % | Câbles & Conduits 2,3 % | Appareillage 2,0 %.
--   Une famille fait à elle seule la moitié du chiffre d'affaires.


-- Q10. Les quatre canaux de vente en 2025 : commandes, CA, panier moyen.
--      Le panier se calcule sur les commandes distinctes, pas sur les lignes.
--      J'ajoute la croissance par rapport à 2024 pour juger de la dynamique.
WITH canal AS (
    SELECT c.canal_vente,
           EXTRACT(YEAR FROM c.date_commande)::int                    AS annee,
           COUNT(DISTINCT c.commande_id)                              AS nb_commandes,
           SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise)) AS ca
    FROM   lignes_commande l
    JOIN   commandes c ON c.commande_id = l.commande_id
    WHERE  c.statut = 'Livrée'
    GROUP  BY 1, 2
)
SELECT n.canal_vente,
       n.nb_commandes,
       ROUND(n.ca)                                    AS ca_net_ht_2025,
       ROUND(100 * n.ca / SUM(n.ca) OVER (), 1)       AS part_ca_pct,
       ROUND(n.ca / n.nb_commandes)                   AS panier_moyen,
       ROUND(100 * (n.ca / p.ca - 1), 1)              AS croissance_vs_2024_pct
FROM   canal n
JOIN   canal p ON p.canal_vente = n.canal_vente AND p.annee = 2024
WHERE  n.annee = 2025
ORDER  BY ca_net_ht_2025 DESC;
-- Résultat
--   Agence    : 1 393 cdes, 11,80 M€ (36,9 %), panier 8 468 €, +0,9 %
--   Web       : 1 013 cdes,  9,04 M€ (28,3 %), panier 8 925 €, +14,5 %
--   Téléphone :   857 cdes,  7,06 M€ (22,1 %), panier 8 242 €, +24,6 %
--   EDI       :   515 cdes,  4,07 M€ (12,7 %), panier 7 913 €, -3,6 %
--   Le web a le panier le plus élevé et une croissance à deux chiffres :
--   c'est le canal à développer en priorité. L'agence reste le premier canal
--   mais ne progresse plus.


-- Q11. Top 10 des clients 2025 par CA net, avec leur poids dans le CA total.
--      Les fonctions fenêtre sont calculées avant le LIMIT : le total porte bien
--      sur l'ensemble des clients.
SELECT cl.client_id,
       cl.raison_sociale,
       cl.segment,
       cl.region,
       COUNT(DISTINCT c.commande_id)                                     AS nb_commandes,
       ROUND(SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise))) AS ca_net_ht,
       ROUND(100 * SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise))
             / SUM(SUM(l.quantite * l.prix_unitaire_ht * (1 - l.taux_remise))) OVER (), 2) AS poids_pct
FROM   lignes_commande l
JOIN   commandes c  ON c.commande_id = l.commande_id
JOIN   clients   cl ON cl.client_id  = c.client_id
WHERE  c.statut = 'Livrée'
  AND  c.date_commande BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
GROUP  BY cl.client_id, cl.raison_sociale, cl.segment, cl.region
ORDER  BY ca_net_ht DESC
LIMIT  10;
-- Résultat
--   N°1 CléoIngénierie SA (artisan, Hauts-de-France) : 365 468 €, 1,14 % du CA.
--   Le 10e (Duro Réseaux SAS) pèse 0,64 %.

-- Q11 bis. Poids cumulé du top 10 (demandé de tête, vérifié ici en SQL).
WITH ca_client AS (
    SELECT client_id, SUM(ca_net_ht) AS ca
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025
    GROUP  BY client_id
)
SELECT ROUND(SUM(ca) FILTER (WHERE rang <= 10))                    AS ca_top10,
       ROUND(100 * SUM(ca) FILTER (WHERE rang <= 10) / SUM(ca), 1) AS poids_top10_pct,
       COUNT(*)                                                    AS clients_actifs_2025
FROM  (SELECT ca, RANK() OVER (ORDER BY ca DESC) AS rang FROM ca_client) t;
-- Résultat
--   Top 10 = 2 480 545 €, soit 7,8 % du CA, sur 389 clients actifs.
--   Aucune dépendance commerciale : le risque est ailleurs (marge, encours).


/* ============================================================================
   PARTIE 3 - Analyser la marge, pas seulement le volume (vue v_ventes)
   ============================================================================ */

-- Q12. Synthèse 2025 sur une ligne.
SELECT ROUND(SUM(ca_net_ht))                                 AS ca_net_ht,
       ROUND(SUM(cout_achat_ht))                             AS cout_achat_ht,
       ROUND(SUM(marge_brute_ht))                            AS marge_brute_ht,
       ROUND(100 * SUM(marge_brute_ht) / SUM(ca_net_ht), 2)  AS taux_marge_pct
FROM   v_ventes
WHERE  statut = 'Livrée'
  AND  annee  = 2025;
-- Résultat
--   CA 31 975 712 € | coût d'achat 23 976 614 € | marge 7 999 098 € | 25,02 %.

-- Q12 bis. Même synthèse sur les deux années : c'est le fil rouge du sujet.
SELECT annee,
       ROUND(SUM(ca_net_ht))                                 AS ca_net_ht,
       ROUND(SUM(marge_brute_ht))                            AS marge_brute_ht,
       ROUND(100 * SUM(marge_brute_ht) / SUM(ca_net_ht), 2)  AS taux_marge_pct
FROM   v_ventes
WHERE  statut = 'Livrée'
GROUP  BY annee
ORDER  BY annee;
-- Résultat
--   2024 : marge 7 768 348 €, 26,35 % | 2025 : marge 7 999 098 €, 25,02 %.
--   Le CA progresse de 8,4 % mais la marge seulement de 3,0 %, et le taux
--   perd 1,33 point.


-- Q13. Taux de marge 2025 par famille, du plus faible au plus élevé, avec le
--      poids de la famille dans le CA et le rappel 2024.
WITH fam AS (
    SELECT famille,
           annee,
           SUM(ca_net_ht)      AS ca,
           SUM(marge_brute_ht) AS marge
    FROM   v_ventes
    WHERE  statut = 'Livrée'
    GROUP  BY famille, annee
)
SELECT f25.famille,
       ROUND(f25.ca)                                             AS ca_2025,
       ROUND(100 * f25.ca / SUM(f25.ca) OVER (), 1)              AS poids_ca_2025_pct,
       ROUND(100 * f25.marge / f25.ca, 2)                        AS taux_marge_2025_pct,
       ROUND(100 * f24.marge / f24.ca, 2)                        AS taux_marge_2024_pct,
       ROUND(100 * (f25.marge / f25.ca - f24.marge / f24.ca), 2) AS variation_pts
FROM   fam f25
JOIN   fam f24 ON f24.famille = f25.famille AND f24.annee = 2024
WHERE  f25.annee = 2025
ORDER  BY taux_marge_2025_pct;
-- Résultat
--   Taux le plus faible : Protection & Tableau (24,00 %), puis Chauffage &
--   Clim (24,68 %) qui pèse 51,7 % du CA. Si le mix basculait encore vers le
--   chauffage, le taux moyen baisserait mécaniquement (effet mix).
--   Mais ce n'est pas ce qui s'est passé en 2025 : les six familles perdent
--   toutes entre 1,10 et 1,79 point. Le recul vient du taux, pas du mix
--   (démonstration en B1).


-- Q14. Coût de la politique de remise par segment (2025).
SELECT segment,
       ROUND(SUM(quantite * prix_unitaire_ht))                          AS ca_avant_remise,
       ROUND(SUM(ca_net_ht))                                            AS ca_net,
       ROUND(SUM(quantite * prix_unitaire_ht) - SUM(ca_net_ht))         AS remise_accordee,
       ROUND(100 * (1 - SUM(ca_net_ht) / SUM(quantite * prix_unitaire_ht)), 2) AS taux_remise_moyen_pct
FROM   v_ventes
WHERE  statut = 'Livrée'
  AND  annee  = 2025
GROUP  BY ROLLUP (segment)
ORDER  BY GROUPING(segment), remise_accordee DESC;
-- Résultat (la ligne sans segment est le total)
--   PME 1 349 908 € (13,17 %) | Artisan 1 282 772 € (7,32 %) | Grands comptes
--   1 230 092 € (21,26 %) | Collectivité 420 564 € (15,58 %).
--   Total : 4 283 336 € de remises, 11,81 % du CA avant remise.
--   En valeur, ce sont les PME qui consomment le plus ; en taux, les grands
--   comptes, avec une remise moyenne de plus de 21 %.

-- Q14 bis. Évolution du taux de remise moyen par segment entre 2024 et 2025.
SELECT segment,
       ROUND(100 * (1 - SUM(ca_net_ht) FILTER (WHERE annee = 2024)
                      / SUM(quantite * prix_unitaire_ht) FILTER (WHERE annee = 2024)), 2) AS remise_2024_pct,
       ROUND(100 * (1 - SUM(ca_net_ht) FILTER (WHERE annee = 2025)
                      / SUM(quantite * prix_unitaire_ht) FILTER (WHERE annee = 2025)), 2) AS remise_2025_pct,
       ROUND(100 * (SUM(ca_net_ht) FILTER (WHERE annee = 2025)
                  / SUM(ca_net_ht) FILTER (WHERE annee = 2024) - 1), 1)                 AS croissance_ca_pct
FROM   v_ventes
WHERE  statut = 'Livrée'
GROUP  BY ROLLUP (segment)
ORDER  BY GROUPING(segment), segment;
-- Résultat
--   Remise moyenne : 10,00 % en 2024, 11,81 % en 2025 (+1,81 point).
--   Grands comptes : 18,30 % -> 21,26 % pour +19,4 % de CA.
--   PME            : 11,15 % -> 13,17 % pour +16,3 % de CA.
--   Les segments qui portent la croissance sont ceux où la remise a le plus
--   augmenté.


-- Q15. Rentabilité réelle de chaque commercial en 2025.
--      J'agrège d'abord les ventes par commercial, puis je joins la table
--      commerciaux : taux et fixe arrivent une seule fois par ligne, sans
--      avoir besoin de MAX() dans le GROUP BY.
WITH perf AS (
    SELECT commercial_id,
           SUM(ca_net_ht)      AS ca,
           SUM(marge_brute_ht) AS marge
    FROM   v_ventes
    WHERE  statut = 'Livrée'
      AND  annee  = 2025
    GROUP  BY commercial_id
)
SELECT co.prenom || ' ' || co.nom                                          AS commercial,
       co.region,
       ROUND(p.ca)                                                         AS ca_net,
       ROUND(p.marge)                                                      AS marge_brute,
       ROUND(p.ca * co.taux_commission)                                    AS commission,
       ROUND(co.salaire_fixe_annuel)                                       AS salaire_fixe,
       ROUND(p.marge - p.ca * co.taux_commission - co.salaire_fixe_annuel) AS marge_apres_cout_commercial,
       RANK() OVER (ORDER BY p.ca DESC)                                    AS rang_ca,
       RANK() OVER (ORDER BY p.marge - p.ca * co.taux_commission
                                     - co.salaire_fixe_annuel DESC)        AS rang_contribution
FROM   perf p
JOIN   commerciaux co ON co.commercial_id = p.commercial_id
ORDER  BY rang_contribution;
-- Résultat
--   Le haut du classement ne bouge pas : les trois commerciaux d'Île-de-France
--   restent en tête (612 572 €, 593 386 €, 576 897 € de marge après coût).
--   Le reste se recompose : Vincent Bernard passe de 6e à 5e, Élodie Laurent
--   de 11e à 10e, Nadia Chevalier de 18e à 15e. Inès Moreau finit dernière.
--   Les taux de commission vont de 0,85 % à 2,45 % du CA : à CA égal, le
--   coût d'un commercial peut presque tripler.


-- Q16. Ventes à perte en 2025 : volume, puis les 15 références les plus
--      destructrices de marge.
SELECT COUNT(*)                     AS nb_lignes_a_perte,
       ROUND(SUM(ca_net_ht))        AS ca_concerne,
       ROUND(SUM(marge_brute_ht))   AS perte_totale
FROM   v_ventes
WHERE  statut = 'Livrée'
  AND  annee  = 2025
  AND  marge_brute_ht < 0;
-- Résultat
--   63 lignes, 477 741 € de CA, 19 057 € de perte.

SELECT reference,
       libelle_produit,
       famille,
       COUNT(*)                              AS nb_lignes,
       ROUND(SUM(ca_net_ht))                 AS ca_concerne,
       ROUND(SUM(marge_brute_ht))            AS perte,
       ROUND(100 * AVG(taux_remise), 1)      AS remise_moyenne_pct
FROM   v_ventes
WHERE  statut = 'Livrée'
  AND  annee  = 2025
  AND  marge_brute_ht < 0
GROUP  BY reference, libelle_produit, famille
ORDER  BY perte
LIMIT  15;
-- Résultat
--   En tête : REF-CHA-0139 Thermostat (-6 143 €) et REF-CHA-0153 Plancher
--   chauffant (-3 688 €). Toutes les lignes à perte portent une remise
--   comprise entre 21,2 % et 29,5 %.
--   Le montant reste faible, mais il montre qu'aucun garde-fou (remise
--   maximale ou prix plancher) n'existe dans la prise de commande.


-- Q17. Classement ABC des 180 références sur la marge 2025.
--      LEFT JOIN depuis produits : une référence sans vente reste dans le
--      classement (marge nulle, classe C).
--      A jusqu'à 80 % de la marge cumulée, B jusqu'à 95 %, C au-delà.
WITH marge_ref AS (
    SELECT p.produit_id,
           p.reference,
           p.libelle_produit,
           p.famille,
           COALESCE(SUM(v.marge_brute_ht), 0) AS marge
    FROM   produits p
    LEFT   JOIN v_ventes v
           ON  v.produit_id = p.produit_id
           AND v.statut     = 'Livrée'
           AND v.annee      = 2025
    GROUP  BY p.produit_id, p.reference, p.libelle_produit, p.famille
),
cumul AS (
    SELECT *,
           SUM(marge) OVER (ORDER BY marge DESC, produit_id
                            ROWS UNBOUNDED PRECEDING) / SUM(marge) OVER () AS part_cumulee
    FROM   marge_ref
),
abc AS (
    SELECT *,
           CASE WHEN part_cumulee <= 0.80 THEN 'A'
                WHEN part_cumulee <= 0.95 THEN 'B'
                ELSE 'C'
           END AS classe
    FROM   cumul
)
SELECT reference,
       libelle_produit,
       famille,
       ROUND(marge)                    AS marge_2025,
       ROUND(100 * part_cumulee, 1)    AS part_cumulee_pct,
       classe
FROM   abc
ORDER  BY marge DESC, produit_id;
-- Résultat
--   180 lignes. La première référence (REF-CHA-0131 Sèche-serviettes,
--   826 117 €) fait à elle seule 10,3 % de la marge.

-- Q17 bis. Synthèse par classe.
WITH marge_ref AS (
    SELECT p.produit_id,
           COALESCE(SUM(v.marge_brute_ht), 0) AS marge
    FROM   produits p
    LEFT   JOIN v_ventes v
           ON  v.produit_id = p.produit_id
           AND v.statut     = 'Livrée'
           AND v.annee      = 2025
    GROUP  BY p.produit_id
),
cumul AS (
    SELECT marge,
           SUM(marge) OVER (ORDER BY marge DESC, produit_id
                            ROWS UNBOUNDED PRECEDING) / SUM(marge) OVER () AS part_cumulee
    FROM   marge_ref
),
abc AS (
    SELECT marge,
           CASE WHEN part_cumulee <= 0.80 THEN 'A'
                WHEN part_cumulee <= 0.95 THEN 'B'
                ELSE 'C'
           END AS classe
    FROM   cumul
)
SELECT classe,
       COUNT(*)                                             AS nb_references,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS part_references_pct,
       ROUND(SUM(marge))                                    AS marge_2025,
       ROUND(100 * SUM(marge) / SUM(SUM(marge)) OVER (), 1) AS part_marge_pct
FROM   abc
GROUP  BY classe
ORDER  BY classe;
-- Résultat
--   A : 38 références (21,1 %) -> 80,0 % de la marge
--   B : 52 références (28,9 %) -> 15,0 %
--   C : 90 références (50,0 %) ->  5,1 %
--   Pareto presque parfait. Les 38 références A sont celles dont il faut
--   sécuriser l'approvisionnement et renégocier les prix d'achat en premier ;
--   la moitié du catalogue (classe C) est à revoir (coûts de stockage et de
--   référencement).


/* ============================================================================
   PARTIE 4 - Confronter le réel au budget
   ============================================================================ */

-- Q18. CA budget contre CA réel 2025 par région, du plus favorable au plus
--      défavorable, avec une ligne de total.
WITH reel AS (
    SELECT region, SUM(ca_net_ht) AS ca
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025
    GROUP  BY region
),
budget AS (
    SELECT region, SUM(ca_budget_ht) AS ca
    FROM   budget_commercial
    WHERE  annee = 2025
    GROUP  BY region
),
detail AS (
    SELECT b.region, b.ca AS ca_budget, r.ca AS ca_reel
    FROM   budget b
    JOIN   reel r ON r.region = b.region
)
SELECT region,
       ROUND(ca_budget)                          AS ca_budget,
       ROUND(ca_reel)                            AS ca_reel,
       ROUND(ca_reel - ca_budget)                AS ecart,
       ROUND(100 * (ca_reel / ca_budget - 1), 1) AS ecart_pct,
       ROUND(100 * ca_reel / ca_budget, 1)       AS taux_atteinte_pct
FROM  (SELECT region, ca_budget, ca_reel, 0 AS tri FROM detail
       UNION ALL
       SELECT 'TOTAL', SUM(ca_budget), SUM(ca_reel), 1 FROM detail) t
ORDER  BY tri, ecart DESC;
-- Résultat
--   Hauts-de-France 103,1 % (+128 046 €) | Occitanie 101,5 % (+84 478 €)
--   | Île-de-France 100,6 % (+53 457 €) | Nouvelle-Aquitaine 93,3 %
--   (-221 938 €) | Grand Est 90,9 % (-400 347 €) | Auvergne-Rhône-Alpes
--   88,9 % (-802 123 €).
--   Total : 31,98 M€ réalisés pour 33,13 M€ budgétés, 96,5 % (-1,16 M€).
--   +8,4 % sur un an, mais 3,5 % sous le budget : la croissance était
--   attendue plus forte. Auvergne-Rhône-Alpes explique à elle seule 69 % de
--   l'écart.


-- Q19. Les 5 écarts de CA les plus défavorables à la maille mois x famille.
--      LEFT JOIN du budget vers le réel : une case budgétée sans vente doit
--      ressortir avec un écart égal au budget.
WITH reel AS (
    SELECT mois, famille, SUM(ca_net_ht) AS ca
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025
    GROUP  BY mois, famille
),
budget AS (
    SELECT mois, famille_produit AS famille, SUM(ca_budget_ht) AS ca
    FROM   budget_commercial
    WHERE  annee = 2025
    GROUP  BY mois, famille_produit
)
SELECT b.mois,
       b.famille,
       ROUND(b.ca)                                    AS ca_budget,
       ROUND(COALESCE(r.ca, 0))                       AS ca_reel,
       ROUND(COALESCE(r.ca, 0) - b.ca)                AS ecart,
       ROUND(100 * (COALESCE(r.ca, 0) / b.ca - 1), 1) AS ecart_pct
FROM   budget b
LEFT   JOIN reel r ON r.mois = b.mois AND r.famille = b.famille
ORDER  BY ecart
LIMIT  5;
-- Résultat
--   Août -237 378 € (-24,5 %) | février -171 125 € | juillet -146 792 €
--   | avril -138 126 € | décembre -113 898 €.
--   Les cinq concernent Chauffage & Clim. Plus qu'un mois, c'est une famille
--   qui décroche ; août est le pire (le budget n'a pas assez intégré le creux
--   d'été).


-- Q20. Décomposition de l'écart de marge 2025 par région.
--      Effet activité = (CA réel - CA budget) x taux de marge budgété
--      Effet prix/mix = (taux réel - taux budgété) x CA réel
--      Contrôle       : la somme des deux effets doit redonner l'écart total.
WITH reel AS (
    SELECT region, SUM(ca_net_ht) AS ca, SUM(marge_brute_ht) AS marge
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025
    GROUP  BY region
),
budget AS (
    SELECT region, SUM(ca_budget_ht) AS ca, SUM(marge_budget_ht) AS marge
    FROM   budget_commercial
    WHERE  annee = 2025
    GROUP  BY region
),
base AS (
    SELECT b.region,
           r.ca AS ca_r, b.ca AS ca_b, r.marge AS m_r, b.marge AS m_b
    FROM   budget b
    JOIN   reel r ON r.region = b.region
    UNION ALL
    SELECT 'TOTAL', SUM(r.ca), SUM(b.ca), SUM(r.marge), SUM(b.marge)
    FROM   budget b
    JOIN   reel r ON r.region = b.region
)
SELECT region,
       ROUND(m_b)                                             AS marge_budget,
       ROUND(m_r)                                             AS marge_reelle,
       ROUND(m_r - m_b)                                       AS ecart_total,
       ROUND((ca_r - ca_b) * (m_b / ca_b))                    AS effet_activite,
       ROUND((m_r / ca_r - m_b / ca_b) * ca_r)                AS effet_prix_mix,
       ROUND((ca_r - ca_b) * (m_b / ca_b)
             + (m_r / ca_r - m_b / ca_b) * ca_r
             - (m_r - m_b), 6)                                AS controle_doit_valoir_0
FROM   base
ORDER  BY region = 'TOTAL', ecart_total;
-- Résultat
--   Total : -565 417 € = effet activité -299 430 € + effet prix/mix -265 986 €.
--   Le contrôle vaut 0 sur toutes les lignes.
--   Auvergne-Rhône-Alpes (-247 328 €) : surtout un problème de volume
--   (-203 668 € d'effet activité).
--   Occitanie (-160 113 €) et Hauts-de-France (-135 512 €) : uniquement un
--   problème de prix (-184 497 € et -173 400 €), alors qu'elles dépassent
--   leur budget de CA.
--   Île-de-France est la seule région au-dessus de son budget de marge
--   (+51 071 €).


-- Q21. Taux d'atteinte du budget de CA cumulé à fin juin 2025 (YTD).
WITH reel AS (
    SELECT SUM(ca_net_ht) AS ca
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025 AND mois <= 6
),
budget AS (
    SELECT SUM(ca_budget_ht) AS ca
    FROM   budget_commercial
    WHERE  annee = 2025 AND mois <= 6
)
SELECT ROUND(budget.ca)                         AS budget_cumule_juin,
       ROUND(reel.ca)                           AS reel_cumule_juin,
       ROUND(reel.ca - budget.ca)               AS ecart,
       ROUND(100 * reel.ca / budget.ca, 1)      AS taux_atteinte_pct
FROM   reel, budget;
-- Résultat
--   16 207 608 € réalisés pour 16 798 673 € budgétés : 96,5 % (-591 065 €).
--   L'atterrissage annuel (96,5 % aussi) était lisible dès la fin du premier
--   semestre.


-- Q22. Alerte : régions au-dessus de leur budget de CA mais sous leur budget
--      de marge.
WITH reel AS (
    SELECT region, SUM(ca_net_ht) AS ca, SUM(marge_brute_ht) AS marge
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025
    GROUP  BY region
),
budget AS (
    SELECT region, SUM(ca_budget_ht) AS ca, SUM(marge_budget_ht) AS marge
    FROM   budget_commercial
    WHERE  annee = 2025
    GROUP  BY region
)
SELECT r.region,
       ROUND(100 * r.ca / b.ca, 1)                  AS atteinte_ca_pct,
       ROUND(100 * r.marge / b.marge, 1)            AS atteinte_marge_pct,
       ROUND(r.marge - b.marge)                     AS ecart_marge,
       ROUND(100 * r.marge / r.ca, 1)               AS taux_marge_reel_pct,
       ROUND(100 * b.marge / b.ca, 1)               AS taux_marge_budget_pct
FROM   reel r
JOIN   budget b ON b.region = r.region
WHERE  r.ca    > b.ca
  AND  r.marge < b.marge
ORDER  BY ecart_marge;
-- Résultat
--   Occitanie       : CA 101,5 %, marge 90,5 %, taux 25,7 % contre 28,9 % budgétés.
--   Hauts-de-France : CA 103,1 %, marge 88,8 %, taux 25,5 % contre 29,6 % budgétés.
--   C'est de la croissance non rentable : le volume a été obtenu par la
--   remise. Action : revoir la délégation de remise des commerciaux de ces
--   deux régions et suivre le taux de marge commande par commande.


/* ============================================================================
   PARTIE 5 - Trésorerie et risque client
   ============================================================================ */

-- Q23. Balance âgée des créances au 31/12/2025.
--      Reste dû = TTC facturé - règlements reçus au plus tard le 31/12/2025.
--      La condition de date est dans le ON du LEFT JOIN : une facture sans
--      règlement reste dans le résultat avec un reste dû égal à son TTC.
WITH reste AS (
    SELECT f.facture_id,
           f.date_echeance,
           f.montant_ttc - COALESCE(SUM(r.montant_regle), 0) AS reste_du
    FROM   factures f
    LEFT   JOIN reglements r
           ON  r.facture_id     = f.facture_id
           AND r.date_reglement <= DATE '2025-12-31'
    WHERE  f.date_facture <= DATE '2025-12-31'
    GROUP  BY f.facture_id
),
tranches AS (
    SELECT reste_du,
           CASE WHEN DATE '2025-12-31' <= date_echeance      THEN '1. Non échu'
                WHEN DATE '2025-12-31' - date_echeance <= 30 THEN '2. Retard 1 à 30 j'
                WHEN DATE '2025-12-31' - date_echeance <= 60 THEN '3. Retard 31 à 60 j'
                WHEN DATE '2025-12-31' - date_echeance <= 90 THEN '4. Retard 61 à 90 j'
                ELSE                                              '5. Retard > 90 j'
           END AS tranche
    FROM   reste
    WHERE  reste_du > 0.005
)
SELECT tranche,
       COUNT(*)                                                   AS nb_factures,
       ROUND(SUM(reste_du))                                       AS encours_ttc,
       ROUND(100 * SUM(reste_du) / SUM(SUM(reste_du)) OVER (), 1) AS part_pct
FROM   tranches
GROUP  BY tranche
ORDER  BY tranche;
-- Résultat (encours total 8 683 695 € TTC, 987 factures)
--   Non échu        441 factures  4 377 370 €  50,4 %
--   1 à 30 jours    105 factures    897 112 €  10,3 %
--   31 à 60 jours    59 factures    646 154 €   7,4 %
--   61 à 90 jours    22 factures    145 155 €   1,7 %
--   Plus de 90 j    360 factures  2 617 904 €  30,1 %
--   Près d'un tiers de l'encours a plus de trois mois de retard : 149 factures
--   jamais réglées (1,75 M€) et 211 réglées en partie (0,87 M€). Ce n'est
--   plus du retard, c'est du contentieux ou des litiges à provisionner.


-- Q24. DSO au 31/12/2025, méthode du ratio global :
--      encours client TTC / CA TTC facturé en 2025 x 365.
--      Comparaison au délai contractuel moyen, simple et pondéré par le CA.
WITH reste AS (
    SELECT f.facture_id,
           f.montant_ttc - COALESCE(SUM(r.montant_regle), 0) AS reste_du
    FROM   factures f
    LEFT   JOIN reglements r
           ON  r.facture_id     = f.facture_id
           AND r.date_reglement <= DATE '2025-12-31'
    WHERE  f.date_facture <= DATE '2025-12-31'
    GROUP  BY f.facture_id
),
encours AS (
    SELECT SUM(reste_du) AS encours_ttc FROM reste WHERE reste_du > 0.005
),
ca AS (
    SELECT SUM(f.montant_ttc)                                     AS ca_ttc_2025,
           SUM(f.montant_ttc * (f.date_echeance - f.date_facture))
             / SUM(f.montant_ttc)                                 AS delai_contractuel_pondere
    FROM   factures f
    WHERE  f.date_facture BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
)
SELECT ROUND(encours.encours_ttc)                                AS encours_ttc,
       ROUND(ca.ca_ttc_2025)                                     AS ca_ttc_2025,
       ROUND(encours.encours_ttc / ca.ca_ttc_2025 * 365, 1)      AS dso_jours,
       ROUND(ca.delai_contractuel_pondere, 1)                    AS delai_contractuel_pondere_j,
       (SELECT ROUND(AVG(delai_paiement_jours), 1) FROM clients) AS delai_contractuel_simple_j,
       ROUND(ca.ca_ttc_2025 / 365)                               AS valeur_d_un_jour_de_dso
FROM   encours, ca;
-- Résultat
--   Encours 8 683 695 € | CA TTC 2025 38 210 786 € | DSO 82,9 jours.
--   Délai contractuel moyen : 40,7 jours (pondéré par le CA), 40,3 (simple).
--   42 jours de dérive, à 104 687 € le jour : environ 4,4 M€ de trésorerie
--   immobilisée. L'écart s'explique en grande partie par la tranche à plus
--   de 90 jours de la Q23.


-- Q25. Clients dont l'encours réel au 31/12/2025 dépasse l'encours autorisé.
WITH reste AS (
    SELECT f.facture_id,
           f.client_id,
           f.montant_ttc - COALESCE(SUM(r.montant_regle), 0) AS reste_du
    FROM   factures f
    LEFT   JOIN reglements r
           ON  r.facture_id     = f.facture_id
           AND r.date_reglement <= DATE '2025-12-31'
    WHERE  f.date_facture <= DATE '2025-12-31'
    GROUP  BY f.facture_id
),
encours_client AS (
    SELECT client_id, SUM(reste_du) AS encours
    FROM   reste
    WHERE  reste_du > 0.005
    GROUP  BY client_id
)
SELECT c.client_id,
       c.raison_sociale,
       c.segment,
       ROUND(e.encours)                            AS encours_reel,
       ROUND(c.encours_autorise)                   AS encours_autorise,
       ROUND(e.encours - c.encours_autorise)       AS depassement,
       ROUND(100 * e.encours / c.encours_autorise) AS utilisation_pct
FROM   encours_client e
JOIN   clients c ON c.client_id = e.client_id
WHERE  e.encours > c.encours_autorise
ORDER  BY depassement DESC;
-- Résultat
--   121 clients dépassent leur plafond. Le premier, Solis Réseaux EURL, a
--   125 809 € d'encours pour 4 427 € autorisés (28 fois son plafond).

-- Q25 bis. Synthèse des dépassements par segment.
WITH reste AS (
    SELECT f.facture_id,
           f.client_id,
           f.montant_ttc - COALESCE(SUM(r.montant_regle), 0) AS reste_du
    FROM   factures f
    LEFT   JOIN reglements r
           ON  r.facture_id     = f.facture_id
           AND r.date_reglement <= DATE '2025-12-31'
    WHERE  f.date_facture <= DATE '2025-12-31'
    GROUP  BY f.facture_id
),
encours_client AS (
    SELECT client_id, SUM(reste_du) AS encours
    FROM   reste
    WHERE  reste_du > 0.005
    GROUP  BY client_id
)
SELECT c.segment,
       COUNT(*)                                                    AS clients_avec_encours,
       COUNT(*) FILTER (WHERE e.encours > c.encours_autorise)      AS clients_en_depassement,
       ROUND(SUM(e.encours - c.encours_autorise)
             FILTER (WHERE e.encours > c.encours_autorise))        AS depassement_cumule
FROM   encours_client e
JOIN   clients c ON c.client_id = e.client_id
GROUP  BY ROLLUP (c.segment)
ORDER  BY GROUPING(c.segment), depassement_cumule DESC NULLS LAST;
-- Résultat
--   Artisans : 99 clients en dépassement sur 177, 2 828 932 €.
--   PME : 20 sur 106 (414 962 €). Collectivités : 2 (32 424 €). Grands
--   comptes : aucun.
--   Total : 121 clients, 3 276 318 € au-dessus des plafonds. Le plafond n'est
--   visiblement pas contrôlé à la prise de commande, surtout sur les petits
--   comptes.


-- Q26. Délai contractuel contre délai réellement constaté, par segment,
--      sur les factures 2025 réglées. Délai réel = dernier règlement - facture.
WITH reglees AS (
    SELECT f.facture_id,
           f.client_id,
           f.date_echeance - f.date_facture       AS delai_contractuel,
           MAX(r.date_reglement) - f.date_facture AS delai_reel
    FROM   factures f
    JOIN   reglements r ON r.facture_id = f.facture_id
    WHERE  f.date_facture BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    GROUP  BY f.facture_id
)
SELECT c.segment,
       COUNT(*)                                          AS nb_factures,
       ROUND(AVG(g.delai_contractuel), 1)                AS delai_contractuel_j,
       ROUND(AVG(g.delai_reel), 1)                       AS delai_reel_j,
       ROUND(AVG(g.delai_reel - g.delai_contractuel), 1) AS derive_j
FROM   reglees g
JOIN   clients c ON c.client_id = g.client_id
GROUP  BY c.segment
ORDER  BY derive_j DESC;
-- Résultat
--   Artisan 30 j contractuels -> 40,6 j constatés (+10,6 j)
--   Collectivité et Grands comptes 60 j -> 69,8 j (+9,8 j)
--   PME 45 j -> 53,8 j (+8,8 j)
--   Tous les segments paient avec 9 à 11 jours de retard. En proportion du
--   délai négocié, ce sont les artisans qui dérivent le plus (+35 %).


-- Q27. Factures réglées à moins de 95 % de leur TTC (litiges ou avoirs non
--      saisis), triées par reste dû décroissant.
SELECT f.facture_id,
       f.client_id,
       c.raison_sociale,
       f.montant_ttc                                         AS montant_facture,
       SUM(r.montant_regle)                                  AS montant_regle,
       ROUND(100 * SUM(r.montant_regle) / f.montant_ttc, 1)  AS pct_regle,
       f.montant_ttc - SUM(r.montant_regle)                  AS reste_du
FROM   factures f
JOIN   reglements r ON r.facture_id = f.facture_id
JOIN   clients    c ON c.client_id  = f.client_id
GROUP  BY f.facture_id, c.raison_sociale
HAVING SUM(r.montant_regle) < 0.95 * f.montant_ttc
ORDER  BY reste_du DESC;
-- Résultat
--   268 factures, 1 104 635 € restant dus au total. La plus importante :
--   facture 914 (Méga Équipement SARL), 94 623 € facturés, 39,7 % réglés.
--   Liste à rapprocher de la comptabilité : avoir non saisi ou litige
--   ouvert, il faut savoir lequel avant de relancer.


/* ============================================================================
   PARTIE 6 - Requêtes avancées et tableau de bord
   ============================================================================ */

-- Q28 et Q29. CA mensuel sur 24 mois : mois précédent, variation M-1,
--             même mois N-1 (seule comparaison qui neutralise la saisonnalité)
--             et moyenne mobile 3 mois.
WITH ca_mensuel AS (
    SELECT annee, mois, SUM(ca_net_ht) AS ca
    FROM   v_ventes
    WHERE  statut = 'Livrée'
    GROUP  BY annee, mois
)
SELECT annee,
       mois,
       ROUND(ca)                                        AS ca_net_ht,
       ROUND(LAG(ca) OVER w)                            AS ca_mois_precedent,
       ROUND(100 * (ca / LAG(ca) OVER w - 1), 1)        AS var_vs_m_1_pct,
       ROUND(LAG(ca, 12) OVER w)                        AS ca_meme_mois_n_1,
       ROUND(100 * (ca / LAG(ca, 12) OVER w - 1), 1)    AS var_vs_n_1_pct,
       ROUND(AVG(ca) OVER (ORDER BY annee, mois
                           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS moyenne_mobile_3m
FROM   ca_mensuel
WINDOW w AS (ORDER BY annee, mois)
ORDER  BY annee, mois;
-- Résultat
--   La variation M-1 est illisible (+150,5 % en septembre 2025, -24,9 % en
--   mai) : elle mesure la saison, pas la performance.
--   Contre N-1, l'année se coupe en deux : janvier à avril entre +23 % et
--   +28 %, puis mai à décembre à plat ou en recul, sauf août (+5,0 %) et
--   septembre (+39,5 %).
--   La moyenne mobile 3 mois gomme le creux d'août (1,95 M€ au lieu de
--   1,56 M€) et montre une tendance qui culmine en novembre 2025 (3,26 M€).


-- Q30. Classement des commerciaux dans leur région (CA 2025), avec leur rang
--      sur le taux de marge pour voir si les deux classements se contredisent.
WITH perf AS (
    SELECT region,
           commercial_id,
           prenom_commercial || ' ' || nom_commercial AS commercial,
           SUM(ca_net_ht)                             AS ca,
           SUM(marge_brute_ht) / SUM(ca_net_ht)       AS taux_marge
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025
    GROUP  BY region, commercial_id, prenom_commercial, nom_commercial
)
SELECT region,
       commercial,
       ROUND(ca)                                                  AS ca_2025,
       ROUND(100 * taux_marge, 1)                                 AS taux_marge_pct,
       RANK() OVER (PARTITION BY region ORDER BY ca DESC)         AS rang_ca,
       RANK() OVER (PARTITION BY region ORDER BY taux_marge DESC) AS rang_taux_marge
FROM   perf
ORDER  BY region, rang_ca;
-- Résultat
--   Oui, et dans trois régions sur six : le premier en CA est dernier en taux
--   de marge en Île-de-France (Antoine Laurent, 24,4 %), en Occitanie
--   (Vincent Bernard, 25,3 %) et en Nouvelle-Aquitaine (Inès Moreau, 24,3 %).
--   Un objectif fixé uniquement sur le CA pousse à la remise.


-- Q31. Fidélité du portefeuille : clients 2024, clients revenus en 2025,
--      taux de rétention et nouveaux clients 2025 (commandes livrées).
WITH c2024 AS (
    SELECT DISTINCT client_id FROM v_ventes WHERE statut = 'Livrée' AND annee = 2024
),
c2025 AS (
    SELECT DISTINCT client_id FROM v_ventes WHERE statut = 'Livrée' AND annee = 2025
),
fideles AS (
    SELECT client_id FROM c2024 JOIN c2025 USING (client_id)
)
SELECT (SELECT COUNT(*) FROM c2024)                            AS clients_2024,
       (SELECT COUNT(*) FROM fideles)                          AS clients_2024_revenus_en_2025,
       ROUND(100.0 * (SELECT COUNT(*) FROM fideles)
                   / (SELECT COUNT(*) FROM c2024), 1)          AS taux_retention_pct,
       (SELECT COUNT(*) FROM c2025
        WHERE  client_id NOT IN (SELECT client_id FROM c2024)) AS nouveaux_clients_2025,
       (SELECT COUNT(*) FROM c2025)                            AS clients_2025;
-- Résultat
--   368 clients en 2024, dont 337 ont recommandé en 2025 : 91,6 % de
--   rétention, au-dessus du seuil de 90 % du négoce. 52 nouveaux clients,
--   389 clients actifs en 2025. Le portefeuille n'est pas le problème.


-- Q32. Tableau de bord mensuel 2025 du comité de direction, en une requête.
WITH reel AS (
    SELECT mois,
           SUM(ca_net_ht)              AS ca,
           SUM(marge_brute_ht)         AS marge,
           COUNT(DISTINCT commande_id) AS nb_commandes,
           COUNT(DISTINCT client_id)   AS clients_actifs
    FROM   v_ventes
    WHERE  statut = 'Livrée' AND annee = 2025
    GROUP  BY mois
),
budget AS (
    SELECT mois,
           SUM(ca_budget_ht)    AS ca,
           SUM(marge_budget_ht) AS marge
    FROM   budget_commercial
    WHERE  annee = 2025
    GROUP  BY mois
)
SELECT b.mois,
       ROUND(r.ca)                                    AS ca_reel,
       ROUND(b.ca)                                    AS ca_budget,
       ROUND(100 * r.ca / b.ca, 1)                    AS atteinte_pct,
       ROUND(r.marge)                                 AS marge_reelle,
       ROUND(100 * r.marge / r.ca, 1)                 AS taux_marge_reel_pct,
       ROUND(100 * b.marge / b.ca, 1)                 AS taux_marge_budget_pct,
       r.nb_commandes,
       ROUND(r.ca / r.nb_commandes)                   AS panier_moyen,
       r.clients_actifs,
       ROUND(SUM(r.ca) OVER cumul)                    AS ca_cumule,
       ROUND(100 * SUM(r.ca) OVER cumul
                 / SUM(b.ca) OVER cumul, 1)           AS atteinte_cumulee_pct
FROM   budget b
LEFT   JOIN reel r ON r.mois = b.mois
WINDOW cumul AS (ORDER BY b.mois ROWS UNBOUNDED PRECEDING)
ORDER  BY b.mois;
-- Résultat
--   12 lignes, une par mois (onglet Q32 du classeur NORDIA_resultats.xlsx).
--   Atteinte cumulée : 95,8 % en janvier, 96,5 % en décembre. Pire mois :
--   août (77,8 %). Le taux de marge réel est sous le budget tous les mois,
--   de 0,5 à 1,3 point : le problème de marge est structurel, pas ponctuel.


/* ============================================================================
   POUR ALLER PLUS LOIN
   ============================================================================ */

-- B1. D'où viennent les 1,33 point de taux de marge perdus entre 2024 et 2025 ?
--     Décomposition par segment :
--     Effet mix  = (poids 2025 - poids 2024) x (taux 2024 du segment - taux 2024 global)
--     Effet taux = poids 2025 x (taux 2025 - taux 2024)
--     La somme des deux effets redonne la variation du taux global.
WITH seg AS (
    SELECT segment,
           SUM(ca_net_ht)      FILTER (WHERE annee = 2024) AS ca24,
           SUM(marge_brute_ht) FILTER (WHERE annee = 2024) AS m24,
           SUM(ca_net_ht)      FILTER (WHERE annee = 2025) AS ca25,
           SUM(marge_brute_ht) FILTER (WHERE annee = 2025) AS m25
    FROM   v_ventes
    WHERE  statut = 'Livrée'
    GROUP  BY segment
),
poids AS (
    SELECT segment,
           ca24 / SUM(ca24) OVER ()          AS w24,
           ca25 / SUM(ca25) OVER ()          AS w25,
           m24 / ca24                        AS t24,
           m25 / ca25                        AS t25,
           SUM(m24) OVER () / SUM(ca24) OVER () AS t24_global
    FROM   seg
)
SELECT segment,
       ROUND(100 * w24, 1)                          AS poids_2024_pct,
       ROUND(100 * w25, 1)                          AS poids_2025_pct,
       ROUND(100 * t24, 2)                          AS taux_2024_pct,
       ROUND(100 * t25, 2)                          AS taux_2025_pct,
       ROUND(100 * (w25 - w24) * (t24 - t24_global), 3) AS effet_mix_pts,
       ROUND(100 * w25 * (t25 - t24), 3)            AS effet_taux_pts
FROM   poids
UNION ALL
SELECT 'TOTAL', 100, 100,
       ROUND(100 * SUM(w24 * t24), 2),
       ROUND(100 * SUM(w25 * t25), 2),
       ROUND(100 * SUM((w25 - w24) * (t24 - t24_global)), 3),
       ROUND(100 * SUM(w25 * (t25 - t24)), 3)
FROM   poids;
-- Résultat
--   Effet mix  : -0,14 point (dont -0,10 dû au poids croissant des grands
--                comptes, le segment le moins margé).
--   Effet taux : -1,19 point. Les quatre segments margent moins bien.
--   Conclusion : près de 90 % de la baisse vient de la façon de vendre
--   (remise), pas de ce qui est vendu.


-- B2. Ce qu'a coûté la hausse des remises : marge perdue si le taux de remise
--     moyen de chaque segment était resté à son niveau de 2024
--     (coûts d'achat et volumes inchangés).
WITH seg AS (
    SELECT segment,
           1 - SUM(ca_net_ht) FILTER (WHERE annee = 2024)
             / SUM(quantite * prix_unitaire_ht) FILTER (WHERE annee = 2024) AS remise_2024,
           1 - SUM(ca_net_ht) FILTER (WHERE annee = 2025)
             / SUM(quantite * prix_unitaire_ht) FILTER (WHERE annee = 2025) AS remise_2025,
           SUM(quantite * prix_unitaire_ht) FILTER (WHERE annee = 2025)     AS brut_2025
    FROM   v_ventes
    WHERE  statut = 'Livrée'
    GROUP  BY segment
)
SELECT segment,
       ROUND(100 * remise_2024, 2)                    AS remise_2024_pct,
       ROUND(100 * remise_2025, 2)                    AS remise_2025_pct,
       ROUND(brut_2025 * (remise_2025 - remise_2024)) AS marge_perdue_par_la_remise
FROM   seg
UNION ALL
SELECT 'TOTAL', NULL, NULL,
       ROUND(SUM(brut_2025 * (remise_2025 - remise_2024)))
FROM   seg
ORDER  BY marge_perdue_par_la_remise DESC NULLS LAST;
-- Résultat
--   588 958 € de marge perdue : PME 207 182 €, artisans 174 196 €, grands
--   comptes 171 371 €, collectivités 36 210 €.
--   Avec les remises de 2024, le taux de marge 2025 aurait été de 26,4 %,
--   soit le niveau de 2024. La dérive des remises explique à elle seule la
--   perte de marge.


-- B3. Résultat 2025 par plateforme logistique : marge des commandes expédiées
--     depuis chaque entrepôt, moins son coût fixe annuel (12 x mensuel).
WITH marge_entrepot AS (
    SELECT c.entrepot_id,
           SUM(v.ca_net_ht)      AS ca,
           SUM(v.marge_brute_ht) AS marge
    FROM   v_ventes v
    JOIN   commandes c ON c.commande_id = v.commande_id
    WHERE  v.statut = 'Livrée' AND v.annee = 2025
    GROUP  BY c.entrepot_id
)
SELECT e.libelle_entrepot,
       e.ville,
       ROUND(m.ca)                                     AS ca_expedie,
       ROUND(m.marge)                                  AS marge_brute,
       ROUND(12 * e.cout_fixe_mensuel)                 AS cout_fixe_annuel,
       ROUND(m.marge - 12 * e.cout_fixe_mensuel)       AS resultat_plateforme,
       ROUND(100 * 12 * e.cout_fixe_mensuel / m.ca, 1) AS cout_fixe_en_pct_du_ca
FROM   marge_entrepot m
JOIN   entrepots e ON e.entrepot_id = m.entrepot_id
ORDER  BY resultat_plateforme;
-- Résultat
--   Les cinq plateformes couvrent leur coût fixe. La moins rentable est la
--   Plateforme Nord (Lille) : 487 355 €, avec le coût fixe le plus lourd
--   (13,9 % du CA expédié). Bordeaux, qui dessert aussi l'Occitanie, est la
--   plus efficace (5,3 %).


-- B4. Rotation du catalogue : références sans aucune vente livrée en 2025.
SELECT COUNT(*) AS nb_references_sans_vente_2025
FROM   produits p
WHERE  NOT EXISTS (
         SELECT 1
         FROM   v_ventes v
         WHERE  v.produit_id = p.produit_id
           AND  v.statut     = 'Livrée'
           AND  v.annee      = 2025);
-- Résultat
--   0 : les 180 références ont vendu en 2025. Le sujet n'est donc pas le stock
--   dormant mais la contribution très faible de la classe C (5 % de la marge
--   pour la moitié du catalogue, Q17).

-- Fin du fichier.
