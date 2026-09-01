# 02 — Aujourd'hui

Maquette : `1a`. Routes : `GET /api/aujourdhui/etats` (code fourni, voir `06-ticket-T2.md`) **plus** `GET /api/cleaning/assignments` pour la section Ménage — deux appels en parallèle.

## Structure

**Barre de navigation en verre**, ancrée en haut, le contenu défile dessous.
- Sur-titre : la date en clair, `mardi 1 septembre`, 12.5/semibold gris atténué.
- Grand titre : « Aujourd'hui » 30/bold.
- À droite : rond `magnifyingglass` 38×38 en verre, puis rond d'initiales 38×38 `#DCE8E1` / texte `#0E3B2E` — **ce dernier ouvre la feuille Mon compte** (écran 10).

**Contenu**, marge 18, espacement 16, réserve haute 150.

1. **Trois compteurs** en ligne, `flex: 1` chacun, rayon 20 : arrivées, départs, à traiter. Le troisième prend le fond terracotta `rgba(253,240,236,.72)` et le texte `#A8452A` **seulement si le compte est non nul**. À zéro, il reprend l'apparence neutre — un compteur à zéro n'est pas une alerte.
2. **Bande calendrier sept jours** — carte rayon 24. Intertitre « AOÛT · SEPTEMBRE » plus `chevron.right` vers l'onglet Calendrier. Sept cases `flex: 1`, rayon 14 : jour abrégé 10/semibold, numéro 17/semibold, puis jusqu'à trois points ø4. Le jour courant prend le fond `#0E3B2E`, son abréviation passe à `#9CCBB8` et son numéro à blanc. La bande montre trois jours passés puis le jour courant puis trois jours à venir — le contexte compte autant que la suite. Légende en pied : occupé, départ, ménage.
3. **« À TRAITER MAINTENANT »** — intertitre, puis une carte par réservation bloquée : bordure terracotta, filet vertical 4px en dégradé `#C4552F → #A8452A` à gauche, nom 18/semibold, ligne « logement · heure · N nuits », badge plateforme en haut à droite. Les motifs de blocage en pastilles (« Fiche police non signée », « Infos bloquées »). Deux actions : la principale pleine largeur en vert, la secondaire « Écrire » en verre.
4. **« ARRIVÉES »** — une carte par arrivée, sans filet ni bordure colorée. Pastilles vertes pour ce qui est fait : `checkmark.circle` « Fiche signée », `key.fill` « Codes envoyés ».
5. **« DÉPARTS »** — même forme, avec l'heure de départ. **Cette section est vide si `departure_time` est absent**, d'où l'exigence de T2.
6. **« MÉNAGES DU JOUR »** — une ligne par ménage : logement, intervenante, créneau. Tap → écran 07. Source : `GET /api/cleaning/assignments`, appel séparé. La section n'apparaît qu'une fois cet appel revenu ; elle ne bloque pas le reste de l'écran.

**Barre d'onglets flottante**, onglet Aujourd'hui actif.

## Comportement

- Pull-to-refresh rappelle T2.
- Le tap sur une carte d'arrivée ouvre la réservation ; « Écrire » ouvre directement le fil de conversation — sauf si `conversation_id` est `null`, auquel cas le bouton propose de créer la conversation.

Les motifs de `blocking` renvoyés par la route sont pour l'instant : `pas_de_conversation`, `ia_a_passe_la_main`, `message_non_lu`, `code_acces_manquant`. Les pastilles « Fiche police non signée » et « Infos bloquées » de la maquette demandent des états du flux `checkin.html` qui n'ont pas encore été relevés — à ne pas afficher avant que la route les renvoie.
- Ordre des sections : à traiter, arrivées, départs, ménages. Une section sans contenu disparaît, elle n'affiche pas d'état vide — sauf si tout est vide, où l'écran montre une seule phrase centrée.
