# 05 — Gestion (sommaire)

Maquette : `5a`.

C'est un sommaire, pas un tableau de bord. Neuf anciennes pages web derrière quatre entrées.

## Structure

**Barre de navigation** : sur-titre « 26 logements · 3 groupes », grand titre « Gestion », recherche et initiales à droite.

1. **Alerte de préparation** — carte or, visible **seulement s'il y a quelque chose à préparer**. `exclamationmark.triangle.fill`, titre « N logement(s) à préparer », explication en une phrase, puis trois petits blocs : Airbnb `24 / 26`, Booking `25 / 26`, Expedia `—`.
   Un tiret signifie *jamais essayée*, pas *en échec*. La distinction existe déjà côté web, il faut la garder.
2. **Les quatre entrées** — une carte, quatre lignes séparées par un filet :
```
Logements      building.2                  livret, prix, accès, assistant     26
Ménage         spray.and.wipe              planning, intervenants, historique 2 aujourd'hui
Propriétaires  person.2                    clients, contrats, factures, débours
Séjours        doc.text                    factures voyageurs, cautions       4 cautions
```
   Vignette 40×40 rayon 12 ; menthe pour Logements, or pour Ménage, gris neutre pour les deux autres. Le chiffre à droite est celui qui bouge — pas un total figé.
3. **« RACCOURCIS »** — « Ajouter un logement » avec le quota `26 / 51`, et « Resynchroniser les plateformes ».

## Droits

Chaque entrée n'apparaît que si le droit correspondant est accordé : `can_view_properties`, `can_view_cleaning`, `can_view_owners` (T4), `can_view_invoices`. Une seule entrée autorisée → l'onglet Gestion ouvre directement ce sous-écran, sans passer par le sommaire.
