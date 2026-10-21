// =============================================================================
//  Groupe HÉLIOS · Requêtes Power Query (M)
//  À coller dans l'éditeur avancé, une requête par table.
//  Dossier_Donnees est un paramètre texte : chemin du dossier des fichiers Excel,
//  terminé par une barre oblique inverse.
// =============================================================================

// ---------------------------------------------------------------- Dossier_Donnees (paramètre)
"C:\HELIOS\02_Donnees\" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

// ---------------------------------------------------------------- Dim_Date
let
    Source = Excel.Workbook(File.Contents(Dossier_Donnees & "HELIOS_donnees_PowerBI.xlsx"), null, true),
    Feuille = Source{[Item="Dim_Date",Kind="Sheet"]}[Data],
    EnTetes = Table.PromoteHeaders(Feuille, [PromoteAllScalars=true]),
    Types = Table.TransformColumnTypes(EnTetes, {{"Date", type date}, {"Annee", Int64.Type}, {"Num_mois", Int64.Type}, {"Nom_mois", type text}, {"Mois_abrege", type text}, {"Trimestre", type text}, {"Annee_mois", type text}, {"Debut_de_mois", type date}, {"Index_mois", Int64.Type}, {"Jour_semaine", Int64.Type}, {"Est_fin_de_mois", type logical}})
in
    Types

// ---------------------------------------------------------------- Dim_Entite
let
    Source = Excel.Workbook(File.Contents(Dossier_Donnees & "HELIOS_donnees_PowerBI.xlsx"), null, true),
    Feuille = Source{[Item="Dim_Entite",Kind="Sheet"]}[Data],
    EnTetes = Table.PromoteHeaders(Feuille, [PromoteAllScalars=true]),
    Types = Table.TransformColumnTypes(EnTetes, {{"Entite_ID", type text}, {"Business_Unit", type text}, {"Pays", type text}, {"Ville", type text}, {"Activite", type text}, {"Directeur", type text}})
in
    Types

// ---------------------------------------------------------------- Dim_CentreCout
let
    Source = Excel.Workbook(File.Contents(Dossier_Donnees & "HELIOS_donnees_PowerBI.xlsx"), null, true),
    Feuille = Source{[Item="Dim_CentreCout",Kind="Sheet"]}[Data],
    EnTetes = Table.PromoteHeaders(Feuille, [PromoteAllScalars=true]),
    Types = Table.TransformColumnTypes(EnTetes, {{"CC_ID", type text}, {"Centre_de_cout", type text}, {"Type_centre", type text}, {"Entite_ID", type text}})
in
    Types

// ---------------------------------------------------------------- Dim_Compte
let
    Source = Excel.Workbook(File.Contents(Dossier_Donnees & "HELIOS_donnees_PowerBI.xlsx"), null, true),
    Feuille = Source{[Item="Dim_Compte",Kind="Sheet"]}[Data],
    EnTetes = Table.PromoteHeaders(Feuille, [PromoteAllScalars=true]),
    // Le numéro de compte est un code, pas un nombre : on le force en texte
    Types = Table.TransformColumnTypes(EnTetes, {{"Compte", type text}, {"Libelle_compte", type text}, {"Rubrique_PnL", type text}, {"Type_compte", type text}, {"Sens", Int64.Type}, {"Ordre_PnL", Int64.Type}}),
    // Ordre unique par rubrique, pour trier Rubrique_PnL dans l'ordre du compte de résultat
    Ordres = Table.Group(Types, {"Rubrique_PnL"}, {{"Ordre_rubrique", each List.Min([Ordre_PnL]), Int64.Type}}),
    Fusion = Table.NestedJoin(Types, {"Rubrique_PnL"}, Ordres, {"Rubrique_PnL"}, "Ordres", JoinKind.LeftOuter),
    Resultat = Table.ExpandTableColumn(Fusion, "Ordres", {"Ordre_rubrique"}, {"Ordre_rubrique"})
in
    Resultat

// ---------------------------------------------------------------- Faits_Realise
let
    Source = Excel.Workbook(File.Contents(Dossier_Donnees & "HELIOS_donnees_PowerBI.xlsx"), null, true),
    Feuille = Source{[Item="Faits_Realise",Kind="Sheet"]}[Data],
    EnTetes = Table.PromoteHeaders(Feuille, [PromoteAllScalars=true]),
    Types = Table.TransformColumnTypes(EnTetes, {{"Date", type date}, {"Entite_ID", type text}, {"CC_ID", type text}, {"Compte", type text}, {"Montant", type number}})
in
    Types

// ---------------------------------------------------------------- Faits_Budget
let
    Source = Excel.Workbook(File.Contents(Dossier_Donnees & "HELIOS_donnees_PowerBI.xlsx"), null, true),
    Feuille = Source{[Item="Faits_Budget",Kind="Sheet"]}[Data],
    EnTetes = Table.PromoteHeaders(Feuille, [PromoteAllScalars=true]),
    Types = Table.TransformColumnTypes(EnTetes, {{"Date", type date}, {"Entite_ID", type text}, {"CC_ID", type text}, {"Compte", type text}, {"Montant", type number}})
in
    Types

// ---------------------------------------------------------------- Faits_Effectifs
let
    Source = Excel.Workbook(File.Contents(Dossier_Donnees & "Effectifs_format_tableau_croise.xlsx"), null, true),
    Feuille = Source{[Item="Effectifs ETP",Kind="Sheet"]}[Data],
    // Trois lignes de titre et une ligne vide au-dessus du tableau de la DRH
    SansTitres = Table.Skip(Feuille, 4),
    EnTetes = Table.PromoteHeaders(SansTitres, [PromoteAllScalars=true]),
    // Un mois par colonne : on dépivote pour obtenir une ligne par mois, BU et catégorie
    Depivote = Table.UnpivotOtherColumns(EnTetes, {"Entite_ID", "Business_Unit", "Categorie"}, "Mois", "ETP"),
    MoisEnDate = Table.TransformColumns(Depivote, {{"Mois", each Date.FromText(Text.From(_) & "-01"), type date}}),
    SansLibelle = Table.RemoveColumns(MoisEnDate, {"Business_Unit"}),
    Types = Table.TransformColumnTypes(SansLibelle, {{"Entite_ID", type text}, {"Categorie", type text}, {"ETP", type number}})
in
    Types

// ---------------------------------------------------------------- Pont_EBITDA
let
    // Table d'étapes du pont d'EBITDA (graphique en cascade), sans lien avec le modèle
    Source = #table(
        type table [Etape = text, Ordre = Int64.Type],
        {
            {"EBITDA budget", 0},
            {"Chiffre d'affaires", 1},
            {"Achats consommés", 2},
            {"Charges externes", 3},
            {"Impôts et taxes", 4},
            {"Charges de personnel", 5},
            {"Autres charges", 6}
        }
    )
in
    Source

// ---------------------------------------------------------------- _Mesures
let
    // Table vide qui sert uniquement à ranger les mesures
    Source = #table(type table [Colonne = text], {})
in
    Source
