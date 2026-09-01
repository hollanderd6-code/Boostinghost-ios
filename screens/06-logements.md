# 06 — Logements : liste et fiche

Maquettes : `5b` (liste) et `6a` / `6b` (fiche).

## Liste

**Barre de navigation** : `chevron.left` + « Gestion » en sur-titre, grand titre « Logements », rond vert `plus` à droite. En pied de barre, **puces de groupe** en défilement horizontal : « Tous · 26 », « Jouy · 8 », « Massy · 12 », « Corbeil · 1 », « Non groupés · 5 ». Les groupes ne servent qu'à filtrer : pas de totaux par groupe, pas de niveau de navigation.

**Ce qui a un problème remonte en tête**, en carte individuelle colorée :
- terracotta pour un logement inutilisable — adresse et plateformes manquantes — avec un bouton « Préparer » ;
- or pour un manque partiel — une plateforme non connectée.

**Le reste est une seule carte de lignes.** Une ligne = nom 16/semibold + « groupe · 15 h → 10 h [· caution] » en 12.5. Rien d'autre.

L'UUID Channex, les boutons d'import d'historique, de resynchronisation, de duplication et de suppression **descendent dans la fiche**. Répétés vingt-six fois dans une liste, ils la rendent illisible.

Pied de liste : « 16 autres logements » — la liste est paginée visuellement, pas tronquée.

## Fiche — neuf blocs

**Barre de navigation** : sur-titre « groupe · adresse » (tronqué sur une ligne), grand titre = nom du logement, `ellipsis` à droite pour dupliquer / resynchroniser / supprimer.

1. **Carte Livret d'accueil**, en tête. Vignette `book`, « Livret d'accueil », « N blocs sur 3 remplis », bouton « Voir ». Barre de progression 5px. Phrase de rappel : « Il se remplit à partir des blocs Accès, Le quartier et Équipements & règles. Rien à ressaisir. »
2. **Les neuf blocs**, une carte de lignes. Chaque ligne : icône, titre, résumé de contenu, état, chevron.

```
Identité              person.text.rectangle   nom, adresse, photo, propriétaire
Séjour                clock                   heures, capacité, nuitées min
Argent                eurosign.circle         prix, ménage, taxe, commissions
Prestations payantes  gift                    tardif, anticipé, panier
Accès                 key.fill        LIVRET  code, instructions, wifi, serrure
Le quartier           map             LIVRET  parking, poubelles, commerces, transports
Équipements & règles  list.bullet     LIVRET
Assistant IA          sparkles                Q&R, faits mémorisés, raccourcis
Plateformes & prix    antenna...              Channex, BoostPrice, majorations
```

- Les trois blocs qui alimentent le livret portent une **étiquette LIVRET** verte, 10.5/bold.
- État : `checkmark.circle.fill` vert si complet ; pastille or « à remplir » si vide ; pastille grise « inactives » pour un bloc éteint volontairement.
- Le résumé de ligne montre les valeurs réelles — « 15 h → 10 h · 4 pers. · 1 nuit min », « code 5327 · wifi Livebox-E600 » — pas une liste de noms de champs.
- Le bloc actif au retour est légèrement teinté `rgba(46,139,98,.055)`.
3. **« Dupliquer ce logement »** en pied.

## Bloc ouvert

Maquette `6b`, « Le quartier ».

- **Bandeau vert** en tête pour les trois blocs du livret : « Ces quatre champs partent directement dans le livret d'accueil. Tu ne les saisis qu'ici. »
- **Une carte par champ** : intertitre 12/bold +0.08em avec icône, puis la valeur en 15, `line-height 1.55`.
- Une liste de valeurs (commerces, transports, poubelles) s'affiche en lignes séparées, pas en un paragraphe. Les poubelles portent un carré de couleur ø9 correspondant.
- « Modifier » en haut à droite fait passer la carte en champs éditables. La lecture est l'état par défaut : on consulte une fiche plus souvent qu'on ne la modifie.

## Données

Écriture : **`04-routes-relevees.md`, section 1** — `multipart/form-data`, clés camelCase, lectures tolérantes camelCase **et** snake_case, identifiant `_id` ou `id`.

Le bloc « Le quartier » correspond exactement à `practicalInfo` : `parking_details`, `trash_day`, `nearby_shops`, `public_transport`. Le découpage en neuf blocs n'exige donc aucune migration de données.

Les groupes viennent de `GET /api/property-groups` (table `property_groups`), pas du localStorage. Un logement n'appartient qu'à un seul groupe.

La carte « à préparer » doit lire `GET /api/properties/:id/sante`, qui dit **pourquoi** un logement ne se vend pas.

## Ce que la fiche règle au passage

- L'URL du livret n'est plus un champ à coller à la main : c'est le bouton « Voir ».
- « Messages automatiques » ne renvoie plus vers l'écran Messages. Les modèles vivent dans Mon compte, avec le logement en filtre.
- BoostPrice entre dans le bloc Plateformes & prix. Les règles sont recopiées dans chaque fiche, **mais l'écran de création laisse cocher plusieurs logements** : une règle écrite une fois apparaît dans chaque fiche concernée.
