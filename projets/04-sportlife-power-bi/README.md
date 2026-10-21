# SportLife · de trois fichiers bruts à un tableau de bord de ventes

Examen de Power BI de mon master : à partir de trois fichiers Excel bruts (clients, produits, ventes 2024) d'un e-commerce d'articles de sport, j'ai préparé les données dans Power Query, construit le modèle et livré un tableau de bord des ventes. Données fictives.

## Ce que j'ai construit

- **Power Query** : types (dates lues en français, prix converti en nombre), colonnes inutiles supprimées, doublons retirés (un client, deux produits), remplissage vers le bas des dates de fiche, fractionnement de « Code postal-Ville », colonne Montant total.
- **Modèle en étoile** : la table des ventes reliée aux clients et aux produits (plusieurs à un, filtrage simple).
- **Mesures DAX** : total des ventes, quantités, nombre de commandes, panier moyen.
- **Rapport** : ventes par mois, par sexe, par âge, par marque, par ville et par produit, avec quatre cartes d'indicateurs.

## Les chiffres

19 372 € de ventes en 2024, 62 commandes, 179 articles, 312 € de panier moyen. Le running fait 52 % des ventes, Salomon est la première marque (5 566 €) et Lille la première ville (4 378 €). Les totaux du rapport ont été recalculés à partir des fichiers sources : ils correspondent au centime.

## Ce que je corrigerais en le reprenant

- la casse des noms de clients (Text.Upper au lieu de Text.Proper) ;
- la carte, construite sur la ville au lieu du code postal, sans boutons de zoom ;
- un titre masqué et une légende inutile sur l'anneau des ventes par sexe ;
- les mois en numéro, l'âge détaillé année par année, l'absence de page d'accueil ;
- la conversion du prix et le chemin des fichiers, qui dépendent du poste de travail.

Côté données, 13 clients sur 30 avaient leur âge saisi en lettres (« vingt »). Une fois remplacé par 20, 40 % des ventes tombent sur l'âge de 20 ans : le graphique par âge reflète surtout cette saisie.

## Contenu du dossier

| Fichier | Contenu |
|---|---|
| `SportLife_tableau_de_bord.pbix` | Le rapport Power BI |
| `donnees_SportLife.zip` | Les trois fichiers Excel sources |
