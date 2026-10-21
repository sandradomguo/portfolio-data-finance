# Groupe HÉLIOS · 5 % de croissance, 2,16 M€ d'EBITDA en moins que prévu

Rapport Power BI d'analyse des écarts budgétaires d'un groupe industriel et de services à quatre business units (réel 2024-2025, budget 2025). Jeu de données fictif, construit pour l'exercice.

## La question

Le groupe a presque tenu son budget de chiffre d'affaires (49,52 M€, −0,8 %) mais finit avec 4,99 M€ d'EBITDA pour 7,15 M€ budgétés. Le comité de direction voulait savoir d'où venait l'écart, et où agir.

## Le pont d'EBITDA

| Étape | M€ |
|---|---:|
| EBITDA budget | 7,15 |
| Chiffre d'affaires | −0,40 |
| Achats consommés | −0,69 |
| Charges externes | −0,09 |
| Charges de personnel | −0,99 |
| Impôts et autres charges | +0,01 |
| **EBITDA réel** | **4,99** |

Deux rubriques expliquent 78 % de l'écart : les achats et le personnel. Deux business units le portent : Industrie (−1,32 M€, un manque d'activité) et Services (−0,63 M€, une masse salariale au-delà du budget).

## Le modèle

Modèle en étoile : trois tables de faits (réel, budget, effectifs) et quatre dimensions (date, entité, centre de coût, compte). Les montants arrivent en valeur absolue et le plan de comptes porte le sens (+1 produit, −1 charge), comme dans une balance comptable : le compte de résultat se construit avec un SUMX qui applique ce sens, et un écart positif est toujours favorable.

Le fichier des effectifs, livré en tableau croisé, est dépivoté dans Power Query. Le dossier des sources est un paramètre : le rapport s'actualise en un clic.

## Le rapport

| Page | Contenu |
|---|---|
| Synthèse groupe | Indicateurs clés, CA mensuel contre budget et N-1, EBITDA par business unit |
| Analyse des écarts | Pont d'EBITDA, compte de résultat réel contre budget, dix centres de coût les plus en retard |
| Focus business unit | Compte de résultat d'une BU, détail par centre de coût, EBITDA mensuel lissé sur trois mois |

## Recommandations

1. Renégocier les prix matières et indexer les prix de vente sur le coût des achats : 0,50 M€ d'EBITDA par point d'achats sur CA récupéré.
2. Revoir les effectifs de HÉLIOS Services : 0,59 M€ si le coût moyen par ETP revient au niveau 2024.
3. Plan commercial chiffré pour Industrie et Benelux : 0,23 M€ d'EBITDA si le CA budgété est atteint.

## Contenu du dossier

| Fichier | Contenu |
|---|---|
| `HELIOS_tableau_de_bord_donnees_incluses.pbit` | Le rapport Power BI (modèle, 46 mesures, trois pages) avec ses données : il s'ouvre directement |
| `HELIOS_tableau_de_bord.pbit` | Le même rapport, relié aux fichiers sources par le paramètre `Dossier_Donnees` |
| `HELIOS_mesures.dax` | Les mesures DAX, commentées |
| `HELIOS_requetes_PowerQuery.m` | Les requêtes Power Query |
| `Note_synthese_HELIOS.pdf` | La note au directeur général |
| `donnees_HELIOS.zip` | Le classeur source et le fichier des effectifs |

Pour voir le rapport, il suffit d'ouvrir `HELIOS_tableau_de_bord_donnees_incluses.pbit` avec Power BI Desktop : les données se chargent seules. Pour repartir des fichiers sources, décompresser `donnees_HELIOS.zip` dans un dossier, ouvrir `HELIOS_tableau_de_bord.pbit` et indiquer le chemin de ce dossier (terminé par `\`) quand Power BI demande le paramètre `Dossier_Donnees`.
