# 03 — Calendrier

Maquettes : `4a` (Planning) et `4b` (Revenus). Fusion de `reservations.html` et `reporting.html`.

## Chrome commun

**Barre de navigation en verre** :
- sur-titre : le logement sélectionné, « Tous les logements » par défaut, avec `chevron.down` — ouvre un sélecteur ;
- grand titre : le mois, « Septembre » ;
- à droite : deux ronds 34×34, `chevron.left` / `chevron.right`, pour changer de mois ;
- en pied de barre : **sélecteur segmenté en verre** Planning / Revenus, deux parts égales, rayon 14.

Le mois et le logement sont partagés par les deux vues : changer de mois en Revenus et revenir en Planning garde le même mois.

## Vue Planning

1. **Grille du mois** — carte rayon 22. En-tête L M M J V S D, 10/bold. Cinq à six rangées de sept cases `flex: 1`, rayon 11, hauteur uniforme.
   - **Tous les logements** : numéro 14.5/semibold puis l'occupation `18/26` en 9.5. Le fond de la case s'assombrit avec le taux — `rgba(46,139,98,.10)` à `.26` — et le chiffre passe en `#1F6B4C`/semibold au-delà de 80 %.
   - **Un logement sélectionné** : le prix de la nuit remplace l'occupation. Un tap ouvre l'édition du prix — c'est le **prix manuel**, prioritaire sur les règles (comportement déjà en place côté web).
   - Le jour courant prend le fond `#0E3B2E`.
   - Les cases hors mois sont des `flex: 1` vides, pas des zéros.
2. **Détail du jour sélectionné** — intertitre « MARDI 1 SEPTEMBRE · 18 OCCUPÉS », puis une carte à trois lignes : arrivées, départs, ménages, chacune avec vignette colorée 38×38, compte, précision horaire, et chevron.
3. **« Bloquer des dates »** — ligne en verre léger, `nosign`.

## Vue Revenus

Six chiffres et deux répartitions. Tout le reste de `reporting.html` — comparateur, score de rentabilité, tableaux mensuels — reste sur le web.

1. **CA brut** — carte héro : intertitre, valeur 34/semibold `#14201B`, puis la décomposition « dont X ménage · Y taxe de séjour ».
2. **Revenu net** — carte héro, valeur en `#0E3B2E`, puis deux sous-blocs côte à côte : Conciergerie (fond menthe) et Propriétaires (fond blanc).
3. **Quatre indicateurs** en deux lignes de deux : réservations, nuits louées, commissions OTA (valeur en `#A8452A`), moyenne par nuit.
4. **« PAR PLATEFORME »** — une entrée par plateforme : point de couleur, nom, montant, pourcentage, puis barre de progression 6px à la couleur de la plateforme. Couleurs et normalisation : voir `01-design-tokens.md`.
5. **« MEILLEURS LOGEMENTS »** — les quatre premiers de `byProperty` : nom, nuits, montant aligné à droite.
6. **« Export comptable »** — ligne en verre léger, `square.and.arrow.down`, ouvre la feuille de partage iOS.

La moyenne par nuit n'est pas renvoyée par l'API : `totalGrossRevenue / totalNights`, arrondie.
